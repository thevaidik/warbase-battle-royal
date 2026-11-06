#!/usr/bin/env node
import NodeWebSocket from 'ws';
import { monitorEventLoopDelay } from 'node:perf_hooks';
import { setTimeout as sleep } from 'node:timers/promises';
import { chmod, lstat, mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

globalThis.WebSocket = NodeWebSocket;
const { Client } = await import('@colyseus/sdk');
const SDK_VERSION = JSON.parse(await readFile(new URL('../node_modules/@colyseus/sdk/package.json', import.meta.url), 'utf8')).version;

const OFFICIAL_URL = 'https://war.vaidik.blog/colyseus';
const MAX_PEERS = 63; // 63 SDK peers plus the separately verified QA_NATIVE observer.
const MAX_DURATION_SECONDS = 300;
const MAX_WALL_SECONDS = 480;
const JOIN_TIMEOUT_MS = 20_000;
const PLAYABLE_MAPS = new Set(['football', 'resoforge', 'industrial', 'village', 'arena', 'shipment', 'dust2', 'nuketown', 'canyon', 'desert_oasis']);

function argumentsFrom(argv) {
  const values = { url: '', map: 'industrial', mode: 'CONQUEST', peers: 63, seconds: 180, observer: 'QA_NATIVE', observerTimeout: 90, output: '/results/official-load.json', steady: false, admissionCache: '', roomId: '', totalPeers: null, coordinated: false };
  for (let i = 0; i < argv.length; i++) {
    const [key, inline] = argv[i].split('=', 2);
    if (key === '--help') return { help: true };
    if (key === '--coordinated') { values.coordinated = true; continue; }
    if (key === '--steady') { values.steady = true; continue; }
    const value = inline ?? argv[++i];
    if (!value) throw new Error(`Missing value for ${key}`);
    if (key === '--url') values.url = value;
    else if (key === '--room-id') values.roomId = value;
    else if (key === '--total-peers') values.totalPeers = Number(value);
    else if (key === '--map') values.map = value;
    else if (key === '--mode') values.mode = value;
    else if (key === '--peers') values.peers = Number(value);
    else if (key === '--seconds') values.seconds = Number(value);
    else if (key === '--observer') values.observer = value;
    else if (key === '--observer-timeout') values.observerTimeout = Number(value);
    else if (key === '--output') values.output = value;
    else if (key === '--admission-cache') values.admissionCache = value;
    else throw new Error(`Unknown option: ${key}`);
  }
  return values;
}

function validate(options) {
  if (options.url !== OFFICIAL_URL) throw new Error(`Refusing endpoint. --url must be exactly ${OFFICIAL_URL}`);
  options.totalPeers ??= options.peers;
  if (!Number.isInteger(options.totalPeers) || options.totalPeers < options.peers || options.totalPeers > MAX_PEERS) throw new Error('--total-peers must include this cohort and be at most 63');
  if (options.roomId && !/^[A-Za-z0-9_-]{1,64}$/.test(options.roomId)) throw new Error('Invalid room identifier');
  if (options.coordinated && !process.send) throw new Error('--coordinated requires the multiprocess runner');
  const parsed = new URL(options.url);
  if (parsed.protocol !== 'https:' || parsed.hostname !== 'war.vaidik.blog' || parsed.pathname !== '/colyseus' || parsed.search || parsed.hash) {
    throw new Error('Refusing non-official or non-candidate endpoint');
  }
  if (!['CONQUEST', 'FFA', 'TDM'].includes(options.mode)) throw new Error('Unsupported mode');
  if (!PLAYABLE_MAPS.has(options.map)) throw new Error(`Unsupported map: ${options.map}`);
  if (!Number.isInteger(options.peers) || options.peers < 1 || options.peers > MAX_PEERS) throw new Error(`--peers must be 1..${MAX_PEERS}; the separate native observer uses one additional slot`);
  if (!Number.isFinite(options.seconds) || options.seconds < 15 || options.seconds > MAX_DURATION_SECONDS) throw new Error(`--seconds must be 15..${MAX_DURATION_SECONDS}`);
  if (!Number.isInteger(options.observerTimeout) || options.observerTimeout < 10 || options.observerTimeout > 120) throw new Error('--observer-timeout must be 10..120');
  if (!/^[A-Za-z0-9_-]{1,24}$/.test(options.observer)) throw new Error('--observer must be a 1..24 character room username');
  return parsed;
}

function percentile(values, fraction) {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return Number(sorted[Math.min(sorted.length - 1, Math.floor((sorted.length - 1) * fraction))].toFixed(2));
}

function vec3(value) {
  if (!value || value.length < 3) return null;
  const result = [Number(value[0]), Number(value[1]), Number(value[2])];
  return result.every(Number.isFinite) ? result : null;
}

export function vehiclePosition(vehicle) {
  const scalar = [vehicle?.x, vehicle?.y, vehicle?.z];
  return scalar.every(Number.isFinite) ? scalar : vec3(vehicle?.pos);
}

function entries(map) {
  return map ? Array.from(map.entries()) : [];
}

export function stageVehicleControls(data, player, phase) {
  const driving = Boolean(player?.driving_vehicle);
  data.vehicle_index = Number(player?.vehicle_index ?? -1);
  data.vehicle_generation = Number(player?.vehicle_generation ?? 0);
  data.vehicle_throttle = driving ? 0.65 : 0;
  data.vehicle_steer = driving ? Math.sin(phase) * 0.25 : 0;
  data.vehicle_brake = driving ? 0 : 1;
  data.vehicle_gear = 1;
  return data;
}

export function evaluateSteadySample({ gateOpen, stateFresh, liveClients, humanPlayers, observerPresent, cohortOpen }) {
  return Boolean(gateOpen && stateFresh && liveClients === 64 && humanPlayers >= 64 && observerPresent && cohortOpen);
}

export function peerDropExpired(dropStartedAt, nowMs, graceMs = 2000) {
  return Number.isFinite(dropStartedAt) && dropStartedAt > 0 && nowMs - dropStartedAt > graceMs;
}

export function admissionCacheReusable(cache, { endpoint, count, nowMs, minimumRemainingMs }) {
  return Boolean(cache && cache.endpoint === endpoint && Array.isArray(cache.tickets) && cache.tickets.length === count &&
    cache.tickets.every((ticket) => typeof ticket?.token === 'string' && ticket.token.length > 0 && Number.isFinite(ticket.expiresAt) && ticket.expiresAt >= nowMs + minimumRemainingMs));
}

async function readAdmissionCache(cachePath, required) {
  if (!cachePath) return null;
  try {
    const info = await lstat(cachePath);
    if (!info.isFile() || (typeof process.getuid === 'function' && info.uid !== process.getuid()) || (info.mode & 0o077) !== 0) return null;
    const cache = JSON.parse(await readFile(cachePath, 'utf8'));
    return admissionCacheReusable(cache, required) ? cache : null;
  } catch { return null; }
}

async function writeAdmissionCache(cachePath, cache) {
  if (!cachePath) return;
  const destination = path.resolve(cachePath);
  await mkdir(path.dirname(destination), { recursive: true });
  const temporary = `${destination}.${process.pid}.tmp`;
  await writeFile(temporary, `${JSON.stringify(cache)}\n`, { mode: 0o600, flag: 'wx' });
  await chmod(temporary, 0o600);
  await rename(temporary, destination);
}

export async function prepareAdmissionTickets(count, minimumRemainingMs, cachePath, signal) {
  const criteria = { endpoint: OFFICIAL_URL, count, nowMs: Date.now(), minimumRemainingMs };
  let cache = await readAdmissionCache(cachePath, criteria);
  if (cache) return cache;
  const tickets = [];
  for (let index = 0; index < count; index++) {
    if (index > 0) await waitFor(2100, signal);
    const issuedAt = Date.now();
    const ticket = await fetchJson(`${OFFICIAL_URL}/api/admission`, { method: 'POST' }, 7000);
    if (!ticket.token || !Number.isFinite(Number(ticket.expiresIn))) throw new Error('Invalid signed admission ticket');
    tickets.push({ token: ticket.token, expiresAt: issuedAt + Number(ticket.expiresIn) * 1000 });
  }
  cache = { endpoint: OFFICIAL_URL, tickets };
  await writeAdmissionCache(cachePath, cache);
  return cache;
}

function waitFor(ms, signal) {
  return sleep(ms, undefined, { signal });
}

async function fetchJson(url, options = {}, timeoutMs = 5000) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, { ...options, signal: controller.signal, headers: { 'content-type': 'application/json', ...(options.headers ?? {}) } });
    const text = await response.text();
    let json = {};
    try { json = text ? JSON.parse(text) : {}; } catch { /* handled as non-JSON response */ }
    if (!response.ok) throw new Error(`${response.status} ${response.statusText}: ${text.slice(0, 300)}`);
    return json;
  } finally {
    clearTimeout(timeout);
  }
}

