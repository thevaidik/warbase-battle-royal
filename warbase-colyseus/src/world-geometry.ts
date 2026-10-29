import { readFileSync } from 'node:fs';
import { gunzipSync } from 'node:zlib';

// These IDs exactly match MainMenu.PLAYABLE_MAPS in the Godot client. Keep the
// list explicit so unsupported maps fail closed instead of receiving fake floors.
export const PLAYABLE_MAPS = Object.freeze(['football', 'resoforge', 'industrial', 'village', 'arena', 'shipment', 'dust2', 'nuketown', 'canyon', 'desert_oasis'] as const);
export type PlayableMap = typeof PLAYABLE_MAPS[number];
export type Vec3 = readonly [x: number, y: number, z: number];

type EncodedMap = { name?: string; nav_step?: number; spawns: number[][]; vehicles?: number[][]; triangles: number[]; nodes: number[]; order: number[] };
type BvhNode = {
  minX: number; minY: number; minZ: number;
  maxX: number; maxY: number; maxZ: number;
  left: number; right: number;
  start: number; count: number;
};
type RayHit = { fraction: number; normal: Vec3 };
type GeometryBuffers = { vertices: Float32Array; nodes: BvhNode[]; order: Uint32Array };
type CollisionScratch = { stack: number[]; candidateTriangles: number[]; fraction: number; normalY: number };
type CollisionCandidates = readonly number[] | null;

const geometryCache = new Map<PlayableMap, WorldGeometry>();
const CAPSULE_LEVELS = [0.08, 0.24, 0.4, 0.9, 1.4, 1.56, 1.72] as const;
const CAPSULE_SPOKES = Array.from({ length: 13 }, (_, spoke) => {
  if (spoke === 12) return [0, 0] as const;
  const angle = (2 * Math.PI * spoke) / 12;
  return [Math.cos(angle), Math.sin(angle)] as const;
});

function finiteVec(value: Vec3): boolean { return value.length === 3 && value.every(Number.isFinite); }

function rayBox(node: BvhNode, origin: Vec3, delta: Vec3, maxFraction: number): boolean {
  let low = 0, high = Math.min(1, maxFraction);
  for (let axis = 0; axis < 3; axis++) {
    const min = axis === 0 ? node.minX : axis === 1 ? node.minY : node.minZ;
    const max = axis === 0 ? node.maxX : axis === 1 ? node.maxY : node.maxZ;
    const o = origin[axis], d = delta[axis];
    if (Math.abs(d) < 1e-9) {
      if (o < min || o > max) return false;
      continue;
    }
    let first = (min - o) / d, last = (max - o) / d;
    if (first > last) [first, last] = [last, first];
    low = Math.max(low, first); high = Math.min(high, last);
    if (low > high) return false;
  }
  return true;
}

function intersectTriangle(vertices: Float32Array, triangle: number, origin: Vec3, delta: Vec3): RayHit | null {
  const offset = triangle * 9;
  const ax = vertices[offset], ay = vertices[offset + 1], az = vertices[offset + 2];
  const e1x = vertices[offset + 3] - ax, e1y = vertices[offset + 4] - ay, e1z = vertices[offset + 5] - az;
  const e2x = vertices[offset + 6] - ax, e2y = vertices[offset + 7] - ay, e2z = vertices[offset + 8] - az;
  const hx = delta[1] * e2z - delta[2] * e2y;
  const hy = delta[2] * e2x - delta[0] * e2z;
  const hz = delta[0] * e2y - delta[1] * e2x;
  const determinant = e1x * hx + e1y * hy + e1z * hz;
  if (Math.abs(determinant) < 1e-9) return null;
  const inverse = 1 / determinant;
  const sx = origin[0] - ax, sy = origin[1] - ay, sz = origin[2] - az;
  const u = inverse * (sx * hx + sy * hy + sz * hz);
  if (u < 0 || u > 1) return null;
  const qx = sy * e1z - sz * e1y, qy = sz * e1x - sx * e1z, qz = sx * e1y - sy * e1x;
  const v = inverse * (delta[0] * qx + delta[1] * qy + delta[2] * qz);
  if (v < 0 || u + v > 1) return null;
  const fraction = inverse * (e2x * qx + e2y * qy + e2z * qz);
  if (fraction < 0 || fraction > 1) return null;
  let nx = e1y * e2z - e1z * e2y, ny = e1z * e2x - e1x * e2z, nz = e1x * e2y - e1y * e2x;
  const length = Math.hypot(nx, ny, nz);
  if (length === 0) return null;
  nx /= length; ny /= length; nz /= length;
  return { fraction, normal: [nx, ny, nz] };
}

