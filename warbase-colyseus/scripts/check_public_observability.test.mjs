import test from 'node:test';
import assert from 'node:assert/strict';
import { checkPublicApi, parseOptions } from './check_public_observability.mjs';

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
