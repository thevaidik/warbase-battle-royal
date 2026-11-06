import { Room, Client } from 'colyseus';
import { definePlugins, ServerError } from '@colyseus/core';
import type { AuthContext } from '@colyseus/core';
import { findOneRoomAvailable } from '@colyseus/core/MatchMaker';
import { UniqueSessionPlugin } from 'colyseus/plugins/unique-session';
import { BattleState, ObjectiveState, PlayerState, VehicleState, GAME_PROTOCOL_VERSION, PRIVATE_VIEW_TAG } from './schema.js';
import { Schema, StateView, defineTypes } from '@colyseus/schema';
import { loadWorldGeometry, PLAYABLE_MAPS, settledVerticalVelocity, type Vec3, type WorldGeometry } from './world-geometry.js';
import { animationCodeForClip, clipForAnimationCode, REWIND_ANIMATION_CLIPS, traceAnimatedHit, type HitZone } from './animated-hitboxes.js';
import { BotSimulation, type BotPlayer, type BotShot } from './bot-simulation.js';
import { grenadeDamageAt, grenadeVehicleDamageAt, GrenadeSimulation, validateGrenadeLaunch, type ThrowableKind } from './grenade-simulation.js';
import { inputIsFromStaleVehicleSeat, VehicleSimulation, type VehiclePlayer } from './vehicle-simulation.js';
import { RewindView } from '@colyseus/core/Rewind';
import { updatePresentationView } from './presentation-relevance.js';
import { performance } from 'node:perf_hooks';
import { anonymousJoinLimiter, canonicalizeUsername, gameMessageLimiter, roomCreationLimiter } from './abuse-protection.js';
import { incrementProcessOperation, newRoomOperationsMetrics, recordProcessTick, roomOperationsMetrics, serviceOperationsMetrics, type RoomOperationsMetrics } from './operations-metrics.js';
import { awardConquestKill, createConquestState, stepConquest, type ConquestState } from './conquest-simulation.js';
import { getConfiguredBattleAdmission } from './admission.js';

class MoveInput extends Schema {
  move_x = 0; move_z = 0; yaw = 0; pitch = 0; jump = 0; sprint = 0; crouch = 0;
  vehicle_throttle = 0; vehicle_steer = 0; vehicle_brake = 0; vehicle_gear = 1; vehicle_index = -1; vehicle_generation = 0;
}
defineTypes(MoveInput, { move_x: 'number', move_z: 'number', yaw: 'number', pitch: 'number', jump: 'number', sprint: 'number', crouch: 'number', vehicle_throttle: 'number', vehicle_steer: 'number', vehicle_brake: 'number', vehicle_gear: 'number', vehicle_index: 'number', vehicle_generation: 'number' });

export const activeRooms = new Map<string, { id: string; room: string; name: string; map: string; mode: string; timeOfDay: string; clients: number; bots: number; maxClients: number }>();
type JoinOptions = { protocol_version?: number; username?: string; room?: string; cid?: string; map?: string; map_name?: string; mode?: string; time_of_day?: string; timeOfDay?: string; name?: string };
type RoomCreationAllowance = { allow(key: string, limit: number, windowMs: number, now?: number): boolean };
type ValidRoomSettings = { requested: string; map: string; requestedMode: string; timeOfDay: string };
type PlayerRuntime = { username: string; map: string; lastShot: number; pendingHit: boolean; reloadUntil: number; spawnAt: number; vy: number;
  ammoByWeapon: Record<string, number>; animationStartedAt: number; pendingWeaponId: string; lastShotId: number; pendingShotId: number; protectedUntil: number;
  grenadeLastThrow: number; grenadeLastRequestId: number; reloadToken: number; reloadTimer?: { clear(): void };
  fireSegment?: { o: Vec3; d: Vec3; range: number; shotId: number; seen: RewindView } };
type Weapon = { damage: number; rpm: number; magazine: number; reloadMs: number; range: number; headshot: number; falloffStart: number; falloffEnd: number; minFraction: number; bodyFraction: number };
const WEAPONS: Record<string, Weapon> = {
  ak47: { damage: 34, rpm: 600, magazine: 30, reloadMs: 2500, range: 90, headshot: 1.8, falloffStart: 20, falloffEnd: 90, minFraction: 0.6, bodyFraction: 0.84 },
  m4: { damage: 25, rpm: 750, magazine: 30, reloadMs: 2200, range: 90, headshot: 1.8, falloffStart: 20, falloffEnd: 90, minFraction: 0.6, bodyFraction: 0.84 },
  mp5: { damage: 25, rpm: 850, magazine: 30, reloadMs: 1800, range: 45, headshot: 1.6, falloffStart: 10, falloffEnd: 45, minFraction: 0.45, bodyFraction: 0.84 },
  dmr: { damage: 50, rpm: 240, magazine: 20, reloadMs: 2600, range: 150, headshot: 1.7, falloffStart: 35, falloffEnd: 150, minFraction: 0.75, bodyFraction: 0.91 },
  pistol: { damage: 34, rpm: 400, magazine: 12, reloadMs: 1500, range: 50, headshot: 1.8, falloffStart: 10, falloffEnd: 50, minFraction: 0.5, bodyFraction: 0.84 },
  m2010: { damage: 100, rpm: 45, magazine: 5, reloadMs: 3200, range: 150, headshot: 1.8, falloffStart: 0, falloffEnd: 150, minFraction: 1, bodyFraction: 1 },
  hmg: { damage: 34, rpm: 520, magazine: 60, reloadMs: 3400, range: 90, headshot: 1.8, falloffStart: 20, falloffEnd: 90, minFraction: 0.6, bodyFraction: 0.84 },
};
export const MAX_WEAPON_RANGE = Math.max(...Object.values(WEAPONS).map(weapon => weapon.range));
const getWeapon = (weaponId: string): Weapon | undefined => Object.hasOwn(WEAPONS, weaponId) ? WEAPONS[weaponId] : undefined;
const clamp = (n: unknown, lo: number, hi: number): number => Number.isFinite(Number(n)) ? Math.max(lo, Math.min(hi, Number(n))) : 0;

/** Validate client fields before charging the shared process create allowance. */
export function consumeRoomCreationAllowance(options: JoinOptions, activeRoomCount: number, limiter: RoomCreationAllowance, now?: number): ValidRoomSettings {
  const requested = String(options.room ?? 'industrial-public').trim();
  const explicitMap = String(options.map_name ?? options.map ?? '').trim().toLowerCase();
  const publicMap = options.room === undefined ? undefined : PLAYABLE_MAPS.find((candidate) => requested === `${candidate}-public`);
  const map = publicMap || explicitMap || [...PLAYABLE_MAPS].sort((a, b) => b.length - a.length).find((candidate) => {
    const normalized = requested.toLowerCase();
    return normalized === candidate || normalized.startsWith(`${candidate}-`);
  }) || '';
  if (!PLAYABLE_MAPS.includes(map as (typeof PLAYABLE_MAPS)[number])) throw new Error(`Unsupported map: ${map || requested}`);
  const defaultMode = map === 'industrial' || map === 'resoforge' || map === 'football' ? 'TDM' : 'FFA';
  const suppliedMode = String(options.mode ?? defaultMode).trim().toUpperCase();
  if (suppliedMode !== 'TDM' && suppliedMode !== 'FFA' && suppliedMode !== 'CONQUEST') throw new Error(`Unsupported room mode: ${suppliedMode}`);
  // Public presets are server-owned: an older client cannot recreate them as FFA/TDM.
  const requestedMode = requested === `${map}-public` ? 'CONQUEST' : suppliedMode;
  const requestedTime = String(options.time_of_day ?? options.timeOfDay ?? 'noon').trim().toLowerCase();
  const timeOfDay = requestedTime === 'night' ? 'overcast' : requestedTime;
  if (!['dawn', 'noon', 'dusk', 'overcast'].includes(timeOfDay)) throw new Error(`Unsupported time of day: ${requestedTime}`);
  if (activeRoomCount >= 128) throw new Error('Room creation capacity reached');
  if (!limiter.allow('process', 60, 60_000, now)) throw new Error('Room creation rate limited');
  return { requested, map, requestedMode, timeOfDay };
}

