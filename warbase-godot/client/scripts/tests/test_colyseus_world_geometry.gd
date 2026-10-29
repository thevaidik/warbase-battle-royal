extends SceneTree

const GEOMETRY = preload("res://scripts/net/ColyseusWorldGeometry.gd")
const FIXTURES_PATH = "res://assets/data/geometry-fixtures.json"
const MAP_FIXTURES_PATH = "res://assets/data/maps/map-fixtures.json"

func _init() -> void:
	var fixture_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES_PATH))
	if not fixture_data is Dictionary:
		push_error("Invalid shared geometry fixture file")
		quit(1)
		return
	var map_fixtures: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP_FIXTURES_PATH))
	if not map_fixtures is Array or map_fixtures.size() != 10:
		push_error("Invalid all-map geometry fixture file")
		quit(1)
	var failures := 0
	var spawns := GEOMETRY.get_authored_spawns()
	if spawns.size() != 12:
		push_error("Expected 12 authored Industrial spawns; got %d" % spawns.size())
		failures += 1
	for ray in fixture_data.get("rays", []):
		var from := Vector3(ray["from"][0], ray["from"][1], ray["from"][2])
		var to := Vector3(ray["to"][0], ray["to"][1], ray["to"][2])
		var actual: bool = GEOMETRY.ray_blocked(from, to)
		if actual != (ray["blocked"] == true):
			push_error("Ray parity fixture failed: %s" % ray["name"])
			failures += 1
	for move in fixture_data.get("moves", []):
		var from := Vector3(move["from"][0], move["from"][1], move["from"][2])
		var to := Vector3(move["to"][0], move["to"][1], move["to"][2])
		var expected := Vector3(move["expected"][0], move["expected"][1], move["expected"][2])
		var actual: Vector3 = GEOMETRY.resolve_move(from, to)
		if actual.distance_to(expected) >= 0.001:
			push_error("Movement parity fixture failed: %s actual=%s expected=%s" % [move["name"], actual, expected])
			failures += 1
	var all_map_rays := 0
	var all_map_moves := 0
	for fixture in map_fixtures:
		GEOMETRY.set_map_override(String(fixture["map"]))
		var map_spawns := GEOMETRY.get_authored_spawns()
		if map_spawns.size() != int(fixture["spawns"]):
			push_error("Authored spawn count mismatch for %s" % fixture["map"])
			failures += 1
			continue
		var spawn: Vector3 = map_spawns[0]
		var ground: Variant = GEOMETRY.floor_height(spawn.x, spawn.z, spawn.y + 2.0)
		if ground == null or not is_finite(float(ground)):
			push_error("No walkable authored ground at %s spawn for %s" % [spawn, fixture["map"]])
			failures += 1
		var ray: Dictionary = fixture["ray"]
		var ray_from := Vector3(ray["from"][0], ray["from"][1], ray["from"][2])
		var ray_to := Vector3(ray["to"][0], ray["to"][1], ray["to"][2])
		if GEOMETRY.ray_blocked(ray_from, ray_to) != bool(ray["blocked"]):
			push_error("Ray parity fixture failed for map %s" % fixture["map"])
			failures += 1
		all_map_rays += 1
		var move: Dictionary = fixture["move"]
		var move_from := Vector3(move["from"][0], move["from"][1], move["from"][2])
		var move_to := Vector3(move["to"][0], move["to"][1], move["to"][2])
		var expected_move := Vector3(move["expected"][0], move["expected"][1], move["expected"][2])
		var actual_move: Vector3 = GEOMETRY.resolve_move(move_from, move_to)
		if actual_move.distance_to(expected_move) >= 0.001:
			push_error("Movement parity fixture failed for map %s actual=%s expected=%s" % [fixture["map"], actual_move, expected_move])
			failures += 1
		all_map_moves += 1
	GEOMETRY.set_map_override()
	if failures == 0:
		print("GEOMETRY_PARITY_OK maps=%d spawns=%d rays=%d moves=%d" % [map_fixtures.size(), spawns.size(), fixture_data["rays"].size() + all_map_rays, fixture_data["moves"].size() + all_map_moves])
	quit(1 if failures > 0 else 0)
