import assert from 'node:assert/strict';
import test from 'node:test';
import { INDUSTRIAL_VEHICLE_SPAWNS, loadWorldGeometry } from './world-geometry.js';
import { inputIsFromStaleVehicleSeat, VehicleSimulation, stepVehicleMotion, type VehiclePlayer } from './vehicle-simulation.js';

function player(username: string, x: number, y: number, z: number): VehiclePlayer {
  return { username, x, y, z, health: 100, deaths: 0, team: 'A', is_dead: false, driving_vehicle: '', vehicle_index: -1, vehicle_generation: 0 };
}

test('vehicles use authored spawns and validate exclusive seat entry/exit', () => {
  const sim = new VehicleSimulation();
  assert.equal(sim.states.size, INDUSTRIAL_VEHICLE_SPAWNS.length);
  const car = sim.states.get('CAR_0')!;
  assert.equal(car.health, 1200);
  const driver = player('driver', car.pos[0], car.pos[1], car.pos[2]);
  const second = player('second', car.pos[0], car.pos[1], car.pos[2]);
  assert.equal(sim.enter(driver, car.id, 1000), true);
  assert.equal(car.driverGeneration, 1);
  assert.equal(driver.driving_vehicle, car.id);
  assert.equal(sim.enter(second, car.id, 1000), false, 'a vehicle has one authoritative driver');
  assert.equal(sim.exit(driver), true);
  assert.equal(driver.driving_vehicle, '');
  assert.equal(sim.enter(driver, car.id, 1200), true);
  assert.equal(car.driverGeneration, 3, 'exit and re-entry advance the seat generation');
  assert.equal(sim.input(driver, { throttle: 1, steer: 0, brake: false, gear: 2, vehicleIndex: 0, vehicleGeneration: 1 }, 1201), false, 'a frame from the prior seat epoch cannot drive the new seat');
});

test('unoccupied vehicles keep a stable seat generation across simulation ticks', () => {
  const sim = new VehicleSimulation();
  const car = sim.states.get('CAR_0')!;
  const generation = car.driverGeneration;
  for (let tick = 1; tick <= 120; tick++) sim.step(1 / 60, 1000 + tick * (1000 / 60), new Map());
  assert.equal(car.driver, '');
  assert.equal(car.driverGeneration, generation, 'parked cars do not publish a new seat epoch every tick');
});

test('forced cleanup repairs an orphaned player-side seat without disturbing another driver', () => {
  const sim = new VehicleSimulation();
  const car = sim.states.get('CAR_0')!;
  const actualDriver = player('actual-driver', ...car.pos);
  const stalePlayer = player('stale-player', ...car.pos);
  assert.equal(sim.enter(actualDriver, car.id, 1000), true);
  stalePlayer.driving_vehicle = car.id; stalePlayer.vehicle_index = 0; stalePlayer.vehicle_generation = car.driverGeneration;
  const generation = stalePlayer.vehicle_generation;
  assert.equal(sim.forceExit(stalePlayer), true);
  assert.equal(stalePlayer.driving_vehicle, '');
  assert.equal(stalePlayer.vehicle_index, -1);
  assert.ok(stalePlayer.vehicle_generation > generation);
  assert.equal(car.driver, actualDriver.username, 'cleanup cannot evict the vehicle’s current owner');
});

test('vehicle prediction step is deterministic and returns collision candidate separately', () => {
  const car = new VehicleSimulation().states.get('CAR_0')!;
  const input = { throttle: 0.7, steer: -0.25, brake: false, gear: 2 };
  const a = stepVehicleMotion(car, input, 1 / 60);
  const b = stepVehicleMotion(car, input, 1 / 60);
  assert.deepEqual(a, b);
  assert.notDeepEqual(a.candidate, car.pos);
  assert.deepEqual(a.pos, car.pos, 'pure helper does not mutate the input state');
});

