import { Room, Client } from 'colyseus';
import { definePlugins, ServerError } from '@colyseus/core';
import type { AuthContext } from '@colyseus/core';
import { findOneRoomAvailable } from '@colyseus/core/MatchMaker';
import { UniqueSessionPlugin } from 'colyseus/plugins/unique-session';
import { BattleState, ObjectiveState, PlayerState, ProjectileState, VehicleState, GAME_PROTOCOL_VERSION, PRIVATE_VIEW_TAG } from './schema.js';
import { Schema, StateView, defineTypes } from '@colyseus/schema';
import { loadWorldGeometry, PLAYABLE_MAPS, type Vec3, type WorldGeometry } from './world-geometry.js';
import { traceDroneHit, type DroneHit } from './drone-hitboxes.js';
import { DRONE_MOBILITY_MODES, DRONE_SPAWN_OFFSET, stepDroneFlight } from './drone-flight.js';
import { animationCodeForClip, REWIND_ANIMATION_CLIPS } from './presentation-animation.js';
import { BotSimulation, type BotPlayer, type BotShot } from './bot-simulation.js';
import { grenadeDamageAt, grenadeVehicleDamageAt, GrenadeSimulation, validateGrenadeLaunch, type ThrowableKind } from './grenade-simulation.js';
import { inputIsFromStaleVehicleSeat, VehicleSimulation, type VehiclePlayer } from './vehicle-simulation.js';
import { RewindView } from '@colyseus/core/Rewind';
import { updatePresentationView } from './presentation-relevance.js';
import { performance } from 'node:perf_hooks';
import { anonymousJoinLimiter, canonicalizeUsername, gameMessageLimiter, roomCreationLimiter } from './abuse-protection.js';
import { incrementProcessOperation, newRoomOperationsMetrics, recordPhaseTiming, recordProcessTick, roomOperationsMetrics, serviceOperationsMetrics, PERF_TRACE_ENABLED, type RoomOperationsMetrics } from './operations-metrics.js';
import { awardConquestKill, createConquestState, stepConquest, type ConquestState } from './conquest-simulation.js';
import { getConfiguredBattleAdmission } from './admission.js';

class MoveInput extends Schema {
  move_x = 0; move_y = 0; move_z = 0; yaw = 0; pitch = 0; jump = 0; sprint = 0; crouch = 0; mobility_index = -1;
  vehicle_throttle = 0; vehicle_steer = 0; vehicle_brake = 0; vehicle_gear = 1; vehicle_index = -1; vehicle_generation = 0;
}
defineTypes(MoveInput, { move_x: 'number', move_y: 'number', move_z: 'number', yaw: 'number', pitch: 'number', jump: 'number', sprint: 'number', crouch: 'number', vehicle_throttle: 'number', vehicle_steer: 'number', vehicle_brake: 'number', vehicle_gear: 'number', vehicle_index: 'number', vehicle_generation: 'number', mobility_index: 'number' });

export const activeRooms = new Map<string, { id: string; room: string; name: string; map: string; mode: string; timeOfDay: string; clients: number; bots: number; maxClients: number }>();
type JoinOptions = { protocol_version?: number; username?: string; room?: string; cid?: string; map?: string; map_name?: string; mode?: string; time_of_day?: string; timeOfDay?: string; name?: string };
type RoomCreationAllowance = { allow(key: string, limit: number, windowMs: number, now?: number): boolean };
type ValidRoomSettings = { requested: string; map: string; requestedMode: string; timeOfDay: string };
type PlayerRuntime = { username: string; map: string; lastShotByWeapon: Record<string, number>; pendingHit: boolean; reloadUntil: number; spawnAt: number;
  ammoByWeapon: Record<string, number>; reserveByWeapon: Record<string, number>; animationStartedAt: number; pendingWeaponId: string; pendingShotId: number; protectedUntil: number;
  grenadeLastThrow: number; grenadeLastRequestId: number; reloadToken: number; reloadTimer?: { clear(): void };
  manualRedeploy: boolean;
  offhandReloads: Map<string, { clear(): void }>;
  fireSegment?: { o: Vec3; d: Vec3; range: number; shotId: number; seen: RewindView } };
type Weapon = { damage: number; rpm: number; magazine: number; reloadMs: number; range: number; headshot: number; falloffStart: number; falloffEnd: number; minFraction: number; bodyFraction: number; missileSpeed?: number };
type Missile = { id: number; owner: PlayerState; sessionId: string; weaponId: string; position: Vec3; direction: Vec3; remaining: number; speed: number; damage: number; trackedTarget?: string; decoyed?: boolean; };
type SmokeZone = { x: number; y: number; z: number; radius: number; expiresAt: number; owner: string; };
const WEAPONS: Record<string, Weapon> = {
  ak47: { damage: 34, rpm: 600, magazine: 30, reloadMs: 2500, range: 90, headshot: 1.8, falloffStart: 20, falloffEnd: 90, minFraction: 0.6, bodyFraction: 0.84 },
  m4: { damage: 25, rpm: 750, magazine: 30, reloadMs: 2200, range: 90, headshot: 1.8, falloffStart: 20, falloffEnd: 90, minFraction: 0.6, bodyFraction: 0.84 },
  mp5: { damage: 25, rpm: 850, magazine: 30, reloadMs: 1800, range: 45, headshot: 1.6, falloffStart: 10, falloffEnd: 45, minFraction: 0.45, bodyFraction: 0.84 },
  dmr: { damage: 50, rpm: 240, magazine: 20, reloadMs: 2600, range: 150, headshot: 1.7, falloffStart: 35, falloffEnd: 150, minFraction: 0.75, bodyFraction: 0.91 },
  pistol: { damage: 34, rpm: 400, magazine: 12, reloadMs: 1500, range: 50, headshot: 1.8, falloffStart: 10, falloffEnd: 50, minFraction: 0.5, bodyFraction: 0.84 },
  m2010: { damage: 100, rpm: 45, magazine: 5, reloadMs: 3200, range: 150, headshot: 1.8, falloffStart: 0, falloffEnd: 150, minFraction: 1, bodyFraction: 1 },
  hmg: { damage: 34, rpm: 520, magazine: 60, reloadMs: 3400, range: 90, headshot: 1.8, falloffStart: 20, falloffEnd: 90, minFraction: 0.6, bodyFraction: 0.84 },
  aim9: { damage: 82, rpm: 75, magazine: 2, reloadMs: 4000, range: 170, headshot: 1, falloffStart: 0, falloffEnd: 170, minFraction: 1, bodyFraction: 1, missileSpeed: 78 },
  agm114: { damage: 95, rpm: 55, magazine: 1, reloadMs: 4000, range: 140, headshot: 1, falloffStart: 0, falloffEnd: 140, minFraction: 1, bodyFraction: 1, missileSpeed: 62 },
};
export const MAX_WEAPON_RANGE = Math.max(...Object.values(WEAPONS).map(weapon => weapon.range));
const getWeapon = (weaponId: string): Weapon | undefined => Object.hasOwn(WEAPONS, weaponId) ? WEAPONS[weaponId] : undefined;
const startingReserve = (weapon: Weapon): number => weapon.magazine * (weapon.missileSpeed ? 2 : 3);
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

