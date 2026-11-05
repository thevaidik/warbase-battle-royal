import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import test from 'node:test';
import express from 'express';
import { mountOperationsTools } from './operations-tools.js';

test('debug tools reject production or non-loopback Playground configurations', () => {
  for (const config of [{ host: '0.0.0.0', production: false }, { host: '127.0.0.1', production: true }]) {
    assert.throws(() => mountOperationsTools(express(), { monitorEnabled: true, localPlaygroundEnabled: true, ...config }), /loopback/);
  }
});

test('mounted tools serve locally, deny public forwarding and stay disabled by default', async (t) => {
  for (const enabled of [false, true]) {
    const app = express();
    mountOperationsTools(app, { monitorEnabled: enabled, localPlaygroundEnabled: enabled, host: '127.0.0.1', production: false });
    const server = createServer(app);
    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve())));
    const address = server.address();
    assert.ok(address && typeof address !== 'string');
    const base = `http://127.0.0.1:${address.port}`;
    for (const route of ['/monitor/', '/playground/']) {
      const response = await fetch(base + route);
      assert.equal(response.status, enabled ? 200 : 404, route);
      if (enabled) assert.match(response.headers.get('cache-control') ?? '', /no-store|no-cache/);
      for (const prefix of ['/colyseus', '/other-public-proxy']) {
        const forwarded = await fetch(base + route, { headers: { 'X-Forwarded-Prefix': prefix } });
        assert.equal(forwarded.status, 404);
      }
    }
  }
});
