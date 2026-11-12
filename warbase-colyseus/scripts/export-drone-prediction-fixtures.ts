import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { DRONE_SPAWN_OFFSET, stepDroneFlight, type DroneInput } from '../src/drone-flight.js';
import { loadWorldGeometry, PLAYABLE_MAPS, type Vec3 } from '../src/world-geometry.js';

const round = (value: number): number => Math.round(value * 1_000_000) / 1_000_000;
const outputArgument = process.argv.indexOf('--out');
if (outputArgument >= 0 && !process.argv[outputArgument + 1]) throw new Error('Usage: export-drone-prediction-fixtures.ts [--out <path>]');
const outputPath = resolve(outputArgument >= 0 ? process.argv[outputArgument + 1] : '/tmp/drone-flight-fixtures.json');
const commands: DroneInput[] = Array.from({ length: 120 }, (_, tick) => {
  if (tick < 45) return { move_x: 0, move_y: 0, move_z: 1, yaw: 0.37, sprint: tick >= 15 && tick < 30 ? 1 : 0 };
  if (tick < 75) return { move_x: 0, move_y: 1, move_z: 0, yaw: 0.37, sprint: 0 };
  if (tick < 100) return { move_x: 1, move_y: -1, move_z: 0, yaw: 0.37, sprint: 0 };
  return { move_x: 0, move_y: 0, move_z: 0, yaw: 0.37, sprint: 0 };
});

const maps = PLAYABLE_MAPS.map((map) => {
  const geometry = loadWorldGeometry(map);
  if (!geometry) throw new Error(`Missing geometry for ${map}`);
  if (geometry.spawns.length !== 12) throw new Error(`${map} expected twelve authored spawn points, received ${geometry.spawns.length}`);
  const spawns = geometry.spawns.map((spawn, spawnIndex) => {
    const start: Vec3 = [spawn[0], spawn[1] + DRONE_SPAWN_OFFSET, spawn[2]];
    let position: Vec3 = [...start], velocity: Vec3 = [0, 0, 0];
    const checkpoints: { tick: number; position: number[]; velocity: number[] }[] = [];
    commands.forEach((command, index) => {
      const next = stepDroneFlight(geometry, position, velocity, command, 1 / 60);
      position = next.position;
      velocity = next.velocity;
      if (!position.every(Number.isFinite) || !velocity.every(Number.isFinite)) throw new Error(`${map} spawn ${spawnIndex} became non-finite at tick ${index + 1}`);
      if ((index + 1) % 20 === 0) checkpoints.push({
        tick: index + 1,
        position: position.map(round),
        velocity: velocity.map(round),
      });
    });
    return { spawn_index: spawnIndex, start: [...start].map(round), checkpoints };
  });
  return { map, spawns };
});

const fixture = { tick_rate: 60, steps: 120, commands, maps };
await mkdir(dirname(outputPath), { recursive: true });
await writeFile(outputPath, `${JSON.stringify(fixture, null, 2)}\n`);
console.log(`Wrote ${maps.length} maps, ${maps.reduce((sum, map) => sum + map.spawns.length, 0)} spawn trajectories and ${maps.reduce((sum, map) => sum + map.spawns.reduce((count, spawn) => count + spawn.checkpoints.length, 0), 0)} checkpoints to ${outputPath}`);