export function maxHealthForChassis(mode?: string): number {
  switch (mode) {
    case 'tracked': return 220;
    case 'wheels': return 170;
    case 'heli': return 100;
    case 'wing': return 75;
    default: return 100;
  }
}

export class BattleRoom extends Room<{ state: BattleState; input: MoveInput }> {
  plugins = definePlugins({ uniqueSession: new UniqueSessionPlugin({ max: 1, onDuplicate: 'reject' }) });
  maxClients = 64;
  state = new BattleState();
  inputs = this.defineInput(MoveInput, { bufferMaxSize: 64, sanitize: { move_x: [-1, 1], move_y: [-1, 1], move_z: [-1, 1], yaw: [-Math.PI * 16, Math.PI * 16], pitch: [-1.55, 1.55], jump: [0, 1], sprint: [0, 1], crouch: [0, 1], vehicle_throttle: [-1, 1], vehicle_steer: [-1, 1], vehicle_brake: [0, 1], vehicle_gear: [1, 2], vehicle_index: [-1, 1000], vehicle_generation: [0, Number.MAX_SAFE_INTEGER] } });
  private internal = new Map<string, PlayerRuntime>();
  /** Stable lookup avoids rescanning all connected sessions for every actor at 60 Hz. */
  private sessionByUsername = new Map<string, string>();
  private rewind: any;
  private geometry!: WorldGeometry;
  private grenadeSimulation!: GrenadeSimulation;
  private readonly missiles = new Map<number, Missile>();
  private nextMissileId = 0;
  private vehicleSimulation!: VehicleSimulation;
  private botSimulation!: BotSimulation;
  private botProtectedUntil = new Map<string, number>();
  private botAnimationStartedAt = new Map<string, number>();
  private botPresentationClip = new Map<string, string>();
  private botFireUntil = new Map<string, number>();
  private vehicleWeaponBeforeDrive = new Map<string, string>();
  private operations!: RoomOperationsMetrics;
  private conquest?: ConquestState;
  private readonly smokeZones: SmokeZone[] = [];
  private presentationViews = new Map<string, Set<PlayerState>>();
  private presentationRefreshAt = 0;
  private readonly simulationPlayers = new Map<string, PlayerState & BotPlayer & VehiclePlayer>();
  private readonly botTickRecords = new Map<string, { x: number; y: number; z: number; dead: boolean; firedTick: number }>();
  private botTickSerial = 0;

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
    if (requested.includes('-quick-')) this.seatReservationTimeout = 60;
    this.syncVehiclesToSchema();
    activeRooms.set(this.roomId, { id: this.roomId, room: requested, name: (requested === `${map}-public` ? "Public Conquest" : String(options.name ?? "Custom Match")), map, mode: requestedMode, timeOfDay, clients: 0, bots: 0, maxClients: this.maxClients });
    this.patchRate = 50;
    this.rewind.attachAll(this.state.players, { fields: ['x', 'y', 'z', 'qx', 'qy', 'qz', 'qw', 'pitch'], mode: 'snapshot', interpolate: 'linear' });
    this.rewind.attachAll(this.state.players, { fields: ['animation_code', 'animation_time', 'health'], mode: 'snapshot', interpolate: 'step' });
    const voidLimit = geometry.name === "canyon" ? -119 : -14;
    let fixedTick = 0;
    let lastTickStartedAt = 0;
    this.setFixedTimestep((ctx) => {
      const tickStartedAt = performance.now();
      const previousTickStartedAt = lastTickStartedAt;
      this.operations.tickCount++;
      if (lastTickStartedAt > 0 && tickStartedAt - lastTickStartedAt > ctx.dt * 1500) this.operations.lateTicks++;
      lastTickStartedAt = tickStartedAt;
      const now = Date.now();
      let phaseStart = PERF_TRACE_ENABLED ? performance.now() : 0;
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
          if (!internal.manualRedeploy && now >= internal.spawnAt) this.respawn(sessionId, p, internal);
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
        const movementYaw = movementInput?.yaw ?? p.yaw;
        const mobilityIndex = movementInput?.mobility_index ?? -1;
        if (Number.isInteger(mobilityIndex) && mobilityIndex >= 0 && mobilityIndex < DRONE_MOBILITY_MODES.length) {
          p.mobility_mode = DRONE_MOBILITY_MODES[mobilityIndex];
        }
        const flight = stepDroneFlight(this.geometry, from, [p.vx, p.vy, p.vz], {
          move_x: movementInput?.move_x ?? 0, move_y: movementInput?.move_y ?? 0,
          move_z: movementInput?.move_z ?? 0, yaw: movementYaw,
          sprint: (movementInput?.sprint ?? 0) > 0.5 ? 1 : 0, mobility_mode: p.mobility_mode,
        }, ctx.dt);
        const resolved = flight.position;
        p.x = resolved[0]; p.y = resolved[1]; p.z = resolved[2];
        p.vx = flight.velocity[0]; p.vy = flight.velocity[1]; p.vz = flight.velocity[2];
        p.yaw = movementYaw; p.pitch = movementInput?.pitch ?? p.pitch;
        p.qx = 0; p.qy = Math.sin(movementYaw * 0.5); p.qz = 0; p.qw = Math.cos(movementYaw * 0.5);
        p.ack_input_sequence = inputChannel.consumedCount;
      }
      if (PERF_TRACE_ENABLED) {
        recordPhaseTiming(this.operations, 'human_movement', performance.now() - phaseStart);
        phaseStart = performance.now();
      }

      if (this.vehicleSimulation.needsStep) this.stepVehicles(ctx.dt);
      if (PERF_TRACE_ENABLED) {
        recordPhaseTiming(this.operations, 'vehicles', performance.now() - phaseStart);
        phaseStart = performance.now();
      }

      if (this.botSimulation.hasBots) this.stepBots(ctx.dt);
      if (PERF_TRACE_ENABLED) {
        recordPhaseTiming(this.operations, 'bots', performance.now() - phaseStart);
        phaseStart = performance.now();
      }

      // The native safety floor is below the playable world. Authority must
      // finish the fall through the existing death/respawn lifecycle.
      for (const actor of this.state.players.values()) {
        if (!actor.is_dead && actor.y < voidLimit) this.killPlayer(undefined, actor);
      }
      if (this.grenadeSimulation.hasGrenades) this.stepGrenades(ctx.dt);
      if (PERF_TRACE_ENABLED) {
        recordPhaseTiming(this.operations, 'grenades', performance.now() - phaseStart);
        phaseStart = performance.now();
      }

      if (this.missiles.size > 0) this.stepMissiles(ctx.dt);
      if (PERF_TRACE_ENABLED) {
        recordPhaseTiming(this.operations, 'missiles', performance.now() - phaseStart);
        phaseStart = performance.now();
      }

      if (this.state.room_mode === 'CONQUEST' && this.state.room_state === 'active') this.stepConquestMode(ctx.dt);
      if (PERF_TRACE_ENABLED) {
        recordPhaseTiming(this.operations, 'conquest', performance.now() - phaseStart);
        phaseStart = performance.now();
      }

      // Simulation remains 60 Hz; replicated schema patches are capped at 20 Hz.
      // Composite driver/vehicle mirrors must describe the same fixed tick.
      // Schema publication remains 20 Hz; this only keeps its pending state coherent.
      if (this.vehicleSimulation.needsStep || ++fixedTick % 3 === 0) this.syncVehiclesToSchema();
      if (PERF_TRACE_ENABLED) {
        recordPhaseTiming(this.operations, 'schema_prep', performance.now() - phaseStart);
      }
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
    this.onMessage('fire', (client, raw: any) => { if (this.allowMessage(client, 'fire', 36)) this.fire(client, raw); });
    this.onMessage('hit', (client, raw: any) => { if (this.allowMessage(client, 'hit', 20)) this.hit(client, raw); });
    this.onMessage('reload', (client, raw: any) => {
      if (!this.allowMessage(client, 'reload', 6)) return;
      if (typeof raw?.weapon === 'string' && raw.weapon !== '') this.reloadOffhand(client, raw.weapon);
      else this.reload(client);
    });
    this.onMessage('switch', (client, raw: any) => { if (this.allowMessage(client, 'switch', 8)) this.selectWeapon(client.sessionId, String(raw?.weapon ?? '')); });
    this.onMessage('loadout', (client, raw: any) => {
      if (!this.allowMessage(client, 'loadout', 4)) return;
      const p = this.state.players.get(this.internal.get(client.sessionId)?.username ?? '');
      const runtime = this.internal.get(client.sessionId);
      if (!p || !runtime || p.is_dead) return;
      runtime.manualRedeploy = raw?.manual_redeploy === true;
      const primary = String(raw?.primary ?? '');
      const secondary = String(raw?.secondary ?? '');
      if (getWeapon(primary)) {
        p.primary_payload = primary;
        p.secondary_payload = secondary !== primary && getWeapon(secondary) ? secondary : '';
        this.selectWeapon(client.sessionId, primary);
      }
      const throwable = String(raw?.throwable ?? p?.throwable ?? 'frag');
      if (throwable === 'frag' || throwable === 'impact') p.throwable = throwable;
    });
    this.onMessage('respawn', (client, raw: any) => { if (this.allowMessage(client, 'respawn', 3)) this.requestRespawn(client, raw); });
    this.onMessage('grenade', (client, raw: any) => {
      const runtime = this.internal.get(client.sessionId), requestId = this.grenadeRequestId(raw?.request_id);
      if (requestId > 0 && runtime && requestId <= runtime.grenadeLastRequestId) { this.rejectGrenadeRequest(client, requestId); return; }
      if (requestId > 0 && runtime) runtime.grenadeLastRequestId = requestId;
      if (this.allowMessage(client, 'grenade', 4)) this.throwGrenade(client, raw);
      else this.rejectGrenadeRequest(client, requestId, false);
    });
    this.onMessage('vehicle_seat', (client, raw: any) => { if (this.allowMessage(client, 'vehicle_seat', 8)) this.vehicleSeat(client, raw); });
    this.onMessage('deploy_smoke', (client, raw: any) => {
      const p = this.state.players.get(this.internal.get(client.sessionId)?.username ?? '');
      if (!p || p.is_dead) return;
      const pos: Vec3 = Array.isArray(raw?.position) && raw.position.length >= 3 ? [raw.position[0], raw.position[1], raw.position[2]] : [p.x, p.y, p.z];
      this.deploySmokeZone(p.username, pos);
    });
    // Vehicle controls are accepted only from the buffered defineInput timeline.
  }