test('buffered driving frames after seat exit are fenced from infantry controls', () => {
  const sim = new VehicleSimulation();
  const car = sim.states.get('CAR_0')!;
  const driver = player('driver', ...car.pos);
  assert.equal(sim.enter(driver, car.id, 1000), true);
  const oldIndex = driver.vehicle_index, oldGeneration = driver.vehicle_generation;
  assert.equal(sim.exit(driver), true);
  assert.equal(driver.vehicle_index, -1);
  assert.equal(inputIsFromStaleVehicleSeat(oldIndex, oldGeneration, driver.vehicle_index, driver.vehicle_generation), true);
  assert.equal(inputIsFromStaleVehicleSeat(-1, driver.vehicle_generation, driver.vehicle_index, driver.vehicle_generation), false);
});

test('death or disconnect releases the authoritative seat and fences buffered controls', () => {
  for (const cleanup of ['death', 'disconnect'] as const) {
    const sim = new VehicleSimulation();
    const car = sim.states.get('CAR_0')!;
    const driver = player(`driver-${cleanup}`, ...car.pos);
    assert.equal(sim.enter(driver, car.id, 1000), true);
    const oldGeneration = driver.vehicle_generation;
    if (cleanup === 'death') driver.is_dead = true;

    sim.step(1 / 30, 1033, cleanup === 'death' ? new Map([[driver.username, driver]]) : new Map());

    assert.equal(car.driver, '');
    assert.equal(car.speed, 0);
    if (cleanup === 'death') {
      assert.equal(driver.driving_vehicle, '');
      assert.equal(driver.vehicle_index, -1);
    }
    assert.ok(car.driverGeneration > oldGeneration);
    if (cleanup === 'death') {
      assert.ok(driver.vehicle_generation > oldGeneration);
      assert.equal(sim.enter(driver, car.id, 1100), false, 'a dead player cannot reclaim the seat');
      driver.is_dead = false;
      assert.equal(sim.enter(driver, car.id, 1200), true);
      assert.equal(sim.input(driver, { throttle: 1, steer: 0, brake: false, gear: 2, vehicleIndex: 0, vehicleGeneration: oldGeneration }, 1201), false);
    }
  }
});

test('destroyed occupied vehicle releases its driver before the respawn delay', () => {
  const sim = new VehicleSimulation();
  const car = sim.states.get('CAR_0')!;
  const driver = player('destroyed-driver', ...car.pos);
  assert.equal(sim.enter(driver, car.id, 1000), true);
  const generation = driver.vehicle_generation;
  assert.deepEqual(sim.damage(car.id, 1200, 1010), { destroyed: true, driver: driver.username });
  sim.step(1 / 30, 1033, new Map([[driver.username, driver]]));
  assert.equal(car.driver, '');
  assert.equal(driver.driving_vehicle, '');
  assert.equal(driver.vehicle_index, -1);
  assert.ok(driver.vehicle_generation > generation);
  assert.equal(car.health, 0, 'seat release does not bypass the vehicle respawn delay');
});

test('vehicle chassis OBB blocks shot rays with nearest-hit fraction and can ignore its own driver', () => {
  const sim = new VehicleSimulation();
  const car = sim.states.get('CAR_0')!;
  const from: [number, number, number] = [car.pos[0], car.pos[1] + 1.5, car.pos[2] - 10];
  const to: [number, number, number] = [car.pos[0], car.pos[1] + 1.5, car.pos[2] + 10];
  const hit = sim.rayHit(from, to);
  assert.equal(hit?.id, car.id);
  assert.ok(hit && hit.fraction > 0 && hit.fraction < 1);
  assert.equal(sim.blocksRay(from, to), true);
  const driver = player('ray-driver', ...car.pos);
  assert.equal(sim.enter(driver, car.id, 1000), true);
  assert.equal(sim.rayHit(from, to, driver.username), null);
});

test('vehicle simulation accepts an independently loaded non-Industrial map geometry', () => {
  const geometry = loadWorldGeometry('desert_oasis')!;
  const sim = new VehicleSimulation(geometry);
  assert.equal(sim.states.size, geometry.vehicleSpawns.length);
  const car = sim.states.get('CAR_0')!;
  assert.ok(Math.abs(car.pos[0] - geometry.vehicleSpawns[0][0]) < 0.001);
  assert.ok(Math.abs(car.pos[2] - geometry.vehicleSpawns[0][2]) < 0.001);
});

