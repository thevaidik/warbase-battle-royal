import { readFileSync } from 'node:fs';
import { gunzipSync } from 'node:zlib';
import { capsuleTriangle, type CapsuleContact } from './capsule-contact.js';

// These IDs exactly match MainMenu.PLAYABLE_MAPS in the Godot client. Keep the
// list explicit so unsupported maps fail closed instead of receiving fake floors.
export const PLAYABLE_MAPS = Object.freeze(['football', 'industrial', 'village', 'arena', 'dust2', 'nuketown', 'canyon', 'military_base', 'ghost_city', 'cosmodrome', 'dam', 'skyline'] as const);
export type PlayableMap = typeof PLAYABLE_MAPS[number];
export type Vec3 = readonly [x: number, y: number, z: number];

/** Settlement uses capsule support; quantizing a free-flight pose is not contact. */
export function settledVerticalVelocity(vy: number, requestedY: number, resolvedY: number, grounded: boolean): number {
  if (vy < 0 && grounded) return 0;
  if (vy > 0 && resolvedY < requestedY - 0.001) return 0;
  return vy;
}

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
function canonicalMove(p: Vec3): Vec3 { return p.map(value => Math.floor(value * 1000 + 0.5) / 1000) as unknown as Vec3; }

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
  private flightPropVertices = new Float32Array();
  private flightPropBounds: Array<{min: Vec3;max: Vec3;first: number}> = [];
  readonly vehicleSpawns: readonly (readonly [number, number, number, number])[];
  private readonly buffers: GeometryBuffers;
  // World queries are synchronous in the room loop. Reusing this traversal
  // storage avoids allocating a stack and hit objects for every capsule spoke.
  private readonly collisionScratch: CollisionScratch = { stack: [], candidateTriangles: [], fraction: 2, normalY: 0 };
  private readonly candidateBufferPool: number[][] = [[], [], [], []];
  private readonly candidateStackPool: number[][] = [[], [], [], []];

  private leaseCandidateBuffer(): number[] {
    const buf = this.candidateBufferPool.pop() ?? [];
    buf.length = 0;
    return buf;
  }

  private releaseCandidateBuffer(buf: number[]): void {
    buf.length = 0;
    if (this.candidateBufferPool.length < 8) this.candidateBufferPool.push(buf);
  }

  private leaseStack(): number[] {
    const s = this.candidateStackPool.pop() ?? [];
    s.length = 0;
    return s;
  }

  private releaseStack(s: number[]): void {
    s.length = 0;
    if (this.candidateStackPool.length < 8) this.candidateStackPool.push(s);
  }

  constructor(name: PlayableMap, encoded: EncodedMap) {
    this.name = name;
    this.navStep = Number.isFinite(encoded.nav_step) && (encoded.nav_step ?? 0) > 0 ? encoded.nav_step! : 2;
    this.buffers = validateMap(name, encoded);
    if (!Array.isArray(encoded.spawns) || encoded.spawns.length === 0) throw new Error(`Invalid authored ${name} spawns`);
    this.spawns = Object.freeze(encoded.spawns.map((spawn) => {
      if (spawn.length !== 3 || !spawn.every(Number.isFinite)) throw new Error(`Invalid authored ${name} spawn`);
      // Some authored markers (notably the Industrial scenery variants) put
      // the feet below the rendered road. A capsule starting embedded cannot
      // escape through an ordinary sweep. Raise only to a nearby walkable
      // surface; do not cast from the sky and accidentally choose a rooftop.
      const nearbyFloor = this.floorHeight(spawn[0], spawn[2], spawn[1] + 0.6);
      const y = nearbyFloor !== undefined && nearbyFloor > spawn[1] ? nearbyFloor + 0.02 : spawn[1];
      return Object.freeze([spawn[0], y, spawn[2]]) as Vec3;
    }));
    this.vehicleSpawns = Object.freeze((encoded.vehicles ?? []).map((spawn) => {
      if (spawn.length !== 4 || !spawn.every(Number.isFinite)) throw new Error(`Invalid authored ${name} vehicle spawn`);
      return Object.freeze([spawn[0], spawn[1], spawn[2], spawn[3]]) as readonly [number, number, number, number];
    }));
    this.buildFlightProps();
  }

  /** Stationary vehicle chassis/cabin shapes remain world obstacles in drone
   * mode. Reuse the same sphere/triangle solver, not a separate collision rule. */
  private buildFlightProps(): void {
    const vertices:number[]=[];
    const faces=[[0,2,1],[0,3,2],[4,5,6],[4,6,7],[0,1,5],[0,5,4],[3,7,6],[3,6,2],[0,4,7],[0,7,3],[1,2,6],[1,6,5]];
    for(const spawn of this.vehicleSpawns) {
      const hit=this.trace([spawn[0],spawn[1]+2.5,spawn[2]],[spawn[0],spawn[1]-5,spawn[2]]);
      const baseY=hit&&Math.abs(hit.normal[1])>=.65?hit.point[1]+.08:spawn[1];
      for(const [lo,hi] of [[[-1.15,.4,-2.5],[1.15,1.5,2.5]],[[-1.1,1.475,-1.8],[1.1,2.425,2.2]]] as const) {
        const c=Math.cos(spawn[3]),ss=Math.sin(spawn[3]);
        const points:Vec3[]=[[lo[0],lo[1],lo[2]],[hi[0],lo[1],lo[2]],[hi[0],hi[1],lo[2]],[lo[0],hi[1],lo[2]],[lo[0],lo[1],hi[2]],[hi[0],lo[1],hi[2]],[hi[0],hi[1],hi[2]],[lo[0],hi[1],hi[2]]].map(p=>[Math.fround(spawn[0]+c*p[0]+ss*p[2]),Math.fround(baseY+p[1]),Math.fround(spawn[2]-ss*p[0]+c*p[2])]);
        this.flightPropBounds.push({min:[Math.min(...points.map(p=>p[0])),Math.min(...points.map(p=>p[1])),Math.min(...points.map(p=>p[2]))],max:[Math.max(...points.map(p=>p[0])),Math.max(...points.map(p=>p[1])),Math.max(...points.map(p=>p[2]))],first:vertices.length/9});
        for(const face of faces)for(const index of face)vertices.push(...points[index]);
      }
    }
    this.flightPropVertices=Float32Array.from(vertices);
  }

  private contactTriangle(at:Vec3,radius:number,height:number,triangle:number,margin:number):CapsuleContact|null {
    return capsuleTriangle(at,radius,height,triangle<0?this.flightPropVertices:this.buffers.vertices,triangle<0?-triangle-1:triangle,margin);
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

  private collectCapsuleCandidatesInto(from: Vec3, to: Vec3, radius: number, height: number, stepHeight: number, output: number[]): void {
    const stack = this.leaseStack();
    stack.push(0);
    const pad = 1e-4;
    const minX = Math.min(from[0], to[0]) - radius - stepHeight - pad, maxX = Math.max(from[0], to[0]) + radius + stepHeight + pad;
    const minY = Math.min(from[1], to[1]) - stepHeight - radius - pad;
    const maxY = Math.max(from[1], to[1]) + stepHeight + height + radius + pad;
    const minZ = Math.min(from[2], to[2]) - radius - stepHeight - pad, maxZ = Math.max(from[2], to[2]) + radius + stepHeight + pad;
    const { nodes, order, vertices } = this.buffers;

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
        output.push(order[index]);
      }
    }
    this.releaseStack(stack);
  }

  private capsuleCandidates(from: Vec3, to: Vec3, radius: number, height: number, stepHeight: number): CollisionCandidates {
    const { candidateTriangles } = this.collisionScratch;
    candidateTriangles.length = 0;
    this.collectCapsuleCandidatesInto(from, to, radius, height, stepHeight, candidateTriangles);
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

  private contacts(at: Vec3, radius: number, height: number, margin: number, candidates: readonly number[]): CapsuleContact[] {
    const contacts: CapsuleContact[] = [];
    for (const triangle of candidates) {
      const hit = this.contactTriangle(at, radius, height, triangle, margin);
      if (hit) contacts.push(hit);
    }
    return contacts;
  }

  private hasContactDeeperThan(at: Vec3, radius: number, height: number, margin: number, candidates: readonly number[], minDepth: number): boolean {
    for (const triangle of candidates) {
      const hit = this.contactTriangle(at, radius, height, triangle, margin);
      if (hit && hit.depth > minDepth) return true;
    }
    return false;
  }

  private hasAnyContact(at: Vec3, radius: number, height: number, margin: number, candidates: readonly number[]): boolean {
    for (const triangle of candidates) {
      const hit = this.contactTriangle(at, radius, height, triangle, margin);
      if (hit) return true;
    }
    return false;
  }

  private hasBlockingCeilingContact(at: Vec3, radius: number, height: number, margin: number, candidates: readonly number[], normalYThreshold = -0.5): boolean {
    for (const triangle of candidates) {
      const hit = this.contactTriangle(at, radius, height, triangle, margin);
      if (hit && hit.normal[1] < normalYThreshold) return true;
    }
    return false;
  }

  private hasGroundSupport(at: Vec3, radius: number, height: number, margin: number, candidates: readonly number[]): boolean {
    for (const triangle of candidates) {
      const hit = this.contactTriangle(at, radius, height, triangle, margin);
      if (hit && (hit.normal[1] >= 0.5 || (Math.abs(hit.surfaceNormalY) >= 0.5 && hit.normal[1] > 0.05)) && hit.depth <= 0.09) {
        return true;
      }
    }
    return false;
  }

  /** The actual lower hemisphere must touch a walkable surface. A centre ray
   * cannot describe support at a ledge, on stairs, or on sloping terrain. */
  isGrounded(at: Vec3, radius = 0.4, height = 1.8): boolean {
    if (!finiteVec(at)) return false;
    const candidates = this.leaseCandidateBuffer();
    try {
      this.collectCapsuleCandidatesInto(at, at, radius + 0.06, height, 0, candidates);
      return this.hasGroundSupport(at, radius, height, 0.055, candidates);
    } finally {
      this.releaseCandidateBuffer(candidates);
    }
  }

  /** Drone state is its centre; the shared contact primitive uses feet origin.
   * Ground profiles may request a short step using the same swept contact solver. */
  resolveFlightMove(from: Vec3, to: Vec3, radius = 0.4, stepHeight = 0): Vec3 {
    const feet: Vec3=[from[0],from[1]-radius,from[2]];
    const target: Vec3=[to[0],to[1]-radius,to[2]];
    const result=this.resolveMove(feet, target, radius, radius * 2, stepHeight > 0, stepHeight, true);
    return [result[0],result[1]+radius,result[2]];
  }

  /** Substepped swept-volume collision with contact-plane sliding. The same
   * capsule dimensions, skin, iterations and stepping rule run in Godot. */
  resolveMove(from: Vec3, to: Vec3, radius = 0.4, height = 1.8, allowStep = true, stepHeight = 0.45, droneMove = false): Vec3 {
    if (!finiteVec(from)) return this.spawns[0];
    if (!finiteVec(to) || ![radius, height].every(Number.isFinite) || radius <= 0 || height < 2 * radius) return from;
    radius = Math.min(radius, 1.5); height = Math.min(height, 4);
    const grounded = allowStep && this.isGrounded(from, radius, height);
    const candidates = this.leaseCandidateBuffer();
    try {
      this.collectCapsuleCandidatesInto(from, to, radius, height, Math.max(0.5, stepHeight), candidates);
      if (!allowStep || droneMove) for (const box of this.flightPropBounds) {
        if(box.max[0]<Math.min(from[0],to[0])-radius-.5 || box.min[0]>Math.max(from[0],to[0])+radius+.5 || box.max[1]<Math.min(from[1],to[1])-.5 || box.min[1]>Math.max(from[1],to[1])+height+.5 || box.max[2]<Math.min(from[2],to[2])-radius-.5 || box.min[2]>Math.max(from[2],to[2])+radius+.5)continue;
        for(let i=0;i<12;i++)candidates.push(-(box.first+i+1));
      }
      const skin = 0.008;
      const recover = (start: Vec3): Vec3 => {
        let p: Vec3 = start;
        for (let iteration = 0; iteration < 4; iteration++) {
          let corrected = false;
          // Recompute each contact after previous corrections; applying stale
          // depths twice at a shared triangle edge would launch the capsule.
          for (const triangle of candidates) {
            const hit = this.contactTriangle(p, radius, height, triangle, skin);
            if (!hit || hit.depth <= 0.000001) continue;
            p = [p[0] + hit.normal[0] * hit.depth, p[1] + hit.normal[1] * hit.depth, p[2] + hit.normal[2] * hit.depth];
            corrected = true;
          }
          if (!corrected) break;
        }
        return p;
      };
      const attempt = (previous: Vec3, desired: Vec3): Vec3 => {
        const next = recover(desired);
        if (Math.hypot(next[0]-desired[0],next[1]-desired[1],next[2]-desired[2]) > 0.2) return previous;
        return this.hasContactDeeperThan(next, radius, height, skin, candidates, 0.001) ? previous : next;
      };
      const advance = (previous: Vec3, desired: Vec3): Vec3 => {
        const next=attempt(previous,desired);
        const nextCell=canonicalMove(next),previousCell=canonicalMove(previous);
        if(nextCell.some((value,axis)=>value!==previousCell[axis]))return next;
        // An impossible horizontal gap must not cancel gravity or tangential
        // movement. Resolve the unblocked components from the last clear pose.
        let result=previous;
        for(const axis of [1,0,2] as const) {
          const amount=desired[axis]-previous[axis];
          if(amount===0)continue;
          const target: [number,number,number]=[...result];target[axis]+=amount;
          result=attempt(result,target);
        }
        return result;
      };
      const delta: Vec3 = [to[0]-from[0],to[1]-from[1],to[2]-from[2]];
      const count = Math.max(1, Math.ceil(Math.hypot(...delta) / Math.min(radius * 0.25, 0.1)));
      // Reject malicious/unbounded teleports; normal fixed-tick movement is 1–3 steps.
      if (count > 512) return from;
      let p = advance(from,from);
      for (let i=0;i<count;i++) p = advance(p,[p[0]+delta[0]/count,p[1]+delta[1]/count,p[2]+delta[2]/count]);
      const horizontal = Math.hypot(delta[0],delta[2]);
      // Grounded standing must not turn gravity into sideways slope motion.
      if (grounded && horizontal === 0 && delta[1] <= 0) return canonicalMove(advance(from,from));
      // Up/forward/down stepping only starts from support, never during a jump.
      const stepTolerance = droneMove ? Math.min(0.01, horizontal * 0.25) : 0.01;
      if (grounded && delta[1] <= 0 && horizontal > 0.000001 && ((p[0]-from[0])*delta[0]+(p[2]-from[2])*delta[2])/horizontal < horizontal - stepTolerance) {
        const up: Vec3 = [from[0],from[1]+stepHeight,from[2]];
        if (!this.hasAnyContact(up, radius, height, skin, candidates)) {
          let step = up;
          for(let i=0;i<count;i++) step=advance(step,[step[0]+delta[0]/count,step[1],step[2]+delta[2]/count]);
          // A step must not teleport through a ceiling on its way up.
          let clear=true;
          for(let lift=0.1;lift<stepHeight;lift+=0.1) if(this.hasBlockingCeilingContact([from[0],from[1]+lift,from[2]], radius, height, 0, candidates, -0.5)){clear=false;break;}
          if(clear) {
            for(let i=0;i<6;i++) step=advance(step,[step[0],step[1]-stepHeight/6,step[2]]);
            if (((step[0]-p[0])*delta[0]+(step[2]-p[2])*delta[2])/horizontal > 0.001 && this.isGrounded(step,radius,height)) p=step;
          }
        }
      }
      return canonicalMove(p);
    } finally {
      this.releaseCandidateBuffer(candidates);
    }
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
