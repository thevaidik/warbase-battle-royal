class_name WarNetwork
extends Node
## Shared network API used by the game and the active Colyseus adapter.
## The retired Go/protobuf transport is intentionally not part of this base.

signal state_received(state: Dictionary)
signal fire_received(shooter: String, origin: Vector3, hit: Vector3, normal: Vector3, wall: bool)
signal hit_confirmed()
signal kill_confirmed()
signal grenade_received(shooter: String, pos: Vector3, vel: Vector3, grenade_id: int, kind: String, request_id: int)
signal grenade_rejected(request_id: int)
signal explosion_received(grenade_id: int, pos: Vector3, kind: String)
signal damage_received(target: String, pos: Vector3, direction: Vector3, amount: int)
signal respawn_received(pos: Vector3)
signal connection_changed(connected: bool)
signal connection_error(reason: String)

var connected := false
var current_ping := 0
var input_sequence := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func connect_to(_username: String, _room: String, _host: String) -> void:
	pass

func disconnect_from() -> void:
	_set_connected(false)

func _set_connected(value: bool) -> void:
	if connected == value: return
	connected = value
	connection_changed.emit(connected)

func _valid(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func send_state(_pos: Vector3, _quat: Quaternion, _anim: String, _weapon: String) -> void:
	pass

func send_aim_pitch(_value: float) -> void:
	pass

func send_fire(_origin: Vector3, _hit: Vector3, _normal: Vector3, _wall: bool, _shot_id: int = 0, _yaw: float = 0.0, _pitch: float = 0.0) -> void:
	pass

func send_fire_with_aim(origin: Vector3, hit: Vector3, normal: Vector3, wall: bool, shot_id: int, yaw: float, pitch: float) -> void:
	send_fire(origin, hit, normal, wall, shot_id, yaw, pitch)

func send_hit(_target: String, _damage: int, _shot_id: int = 0, _view_time_ms: int = 0) -> void:
	pass

func send_reload() -> void:
	pass

func send_switch(_weapon_id: String) -> void:
	pass

func send_loadout(_primary: String, _secondary: String, _throwable: String) -> void:
	pass

func send_respawn() -> void:
	pass

func send_grenade(_pos: Vector3, _velocity: Vector3, _kind: String = "frag") -> int:
	return 0

func send_vehicle_seat(_id: String, _enter: bool) -> void:
	pass

func send_vehicle_input(_throttle: float, _steer: float, _brake: bool, _gear: int) -> void:
	pass

func send_ping_now() -> void:
	pass
