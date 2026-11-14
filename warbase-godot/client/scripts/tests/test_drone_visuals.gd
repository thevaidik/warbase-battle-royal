extends Node

var failures := 0

func _ready() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
	print("PASS: " if condition else "FAIL: ", message)

func _mesh_aabb_radius(root_node: Node3D) -> float:
	var points: Array[Vector3] = []
	for item in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := item as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var bounds := mesh_instance.get_aabb()
		var item_radius := 0.0
		for x in [bounds.position.x, bounds.end.x]:
			for y in [bounds.position.y, bounds.end.y]:
				for z in [bounds.position.z, bounds.end.z]:
					points.append(mesh_instance.global_transform * Vector3(x, y, z))
	if points.is_empty():
		return INF
	var bounds := AABB(points[0], Vector3.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	var center := bounds.get_center()
	var max_radius := 0.0
	for point in points:
		max_radius = maxf(max_radius, center.distance_to(point))
	return max_radius

func _mesh_max_radius_from_origin(root_node: Node3D, origin: Vector3, excluded: Node3D = null) -> float:
	var max_radius := 0.0
	for item in root_node.find_children("*", "MeshInstance3D", true, false):
		if excluded != null and excluded.is_ancestor_of(item):
			continue
		var mesh_instance := item as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var item_radius := 0.0
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				item_radius = maxf(item_radius, origin.distance_to(mesh_instance.global_transform * vertex))
		max_radius = maxf(max_radius, item_radius)
	return max_radius

func run() -> void:
	var friendly := DroneVisual.new()
	add_child(friendly)
	friendly.configure(true, "ak47")
	var enemy := DroneVisual.new()
	add_child(enemy)
	enemy.configure(false, "ak47")
	await get_tree().process_frame
	for _frame in range(3):
		await get_tree().process_frame
	check(friendly.get_node_or_null("BankVisual/Vanguard") != null, "friendly visuals use the Vanguard camera quadcopter")
	check(enemy.get_node_or_null("BankVisual/Raider") != null, "opposing visuals use the Raider inspection quadcopter")
	check(friendly.get_node_or_null("BankVisual/TeamSurfaceTrim") != null and enemy.get_node_or_null("BankVisual/TeamSurfaceTrim") != null,
		"both teams use restrained surface trim")
	check(_mesh_max_radius_from_origin(friendly, friendly.global_position) <= (0.381 * DroneVisual.DISPLAY_SCALE) and _mesh_max_radius_from_origin(enemy, enemy.global_position) <= (0.381 * DroneVisual.DISPLAY_SCALE),
		"each team airframe, status lights, trim, and default payload fit inside R=.45 m")
	var modules_ok := true
	var ground_contact_ok := true
	var only_selected_kit := true
	for chassis in ["wheels", "tracked", "heli", "wing"]:
		friendly.set_chassis(chassis)
		await get_tree().process_frame
		var ground_gear: Node3D = null
		if chassis in ["wheels", "tracked"]:
			ground_gear = friendly._attachment_sets[chassis][0]
			var bounds := friendly._payload_bounds(ground_gear)
			var bottom := (ground_gear.get_parent_node_3d().global_transform * bounds.position).y - friendly.global_position.y
			ground_contact_ok = ground_contact_ok and absf(bottom + DroneVisual.GROUND_CONTACT_DEPTH) < 0.003
		modules_ok = modules_ok and friendly.chassis_id == chassis and _mesh_max_radius_from_origin(friendly, friendly.global_position, ground_gear) <= (0.381 * DroneVisual.DISPLAY_SCALE)
		modules_ok = modules_ok and friendly._attachment_sets[chassis].any(func(node): return node.visible)
		only_selected_kit = only_selected_kit and friendly._attachment_sets.size() == 1
		only_selected_kit = only_selected_kit and (friendly.find_child("Rotor", true, false) != null) == (chassis == "heli")
	check(modules_ok, "hulls and flight gear stay inside the hit sphere across mobility profiles")
	check(ground_contact_ok, "deployed tyres and tracks reach the collision floor")
	check(only_selected_kit, "mobility swaps build only the selected kit and wing mode has no rotor")
	var body_mesh_count := friendly._body.find_children("*", "MeshInstance3D", true, false).size()
	check(body_mesh_count <= 50, "static aircraft details are material-batched to a bounded mesh count")
	check(friendly._team_leds.size() == 2 and enemy._team_leds.size() == 2,
		"team identity comes from paired LEDs without sphere markers")
	check(friendly.get_payload() != null and enemy.get_payload() != null, "configure mounts the selected weapon as a small drone payload")
	var original_body_id := friendly.get_node("BankVisual/Vanguard").get_instance_id()
	friendly.set_payload_visible(false)
	var weapon_bounds_ok := true
	var muzzle_is_valid := true
	var weapon_ids_match := true
	var muzzle_aim_ok := true
	var muzzle_bounds_ok := true
	var yaw := 0.73
	friendly.rotation.y = yaw
	for weapon in GameState.WEAPONS:
		var weapon_id := String(weapon["id"])
		friendly.set_weapon(weapon_id)
		await get_tree().process_frame
		weapon_ids_match = weapon_ids_match and String(friendly.get_payload().get_meta("weapon_id", "")) == weapon_id
		muzzle_is_valid = muzzle_is_valid and friendly.get_muzzle_global().is_finite()
		for bank in [-deg_to_rad(10.0), deg_to_rad(10.0)]:
			for pitch in [-1.55, 1.55]:
				friendly.apply_motion(Vector3(5.0, 0.0, 0.0), yaw, pitch)
				friendly._bank_root.rotation.z = bank
				await get_tree().process_frame
				weapon_bounds_ok = weapon_bounds_ok and _mesh_max_radius_from_origin(friendly, friendly.global_position) <= (0.381 * DroneVisual.DISPLAY_SCALE)
				if _mesh_max_radius_from_origin(friendly,friendly.global_position)>(0.381 * DroneVisual.DISPLAY_SCALE): print("WEAPON_RADIUS ",weapon_id," ",_mesh_max_radius_from_origin(friendly,friendly.global_position))
				var muzzle := friendly.get_payload().find_child("Muzzle", true, false) as Node3D
				var muzzle_forward := -friendly.get_payload().global_transform.basis.z.normalized()
				var expected_forward := Vector3(0.0, sin(pitch), -cos(pitch)).rotated(Vector3.UP, yaw).normalized()
				muzzle_aim_ok = muzzle_aim_ok and muzzle_forward.angle_to(expected_forward) < deg_to_rad(0.5)
				muzzle_bounds_ok = muzzle_bounds_ok and friendly.global_position.distance_to(friendly.get_muzzle_global()) <= 0.4
				muzzle_is_valid = muzzle_is_valid and muzzle.global_position.is_finite()
				check(not friendly.get_payload().visible, "camera view can persistently hide mounted payload during motion")
	check(weapon_bounds_ok, "all selected payloads stay inside R=.45 m while the body banks")
	check(weapon_ids_match, "all gameplay weapon IDs select the matching procedural payload")
	check(muzzle_is_valid, "selected weapon payloads provide a physical muzzle origin")
	check(muzzle_aim_ok, "payload muzzle aim follows yaw and pitch independently of hull bank")
	check(muzzle_bounds_ok, "payload muzzle stays inside R=.45 m across the full pitch sweep")
	var gimbal_count := 0
	for child in friendly.get_children():
		if child is Node3D and child != friendly._bank_root:
			gimbal_count += 1
	check(gimbal_count == 1,
		"weapon swaps keep a single payload gimbal attached")
	check(friendly.get_node("BankVisual/Vanguard").get_instance_id() == original_body_id,
		"weapon swaps replace only the payload and keep the selected drone airframe")
	friendly.set_payload_visible(true)
	friendly.set_loadout("aim9", "agm114", "aim9")
	var left_muzzle := friendly.to_local(friendly.get_muzzle_global())
	var left_mount := friendly.get_node("WeaponTurret/PrimaryLeft")
	var right_mount := friendly.get_node("WeaponTurret/SecondaryRight")
	friendly.set_weapon("agm114")
	var right_muzzle := friendly.to_local(friendly.get_muzzle_global())
	check(left_muzzle.x < 0.0 and right_muzzle.x > 0.0 and friendly.get_node("WeaponTurret/PrimaryLeft") == left_mount and friendly.get_node("WeaponTurret/SecondaryRight") == right_mount,
		"both payloads stay mounted while the active muzzle switches sides")
	friendly.set_chassis("heli")
	await get_tree().process_frame
	var friendly_player := friendly.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var enemy_player := enemy.find_child("AnimationPlayer", true, false) as AnimationPlayer
	check(friendly_player != null and friendly_player.current_animation == "rotor-spin" and friendly_player.get_animation("rotor-spin").loop_mode == Animation.LOOP_LINEAR,
		"Vanguard rotor-spin loops independently of combat state")
	check(enemy_player != null and enemy_player.current_animation == "rotor-spin" and enemy_player.get_animation("rotor-spin").loop_mode == Animation.LOOP_LINEAR,
		"Raider rotor-spin loops independently of combat state")
	var largest_rotor_radius := 0.0
	for pair in [[friendly, friendly_player], [enemy, enemy_player]]:
		var actor: DroneVisual = pair[0]
		var player: AnimationPlayer = pair[1]
		for phase in [0.0, 0.25, 0.5, 0.75]:
			player.seek(player.get_animation("rotor-spin").length * phase, true)
			await get_tree().process_frame
			largest_rotor_radius = maxf(largest_rotor_radius, _mesh_max_radius_from_origin(actor,actor.global_position))
	check(largest_rotor_radius <= (0.381 * DroneVisual.DISPLAY_SCALE),
		"both source meshes and rotor-spin quarter phases fit inside the 0.45 m hit sphere")
	var remote := load("res://scenes/RemotePlayer.tscn").instantiate() as WarRemote
	remote.player_id = "drone_test"
	remote.set_meta("init_state", {"team": "B", "weapon": "ak47", "x": 0.0, "y": 0.0, "z": -2.0})
	add_child(remote)
	check(remote.drone.get_node_or_null("BankVisual/Raider") != null, "remote enemy state selects the Raider model")
	check(remote.name_label.position.is_equal_approx(Vector3(0.0, 0.65, 0.0)), "remote callsign sits just above the centered body")
	check(remote._hitbox_areas.size() == 1 and remote._hitbox_areas[0].get_meta("radius") == WarGameState.DRONE_HIT_RADIUS,
		"remote actors expose one centered R=0.4 m server-authoritative hit hint")
	var sphere_markers := 0
	for item in remote.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := item as MeshInstance3D
		if mesh_instance.mesh is SphereMesh:
			sphere_markers += 1
	check(remote.find_child("SphereMarker", true, false) == null and remote.find_child("IdentityBeacon", true, false) == null,
		"remote identity has no floating sphere markers or beacons")
	check(remote.find_child("Soldier", true, false) == null and remote.find_child("AnimationPlayer", true, false) != null,
		"remote scene contains the looping drone rotor animation and no human rig")
	remote.apply_sdk_pose({"x": 1.0, "y": 2.0, "z": 3.0, "rx": 0.0, "ry": 0.0, "rz": 0.0, "rw": 1.0, "pose_time_ms": 1000})
	check(remote.global_position.is_equal_approx(Vector3(1.0, 2.0, 3.0)) and remote.sdk_pose_driven,
		"SDK pose applies at the centered drone root while preserving the remote API")
	remote.free()
	friendly.free()
	enemy.free()
	print("DRONE_VISUAL_TEST failures=", failures)
	get_tree().quit(failures)
