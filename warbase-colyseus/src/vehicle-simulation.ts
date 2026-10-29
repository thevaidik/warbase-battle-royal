import { INDUSTRIAL_GEOMETRY, type Vec3, type WorldGeometry } from './world-geometry.js';

export type VehicleState = {
  id: string;
  pos: [number, number, number];
  yaw: number;
  speed: number;
  health: number;
  driver: string;
  gear: 1 | 2;
};
export type VehicleInput = { throttle: number; steer: number; brake: boolean; gear: number };
export type VehiclePlayer = {
  username: string;
  x: number; y: number; z: number;
  health: number; deaths: number; team: string; is_dead: boolean;
  driving_vehicle: string;
};
export type Roadkill = { driver: string; target: string; vehicle: string };
type RuntimeVehicle = {
  state: VehicleState;
  spawn: readonly [number, number, number, number];
  throttle: number;
  steer: number;
  brake: boolean;
  inputAt: number;
  destroyedAt: number;
  roadkillAt: Map<string, number>;
};

const clamp = (n: number, min: number, max: number): number => Math.max(min, Math.min(max, n));
const distance = (a: Vec3, b: Vec3): number => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);
function groundAt(geometry: WorldGeometry, p: Vec3): number | undefined {
  const from: Vec3 = [p[0], p[1] + 2.5, p[2]], to: Vec3 = [p[0], p[1] - 5, p[2]];
  const hit = geometry.trace(from, to);
  if (!hit || Math.abs(hit.normal[1]) < 0.65) return undefined;
  return from[1] + (to[1] - from[1]) * hit.fraction + 0.08;
}

function vehicleRayFraction(vehicle: VehicleState, from: Vec3, to: Vec3): number | null {
  const s = Math.sin(vehicle.yaw), c = Math.cos(vehicle.yaw);
  const local = (p: Vec3): Vec3 => {
    const x = p[0] - vehicle.pos[0], z = p[2] - vehicle.pos[2];
    return [c * x - s * z, p[1] - vehicle.pos[1], s * x + c * z];
  };
  const a = local(from), b = local(to), d: Vec3 = [b[0] - a[0], b[1] - a[1], b[2] - a[2]];
  const min: Vec3 = [-1.2, 0.15, -2.6], max: Vec3 = [1.2, 2.5, 2.6];
  let low = 0, high = 1;
  for (let axis = 0; axis < 3; axis++) {
    if (Math.abs(d[axis]) < 1e-8) {
      if (a[axis] < min[axis] || a[axis] > max[axis]) return null;
      continue;
    }
    let first = (min[axis] - a[axis]) / d[axis], last = (max[axis] - a[axis]) / d[axis];
    if (first > last) [first, last] = [last, first];
    low = Math.max(low, first); high = Math.min(high, last);
    if (low > high) return null;
  }
  return low;
}

function movementBlocked(geometry: WorldGeometry, from: Vec3, to: Vec3): boolean {
  for (const offset of [[0, 0.9, 0], [-0.25, 0.9, 0], [0.25, 0.9, 0], [0, 0.9, -0.25], [0, 0.9, 0.25]] as const) {
    const a: Vec3 = [from[0] + offset[0], from[1] + offset[1], from[2] + offset[2]];
    const b: Vec3 = [to[0] + offset[0], to[1] + offset[1], to[2] + offset[2]];
    const hit = geometry.trace(a, b);
    if (hit && hit.fraction > 0.0001) return true;
  }
  return false;
}

/**
 * Authoritative port of the Go Industrial vehicle controller. The module only
 * mutates its own vehicle state and the minimal occupant pose/seat fields;
 * the room owns score, health, protection, and network replication policy.
 */
export class VehicleSimulation {
  private readonly runtime = new Map<string, RuntimeVehicle>();

  constructor(private readonly geometry: WorldGeometry = INDUSTRIAL_GEOMETRY) {
    const spawns = geometry.vehicleSpawns;
    for (let i = 0; i < spawns.length; i++) {
      const spawn = spawns[i];
      if (spawn.length !== 4 || !spawn.every(Number.isFinite)) throw new Error(`Invalid authored vehicle spawn ${i}`);
      const ground = groundAt(geometry, [spawn[0], spawn[1], spawn[2]]);
      const position: [number, number, number] = [spawn[0], ground === undefined ? spawn[1] : ground, spawn[2]];
      const state: VehicleState = { id: `CAR_${i}`, pos: position, yaw: spawn[3], speed: 0, health: 1200, driver: '', gear: 1 };
      const safeSpawn = [position[0], position[1], position[2], spawn[3]] as const;
      this.runtime.set(state.id, { state, spawn: safeSpawn, throttle: 0, steer: 0, brake: false, inputAt: 0, destroyedAt: 0, roadkillAt: new Map() });
    }
  }

