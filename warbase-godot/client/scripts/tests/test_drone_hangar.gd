extends SceneTree
## Exercise real hangar selection, not just the visual's weapon setter.

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", message)

func run() -> void:
	var settings_path := "user://settings.cfg"
	var had_settings := FileAccess.file_exists(settings_path)
	var saved_bytes := FileAccess.get_file_as_bytes(settings_path) if had_settings else PackedByteArray()
	var state = root.get_node("GameState")
	var hangar = load("res://scripts/ui/OperatorMenu.gd").new()
	root.add_child(hangar)
	await process_frame
	check(hangar._payload_picker.item_count == state.WEAPONS.size(), "hangar offers every functioning payload")
	var ids: Array[String] = []
	for index in hangar._payload_picker.item_count:
		var weapon_id := String(hangar._payload_picker.get_item_metadata(index))
		ids.append(weapon_id)
		hangar._select_payload(index)
		await process_frame
		check(state.selected_primary == weapon_id and hangar._drone.weapon_id == weapon_id,
			"selecting %s equips and previews the same weapon" % weapon_id)
		check(state.selected_primary != state.selected_secondary, "selection keeps primary and secondary distinct")
		var preferences := ConfigFile.new()
		check(preferences.load(settings_path) == OK and String(preferences.get_value("loadout", "primary", "")) == weapon_id,
			"selected payload survives restart")
	for weapon in state.WEAPONS:
		check(ids.has(String(weapon["id"])), "payload available: " + String(weapon["id"]))
	for mode in ["wheels", "tracked", "heli", "wing"]:
		hangar._select_chassis(mode)
		await process_frame
		var preferences := ConfigFile.new()
		check(state.selected_drone_chassis == mode and hangar._drone.chassis_id == mode,
			"hangar previews selected mobility: " + mode)
		check(preferences.load(settings_path) == OK and String(preferences.get_value("loadout", "drone_chassis", "")) == mode,
			"mobility selection survives restart: " + mode)
	hangar.free()
	if had_settings:
		var file := FileAccess.open(settings_path, FileAccess.WRITE)
		file.store_buffer(saved_bytes)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	print("DRONE_HANGAR_TEST failures=", failures)
	quit(failures)
