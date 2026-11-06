extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", message)
func run() -> void:
	for id in ["desert_oasis", "canyon"]:
		var builder = load("res://scripts/maps/MapBuilder.gd").new()
		root.add_child(builder)
		var spawns: Array = builder.build(id)
		for jeep in get_nodes_in_group("combat_jeeps"): jeep.freeze = true
		await physics_frame
		await physics_frame
		var space := root.get_world_3d().direct_space_state
		check(builder.find_children("PerimeterWall_*", "StaticBody3D", true, false).is_empty(), id + " has no invisible perimeter bodies")
		if id == "canyon": check(builder.find_child("GLBMap", true, false) == null, "Canyon does not instantiate the Industrial asset")
		for collider in builder.find_children("*", "CollisionShape3D", true, false):
			if not collider.get_parent() is StaticBody3D or collider.get_parent().name == "SafetyFloor": continue
			var mesh = collider.get_parent().get_parent()
			check(mesh is MeshInstance3D and mesh.is_visible_in_tree(), id + " static collider has visible mesh")
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.4
		capsule.height = 1.8
		for point: Vector3 in spawns:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.collision_mask = 1
			query.transform.origin = point + Vector3.UP * 0.9
			check(space.intersect_shape(query).is_empty(), "%s spawn capsule is not embedded: %s" % [id,point])
		if id == "desert_oasis":
			for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
				var from: Vector3 = direction * 30 + Vector3.UP
				var to: Vector3 = direction * 35 + Vector3.UP
				check(space.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1)).is_empty(), "former Desert Oasis hidden boundary is clear")
				check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(to,direction * 42 + Vector3.UP,1)).is_empty(), "visible Desert Oasis rock boundary remains solid")
		builder.free()
		await physics_frame
	print("DESERT CANYON COLLISION TEST: %d failures" % failures)
	quit(failures)