  onJoin(client: Client, options: JoinOptions, auth?: { username: string; queueTeam?: 'A' | 'B' }) {
    const username = canonicalizeUsername(auth?.username ?? options.username);
    if (!username) { this.operations.rejectedAdmissions++; incrementProcessOperation('rejectedAdmissions'); throw new Error('valid username required'); }
    if ([...this.internal.values()].some((x) => x.username.normalize('NFKC').toLowerCase() === username.normalize('NFKC').toLowerCase())) { this.operations.rejectedAdmissions++; incrementProcessOperation('rejectedAdmissions'); throw new Error('username already in room'); }
    this.operations.joined++;
    incrementProcessOperation('joined');
    const p = new PlayerState();
    const spawn = this.geometry.spawns[(this.clients.length - 1) % this.geometry.spawns.length];
    p.x = spawn[0]; p.y = spawn[1] + DRONE_SPAWN_OFFSET; p.z = spawn[2];
    if (this.state.room_mode === 'TDM' || this.state.room_mode === 'CONQUEST') {
      const players = [...this.state.players.values()];
      p.team = auth?.queueTeam ?? (players.filter((player) => player.team === 'A' && !player.is_bot).length <= players.filter((player) => player.team === 'B' && !player.is_bot).length ? 'A' : 'B');
    } else p.team = 'NONE';
    p.username = username;
    p.health = maxHealthForChassis(p.mobility_mode);
    this.state.players.set(username, p);
    this.simulationPlayers.set(username, p as PlayerState & BotPlayer & VehiclePlayer);
    client.view = new StateView();
    client.view.add(p, PRIVATE_VIEW_TAG);
    const listing = activeRooms.get(this.roomId); if (listing) listing.clients = this.clients.length;
    const runtime: PlayerRuntime = {
      username, map: String(this.metadata?.map ?? 'industrial'), lastShotByWeapon: {}, manualRedeploy: false, offhandReloads: new Map(), pendingHit: false,
      reloadUntil: 0, reloadToken: 0, spawnAt: 0, ammoByWeapon: {}, reserveByWeapon: {},
      animationStartedAt: Date.now(), pendingWeaponId: 'ak47', pendingShotId: 0,
      protectedUntil: Date.now() + 2500, grenadeLastThrow: 0, grenadeLastRequestId: 0,
    };
    this.restockAmmo(p, runtime);
    this.internal.set(client.sessionId, runtime);
    this.sessionByUsername.set(username, client.sessionId);
    client.send('identity', { username, map: this.metadata?.map, session_id: client.sessionId, dual_payload: true, manual_redeploy: true });
    this.syncBots();
    this.presentationRefreshAt = 0;
    this.refreshPresentationViews();
  }

  async onDrop(client: Client) {
    const player = this.state.players.get(this.internal.get(client.sessionId)?.username ?? '');
    if (player?.driving_vehicle) this.exitVehicle(player, true);
    try { await this.allowReconnection(client, 15); } catch { /* Colyseus invokes onLeave after the reconnect window expires. */ }
  }
  onReconnect(client: Client) {
    const meta = this.internal.get(client.sessionId);
    if (!meta) return;
    client.send('identity', { username: meta.username, map: this.metadata?.map, session_id: client.sessionId, dual_payload: true, manual_redeploy: true });
    const player = this.state.players.get(meta.username);
    if (player) for (const weapon of [player.primary_payload, player.secondary_payload]) {
      if (weapon && weapon !== player.weapon_id) this.sendOffhandAmmo(client, meta, weapon, player.last_shot_id);
    }
  }
  onLeave(client: Client) { client.view?.dispose(); client.view = undefined; this.presentationViews.delete(client.sessionId); const meta = this.internal.get(client.sessionId); if (meta) { this.operations.left++; incrementProcessOperation('left'); this.cancelReload(meta); this.sessionByUsername.delete(meta.username); const player = this.state.players.get(meta.username); if (player?.driving_vehicle) this.exitVehicle(player, true); if (player) for (const peer of this.clients) peer.view?.remove(player); this.state.players.delete(meta.username); this.simulationPlayers.delete(meta.username); } this.internal.delete(client.sessionId); const listing = activeRooms.get(this.roomId); if (listing) listing.clients = this.clients.length; this.syncBots(); if (this.clients.length === 0) activeRooms.delete(this.roomId); }

