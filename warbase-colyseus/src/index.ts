import { GAME_PROTOCOL_VERSION } from './schema.js';
import { randomBytes, randomUUID } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { extname, resolve } from 'node:path';
import { monitorEventLoopDelay, performance } from 'node:perf_hooks';
import { Server } from 'colyseus';
import { mountOperationsTools } from './operations-tools.js';
import { createPrivateAdmin, privateAdminOnly } from './private-admin.js';
import { createRoom } from '@colyseus/core/MatchMaker';
import express from 'express';
import { WebSocketTransport } from '@colyseus/ws-transport';
import { BattleRoom, activeRooms } from './battle-room.js';
import { prewarmBotNavigation } from './bot-simulation.js';
import { loadWorldGeometry, PLAYABLE_MAPS, releaseWorldGeometry } from './world-geometry.js';
import { processOperationsMetrics, processTimingSnapshot, roomOperationsMetrics, serviceOperationsMetrics } from './operations-metrics.js';
import { createOperationsMetricsHandler } from './metrics-handler.js';
import { configureBattleAdmission, loadAdmissionGatewaySecret, loadAdmissionSecret } from './admission.js';
import { configureRealtimeLobby } from './lobby.js';
import { createRoomInfrastructure } from './room-infrastructure.js';
import { buildRoomDirectory, listLiveBattleRooms } from './room-directory.js';
import { assetCacheControl } from './static-cache.js';

