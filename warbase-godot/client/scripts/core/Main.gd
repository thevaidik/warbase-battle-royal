extends Node3D
## Game orchestrator: menu -> deploy -> play/pause/dead match loop.
## Owns world, player, weapons, bots, multiplayer, HUD wiring, and 60Hz net sync.

const MapDownloadScript := preload("res://scripts/maps/MapDownload.gd")
const PlayerScript := preload("res://scripts/core/Player.gd")
const WeaponSysScript := preload("res://scripts/weapons/WeaponSystem.gd")
const MapBuilderScript := preload("res://scripts/maps/MapBuilder.gd")
const BotMgrScript := preload("res://scripts/bots/BotManager.gd")
const MultiplayerScript := preload("res://scripts/net/MultiplayerManager.gd")
const NetScript := preload("res://scripts/net/NetworkManager.gd")
const HudScript := preload("res://scripts/ui/HUD.gd")
const MenuScript := preload("res://scripts/ui/MainMenu.gd")
const CombatJeepScript := preload("res://scripts/vehicles/CombatJeep.gd")

enum Phase { MENU, PLAYING, PAUSED, DEAD }

var phase: int = Phase.MENU
var world: Node3D
var map_builder
var player: WarPlayer
var weapons: WarWeaponSystem
var bots
var mp
var net: WarNetwork
var hud: WarHUD
var menu: WarMenu
var sway_root: Node3D
var current_driven_jeep = null
var _online_vehicles: Dictionary = {}

var _send_acc := 0.0
var _respawn_t := 0.0
var _next_respawn_request_ms := 0
var _deploy_pending := false
var _grenade_cd := 0.0
var _grenade_aiming := false
var _grenade_preview: Array[MeshInstance3D] = []
var _grenade_preview_t := 0.0
const GrenadeFlight = preload("res://scripts/weapons/GrenadeBallistics.gd")
var _last_winner := ""
var _last_round_finished := false
var _network_correction_count := 0
var _reconcile_after_sequence := 0
var _last_damage_feedback_ms := -1000

var _autotest := false
var _qa_active := false
var _test_t := 0.0
var _test_stage := 0

func _ready() -> void:
	_configure_ui_scale()
	get_window().size_changed.connect(_configure_ui_scale)
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index in range(4, GameState.WEAPONS.size()):
		var action := "weapon_%d" % (index + 1)
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key := InputEventKey.new()
			key.physical_keycode = KEY_1 + index
			InputMap.action_add_event(action, key)
	# Industry competitive standard: unbuffered sub-millisecond raw mouse input
	Input.use_accumulated_input = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Draw at the window's actual resolution; upscaling amplifies moving edges.
	get_viewport().msaa_3d = Viewport.MSAA_4X
	get_viewport().scaling_3d_scale = 1.0

	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E
		InputMap.action_add_event("interact", ev)
	if not InputMap.has_action("crouch"):
		InputMap.add_action("crouch")
		var ev_c := InputEventKey.new()
		ev_c.physical_keycode = KEY_C
		InputMap.action_add_event("crouch", ev_c)
	for a in OS.get_cmdline_user_args():
		if a == "autotest":
			_autotest = true
			GameState.practice_mode = true
			GameState.selected_primary = "ak47"
			GameState.selected_secondary = "pistol"
		if a.begins_with("map="):
			GameState.selected_map = a.trim_prefix("map=")
			GameState.room_id = GameState.selected_map + "-public"
		if a.begins_with("host="):
			GameState.server_host = a.trim_prefix("host=")
			
	world = Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	
	net = NetScript.new()
	net.name = "Net"
	net.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(net)
	
	hud = HudScript.new()
	hud.name = "HUD"
	hud.visible = false
	add_child(hud)
	hud.resume_pressed.connect(_toggle_pause)
	hud.quit_pressed.connect(_quit_to_menu)
	hud.scoreboard_closed.connect(_on_scoreboard_closed)
	
	menu = MenuScript.new()
	menu.name = "Menu"
	add_child(menu)
	menu.deploy_requested.connect(_on_deploy)
	
	net.state_received.connect(_on_state)
	net.hit_confirmed.connect(_on_hit_confirmed)
	net.damage_received.connect(_on_damage_effect)
	net.kill_confirmed.connect(_on_kill_confirmed)
	net.respawn_received.connect(_on_net_respawn)
	net.connection_changed.connect(_on_conn)
	net.connection_error.connect(func(reason: String) -> void:
		GameState.online_ready = false
		if phase != Phase.MENU: call_deferred("_return_after_connection_error", reason)
	)

	if "qa_official" in OS.get_cmdline_user_args():
		_qa_active = true
		var probe = load("res://scripts/qa/OfficialProbe.gd").new()
		add_child(probe)
		probe.begin(self)

func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _qa_active else Input.MOUSE_MODE_CAPTURED

func _return_after_connection_error(reason: String) -> void:
	if phase == Phase.MENU: return
	_quit_to_menu()
	menu._show_toast(reason + ". Select a room to reconnect.", false)

func _configure_ui_scale() -> void:
	# Keep UI readable on large windows without squeezing the compact layout.
	var window := get_window()
	var pixels := Vector2(window.size)
	var factor := maxf(1.0, minf(pixels.x / 1280.0, pixels.y / 720.0))
	var logical := Vector2i(roundi(pixels.x / factor), roundi(pixels.y / factor))
	if window.content_scale_size != logical:
		window.content_scale_size = logical