export function damageForZone(weaponId: string, metres: number, zone: string): number {
  const weapon = getWeapon(weaponId) ?? WEAPONS.ak47;
  const fraction = Math.max(0, Math.min(1, (metres - weapon.falloffStart) / Math.max(1, weapon.falloffEnd - weapon.falloffStart)));
  const rangedDamage = Math.round(weapon.damage * (1 - fraction * (1 - weapon.minFraction)));
  let damage = rangedDamage;
  if (zone === 'head') damage *= weapon.headshot;
  else if (['stomach', 'arm', 'leg'].includes(zone)) damage *= weapon.bodyFraction;
  if (weaponId === 'm2010' && damage < 100) damage = 100;
  return Math.round(damage);
}

/** Godot camera forward at yaw=0 is -Z; positive yaw turns toward -X and positive pitch looks down. */
export function aimDirection(yaw: number, pitch: number): Vec3 {
  const cp = Math.cos(pitch);
  return [-Math.sin(yaw) * cp, -Math.sin(pitch), -Math.cos(yaw) * cp];
}

export function movementVelocity(moveX: number, moveZ: number, yaw: number, speed: number): [number, number] {
  const magnitude = Math.max(Math.hypot(moveX, moveZ), 1);
  return [(moveX * Math.cos(yaw) - moveZ * Math.sin(yaw)) / magnitude * speed,
    (-moveX * Math.sin(yaw) - moveZ * Math.cos(yaw)) / magnitude * speed];
}

export class BattleRoom extends Room<{ state: BattleState; input: MoveInput }> {
  plugins = definePlugins({ uniqueSession: new UniqueSessionPlugin({ max: 1, onDuplicate: 'reject' }) });
  maxClients = 64;
  state = new BattleState();
  inputs = this.defineInput(MoveInput, { bufferMaxSize: 64, sanitize: { move_x: [-1, 1], move_z: [-1, 1], yaw: [-Math.PI * 16, Math.PI * 16], pitch: [-1.55, 1.55], jump: [0, 1], sprint: [0, 1], crouch: [0, 1], vehicle_throttle: [-1, 1], vehicle_steer: [-1, 1], vehicle_brake: [0, 1], vehicle_gear: [1, 2], vehicle_index: [-1, 1000], vehicle_generation: [0, Number.MAX_SAFE_INTEGER] } });
  private internal = new Map<string, PlayerRuntime>();
  /** Stable lookup avoids rescanning all connected sessions for every actor at 60 Hz. */
  private sessionByUsername = new Map<string, string>();
  private rewind: any;
  private geometry!: WorldGeometry;
  private grenadeSimulation!: GrenadeSimulation;
  private vehicleSimulation!: VehicleSimulation;
  private botSimulation!: BotSimulation;
  private botProtectedUntil = new Map<string, number>();
  private botAnimationStartedAt = new Map<string, number>();
  private vehicleWeaponBeforeDrive = new Map<string, string>();
  private operations!: RoomOperationsMetrics;
  private conquest?: ConquestState;
  private presentationViews = new Map<string, Set<PlayerState>>();
  private presentationRefreshAt = 0;

  /**
   * Matchmaker admission runs before find-or-create, so a missing/forged ticket
   * cannot trigger expensive geometry and bot initialization in onCreate.
   * Unit fixtures and local dev without configured controls retain the legacy
   * instance-level name guard.
   */
  static async onAuth(token: string | undefined, options: JoinOptions, _context: AuthContext): Promise<{ id: string; sub: string; username: string } | false | true> {
    const admission = getConfiguredBattleAdmission();
    if (!admission) return true;
    const player = admission.authorizeJoin(token ?? '');
    if (!player) { incrementProcessOperation('rejectedAdmissions'); return false; }
    const username = canonicalizeUsername(options?.username);
    if (!username) { incrementProcessOperation('rejectedAdmissions'); return false; }

    if (options?.protocol_version !== GAME_PROTOCOL_VERSION) {
      throw new ServerError(409, 'Game update required. Reload the browser or update the native client.');
    }

    let existingRoom;
    try {
      // This mirrors the matchmaker's filter lookup to charge the per-player
      // create quota only when this request would need a new room.
      existingRoom = await findOneRoomAvailable('battle', options ?? {});
    } catch {
      incrementProcessOperation('rejectedAdmissions');
      return false;
    }
    if (!existingRoom && !admission.authorizeRoomCreate(token ?? '')) {
      serviceOperationsMetrics.roomCreateRateLimited++;
      incrementProcessOperation('rejectedAdmissions');
      return false;
    }
    const roomKey = existingRoom?.roomId ?? String(options?.room ?? 'industrial-public');
    if (!anonymousJoinLimiter.allow(roomKey, 256, 60_000)) {
      incrementProcessOperation('rejectedAdmissions');
      return false;
    }
    return { id: player.id, sub: player.sub, username };
  }

