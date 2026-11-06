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
    client.send('grenade', { pos: [vx, vy + 1.2, vz], vel: [0, 2, 0], throwable: 'frag', request_id: 123 });
    await waitFor(() => player.grenades === 1);
    const accepted = await Promise.race([receivedGrenade, new Promise((resolve) => setTimeout(() => resolve(null), 1000))]) as any;
    assert.ok(accepted);
    assert.equal(accepted.request_id, 123, 'accepted throw echoes the optimistic request key');
    const duplicateRejection = new Promise<any>((resolve) => client.onMessage('grenade_rejected', resolve));
    client.send('grenade', { pos: [vx, vy + 1.2, vz], vel: [0, 2, 0], throwable: 'frag', request_id: 123 });
    const duplicate = await Promise.race([duplicateRejection, new Promise((resolve) => setTimeout(() => resolve(null), 1000))]) as any;
    assert.ok(duplicate);
    assert.equal(duplicate.request_id, 123, 'duplicate request keys are rejected');
    assert.equal(player.grenades, 1, 'duplicate request does not consume a second grenade');
    const rejectedGrenade = new Promise<any>((resolve) => client.onMessage('grenade_rejected', resolve));
    client.send('grenade', { pos: [vx, vy + 1.2, vz], vel: [0, 2, 0], throwable: 'frag', request_id: 124 });
    const rejected = await Promise.race([rejectedGrenade, new Promise((resolve) => setTimeout(() => resolve(null), 1000))]) as any;
    assert.ok(rejected);
    assert.equal(rejected.request_id, 124, 'server validation rejection settles the matching prediction');
    assert.equal(player.grenades, 1, 'rejected throw does not consume server inventory');
    client.send('vehicle_seat', { id: 'CAR_0', enter: true });
    await waitFor(() => player.driving_vehicle === 'CAR_0' && vehicle.driver === 'module-smoke');
    const startX = vehicle.pos[0], startZ = vehicle.pos[2];
    const vehicleInput = client.input<any>({ mode: 'reliable' });
    for (let tick = 0; tick < 60 && Math.hypot(vehicle.pos[0] - startX, vehicle.pos[2] - startZ) <= 0.02; tick++) {
      Object.assign(vehicleInput.data, {
        vehicle_throttle: 1, vehicle_steer: 0, vehicle_brake: 0, vehicle_gear: 1,
        vehicle_index: player.vehicle_index, vehicle_generation: player.vehicle_generation,
      });
      vehicleInput.send();
      await new Promise((resolve) => setTimeout(resolve, 1000 / 60));
    }
    assert.ok(vehicle.speed > 0.1, 'server applies buffered vehicle input');
    assert.ok(Math.hypot(vehicle.pos[0] - startX, vehicle.pos[2] - startZ) > 0.02, 'buffered input moves the authoritative vehicle');
    assert.equal(player.animation_code, 5);
    await client.leave();
  });

  await t.test('death and dropped connections forcibly release vehicle seats and invalidate old inputs', async () => {
    const room = await testing.createRoom<BattleRoom>('battle', { room: 'industrial-public' });
    const client = await testing.connectTo(room, { username: 'seat-lifecycle', room: 'industrial-public' });
    const player = room.state.players.get('seat-lifecycle')!;
    const vehicle = room.state.vehicles.get('CAR_0')!;
    player.x = vehicle.pos[0]; player.y = vehicle.pos[1]; player.z = vehicle.pos[2];
    (room as any).vehicleSeat(client, { id: vehicle.id, enter: true });
    assert.equal(player.driving_vehicle, vehicle.id);
    const oldIndex = player.vehicle_index, oldGeneration = player.vehicle_generation;
    (room as any).killPlayer(undefined, player);
    assert.equal(vehicle.driver, '');
    assert.equal(player.driving_vehicle, '');
    assert.equal(player.vehicle_index, -1);
    assert.ok(player.vehicle_generation > oldGeneration);
    assert.equal((room as any).vehicleSimulation.input((room as any).vehiclePlayer(player), {
      throttle: 1, steer: 0, brake: false, gear: 2, vehicleIndex: oldIndex, vehicleGeneration: oldGeneration,
    }, Date.now()), false);

    player.is_dead = false; player.health = 100;
    player.x = vehicle.pos[0]; player.y = vehicle.pos[1]; player.z = vehicle.pos[2];
    (room as any).vehicleSeat(client, { id: vehicle.id, enter: true });
    assert.equal(player.driving_vehicle, vehicle.id);
    const reconnectIndex = player.vehicle_index, reconnectGeneration = player.vehicle_generation;
    (room as any).allowReconnection = async () => { throw new Error('test drop window ended'); };
    await (room as any).onDrop(client);
    assert.equal(vehicle.driver, '');
    assert.equal(player.driving_vehicle, '');
    assert.equal(player.vehicle_index, -1);
    assert.ok(player.vehicle_generation > reconnectGeneration);
    assert.equal((room as any).vehicleSimulation.input((room as any).vehiclePlayer(player), {
      throttle: 1, steer: 0, brake: false, gear: 2, vehicleIndex: reconnectIndex, vehicleGeneration: reconnectGeneration,
    }, Date.now()), false);
    await client.leave();
  });

  await t.test('SDK reconnect releases the old vehicle epoch and accepts fresh inputs after re-entry', async () => {
    const room = await testing.createRoom<BattleRoom>('battle', { room: 'industrial-public' });
    const client = await testing.connectTo(room, { username: 'vehicle-reconnect', room: 'industrial-public' });
    client.onMessage('identity', () => {});
    const player = room.state.players.get('vehicle-reconnect')!;
    const vehicle = room.state.vehicles.get('CAR_0')!;
    player.x = vehicle.pos[0]; player.y = vehicle.pos[1]; player.z = vehicle.pos[2];
    client.send('vehicle_seat', { id: vehicle.id, enter: true });
    await waitFor(() => player.driving_vehicle === vehicle.id && vehicle.driver === player.username);
    const oldIndex = player.vehicle_index, oldGeneration = player.vehicle_generation;
    const input = client.input<any>({ mode: 'reliable' });
    const sendControl = (index: number, generation: number, throttle: number) => {
      Object.assign(input.data, { vehicle_throttle: throttle, vehicle_steer: 0, vehicle_brake: 0, vehicle_gear: 1, vehicle_index: index, vehicle_generation: generation });
      input.send();
    };
    const startZ = vehicle.pos[2];
    for (let tick = 0; tick < 30 && Math.abs(vehicle.pos[2] - startZ) < 0.08; tick++) {
      sendControl(oldIndex, oldGeneration, 1);
      await new Promise((resolve) => setTimeout(resolve, 1000 / 60));
    }
    assert.ok(Math.abs(vehicle.pos[2] - startZ) >= 0.08, 'vehicle had active nonzero input before transport loss');

    client.reconnection.minUptime = 0;
    const reconnected = new Promise<void>((resolve) => client.onReconnect.once(resolve));
    client.connection.close();
    await waitFor(() => player.driving_vehicle === '' && vehicle.driver === '');
    assert.ok(player.vehicle_generation > oldGeneration);
    await Promise.race([reconnected, new Promise((_, reject) => setTimeout(() => reject(new Error('SDK vehicle reconnect timed out')), 5000))]);

    const stoppedAt = vehicle.pos[2];
    sendControl(oldIndex, oldGeneration, 1);
    await waitFor(() => player.ack_input_sequence > 0);
    await new Promise((resolve) => setTimeout(resolve, 150));
    assert.ok(Math.abs(vehicle.pos[2] - stoppedAt) < 0.1, 'stale pre-drop input does not resume vehicle motion');

    client.send('vehicle_seat', { id: vehicle.id, enter: true });
    await waitFor(() => player.driving_vehicle === vehicle.id && vehicle.driver === player.username);
    const freshGeneration = player.vehicle_generation;
    assert.ok(freshGeneration > oldGeneration);
    const reentryStart = vehicle.pos[2];
    const priorAck = player.ack_input_sequence;
    for (let tick = 0; tick < 30 && Math.abs(vehicle.pos[2] - reentryStart) < 0.08; tick++) {
      sendControl(player.vehicle_index, freshGeneration, 1);
      await new Promise((resolve) => setTimeout(resolve, 1000 / 60));
    }
    await waitFor(() => player.ack_input_sequence > priorAck);
    assert.ok(Math.abs(vehicle.pos[2] - reentryStart) >= 0.08, 'fresh seat epoch resumes acknowledged authoritative motion');
    await client.leave();
  });

  await t.test('preserves weapon magazines across switches and completes reloads', async () => {
    const room = await testing.createRoom<BattleRoom>('battle', { room: 'industrial-public' });
    const client = await testing.connectTo(room, { username: 'ammo', room: 'industrial-public' });
    const player = room.state.players.get('ammo')!;
    const internal = (room as any).internal.get(client.sessionId);
    player.ammo = 7; internal.ammoByWeapon.ak47 = 7;
    (room as any).selectWeapon(client.sessionId, 'pistol');
    assert.equal(player.ammo, 12);
    player.ammo = 3; internal.ammoByWeapon.pistol = 3;
    (room as any).selectWeapon(client.sessionId, 'ak47');
    assert.equal(player.ammo, 7);
    (room as any).selectWeapon(client.sessionId, 'pistol');
    assert.equal(player.ammo, 3);
    (room as any).reload({ sessionId: client.sessionId });
    assert.equal((room as any).internal.get(client.sessionId).reloadUntil > Date.now(), true);
    (room as any).selectWeapon(client.sessionId, 'ak47');
    assert.equal(player.weapon_id, 'pistol', 'cannot switch during reload');
    await new Promise((resolve) => setTimeout(resolve, 1550));
    assert.equal(player.ammo, 12);
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
    p1.x = a[0]; p1.y = a[1]; p1.z = a[2]; p1.team = 'A'; p1.yaw = 0; p1.pitch = 0; // stale consumed movement aim
    p2.x = b[0]; p2.y = b[1]; p2.z = b[2]; p2.team = 'B';
    for (const bot of room.state.players.values()) if (bot.is_bot) { bot.health = 0; bot.is_dead = true; }
    (room as any).rewind.record(Date.now());
    (room as any).internal.get(shooter.sessionId).protectedUntil = 0;
    (room as any).internal.get(victim.sessionId).protectedUntil = 0;
    const serverShooter = room.clients.find((client: Client) => client.sessionId === shooter.sessionId)!;
    const origin: [number, number, number] = [p1.x, p1.y + 1.2, p1.z];
    const fire = (room as any).fire.bind(room);
    const hit = (room as any).hit.bind(room);
    const firstHitPoint: [number, number, number] = [p2.x, p2.y + 1.2, p2.z];
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
    assert.equal(p1.ammo, afterAmmo, 'weapon cadence rejects an immediate next shot');
    await shooter.leave(); await victim.leave();
  });

  await t.test('framework rewind preserves run→firing→jump clip, phase and quaternion at each shot', async () => {
    const room = await testing.createRoom<BattleRoom>('battle', { room: 'industrial-public' });
    const shooter = await testing.connectTo(room, { username: 'timeline-shooter', room: 'industrial-public' });
    await testing.connectTo(room, { username: 'timeline-target', room: 'industrial-public' });
    const source = room.state.players.get('timeline-shooter')!, target = room.state.players.get('timeline-target')!;
    const from: [number, number, number] = [-22, 0, -10], to: [number, number, number] = [-22, 0, 0];
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
      runtime.lastShot = Date.now() - 1000;
      (room as any).fire(serverShooter, { shot_id: shotId++, origin: [from[0], from[1] + 1.2, from[2]], yaw, pitch: 0 });
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
    const start = INDUSTRIAL_SPAWNS[0], middle: [number, number, number] = [-22, 1.3, -10], end: [number, number, number] = [-22, 1.3, 0];
    p1.x = start[0]; p1.y = start[1]; p1.z = start[2]; p1.team = 'A'; p1.yaw = 0; p1.pitch = 0;
    ally.x = middle[0]; ally.y = middle[1]; ally.z = middle[2]; ally.team = 'A';
    p2.x = end[0]; p2.y = end[1]; p2.z = end[2]; p2.team = 'B';
    for (const bot of room.state.players.values()) if (bot.is_bot) { bot.health = 0; bot.is_dead = true; }
    (room as any).rewind.record(Date.now());
    const internal = (room as any).internal;
    internal.get(shooter.sessionId).protectedUntil = 0;
    internal.get(victim.sessionId).protectedUntil = Date.now() + 2500;
    const serverShooter = room.clients.find((client: Client) => client.sessionId === shooter.sessionId)!;
    const origin: [number, number, number] = [p1.x, p1.y + 1.2, p1.z];
    (room as any).fire(serverShooter, { shot_id: 1, origin, hit: end, yaw: Math.PI, pitch: 0 });
    (room as any).hit(serverShooter, { target: 'guard-victim', shot_id: 1 });
    assert.equal(p2.health, 100, 'spawn protection prevents damage');
    internal.get(victim.sessionId).protectedUntil = 0;
    internal.get(shooter.sessionId).lastShot = Date.now() - 2000;
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
    p1.x = -12; p1.y = 0; p1.z = -10; p1.team = 'A'; p1.yaw = Math.PI / 2; p1.pitch = 0;
    p2.x = -8; p2.y = 0; p2.z = -10; p2.team = 'B';
    p1.yaw = -Math.PI / 2;
    for (const bot of room.state.players.values()) if (bot.is_bot) { bot.health = 0; bot.is_dead = true; }
    (room as any).rewind.record(Date.now());
    const internal = (room as any).internal;
    internal.get(shooter.sessionId).protectedUntil = 0;
    internal.get(victim.sessionId).protectedUntil = 0;
    const serverShooter = room.clients.find((client: Client) => client.sessionId === shooter.sessionId)!;
    const origin: [number, number, number] = [p1.x, p1.y + 1.2, p1.z];
    assert.equal(rayBlocked(origin, [p2.x, p2.y + 1.2, p2.z]), true);
    (room as any).fire(serverShooter, { shot_id: 1, origin, hit: [p2.x, p2.y + 1.2, p2.z], yaw: p1.yaw, pitch: 0 });
    (room as any).hit(serverShooter, { target: 'wall-victim', shot_id: 1 });
    assert.equal(p2.health, 100, 'a static warehouse wall occludes the animated player hitbox');
    await shooter.leave(); await victim.leave();
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