func _on_deploy() -> void:
	if _deploy_pending: return
	var name_rule := RegEx.new()
	name_rule.compile("^[A-Za-z0-9_-]{3,16}$")
	if name_rule.search(GameState.username) == null:
		menu._show_toast("Callsign: use 3–16 letters, numbers, underscores or hyphens.", false)
		return
	var requested_map := GameState.selected_map
	_deploy_pending = true
	menu.join_btn.disabled = true
	var available: bool = await MapDownloadScript.ensure_loaded(self, requested_map, func(message: String) -> void: menu.join_btn.text = message)
	_deploy_pending = false
	menu._update_footer_selection()
	if not available:
		menu._show_toast("Stadium download failed. Please try again.", false)
		return
	if requested_map != GameState.selected_map: return
	menu.visible = false
	if _autotest:
		GameState.set_bot_damage(false)
	_start_match()
	if _autotest:
		print("AUTOTEST: deployed map=", GameState.selected_map, " player_at=", player.global_position)

func _start_match() -> void:
	GameState.online_ready = GameState.practice_mode
	_reconcile_after_sequence = net.input_sequence
	_network_correction_count = 0
	hud.set_connection_status("Synchronizing match…" if not GameState.practice_mode else "")
	GameState.reset_match_stats()
	
	# Map generation
	map_builder = MapBuilderScript.new()
	world.add_child(map_builder)
	var spawns: Array[Vector3] = map_builder.build(GameState.selected_map)
	_online_vehicles.clear()
	if not GameState.practice_mode:
		var vehicles = map_builder.find_children("*", "VehicleBody3D", true, false)
		for i in vehicles.size():
			var vehicle = vehicles[i]
			var id := "CAR_%d" % i
			_online_vehicles[id] = vehicle
			vehicle.set_meta("server_vehicle_id", id)
			vehicle.network_controlled = true
			vehicle.network_position = vehicle.global_position
			vehicle.network_yaw = vehicle.rotation.y
			vehicle.freeze = true
	
	# Instantiate player from Player.tscn
	const PlayerScene: PackedScene = preload("res://scenes/Player.tscn")
	player = PlayerScene.instantiate() as WarPlayer
	world.add_child(player)
	sway_root = player.get_node("Head/Camera3D/SwayRoot") as Node3D
	var cam := player.get_node("Head/Camera3D") as Camera3D
	var sp: Vector3 = spawns[0] if not spawns.is_empty() else Vector3(0, 0.5, 0)
	player.global_position = sp + Vector3(0, 0.2, 0)
	if GameState.selected_map in ["resoforge", "football"]: player.yaw = atan2(sp.x, sp.z)
	
	# Weapons system
	weapons = WeaponSysScript.new()
	weapons.name = "WeaponSystem"
	world.add_child(weapons)
	weapons.setup(player, cam, sway_root, net, world)
	weapons.ammo_changed.connect(func(a: int, m: int) -> void:
		hud.set_ammo(a, m, String(weapons.current_config()["name"]), weapons.is_reloading)
	)
	weapons.hit_confirmed_editorial.connect(_on_local_hit_confirmed)
	hud.set_ammo(weapons.ammo, int(weapons.current_config()["mag_size"]), String(weapons.current_config()["name"]), false)
	
	# Player damage & death hooks
	player.damaged.connect(_on_player_damaged)
	player.died.connect(_on_dead)
	player.respawned.connect(func() -> void: hud.set_dead(false, 0))
	
	# Bots system (offline / mixed combatants)
	bots = BotMgrScript.new()
	bots.name = "Bots"
	world.add_child(bots)
	bots.target_count = 7 if GameState.practice_mode else 0
	bots.setup(player, spawns)
	bots.bot_eliminated.connect(_on_bot_eliminated)
	
	# Multiplayer entities
	mp = MultiplayerScript.new()
	mp.name = "Multiplayer"
	world.add_child(mp)
	mp.setup(net, world, GameState.username)
	if not GameState.practice_mode:
		net.connect_to(GameState.username, GameState.room_id if not GameState.room_id.is_empty() else "industrial-public", GameState.server_host)
	
	phase = Phase.PLAYING
	hud.visible = true
	hud.update_player_header(GameState.username, GameState.local_team, GameState.selected_mode)
	_capture_mouse()
	hud.feed("Deployed to %s [%s]" % [GameState.selected_map.to_upper(), GameState.selected_mode], Color(0.2, 0.9, 0.4))

