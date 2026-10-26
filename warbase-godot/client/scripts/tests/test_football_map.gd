extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ",message)
func run() -> void:
	var builder = load("res://scripts/maps/MapBuilder.gd").new()
	root.add_child(builder)
	var spawns = builder.build("football")
	await physics_frame
	await physics_frame
	check(spawns.size() == 12, "stadium has 12 authored spawns")
	check(builder.find_children("PerimeterWall_*", "StaticBody3D", true, false).is_empty(), "no artificial invisible boundaries")
	var space = root.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	for i in spawns.size():
		var point: Vector3 = spawns[i]
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.1, point + Vector3.DOWN * 0.4, 1)
		check(not space.intersect_ray(ray).is_empty(), "spawn %d has solid ground" % i)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform.origin = point + Vector3.UP * 0.9
		query.collision_mask = 1
		check(space.intersect_shape(query).is_empty(), "spawn %d clears a player capsule" % i)
	var map_root = builder.find_child("GLBMap",true,false)
	var meshes: Array = map_root.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 2, "uses the supplied stadium plus repaired rear surfaces")
	var rear = map_root.find_child("StadiumBackFaces", true, false)
	check(rear != null and rear.mesh.get_faces().size() / 3 == 34263, "missing rear faces are present")
	check(rear.get_parent() == meshes[0] and rear.transform == Transform3D.IDENTITY, "rear faces align with the source mesh")
	check(rear.find_children("*", "CollisionShape3D", true, false).is_empty(), "rear surfaces add no collision geometry")
	check(rear.get_active_material(0) == meshes[0].get_active_material(0), "both wall sides share the original atlas material")
	var rear_arrays = rear.mesh.surface_get_arrays(0)
	var rear_vertices: PackedVector3Array = rear_arrays[Mesh.ARRAY_VERTEX]
	var rear_normals: PackedVector3Array = rear_arrays[Mesh.ARRAY_NORMAL]
	var correctly_wound := true
	for i in range(0, rear_vertices.size(), 3):
		var cross_product := (rear_vertices[i+1] - rear_vertices[i]).cross(rear_vertices[i+2] - rear_vertices[i])
		if cross_product.dot(rear_normals[i] + rear_normals[i+1] + rear_normals[i+2]) > 0.00001:
			correctly_wound = false
	check(correctly_wound, "rear triangles face outward using Godot winding")
	var faces: PackedVector3Array = meshes[0].mesh.get_faces()
	var seen := {}
	var duplicates := 0
	for i in range(0, faces.size(), 3):
		var points := [faces[i], faces[i+1], faces[i+2]]
		var smallest := 0
		for j in [1, 2]:
			if points[j] < points[smallest]: smallest = j
		var key := [points[smallest], points[(smallest+1)%3], points[(smallest+2)%3]]
		if seen.has(key): duplicates += 1
		seen[key] = true
	check(duplicates == 0, "no identically oriented overlapping triangles remain")
	check(faces.size() / 3 == 34422, "repaired full-detail mesh retains the expected non-overlapping surfaces")
	var material = meshes[0].get_active_material(0)
	check(material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, "authored railings and cut-outs retain alpha masking")
	check(material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL, "stadium responds to room time of day")
	check(material.albedo_texture.get_width() == 8192, "full texture resolution retained")
	builder.free()
	print("FOOTBALL MAP TEST: %d failures" % failures)
	quit(failures)
