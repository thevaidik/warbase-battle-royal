extends SceneTree
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
var event_markers: Array[Dictionary] = []
var observer_started_usec := 0
var last_frame_wall_usec := 0
var frame_stall_marker_index := -1
var saw_connection := false
var connection_was_lost := false
var seconds := 180.0
var output_path := ""
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var state = root.get_node("GameState")
	var candidate_backend := OS.get_cmdline_user_args().has("qa_colyseus")
	state.server_host = COLYSEUS_CANDIDATE_HOST if candidate_backend else OFFICIAL_HOST
	var allowed_host := COLYSEUS_CANDIDATE_HOST if candidate_backend else OFFICIAL_HOST
	if state.server_host != allowed_host:
		push_error("Official observer host rejected: " + state.server_host)
		quit(1)
		return
	state.username = "QA_NATIVE"
	state.practice_mode = false
	state.selected_map = "industrial"
	state.room_id = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("qa_room="): state.room_id = arg.trim_prefix("qa_room=")
		if arg.begins_with("qa_map="): state.selected_map = arg.trim_prefix("qa_map=")
		if arg.begins_with("qa_seconds="): seconds = float(arg.trim_prefix("qa_seconds="))
		if arg.begins_with("qa_output="): output_path = arg.trim_prefix("qa_output=")
	if state.room_id.is_empty(): push_error("Explicit official test room required"); quit(1); return
	change_scene_to_file("res://scenes/Main.tscn")
	while current_scene == null: await process_frame
	main = current_scene
	main._on_deploy()
	main.net.state_received.connect(on_state)
	main.net.connection_changed.connect(_on_observer_connection_changed)
	main.net.fire_received.connect(func(_a,_b,_c,_d,_e): fire_events += 1)
	main.net.respawn_received.connect(func(_pos): respawn_at_ms = Time.get_ticks_msec())
	main.net.damage_received.connect(func(_a,_b,_c,_d): damage_events += 1)
	main.net.explosion_received.connect(_on_observer_explosion)
	var timeout := Time.get_ticks_msec() + 20000
	while not state.online_ready and Time.get_ticks_msec() < timeout: await process_frame
	if not state.online_ready: push_error("Official server connection failed");quit(1);return
	print("OFFICIAL OBSERVER CONNECTED host=", state.server_host, " room=",state.room_id," map=",state.selected_map)
	observer_started_usec = Time.get_ticks_usec()
	last_frame_wall_usec = observer_started_usec
	_mark_event("observer_started", {"room": state.room_id, "map": state.selected_map, "backend": "colyseus" if candidate_backend else "legacy"})
	previous_walk = main.player.global_position
	var next_partial_report := 10.0
	while elapsed < seconds:
		await process_frame
		var wall_now_usec := Time.get_ticks_usec()
		var wall_gap_ms := float(wall_now_usec - last_frame_wall_usec) / 1000.0
		last_frame_wall_usec = wall_now_usec
		_track_frame_stall(wall_now_usec, wall_gap_ms, root.get_process_delta_time())
		var dt := root.get_process_delta_time()
		elapsed += dt
		frames.append(dt*1000)
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
		if player.is_dead: continue
		if main.current_driven_jeep != null:
			var car = main.current_driven_jeep
			if not was_driving: seat_entries += 1; previous_car = car.global_position
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
			if driving_seconds > 35 and int(elapsed) != last_sample:
				_mark_event("vehicle_exit_requested", {"driving_seconds": driving_seconds, "position": _vec_array(player.global_position)})
				main.net.send_vehicle_seat("",false)
		else:
			if was_driving:
				seat_exits += 1
				_mark_event("vehicle_exit_applied", {"driving_seconds": driving_seconds, "vehicle_position": _vec_array(previous_car), "player_position": _vec_array(player.global_position)})
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
				main.weapons.is_firing = int(elapsed)%5<2
				if main.weapons.ammo == 0: main.weapons.start_reload()
		if int(elapsed) != last_sample:
			last_sample = int(elapsed)
			pings.append(main.net.current_ping)
			print("OBS t=",last_sample," fps=",Engine.get_frames_per_second()," ping=",main.net.current_ping," remotes=",main.mp.remotes.size()," seats=",seat_entries," drive_m=",snappedf(drive_distance,.1)," pos=",player.global_position)
		if elapsed >= next_partial_report:
			_write_observer_report(false)
			next_partial_report += 10.0
	for action in ["move_forward","move_back","move_right","jump"]: Input.action_release(action)
	_write_observer_report(true)
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(output_path.get_basename()+".png")
	main.net.disconnect_from()
	quit()

