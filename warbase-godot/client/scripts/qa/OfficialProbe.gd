## Explicit CLI QA mode for the official server; inactive in ordinary play.
extends Node
## Real rendered observer. Explicit official room only; never creates a local server.
const OFFICIAL_HOST := "war.vaidik.blog"
const COLYSEUS_CANDIDATE_HOST := "war.vaidik.blog/colyseus"
var main
var elapsed := 0.0
var frames: Array[float] = []
var gaps: Array[float] = []
var pings: Array[float] = []
var last_state_ms := 0
var last_sample := 0
var peak_remotes := 0
var max_position_error := 0.0
var errors_over_2_5 := 0
var disconnects := 0
var seat_entries := 0
var seat_exits := 0
var driving_seconds := 0.0
var fire_events := 0
var damage_events := 0
var explosion_events := 0
var drive_distance := 0.0
var previous_car := Vector3.ZERO
var was_driving := false
var ads_frames := 0
var confirmed_hits := 0
var confirmed_kills := 0
var local_grenades := 0
var next_respawn_ms := 0
var local_respawns := 0
var next_grenade := 75.0
var applied_corrections := 0
var previous_watermark := 0
var sdk_reconcile_seq_max := 0
var sdk_ack_sequence_max := 0
var sdk_inputs_sent_max := 0
var respawn_at_ms := 0
var last_pos := Vector3.ZERO
var walking_distance := 0.0
var previous_walk := Vector3.ZERO
var cpu: Array[float] = []
var draws: Array[float] = []
var phase_position_errors: Dictionary = {}
var prediction_samples: Array[Dictionary] = []
var event_markers: Array[Dictionary] = []
var _last_prediction_sample_ms := 0
var _last_phase := ""
var _last_server_seat := ""
var _stall_active := false
var seconds := 180.0
var output_path := ""
func begin(game: Node) -> void:
	main = game
	call_deferred("run")
