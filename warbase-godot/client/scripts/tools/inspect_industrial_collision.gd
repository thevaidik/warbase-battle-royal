extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var builder = load("res://scripts/maps/MapBuilder.gd").new()
	root.size = Vector2i(1100, 900)
	root.add_child(builder)
	builder.build("industrial")
	for jeep in get_nodes_in_group("combat_jeeps"): jeep.freeze = true
	for wall in builder.find_children("PerimeterWall_*", "StaticBody3D", true, false):
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = wall.get_child(0).shape.size
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0.05, 0.02, 0.3)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		wall.add_child(mi)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(5, 160, 100)
	camera.look_at(Vector3(5, 0, -4))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 190
	camera.current = true
	for i in 5: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../audit/map-collision-upgrade/industrial-before.png"))
	quit()
