import assert from 'node:assert/strict';
import test from 'node:test';
import { DRONE_MAX_ALTITUDE, DRONE_RADIUS, DRONE_SPAWN_OFFSET, stepDroneFlight, type DroneInput } from './drone-flight.js';
import { loadWorldGeometry, PLAYABLE_MAPS, type Vec3, type WorldGeometry } from './world-geometry.js';

const industrial = loadWorldGeometry('industrial')!;
const idle: DroneInput = { move_x: 0, move_y: 0, move_z: 0, yaw: 0, sprint: 0 };
const flightAt = (geometry: WorldGeometry, position: Vec3, velocity: Vec3 = [0, 0, 0], input: DroneInput = idle, ticks = 1) => {
  let state = { position: [...position] as Vec3, velocity: [...velocity] as Vec3 };
  for (let tick = 0; tick < ticks; tick++) state = stepDroneFlight(geometry, state.position, state.velocity, input, 1 / 60);
  return state;
};

test('neutral input holds altitude in midair without gravity', () => {
  const start: Vec3 = [0, 40, 0];
  const end = flightAt(industrial, start, [0, 0, 0], idle, 120);
  assert.deepEqual(end.position, start);
  assert.deepEqual(end.velocity, [0, 0, 0]);
});

test('vertical commands continuously ascend and descend in midair', () => {
  const start: Vec3 = [0, 40, 0];
  const climb = flightAt(industrial, start, [0, 0, 0], { ...idle, move_y: 1 }, 30);
  assert.ok(climb.position[1] > start[1] + 0.5, `climb should gain height: ${climb.position[1]}`);
  const descend = flightAt(industrial, climb.position, climb.velocity, { ...idle, move_y: -1 }, 30);
  assert.ok(descend.position[1] < climb.position[1] - 0.5, `descent should lose height: ${descend.position[1]}`);
  assert.ok(descend.position[1] > 0, 'a two second flight remains in the playable altitude range');
});

test('mobility profiles change authoritative movement while sharing the same collision solver', () => {
  const midair: Vec3 = [0, 40, 0];
  const climb = flightAt(industrial, midair, [0,0,0], { ...idle, move_y: 1, mobility_mode: 'heli' }, 30);
  const floor = industrial.floorHeight(0, 0, 10)!;
  const start: Vec3 = [0, floor + DRONE_RADIUS, 0];
  const tracked = flightAt(industrial, start, [0,0,0], { ...idle, move_y: 1, move_z: 1, mobility_mode: 'tracked' }, 60);
  const wheels = flightAt(industrial, start, [0,0,0], { ...idle, move_y: 1, move_z: 1, mobility_mode: 'wheels' }, 60);
  const wing = flightAt(industrial, midair, [0,0,0], { ...idle, move_z: 1, mobility_mode: 'wing' }, 60);
  assert.ok(climb.position[1] > midair[1] + 1, 'helicopter profile can climb');
  assert.ok(Math.abs(tracked.position[1]-(floor+DRONE_RADIUS))<0.02, 'tracked profile stays in ground contact without flight lift');
  assert.ok(Math.abs(wheels.position[1]-(floor+DRONE_RADIUS))<0.02, 'wheeled profile stays in ground contact without flight lift');
  assert.ok(Math.abs(wheels.velocity[2])>Math.abs(tracked.velocity[2]), 'wheels are faster than continuous tracks');
  assert.ok(wing.position[1] < midair[1], 'fixed wing cannot lift before forward airspeed builds');
  assert.ok(Math.abs(tracked.velocity[2]) < 5, 'tracked profile has a reduced ground speed');
  assert.ok(Math.abs(wing.velocity[2]) > Math.abs(tracked.velocity[2]), 'fixed wing profile has a faster forward cruise');
});

test('wing pull-up responds promptly and heli S descends without reverse thrust', () => {
  const position: Vec3 = [0, 40, 0];
  const climb = flightAt(industrial, position, [0, 0, -11], { ...idle, mobility_mode: 'wing', move_z: 1, move_y: 1 }, 30);
  assert.ok(climb.position[1] > 42.5, 'full pull-up gains at least 2.5m in half a second at cruise');
  const descend = flightAt(industrial, position, [0, 0, 0], { ...idle, mobility_mode: 'heli', move_z: -1 }, 60);
  assert.ok(descend.position[1] < 38 && descend.position[1] > 37.4);
  assert.equal(descend.position[2], 0, 'S supplies no reverse thrust');
});

