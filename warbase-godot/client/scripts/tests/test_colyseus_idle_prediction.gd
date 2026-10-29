extends Node

const NetworkScript := preload("res://scripts/net/ColyseusNetwork.gd")
const Geometry := preload("res://scripts/net/ColyseusWorldGeometry.gd")
const MAP_FIXTURES_PATH := "res://assets/data/maps/map-fixtures.json"
const MAPS: Array[String] = ["football", "resoforge", "industrial", "village", "arena", "shipment", "dust2", "nuketown", "canyon", "desert_oasis"]
const DT := 1.0 / 60.0

class StepContext extends RefCounted:
	var dt := 1.0 / 60.0

class StepState extends RefCounted:
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var vx := 0.0
	var vy := 0.0
	var vz := 0.0
	var health := 100.0

class StepCommand extends RefCounted:
	var move_x := 0.0
	var move_z := 0.0
	var yaw := 0.0
	var pitch := 0.0
	var jump := 0.0
	var sprint := 0.0
	var crouch := 0.0

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var network = NetworkScript.new()
	var context := StepContext.new()
	var command := StepCommand.new()
	var failures := 0
	var baseline_total_usec := 0
	for map_name in MAPS:
		Geometry.set_map_override(map_name)
		var spawns := Geometry.get_authored_spawns()
		if spawns.is_empty():
			push_error("No test spawn for " + map_name)
			failures += 1
			continue
		var spawn: Vector3 = spawns[0]
		var floor_value: Variant = Geometry.floor_height(spawn.x, spawn.z, spawn.y + 0.1)
		if floor_value == null:
			push_error("No test floor for " + map_name)
			failures += 1
			continue
		var start_usec := Time.get_ticks_usec()
		var expected := _server_idle_step(Vector3(spawn.x, float(floor_value), spawn.z), DT)
		baseline_total_usec += Time.get_ticks_usec() - start_usec
		var state := _new_state(expected.position)
		state.vy = 0.0
		network._predict_server_step(context, state, command)
		var actual_position := Vector3(state.x, state.y, state.z)
		if actual_position.distance_to(expected.position) > 0.0001 or absf(state.vx) > 0.0001 or absf(state.vy) > 0.0001 or absf(state.vz) > 0.0001:
			push_error("Idle prediction differs from authoritative step for %s: got %s velocity=(%s,%s,%s) expected=%s" % [map_name, actual_position, state.vx, state.vy, state.vz, expected.position])
			failures += 1
		for offset_value in [-0.02, 0.0, 0.02]:
			var offset := float(offset_value)
			for incoming_velocity in [0.0, -0.2, -1.0]:
				var incoming_vy := float(incoming_velocity)
				var varied_start: Vector3 = expected.position + Vector3.UP * offset
				var varied_state := _new_state(varied_start)
				varied_state.vy = incoming_vy
				var varied_expected_with_velocity := _server_idle_step_with_velocity(varied_start, incoming_vy, DT)
				network._predict_server_step(context, varied_state, command)
				var varied_actual := Vector3(varied_state.x, varied_state.y, varied_state.z)
				if varied_actual.distance_to(varied_expected_with_velocity.position) > 0.0001 or absf(varied_state.vy - varied_expected_with_velocity.vy) > 0.0001:
					push_error("Idle prediction differs at %s offset=%0.2f vy=%0.1f: got %s/vy=%0.4f expected=%s/vy=%0.4f" % [map_name, offset, incoming_vy, varied_actual, varied_state.vy, varied_expected_with_velocity.position, varied_expected_with_velocity.vy])
					failures += 1
		var move_command := StepCommand.new()
		move_command.move_x = 0.6
		move_command.move_z = -0.4
		move_command.yaw = 0.37
		var grounded_start := Vector3(spawn.x, float(floor_value), spawn.z)
		var movement_expected := _server_step(grounded_start, 0.0, move_command, DT)
		var movement_state := _new_state(grounded_start)
		network._predict_server_step(context, movement_state, move_command)
		if not _state_matches(movement_state, movement_expected):
			push_error("Analog movement diverged from server step for " + map_name)
			failures += 1
		var jump_command := StepCommand.new()
		jump_command.jump = 1.0
		var jump_expected := _server_step(grounded_start, 0.0, jump_command, DT)
		var jump_state := _new_state(grounded_start)
		network._predict_server_step(context, jump_state, jump_command)
		if not _state_matches(jump_state, jump_expected):
			push_error("Jump prediction diverged from server step for " + map_name)
			failures += 1

	Geometry.set_map_override("industrial")
	var benchmark_spawn: Vector3 = Geometry.get_authored_spawns()[0]
	var benchmark_floor: float = float(Geometry.floor_height(benchmark_spawn.x, benchmark_spawn.z, benchmark_spawn.y + 0.1))
	var benchmark_state := _new_state(Vector3(benchmark_spawn.x, benchmark_floor, benchmark_spawn.z))
	var start_benchmark_usec := Time.get_ticks_usec()
	for _step in 60:
		network._predict_server_step(context, benchmark_state, command)
	var optimized_total_usec := Time.get_ticks_usec() - start_benchmark_usec
	var optimized_mean_usec := float(optimized_total_usec) / 60.0
	var moving_state := _new_state(Vector3(benchmark_spawn.x, benchmark_floor, benchmark_spawn.z))
	var gated_moving_state := _new_state(Vector3(benchmark_spawn.x, benchmark_floor, benchmark_spawn.z))
	command.move_z = -1.0
	var old_movement_total_usec := 0
	var gated_movement_total_usec := 0
	for _moving_step in 60:
		var old_step_start := Time.get_ticks_usec()
		Geometry.floor_height(moving_state.x, moving_state.z, moving_state.y + 0.1)
		network._predict_server_step(context, moving_state, command)
		old_movement_total_usec += Time.get_ticks_usec() - old_step_start
		var gated_step_start := Time.get_ticks_usec()
		network._predict_server_step(context, gated_moving_state, command)
		gated_movement_total_usec += Time.get_ticks_usec() - gated_step_start
		if not _state_matches(moving_state, {"position": Vector3(gated_moving_state.x, gated_moving_state.y, gated_moving_state.z), "vx": gated_moving_state.vx, "vy": gated_moving_state.vy, "vz": gated_moving_state.vz}):
			push_error("Movement changed when skipping the redundant starting floor query at input %d" % _moving_step)
			failures += 1
	var old_movement_mean_usec := float(old_movement_total_usec) / 60.0
	var gated_movement_mean_usec := float(gated_movement_total_usec) / 60.0
	command.move_z = 0.0
	var open_from := Vector3(benchmark_spawn.x, benchmark_floor, benchmark_spawn.z)
	var open_to := open_from + Vector3(0.1, 0.0, 0.0)
	var open_start_usec := Time.get_ticks_usec()
	for _open_sweep in 10:
		Geometry.resolve_move(open_from, open_to)
	var open_sweep_mean_usec := float(Time.get_ticks_usec() - open_start_usec) / 10.0
	Geometry.set_map_override("arena")
	var wall_from := Vector3(-26.0, 1.1, -3.0)
	var wall_to := Vector3(-25.6, 1.1, -3.0)
	var wall_start_usec := Time.get_ticks_usec()
	for _wall_sweep in 10:
		Geometry.resolve_move(wall_from, wall_to)
	var wall_sweep_mean_usec := float(Time.get_ticks_usec() - wall_start_usec) / 10.0
	var map_fixtures: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP_FIXTURES_PATH))
	var reference_total_usec := 0
	var cached_total_usec := 0
	var cached_comparisons := 0
	for fixture in map_fixtures:
		Geometry.set_map_override(String(fixture["map"]))
		var move: Dictionary = fixture["move"]
		var move_from := Vector3(move["from"][0], move["from"][1], move["from"][2])
		var move_to := Vector3(move["to"][0], move["to"][1], move["to"][2])
		for _repeat in 8:
			var reference_start := Time.get_ticks_usec()
			var reference_position: Vector3 = Geometry.resolve_move(move_from, move_to, 0.4, 1.8, false)
			reference_total_usec += Time.get_ticks_usec() - reference_start
			var cached_start := Time.get_ticks_usec()
			var cached_position: Vector3 = Geometry.resolve_move(move_from, move_to)
			cached_total_usec += Time.get_ticks_usec() - cached_start
			if reference_position.distance_to(cached_position) > 0.0000001:
				push_error("Candidate cache changed fixture move on %s: reference=%s cached=%s" % [fixture["map"], reference_position, cached_position])
				failures += 1
			cached_comparisons += 1
	var reference_move_mean_usec := float(reference_total_usec) / maxf(float(cached_comparisons), 1.0)
	var cached_move_mean_usec := float(cached_total_usec) / maxf(float(cached_comparisons), 1.0)
	var result_label := "OK" if failures == 0 else "FAILED"
	print("COLYSEUS_IDLE_PREDICTION_%s maps=%d reference_mean_us=%0.1f idle_60_total_ms=%0.3f idle_60_mean_us=%0.1f moving_with_old_floor_query_mean_us=%0.1f moving_gated_mean_us=%0.1f open_sweep_mean_us=%0.1f near_wall_sweep_mean_us=%0.1f move_bvh_reference_mean_us=%0.1f move_candidates_mean_us=%0.1f candidate_comparisons=%d failures=%d" % [result_label, MAPS.size(), float(baseline_total_usec) / MAPS.size(), float(optimized_total_usec) / 1000.0, optimized_mean_usec, old_movement_mean_usec, gated_movement_mean_usec, open_sweep_mean_usec, wall_sweep_mean_usec, reference_move_mean_usec, cached_move_mean_usec, cached_comparisons, failures])
	Geometry.set_map_override()
	get_tree().quit(1 if failures > 0 else 0)

