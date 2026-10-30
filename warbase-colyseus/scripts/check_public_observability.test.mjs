import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { mkdtempSync, writeFileSync, chmodSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import express from 'express';
import { checkPublicApi, parseOptions } from './check_public_observability.mjs';
import { createOperationsMetricsHandler } from '../src/metrics-handler.ts';

const maps = ['football', 'resoforge', 'industrial', 'village', 'arena', 'shipment', 'dust2', 'nuketown', 'canyon', 'desert_oasis'];

function fixtureFetcher({ mapIds = maps, rooms = [{ id: 'industrial-public', map: 'industrial', playerCount: 2, botCount: 4, capacity: 64 }] } = {}) {
  return async (url, _timeout, headers = {}) => {
    const path = new URL(url).pathname;
    let status = 200;
    let json;
    if (path.endsWith('/health')) json = { status: 'ok', protocol: 'colyseus' };
    else if (path.endsWith('/api/maps')) json = { maps: mapIds.map((id) => typeof id === 'string' ? { id } : id) };
    else if (path.endsWith('/api/rooms')) json = { online_players: 2, rooms };
    else if (path.endsWith('/internal/metrics')) {
      if (headers.authorization === 'Bearer fixture-secret') json = { process: { uptimeSeconds: 12 } };
      else { status = 404; json = { error: 'not_found' }; }
    } else { status = 404; json = {}; }
    return { response: { status }, json, elapsedMs: 1 };
  };
}

test('public API check validates health, all supported maps, bounded rooms, and protected metrics', async (t) => {
  const options = parseOptions(['--base-url', 'https://example.test/colyseus'], { OPS_METRICS_TOKEN: 'fixture-secret' });
  const report = await checkPublicApi(options, fixtureFetcher());
  assert.equal(report.ok, true);
  assert.equal(report.checks.maps.count, 10);
  assert.equal(report.checks.rooms.listed, 1);
  assert.equal(report.checks.metrics.unauthenticatedStatus, 404);
  assert.equal(report.checks.metrics.authorizedStatus, 200);
});

test('public API check rejects unsupported maps and unsafe room lists', async (t) => {
  const options = parseOptions(['--base-url', 'https://example.test/colyseus'], {});
  await assert.rejects(checkPublicApi(options, fixtureFetcher({ mapIds: [...maps, 'loft'] })), /ten supported playable maps/);
  await assert.rejects(checkPublicApi(options, fixtureFetcher({ rooms: Array.from({ length: 257 }, (_, i) => ({
    id: `room-${i}`, map: 'industrial', playerCount: 0, botCount: 0, capacity: 64,
  })) })), /256-room safety bound/);
});

test('base URL parser rejects embedded credentials and invalid timeouts', () => {
  assert.throws(() => parseOptions(['--base-url', 'https://user:pass@example.test/colyseus'], {}), /without credentials/);
  assert.throws(() => parseOptions(['--base-url', 'https://example.test', '--timeout-ms', '30100'], {}), /250 through 30000/);
});

test('checker accepts a plaintext denial and reads its bearer token from a file against the real HTTP handler', async (t) => {
  const directory = mkdtempSync(join(tmpdir(), 'warbase-ops-metrics-'));
  const tokenFile = join(directory, 'metrics-token');
  writeFileSync(tokenFile, 'integration-secret\n', { mode: 0o600 });
  chmodSync(tokenFile, 0o400);
  t.after(() => rmSync(directory, { recursive: true, force: true }));

  const options = parseOptions(['--base-url', 'http://127.0.0.1:8082/'], { OPS_METRICS_TOKEN_FILE: tokenFile });
  const app = express();
  app.get('/health', (_req, res) => res.json({ status: 'ok', protocol: 'colyseus' }));
  app.get('/api/maps', (_req, res) => res.json({ maps: maps.map((id) => ({ id })) }));
  app.get('/api/rooms', (_req, res) => res.json({ online_players: 0, rooms: [] }));
  app.get('/internal/metrics', createOperationsMetricsHandler(options.metricsToken, () => ({ uptime_seconds: 1 })));
  const server = createServer(app);
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  t.after(() => new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve())));
  const address = server.address();
  assert.ok(address && typeof address !== 'string');
  options.baseUrl = `http://127.0.0.1:${address.port}/`;
  const report = await checkPublicApi(options);
  assert.equal(report.checks.metrics.unauthenticatedStatus, 401);
  assert.equal(report.checks.metrics.authorizedStatus, 200);
});
