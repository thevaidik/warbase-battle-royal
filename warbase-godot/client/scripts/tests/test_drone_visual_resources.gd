extends Node

const DroneVisualScript = preload("res://scripts/drones/DroneVisual.gd")
const DroneVisualResourcesScript = preload("res://scripts/drones/DroneVisualResources.gd")

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	DroneVisualResourcesScript.clear_cache()

	# Test 1: Cold spawn performs initial SurfaceTool merge
	var drone1 = DroneVisualScript.new()
	add_child(drone1)
	drone1.configure(true, "ak47", "heli")
	await get_tree().process_frame

	var stats1 := DroneVisualResourcesScript.get_stats()
	_check(int(stats1.cached_mesh_variants) > 0, "cold spawn populates mesh variant cache")
	var initial_merges := int(stats1.merges)
	_check(initial_merges > 0, "cold spawn performs initial merges")

	# Test 2: Warm spawn of same variant reuses cached meshes without SurfaceTool merges
	var drone2 = DroneVisualScript.new()
	add_child(drone2)
	drone2.configure(true, "ak47", "heli")
	await get_tree().process_frame

	var stats2 := DroneVisualResourcesScript.get_stats()
	_check(int(stats2.merges) == initial_merges, "warm spawn performs zero new SurfaceTool merges")
	_check(int(stats2.hits) > 0, "warm spawn registers cache hits")

	# Test 3: Unchanged configure does not rebuild body
	var body_id_before: int = drone2._body.get_instance_id()
	drone2.configure(true, "ak47", "heli")
	var body_id_after: int = drone2._body.get_instance_id()
	_check(body_id_before == body_id_after, "unchanged configure preserves existing body instance")

	# Test 4: Switching chassis to wheeled variant populates wheels without breaking cache
	drone2.set_chassis("wheels")
	await get_tree().process_frame
	var stats3 := DroneVisualResourcesScript.get_stats()
	_check(int(stats3.cached_mesh_variants) > int(stats1.cached_mesh_variants), "wheels kit caches additional part meshes")

	# Test 5: Setting same chassis does not rebuild
	var wheel_body_id: int = drone2._body.get_instance_id()
	drone2.set_chassis("wheels")
	_check(drone2._body.get_instance_id() == wheel_body_id, "redundant set_chassis preserves body")

	drone1.queue_free()
	drone2.queue_free()

	if failures.is_empty():
		print("DRONE_VISUAL_RESOURCES_TEST_OK")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
