import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { VehicleSimulation, type VehiclePlayer } from '../src/vehicle-simulation.js';
import { loadWorldGeometry, PLAYABLE_MAPS } from '../src/world-geometry.js';

const outputPath = resolve(dirname(fileURLToPath(import.meta.url)), '../../warbase-godot/client/assets/data/vehicle-prediction-fixtures.json');
const round = (value: number): number => Math.round(value * 1_000_000) / 1_000_000;
const commands = Array.from({ length: 120 }, (_, tick) => {
  if (tick < 30) return { throttle: 1, steer: 0, brake: false, gear: 1 };
  if (tick < 60) return { throttle: 0.65, steer: 0.7, brake: false, gear: 2 };
  if (tick < 75) return { throttle: 0, steer: -0.35, brake: true, gear: 2 };
  if (tick < 90) return { throttle: -0.6, steer: 0, brake: false, gear: 1 };
  if (tick < 105) return { throttle: 0.8, steer: -0.8, brake: false, gear: 2 };
  return { throttle: 0, steer: 0, brake: true, gear: 1 };
});

const maps = PLAYABLE_MAPS.map((map) => {
  const geometry = loadWorldGeometry(map);
  if (!geometry) throw new Error(`Missing geometry for ${map}`);
  const simulation = new VehicleSimulation(geometry);
  const initialVehicles = [...simulation.states.values()].map((vehicle) => ({
    id: vehicle.id, x: round(vehicle.pos[0]), y: round(vehicle.pos[1]), z: round(vehicle.pos[2]),
    yaw: round(vehicle.yaw), speed: round(vehicle.speed), health: vehicle.health, gear: vehicle.gear,
    driver: vehicle.driver, driver_generation: vehicle.driverGeneration,
  }));
  const car = simulation.states.get('CAR_0');
  if (!car) return { map, initialVehicles, driver: null, steps: [], note: 'No authored vehicles on this map.' };
  const player: VehiclePlayer = {
    username: 'fixture_driver', x: car.pos[0], y: car.pos[1], z: car.pos[2],
    health: 100, deaths: 0, team: 'A', is_dead: false, driving_vehicle: '', vehicle_index: -1, vehicle_generation: 0,
  };
  if (!simulation.enter(player, car.id, 10_000)) throw new Error(`${map} rejected fixture driver seat entry`);
  const steps = commands.map((command, tick) => {
    const before = [...car.pos] as [number, number, number];
    const input = { ...command, vehicleIndex: player.vehicle_index, vehicleGeneration: player.vehicle_generation };
    if (!simulation.input(player, input, 10_000 + tick * (1000 / 60))) throw new Error(`${map} rejected fixture input ${tick}`);
    simulation.step(1 / 60, 10_000 + tick * (1000 / 60), new Map([[player.username, player]]));
    const distance = Math.hypot(car.pos[0] - before[0], car.pos[1] - before[1], car.pos[2] - before[2]);
    return {
      tick,
      ...command,
      collision_blocked: Math.abs(car.speed) > 0.1 && distance < Math.abs(car.speed) / 60 * 0.25,
      x: round(car.pos[0]), y: round(car.pos[1]), z: round(car.pos[2]),
      yaw: round(car.yaw), speed: round(car.speed), gear: car.gear,
    };
  });
  let collisionCase: { start: number[]; yaw: number; steps: object[] } | null = null;
  if (map === 'industrial') {
    const wallSimulation = new VehicleSimulation(geometry);
    const wallCar = wallSimulation.states.get('CAR_0')!;
    wallCar.pos = [-16, 0.9221, -10]; wallCar.yaw = -Math.PI / 2;
    const wallDriver: VehiclePlayer = { ...player, x: wallCar.pos[0], y: wallCar.pos[1], z: wallCar.pos[2], driving_vehicle: '', vehicle_index: -1, vehicle_generation: 0 };
    if (!wallSimulation.enter(wallDriver, wallCar.id, 20_000)) throw new Error('Industrial wall collision fixture seat entry failed');
    const wallSteps = Array.from({ length: 60 }, (_, tick) => {
      const before = [...wallCar.pos] as [number, number, number];
      const beforeSpeed = wallCar.speed;
      wallSimulation.input(wallDriver, { throttle: 1, steer: 0, brake: false, gear: 1, vehicleIndex: wallDriver.vehicle_index, vehicleGeneration: wallDriver.vehicle_generation }, 20_000 + tick * (1000 / 60));
      wallSimulation.step(1 / 60, 20_000 + tick * (1000 / 60), new Map([[wallDriver.username, wallDriver]]));
      const distance = Math.hypot(wallCar.pos[0] - before[0], wallCar.pos[1] - before[1], wallCar.pos[2] - before[2]);
      return { tick, throttle: 1, steer: 0, brake: false, gear: 1, collision_blocked: beforeSpeed > 0.1 && distance < beforeSpeed / 60 * 0.25, x: round(wallCar.pos[0]), y: round(wallCar.pos[1]), z: round(wallCar.pos[2]), yaw: round(wallCar.yaw), speed: round(wallCar.speed), gear_actual: wallCar.gear };
    });
    collisionCase = { start: [-16, 0.9221, -10], yaw: round(-Math.PI / 2), steps: wallSteps };
  }
  return {
    map,
    initialVehicles,
    driver: { username: player.username, vehicle_index: player.vehicle_index, vehicle_generation: player.vehicle_generation },
    steps,
    ...(collisionCase ? { collision_case: collisionCase } : {}),
  };
});

const fixture = {
  format: 1,
  description: 'Deterministic server vehicle controller and map collision parity traces; each command is applied on one 60 Hz consumed input step.',
  tolerances: { position_metres: 0.005, yaw_radians: 0.0001, speed_metres_per_second: 0.005 },
  maps,
};
await mkdir(dirname(outputPath), { recursive: true });
await writeFile(outputPath, `${JSON.stringify(fixture, null, 2)}\n`);
console.log(`Wrote vehicle prediction fixtures for ${maps.length} maps to ${outputPath}`);