func _input(event: InputEvent) -> void:
	if phase == Phase.MENU:
		return
	if phase == Phase.PLAYING and not hud.is_board_visible() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and event is InputEventMouseButton and event.pressed:
		_capture_mouse()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and phase == Phase.PLAYING:
		var mm := event as InputEventMouseMotion
		if current_driven_jeep != null:
			current_driven_jeep.apply_aim_input(mm.relative.x, mm.relative.y)
		else:
			player.apply_look(mm.relative.x, mm.relative.y, weapons.ads_amount if weapons else 0.0)
	if event.is_action_pressed("pause"):
		if hud.is_board_visible():
			_toggle_scoreboard()
			return
		_toggle_pause()
	if event.is_action_pressed("scoreboard"):
		_toggle_scoreboard()
		return
	if GameState.practice_mode and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		GameState.toggle_bot_damage()
		Audio.ui_btn_click()
		if GameState.bot_damage_enabled:
			hud.feed(" Combat Mode: Bot Damage Enabled", Color(1.0, 0.45, 0.25))
		else:
			hud.feed(" Peaceful Mode: Bot Damage OFF — Walk & Drive in Peace!", Color(0.3, 0.95, 0.4))
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_F3 or event.physical_keycode == KEY_F3):
		var on = GameState.toggle_vsync()
		Audio.ui_btn_click()
		hud.feed(" V-Sync: %s" % ("ENABLED (Locked to Screen Refresh)" if on else "DISABLED (Uncapped Full Hardware FPS)"), Color(0.4, 0.9, 1.0))
		return
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_E or event.physical_keycode == KEY_E)):
		get_viewport().set_input_as_handled()
		_handle_vehicle_interact()
		return
	if phase != Phase.PLAYING:
		return
	if current_driven_jeep != null:
		if event is InputEventKey and event.pressed and not event.echo:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if code == KEY_1:
				get_viewport().set_input_as_handled()
				current_driven_jeep.shift_gear(1)
				return
			elif code == KEY_2:
				get_viewport().set_input_as_handled()
				current_driven_jeep.shift_gear(2)
				return
			elif code == KEY_C or event.is_action_pressed("crouch"):
				get_viewport().set_input_as_handled()
				current_driven_jeep.toggle_camera_view()
				return
		return
	if event.is_action_pressed("inspect") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I):
		if weapons and weapons.has_method("start_inspect"):
			weapons.start_inspect()
	if event.is_action_pressed("grenade") and not event.is_echo():
		_grenade_aiming = _grenade_cd <= 0.0 and GameState.throwables_remaining > 0 and GameState.online_ready and not player.is_dead
	if event.is_action_released("grenade") and _grenade_aiming:
		_grenade_aiming = false
		_hide_grenade_preview()
		_throw_grenade()

func _toggle_scoreboard() -> void:
	if hud.is_board_visible():
		hud.hide_board()
		if phase == Phase.PLAYING:
			_capture_mouse()
	else:
		hud.show_board(get_full_scoreboard_roster(), GameState.username)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_scoreboard_closed() -> void:
	if phase == Phase.PLAYING:
		_capture_mouse()

func _handle_vehicle_interact() -> void:
	if phase != Phase.PLAYING: return
	if current_driven_jeep != null:
		if GameState.practice_mode: _exit_combat_jeep(current_driven_jeep)
		else: net.send_vehicle_seat("", false)
		return
	if not is_instance_valid(player) or player.is_dead:
		return
	var nearest_jeep = null
	var min_d := 4.8
	for j in get_tree().get_nodes_in_group("combat_jeeps"):
		if is_instance_valid(j) and not j.is_destroyed:
			var d: float = player.global_position.distance_to(j.global_position)
			if d < min_d:
				min_d = d
				nearest_jeep = j
	if nearest_jeep:
		if GameState.practice_mode: _enter_combat_jeep(nearest_jeep)
		elif String(nearest_jeep.get_meta("server_driver", "")).is_empty(): net.send_vehicle_seat(String(nearest_jeep.get_meta("server_vehicle_id", "")), true)
		else: hud.feed("Vehicle is occupied.", WarUI.MUTED)

func _enter_combat_jeep(jeep) -> void:
	if jeep == null or jeep.is_destroyed:
		return
	current_driven_jeep = jeep
	player.global_position = jeep.global_position
	player.set_driving(true)
	if is_instance_valid(weapons):
		weapons.visible = false
	jeep.enter_vehicle(player)
	if not GameState.practice_mode: jeep.freeze = true
	hud.set_vehicle_prompt(false)
	hud.set_vehicle_active(true)
	hud.feed("Mounted Armored Combat Van", Color(0.3, 0.9, 1.0))

func _exit_combat_jeep(jeep) -> void:
	if jeep == null:
		return
	var exit_pos: Vector3 = jeep.global_position - jeep.global_transform.basis.x * 2.4 + Vector3.UP * 0.25
	jeep.exit_vehicle()
	current_driven_jeep = null
	if is_instance_valid(player):
		player.global_position = exit_pos
		player.set_driving(false)
		if is_instance_valid(player.camera):
			player.camera.make_current()
	if is_instance_valid(weapons):
		weapons.visible = true
	hud.set_vehicle_active(false)

func _toggle_pause() -> void:
	if phase == Phase.PLAYING:
		phase = Phase.PAUSED
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.set_paused(true)
	elif phase == Phase.PAUSED:
		phase = Phase.PLAYING
		get_tree().paused = false
		_capture_mouse()
		hud.set_paused(false)

func _quit_to_menu() -> void:
	_grenade_aiming = false
	_hide_grenade_preview()
	_grenade_preview.clear()
	get_tree().paused = false
	if current_driven_jeep != null:
		current_driven_jeep.exit_vehicle()
		current_driven_jeep = null
	net.disconnect_from()
	if mp:
		mp.clear()
	if is_instance_valid(bots):
		bots.clear()
	if is_instance_valid(weapons):
		weapons.clear()
	for child in world.get_children():
		child.queue_free()
		
	player = null
	weapons = null
	bots = null
	mp = null
	map_builder = null
	hud.visible = false
	hud.set_paused(false)
	hud.set_dead(false, 0)
	hud.hide_board()
	menu.visible = true
	phase = Phase.MENU
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _grenade_launch() -> Dictionary:
	var cam: Camera3D = player.camera
	var dir := -cam.global_transform.basis.z.normalized()
	var pos := cam.global_position + dir * 0.35 + cam.global_transform.basis.x * 0.16 - cam.global_transform.basis.y * 0.12
	# Clip the hand's release point against cover rather than spawning through it.
	var space := player.get_world_3d().direct_space_state
	var obstruction := GrenadeFlight.sweep(space, cam.global_position, pos)
	if not obstruction.is_empty():
		pos = cam.global_position.lerp(pos, maxf(0.0, float(obstruction.fraction) - 0.08))
	return {"position":pos, "velocity":GrenadeFlight.launch_velocity(dir, player.velocity)}