  onDispose() { for (const client of this.clients) { client.view?.dispose(); client.view = undefined; } this.presentationViews.clear(); for (const internal of this.internal.values()) this.cancelReload(internal); activeRooms.delete(this.roomId); roomOperationsMetrics.delete(this.roomId); this.simulationPlayers.clear(); this.botTickRecords.clear(); }

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
    for (const name of removed) { this.state.players.delete(name); this.simulationPlayers.delete(name); this.botTickRecords.delete(name); this.botProtectedUntil.delete(name); this.botAnimationStartedAt.delete(name); this.botPresentationClip.delete(name); this.botFireUntil.delete(name); }
    for (const descriptor of joined) {
      const bot = new PlayerState();
      bot.username = descriptor.username; bot.is_bot = true; bot.x = descriptor.x; bot.y = descriptor.y; bot.z = descriptor.z;
      bot.vx = descriptor.vx ?? 0; bot.vy = descriptor.vy ?? 0; bot.vz = descriptor.vz ?? 0;
      bot.qy = descriptor.qy ?? 0; bot.qw = descriptor.qw ?? 1; bot.yaw = descriptor.yaw ?? 0; bot.pitch = descriptor.pitch ?? 0;
      bot.health = descriptor.health; bot.kills = descriptor.kills; bot.deaths = descriptor.deaths; bot.team = descriptor.team;
      bot.weapon_id = descriptor.weapon_id; bot.ammo = descriptor.ammo; bot.driving_vehicle = descriptor.driving_vehicle ?? '';
      bot.mobility_mode = descriptor.mobility_mode ?? 'heli';
      this.state.players.set(bot.username, bot); this.simulationPlayers.set(bot.username, bot as PlayerState & BotPlayer & VehiclePlayer); this.botProtectedUntil.set(bot.username, Date.now() + 2500); this.botAnimationStartedAt.set(bot.username, Date.now());
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
    if (this.simulationPlayers.size !== this.state.players.size) {
      this.simulationPlayers.clear();
      for (const [name, player] of this.state.players) {
        this.simulationPlayers.set(name, player as PlayerState & BotPlayer & VehiclePlayer);
      }
    }
    return this.simulationPlayers;
  }

  private vehiclePlayer(player: PlayerState): VehiclePlayer {
    return player as PlayerState & VehiclePlayer;
  }

  private stepVehicles(dt: number): void {
    const players = this.playerView();
    const roadkills = this.vehicleSimulation.step(dt, Date.now(), players);
    for (const impact of this.vehicleSimulation.takeImpacts()) this.broadcast('vehicle_impact', impact);
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
    if (!this.botTickRecords) (this as any).botTickRecords = new Map();
    if (this.botTickSerial === undefined) this.botTickSerial = 0;
    this.botTickSerial++;
    const currentTick = this.botTickSerial;
    for (const [name, player] of this.state.players) {
      if (!player.is_bot) continue;
      let rec = this.botTickRecords.get(name);
      if (!rec) {
        rec = { x: player.x, y: player.y, z: player.z, dead: player.is_dead, firedTick: 0 };
        this.botTickRecords.set(name, rec);
      } else {
        rec.x = player.x;
        rec.y = player.y;
        rec.z = player.z;
        rec.dead = player.is_dead;
      }
    }
    this.botSimulation.step(players, dt, Date.now(), {
      vehicleBlocked: (at) => {
        for (const v of this.vehicleSimulation.states.values()) {
          if (Math.hypot(at[0] - v.pos[0], at[2] - v.pos[2]) < 3.2) return true;
        }
        return false;
      },
      ...(this.state.room_mode === 'CONQUEST' ? { objectiveGoal: (bot: BotPlayer) => this.conquestBotGoal(bot) } : {}),
      onSmoke: (bot) => {
        this.deploySmokeZone(bot.username, [bot.x, bot.y, bot.z]);
      },
      onShot: (shot) => {
        const rec = this.botTickRecords.get(shot.shooter);
        if (rec) rec.firedTick = currentTick;
        this.resolveBotShot(shot);
      },
    });
    for (const [name, player] of this.state.players) {
      if (!player.is_bot) continue;
      const previous = this.botTickRecords.get(name), now = Date.now();
      if (previous?.dead && !player.is_dead) this.botProtectedUntil.set(name, now + 2500);
      const moved = previous ? Math.hypot(player.x - previous.x, player.y - previous.y, player.z - previous.z) > 0.01 : false;
      if (previous && previous.firedTick === currentTick) this.botFireUntil.set(name, now + 320);
      const firing = now < (this.botFireUntil.get(name) ?? 0);
      const clip = player.is_dead ? 'death' : firing ? (moved ? 'firing walk' : 'firing') : moved ? 'run' : 'idle';
      if (this.botPresentationClip.get(name) !== clip) {
        this.botPresentationClip.set(name, clip); this.botAnimationStartedAt.set(name, now);
      }
      player.animation = clip; player.animation_code = animationCodeForClip(clip);
      const startedAt = this.botAnimationStartedAt.get(name) ?? now;
      player.pose_time_ms = now; player.animation_time = Math.max(0, (now - startedAt) / 1000);
    }
  }

  private stepGrenades(dt: number): void {
    const explosions = this.grenadeSimulation.step(dt);
    for (const grenade of this.grenadeSimulation.grenades) {
      this.moveProjectile(this.state.grenade_projectiles.get(String(grenade.id)), grenade.position, grenade.velocity);
    }
    for (const explosion of explosions) {
      this.retireProjectile(this.state.grenade_projectiles, explosion.id, explosion.position);
      this.resolveExplosion(explosion.id, explosion.owner, explosion.kind, explosion.position);
    }
  }

  private moveProjectile(state: ProjectileState | undefined, position: Vec3, velocity: Vec3): void {
    if (!state) return;
    [state.x, state.y, state.z] = position;
    [state.vx, state.vy, state.vz] = velocity;
  }

  private publishProjectile(collection: Map<string, ProjectileState>, id: number, owner: string, kind: string, requestId: number, position: Vec3, velocity: Vec3): void {
    const projectile = new ProjectileState();
    projectile.id = String(id);
    projectile.owner = owner;
    projectile.kind = kind;
    projectile.request_id = requestId;
    this.moveProjectile(projectile, position, velocity);
    collection.set(projectile.id, projectile);
  }

  private retireProjectile(collection: Map<string, ProjectileState>, id: number, position: Vec3): void {
    const key = String(id);
    const projectile = collection.get(key);
    if (!projectile) return;
    projectile.active = 0;
    this.moveProjectile(projectile, position, [0, 0, 0]);
    // Preserve the correlation key even when launch and impact share a patch.
    this.clock.setTimeout(() => collection.delete(key), 150);
  }

