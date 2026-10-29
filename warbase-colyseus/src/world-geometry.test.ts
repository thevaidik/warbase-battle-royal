import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { performance } from 'node:perf_hooks';
import { INDUSTRIAL_SPAWNS, floorHeight, loadWorldGeometry, normalizeMapId, PLAYABLE_MAPS, rayBlocked, resolveIndustrialMove, type Vec3, type WorldGeometry } from './world-geometry.js';

const fixtures = JSON.parse(readFileSync(new URL('./data/geometry-fixtures.json', import.meta.url), 'utf8')) as {
  rays: Array<{ name: string; from: number[]; to: number[]; blocked: boolean }>;
  moves: Array<{ name: string; from: number[]; to: number[]; expected: number[] }>;
};

function referenceFloor(geometry: WorldGeometry, x: number, z: number, fromY: number): number | undefined {
  const hit = geometry.trace([x, fromY, z], [x, -100, z]);
  if (!hit || Math.abs(hit.normal[1]) < 0.5) return undefined;
  return fromY + (-100 - fromY) * hit.fraction;
}

function referenceCapsuleBlocked(geometry: WorldGeometry, from: Vec3, to: Vec3, radius: number, height: number, horizontalOnly = false): boolean {
  const levels = [0.08, 0.24, 0.4, 0.9, 1.4, 1.56, 1.72] as const, spokes = 12;
  const deltaY = to[1] - from[1];
  for (const yOffset of levels) {
    if (yOffset > height) continue;
    let ringRadius = radius;
    if (yOffset < radius) ringRadius = Math.sqrt(Math.max(0, radius * radius - (radius - yOffset) ** 2));
    else if (yOffset > height - radius) ringRadius = Math.sqrt(Math.max(0, radius * radius - (yOffset - (height - radius)) ** 2));
    for (let spoke = 0; spoke <= spokes; spoke++) {
      const angle = spoke === spokes ? 0 : (2 * Math.PI * spoke) / spokes;
      const ox = spoke === spokes ? 0 : Math.cos(angle) * ringRadius, oz = spoke === spokes ? 0 : Math.sin(angle) * ringRadius;
      const hit = geometry.trace([from[0] + ox, from[1] + yOffset, from[2] + oz], [to[0] + ox, to[1] + yOffset, to[2] + oz]);
      if (!hit || hit.fraction <= 1e-4) continue;
      if (horizontalOnly && Math.abs(deltaY) < 1e-6 && Math.abs(hit.normal[1]) >= 0.5) continue;
      return true;
    }
  }
  return false;
}

function referenceMove(geometry: WorldGeometry, from: Vec3, to: Vec3, radius = 0.4, height = 1.8): Vec3 {
  if (!from.every(Number.isFinite)) return geometry.spawns[0];
  if (!to.every(Number.isFinite)) return from;
  if (![radius, height].every(Number.isFinite) || radius <= 0 || height < 2 * radius) return from;
  radius = Math.min(radius, 1.5); height = Math.min(height, 4);
  let x = from[0], y = from[1], z = from[2];
  const stepHeight = 0.45;
  const targetFloor = referenceFloor(geometry, to[0], to[2], y + stepHeight);
  if (targetFloor !== undefined && targetFloor > y + 0.03 && targetFloor <= y + stepHeight) {
    const steppedFrom: Vec3 = [x, targetFloor, z], steppedTarget: Vec3 = [to[0], targetFloor, to[2]];
    if (!referenceCapsuleBlocked(geometry, from, steppedFrom, radius, height) && !referenceCapsuleBlocked(geometry, steppedFrom, steppedTarget, radius, height, true)) { x = to[0]; y = targetFloor; z = to[2]; }
  }
  const moveAxis = (axis: 0 | 2, target: number): number => {
    const current: Vec3 = [x, y, z], destination: Vec3 = axis === 0 ? [target, y, z] : [x, y, target];
    if (!referenceCapsuleBlocked(geometry, current, destination, radius, height, true)) return target;
    let safe = 0, blocked = 1;
    for (let iteration = 0; iteration < 10; iteration++) {
      const middle = (safe + blocked) * 0.5;
      const candidate: Vec3 = axis === 0 ? [x + (target - x) * middle, y, z] : [x, y, z + (target - z) * middle];
      if (referenceCapsuleBlocked(geometry, current, candidate, radius, height, true)) blocked = middle; else safe = middle;
    }
    return axis === 0 ? x + (target - x) * safe : z + (target - z) * safe;
  };
  x = moveAxis(0, to[0]); z = moveAxis(2, to[2]);
  const floor = referenceFloor(geometry, x, z, Math.max(y, to[1]) + stepHeight);
  let targetY = to[1];
  if (floor !== undefined && targetY <= floor && y >= floor - stepHeight) targetY = floor;
  const verticalFrom: Vec3 = [x, y, z], verticalTo: Vec3 = [x, targetY, z];
  if (!referenceCapsuleBlocked(geometry, verticalFrom, verticalTo, radius, height)) y = targetY;
  else {
    let safe = 0, blocked = 1;
    for (let iteration = 0; iteration < 10; iteration++) {
      const middle = (safe + blocked) * 0.5, candidate: Vec3 = [x, y + (targetY - y) * middle, z];
      if (referenceCapsuleBlocked(geometry, verticalFrom, candidate, radius, height)) blocked = middle; else safe = middle;
    }
    y += (targetY - y) * safe;
  }
  return [x, y, z];
}

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