async function withTimeout(promise, timeoutMs, onLate = () => {}) {
  let timer;
  const timeout = new Promise((_, reject) => { timer = setTimeout(() => reject(new Error(`timed out after ${timeoutMs} ms`)), timeoutMs); });
  try { return await Promise.race([promise, timeout]); }
  catch (error) {
    promise.then(onLate).catch(() => {});
    throw error;
  } finally { clearTimeout(timer); }
}

function makePeer(room, username, index, counters, currentPhase, onGateFatal = () => {}) {
  const input = room.input({ mode: 'reliable' });
  if (input.tickRate !== 60) throw new Error(`Server input rate was ${input.tickRate ?? 'unadvertised'} Hz; expected 60 Hz`);
  const peer = { room, username, index, input, counters, timer: null, lastAck: 0, lastAckAt: Date.now(), localAckProgress: 0, forcedDrop: false, dropStartedAt: 0, lastDropAt: 0, maxRecoveryMs: 0, recoveredDrops: 0 };
  const markDrop = () => { const now = Date.now(); if (!peer.dropStartedAt) peer.dropStartedAt = now; peer.lastDropAt = now; };
  counters.inputRateHz = input.tickRate;
  room.onError((code, message) => {
    counters.errors++;
    const phase = currentPhase();
    if (counters.errorSamples.length < 50) counters.errorSamples.push({ username, type: 'room_error', phase, code, message: String(message ?? '') });
    if (phase === 'active') {
      if (Number(code) === 1006) markDrop();
      else onGateFatal(`SDK peer ${username} room error ${code}: ${String(message ?? '')}`);
    }
  });
  room.onDrop((code, reason) => {
    markDrop();
    counters.drops++;
    counters.dropsByPhase[currentPhase()]++;
    if (counters.errorSamples.length < 50) counters.errorSamples.push({ username, type: 'drop', phase: currentPhase(), code, reason: String(reason ?? '') });
  });
  room.onReconnect(() => {
    counters.reconnects++;
    counters.reconnectsByPhase[currentPhase()]++;
    if (peer.dropStartedAt) {
      peer.maxRecoveryMs = Math.max(peer.maxRecoveryMs, Date.now() - peer.dropStartedAt);
      peer.recoveredDrops++;
      peer.dropStartedAt = 0;
    }
  });
  room.onLeave((code, reason) => {
    const phase = currentPhase();
    counters.leaves++;
    if (counters.errorSamples.length < 50 && code !== 1000 && code !== 4000) counters.errorSamples.push({ username, type: 'leave', phase, code, reason: String(reason ?? '') });
    if (phase === 'active' && code !== 1000 && code !== 4000) onGateFatal(`SDK peer ${username} left ${code}: ${String(reason ?? '')}`);
  });
  room.onMessage('hit_confirmed', () => { counters.confirmedHits++; });
  room.onMessage('fire', (event) => { if (event?.shooter === username) counters.fireEchoes++; });
  room.onMessage('grenade', (event) => { if (event?.shooter === username) counters.grenadeAccepted++; });
  room.onMessage('explosion', (event) => { if (event?.id !== undefined) counters.explosionIds.add(String(event.id)); });
  room.onMessage('damage', (event) => { if (event?.target === username) counters.damageEvents++; });
  room.onMessage('kill_confirmed', () => { counters.killEvents++; });
  return peer;
}

function getPlayer(room, username) {
  return room.state?.players?.get(username) ?? null;
}

