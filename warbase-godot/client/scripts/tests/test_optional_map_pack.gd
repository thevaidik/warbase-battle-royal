extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if ResourceLoader.exists("res://assets/maps/football.glb"):
		push_error("Stadium leaked into the initial web pack")
		quit(1); return
	var path := ""
	var manifest_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("optional="): path = arg.trim_prefix("optional=")
		if arg.begins_with("manifest="): manifest_path = arg.trim_prefix("manifest=")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not load("res://scripts/maps/MapDownload.gd")._mount(path, data.football): quit(1); return
	var builder = load("res://scripts/maps/MapBuilder.gd").new()
	root.add_child(builder)
	var spawns = builder.build("football")
	if spawns.size() != 12: quit(1); return
	var meshes = builder.find_child("GLBMap", true, false).find_children("*", "MeshInstance3D", true, false)
	if meshes.size() != 2 or builder.find_child("StadiumBackFaces", true, false) == null: quit(1); return
	if meshes[0].get_active_material(0).albedo_texture.get_width() != 8192: quit(1); return
	builder.free()
	print("OPTIONAL PACK TEST: PASS - excluded from startup, mounted successfully, 12 spawns, full 8K atlas")
	quit()