func _hide_grenade_preview() -> void:
	for marker in _grenade_preview:
		if is_instance_valid(marker): marker.visible = false

func _update_grenade_preview(delta: float) -> void:
	if not _grenade_aiming: return
	if phase != Phase.PLAYING or not is_instance_valid(player) or player.is_dead or current_driven_jeep != null or hud.is_board_visible() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_grenade_aiming = false
		_hide_grenade_preview()
		return
	_grenade_preview_t -= delta
	if _grenade_preview_t > 0.0: return
	_grenade_preview_t = 0.08
	if _grenade_preview.is_empty():
		var mesh := SphereMesh.new()
		mesh.radius = 0.045
		mesh.height = 0.09
		mesh.radial_segments = 8
		mesh.rings = 4
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("e5c17c")
		for i in 30:
			var marker := MeshInstance3D.new()
			marker.mesh = mesh
			marker.material_override = material
			marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			world.add_child(marker)
			_grenade_preview.append(marker)
	_hide_grenade_preview()
	var launch := _grenade_launch()
	var at: Vector3 = launch.position
	var velocity: Vector3 = launch.velocity
	var space := player.get_world_3d().direct_space_state
	var marker_index := 0
	# Preview the first flight and impact, not an uncertain sequence of bounces.
	for i in 90:
		var result := GrenadeFlight.step(space, at, velocity, 1.0 / 30.0, true)
		at = result.position
		velocity = result.velocity
		if i % 3 == 0 or result.contact:
			var marker := _grenade_preview[mini(marker_index, _grenade_preview.size() - 1)]
			marker.global_position = at
			marker.scale = Vector3.ONE * (2.5 if result.contact else 1.0)
			marker.visible = true
			marker_index += 1
		if result.contact: break

func _throw_grenade() -> void:
	if _grenade_cd > 0.0 or GameState.throwables_remaining <= 0 or player.is_dead or not GameState.online_ready:
		return
	_grenade_cd = 1.0
	GameState.throwables_remaining -= 1
	player.end_spawn_protection()
	Audio.grenade_pin()
	if weapons and weapons.has_method("play_grenade_throw"):
		weapons.play_grenade_throw()
	if player and player.has_method("apply_recoil"):
		player.apply_recoil(0.04, randf_range(-0.02, 0.02))
		
	var cam: Camera3D = player.camera
	var launch := _grenade_launch()
	var pos: Vector3 = launch.position
	var vel: Vector3 = launch.velocity
	var spin: Vector3 = Vector3(randf_range(16.0, 24.0), randf_range(-8.0, 8.0), randf_range(-6.0, 6.0))
	if GameState.practice_mode:
		spawn_grenade(pos, vel, spin, GameState.selected_throwable)
	_spawn_spoon_fly(pos, cam.global_transform.basis.x * 2.8 + Vector3.UP * 2.2 + (player.velocity * 0.3 if player else Vector3.ZERO))
	net.send_grenade(pos, vel, GameState.selected_throwable)

func _spawn_spoon_fly(pos: Vector3, vel: Vector3) -> void:
	if not is_instance_valid(world):
		return
	var spoon := RigidBody3D.new()
	spoon.collision_layer = 0 # Cosmetic debris must not obstruct aiming or projectiles.
	spoon.collision_mask = 1
	spoon.mass = 0.04
	spoon.linear_velocity = vel
	spoon.angular_velocity = Vector3(randf_range(15.0, 30.0), randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.015, 0.08, 0.006)
	col.shape = bs
	spoon.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bs.size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.30, 0.22)
	mat.metallic = 0.75
	mat.roughness = 0.4
	mi.material_override = mat
	spoon.add_child(mi)
	world.add_child(spoon)
	spoon.global_position = pos + Vector3(0, 0.05, 0)
	var tw := get_tree().create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(spoon.queue_free)

func spawn_grenade(pos: Vector3, vel: Vector3, spin: Vector3 = Vector3.ZERO, kind: String = "frag") -> WarGrenade:
	return WarGrenade.throw(world, pos, vel, spin, kind)

func remote_shoot_fx(origin: Vector3, hit: Vector3, normal: Vector3, wall: bool, weapon_id: String = "ak47") -> void:
	if weapons:
		weapons._spawn_tracer(origin, hit, weapon_id)
		if wall:
			weapons.queue_impact(hit, normal if normal.length() > 0.01 else Vector3.UP, origin.distance_to(hit) / float(weapons.MUZZLE_SPEEDS.get(weapon_id, 715.0)))
	var distance_to_shot := player.global_position.distance_to(origin) if is_instance_valid(player) else 50.0
	Audio.shoot(weapon_id, clampf(-distance_to_shot * 0.45, -28.0, -3.0))

func bot_shoot_fx(from: Vector3, to: Vector3) -> void:
	if weapons:
		weapons._spawn_tracer(from, to)
	Audio.shoot("ak47")

func _on_local_hit_confirmed(_target: String, _damage: int, is_kill: bool, is_headshot: bool) -> void:
	if not GameState.practice_mode:
		return
	hud.flash_hitmarker(is_kill, is_headshot)
	Audio.hitmarker(is_kill)

