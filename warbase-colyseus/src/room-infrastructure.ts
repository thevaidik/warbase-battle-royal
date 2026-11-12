import { RedisPresence } from '@colyseus/redis-presence';
import { RedisDriver } from '@colyseus/redis-driver';

/** Defaults remain the framework's single-process services. Different rooms
 * can share these official Redis services when worker routing is configured. */
export function roomInfrastructureConfig(environment: NodeJS.ProcessEnv) {
  const value = String(environment.REDIS_URL ?? '').trim();
  if (!value) return null;
  let url: URL;
  try { url = new URL(value); } catch { throw new Error('REDIS_URL is invalid'); }
  if (!['redis:', 'rediss:'].includes(url.protocol) || !url.hostname || url.search || url.hash) throw new Error('REDIS_URL must use redis:// or rediss://');
  const db = url.pathname === '' || url.pathname === '/' ? 0 : Number(url.pathname.slice(1));
  if (!Number.isInteger(db) || db < 0 || db > 15) throw new Error('REDIS_URL database must be 0–15');
  if (!String(environment.PUBLIC_ADDRESS ?? '').trim()) throw new Error('Redis workers require their own reachable PUBLIC_ADDRESS');
  return {
    host: url.hostname, port: Number(url.port || 6379), db,
    username: url.username ? decodeURIComponent(url.username) : undefined,
    password: url.password ? decodeURIComponent(url.password) : undefined,
    tls: url.protocol === 'rediss:' ? {} : undefined,
    connectTimeout: 2500, maxRetriesPerRequest: 1,
    retryStrategy: (attempt: number) => attempt <= 2 ? 100 * attempt : null,
  };
}

export async function createRoomInfrastructure(environment: NodeJS.ProcessEnv) {
  const options = roomInfrastructureConfig(environment);
  if (!options) return {};
  const presence = new RedisPresence(options);
  const driver = new RedisDriver(options);
  let deadline: ReturnType<typeof setTimeout> | undefined;
  try {
    await Promise.race([
      Promise.all([presence.get('warbase:infrastructure:readiness'), driver.query({ name: 'battle' })]),
      new Promise((_, reject) => { deadline = setTimeout(() => reject(new Error('Redis startup deadline')), 6000); }),
    ]);
    return { presence, driver };
  } catch {
    await Promise.allSettled([presence.shutdown(), driver.shutdown()]);
    throw new Error('Configured Redis room services are unavailable');
  } finally {
    if (deadline) clearTimeout(deadline);
  }
}
