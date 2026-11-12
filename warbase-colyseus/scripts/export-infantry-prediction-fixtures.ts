import { readFileSync, writeFileSync } from 'node:fs';
import { gunzipSync } from 'node:zlib';
import { PLAYABLE_MAPS, loadWorldGeometry, type Vec3 } from '../src/world-geometry.js';

const TICK_RATE = 60;
const DT = 1 / TICK_RATE;
const STEPS = 120;
const CHECK_INTERVAL = 20;
const WALK_SPEED = 6.2;
const GRAVITY = 18;
const JUMP_SPEED = 6.2;

type Checkpoint = { tick: number; position: Vec3; vy: number };
type SpawnRun = { spawn_index: number; start: Vec3; checkpoints: Checkpoint[] };
type MapRun = { map: string; spawns: SpawnRun[] };

function authoredSpawns(map: string): Vec3[] {
  const path = new URL(`../src/data/maps/${map}.json.gz`, import.meta.url);
  const encoded = JSON.parse(gunzipSync(readFileSync(path)).toString('utf8')) as { spawns?: number[][] };
  if (!Array.isArray(encoded.spawns) || encoded.spawns.length !== 12) throw new Error(`${map}: expected 12 authored spawns`);
  return encoded.spawns.map((spawn) => {
    if (spawn.length !== 3 || !spawn.every(Number.isFinite)) throw new Error(`${map}: invalid authored spawn`);
    return [spawn[0], spawn[1], spawn[2]];
  });
}

function simulateSpawn(map: string, spawnIndex: number, start: Vec3): SpawnRun {
  const geometry = loadWorldGeometry(map);
  if (!geometry) throw new Error(`Could not load map geometry: ${map}`);
  let position: Vec3 = [...start];
  let vy = 0;
  const checkpoints: Checkpoint[] = [];

  for (let tick = 0; tick < STEPS; tick++) {
    const from = position;
    if (tick === 30 && Math.abs(vy) < 0.001 && geometry.isGrounded(from)) vy = JUMP_SPEED;
    vy -= GRAVITY * DT;
    const dx = tick < 60 ? WALK_SPEED * DT : 0;
    const dz = tick < 60 ? 0 : -WALK_SPEED * DT;
    const requested: Vec3 = [from[0] + dx, from[1] + vy * DT, from[2] + dz];
    const resolved = geometry.resolveMove(from, requested);
    position = resolved;
    if (vy < 0 && geometry.isGrounded(position)) vy = 0;
    else if (vy > 0 && position[1] < requested[1] - 0.001) vy = 0;

    const completedTick = tick + 1;
    if (completedTick % CHECK_INTERVAL === 0 || completedTick === STEPS) {
      checkpoints.push({ tick: completedTick, position: [...position], vy });
    }
  }
  return { spawn_index: spawnIndex, start, checkpoints };
}

function outputPath(): string {
  const args = process.argv.slice(2);
  const inline = args.find((arg) => arg.startsWith('--out='));
  const separate = args.indexOf('--out');
  const path = inline?.slice('--out='.length) ?? (separate >= 0 ? args[separate + 1] : undefined);
  if (!path) throw new Error('Usage: node --import tsx scripts/export-infantry-prediction-fixtures.ts --out /tmp/infantry-parity.json');
  return path;
}

const maps: MapRun[] = PLAYABLE_MAPS.map((map) => ({
  map,
  spawns: authoredSpawns(map).map((spawn, index) => simulateSpawn(map, index, spawn)),
}));
const fixture = {
  version: 1,
  tick_rate: TICK_RATE,
  steps: STEPS,
  gravity: GRAVITY,
  jump_speed: JUMP_SPEED,
  walk_speed: WALK_SPEED,
  maps,
};
const path = outputPath();
writeFileSync(path, `${JSON.stringify(fixture)}\n`);
console.log(`INFANTRY_FIXTURES_OK maps=${maps.length} spawns=${maps.reduce((count, map) => count + map.spawns.length, 0)} checks=${maps.reduce((count, map) => count + map.spawns.reduce((sum, spawn) => sum + spawn.checkpoints.length, 0), 0)} out=${path}`);