  onCreate(options: JoinOptions) {
    let settings: ValidRoomSettings;
    try {
      settings = consumeRoomCreationAllowance(options, activeRooms.size, roomCreationLimiter);
    } catch (error) {
      if (error instanceof Error && error.message === 'Room creation capacity reached') serviceOperationsMetrics.roomCreateRejected++;
      if (error instanceof Error && error.message === 'Room creation rate limited') serviceOperationsMetrics.roomCreateRateLimited++;
      throw error;
    }
    const { requested, map, requestedMode, timeOfDay } = settings;
    const geometry = loadWorldGeometry(map);
    if (!geometry) throw new Error(`Unsupported map: ${map || requested}`);
    this.geometry = geometry;
    this.operations = newRoomOperationsMetrics();
    roomOperationsMetrics.set(this.roomId, this.operations);
    this.grenadeSimulation = new GrenadeSimulation(geometry);
    this.vehicleSimulation = new VehicleSimulation(geometry);
    this.botSimulation = new BotSimulation(geometry);
    this.setMetadata({ id: this.roomId, room: requested, name: (requested === `${map}-public` ? "Public Conquest" : String(options.name ?? "Custom Match")), map, mode: requestedMode, timeOfDay, playerCount: 0, botCount: 0, capacity: this.maxClients });
    this.rewind = this.allowRewindState({ maxRewindMs: 400 });
    this.state.room_mode = requestedMode;
    if (requestedMode === 'CONQUEST') {
      this.conquest = createConquestState(geometry.spawns);
      for (const point of this.conquest.objectives) { const objective = new ObjectiveState(); Object.assign(objective, point); this.state.objectives.set(point.id, objective); }
    }
    this.state.map_name = map;
    this.state.time_of_day = timeOfDay;
    this.syncVehiclesToSchema();
    activeRooms.set(this.roomId, { id: this.roomId, room: requested, name: (requested === `${map}-public` ? "Public Conquest" : String(options.name ?? "Custom Match")), map, mode: requestedMode, timeOfDay, clients: 0, bots: 0, maxClients: this.maxClients });
    this.patchRate = 50;
    this.rewind.attachAll(this.state.players, { fields: ['x', 'y', 'z', 'qx', 'qy', 'qz', 'qw'], mode: 'snapshot', interpolate: 'linear' });
    this.rewind.attachAll(this.state.players, { fields: ['animation_code', 'animation_time', 'health'], mode: 'snapshot', interpolate: 'step' });
    let fixedTick = 0;
    let lastTickStartedAt = 0;
    this.setFixedTimestep((ctx) => {
      const tickStartedAt = performance.now();
      const previousTickStartedAt = lastTickStartedAt;
      this.operations.tickCount++;
      if (lastTickStartedAt > 0 && tickStartedAt - lastTickStartedAt > ctx.dt * 1500) this.operations.lateTicks++;
      lastTickStartedAt = tickStartedAt;
      const now = Date.now();
      for (const [username, player] of this.state.players) {
        const sessionId = this.sessionByUsername.get(username);
        if (!sessionId) continue;
        const internal = this.internal.get(sessionId);
        if (!internal) continue;
        const p = player as PlayerState;
        p.pose_time_ms = now; p.animation_time = Math.max(0, (now - internal.animationStartedAt) / 1000);
        // Keep the buffered input timeline advancing while dead. Otherwise
        // inputs sent during the respawn delay become stale movement and force
        // the client to replay a growing backlog after respawn.
        const inputChannel = this.inputs.get(sessionId);
        const input = inputChannel.next();
        if (input) this.operations.consumedInputs++;
        else this.operations.emptyInputSteps++;
        if (p.is_dead) {
          p.ack_input_sequence = inputChannel.consumedCount;
          if (now >= internal.spawnAt) this.respawn(sessionId, p, internal);
          continue;
        }
        const from: Vec3 = [p.x, p.y, p.z];
        if (p.driving_vehicle) {
          if (input) this.vehicleSimulation.input(this.vehiclePlayer(p), { throttle: input.vehicle_throttle, steer: input.vehicle_steer, brake: input.vehicle_brake > 0.5, gear: input.vehicle_gear, vehicleIndex: input.vehicle_index, vehicleGeneration: input.vehicle_generation }, now);
          p.ack_input_sequence = inputChannel.consumedCount;
          continue;
        }
        // A buffered driving frame can arrive after the seat-exit message. Consume
        // and acknowledge it, but do not reinterpret its stale controls as walking.
        const movementInput = input && inputIsFromStaleVehicleSeat(input.vehicle_index, input.vehicle_generation, p.vehicle_index, p.vehicle_generation) ? undefined : input;
        const jumpFloor = (movementInput?.jump ?? 0) > 0.5 ? this.geometry.floorHeight(p.x, p.z, p.y + 0.1) : undefined;
        if ((movementInput?.jump ?? 0) > 0.5 && Math.abs(internal.vy) < 0.001 && jumpFloor !== undefined && p.y >= jumpFloor - 0.06 && p.y <= jumpFloor + 0.3) internal.vy = 6.2;
        internal.vy -= 18 * ctx.dt;
        const movementX = movementInput?.move_x ?? 0, movementZ = movementInput?.move_z ?? 0;
        const movementSpeed = (movementInput?.sprint ?? 0) > 0.5 ? 8.8 : (movementInput?.crouch ?? 0) > 0.5 ? 2.5 : 6.2;
        const movementYaw = movementInput?.yaw ?? p.yaw;
        const [movementDx, movementDz] = movementVelocity(movementX, movementZ, movementYaw, movementSpeed);
        const requested: Vec3 = [p.x + movementDx * ctx.dt, p.y + internal.vy * ctx.dt, p.z + movementDz * ctx.dt];
        const resolved = this.geometry.resolveMove(from, requested);
        p.x = resolved[0]; p.y = resolved[1]; p.z = resolved[2];
        p.vx = (p.x - from[0]) / ctx.dt; p.vz = (p.z - from[2]) / ctx.dt;
        // The settlement helper already stops a clamped downward sweep, and
        // upward motion never reads the floor. Query only for its remaining case.
        const settlementFloor = internal.vy < 0 && !(resolved[1] > requested[1] + 0.00001)
          ? this.geometry.floorHeight(p.x, p.z, p.y + 0.1) : undefined;
        internal.vy = settledVerticalVelocity(internal.vy, requested[1], resolved[1], settlementFloor);
        p.vy = internal.vy;
        p.yaw = movementYaw; p.pitch = movementInput?.pitch ?? p.pitch;
        p.qx = 0; p.qy = Math.sin(movementYaw * 0.5); p.qz = 0; p.qw = Math.cos(movementYaw * 0.5);
        p.ack_input_sequence = inputChannel.consumedCount;
      }
      if (this.vehicleSimulation.needsStep) this.stepVehicles(ctx.dt);
      if (this.botSimulation.hasBots) this.stepBots(ctx.dt);
      if (this.grenadeSimulation.hasGrenades) this.stepGrenades(ctx.dt);
      if (this.state.room_mode === 'CONQUEST' && this.state.room_state === 'active') this.stepConquestMode(ctx.dt);
      // Simulation remains 60 Hz; replicated schema patches are capped at 20 Hz.
      // Composite driver/vehicle mirrors must describe the same fixed tick.
      // Schema publication remains 20 Hz; this only keeps its pending state coherent.
      if (this.vehicleSimulation.needsStep || ++fixedTick % 3 === 0) this.syncVehiclesToSchema();
      const durationMs = performance.now() - tickStartedAt;
      this.operations.lastTickDurationMs = durationMs;
      this.operations.maxTickDurationMs = Math.max(this.operations.maxTickDurationMs, durationMs);
      this.operations.totalTickDurationMs += durationMs;
      if (durationMs > ctx.dt * 1000) this.operations.tickOverruns++;
      recordProcessTick(durationMs, previousTickStartedAt > 0 ? Math.max(0, tickStartedAt - previousTickStartedAt - ctx.dt * 1000) : 0);
    }, 60);

    this.onMessage('state_meta', (client, raw: any) => {
      if (!this.allowMessage(client, 'state_meta', 20)) return;
      const p = this.state.players.get(this.internal.get(client.sessionId)?.username ?? ''); if (!p || p.is_dead) return;
      const requested = String(raw?.animation ?? 'idle');
      const animation = REWIND_ANIMATION_CLIPS.includes(requested as (typeof REWIND_ANIMATION_CLIPS)[number]) || requested === 'death' ? requested : 'idle';
      if (p.animation !== animation) { p.animation = animation; p.animation_code = animationCodeForClip(animation); const meta = this.internal.get(client.sessionId); if (meta) meta.animationStartedAt = Date.now(); p.animation_time = 0; }
      const weapon = String(raw?.weapon ?? p.weapon_id);
      if (getWeapon(weapon)) this.selectWeapon(client.sessionId, weapon);
    });
    this.onMessage('fire', (client, raw: any) => { if (this.allowMessage(client, 'fire', 20)) this.fire(client, raw); });
    this.onMessage('hit', (client, raw: any) => { if (this.allowMessage(client, 'hit', 20)) this.hit(client, raw); });
    this.onMessage('reload', (client) => { if (this.allowMessage(client, 'reload', 4)) this.reload(client); });
    this.onMessage('switch', (client, raw: any) => { if (this.allowMessage(client, 'switch', 8)) this.selectWeapon(client.sessionId, String(raw?.weapon ?? '')); });
    this.onMessage('loadout', (client, raw: any) => {
      if (!this.allowMessage(client, 'loadout', 4)) return;
      this.selectWeapon(client.sessionId, String(raw?.primary ?? 'ak47'));
      const p = this.state.players.get(this.internal.get(client.sessionId)?.username ?? '');
      const throwable = String(raw?.throwable ?? p?.throwable ?? 'frag');
      if (p && (throwable === 'frag' || throwable === 'impact')) p.throwable = throwable;
    });
    this.onMessage('respawn', (client) => { if (this.allowMessage(client, 'respawn', 3)) this.requestRespawn(client); });
    this.onMessage('grenade', (client, raw: any) => {
      const runtime = this.internal.get(client.sessionId), requestId = this.grenadeRequestId(raw?.request_id);
      if (requestId > 0 && runtime && requestId <= runtime.grenadeLastRequestId) { this.rejectGrenadeRequest(client, requestId); return; }
      if (requestId > 0 && runtime) runtime.grenadeLastRequestId = requestId;
      if (this.allowMessage(client, 'grenade', 4)) this.throwGrenade(client, raw);
      else this.rejectGrenadeRequest(client, requestId, false);
    });
    this.onMessage('vehicle_seat', (client, raw: any) => { if (this.allowMessage(client, 'vehicle_seat', 8)) this.vehicleSeat(client, raw); });
    // Vehicle controls are accepted only from the buffered defineInput timeline.
  }

