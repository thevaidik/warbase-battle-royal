import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { INDUSTRIAL_SPAWNS, floorHeight, loadWorldGeometry, normalizeMapId, PLAYABLE_MAPS, rayBlocked, resolveIndustrialMove } from './world-geometry.js';

const fixtures = JSON.parse(readFileSync(new URL('./data/geometry-fixtures.json', import.meta.url), 'utf8')) as {
  rays: Array<{ name: string; from: number[]; to: number[]; blocked: boolean }>;
  moves: Array<{ name: string; from: number[]; to: number[]; expected: number[] }>;
};

test('loads the authored Industrial spawn set and finds walkable ground', () => {
  assert.equal(INDUSTRIAL_SPAWNS.length, 12);
  assert.deepEqual(INDUSTRIAL_SPAWNS[0], [-22, 1.29999995231628, -22]);
  for (const [x, spawnY, z] of INDUSTRIAL_SPAWNS) {
    const ground = floorHeight(x, z, spawnY + 3);
    assert.ok(ground !== undefined && Number.isFinite(ground), `missing floor beneath spawn ${x},${z}`);
    assert.ok(ground! <= spawnY && spawnY - ground! <= 0.6, `unexpected floor height ${ground} at spawn ${x},${z}`);
  }
  assert.equal(floorHeight(1_000, 1_000), undefined);
});

test('rays hit actual warehouse walls and perimeter fence while road lanes remain open', () => {
  assert.equal(rayBlocked([-12, 1.1, -10], [-8, 1.1, -10]), true, 'warehouse wall must stop fire');
  assert.equal(rayBlocked([77, 1.4, -20], [81, 1.4, -20]), true, 'perimeter fence must stop fire');
  assert.equal(rayBlocked([67, 0.5, -20], [73, 0.5, -20]), false, 'east road lane must remain open');
  assert.equal(rayBlocked([-100, 1, 0], [-99, 1, 0]), false, 'unobstructed exterior segment must remain clear');
});

test('capsule movement stops at authored walls and slides along them', () => {
  const floor = floorHeight(-12, -10, 10);
  assert.ok(floor !== undefined);
  const resolved = resolveIndustrialMove([-12, floor!, -10], [-8, floor!, -6]);
  assert.ok(resolved.every(Number.isFinite));
  assert.ok(resolved[0] < -10.5 && resolved[0] > -11.5, `capsule crossed warehouse wall: ${resolved}`);
  assert.ok(Math.abs(resolved[2] + 6) < 0.05, `capsule failed to slide along the warehouse wall: ${resolved}`);

  const roadY = floorHeight(67, -20, 10);
  assert.ok(roadY !== undefined);
  const road = resolveIndustrialMove([67, roadY!, -20], [73, roadY!, -20]);
  assert.ok(road[0] > 72.5, `capsule was blocked by open road: ${road}`);
  const fenceY = floorHeight(77, -20, 10);
  assert.ok(fenceY !== undefined);
  const fence = resolveIndustrialMove([77, fenceY!, -20], [81, fenceY!, -20]);
  assert.ok(fence[0] < 80, `capsule crossed perimeter fence: ${fence}`);
});

test('invalid coordinates fail closed without leaking non-finite movement', () => {
  assert.equal(rayBlocked([Number.NaN, 0, 0], [0, 0, 0]), true);
  assert.equal(floorHeight(Number.NaN, 0), undefined);
  assert.deepEqual(resolveIndustrialMove([Number.NaN, 0, 0], [1, 0, 0]), INDUSTRIAL_SPAWNS[0]);
  assert.deepEqual(resolveIndustrialMove([1, 2, 3], [Number.POSITIVE_INFINITY, 2, 3]), [1, 2, 3]);
  assert.deepEqual(resolveIndustrialMove([1, 2, 3], [4, 5, 6], Number.NaN), [1, 2, 3]);
});

