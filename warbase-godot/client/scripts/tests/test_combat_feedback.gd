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
	state.selected_time = "overcast"
	change_scene_to_file("res://scenes/Main.tscn")
	while current_scene == null: await process_frame
	var main = current_scene
	main._on_deploy()
	main.bots.target_count = 0
	main.bots.clear()
	for i in 8: await physics_frame
	check(not state.TIMES.has("night") and state.TIMES.has("overcast"), "four selectable daylight presets replace total night")
	var environment = main.map_builder.find_children("*","WorldEnvironment",true,false)[0].environment
	check(environment.ambient_light_energy >= 0.65, "overcast visibility remains bright")
	state.bot_damage_enabled = true
	main.player.end_spawn_protection()
	main.player.take_bot_damage(35, main.player.global_position + Vector3(0,0,5))
	check(main.hud._hurt_flash_t > 0, "incoming damage flashes the hull HUD")
	await create_timer(0.15).timeout
	main.player.take_bot_damage(200)
	await create_timer(0.6).timeout
	check(main.player.is_dead and main.hud.death_panel.visible, "lethal damage enters the death presentation")
	check(is_instance_valid(main.player._crash_focus) and not main.player._drone_visual.visible, "death camera follows the wreck")
	check(get_first_node_in_group("drone_combat_effects")._wrecks.size() == 1, "death leaves one cosmetic wreck")
	main._do_respawn(main.map_builder.spawn_points[0])
	check(not main.player.is_dead and main.player._drone_visual.visible and is_zero_approx(main.hud._hurt_flash_t), "respawn restores the camera, weapons and clear screen")
	main._quit_to_menu()
	print("COMBAT FEEDBACK TEST: %d failures" % failures)
	quit(failures)