  private conquestBotGoal(bot: BotPlayer): { position: Vec3; radius: number } | undefined {
    if (!this.conquest?.objectives.length) return undefined;
    const team = bot.team === 'A' || bot.team === 'B' ? bot.team : 'A';
    // Priority 1: Friendly objectives currently being captured by enemy
    const underAttack = this.conquest.objectives.filter((o) => o.owner === team && o.capturing_team !== '' && o.capturing_team !== team);
    // Priority 2: Unowned or enemy-owned objectives
    const unownedOrEnemy = this.conquest.objectives.filter((o) => o.owner !== team);
    const candidates = underAttack.length ? underAttack : (unownedOrEnemy.length ? unownedOrEnemy : this.conquest.objectives);
    const teamBots = [...this.state.players.values()].filter((player) => player.is_bot && player.team === team).sort((a, b) => a.username.localeCompare(b.username));
    const index = Math.max(0, teamBots.findIndex((player) => player.username === bot.username));
    const goal = candidates[index % candidates.length];
    return { position: [goal.x, goal.y + DRONE_SPAWN_OFFSET, goal.z], radius: goal.radius };
  }

  private throwGrenade(client: Client, raw: any): void {
    const runtime = this.internal.get(client.sessionId), player = this.state.players.get(runtime?.username ?? '');
    if (!runtime || !player || player.is_dead || player.driving_vehicle || player.grenades <= 0) { this.rejectGrenadeRequest(client, raw?.request_id); return; }
    const kind = player.throwable === 'impact' ? 'impact' : 'frag';
    const position = this.vec(raw?.pos), velocity = this.vec(raw?.vel);
    if (!position || !velocity) { this.rejectGrenadeRequest(client, raw?.request_id); return; }
    const now = Date.now(), eye: Vec3 = [player.x, player.y, player.z], feet: Vec3 = [player.x, player.y, player.z];
    const launch = { owner: player.username, kind, position, velocity };
    if (!validateGrenadeLaunch(launch, feet, eye, kind, runtime.grenadeLastThrow, now, player.grenades, this.geometry)) { this.rejectGrenadeRequest(client, raw?.request_id); return; }
    const grenade = this.grenadeSimulation.launch(launch);
    if (!grenade) { this.rejectGrenadeRequest(client, raw?.request_id); return; }
    runtime.grenadeLastThrow = now; player.grenades--;
    this.publishProjectile(this.state.grenade_projectiles, grenade.id, client.sessionId, kind, this.grenadeRequestId(raw?.request_id), grenade.position, grenade.velocity);
    this.broadcast('grenade', { shooter: player.username, pos: grenade.position, vel: grenade.velocity, id: grenade.id, throwable: grenade.kind, request_id: this.grenadeRequestId(raw?.request_id) });
  }

