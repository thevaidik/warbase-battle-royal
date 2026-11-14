import {
  FuzzyModule, FuzzyVariable, LeftShoulderFuzzySet, TriangularFuzzySet, RightShoulderFuzzySet,
  FuzzyRule, FuzzyAND,
} from 'yuka';
import { BotSteering } from './bot-steering.js';
import { INDUSTRIAL_GEOMETRY, type Vec3, type WorldGeometry } from './world-geometry.js';
import { DRONE_SPAWN_OFFSET, stepDroneFlight, sampleChassisGroundRays, DRONE_RADIUS } from './drone-flight.js';

export type BotPlayer = {
  username: string;
  is_bot?: boolean;
  x: number; y: number; z: number;
  vx?: number; vy?: number; vz?: number;
  qy?: number; qw?: number; yaw?: number; pitch?: number;
  health: number; kills: number; deaths: number; team: string; is_dead: boolean;
  weapon_id: string; ammo: number; driving_vehicle?: string; animation?: string;
  mobility_mode?: string;
};
export type BotShot = { shooter: string; target: string; weapon: string; origin: Vec3; endpoint: Vec3; shotId: number };
export type BotRosterChange = { joined: BotPlayer[]; removed: string[] };
export type BotObjectiveGoal = { position: Vec3; radius?: number };
export type BotUpdateCallbacks = {
  onShot: (shot: BotShot) => void;
  onSmoke?: (bot: BotPlayer) => void;
  vehicleBlocked?: (position: Vec3) => boolean;
  objectiveGoal?: (bot: BotPlayer) => BotObjectiveGoal | Vec3 | undefined;
};

export type TacticalState = 'PATROL' | 'ATTACK' | 'FLANK' | 'TAKE_COVER' | 'SEARCH';

export function maxHealthForChassis(mode?: string): number {
  switch (mode) {
    case 'tracked': return 220;
    case 'wheels': return 170;
    case 'heli': return 100;
    case 'wing': return 75;
    default: return 100;
  }
}

/** Yuka Fuzzy Logic Decision Module for human-like risk evaluation. */
export class TacticalFuzzyBrain {
  private readonly fm = new FuzzyModule();

  constructor() {
    const healthVar = new FuzzyVariable();
    const lowHealth = new LeftShoulderFuzzySet(0, 25, 42);
    const medHealth = new TriangularFuzzySet(30, 55, 80);
    const highHealth = new RightShoulderFuzzySet(65, 85, 100);
    healthVar.add(lowHealth); healthVar.add(medHealth); healthVar.add(highHealth);
    this.fm.addFLV('health', healthVar);

    const distVar = new FuzzyVariable();
    const closeDist = new LeftShoulderFuzzySet(0, 6, 12);
    const medDist = new TriangularFuzzySet(9, 18, 30);
    const farDist = new RightShoulderFuzzySet(22, 35, 60);
    distVar.add(closeDist); distVar.add(medDist); distVar.add(farDist);
    this.fm.addFLV('distance', distVar);

    const ammoVar = new FuzzyVariable();
    const emptyAmmo = new LeftShoulderFuzzySet(0, 0.15, 0.32);
    const fullAmmo = new RightShoulderFuzzySet(0.50, 0.75, 1.0);
    ammoVar.add(emptyAmmo); ammoVar.add(fullAmmo);
    this.fm.addFLV('ammo', ammoVar);

    const coverVar = new FuzzyVariable();
    const lowCover = new LeftShoulderFuzzySet(0, 20, 40);
    const medCover = new TriangularFuzzySet(30, 50, 70);
    const highCover = new RightShoulderFuzzySet(60, 80, 100);
    coverVar.add(lowCover); coverVar.add(medCover); coverVar.add(highCover);
    this.fm.addFLV('cover', coverVar);

    const attackVar = new FuzzyVariable();
    const lowAttack = new LeftShoulderFuzzySet(0, 20, 40);
    const medAttack = new TriangularFuzzySet(30, 50, 70);
    const highAttack = new RightShoulderFuzzySet(60, 80, 100);
    attackVar.add(lowAttack); attackVar.add(medAttack); attackVar.add(highAttack);
    this.fm.addFLV('attack', attackVar);

    this.fm.addRule(new FuzzyRule(lowHealth, highCover));
    this.fm.addRule(new FuzzyRule(emptyAmmo, highCover));
    this.fm.addRule(new FuzzyRule(new FuzzyAND(highHealth, fullAmmo), lowCover));
    this.fm.addRule(new FuzzyRule(medHealth, medCover));

    this.fm.addRule(new FuzzyRule(new FuzzyAND(highHealth, fullAmmo), highAttack));
    this.fm.addRule(new FuzzyRule(lowHealth, lowAttack));
    this.fm.addRule(new FuzzyRule(emptyAmmo, lowAttack));
    this.fm.addRule(new FuzzyRule(medHealth, medAttack));
  }

  evaluate(health: number, distance: number, ammoRatio: number, maxHealth = 100): { cover: number; attack: number } {
    const healthPercent = maxHealth > 0 ? (health / maxHealth) * 100 : health;
    this.fm.fuzzify('health', Math.max(0, Math.min(100, healthPercent)));
    this.fm.fuzzify('distance', Math.max(0, Math.min(60, distance)));
    this.fm.fuzzify('ammo', Math.max(0, Math.min(1.0, ammoRatio)));
    return {
      cover: this.fm.defuzzify('cover'),
      attack: this.fm.defuzzify('attack'),
    };
  }
}


type NavNode = { position: Vec3; edges: number[] };
type Brain = {
  steering: BotSteering;
  role: number;
  seed: number;
  state: TacticalState;
  target: string;
  lastKnown: Vec3;
  targetVelocity: Vec3;
  visible: boolean;
  seenUntil: number;
  reactAt: number;
  perceiveAt: number;
  planAt: number;
  nextShotAt: number;
  burstUntil: number;
  shotsInBurst: number;
  path: number[];
  waypoint: number;
  deathAt: number;
  protectedUntil: number;
  reloadUntil: number;
  lastProgressAt: number;
  progressPoint: Vec3;
  stuckSince: number;
  ammo: number;
  shotId: number;
  aimSwayOffset: [number, number];
  aimSwayAt: number;
  strafeDirection: number;
  strafeUntil: number;
  coverPoint?: Vec3;
  firstShotGrace: boolean;
  aimSettledAt: number;
  trackingNoiseX: number;
  trackingNoiseY: number;
  trackingNoiseAt: number;
  lastSmokeAt: number;
};

