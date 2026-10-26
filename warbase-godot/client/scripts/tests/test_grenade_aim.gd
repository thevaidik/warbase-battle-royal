extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", message)
func run() -> void:
	var state = root.get_node("GameState")
	state.practice_mode = true
	state.bot_damage_enabled = false
	state.selected_map = "resoforge"
	state.throwables_remaining = 2
	change_scene_to_file("res://scenes/Main.tscn")
	while current_scene == null: await process_frame
	var main = current_scene
	main._on_deploy()
	for i in 8: await physics_frame
	var press := InputEventAction.new()
	press.action = "grenade"
	press.pressed = true
	main._input(press)
	main._update_grenade_preview(0.1)
	check(main._grenade_aiming, "holding grenade enters aim mode")
	check(state.throwables_remaining == 2 and get_nodes_in_group("grenades").is_empty(), "aiming does not spend or throw a grenade")
	var markers := 0
	for marker in main._grenade_preview:
		if marker.visible: markers += 1
	check(markers > 1, "flight preview is visible while aiming")
	for i in 3: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../audit/grenade-map-upgrade/aim-preview.png"))
	press.pressed = false
	main._input(press)
	check(not main._grenade_aiming and state.throwables_remaining == 1, "release throws exactly one grenade")
	check(get_nodes_in_group("grenades").size() == 1, "release creates a simulated grenade")
	for i in 30: await physics_frame
	check(get_nodes_in_group("grenades").size() == 1, "frag remains in flight before fuse expires")
	# Release into cover must stay on the player's side of a wall.
	main._grenade_cd = 0
	main._input(press) # Repeated release must not spend another grenade.
	check(state.throwables_remaining == 1, "repeated release does not duplicate the throw")
	main._quit_to_menu()
	check(main._grenade_preview.is_empty(), "returning home clears aim markers")
	print("GRENADE AIM TEST: %d failures" % failures)
	quit(failures)
