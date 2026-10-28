extends SceneTree
## Physics regression for local-bot and remote-player anatomical ray hits.

var failures := 0
var _weapon_helper: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("CHECK ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func _bone_point(actor: Node3D, bone_name: String) -> Vector3:
	var skeleton := actor.get_node("Soldier/Armature/Skeleton3D") as Skeleton3D
	var pose: Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone(bone_name))
	return actor.to_local(skeleton.global_transform * pose.origin)

func _segment_point(actor: Node3D, from_bone: String, to_bone: String, weight: float = 0.5) -> Vector3:
	var from_pos := _bone_point(actor, from_bone)
	var to_pos := _bone_point(actor, to_bone)
	return from_pos.lerp(to_pos, weight)

func _ray_zone_at(actor: Node3D, local_point: Vector3, local_direction: Vector3 = Vector3.RIGHT) -> String:
	var ray_offset := local_direction.normalized() * 2.0
	var query := PhysicsRayQueryParameters3D.create(
		actor.to_global(local_point - ray_offset),
		actor.to_global(local_point + ray_offset),
		1 | 4
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if actor is CollisionObject3D:
		query.exclude = [actor.get_rid()]
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return ""
	var collider: Object = hit.get("collider")
	return String(collider.get_meta("zone", "")) if collider and collider.has_meta("hitbox") else "body"

func _area_overlaps_point(actor: Node3D, area: Area3D, local_point: Vector3) -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = 0.012
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, actor.to_global(local_point))
	query.collision_mask = 4
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hits := actor.get_world_3d().direct_space_state.intersect_shape(query, 32)
	for hit in hits:
		if hit.get("collider") == area:
			return true
	return false

func _find_limb_center_promotion(actor: Node3D) -> Dictionary:
	var directions := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK, Vector3(1, 0, 1).normalized(), Vector3(-1, 0, 1).normalized(), Vector3(1, 0, -1).normalized(), Vector3(-1, 0, -1).normalized()]
	var state := actor.get_world_3d().direct_space_state
	for area in actor.get("_hitbox_areas"):
		if String(area.get_meta("zone", "")) not in ["arm", "leg"]:
			continue
		var point := _segment_point(actor, String(area.get_meta("from_bone")), String(area.get_meta("to_bone")), 0.65)
		for direction in directions:
			var offset: Vector3 = direction * 2.0
			var from := actor.to_global(point - offset)
			var to := actor.to_global(point + offset)
			var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
			query.collide_with_areas = true
			query.collide_with_bodies = true
			var first := state.intersect_ray(query)
			if first.is_empty() or first.get("collider") != area:
				continue
			var retry := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
			retry.collide_with_areas = true
			retry.collide_with_bodies = true
			var resolved: Dictionary = _weapon_helper.resolve_same_actor_center_through_limb(state, retry, first)
			var next_collider: Object = resolved.get("collider")
			if next_collider and next_collider != area and String(next_collider.get_meta("zone", "")) in ["head", "torso", "stomach"] and next_collider.get_parent() == actor:
				return {"area": area, "first": first, "resolved": resolved, "from": from, "to": to}
	return {}

func _check_zones(actor: Node3D, label: String) -> void:
	var cases := [
		{"zone": "head", "from": "mixamorig_Head", "to": "mixamorig_HeadTop_End", "direction": Vector3.RIGHT},
		{"zone": "torso", "from": "mixamorig_Spine1", "to": "mixamorig_Neck", "direction": Vector3.FORWARD},
		{"zone": "stomach", "from": "mixamorig_Hips", "to": "mixamorig_Spine1", "direction": Vector3.RIGHT},
		{"zone": "arm", "from": "mixamorig_LeftForeArm", "to": "mixamorig_LeftHand", "direction": Vector3.FORWARD},
		{"zone": "leg", "from": "mixamorig_LeftLeg", "to": "mixamorig_LeftFoot", "direction": Vector3.RIGHT},
	]
	for item in cases:
		var weight := 0.7 if String(item["zone"]) == "head" else 0.5
		var point := _segment_point(actor, String(item["from"]), String(item["to"]), weight)
		var actual_zone := _ray_zone_at(actor, point, item["direction"])
		check(actual_zone == String(item["zone"]), "%s actual %s bone path resolves to its anatomical area (got %s)" % [label, item["zone"], actual_zone])
	var head_point := _segment_point(actor, "mixamorig_Head", "mixamorig_HeadTop_End", 0.7)
	check(_ray_zone_at(actor, head_point + Vector3(0.5, 0.0, 0.0), Vector3.FORWARD).is_empty(), "%s narrow head proxy does not inflate sideways" % label)
	check(_ray_zone_at(actor, head_point + Vector3(0.0, 0.0, 1.5), Vector3.RIGHT).is_empty(), "%s clear miss remains a miss" % label)

