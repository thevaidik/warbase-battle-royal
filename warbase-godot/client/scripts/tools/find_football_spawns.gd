extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var builder = load("res://scripts/maps/MapBuilder.gd").new()
	root.add_child(builder)
	builder.build("football")
	await physics_frame
	await physics_frame
	var space = root.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	for z in range(-65, 86, 10):
		for x in range(-65, 86, 10):
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 10, z), Vector3(x, -14, z), 1))
			if hit.is_empty() or hit.normal.y < 0.9: continue
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.transform.origin = hit.position + Vector3(0, 0.98, 0)
			query.collision_mask = 1
			if space.intersect_shape(query).is_empty(): print("SPAWN ",hit.position + Vector3(0, 0.15, 0))
	quit()
