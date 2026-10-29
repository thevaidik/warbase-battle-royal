import { INDUSTRIAL_GEOMETRY, type Vec3, type WorldGeometry } from './world-geometry.js';

export type ThrowableKind = 'frag' | 'impact';
export type Grenade = {
  id: number;
  owner: string;
  kind: ThrowableKind;
  position: [number, number, number];
  velocity: [number, number, number];
  age: number;
};
export type GrenadeLaunch = { owner: string; kind: string; position: Vec3; velocity: Vec3 };
export type GrenadeExplosion = { id: number; owner: string; kind: ThrowableKind; position: Vec3 };
export type RadialDamage = { target: string; damage: number; distance: number };

const GRAVITY = 9.81;
const AIR_DRAG = 0.035;
const RADIUS = 0.06;
const RESTITUTION = 0.35;
const TANGENT_RETENTION = 0.70;
const GROUND_FRICTION = 10;
const MAX_ACTIVE = 128;
const SUBSTEP = 1 / 120;

const finiteVec = (v: Vec3): boolean => v.length === 3 && v.every(Number.isFinite);
const dot = (a: Vec3, b: Vec3): number => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const sub = (a: Vec3, b: Vec3): [number, number, number] => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const distance = (a: Vec3, b: Vec3): number => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);

/** Go-server launch validation (ammo/selection ownership is supplied by the room). */
export function validateGrenadeLaunch(
  launch: GrenadeLaunch,
  player: Vec3,
  eye: Vec3,
  expectedKind: ThrowableKind,
  lastThrowMs: number,
  nowMs: number,
  grenadesRemaining: number,
  geometry: WorldGeometry = INDUSTRIAL_GEOMETRY,
): boolean {
  if (!launch.owner || launch.kind !== expectedKind || !finiteVec(launch.position) || !finiteVec(launch.velocity) || !finiteVec(player) || !finiteVec(eye)) return false;
  if (!Number.isFinite(nowMs) || !Number.isFinite(lastThrowMs) || !Number.isFinite(grenadesRemaining) || grenadesRemaining <= 0) return false;
  if (nowMs - lastThrowMs < 1000 || Math.hypot(...launch.velocity) > 30) return false;
  if (distance(launch.position, player) > 4 || geometry.rayBlocked(eye, launch.position)) return false;
  return true;
}

/** Match the industrial Go grenade collision sweep: center plus six radius offsets. */
function grenadeTrace(geometry: WorldGeometry, from: Vec3, to: Vec3): { fraction: number; normal: Vec3 } | null {
  const offsets: Vec3[] = [[0, 0, 0], [RADIUS, 0, 0], [-RADIUS, 0, 0], [0, RADIUS, 0], [0, -RADIUS, 0], [0, 0, RADIUS], [0, 0, -RADIUS]];
  let closest: { fraction: number; normal: Vec3 } | null = null;
  for (const offset of offsets) {
    const start: Vec3 = [from[0] + offset[0], from[1] + offset[1], from[2] + offset[2]];
    const end: Vec3 = [to[0] + offset[0], to[1] + offset[1], to[2] + offset[2]];
    const hit = geometry.trace(start, end);
    if (hit && (!closest || hit.fraction < closest.fraction)) closest = { fraction: hit.fraction, normal: hit.normal };
  }
  if (!closest) return null;
  const movement = sub(to, from);
  if (dot(movement, closest.normal) > 0) closest.normal = [-closest.normal[0], -closest.normal[1], -closest.normal[2]];
  return closest;
}

