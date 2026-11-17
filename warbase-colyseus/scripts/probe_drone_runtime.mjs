import assert from 'node:assert/strict';
import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { Client } from '@colyseus/sdk';

const DEFAULT_ORIGIN = 'https://war.vaidik.blog/colyseus';
const PROTOCOL_VERSION = 16;
const PLAYABLE_MAPS = ['football', 'industrial', 'village', 'arena', 'dust2', 'nuketown', 'canyon', 'military_base', 'ghost_city', 'cosmodrome', 'dam', 'skyline'];
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function argumentsFrom(argv) {
  const options = {
    origin: process.env.WARBASE_ORIGIN || process.env.COLYSEUS_URL || DEFAULT_ORIGIN,
    map: 'industrial', allMaps: false, checkPacks: false, isolateCombat: false, output: '', help: false,
  };
  for (let index = 0; index < argv.length; index++) {
    const value = argv[index];
    if (value === '--help' || value === '-h') options.help = true;
    else if (value === '--all-maps') options.allMaps = true;
    else if (value === '--check-packs') options.checkPacks = true;
    else if (value === '--isolate-combat') options.isolateCombat = true;
    else if (value === '--origin' || value === '--url') options.origin = argv[++index] ?? '';
    else if (value.startsWith('--origin=')) options.origin = value.slice('--origin='.length);
    else if (value.startsWith('--url=')) options.origin = value.slice('--url='.length);
    else if (value === '--map') options.map = argv[++index] ?? '';
    else if (value.startsWith('--map=')) options.map = value.slice('--map='.length);
    else if (value === '--out') options.output = argv[++index] ?? '';
    else if (value.startsWith('--out=')) options.output = value.slice('--out='.length);
    else throw new Error(`Unknown argument: ${value}`);
  }
  return options;
}

function validateOptions(options) {
  let parsed;
  try { parsed = new URL(options.origin); } catch { throw new Error(`Invalid origin URL: ${options.origin}`); }
  const loopback = ['localhost', '127.0.0.1', '[::1]'].includes(parsed.hostname);
  if (parsed.protocol !== 'https:' && !(parsed.protocol === 'http:' && loopback)) {
    throw new Error('Origin must use HTTPS, or HTTP on loopback for local staging.');
  }
  if (options.allMaps && options.map !== 'industrial') throw new Error('Use either --map or --all-maps, not both.');
  if (!options.allMaps && !PLAYABLE_MAPS.includes(options.map)) throw new Error(`Unsupported map: ${options.map}`);
  options.origin = options.origin.replace(/\/$/, '');
  if (options.output) options.output = resolve(options.output);
}

async function until(check, label, timeoutMs = 12_000) {
  const deadline = Date.now() + timeoutMs;
  while (!check() && Date.now() < deadline) await sleep(25);
  assert.ok(check(), `${label} timed out after ${timeoutMs}ms`);
}

async function fetchJson(url, init = {}, timeoutMs = 8_000) {
  const response = await fetch(url, { ...init, signal: AbortSignal.timeout(timeoutMs), redirect: 'error' });
  const body = await response.json().catch(() => ({}));
  assert.ok(response.ok, `${url} returned ${response.status}: ${JSON.stringify(body)}`);
  return body;
}

async function admissionTicket(origin) {
  const ticket = await fetchJson(`${origin}/api/admission`, { method: 'POST' });
  assert.ok(typeof ticket.token === 'string' && ticket.token.length > 0, 'admission response did not contain a signed ticket');
  return ticket.token;
}

function observeDrone(player, label) {
  assert.ok(player, `${label}: player state is missing`);
  for (const field of ['x', 'y', 'z', 'vx', 'vy', 'vz']) {
    assert.ok(Number.isFinite(Number(player[field])), `${label}: non-finite drone center/velocity ${field}=${player[field]}`);
  }
  assert.equal(player.is_dead, false, `${label}: drone died during the movement probe`);
  return { x: Number(player.x), y: Number(player.y), z: Number(player.z), vx: Number(player.vx), vy: Number(player.vy), vz: Number(player.vz) };
}