const BOT_NAMES = ['VIPER', 'KESTREL', 'GHOST', 'ROOK', 'NOMAD', 'LYNX', 'WRAITH'];
const BOT_WEAPONS = ['m4', 'mp5', 'ak47', 'dmr'];
const BOT_CHASSIS = ['heli', 'tracked', 'wheels', 'wing'] as const;
const BOT_MAGAZINES: Record<string, number> = { m4: 30, mp5: 30, ak47: 30, dmr: 20 };
const BOT_RPM: Record<string, number> = { m4: 750, mp5: 850, ak47: 600, dmr: 240 };
const BOT_RELOAD_MS: Record<string, number> = { m4: 2200, mp5: 1800, ak47: 2500, dmr: 2600 };
const NAV_NEIGHBORS = [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]] as const;
const vector = (p: Pick<BotPlayer, 'x' | 'y' | 'z'>): Vec3 => [p.x, p.y, p.z];
const dist = (a: Vec3, b: Vec3): number => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);
const distSquared = (a: Vec3, b: Vec3): number => {
  const dx = a[0] - b[0], dy = a[1] - b[1], dz = a[2] - b[2];
  return dx * dx + dy * dy + dz * dz;
};
const dot = (a: Vec3, b: Vec3): number => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const finite = (n: number): boolean => Number.isFinite(n);

function movementBlocked(geometry: WorldGeometry, from: Vec3, to: Vec3): boolean {
  return dist(to, geometry.resolveFlightMove(from, to)) > 0.08;
}

function buildNavigation(geometry: WorldGeometry): NavNode[] {
  if (geometry.spawns.length === 0) return [];
  const lowY = Math.min(...geometry.spawns.map((p) => p[1]));
  const highY = Math.max(...geometry.spawns.map((p) => p[1]));
  const lowX = Math.min(...geometry.spawns.map((p) => p[0]));
  const highX = Math.max(...geometry.spawns.map((p) => p[0]));
  const lowZ = Math.min(...geometry.spawns.map((p) => p[2]));
  const highZ = Math.max(...geometry.spawns.map((p) => p[2]));
  const step = geometry.navStep;
  const cells = new Map<string, number[]>();
  const nodes: NavNode[] = [];
  const cellKey = (x: number, z: number): string => `${x},${z}`;
  const minX = Math.floor((lowX - 10) / step), maxX = Math.ceil((highX + 10) / step);
  const minZ = Math.floor((lowZ - 10) / step), maxZ = Math.ceil((highZ + 10) / step);
  for (let x = minX; x <= maxX; x++) for (let z = minZ; z <= maxZ; z++) {
    let origin: Vec3 = [x * step, highY + 1, z * step];
    const endY = lowY - 3;
    for (let layer = 0; layer < 8 && origin[1] > endY; layer++) {
      const hit = geometry.trace(origin, [origin[0], endY, origin[2]]);
      if (!hit) break;
      const y = origin[1] + (endY - origin[1]) * hit.fraction;
      origin = [origin[0], y - 0.08, origin[2]];
      if (Math.abs(hit.normal[1]) < 0.7) continue;
      const position: Vec3 = [x * step, y + DRONE_SPAWN_OFFSET, z * step];
      let clear = true;
      for (const offset of [[0, 0], [0.32, 0], [-0.32, 0], [0, 0.32], [0, -0.32]] as const) {
        if (geometry.trace([position[0] + offset[0], y + 0.15, position[2] + offset[1]], [position[0] + offset[0], y + 1.8, position[2] + offset[1]])) { clear = false; break; }
      }
      if (!clear) continue;
      const index = nodes.length;
      nodes.push({ position, edges: [] });
      const key = cellKey(x, z), indices = cells.get(key) ?? [];
      indices.push(index); cells.set(key, indices);
    }
  }
  for (const [key, indices] of cells) {
    const [x, z] = key.split(',').map(Number);
    for (const i of indices) for (const [dx, dz] of NAV_NEIGHBORS) {
      for (const j of cells.get(cellKey(x + dx, z + dz)) ?? []) {
        const a = nodes[i].position, b = nodes[j].position;
        if (Math.abs(a[1] - b[1]) > 0.6 || movementBlocked(geometry, a, b)) continue;
        const mid: Vec3 = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2];
        const support = geometry.trace([mid[0], mid[1] + 0.3, mid[2]], [mid[0], mid[1] - DRONE_SPAWN_OFFSET - 0.65, mid[2]]);
        if (support) nodes[i].edges.push(j);
      }
    }
  }
  return nodes;
}

class MinHeap {
  private items: { node: number; score: number }[] = [];
  get size(): number { return this.items.length; }
  push(item: { node: number; score: number }): void {
    let i = this.items.push(item) - 1;
    while (i > 0) {
      const parent = (i - 1) >> 1;
      if (this.items[parent].score <= item.score) break;
      this.items[i] = this.items[parent]; i = parent;
    }
    this.items[i] = item;
  }
  pop(): { node: number; score: number } | undefined {
    const root = this.items[0], last = this.items.pop();
    if (!root || !last || this.items.length === 0) return root;
    let i = 0;
    while (true) {
      const left = i * 2 + 1, right = left + 1;
      if (left >= this.items.length) break;
      const child = right < this.items.length && this.items[right].score < this.items[left].score ? right : left;
      if (this.items[child].score >= last.score) break;
      this.items[i] = this.items[child]; i = child;
    }
    this.items[i] = last;
    return root;
  }
}

const sharedNavigation = new Map<string, NavNode[]>();