func get_full_scoreboard_roster() -> Dictionary:
	var roster: Dictionary = GameState.players.duplicate()
	roster[GameState.username] = {
		"name": GameState.username,
		"kills": GameState.local_kills,
		"deaths": GameState.local_deaths,
		"health": int(player.health) if is_instance_valid(player) else 0,
		"team": GameState.local_team
	}
	if bots and bots.has_method("get_roster_dict"):
		var b_roster: Dictionary = bots.get_roster_dict()
		for bname in b_roster.keys():
			roster[bname] = b_roster[bname]
	return roster

func _on_bot_eliminated(bot_name: String, killer: String, is_headshot: bool, source: String) -> void:
	if killer == "OPERATOR" or killer == GameState.username or killer.begins_with("OPERATOR"):
		GameState.record_local_kill()
		if source == "grenade":
			hud.feed("You eliminated %s + GRENADE" % bot_name, Color(1.0, 0.5, 0.1))
		elif source == "roadkill":
			hud.feed("ROADKILL: %s + VEHICLE" % bot_name, Color(1.0, 0.25, 0.2))
		else:
			hud.feed("You eliminated %s%s" % [bot_name, " + HEADSHOT" if is_headshot else ""], Color(0.2, 1.0, 0.4))
		if GameState.selected_mode == "TDM":
			GameState.score_a += 1
	else:
		hud.feed("%s was eliminated" % bot_name, Color(0.8, 0.8, 0.8))

func _on_player_damaged(attacker_dir: Vector3, amount: float) -> void:
	hud.show_damage_blood(amount)
	if is_instance_valid(player): player.apply_recoil(minf(0.025, amount * 0.0005), 0.0)
	if attacker_dir != Vector3.ZERO and is_instance_valid(player):
		var rel := player.global_transform.basis.inverse() * attacker_dir
		hud.add_damage_indicator(rel)

func _on_state(state: Dictionary) -> void:
	if not GameState.practice_mode and int(state.get("protocol_version", 0)) != 5:
		net.disconnect_from()
		hud.feed("Game updated. Refresh the page or reopen the latest build.", Color(1, 0.4, 0.3))
		return
	var server_map := String(state.get("map_name", ""))
	if not GameState.practice_mode and not server_map.is_empty() and server_map != GameState.selected_map:
		_quit_to_menu()
		menu._show_toast("Room map changed. Select the room again.", false)
		return
	var server_time := String(state.get("time_of_day", GameState.selected_time))
	if server_time != GameState.selected_time:
		GameState.selected_time = server_time
		if is_instance_valid(map_builder): map_builder.apply_time_of_day(server_time)
	GameState.selected_mode = String(state.get("room_mode", GameState.selected_mode))
	var me: Dictionary = (state.get("players", {}) as Dictionary).get(GameState.username, {})
	_apply_online_vehicles(state.get("vehicles", {}), me)
	if not me.is_empty():
		if weapons and not GameState.practice_mode:
			weapons.reconcile_ammo(me)
		GameState.online_ready = true
		hud.set_connection_status("")
		GameState.throwables_remaining = int(me.get("grenades", 2))
		var remote_hp := int(me.get("health", 100))
		# A respawn event and an older death snapshot can share a delivery batch.
		# Once waiting for respawn, an authoritative living snapshot also restores
		# the client, rather than leaving the death screen latched indefinitely.
		if is_instance_valid(player) and player.is_dead and player.get_meta("respawn_requested", false) and not bool(me.get("is_dead", false)) and remote_hp > 0:
			_on_net_respawn(Vector3(float(me.get("x", 0)), float(me.get("y", 0)), float(me.get("z", 0))) + Vector3.UP * 0.2)
		if not GameState.practice_mode and is_instance_valid(player) and not player.is_dead and not player.is_driving:
			var sequence := int(me.get("ack_input_sequence",0))
			var acknowledged = net.take_acknowledged_position(sequence)
			if acknowledged is Vector3 and sequence > _reconcile_after_sequence:
				var authoritative_pos := Vector3(float(me.get("x",0)),float(me.get("y",0)),float(me.get("z",0)))
				var error: Vector3 = authoritative_pos - acknowledged
				if error.length() > 0.35:
					_network_correction_count += 1
					if _network_correction_count >= 3:
						# Rebase from the acknowledged input, retaining later valid movement.
						var collision = player.move_and_collide(error, true)
						if collision or error.length() > 3.0: player.global_position = authoritative_pos
						else: player.global_position += error
						player.velocity = Vector3.ZERO
						player._step_active = false
						player.reset_physics_interpolation()
						_network_correction_count = 0
						_reconcile_after_sequence = net.input_sequence
				else: _network_correction_count = 0
		if is_instance_valid(player):
			if remote_hp < player.health and not player.is_dead:
				if Time.get_ticks_msec() - _last_damage_feedback_ms > 150: hud.add_damage_indicator(Vector3.ZERO)
				player.health = remote_hp
			elif not GameState.practice_mode and not player.is_dead:
				player.health = remote_hp
			elif player.is_dead:
				player.health = 0
		hud.set_health(int(player.health) if is_instance_valid(player) else 0)
		GameState.local_team = String(me.get("team", "A"))
		hud.update_player_header(GameState.username, GameState.local_team, GameState.selected_mode)
		if (bool(me.get("is_dead", false)) or (is_instance_valid(player) and player.health <= 0)) and is_instance_valid(player) and not player.is_dead:
			player.set_meta("network_dead", true)
			player.kill()
	hud.set_score(GameState.selected_mode, GameState.score_a, GameState.score_b, GameState.local_team, GameState.winner_id)
	hud.set_ping(net.current_ping)
	var finished := String(state.get("room_state", "PLAYING")) == "FINISHED"
	if _last_round_finished and not finished:
		GameState.reset_match_stats()
		hud.feed("New round", Color(0.4, 0.8, 0.65))
	_last_round_finished = finished
	if not String(state.get("winner", "")).is_empty() and _last_winner != String(state.get("winner", "")):
		_last_winner = String(state.get("winner", ""))
		hud.feed("WINNER: " + _last_winner, Color.YELLOW)
	if not finished:
		_last_winner = ""

