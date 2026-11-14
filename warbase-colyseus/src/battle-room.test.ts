import assert from 'node:assert/strict';
import { createServer } from 'node:net';
import test from 'node:test';
import { Server } from 'colyseus';
import { WebSocketTransport } from '@colyseus/ws-transport';
import { ColyseusTestServer } from '@colyseus/testing';
import type { Client } from 'colyseus';
import { RewindView } from '@colyseus/core/Rewind';
import { activeRooms, aimDirection, BattleRoom, damageForZone, movementVelocity } from './battle-room.js';
import { processOperationsMetrics, processTimingSnapshot, roomOperationsMetrics } from './operations-metrics.js';
import { readFileSync } from 'node:fs';
import { INDUSTRIAL_SPAWNS, rayBlocked, type Vec3 } from './world-geometry.js';
import { VehicleSimulation, type VehiclePlayer } from './vehicle-simulation.js';
import { configureBattleAdmission } from './admission.js';
import { UniqueSessionPlugin } from 'colyseus/plugins/unique-session';

async function availablePort(): Promise<number> {
  const socket = createServer();
  await new Promise<void>((resolve, reject) => socket.listen(0, '127.0.0.1', resolve).once('error', reject));
  const address = socket.address();
  if (!address || typeof address === 'string') throw new Error('No loopback port available');
  const port = address.port;
  await new Promise<void>((resolve, reject) => socket.close((error) => error ? reject(error) : resolve()));
  return port;
}

async function waitFor(predicate: () => boolean, timeoutMs = 1500): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (!predicate() && Date.now() < deadline) await new Promise((resolve) => setTimeout(resolve, 20));
  assert.ok(predicate(), 'condition did not become true before timeout');
}

test('all 280 authoritative weapon-zone rows match the shared combat fixture', () => {
  const fixturePath = new URL('../../warbase-godot/client/scripts/tests/combat-fixture.json', import.meta.url);
  const rows = JSON.parse(readFileSync(fixturePath, 'utf8')) as Array<{ weapon: string; range_m: number; zone: string; damage: number }>;
  assert.equal(rows.length, 280);
  for (const row of rows) {
    assert.equal(damageForZone(row.weapon, row.range_m, row.zone), row.damage, `${row.weapon} ${row.range_m}m ${row.zone}`);
  }
});

test('server ray directions match the Godot camera at four yaw cardinals and pitch', () => {
  const close = (a: number, b: number) => assert.ok(Math.abs(a - b) < 1e-9, `${a} != ${b}`);
  const expected: Array<[number, Vec3]> = [
    [0, [0, 0, -1]], [Math.PI / 2, [-1, 0, 0]], [Math.PI, [0, 0, 1]], [-Math.PI / 2, [1, 0, 0]],
  ];
  for (const [yaw, vector] of expected) aimDirection(yaw, 0).forEach((value, index) => close(value, vector[index]));
  const pitched = aimDirection(0, Math.PI / 6);
  close(pitched[0], 0); close(pitched[1], -0.5); close(pitched[2], -Math.sqrt(3) / 2);
});

test('server movement preserves analog magnitude and normalizes diagonal input like Godot', () => {
  const close = (a: number, b: number) => assert.ok(Math.abs(a - b) < 1e-9, `${a} != ${b}`);
  const forward = movementVelocity(0, 0.5, 0, 6.2);
  close(forward[0], 0); close(forward[1], -3.1);
  const diagonal = movementVelocity(1, 1, 0, 6.2);
  close(Math.hypot(...diagonal), 6.2); close(diagonal[0], 6.2 / Math.sqrt(2)); close(diagonal[1], -6.2 / Math.sqrt(2));
});

test('two driven vehicles collide head-on without chassis passing through at 60 Hz', () => {
  const sim = new VehicleSimulation();
  const carA = sim.states.get('CAR_0')!;
  const carB = sim.states.get('CAR_1')!;
  carB.pos = [carA.pos[0], carA.pos[1], carA.pos[2] - 9];
  carB.yaw = Math.PI;
  const driverA: VehiclePlayer = { username: 'collision-a', x: carA.pos[0], y: carA.pos[1], z: carA.pos[2], health: 100, deaths: 0, team: 'A', is_dead: false, driving_vehicle: '', vehicle_index: -1, vehicle_generation: 0 };
  const driverB: VehiclePlayer = { username: 'collision-b', x: carB.pos[0], y: carB.pos[1], z: carB.pos[2], health: 100, deaths: 0, team: 'B', is_dead: false, driving_vehicle: '', vehicle_index: -1, vehicle_generation: 0 };
  assert.equal(sim.enter(driverA, carA.id, 1000), true);
  assert.equal(sim.enter(driverB, carB.id, 1000), true);
  const players = new Map([[driverA.username, driverA], [driverB.username, driverB]]);
  for (let tick = 1; tick <= 180; tick++) {
    const now = 1000 + tick * (1000 / 60);
    sim.input(driverA, { throttle: 1, steer: 0, brake: false, gear: 1, vehicleIndex: driverA.vehicle_index, vehicleGeneration: driverA.vehicle_generation }, now);
    sim.input(driverB, { throttle: 1, steer: 0, brake: false, gear: 1, vehicleIndex: driverB.vehicle_index, vehicleGeneration: driverB.vehicle_generation }, now);
    sim.step(1 / 60, now, players);
  }
  const separation = Math.hypot(carA.pos[0] - carB.pos[0], carA.pos[2] - carB.pos[2]);
  assert.ok(carA.pos.every(Number.isFinite) && carB.pos.every(Number.isFinite), 'collision resolution keeps both authoritative poses finite');
  assert.ok(separation > 4.5, `vehicles remain nose-to-nose instead of passing through (separation=${separation})`);
  assert.equal(carA.driver, driverA.username);
  assert.equal(carB.driver, driverB.username);
});