/** Build and cache collision-derived navigation before listeners accept joins. */
export function prewarmBotNavigation(geometry: WorldGeometry): void {
  if (!sharedNavigation.has(geometry.name)) sharedNavigation.set(geometry.name, buildNavigation(geometry));
}

/**
 * Inserts a candidate into an ascending-sorted bounded array of at most `capacity` items.
 * Preserves original nodeIndex as tie-breaker (stable sort equivalence).
 * Returns the new count (at most capacity).
 */
export function insertNearestCandidate(
  indices: Int32Array,
  distances: Float64Array,
  count: number,
  capacity: number,
  nodeIndex: number,
  distSq: number
): number {
  if (count === capacity && distSq > distances[capacity - 1]) {
    return count;
  }
  if (count === capacity && distSq === distances[capacity - 1] && nodeIndex >= indices[capacity - 1]) {
    return count;
  }
  let insertAt = count;
  for (let i = 0; i < count; i++) {
    if (distSq < distances[i] || (distSq === distances[i] && nodeIndex < indices[i])) {
      insertAt = i;
      break;
    }
  }
  const end = Math.min(count, capacity - 1);
  for (let i = end; i > insertAt; i--) {
    indices[i] = indices[i - 1];
    distances[i] = distances[i - 1];
  }
  if (insertAt < capacity) {
    indices[insertAt] = nodeIndex;
    distances[insertAt] = distSq;
  }
  return Math.min(count + 1, capacity);
}

/** Server-owned Industrial bots: collision-derived A*, visibility, reaction delay, magazines, burst cadence and respawn. */
export class BotSimulation {
  private sequence = 0;
  private readonly brains = new Map<string, Brain>();
  private readonly fuzzy = new TacticalFuzzyBrain();
  private readonly nearestIndices = new Int32Array(8);
  private readonly nearestDistances = new Float64Array(8);
  private readonly coverIndices = new Int32Array(16);
  private readonly coverDistances = new Float64Array(16);
  constructor(private readonly geometry: WorldGeometry = INDUSTRIAL_GEOMETRY) {}

  private navigation(): NavNode[] {
    prewarmBotNavigation(this.geometry);
    return sharedNavigation.get(this.geometry.name)!;
  }

  get botIds(): readonly string[] { return [...this.brains.keys()]; }
  get hasBots(): boolean { return this.brains.size > 0; }

  /** Adds up to 7 bots when humans are present; they yield slots as humans join. */
  sync(humans: readonly BotPlayer[], nowMs: number, mode: 'TDM' | 'FFA' = 'TDM'): BotRosterChange {
    const humanPlayers = humans.filter((player) => !player.is_bot);
    const desired = humanPlayers.length > 0 ? Math.max(0, Math.min(7, 8 - humanPlayers.length)) : 0;
    const removed: string[] = [];
    for (const id of this.brains.keys()) {
      if (this.brains.size <= desired) break;
      this.brains.delete(id); removed.push(id);
    }
    const joined: BotPlayer[] = [];
    while (this.brains.size < desired) {
      const n = ++this.sequence;
      const name = `[BOT] ${BOT_NAMES[(n - 1) % BOT_NAMES.length]}-${String(n).padStart(2, '0')}`;
      const groundSpawn = this.geometry.spawns[(n - 1) % this.geometry.spawns.length];
      const spawn: Vec3 = [groundSpawn[0], groundSpawn[1] + DRONE_SPAWN_OFFSET, groundSpawn[2]];
      const weapon = BOT_WEAPONS[(n - 1) % BOT_WEAPONS.length];
      let team = 'NONE';
      if (mode === 'TDM') {
        const teamA = humanPlayers.filter((p) => p.team === 'A').length + joined.filter((p) => p.team === 'A').length;
        const teamB = humanPlayers.filter((p) => p.team === 'B').length + joined.filter((p) => p.team === 'B').length;
        team = teamA <= teamB ? 'A' : 'B';
      }
      const chassis = BOT_CHASSIS[(n - 1) % BOT_CHASSIS.length];
      const bot: BotPlayer = { username: name, is_bot: true, x: spawn[0], y: spawn[1], z: spawn[2], vx: 0, vy: 0, vz: 0, qy: 0, qw: 1, yaw: 0, pitch: 0,
        health: maxHealthForChassis(chassis), kills: 0, deaths: 0, team, is_dead: false, weapon_id: weapon, ammo: BOT_MAGAZINES[weapon], driving_vehicle: '', mobility_mode: chassis };
      const seed = (n * 0x9e3779b1) >>> 0;
      this.brains.set(name, {
        steering: new BotSteering(), role: n % 3, seed, state: 'PATROL', target: '', lastKnown: spawn, targetVelocity: [0, 0, 0], visible: false, seenUntil: 0,
        reactAt: nowMs + 600, perceiveAt: 0, planAt: 0, nextShotAt: 0, burstUntil: 0, shotsInBurst: 0,
        path: [], waypoint: 0, deathAt: 0, protectedUntil: nowMs + 2500, reloadUntil: 0, lastProgressAt: nowMs, progressPoint: spawn, stuckSince: 0,
        ammo: BOT_MAGAZINES[weapon], shotId: 0,
        aimSwayOffset: [0, 0], aimSwayAt: 0, strafeDirection: n % 2 === 0 ? 1 : -1, strafeUntil: 0,
        firstShotGrace: true, aimSettledAt: 0, trackingNoiseX: 0, trackingNoiseY: 0, trackingNoiseAt: 0,
        lastSmokeAt: 0,
      });
      joined.push(bot);
    }
    if (this.brains.size > 0) this.navigation();
    return { joined, removed };
  }

  markDead(id: string, nowMs: number): void { const brain = this.brains.get(id); if (brain) brain.deathAt = nowMs; }