func _server_idle_step(position: Vector3, dt: float) -> Dictionary:
	return _server_idle_step_with_velocity(position, 0.0, dt)

func _server_idle_step_with_velocity(position: Vector3, incoming_vy: float, dt: float) -> Dictionary:
	var command := StepCommand.new()
	return _server_step(position, incoming_vy, command, dt)

func _server_step(position: Vector3, incoming_vy: float, command: StepCommand, dt: float, use_candidate_cache: bool = false) -> Dictionary:
	var move_x := clampf(command.move_x, -1.0, 1.0)
	var move_z := clampf(command.move_z, -1.0, 1.0)
	var magnitude := maxf(sqrt(move_x * move_x + move_z * move_z), 1.0)
	var speed := 8.8 if command.sprint > 0.5 else (2.5 if command.crouch > 0.5 else 6.2)
	var yaw := command.yaw
	var vx := (move_x * cos(yaw) - move_z * sin(yaw)) / magnitude * speed
	var vz := (-move_x * sin(yaw) - move_z * cos(yaw)) / magnitude * speed
	var vy := incoming_vy - 18.0 * dt
	var jump_floor: Variant = Geometry.floor_height(position.x, position.z, position.y + 0.1)
	var grounded_height := position.y if jump_floor == null else float(jump_floor)
	if command.jump > 0.5 and absf(incoming_vy) < 0.001 and position.y <= grounded_height + 0.03:
		vy = 6.2 - 18.0 * dt
	var requested := position + Vector3(vx, vy, vz) * dt
	var resolved: Vector3 = Geometry.resolve_move(position, requested, 0.4, 1.8, use_candidate_cache)
	vx = (resolved.x - position.x) / dt
	vz = (resolved.z - position.z) / dt
	var ground: Variant = Geometry.floor_height(resolved.x, resolved.z, resolved.y + 0.1)
	if ground != null and resolved.y <= float(ground) + 0.03 and vy < 0.0:
		vy = 0.0
	return {"position": resolved, "vx": vx, "vy": vy, "vz": vz}

func _state_matches(state: StepState, expected: Dictionary) -> bool:
	var position := Vector3(state.x, state.y, state.z)
	return position.distance_to(expected.position) <= 0.0001 and absf(state.vx - expected.vx) <= 0.0001 and absf(state.vy - expected.vy) <= 0.0001 and absf(state.vz - expected.vz) <= 0.0001

func _new_state(position: Vector3) -> StepState:
	var state := StepState.new()
	state.x = position.x
	state.y = position.y
	state.z = position.z
	return state