function raycast(data: GeometryBuffers, from: Vec3, to: Vec3): RayHit | null {
  if (!finiteVec(from) || !finiteVec(to)) return null;
  const delta: Vec3 = [to[0] - from[0], to[1] - from[1], to[2] - from[2]];
  let nearest = 2;
  let hit: RayHit | null = null;
  const stack = [0];
  while (stack.length) {
    const nodeIndex = stack.pop()!;
    const node = data.nodes[nodeIndex];
    if (!node || !rayBox(node, from, delta, nearest)) continue;
    if (node.count) {
      for (let index = node.start; index < node.start + node.count; index++) {
        const candidate = intersectTriangle(data.vertices, data.order[index], from, delta);
        if (candidate && candidate.fraction < nearest) { nearest = candidate.fraction; hit = candidate; }
      }
    } else {
      if (node.left >= 0) stack.push(node.left);
      if (node.right >= 0) stack.push(node.right);
    }
  }
  return hit;
}

function testCollisionTriangle(data: GeometryBuffers, triangle: number, ox: number, oy: number, oz: number, dx: number, dy: number, dz: number, scratch: CollisionScratch): void {
  const offset = triangle * 9, vertices = data.vertices;
  const ax = vertices[offset], ay = vertices[offset + 1], az = vertices[offset + 2];
  const e1x = vertices[offset + 3] - ax, e1y = vertices[offset + 4] - ay, e1z = vertices[offset + 5] - az;
  const e2x = vertices[offset + 6] - ax, e2y = vertices[offset + 7] - ay, e2z = vertices[offset + 8] - az;
  const hx = dy * e2z - dz * e2y, hy = dz * e2x - dx * e2z, hz = dx * e2y - dy * e2x;
  const determinant = e1x * hx + e1y * hy + e1z * hz;
  if (Math.abs(determinant) < 1e-9) return;
  const inverse = 1 / determinant, sx = ox - ax, sy = oy - ay, sz = oz - az;
  const u = inverse * (sx * hx + sy * hy + sz * hz);
  if (u < 0 || u > 1) return;
  const qx = sy * e1z - sz * e1y, qy = sz * e1x - sx * e1z, qz = sx * e1y - sy * e1x;
  const v = inverse * (dx * qx + dy * qy + dz * qz);
  if (v < 0 || u + v > 1) return;
  const fraction = inverse * (e2x * qx + e2y * qy + e2z * qz);
  if (fraction < 0 || fraction >= scratch.fraction || fraction > 1) return;
  const nx = e1y * e2z - e1z * e2y, ny = e1z * e2x - e1x * e2z, nz = e1x * e2y - e1y * e2x;
  const length = Math.hypot(nx, ny, nz);
  if (length === 0) return;
  scratch.fraction = fraction;
  scratch.normalY = ny / length;
}