  step(players: ReadonlyMap<string, BotPlayer>, dt: number, nowMs: number, callbacks: BotUpdateCallbacks): void {
    if (!Number.isFinite(dt) || dt <= 0 || !Number.isFinite(nowMs)) return;
    const elapsed = Math.min(dt, 0.1), nodes = this.navigation();
    if (!nodes.length) return;
    for (const [id, brain] of this.brains) {
      const bot = players.get(id);
      if (!bot) continue;
      if (bot.is_dead) {
        if (brain.deathAt > 0 && nowMs - brain.deathAt >= 3000) this.respawn(bot, brain, nowMs);
        continue;
      }
      const wasVisible = brain.visible;
      if (nowMs >= brain.perceiveAt) this.perceive(bot, brain, players, nowMs, wasVisible);
      if (wasVisible && !brain.visible && nowMs <= brain.seenUntil) {
        brain.planAt = Math.min(brain.planAt, nowMs + 100);
        if (brain.state === 'ATTACK' || brain.state === 'FLANK') brain.state = 'SEARCH';
      }
      const weapon = bot.weapon_id in BOT_MAGAZINES ? bot.weapon_id : 'ak47';
      if (brain.reloadUntil > 0 && nowMs >= brain.reloadUntil) {
        brain.reloadUntil = 0; brain.ammo = BOT_MAGAZINES[weapon]; bot.ammo = brain.ammo; bot.animation = 'idle';
      } else if (brain.reloadUntil === 0 && (brain.ammo <= 0 || (!brain.visible && brain.ammo < BOT_MAGAZINES[weapon] / 2))) {
        brain.reloadUntil = nowMs + BOT_RELOAD_MS[weapon]; bot.animation = 'reload';
      }
      if (nowMs >= brain.planAt) this.plan(bot, brain, nodes, nowMs, callbacks.vehicleBlocked, callbacks.objectiveGoal, callbacks.onSmoke);
      this.move(bot, brain, nodes, elapsed, nowMs, players, callbacks.vehicleBlocked);
      if (brain.reloadUntil === 0 && brain.visible && nowMs >= brain.reactAt && nowMs >= brain.nextShotAt && nowMs >= brain.burstUntil) {
        const target = players.get(brain.target);
        if (target && this.enemy(bot, target) && !this.geometry.rayBlocked(this.eye(bot), this.eye(target))) {
          // Use the freshly observed position only while the target remains visible.
          brain.lastKnown = vector(target);
          brain.targetVelocity = [target.vx ?? 0, target.vy ?? 0, target.vz ?? 0];
          if (this.aimAligned(bot, brain.lastKnown)) this.fire(bot, target, brain, nowMs, callbacks.onShot);
        } else {
          brain.visible = false;
        }
      }
    }
  }

  private random(brain: Brain): number {
    let x = brain.seed | 0;
    x ^= x << 13; x ^= x >>> 17; x ^= x << 5;
    brain.seed = x >>> 0;
    return brain.seed / 0x1_0000_0000;
  }
  private normal(brain: Brain): number { return Math.sqrt(-2 * Math.log(Math.max(1e-9, this.random(brain)))) * Math.cos(2 * Math.PI * this.random(brain)); }
  private enemy(a: BotPlayer, b: BotPlayer): boolean { return a.username !== b.username && !b.is_dead && (!a.team || a.team === 'NONE' || a.team !== b.team); }
  private eye(p: BotPlayer): Vec3 { return [p.x, p.y, p.z]; }

  private perceive(bot: BotPlayer, brain: Brain, players: ReadonlyMap<string, BotPlayer>, nowMs: number, wasVisible = false): void {
    brain.perceiveAt = nowMs + 140 + Math.floor(this.random(brain) * 80);
    brain.visible = false;
    let bestScore = Infinity;
    const pos = vector(bot), yaw = finite(bot.yaw ?? 0) ? (bot.yaw ?? 0) : 0;
    const forward: Vec3 = [-Math.sin(yaw), 0, -Math.cos(yaw)];
    for (const target of players.values()) {
      if (!this.enemy(bot, target) || target.driving_vehicle) continue;
      const targetPos = vector(target), dSquared = distSquared(pos, targetPos);
      if (dSquared > 4900) continue;
      const to: Vec3 = [targetPos[0] - pos[0], targetPos[1] - pos[1], targetPos[2] - pos[2]];
      const forwardDistance = dot(to, forward);
      const inView = dSquared < 100 || (forwardDistance > 0 && forwardDistance * forwardDistance > dSquared * 0.0025);
      const visible = inView && !this.geometry.rayBlocked(this.eye(bot), this.eye(target));
      const score = dSquared * (target.username === brain.target ? 0.64 : 1);
      if (visible && score < bestScore) {
        bestScore = score;
        const isNewTarget = brain.target !== target.username;
        const reacquiredSight = !wasVisible;
        if (isNewTarget) {
          brain.reactAt = nowMs + 380 + Math.floor(this.random(brain) * 240);
          brain.shotsInBurst = 0;
          brain.firstShotGrace = true;
        } else if (reacquiredSight) {
          // Human perception re-acquisition buffer upon re-spotting target
          brain.reactAt = Math.max(brain.reactAt, nowMs + 240 + Math.floor(this.random(brain) * 160));
          brain.firstShotGrace = true;
        }
        brain.target = target.username;
        brain.lastKnown = targetPos;
        brain.targetVelocity = [target.vx ?? 0, target.vy ?? 0, target.vz ?? 0];
        brain.seenUntil = nowMs + 3200;
        brain.visible = true;
      }
    }
  }

  private nearest(nodes: readonly NavNode[], point: Vec3): number {
    let count = 0;
    for (let index = 0; index < nodes.length; index++) {
      const distance = distSquared(point, nodes[index].position);
      if (distance < 81 && Math.abs(point[1] - nodes[index].position[1]) < 7) {
        count = insertNearestCandidate(this.nearestIndices, this.nearestDistances, count, 8, index, distance);
      }
    }
    // The collision sweep is the expensive part. Try the closest links first
    // and keep a blocked spawn or target from consuming a whole server tick.
    for (let i = 0; i < count; i++) {
      const index = this.nearestIndices[i];
      if (!movementBlocked(this.geometry, point, nodes[index].position)) return index;
    }
    return -1;
  }

