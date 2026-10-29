import assert from 'node:assert/strict';
import test from 'node:test';
import { INDUSTRIAL_VEHICLE_SPAWNS, loadWorldGeometry } from './world-geometry.js';
import { VehicleSimulation, type VehiclePlayer } from './vehicle-simulation.js';

function player(username: string, x: number, y: number, z: number): VehiclePlayer {
  return { username, x, y, z, health: 100, deaths: 0, team: 'A', is_dead: false, driving_vehicle: '' };
}

test('vehicles use authored spawns and validate exclusive seat entry/exit', () => {
  const sim = new VehicleSimulation();
  assert.equal(sim.states.size, INDUSTRIAL_VEHICLE_SPAWNS.length);
  const car = sim.states.get('CAR_0')!;
  assert.equal(car.health, 1200);
  const driver = player('driver', car.pos[0], car.pos[1], car.pos[2]);
  const second = player('second', car.pos[0], car.pos[1], car.pos[2]);
  assert.equal(sim.enter(driver, car.id, 1000), true);
  assert.equal(driver.driving_vehicle, car.id);
  assert.equal(sim.enter(second, car.id, 1000), false, 'a vehicle has one authoritative driver');
  assert.equal(sim.exit(driver), true);
  assert.equal(driver.driving_vehicle, '');
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
  assert.equal(sim.input(driver, { throttle: 1, steer: 0, brake: false, gear: 2 }, 1000), true);
  const start = [...car.pos];
  for (let tick = 1; tick <= 20; tick++) sim.step(1 / 30, 1000 + tick * 33, new Map([[driver.username, driver]]));
  assert.ok(Math.hypot(car.pos[0] - start[0], car.pos[2] - start[2]) > 0.2);
  assert.equal(car.gear, 2);
  const previousSpeed = car.speed;
  const moved = [...car.pos];
  sim.step(1 / 30, 3000, new Map([[driver.username, driver]]));
  assert.ok(car.speed < previousSpeed, 'stale input brakes vehicle');
  assert.ok(Math.hypot(car.pos[0] - moved[0], car.pos[2] - moved[2]) < 0.1, 'stale input yields only one short braking step');
  assert.equal(sim.input(driver, { throttle: Number.NaN, steer: 0, brake: false, gear: 1 }, 3001), false);
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
    blocked.input(driver, { throttle: 1, steer: 0, brake: false, gear: 1 }, 1000 + tick * 33);
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
    road.input(roadDriver, { throttle: 1, steer: 0, brake: false, gear: 1 }, 1000 + tick * 33);
    events.push(...road.step(1 / 30, 1000 + tick * 33, players));
  }
  assert.ok(events.some((event) => event.driver === roadDriver.username && event.target === target.username && event.vehicle === roadCar.id));
});