func _apply_online_vehicles(vehicles: Dictionary, me: Dictionary) -> void:
	if GameState.practice_mode: return
	for id in vehicles:
		if not _online_vehicles.has(id): continue
		var vehicle = _online_vehicles[id]
		var snapshot: Dictionary = vehicles[id]
		var at: Vector3 = snapshot["pos"]
		if vehicle.global_position.distance_to(at) > 8: vehicle.global_position = at
		vehicle.network_position = at
		vehicle.network_yaw = float(snapshot.get("yaw", 0))
		vehicle.current_speed_kmh = absf(float(snapshot.get("speed", 0))) * 3.6
		vehicle.is_reversing = float(snapshot.get("speed", 0)) < 0
		vehicle.set_meta("server_driver", snapshot.get("driver", ""))
		vehicle.health = float(snapshot.get("health", 1200))
		vehicle.is_destroyed = vehicle.health <= 0
	var seat := String(me.get("driving_vehicle", ""))
	if not seat.is_empty() and _online_vehicles.has(seat) and current_driven_jeep != _online_vehicles[seat]:
		_enter_combat_jeep(_online_vehicles[seat])
	elif seat.is_empty() and current_driven_jeep != null:
		_exit_combat_jeep(current_driven_jeep)
		player.global_position = Vector3(float(me.get("x", 0)), float(me.get("y", 0)), float(me.get("z", 0)))

func _on_damage_effect(target: String, pos: Vector3, direction: Vector3, amount: int) -> void:
	if phase == Phase.MENU or not is_instance_valid(weapons): return
	weapons.spawn_blood(pos, direction, clampf(amount / 30.0, 0.75, 2.0))
	if target == GameState.username and is_instance_valid(player):
		_last_damage_feedback_ms = Time.get_ticks_msec()
		_on_player_damaged(-direction, float(amount))
		Audio.hurt()
	elif mp and mp.remotes.has(target):
		mp.remotes[target].react_to_hit()

func _on_hit_confirmed() -> void:
	hud.flash_hitmarker(false)
	Audio.hitmarker(false)

func _on_kill_confirmed() -> void:
	hud.flash_hitmarker(true)
	Audio.hitmarker(true)
	hud.feed("Enemy eliminated", Color.RED)
	GameState.record_local_kill()

func _on_conn(connected_now: bool) -> void:
	if phase == Phase.MENU or GameState.practice_mode:
		return
	if connected_now:
		hud.set_connection_status("Synchronizing match…")
		net.send_loadout(GameState.selected_primary, GameState.selected_secondary, GameState.selected_throwable)
		if weapons:
			net.send_switch(String(weapons.current_config()["id"]))
	else:
		GameState.online_ready = false
		hud.set_connection_status("Connection interrupted. Reconnecting…")

func _on_net_respawn(pos: Vector3) -> void:
	_reconcile_after_sequence = net.input_sequence
	_network_correction_count = 0
	net._sent_positions.clear()
	_do_respawn(pos - Vector3(0, 0.2, 0))
	if weapons:
		net.send_switch(String(weapons.current_config()["id"]))

func spawn_death_blood(at: Vector3) -> void:
	if is_instance_valid(weapons): weapons.spawn_death_blood(at)

func _on_dead() -> void:
	if is_instance_valid(player): spawn_death_blood(player.global_position)
	if current_driven_jeep != null:
		_exit_combat_jeep(current_driven_jeep)
	if is_instance_valid(sway_root): sway_root.visible = false
	hud.set_health(0)
	phase = Phase.DEAD
	_respawn_t = 3.0
	_next_respawn_request_ms = 0
	hud.set_dead(true, 3)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.record_local_death()

func _do_respawn(pos: Vector3) -> void:
	if not is_instance_valid(player):
		return
	player.set_meta("network_dead", false)
	player.set_meta("respawn_requested", false)
	GameState.throwables_remaining = 2
	player.heal_full()
	player.respawn_at(pos)
	if GameState.selected_map in ["resoforge", "football"]: player.yaw = atan2(pos.x, pos.z)
	if is_instance_valid(weapons):
		weapons.reset_after_respawn()
		hud.set_ammo(weapons.ammo, int(weapons.current_config()["mag_size"]), String(weapons.current_config()["name"]), false)
	if is_instance_valid(sway_root): sway_root.visible = true
	phase = Phase.PLAYING
	hud.set_dead(false, 0)
	hud.set_health(100)
	_capture_mouse()

