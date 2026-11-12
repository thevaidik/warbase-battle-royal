extends SceneTree
## Full offline Main/Player/WeaponSystem/HUD smoke test for the drone game.

const FLIGHT_TICKS := 18
const BRAKE_TICKS := 72

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
	print("CHECK ", "PASS " if ok else "FAIL ", message)

func _physics_ticks(count: int) -> void:
	for _i in count:
		await physics_frame

func _hardware_visible_to_camera(node: Node, camera_mask: int) -> bool:
	var okay := true
	if node is VisualInstance3D:
		okay = ((node as VisualInstance3D).layers & camera_mask) != 0
	for child in node.get_children():
		okay = okay and _hardware_visible_to_camera(child, camera_mask)
	return okay

func _cancel_menu_network(main: Variant) -> void:
	if is_instance_valid(main.menu):
		main.menu.set_process(false)
		if is_instance_valid(main.menu._lobby_adapter):
			main.menu._lobby_adapter.stop()
		for request in main.menu.find_children("*", "HTTPRequest", true, false):
			(request as HTTPRequest).cancel_request()


func _test_physical_aim_parallax(main: Variant) -> void:
	var player = main.player
	var weapons = main.weapons
	player.global_position = Vector3(500.0, 100.0, 500.0)
	player.yaw = 0.0
	player.pitch = 0.0
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	await physics_frame
	player._process(1.0 / 60.0)
	var camera: Camera3D = player.camera
	var target_panel := StaticBody3D.new()
	var target_shape := CollisionShape3D.new()
	var target_box := BoxShape3D.new()
	target_box.size = Vector3(3.0, 3.0, 0.2)
	target_shape.shape = target_box
	target_panel.add_child(target_shape)
	main.world.add_child(target_panel)
	target_panel.global_position = player.global_position + Vector3(0.0, 0.43, -3.0)
	await physics_frame
	var aim_ray := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * 100.0, 1 | 4)
	aim_ray.exclude = [player.get_rid()]
	var aim_hit: Dictionary = main.world.get_world_3d().direct_space_state.intersect_ray(aim_ray)
	player._process(1.0 / 60.0)
	check(not aim_hit.is_empty() and aim_hit.collider == target_panel, "test target lies at the chase camera crosshair")
	if aim_hit.is_empty():
		target_panel.queue_free()
		return
	var muzzle: Vector3 = weapons._muzzle_global()
	var crosshair_target: Vector3 = aim_hit.position
	var drone_visual: Node = player.get("_drone_visual")
	var payload_gimbal: Node3D = drone_visual.get("_payload_gimbal")
	var gimbal_direction := -payload_gimbal.global_basis.z.normalized()
	check(gimbal_direction.dot((crosshair_target - payload_gimbal.global_position).normalized()) > 0.999,
		"local payload gimbal converges on the near crosshair target")
	var barrel_line_midpoint := muzzle.lerp(crosshair_target, 0.45)
	var cover := StaticBody3D.new()
	var cover_shape := CollisionShape3D.new()
	var cover_box := BoxShape3D.new()
	cover_box.size = Vector3(0.55, 0.10, 0.30)
	cover_shape.shape = cover_box
	cover.add_child(cover_shape)
	main.world.add_child(cover)
	cover.global_position = barrel_line_midpoint
	await physics_frame
	var cover_cam_ray := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * 100.0, 1 | 4)
	cover_cam_ray.exclude = [player.get_rid()]
	var cover_cam_hit: Dictionary = main.world.get_world_3d().direct_space_state.intersect_ray(cover_cam_ray)
	var muzzle_ray := PhysicsRayQueryParameters3D.create(muzzle, crosshair_target, 1 | 4)
	muzzle_ray.exclude = [player.get_rid()]
	var cover_muzzle_hit: Dictionary = main.world.get_world_3d().direct_space_state.intersect_ray(muzzle_ray)
	check(not cover_cam_hit.is_empty() and cover_cam_hit.collider == target_panel and not cover_muzzle_hit.is_empty() and cover_muzzle_hit.collider == cover,
		"close crosshair remains visible while the lower physical muzzle is blocked by cover")
	var capture_script: Script = load("res://scripts/tests/CapturingWarNetwork.gd")
	var capture = capture_script.new()
	capture.connected = true
	root.add_child(capture)
	var previous_net = weapons.net
	weapons.net = capture
	weapons._time = 10.0
	weapons._last_fire_by_mount.clear()
	weapons._switch_t = 1.0
	weapons._can_fire_semi = true
	weapons.is_reloading = false
	weapons.spread = 0.0
	weapons.try_fire()
	var wire_hit: Vector3 = cover_muzzle_hit.position
	var expected_dir := (crosshair_target - muzzle).normalized()
	var transmitted_dir := Vector3(-sin(float(capture.captured_fire.get("yaw", 0.0))), -sin(float(capture.captured_fire.get("pitch", 0.0))), -cos(float(capture.captured_fire.get("yaw", 0.0)))).normalized()
	var expected_yaw := atan2(-expected_dir.x, -expected_dir.z)
	var expected_pitch := -asin(clampf(expected_dir.y, -1.0, 1.0))
	check(not capture.captured_fire.is_empty() and capture.captured_fire.get("wall", false) and Vector3(capture.captured_fire.get("hit", Vector3.ZERO)).distance_to(wire_hit) < 0.01,
		"network shot reports the muzzle's cover hit while aiming through the crosshair target")
	check(absf(wrapf(float(capture.captured_fire.get("yaw", 0.0)) - expected_yaw, -PI, PI)) < 0.002 and absf(float(capture.captured_fire.get("pitch", 0.0)) - expected_pitch) < 0.002 and transmitted_dir.dot(expected_dir) > 0.9999,
		"wire positive-down yaw/pitch point from physical muzzle to the close crosshair target")
	check(absf(expected_pitch) > deg_to_rad(4.0), "close-range muzzle convergence corrects meaningful camera-to-barrel parallax")
	weapons.net = previous_net
	capture.queue_free()
	cover.queue_free()
	target_panel.queue_free()