  onJoin(client: Client, options: JoinOptions, auth?: { username: string }) {
    const username = canonicalizeUsername(auth?.username ?? options.username);
    if (!username) { this.operations.rejectedAdmissions++; incrementProcessOperation('rejectedAdmissions'); throw new Error('valid username required'); }
    if ([...this.internal.values()].some((x) => x.username.normalize('NFKC').toLowerCase() === username.normalize('NFKC').toLowerCase())) { this.operations.rejectedAdmissions++; incrementProcessOperation('rejectedAdmissions'); throw new Error('username already in room'); }
    this.operations.joined++;
    incrementProcessOperation('joined');
    const p = new PlayerState();
    const spawn = this.geometry.spawns[(this.clients.length - 1) % this.geometry.spawns.length];
    p.x = spawn[0]; p.y = spawn[1]; p.z = spawn[2];
    if (this.state.room_mode === 'TDM' || this.state.room_mode === 'CONQUEST') {
      const players = [...this.state.players.values()];
      p.team = players.filter((player) => player.team === 'A' && !player.is_bot).length <= players.filter((player) => player.team === 'B' && !player.is_bot).length ? 'A' : 'B';
    } else p.team = 'NONE';
    p.username = username;
    this.state.players.set(username, p);
    client.view = new StateView();
    client.view.add(p, PRIVATE_VIEW_TAG);
    const listing = activeRooms.get(this.roomId); if (listing) listing.clients = this.clients.length;
    this.internal.set(client.sessionId, { username, map: String(this.metadata?.map ?? 'industrial'), lastShot: 0, pendingHit: false, reloadUntil: 0, reloadToken: 0, spawnAt: 0, vy: 0, ammoByWeapon: Object.fromEntries(Object.entries(WEAPONS).map(([id, weapon]) => [id, weapon.magazine])), animationStartedAt: Date.now(), pendingWeaponId: 'ak47', lastShotId: 0, pendingShotId: 0, protectedUntil: Date.now() + 2500, grenadeLastThrow: 0, grenadeLastRequestId: 0 });
    this.sessionByUsername.set(username, client.sessionId);
    client.send('identity', { username, map: this.metadata?.map, session_id: client.sessionId });
    this.syncBots();
    this.presentationRefreshAt = 0;
    this.refreshPresentationViews();
  }

  async onDrop(client: Client) {
    const player = this.state.players.get(this.internal.get(client.sessionId)?.username ?? '');
    if (player?.driving_vehicle) this.exitVehicle(player, true);
    try { await this.allowReconnection(client, 15); } catch { /* Colyseus invokes onLeave after the reconnect window expires. */ }
  }
  onReconnect(client: Client) { const meta = this.internal.get(client.sessionId); if (meta) client.send('identity', { username: meta.username, map: this.metadata?.map, session_id: client.sessionId }); }
  onLeave(client: Client) { client.view?.dispose(); client.view = undefined; this.presentationViews.delete(client.sessionId); const meta = this.internal.get(client.sessionId); if (meta) { this.operations.left++; incrementProcessOperation('left'); this.cancelReload(meta); this.sessionByUsername.delete(meta.username); const player = this.state.players.get(meta.username); if (player?.driving_vehicle) this.exitVehicle(player, true); if (player) for (const peer of this.clients) peer.view?.remove(player); this.state.players.delete(meta.username); } this.internal.delete(client.sessionId); const listing = activeRooms.get(this.roomId); if (listing) listing.clients = this.clients.length; this.syncBots(); if (this.clients.length === 0) activeRooms.delete(this.roomId); }

  onDispose() { for (const client of this.clients) { client.view?.dispose(); client.view = undefined; } this.presentationViews.clear(); for (const internal of this.internal.values()) this.cancelReload(internal); activeRooms.delete(this.roomId); roomOperationsMetrics.delete(this.roomId); }

  private allowMessage(client: Client, message: string, limitPerSecond: number): boolean {
    if (gameMessageLimiter.allow(`${this.roomId}:${client.sessionId}:${message}`, limitPerSecond, 1000)) return true;
    this.operations.rateLimitedMessages++;
    this.operations.rejectedMessages++;
    incrementProcessOperation('rateLimitedMessages'); incrementProcessOperation('rejectedMessages');
    return false;
  }

  onBeforePatch() { this.refreshPresentationViews(); }

  private refreshPresentationViews() {
    const now = performance.now();
    if (now < this.presentationRefreshAt) return;
    this.presentationRefreshAt = now + 250;
    for (const client of this.clients) {
      const observer = this.state.players.get(this.internal.get(client.sessionId)?.username ?? '');
      if (!observer || !client.view) continue;
      let visible = this.presentationViews.get(client.sessionId);
      if (!visible) { visible = new Set(); this.presentationViews.set(client.sessionId, visible); }
      updatePresentationView(client.view, observer, this.state.players.values(), visible);
    }
  }

  private rejectMessage(): void { this.operations.rejectedPayloads++; this.operations.rejectedMessages++; incrementProcessOperation('rejectedPayloads'); incrementProcessOperation('rejectedMessages'); }

  private grenadeRequestId(raw: unknown): number {
    const value = Number(raw);
    return Number.isSafeInteger(value) && value > 0 ? value : 0;
  }

