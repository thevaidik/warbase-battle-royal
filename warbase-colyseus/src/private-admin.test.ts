import assert from 'node:assert/strict';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createServer } from 'node:http';
import test from 'node:test';
import express from 'express';
import { createPrivateAdmin, privateAdminOnly } from './private-admin.js';
import { mountOperationsTools } from './operations-tools.js';

test('private admin is opt-in and requires private operations storage and secrets', async () => {
  assert.equal(await createPrivateAdmin({}), null);
  await assert.rejects(createPrivateAdmin({ ENABLE_PRIVATE_ADMIN: '1' }), /Tailscale/);
  await assert.rejects(createPrivateAdmin({ ENABLE_PRIVATE_ADMIN: '1', ENABLE_PRIVATE_MONITOR: '1' }), /storage/);
});

test('beta admin bootstraps, authenticates and persists while denying public forwarding', async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'warbase-admin-test-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const jwtFile = join(directory, 'jwt');
  const sessionFile = join(directory, 'session');
  await writeFile(jwtFile, 'test-only-jwt-secret-0123456789abcdef0123456789', { mode: 0o600 });
  await writeFile(sessionFile, 'test-only-session-secret-0123456789abcdef0123456789', { mode: 0o600 });
  const environment = { ENABLE_PRIVATE_ADMIN: '1', ENABLE_PRIVATE_MONITOR: '1', ADMIN_TAILNET_HTTP: '1',
    ADMIN_DATABASE_PATH: join(directory, 'admin.sqlite'), ADMIN_JWT_SECRET_FILE: jwtFile, ADMIN_SESSION_SECRET_FILE: sessionFile };
  const panel = await createPrivateAdmin(environment);
  assert.ok(panel);
  const app = express();
  app.use(express.json());
  app.use(['/admin', '/admin-api'], privateAdminOnly);
  app.use(panel.middleware);
  mountOperationsTools(app, { monitorEnabled: true, localPlaygroundEnabled: false, host: '127.0.0.1', production: true, adminGuard: panel.guard });
  const server = createServer(app);
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(async () => { await new Promise<void>((resolve) => server.close(() => resolve())); await panel.database.shutdown(); });
  const address = server.address();
  assert.ok(address && typeof address !== 'string');
  const base = `http://127.0.0.1:${address.port}`;
  assert.equal((await fetch(base + '/admin/')).status, 200);
  const status = await (await fetch(base + '/admin-api/auth/status')).json() as any;
  assert.equal(status.needsBootstrap, true);
  assert.equal((await fetch(base + '/monitor/api')).status, 401);
  assert.equal((await fetch(base + '/admin-api/auth/me', { headers: { 'X-User-Id': 'fake-admin' } })).status, 401);
  for (const route of ['/admin/', '/admin-api/auth/status', '/monitor/']) {
    assert.equal((await fetch(base + route, { headers: { 'X-Forwarded-Prefix': '/colyseus' } })).status, 404);
  }
  const credentials = { email: 'operator@example.invalid', password: 'test-only-password-with-24chars' };
  const boot = await fetch(base + '/admin-api/auth/bootstrap', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(credentials) });
  assert.equal(boot.status, 200, await boot.clone().text());
  const cookie = boot.headers.get('set-cookie')?.split(';')[0];
  assert.ok(cookie);
  const me = await fetch(base + '/admin-api/auth/me', { headers: { Cookie: cookie } });
  assert.equal(me.status, 200);
  assert.equal((await fetch(base + '/admin-api/auth/bootstrap', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(credentials) })).status, 403);
  assert.equal((await fetch(base + '/admin-api/_health')).status, 200);
  const signedInStatus = await (await fetch(base + '/admin-api/auth/status', { headers: { Cookie: cookie } })).json() as any;
  assert.equal(signedInStatus.needsBootstrap, false);
  assert.equal(signedInStatus.role, 'admin');
  // Reopening the same SQLite file must retain the first administrator.
  const reopened = await createPrivateAdmin(environment);
  assert.ok(reopened);
  try { assert.equal(await reopened.database.moderation.getRole(signedInStatus.userId), 'admin'); }
  finally { await reopened.database.shutdown(); }
});
