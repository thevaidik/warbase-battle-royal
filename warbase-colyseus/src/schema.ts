import { ArraySchema, MapSchema, Schema, defineTypes } from '@colyseus/schema';

export class PlayerState extends Schema {
  x = 0; y = 1; z = 0; vx = 0; vy = 0; vz = 0;
  qx = 0; qy = 0; qz = 0; qw = 1;
  yaw = 0; pitch = 0;
  username = ''; animation = 'idle'; animation_code = 0; animation_time = 0; pose_time_ms = 0; weapon_id = 'ak47';
  health = 100; kills = 0; deaths = 0; team = 'A'; is_dead = false;
  ammo = 30; ack_input_sequence = 0;
  is_bot = false; driving_vehicle = ''; grenades = 2; throwable = 'frag';
}
defineTypes(PlayerState, {
  x: 'number', y: 'number', z: 'number', vx: 'number', vy: 'number', vz: 'number', qx: 'number', qy: 'number', qz: 'number', qw: 'number',
  yaw: 'number', pitch: 'number', username: 'string', animation: 'string', animation_code: 'number', animation_time: 'number', pose_time_ms: 'number', weapon_id: 'string', health: 'number',
  kills: 'number', deaths: 'number', team: 'string', is_dead: 'boolean', ammo: 'number', ack_input_sequence: 'number',
  is_bot: 'boolean', driving_vehicle: 'string', grenades: 'number', throwable: 'string',
});

export class VehicleState extends Schema {
  id = ''; pos = new ArraySchema<number>(0, 0, 0); yaw = 0; speed = 0; health = 1200; driver = ''; gear = 1;
}
defineTypes(VehicleState, { id: 'string', pos: ['number'], yaw: 'number', speed: 'number', health: 'number', driver: 'string', gear: 'number' });

export class BattleState extends Schema {
  players = new MapSchema<PlayerState>();
  protocol_version = 5; map_name = 'industrial'; time_of_day = 'noon';
  room_mode = 'TDM'; score_a = 0; score_b = 0; winner = '';
  vehicles = new MapSchema<VehicleState>();
}
defineTypes(BattleState, { players: { map: PlayerState }, protocol_version: 'number', map_name: 'string', time_of_day: 'string', room_mode: 'string', score_a: 'number', score_b: 'number', winner: 'string', vehicles: { map: VehicleState } });
