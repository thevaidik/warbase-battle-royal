import { randomUUID, timingSafeEqual } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { extname, resolve } from 'node:path';
import { performance } from 'node:perf_hooks';
import { Server } from 'colyseus';
import { createRoom } from '@colyseus/core/MatchMaker';
import express from 'express';
import { WebSocketTransport } from '@colyseus/ws-transport';
import { BattleRoom, activeRooms } from './battle-room.js';
import { prewarmBotNavigation } from './bot-simulation.js';
import { loadWorldGeometry, PLAYABLE_MAPS, releaseWorldGeometry } from './world-geometry.js';
import { roomOperationsMetrics, serviceOperationsMetrics } from './operations-metrics.js';

const port = Number(process.env.PORT ?? 8081);
const host = process.env.HOST ?? '0.0.0.0';
const staticDirectory = String(process.env.STATIC_DIR ?? '').trim() ? resolve(String(process.env.STATIC_DIR).trim()) : '';
const publicAddress = String(process.env.PUBLIC_ADDRESS ?? '').trim() || undefined;
const operationsToken = String(process.env.OPS_METRICS_TOKEN ?? '');
const defaultMode = (map: string): string => ['industrial', 'resoforge', 'football'].includes(map) ? 'TDM' : 'FFA';
const gameServer = new Server({
  transport: new WebSocketTransport(),
  greet: false,
  publicAddress,
  express: (app) => {
    app.set('trust proxy', 1);
    app.use(express.json({ limit: '16kb' }));
    const health = (_req: any, res: any) => res.json({ status: 'ok', server: 'warbase-colyseus', protocol: 'colyseus', version: '0.18.10' });
    app.get('/health', health);
    app.get('/healthcheck', health);
    app.get('/internal/metrics', (req, res) => {
      if (!operationsToken) return res.sendStatus(404);
      res.setHeader('Cache-Control', 'no-store');
      const authorization = req.get('authorization') ?? '';
      const suppliedToken = authorization.startsWith('Bearer ') ? authorization.slice(7) : '';
      const supplied = Buffer.from(suppliedToken), expected = Buffer.from(operationsToken);
      if (supplied.length !== expected.length || !timingSafeEqual(supplied, expected)) return res.sendStatus(401);
      const roomMetrics = [...roomOperationsMetrics.values()];
      const sum = (field: keyof (typeof roomMetrics)[number]) => roomMetrics.reduce((total, value) => total + value[field], 0);
      const tickCount = sum('tickCount'), tickDuration = sum('totalTickDurationMs');
      const maxTickMs = roomMetrics.reduce((max, room) => Math.max(max, room.maxTickDurationMs), 0);
      return res.json({
        service: 'warbase-colyseus',
        uptime_seconds: Math.floor(process.uptime()),
        rooms: { active: activeRooms.size, clients: [...activeRooms.values()].reduce((n, room) => n + room.clients, 0), bots: [...activeRooms.values()].reduce((n, room) => n + room.bots, 0) },
        simulation: { ticks: tickCount, over_budget_ticks: sum('tickOverruns'), late_ticks: sum('lateTicks'), average_tick_ms: tickCount ? tickDuration / tickCount : 0, max_tick_ms: maxTickMs },
        inputs: { consumed: sum('consumedInputs'), empty_steps: sum('emptyInputSteps') },
        validation: { joins: sum('joined'), leaves: sum('left'), rejected_admissions: sum('rejectedAdmissions'), rejected_messages: sum('rejectedMessages'),
          rejected_payloads: sum('rejectedPayloads'), rate_limited_messages: sum('rateLimitedMessages'),
          rejected_room_creates: serviceOperationsMetrics.roomCreateRejected, rate_limited_room_creates: serviceOperationsMetrics.roomCreateRateLimited },
        process: { rss_bytes: process.memoryUsage().rss, heap_used_bytes: process.memoryUsage().heapUsed },
      });
    });
    app.get('/api/maps', (_req, res) => res.json({ maps: PLAYABLE_MAPS.map((map) => ({ id: map, mode: defaultMode(map) })) }));
    app.get('/api/rooms', (_req, res) => {
      const live = [...activeRooms.values()];
      const roomNames: Record<string, string> = {
        industrial: 'Industrial Zone (Public)', resoforge: 'ResoForge Yard (Public)', football: 'Football Stadium (Public)',
        village: 'Village Outpost (Public)', arena: 'Game Arena (Public)', shipment: 'Shipment (Public)',
        dust2: 'Industrial Recon (Public)', canyon: 'Canyon (Public)', desert_oasis: 'Desert Oasis (Public)', nuketown: 'Industrial Outpost (Public)',
      };
      const defaults = PLAYABLE_MAPS.map((map) => {
        const logicalId = `${map}-public`;
        const liveRoom = live.find((room) => room.room === logicalId);
        return { id: logicalId, name: liveRoom?.name ?? roomNames[map] ?? `${map} (Public)`, map, mode: liveRoom?.mode ?? defaultMode(map),
          playerCount: liveRoom?.clients ?? 0, botCount: liveRoom?.bots ?? 0, capacity: 64, timeOfDay: liveRoom?.timeOfDay ?? 'dusk' };
      });
      const custom = live.filter((room) => !room.room.endsWith('-public')).map((room) => ({ id: room.room, name: room.name, map: room.map, mode: room.mode,
        playerCount: room.clients, botCount: room.bots, capacity: room.maxClients, timeOfDay: room.timeOfDay }));
      const rooms = [...defaults, ...custom].sort((a, b) => b.playerCount - a.playerCount || a.name.localeCompare(b.name));
      const onlinePlayers = live.reduce((count, room) => count + room.clients, 0);
      return res.json({ online_players: onlinePlayers, rooms });
    });
    app.get('/api/rooms/:name', (req, res) => {
      const room = activeRooms.get(req.params.name) ?? [...activeRooms.values()].find((room) => room.room === req.params.name || room.id === req.params.name);
      if (!room) return res.status(404).json({ error: 'room_not_found' });
      return res.json(room);
    });
    app.post('/api/rooms', async (req, res) => {
      if (activeRooms.size >= 128) {
        serviceOperationsMetrics.roomCreateRejected++;
        return res.status(503).json({ error: 'room_capacity_reached' });
      }
      const map = String(req.body?.map ?? '').trim().toLowerCase();
      if (!loadWorldGeometry(map)) { serviceOperationsMetrics.roomCreateRejected++; return res.status(400).json({ error: 'unsupported_map' }); }
      const mode = String(req.body?.mode ?? defaultMode(map)).trim().toUpperCase();
      if (mode !== 'TDM' && mode !== 'FFA') { serviceOperationsMetrics.roomCreateRejected++; return res.status(400).json({ error: 'unsupported_mode' }); }
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
      try {
        const manifest = JSON.parse(readFileSync(manifestFile, 'utf8')) as { files?: Record<string, unknown> };
        manifestFiles = new Set(Object.keys(manifest.files ?? {}));
      } catch { /* Source/dev static folders may not have a candidate manifest. */ }
      app.use((req, res, next) => {
        if (req.method !== 'GET' && req.method !== 'HEAD') return next();
        let requestPath: string;
        try { requestPath = decodeURIComponent(new URL(req.originalUrl, 'http://localhost').pathname); }
        catch { return res.sendStatus(400); }
        const relative = requestPath.replace(/^\/+/, '');
        if (!relative || relative === 'candidate-manifest.json' || relative.includes('..') || relative.includes('\\')) return next();
        const root = resolve(staticDirectory);
        const identityFile = resolve(root, relative);
        if (!identityFile.startsWith(`${root}/`) || !existsSync(identityFile) || !manifestFiles.has(relative)) return next();
        const encoding = req.header('accept-encoding') ?? '';
        const sidecar = encoding.includes('br') && existsSync(`${identityFile}.br`) ? { path: `${identityFile}.br`, value: 'br' }
          : encoding.includes('gzip') && existsSync(`${identityFile}.gz`) ? { path: `${identityFile}.gz`, value: 'gzip' } : undefined;
        res.setHeader('Vary', 'Accept-Encoding');
        res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
        res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
        res.setHeader('Cache-Control', extname(relative) === '.html' ? 'no-cache' : 'public, max-age=31536000, immutable');
        if (!sidecar) return next();
        res.type(extname(relative));
        res.setHeader('Content-Encoding', sidecar.value);
        return res.sendFile(sidecar.path);
      });
      app.use(express.static(staticDirectory, {
        index: ['index.html'],
        setHeaders(res, path) {
          if (path.endsWith('.wasm')) res.type('application/wasm');
          if (path.endsWith('.dlink')) res.type('application/octet-stream');
          if (manifestFiles.has(path.split('/').pop() ?? '')) res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
          else if (path.endsWith('.wasm') || path.endsWith('.pck') || path.endsWith('.dlink')) res.setHeader('Cache-Control', 'public, max-age=300');
          else if (path.endsWith('.html') || path.endsWith('.js')) res.setHeader('Cache-Control', 'no-cache');
          res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
          res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
        },
      }));
      app.get('/', (_req, res) => res.sendFile(resolve(staticDirectory, 'index.html')));
    }
  },
});

gameServer.define('battle', BattleRoom).filterBy(['room']);
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
}).catch(async (error) => {
  console.error('Failed to start Colyseus server', error);
  await shutdown(1);
  // A failed transport can retain handles even though listen() rejected.
  process.exit(1);
});

process.once('SIGTERM', () => { void shutdown(); });
process.once('SIGINT', () => { void shutdown(); });
