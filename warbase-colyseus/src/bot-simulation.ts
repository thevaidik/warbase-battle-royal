import { INDUSTRIAL_GEOMETRY, type Vec3, type WorldGeometry } from './world-geometry.js';

export type BotPlayer = {
  username: string;
  is_bot?: boolean;
  x: number; y: number; z: number;
  vx?: number; vy?: number; vz?: number;
  qy?: number; qw?: number; yaw?: number; pitch?: number;
  health: number; kills: number; deaths: number; team: string; is_dead: boolean;
  weapon_id: string; ammo: number; driving_vehicle?: string; animation?: string;
};
export type BotShot = { shooter: string; target: string; weapon: string; origin: Vec3; endpoint: Vec3; shotId: number };
export type BotRosterChange = { joined: BotPlayer[]; removed: string[] };
export type BotUpdateCallbacks = { onShot: (shot: BotShot) => void; vehicleBlocked?: (position: Vec3) => boolean };

type NavNode = { position: Vec3; edges: number[] };
type Brain = {
  role: number;
  seed: number;
  target: string;
  lastKnown: Vec3;
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
};

const BOT_NAMES = ['VIPER', 'KESTREL', 'GHOST', 'ROOK', 'NOMAD', 'LYNX', 'WRAITH'];
const BOT_WEAPONS = ['m4', 'mp5', 'ak47', 'dmr'];
const BOT_MAGAZINES: Record<string, number> = { m4: 30, mp5: 30, ak47: 30, dmr: 20 };
const BOT_RPM: Record<string, number> = { m4: 750, mp5: 850, ak47: 600, dmr: 240 };
const BOT_RELOAD_MS: Record<string, number> = { m4: 2200, mp5: 1800, ak47: 2500, dmr: 2600 };
const NAV_NEIGHBORS = [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]] as const;
const vector = (p: Pick<BotPlayer, 'x' | 'y' | 'z'>): Vec3 => [p.x, p.y, p.z];
const dist = (a: Vec3, b: Vec3): number => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);
const dot = (a: Vec3, b: Vec3): number => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const finite = (n: number): boolean => Number.isFinite(n);

