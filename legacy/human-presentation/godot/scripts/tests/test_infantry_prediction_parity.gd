extends SceneTree

const Geometry = preload("res://scripts/net/ColyseusWorldGeometry.gd")
const POSITION_TOLERANCE := 0.03
const VERTICAL_VELOCITY_TOLERANCE := 0.001

var failures := 0
var comparisons := 0
var printed_failures := 0
var print_all_failures := false
var max_position_error := 0.0
var max_vertical_velocity_error := 0.0

func _initialize() -> void:
	call_deferred("run")

func _fixture_path() -> String:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()):
		var arg := String(args[index])
		if arg.begins_with("fixtures="): return arg.trim_prefix("fixtures=")
		if arg.begins_with("--fixtures="): return arg.trim_prefix("--fixtures=")
		if arg == "--fixtures" and index + 1 < args.size(): return String(args[index + 1])
	return "/tmp/infantry-parity.json"

func _vec3(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

func _step(position: Vector3, vy: float, tick: int, dt: float, speed: float, gravity: float, jump_speed: float) -> Dictionary:
	if tick == 30 and absf(vy) < 0.001 and Geometry.is_grounded(position):
		vy = jump_speed
	vy -= gravity * dt
	var move_x := 1.0 if tick < 60 else 0.0
	var move_z := 0.0 if tick < 60 else 1.0
	var from := position
	var requested := from + Vector3(move_x * speed, vy, -move_z * speed) * dt
	position = Geometry.resolve_move(from, requested)
	if vy < 0.0 and Geometry.is_grounded(position):
		vy = 0.0
	elif vy > 0.0 and position.y < requested.y - 0.001:
		vy = 0.0
	return {"position": position, "vy": vy}

func _record_failure(message: String) -> void:
	failures += 1
	if print_all_failures or printed_failures < 10:
		push_error(message)
		printed_failures += 1

func run() -> void:
	print_all_failures = OS.get_cmdline_user_args().has("all-failures")
	var path := _fixture_path()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open TypeScript infantry fixture: %s" % path)
		quit(1)
		return
	var fixture: Variant = JSON.parse_string(file.get_as_text())
	if not fixture is Dictionary or not fixture.get("maps", []) is Array:
		push_error("Invalid TypeScript infantry fixture: %s" % path)
		quit(1)
		return
	var dt := 1.0 / float(fixture.tick_rate)
	var steps := int(fixture.steps)
	for map_data: Variant in fixture.maps:
		var map_name := String(map_data.map)
		Geometry.set_map_override(map_name)
		var native_spawns: Array[Vector3] = Geometry.get_authored_spawns()
		if native_spawns.size() != 12 or map_data.spawns.size() != 12:
			_record_failure("%s: expected 12 spawns; native=%d fixture=%d" % [map_name, native_spawns.size(), map_data.spawns.size()])
			continue
		for spawn_data: Variant in map_data.spawns:
			var spawn_index := int(spawn_data.spawn_index)
			if spawn_index < 0 or spawn_index >= native_spawns.size():
				_record_failure("%s: invalid spawn index %d" % [map_name, spawn_index])
				continue
			var position: Vector3 = native_spawns[spawn_index]
			var start: Vector3 = _vec3(spawn_data.start)
			if position.distance_to(start) > 0.00001:
				_record_failure("%s spawn %d: authored start differs from TypeScript fixture; native=%s fixture=%s" % [map_name, spawn_index, position, start])
				continue
			var vy := 0.0
			var checkpoint_index := 0
			for tick in range(1, steps + 1):
				var result := _step(position, vy, tick - 1, dt, float(fixture.walk_speed), float(fixture.gravity), float(fixture.jump_speed))
				position = result.position
				vy = float(result.vy)
				if tick % 20 != 0 and tick != steps: continue
				if checkpoint_index >= spawn_data.checkpoints.size():
					_record_failure("%s spawn %d tick %d: missing TypeScript checkpoint" % [map_name, spawn_index, tick])
					continue
				var expected: Variant = spawn_data.checkpoints[checkpoint_index]
				checkpoint_index += 1
				if int(expected.tick) != tick:
					_record_failure("%s spawn %d: expected checkpoint tick %d, got %d" % [map_name, spawn_index, expected.tick, tick])
					continue
				var expected_position := _vec3(expected.position)
				var position_error := position.distance_to(expected_position)
				var velocity_error := absf(vy - float(expected.vy))
				max_position_error = maxf(max_position_error, position_error)
				max_vertical_velocity_error = maxf(max_vertical_velocity_error, velocity_error)
				comparisons += 1
				if position_error > POSITION_TOLERANCE or velocity_error > VERTICAL_VELOCITY_TOLERANCE:
					_record_failure("%s spawn %d start=%s tick %d: position error %.6f (native=%s fixture=%s), vy error %.6f (native=%.6f fixture=%.6f)" % [map_name, spawn_index, start, tick, position_error, position, expected_position, velocity_error, vy, float(expected.vy)])
			if checkpoint_index != spawn_data.checkpoints.size():
				_record_failure("%s spawn %d: consumed %d of %d checkpoints" % [map_name, spawn_index, checkpoint_index, spawn_data.checkpoints.size()])
	Geometry.set_map_override()
	print("INFANTRY_PREDICTION_PARITY: %d failures; comparisons=%d max_position_error=%.6f max_vertical_velocity_error=%.6f" % [failures, comparisons, max_position_error, max_vertical_velocity_error])
	quit(1 if failures > 0 else 0)