  private rejectGrenadeRequest(client: Client, rawRequestId: unknown, countPayload = true): void {
    if (countPayload) this.rejectMessage();
    client.send('grenade_rejected', { request_id: this.grenadeRequestId(rawRequestId) });
  }

  private mapFromRoomId(roomId: string): string {
    const normalized = roomId.trim().toLowerCase();
    return [...PLAYABLE_MAPS].sort((a, b) => b.length - a.length).find((map) => normalized === map || normalized.startsWith(`${map}-`)) ?? '';
  }

  private syncBots(): void {
    if (!this.botSimulation) return;
    const humans = [...this.state.players.values()].filter((p) => !p.is_bot) as unknown as BotPlayer[];
    const { joined, removed } = this.botSimulation.sync(humans, Date.now(), this.state.room_mode === 'TDM' || this.state.room_mode === 'CONQUEST' ? 'TDM' : 'FFA');
    for (const name of removed) { this.state.players.delete(name); this.botProtectedUntil.delete(name); this.botAnimationStartedAt.delete(name); }
    for (const descriptor of joined) {
      const bot = new PlayerState();
      bot.username = descriptor.username; bot.is_bot = true; bot.x = descriptor.x; bot.y = descriptor.y; bot.z = descriptor.z;
      bot.vx = descriptor.vx ?? 0; bot.vy = descriptor.vy ?? 0; bot.vz = descriptor.vz ?? 0;
      bot.qy = descriptor.qy ?? 0; bot.qw = descriptor.qw ?? 1; bot.yaw = descriptor.yaw ?? 0; bot.pitch = descriptor.pitch ?? 0;
      bot.health = descriptor.health; bot.kills = descriptor.kills; bot.deaths = descriptor.deaths; bot.team = descriptor.team;
      bot.weapon_id = descriptor.weapon_id; bot.ammo = descriptor.ammo; bot.driving_vehicle = descriptor.driving_vehicle ?? '';
      this.state.players.set(bot.username, bot); this.botProtectedUntil.set(bot.username, Date.now() + 2500); this.botAnimationStartedAt.set(bot.username, Date.now());
    }
    const listing = activeRooms.get(this.roomId); if (listing) listing.bots = this.botSimulation.botIds.length;
    if (listing) this.setMetadata({ ...this.metadata, playerCount: this.clients.length, botCount: listing.bots, capacity: this.maxClients });
  }

  private syncVehiclesToSchema(): void {
    if (!this.vehicleSimulation) return;
    const states = this.vehicleSimulation.states;
    for (const id of [...this.state.vehicles.keys()]) if (!states.has(id)) this.state.vehicles.delete(id);
    for (const [id, snapshot] of states) {
      let vehicle = this.state.vehicles.get(id);
      if (!vehicle) { vehicle = new VehicleState(); this.state.vehicles.set(id, vehicle); }
      vehicle.id = id; vehicle.pos[0] = snapshot.pos[0]; vehicle.pos[1] = snapshot.pos[1]; vehicle.pos[2] = snapshot.pos[2];
      vehicle.x = snapshot.pos[0]; vehicle.y = snapshot.pos[1]; vehicle.z = snapshot.pos[2];
      vehicle.yaw = snapshot.yaw; vehicle.speed = snapshot.speed; vehicle.health = snapshot.health; vehicle.driver = snapshot.driver; vehicle.gear = snapshot.gear; vehicle.driver_generation = snapshot.driverGeneration;
    }
  }

  private playerView(): Map<string, PlayerState & BotPlayer & VehiclePlayer> {
    return new Map([...this.state.players].map(([name, player]) => [name, player as PlayerState & BotPlayer & VehiclePlayer]));
  }

  private vehiclePlayer(player: PlayerState): VehiclePlayer {
    return player as PlayerState & VehiclePlayer;
  }

  private stepVehicles(dt: number): void {
    const players = this.playerView();
    const roadkills = this.vehicleSimulation.step(dt, Date.now(), players);
    for (const vehicle of this.vehicleSimulation.states.values()) {
      const driver = this.state.players.get(vehicle.driver);
      if (!driver) continue;
      driver.vx = -Math.sin(vehicle.yaw) * vehicle.speed; driver.vy = 0; driver.vz = -Math.cos(vehicle.yaw) * vehicle.speed;
      driver.yaw = vehicle.yaw; driver.qx = 0; driver.qy = Math.sin(vehicle.yaw * 0.5); driver.qz = 0; driver.qw = Math.cos(vehicle.yaw * 0.5);
      driver.animation = 'drive'; driver.animation_code = 5; driver.animation_time = 0; driver.pose_time_ms = Date.now();
    }
    for (const event of roadkills) {
      const driver = this.state.players.get(event.driver), target = this.state.players.get(event.target);
      if (!driver || !target || !this.areEnemies(driver, target) || this.isProtected(target)) continue;
      this.killPlayer(driver, target);
    }
  }

  private stepBots(dt: number): void {
    const players = this.playerView();
    const before = new Map([...players].filter(([, player]) => player.is_bot).map(([name, player]) => [name, { x: player.x, y: player.y, z: player.z, dead: player.is_dead }]));
    const fired = new Set<string>();
    this.botSimulation.step(players, dt, Date.now(), {
      vehicleBlocked: (at) => [...this.vehicleSimulation.states.values()].some((v) => Math.hypot(at[0] - v.pos[0], at[2] - v.pos[2]) < 3.2),
      ...(this.state.room_mode === 'CONQUEST' ? { objectiveGoal: (bot: BotPlayer) => this.conquestBotGoal(bot) } : {}),
      onShot: (shot) => { fired.add(shot.shooter); this.resolveBotShot(shot); },
    });
    for (const [name, player] of this.state.players) {
      if (!player.is_bot) continue;
      const previous = before.get(name), now = Date.now();
      if (previous?.dead && !player.is_dead) this.botProtectedUntil.set(name, now + 2500);
      const moved = previous ? Math.hypot(player.x - previous.x, player.y - previous.y, player.z - previous.z) > 0.01 : false;
      let clip = player.is_dead ? 'death' : fired.has(name) ? 'firing' : player.animation === 'firing' && now - (this.botAnimationStartedAt.get(name) ?? 0) < 140 ? 'firing' : moved ? 'run' : 'idle';
      if (player.animation !== clip) { player.animation = clip; player.animation_code = animationCodeForClip(clip); player.animation_time = 0; this.botAnimationStartedAt.set(name, now); }
      const startedAt = this.botAnimationStartedAt.get(name) ?? now;
      player.pose_time_ms = now; player.animation_time = Math.max(0, (now - startedAt) / 1000);
    }
  }

  private stepGrenades(dt: number): void {
    for (const explosion of this.grenadeSimulation.step(dt)) this.resolveExplosion(explosion.id, explosion.owner, explosion.kind, explosion.position);
  }

  private conquestBotGoal(bot: BotPlayer): Vec3 | undefined {
    if (!this.conquest?.objectives.length) return undefined;
    const team = bot.team === 'A' || bot.team === 'B' ? bot.team : 'A';
    const unownedOrEnemy = this.conquest.objectives.filter((objective) => objective.owner !== team);
    const candidates = unownedOrEnemy.length ? unownedOrEnemy : this.conquest.objectives;
    const teamBots = [...this.state.players.values()].filter((player) => player.is_bot && player.team === team).sort((a, b) => a.username.localeCompare(b.username));
    const index = Math.max(0, teamBots.findIndex((player) => player.username === bot.username));
    const goal = candidates[index % candidates.length];
    return [goal.x, goal.y, goal.z];
  }

