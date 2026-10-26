extends SceneTree
## Rebuild server collision/spawn data from the same shapes used by the client.
const MAPS := ["football", "resoforge", "industrial", "village", "arena", "shipment", "dust2", "canyon", "desert_oasis", "nuketown"]
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var output := {}
	for map_id in MAPS:
		var builder = load("res://scripts/maps/MapBuilder.gd").new()
		root.add_child(builder)
		var spawns: Array[Vector3] = builder.build(map_id)
		var spawn_data := []
		for point in spawns: spawn_data.append([point.x, point.y, point.z])
		var triangles := []
		collect(builder, triangles)
		var vehicles := []
		for vehicle in builder.find_children("*", "VehicleBody3D", true, false):
			var at: Vector3 = vehicle.global_position
			vehicles.append([at.x, at.y, at.z, vehicle.global_rotation.y])
		output[map_id] = {"spawns": spawn_data, "triangles": triangles, "vehicles":vehicles, "nav_step":1.0 if map_id == "football" else 2.0}
		print("MAP EXPORT: ", map_id, " triangles=", triangles.size() / 9)
		builder.free()
	var path := ProjectSettings.globalize_path("res://../server/internal/engine/maps.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write map collision data")
		quit(1)
		return
	file.store_string(JSON.stringify(output))
	quit()
func collect(node: Node, triangles: Array) -> void:
	if node is CollisionShape3D and not node.disabled and node.get_parent() is StaticBody3D:
		var shape: Shape3D = node.shape
		var faces := PackedVector3Array()
		var mesh: PrimitiveMesh
		if shape is ConcavePolygonShape3D:
			faces = shape.get_faces()
		elif shape is BoxShape3D:
			var box := BoxMesh.new()
			box.size = shape.size
			mesh = box
		elif shape is CylinderShape3D:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = shape.radius
			cylinder.bottom_radius = shape.radius
			cylinder.height = shape.height
			cylinder.radial_segments = 12
			mesh = cylinder
		if mesh: faces = mesh.get_faces()
		for point in faces:
			var world_point: Vector3 = node.global_transform * point
			triangles.append(snappedf(world_point.x, 0.00001))
			triangles.append(snappedf(world_point.y, 0.00001))
			triangles.append(snappedf(world_point.z, 0.00001))
	for child in node.get_children(): collect(child, triangles)
