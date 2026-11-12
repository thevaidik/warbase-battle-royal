extends SceneTree

const Geometry = preload("res://scripts/net/ColyseusWorldGeometry.gd")
const DroneFlight = preload("res://scripts/drones/DroneFlight.gd")
const POSITION_TOLERANCE := 0.03
const VELOCITY_TOLERANCE := 0.06

var failures := 0
var comparisons := 0
var max_position_error := 0.0
var max_velocity_error := 0.0

func _initialize() -> void:
	call_deferred("run")

func _fixture_path() -> String:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()):
		var arg := String(args[index])
		if arg.begins_with("fixtures="): return arg.trim_prefix("fixtures=")
		if arg.begins_with("--fixtures="): return arg.trim_prefix("--fixtures=")
		if arg == "--fixtures" and index + 1 < args.size(): return String(args[index + 1])
	return "/tmp/drone-flight-fixtures.json"

func _vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

func _record_failure(message: String) -> void:
	failures += 1
	if failures <= 12: push_error(message)

func run() -> void:
	var path := _fixture_path()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_record_failure("Could not open TypeScript drone fixture: %s" % path)
		print("DRONE_PREDICTION_PARITY failures=", failures)
		quit(1)
		return
	var fixture: Variant = JSON.parse_string(file.get_as_text())
	if not fixture is Dictionary or not fixture.get("maps", []) is Array or not fixture.get("commands", []) is Array:
		_record_failure("Invalid TypeScript drone fixture: %s" % path)
		print("DRONE_PREDICTION_PARITY failures=", failures)
		quit(1)
		return
	var dt := 1.0 / float(fixture.get("tick_rate", 60))
	var steps := int(fixture.get("steps", 0))
	var commands: Array = fixture.commands
	if steps != commands.size(): _record_failure("Fixture step count does not match command count")
	for map_data: Variant in fixture.maps:
		var map_name := String(map_data.get("map", ""))
		Geometry.set_map_override(map_name)
		var authored: Array[Vector3] = Geometry.get_authored_spawns()
		if authored.size() != 12 or not map_data.get("spawns", []) is Array or map_data.spawns.size() != 12:
			_record_failure("%s: expected twelve native and fixture spawns; native=%d fixture=%d" % [map_name, authored.size(), map_data.get("spawns", []).size()])
			continue
		for spawn_data: Variant in map_data.spawns:
			var spawn_index := int(spawn_data.get("spawn_index", -1))
			if spawn_index < 0 or spawn_index >= authored.size():
				_record_failure("%s: invalid spawn index %d" % [map_name, spawn_index])
				continue
			var expected_start := _vector(spawn_data.start)
			var native_start := authored[spawn_index] + Vector3.UP * DroneFlight.SPAWN_OFFSET
			if native_start.distance_to(expected_start) > 0.00001:
				_record_failure("%s spawn %d: start differs; native=%s fixture=%s" % [map_name, spawn_index, str(native_start), str(expected_start)])
			# Start from the fixture once; checkpoints never reseed this running trajectory.
			var position := expected_start
			var velocity := Vector3.ZERO
			var checkpoint_by_tick: Dictionary = {}
			for checkpoint: Variant in spawn_data.get("checkpoints", []): checkpoint_by_tick[int(checkpoint.tick)] = checkpoint
			for tick in range(1, steps + 1):
				var result: Dictionary = DroneFlight.step(position, velocity, commands[tick - 1], dt)
				position = result.position
				velocity = result.velocity
				if not checkpoint_by_tick.has(tick): continue
				var expected: Dictionary = checkpoint_by_tick[tick]
				var position_error := position.distance_to(_vector(expected.position))
				var velocity_error := velocity.distance_to(_vector(expected.velocity))
				comparisons += 1
				max_position_error = maxf(max_position_error, position_error)
				max_velocity_error = maxf(max_velocity_error, velocity_error)
				if position_error > POSITION_TOLERANCE or velocity_error > VELOCITY_TOLERANCE:
					_record_failure("%s spawn %d tick %d: position_error=%.6f velocity_error=%.6f native=%s/%s server=%s/%s" % [map_name, spawn_index, tick, position_error, velocity_error, str(position), str(velocity), str(_vector(expected.position)), str(_vector(expected.velocity))])
	Geometry.set_map_override("")
	print("DRONE_PREDICTION_PARITY comparisons=%d max_position_error=%.6f max_velocity_error=%.6f failures=%d" % [comparisons, max_position_error, max_velocity_error, failures])
	quit(1 if failures else 0)