function validateMap(name: PlayableMap, encoded: EncodedMap): GeometryBuffers {
  if (encoded.name !== undefined && encoded.name !== name) throw new Error(`Map dataset name mismatch: expected ${name}, got ${encoded.name}`);
  if (!Array.isArray(encoded.triangles) || encoded.triangles.length === 0 || encoded.triangles.length % 9 !== 0) throw new Error(`Invalid ${name} triangle data`);
  if (!Array.isArray(encoded.nodes) || encoded.nodes.length === 0 || encoded.nodes.length % 10 !== 0 || encoded.order.length !== encoded.triangles.length / 9) throw new Error(`Invalid ${name} BVH data`);
  const vertices = Float32Array.from(encoded.triangles);
  const order = Uint32Array.from(encoded.order);
  for (let i = 0; i < vertices.length; i++) if (!Number.isFinite(vertices[i])) throw new Error(`Non-finite ${name} map vertex ${i}`);
  const nodes: BvhNode[] = [];
  for (let i = 0; i < encoded.nodes.length; i += 10) {
    const values = encoded.nodes.slice(i, i + 10);
    if (values.slice(0, 6).some((value) => !Number.isFinite(value)) || values.slice(6).some((value) => !Number.isInteger(value))) throw new Error(`Invalid ${name} BVH node ${i / 10}`);
    nodes.push({ minX: values[0], minY: values[1], minZ: values[2], maxX: values[3], maxY: values[4], maxZ: values[5], left: values[6], right: values[7], start: values[8], count: values[9] });
  }
  if (order.some((triangle) => triangle >= vertices.length / 9)) throw new Error(`Invalid ${name} BVH triangle order`);
  return { vertices, nodes, order };
}

/** Immutable collision/query instance; separate rooms can own different maps concurrently. */
export class WorldGeometry {
  readonly name: PlayableMap;
  readonly navStep: number;
  readonly spawns: readonly Vec3[];
  readonly vehicleSpawns: readonly (readonly [number, number, number, number])[];
  private readonly buffers: GeometryBuffers;
  // World queries are synchronous in the room loop. Reusing this traversal
  // storage avoids allocating a stack and hit objects for every capsule spoke.
  private readonly collisionScratch: CollisionScratch = { stack: [], candidateTriangles: [], fraction: 2, normalY: 0 };

  constructor(name: PlayableMap, encoded: EncodedMap) {
    this.name = name;
    this.navStep = Number.isFinite(encoded.nav_step) && (encoded.nav_step ?? 0) > 0 ? encoded.nav_step! : 2;
    if (!Array.isArray(encoded.spawns) || encoded.spawns.length === 0) throw new Error(`Invalid authored ${name} spawns`);
    this.spawns = Object.freeze(encoded.spawns.map((spawn) => {
      if (spawn.length !== 3 || !spawn.every(Number.isFinite)) throw new Error(`Invalid authored ${name} spawn`);
      return Object.freeze([spawn[0], spawn[1], spawn[2]]) as Vec3;
    }));
    this.vehicleSpawns = Object.freeze((encoded.vehicles ?? []).map((spawn) => {
      if (spawn.length !== 4 || !spawn.every(Number.isFinite)) throw new Error(`Invalid authored ${name} vehicle spawn`);
      return Object.freeze([spawn[0], spawn[1], spawn[2], spawn[3]]) as readonly [number, number, number, number];
    }));
    this.buffers = validateMap(name, encoded);
  }

  trace(from: Vec3, to: Vec3): (RayHit & { point: Vec3 }) | null {
    const hit = raycast(this.buffers, from, to);
    if (!hit) return null;
    return { ...hit, point: [from[0] + (to[0] - from[0]) * hit.fraction, from[1] + (to[1] - from[1]) * hit.fraction, from[2] + (to[2] - from[2]) * hit.fraction] };
  }

