class_name WBColyseusSchema
extends RefCounted

class PlayerState extends Colyseus.Schema:
	static func definition() -> Array:
		return [
		Colyseus.Schema.Field.new("x", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("y", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("z", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("vx", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("vy", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("vz", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("qx", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("qy", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("qz", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("qw", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("yaw", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("pitch", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("username", Colyseus.Schema.STRING),
		Colyseus.Schema.Field.new("animation", Colyseus.Schema.STRING),
		Colyseus.Schema.Field.new("animation_code", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("animation_time", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("pose_time_ms", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("weapon_id", Colyseus.Schema.STRING),
		Colyseus.Schema.Field.new("health", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("kills", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("deaths", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("team", Colyseus.Schema.STRING),
		Colyseus.Schema.Field.new("is_dead", Colyseus.Schema.BOOLEAN),
		Colyseus.Schema.Field.new("ammo", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("ack_input_sequence", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("is_bot", Colyseus.Schema.BOOLEAN),
		Colyseus.Schema.Field.new("driving_vehicle", Colyseus.Schema.STRING),
		Colyseus.Schema.Field.new("grenades", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("throwable", Colyseus.Schema.STRING),
	]

class VehicleState extends Colyseus.Schema:
	static func definition() -> Array:
		return [
		Colyseus.Schema.Field.new("id", Colyseus.Schema.STRING),
		Colyseus.Schema.Field.new("pos", Colyseus.Schema.ARRAY, Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("yaw", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("speed", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("health", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("driver", Colyseus.Schema.STRING),
		Colyseus.Schema.Field.new("gear", Colyseus.Schema.NUMBER),
	]

class RoomState extends Colyseus.Schema:
	static func definition() -> Array:
		return [
		Colyseus.Schema.Field.new("players", Colyseus.Schema.MAP, PlayerState),
		Colyseus.Schema.Field.new("protocol_version", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("map_name", Colyseus.Schema.STRING),
		Colyseus.Schema.Field.new("time_of_day", Colyseus.Schema.STRING),
		Colyseus.Schema.Field.new("room_mode", Colyseus.Schema.STRING),
		Colyseus.Schema.Field.new("score_a", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("score_b", Colyseus.Schema.NUMBER),
		Colyseus.Schema.Field.new("winner", Colyseus.Schema.STRING),
		Colyseus.Schema.Field.new("vehicles", Colyseus.Schema.MAP, VehicleState),
	]

static func to_dictionary(value: Variant) -> Variant:
	if value is Colyseus.Schema:
		return to_dictionary(value.to_dictionary())
	if value is Dictionary:
		var out := {}
		for key in value:
			out[key] = to_dictionary(value[key])
		return out
	if value is Array:
		var out := []
		for item in value:
			out.append(to_dictionary(item))
		return out
	return value