  private throwGrenade(client: Client, raw: any): void {
    const runtime = this.internal.get(client.sessionId), player = this.state.players.get(runtime?.username ?? '');
    if (!runtime || !player || player.is_dead || player.driving_vehicle || player.grenades <= 0) { this.rejectGrenadeRequest(client, raw?.request_id); return; }
    const kind = player.throwable === 'impact' ? 'impact' : 'frag';
    const position = this.vec(raw?.pos), velocity = this.vec(raw?.vel);
    if (!position || !velocity) { this.rejectGrenadeRequest(client, raw?.request_id); return; }
    const now = Date.now(), eye: Vec3 = [player.x, player.y + 1.35, player.z], feet: Vec3 = [player.x, player.y, player.z];
    const launch = { owner: player.username, kind, position, velocity };
    if (!validateGrenadeLaunch(launch, feet, eye, kind, runtime.grenadeLastThrow, now, player.grenades, this.geometry)) { this.rejectGrenadeRequest(client, raw?.request_id); return; }
    const grenade = this.grenadeSimulation.launch(launch);
    if (!grenade) { this.rejectGrenadeRequest(client, raw?.request_id); return; }
    runtime.grenadeLastThrow = now; player.grenades--;
    this.broadcast('grenade', { shooter: player.username, pos: grenade.position, vel: grenade.velocity, id: grenade.id, throwable: grenade.kind, request_id: this.grenadeRequestId(raw?.request_id) });
  }

  private resolveExplosion(id: number, ownerName: string, kind: ThrowableKind, position: Vec3): void {
    if (this.state.room_mode === 'CONQUEST' && this.state.room_state === 'finished') return;
    this.broadcast('explosion', { id, pos: position, throwable: kind });
    const owner = this.state.players.get(ownerName);
    for (const target of this.state.players.values()) {
      if (target.is_dead || target.driving_vehicle || this.isProtected(target)) continue;
      if (owner && target.username !== owner.username && this.isTeamMode() && target.team === owner.team) continue;
      const center: Vec3 = [target.x, target.y + 0.9, target.z];
      const damage = grenadeDamageAt(kind, position, center, this.geometry);
      if (damage > 0) this.applyPlayerDamage(owner, target, damage);
    }
    for (const vehicle of this.vehicleSimulation.states.values()) {
      if (!vehicle.health || vehicle.health <= 0) continue;
      const driver = this.state.players.get(vehicle.driver);
      if (owner && driver && this.isTeamMode() && driver.team === owner.team) continue;
      const center: Vec3 = [vehicle.pos[0], vehicle.pos[1] + 1, vehicle.pos[2]];
      const damage = grenadeVehicleDamageAt(kind, position, center, this.geometry);
      if (damage <= 0) continue;
      const result = this.vehicleSimulation.damage(vehicle.id, damage, Date.now());
      if (result?.destroyed && result.driver) this.destroyVehicleDriver(owner, result.driver);
    }
  }

  private vehicleSeat(client: Client, raw: any): void {
    const player = this.state.players.get(this.internal.get(client.sessionId)?.username ?? '');
    if (!player || player.is_dead) return;
    const requestedId = String(raw?.id ?? player.driving_vehicle);
    if (raw?.enter === false || player.driving_vehicle) {
      this.exitVehicle(player);
      return;
    }
    if (!this.vehicleSimulation.enter(this.vehiclePlayer(player), requestedId, Date.now())) return;
    const enteredVehicle = this.vehicleSimulation.states.get(requestedId)!;
    player.vehicle_index = Number(requestedId.replace('CAR_', '')); player.vehicle_generation = enteredVehicle.driverGeneration;
    this.vehicleWeaponBeforeDrive.set(player.username, player.weapon_id);
    player.animation = 'drive'; player.animation_code = 5; player.weapon_id = 'vehicle';
  }

  private isTeamMode(): boolean { return this.state.room_mode === 'TDM' || this.state.room_mode === 'CONQUEST'; }
  private areEnemies(a: PlayerState, b: PlayerState): boolean { return !this.isTeamMode() || a.team !== b.team; }

  private conquestSimulation(): ConquestState {
    if (!this.conquest) throw new Error('Conquest state is not initialized');
    return this.conquest;
  }

  private publishConquestState(state: ConquestState): void {
    this.state.tickets_a = state.ticketsA; this.state.tickets_b = state.ticketsB;
    this.state.room_state = state.roomState; this.state.winner = state.winner;
    for (const point of state.objectives) {
      const target = this.state.objectives.get(point.id);
      if (target) { target.owner = point.owner; target.capturing_team = point.capturing_team; target.progress = point.progress; target.contested = point.contested; }
    }
  }

  private stepConquestMode(dt: number): void {
    const state = this.conquestSimulation();
    stepConquest(state, this.state.players.values() as Iterable<PlayerState>, dt);
    this.publishConquestState(state);
  }
  private isProtected(player: PlayerState): boolean {
    if (player.is_bot) return Date.now() < (this.botProtectedUntil.get(player.username) ?? 0);
    const runtime = [...this.internal.values()].find((value) => value.username === player.username);
    return Date.now() < (runtime?.protectedUntil ?? 0);
  }

  private applyPlayerDamage(attacker: PlayerState | undefined, target: PlayerState, damage: number, client?: Client): void {
    if (this.state.room_mode === 'CONQUEST' && this.state.room_state === 'finished') return;
    if (target.is_dead || !Number.isFinite(damage) || damage <= 0) return;
    target.health = Math.max(0, target.health - Math.trunc(damage));
    this.broadcast('damage', { target: target.username, pos: [target.x, target.y, target.z], direction: [0, 0, 0], amount: Math.trunc(damage) });
    if (target.health <= 0) this.killPlayer(attacker, target, client);
  }

  private killPlayer(attacker: PlayerState | undefined, target: PlayerState, client?: Client): void {
    if (this.state.room_mode === 'CONQUEST' && this.state.room_state === 'finished') return;
    if (target.is_dead) return;
    target.health = 0; target.is_dead = true; target.deaths++; target.animation = 'death'; target.animation_code = 0; target.animation_time = 0;
    if (target.is_bot) this.botSimulation.markDead(target.username, Date.now());
    else {
      const targetRuntime = [...this.internal.values()].find((entry) => entry.username === target.username);
      if (targetRuntime) { targetRuntime.spawnAt = Date.now() + 3000; this.cancelReload(targetRuntime); }
      if (target.driving_vehicle) this.exitVehicle(target, true);
    }
    if (!attacker || attacker.username === target.username) return;
    attacker.kills++;
    if (this.state.room_mode === 'CONQUEST') {
      if (this.state.room_state === 'active') { const state = this.conquestSimulation(); awardConquestKill(state, attacker.team); this.publishConquestState(state); }
    } else if (this.state.room_mode === 'TDM') {
      if (attacker.team === 'A') this.state.score_a++;
      else if (attacker.team === 'B') this.state.score_b++;
      if (this.state.score_a >= 60) this.state.winner = 'A';
      else if (this.state.score_b >= 60) this.state.winner = 'B';
    } else if (attacker.kills >= 30) this.state.winner = attacker.username;
    client?.send('kill_confirmed', {});
  }