const port = Number(process.env.PORT ?? 8081);
const host = process.env.HOST ?? '0.0.0.0';
const localMonitorEnabled = process.env.ENABLE_LOCAL_MONITOR === '1';
const privateMonitorEnabled = process.env.ENABLE_PRIVATE_MONITOR === '1';
const isLoopbackHost = host === '127.0.0.1' || host === '::1';
if (localMonitorEnabled && (process.env.NODE_ENV === 'production' || !isLoopbackHost)) {
  throw new Error('The Colyseus monitoring panel is local-only; use a non-production server bound to 127.0.0.1 or ::1.');
}
if (privateMonitorEnabled && process.env.NODE_ENV !== 'production') {
  throw new Error('ENABLE_PRIVATE_MONITOR is reserved for the production candidate behind its Tailscale-only host binding.');
}
const monitorEnabled = localMonitorEnabled || privateMonitorEnabled;
const admissionSecretPath = String(process.env.ADMISSION_JWT_SECRET_FILE ?? '').trim();
const admissionGatewaySecretPath = String(process.env.ADMISSION_GATEWAY_SECRET_FILE ?? '').trim();
const admissionTrustedProxyCidrs = String(process.env.ADMISSION_TRUSTED_PROXY_CIDRS ?? '').split(',').map((cidr) => cidr.trim()).filter(Boolean);
if (process.env.NODE_ENV === 'production' && !admissionSecretPath) {
  throw new Error('ADMISSION_JWT_SECRET_FILE is required in production for anonymous gameplay admission.');
}
if (process.env.NODE_ENV === 'production' && !admissionGatewaySecretPath) {
  throw new Error('ADMISSION_GATEWAY_SECRET_FILE is required in production for trusted proxy attribution.');
}
if (process.env.NODE_ENV === 'production' && admissionTrustedProxyCidrs.length === 0) {
  throw new Error('ADMISSION_TRUSTED_PROXY_CIDRS must pin the immediate gateway peer in production.');
}
const positiveLimit = (key: string, fallback: number): number => {
  const raw = String(process.env[key] ?? '').trim();
  if (!raw) return fallback;
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value < 1) throw new Error(`${key} must be a positive integer.`);
  return value;
};
// Local clients use the same signed flow. A development restart intentionally
// invalidates its temporary tickets; production always requires persisted keys.
const admissionSecret = admissionSecretPath ? loadAdmissionSecret(process.env) : randomBytes(32).toString('base64url');
const admissionGatewaySecret = admissionGatewaySecretPath ? loadAdmissionGatewaySecret(process.env) : undefined;
// Admission uses its own JWT key. Do not assign @colyseus/auth's process-global
// JWT.settings.secret here; that key is reserved for the separate admin panel.
const admission = configureBattleAdmission(admissionSecret ? {
  secret: admissionSecret,
  gatewaySecret: admissionGatewaySecret,
  trustedProxyCidrs: admissionTrustedProxyCidrs,
  perCallerLimit: positiveLimit('ADMISSION_ISSUE_PER_CALLER_PER_MINUTE', 30),
  globalLimit: positiveLimit('ADMISSION_ISSUE_GLOBAL_PER_MINUTE', 300),
  playerJoinLimit: positiveLimit('ADMISSION_PLAYER_JOINS_PER_MINUTE', 30),
  playerRoomCreateLimit: positiveLimit('ADMISSION_PLAYER_ROOM_CREATES_PER_MINUTE', 4),
} : undefined);
const privateAdmin = await createPrivateAdmin(process.env);
const staticDirectory = String(process.env.STATIC_DIR ?? '').trim() ? resolve(String(process.env.STATIC_DIR).trim()) : '';
const publicAddress = String(process.env.PUBLIC_ADDRESS ?? '').trim() || undefined;
const operationsTokenFile = String(process.env.OPS_METRICS_TOKEN_FILE ?? '').trim();
const operationsToken = (operationsTokenFile ? readFileSync(operationsTokenFile, 'utf8').trim() : '') || String(process.env.OPS_METRICS_TOKEN ?? '');
const eventLoopDelay = monitorEventLoopDelay({ resolution: 20 });
if (operationsToken) eventLoopDelay.enable();
const defaultMode = (_map: string): string => 'CONQUEST';
const roomInfrastructure = await createRoomInfrastructure(process.env);
const gameServer = new Server({
  ...roomInfrastructure,
  transport: new WebSocketTransport(),
  greet: false,
  publicAddress,
  express: (app) => {
    app.set('trust proxy', 1);
    app.use(express.json({ limit: '16kb' }));
    if (privateAdmin) {
      app.use(['/admin', '/admin-api'], privateAdminOnly);
      app.use(privateAdmin.middleware);
    }
    mountOperationsTools(app, { monitorEnabled, localPlaygroundEnabled: localMonitorEnabled,
      host, production: process.env.NODE_ENV === 'production', adminGuard: privateAdmin?.guard });
    const health = (_req: any, res: any) => res.json({ status: 'ok', server: 'warbase-colyseus', protocol: 'colyseus', game_protocol: GAME_PROTOCOL_VERSION, version: '0.18.10' });
    app.get('/health', health);
    app.get('/healthcheck', health);
    app.get('/internal/metrics', createOperationsMetricsHandler(operationsToken, () => {
      const roomMetrics = [...roomOperationsMetrics.values()];
      const sum = (field: keyof (typeof roomMetrics)[number]) => roomMetrics.reduce((total, value) => total + value[field], 0);
      const tickCount = sum('tickCount'), tickDuration = sum('totalTickDurationMs');
      const maxTickMs = roomMetrics.reduce((max, room) => Math.max(max, room.maxTickDurationMs), 0);
      return {
        service: 'warbase-colyseus',
        uptime_seconds: Math.floor(process.uptime()),
        rooms: { active: activeRooms.size, clients: [...activeRooms.values()].reduce((n, room) => n + room.clients, 0), bots: [...activeRooms.values()].reduce((n, room) => n + room.bots, 0) },
        simulation: { active_room_aggregates: { ticks: tickCount, over_budget_ticks: sum('tickOverruns'), late_ticks: sum('lateTicks'), average_tick_ms: tickCount ? tickDuration / tickCount : 0,
          max_tick_ms: maxTickMs }, recent_window: processTimingSnapshot(),
          event_loop_delay: { p95_ms: eventLoopDelay.percentile(95) / 1e6, max_ms: eventLoopDelay.max / 1e6 } },
        inputs: { active_room_aggregates: { consumed: sum('consumedInputs'), empty_steps: sum('emptyInputSteps') } },
        validation: { active_room_totals: { joins: sum('joined'), leaves: sum('left'), rejected_admissions: sum('rejectedAdmissions'), rejected_messages: sum('rejectedMessages'),
          rejected_payloads: sum('rejectedPayloads'), rate_limited_messages: sum('rateLimitedMessages') },
          process_lifetime: { ...processOperationsMetrics, rejected_room_creates: serviceOperationsMetrics.roomCreateRejected,
            rate_limited_room_creates: serviceOperationsMetrics.roomCreateRateLimited } },
        process: { rss_bytes: process.memoryUsage().rss, heap_used_bytes: process.memoryUsage().heapUsed },
      };
    }));
    app.get('/api/maps', (_req, res) => res.json({ maps: PLAYABLE_MAPS.map((map) => ({ id: map, mode: defaultMode(map) })) }));
    if (admission) app.post('/api/admission', admission.issueTicket);
    app.get('/api/rooms', async (_req, res) => {
      try { return res.json(buildRoomDirectory(await listLiveBattleRooms())); }
      catch { return res.status(503).json({ error: 'room_directory_unavailable' }); }
    });
    app.get('/api/rooms/:name', async (req, res) => {
      try {
        const room = (await listLiveBattleRooms()).find(room => room.room === req.params.name || room.id === req.params.name);
        return room ? res.json(room) : res.status(404).json({ error: 'room_not_found' });
      } catch { return res.status(503).json({ error: 'room_directory_unavailable' }); }
    });
    app.post('/api/rooms', admission?.roomCreateMiddleware ?? ((_req: any, _res: any, next: any) => next()), async (req, res) => {
      if (activeRooms.size >= 128) {
        serviceOperationsMetrics.roomCreateRejected++;
        return res.status(503).json({ error: 'room_capacity_reached' });
      }
      const map = String(req.body?.map ?? '').trim().toLowerCase();
      if (!PLAYABLE_MAPS.includes(map as (typeof PLAYABLE_MAPS)[number])) { serviceOperationsMetrics.roomCreateRejected++; return res.status(400).json({ error: 'unsupported_map' }); }
      const mode = String(req.body?.mode ?? defaultMode(map)).trim().toUpperCase();
      if (mode !== 'TDM' && mode !== 'FFA' && mode !== 'CONQUEST') { serviceOperationsMetrics.roomCreateRejected++; return res.status(400).json({ error: 'unsupported_mode' }); }
      const rawTime = String(req.body?.timeOfDay ?? req.body?.time_of_day ?? 'noon').trim().toLowerCase();
      const timeOfDay = rawTime === 'night' ? 'overcast' : rawTime;
      if (!['dawn', 'noon', 'dusk', 'overcast'].includes(timeOfDay)) { serviceOperationsMetrics.roomCreateRejected++; return res.status(400).json({ error: 'unsupported_time_of_day' }); }
      const roomId = randomUUID();
      const name = String(req.body?.name ?? '').trim().slice(0, 48) || `${map} ${mode}`;
      try {
        await createRoom('battle', { room: roomId, name, map, mode, time_of_day: timeOfDay });
        return res.status(201).json({ room_id: roomId });
      } catch (error) {
        if (!(error instanceof Error) || !['Room creation capacity reached', 'Room creation rate limited'].includes(error.message)) serviceOperationsMetrics.roomCreateRejected++;
        console.error('Failed to create Colyseus room', error);
        return res.status(400).json({ error: 'room_creation_failed' });
      }
    });
    if (staticDirectory && existsSync(staticDirectory)) {
      const manifestFile = resolve(staticDirectory, 'candidate-manifest.json');
      let manifestFiles = new Set<string>();
      let noCacheFiles = new Set<string>();
      const root = resolve(staticDirectory);
      try {
        const manifest = JSON.parse(readFileSync(manifestFile, 'utf8')) as { files?: Record<string, unknown>; cachePolicy?: { noCacheAssets?: unknown } };
        manifestFiles = new Set(Object.keys(manifest.files ?? {}));
        noCacheFiles = new Set(Array.isArray(manifest.cachePolicy?.noCacheAssets) ? manifest.cachePolicy!.noCacheAssets.filter((name): name is string => typeof name === 'string') : []);
      } catch { /* Source/dev static folders may not have a candidate manifest. */ }
      app.use((req, res, next) => {
        if (req.method !== 'GET' && req.method !== 'HEAD') return next();
        let requestPath: string;
        try { requestPath = decodeURIComponent(new URL(req.originalUrl, 'http://localhost').pathname); }
        catch { return res.sendStatus(400); }
        const relative = requestPath.replace(/^\/+/, '');
        if (!relative || relative === 'candidate-manifest.json' || relative.includes('..') || relative.includes('\\')) return next();
        const identityFile = resolve(root, relative);
        if (!identityFile.startsWith(`${root}/`) || !existsSync(identityFile) || !manifestFiles.has(relative)) return next();
        const encoding = req.header('accept-encoding') ?? '';
        const sidecar = encoding.includes('br') && existsSync(`${identityFile}.br`) ? { path: `${identityFile}.br`, value: 'br' }
          : encoding.includes('gzip') && existsSync(`${identityFile}.gz`) ? { path: `${identityFile}.gz`, value: 'gzip' } : undefined;
        res.setHeader('Vary', 'Accept-Encoding');
        res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
        res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
        res.setHeader('Cache-Control', assetCacheControl(relative, manifestFiles, noCacheFiles)!);
        if (!sidecar) return next();
        res.type(extname(relative));
        res.setHeader('Content-Encoding', sidecar.value);
        return res.sendFile(sidecar.path);
      });
      app.use(express.static(staticDirectory, {
        index: ['index.html'],
        setHeaders(res, path) {
          const relative = path.startsWith(`${root}/`) ? path.slice(root.length + 1).replaceAll('\\', '/') : '';
          if (path.endsWith('.wasm')) res.type('application/wasm');
          if (path.endsWith('.dlink')) res.type('application/octet-stream');
          const cacheControl = assetCacheControl(relative, manifestFiles, noCacheFiles);
          if (cacheControl) res.setHeader('Cache-Control', cacheControl);
          res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
          res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
        },
      }));
      app.get('/', (_req, res) => res.sendFile(resolve(staticDirectory, 'index.html')));
    }
  },
});