  private path(nodes: readonly NavNode[], start: number, goal: number, blocked?: (position: Vec3) => boolean): number[] {
    if (start < 0 || goal < 0) return [];
    const frontier = new MinHeap(), cost = new Map<number, number>([[start, 0]]), previous = new Map<number, number>([[start, -1]]);
    frontier.push({ node: start, score: 0 });
    for (let expanded = 0; frontier.size && expanded < 6000; expanded++) {
      const current = frontier.pop()!.node;
      if (current === goal) {
        const result: number[] = [];
        for (let at = current; at !== -1; at = previous.get(at) ?? -1) result.push(at);
        return result.reverse();
      }
      for (const next of nodes[current].edges) {
        if (blocked?.(nodes[next].position)) continue;
        const candidate = cost.get(current)! + dist(nodes[current].position, nodes[next].position);
        if (candidate < (cost.get(next) ?? Infinity)) {
          cost.set(next, candidate); previous.set(next, current);
          frontier.push({ node: next, score: candidate + dist(nodes[next].position, nodes[goal].position) });
        }
      }
    }
    return [];
  }

  private findTacticalCover(botPos: Vec3, threatPos: Vec3, nodes: readonly NavNode[], anchorPos?: Vec3, anchorRadius?: number): Vec3 | undefined {
    let bestNode: Vec3 | undefined;
    let bestScore = Infinity;
    const currentDist = dist(botPos, threatPos);
    let count = 0;
    for (let i = 0; i < nodes.length; i++) {
      const dSq = distSquared(botPos, nodes[i].position);
      if (dSq >= 4 && dSq <= 256) {
        if (anchorPos && anchorRadius && dist(nodes[i].position, anchorPos) > anchorRadius) continue;
        count = insertNearestCandidate(this.coverIndices, this.coverDistances, count, 16, i, dSq);
      }
    }
    for (let i = 0; i < count; i++) {
      const nodeIndex = this.coverIndices[i];
      const distSq = this.coverDistances[i];
      const candidatePos = nodes[nodeIndex].position;
      if (this.geometry.rayBlocked(threatPos, candidatePos)) {
        const distFromThreat = dist(candidatePos, threatPos);
        const retreatBonus = distFromThreat >= currentDist ? -3 : 6;
        const score = Math.sqrt(distSq) + retreatBonus;
        if (score < bestScore) {
          bestScore = score;
          bestNode = candidatePos;
        }
      }
    }
    return bestNode;
  }