func run() -> void:
	var game_state = root.get_node("GameState")
	game_state.practice_mode = true
	game_state.online_ready = false
	game_state.server_host = "offline-drone-smoke.invalid"
	game_state.selected_map = "industrial"
	game_state.selected_mode = "FFA"
	game_state.selected_drone_chassis = "heli"
	game_state.selected_primary = "ak47"
	game_state.selected_secondary = "pistol"
	game_state.bot_damage_enabled = false
	var main: Variant = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_cancel_menu_network(main)
	main.menu.visible = false
	main._start_match()
	await process_frame
	check(game_state.online_ready and game_state.practice_mode and not main.net.connected,
		"Main starts an offline practice scene without joining a room")
	check(is_instance_valid(main.player) and is_instance_valid(main.weapons) and is_instance_valid(main.hud) and main.hud.visible,
		"Main wires the drone, payload system, and HUD")
	check(main.player._col.shape is SphereShape3D and is_equal_approx((main.player._col.shape as SphereShape3D).radius, game_state.DRONE_RADIUS) and main.player._col.position.is_zero_approx(),
		"player collision is a centered R=0.4 m drone sphere")
	check(main.player.find_child("Armature", true, false) == null and main.player.find_child("Skeleton3D", true, false) == null and main.player.find_child("Soldier", true, false) == null,
		"local player has no human rig or soldier mesh")
	var drone_visual: Node = main.player.get("_drone_visual") as Node
	var local_payload: Node3D = drone_visual.call("get_payload") if is_instance_valid(drone_visual) else null
	check(main.player.camera.get_node_or_null("SwayRoot") == null, "camera has no first-person weapon nodes")
	check(is_instance_valid(local_payload) and local_payload.visible,
		"selected weapon is shown on the drone body as a physical payload")
	check(main.player.camera.global_position.distance_to(main.player.global_position) > 1.5,
		"chase camera sits behind the physical drone")
	var camera_wall := StaticBody3D.new()
	var camera_wall_shape := CollisionShape3D.new()
	var camera_wall_box := BoxShape3D.new()
	camera_wall_box.size = Vector3(4.0, 4.0, 0.2)
	camera_wall_shape.shape = camera_wall_box
	camera_wall.add_child(camera_wall_shape)
	main.world.add_child(camera_wall)
	camera_wall.global_position = main.player.global_position + Vector3(0, 0, 0.7)
	await physics_frame
	main.player._update_drone_chase_camera()
	check(main.player.camera.global_position.distance_to(main.player.global_position) < 0.8,
		"chase camera sweep retracts before a wall")
	check(not drone_visual.visible, "drone body hides when camera compresses into the hull")
	camera_wall.queue_free()
	await physics_frame
	main.player._update_drone_chase_camera()
	check(drone_visual.visible and main.player.camera.global_position.distance_to(main.player.global_position) > 1.5,
		"drone body and chase distance restore after clearing the wall")
	var payload_layer_ok: bool = true
	for weapon in game_state.WEAPONS:
		main.weapons.active_index = game_state.weapon_index_for_id(String(weapon["id"]))
		main.weapons._sync_drone_payload()
		await process_frame
		drone_visual = main.player.get("_drone_visual") as Node
		payload_layer_ok = payload_layer_ok and _hardware_visible_to_camera(drone_visual, main.player.camera.cull_mask)
	main.weapons.active_index = game_state.starting_weapon_index()
	main.weapons._sync_drone_payload()
	await process_frame
	local_payload = drone_visual.call("get_payload")
	check(payload_layer_ok and local_payload.visible,
		"body-mounted payload remains visible to the chase camera across weapon changes")
	var grenade_launch: Dictionary = main._grenade_launch()
	check((grenade_launch.position as Vector3).distance_to(main.player.global_position) <= 0.9,
		"grenades release beside the drone instead of from the chase camera")
	var current_muzzle: Vector3 = main.weapons._muzzle_global()
	check(current_muzzle.is_finite() and current_muzzle.distance_to(main.player.global_position) <= 0.9,
		"ballistics start at the physical payload muzzle close to the drone")
	await _test_physical_aim_parallax(main)
	check(not main.has_method("_handle_vehicle_interact") and not main.player.is_driving,
		"live drone match exposes no vehicle seat controls")
	main.player.velocity = Vector3.ZERO
	await physics_frame
	check(main.hud.health_label.text == "100" and main.hud.drone_telemetry_label.text.contains("ALT"),
		"HUD presents hull integrity and drone altitude/speed telemetry")

	var start_position: Vector3 = main.player.global_position
	Input.action_press("drone_up")
	await _physics_ticks(FLIGHT_TICKS)
	Input.action_release("drone_up")
	var climbed_to: float = main.player.global_position.y
	check(climbed_to > start_position.y + 0.2 and main.player.velocity.y > 0.0,
		"Space control produces continuous upward flight (%.2f to %.2f, vy %.2f)" % [start_position.y, climbed_to, main.player.velocity.y])
	await _physics_ticks(BRAKE_TICKS)
	check(absf(main.player.velocity.y) < 0.2,
		"releasing vertical input actively brakes the drone")
	var descent_start: float = main.player.global_position.y
	Input.action_press("drone_down")
	await _physics_ticks(FLIGHT_TICKS)
	Input.action_release("drone_down")
	var descended_to: float = main.player.global_position.y
	check(descended_to < descent_start - 0.2 and main.player.velocity.y < 0.0,
		"Ctrl control produces continuous downward flight")
	await _physics_ticks(BRAKE_TICKS)
	check(absf(main.player.velocity.y) < 0.2,
		"downward flight brakes smoothly after release")
	var horizontal_start: Vector3 = main.player.global_position
	Input.action_press("move_forward")
	await _physics_ticks(FLIGHT_TICKS)
	Input.action_release("move_forward")
	var horizontal_moved: float = main.player.global_position.distance_to(horizontal_start)
	await _physics_ticks(BRAKE_TICKS)
	check(horizontal_moved > 0.25 and Vector2(main.player.velocity.x, main.player.velocity.z).length() < 0.2,
		"WASD flight accelerates and then brakes to a hover")

	var expected_spawn := Vector3(8.0, 1.2, -6.0)
	var respawn_points: Array[Vector3] = [expected_spawn]
	main.map_builder.spawn_points = respawn_points
	main.player.kill()
	var effects := get_first_node_in_group("drone_combat_effects")
	check(is_instance_valid(main.player._crash_focus) and not main.player._drone_visual.visible,
		"local destruction leaves a separate wreck for the death camera")
	main.hud._open_drone_editor()
	check(main.hud.is_editing_drone(), "death screen opens the drone editor")
	main._respawn_t = 0.0
	main._process(0.001)
	check(main.player.is_dead, "cooldown can expire without closing the editor or respawning")
	# Edit preferences directly so the test does not write the user's saved settings.
	game_state.selected_drone_chassis = "tracked"
	game_state.selected_primary = "m4"
	game_state.selected_secondary = "aim9"
	main._request_redeployment()
	main._process(0.001)
	check(main.phase == 1 and main.player.global_position.is_equal_approx(expected_spawn + Vector3.UP * game_state.DRONE_SPAWN_OFFSET),
		"offline respawn places the sphere center at the requested spawn offset exactly once")
	check(main.player._col.position.is_zero_approx() and is_zero_approx(main.player.velocity.length()),
		"respawn restores the centered drone collision and zeroes flight velocity")
	check(not main.player.is_dead and main.player._drone_visual.get_payload().visible,
		"respawn restores a living drone with its payload visible")

	check(main.weapons.current_config()["id"] == "m4" and main.player._drone_visual.chassis_id == "tracked" and not main.hud.is_editing_drone(),
		"redeploy equips the edited chassis and payload and closes the editor")

	var remote: Node = load("res://scenes/RemotePlayer.tscn").instantiate()
	remote.set_meta("init_state", {"team": "B", "weapon": "ak47", "x": 0.0, "y": 8.0, "z": -8.0})
	main.world.add_child(remote)
	await process_frame
	for wire_pitch in [-0.7, 0.7]:
		remote.call("apply_sdk_pose", {"x": 0.0, "y": 8.0, "z": -8.0, "rx": 0.0, "ry": 0.0, "rz": 0.0, "rw": 1.0, "pitch": wire_pitch, "pose_time_ms": Time.get_ticks_msec()})
		var remote_visual: Node = remote.get("drone")
		var gimbal: Node3D = remote_visual.get("_payload_gimbal")
		var payload_forward := -gimbal.global_basis.z
		check(payload_forward.y > 0.5 if wire_pitch < 0.0 else payload_forward.y < -0.5,
			"remote gimbal follows server pitch sign %.1f" % wire_pitch)

	var prior_wrecks: int = effects._wrecks.size()
	var destroyed := {"x": 0.0, "y": 8.0, "z": -8.0, "is_dead": true}
	remote.call("push_state", destroyed)
	remote.call("push_state", destroyed)
	remote.call("apply_sdk_pose", destroyed)
	check(effects._wrecks.size() == prior_wrecks + 1 and not remote.get("drone").visible,
		"repeated multiplayer death states leave one wreck")
	remote.call("push_state", {"x": 0.0, "y": 8.0, "z": -8.0, "is_dead": false})
	check(remote.get("drone").visible, "multiplayer respawn restores the live model")

	for action in ["drone_up", "drone_down", "move_forward"]:
		Input.action_release(action)
	remote.queue_free()
	main._quit_to_menu()
	main.queue_free()
	await process_frame
	print("DRONE_SMOKE_TEST failures=", failures)
	quit(1 if failures > 0 else 0)