test('fixed wing carries forward momentum off throttle and cannot strafe or reverse from rest', () => {
  const position: Vec3 = [0, 40, 0];
  const glide = flightAt(industrial, position, [0, 0, -11], { ...idle, mobility_mode: 'wing' }, 30);
  assert.ok(glide.position[2] < -3, 'aircraft glides when the throttle is released');
  const reverse = flightAt(industrial, position, [0, 0, 0], { ...idle, move_x: 1, move_z: -1, mobility_mode: 'wing' }, 30);
  assert.equal(reverse.position[0], 0);
  assert.equal(reverse.position[2], 0);
  assert.ok(reverse.position[1] < position[1]);
});

test('tracked steering rejects sideways throttle and lateral momentum', () => {
  const start: Vec3 = [0, 40, 0];
  const turn = flightAt(industrial, start, [0, 0, 0], { ...idle, mobility_mode: 'tracked', move_x: 1 });
  assert.equal(turn.position[0], start[0]);
  assert.equal(turn.position[2], start[2]);
  const drive = flightAt(industrial, start, [0, 0, 3], {
    ...idle, mobility_mode: 'tracked', move_x: 1, move_z: 1, yaw: Math.PI / 2,
  });
  assert.ok(drive.position[0] < start[0]);
  assert.equal(drive.position[2], start[2]);
});

test('boost speed is bounded and neutral input actively brakes', () => {
  const boost = flightAt(industrial, [0, 40, 0], [0, 0, 0], { ...idle, move_z: 1, sprint: 1 }, 120);
  assert.ok(Math.hypot(...boost.velocity) <= 14.01, `boost velocity exceeded limit: ${boost.velocity}`);
  assert.ok(Math.abs(boost.velocity[1]) <= 9.01);
  const cruise = flightAt(industrial, [0, 40, 0], [0, 0, 0], { ...idle, move_z: 1 }, 35);
  assert.ok(Math.abs(cruise.velocity[2]) > 5, `expected established cruise speed: ${cruise.velocity}`);
  const braked = flightAt(industrial, cruise.position, cruise.velocity, idle, 30);
  assert.ok(Math.hypot(...braked.velocity) < 0.1, `neutral input should actively brake: ${braked.velocity}`);
});

test('released input zeros low residual velocity and remains position-stable for thirty ticks', () => {
  let state = { position: [0, 40, 0] as Vec3, velocity: [0.06, 0, 0] as Vec3 };
  for (let tick = 0; tick < 30; tick++) state = stepDroneFlight(industrial, state.position, state.velocity, idle, 1 / 60);
  const settledPosition = [...state.position];
  for (let tick = 0; tick < 30; tick++) state = stepDroneFlight(industrial, state.position, state.velocity, idle, 1 / 60);
  assert.deepEqual(state.velocity, [0, 0, 0]);
  assert.deepEqual(state.position, settledPosition, 'zeroed integrator velocity keeps the last thirty frames stationary');
});

test('sphere flight slides along the Industrial warehouse wall without stepping or clipping', () => {
  const floor = industrial.floorHeight(-12, -10, 2);
  assert.notEqual(floor, undefined);
  const startFloor = industrial.floorHeight(-12, -15, 2);
  assert.notEqual(startFloor, undefined);
  const start: Vec3 = [-12, startFloor! + 0.9, -15];
  const destination: Vec3 = [-8, startFloor! + 0.9, -12];
  const resolved = industrial.resolveFlightMove(start, destination, DRONE_RADIUS);
  assert.ok(resolved[0] < -10.2, `sphere should stop at the wall face: ${resolved}`);
  assert.ok(resolved[0] > start[0], `sphere should make progress toward the wall: ${resolved}`);
  assert.ok(resolved[2] > start[2] + 2, `sphere should slide along the wall: ${resolved}`);
  assert.ok(resolved[1] <= start[1] + 0.02, `sphere collision must not step upward: ${resolved}`);
  assert.equal(industrial.rayBlocked(start, resolved), false, 'resolved center remains outside the wall');
});

