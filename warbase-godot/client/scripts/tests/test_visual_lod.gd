extends Node

const DroneVisualScript = preload("res://scripts/drones/DroneVisual.gd")
const DroneVisualResourcesScript = preload("res://scripts/drones/DroneVisualResources.gd")
const RemoteScript = preload("res://scripts/net/RemotePlayer.gd")

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _count_visible_by_tier(drone: Node3D, target_tier: int) -> int:
	var count := 0
	if not is_instance_valid(drone._body): return 0
	for child in drone._body.find_children("*", "MeshInstance3D", true, false):
		var tier := int(child.get_meta("visual_lod_tier", 0))
		if tier == target_tier and child.visible:
			count += 1
	return count

func _count_total_by_tier(drone: Node3D, target_tier: int) -> int:
	var count := 0
	if not is_instance_valid(drone._body): return 0
	for child in drone._body.find_children("*", "MeshInstance3D", true, false):
		var tier := int(child.get_meta("visual_lod_tier", 0))
		if tier == target_tier:
			count += 1
	return count

func _run() -> void:
	# Clear resource cache to ensure cold pass coverage
	DroneVisualResourcesScript.clear_cache()

	# Test 1: Verify all detail groups across all 4 chassis on cold and warm passes (F2)
	for chassis in ["heli", "wheels", "tracked", "wing"]:
		for warm_pass in [false, true]:
			var pass_name := "warm" if warm_pass else "cold"
			var drone = DroneVisualScript.new()
			add_child(drone)
			drone.configure(true, "ak47", chassis)
			await get_tree().process_frame

			var total_tier1 := _count_total_by_tier(drone, 1)
			var total_tier2 := _count_total_by_tier(drone, 2)
			_check(total_tier1 > 0, "%s %s: tier 1 fine details exist" % [chassis, pass_name])
			_check(total_tier2 > 0, "%s %s: tier 2 medium details exist" % [chassis, pass_name])

			# LOD 0: all detail groups must be visible
			drone.set_visual_lod(0)
			_check(_count_visible_by_tier(drone, 1) == total_tier1,
				"%s %s: all tier 1 details visible at LOD 0" % [chassis, pass_name])
			_check(_count_visible_by_tier(drone, 2) == total_tier2,
				"%s %s: all tier 2 details visible at LOD 0" % [chassis, pass_name])

			var muzzle_l0 := drone.get_muzzle_global()
			_check(muzzle_l0.is_finite(), "%s %s: muzzle valid at LOD 0" % [chassis, pass_name])

			# LOD 1: fine details hidden, medium details visible
			drone.set_visual_lod(1)
			var muzzle_l1 := drone.get_muzzle_global()
			_check(muzzle_l1.is_equal_approx(muzzle_l0), "%s %s: muzzle unchanged at LOD 1" % [chassis, pass_name])
			_check(_count_visible_by_tier(drone, 1) == 0,
				"%s %s: all tier 1 details hidden at LOD 1 (0 visible)" % [chassis, pass_name])
			_check(_count_visible_by_tier(drone, 2) == total_tier2,
				"%s %s: all tier 2 details visible at LOD 1" % [chassis, pass_name])

			# LOD 2: all fine and medium details hidden
			drone.set_visual_lod(2)
			var muzzle_l2 := drone.get_muzzle_global()
			_check(muzzle_l2.is_equal_approx(muzzle_l0), "%s %s: muzzle unchanged at LOD 2" % [chassis, pass_name])
			_check(_count_visible_by_tier(drone, 1) == 0,
				"%s %s: all tier 1 details hidden at LOD 2 (0 visible)" % [chassis, pass_name])
			_check(_count_visible_by_tier(drone, 2) == 0,
				"%s %s: all tier 2 details hidden at LOD 2 (0 visible)" % [chassis, pass_name])

			# Restore LOD 0
			drone.set_visual_lod(0)
			_check(_count_visible_by_tier(drone, 1) == total_tier1,
				"%s %s: all tier 1 details restored at LOD 0" % [chassis, pass_name])
			_check(_count_visible_by_tier(drone, 2) == total_tier2,
				"%s %s: all tier 2 details restored at LOD 0" % [chassis, pass_name])

			drone.queue_free()

	# Test 2: Rebuilding chassis preserves requested visual LOD (F3)
	var drone_rebuild = DroneVisualScript.new()
	add_child(drone_rebuild)
	drone_rebuild.configure(true, "ak47", "tracked")
	await get_tree().process_frame

	drone_rebuild.set_visual_lod(2)
	_check(_count_visible_by_tier(drone_rebuild, 1) == 0, "tracked at LOD 2: tier 1 hidden")
	_check(_count_visible_by_tier(drone_rebuild, 2) == 0, "tracked at LOD 2: tier 2 hidden")

	# Change chassis to wheels while at LOD 2
	drone_rebuild.set_chassis("wheels")
	_check(drone_rebuild.visual_lod == 2, "visual_lod preserved as 2 across chassis rebuild")
	_check(_count_visible_by_tier(drone_rebuild, 1) == 0,
		"wheels after rebuild from LOD 2: all tier 1 details immediately hidden")
	_check(_count_visible_by_tier(drone_rebuild, 2) == 0,
		"wheels after rebuild from LOD 2: all tier 2 details immediately hidden")

	# Re-invoking set_visual_lod(2) with same level is idempotent and preserves hidden details
	drone_rebuild.set_visual_lod(2)
	_check(_count_visible_by_tier(drone_rebuild, 1) == 0,
		"wheels after re-invoking set_visual_lod(2): tier 1 remains hidden")
	_check(_count_visible_by_tier(drone_rebuild, 2) == 0,
		"wheels after re-invoking set_visual_lod(2): tier 2 remains hidden")

	# Restore LOD 0 on rebuilt chassis
	drone_rebuild.set_visual_lod(0)
	var wheels_t1 := _count_total_by_tier(drone_rebuild, 1)
	var wheels_t2 := _count_total_by_tier(drone_rebuild, 2)
	_check(_count_visible_by_tier(drone_rebuild, 1) == wheels_t1, "wheels tier 1 details restored at LOD 0")
	_check(_count_visible_by_tier(drone_rebuild, 2) == wheels_t2, "wheels tier 2 details restored at LOD 0")

	# Test 3: Wreck material caching
	var wreck_parent := Node3D.new()
	add_child(wreck_parent)
	var wreck1 = drone_rebuild.make_wreck_visual(wreck_parent)
	var wreck2 = drone_rebuild.make_wreck_visual(wreck_parent)

	var shared_materials := 0
	for m1 in wreck1.find_children("*", "MeshInstance3D", true, false):
		var mesh1 := m1 as MeshInstance3D
		if mesh1.material_override != null:
			var m2 = wreck2.get_node_or_null(wreck1.get_path_to(mesh1)) as MeshInstance3D
			if is_instance_valid(m2) and m2.material_override == mesh1.material_override:
				shared_materials += 1

	_check(shared_materials > 0, "wreck instances share immutable darkened material resources")

	drone_rebuild.queue_free()
	wreck_parent.queue_free()

	if failures.is_empty():
		print("VISUAL_LOD_TEST_OK")
		get_tree().quit(0)
	else:
		for f in failures:
			print("FAILURE: ", f)
		get_tree().quit(1)