test('swept candidate reuse exactly matches the pre-optimization movement solver on all maps', () => {
  const mapFixtures = JSON.parse(readFileSync(new URL('./data/maps/map-fixtures.json', import.meta.url), 'utf8')) as Array<{ map: string; move: { from: number[]; to: number[] } }>;
  let seed = 0x51f15e;
  const random = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 0x1_0000_0000; };
  for (const fixture of mapFixtures) {
    const geometry = loadWorldGeometry(fixture.map)!;
    const from = fixture.move.from as unknown as Vec3, to = fixture.move.to as unknown as Vec3;
    const recorded = geometry.resolveMove(from, to);
    const reference = referenceMove(geometry, from, to);
    assert.ok(Math.hypot(recorded[0] - reference[0], recorded[1] - reference[1], recorded[2] - reference[2]) < 1e-7, `${fixture.map} shared fixture: ${recorded} vs ${reference}`);
    for (let i = 0; i < 12; i++) {
      const spawn = geometry.spawns[i % geometry.spawns.length];
      const from: Vec3 = [spawn[0] + (random() - 0.5) * 0.3, spawn[1] + (random() - 0.5) * 0.1, spawn[2] + (random() - 0.5) * 0.3];
      const to: Vec3 = [from[0] + (random() - 0.5) * 0.35, from[1] + (random() - 0.5) * 0.08, from[2] + (random() - 0.5) * 0.35];
      const actual = geometry.resolveMove(from, to), expected = referenceMove(geometry, from, to);
      assert.ok(Math.hypot(actual[0] - expected[0], actual[1] - expected[1], actual[2] - expected[2]) < 1e-7, `${fixture.map} seeded move ${i}: ${actual} vs ${expected}`);
    }
  }
  const industrial = loadWorldGeometry('industrial')!;
  const floor = industrial.floorHeight(-12, -10, 10)!;
  for (const [from, to] of [
    [[-12, floor, -10], [-8, floor, -6]], [[-11, floor, -12], [-11, floor, -8]],
    [[67, industrial.floorHeight(67, -20, 10)!, -20], [73, industrial.floorHeight(67, -20, 10)!, -20]],
    [[77, industrial.floorHeight(77, -20, 10)!, -20], [81, industrial.floorHeight(77, -20, 10)!, -20]],
  ] as Array<[Vec3, Vec3]>) {
    const actual = industrial.resolveMove(from, to), expected = referenceMove(industrial, from, to);
    assert.ok(Math.hypot(actual[0] - expected[0], actual[1] - expected[1], actual[2] - expected[2]) < 1e-7, `${from} → ${to}: ${actual} vs ${expected}`);
  }
});

test('benchmark swept movement candidate reuse against the reference solver', { skip: !process.env.GEOMETRY_BENCHMARK }, () => {
  const workload: Array<{ geometry: WorldGeometry; from: Vec3; to: Vec3 }> = [];
  for (const map of ['industrial', 'football'] as const) {
    const geometry = loadWorldGeometry(map)!;
    for (let i = 0; i < 28; i++) {
      const spawn = geometry.spawns[i % geometry.spawns.length];
      const from: Vec3 = [spawn[0] + (i % 4) * 0.17, spawn[1], spawn[2] - (i % 3) * 0.13];
      const to: Vec3 = [from[0] + ((i % 5) - 2) * 0.72, from[1] + (i % 7 === 0 ? -0.3 : 0), from[2] + ((i % 3) - 1) * 0.68];
      workload.push({ geometry, from, to });
    }
  }
  for (const item of workload) { referenceMove(item.geometry, item.from, item.to); item.geometry.resolveMove(item.from, item.to); }
  const measure = (run: (item: typeof workload[number]) => Vec3): number => {
    const start = performance.now();
    for (let repeat = 0; repeat < 3; repeat++) for (const item of workload) run(item);
    return performance.now() - start;
  };
  const referenceMs = measure(item => referenceMove(item.geometry, item.from, item.to));
  const optimizedMs = measure(item => item.geometry.resolveMove(item.from, item.to));
  assert.ok(optimizedMs < referenceMs, `candidate reuse benchmark regressed: reference=${referenceMs.toFixed(2)}ms optimized=${optimizedMs.toFixed(2)}ms`);
  console.log(`movement benchmark: ${workload.length * 3} Industrial/Football moves; reference=${referenceMs.toFixed(2)}ms optimized=${optimizedMs.toFixed(2)}ms speedup=${(referenceMs / optimizedMs).toFixed(2)}x`);
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