function assignInput(input, command) {
  Object.assign(input.data, {
    move_x: 0, move_y: 0, move_z: 0, yaw: 0, pitch: 0, jump: 0, sprint: 0, crouch: 0,
    vehicle_throttle: 0, vehicle_steer: 0, vehicle_brake: 0, vehicle_gear: 1,
    vehicle_index: -1, vehicle_generation: 0,
    ...command,
  });
}

async function sendPhase(input, player, command, frames, label, note) {
  let lastSequence = 0;
  for (let frame = 0; frame < frames; frame++) {
    assignInput(input, command);
    lastSequence = input.send();
    note(observeDrone(player, `${label} frame ${frame}`));
    await sleep(16);
  }
  await until(() => Number(player.ack_input_sequence) >= lastSequence, `${label} input acknowledgement`);
  const pose = observeDrone(player, `${label} final state`);
  note(pose);
  return { sequence: lastSequence, pose };
}

async function boundedJoin(client, options) {
  const joining = client.joinOrCreate('battle', options);
  let timedOut = false;
  const watched = joining.then((room) => {
    if (timedOut) void room.leave().catch(() => {});
    return room;
  });
  let timer;
  try {
    return await Promise.race([
      watched,
      new Promise((_, reject) => { timer = setTimeout(() => { timedOut = true; reject(new Error(`SDK join timed out for ${options.room}`)); }, 10_000); }),
    ]);
  } finally { clearTimeout(timer); }
}

async function leaveRoom(room) {
  if (!room) return;
  let timer;
  try {
    await Promise.race([room.leave().catch(() => {}), new Promise((resolve) => { timer = setTimeout(resolve, 3_000); })]);
  } finally { clearTimeout(timer); }
}

async function verifyOldProtocol(origin, report) {
  const ticket = await admissionTicket(origin);
  const client = new Client(origin);
  client.auth.token = ticket;
  const username = `OldProbe_${Date.now().toString(36)}`;
  let oldRoom;
  let rejection;
  try {
    oldRoom = await boundedJoin(client, { protocol_version: PROTOCOL_VERSION - 1, room: 'industrial-public', username });
  } catch (error) { rejection = error; }
  if (oldRoom) {
    await leaveRoom(oldRoom);
    throw new Error('An older protocol unexpectedly joined a protocol 16 room.');
  }
  assert.match(String(rejection?.message ?? rejection), /Game update required/i, 'previous protocol must fail specifically with the update-required response');
  report.previousProtocolRejected = true;
}

async function verifyPublicDirectory(origin) {
  const mapResponse = await fetchJson(`${origin}/api/maps`);
  const mapIds = Array.isArray(mapResponse.maps) ? mapResponse.maps.map((entry) => entry?.id) : [];
  assert.deepEqual([...mapIds].sort(), [...PLAYABLE_MAPS].sort(), 'map API must expose all eleven playable maps');
  const directory = await fetchJson(`${origin}/api/rooms`);
  assert.ok(Array.isArray(directory.rooms), 'room directory has no rooms array');
  const publicRooms = new Map(directory.rooms.filter((room) => String(room.id).endsWith('-public')).map((room) => [room.id, room]));
  for (const map of PLAYABLE_MAPS) {
    const id = `${map}-public`, room = publicRooms.get(id);
    assert.ok(room, `room directory is missing ${id}`);
    assert.equal(room.map, map, `${id} has the wrong map`);
    assert.equal(room.mode, 'CONQUEST', `${id} must remain Conquest`);
  }
  return { maps: mapIds.length, publicConquestRooms: PLAYABLE_MAPS.length, onlinePlayers: Number(directory.online_players ?? 0) };
}

async function verifyOptionalPacks(origin) {
  const packBase = new URL('/colyseus/', origin);
  const manifest = await fetchJson(new URL('optional-maps.json', packBase));
  const ids = Object.keys(manifest).sort();
  assert.equal(ids.length, 6, `optional map manifest must list six packs (found ${ids.length})`);
  const resources = [];
  for (const id of ids) {
    const file = String(manifest[id]?.file ?? '');
    assert.ok(file.startsWith(`map-${id}-`) && file.endsWith('.pck') && !file.includes('/') && !file.includes('\\'), `${id}: invalid optional pack filename`);
    const response = await fetch(new URL(file, packBase), { method: 'HEAD', signal: AbortSignal.timeout(8_000), redirect: 'error' });
    assert.equal(response.status, 200, `${file} returned HTTP ${response.status} to HEAD`);
    resources.push({ map: id, file, status: response.status, bytes: Number(response.headers.get('content-length') ?? manifest[id].bytes ?? 0) });
  }
  return { manifest: 'present', packs: ids.length, headResources: resources };
}