func run() -> void:
	var state = get_tree().root.get_node("GameState")
	var candidate_backend := OS.get_cmdline_user_args().has("qa_colyseus")
	if OS.has_feature("web"):
		candidate_backend = candidate_backend or String(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa_colyseus') || ''")) == "1"
	if main.get("_use_colyseus") != candidate_backend:
		push_error("Official observer backend selection must match explicit qa_colyseus flag")
		get_tree().quit(1)
		return
	state.server_host = COLYSEUS_CANDIDATE_HOST if candidate_backend else OFFICIAL_HOST
	var allowed_host := COLYSEUS_CANDIDATE_HOST if candidate_backend else OFFICIAL_HOST
	if state.server_host != allowed_host:
		push_error("Official observer host rejected: " + state.server_host)
		get_tree().quit(1)
		return
	state.username = "QA_WEB_APP" if OS.has_feature("web") else "QA_NATIVE_APP"
	state.practice_mode = false
	state.selected_map = "industrial"
	state.room_id = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("qa_room="): state.room_id = arg.trim_prefix("qa_room=")
		if arg.begins_with("qa_map="): state.selected_map = arg.trim_prefix("qa_map=")
		if arg.begins_with("qa_seconds="): seconds = float(arg.trim_prefix("qa_seconds="))
		if arg.begins_with("qa_output="): output_path = arg.trim_prefix("qa_output=")
	if OS.has_feature("web"):
		var room_query := String(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa_room') || ''"))
		var map_query := String(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa_map') || ''"))
		var seconds_query := String(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa_seconds') || ''"))
		var valid_room_query := RegEx.new()
		valid_room_query.compile("^[A-Za-z0-9_-]{1,64}$")
		if valid_room_query.search(room_query) != null: state.room_id = room_query
		if ["industrial", "resoforge", "football", "village", "arena", "shipment", "dust2", "nuketown", "canyon", "desert_oasis"].has(map_query): state.selected_map = map_query
		if seconds_query.is_valid_float(): seconds = float(seconds_query)
	var allowed_room := RegEx.new()
	allowed_room.compile("^[A-Za-z0-9_-]{1,64}$")
	if allowed_room.search(state.room_id) == null:
		push_error("Explicit official test room must be a simple room identifier")
		get_tree().quit(1)
		return
	if state.room_id.is_empty(): push_error("Explicit official test room required"); get_tree().quit(1); return
	seconds = clampf(seconds,1.0,1800.0)
	await main._on_deploy()
	if not is_instance_valid(main.player): push_error("QA deployment rejected");get_tree().quit(1);return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main.net.state_received.connect(on_state)
	main.net.connection_changed.connect(func(connected: bool):
		if not connected:
			disconnects += 1
			_mark_event("connection_lost", _prediction_diagnostics())
		else:
			_mark_event("connection_restored", _prediction_diagnostics()))
	main.net.fire_received.connect(func(_a,_b,_c,_d,_e): fire_events += 1)
	main.net.hit_confirmed.connect(func(): confirmed_hits += 1)
	main.net.kill_confirmed.connect(func(): confirmed_kills += 1)
	main.net.respawn_received.connect(func(_pos):
		respawn_at_ms = Time.get_ticks_msec()
		local_respawns += 1
		_mark_event("respawn_received", _prediction_diagnostics()))
	main.net.damage_received.connect(func(_a,_b,_c,_d): damage_events += 1)
	main.net.explosion_received.connect(func(_id,_pos,_kind):
		explosion_events += 1
		_mark_event("explosion_received", {"id": _id, "pos": _vec_array(_pos), "kind": _kind}))
	var timeout := Time.get_ticks_msec() + 20000
	while not state.online_ready and Time.get_ticks_msec() < timeout: await get_tree().process_frame
	if not state.online_ready: push_error("Official server connection failed");get_tree().quit(1);return
	print("OFFICIAL OBSERVER CONNECTED host=", state.server_host, " room=",state.room_id," map=",state.selected_map)
	previous_walk = main.player.global_position
	while elapsed < seconds:
		await get_tree().process_frame
		var dt := get_tree().root.get_process_delta_time()
		elapsed += dt
		frames.append(dt*1000)
		if dt >= 0.1 and not _stall_active:
			_stall_active = true
			_mark_event("frame_stall_started", {"frame_ms": dt * 1000.0, "fps": Engine.get_frames_per_second(), "remotes": main.mp.remotes.size(), "driving": main.current_driven_jeep != null, "prediction": _prediction_diagnostics()})
		elif _stall_active and dt < 0.05:
			_stall_active = false
			_mark_event("frame_stall_ended", {"fps": Engine.get_frames_per_second(), "remotes": main.mp.remotes.size(), "driving": main.current_driven_jeep != null})
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		peak_remotes = maxi(peak_remotes, main.mp.remotes.size())
		var player = main.player
		if not is_instance_valid(player):
			print("OBSERVER: returned to lobby after a terminal connection error")
			break
		if candidate_backend:
			var reconciler = main.net.get("local_reconciler")
			var input_handle = main.net.get("input_handle")
			if reconciler != null: sdk_reconcile_seq_max = maxi(sdk_reconcile_seq_max, int(reconciler.reconcile_seq))
			if input_handle != null:
				sdk_ack_sequence_max = maxi(sdk_ack_sequence_max, int(input_handle.last_processed))
				sdk_inputs_sent_max = maxi(sdk_inputs_sent_max, int(input_handle.sent_count))
		if main._reconcile_after_sequence != previous_watermark:
			if Time.get_ticks_msec()-respawn_at_ms>1000 and not player.is_driving: applied_corrections += 1
			previous_watermark = main._reconcile_after_sequence
		if main.weapons.ads_amount > 0.9: ads_frames += 1
		if player.is_dead:
			if Time.get_ticks_msec()>=next_respawn_ms:
				next_respawn_ms=Time.get_ticks_msec()+1000
				main.net.send_respawn()
			continue
		if main.current_driven_jeep != null:
			var car = main.current_driven_jeep
			if not was_driving:
				seat_entries += 1
				previous_car = car.global_position
				_mark_event("vehicle_entered", {"pos": _vec_array(car.global_position), "vehicle_id": String(car.get_meta("server_vehicle_id", "")), "prediction": _prediction_diagnostics()})
			was_driving = true
			driving_seconds += dt
			drive_distance += car.global_position.distance_to(previous_car)
			previous_car = car.global_position
			if int(driving_seconds / 6) % 3 == 0:
				Input.action_release("move_forward")
				Input.action_press("move_back",0.7)
			else:
				Input.action_release("move_back")
				Input.action_press("move_forward")
			if int(driving_seconds / 8) % 2 == 1: Input.action_press("move_right",0.25)
			else: Input.action_release("move_right")
			if driving_seconds > 35 and int(elapsed) != last_sample: main.net.send_vehicle_seat("",false)
		else:
			if was_driving:
				seat_exits += 1
				_mark_event("vehicle_exited", {"pos": _vec_array(player.global_position), "prediction": _prediction_diagnostics()})
			was_driving = false
			walking_distance += minf(player.global_position.distance_to(previous_walk),1.0)
			previous_walk = player.global_position
			var target := Vector3.ZERO
			var nearest := INF
			var candidate = null
			if seat_entries == 0:
				for car in main._online_vehicles.values():
					if String(car.get_meta("server_driver","")).is_empty():
						var distance: float = player.global_position.distance_to(car.global_position)
						if distance < nearest: nearest=distance;target=car.global_position;candidate=car
			if candidate:
				var direction: Vector3 = target-player.global_position
				player.yaw = atan2(-direction.x,-direction.z)
				if nearest < 4.3 and int(elapsed) != last_sample: main._handle_vehicle_interact()
			else: player.yaw += dt * 0.15
			Input.action_press("move_forward")
			if player.velocity.length() < 0.8 and int(elapsed)%4<2: Input.action_press("move_right")
			else: Input.action_release("move_right")
			if int(elapsed)%10==7: Input.action_press("jump")
			else: Input.action_release("jump")
			if elapsed > 50:
				_aim_at_visible_hostile()
				if int(elapsed)%5<2: Input.action_press("fire")
				else: Input.action_release("fire")
				if int(elapsed)%12>=6: Input.action_press("ads")
				else: Input.action_release("ads")
				if elapsed >= next_grenade and state.throwables_remaining>0:
					next_grenade = elapsed + 35
					main._throw_grenade()
					local_grenades += 1
				if main.weapons.ammo == 0: main.weapons.start_reload()
		if int(elapsed) != last_sample:
			last_sample = int(elapsed)
			pings.append(main.net.current_ping)
			print("OBS t=",last_sample," fps=",Engine.get_frames_per_second()," ping=",main.net.current_ping," remotes=",main.mp.remotes.size()," seats=",seat_entries," drive_m=",snappedf(drive_distance,.1)," pos=",player.global_position)
		if candidate_backend and Time.get_ticks_msec() - _last_prediction_sample_ms >= 1000:
			_last_prediction_sample_ms = Time.get_ticks_msec()
			_record_prediction_sample(player)
	for action in ["move_forward","move_back","move_right","jump","fire","ads"]: Input.action_release(action)
	var report := {"host":state.server_host,"backend":"colyseus" if candidate_backend else "legacy","platform":"web" if OS.has_feature("web") else "native-release","audio_disabled":AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),"release_export":OS.has_feature("release") and not OS.has_feature("editor"),"local_respawns":local_respawns,"local_shots":main.weapons._shot_seq if is_instance_valid(main.weapons) else 0,"confirmed_hits":confirmed_hits,"confirmed_kills":confirmed_kills,"ads_frames":ads_frames,"local_grenades":local_grenades,"sdk_reconcile_seq_max":sdk_reconcile_seq_max,"sdk_ack_sequence_max":sdk_ack_sequence_max,"sdk_inputs_sent_max":sdk_inputs_sent_max,"seconds":elapsed,"peak_remotes":peak_remotes,"frame_ms_p50":percentile(frames,.5),"frame_ms_p95":percentile(frames,.95),"frame_ms_p99":percentile(frames,.99),"frame_ms_max":percentile(frames,1),"cpu_process_ms_p95":percentile(cpu,.95),"draw_calls_p95":percentile(draws,.95),"snapshot_gap_ms_p95":percentile(gaps,.95),"snapshot_gap_ms_max":percentile(gaps,1),"ping_ms_p50":percentile(pings,.5),"ping_ms_p95":percentile(pings,.95),"max_position_error_m":max_position_error,"snapshots_with_error_over_2_5m":errors_over_2_5,"phase_position_errors":phase_position_errors,"prediction_samples":prediction_samples,"prediction_final":_prediction_diagnostics(),"event_markers":event_markers,"applied_corrections":applied_corrections,"disconnects":disconnects,"seat_entries":seat_entries,"seat_exits":seat_exits,"driving_seconds":driving_seconds,"drive_distance_m":drive_distance,"walking_distance_m":walking_distance,"fire_events":fire_events,"damage_events":damage_events,"explosion_events":explosion_events,"local_bots":main.bots.bots.size() if is_instance_valid(main.bots) else -1}
	if output_path.is_empty(): output_path = "user://qa-latest.json"
	var file := FileAccess.open(output_path,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"  "))
	print("OFFICIAL OBSERVER REPORT ",JSON.stringify(report))
	if is_instance_valid(main.weapons): main.weapons.is_firing = false
	if OS.has_feature("web"):
		main.net.disconnect_from()
		main._qa_active = false
		main._quit_to_menu()
		JavaScriptBridge.eval("const qaReport=document.createElement('pre');qaReport.id='warbase-qa-report';qaReport.style.cssText='position:fixed;bottom:12px;right:12px;width:34rem;max-height:70vh;overflow:auto;z-index:9999;padding:16px;background:#08131fee;color:#e3f3ff;font:13px monospace;border:1px solid #c8a66b';qaReport.textContent=JSON.stringify(%s,null,2);document.body.appendChild(qaReport);"%JSON.stringify(report))
	else:
		RenderingServer.force_draw(false)
		get_tree().root.get_texture().get_image().save_png(output_path.get_basename()+".png")
		main.net.disconnect_from()
		get_tree().quit()

func on_state(snapshot: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	if last_state_ms: gaps.append(now-last_state_ms)
	last_state_ms = now
	var state = get_tree().root.get_node("GameState")
	var me: Dictionary = snapshot.get("players",{}).get(state.username,{})
	if me.is_empty() or not is_instance_valid(main.player): return
	var player = main.player
	var server_seat := String(me.get("driving_vehicle", ""))
	if server_seat != _last_server_seat:
		_mark_event("vehicle_seat_enter_authoritative" if not server_seat.is_empty() else "vehicle_seat_exit_authoritative", {"previous_seat": _last_server_seat, "server_seat": server_seat, "server_player_pos": [float(me.get("x", 0)), float(me.get("y", 0)), float(me.get("z", 0))], "prediction": _prediction_diagnostics()})
		_last_server_seat = server_seat
	var phase := "dead" if player.is_dead else ("driving" if player.is_driving else ("respawn_grace" if respawn_at_ms > 0 and now - respawn_at_ms < 2000 else "walking"))
	if phase != _last_phase:
		_mark_event("phase_changed", {"from": _last_phase, "to": phase, "player_pos": _vec_array(player.global_position), "server_player_pos": [float(me.get("x", 0)), float(me.get("y", 0)), float(me.get("z", 0))], "prediction": _prediction_diagnostics()})
		_last_phase = phase
	if phase == "driving":
		var seat := String(me.get("driving_vehicle", ""))
		var vehicles: Dictionary = snapshot.get("vehicles", {})
		var server_vehicle: Dictionary = vehicles.get(seat, {})
		var local_vehicle = main.current_driven_jeep
		if not is_instance_valid(local_vehicle) and main._online_vehicles.has(seat):
			local_vehicle = main._online_vehicles[seat]
		if not server_vehicle.is_empty() and is_instance_valid(local_vehicle):
			var server_vehicle_pos: Vector3 = server_vehicle.get("pos", Vector3.ZERO)
			_record_phase_error("driving_vehicle_render", local_vehicle.global_position.distance_to(server_vehicle_pos), local_vehicle.global_position, server_vehicle_pos)
		return
	if phase == "dead": return
	var server_pos := Vector3(float(me.get("x", 0)), float(me.get("y", 0)), float(me.get("z", 0)))
	var error: float = player.global_position.distance_to(server_pos)
	_record_phase_error(phase, error, player.global_position, server_pos)
	if phase == "walking" or phase == "respawn_grace":
		max_position_error = maxf(max_position_error, error)
		if error > 2.5: errors_over_2_5 += 1

func _record_phase_error(phase: String, error: float, local_pos: Vector3, server_pos: Vector3) -> void:
	var stats: Dictionary = phase_position_errors.get(phase, {"count": 0, "max_m": 0.0, "over_2_5m": 0, "last_error_m": 0.0, "last_local": [], "last_server": []})
	stats["count"] = int(stats.get("count", 0)) + 1
	stats["max_m"] = maxf(float(stats.get("max_m", 0.0)), error)
	stats["last_error_m"] = error
	stats["last_local"] = _vec_array(local_pos)
	stats["last_server"] = _vec_array(server_pos)
	if error > 2.5: stats["over_2_5m"] = int(stats.get("over_2_5m", 0)) + 1
	phase_position_errors[phase] = stats

func _record_prediction_sample(player: Node) -> void:
	if prediction_samples.size() >= 1800: return
	var diagnostics := _prediction_diagnostics()
	var phase := "dead" if player.is_dead else ("driving" if player.is_driving else ("respawn_grace" if respawn_at_ms > 0 and Time.get_ticks_msec() - respawn_at_ms < 2000 else "walking"))
	var sample := {"t_s": elapsed, "phase": phase, "player_pos": _vec_array(player.global_position), "velocity": _vec_array(player.velocity), "diagnostics": diagnostics}
	if phase == "driving" and is_instance_valid(main.current_driven_jeep): sample["vehicle_pos"] = _vec_array(main.current_driven_jeep.global_position)
	prediction_samples.append(sample)

func _prediction_diagnostics() -> Dictionary:
	return main.net.get_prediction_diagnostics() if main.net.has_method("get_prediction_diagnostics") else {}

func _mark_event(name: String, data: Dictionary = {}) -> void:
	if event_markers.size() >= 512: return
	var item := {"event": name, "t_s": elapsed, "monotonic_ms": Time.get_ticks_msec(), "phase": _last_phase}
	for key in data: item[key] = data[key]
	event_markers.append(item)

func _vec_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _aim_at_visible_hostile() -> bool:
	if not is_instance_valid(main.player) or main.player.is_dead or main.player.is_driving:
		return false
	var player = main.player
	var camera: Camera3D = player.camera
	if not is_instance_valid(camera):
		return false
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var best_remote: Node3D = null
	var best_point := Vector3.ZERO
	var best_distance := 80.0
	for remote in main.mp.remotes.values():
		if not is_instance_valid(remote) or not (remote is Node3D):
			continue
		if bool(remote.get("dead")) or bool(remote.get("is_driving")):
			continue
		if remote.has_method("_is_friendly") and bool(remote.call("_is_friendly")):
			continue
		var chest: Area3D = null
		var hit_areas: Array = remote.get("_hitbox_areas")
		for area in hit_areas:
			if not is_instance_valid(area) or not (area is Area3D):
				continue
			if String(area.get_meta("zone", "")) != "torso":
				continue
			if chest == null:
				chest = area
			if String(area.get_meta("from_bone", "")) == "mixamorig_Spine1" and String(area.get_meta("to_bone", "")) == "mixamorig_Neck":
				chest = area
				break
		if not is_instance_valid(chest):
			continue
		var point := chest.global_position
		var distance := camera.global_position.distance_to(point)
		if distance <= 0.01 or distance > best_distance:
			continue
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, point, 1 | 4)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		var hit: Dictionary = space.intersect_ray(query)
		var collider = hit.get("collider")
		if not is_instance_valid(collider) or collider.get_parent() != remote:
			continue
		best_distance = distance
		best_remote = remote
		best_point = point
	if not is_instance_valid(best_remote):
		return false
	var direction := best_point - camera.global_position
	var horizontal := Vector2(direction.x, direction.z).length()
	player.yaw = atan2(-direction.x, -direction.z)
	player.pitch = clampf(atan2(direction.y, horizontal), -PI / 2.1, PI / 2.1)
	player.rotation.y = player.yaw
	player.head.rotation.x = player.pitch
	return true

func percentile(values: Array[float], p: float) -> float:
	if values.is_empty(): return 0
	var ordered := values.duplicate()
	ordered.sort()
	return ordered[int((ordered.size()-1)*p)]