const battleHandler = gameServer.define('battle', BattleRoom).filterBy(['room']);
configureRealtimeLobby(gameServer, battleHandler);
let shuttingDown = false;
async function shutdown(exitCode = 0): Promise<void> {
  if (shuttingDown) return;
  shuttingDown = true;
  const forceExit = setTimeout(() => {
    console.error('Colyseus shutdown exceeded 5 seconds; exiting');
    process.exit(1);
  }, 5_000);
  forceExit.unref();
  try {
    await gameServer.gracefullyShutdown(false);
    if (privateAdmin) await privateAdmin.database.shutdown();
  } catch (error) {
    console.error('Failed to shut down Colyseus cleanly', error);
    exitCode = 1;
  } finally {
    clearTimeout(forceExit);
  }
  process.exitCode = exitCode;
}

const navigationWarmStarted = performance.now();
for (const map of PLAYABLE_MAPS) {
  const geometry = loadWorldGeometry(map);
  if (!geometry) throw new Error(`Unable to load navigation geometry for ${map}`);
  prewarmBotNavigation(geometry);
  releaseWorldGeometry(map);
}
const navigationWarmMs = performance.now() - navigationWarmStarted;
const navigationMemory = process.memoryUsage();
console.log(`Bot navigation prewarmed for ${PLAYABLE_MAPS.length} maps in ${navigationWarmMs.toFixed(0)} ms (RSS ${(navigationMemory.rss / 1024 / 1024).toFixed(1)} MiB, heap ${(navigationMemory.heapUsed / 1024 / 1024).toFixed(1)} MiB)`);

gameServer.listen(port, host).then(() => {
  const address = (gameServer as any).transport.server?.address?.();
  const boundPort = typeof address === 'object' && address ? address.port : port;
  console.log(`WarBase Colyseus server listening on ${host}:${boundPort}`);
  if (localMonitorEnabled) console.log(`Local Colyseus monitor: http://${host}:${boundPort}/monitor`);
  if (privateMonitorEnabled) console.log('Private Colyseus monitor enabled; expose it only through the host Tailscale address.');
}).catch(async (error) => {
  console.error('Failed to start Colyseus server', error);
  await shutdown(1);
  // A failed transport can retain handles even though listen() rejected.
  process.exit(1);
});

process.once('SIGTERM', () => { void shutdown(); });
process.once('SIGINT', () => { void shutdown(); });
