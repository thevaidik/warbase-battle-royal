extends SceneTree
## Preserve the full stadium atlas without putting it in the initial web pack.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var packer := PCKPacker.new()
	var uids := {}
	var temporary := ProjectSettings.globalize_path("res://dist/football.pck")
	if packer.pck_start(temporary) != OK: quit(1); return
	for source in ["res://assets/maps/football.glb", "res://assets/maps/football_0.png"]:
		var config := ConfigFile.new()
		if config.load(source + ".import") != OK: quit(1); return
		var imported: String = config.get_value("remap", "path")
		if packer.add_file(imported, ProjectSettings.globalize_path(imported)) != OK: quit(1); return
		uids[str(config.get_value("remap", "uid"))] = source
		if packer.add_file(source + ".import", ProjectSettings.globalize_path(source + ".import")) != OK: quit(1); return
	if packer.add_file("res://assets/maps/Football-LICENSE.txt", ProjectSettings.globalize_path("res://assets/maps/Football-LICENSE.txt")) != OK: quit(1); return
	if packer.add_file("res://assets/maps/football_backfaces.res", ProjectSettings.globalize_path("res://assets/maps/football_backfaces.res")) != OK: quit(1); return
	if packer.flush() != OK: quit(1); return
	var hash := FileAccess.get_sha256(temporary)
	var filename := "map-football-" + hash.left(16) + ".pck"
	var destination := ProjectSettings.globalize_path("res://dist/" + filename)
	if FileAccess.file_exists(destination): DirAccess.remove_absolute(temporary)
	else: DirAccess.rename_absolute(temporary, destination)
	var file := FileAccess.open(destination, FileAccess.READ)
	var manifest := {"football":{"file":filename, "sha256":hash, "bytes":file.get_length(), "uids":uids}}
	var output := FileAccess.open("res://dist/optional-maps.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(manifest))
	print("OPTIONAL MAP PACK: ", filename, " bytes=",file.get_length())
	quit()