  private plan(bot: BotPlayer, brain: Brain, nodes: readonly NavNode[], nowMs: number, vehicleBlocked?: (p: Vec3) => boolean, objectiveGoal?: (bot: BotPlayer) => BotObjectiveGoal | Vec3 | undefined, onSmoke?: (bot: BotPlayer) => void): void {
    brain.planAt = nowMs + 650 + Math.floor(this.random(brain) * 300);
    const rawObj = objectiveGoal?.(bot);
    const isObj = rawObj !== undefined && 'position' in rawObj;
    const objectivePos: Vec3 | undefined = isObj ? rawObj.position : (rawObj as Vec3 | undefined);
    const objectiveRadius: number = isObj && typeof rawObj.radius === 'number' ? rawObj.radius : 12;
    const distToObjective = objectivePos ? dist(vector(bot), objectivePos) : Infinity;
    const isAtObjective = objectivePos !== undefined && distToObjective <= objectiveRadius;

    const d = dist(vector(bot), brain.lastKnown);
    const maxAmmo = BOT_MAGAZINES[bot.weapon_id] ?? 30;
    const ammoRatio = brain.ammo / maxAmmo;
    const isReloading = brain.reloadUntil > nowMs || brain.ammo <= 0;
    const fuzzy = this.fuzzy.evaluate(bot.health, d, isReloading ? 0 : ammoRatio, maxHealthForChassis(bot.mobility_mode));

    const enemyInSight = brain.visible;
    const enemyRemembered = !enemyInSight && nowMs <= brain.seenUntil;

    if (enemyInSight || enemyRemembered) {
      if (isReloading || fuzzy.cover > 55) {
        brain.state = 'TAKE_COVER';
        if (bot.health / maxHealthForChassis(bot.mobility_mode) < 0.35 && nowMs - brain.lastSmokeAt > 16000) {
          brain.lastSmokeAt = nowMs;
          onSmoke?.(bot);
        }
      } else if (enemyInSight) {
        if (!isAtObjective && (brain.role === 2 || (brain.role === 1 && d > 16))) {
          brain.state = 'FLANK';
        } else {
          brain.state = 'ATTACK';
        }
      } else {
        brain.state = isAtObjective ? 'ATTACK' : 'SEARCH';
      }
    } else {
      brain.state = 'PATROL';
    }

    // Keep a useful patrol route instead of choosing a random destination each plan tick.
    if (brain.state === 'PATROL' && !objectivePos && brain.waypoint < brain.path.length && nowMs - brain.lastProgressAt < 1500) {
      return;
    }

    const start = this.nearest(nodes, vector(bot));
    let goal: Vec3;

    switch (brain.state) {
      case 'TAKE_COVER': {
        const cover = this.findTacticalCover(
          vector(bot),
          brain.lastKnown,
          nodes,
          isAtObjective ? objectivePos : undefined,
          isAtObjective ? objectiveRadius * 0.85 : undefined
        );
        if (cover) {
          goal = cover;
          brain.coverPoint = cover;
        } else if (isAtObjective && objectivePos) {
          const dx = brain.lastKnown[0] - objectivePos[0], dz = brain.lastKnown[2] - objectivePos[2];
          const dThreat = Math.max(Math.hypot(dx, dz), 1);
          const rearOffset = Math.min(objectiveRadius * 0.6, 6.0);
          goal = [
            objectivePos[0] - (dx / dThreat) * rearOffset,
            objectivePos[1],
            objectivePos[2] - (dz / dThreat) * rearOffset,
          ];
        } else {
          const dx = brain.lastKnown[0] - bot.x, dz = brain.lastKnown[2] - bot.z;
          const d = Math.max(Math.hypot(dx, dz), 1);
          goal = [bot.x - (dx / d) * 10, bot.y, bot.z - (dz / d) * 10];
        }
        break;
      }

      case 'ATTACK': {
        if (isAtObjective && objectivePos) {
          const toThreatX = brain.lastKnown[0] - objectivePos[0];
          const toThreatZ = brain.lastKnown[2] - objectivePos[2];
          const threatD = Math.max(Math.hypot(toThreatX, toThreatZ), 0.001);
          const holdRadius = Math.min(objectiveRadius * 0.60, 7.0);
          const lateral = (brain.role - 1) * 2.2;
          goal = [
            objectivePos[0] + (toThreatX / threatD) * holdRadius - (toThreatZ / threatD) * lateral,
            objectivePos[1],
            objectivePos[2] + (toThreatZ / threatD) * holdRadius + (toThreatX / threatD) * lateral,
          ];
        } else if (objectivePos && d > 20) {
          goal = objectivePos;
        } else {
          const dx = brain.lastKnown[0] - bot.x, dz = brain.lastKnown[2] - bot.z;
          const d = Math.max(Math.hypot(dx, dz), 1);
          const preferredRange = bot.weapon_id === 'mp5' ? 7 : bot.weapon_id === 'dmr' ? 24 : 12;
          const lateral = (brain.role - 1) * 5;
          goal = [
            brain.lastKnown[0] - (dx / d) * preferredRange - (dz / d) * lateral,
            brain.lastKnown[1],
            brain.lastKnown[2] - (dz / d) * preferredRange + (dx / d) * lateral,
          ];
        }
        break;
      }

      case 'FLANK': {
        if (isAtObjective && objectivePos) {
          const toThreatX = brain.lastKnown[0] - objectivePos[0];
          const toThreatZ = brain.lastKnown[2] - objectivePos[2];
          const threatD = Math.max(Math.hypot(toThreatX, toThreatZ), 0.001);
          const holdRadius = Math.min(objectiveRadius * 0.65, 7.5);
          const flankSign = brain.role === 2 ? 1 : -1;
          const flankOffset = flankSign * 3.0;
          goal = [
            objectivePos[0] + (toThreatX / threatD) * holdRadius - (toThreatZ / threatD) * flankOffset,
            objectivePos[1],
            objectivePos[2] + (toThreatZ / threatD) * holdRadius + (toThreatX / threatD) * flankOffset,
          ];
        } else if (objectivePos && d > 20) {
          goal = objectivePos;
        } else {
          const dx = brain.lastKnown[0] - bot.x, dz = brain.lastKnown[2] - bot.z;
          const d = Math.max(Math.hypot(dx, dz), 1);
          const preferredRange = bot.weapon_id === 'mp5' ? 8 : 14;
          const flankSign = brain.role === 2 ? 1 : -1;
          const flankOffset = flankSign * (preferredRange * 0.7);
          goal = [
            brain.lastKnown[0] - (dx / d) * preferredRange - (dz / d) * flankOffset,
            brain.lastKnown[1],
            brain.lastKnown[2] - (dz / d) * preferredRange + (dx / d) * flankOffset,
          ];
        }
        break;
      }

      case 'SEARCH': {
        if (isAtObjective && objectivePos) {
          goal = objectivePos;
        } else {
          goal = brain.lastKnown;
        }
        break;
      }

      case 'PATROL':
      default: {
        if (objectivePos) {
          if (isAtObjective) {
            const angle = (brain.role * (Math.PI * 2 / 3)) + ((nowMs % 12000) / 12000) * (Math.PI * 2);
            const patrolOffset = Math.min(objectiveRadius * 0.40, 4.0);
            goal = [
              objectivePos[0] + Math.cos(angle) * patrolOffset,
              objectivePos[1],
              objectivePos[2] + Math.sin(angle) * patrolOffset,
            ];
          } else {
            goal = objectivePos;
          }
        } else {
          const spawn = this.geometry.spawns[Math.floor(this.random(brain) * this.geometry.spawns.length)];
          goal = [spawn[0], spawn[1] + DRONE_SPAWN_OFFSET, spawn[2]];
        }
        break;
      }
    }

    let end = this.nearest(nodes, goal);
    if (end < 0) end = this.nearest(nodes, brain.lastKnown);
    brain.path = this.path(nodes, start, end, vehicleBlocked);
    brain.waypoint = Math.min(1, brain.path.length);
  }

  private face(bot: BotPlayer, target: Vec3, dt: number, nowMs?: number, leadVelocity?: Vec3, brain?: Brain): void {
    let targetPoint: Vec3 = target;
    if (leadVelocity && (leadVelocity[0] !== 0 || leadVelocity[2] !== 0)) {
      const d = dist(vector(bot), target);
      let leadNoise = 1.0;
      if (brain && nowMs) {
        if (nowMs >= brain.trackingNoiseAt) {
          brain.trackingNoiseX = (this.random(brain) - 0.5) * 0.35;
          brain.trackingNoiseY = (this.random(brain) - 0.5) * 0.20;
          brain.trackingNoiseAt = nowMs + 350 + Math.floor(this.random(brain) * 250);
        }
        leadNoise += brain.trackingNoiseX;
      }
      const leadTime = Math.min(d / 140, 0.22) * Math.max(0.65, Math.min(1.35, leadNoise));
      targetPoint = [
        target[0] + leadVelocity[0] * leadTime,
        target[1] + leadVelocity[1] * leadTime,
        target[2] + leadVelocity[2] * leadTime,
      ];
    }
    const dx = targetPoint[0] - bot.x, dz = targetPoint[2] - bot.z;
    const horizontal = Math.max(Math.hypot(dx, dz), 0.001);
    const desiredYaw = Math.atan2(-dx, -dz);
    const desiredPitch = -Math.atan2(targetPoint[1] - bot.y, horizontal);
    const currentYaw = finite(bot.yaw ?? 0) ? (bot.yaw ?? 0) : 0;
    const yawDelta = Math.abs(Math.atan2(Math.sin(desiredYaw - currentYaw), Math.cos(desiredYaw - currentYaw)));
    if (brain && nowMs && yawDelta > 0.45) {
      brain.aimSettledAt = Math.max(brain.aimSettledAt, nowMs + 200);
    }
    const turn = (current: number, desired: number, maxStep: number): number => {
      const delta = Math.atan2(Math.sin(desired - current), Math.cos(desired - current));
      return current + Math.max(-maxStep, Math.min(maxStep, delta));
    };
    const mode = bot.mobility_mode ?? 'heli';
    const maxYawRate = mode === 'tracked' ? 1.0 : mode === 'wheels' ? 1.4 : mode === 'wing' ? 1.7 : 2.0;
    const maxPitchRate = mode === 'tracked' || mode === 'wheels' ? 1.0 : 1.6;
    const yaw = turn(currentYaw, desiredYaw, maxYawRate * dt);
    const pitch = turn(finite(bot.pitch ?? 0) ? (bot.pitch ?? 0) : 0, desiredPitch, maxPitchRate * dt);
    bot.yaw = yaw; bot.pitch = pitch; bot.qy = Math.sin(yaw / 2); bot.qw = Math.cos(yaw / 2);
  }

