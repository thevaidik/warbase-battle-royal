extends SceneTree
const DroneFlight := preload("res://scripts/drones/DroneFlight.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", message)
func run() -> void:
	for id in ["dust2", "canyon"]:
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
		var drone_sphere := SphereShape3D.new()
		drone_sphere.radius = DroneFlight.RADIUS
		for point: Vector3 in spawns:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = drone_sphere
			query.collision_mask = 1
			query.transform.origin = point + Vector3.UP * DroneFlight.SPAWN_OFFSET
			check(space.intersect_shape(query).is_empty(), "%s spawn drone sphere is not embedded: %s" % [id,point])
		builder.free()
		await physics_frame
	print("DESERT CANYON COLLISION TEST: %d failures" % failures)
	quit(failures)