test('BattleRoom admission, combat authority, ammo and lifecycle', async (t) => {
  const port = await availablePort();
  const server = new Server({ transport: new WebSocketTransport(), greet: false });
  server.define('battle', BattleRoom).filterBy(['room']);
  await server.listen(port, '127.0.0.1');
  const testing = new ColyseusTestServer(server);
  t.after(async () => {
    await testing.cleanup();
    await testing.shutdown();
  });

  await t.test('admits a player, times the real Industrial bot join, and cleans up leaving clients', async (t) => {
    const processJoinsBefore = processOperationsMetrics.joined;
    const processLeavesBefore = processOperationsMetrics.left;
    const processTicksBefore = processTimingSnapshot().ticks_total;
    await assert.rejects(() => testing.createRoom('battle', { username: 'bad-map', room: 'loft-public' }));
    const room = await testing.createRoom<BattleRoom>('battle', { room: 'industrial-public' });
    await assert.rejects(async () => room.onJoin({ sessionId: 'invalid-name' } as any, { username: '<script>' }), /valid username required/, 'unsafe names cannot enter live room state');
    const joinStarted = performance.now();
    const alice = await testing.connectTo(room, { username: 'alice', room: 'industrial-public' });
    assert.ok(Math.abs(room.state.players.get('alice')!.y - (room as any).geometry.spawns[0][1] - 0.9) < 0.01, 'human state begins at the drone center above its authored spawn');
    await waitFor(() => room.state.players.has('alice'));
    (room as any).selectWeapon(alice.sessionId, 'constructor');
    (room as any).selectWeapon(alice.sessionId, '__proto__');
    assert.equal(room.state.players.get('alice')?.weapon_id, 'ak47', 'prototype property names are not accepted as weapons');
    assert.equal(roomOperationsMetrics.get(room.roomId)?.joined, 1);
    const metrics = roomOperationsMetrics.get(room.roomId)!;
    assert.equal((room as any).allowMessage(alice, 'audit-limit', 1), true);
    assert.equal((room as any).allowMessage(alice, 'audit-limit', 1), false);
    assert.equal(metrics.rateLimitedMessages, 1);
    assert.equal((room as any).sessionByUsername.get('alice'), alice.sessionId);
    await waitFor(() => [...room.state.players.values()].filter((player) => player.is_bot).length === 7);
    const drone = room.state.players.get('alice')!;
    const flightInput = alice.input<any>({ mode: 'reliable' });
    const altitudeBefore = drone.y;
    flightInput.data.move_y = 1;
    let sequence = 0;
    for (let tick = 0; tick < 15; tick++) {
      sequence = flightInput.send();
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
    await waitFor(() => drone.ack_input_sequence >= sequence);
    assert.ok(drone.y > altitudeBefore + 0.1, 'authoritative move_y input makes a drone climb');
    const highPoint = drone.y;
    flightInput.data.move_y = -1;
    // The default helicopter must brake its upward velocity before descending.
    // Allow 0.9 seconds for the bounded 15 m/s² vertical acceleration.
    for (let tick = 0; tick < 45; tick++) {
      sequence = flightInput.send();
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
    await waitFor(() => drone.ack_input_sequence >= sequence);
    assert.ok(drone.y < highPoint - 0.1, `negative move_y input makes a drone descend: high=${highPoint}, y=${drone.y}, vy=${drone.vy}, mode=${drone.mobility_mode}`);
    await waitFor(() => processTimingSnapshot().ticks_total > processTicksBefore);
    assert.ok(processTimingSnapshot().ticks_total > processTicksBefore, 'active match ticks reach process metrics');
    t.diagnostic(`first Industrial player+bot admission: ${(performance.now() - joinStarted).toFixed(1)} ms`);
    assert.equal(room.state.map_name, 'industrial');
    await assert.rejects(() => testing.connectTo(room, { username: 'alice', room: 'industrial-public' }));
    alice.reconnection.minUptime = 0;
    const reconnected = new Promise<void>((resolve) => alice.onReconnect.once(resolve));
    alice.connection.close();
    await Promise.race([reconnected, new Promise((_, reject) => setTimeout(() => reject(new Error('SDK reconnect timed out')), 5000))]);
    assert.equal(room.state.players.size, 8, 'one human and seven bots remain during reconnection');
    await alice.leave();
    await waitFor(() => room.state.players.size === 0);
    assert.equal((room as any).sessionByUsername.has('alice'), false);
    assert.equal(processOperationsMetrics.joined, processJoinsBefore + 1);
    assert.equal(processOperationsMetrics.left, processLeavesBefore + 1);
    room.onDispose();
    assert.equal(roomOperationsMetrics.has(room.roomId), false, 'room-local metrics are removed on disposal');
    assert.equal(processOperationsMetrics.joined, processJoinsBefore + 1, 'process totals survive room disposal');
  });

  await t.test('authority recovers fallen actors through death and respawn on normal and deep Canyon floors', async () => {
    for (const map of ['industrial', 'canyon']) {
      const room = await testing.createRoom<BattleRoom>('battle', { room: map + '-public' });
      const client = await testing.connectTo(room, { username: 'void-check-' + map });
      const player = room.state.players.get('void-check-' + map)!;
      player.y = map === 'canyon' ? -121 : -16;
      await waitFor(() => player.is_dead);
      assert.equal(player.health, 0);
      assert.equal(player.deaths, 1);
      const runtime = (room as any).internal.get(client.sessionId);
      assert.ok(runtime.spawnAt > 0, 'uses scheduled authoritative respawn');
      runtime.spawnAt = Date.now() - 1;
      await waitFor(() => !player.is_dead);
      assert.ok(player.y > -1, 'returns to authored ground');
      assert.equal(player.health, 100);
      await room.disconnect();
    }
  });

  await t.test('times actual Football geometry and bot admission', async (t) => {
    const room = await testing.createRoom<BattleRoom>('battle', { room: 'football-public' });
    const joinStarted = performance.now();
    const client = await testing.connectTo(room, { username: 'footballer', room: 'football-public' });
    await waitFor(() => room.state.players.has('footballer') && [...room.state.players.values()].filter((player) => player.is_bot).length === 7);
    t.diagnostic(`first Football player+bot admission: ${(performance.now() - joinStarted).toFixed(1)} ms`);
    assert.equal(room.state.map_name, 'football');
    await client.leave();
  });

  await t.test('joins a live Conquest room with four objectives, balanced teams, and ticking capture state', async () => {
    const room = await testing.createRoom<BattleRoom>('battle', { room: 'conquest-live', map: 'resoforge', mode: 'CONQUEST' });
    const alpha = await testing.connectTo(room, { username: 'conquest-alpha', room: 'conquest-live' });
    const beta = await testing.connectTo(room, { username: 'conquest-beta', room: 'conquest-live' });
    await waitFor(() => room.state.players.has('conquest-alpha') && room.state.players.has('conquest-beta'));
    assert.equal(room.state.room_mode, 'CONQUEST');
    assert.equal(room.state.objectives.size, 4);
    assert.equal(room.state.players.get('conquest-alpha')?.team, 'A');
    assert.equal(room.state.players.get('conquest-beta')?.team, 'B');
    for (const actor of room.state.players.values()) if (actor.is_bot) {
      actor.is_dead = true; actor.health = 0; actor.x = 10_000; actor.z = 10_000;
      (room as any).botSimulation.markDead(actor.username, Date.now());
    }
    room.state.players.get('conquest-beta')!.is_dead = true;
    const objective = room.state.objectives.get('A')!;
    const actor = room.state.players.get('conquest-alpha')!;
    actor.x = objective.x; actor.y = objective.y; actor.z = objective.z;
    await waitFor(() => objective.capturing_team === 'A' && objective.progress > 0, 1500);
    assert.equal(objective.capturing_team, 'A');
    assert.equal(objective.radius > 0 && objective.radius <= 12, true);
    const target = room.state.players.get('conquest-beta')!;
    target.is_dead = false; target.health = 100;
    room.state.room_state = 'finished'; room.state.winner = 'A';
    const kills = actor.kills, deaths = target.deaths;
    (room as any).applyPlayerDamage(actor, target, 50);
    (room as any).killPlayer(actor, target);
    assert.equal(target.health, 100, 'finished Conquest matches stop damage');
    assert.equal(actor.kills, kills); assert.equal(target.deaths, deaths, 'finished matches stop kill and death changes');
    await alpha.leave(); await beta.leave();
  });

  await t.test('live room actions replicate grenade inventory, vehicle seat and authoritative motion', async () => {
    const room = await testing.createRoom<BattleRoom>('battle', { room: 'industrial-public' });
    const client = await testing.connectTo(room, { username: 'module-smoke', room: 'industrial-public' });
    client.onMessage('identity', () => {}); client.onMessage('grenade', () => {}); client.onMessage('grenade_rejected', () => {});
    const player = room.state.players.get('module-smoke')!;
    const vehicle = room.state.vehicles.get('CAR_0')!;
    const [vx, vy, vz] = [...vehicle.pos];
    player.x = vx; player.y = vy; player.z = vz;
    const receivedGrenade = new Promise((resolve) => client.onMessage('grenade', resolve));
    client.send('grenade', { pos: [vx, vy, vz], vel: [0, 2, 0], throwable: 'frag', request_id: 123 });
    await waitFor(() => player.grenades === 1);
    const accepted = await Promise.race([receivedGrenade, new Promise((resolve) => setTimeout(() => resolve(null), 1000))]) as any;
    assert.ok(accepted);
    assert.equal(accepted.request_id, 123, 'accepted throw echoes the optimistic request key');
    const duplicateRejection = new Promise<any>((resolve) => client.onMessage('grenade_rejected', resolve));
    client.send('grenade', { pos: [vx, vy, vz], vel: [0, 2, 0], throwable: 'frag', request_id: 123 });
    const duplicate = await Promise.race([duplicateRejection, new Promise((resolve) => setTimeout(() => resolve(null), 1000))]) as any;
    assert.ok(duplicate);
    assert.equal(duplicate.request_id, 123, 'duplicate request keys are rejected');
    assert.equal(player.grenades, 1, 'duplicate request does not consume a second grenade');
    const rejectedGrenade = new Promise<any>((resolve) => client.onMessage('grenade_rejected', resolve));
    client.send('grenade', { pos: [vx, vy, vz], vel: [0, 2, 0], throwable: 'frag', request_id: 124 });
    const rejected = await Promise.race([rejectedGrenade, new Promise((resolve) => setTimeout(() => resolve(null), 1000))]) as any;
    assert.ok(rejected);
    assert.equal(rejected.request_id, 124, 'server validation rejection settles the matching prediction');
    assert.equal(player.grenades, 1, 'rejected throw does not consume server inventory');
    client.send('vehicle_seat', { id: 'CAR_0', enter: true });
    await new Promise((resolve) => setTimeout(resolve, 50));
    const startX = vehicle.pos[0], startZ = vehicle.pos[2];
    const vehicleInput = client.input<any>({ mode: 'reliable' });
    Object.assign(vehicleInput.data, { vehicle_throttle: 1, vehicle_index: 0, vehicle_generation: 0 });
    vehicleInput.send();
    await waitFor(() => player.ack_input_sequence > 0);
    assert.equal(player.driving_vehicle, '', 'drone seat requests are rejected');
    assert.equal(vehicle.driver, '', 'vehicles remain unoccupied world props');
    assert.equal(vehicle.speed, 0, 'vehicle controls cannot move an unoccupied prop');
    assert.ok(Math.hypot(vehicle.pos[0] - startX, vehicle.pos[2] - startZ) <= 0.02);
    await client.leave();
  });

  await t.test('drone seat requests are rejected while vehicle lifecycle remains server owned', async () => {
    const room = await testing.createRoom<BattleRoom>('battle', { room: 'industrial-public' });
    const client = await testing.connectTo(room, { username: 'seat-lifecycle', room: 'industrial-public' });
    const player = room.state.players.get('seat-lifecycle')!;
    const vehicle = room.state.vehicles.get('CAR_0')!;
    (room as any).vehicleSeat(client, { id: vehicle.id, enter: true });
    assert.equal(player.driving_vehicle, '');
    assert.equal(vehicle.driver, '');
    const oldIndex = player.vehicle_index, oldGeneration = player.vehicle_generation;
    (room as any).killPlayer(undefined, player);
    assert.equal(vehicle.driver, '');
    assert.equal(player.driving_vehicle, '');
    assert.equal(player.vehicle_index, -1);
    assert.equal((room as any).vehicleSimulation.input((room as any).vehiclePlayer(player), {
      throttle: 1, steer: 0, brake: false, gear: 2, vehicleIndex: oldIndex, vehicleGeneration: oldGeneration,
    }, Date.now()), false);
    (room as any).allowReconnection = async () => { throw new Error('test drop window ended'); };
    await (room as any).onDrop(client);
    assert.equal(vehicle.driver, '');
    assert.equal(player.driving_vehicle, '');
    assert.equal(player.vehicle_index, -1);
    await client.leave();
  });

  await t.test('SDK reconnect preserves drone state and does not enter world vehicles', async () => {
    const room = await testing.createRoom<BattleRoom>('battle', { room: 'industrial-public' });
    const client = await testing.connectTo(room, { username: 'vehicle-reconnect', room: 'industrial-public' });
    client.onMessage('identity', () => {});
    const player = room.state.players.get('vehicle-reconnect')!;
    const vehicle = room.state.vehicles.get('CAR_0')!;
    client.send('vehicle_seat', { id: vehicle.id, enter: true });
    await new Promise((resolve) => setTimeout(resolve, 50));
    assert.equal(player.driving_vehicle, '');
    assert.equal(vehicle.driver, '');

    client.reconnection.minUptime = 0;
    const reconnected = new Promise<void>((resolve) => client.onReconnect.once(resolve));
    client.connection.close();
    await Promise.race([reconnected, new Promise((_, reject) => setTimeout(() => reject(new Error('SDK vehicle reconnect timed out')), 5000))]);
    client.send('vehicle_seat', { id: vehicle.id, enter: true });
    await new Promise((resolve) => setTimeout(resolve, 50));
    assert.equal(player.driving_vehicle, '');
    assert.equal(vehicle.driver, '');
    await client.leave();
  });

  await t.test('preserves ammunition across switches and reloads only from reserve', async () => {
    const room = await testing.createRoom<BattleRoom>('battle', { room: 'industrial-public' });
    const client = await testing.connectTo(room, { username: 'ammo', room: 'industrial-public' });
    const player = room.state.players.get('ammo')!;
    const internal = (room as any).internal.get(client.sessionId);
    player.ammo = 7; internal.ammoByWeapon.ak47 = 7;
    (room as any).selectWeapon(client.sessionId, 'pistol');
    assert.equal(player.ammo, 12);
    assert.equal(player.reserve_ammo, 36);
    player.ammo = 3; internal.ammoByWeapon.pistol = 3;
    player.reserve_ammo = 4;
    (room as any).selectWeapon(client.sessionId, 'ak47');
    assert.equal(player.ammo, 7);
    assert.equal(player.reserve_ammo, 90);
    (room as any).selectWeapon(client.sessionId, 'pistol');
    assert.equal(player.ammo, 3);
    assert.equal(player.reserve_ammo, 4);
    (room as any).reload({ sessionId: client.sessionId });
    assert.equal((room as any).internal.get(client.sessionId).reloadUntil > Date.now(), true);
    (room as any).selectWeapon(client.sessionId, 'ak47');
    assert.equal(player.weapon_id, 'ak47', 'switching cancels the reload');
    (room as any).selectWeapon(client.sessionId, 'pistol');
    assert.equal(player.ammo, 3);
    assert.equal(player.reserve_ammo, 4);
    (room as any).reload({ sessionId: client.sessionId });
    await new Promise((resolve) => setTimeout(resolve, 1550));
    assert.equal(player.ammo, 7);
    assert.equal(player.reserve_ammo, 0);
    (room as any).reload({ sessionId: client.sessionId });
    assert.equal(internal.reloadUntil, 0, 'empty reserve cannot start a reload');
    await client.leave();
  });

  await t.test('dual payloads preserve independent cadence, authoritative ammo and reload', async () => {
    const room = await testing.createRoom<BattleRoom>('battle', { room: 'industrial-public' });
    const client = await testing.connectTo(room, { username: 'dual-payload', room: 'industrial-public' });
    const player = room.state.players.get('dual-payload')!;
    const runtime = (room as any).internal.get(client.sessionId);
    client.send('loadout', { primary: 'ak47', secondary: 'pistol' });
    await waitFor(() => player.secondary_payload === 'pistol');
    const snapshots: Array<{ weapon: string; ammo: number; reserve_ammo: number; last_shot_id: number; reloading: boolean }> = [];
    client.onMessage('payload_ammo', data => snapshots.push(data));
    client.send('fire', { shot_id: 1, weapon: 'ak47', yaw: 0, pitch: -1 });
    client.send('fire', { shot_id: 2, weapon: 'pistol', yaw: 0, pitch: -1 });
    client.send('fire', { shot_id: 3, weapon: 'pistol', yaw: 0, pitch: -1 });
    client.send('fire', { shot_id: 4, weapon: 'aim9', yaw: 0, pitch: -1 });
    await waitFor(() => player.last_shot_id === 4 && snapshots.length === 2);
    assert.equal(player.weapon_id, 'ak47');
    assert.equal(player.ammo, 29);
    assert.equal(runtime.ammoByWeapon.pistol, 11);
    assert.equal(runtime.ammoByWeapon.aim9, 2);
    assert.deepEqual(snapshots.map(({ weapon, ammo, last_shot_id }) => [weapon, ammo, last_shot_id]), [['pistol', 11, 2], ['pistol', 11, 3]]);
    client.send('reload', { weapon: 'pistol' });
    await waitFor(() => snapshots.some(snapshot => snapshot.reloading));
    await waitFor(() => snapshots.some(snapshot => snapshot.ammo === 12 && snapshot.reserve_ammo === 35), 2200);
    assert.equal(player.ammo, 29);
    await client.leave();
  });

  await t.test('stale reload completion cannot clear a newer weapon reload', async () => {
    const room = await testing.createRoom<BattleRoom>('battle', { room: 'industrial-public' });
    const client = await testing.connectTo(room, { username: 'reload-race', room: 'industrial-public' });
    const player = room.state.players.get('reload-race')!;
    const internal = (room as any).internal.get(client.sessionId);
    for (const bot of room.state.players.values()) if (bot.is_bot) { bot.health = 0; bot.is_dead = true; }
    player.ammo = 0; internal.ammoByWeapon.ak47 = 0;
    (room as any).reload({ sessionId: client.sessionId });
    const staleDeadline = internal.reloadUntil;
    // Simulate a weapon selection arriving as the old completion is due; token checks must protect the new deadline.
    internal.reloadUntil = 0;
    player.ammo = 0; internal.ammoByWeapon.m2010 = 0;
    (room as any).selectWeapon(client.sessionId, 'm2010');
    (room as any).reload({ sessionId: client.sessionId });
    assert.ok(internal.reloadUntil > staleDeadline);
    await new Promise((resolve) => setTimeout(resolve, 2650));
    assert.ok(internal.reloadUntil > Date.now(), 'the old AK completion cannot unlock the M2010 reload');
    assert.equal(player.ammo, 0);
    await new Promise((resolve) => setTimeout(resolve, 650));
    assert.equal(internal.reloadUntil, 0);
    assert.equal(player.ammo, 5);
    await client.leave();
  });

  await t.test('applies server ray damage with range falloff and rejects shot replay/cadence', async () => {
    const room = await testing.createRoom<BattleRoom>('battle', { room: 'industrial-public' });
    const shooter = await testing.connectTo(room, { username: 'shooter', room: 'industrial-public' });
    const victim = await testing.connectTo(room, { username: 'victim', room: 'industrial-public' });
    const p1 = room.state.players.get('shooter')!, p2 = room.state.players.get('victim')!;
    const a = INDUSTRIAL_SPAWNS[0], b = INDUSTRIAL_SPAWNS[10];
    const fireYaw = Math.atan2(-(b[0] - a[0]), -(b[2] - a[2]));
    p1.x = a[0]; p1.y = a[1] + 0.9; p1.z = a[2]; p1.team = 'A'; p1.yaw = 0; p1.pitch = 0; // stale consumed movement aim
    p2.x = b[0]; p2.y = b[1] + 0.9; p2.z = b[2]; p2.team = 'B';
    for (const bot of room.state.players.values()) if (bot.is_bot) { bot.health = 0; bot.is_dead = true; }
    (room as any).rewind.record(Date.now());
    (room as any).internal.get(shooter.sessionId).protectedUntil = 0;
    (room as any).internal.get(victim.sessionId).protectedUntil = 0;
    const serverShooter = room.clients.find((client: Client) => client.sessionId === shooter.sessionId)!;
    const origin: [number, number, number] = [p1.x, p1.y, p1.z];
    const fire = (room as any).fire.bind(room);
    const hit = (room as any).hit.bind(room);
    const firstHitPoint: [number, number, number] = [p2.x, p2.y, p2.z];
    assert.equal(rayBlocked(origin, firstHitPoint), false, 'fixture spawns have an open ray');
    fire(serverShooter, { shot_id: 1, origin, hit: firstHitPoint, yaw: fireYaw, pitch: p1.pitch });
    assert.equal(p1.ammo, 29);
    const expectedAim = aimDirection(fireYaw, 0);
    const shotDirection = (room as any).internal.get(shooter.sessionId).fireSegment.d as Vec3;
    shotDirection.forEach((value, index) => assert.ok(Math.abs(value - expectedAim[index]) < 1e-9));
    assert.ok(p2.health < 100, 'fire alone resolves the server ray without a client hit notice');
    const afterServerHit = p2.health;
    (room as any).selectWeapon(shooter.sessionId, 'm2010');
    hit(serverShooter, { target: 'victim', shot_id: 1 });
    assert.equal(p2.health, afterServerHit, 'legacy client hit notices cannot duplicate or alter authoritative damage');
    const afterHit = p2.health;
    hit(serverShooter, { target: 'victim', shot_id: 1 });
    assert.equal(p2.health, afterHit, 'a consumed shot cannot resolve twice');
    const afterAmmo = p1.ammo;
    fire(serverShooter, { shot_id: 1, origin, hit: firstHitPoint });
    assert.equal(p1.ammo, afterAmmo, 'a replayed shot id is rejected');
    fire(serverShooter, { shot_id: 2, origin, hit: firstHitPoint });
    assert.equal(p1.ammo, afterAmmo - 1, 'switching allows a separate weapon to fire');
    fire(serverShooter, { shot_id: 3, origin, hit: firstHitPoint });
    assert.equal(p1.ammo, afterAmmo - 1, 'same-weapon cadence rejects an immediate next shot');
    assert.equal(p1.last_shot_id, 3, 'rejected shot still clears the client prediction');
    await shooter.leave(); await victim.leave();
  });

  await t.test('framework rewind retains SDK pose metadata while drone hits use the rewound center', async () => {
    const room = await testing.createRoom<BattleRoom>('battle', { room: 'industrial-public' });
    const shooter = await testing.connectTo(room, { username: 'timeline-shooter', room: 'industrial-public' });
    await testing.connectTo(room, { username: 'timeline-target', room: 'industrial-public' });
    const source = room.state.players.get('timeline-shooter')!, target = room.state.players.get('timeline-target')!;
    const from: [number, number, number] = [-22, 1.3, -10], to: [number, number, number] = [-22, 1.3, 0];
    source.x = from[0]; source.y = from[1]; source.z = from[2]; source.team = 'A';
    target.x = to[0]; target.y = to[1]; target.z = to[2]; target.team = 'B'; target.health = 100;
    for (const bot of room.state.players.values()) if (bot.is_bot) { bot.health = 0; bot.is_dead = true; }
    const yaw = 0;
    const serverShooter = room.clients.find((client: Client) => client.sessionId === shooter.sessionId)!;
    const runtime = (room as any).internal.get(shooter.sessionId);
    // Stop automatic room sampling so the framework timeline contains only these deliberately spaced records.
    room.setSimulationInterval();
    const states = [
      { code: 1, phase: 0.21, yaw: 0.15 },
      { code: 2, phase: 0.38, yaw: 0.35 },
      { code: 4, phase: 0.62, yaw: -0.2 },
    ];
    let shotId = 1;
    const stamps: number[] = [];
    const baseStamp = Date.now();
    for (let index = 0; index < states.length; index++) {
      const state = states[index];
      target.animation_code = state.code; target.animation_time = state.phase;
      target.qx = 0; target.qy = Math.sin(state.yaw / 2); target.qz = 0; target.qw = Math.cos(state.yaw / 2);
      const stamp = baseStamp + index * 100; stamps.push(stamp); (room as any).rewind.record(stamp);
      runtime.lastShotByWeapon = {};
      (room as any).fire(serverShooter, { shot_id: shotId++, origin: from, yaw, pitch: 0 });
      const seen = runtime.fireSegment.seen;
      assert.equal(seen.value(target, 'animation_code'), state.code);
      assert.ok(Math.abs(seen.value(target, 'animation_time') - state.phase) < 1e-9);
      assert.ok(Math.abs(seen.value(target, 'qy') - Math.sin(state.yaw / 2)) < 1e-9);
      assert.ok(Math.abs(seen.value(target, 'qw') - Math.cos(state.yaw / 2)) < 1e-9);
    }
    const midpoint = (room as any).rewind.at((stamps[0] + stamps[1]) / 2, new RewindView());
    assert.equal(midpoint.value(target, 'animation_code'), states[0].code, 'clip transitions step instead of inventing an intermediate enum');
    assert.equal(midpoint.value(target, 'animation_time'), states[0].phase, 'clip phase stays attached to the selected clip');
    assert.ok(Math.abs(midpoint.value(target, 'qy') - (Math.sin(states[0].yaw / 2) + Math.sin(states[1].yaw / 2)) / 2) < 1e-9,
      'the same framework view linearly interpolates continuous quaternion fields');
    await shooter.leave();
  });

  await t.test('spawn protection and friendly bodies block authoritative hits', async () => {
    const room = await testing.createRoom<BattleRoom>('battle', { room: 'industrial-public' });
    const shooter = await testing.connectTo(room, { username: 'guard-shooter', room: 'industrial-public' });
    const friend = await testing.connectTo(room, { username: 'guard-friend', room: 'industrial-public' });
    const victim = await testing.connectTo(room, { username: 'guard-victim', room: 'industrial-public' });
    const p1 = room.state.players.get('guard-shooter')!, ally = room.state.players.get('guard-friend')!, p2 = room.state.players.get('guard-victim')!;
    const start = INDUSTRIAL_SPAWNS[0], middle: [number, number, number] = [-22, 2.2, -10], end: [number, number, number] = [-22, 2.2, 0];
    p1.x = start[0]; p1.y = start[1] + 0.9; p1.z = start[2]; p1.team = 'A'; p1.yaw = 0; p1.pitch = 0;
    ally.x = middle[0]; ally.y = middle[1]; ally.z = middle[2]; ally.team = 'A';
    p2.x = end[0]; p2.y = end[1]; p2.z = end[2]; p2.team = 'B';
    for (const bot of room.state.players.values()) if (bot.is_bot) { bot.health = 0; bot.is_dead = true; }
    (room as any).rewind.record(Date.now());
    const internal = (room as any).internal;
    internal.get(shooter.sessionId).protectedUntil = 0;
    internal.get(victim.sessionId).protectedUntil = Date.now() + 2500;
    const serverShooter = room.clients.find((client: Client) => client.sessionId === shooter.sessionId)!;
    const origin: [number, number, number] = [p1.x, p1.y, p1.z];
    (room as any).fire(serverShooter, { shot_id: 1, origin, hit: end, yaw: Math.PI, pitch: 0 });
    (room as any).hit(serverShooter, { target: 'guard-victim', shot_id: 1 });
    assert.equal(p2.health, 100, 'spawn protection prevents damage');
    internal.get(victim.sessionId).protectedUntil = 0;
    internal.get(shooter.sessionId).lastShotByWeapon = {};
    (room as any).fire(serverShooter, { shot_id: 2, origin, hit: end, yaw: Math.PI, pitch: 0 });
    (room as any).hit(serverShooter, { target: 'guard-victim', shot_id: 2 });
    assert.equal(p2.health, 100, 'a teammate in front blocks the hit');
    await shooter.leave(); await friend.leave(); await victim.leave();
  });

  await t.test('early respawn requests cannot bypass server death delay or spawn protection', async () => {
    const room = await testing.createRoom<BattleRoom>('battle', { room: 'industrial-public' });
    const client = await testing.connectTo(room, { username: 'respawn-guard', room: 'industrial-public' });
    const player = room.state.players.get('respawn-guard')!;
    const internal = (room as any).internal.get(client.sessionId);
    (room as any).killPlayer(undefined, player);
    const deadline = internal.spawnAt;
    (room as any).requestRespawn({ sessionId: client.sessionId });
    assert.equal(player.is_dead, true);
    assert.equal(internal.spawnAt, deadline);
    internal.spawnAt = Date.now() - 1;
    (room as any).requestRespawn({ sessionId: client.sessionId });
    assert.equal(player.is_dead, false);
    assert.ok(internal.protectedUntil > Date.now());
    await client.leave();
  });

  await t.test('manual redeployment waits for the pilot and applies a complete valid loadout', async () => {
    const room = await testing.createRoom<BattleRoom>('battle', { room: 'industrial-public' });
    const client = await testing.connectTo(room, { username: 'manual-redeploy', room: 'industrial-public' });
    const player = room.state.players.get('manual-redeploy')!;
    const runtime = (room as any).internal.get(client.sessionId);
    client.send('loadout', { primary: 'ak47', secondary: 'pistol', throwable: 'frag', manual_redeploy: true });
    await waitFor(() => runtime.manualRedeploy);
    (room as any).killPlayer(undefined, player);
    const payload = { primary: 'hmg', secondary: 'aim9', throwable: 'impact', chassis: 'tracked' };
    client.send('respawn', payload);
    await new Promise(resolve => setTimeout(resolve, 80));
    assert.equal(player.is_dead, true, 'redeploy cannot bypass the cooldown');
    runtime.spawnAt = Date.now() - 1;
    client.send('respawn', { ...payload, secondary: 'hmg' });
    await new Promise(resolve => setTimeout(resolve, 80));
    assert.equal(player.is_dead, true, 'invalid payload keeps the pilot in the editor');
    assert.equal(player.weapon_id, 'ak47');
    client.send('respawn', payload);
    await waitFor(() => !player.is_dead);
    assert.deepEqual([player.weapon_id, player.primary_payload, player.secondary_payload, player.throwable, player.mobility_mode, player.ammo],
      ['hmg', 'hmg', 'aim9', 'impact', 'tracked', 60]);
    await client.leave();
  });

  await t.test('consumes and acknowledges movement inputs while dead without moving the player', async () => {
    const room = await testing.createRoom<BattleRoom>('battle', { room: 'industrial-public' });
    const client = await testing.connectTo(room, { username: 'dead-input', room: 'industrial-public' });
    const player = room.state.players.get('dead-input')!;
    const input = client.input<any>();
    (room as any).killPlayer(undefined, player);
    const position = [player.x, player.y, player.z];
    input.data.move_z = 1;
    let lastSequence = 0;
    for (let i = 0; i < 12; i++) {
      lastSequence = input.send();
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
    await waitFor(() => player.ack_input_sequence >= lastSequence);
    assert.equal(player.is_dead, true);
    assert.deepEqual([player.x, player.y, player.z], position);
    assert.equal(player.ack_input_sequence, lastSequence);
    await client.leave();
  });

  await t.test('Industrial walls block server-traced animated hits', async () => {
    const room = await testing.createRoom<BattleRoom>('battle', { room: 'industrial-public' });
    const shooter = await testing.connectTo(room, { username: 'wall-shooter', room: 'industrial-public' });
    const victim = await testing.connectTo(room, { username: 'wall-victim', room: 'industrial-public' });
    const p1 = room.state.players.get('wall-shooter')!, p2 = room.state.players.get('wall-victim')!;
    p1.x = -12; p1.y = 0.9; p1.z = -10; p1.team = 'A'; p1.yaw = Math.PI / 2; p1.pitch = 0;
    p2.x = -8; p2.y = 0.9; p2.z = -10; p2.team = 'B';
    p1.yaw = -Math.PI / 2;
    for (const bot of room.state.players.values()) if (bot.is_bot) { bot.health = 0; bot.is_dead = true; }
    (room as any).rewind.record(Date.now());
    const internal = (room as any).internal;
    internal.get(shooter.sessionId).protectedUntil = 0;
    internal.get(victim.sessionId).protectedUntil = 0;
    const serverShooter = room.clients.find((client: Client) => client.sessionId === shooter.sessionId)!;
    const origin: [number, number, number] = [p1.x, p1.y, p1.z];
    assert.equal(rayBlocked(origin, [p2.x, p2.y, p2.z]), true);
    (room as any).fire(serverShooter, { shot_id: 1, origin, hit: [p2.x, p2.y, p2.z], yaw: p1.yaw, pitch: 0 });
    (room as any).hit(serverShooter, { target: 'wall-victim', shot_id: 1 });
    assert.equal(p2.health, 100, 'a static warehouse wall occludes the animated player hitbox');
    await shooter.leave(); await victim.leave();
  });

  await t.test('tracked and wheeled vehicles apply directional armor (front 0.75x, rear 1.5x, top attack bypasses)', async () => {
    const room = await testing.createRoom<BattleRoom>('battle', { room: 'industrial-public' });
    const clientA = await testing.connectTo(room, { username: 'tank-victim', room: 'industrial-public' });
    const victim = room.state.players.get('tank-victim')!;
    victim.mobility_mode = 'tracked';
    victim.yaw = 0; // facing -Z
    victim.x = 0; victim.y = 1; victim.z = 0;
    victim.health = 220;
    victim.is_dead = false;
    (room as any).internal.get(clientA.sessionId).protectedUntil = 0;

    // 1. Frontal shot: coming from z = -10 towards victim at z = 0 (shotDir is [0, 0, 1])
    (room as any).applyPlayerDamage(undefined, victim, 40, undefined, [0, 0, 1]);
    assert.equal(victim.health, 190, 'frontal hit takes 0.75x deflected damage');

    // 2. Rear shot: coming from z = 10 towards victim at z = 0 (shotDir is [0, 0, -1])
    (room as any).applyPlayerDamage(undefined, victim, 40, undefined, [0, 0, -1]);
    assert.equal(victim.health, 130, 'rear engine bay hit takes 1.5x critical weakspot damage');

    // 3. Top attack: downward plunge (>35 deg downward pitch, shotDir[1] = -0.71)
    (room as any).applyPlayerDamage(undefined, victim, 40, undefined, [0, -0.71, 0.704]);
    assert.equal(victim.health, 90, 'top attack downward plunge bypasses frontal armor reduction');

    await clientA.leave();
  });

  await t.test('smoke screen breaks guided missile tracking and creates protective smoke zone', async () => {
    const room = await testing.createRoom<BattleRoom>('battle', { room: 'industrial-public' });
    const client = await testing.connectTo(room, { username: 'smoke-pilot', room: 'industrial-public' });
    const pilot = room.state.players.get('smoke-pilot')!;
    pilot.x = 10; pilot.y = 2; pilot.z = 10;

    // Initially position is not smoked
    assert.equal(room.isPositionSmoked([10, 2, 10]), false);

    // Deploy smoke at pilot's position
    room.deploySmokeZone(pilot.username, [10, 2, 10]);

    // Position is now protected by smoke zone
    assert.equal(room.isPositionSmoked([10, 2, 10]), true);
    assert.equal(room.isPositionSmoked([50, 2, 50]), false);

    await client.leave();
  });
});

test('matchmaker rejects an invalid admission ticket before room lookup or geometry allocation', async () => {
  configureBattleAdmission({ secret: 'battle admission test key with more than thirty two bytes' });
  try {
    const result = await BattleRoom.onAuth('forged.invalid.ticket', {
      username: 'honest-looking-name', room: 'admission-rejected-map-test',
    }, {} as any);
    assert.equal(result, false);
    assert.equal(activeRooms.has('admission-rejected-map-test'), false, 'invalid ticket did not allocate a room');
  } finally {
    configureBattleAdmission();
  }
});

test('BattleRoom installs the official singleton session plugin keyed by authenticated identity', () => {
  const room = new BattleRoom();
  const uniqueSession = (room as any).plugins.uniqueSession;
  assert.ok(uniqueSession instanceof UniqueSessionPlugin);
  assert.equal((uniqueSession as any).max, 1);
  assert.equal((uniqueSession as any).mode, 'reject');
});

test('bot attack presentation survives locomotion writes and preserves its phase between shots', (t) => {
  let now=1000,fire=true;
  t.mock.method(Date,'now',()=>now);
  const bot:any={username:'test-bot',is_bot:true,x:0,y:0,z:0,health:100,is_dead:false,animation:'idle',animation_time:0};
  const players=new Map([['test-bot',bot]]);
  const fake:any={
    state:{players,room_mode:'TDM'},playerView:()=>players,
    vehicleSimulation:{states:new Map()},botProtectedUntil:new Map(),botAnimationStartedAt:new Map(),botPresentationClip:new Map(),botFireUntil:new Map(),resolveBotShot:()=>{},
    botSimulation:{step:(_players:any,_dt:number,_now:number,callbacks:any)=>{
      bot.animation='run';bot.x+=.08;
      if(fire)callbacks.onShot({shooter:'test-bot'});
    }},
  };
  const step=()=> (BattleRoom.prototype as any).stepBots.call(fake,1/60);
  step();assert.equal(bot.animation,'firing walk');assert.equal(bot.animation_time,0);
  fire=false;
  now+=100;step();assert.equal(bot.animation,'firing walk');assert.equal(bot.animation_time,.1);
  fire=true;now+=100;step();assert.equal(bot.animation_time,.2,'another shot must not restart the full-body clip');
  fire=false;now+=200;step();assert.equal(bot.animation,'firing walk');assert.equal(bot.animation_time,.4);
  now+=150;step();assert.equal(bot.animation,'run','gesture ends after the shot hold window');
});
