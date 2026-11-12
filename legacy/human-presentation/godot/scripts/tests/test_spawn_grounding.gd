extends Node3D
const Geometry := preload("res://scripts/net/ColyseusWorldGeometry.gd")
const Adapter := preload("res://scripts/net/ColyseusNetwork.gd")
class State extends RefCounted:
	var x := 28.0
	var y := 0.8621013333035128
	var z := 0.0
	var vx := 0.0
	var vy := 0.0
	var vz := 0.0
	var health := 100.0
class Context extends RefCounted:
	var dt := 1.0 / 60.0

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	GameState.practice_mode = false
	GameState.online_ready = true
	GameState.selected_map = "nuketown"
	var builder := preload("res://scripts/maps/MapBuilder.gd").new()
	add_child(builder)
	builder.build("nuketown")
	Geometry.set_map_override("nuketown")
	var player := preload("res://scenes/Player.tscn").instantiate() as WarPlayer
	add_child(player)
	player.colyseus_authoritative_sim = true
	var network := Adapter.new()
	var state := State.new()
	var context := Context.new()
	var command := {"move_x": 0.0, "move_z": 0.0, "yaw": 0.0, "jump": 0.0, "sprint": 0.0, "crouch": 0.0}
	for tick in 120:
		network._predict_server_step(context, state, command)
		player.global_position = Vector3(state.x, state.y, state.z)
		var floor_value: Variant = Geometry.floor_height(state.x, state.z, state.y + 0.1)
		var gap := state.y - float(floor_value)
		player.apply_authoritative_motion(Vector3(state.vx, state.vy, state.vz), gap >= -0.06 and gap <= 0.3 and absf(state.vy) <= 0.1, false, false)
		if tick < 3: await get_tree().physics_frame
	var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.1, player.global_position - Vector3.UP * 0.5, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var ok := not hit.is_empty() and absf(state.vy) < 0.001 and player.is_grounded
	var eye_height := player.camera.global_position.y - float(hit.position.y) if not hit.is_empty() else 0.0
	ok = ok and player.global_position.y >= float(hit.position.y) - 0.02 and eye_height >= 1.5
	print("SPAWN_GROUNDING_%s feet_y=%.4f eye_height=%.4f vy=%.4f grounded=%s" % ["OK" if ok else "FAILED", state.y, eye_height, state.vy, player.is_grounded])
	network.free()
	get_tree().quit(0 if ok else 1)