  private resolveBotShot(shot: BotShot): void {
    const shooter = this.state.players.get(shot.shooter);
    if (!shooter || shooter.is_dead || shooter.driving_vehicle) return;
    const endpoint = this.vec(shot.endpoint), origin = this.vec(shot.origin);
    if (!endpoint || !origin) return;
    let nearest: { target: PlayerState; distance: number; zone: HitZone } | undefined;
    const delta: Vec3 = [endpoint[0] - origin[0], endpoint[1] - origin[1], endpoint[2] - origin[2]];
    const length = Math.hypot(...delta); if (length < 0.01) return;
    const direction: Vec3 = [delta[0] / length, delta[1] / length, delta[2] / length];
    const vehicleHit = this.vehicleSimulation.rayHit(origin, endpoint, shooter.username);
    for (const target of this.state.players.values()) {
      if (target.username === shooter.username || target.is_dead || target.driving_vehicle) continue;
      const hit = traceAnimatedHit(origin, endpoint, [target.x, target.y, target.z], [target.qx, target.qy, target.qz, target.qw], clipForAnimationCode(target.animation_code), target.animation_time);
      if (!hit) continue;
      const distance = hit.fraction * length;
      if (!nearest || distance < nearest.distance) nearest = { target, distance, zone: hit.zone };
    }
    if (nearest) {
      const impact: Vec3 = [origin[0] + direction[0] * nearest.distance, origin[1] + direction[1] * nearest.distance, origin[2] + direction[2] * nearest.distance];
      if (vehicleHit && vehicleHit.fraction * length <= nearest.distance && !this.geometry.rayBlocked(origin, [origin[0] + direction[0] * vehicleHit.fraction * length, origin[1] + direction[1] * vehicleHit.fraction * length, origin[2] + direction[2] * vehicleHit.fraction * length])) {
        this.applyVehicleDamage(shooter, vehicleHit.id, shot.weapon, vehicleHit.fraction * length);
      } else if (!this.geometry.rayBlocked(origin, impact) && !this.vehicleSimulation.blocksRay(origin, impact, shooter.username)) {
        if (this.areEnemies(shooter, nearest.target) && !this.isProtected(nearest.target)) this.applyPlayerDamage(shooter, nearest.target, damageForZone(shot.weapon, nearest.distance, nearest.zone));
      }
    } else if (vehicleHit) {
      const impact: Vec3 = [origin[0] + direction[0] * vehicleHit.fraction * length, origin[1] + direction[1] * vehicleHit.fraction * length, origin[2] + direction[2] * vehicleHit.fraction * length];
      if (!this.geometry.rayBlocked(origin, impact)) this.applyVehicleDamage(shooter, vehicleHit.id, shot.weapon, vehicleHit.fraction * length);
    }
    this.broadcast('fire', { shooter: shooter.username, origin, hit: endpoint, normal: [0, 1, 0], wall: false, shot_id: shot.shotId });
  }

  private applyVehicleDamage(attacker: PlayerState | undefined, vehicleId: string, weaponId: string, metres: number, client?: Client): void {
    if (this.state.room_mode === 'CONQUEST' && this.state.room_state === 'finished') return;
    const vehicle = this.vehicleSimulation.states.get(vehicleId);
    if (!vehicle || (attacker && this.isTeamMode() && vehicle.driver && this.state.players.get(vehicle.driver)?.team === attacker.team)) return;
    const result = this.vehicleSimulation.damage(vehicleId, damageForZone(weaponId, metres, 'torso'), Date.now());
    if (!result) return;
    client?.send('hit_confirmed', {});
    if (result.destroyed && result.driver) this.destroyVehicleDriver(attacker, result.driver);
  }

  private destroyVehicleDriver(attacker: PlayerState | undefined, username: string): void {
    const driver = this.state.players.get(username);
    if (!driver || driver.is_dead) return;
    this.killPlayer(attacker, driver);
    if (driver.driving_vehicle) this.exitVehicle(driver, true);
  }

  private exitVehicle(player: PlayerState, force = false): void {
    const vehicleId = player.driving_vehicle;
    const exited = force
      ? this.vehicleSimulation.forceExit(this.vehiclePlayer(player))
      : this.vehicleSimulation.exit(this.vehiclePlayer(player));
    if (!exited) return;
    player.vehicle_index = -1;
    const exitedVehicle = this.vehicleSimulation.states.get(vehicleId);
    player.vehicle_generation = exitedVehicle?.driverGeneration ?? player.vehicle_generation + 1;
    const previousWeapon = this.vehicleWeaponBeforeDrive.get(player.username);
    if (previousWeapon && getWeapon(previousWeapon)) player.weapon_id = previousWeapon;
    this.vehicleWeaponBeforeDrive.delete(player.username);
    if (!player.is_dead) { player.animation = 'idle'; player.animation_code = 0; player.animation_time = 0; }
  }

  private selectWeapon(sessionId: string, weapon: string) {
    const meta = this.internal.get(sessionId), p = this.state.players.get(meta?.username ?? '');
    const selectedWeapon = getWeapon(weapon);
    if (!p || !meta || !selectedWeapon || p.is_dead || Date.now() < meta.reloadUntil || p.weapon_id === weapon) return;
    if (meta.reloadTimer) this.cancelReload(meta);
    meta.ammoByWeapon[p.weapon_id] = p.ammo;
    p.weapon_id = weapon; p.ammo = meta.ammoByWeapon[weapon] ?? selectedWeapon.magazine;
  }

  private fire(client: Client, raw: any) {
    const state = this.internal.get(client.sessionId), p = this.state.players.get(state?.username ?? '');
    if (!p || !state || p.is_dead) return;
    const now = Date.now(), weapon = getWeapon(p.weapon_id) ?? WEAPONS.ak47;
    if (now < state.reloadUntil || now - state.lastShot < 60000 / weapon.rpm || p.ammo <= 0) return;
    const requestedShotId = Math.trunc(Number(raw?.shot_id) || 0);
    if (requestedShotId > 0 && requestedShotId <= state.lastShotId) return;
    const shotId = requestedShotId > 0 ? requestedShotId : state.lastShotId + 1;
    const requestedOrigin = this.vec(raw?.origin);
    const origin: [number, number, number] = requestedOrigin && Math.hypot(requestedOrigin[0] - p.x, requestedOrigin[1] - (p.y + 1.2), requestedOrigin[2] - p.z) <= 0.8
      ? requestedOrigin : [p.x, p.y + 1.2, p.z];
    const buffered = this.inputs.get(client.sessionId).latest;
    const hasYaw = raw?.yaw !== undefined, hasPitch = raw?.pitch !== undefined;
    if ((hasYaw && !Number.isFinite(Number(raw.yaw))) || (hasPitch && !Number.isFinite(Number(raw.pitch)))) { this.rejectMessage(); return; }
    const aimYaw = clamp(hasYaw ? raw.yaw : buffered?.yaw ?? p.yaw, -Math.PI * 16, Math.PI * 16);
    const aimPitch = clamp(hasPitch ? raw.pitch : buffered?.pitch ?? p.pitch, -1.55, 1.55);
    p.yaw = aimYaw; p.pitch = aimPitch;
    p.qx = 0; p.qy = Math.sin(aimYaw * 0.5); p.qz = 0; p.qw = Math.cos(aimYaw * 0.5);
    const direction = aimDirection(aimYaw, aimPitch);
    const maxRange = 300;
    const endpoint: [number, number, number] = [origin[0] + direction[0] * maxRange, origin[1] + direction[1] * maxRange, origin[2] + direction[2] * maxRange];
    const requestedHit = this.vec(raw?.hit);
    const visualHit = requestedHit && Math.hypot(requestedHit[0] - endpoint[0], requestedHit[1] - endpoint[1], requestedHit[2] - endpoint[2]) <= maxRange + 1 ? requestedHit : endpoint;
    p.ammo--; state.ammoByWeapon[p.weapon_id] = p.ammo; state.lastShot = now; state.pendingHit = false;
    state.lastShotId = shotId; state.pendingShotId = shotId; state.pendingWeaponId = p.weapon_id;
    state.fireSegment = { o: origin, d: direction, range: maxRange, shotId, seen: this.rewind.lastSeenBy(client.sessionId, new RewindView()) };
    this.broadcast('fire', { shooter: state.username, origin, hit: visualHit, normal: this.vec(raw?.normal) ?? [0, 1, 0], wall: Boolean(raw?.wall), shot_id: shotId });
    this.resolveShot(client, state);
  }