test('vehicle input is bounded, authoritative, and fails safe when it goes stale', () => {
  const sim = new VehicleSimulation();
  const car = sim.states.get('CAR_0')!;
  const driver = player('driver', ...car.pos);
  assert.equal(sim.enter(driver, car.id, 1000), true);
  assert.equal(sim.input(driver, { throttle: 1, steer: 0, brake: false, gear: 2, vehicleIndex: driver.vehicle_index, vehicleGeneration: driver.vehicle_generation }, 1000), true);
  const start = [...car.pos];
  for (let tick = 1; tick <= 20; tick++) sim.step(1 / 30, 1000 + tick * 33, new Map([[driver.username, driver]]));
  assert.ok(Math.hypot(car.pos[0] - start[0], car.pos[2] - start[2]) > 0.2);
  assert.equal(car.gear, 2);
  const previousSpeed = car.speed;
  const moved = [...car.pos];
  sim.step(1 / 30, 3000, new Map([[driver.username, driver]]));
  assert.ok(car.speed < previousSpeed, 'stale input brakes vehicle');
  assert.ok(Math.hypot(car.pos[0] - moved[0], car.pos[2] - moved[2]) < 0.1, 'stale input yields only one short braking step');
  assert.equal(sim.input(driver, { throttle: Number.NaN, steer: 0, brake: false, gear: 1, vehicleIndex: driver.vehicle_index, vehicleGeneration: driver.vehicle_generation }, 3001), false);
});

test('vehicle damage destroys then respawns at the authored location after the Go delay', () => {
  const sim = new VehicleSimulation();
  const car = sim.states.get('CAR_0')!;
  const spawnPosition = [...car.pos];
  assert.deepEqual(sim.damage(car.id, 1200, 2000), { destroyed: true, driver: '' });
  assert.equal(car.health, 0);
  sim.step(1 / 30, 21_999, new Map());
  assert.equal(car.health, 0);
  sim.step(1 / 30, 22_001, new Map());
  assert.equal(car.health, 1200);
  assert.deepEqual(car.pos, spawnPosition);
});

test('vehicle chassis stops at the authored Industrial warehouse and speeding roadkills are emitted', () => {
  const blocked = new VehicleSimulation();
  const car = blocked.states.get('CAR_0')!;
  car.pos = [-16, 0.9221, -10];
  car.yaw = -Math.PI / 2;
  const driver = player('wall-driver', car.pos[0], car.pos[1], car.pos[2]);
  assert.equal(blocked.enter(driver, car.id, 1000), true);
  const solo = new Map([[driver.username, driver]]);
  for (let tick = 1; tick <= 120; tick++) {
    blocked.input(driver, { throttle: 1, steer: 0, brake: false, gear: 1, vehicleIndex: driver.vehicle_index, vehicleGeneration: driver.vehicle_generation }, 1000 + tick * 33);
    blocked.step(1 / 30, 1000 + tick * 33, solo);
  }
  assert.ok(car.pos[0] <= -12.5, `vehicle chassis should stop before the wall (x=${car.pos[0]})`);

  const road = new VehicleSimulation();
  const roadCar = road.states.get('CAR_0')!;
  const roadDriver = player('road-driver', ...roadCar.pos);
  const target = player('road-target', roadCar.pos[0], roadCar.pos[1], roadCar.pos[2] - 3);
  assert.equal(road.enter(roadDriver, roadCar.id, 1000), true);
  const players = new Map([[roadDriver.username, roadDriver], [target.username, target]]);
  const events = [];
  for (let tick = 1; tick <= 60; tick++) {
    road.input(roadDriver, { throttle: 1, steer: 0, brake: false, gear: 1, vehicleIndex: roadDriver.vehicle_index, vehicleGeneration: roadDriver.vehicle_generation }, 1000 + tick * 33);
    events.push(...road.step(1 / 30, 1000 + tick * 33, players));
  }
  assert.ok(events.some((event) => event.driver === roadDriver.username && event.target === target.username && event.vehicle === roadCar.id));
});
