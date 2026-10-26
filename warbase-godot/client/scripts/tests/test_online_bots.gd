extends SceneTree
## Integration check against a running local authority; no local AI is permitted.
var failures := 0
var bot_shots := 0
var damage_events := 0
var authoritative_damage := false
var room_time := ""
var me_state: Dictionary = {}
var impact_seen := false
var impact_exploded := false
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, description: String) -> void:
	print("CHECK ", "PASS " if value else "FAIL ", description)
	if not value: failures += 1
func run() -> void:
	var state = root.get_node("GameState")
	state.server_host = "localhost:18092"
	state.username = "AI_TESTER"
	state.practice_mode = false
	state.selected_map = "desert_oasis"
	state.room_id = "desert_oasis-public"
	state.selected_primary = "m4"
	state.selected_secondary = "dmr"
	state.selected_throwable = "impact"
	change_scene_to_file("res://scenes/Main.tscn")
	while current_scene == null: await process_frame
	var main = current_scene
	main.net.fire_received.connect(func(shooter: String, _a: Vector3, _b: Vector3, _c: Vector3, _wall: bool) -> void:
		if shooter.begins_with("[BOT]"): bot_shots += 1
	)
	main.net.state_received.connect(func(snapshot: Dictionary) -> void:
		room_time = String(snapshot.get("time_of_day", ""))
		me_state = snapshot.get("players", {}).get("AI_TESTER", me_state)
		for combatant in snapshot.get("players", {}).values():
			if int(combatant.get("health", 100)) < 100: authoritative_damage = true
	)
	main.net.grenade_received.connect(func(_shooter: String, _pos: Vector3, _vel: Vector3, _id: int, kind: String) -> void:
		if kind == "impact": impact_seen = true
	)
	main.net.explosion_received.connect(func(_id: int, _pos: Vector3, kind: String) -> void:
		if kind == "impact": impact_exploded = true
	)
	main.net.damage_received.connect(func(_target: String, pos: Vector3, direction: Vector3, amount: int) -> void:
		if pos.is_finite() and direction.is_finite() and amount > 0: damage_events += 1
	)
	main._on_deploy()
	await create_timer(3).timeout
	check(main.net.connected and state.online_ready, "online authority connected")
	check(String(me_state.get("weapon", "")) == "m4", "selected primary applied by authority")
	main.weapons.switch_weapon(6)
	await create_timer(0.4).timeout
	check(String(me_state.get("weapon", "")) == "dmr" and main.weapons.ammo == 20, "selected secondary switches online")
	main._throw_grenade()
	await create_timer(2).timeout
	check(impact_seen and impact_exploded, "selected impact grenade replicated and detonated")
	check(int(me_state.get("grenades", -1)) == 1, "online throwable inventory authoritative")
	check(state.TIMES.has(room_time) and state.selected_time == room_time, "room lighting synchronized")
	check(main._online_vehicles.size() == 2, "online map vehicles registered")
	var car = main._online_vehicles.get("CAR_0")
	if car:
		var previous_position: Vector3 = main.player.global_position
		var cars := {"CAR_0":{"pos":car.global_position,"yaw":car.rotation.y,"speed":0,"driver":state.username,"health":1200}}
		main._apply_online_vehicles(cars, {"driving_vehicle":"CAR_0"})
		check(main.current_driven_jeep == car and main.player.is_driving and car.freeze, "seat snapshot activates online vehicle camera")
		cars["CAR_0"]["driver"] = ""
		main._apply_online_vehicles(cars, {"driving_vehicle":"", "x":previous_position.x, "y":previous_position.y, "z":previous_position.z})
		check(main.current_driven_jeep == null and not main.player.is_driving, "exit snapshot restores infantry control")

	var ghost_free := true
	for remote in main.mp.remotes.values():
		ghost_free = ghost_free and remote.find_child("FallbackVehicleCollider", true, false) == null
	check(ghost_free, "infantry has no invisible vehicle collider")
	check(main.bots.bots.is_empty(), "online bots are not simulated on client")
	check(main.mp.remotes.size() == 7, "seven server bots replicated")
	check(main.map_builder.find_child("DesertOasis", true, false) != null and main.map_builder.find_child("GLBMap", true, false) == null, "desert has no industrial scene")
	var previous := {}
	for id in main.mp.remotes: previous[id] = main.mp.remotes[id].global_position
	await create_timer(7).timeout
	var moved := 0
	for id in previous:
		if main.mp.remotes.has(id) and main.mp.remotes[id].global_position.distance_to(previous[id]) > 1.0: moved += 1
	print("ONLINE AI: remotes=", main.mp.remotes.size(), " moving=", moved, " shots=", bot_shots)
	check(moved >= 3, "AI navigates the arena")
	check(bot_shots > 0, "server AI perceives and fires at opponents")
	check(authoritative_damage, "AI combat produces authoritative damage")
	check(damage_events > 0, "confirmed damage reaches blood and hit-reaction feedback")
	check(main.get_full_scoreboard_roster().size() == 8, "AI included in scoreboard")
	main._quit_to_menu()
	await process_frame
	await process_frame
	print("ONLINE AI TEST: ", failures, " failures")
	quit(1 if failures else 0)
