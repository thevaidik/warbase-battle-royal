extends SceneTree
class Overhead extends Control:
	var edges: Array = []
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("132028"))
		for x in range(0, int(size.x), 28): draw_line(Vector2(x, 0), Vector2(x, size.y), Color("1e333b"))
		for y in range(0, int(size.y), 28): draw_line(Vector2(0, y), Vector2(size.x, y), Color("1e333b"))
		for edge in edges: draw_line(edge[0], edge[1], Color(0.77, 0.68, 0.48, 0.65), 2.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(28, 36), "COMBAT ARENA / OVERHEAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("91a2a8"))

func collect_edges(node: Node, points: Array) -> void:
	if node is MeshInstance3D and node.mesh:
		var faces: PackedVector3Array = node.mesh.get_faces()
		for i in range(0, faces.size(), 3):
			for pair in [[0, 1], [1, 2], [2, 0]]:
				var a: Vector3 = node.global_transform * faces[i + pair[0]]
				var b: Vector3 = node.global_transform * faces[i + pair[1]]
				if absf(a.y - b.y) < 0.02: points.append([Vector2(a.x, a.z), Vector2(b.x, b.z)])
	for child in node.get_children(): collect_edges(child, points)

func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1100, 550)
	var views := {
		"football": [Vector3(90, 100, 130), Vector3(5, 0, 13)],
		"resoforge": [Vector3(25, 30, 35), Vector3(0, 2, 0)],
		"industrial": [Vector3(28, 16, 36), Vector3(0, 1, 0)],
		"village": [Vector3(28, 22, 36), Vector3(0, 2, 0)],
		"arena": [Vector3(-26, 2.75, -3), Vector3(-10, 2, -5)],
		"loft": [Vector3(7, 5, 6), Vector3(0, 2, -4)],
		"shipment": [Vector3(24, 20, 24), Vector3(0, 1, 0)],
		"dust2": [Vector3(45, 24, 46), Vector3(8, 1, 10)],
		"nuketown": [Vector3(-32, 20, 30), Vector3(0, 1, 0)],
		"canyon": [Vector3(42, 25, -40), Vector3(0, 1, 0)],
		"desert_oasis": [Vector3(30, 18, 28), Vector3(0, 1, 0)]
	}
	var selected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("map="): selected = arg.trim_prefix("map=")
	for map_id in views:
		if not selected.is_empty() and selected != map_id: continue
		var builder = load("res://scripts/maps/MapBuilder.gd").new()
		root.add_child(builder)
		builder.build(map_id)
		builder.process_mode = Node.PROCESS_MODE_DISABLED
		for jeep in get_nodes_in_group("combat_jeeps"): jeep.freeze = true
		var diagram: Overhead
		if map_id == "arena":
			diagram = Overhead.new()
			diagram.size = Vector2(root.size)
			var points: Array = []
			collect_edges(builder.find_child("GLBMap", true, false), points)
			var bounds := Rect2(Vector2(-30, -30), Vector2(30, 30))
			for edge in points:
				for point in edge: bounds = bounds.expand(point)
			var scale_factor := minf((diagram.size.x - 150.0) / maxf(bounds.size.x, 1.0), (diagram.size.y - 100.0) / maxf(bounds.size.y, 1.0))
			for edge in points:
				diagram.edges.append([(edge[0] - bounds.get_center()) * scale_factor + diagram.size * 0.5, (edge[1] - bounds.get_center()) * scale_factor + diagram.size * 0.5])
			root.add_child(diagram)
			builder.visible = false
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.position = views[map_id][0]
		camera.look_at(views[map_id][1])
		camera.current = true
		camera.fov = 55
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://assets/ui/maps/" + map_id + ".png"))
		if diagram: diagram.free()
		camera.free()
		builder.free()
		await process_frame
	print("MAP ART COMPLETE")
	quit()