  private collisionRaycast(ox: number, oy: number, oz: number, tx: number, ty: number, tz: number, candidates?: CollisionCandidates): CollisionScratch {
    const data = this.buffers, scratch = this.collisionScratch;
    const dx = tx - ox, dy = ty - oy, dz = tz - oz;
    scratch.fraction = 2; scratch.normalY = 0;
    if (candidates !== undefined && candidates !== null) {
      for (let index = 0; index < candidates.length; index++) testCollisionTriangle(data, candidates[index], ox, oy, oz, dx, dy, dz, scratch);
      return scratch;
    }
    const stack = scratch.stack;
    stack.length = 0; stack.push(0);
    while (stack.length) {
      const node = data.nodes[stack.pop()!];
      if (!node) continue;
      let low = 0, high = Math.min(1, scratch.fraction), intersects = true;
      for (let axis = 0; axis < 3; axis++) {
        const min = axis === 0 ? node.minX : axis === 1 ? node.minY : node.minZ;
        const max = axis === 0 ? node.maxX : axis === 1 ? node.maxY : node.maxZ;
        const origin = axis === 0 ? ox : axis === 1 ? oy : oz;
        const delta = axis === 0 ? dx : axis === 1 ? dy : dz;
        if (Math.abs(delta) < 1e-9) {
          if (origin < min || origin > max) { intersects = false; break; }
          continue;
        }
        let first = (min - origin) / delta, last = (max - origin) / delta;
        if (first > last) { const swap = first; first = last; last = swap; }
        low = Math.max(low, first); high = Math.min(high, last);
        if (low > high) { intersects = false; break; }
      }
      if (!intersects) continue;
      if (!node.count) {
        if (node.left >= 0) stack.push(node.left);
        if (node.right >= 0) stack.push(node.right);
        continue;
      }
      for (let index = node.start; index < node.start + node.count; index++) {
        testCollisionTriangle(data, data.order[index], ox, oy, oz, dx, dy, dz, scratch);
      }
    }
    return scratch;
  }

  private capsuleCandidates(from: Vec3, to: Vec3, radius: number, height: number, stepHeight: number): CollisionCandidates {
    const { stack, candidateTriangles } = this.collisionScratch;
    candidateTriangles.length = 0; stack.length = 0; stack.push(0);
    const pad = 1e-4;
    const minX = Math.min(from[0], to[0]) - radius - pad, maxX = Math.max(from[0], to[0]) + radius + pad;
    const minY = Math.min(from[1], to[1]) + CAPSULE_LEVELS[0] - pad;
    const maxY = Math.max(from[1], to[1]) + Math.min(stepHeight, 0.45) + Math.min(height, CAPSULE_LEVELS[CAPSULE_LEVELS.length - 1]) + pad;
    const minZ = Math.min(from[2], to[2]) - radius - pad, maxZ = Math.max(from[2], to[2]) + radius + pad;
    const { nodes, order, vertices } = this.buffers;
    const maximumReusableTriangles = 12;
    while (stack.length) {
      const node = nodes[stack.pop()!];
      if (!node || node.maxX < minX || node.minX > maxX || node.maxY < minY || node.minY > maxY || node.maxZ < minZ || node.minZ > maxZ) continue;
      if (!node.count) {
        if (node.left >= 0) stack.push(node.left);
        if (node.right >= 0) stack.push(node.right);
        continue;
      }
      for (let index = node.start; index < node.start + node.count; index++) {
        const offset = order[index] * 9;
        const ax = vertices[offset], ay = vertices[offset + 1], az = vertices[offset + 2];
        const bx = vertices[offset + 3], by = vertices[offset + 4], bz = vertices[offset + 5];
        const cx = vertices[offset + 6], cy = vertices[offset + 7], cz = vertices[offset + 8];
        if (Math.max(ax, bx, cx) < minX || Math.min(ax, bx, cx) > maxX || Math.max(ay, by, cy) < minY || Math.min(ay, by, cy) > maxY || Math.max(az, bz, cz) < minZ || Math.min(az, bz, cz) > maxZ) continue;
        candidateTriangles.push(order[index]);
        if (candidateTriangles.length > maximumReusableTriangles) { candidateTriangles.length = 0; return null; }
      }
    }
    return candidateTriangles;
  }