func _process(delta: float) -> void:
	_grenade_cd = maxf(0.0, _grenade_cd - delta)
	_update_grenade_preview(delta)
	if phase == Phase.MENU:
		if _autotest and _test_stage == 0:
			_test_stage = -1
			_test_t = 0.0
			_on_deploy()
		return
		
	if phase == Phase.DEAD:
		_respawn_t -= delta
		hud.set_dead(true, int(maxf(_respawn_t, 0.0)))
		# Sync death state to server so remote clients render death animation
		_send_acc += delta
		if _send_acc >= 1.0 / 20.0 and net.connected and is_instance_valid(player):
			_send_acc = 0.0
			var basis := Basis(Quaternion(Vector3.UP, player.yaw))
			var wep_id := GameState.weapon_id_for_index(weapons.active_index) if weapons else "ak47"
			net.send_state(player.global_position, Quaternion(basis), "death", wep_id)
			
		if _respawn_t <= 0.0:
			if net.connected:
				if not player.get_meta("respawn_requested", false) or Time.get_ticks_msec() >= _next_respawn_request_ms:
					net.send_respawn()
					player.set_meta("respawn_requested", true)
					_next_respawn_request_ms = Time.get_ticks_msec() + 1000

			else:
				var sp: Vector3 = map_builder.spawn_points[randi() % map_builder.spawn_points.size()] if map_builder and not map_builder.spawn_points.is_empty() else Vector3(randf_range(-15, 15), 1.0, randf_range(-15, 15))
				_do_respawn(sp)
		if _autotest:
			_autotest_tick(delta)
		return
		
	if phase != Phase.PLAYING or player == null:
		return
		
	# HUD live values
	hud.set_health(int(player.health))
	hud.set_crosshair(weapons.spread if weapons else 1.5, weapons.ads_amount if weapons else 0.0)
	var optic_active := weapons and weapons.ads_amount > 0.65 and (weapons.get_current_scope_zoom() > 1 or String(weapons.current_config()["id"]) in ["m4", "mp5"])
	var optic_weight := smoothstep(0.65, 0.88, weapons.ads_amount) if weapons else 0.0
	if weapons:
		hud.set_scope_magnification(weapons.get_current_scope_zoom(), String(weapons.current_config()["id"]) in ["m4", "mp5"])
		hud.scope_overlay.field_of_view = player.camera.fov
		hud.scope_overlay.sniper = weapons.is_scoped()
	hud.set_scope(optic_active, optic_weight)
	if optic_active:
		hud.update_scope_steady(weapons.is_holding_breath, weapons.breath_stamina, rad_to_deg(player.yaw))
	hud.set_ammo(weapons.ammo, int(weapons.current_config()["mag_size"]), String(weapons.current_config()["name"]), weapons.is_reloading)
	
	# Vehicle driving and telemetry loop
	if current_driven_jeep != null:
		if current_driven_jeep.is_destroyed:
			_exit_combat_jeep(current_driven_jeep)
		else:
			hud.set_vehicle_stats(
				current_driven_jeep.current_speed_kmh,
				current_driven_jeep.current_gear,
				current_driven_jeep.health,
				current_driven_jeep.max_health,
				current_driven_jeep.is_reversing
			)
			player.global_position = current_driven_jeep.global_position
	else:
		var nearby_jeep = null
		for j in get_tree().get_nodes_in_group("combat_jeeps"):
			if is_instance_valid(j) and not j.is_destroyed and j.is_player_nearby(player):
				nearby_jeep = j
				break
		hud.set_vehicle_prompt(nearby_jeep != null)

	# Movement and vehicle input at 30 Hz; rendering/physics remain independent.
	_send_acc += delta
	if _send_acc >= 1.0 / 30.0:
		_send_acc = 0.0
		if current_driven_jeep != null:
			player.global_position = current_driven_jeep.global_position
			if not GameState.practice_mode:
				net.send_vehicle_input(Input.get_axis("move_back", "move_forward"), Input.get_axis("move_left", "move_right"), Input.is_action_pressed("jump"), current_driven_jeep.current_gear)
		else:
			var moving := Input.is_action_pressed("move_forward") or Input.is_action_pressed("move_back") or Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right")
			var anim := "idle"
			if player.is_dead:
				anim = "death"
			elif weapons.is_firing and moving:
				anim = "firing walk"
			elif weapons.is_firing:
				anim = "firing"
			elif moving:
				anim = "run"
			var basis := Basis(Quaternion(Vector3.UP, player.yaw))
			var wep_id := GameState.weapon_id_for_index(weapons.active_index) if weapons else "ak47"
			net.send_state(player.global_position, Quaternion(basis), anim, wep_id)
		
	if _autotest:
		_autotest_tick(delta)

