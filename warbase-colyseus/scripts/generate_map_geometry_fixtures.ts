import { readFileSync, writeFileSync } from 'node:fs';
import { loadWorldGeometry, PLAYABLE_MAPS } from '../src/world-geometry.js';

const file = new URL('../src/data/maps/map-fixtures.json', import.meta.url);
const godotFile = new URL('../../warbase-godot/client/assets/data/maps/map-fixtures.json', import.meta.url);
const fixtures = JSON.parse(readFileSync(file, 'utf8')) as Array<Record<string, unknown>>;
for (const id of PLAYABLE_MAPS) {
  const geometry = loadWorldGeometry(id);
  if (!geometry) throw new Error(`No geometry for ${id}`);
  const item = fixtures.find((row) => row.map === id);
  if (!item) throw new Error(`No extraction metadata for ${id}`);
  const spawn = geometry.spawns[0];
  const rayFrom = [spawn[0], spawn[1] + 1, spawn[2]] as const;
  const rayTo = [spawn[0], spawn[1] - 1, spawn[2]] as const;
  const moveFrom = spawn;
  const moveTo = [spawn[0] + 0.4, spawn[1], spawn[2]] as const;
  item.ray = { from: rayFrom, to: rayTo, blocked: geometry.rayBlocked(rayFrom, rayTo) };
  item.move = { from: moveFrom, to: moveTo, expected: geometry.resolveMove(moveFrom, moveTo) };
}
const payload = `${JSON.stringify(fixtures, null, 2)}\n`;
writeFileSync(file, payload);
writeFileSync(godotFile, payload);