  private resolveExplosion(id: number, ownerName: string, kind: ThrowableKind, position: Vec3): void {
    if (this.state.room_mode === 'CONQUEST' && this.state.room_state === 'finished') return;
    this.broadcast('explosion', { id, pos: position, throwable: kind });
    const owner = this.state.players.get(ownerName);
    for (const target of this.state.players.values()) {
      if (target.is_dead || target.driving_vehicle || this.isProtected(target)) continue;
      if (owner && target.username !== owner.username && this.isTeamMode() && target.team === owner.team) continue;
      const center: Vec3 = [target.x, target.y, target.z];
      const damage = grenadeDamageAt(kind, position, center, this.geometry);
      if (damage > 0) {
        const delta: Vec3 = [center[0] - position[0], center[1] - position[1], center[2] - position[2]];
        const dist = Math.hypot(...delta);
        const gDir: Vec3 = dist > 0.01 ? [delta[0] / dist, delta[1] / dist, delta[2] / dist] : [0, 1, 0];
        this.applyPlayerDamage(owner, target, damage, undefined, gDir);
      }
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
    // Drones cannot occupy vehicle seats; world vehicles remain collidable props.
    void requestedId;
    this.rejectMessage();
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
    const runtime = this.internal.get(this.sessionByUsername.get(player.username) ?? '');
    return Date.now() < (runtime?.protectedUntil ?? 0);
  }

  private applyPlayerDamage(attacker: PlayerState | undefined, target: PlayerState, damage: number, client?: Client, shotDir?: Vec3): void {
    if (this.state.room_mode === 'CONQUEST' && this.state.room_state === 'finished') return;
    if (target.is_dead || !Number.isFinite(damage) || damage <= 0) return;

    let hitType: 'normal' | 'deflect' | 'crit' = 'normal';
    // Directional Armor & Weakspot calculation for ground vehicles (tracked & wheels)
    if (shotDir && (target.mobility_mode === 'tracked' || target.mobility_mode === 'wheels')) {
      const isTopAttack = shotDir[1] < -0.5736; // >35 deg downward steep plunge
      if (!isTopAttack) {
        const yaw = target.yaw ?? 0;
        // Godot camera forward at yaw=0 is -Z, positive yaw turns toward -X
        const fwdX = -Math.sin(yaw);
        const fwdZ = -Math.cos(yaw);
        // shotDir travels from attacker towards victim, so vector from victim towards attacker is -shotDir
        const toAttackerX = -shotDir[0];
        const toAttackerZ = -shotDir[2];
        const len = Math.hypot(toAttackerX, toAttackerZ);
        if (len > 0.001) {
          const cosAngle = (fwdX * toAttackerX + fwdZ * toAttackerZ) / len;
          if (cosAngle > 0.5) {
            // Frontal 60 deg arc: 0.75x damage deflection
            damage = Math.round(damage * 0.75);
            hitType = 'deflect';
          } else if (cosAngle < -0.5) {
            // Rear 60 deg engine bay weakspot: 1.5x damage critical
            damage = Math.round(damage * 1.5);
            hitType = 'crit';
          }
        }
      }
    }

    target.health = Math.max(0, target.health - Math.trunc(damage));
    if (target.is_bot) this.botSimulation.onBotDamaged(target.username, damage, attacker?.username, Date.now());
    this.broadcast('damage', { target: target.username, pos: [target.x, target.y, target.z], direction: shotDir ?? [0, 0, 0], amount: Math.trunc(damage), hit_type: hitType });
    client?.send('hit_confirmed', { type: hitType, target: target.username, damage: Math.trunc(damage) });
    if (target.health <= 0) this.killPlayer(attacker, target, client);
  }

  private killPlayer(attacker: PlayerState | undefined, target: PlayerState, client?: Client): void {
    if (this.state.room_mode === 'CONQUEST' && this.state.room_state === 'finished') return;
    if (target.is_dead) return;
    target.health = 0; target.is_dead = true; target.deaths++; target.animation = 'death'; target.animation_code = 0; target.animation_time = 0;
    if (target.is_bot) this.botSimulation.markDead(target.username, Date.now());
    else {
      const targetRuntime = this.internal.get(this.sessionByUsername.get(target.username) ?? '');
      if (targetRuntime) { targetRuntime.spawnAt = Date.now() + 3000; this.cancelReload(targetRuntime); }
      if (target.driving_vehicle) this.exitVehicle(target, true);
    }
    if (!attacker || attacker.username === target.username) return;
    attacker.kills++;
    this.broadcast('elimination', {
      killer: attacker.username,
      victim: target.username,
      weapon: attacker.weapon_id || 'ak47',
      drone: attacker.mobility_mode || 'quad',
    });
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
    let nearest: { target: PlayerState; distance: number; zone: DroneHit['zone'] } | undefined;
    const delta: Vec3 = [endpoint[0] - origin[0], endpoint[1] - origin[1], endpoint[2] - origin[2]];
    const length = Math.hypot(...delta); if (length < 0.01) return;
    const direction: Vec3 = [delta[0] / length, delta[1] / length, delta[2] / length];
    const vehicleHit = this.vehicleSimulation.rayHit(origin, endpoint, shooter.username);
    for (const target of this.state.players.values()) {
      if (target.username === shooter.username || target.is_dead || target.driving_vehicle) continue;
      const hit = traceDroneHit(origin, endpoint, [target.x, target.y, target.z]);
      if (!hit) continue;
      const distance = hit.fraction * length;
      if (!nearest || distance < nearest.distance) nearest = { target, distance, zone: hit.zone };
    }
    if (nearest) {
      const impact: Vec3 = [origin[0] + direction[0] * nearest.distance, origin[1] + direction[1] * nearest.distance, origin[2] + direction[2] * nearest.distance];
      if (vehicleHit && vehicleHit.fraction * length <= nearest.distance && !this.geometry.rayBlocked(origin, [origin[0] + direction[0] * vehicleHit.fraction * length, origin[1] + direction[1] * vehicleHit.fraction * length, origin[2] + direction[2] * vehicleHit.fraction * length])) {
        this.applyVehicleDamage(shooter, vehicleHit.id, shot.weapon, vehicleHit.fraction * length);
      } else if (!this.geometry.rayBlocked(origin, impact) && !this.vehicleSimulation.blocksRay(origin, impact, shooter.username)) {
        if (this.areEnemies(shooter, nearest.target) && !this.isProtected(nearest.target)) this.applyPlayerDamage(shooter, nearest.target, damageForZone(shot.weapon, nearest.distance, nearest.zone), undefined, direction);
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
    if (!p || !meta || !selectedWeapon || p.is_dead || p.weapon_id === weapon) return;
    if (meta.reloadTimer) this.cancelActiveReload(meta);
    meta.offhandReloads.get(weapon)?.clear();
    meta.offhandReloads.delete(weapon);
    meta.ammoByWeapon[p.weapon_id] = p.ammo;
    meta.reserveByWeapon[p.weapon_id] = p.reserve_ammo;
    p.weapon_id = weapon; p.ammo = meta.ammoByWeapon[weapon] ?? selectedWeapon.magazine;
    p.reserve_ammo = meta.reserveByWeapon[weapon] ?? startingReserve(selectedWeapon);
  }

  private fire(client: Client, raw: any) {
    const state = this.internal.get(client.sessionId), p = this.state.players.get(state?.username ?? '');
    if (!p || !state || p.is_dead || p.driving_vehicle) return;
    const suppliedId = Number(raw?.shot_id ?? 0);
    if (!Number.isSafeInteger(suppliedId) || suppliedId < 0 || suppliedId > 0x7fffffff) return;
    if (suppliedId > 0 && suppliedId <= p.last_shot_id) return;
    const shotId = suppliedId || p.last_shot_id + 1;
    // Confirm receipt even when cadence, reload, or empty ammo rejects the shot.
    p.last_shot_id = shotId;
    const explicit = typeof raw?.weapon === 'string' ? raw.weapon : '';
    if (explicit && explicit !== p.primary_payload && explicit !== p.secondary_payload) return;
    const weaponId = explicit || p.weapon_id;
    const offhand = weaponId !== p.weapon_id;
    const weapon = getWeapon(weaponId);
    if (!weapon) return;
    const now = Date.now();
    if ((offhand ? state.offhandReloads.has(weaponId) : now < state.reloadUntil)
      || now - (state.lastShotByWeapon[weaponId] ?? 0) < 60000 / weapon.rpm
      || (offhand ? state.ammoByWeapon[weaponId] : p.ammo) <= 0
      || (weapon.missileSpeed && this.missiles.size >= 128)) {
      if (offhand) this.sendOffhandAmmo(client, state, weaponId, shotId);
      return;
    }
    const requestedOrigin = this.vec(raw?.origin);
    const origin: [number, number, number] = requestedOrigin && Math.hypot(requestedOrigin[0] - p.x, requestedOrigin[1] - p.y, requestedOrigin[2] - p.z) <= 0.9
      ? requestedOrigin : [p.x, p.y, p.z];
    const buffered = this.inputs.get(client.sessionId).latest;
    const hasYaw = raw?.yaw !== undefined, hasPitch = raw?.pitch !== undefined;
    if ((hasYaw && !Number.isFinite(Number(raw.yaw))) || (hasPitch && !Number.isFinite(Number(raw.pitch)))) { this.rejectMessage(); return; }
    const aimYaw = clamp(hasYaw ? raw.yaw : buffered?.yaw ?? p.yaw, -Math.PI * 16, Math.PI * 16);
    const aimPitch = clamp(hasPitch ? raw.pitch : buffered?.pitch ?? p.pitch, -1.55, 1.55);
    const direction = aimDirection(aimYaw, aimPitch);
    const maxRange = 300;
    const endpoint: [number, number, number] = [origin[0] + direction[0] * maxRange, origin[1] + direction[1] * maxRange, origin[2] + direction[2] * maxRange];
    const requestedHit = this.vec(raw?.hit);
    const visualHit = requestedHit && Math.hypot(requestedHit[0] - endpoint[0], requestedHit[1] - endpoint[1], requestedHit[2] - endpoint[2]) <= maxRange + 1 ? requestedHit : endpoint;
    state.ammoByWeapon[weaponId] = (offhand ? state.ammoByWeapon[weaponId] : p.ammo) - 1;
    if (offhand) this.sendOffhandAmmo(client, state, weaponId, shotId);
    else p.ammo = state.ammoByWeapon[weaponId];
    state.lastShotByWeapon[weaponId] = now;
    state.pendingHit = false;
    state.pendingShotId = shotId; state.pendingWeaponId = weaponId;
    if (weapon.missileSpeed) {
      const center: Vec3 = [p.x, p.y, p.z];
      const position = this.geometry.rayBlocked(center, origin) ? center : origin;
      const id = ++this.nextMissileId;
      this.missiles.set(id, { id, owner: p, sessionId: client.sessionId, weaponId: weaponId, position, direction, remaining: weapon.range, speed: weapon.missileSpeed, damage: weapon.damage });
      const velocity = direction.map(component => component * weapon.missileSpeed!) as [number, number, number];
      this.publishProjectile(this.state.missile_projectiles, id, client.sessionId, weaponId, shotId, position, velocity);
      this.broadcast('missile_launch', { id, weapon: weaponId, position, direction, speed: weapon.missileSpeed, duration: weapon.range / weapon.missileSpeed });
      return;
    }
    state.fireSegment = { o: origin, d: direction, range: maxRange, shotId, seen: this.rewind.lastSeenBy(client.sessionId, new RewindView()) };
    this.broadcast('fire', { shooter: state.username, origin, hit: visualHit, normal: this.vec(raw?.normal) ?? [0, 1, 0], wall: Boolean(raw?.wall), shot_id: shotId, weapon: weaponId });
    this.resolveShot(client, state);
  }

  private hit(client: Client, raw: any) {
    // Legacy client hit notices are informational only; the server already resolved each fire ray.
    void client; void raw;
  }

  public deploySmokeZone(owner: string, pos: Vec3): void {
    const expiresAt = Date.now() + 6500;
    this.smokeZones.push({ x: pos[0], y: pos[1], z: pos[2], radius: 14, expiresAt, owner });
    this.broadcast('smoke_screen', { shooter: owner, position: pos, radius: 14 });

    // Break any incoming missile tracking this owner or passing near this smoke
    for (const missile of this.missiles.values()) {
      if (missile.trackedTarget === owner || Math.hypot(missile.position[0] - pos[0], missile.position[2] - pos[2]) < 18) {
        missile.trackedTarget = undefined;
        missile.decoyed = true;
        const jitterX = (Math.random() - 0.5) * 0.9;
        const jitterY = Math.random() * 0.6 + 0.3;
        const jitterZ = (Math.random() - 0.5) * 0.9;
        const dir = [missile.direction[0] + jitterX, missile.direction[1] + jitterY, missile.direction[2] + jitterZ];
        const len = Math.hypot(dir[0], dir[1], dir[2]) || 1;
        missile.direction = [dir[0] / len, dir[1] / len, dir[2] / len];

        const session = this.sessionByUsername.get(owner);
        const client = session ? this.clients.getById(session) : undefined;
        client?.send('missile_lock_break', { id: missile.id });
      }
    }
  }

  public isPositionSmoked(pos: Vec3): boolean {
    const now = Date.now();
    for (let i = this.smokeZones.length - 1; i >= 0; i--) {
      const z = this.smokeZones[i];
      if (now >= z.expiresAt) {
        this.smokeZones.splice(i, 1);
        continue;
      }
      const dSq = (pos[0] - z.x) ** 2 + (pos[1] - z.y) ** 2 + (pos[2] - z.z) ** 2;
      if (dSq <= z.radius * z.radius) return true;
    }
    return false;
  }

  private stepMissiles(dt: number): void {
    for (const missile of this.missiles.values()) {
      // Homing guidance for aim9 (air/air) and agm114 (anti-armor)
      if (!missile.decoyed && (missile.weaponId === 'aim9' || missile.weaponId === 'agm114')) {
        let bestTarget: PlayerState | undefined;
        let bestDist = 75;

        // Maintain current target if valid, alive, and not inside smoke
        if (missile.trackedTarget) {
          const current = this.state.players.get(missile.trackedTarget);
          if (current && !current.is_dead && !this.isPositionSmoked([current.x, current.y, current.z])) {
            const d = Math.hypot(current.x - missile.position[0], current.y - missile.position[1], current.z - missile.position[2]);
            if (d < 85) {
              bestTarget = current;
              bestDist = d;
            }
          }
        }

        if (!bestTarget) {
          for (const candidate of this.state.players.values()) {
            if (candidate === missile.owner || candidate.is_dead || (this.isTeamMode() && candidate.team === missile.owner.team)) continue;
            if (this.isPositionSmoked([candidate.x, candidate.y, candidate.z])) continue;
            const toCand: Vec3 = [candidate.x - missile.position[0], candidate.y - missile.position[1], candidate.z - missile.position[2]];
            const dist = Math.hypot(toCand[0], toCand[1], toCand[2]);
            if (dist > bestDist || dist < 1.0) continue;
            const dot = (toCand[0] * missile.direction[0] + toCand[1] * missile.direction[1] + toCand[2] * missile.direction[2]) / dist;
            if (dot > 0.50) { // ~60 degree acquisition cone
              bestDist = dist;
              bestTarget = candidate;
            }
          }
        }

        if (bestTarget) {
          missile.trackedTarget = bestTarget.username;
          const toTarget: Vec3 = [bestTarget.x - missile.position[0], (bestTarget.y + 0.3) - missile.position[1], bestTarget.z - missile.position[2]];
          const dist = Math.hypot(toTarget[0], toTarget[1], toTarget[2]);
          if (dist > 0.5) {
            const targetDir: Vec3 = [toTarget[0] / dist, toTarget[1] / dist, toTarget[2] / dist];
            const turnRate = missile.weaponId === 'aim9' ? 4.2 : 2.8;
            const t = Math.min(1.0, turnRate * dt);
            const blended: Vec3 = [
              missile.direction[0] * (1 - t) + targetDir[0] * t,
              missile.direction[1] * (1 - t) + targetDir[1] * t,
              missile.direction[2] * (1 - t) + targetDir[2] * t,
            ];
            const blen = Math.hypot(blended[0], blended[1], blended[2]) || 1;
            missile.direction = [blended[0] / blen, blended[1] / blen, blended[2] / blen];

            // Inbound threat warning to human target
            if (!bestTarget.is_bot && bestDist < 65) {
              const session = this.sessionByUsername.get(bestTarget.username);
              const targetClient = session ? this.clients.getById(session) : undefined;
              targetClient?.send('missile_lock', {
                id: missile.id,
                distance: Math.round(bestDist),
                direction: [-targetDir[0], -targetDir[1], -targetDir[2]],
              });
            }
          }
        }
      }

      const distance = Math.min(missile.remaining, missile.speed * dt);
      const start = missile.position;
      const pointAt = (fraction: number): Vec3 => [
        start[0] + missile.direction[0] * distance * fraction,
        start[1] + missile.direction[1] * distance * fraction,
        start[2] + missile.direction[2] * distance * fraction,
      ];
      const end = pointAt(1);
      const wall = this.geometry.trace(start, end);
      const vehicle = this.vehicleSimulation.rayHit(start, end, missile.owner.username);
      let fraction = Math.min(wall?.fraction ?? Infinity, vehicle?.fraction ?? Infinity);
      let target: PlayerState | undefined;
      for (const candidate of this.state.players.values()) {
        if (candidate === missile.owner || candidate.is_dead) continue;
        const hit = traceDroneHit(start, end, [candidate.x, candidate.y, candidate.z]);
        if (hit && hit.fraction < fraction) {
          fraction = hit.fraction;
          target = candidate;
        }
      }
      missile.remaining -= distance;
      if (!Number.isFinite(fraction) && missile.remaining > 0) {
        missile.position = end;
        const velocity = missile.direction.map(component => component * missile.speed) as [number, number, number];
        this.moveProjectile(this.state.missile_projectiles.get(String(missile.id)), end, velocity);
        continue;
      }
      const position = pointAt(Math.min(1, fraction));
      this.missiles.delete(missile.id);
      this.retireProjectile(this.state.missile_projectiles, missile.id, position);
      this.broadcast('missile_impact', { id: missile.id, position });
      if (target && !this.isProtected(target) && !(this.isTeamMode() && target.team === missile.owner.team)) {
        const client = this.clients.getById(missile.sessionId);
        this.applyPlayerDamage(missile.owner, target, missile.damage, client, missile.direction);
      } else if (!target && vehicle && vehicle.fraction < (wall?.fraction ?? Infinity)) {
        this.applyVehicleDamage(missile.owner, vehicle.id, missile.weaponId, 0);
      }
    }
  }

  private resolveShot(client: Client, as: PlayerRuntime): void {
    const attacker = this.state.players.get(as.username);
    const fire = as.fireSegment;
    if (!attacker || !fire || attacker.is_dead) return;
    const seen = fire.seen;
    const endpoint: Vec3 = [fire.o[0] + fire.d[0] * fire.range, fire.o[1] + fire.d[1] * fire.range, fire.o[2] + fire.d[2] * fire.range];
    const vehicleHit = this.vehicleSimulation.rayHit(fire.o, endpoint, attacker.username);
    let first: { target: PlayerState; along: number; zone: DroneHit['zone'] } | undefined;
    for (const other of this.state.players.values()) {
      if (other.username === attacker.username || seen.value(other, 'health') <= 0) continue;
      const snapshot = (field: string): number => Number(seen.value(other, field as any));
      const position: Vec3 = [snapshot('x'), snapshot('y'), snapshot('z')];
      const hit = traceDroneHit(fire.o, endpoint, position);
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
    this.applyPlayerDamage(attacker, target, damageForZone(as.pendingWeaponId, along, zone), client, fire.d);
  }

  private reload(client: Client) {
    const internal = this.internal.get(client.sessionId), p = this.state.players.get(internal?.username ?? '');
    if (!p || !internal || p.is_dead) return;
    const w = getWeapon(p.weapon_id) ?? WEAPONS.ak47;
    if (p.ammo < w.magazine && p.reserve_ammo > 0 && Date.now() >= internal.reloadUntil) {
      internal.reloadUntil = Date.now() + w.reloadMs;
      const reloadingWeapon = p.weapon_id;
      const deadline = internal.reloadUntil;
      const token = ++internal.reloadToken;
      internal.reloadTimer = this.clock.setTimeout(() => {
        if (internal.reloadToken !== token || internal.reloadUntil !== deadline) return;
        internal.reloadTimer = undefined; internal.reloadUntil = 0;
        if (this.state.players.get(p.username) !== p || p.is_dead || p.weapon_id !== reloadingWeapon) return;
        const transferred = Math.min(w.magazine - p.ammo, p.reserve_ammo);
        p.ammo += transferred;
        p.reserve_ammo -= transferred;
        internal.ammoByWeapon[reloadingWeapon] = p.ammo;
        internal.reserveByWeapon[reloadingWeapon] = p.reserve_ammo;
      }, w.reloadMs);
    }
  }

  private sendOffhandAmmo(client: Client, runtime: PlayerRuntime, weapon: string, shotId: number) {
    client.send('payload_ammo', { weapon, ammo: runtime.ammoByWeapon[weapon], reserve_ammo: runtime.reserveByWeapon[weapon],
      last_shot_id: shotId, reloading: runtime.offhandReloads.has(weapon) });
  }

  private reloadOffhand(client: Client, weaponId: string) {
    const runtime = this.internal.get(client.sessionId), player = this.state.players.get(runtime?.username ?? '');
    const weapon = getWeapon(weaponId);
    if (!runtime || !player || !weapon || player.is_dead || player.driving_vehicle || weaponId === player.weapon_id
      || (weaponId !== player.primary_payload && weaponId !== player.secondary_payload)) return;
    if (!runtime.offhandReloads.has(weaponId) && runtime.ammoByWeapon[weaponId] < weapon.magazine && runtime.reserveByWeapon[weaponId] > 0) {
      const timer = this.clock.setTimeout(() => {
        if (runtime.offhandReloads.get(weaponId) !== timer) return;
        runtime.offhandReloads.delete(weaponId);
        const transferred = Math.min(weapon.magazine - runtime.ammoByWeapon[weaponId], runtime.reserveByWeapon[weaponId]);
        runtime.ammoByWeapon[weaponId] += transferred;
        runtime.reserveByWeapon[weaponId] -= transferred;
        const peer = this.clients.find(candidate => candidate.sessionId === client.sessionId);
        if (peer) this.sendOffhandAmmo(peer, runtime, weaponId, player.last_shot_id);
      }, weapon.reloadMs);
      runtime.offhandReloads.set(weaponId, timer);
    }
    this.sendOffhandAmmo(client, runtime, weaponId, player.last_shot_id);
  }

  private cancelReload(internal: PlayerRuntime): void {
    this.cancelActiveReload(internal);
    for (const timer of internal.offhandReloads.values()) timer.clear();
    internal.offhandReloads.clear();
  }

  private cancelActiveReload(internal: PlayerRuntime): void {
    internal.reloadToken++;
    internal.reloadTimer?.clear();
    internal.reloadTimer = undefined;
    internal.reloadUntil = 0;
  }

  private restockAmmo(player: PlayerState, runtime: PlayerRuntime): void {
    for (const [id, weapon] of Object.entries(WEAPONS)) {
      runtime.ammoByWeapon[id] = weapon.magazine;
      runtime.reserveByWeapon[id] = startingReserve(weapon);
    }
    const activeWeapon = getWeapon(player.weapon_id) ? player.weapon_id : 'ak47';
    player.ammo = runtime.ammoByWeapon[activeWeapon];
    player.reserve_ammo = runtime.reserveByWeapon[activeWeapon];
  }

  private respawn(sessionId: string, p: PlayerState, internal: PlayerRuntime) {
    const teamOffset = p.team === 'A' ? 0 : Math.floor(this.geometry.spawns.length / 2);
    const spawnIndex = (teamOffset + p.deaths) % this.geometry.spawns.length;
    const spawn = this.geometry.spawns[spawnIndex];
    p.x = spawn[0]; p.y = spawn[1] + DRONE_SPAWN_OFFSET; p.z = spawn[2];
    this.cancelReload(internal);
    p.health = maxHealthForChassis(p.mobility_mode); p.is_dead = false; p.vx = 0; p.vy = 0; p.vz = 0; p.animation_time = 0; p.pose_time_ms = Date.now(); p.animation = 'idle'; p.animation_code = 0; p.grenades = 2; internal.grenadeLastThrow = 0; internal.animationStartedAt = Date.now(); internal.protectedUntil = Date.now() + 2500;
    this.restockAmmo(p, internal);
    internal.spawnAt = 0;
    this.clients.find((client) => client.sessionId === sessionId)?.send('respawn', { x: p.x, y: p.y, z: p.z });
  }

  private requestRespawn(client: Client, raw?: any): void {
    const internal = this.internal.get(client.sessionId);
    const player = this.state.players.get(internal?.username ?? '');
    if (!player?.is_dead || !internal || Date.now() < internal.spawnAt) return;
    if (internal.manualRedeploy) {
      const { primary, secondary, throwable, chassis } = raw ?? {};
      if (typeof primary !== 'string' || typeof secondary !== 'string'
        || !getWeapon(primary) || !getWeapon(secondary) || primary === secondary
        || (throwable !== 'frag' && throwable !== 'impact')
        || !['quad', 'heli', 'wing', 'wheels', 'tracked'].includes(chassis)) return;
      player.primary_payload = primary;
      player.secondary_payload = secondary;
      player.throwable = throwable;
      player.mobility_mode = chassis === 'quad' ? 'heli' : chassis;
      player.weapon_id = primary;
    }
    this.respawn(client.sessionId, player, internal);
  }

  private vec(value: any): [number, number, number] | undefined {
    if (!Array.isArray(value) || value.length < 3) return;
    const out = [Number(value[0]), Number(value[1]), Number(value[2])];
    if (!out.every(Number.isFinite)) return;
    return [out[0], out[1], out[2]];
  }
}