test('shared TS/Godot ray and movement fixtures stay deterministic', () => {
  for (const fixture of fixtures.rays) {
    assert.equal(rayBlocked(fixture.from as [number, number, number], fixture.to as [number, number, number]), fixture.blocked, fixture.name);
  }
  for (const fixture of fixtures.moves) {
    const actual = resolveIndustrialMove(fixture.from as [number, number, number], fixture.to as [number, number, number]);
    assert.ok(Math.hypot(actual[0] - fixture.expected[0], actual[1] - fixture.expected[1], actual[2] - fixture.expected[2]) < 0.001, `${fixture.name}: ${actual}`);
  }
});

test('allocation-light BVH collision queries match the reference trace for shared rays and floors', () => {
  const geometry = loadWorldGeometry('industrial')!;
  for (const fixture of fixtures.rays) {
    const from = fixture.from as [number, number, number], to = fixture.to as [number, number, number];
    const length = Math.hypot(to[0] - from[0], to[1] - from[1], to[2] - from[2]);
    const hit = geometry.trace(from, to);
    const expectedBlocked = length >= 0.05 && hit !== null && hit.fraction > 0.02 / length && hit.fraction < 1 - 0.04 / length;
    assert.equal(geometry.rayBlocked(from, to), expectedBlocked, fixture.name);
  }
  for (const [x, y, z] of INDUSTRIAL_SPAWNS) {
    const fromY = y + 3;
    const hit = geometry.trace([x, fromY, z], [x, -100, z]);
    const expected = hit && Math.abs(hit.normal[1]) >= 0.5 ? fromY + (-100 - fromY) * hit.fraction : undefined;
    const actual = geometry.floorHeight(x, z, fromY);
    if (expected === undefined) assert.equal(actual, undefined);
    else assert.ok(actual !== undefined && Math.abs(actual - expected) < 1e-6);
  }
});

test('all selectable maps load independent authored geometry and match the shared Godot fixtures', () => {
  const mapFixtures = JSON.parse(readFileSync(new URL('./data/maps/map-fixtures.json', import.meta.url), 'utf8')) as Array<{
    map: string; triangles: number; spawns: number; vehicles: number; nav_step: number;
    ray: { from: number[]; to: number[]; blocked: boolean };
    move: { from: number[]; to: number[]; expected: number[] };
  }>;
  assert.equal(mapFixtures.length, PLAYABLE_MAPS.length);
  assert.equal(normalizeMapId('  DESERT_OASIS '), 'desert_oasis');
  assert.equal(normalizeMapId('loft'), null);
  for (const fixture of mapFixtures) {
    const geometry = loadWorldGeometry(fixture.map);
    assert.ok(geometry, `${fixture.map} should be an allow-listed map`);
    assert.equal(geometry.name, fixture.map);
    assert.equal(geometry.spawns.length, fixture.spawns);
    assert.equal(geometry.vehicleSpawns.length, fixture.vehicles);
    assert.ok(geometry.navStep > 0);
    assert.ok(geometry.floorHeight(geometry.spawns[0][0], geometry.spawns[0][2], geometry.spawns[0][1] + 2) !== undefined);
    assert.equal(geometry.rayBlocked(fixture.ray.from as [number, number, number], fixture.ray.to as [number, number, number]), fixture.ray.blocked, fixture.map);
    const actual = geometry.resolveMove(fixture.move.from as [number, number, number], fixture.move.to as [number, number, number]);
    assert.ok(Math.hypot(actual[0] - fixture.move.expected[0], actual[1] - fixture.move.expected[1], actual[2] - fixture.move.expected[2]) < 0.001, `${fixture.map}: ${actual}`);
  }
  const industrial = loadWorldGeometry('industrial')!;
  const village = loadWorldGeometry('village')!;
  assert.notEqual(industrial, village);
  assert.equal(industrial.spawns[0][0], -22);
  assert.ok(village.spawns[0][0] !== industrial.spawns[0][0]);
  assert.equal(loadWorldGeometry(' INDUSTRIAL '), industrial);
});