async function probeMap(origin, map, index, tickets, isolateCombat) {
  const cohortRooms = [];
  const suffix = Date.now().toString(36);
  let room, username;
  try {
    const cohortSize = isolateCombat ? 8 : 1;
    const joinMember = async (member) => {
      const memberUsername = `DroneProbe${index}_${member}_${suffix}`;
      const client = new Client(origin);
      client.auth.token = tickets[member];
      const joinedRoom = await boundedJoin(client, { protocol_version: PROTOCOL_VERSION, room: `${map}-public`, username: memberUsername });
      joinedRoom.onMessage('*', () => {});
      cohortRooms.push(joinedRoom);
      await until(() => joinedRoom.state?.players?.has(memberUsername), `${map}: cohort member ${member} state`);
      return joinedRoom;
    };
    await joinMember(0);
    const observerResults = await Promise.allSettled(Array.from({ length: cohortSize - 1 }, (_, index) => joinMember(index + 1)));
    const observerFailure = observerResults.find((result) => result.status === 'rejected');
    if (observerFailure?.status === 'rejected') throw observerFailure.reason;
    room = cohortRooms[0];
    username = `DroneProbe${index}_0_${suffix}`;
    const player = room.state.players.get(username);
    const directory = await fetchJson(`${origin}/api/rooms`);
    const listing = directory.rooms.find((entry) => entry.id === `${map}-public`);
    assert.ok(listing, `${map}: joined room is missing from the directory`);
    const botsAfterJoin = Number(listing.botCount);
    assert.ok(Number.isInteger(botsAfterJoin), `${map}: invalid directory bot count`);
    if (isolateCombat) assert.equal(botsAfterJoin, 0, `${map}: bots must yield to eight SDK players`);
    assert.equal(Number(room.state.protocol_version), PROTOCOL_VERSION, `${map}: room protocol version mismatch`);
    assert.equal(String(room.state.map_name), map, `${map}: joined the wrong map`);
    assert.equal(String(room.state.room_mode), 'CONQUEST', `${map}: public room must remain Conquest`);
    assert.equal(Number(room.state.objectives?.size), 4, `${map}: Conquest objectives are missing`);
    const start = observeDrone(player, `${map}: spawn`);
    const input = room.input({ mode: 'reliable' });
    assert.equal(Number(input.tickRate), 60, `${map}: server input timeline did not negotiate 60 Hz`);
    let highestY = start.y, lowestY = start.y;
    const note = (pose) => { highestY = Math.max(highestY, pose.y); lowestY = Math.min(lowestY, pose.y); };
    const yaw = Number(player.yaw) || 0;
    const ascent = await sendPhase(input, player, { move_y: 1, yaw }, 30, `${map}: ascent`, note);
    assert.ok(highestY > start.y + 0.25, `${map}: move_y did not produce continuous ascent (${start.y} -> ${highestY})`);
    const descent = await sendPhase(input, player, { move_y: -1, yaw }, 30, `${map}: descent`, note);
    assert.ok(lowestY < ascent.pose.y - 0.25, `${map}: negative move_y did not produce continuous descent (${ascent.pose.y} -> ${lowestY})`);
    await sendPhase(input, player, { yaw }, 45, `${map}: braking`, note);
    const settled = observeDrone(player, `${map}: settled`);
    await sleep(400);
    const held = observeDrone(player, `${map}: settled hold`);
    const drift = Math.hypot(held.x - settled.x, held.y - settled.y, held.z - settled.z);
    const residualSpeed = Math.hypot(held.vx, held.vy, held.vz);
    assert.ok(residualSpeed <= 0.08, `${map}: released controls left ${residualSpeed.toFixed(4)}m/s`);
    assert.ok(drift <= 0.04, `${map}: released controls drifted ${drift.toFixed(4)}m after settling`);

    const vehicles = [...room.state.vehicles.values()];
    const vehicle = vehicles[0];
    const vehicleId = String(vehicle?.id ?? 'CAR_0');
    const originalDriver = String(vehicle?.driver ?? '');
    room.send('vehicle_seat', { id: vehicleId, enter: true });
    await sleep(250);
    assert.equal(String(player.driving_vehicle ?? ''), '', `${map}: drone entered vehicle seat ${vehicleId}`);
    if (vehicle) assert.equal(String(vehicle.driver ?? ''), originalDriver, `${map}: rejected request changed vehicle ${vehicleId}`);
    assert.equal(String(room.state.room_mode), 'CONQUEST', `${map}: room mode changed during probe`);
    assert.equal(Number(room.state.objectives?.size), 4, `${map}: Conquest state changed during probe`);
    return {
      map, roomMode: String(room.state.room_mode), objectives: Number(room.state.objectives.size),
      ascentMetres: Number((highestY - start.y).toFixed(3)), descentMetres: Number((ascent.pose.y - lowestY).toFixed(3)),
      settledSpeed: Number(residualSpeed.toFixed(4)), driftMetres: Number(drift.toFixed(4)), vehicleSeatRejected: true,
      cohortPlayers: cohortRooms.length, botsAfterJoin,
    };
  } finally {
    for (const joined of [...cohortRooms].reverse()) await leaveRoom(joined);
  }
}

