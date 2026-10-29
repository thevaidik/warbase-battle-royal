#!/usr/bin/env node

/** Read-only smoke check for the public Colyseus API and optional ops metrics. */
import { pathToFileURL } from 'node:url';

const PLAYABLE_MAPS = [
  'football', 'resoforge', 'industrial', 'village', 'arena', 'shipment',
  'dust2', 'nuketown', 'canyon', 'desert_oasis',
];
const MAX_BODY_BYTES = 256 * 1024;

export function parseOptions(argv, env = process.env) {
  const options = { baseUrl: '', timeoutMs: 5000, metricsToken: env.OPS_METRICS_TOKEN ?? '' };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--base-url') options.baseUrl = argv[++i] ?? '';
    else if (arg === '--timeout-ms') options.timeoutMs = Number(argv[++i]);
    else if (arg === '--no-metrics') options.metricsToken = null;
    else if (arg === '--help' || arg === '-h') options.help = true;
    else throw new Error(`Unknown option: ${arg}`);
  }
  if (options.help) return options;
  if (!options.baseUrl) throw new Error('Pass --base-url, for example https://war.vaidik.blog/colyseus/');
  const base = new URL(options.baseUrl);
  if (!['http:', 'https:'].includes(base.protocol) || base.username || base.password || base.search || base.hash)
    throw new Error('--base-url must be an HTTP(S) URL without credentials, query, or fragment');
  if (!Number.isInteger(options.timeoutMs) || options.timeoutMs < 250 || options.timeoutMs > 30000)
    throw new Error('--timeout-ms must be an integer from 250 through 30000');
  options.baseUrl = base.href.endsWith('/') ? base.href : `${base.href}/`;
  return options;
}

async function getJson(url, timeoutMs, headers = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  timer.unref?.();
  const started = performance.now();
  try {
    const response = await fetch(url, { method: 'GET', headers, signal: controller.signal, redirect: 'error' });
    const text = await response.text();
    if (Buffer.byteLength(text) > MAX_BODY_BYTES) throw new Error(`${new URL(url).pathname} response exceeded ${MAX_BODY_BYTES} bytes`);
    let json;
    try { json = JSON.parse(text); } catch { throw new Error(`${new URL(url).pathname} did not return JSON (HTTP ${response.status})`); }
    return { response, json, elapsedMs: performance.now() - started };
  } finally {
    clearTimeout(timer);
  }
}

function requireStatus(result, status, path) {
  if (result.response.status !== status) throw new Error(`${path} returned HTTP ${result.response.status}; expected ${status}`);
}

export async function checkPublicApi(options, fetcher = getJson) {
  const health = await fetcher(new URL('health', options.baseUrl), options.timeoutMs);
  requireStatus(health, 200, '/health');
  if (health.json?.status !== 'ok' || health.json?.protocol !== 'colyseus') throw new Error('/health response contract mismatch');

  const maps = await fetcher(new URL('api/maps', options.baseUrl), options.timeoutMs);
  requireStatus(maps, 200, '/api/maps');
  const ids = Array.isArray(maps.json?.maps) ? maps.json.maps.map((map) => map?.id) : [];
  if (PLAYABLE_MAPS.some((id) => !ids.includes(id)) || ids.some((id) => !PLAYABLE_MAPS.includes(id)))
    throw new Error('/api/maps did not match the ten supported playable maps');

  const rooms = await fetcher(new URL('api/rooms', options.baseUrl), options.timeoutMs);
  requireStatus(rooms, 200, '/api/rooms');
  if (!Number.isSafeInteger(rooms.json?.online_players) || rooms.json.online_players < 0 || !Array.isArray(rooms.json?.rooms))
    throw new Error('/api/rooms response contract mismatch');
  if (rooms.json.rooms.length > 256) throw new Error('/api/rooms exceeded the 256-room safety bound');
  for (const room of rooms.json.rooms) {
    if (typeof room?.id !== 'string' || !PLAYABLE_MAPS.includes(room?.map)
      || !Number.isSafeInteger(room?.playerCount) || room.playerCount < 0
      || !Number.isSafeInteger(room?.botCount) || room.botCount < 0
      || !Number.isSafeInteger(room?.capacity) || room.capacity < 1) {
      throw new Error('/api/rooms contains an invalid or unsupported room record');
    }
  }

  const result = {
    ok: true,
    checks: {
      health: { status: health.response.status, elapsedMs: Math.round(health.elapsedMs) },
      maps: { status: maps.response.status, count: ids.length },
      rooms: { status: rooms.response.status, listed: rooms.json.rooms.length, onlinePlayers: rooms.json.online_players },
    },
  };

  if (options.metricsToken) {
    const metricsUrl = new URL('internal/metrics', options.baseUrl);
    const denied = await fetcher(metricsUrl, options.timeoutMs);
    if (denied.response.status !== 404 && denied.response.status !== 401 && denied.response.status !== 403)
      throw new Error('Unauthenticated /internal/metrics request was not denied');
    const authorized = await fetcher(metricsUrl, options.timeoutMs, { authorization: `Bearer ${options.metricsToken}` });
    requireStatus(authorized, 200, '/internal/metrics with bearer token');
    if (!authorized.json || typeof authorized.json !== 'object' || Array.isArray(authorized.json))
      throw new Error('/internal/metrics did not return a JSON object');
    result.checks.metrics = { unauthenticatedStatus: denied.response.status, authorizedStatus: authorized.response.status };
  } else {
    result.checks.metrics = { skipped: true, reason: 'OPS_METRICS_TOKEN is unset or --no-metrics was passed' };
  }
  return result;
}

const HELP = `Usage: node scripts/check_public_observability.mjs --base-url https://war.vaidik.blog/colyseus/

Read-only bounded GET checks for /health, /api/maps, /api/rooms, and (when OPS_METRICS_TOKEN is set) the token-gated /internal/metrics route.
Options: --timeout-ms 5000 (250..30000), --no-metrics, --help
Never pass the metrics token as a command-line argument.`;

async function main() {
  const options = parseOptions(process.argv.slice(2));
  if (options.help) { console.log(HELP); return; }
  const result = await checkPublicApi(options);
  console.log(JSON.stringify(result, null, 2));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(`OBSERVABILITY_CHECK_FAILED: ${error.message}`);
    process.exitCode = 1;
  });
}
