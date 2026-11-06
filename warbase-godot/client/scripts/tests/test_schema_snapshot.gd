extends Node
const Types := preload("res://scripts/net/ColyseusSchema.gd")
class NestedState extends Colyseus.Schema:
	static func definition() -> Array:
		return [Colyseus.Schema.Field.new("pos", Colyseus.Schema.ARRAY, Colyseus.Schema.NUMBER)]
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("CHECK FAIL " + message)

func old_snapshot(value: Variant) -> Variant:
	if value is Colyseus.Schema: return old_snapshot(value.to_dictionary())
	if value is Dictionary:
		var out := {}
		for key in value: out[key] = old_snapshot(value[key])
		return out
	if value is Array:
		var out := []
		for item in value: out.append(old_snapshot(item))
		return out
	return value

func _ready() -> void:
	for schema_type in [Types.PlayerState, Types.VehicleState, Types.ObjectiveState, Types.RoomState]:
		check(is_same(schema_type.definition(), schema_type.definition()), "schema field metadata is shared per class")
		check(schema_type.definition().is_read_only(), "shared field metadata is immutable")
	for schema_type in [Types.PlayerState, Types.ObjectiveState]:
		for field in schema_type.definition():
			check(field.type not in [Colyseus.Schema.REF, Colyseus.Schema.MAP, Colyseus.Schema.ARRAY], "fast-path schema must stay flat")
	var players: Array = []
	for index in 64:
		var player = Types.PlayerState.new()
		player.set("username", "Snapshot_%d" % index)
		player.set("x", -103.123456789 + index)
		player.set("health", 73.25)
		player.set("is_dead", index % 2 == 0)
		players.append(player)
		check(Types.to_dictionary(player) == old_snapshot(player), "all player fields remain equal")
	var snapshot: Dictionary = Types.to_dictionary(players[0])
	players[0].set("x", 99.0)
	check(snapshot.x != 99.0, "decoded mutation cannot change emitted snapshot")
	snapshot.health = 4.0
	check(players[0].get("health") == 73.25, "consumer mutation cannot change authoritative schema")
	var vehicle = NestedState.new()
	var raw_pos := [1.25, 2.5, -3.75]
	vehicle.set("pos", raw_pos)
	var nested := {"players": {"one": players[0]}, "vehicles": {"car": vehicle}}
	var copied: Dictionary = Types.to_dictionary(nested)
	check(copied == old_snapshot(nested), "nested room and vehicle conversions remain equal")
	raw_pos[0] = 42.0
	check(copied.vehicles.car.pos[0] == 1.25, "vehicle arrays remain isolated")
	var objective = Types.ObjectiveState.new()
	objective.set("progress", 0.327)
	check(Types.to_dictionary(objective) == old_snapshot(objective), "objective fields remain equal")
	var old_us: Array[int] = []
	var new_us: Array[int] = []
	for round_index in 5:
		var start := Time.get_ticks_usec()
		for repeat in 100:
			for player in players: old_snapshot(player)
		old_us.append(Time.get_ticks_usec() - start)
		start = Time.get_ticks_usec()
		for repeat in 100:
			for player in players: Types.to_dictionary(player)
		new_us.append(Time.get_ticks_usec() - start)
	old_us.sort(); new_us.sort()
	print("SCHEMA_SNAPSHOT parity=64 isolation=true old_median_us=%d new_median_us=%d failures=%d" % [old_us[2], new_us[2], failures])
	get_tree().quit(1 if failures else 0)