async function main() {
  const options = argumentsFrom(process.argv.slice(2));
  if (options.help) {
    process.stdout.write(`Usage: node scripts/official-load-harness.mjs --url ${OFFICIAL_URL} [--map industrial] [--mode CONQUEST] [--peers 63] [--seconds 180] [--steady] [--admission-cache /results/admission.json] [--observer QA_NATIVE] [--observer-timeout 90] [--output /results/official-load.json]\n`);
    return 0;
  }
  validate(options);

  const abort = new AbortController();
  process.once('SIGINT', () => abort.abort(new Error('interrupted')));
  process.once('SIGTERM', () => abort.abort(new Error('terminated')));
  const startedAt = Date.now();
  const hardStop = setTimeout(() => abort.abort(new Error(`hard wall limit ${MAX_WALL_SECONDS}s reached`)), MAX_WALL_SECONDS * 1000);
  const loopDelay = monitorEventLoopDelay({ resolution: 10 });
  loopDelay.enable();
  const cpuStart = process.cpuUsage();
  const resources = [];
  const ackSamples = [];
  const pingSamples = [];
  const clockRttSamples = [];
  const stateGaps = [];
  const peerCounters = [];
  const peerHandles = [];
  const roomHandles = [];
  const serverPositions = new Map();
  const vehiclePositions = new Map();
  let gate = null;
  let gateUsername = '';
  let nativeObserverJoined = false;
  let nativeObserverVerifiedHuman = false;
  let roomId = '';
  let gateStateLastAt = 0;
  let gateLastStatePatchAt = 0;
  let roomStateCount = 0;
  let roomStateNames = new Set();
  let maxPlayers = 0;
  let maxHumans = 0;
  let maxBots = 0;
  let statePlayersCount = 0;
  const cohortNames = new Set();
  const removalsObserved = new Set();
  let finalReason = 'completed';
  let creationMs = 0;
  const runName = `Load_${Date.now().toString(36)}`;
  const usernamePrefix = `SDK${process.pid.toString(36)}${Date.now().toString(36).slice(-6)}`;
  let sdkClient;
  let sampleTimer;
  let actionTimer;
  let resourceTimer;
  let inputTimer;
  let baseOrigin = '';
  let serverClientsAfterCohort = null;
  let serverBotsAfterCohort = null;
  let remainingHumansAfterCohort = null;
  let cleanupRemovalTimedOut = false;
  let runPhase = 'joining';
  let measurementStartedAt = 0;
  let measurementEndedAt = 0;
  let previousOccupancySample = null;
  let fullOccupancyMs = 0;
  let minHumanPlayersDuringMeasurement = Infinity;
  let minLiveClientsDuringMeasurement = Infinity;
  let occupancyTimer;
  let occupancyPollBusy = false;
  const commonCounters = () => ({ errors: 0, drops: 0, reconnects: 0, dropsByPhase: { joining: 0, active: 0, cleanup: 0 }, reconnectsByPhase: { joining: 0, active: 0, cleanup: 0 }, leaves: 0, confirmedHits: 0, fireEchoes: 0, grenadeAccepted: 0, explosionIds: new Set(), damageEvents: 0, killEvents: 0, errorSamples: [], inputRateHz: null, ackAdvances: 0, maxPendingInputs: 0, ackStalls: 0, hadAckStall: false, movementInputsSent: 0, zeroSendResults: 0, shotsAttempted: 0, grenadeAttempts: 0, seatAttempts: 0, seatEntries: 0, vehicleApproachInputs: 0, vehicleInputs: 0, forcedDrops: 0 });

  const leaveAll = async () => {
    for (const peer of peerHandles) {
      if (peer.timer) clearInterval(peer.timer);
      if (peer.pingTimer) clearInterval(peer.pingTimer);
    }
    if (inputTimer) clearInterval(inputTimer);
    if (sampleTimer) clearInterval(sampleTimer);
    if (actionTimer) clearInterval(actionTimer);
    if (resourceTimer) clearInterval(resourceTimer);
    const cohortPeers = peerHandles.slice(1);
    try { await withTimeout(Promise.allSettled(cohortPeers.map((peer) => peer.room.leave())), 10_000); }
    catch {
      cleanupRemovalTimedOut = true;
      for (const peer of cohortPeers) {
        if (peer.room.leaveCode === undefined) { try { void peer.room.leave(false); } catch { /* already closed */ } }
      }
    }
    const removalDeadline = Date.now() + 7000;
    while (Date.now() < removalDeadline && removalsObserved.size < cohortPeers.length) await new Promise((resolve) => setTimeout(resolve, 100));
    cleanupRemovalTimedOut ||= removalsObserved.size < cohortPeers.length;
    remainingHumansAfterCohort = entries(gate?.state?.players).filter(([, player]) => !player.is_bot).length;
    if (baseOrigin && roomId) {
      try {
        const response = await fetchJson(`${baseOrigin}/api/rooms/${encodeURIComponent(roomId)}`, {}, 3000);
        const info = response.room ?? response;
        serverClientsAfterCohort = Number(info.clients ?? 0);
        serverBotsAfterCohort = Number(info.bots ?? 0);
      } catch { /* the public room listing may expire during cleanup */ }
    }
    const gateRoom = peerHandles[0]?.room;
    if (gateRoom && gateRoom.leaveCode === undefined) {
      try { await withTimeout(gateRoom.leave(), 5000); }
      catch { try { void gateRoom.leave(false); } catch { /* already closed */ } }
    }
    for (const room of [...roomHandles].reverse()) {
      if (room === gateRoom || room.leaveCode !== undefined) continue;
      try { await withTimeout(room.leave(), 2500); }
      catch { try { void room.leave(false); } catch { /* already closed */ } }
    }
  };

  try {
    const origin = options.url.replace(/\/$/, '');
    baseOrigin = origin;
    await fetchJson(`${origin}/health`, {}, 7000);
    // Each simulated human needs its own signed identity. Pace issuance below
    // the production per-caller quota; never disable admission for a load run.
    const requiredCacheHorizonMs = (options.seconds + options.observerTimeout + 60) * 1000;
    const admissionCache = await prepareAdmissionTickets(options.peers, requiredCacheHorizonMs, options.admissionCache, abort.signal);
    const admittedClients = [];
    const admissionTokens = [];
    for (let index = 0; index < options.peers; index++) {
      const ticket = admissionCache.tickets[index];
      const peerClient = new Client(options.url);
      peerClient.auth.token = ticket.token;
      admittedClients.push(peerClient);
      admissionTokens.push(ticket.token);
    }
    const createStart = Date.now();
    if (options.roomId) roomId = options.roomId;
    else {
      const created = await fetchJson(`${origin}/api/rooms`, {
        method: 'POST', headers: { authorization: `Bearer ${admissionTokens[0]}` }, body: JSON.stringify({ map: options.map, mode: options.mode, name: `${runName} official SDK cohort`, timeOfDay: 'noon' }),
      }, 10_000);
      roomId = String(created.room_id ?? '');
    }
    creationMs = Date.now() - createStart;
    if (!roomId) throw new Error('Official room creation returned no room_id');
    process.stdout.write(`PREPARED_ROOM room_id=${roomId} observer=${options.observer} endpoint=${OFFICIAL_URL}\n`);
    process.send?.({ type: 'room', roomId });

    sdkClient = admittedClients[0];
    gateUsername = `${usernamePrefix}Gate`;
    cohortNames.add(gateUsername);
    const gateStats = commonCounters();
    const gateStarted = Date.now();
    const gateRoomPromise = sdkClient.joinOrCreate('battle', { protocol_version: 9, room: roomId, username: gateUsername, map: options.map, mode: options.mode, time_of_day: 'noon' });
    gate = await withTimeout(gateRoomPromise, JOIN_TIMEOUT_MS, (lateRoom) => { void lateRoom.leave(); });
    roomHandles.push(gate);
    gateStats.joinMs = Date.now() - gateStarted;
    const gatePeer = makePeer(gate, gateUsername, 0, gateStats, () => runPhase, (reason) => abort.abort(new Error(reason)));
    peerHandles.push(gatePeer);
    peerCounters.push(gateStats);
    if (gatePeer.input.tickRate !== 60) throw new Error('Gate input did not negotiate the server 60 Hz tick rate');

    gate.onStateChange((state) => {
      const now = Date.now();
      if (gateStateLastAt) stateGaps.push(now - gateStateLastAt);
      gateStateLastAt = now;
      gateLastStatePatchAt = now;
      roomStateCount++;
      const players = entries(state.players);
      const names = new Set(players.map(([name]) => String(name)));
      statePlayersCount = players.length;
      const bots = players.filter(([, player]) => Boolean(player.is_bot)).length;
      maxPlayers = Math.max(maxPlayers, players.length);
      maxBots = Math.max(maxBots, bots);
      maxHumans = Math.max(maxHumans, players.length - bots);
      for (const name of roomStateNames) if (!names.has(name) && cohortNames.has(name)) removalsObserved.add(name);
      roomStateNames = names;
      for (const [name, player] of players) {
        if (!cohortNames.has(String(name)) || player.is_bot) continue;
        const position = [Number(player.x), Number(player.y), Number(player.z)];
        const previous = serverPositions.get(String(name));
        if (previous && position.every(Number.isFinite)) {
          const distance = Math.hypot(position[0] - previous.last[0], position[1] - previous.last[1], position[2] - previous.last[2]);
          if (distance > 0.001) { previous.path += Math.min(distance, 5); previous.updates++; }
          previous.last = position;
        } else if (position.every(Number.isFinite)) serverPositions.set(String(name), { last: position, path: 0, updates: 0 });
      }
      for (const [id, vehicle] of entries(state.vehicles)) {
        const position = vehiclePosition(vehicle);
        if (!position) continue;
        const previous = vehiclePositions.get(String(id));
        if (previous) {
          const distance = Math.hypot(position[0] - previous.last[0], position[1] - previous.last[1], position[2] - previous.last[2]);
          if (distance > 0.001) { previous.path += Math.min(distance, 5); previous.updates++; }
          previous.last = position;
        } else vehiclePositions.set(String(id), { last: position, path: 0, updates: 0 });
      }
    });

    const observerDeadline = Date.now() + options.observerTimeout * 1000;
    while (Date.now() < observerDeadline && !abort.signal.aborted) {
      if (getPlayer(gate, options.observer)) break;
      await waitFor(250, abort.signal).catch(() => {});
    }
    if (!getPlayer(gate, options.observer)) throw new Error(`Native observer ${options.observer} did not join room ${roomId} within ${options.observerTimeout}s`);
    nativeObserverJoined = true;
    nativeObserverVerifiedHuman = !Boolean(getPlayer(gate, options.observer)?.is_bot);
    if (!nativeObserverVerifiedHuman) throw new Error(`Observer ${options.observer} was not a human player`);

    const batchSize = 8;
    for (let next = 1; next < options.peers; next += batchSize) {
      const batch = [];
      for (let index = next; index < Math.min(options.peers, next + batchSize); index++) {
        const username = `${usernamePrefix}${String(index).padStart(2, '0')}`;
        cohortNames.add(username);
        const stats = commonCounters();
        const joiningAt = Date.now();
        const pending = admittedClients[index].joinOrCreate('battle', { protocol_version: 9, room: roomId, username, map: options.map, mode: options.mode, time_of_day: 'noon' });
        batch.push(withTimeout(pending, JOIN_TIMEOUT_MS, (lateRoom) => { void lateRoom.leave(); }).then((room) => ({ room, username, index, stats, joinMs: Date.now() - joiningAt }), (error) => ({ error, username, index, stats })));
      }
      const joined = await Promise.all(batch);
      for (const result of joined) {
        if (result.error) {
          result.stats.errors++;
          result.stats.errorSamples.push({ username: result.username, type: 'join_failure', message: String(result.error.message ?? result.error) });
          peerCounters.push(result.stats);
          continue;
        }
        result.stats.joinMs = result.joinMs;
        roomHandles.push(result.room);
        const peer = makePeer(result.room, result.username, result.index, result.stats, () => runPhase, (reason) => abort.abort(new Error(reason)));
        peerHandles.push(peer);
        peerCounters.push(result.stats);
      }
      process.stdout.write(`JOIN_PROGRESS peers=${peerHandles.length}/${options.peers} humans_expected=${options.peers + 1}\n`);
      if (abort.signal.aborted) throw abort.signal.reason;
    }

    const stateDeadline = Date.now() + (options.coordinated ? 90_000 : 15_000);
    while (Date.now() < stateDeadline && !abort.signal.aborted) {
      if (entries(gate.state.players).filter(([, player]) => !player.is_bot).length >= options.totalPeers + 1) break;
      await waitFor(100, abort.signal).catch(() => {});
    }
    const actualHumanNames = entries(gate.state.players).filter(([, player]) => !player.is_bot).map(([name]) => String(name));
    const observerCount = actualHumanNames.includes(options.observer) ? 1 : 0;
    const sdkNames = new Set(peerHandles.map((peer) => peer.username));
    const targetSdkCount = options.peers;
    const missingSdk = [...Array(targetSdkCount).keys()].map((index) => index === 0 ? gateUsername : `${usernamePrefix}${String(index).padStart(2, '0')}`).filter((name) => !sdkNames.has(name));
    if (missingSdk.length) throw new Error(`Only ${sdkNames.size}/${targetSdkCount} SDK peers joined: ${missingSdk.slice(0, 5).join(', ')}`);
    if (actualHumanNames.length !== options.totalPeers + observerCount) {
      throw new Error(`Expected ${options.totalPeers} total SDK peers plus one native observer; server state has ${actualHumanNames.length} human actors`);
    }

    if (options.coordinated) {
      const go = new Promise((resolve, reject) => {
        const receive = (message) => {
          if (message?.type !== 'start' || !Number.isFinite(message.at)) return;
          cleanup(); resolve(message.at);
        };
        const cancel = () => { cleanup(); reject(abort.signal.reason); };
        const cleanup = () => { process.off('message', receive); abort.signal.removeEventListener('abort', cancel); };
        process.on('message', receive);
        abort.signal.addEventListener('abort', cancel, { once: true });
      });
      process.send({ type: 'ready', roomId });
      const startAt = await go;
      await waitFor(Math.max(0, startAt - Date.now()), abort.signal);
    }
    let previousResourceAt = Date.now();
    let previousResourceCpu = process.cpuUsage();
    inputTimer = setInterval(() => {
      const now = Date.now();
      const elapsed = (now - loadStartedAt) / 1000;
      for (const peer of peerHandles) {
        const { input, room, username, index, counters } = peer;
        if (room.leaveCode !== undefined) continue;
        const player = getPlayer(room, username);
        const phase = now / 1000 + index * 0.013;
        let moveX = Math.sin(phase * 0.7) * 0.35;
        let moveZ = elapsed % 12 < 6 ? -0.5 : 0.45;
        let yaw = ((phase * 0.09) % (Math.PI * 2)) - Math.PI;
        if (player && index < 20 && !player.driving_vehicle && !peer.vehicleExitSent) {
          const nearest = entries(room.state.vehicles)
            .filter(([, vehicle]) => Number(vehicle.health) > 0 && !String(vehicle.driver ?? ''))
            .map(([id, vehicle]) => {
              const position = vehiclePosition(vehicle);
              return { id: String(id), position, distance: position ? Math.hypot(Number(player.x) - position[0], Number(player.y) - position[1], Number(player.z) - position[2]) : Infinity };
            }).sort((a, b) => a.distance - b.distance)[0];
          if (nearest?.position && nearest.distance > 2.5 && nearest.distance < 60) {
            const dx = nearest.position[0] - Number(player.x);
            const dz = nearest.position[2] - Number(player.z);
            yaw = Math.atan2(dx, dz);
            moveX = 0;
            moveZ = -0.65;
            counters.vehicleApproachInputs++;
          }
        }
        input.data.move_x = moveX;
        input.data.move_z = moveZ;
        input.data.yaw = yaw;
        input.data.pitch = Math.sin(phase * 0.11) * 0.06;
        input.data.jump = elapsed % 9 > 8.7 ? 1 : 0;
        input.data.sprint = 1;
        input.data.crouch = 0;
        stageVehicleControls(input.data, player, phase);
        const sent = input.send();
        if (sent > 0) counters.movementInputsSent++;
        else counters.zeroSendResults++;
        const ack = input.lastProcessed;
        if (ack > peer.lastAck) { counters.ackAdvances += ack - peer.lastAck; peer.lastAck = ack; peer.lastAckAt = now; }
        const pending = Math.max(0, input.sentCount - ack);
        counters.maxPendingInputs = Math.max(counters.maxPendingInputs, pending);
        if (pending > 5 && now - peer.lastAckAt > 1500) { counters.ackStalls++; counters.hadAckStall = true; }

        if (!player) continue;
        if (!peer.fired && elapsed >= 5 + index * 0.045) {
          peer.fired = true;
          const origin = [Number(player.x), Number(player.y) + 1.2, Number(player.z)];
          const candidates = entries(room.state.players)
            .filter(([name, target]) => name !== username && !target.is_bot && !target.is_dead)
            .map(([, target]) => {
              const targetPos = [Number(target.x), Number(target.y) + 0.9, Number(target.z)];
              const dx = targetPos[0] - origin[0], dy = targetPos[1] - origin[1], dz = targetPos[2] - origin[2];
              const distance = Math.hypot(dx, dy, dz);
              return { dx, dy, dz, distance };
            }).filter((target) => target.distance > 0.2).sort((a, b) => a.distance - b.distance);
          const target = candidates[0];
          const yaw = target ? Math.atan2(-target.dx, -target.dz) : Number(player.yaw);
          const pitch = target ? -Math.asin(Math.max(-1, Math.min(1, target.dy / target.distance))) : Number(player.pitch);
          room.send('fire', { origin, yaw, pitch, shot_id: (peer.shotId = (peer.shotId ?? 0) + 1) });
          counters.shotsAttempted++;
        }
        if (index < 8 && !peer.grenadeThrown && elapsed >= 8 + index * 0.45 && !player.is_dead && !String(player.driving_vehicle ?? '') && Number(player.grenades ?? 0) > 0) {
          peer.grenadeThrown = true;
          const yaw = Number(player.yaw);
          room.send('grenade', { pos: [Number(player.x), Number(player.y) + 1.35, Number(player.z)], vel: [-Math.sin(yaw) * 5.5, 3.0, -Math.cos(yaw) * 5.5] });
          counters.grenadeAttempts++;
        }
        const driving = String(player.driving_vehicle ?? '');
        if (driving) {
          if (!peer.vehicleStartedAt) { peer.vehicleStartedAt = now; counters.seatEntries++; }
          if (!peer.lastVehicleInputAt || now - peer.lastVehicleInputAt >= 100) {
            peer.lastVehicleInputAt = now;
            counters.vehicleInputs++;
          }
          if (now - peer.vehicleStartedAt > 4500 && !peer.vehicleExitSent) {
            room.send('vehicle_seat', { id: driving, enter: false });
            peer.vehicleExitSent = true;
          }
        } else if (index < 20 && !peer.vehicleExitSent && now - (peer.lastVehicleTryAt ?? 0) > 2500) {
          const vehicles = entries(room.state.vehicles).filter(([, v]) => Number(v.health) > 0 && !String(v.driver ?? ''));
          const nearest = vehicles.map(([id, vehicle]) => {
            const pos = vehiclePosition(vehicle);
            return { id: String(id), distance: pos ? Math.hypot(Number(player.x) - pos[0], Number(player.y) - pos[1], Number(player.z) - pos[2]) : Infinity };
          }).sort((a, b) => a.distance - b.distance)[0];
          if (nearest && nearest.distance <= 4.8) {
            room.send('vehicle_seat', { id: nearest.id, enter: true });
            peer.lastVehicleTryAt = now;
            counters.seatAttempts++;
          }
        }
      }
    }, 1000 / 60);
    peerHandles.forEach((peer) => { peer.timer = inputTimer; });

    // The SDK cohort joins the public room only after the native observer has
    // appeared. A single intentional SDK transport drop checks reconnection.
    const loadStartedAt = Date.now();
    runPhase = 'active';
    let reconnectInjected = false;
    actionTimer = setInterval(() => {
      const elapsed = (Date.now() - loadStartedAt) / 1000;
      if (!options.steady && !reconnectInjected && elapsed >= Math.min(30, options.seconds * 0.25)) {
        const peer = peerHandles.find((candidate) => candidate.index === Math.min(1, peerHandles.length - 1));
        if (peer && !peer.forcedDrop) {
          peer.forcedDrop = true;
          peer.counters.forcedDrops++;
          void peer.room.leave(false);
          reconnectInjected = true;
        }
      }
      if (elapsed >= options.seconds) abort.abort(new Error('duration complete'));
    }, 250);

    let resourcePollBusy = false;
    resourceTimer = setInterval(async () => {
      if (resourcePollBusy) return;
      resourcePollBusy = true;
      const cpu = process.cpuUsage();
      const memory = process.memoryUsage();
      const pending = peerHandles.map((peer) => Math.max(0, peer.input.sentCount - peer.input.lastProcessed));
      const acks = peerHandles.reduce((sum, peer) => sum + peer.input.lastProcessed, 0);
      for (const peer of peerHandles) {
        const rtt = Number(peer.room.clock?.rtt?.() ?? 0);
        const smoothedRtt = Number(peer.room.clock?.smoothedRtt?.() ?? 0);
        if (Number.isFinite(rtt)) clockRttSamples.push({ at: Date.now(), username: peer.username, rttMs: rtt, smoothedRttMs: smoothedRtt });
      }
      ackSamples.push({ at: Date.now(), totalAckedInputs: acks, pendingMean: pending.length ? pending.reduce((a, b) => a + b, 0) / pending.length : 0, pendingMax: Math.max(0, ...pending) });
      const resourceAt = Date.now();
      const cpuPercent = ((cpu.user - previousResourceCpu.user) + (cpu.system - previousResourceCpu.system)) / Math.max(1, resourceAt - previousResourceAt) / 10;
      previousResourceAt = resourceAt; previousResourceCpu = cpu;
      resources.push({ cpuOneCorePercent: Number(cpuPercent.toFixed(2)), at: resourceAt, rssBytes: memory.rss, heapUsedBytes: memory.heapUsed, cpuUserMs: cpu.user / 1000, cpuSystemMs: cpu.system / 1000, eventLoopP95Ms: Number(loopDelay.percentile(95) / 1e6), eventLoopExcessP95Ms: Math.max(0, Number(loopDelay.percentile(95) / 1e6) - 10), eventLoopMaxMs: Number(loopDelay.max / 1e6) });
      loopDelay.reset();
      try {
        const response = await fetchJson(`${origin}/api/rooms/${encodeURIComponent(roomId)}`, {}, 3000);
        const info = response.room ?? response;
        resources[resources.length - 1].serverRoomClients = Number(info.clients ?? 0);
        resources[resources.length - 1].serverRoomBots = Number(info.bots ?? 0);
      } catch (error) {
        resources[resources.length - 1].roomPollError = String(error.message ?? error);
      } finally { resourcePollBusy = false; }
    }, 5000);

    for (const peer of peerHandles) {
      const pingTimer = setInterval(() => {
        if (peer.room.connection?.isOpen) peer.room.ping((ms) => pingSamples.push({ at: Date.now(), username: peer.username, ms }));
      }, 5000);
      peer.pingTimer = pingTimer;
    }

    const startedLoad = Date.now();
    measurementStartedAt = startedLoad;
    const sampleOccupancy = async () => {
      const now = Date.now();
      if (runPhase !== 'active') return;
      if (!gate?.connection?.isOpen && !options.steady) { abort.abort(new Error('gate connection closed during active measurement')); return; }
      if (options.steady && (!gateLastStatePatchAt || now - gateLastStatePatchAt > 5000)) { abort.abort(new Error('gate state patches stale during active measurement')); return; }
      if (options.steady) {
        for (const peer of peerHandles) {
          if (!peer.room.connection?.isOpen && !peer.dropStartedAt) { peer.dropStartedAt = now; peer.lastDropAt = now; }
          if (peer.room.leaveCode !== undefined && peer.room.leaveCode !== 1000 && peer.room.leaveCode !== 4000) { abort.abort(new Error(`SDK peer ${peer.username} left during active measurement (${peer.room.leaveCode})`)); return; }
          if (peerDropExpired(peer.dropStartedAt, now)) { abort.abort(new Error(`SDK peer ${peer.username} reconnect exceeded 2000 ms`)); return; }
        }
      }
      if (occupancyPollBusy) return;
      occupancyPollBusy = true;
      try {
        // The public matchmaker directory reads live framework client counts;
        // schema players can remain cached locally after a transport drop.
        const info = await fetchJson(`${origin}/api/rooms/${encodeURIComponent(roomId)}`, {}, 3000);
        if (runPhase !== 'active') return;
        const clients = Number(info.clients ?? -1);
        const humans = entries(gate?.state?.players).filter(([, player]) => !player.is_bot).length;
        const observer = getPlayer(gate, options.observer);
        const observerPresent = Boolean(observer && !observer.is_bot);
        minLiveClientsDuringMeasurement = Math.min(minLiveClientsDuringMeasurement, Math.max(0, clients));
        const freshState = gateLastStatePatchAt > 0 && Date.now() - gateLastStatePatchAt <= 5000;
        const previousAt = previousOccupancySample?.at ?? Date.now();
        const noDropSincePreviousSample = peerHandles.every((peer) => !peer.lastDropAt || peer.lastDropAt <= previousAt);
        const recovering = peerHandles.some((peer) => peer.dropStartedAt > 0);
        const cohortOpen = peerHandles.every((peer) => peer.room.connection?.isOpen && peer.room.leaveCode === undefined) && !recovering && noDropSincePreviousSample;
        const full = evaluateSteadySample({ gateOpen: gate.connection?.isOpen, stateFresh: freshState, liveClients: clients, humanPlayers: humans, observerPresent, cohortOpen });
        minHumanPlayersDuringMeasurement = Math.min(minHumanPlayersDuringMeasurement, Math.min(humans, Math.max(0, clients)));
        if (previousOccupancySample && previousOccupancySample.full && full) fullOccupancyMs += Math.min(Date.now() - previousOccupancySample.at, 1500);
        previousOccupancySample = { at: Date.now(), full };
      } catch {
        previousOccupancySample = { at: now, full: false };
      } finally { occupancyPollBusy = false; }
    };
    sampleOccupancy();
    occupancyTimer = setInterval(sampleOccupancy, 1000);
    const deadline = startedLoad + options.seconds * 1000;
    while (Date.now() < deadline && !abort.signal.aborted) await waitFor(250, abort.signal).catch(() => {});
    measurementEndedAt = Date.now();
    if (occupancyTimer) clearInterval(occupancyTimer);
    finalReason = abort.signal.reason?.message === 'duration complete' ? 'duration_complete' : abort.signal.reason?.message ?? 'completed';
  } catch (error) {
    finalReason = abort.signal.aborted ? String(abort.signal.reason?.message ?? 'interrupted') : `failed: ${error.message ?? error}`;
    if (!abort.signal.aborted) process.stderr.write(`LOAD_HARNESS_ERROR ${finalReason}\n`);
  } finally {
    runPhase = 'cleanup';
    if (!measurementEndedAt && measurementStartedAt) measurementEndedAt = Date.now();
    if (occupancyTimer) clearInterval(occupancyTimer);
    await leaveAll();
    clearTimeout(hardStop);
    loopDelay.disable();
  }

  const endCpu = process.cpuUsage(cpuStart);
  const joinedPeers = peerHandles.length;
  const negotiatedExtensions = [...new Set(peerHandles.map((peer) => peer.room.connection?.transport?.ws?.extensions).filter((value) => typeof value === 'string'))];
  const recoveredDropCount = peerHandles.reduce((sum, peer) => sum + peer.recoveredDrops, 0);
  const maxRecoveryMs = Math.max(0, ...peerHandles.map((peer) => peer.maxRecoveryMs));
  const allExplosionIds = new Set();
  const counters = peerCounters.reduce((sum, peer) => {
    for (const key of ['errors', 'drops', 'reconnects', 'leaves', 'confirmedHits', 'fireEchoes', 'grenadeAccepted', 'damageEvents', 'killEvents', 'ackAdvances', 'ackStalls', 'movementInputsSent', 'zeroSendResults', 'shotsAttempted', 'grenadeAttempts', 'seatAttempts', 'seatEntries', 'vehicleApproachInputs', 'vehicleInputs', 'forcedDrops']) sum[key] += Number(peer[key] ?? 0);
    sum.maxPendingInputs = Math.max(sum.maxPendingInputs, Number(peer.maxPendingInputs ?? 0));
    for (const phase of ['joining', 'active', 'cleanup']) {
      sum.dropsByPhase[phase] += peer.dropsByPhase[phase];
      sum.reconnectsByPhase[phase] += peer.reconnectsByPhase[phase];
    }
    for (const id of peer.explosionIds) allExplosionIds.add(id);
    sum.errorSamples.push(...peer.errorSamples);
    return sum;
    }, { errors: 0, drops: 0, reconnects: 0, dropsByPhase: { joining: 0, active: 0, cleanup: 0 }, reconnectsByPhase: { joining: 0, active: 0, cleanup: 0 }, leaves: 0, confirmedHits: 0, fireEchoes: 0, grenadeAccepted: 0, damageEvents: 0, killEvents: 0, ackAdvances: 0, maxPendingInputs: 0, ackStalls: 0, movementInputsSent: 0, zeroSendResults: 0, shotsAttempted: 0, grenadeAttempts: 0, seatAttempts: 0, seatEntries: 0, vehicleApproachInputs: 0, vehicleInputs: 0, forcedDrops: 0, errorSamples: [] });
  counters.errorSamples.sort((a, b) => Number(b.phase === 'active') - Number(a.phase === 'active'));
  counters.errorSamples = counters.errorSamples.slice(0, 50);
  const report = {
    test: 'official-colyseus-sdk-buffered-input-load',
    endpoint: OFFICIAL_URL,
    roomId,
    map: options.map, mode: options.mode,
    result: finalReason,
    runSeconds: Number(((Date.now() - startedAt) / 1000).toFixed(1)),
    requested: { sdkPeers: options.peers, nativeObserverUsername: options.observer, humansTotalTarget: options.totalPeers + 1, coordinated: options.coordinated, durationSeconds: options.seconds, steady: options.steady, helperEndpoint: 'wss://war.vaidik.blog/colyseus', publicRouteTest: true, admissionCacheUsed: Boolean(options.admissionCache), maxWallSeconds: MAX_WALL_SECONDS, sdk: SDK_VERSION, sdkWebSocketImplementation: NodeWebSocket.name, roomCreationMs: creationMs, sdkJoinLatencyP95Ms: percentile(peerCounters.map((peer) => peer.joinMs).filter(Number.isFinite), 0.95) },
    helperTransport: { label: 'official-public-websocket', implementation: NodeWebSocket.name, negotiatedExtensions },
    observed: { sdkPeersJoined: joinedPeers, nativeObserverSeen: nativeObserverJoined, nativeObserverVerifiedHuman, humanActorsAtPeak: maxHumans, fullOccupancySeconds: Number((fullOccupancyMs / 1000).toFixed(1)), minHumanPlayersDuringMeasurement: Number.isFinite(minHumanPlayersDuringMeasurement) ? minHumanPlayersDuringMeasurement : 0, minLiveClientsDuringMeasurement: Number.isFinite(minLiveClientsDuringMeasurement) ? minLiveClientsDuringMeasurement : 0, measurementStartedAt, measurementEndedAt, measurementSeconds: measurementStartedAt ? Number(((measurementEndedAt - measurementStartedAt) / 1000).toFixed(1)) : 0, maxPlayersIncludingBots: maxPlayers, maxBotsObserved: maxBots, serverStatePatches: roomStateCount, statePlayersAtLastSample: statePlayersCount, maxClients: 64 },
    input: { tickRateHz: peerCounters.find((p) => p.inputRateHz)?.inputRateHz ?? null, sent: counters.movementInputsSent, ackAdvances: counters.ackAdvances, zeroSendResults: counters.zeroSendResults, maxPendingInputFrames: counters.maxPendingInputs, ackStallIntervals: counters.ackStalls, peersWithAckStalls: peerCounters.filter((peer) => peer.hadAckStall).length },
    gameplay: { shotsAttempted: counters.shotsAttempted, fireEchoes: counters.fireEchoes, confirmedHits: counters.confirmedHits, grenadeAttempts: counters.grenadeAttempts, grenadesAccepted: counters.grenadeAccepted, uniqueExplosionsSeen: allExplosionIds.size, seatAttempts: counters.seatAttempts, vehicleApproachInputs: counters.vehicleApproachInputs, seatEntries: counters.seatEntries, vehicleInputs: counters.vehicleInputs, damageEvents: counters.damageEvents, killEvents: counters.killEvents },
    authoritativeMovement: { sampledSdkPlayers: serverPositions.size, playersMovedOverHalfMeter: [...serverPositions.values()].filter((v) => v.path >= 0.5).length, totalPathMeters: Number([...serverPositions.values()].reduce((sum, v) => sum + v.path, 0).toFixed(2)), playersWithPositionUpdates: [...serverPositions.values()].filter((v) => v.updates > 0).length },
    vehicleMovement: { vehiclesSampled: vehiclePositions.size, vehiclesMoved: [...vehiclePositions.values()].filter((v) => v.path >= 0.25).length, totalVehiclePathMeters: Number([...vehiclePositions.values()].reduce((sum, v) => sum + v.path, 0).toFixed(2)) },
    lifecycle: { controlledTransportDrops: counters.forcedDrops, drops: counters.drops, dropsByPhase: counters.dropsByPhase, reconnects: counters.reconnects, reconnectsByPhase: counters.reconnectsByPhase, recoveredDrops: recoveredDropCount, maxRecoveryMs, clientLeaves: counters.leaves, sdkCohortRemovalsExpected: Math.max(0, joinedPeers - 1), sdkCohortRemovalsObserved: removalsObserved.size, remainingHumanActorsAfterSdkLeaves: remainingHumansAfterCohort, serverClientsAfterSdkLeaves: serverClientsAfterCohort, serverBotsAfterSdkLeaves: serverBotsAfterCohort, cleanupRemovalTimedOut, errors: counters.errors },
    network: { sdkPingRttP50Ms: percentile(pingSamples.map((sample) => sample.ms), 0.5), sdkPingRttP95Ms: percentile(pingSamples.map((sample) => sample.ms), 0.95), sdkClockRttP50Ms: percentile(clockRttSamples.map((sample) => sample.rttMs), 0.5), sdkClockSmoothedRttP95Ms: percentile(clockRttSamples.map((sample) => sample.smoothedRttMs), 0.95), inputAckTotalSamples: ackSamples.length, ackPendingMeanP95: percentile(ackSamples.map((sample) => sample.pendingMean), 0.95), ackPendingFrameMax: Math.max(0, ...ackSamples.map((sample) => sample.pendingMax)), roomStateGapP50Ms: percentile(stateGaps, 0.5), roomStateGapP95Ms: percentile(stateGaps, 0.95), roomStateGapMaxMs: Math.max(0, ...stateGaps) },
    helperResources: { eventLoopResolutionMs: 10, eventLoopExcessP95MsMax: Math.max(0, ...resources.map(s => s.eventLoopExcessP95Ms)), cpuOneCorePercentMax: Math.max(0, ...resources.map((s) => s.cpuOneCorePercent)), rssP95Bytes: percentile(resources.map((sample) => sample.rssBytes), 0.95), heapP95Bytes: percentile(resources.map((sample) => sample.heapUsedBytes), 0.95), processCpuUserMs: Number((endCpu.user / 1000).toFixed(1)), processCpuSystemMs: Number((endCpu.system / 1000).toFixed(1)), eventLoopP95MsMax: Math.max(0, ...resources.map((sample) => sample.eventLoopP95Ms)), samples: resources },
    serverContainerResources: 'Collect server telemetry separately; this report measures only its SDK helper process.',
    errorSamples: counters.errorSamples,
    limits: { officialUrlGuard: true, directTransformMutation: false, localCapacityRun: false, loadPeersIncludeBots: false, helperPid: process.pid, helperPlacement: 'Record the runner machine separately; no container resource limit is assumed' },
    evidenceCoverage: { nativeObserverGate: nativeObserverJoined && nativeObserverVerifiedHuman, peak64HumanActors: maxHumans >= 64, sustained64HumanOccupancy: !options.steady || fullOccupancyMs >= Math.min(60, Math.max(0, options.seconds - 2)) * 1000, authoritativeMovement: [...serverPositions.values()].some((v) => v.path >= 0.5), fireEcho: counters.fireEchoes > 0, confirmedHit: counters.confirmedHits > 0, acceptedGrenade: counters.grenadeAccepted > 0, explosion: allExplosionIds.size > 0, vehicleSeatEntry: counters.seatEntries > 0, vehicleInputsSent: counters.vehicleInputs > 0, vehicleMotion: [...vehiclePositions.values()].some((v) => v.path >= 0.25), sdkCleanupObserved: removalsObserved.size >= Math.max(0, joinedPeers - 1) && !cleanupRemovalTimedOut },
  };
  report.missingEvidence = Object.entries(report.evidenceCoverage).filter(([, observed]) => !observed).map(([name]) => name);
  report.coverageStatus = report.missingEvidence.length === 0 ? 'complete' : 'incomplete';

  try {
    const outputPath = path.resolve(options.output);
    await mkdir(path.dirname(outputPath), { recursive: true });
    await writeFile(outputPath, `${JSON.stringify(report, null, 2)}\n`);
    process.stdout.write(`LOAD_REPORT ${outputPath}\n${JSON.stringify(report, null, 2)}\n`);
  } catch (error) {
    process.stderr.write(`LOAD_REPORT_WRITE_FAILED ${error.message ?? error}\n`);
  }
  return finalReason === 'duration_complete' ? 0 : 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().then((code) => { process.exitCode = code; process.disconnect?.(); }).catch((error) => {
    process.stderr.write(`LOAD_HARNESS_FATAL ${error.message ?? error}\n`);
    process.exitCode = 2; process.disconnect?.();
  });
}