func _autotest_tick(delta: float) -> void:
	_test_t += delta
	# proto roundtrip
	if _test_stage == -1 and _test_t > 0.5:
		_test_stage = 1
		_test_t = 0.0
		var fe := WarProto._strf(1, "BOT_1")
		for i in range(2, 11):
			fe += WarProto._f32f(i, float(i))
		fe += WarProto._boolf(11, true)
		var dec := WarProto.decode_server(WarProto._len(2, WarProto._len(2, fe)))
		print("AUTOTEST: server fire decode kind=", dec.get("kind", "?"), " shooter=", dec.get("shooter", "?"), " wall=", dec.get("wall", false))
		var st := WarProto.encode_state(1, 2, 3, 0, 0, 0, 1, "run", 42, "ak47")
		print("AUTOTEST: state bytes=", st.size())
		
	elif _test_stage == 1 and _test_t > 0.8:
		_test_stage = 2
		_test_t = 0.0
		Input.action_press("move_forward")
		print("AUTOTEST: moving forward, pos=", player.global_position)
		
	elif _test_stage == 2 and _test_t > 1.0:
		_test_stage = 3
		_test_t = 0.0
		Input.action_release("move_forward")
		print("AUTOTEST: moved to ", player.global_position)
		weapons.try_fire()
		print("AUTOTEST: fired, ammo=", weapons.ammo, " tracers_active=", weapons._tracers.filter(func(t: Dictionary) -> bool: return t["active"]).size())
		
	elif _test_stage == 3 and _test_t > 0.5:
		_test_stage = 4
		_test_t = 0.0
		var orig_pitch = player.camera.rotation.x
		player.camera.rotation.x = deg_to_rad(30)
		_throw_grenade()
		player.camera.rotation.x = orig_pitch
		print("AUTOTEST: grenade thrown, bots=", bots.bots.size())
		
	elif _test_stage == 4 and _test_t > 1.2:
		_test_stage = 5
		_test_t = 0.0
		var b = bots.bots[0] if not bots.bots.is_empty() else null
		if b:
			b.take_damage(34.0, "torso")
			print("AUTOTEST: bot damaged hp=", b.health)
			b.take_damage(200.0, "head")
			print("AUTOTEST: bot killed dead=", b.dead)
		GameState.set_bot_damage(true)
		player.take_bot_damage(25.0)
		GameState.set_bot_damage(false)
		assert(player.health == 75.0)
		print("AUTOTEST: player hp=", player.health)
		print("AUTOTEST: local kills=", GameState.local_kills)
		var r := get_full_scoreboard_roster()
		print("AUTOTEST: roster entries=", r.size(), " player_kills=", r.get(GameState.username, {}).get("kills", -1))
		hud.feed("AUTOTEST killfeed OK", Color.GREEN)
		
	elif _test_stage == 5 and _test_t > 1.2:
		_test_stage = 6
		_test_t = 0.0
		weapons.switch_weapon(1)
		print("AUTOTEST: switched to pistol ammo=", weapons.ammo)
		GameState.selected_secondary = "hmg"
		weapons.switch_weapon(3)
		print("AUTOTEST: switched to HMG ammo=", weapons.ammo, " name=", weapons.current_config()["name"])
		weapons.switch_weapon(0)
		print("AUTOTEST: back to AK ammo=", weapons.ammo)
		player.heal_full()
		GameState.set_bot_damage(false)
		var jeep = get_tree().get_first_node_in_group("combat_jeeps")
		if jeep:
			_enter_combat_jeep(jeep)
			print("AUTOTEST: vehicle entered! jeep_pos=", jeep.global_position, " vel=", jeep.linear_velocity)
			Input.action_press("move_forward")
		else:
			print("AUTOTEST: no jeep found on map")
			
	elif _test_stage == 6 and _test_t > 2.0:
		_test_stage = 7
		_test_t = 0.0
		Input.action_release("move_forward")
		if current_driven_jeep:
			# Test gear shifting: starts in Gear 1 (top speed 52)
			assert(current_driven_jeep.current_gear == 1)
			assert(current_driven_jeep.get_top_speed() == 52.0)
			current_driven_jeep.shift_gear(2)
			assert(current_driven_jeep.current_gear == 2)
			assert(current_driven_jeep.get_top_speed() == 115.0)
			current_driven_jeep.shift_gear(1)
			assert(current_driven_jeep.current_gear == 1)
			assert(current_driven_jeep.get_top_speed() == 52.0)
			print("AUTOTEST: vehicle transmission verified! Gear 1=52km/h (climb), Gear 2=115km/h (speed)")
			# Test C key view toggle (Close 3rd Person <-> Wide 3rd Person)
			assert(current_driven_jeep.is_wide_view == false)
			current_driven_jeep.toggle_camera_view()
			print("AUTOTEST: vehicle toggled to wide 3rd person chase! is_wide=", current_driven_jeep.is_wide_view, " spring_len=", current_driven_jeep.chase_spring_arm.spring_length)
			assert(current_driven_jeep.is_wide_view == true)
			current_driven_jeep.toggle_camera_view()
			print("AUTOTEST: vehicle toggled back to normal 3rd person chase! is_wide=", current_driven_jeep.is_wide_view, " spring_len=", current_driven_jeep.chase_spring_arm.spring_length)
			assert(current_driven_jeep.is_wide_view == false)
			_exit_combat_jeep(current_driven_jeep)
			print("AUTOTEST: vehicle exited safely! player_pos=", player.global_position, " driving=", player.is_driving)
		# Test peaceful mode toggle
		_toggle_scoreboard()
		print("AUTOTEST: scoreboard open=", hud.is_board_visible(), " mouse_mode=", Input.mouse_mode)
		GameState.set_bot_damage(false)
		print("AUTOTEST: bot_damage_enabled=", GameState.bot_damage_enabled)
		var hp_before: float = player.health
		player.take_bot_damage(50.0)
		print("AUTOTEST: peaceful test hp_before=", hp_before, " hp_after=", player.health, " (damage prevented=", hp_before == player.health, ")")
		_toggle_scoreboard()
		print("AUTOTEST: scoreboard closed, mouse_mode=", Input.mouse_mode)
		assert(phase == Phase.PLAYING and not player.is_dead and player.health == 100.0)
		print("AUTOTEST: DONE pos=", player.global_position, " hp=", player.health, " phase=", phase, " fps=", Engine.get_frames_per_second(), " phys_ms=", Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		Audio.stop_all()
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().quit()
