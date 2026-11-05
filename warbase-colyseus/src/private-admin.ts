import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import type { RequestHandler } from 'express';

export async function createPrivateAdmin(environment: NodeJS.ProcessEnv) {
  if (environment.ENABLE_PRIVATE_ADMIN !== '1') return null;
  if (environment.ENABLE_PRIVATE_MONITOR !== '1') throw new Error('Private admin requires the Tailscale-only operations listener.');
  const databasePath = String(environment.ADMIN_DATABASE_PATH ?? '').trim();
  if (!databasePath) throw new Error('ADMIN_DATABASE_PATH must point to persistent admin-only storage.');
  const readSecret = (key: string): string => {
    const path = environment[key];
    if (!path) throw new Error(`${key} is required for the private admin panel.`);
    const value = readFileSync(path, 'utf8').trim();
    if (value.length < 32) throw new Error(`${key} must contain at least 32 characters.`);
    return value;
  };
  const jwtSecret = readSecret('ADMIN_JWT_SECRET_FILE');
  const sessionSecret = readSecret('ADMIN_SESSION_SECRET_FILE');
  const [{ GameDatabase }, { admin }, { JWT }] = await Promise.all([
    import('@colyseus/database'), import('@colyseus/admin'), import('@colyseus/auth'),
  ]);
  JWT.settings.secret = jwtSecret;
  process.env.SESSION_SECRET = sessionSecret;
  const database = new GameDatabase({ connectionString: resolve(databasePath) });
  await database.boot();
  try {
    const middleware = admin({
      database, enforceRbac: true, allowDevHeader: false, minPasswordLength: 12,
      session: { ttlSeconds: 8 * 60 * 60, cookieSameSite: 'Strict', cookieSecure: environment.ADMIN_TAILNET_HTTP !== '1' },
      // Never log reset tokens. Admins can use an explicitly configured mailer
      // later; the initial deployment uses the framework's bootstrap form.
      onResetRequest: async () => { throw new Error('Admin password-reset delivery is not configured.'); },
      dashboard: { presets: { totals: { only: ['users'] }, recentUsers: false, segments: false,
        liveRooms: { limit: 32, columns: ['roomId', 'name', 'clients', 'maxClients', 'metadata', 'locked'] } } },
    });
    return { database, middleware, guard: admin.guard({ database, role: 'admin' }) };
  } catch (error) {
    await database.shutdown();
    throw error;
  }
}

export const privateAdminOnly: RequestHandler = (req, res, next) => {
  if (req.get('x-forwarded-prefix')) { res.sendStatus(404); return; }
  res.setHeader('Cache-Control', 'no-store');
  next();
};