  rayBlocked(from: Vec3, to: Vec3): boolean {
    if (!finiteVec(from) || !finiteVec(to)) return true;
    const length = Math.hypot(to[0] - from[0], to[1] - from[1], to[2] - from[2]);
    if (length < 0.05) return false;
    const hit = this.collisionRaycast(from[0], from[1], from[2], to[0], to[1], to[2]);
    return hit.fraction <= 1 && hit.fraction > 0.02 / length && hit.fraction < 1 - 0.04 / length;
  }

  /** Highest walkable map surface below fromY, in world metres. */
  floorHeight(x: number, z: number, fromY = 100): number | undefined {
    if (![x, z, fromY].every(Number.isFinite)) return undefined;
    const hit = this.collisionRaycast(x, fromY, z, x, -100, z);
    if (hit.fraction > 1 || Math.abs(hit.normalY) < 0.5) return undefined;
    return fromY + (-100 - fromY) * hit.fraction;
  }

  private capsuleBlocked(from: Vec3, to: Vec3, radius: number, height: number, horizontalOnly = false, candidates?: CollisionCandidates): boolean {
    // A zero-length query cannot intersect a triangle in the existing ray model.
    if (from[0] === to[0] && from[1] === to[1] && from[2] === to[2]) return false;
    const deltaY = to[1] - from[1];
    for (const yOffset of CAPSULE_LEVELS) {
      if (yOffset > height) continue;
      let ringRadius = radius;
      if (yOffset < radius) ringRadius = Math.sqrt(Math.max(0, radius * radius - (radius - yOffset) ** 2));
      else if (yOffset > height - radius) ringRadius = Math.sqrt(Math.max(0, radius * radius - (yOffset - (height - radius)) ** 2));
      for (let spoke = 0; spoke < CAPSULE_SPOKES.length; spoke++) {
        const ox = CAPSULE_SPOKES[spoke][0] * ringRadius, oz = CAPSULE_SPOKES[spoke][1] * ringRadius;
        const hit = this.collisionRaycast(from[0] + ox, from[1] + yOffset, from[2] + oz, to[0] + ox, to[1] + yOffset, to[2] + oz, candidates);
        if (hit.fraction > 1 || hit.fraction <= 1e-4) continue;
        if (horizontalOnly && Math.abs(deltaY) < 1e-6 && Math.abs(hit.normalY) >= 0.5) continue;
        return true;
      }
    }
    return false;
  }