  private aimAligned(bot: BotPlayer, target: Vec3): boolean {
    const dx = target[0] - bot.x, dz = target[2] - bot.z;
    const horizontal = Math.max(Math.hypot(dx, dz), 0.001);
    const desiredYaw = Math.atan2(-dx, -dz);
    const desiredPitch = -Math.atan2(target[1] - bot.y, horizontal);
    const yawError = Math.abs(Math.atan2(Math.sin(desiredYaw - (bot.yaw ?? 0)), Math.cos(desiredYaw - (bot.yaw ?? 0))));
    const pitchError = Math.abs(desiredPitch - (bot.pitch ?? 0));
    return yawError < 0.12 && pitchError < 0.10;
  }

  private move(bot: BotPlayer, brain: Brain, nodes: readonly NavNode[], dt: number, nowMs: number, players: ReadonlyMap<string, BotPlayer>, vehicleBlocked?: (p: Vec3) => boolean): void {
    if (dist(vector(bot), brain.progressPoint) > 0.35) { brain.lastProgressAt = nowMs; brain.progressPoint = vector(bot); }
    if (brain.waypoint < brain.path.length && nowMs - brain.lastProgressAt > 1500) { brain.planAt = Math.min(brain.planAt, nowMs + 150); brain.lastProgressAt = nowMs; }
    let goal: Vec3 | undefined;
    const isFinalWaypoint = brain.waypoint === brain.path.length - 1;
    if (brain.waypoint < brain.path.length) {
      goal = nodes[brain.path[brain.waypoint]].position;
      if (dist(vector(bot), goal) < 0.45) {
        brain.waypoint++;
        goal = brain.path[brain.waypoint] === undefined ? undefined : nodes[brain.path[brain.waypoint]].position;
      }
    }
    const from = vector(bot), yaw = finite(bot.yaw ?? 0) ? bot.yaw ?? 0 : 0;
    let moveX = 0, moveY = 0, moveZ = 0;
    if (goal && !vehicleBlocked?.(goal)) {
      if (brain.visible && (brain.state === 'ATTACK' || brain.state === 'FLANK')) {
        if (nowMs >= brain.strafeUntil) {
          brain.strafeDirection = this.random(brain) > 0.5 ? 1 : -1;
          brain.strafeUntil = nowMs + 1400 + Math.floor(this.random(brain) * 1200);
        }
      } else {
        brain.strafeDirection = 0;
      }
      const strafe = brain.visible ? brain.strafeDirection * 0.4 : 0;

      // Collect nearby friendly bots to apply Yuka SeparationBehavior
      const neighbors: Vec3[] = [];
      const botPos = vector(bot);
      for (const other of players.values()) {
        if (other.username !== bot.username && other.is_bot && !other.is_dead) {
          const dSq = distSquared(botPos, vector(other));
          if (dSq > 0.001 && dSq < 25) neighbors.push(vector(other));
        }
      }

      const command = brain.steering.command(from, [bot.vx ?? 0, bot.vy ?? 0, bot.vz ?? 0], goal, yaw, isFinalWaypoint, { strafe, neighbors });
      moveX = command.x; moveY = command.y; moveZ = command.z;
      const botMode = bot.mobility_mode ?? 'heli';
      if (!brain.visible) {
        this.face(bot, goal, dt);
      } else if (botMode === 'tracked' || botMode === 'wheels') {
        // Angling front armor toward threat: face attacker so 0.75x front slope deflects shots
        this.face(bot, brain.lastKnown, dt, nowMs, brain.targetVelocity, brain);
      }
    }
    const mode = bot.mobility_mode ?? 'heli';
    const flight = stepDroneFlight(this.geometry, from, [bot.vx ?? 0, bot.vy ?? 0, bot.vz ?? 0], { move_x: moveX, move_y: moveY, move_z: moveZ, yaw: bot.yaw ?? yaw, sprint: 0, mobility_mode: mode }, dt);
    let finalPos = flight.position;
    if (mode === 'tracked' || mode === 'wheels') {
      const groundProfile = sampleChassisGroundRays(this.geometry, finalPos, bot.yaw ?? 0);
      if (groundProfile.grounded) {
        finalPos = [finalPos[0], groundProfile.groundY + DRONE_RADIUS, finalPos[2]];
        bot.pitch = groundProfile.pitch;
      }
    }
    const moved = dist(from, finalPos);
    bot.x = finalPos[0]; bot.y = finalPos[1]; bot.z = finalPos[2];
    bot.vx = flight.velocity[0]; bot.vy = flight.velocity[1]; bot.vz = flight.velocity[2];
    bot.animation = moved > 0.02 ? 'run' : 'idle';
    if (brain.visible && mode !== 'tracked' && mode !== 'wheels') this.face(bot, brain.lastKnown, dt, nowMs, brain.targetVelocity, brain);
  }