func _write_observer_report(complete: bool) -> void:
	var state = root.get_node("GameState")
	var report := {"complete":complete,"host":state.server_host,"backend":"colyseus" if state.server_host == COLYSEUS_CANDIDATE_HOST else "legacy","platform":"native","render_mode":"headless" if DisplayServer.get_name() == "headless" else "windowed","seconds":elapsed,"peak_remotes":peak_remotes,"sdk_reconcile_seq_max":sdk_reconcile_seq_max,"sdk_ack_sequence_max":sdk_ack_sequence_max,"sdk_inputs_sent_max":sdk_inputs_sent_max,"frame_ms_p50":percentile(frames,.5),"frame_ms_p95":percentile(frames,.95),"frame_ms_p99":percentile(frames,.99),"frame_ms_max":percentile(frames,1),"cpu_process_ms_p95":percentile(cpu,.95),"draw_calls_p95":percentile(draws,.95),"snapshot_gap_ms_p95":percentile(gaps,.95),"snapshot_gap_ms_max":percentile(gaps,1),"ping_ms_p50":percentile(pings,.5),"ping_ms_p95":percentile(pings,.95),"max_position_error_m":max_position_error,"snapshots_with_error_over_2_5m":errors_over_2_5,"applied_corrections":applied_corrections,"disconnects":disconnects,"seat_entries":seat_entries,"seat_exits":seat_exits,"driving_seconds":driving_seconds,"drive_distance_m":drive_distance,"walking_distance_m":walking_distance,"fire_events":fire_events,"damage_events":damage_events,"explosion_events":explosion_events,"local_bots":main.bots.bots.size() if is_instance_valid(main.bots) else -1,"event_markers":event_markers}
	if output_path.is_empty(): output_path = ProjectSettings.globalize_path("res://../../audit/official-stress-2026-10-27/native-"+state.selected_map+".json")
	var output_dir := output_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(output_dir): DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_path,FileAccess.WRITE)
	if file == null:
		push_error("Unable to save observer report: " + output_path)
		return
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("OFFICIAL OBSERVER ","REPORT" if complete else "PARTIAL_REPORT ",JSON.stringify(report))
func on_state(snapshot: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	if last_state_ms: gaps.append(now-last_state_ms)
	last_state_ms = now
	var state = root.get_node("GameState")
	var me: Dictionary = snapshot.get("players",{}).get(state.username,{})
	if not me.is_empty() and is_instance_valid(main.player) and not main.player.is_dead and not main.player.is_driving:
		var position := Vector3(me.get("x",0),me.get("y",0),me.get("z",0))
		var error: float = main.player.global_position.distance_to(position)
		max_position_error = maxf(max_position_error,error)
		if error > 2.5: errors_over_2_5 += 1

func _on_observer_connection_changed(connected: bool) -> void:
	if connected:
		if saw_connection and connection_was_lost:
			_mark_event("connection_recovered", {"disconnects": disconnects})
		saw_connection = true
		connection_was_lost = false
	else:
		disconnects += 1
		if saw_connection:
			connection_was_lost = true
			_mark_event("connection_lost", {"disconnects": disconnects})

func _on_observer_explosion(grenade_id: int, pos: Vector3, kind: String) -> void:
	explosion_events += 1
	_mark_event("explosion", {"grenade_id": grenade_id, "kind": kind, "position": _vec_array(pos), "explosion_count": explosion_events})

func _track_frame_stall(wall_now_usec: int, wall_gap_ms: float, process_delta: float) -> void:
	const STALL_THRESHOLD_MS := 250.0
	if wall_gap_ms >= STALL_THRESHOLD_MS:
		if frame_stall_marker_index < 0:
			var input_handle = main.net.get("input_handle") if main.net.has_method("get_sdk_remote_poses") else null
			var reconciler = main.net.get("local_reconciler") if main.net.has_method("get_sdk_remote_poses") else null
			_mark_event("frame_stall_started", {"wall_gap_ms": wall_gap_ms, "process_delta_ms": process_delta * 1000.0, "fps": Engine.get_frames_per_second(), "remotes": main.mp.remotes.size(), "driving": main.current_driven_jeep != null, "sdk_ack_sequence": int(input_handle.last_processed) if input_handle != null else -1, "sdk_inputs_sent": int(input_handle.sent_count) if input_handle != null else -1, "sdk_reconcile_sequence": int(reconciler.reconcile_seq) if reconciler != null else -1, "explosion_events": explosion_events, "fire_events": fire_events, "damage_events": damage_events})
			frame_stall_marker_index = event_markers.size() - 1
		var stall: Dictionary = event_markers[frame_stall_marker_index]
		stall["frames"] = int(stall.get("frames", 0)) + 1
		stall["max_gap_ms"] = maxf(float(stall.get("max_gap_ms", 0.0)), wall_gap_ms)
		stall["duration_ms"] = float(wall_now_usec - observer_started_usec) / 1000.0 - float(stall.get("wall_ms", 0.0))
	elif frame_stall_marker_index >= 0:
		var stall: Dictionary = event_markers[frame_stall_marker_index]
		_mark_event("frame_stall_recovered", {"stall_duration_ms": float(stall.get("duration_ms", 0.0)), "stall_frames": int(stall.get("frames", 0)), "max_gap_ms": float(stall.get("max_gap_ms", 0.0))})
		frame_stall_marker_index = -1

func _mark_event(event_name: String, details: Dictionary = {}) -> void:
	var marker := {"event": event_name, "wall_ms": float(Time.get_ticks_usec() - observer_started_usec) / 1000.0 if observer_started_usec > 0 else 0.0, "game_elapsed_s": elapsed}
	for key in details:
		marker[key] = details[key]
	event_markers.append(marker)
	print("OBSERVER EVENT ", JSON.stringify(marker))

func _vec_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]

func percentile(values: Array[float], p: float) -> float:
	if values.is_empty(): return 0
	var ordered := values.duplicate()
	ordered.sort()
	return ordered[int((ordered.size()-1)*p)]