func _check_all_capsules(actor: Node3D, label: String) -> bool:
	var areas: Array = actor.get("_hitbox_areas")
	var okay: bool = areas.size() == 14
	for area in areas:
		var from_bone := String(area.get_meta("from_bone"))
		var to_bone := String(area.get_meta("to_bone"))
		var zone := String(area.get_meta("zone"))
		var weight := 0.7 if zone == "head" else 0.5
		var point := _segment_point(actor, from_bone, to_bone, weight)
		if not _area_overlaps_point(actor, area, point):
			okay = false
			print("CAPSULE_POINT_FAIL ", label, " ", area.name, " from=", from_bone, " to=", to_bone, " zone=", zone)
	var head_point := _segment_point(actor, "mixamorig_Head", "mixamorig_HeadTop_End", 0.7)
	if _ray_zone_at(actor, head_point, Vector3.RIGHT) != "head":
		okay = false
		print("CAPSULE_HEAD_RAY_FAIL ", label, " point=", head_point)
	return okay

func run() -> void:
	var game_state = root.get_node_or_null("GameState")
	if game_state:
		game_state.practice_mode = false
	change_scene_to_file("res://scenes/Main.tscn")
	while current_scene == null:
		await process_frame
	await process_frame
	_weapon_helper = load("res://scripts/weapons/WeaponSystem.gd").new()
	var fixture_text := FileAccess.get_file_as_string("res://scripts/tests/combat-fixture.json")
	var fixture: Array = JSON.parse_string(fixture_text)
	check(fixture.size() == 280, "Go combat fixture contains 280 weapon/zone/range cases")
	var damage_parity_ok := true
	for row in fixture:
		var weapon_id := String(row["weapon"])
		var config: Dictionary = game_state.WEAPONS[game_state.weapon_index_for_id(weapon_id)]
		var zone := String(row["zone"])
		var metres := float(row["range_m"])
		var expected := int(row["damage"])
		var actual: int = game_state.damage_for_zone(config, metres, zone)
		if actual != expected:
			damage_parity_ok = false
			print("DAMAGE PARITY FAIL ", weapon_id, " ", zone, " ", metres, "m: got ", actual, " want ", expected)
	check(damage_parity_ok, "client zone damage matches Go combat fixture across weapons, zones, and ranges")
	var holder := Node3D.new()
	holder.name = "HitboxRegression"
	root.add_child(holder)
	var camera := Camera3D.new()
	holder.add_child(camera)
	camera.make_current()

	var remote_script: Script = load("res://scripts/net/RemotePlayer.gd")
	var remote: Node3D = remote_script.create("HITBOX_REMOTE", {"team": "B", "weapon": "ak47"})
	holder.add_child(remote)
	remote.global_position = Vector3(0.0, 0.0, -12.0)
	var bot_script: Script = load("res://scripts/bots/Bot.gd")
	var bot: CharacterBody3D = bot_script.create_bot("HITBOX_BOT", Vector3.ZERO)
	holder.add_child(bot)
	bot.global_position = Vector3(3.0, 0.0, -12.0)
	await physics_frame
	remote.set_process(false)
	remote.set_physics_process(false)
	bot.set_process(false)
	bot.set_physics_process(false)
	await physics_frame

	_check_zones(remote, "remote")
	_check_zones(bot, "local bot")
	var bot_head_point := _segment_point(bot, "mixamorig_Head", "mixamorig_HeadTop_End", 0.7)
	check(bot.collision_layer == 2 and _ray_zone_at(bot, bot_head_point) == "head", "layer-2 bot body cannot mask the layer-4 head zone")

	remote.rotation.y = PI * 0.5
	bot.rotation.y = PI * 0.5
	await physics_frame
	_check_zones(remote, "rotated remote")
	_check_zones(bot, "rotated local bot")

	remote.rotation.y = 0.0
	var lod_distances := [20.0, 70.0, 130.0]
	for lod in [0, 1, 2]:
		remote.global_position = Vector3(0.0, 0.0, -lod_distances[lod])
		remote._update_distance_lod()
		await physics_frame
		check(remote._current_lod == lod, "remote at %dm selects visual LOD %d" % [int(lod_distances[lod]), lod])
		var all_active := true
		for area in remote._hitbox_areas:
			all_active = all_active and area.collision_layer == 4
		check(all_active, "remote anatomical zones stay active at %dm visual LOD %d" % [int(lod_distances[lod]), lod])
		_check_zones(remote, "remote LOD %d at %dm" % [lod, int(lod_distances[lod])])

	remote._set_driving_state(true)
	var driver_disabled := true
	for area in remote._hitbox_areas:
		driver_disabled = driver_disabled and area.collision_layer == 0
	check(driver_disabled, "driver state disables all remote anatomical areas")
	remote._set_driving_state(false)
	var driver_restored := true
	for area in remote._hitbox_areas:
		driver_restored = driver_restored and area.collision_layer == 4
	check(driver_restored, "leaving driver state restores all remote anatomical areas")

	var remote_anim: AnimationPlayer = remote.get_node("Soldier/AnimationPlayer")
	var animation_capsules_ok := true
	for clip_data in [
		{"state": "idle", "clip": "Rifle Idle"},
		{"state": "run", "clip": "Rifle Run"},
		{"state": "jump", "clip": "Rifle Jump"},
	]:
		var clip := remote_anim.get_animation(String(clip_data["clip"]))
		var frame_count := ceili(clip.length * 30.0)
		var clip_ok := true
		for frame_index in range(frame_count + 1):
			var phase := minf(float(frame_index) / 30.0, clip.length)
			remote._sync_anim(String(clip_data["state"]), false, phase)
			await physics_frame
			if not _check_all_capsules(remote, String(clip_data["state"]) + " frame " + str(frame_index)):
				clip_ok = false
		animation_capsules_ok = animation_capsules_ok and clip_ok
		check(clip_ok, "%s sampled clip keeps all 14 bone-following capsules ray-hittable" % clip_data["state"])
	check(animation_capsules_ok, "idle, run, and jump animation pose rays stay inside matching zones")
	remote._sync_anim("idle", false, 0.0)
	await physics_frame
	var penetration_case := _find_limb_center_promotion(remote)
	var penetration_ok := not penetration_case.is_empty()
	check(penetration_ok, "same finite ray can promote an intervening limb to this actor's torso, head, or stomach")
	if penetration_ok:
		var first_limb: Dictionary = penetration_case["first"]
		var promoted: Dictionary = penetration_case["resolved"]
		var first_point: Vector3 = first_limb["position"]
		var promoted_point: Vector3 = promoted["position"]
		var cover := StaticBody3D.new()
		cover.collision_layer = 1
		cover.collision_mask = 0
		var cover_shape := CollisionShape3D.new()
		var cover_sphere := SphereShape3D.new()
		cover_sphere.radius = 0.045
		cover_shape.shape = cover_sphere
		cover.add_child(cover_shape)
		holder.add_child(cover)
		cover.global_position = first_point.lerp(promoted_point, 0.5)
		await physics_frame
		var cover_query := PhysicsRayQueryParameters3D.create(penetration_case["from"], penetration_case["to"], 1 | 4)
		cover_query.collide_with_areas = true
		cover_query.collide_with_bodies = true
		var state := remote.get_world_3d().direct_space_state
		var cover_first := state.intersect_ray(cover_query)
		var cover_result: Dictionary = _weapon_helper.resolve_same_actor_center_through_limb(state, cover_query, cover_first)
		check(cover_first.get("collider") == first_limb.get("collider") and cover_result.get("collider") == first_limb.get("collider"), "same-actor limb promotion retains the limb hit when cover blocks the deeper body zone")
		cover.queue_free()
		await physics_frame
		var other_actor := Node3D.new()
		holder.add_child(other_actor)
		other_actor.global_position = first_point.lerp(promoted_point, 0.5)
		var other_area := Area3D.new()
		other_area.collision_layer = 4
		other_area.collision_mask = 0
		other_area.set_meta("hitbox", true)
		other_area.set_meta("zone", "torso")
		other_area.set_meta("player_id", "OTHER_ACTOR")
		var other_shape := CollisionShape3D.new()
		var other_sphere := SphereShape3D.new()
		other_sphere.radius = 0.045
		other_shape.shape = other_sphere
		other_area.add_child(other_shape)
		other_actor.add_child(other_area)
		await physics_frame
		var other_query := PhysicsRayQueryParameters3D.create(penetration_case["from"], penetration_case["to"], 1 | 4)
		other_query.collide_with_areas = true
		other_query.collide_with_bodies = true
		var other_first := state.intersect_ray(other_query)
		var other_result: Dictionary = _weapon_helper.resolve_same_actor_center_through_limb(state, other_query, other_first)
		check(other_first.get("collider") == first_limb.get("collider") and other_result.get("collider") == first_limb.get("collider"), "same-actor limb promotion does not pass through a different combatant")
		other_actor.queue_free()
	var base_pose_time := 1_800_000_000_000
	var pose_a := {"anim": "idle", "animation_time": 1.0, "pose_time_ms": base_pose_time}
	var pose_b := {"anim": "idle", "animation_time": 1.2, "pose_time_ms": base_pose_time + 100}
	remote._render_animation(pose_a, pose_b, 0.375)
	check(remote.get_hit_view_time_ms() == base_pose_time + 38, "remote rendered-pose time interpolates replicated uint64 timestamps without absolute-float precision loss")
	var older_buf: Array = remote._buf
	var snapshot_now := Time.get_ticks_msec() / 1000.0
	var previous_state := {"x": 0.0, "y": 0.0, "z": -20.0, "rx": 0.0, "ry": 0.0, "rz": 0.0, "rw": 1.0, "anim": "idle", "animation_time": 0.5, "pose_time_ms": base_pose_time}
	var latest_state := {"x": 10.0, "y": 0.0, "z": -20.0, "rx": 0.0, "ry": 0.0, "rz": 0.0, "rw": 1.0, "anim": "idle", "animation_time": 0.7, "pose_time_ms": base_pose_time + 100}
	remote._buf = [{"t": snapshot_now - 1.0, "st": previous_state}, {"t": snapshot_now - 0.5, "st": latest_state}]
	remote.global_position = Vector3(2.5, 0.0, -20.0)
	remote.interpolate(0.0)
	check(remote.get_hit_view_time_ms() == base_pose_time + 25, "remote catch-up rendering projects its pose timestamp from the last two snapshots")
	previous_state["x"] = 10.0
	latest_state["pose_time_ms"] = base_pose_time + 200
	remote.global_position = Vector3(10.0, 0.0, -20.0)
	remote.interpolate(0.0)
	check(remote.get_hit_view_time_ms() == base_pose_time + 200, "stationary remote catch-up uses the latest authoritative pose timestamp")
	remote._buf = older_buf
	var encoded_hit := WarProto._parse_msg(WarProto.encode_hit("POSE_TARGET", 25, 41, base_pose_time + 400))
	var hit_payload: PackedByteArray = encoded_hit.get(2, PackedByteArray())
	var decoded_hit := WarProto._parse_msg(hit_payload)
	check(int(decoded_hit.get(4, 0)) == base_pose_time + 400, "hit event protobuf includes the rendered view timestamp in field 4")
	var legacy_hit := WarProto._parse_msg(WarProto.encode_hit("POSE_TARGET", 25, 41))
	var legacy_payload: PackedByteArray = legacy_hit.get(2, PackedByteArray())
	check(not WarProto._parse_msg(legacy_payload).has(4), "default zero hit view timestamp remains omitted for server-current fallback")
	var saved_practice: bool = game_state.practice_mode
	var saved_ready: bool = game_state.online_ready
	game_state.practice_mode = false
	game_state.online_ready = true
	var stress_player := (load("res://scenes/Player.tscn") as PackedScene).instantiate() as Node3D
	holder.add_child(stress_player)
	stress_player.global_position = Vector3(10000.0, 10000.0, 10000.0)
	stress_player.set("yaw", 0.0)
	stress_player.set("pitch", 0.0)
	stress_player.rotation = Vector3.ZERO
	stress_player.set("is_grounded", true)
	stress_player.set_physics_process(false)
	await process_frame
	var stress_camera := stress_player.get_node("Head/Camera3D") as Camera3D
	stress_camera.make_current()
	stress_camera.global_rotation = Vector3.ZERO
	remote.player_id = "BOT_STRESS_00"
	for area in remote._hitbox_areas:
		area.set_meta("player_id", "BOT_STRESS_00")
	remote.global_position = stress_camera.global_position + Vector3(0.0, -1.52, -8.0)
	remote.rotation = Vector3.ZERO
	remote._render_animation({"anim": "idle", "animation_time": 1.0, "pose_time_ms": 2_345_678_901_234}, {"anim": "idle", "animation_time": 1.0, "pose_time_ms": 2_345_678_901_234}, 0.0)
	await physics_frame
	var capture_net: Node = (load("res://scripts/tests/capture_hit_network.gd") as Script).new()
	capture_net.set("connected", true)
	holder.add_child(capture_net)
	var live_weapon: Node3D = (load("res://scripts/weapons/WeaponSystem.gd") as Script).new() as Node3D
	holder.add_child(live_weapon)
	live_weapon.call("setup", stress_player, stress_player.get_node("Head/Camera3D") as Camera3D, stress_player.get_node("Head/Camera3D/SwayRoot"), capture_net, holder)
	var captured_packets: Array = capture_net.get("sent_packets")
	captured_packets.clear()
	live_weapon.set("spread", 0.0)
	live_weapon.set("_last_fire", -10.0)
	live_weapon.set("_switch_t", 1.0)
	live_weapon.set("_can_fire_semi", true)
	live_weapon.call("try_fire")
	var saw_fire := false
	var saw_stress_hit := false
	for packet in captured_packets:
		var event := WarProto._parse_msg(packet)
		if event.has(3):
			saw_fire = true
		if event.has(2):
			var hit_event := WarProto._parse_msg(event[2])
			var target_bytes: PackedByteArray = hit_event.get(1, PackedByteArray())
			var reported_time := int(hit_event.get(4, 0))
			if target_bytes.get_string_from_utf8() == "BOT_STRESS_00" and reported_time == 2_345_678_901_234:
				saw_stress_hit = true
	check(saw_fire, "actual online weapon fire emits a fire event for a stress peer")
	check(saw_stress_hit, "actual online weapon hit reports BOT_STRESS_00 and its rendered pose timestamp")
	live_weapon.queue_free()
	capture_net.queue_free()
	stress_player.queue_free()
	game_state.practice_mode = saved_practice
	game_state.online_ready = saved_ready

	var hud_script: Script = load("res://scripts/ui/HUD.gd")
	var test_hud: Node = hud_script.new()
	holder.add_child(test_hud)
	await process_frame
	var main_script: Node3D = load("res://scripts/core/Main.gd").new()
	main_script.hud = test_hud
	game_state.practice_mode = false
	test_hud._hit_t = 0.0
	main_script._on_local_hit_confirmed("REMOTE", 20, false, false)
	check(test_hud._hit_t == 0.0, "online predicted hit does not show confirmed local hitmarker")
	main_script._on_hit_confirmed()
	check(test_hud._hit_t > 0.0, "server hit confirmation still shows online hitmarker")
	game_state.practice_mode = true
	test_hud._hit_t = 0.0
	main_script._on_local_hit_confirmed("BOT", 20, false, false)
	check(test_hud._hit_t > 0.0, "practice mode retains immediate local hitmarker")
	main_script.free()
	_weapon_helper.free()

	bot.queue_free()
	remote.queue_free()
	holder.queue_free()
	print("HITBOX TEST: %d failures" % failures)
	quit(1 if failures > 0 else 0)