  /** True only while a vehicle is occupied or needs timed respawn processing. */
  get needsStep(): boolean {
    for (const vehicle of this.runtime.values()) if (vehicle.state.driver || vehicle.state.health <= 0) return true;
    return false;
  }

  get states(): ReadonlyMap<string, VehicleState> {
    return new Map([...this.runtime].map(([id, vehicle]) => [id, vehicle.state]));
  }

  /** Nearest segment/chassis OBB hit for authoritative bullets and visibility. */
  rayHit(from: Vec3, to: Vec3, ignoreDriver?: string): { id: string; fraction: number } | null {
    if (!from.every(Number.isFinite) || !to.every(Number.isFinite)) return null;
    let best: { id: string; fraction: number } | null = null;
    for (const { state } of this.runtime.values()) {
      if (ignoreDriver && state.driver === ignoreDriver) continue;
      const fraction = vehicleRayFraction(state, from, to);
      if (fraction !== null && (!best || fraction < best.fraction)) best = { id: state.id, fraction };
    }
    return best;
  }

  blocksRay(from: Vec3, to: Vec3, ignoreDriver?: string): boolean { return this.rayHit(from, to, ignoreDriver) !== null; }

  enter(player: VehiclePlayer, vehicleId: string, nowMs: number): boolean {
    const vehicle = this.runtime.get(vehicleId);
    if (!vehicle || !Number.isFinite(nowMs) || player.is_dead || player.driving_vehicle || vehicle.state.driver || vehicle.state.health <= 0) return false;
    if (distance([player.x, player.y, player.z], vehicle.state.pos) > 4.8) return false;
    if (this.geometry.rayBlocked([player.x, player.y + 1.35, player.z], [vehicle.state.pos[0], vehicle.state.pos[1] + 1.3, vehicle.state.pos[2]])) return false;
    vehicle.state.driver = player.username;
    vehicle.throttle = 0; vehicle.steer = 0; vehicle.state.speed = 0; vehicle.inputAt = nowMs;
    player.driving_vehicle = vehicleId;
    player.x = vehicle.state.pos[0]; player.y = vehicle.state.pos[1]; player.z = vehicle.state.pos[2];
    return true;
  }

  exit(player: VehiclePlayer): boolean {
    const vehicle = this.runtime.get(player.driving_vehicle);
    if (!vehicle || vehicle.state.driver !== player.username) return false;
    const [x, y, z] = vehicle.state.pos;
    const s = Math.sin(vehicle.state.yaw), c = Math.cos(vehicle.state.yaw);
    for (const offset of [[-2.2, 0, 0], [2.2, 0, 0], [0, 0, 3.3], [0, 0, -3.3]] as const) {
      const at: Vec3 = [x + c * offset[0] + s * offset[2], y, z - s * offset[0] + c * offset[2]];
      const ground = groundAt(this.geometry, at);
      if (ground === undefined || movementBlocked(this.geometry, vehicle.state.pos, at)) continue;
      player.x = at[0]; player.y = ground; player.z = at[2];
      vehicle.state.driver = ''; vehicle.throttle = 0; vehicle.steer = 0; vehicle.state.speed = 0;
      player.driving_vehicle = '';
      return true;
    }
    return false;
  }

  input(player: VehiclePlayer, input: VehicleInput, nowMs: number): boolean {
    const vehicle = this.runtime.get(player.driving_vehicle);
    if (!vehicle || vehicle.state.driver !== player.username || !Number.isFinite(nowMs) || ![input.throttle, input.steer].every(Number.isFinite) || typeof input.brake !== 'boolean') return false;
    vehicle.throttle = clamp(input.throttle, -1, 1);
    vehicle.steer = clamp(input.steer, -1, 1);
    vehicle.brake = input.brake;
    vehicle.inputAt = nowMs;
    vehicle.state.gear = input.gear === 2 ? 2 : 1;
    return true;
  }