  private hit(client: Client, raw: any) {
    // Legacy client hit notices are informational only; the server already resolved each fire ray.
    void client; void raw;
  }

  private resolveShot(client: Client, as: PlayerRuntime): void {
    const attacker = this.state.players.get(as.username);
    const fire = as.fireSegment;
    if (!attacker || !fire || attacker.is_dead) return;
    const seen = fire.seen;
    const endpoint: Vec3 = [fire.o[0] + fire.d[0] * fire.range, fire.o[1] + fire.d[1] * fire.range, fire.o[2] + fire.d[2] * fire.range];
    const vehicleHit = this.vehicleSimulation.rayHit(fire.o, endpoint, attacker.username);
    let first: { target: PlayerState; along: number; zone: HitZone } | undefined;
    for (const other of this.state.players.values()) {
      if (other.username === attacker.username || seen.value(other, 'health') <= 0 || seen.value(other, 'animation_code') === 5) continue;
      const snapshot = (field: string): number => Number(seen.value(other, field as any));
      const position: Vec3 = [snapshot('x'), snapshot('y'), snapshot('z')];
      const rotation: [number, number, number, number] = [snapshot('qx'), snapshot('qy'), snapshot('qz'), snapshot('qw')];
      const code = Math.trunc(snapshot('animation_code'));
      const clip = clipForAnimationCode(code);
      const phase = snapshot('animation_time');
      const hit = traceAnimatedHit(fire.o, endpoint, position, rotation, clip, phase);
      if (!hit) continue;
      const along = hit.fraction * fire.range;
      if (!first || along < first.along) first = { target: other, along, zone: hit.zone };
    }
    const vehicleAlong = vehicleHit ? vehicleHit.fraction * fire.range : Infinity;
    if (vehicleHit && vehicleAlong <= (first?.along ?? Infinity)) {
      const impact: Vec3 = [fire.o[0] + fire.d[0] * vehicleAlong, fire.o[1] + fire.d[1] * vehicleAlong, fire.o[2] + fire.d[2] * vehicleAlong];
      if (!this.geometry.rayBlocked(fire.o, impact)) this.applyVehicleDamage(attacker, vehicleHit.id, as.pendingWeaponId, vehicleAlong, client);
      return;
    }
    if (!first) return;
    const { target, along, zone } = first;
    if (!this.areEnemies(attacker, target) || this.isProtected(target)) return;
    const impact: Vec3 = [fire.o[0] + fire.d[0] * along, fire.o[1] + fire.d[1] * along, fire.o[2] + fire.d[2] * along];
    if (this.geometry.rayBlocked(fire.o, impact) || this.vehicleSimulation.blocksRay(fire.o, impact, attacker.username)) return;
    this.applyPlayerDamage(attacker, target, damageForZone(as.pendingWeaponId, along, zone), client);
    client.send('hit_confirmed', {});
  }

  private reload(client: Client) {
    const internal = this.internal.get(client.sessionId), p = this.state.players.get(internal?.username ?? '');
    if (!p || !internal || p.is_dead) return;
    const w = getWeapon(p.weapon_id) ?? WEAPONS.ak47;
    if (p.ammo < w.magazine && Date.now() >= internal.reloadUntil) {
      internal.reloadUntil = Date.now() + w.reloadMs;
      const reloadingWeapon = p.weapon_id;
      const deadline = internal.reloadUntil;
      const token = ++internal.reloadToken;
      internal.reloadTimer = this.clock.setTimeout(() => {
        if (internal.reloadToken !== token || internal.reloadUntil !== deadline) return;
        internal.reloadTimer = undefined; internal.reloadUntil = 0;
        if (this.state.players.has(p.username) && !p.is_dead && p.weapon_id === reloadingWeapon) { p.ammo = w.magazine; internal.ammoByWeapon[reloadingWeapon] = p.ammo; }
      }, w.reloadMs);
    }
  }

  private cancelReload(internal: PlayerRuntime): void {
    internal.reloadToken++;
    internal.reloadTimer?.clear();
    internal.reloadTimer = undefined;
    internal.reloadUntil = 0;
  }

  private respawn(sessionId: string, p: PlayerState, internal: PlayerRuntime) {
    const teamOffset = p.team === 'A' ? 0 : Math.floor(this.geometry.spawns.length / 2);
    const spawnIndex = (teamOffset + p.deaths) % this.geometry.spawns.length;
    const spawn = this.geometry.spawns[spawnIndex];
    p.x = spawn[0]; p.y = spawn[1]; p.z = spawn[2];
    this.cancelReload(internal);
    p.health = 100; p.is_dead = false; p.vx = 0; p.vy = 0; p.vz = 0; p.animation_time = 0; p.pose_time_ms = Date.now(); p.animation = 'idle'; p.animation_code = 0; p.grenades = 2; internal.grenadeLastThrow = 0; internal.animationStartedAt = Date.now(); internal.protectedUntil = Date.now() + 2500; p.ammo = (getWeapon(p.weapon_id) ?? WEAPONS.ak47).magazine; internal.ammoByWeapon[p.weapon_id] = p.ammo;
    internal.spawnAt = 0; internal.vy = 0;
    this.clients.find((client) => client.sessionId === sessionId)?.send('respawn', { x: p.x, y: p.y, z: p.z });
  }

  private requestRespawn(client: Client): void {
    const internal = this.internal.get(client.sessionId);
    const player = this.state.players.get(internal?.username ?? '');
    if (player?.is_dead && internal && Date.now() >= internal.spawnAt) this.respawn(client.sessionId, player, internal);
  }

  private vec(value: any): [number, number, number] | undefined {
    if (!Array.isArray(value) || value.length < 3) return;
    const out = [Number(value[0]), Number(value[1]), Number(value[2])];
    if (!out.every(Number.isFinite)) return;
    return [out[0], out[1], out[2]];
  }
}
