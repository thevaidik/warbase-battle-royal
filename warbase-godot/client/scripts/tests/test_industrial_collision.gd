extends SceneTree
## Regression for the square invisible boundaries that bisected the industrial asset.
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", message)
func run() -> void:
	for map_id in ["industrial", "dust2", "nuketown", "canyon"]:
		var builder = load("res://scripts/maps/MapBuilder.gd").new()
		root.add_child(builder)
		builder.build(map_id)
		for jeep in get_nodes_in_group("combat_jeeps"): jeep.freeze = true
		await physics_frame
		await physics_frame
		var space = root.get_world_3d().direct_space_state
		check(builder.find_children("PerimeterWall_*", "StaticBody3D", true, false).is_empty(), map_id + " uses the authored visible boundary")
		for z in [-20.0, 20.0, 35.0]:
			var ray := PhysicsRayQueryParameters3D.create(Vector3(67, 1.4, z), Vector3(73, 1.4, z), 1)
			check(space.intersect_ray(ray).is_empty(), "%s east road ray clear at z=%s" % [map_id, z])
			var capsule := CapsuleShape3D.new()
			capsule.height = 1.8
			capsule.radius = 0.35
			var sweep := PhysicsShapeQueryParameters3D.new()
			sweep.shape = capsule
			sweep.transform.origin = Vector3(67, 1.5, z)
			sweep.motion = Vector3(6, 0, 0)
			sweep.collision_mask = 1
			var travel: PackedFloat32Array = space.cast_motion(sweep)
			check(travel.size() == 2 and travel[0] > 0.999, "%s player capsule crosses former invisible wall at z=%s" % [map_id, z])
			var fence := PhysicsRayQueryParameters3D.create(Vector3(73, 1.4, z), Vector3(84, 1.4, z), 1)
			check(not space.intersect_ray(fence).is_empty(), "%s visible perimeter fence remains solid at z=%s" % [map_id, z])
		var wall := PhysicsRayQueryParameters3D.create(Vector3(-12, 2, -10), Vector3(-8, 2, -10), 1)
		check(not space.intersect_ray(wall).is_empty(), map_id + " warehouse wall remains solid")
		builder.free()
		await physics_frame
	print("INDUSTRIAL COLLISION TEST: %d failures" % failures)
	quit(failures)