  /** Returns roadkill candidates; the room must apply team, protection, score, and respawn policy. */
  step(dt: number, nowMs: number, players: ReadonlyMap<string, VehiclePlayer>): Roadkill[] {
    if (!Number.isFinite(dt) || dt <= 0 || !Number.isFinite(nowMs)) return [];
    const elapsed = Math.min(dt, 0.1);
    const roadkills: Roadkill[] = [];
    for (const vehicle of this.runtime.values()) {
      const state = vehicle.state;
      if (state.health <= 0) {
        if (vehicle.destroyedAt > 0 && nowMs - vehicle.destroyedAt > 20_000) {
          state.health = 1200; state.pos = [vehicle.spawn[0], vehicle.spawn[1], vehicle.spawn[2]]; state.yaw = vehicle.spawn[3];
          vehicle.destroyedAt = 0; state.driver = '';
        }
        continue;
      }
      const player = players.get(state.driver);
      if (!player || player.is_dead || player.driving_vehicle !== state.id) {
        state.driver = ''; state.speed = 0; continue;
      }
      if (nowMs - vehicle.inputAt > 300) { vehicle.throttle = 0; vehicle.steer = 0; vehicle.brake = true; }
      const speedCap = state.gear === 2 ? 22 : 14.4;
      let acceleration = vehicle.throttle * 9 - state.speed * 0.24;
      if (vehicle.brake) acceleration -= state.speed * 6;
      state.speed = clamp(state.speed + acceleration * elapsed, -6, speedCap);
      if (Math.abs(state.speed) < 0.05 && vehicle.throttle === 0) state.speed = 0;
      const yaw = state.yaw - vehicle.steer * state.speed / 5 * elapsed;
      const from = state.pos;
      const to: Vec3 = [from[0] - Math.sin(yaw) * state.speed * elapsed, from[1], from[2] - Math.cos(yaw) * state.speed * elapsed];
      let blocked = false;
      for (const offset of [[0, 0, 0], [-1.1, 0, -2.4], [1.1, 0, -2.4], [-1.1, 0, 2.4], [1.1, 0, 2.4]] as const) {
        const rot: Vec3 = [Math.cos(yaw) * offset[0] + Math.sin(yaw) * offset[2], 0, -Math.sin(yaw) * offset[0] + Math.cos(yaw) * offset[2]];
        const a: Vec3 = [from[0] + rot[0], from[1], from[2] + rot[2]], b: Vec3 = [to[0] + rot[0], to[1], to[2] + rot[2]];
        for (const other of this.runtime.values()) {
          if (other !== vehicle && vehicleRayFraction(other.state, [b[0], b[1] + 0.9, b[2]], [b[0], b[1] + 0.9, b[2]]) !== null) { blocked = true; break; }
        }
        if (blocked || movementBlocked(this.geometry, a, b)) { blocked = true; break; }
      }
      const ground = groundAt(this.geometry, to);
      if (!blocked && ground !== undefined && Math.abs(ground - from[1]) < 0.6) {
        state.pos = [to[0], ground, to[2]]; state.yaw = yaw;
      } else state.speed = 0;
      player.x = state.pos[0]; player.y = state.pos[1]; player.z = state.pos[2];
      if (Math.abs(state.speed) > 5) {
        for (const target of players.values()) {
          if (target.username === player.username || target.is_dead || target.driving_vehicle || (vehicle.roadkillAt.get(target.username) ?? -Infinity) + 1000 > nowMs) continue;
          if (distance([player.x, player.y, player.z], [target.x, target.y, target.z]) < 2) {
            vehicle.roadkillAt.set(target.username, nowMs);
            roadkills.push({ driver: player.username, target: target.username, vehicle: state.id });
          }
        }
      }
    }
    return roadkills;
  }

  damage(vehicleId: string, amount: number, nowMs: number): { destroyed: boolean; driver: string } | null {
    const vehicle = this.runtime.get(vehicleId);
    if (!vehicle || !Number.isFinite(amount) || amount <= 0 || !Number.isFinite(nowMs) || vehicle.state.health <= 0) return null;
    vehicle.state.health = Math.max(0, vehicle.state.health - Math.trunc(amount));
    if (vehicle.state.health > 0) return { destroyed: false, driver: vehicle.state.driver };
    vehicle.destroyedAt = nowMs;
    vehicle.state.speed = 0;
    return { destroyed: true, driver: vehicle.state.driver };
  }
}
