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
	state.selected_map = "football"
	change_scene_to_file("res://scenes/Main.tscn")
	while current_scene == null: await process_frame
	var main = current_scene
	main._on_deploy()
	main.bots.target_count = 0
	main.bots.clear()
	main.player.global_position = Vector3(-45, 2.36, 45)
	main.player.yaw = 0
	main.player.reset_physics_interpolation()
	for i in 10: await physics_frame
	var sun = main.map_builder.find_children("*", "DirectionalLight3D", true, false)[0]
	var light_pose: Transform3D = sun.global_transform
	var model = main.map_builder.find_child("GLBMap", true, false)
	var model_pose: Transform3D = model.global_transform
	var start: Vector3 = main.player.global_position
	var stationary_light := true
	var stationary_geometry := true
	Input.action_press("move_forward")
	for i in 90:
		await physics_frame
		stationary_light = stationary_light and sun.global_transform.is_equal_approx(light_pose)
		stationary_geometry = stationary_geometry and model.global_transform.is_equal_approx(model_pose)
	Input.action_release("move_forward")
	check(main.player.global_position.distance_to(start) > 2.0, "movement exercised the stadium concourse")
	check(stationary_light and stationary_geometry, "sun and stadium transforms remain fixed during movement")
	check(is_equal_approx(main.player.camera.near, 0.08) and is_equal_approx(main.player.camera.far, 650.0), "camera uses the tighter depth range")
	for i in 3: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../audit/render-stability/moving-view.png"))
	print("MOVEMENT RENDER TEST: %d failures; moved %.2fm" % [failures, main.player.global_position.distance_to(start)])
	quit(failures)
