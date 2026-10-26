extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var builder = load("res://scripts/maps/MapBuilder.gd").new()
	root.add_child(builder)
	builder.build("resoforge")
	await physics_frame
	await physics_frame
	var space = root.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	for z in [-20, -17, -14, 14, 17, 20]:
		for x in [-9, -6, -3, 0, 3, 6, 9]:
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 2.5, z), Vector3(x, -0.5, z), 1))
			if hit.is_empty() or hit.position.y > 0.5 or hit.normal.y < 0.7: continue
			var check := PhysicsShapeQueryParameters3D.new()
			check.shape = capsule
			check.transform.origin = hit.position + Vector3(0, 0.98, 0)
			check.collision_mask = 1
			if space.intersect_shape(check).is_empty(): print("SPAWN ", hit.position + Vector3(0, 0.15, 0))
	quit()