function movementBlocked(geometry: WorldGeometry, from: Vec3, to: Vec3): boolean {
  for (const offset of [[0, 0.9, 0], [-0.25, 0.9, 0], [0.25, 0.9, 0], [0, 0.9, -0.25], [0, 0.9, 0.25]] as const) {
    const hit = geometry.trace([from[0] + offset[0], from[1] + offset[1], from[2] + offset[2]], [to[0] + offset[0], to[1] + offset[1], to[2] + offset[2]]);
    if (hit && hit.fraction > 0.0001) return true;
  }
  return false;
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
      const position: Vec3 = [x * step, y + 0.05, z * step];
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
        const support = geometry.trace([mid[0], mid[1] + 0.3, mid[2]], [mid[0], mid[1] - 0.65, mid[2]]);
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

/** Server-owned Industrial bots: collision-derived A*, visibility, reaction delay, magazines, burst cadence and respawn. */
export class BotSimulation {
  private sequence = 0;
  private readonly brains = new Map<string, Brain>();
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
      const spawn = this.geometry.spawns[(n - 1) % this.geometry.spawns.length];
      const weapon = BOT_WEAPONS[(n - 1) % BOT_WEAPONS.length];
      let team = 'NONE';
      if (mode === 'TDM') {
        const teamA = humanPlayers.filter((p) => p.team === 'A').length + joined.filter((p) => p.team === 'A').length;
        const teamB = humanPlayers.filter((p) => p.team === 'B').length + joined.filter((p) => p.team === 'B').length;
        team = teamA <= teamB ? 'A' : 'B';
      }
      const bot: BotPlayer = { username: name, is_bot: true, x: spawn[0], y: spawn[1], z: spawn[2], vx: 0, vy: 0, vz: 0, qy: 0, qw: 1, yaw: 0, pitch: 0,
        health: 100, kills: 0, deaths: 0, team, is_dead: false, weapon_id: weapon, ammo: BOT_MAGAZINES[weapon], driving_vehicle: '' };
      const seed = (n * 0x9e3779b1) >>> 0;
      this.brains.set(name, { role: n % 3, seed, target: '', lastKnown: spawn, visible: false, seenUntil: 0,
        reactAt: nowMs + 600, perceiveAt: 0, planAt: 0, nextShotAt: 0, burstUntil: 0, shotsInBurst: 0,
        path: [], waypoint: 0, deathAt: 0, protectedUntil: nowMs + 2500, reloadUntil: 0, lastProgressAt: nowMs, progressPoint: spawn, stuckSince: 0,
        ammo: BOT_MAGAZINES[weapon], shotId: 0 });
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
    const bots = [...this.brains.entries()];
    for (const [id, brain] of bots) {
      const bot = players.get(id);
      if (!bot) continue;
      if (bot.is_dead) {
        if (brain.deathAt > 0 && nowMs - brain.deathAt >= 3000) this.respawn(bot, brain, nowMs);
        continue;
      }
      if (nowMs >= brain.perceiveAt) this.perceive(bot, brain, players, nowMs);
      const weapon = bot.weapon_id in BOT_MAGAZINES ? bot.weapon_id : 'ak47';
      if (brain.reloadUntil > 0 && nowMs >= brain.reloadUntil) {
        brain.reloadUntil = 0; brain.ammo = BOT_MAGAZINES[weapon]; bot.ammo = brain.ammo; bot.animation = 'idle';
      } else if (brain.reloadUntil === 0 && (brain.ammo <= 0 || (!brain.visible && brain.ammo < BOT_MAGAZINES[weapon] / 2))) {
        brain.reloadUntil = nowMs + BOT_RELOAD_MS[weapon]; bot.animation = 'reload';
      }
      if (nowMs >= brain.planAt) this.plan(bot, brain, nodes, nowMs, callbacks.vehicleBlocked);
      this.move(bot, brain, nodes, elapsed, nowMs, callbacks.vehicleBlocked);
      if (brain.reloadUntil === 0 && brain.visible && nowMs >= brain.reactAt && nowMs >= brain.nextShotAt && nowMs >= brain.burstUntil) {
        const target = players.get(brain.target);
        if (target && this.enemy(bot, target)) this.fire(bot, target, brain, nowMs, callbacks.onShot);
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
  private eye(p: BotPlayer): Vec3 { return [p.x, p.y + 1.35, p.z]; }

  private perceive(bot: BotPlayer, brain: Brain, players: ReadonlyMap<string, BotPlayer>, nowMs: number): void {
    brain.perceiveAt = nowMs + 140 + Math.floor(this.random(brain) * 80);
    brain.visible = false;
    let best = Infinity;
    const pos = vector(bot), yaw = finite(bot.yaw ?? 0) ? (bot.yaw ?? 0) : 0;
    const forward: Vec3 = [-Math.sin(yaw), 0, -Math.cos(yaw)];
    for (const target of players.values()) {
      if (!this.enemy(bot, target) || target.driving_vehicle) continue;
      const targetPos = vector(target), d = dist(pos, targetPos);
      if (d > 70) continue;
      const to: Vec3 = [targetPos[0] - pos[0], targetPos[1] - pos[1], targetPos[2] - pos[2]];
      const inView = d < 10 || dot(to, forward) > d * 0.05;
      const visible = inView && !this.geometry.rayBlocked(this.eye(bot), this.eye(target));
      let score = d;
      if (target.username === brain.target) score *= 0.8;
      if (visible && score < best) {
        best = score;
        if (brain.target !== target.username) {
          brain.reactAt = nowMs + 450 + Math.floor(this.random(brain) * 300);
          brain.shotsInBurst = 0;
        }
        brain.target = target.username;
        brain.lastKnown = targetPos;
        brain.seenUntil = nowMs + 3000;
        brain.visible = true;
      }
    }
  }

  private nearest(nodes: readonly NavNode[], point: Vec3): number {
    let nearest = -1, best = 9;
    for (let i = 0; i < nodes.length; i++) {
      const d = dist(point, nodes[i].position);
      if (d < best && Math.abs(point[1] - nodes[i].position[1]) < 1 && !movementBlocked(this.geometry, point, nodes[i].position)) { best = d; nearest = i; }
    }
    return nearest;
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

  private plan(bot: BotPlayer, brain: Brain, nodes: readonly NavNode[], nowMs: number, vehicleBlocked?: (p: Vec3) => boolean): void {
    brain.planAt = nowMs + 650 + Math.floor(this.random(brain) * 300);
    const start = this.nearest(nodes, vector(bot));
    let goal: Vec3;
    if (nowMs > brain.seenUntil || !brain.visible) {
      const patrol = this.geometry.spawns[Math.floor(this.random(brain) * this.geometry.spawns.length)];
      goal = patrol;
    } else {
      const dx = brain.lastKnown[0] - bot.x, dz = brain.lastKnown[2] - bot.z;
      const d = Math.max(Math.hypot(dx, dz), 1);
      if (brain.reloadUntil > nowMs || bot.health < 35) {
        let best = Infinity;
        goal = [bot.x - dx / d * 8, bot.y, bot.z - dz / d * 8];
        for (const node of nodes) {
          const cost = dist(vector(bot), node.position);
          if (cost < 3 || cost > 12 || cost >= best) continue;
          if (this.geometry.rayBlocked([brain.lastKnown[0], brain.lastKnown[1] + 1.35, brain.lastKnown[2]], [node.position[0], node.position[1] + 1.35, node.position[2]])) {
            goal = node.position; best = cost;
          }
        }
      } else {
        const preferredRange = bot.weapon_id === 'mp5' ? 7 : bot.weapon_id === 'dmr' ? 24 : 12;
        const lateral = (brain.role - 1) * 6;
        goal = [brain.lastKnown[0] - dx / d * preferredRange - dz / d * lateral, brain.lastKnown[1], brain.lastKnown[2] - dz / d * preferredRange + dx / d * lateral];
      }
    }
    let end = this.nearest(nodes, goal);
    if (end < 0) end = this.nearest(nodes, brain.lastKnown);
    brain.path = this.path(nodes, start, end, vehicleBlocked);
    brain.waypoint = Math.min(1, brain.path.length);
  }

  private face(bot: BotPlayer, target: Vec3): void {
    const yaw = Math.atan2(bot.x - target[0], bot.z - target[2]);
    bot.yaw = yaw; bot.pitch = 0; bot.qy = Math.sin(yaw / 2); bot.qw = Math.cos(yaw / 2);
  }

  private move(bot: BotPlayer, brain: Brain, nodes: readonly NavNode[], dt: number, nowMs: number, vehicleBlocked?: (p: Vec3) => boolean): void {
    if (dist(vector(bot), brain.progressPoint) > 0.35) { brain.lastProgressAt = nowMs; brain.progressPoint = vector(bot); }
    if (brain.waypoint < brain.path.length && nowMs - brain.lastProgressAt > 1500) { brain.planAt = 0; brain.lastProgressAt = nowMs; }
    if (brain.waypoint < brain.path.length) {
      const goal = nodes[brain.path[brain.waypoint]].position, from = vector(bot), d = dist(from, goal);
      if (d < 0.18) brain.waypoint++;
      else {
        const speed = brain.reloadUntil > nowMs ? 3.2 : 4.8, amount = Math.min(1, speed * dt / d);
        const destination: Vec3 = [from[0] + (goal[0] - from[0]) * amount, from[1] + (goal[1] - from[1]) * amount, from[2] + (goal[2] - from[2]) * amount];
        if (!vehicleBlocked?.(destination)) {
          const resolved = this.geometry.resolveMove(from, destination);
          const moved = dist(from, resolved);
          bot.x = resolved[0]; bot.y = resolved[1]; bot.z = resolved[2];
          bot.vx = (resolved[0] - from[0]) / dt; bot.vy = (resolved[1] - from[1]) / dt; bot.vz = (resolved[2] - from[2]) / dt;
          bot.animation = moved > 0.02 ? 'run' : 'idle';
          if (moved < 0.02 && d > 0.5) { brain.planAt = 0; brain.path = []; brain.waypoint = 0; }
          else if (moved > 0.02) this.face(bot, goal);
        } else { brain.planAt = 0; brain.path = []; brain.waypoint = 0; }
      }
    }
    if (brain.visible) this.face(bot, brain.lastKnown);
  }

  private fire(bot: BotPlayer, target: BotPlayer, brain: Brain, nowMs: number, onShot: (shot: BotShot) => void): void {
    const weapon = bot.weapon_id in BOT_RPM ? bot.weapon_id : 'ak47';
    if (brain.ammo <= 0) return;
    const origin = this.eye(bot), d = dist(origin, this.eye(target));
    const error = 0.24 + d * 0.022;
    const endpoint: Vec3 = [brain.lastKnown[0] + this.normal(brain) * error, brain.lastKnown[1] + 1.05 + this.normal(brain) * error, brain.lastKnown[2] + this.normal(brain) * error];
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
    if (brain.shotsInBurst >= 2 + brain.role) { brain.shotsInBurst = 0; brain.burstUntil = nowMs + 450 + Math.floor(this.random(brain) * 350); }
    onShot({ shooter: bot.username, target: target.username, weapon, origin, endpoint: hitPoint, shotId: brain.shotId });
  }

  private respawn(bot: BotPlayer, brain: Brain, nowMs: number): void {
    const spawn = this.geometry.spawns[bot.deaths % this.geometry.spawns.length];
    bot.x = spawn[0]; bot.y = spawn[1]; bot.z = spawn[2]; bot.vx = 0; bot.vy = 0; bot.vz = 0;
    bot.health = 100; bot.is_dead = false; bot.ammo = BOT_MAGAZINES[bot.weapon_id] ?? 30; bot.animation = 'idle';
    brain.ammo = bot.ammo; brain.deathAt = 0; brain.target = ''; brain.visible = false;
    brain.path = []; brain.waypoint = 0; brain.reactAt = nowMs + 600; brain.protectedUntil = nowMs + 2500; brain.reloadUntil = 0;
  }
}