function advance(geometry: WorldGeometry, grenade: Grenade, dt: number): boolean {
  grenade.velocity[1] -= GRAVITY * dt * 0.5;
  for (let axis = 0; axis < 3; axis++) grenade.velocity[axis] *= Math.max(0, 1 - AIR_DRAG * dt);
  let remaining = dt;
  for (let bounce = 0; bounce < 4; bounce++) {
    const end: Vec3 = [
      grenade.position[0] + grenade.velocity[0] * remaining,
      grenade.position[1] + grenade.velocity[1] * remaining,
      grenade.position[2] + grenade.velocity[2] * remaining,
    ];
    const hit = grenadeTrace(geometry, grenade.position, end);
    if (!hit) {
      grenade.position = [...end];
      break;
    }
    const step = sub(end, grenade.position);
    for (let axis = 0; axis < 3; axis++) grenade.position[axis] += step[axis] * hit.fraction + hit.normal[axis] * 0.002;
    if (grenade.kind === 'impact' && grenade.age >= 0.18) {
      grenade.velocity = [0, 0, 0];
      return true;
    }
    const incoming = dot(grenade.velocity, hit.normal);
    const tangent: Vec3 = [grenade.velocity[0] - hit.normal[0] * incoming, grenade.velocity[1] - hit.normal[1] * incoming, grenade.velocity[2] - hit.normal[2] * incoming];
    if (-incoming > 1.5) {
      grenade.velocity = [
        tangent[0] * TANGENT_RETENTION - hit.normal[0] * incoming * RESTITUTION,
        tangent[1] * TANGENT_RETENTION - hit.normal[1] * incoming * RESTITUTION,
        tangent[2] * TANGENT_RETENTION - hit.normal[2] * incoming * RESTITUTION,
      ];
    } else grenade.velocity = [...tangent];
    remaining *= 1 - hit.fraction;
    if (remaining < 0.00001) break;
  }
  grenade.velocity[1] -= GRAVITY * dt * 0.5;
  if (Math.abs(grenade.velocity[1]) < 1) {
    const end: Vec3 = [grenade.position[0], grenade.position[1] - 0.025, grenade.position[2]];
    const hit = grenadeTrace(geometry, grenade.position, end);
    if (hit && hit.normal[1] > 0.65) {
      grenade.position[1] -= 0.025 * hit.fraction;
      for (let axis = 0; axis < 3; axis++) grenade.position[axis] += hit.normal[axis] * 0.002;
      const projection = dot(grenade.velocity, hit.normal);
      const tangent: Vec3 = [grenade.velocity[0] - hit.normal[0] * projection, grenade.velocity[1] - hit.normal[1] * projection, grenade.velocity[2] - hit.normal[2] * projection];
      const speed = Math.hypot(...tangent);
      const factor = speed > 0 ? Math.max(0, 1 - GROUND_FRICTION * dt / speed) : 0;
      grenade.velocity = [tangent[0] * factor, tangent[1] * factor, tangent[2] * factor];
    }
  }
  return false;
}

/** Damage is line-of-sight attenuated exactly as in the Go grenade implementation. */
export function grenadeDamageAt(kind: ThrowableKind, explosion: Vec3, target: Vec3, geometry: WorldGeometry = INDUSTRIAL_GEOMETRY): number {
  if (!finiteVec(explosion) || !finiteVec(target) || geometry.rayBlocked(explosion, target)) return 0;
  const d = distance(explosion, target);
  const radius = kind === 'impact' ? 5.5 : 8.5;
  const peak = kind === 'impact' ? 75 : 90;
  return d >= radius ? 0 : Math.max(0, Math.trunc(peak * (1 - d / radius)));
}

/** Vehicle damage uses the corresponding four-times player-damage peak. */
export function grenadeVehicleDamageAt(kind: ThrowableKind, explosion: Vec3, vehicleCenter: Vec3, geometry: WorldGeometry = INDUSTRIAL_GEOMETRY): number {
  const damage = grenadeDamageAt(kind, explosion, vehicleCenter, geometry);
  return damage === 0 ? 0 : damage * 4;
}

/**
 * Deterministic fixed-step throwable simulation. Room policy and health/score
 * mutation are emitted as events so BattleRoom can reuse its own authority path.
 */
export class GrenadeSimulation {
  private sequence = 0;
  private readonly active = new Map<number, Grenade>();

  constructor(private readonly geometry: WorldGeometry = INDUSTRIAL_GEOMETRY) {}

  get grenades(): readonly Grenade[] { return [...this.active.values()]; }
  get hasGrenades(): boolean { return this.active.size > 0; }

  launch(input: GrenadeLaunch): Grenade | null {
    if (!input.owner || !finiteVec(input.position) || !finiteVec(input.velocity) || (input.kind !== 'frag' && input.kind !== 'impact') || Math.hypot(...input.velocity) > 30 || this.active.size >= MAX_ACTIVE) return null;
    const grenade: Grenade = {
      id: ++this.sequence,
      owner: input.owner,
      kind: input.kind,
      position: [...input.position],
      velocity: [...input.velocity],
      age: 0,
    };
    this.active.set(grenade.id, grenade);
    return grenade;
  }

  step(dt: number): GrenadeExplosion[] {
    if (!Number.isFinite(dt) || dt <= 0) return [];
    const elapsed = Math.min(dt, 0.25);
    const steps = Math.max(1, Math.ceil(elapsed / SUBSTEP));
    const step = elapsed / steps;
    const exploded: GrenadeExplosion[] = [];
    for (const grenade of this.active.values()) {
      let impact = false;
      for (let i = 0; i < steps; i++) {
        grenade.age += step;
        if (advance(this.geometry, grenade, step)) { impact = true; break; }
      }
      const fuse = grenade.kind === 'impact' ? 1.8 : 3;
      if (impact || grenade.age >= fuse) {
        exploded.push({ id: grenade.id, owner: grenade.owner, kind: grenade.kind, position: [...grenade.position] });
        this.active.delete(grenade.id);
      }
    }
    return exploded;
  }

  clear(): void { this.active.clear(); }
}
