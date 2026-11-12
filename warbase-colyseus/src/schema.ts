import { MapSchema, Schema, defineTypes, schema, t } from '@colyseus/schema';

export const GAME_PROTOCOL_VERSION = 16;
export const PRESENTATION_VIEW_TAG = 1;
export const PRIVATE_VIEW_TAG = 2;

// Quaternion samples remain available to server rewind, but only the full join
// state sends them. Live rendering derives rotation from yaw.
export class PlayerState extends schema({
  x: t.float32().default(0),
  y: t.float32().default(1),
  z: t.float32().default(0),
  vx: t.float32().default(0),
  vy: t.float32().default(0),
  vz: t.float32().default(0),
  qx: t.float32().default(0).fullStateOnly(),
  qy: t.float32().default(0).fullStateOnly(),
  qz: t.float32().default(0).fullStateOnly(),
  qw: t.float32().default(1).fullStateOnly(),
  yaw: t.float32().default(0),
  pitch: t.float32().default(0),
  username: t.string().default(""),
  animation: t.string().default("idle").view(PRESENTATION_VIEW_TAG),
  animation_code: t.number().default(0).view(PRESENTATION_VIEW_TAG),
  animation_time: t.float32().default(0).view(PRESENTATION_VIEW_TAG),
  pose_time_ms: t.number().default(0),
  weapon_id: t.string().default("ak47").view(PRESENTATION_VIEW_TAG),
  health: t.number().default(100),
  kills: t.number().default(0),
  deaths: t.number().default(0),
  team: t.string().default("A"),
  is_dead: t.boolean().default(false),
  ammo: t.number().default(30).view(PRIVATE_VIEW_TAG),
  ack_input_sequence: t.number().default(0).view(PRIVATE_VIEW_TAG),
  is_bot: t.boolean().default(false),
  driving_vehicle: t.string().default(""),
  grenades: t.number().default(2).view(PRIVATE_VIEW_TAG),
  throwable: t.string().default("frag").view(PRIVATE_VIEW_TAG),
  vehicle_index: t.number().default(-1),
  vehicle_generation: t.number().default(0),
  mobility_mode: t.string().default("heli"),
  primary_payload: t.string().default("").view(PRESENTATION_VIEW_TAG),
  secondary_payload: t.string().default("").view(PRESENTATION_VIEW_TAG),
  reserve_ammo: t.number().default(90).view(PRIVATE_VIEW_TAG),
  last_shot_id: t.number().default(0).view(PRIVATE_VIEW_TAG),
}, 'PlayerStateBase') {}

export class VehicleState extends Schema {
  id = ''; pos = [0, 0, 0]; yaw = 0; speed = 0; health = 1200; driver = ''; gear = 1;
  x = 0; y = 0; z = 0; driver_generation = 0;
}
defineTypes(VehicleState, { id: 'string', yaw: 'float32', speed: 'float32', health: 'number', driver: 'string', gear: 'number', x: 'float32', y: 'float32', z: 'float32', driver_generation: 'number' });

export class ObjectiveState extends Schema {
  id = ''; x = 0; y = 0; z = 0; owner = ''; capturing_team = ''; progress = 0; contested = false; radius = 0;
}
defineTypes(ObjectiveState, { id: 'string', x: 'float32', y: 'float32', z: 'float32', owner: 'string', capturing_team: 'string', progress: 'float32', contested: 'boolean', radius: 'float32' });

export class ProjectileState extends schema({
  id: t.string(), owner: t.string(), kind: t.string(),
  request_id: t.number(),
  x: t.float32(), y: t.float32(), z: t.float32(),
  vx: t.float32(), vy: t.float32(), vz: t.float32(),
  active: t.number().default(1),
}, 'ProjectileStateBase') {}

export class BattleState extends Schema {
  players = new MapSchema<PlayerState>();
  protocol_version = GAME_PROTOCOL_VERSION; map_name = 'industrial'; time_of_day = 'noon';
  room_mode = 'TDM'; score_a = 0; score_b = 0; winner = '';
  vehicles = new MapSchema<VehicleState>();
  objectives = new MapSchema<ObjectiveState>();
  tickets_a = 500; tickets_b = 500; room_state = 'active';
  grenade_projectiles = new MapSchema<ProjectileState>();
  missile_projectiles = new MapSchema<ProjectileState>();
}
defineTypes(BattleState, { players: { map: PlayerState }, protocol_version: 'number', map_name: 'string', time_of_day: 'string', room_mode: 'string', score_a: 'number', score_b: 'number', winner: 'string', vehicles: { map: VehicleState }, objectives: { map: ObjectiveState }, tickets_a: 'number', tickets_b: 'number', room_state: 'string', grenade_projectiles: { map: ProjectileState }, missile_projectiles: { map: ProjectileState } });