async function main() {
  const options = argumentsFrom(process.argv.slice(2));
  if (options.help) {
    console.log('Usage: node scripts/probe_drone_runtime.mjs [--origin URL] [--map ID | --all-maps] [--isolate-combat] [--check-packs] [--out JSON]');
    console.log('Origin: WARBASE_ORIGIN or COLYSEUS_URL; default is the public Colyseus endpoint.');
    return;
  }
  validateOptions(options);
  const maps = options.allMaps ? PLAYABLE_MAPS : [options.map];
  const report = { origin: options.origin, protocol: PROTOCOL_VERSION, previousProtocolRejected: false, isolateCombat: options.isolateCombat, directory: null, optionalPacks: null, maps: [], failures: [] };
  try {
    await fetchJson(`${options.origin}/health`);
    report.directory = await verifyPublicDirectory(options.origin);
    await verifyOldProtocol(options.origin, report);
    if (options.checkPacks) report.optionalPacks = await verifyOptionalPacks(options.origin);
    const tickets = [];
    for (let index = 0; index < (options.isolateCombat ? 8 : 1); index++) tickets.push(await admissionTicket(options.origin));
    for (const [index, map] of maps.entries()) {
      try {
        const result = await probeMap(options.origin, map, index, tickets, options.isolateCombat);
        report.maps.push(result);
        console.log(`DRONE_SDK_MAP_OK ${map} cohort=${result.cohortPlayers} bots=${result.botsAfterJoin} ascent_m=${result.ascentMetres} descent_m=${result.descentMetres} settled_speed=${result.settledSpeed} drift_m=${result.driftMetres} seat_rejected=true`);
      } catch (error) {
        const failure = { map, error: error?.message ?? String(error) };
        report.failures.push(failure);
        console.error(`DRONE_SDK_MAP_FAILED ${map}: ${failure.error}`);
      }
    }
  } catch (error) { report.failures.push({ phase: 'preflight', error: error?.message ?? String(error) }); }
  report.ok = report.failures.length === 0 && report.maps.length === maps.length && report.previousProtocolRejected;
  if (options.output) {
    await mkdir(dirname(options.output), { recursive: true });
    await writeFile(options.output, `${JSON.stringify(report, null, 2)}\n`);
  }
  console.log(`DRONE_SDK_PROBE_${report.ok ? 'OK' : 'FAILED'} maps=${report.maps.length}/${maps.length} previousProtocolRejected=${report.previousProtocolRejected} directory_conquest=${report.directory?.publicConquestRooms ?? 0} failures=${report.failures.length}${options.output ? ` out=${options.output}` : ''}`);
  if (!report.ok) process.exitCode = 1;
}

main().catch((error) => {
  console.error('DRONE_SDK_PROBE_FAILED', error?.stack ?? error);
  process.exitCode = 1;
});