  /** Capsule move with axis sliding and the existing 0.45 m grounded step. */
  resolveMove(from: Vec3, to: Vec3, radius = 0.4, height = 1.8): Vec3 {
    if (!finiteVec(from)) return this.spawns[0];
    if (!finiteVec(to)) return from;
    if (![radius, height].every(Number.isFinite) || radius <= 0 || height < 2 * radius) return from;
    radius = Math.min(radius, 1.5); height = Math.min(height, 4);
    let x = from[0], y = from[1], z = from[2];
    const stepHeight = 0.45;
    const candidates = this.capsuleCandidates(from, to, radius, height, stepHeight);
    const targetFloor = this.floorHeight(to[0], to[2], y + stepHeight);
    if (targetFloor !== undefined && targetFloor > y + 0.03 && targetFloor <= y + stepHeight) {
      const steppedFrom: Vec3 = [x, targetFloor, z], steppedTarget: Vec3 = [to[0], targetFloor, to[2]];
      if (!this.capsuleBlocked(from, steppedFrom, radius, height, false, candidates) && !this.capsuleBlocked(steppedFrom, steppedTarget, radius, height, true, candidates)) { x = to[0]; y = targetFloor; z = to[2]; }
    }
    const moveAxis = (axis: 0 | 2, target: number): number => {
      const current: Vec3 = [x, y, z], destination: Vec3 = axis === 0 ? [target, y, z] : [x, y, target];
      if (!this.capsuleBlocked(current, destination, radius, height, true, candidates)) return target;
      let safe = 0, blocked = 1;
      for (let iteration = 0; iteration < 10; iteration++) {
        const middle = (safe + blocked) * 0.5;
        const candidate: Vec3 = axis === 0 ? [x + (target - x) * middle, y, z] : [x, y, z + (target - z) * middle];
        if (this.capsuleBlocked(current, candidate, radius, height, true, candidates)) blocked = middle; else safe = middle;
      }
      return axis === 0 ? x + (target - x) * safe : z + (target - z) * safe;
    };
    x = moveAxis(0, to[0]); z = moveAxis(2, to[2]);
    const floor = this.floorHeight(x, z, Math.max(y, to[1]) + stepHeight);
    let targetY = to[1];
    if (floor !== undefined && targetY <= floor && y >= floor - stepHeight) targetY = floor;
    const verticalFrom: Vec3 = [x, y, z], verticalTo: Vec3 = [x, targetY, z];
    if (!this.capsuleBlocked(verticalFrom, verticalTo, radius, height, false, candidates)) y = targetY;
    else {
      let safe = 0, blocked = 1;
      for (let iteration = 0; iteration < 10; iteration++) {
        const middle = (safe + blocked) * 0.5, candidate: Vec3 = [x, y + (targetY - y) * middle, z];
        if (this.capsuleBlocked(verticalFrom, candidate, radius, height, false, candidates)) blocked = middle; else safe = middle;
      }
      y += (targetY - y) * safe;
    }
    return [x, y, z];
  }
}

export function normalizeMapId(value: unknown): PlayableMap | null {
  const name = String(value ?? '').trim().toLowerCase();
  return (PLAYABLE_MAPS as readonly string[]).includes(name) ? name as PlayableMap : null;
}

/** Loads a validated map lazily and caches an immutable instance per map ID. */
export function loadWorldGeometry(mapName: unknown): WorldGeometry | null {
  const name = normalizeMapId(mapName);
  if (!name) return null;
  const cached = geometryCache.get(name);
  if (cached) return cached;
  const packed = readFileSync(new URL(`./data/maps/${name}.json.gz`, import.meta.url));
  const encoded = JSON.parse(gunzipSync(packed).toString('utf8')) as EncodedMap;
  const geometry = new WorldGeometry(name, encoded);
  geometryCache.set(name, geometry);
  return geometry;
}

/** Release an unused startup-prewarm reference; rooms already holding the instance remain safe. */
export function releaseWorldGeometry(mapName: unknown): void {
  const name = String(mapName ?? '').trim().toLowerCase() as PlayableMap;
  geometryCache.delete(name);
}

export const INDUSTRIAL_GEOMETRY = loadWorldGeometry('industrial')!;
export const INDUSTRIAL_SPAWNS = INDUSTRIAL_GEOMETRY.spawns;
export const INDUSTRIAL_VEHICLE_SPAWNS = INDUSTRIAL_GEOMETRY.vehicleSpawns;
export const INDUSTRIAL_NAV_STEP = INDUSTRIAL_GEOMETRY.navStep;

// Backward-compatible Industrial wrappers for existing hit/combat code and tests.
export const traceIndustrial = (from: Vec3, to: Vec3): (RayHit & { point: Vec3 }) | null => INDUSTRIAL_GEOMETRY.trace(from, to);
export const rayBlocked = (from: Vec3, to: Vec3): boolean => INDUSTRIAL_GEOMETRY.rayBlocked(from, to);
export const floorHeight = (x: number, z: number, fromY = 100): number | undefined => INDUSTRIAL_GEOMETRY.floorHeight(x, z, fromY);
export const resolveIndustrialMove = (from: Vec3, to: Vec3, radius = 0.4, height = 1.8): Vec3 => INDUSTRIAL_GEOMETRY.resolveMove(from, to, radius, height);
