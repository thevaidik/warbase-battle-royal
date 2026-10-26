extends SceneTree
## Bounded gameplay regression: handling, scopes, ammunition, pause, and physics stability.
var failures := 0
var main: Node
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, description: String) -> void:
	print("CHECK ", "PASS " if value else "FAIL ", description)
	if not value: failures += 1
func run() -> void:
	root.get_node("GameState").server_host = "localhost:18091"
	root.get_node("GameState").practice_mode = true
	root.get_node("GameState").selected_primary = "ak47"
	root.get_node("GameState").selected_secondary = "pistol"
	change_scene_to_file("res://scenes/Main.tscn")
	while current_scene == null: await process_frame
	main = current_scene
	seed(0)
	main._on_deploy()
	root.get_node("GameState").set_bot_damage(false)
	var weapon = main.weapons
	await create_timer(0.3).timeout
	weapon.try_fire()
	check(weapon.ammo == 29, "AK consumes one cartridge")
	weapon.switch_weapon(1)
	weapon.try_fire()
	check(weapon.ammo == 12, "draw animation blocks firing")
	await create_timer(0.3).timeout
	weapon.try_fire()
	check(weapon.ammo == 11, "pistol consumes one cartridge")
	weapon.switch_weapon(0)
	check(weapon.ammo == 29, "switch preserves rifle magazine")
	weapon.switch_weapon(1)
	check(weapon.ammo == 11, "switch preserves pistol magazine")
	weapon.start_reload()
	weapon.switch_weapon(0)
	check(not weapon.is_reloading and weapon.ammo == 29, "switch cancels reload without free ammo")
	root.get_node("GameState").selected_secondary = "m2010"
	weapon.switch_weapon(2)
	weapon.scope_idx = 1
	var fov: float = weapon.get_current_ads_fov()
	var zoom: float = tan(deg_to_rad(75.0) * 0.5) / tan(deg_to_rad(fov) * 0.5)
	check(absf(zoom - 8.0) < 0.001, "8x zoom uses optical FOV ratio")
	check(weapon.is_scoped(), "sniper uses scope aperture")
	var spring := Vector2(0.4, 3.0)
	for i in 100: spring = weapon._spring(spring.x, spring.y, 0.1)
	check(spring.is_finite() and spring.length() < 0.001, "recoil spring settles through frame spikes")
	await create_timer(2.0).timeout
	var finite: bool = main.player.global_transform.is_finite()
	for bot in main.bots.bots:
		finite = finite and bot.global_transform.is_finite() and bot.velocity.is_finite()
	for jeep in get_nodes_in_group("combat_jeeps"):
		finite = finite and jeep.global_transform.is_finite() and jeep.linear_velocity.is_finite()
	check(finite, "bots and parked vehicles retain finite physics")
	main._toggle_pause()
	check(paused and not main.player.can_process(), "pause suspends practice simulation")
	main._toggle_pause()
	weapon.reset_after_respawn()
	check(weapon.ammo == 5 and weapon._pending_shots.is_empty(), "respawn resets weapon state")
	for index in range(4, root.get_node("GameState").WEAPONS.size()):
		root.get_node("GameState").selected_secondary = root.get_node("GameState").weapon_id_for_index(index)
		weapon.switch_weapon(index)
		await create_timer(0.3).timeout
		var config: Dictionary = weapon.current_config()
		var before: int = weapon.ammo
		if config["id"] == "dmr": Input.action_press("fire")
		weapon.try_fire()
		check(weapon.ammo == before - 1, String(config["name"]) + " fires and consumes ammo")
		check(root.get_node("GameState").weapon_index_for_id(config["id"]) == index, "weapon ID roundtrip")
		check(weapon._views[index].has_node("Muzzle") and weapon._views[index].has_node("magazine"), "new weapon has muzzle and animated magazine")
		if config["id"] == "dmr":
			check(weapon.is_scoped() and weapon.get_current_scope_zoom() == 4, "DMR starts at 4x")
			weapon.cycle_scope_magnification()
			check(weapon.get_current_scope_zoom() == 6, "DMR supports 6x")
			await create_timer(0.3).timeout
			weapon.try_fire()
			check(weapon.ammo == before - 1, "DMR requires trigger release between shots")
			Input.action_release("fire")
			# Headless display cannot capture the mouse; drive the completed ADS state.
			weapon.ads_amount = 1.0
			main._process(0.0)
			check(main.hud.scope_overlay.visible, "DMR ADS displays the scope reticle")
			weapon.ads_amount = 0.0
	var previous_index: int = weapon.active_index
	weapon.switch_weapon(3)
	check(weapon.active_index == previous_index, "cannot equip a weapon outside selected slots")
	weapon._spawn_tracer(Vector3(0, 1, 0), Vector3(0, 1, -100), "m4")
	var tracer: Dictionary = weapon._tracers[(weapon._tracer_idx + weapon.TRACER_POOL - 1) % weapon.TRACER_POOL]
	check(absf(float(tracer["dur"]) - 100.0/900.0) < 0.001, "tracer uses rifle muzzle velocity")
	var sniper: Dictionary = root.get_node("GameState").WEAPONS[2]
	check(root.get_node("GameState").damage_at_range(sniper, 300) >= 100, "sniper retains lethal damage at maximum range")
	weapon.spawn_blood(Vector3(0, 2, 0), Vector3.FORWARD)
	var active_blood := 0
	for slot in weapon._bloods:
		if slot["active"]: active_blood += 1
	check(active_blood == 8, "hit feedback uses the bounded blood pool")
	await create_timer(0.65).timeout
	var blood_cleared := true
	for slot in weapon._bloods: blood_cleared = blood_cleared and not slot["active"]
	check(blood_cleared, "blood effect expires and particles are reused")
	main._quit_to_menu()
	await process_frame
	await process_frame
	print("WEAPON TEST: ", failures, " failures")
	quit(1 if failures > 0 else 0)