  private fire(bot: BotPlayer, target: BotPlayer, brain: Brain, nowMs: number, onShot: (shot: BotShot) => void): void {
    const weapon = bot.weapon_id in BOT_RPM ? bot.weapon_id : 'ak47';
    if (brain.ammo <= 0) return;
    const origin = this.eye(bot), d = dist(origin, this.eye(target));

    // Base angular spread in radians (dmr: ~1.7°, m4: ~3.0°, ak47: ~3.6°, mp5: ~4.6°)
    let angularSpread = weapon === 'dmr' ? 0.030 : weapon === 'm4' ? 0.052 : weapon === 'ak47' ? 0.062 : 0.080;

    // 1. Halo / Half-Life First-Shot Warning Grace Period
    // The very first shot of an encounter intentionally misses or grazes wide as an audio-visual cue
    let firstShotMiss = 0;
    if (brain.firstShotGrace) {
      brain.firstShotGrace = false;
      firstShotMiss = 0.80 + this.random(brain) * 0.45;
    }

    // 2. Target Velocity & Aerial Maneuvering Tracking Error
    const targetSpeed = Math.hypot(target.vx ?? 0, target.vy ?? 0, target.vz ?? 0);
    if (targetSpeed > 1.2) {
      angularSpread += Math.min(targetSpeed * 0.007, 0.045);
    }

    // 3. Bot Movement Bloom (firing while moving)
    const botSpeed = Math.hypot(bot.vx ?? 0, bot.vz ?? 0);
    if (botSpeed > 1.2) {
      angularSpread *= 1.35;
    }

    // 4. Fitts's Law Flick Settling Penalty
    if (nowMs < brain.aimSettledAt) {
      angularSpread *= 1.45;
    }

    // 5. Burst recoil climb & spread bloom
    angularSpread += brain.shotsInBurst * 0.010;
    const recoilClimb = brain.shotsInBurst * 0.040;
    const horizontalKick = this.normal(brain) * (0.022 * brain.shotsInBurst);

    // Convert angular spread to linear displacement at distance d
    const spreadRadius = Math.tan(angularSpread) * d;
    const azimuth = this.random(brain) * Math.PI * 2;
    const radial = (0.25 + 0.75 * Math.sqrt(this.random(brain))) * spreadRadius + firstShotMiss;
    const spreadX = Math.cos(azimuth) * radial;
    const spreadY = Math.sin(azimuth) * radial;

    const endpoint: Vec3 = [
      brain.lastKnown[0] + spreadX + horizontalKick,
      brain.lastKnown[1] + spreadY + recoilClimb,
      brain.lastKnown[2] + spreadX * 0.5 + horizontalKick,
    ];
    const delta: Vec3 = [endpoint[0] - origin[0], endpoint[1] - origin[1], endpoint[2] - origin[2]];
    const length = Math.hypot(...delta);
    if (length < 0.1) return;
    const scale = Math.min(300 / length, 1.08);
    let hitPoint: Vec3 = [origin[0] + delta[0] * scale, origin[1] + delta[1] * scale, origin[2] + delta[2] * scale];
    const wall = this.geometry.trace(origin, hitPoint);
    if (wall) hitPoint = wall.point;
    brain.shotId++; brain.ammo--; bot.ammo = brain.ammo;
    brain.nextShotAt = nowMs + 60_000 / BOT_RPM[weapon];
    brain.shotsInBurst++;
    const range = d;
    const baseBurst = weapon === 'dmr' ? 1 : weapon === 'mp5' ? 4 : 3;
    const rangePenalty = range > 24 ? 2 : range > 14 ? 1 : 0;
    const burstLength = weapon === 'dmr' ? 1 : Math.max(1, baseBurst + (brain.role === 1 ? 1 : 0) - rangePenalty);
    if (brain.shotsInBurst >= burstLength) {
      brain.shotsInBurst = 0;
      const pauseBase = weapon === 'dmr' ? 700 : weapon === 'mp5' ? 340 : 460;
      const rangeBonus = range > 18 ? 160 : 0;
      brain.burstUntil = nowMs + pauseBase + rangeBonus + Math.floor(this.random(brain) * 280);
    }
    onShot({ shooter: bot.username, target: target.username, weapon, origin, endpoint: hitPoint, shotId: brain.shotId });
  }

  onBotDamaged(botUsername: string, damage: number, attackerUsername?: string, nowMs: number = Date.now()): void {
    const brain = this.brains.get(botUsername);
    if (!brain) return;
    brain.aimSettledAt = Math.max(brain.aimSettledAt, nowMs + 220);
    brain.shotsInBurst = 0;
    brain.burstUntil = Math.max(brain.burstUntil, nowMs + 160 + Math.floor(this.random(brain) * 120));
    brain.planAt = Math.min(brain.planAt, nowMs + 60);
    if (attackerUsername && !brain.visible) {
      brain.reactAt = Math.min(brain.reactAt, nowMs + 240 + Math.floor(this.random(brain) * 120));
    }
  }

  private respawn(bot: BotPlayer, brain: Brain, nowMs: number): void {
    const spawn = this.geometry.spawns[bot.deaths % this.geometry.spawns.length];
    bot.x = spawn[0]; bot.y = spawn[1] + DRONE_SPAWN_OFFSET; bot.z = spawn[2]; bot.vx = 0; bot.vy = 0; bot.vz = 0;
    bot.health = maxHealthForChassis(bot.mobility_mode); bot.is_dead = false; bot.ammo = BOT_MAGAZINES[bot.weapon_id] ?? 30; bot.animation = 'idle';
    brain.ammo = bot.ammo; brain.deathAt = 0; brain.target = ''; brain.visible = false;
    brain.targetVelocity = [0, 0, 0]; brain.state = 'PATROL'; brain.coverPoint = undefined;
    brain.path = []; brain.waypoint = 0; brain.reactAt = nowMs + 600; brain.protectedUntil = nowMs + 2500; brain.reloadUntil = 0;
    brain.aimSwayOffset = [0, 0]; brain.aimSwayAt = 0; brain.strafeUntil = 0;
    brain.firstShotGrace = true; brain.aimSettledAt = 0;
    brain.trackingNoiseX = 0; brain.trackingNoiseY = 0; brain.trackingNoiseAt = 0; brain.lastSmokeAt = 0;
  }
}