test('flight respects the 120 metre ceiling', () => {
  const start: Vec3 = [500, DRONE_MAX_ALTITUDE - 0.1, 500];
  const result = flightAt(industrial, start, [0, 0, 0], { ...idle, move_y: 1 }, 120);
  assert.ok(result.position[1] <= DRONE_MAX_ALTITUDE + 1e-6);
  assert.ok(Math.abs(result.position[1] - DRONE_MAX_ALTITUDE) < 1e-5);
  assert.ok(Math.abs(result.velocity[1]) < 0.01, `ceiling contact should stop vertical velocity: ${result.velocity}`);
});

test('invalid flight coordinates fail closed', () => {
  const fallback = stepDroneFlight(industrial, [Number.NaN, 2, 3], [1, 2, 3], idle, 1 / 60);
  assert.deepEqual(fallback.position, [industrial.spawns[0][0], industrial.spawns[0][1] + DRONE_SPAWN_OFFSET, industrial.spawns[0][2]]);
  assert.deepEqual(fallback.velocity, [0, 0, 0]);
  const rejected = stepDroneFlight(industrial, [4, 40, 5], [1, 2, 3], { ...idle, move_z: Number.POSITIVE_INFINITY }, 1 / 60);
  assert.deepEqual(rejected.position, [4, 40, 5]);
  assert.deepEqual(rejected.velocity, [0, 0, 0]);
});

test('drone sphere collides with authored parked car chassis in Industrial and Village', () => {
  for (const map of ['industrial', 'village'] as const) {
    const geometry = loadWorldGeometry(map)!;
    assert.ok(geometry.vehicleSpawns.length > 0, `${map} has authored parked cars`);
    const [carX, carY, carZ, yaw] = geometry.vehicleSpawns[0];
    const c = Math.cos(yaw), s = Math.sin(yaw);
    for (const [label, height, localZ] of [['chassis', 0.95, 0], ['cabin', 1.95, 0.2]] as const) {
      const atLocalX = (distance: number): Vec3 => [carX + c * distance, carY + height, carZ + localZ - s * distance];
      const start = atLocalX(-4), destination = atLocalX(4);
      const resolved = geometry.resolveFlightMove(start, destination, DRONE_RADIUS);
      const localX = (resolved[0] - carX) * c - (resolved[2] - carZ) * s;
      assert.ok(localX < -1.05, `${map} drone sphere clipped through the parked ${label} OBB at localX=${localX}`);
      assert.ok(localX > -2, `${map} ${label} contact pushed the drone implausibly far from the chassis at localX=${localX}`);
      assert.ok(Math.abs(resolved[1] - start[1]) < 0.35, `${map} parked ${label} OBB contact remains bounded vertically`);
    }
  }
});

test('every authored spawn can run the fixed 120 tick flight command sequence', () => {
  for (const map of PLAYABLE_MAPS) {
    const geometry = loadWorldGeometry(map)!;
    assert.equal(geometry.spawns.length, 12, `${map} retains twelve authored starts`);
    for (const [spawnIndex, spawn] of geometry.spawns.entries()) {
      let position: Vec3 = [spawn[0], spawn[1] + DRONE_SPAWN_OFFSET, spawn[2]], velocity: Vec3 = [0, 0, 0];
      for (let tick = 0; tick < 120; tick++) {
        const command: DroneInput = tick < 45
          ? { move_x: 0, move_y: 0, move_z: 1, yaw: 0.37, sprint: tick >= 15 && tick < 30 ? 1 : 0 }
          : tick < 75
            ? { move_x: 0, move_y: 1, move_z: 0, yaw: 0.37, sprint: 0 }
            : tick < 100
              ? { move_x: 1, move_y: -1, move_z: 0, yaw: 0.37, sprint: 0 }
              : { ...idle, yaw: 0.37 };
        const next = stepDroneFlight(geometry, position, velocity, command, 1 / 60);
        position = next.position; velocity = next.velocity;
        assert.ok(position.every(Number.isFinite), `${map} spawn ${spawnIndex} produced invalid position at tick ${tick}`);
        assert.ok(velocity.every(Number.isFinite), `${map} spawn ${spawnIndex} produced invalid velocity at tick ${tick}`);
      }
    }
  }
});
