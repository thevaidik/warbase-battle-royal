class_name WarColyseusNetwork
extends WarNetwork
## Colyseus SDK adapter. Inputs are staged through the SDK's reflected buffered
## input channel; decoded room state and lifecycle events feed WarNetwork's API.

const SchemaTypes := preload("res://scripts/net/ColyseusSchema.gd")
const WorldGeometry := preload("res://scripts/net/ColyseusWorldGeometry.gd")
# Leave one second of margin before the server's 15-second seat-reconnection expiry.
const CLIENT_RECONNECT_GRACE_MS := 14000

var client
var room
var predictor
var input_handle
var local_reconciler
var _reconciled_instance
var _last_normalized_state: Dictionary = {}
var _has_initial_state := false
var _last_meta_ms := 0
var _local_driving_vehicle := false
var _pose_clock_raw_delta_ms := 0.0
var _pose_clock_server_offset_ms := 0.0
var _pose_clock_render_delta_ms := 0.0
var _pose_clock_samples := 0
var _pose_clock_coherent := false
var _pose_clock_warned := false
var _desired_animation := "idle"
var _desired_weapon := "ak47"
var _desired_quat := Quaternion.IDENTITY
var _desired_pitch := 0.0
var _drop_started_ms := 0
var _jump_pending := false
var _drop_count := 0
var _reconnect_count := 0
var _last_reconnect_gap_ms := -1
var _last_lifecycle_event := ""
var _last_steps_due := 0
var _max_steps_due := 0

func connect_to(username: String, room_name: String, host: String) -> void:
	disconnect_from()
	_username = username
	_room = room_name
	_host = host
	_want_connection = true
	_has_initial_state = false
	_drop_count = 0
	_reconnect_count = 0
	_last_reconnect_gap_ms = -1
	_last_lifecycle_event = "connecting"
	_last_steps_due = 0
	_max_steps_due = 0
	var scheme := "wss"
	if host.begins_with("localhost") or host.begins_with("127."):
		scheme = "ws"
	var clean_host := host.trim_prefix("https://").trim_prefix("http://").trim_prefix("wss://").trim_prefix("ws://").trim_suffix("/")
	var endpoint := "%s://%s" % [scheme, clean_host]
	if not clean_host.contains(":") and (clean_host == "localhost" or clean_host.begins_with("127.")):
		endpoint += ":8081"
	if OS.has_feature("web"):
		var web_host = JavaScriptBridge.eval("window.location.host")
		var web_proto = JavaScriptBridge.eval("window.location.protocol")
		var web_path = JavaScriptBridge.eval("window.location.pathname")
		var web_backend = String(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('backend') || ''")).to_lower()
		var web_qa_colyseus = String(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa_colyseus') || ''"))
		if web_host != null and not String(web_host).is_empty():
			var base_path := "/colyseus" if String(web_path).begins_with("/colyseus") or web_backend in ["colyseus", "qa_colyseus"] or web_qa_colyseus == "1" else ""
			endpoint = "%s://%s%s" % ["wss" if String(web_proto) == "https:" else "ws", String(web_host), base_path]
	client = Colyseus.Client.new(endpoint)
	room = client.join_or_create("battle", {
		"username": username,
		"room": room_name,
		"map": GameState.selected_map,
		"mode": GameState.selected_mode,
		"time_of_day": GameState.selected_time,
		"cid": _load_or_make_cid(),
	})
	if room == null:
		_want_connection = false
		connection_error.emit("Unable to create Colyseus room connection")
		return
	room.set_state_type(SchemaTypes.RoomState)
	room.joined.connect(_on_joined)
	room.state_changed.connect(_on_state_changed)
	room.message_received.connect(_on_message)
	room.error.connect(func(code: int, message: String) -> void:
		_last_lifecycle_event = "error"
		_want_connection = false
		connection_error.emit(message if not message.is_empty() else "Colyseus room error %d" % code)
	)
	room.left.connect(func(_code: int, reason: String) -> void:
		_last_lifecycle_event = "left"
		_set_connected(false)
		if _want_connection:
			_want_connection = false
			connection_error.emit("Colyseus room closed: " + reason)
	)
	room.dropped.connect(func(_code: int, _reason: String) -> void:
		_drop_started_ms = Time.get_ticks_msec()
		_drop_count += 1
		_last_lifecycle_event = "dropped"
		_set_connected(false)
	)
	room.reconnected.connect(_on_joined)

func _on_joined() -> void:
	if _drop_started_ms > 0:
		_reconnect_count += 1
		_last_reconnect_gap_ms = Time.get_ticks_msec() - _drop_started_ms
		_last_lifecycle_event = "reconnected"
	else:
		_last_lifecycle_event = "joined"
	_want_connection = true
	_drop_started_ms = 0
	# The SDK's default min-uptime rejects reconnects for rooms dropped soon
	# after joining. The server explicitly allows reconnect windows, so avoid
	# discarding a valid seat on short-lived network interruption.
	room.set_reconnection_options({"min_uptime_ms": 0})
	input_handle = room.input()
	if input_handle == null:
		connection_error.emit("Colyseus server did not declare buffered inputs")
		return
	predictor = Colyseus.Predict.of(room)
	predictor.attach_all("players", {
		"x": Colyseus.Predict.LERP,
		"y": Colyseus.Predict.LERP,
		"z": Colyseus.Predict.LERP,
		"yaw": {"mode": Colyseus.Predict.LERP, "angle": true},
	}, _username)
	local_reconciler = null
	_reconciled_instance = null
	_set_connected(true)

func _on_state_changed() -> void:
	if room == null: return
	var state = SchemaTypes.to_dictionary(room.get_state())
	if state is Dictionary:
		if not _has_initial_state:
			if int(state.get("protocol_version", 0)) <= 0: return
			_has_initial_state = true
		var authoritative_map := String(state.get("map_name", ""))
		if not authoritative_map.is_empty():
			WorldGeometry.set_map_override(authoritative_map)
		var decoded = room.get_state()
		var instances: Dictionary = decoded.get("players") if decoded != null else {}
		var normalized_players := {}
		for player_id in state.get("players", {}):
			var player_state: Dictionary = state.players[player_id]
			var public_id := String(player_state.get("username", player_id))
			player_state["rx"] = player_state.get("qx", 0.0)
			player_state["ry"] = player_state.get("qy", 0.0)
			player_state["rz"] = player_state.get("qz", 0.0)
			player_state["rw"] = player_state.get("qw", 1.0)
			player_state["anim"] = player_state.get("animation", "idle")
			player_state["weapon"] = player_state.get("weapon_id", "ak47")
			if predictor != null and instances.has(player_id):
				var instance = instances[player_id]
				if public_id == _username and input_handle != null and instance != _reconciled_instance:
					_reconciled_instance = instance
					local_reconciler = predictor.reconciler(instance, {
						"input": input_handle,
						"fields": ["x", "y", "z", "vx", "vy", "vz", "health"],
						"step": Callable(self, "_predict_server_step"),
						"smooth_ms": 80.0,
						"snap": 1.5,
					})
				if public_id != _username:
					for field in ["x", "y", "z"]:
						var predicted: float = predictor.value(instance, field)
						if is_finite(predicted): player_state[field] = predicted
			normalized_players[public_id] = player_state
		var local_player_state: Dictionary = normalized_players.get(_username, {})
		_local_driving_vehicle = not String(local_player_state.get("driving_vehicle", "")).is_empty()
		var removed_players: Array[String] = []
		for previous_id in _last_normalized_state.get("players", {}).keys():
			if not normalized_players.has(previous_id): removed_players.append(String(previous_id))
		state["removed_players"] = removed_players
		state["players"] = normalized_players
		var normalized_vehicles: Dictionary = state.get("vehicles", {})
		for vehicle_id in normalized_vehicles.keys():
			var vehicle_state: Dictionary = normalized_vehicles[vehicle_id]
			vehicle_state["pos"] = _vec(vehicle_state.get("pos", []))
		state["vehicles"] = normalized_vehicles
		_last_normalized_state = state
		state_received.emit(state)
		_apply_local_reconciler()

func get_sdk_remote_poses() -> Dictionary:
	var players: Dictionary = _last_normalized_state.get("players", {})
	if players.is_empty(): return {}
	var decoded = room.get_state() if room != null and predictor != null else null
	var instances: Dictionary = decoded.get("players") if decoded != null else {}
	var render_time_ms := float(room.clock.render_now()) if room != null and predictor != null else 0.0
	var sdk_server_time_ms := float(room.clock.server_now()) if room != null and predictor != null else 0.0
	var poses := {}
	for username in players:
		if username == _username: continue
		var pose: Dictionary = players[username].duplicate()
		if room != null and predictor != null and instances.has(username):
			var instance = instances[username]
			for field in ["x", "y", "z", "yaw"]:
				var value: float = predictor.value(instance, field)
				if is_finite(value): pose[field] = value
			var snapshot_time_ms := float(pose.get("pose_time_ms", render_time_ms))
			var snapshot_animation_time := float(pose.get("animation_time", 0.0))
			_pose_clock_raw_delta_ms = render_time_ms - snapshot_time_ms
			_pose_clock_server_offset_ms = sdk_server_time_ms - snapshot_time_ms
			_pose_clock_render_delta_ms = render_time_ms - sdk_server_time_ms
			_pose_clock_coherent = is_finite(_pose_clock_raw_delta_ms) and is_finite(_pose_clock_server_offset_ms) and is_finite(_pose_clock_render_delta_ms) and absf(_pose_clock_render_delta_ms) <= 500.0
			if _pose_clock_coherent:
				_pose_clock_samples += 1
				pose["animation_time"] = maxf(0.0, snapshot_animation_time + _pose_clock_render_delta_ms / 1000.0)
				pose["pose_time_ms"] = int(render_time_ms - _pose_clock_server_offset_ms)
			else:
				pose["animation_time"] = snapshot_animation_time
				pose["pose_time_ms"] = int(snapshot_time_ms)
				if not _pose_clock_warned:
					_pose_clock_warned = true
					push_warning("Colyseus SDK clock/pose timing is incoherent (raw=%0.1f ms render-vs-server=%0.1f ms); using snapshot phase/time" % [_pose_clock_raw_delta_ms, _pose_clock_render_delta_ms])
		var rotation := Quaternion(Vector3.UP, float(pose.get("yaw", 0.0)))
		pose["rx"] = rotation.x
		pose["ry"] = rotation.y
		pose["rz"] = rotation.z
		pose["rw"] = rotation.w
		poses[username] = pose
	return poses

func get_sdk_remote_pose(username: String) -> Dictionary:
	return get_sdk_remote_poses().get(username, {})

func get_pose_clock_diagnostics() -> Dictionary:
	return {"raw_delta_ms": _pose_clock_raw_delta_ms, "server_offset_ms": _pose_clock_server_offset_ms, "render_delta_ms": _pose_clock_render_delta_ms, "samples": _pose_clock_samples, "coherent": _pose_clock_coherent}

## Snapshot for explicit QA observers. Read only; ordinary gameplay doesn't
## allocate or emit these diagnostics.
func get_prediction_diagnostics() -> Dictionary:
	var me: Dictionary = _last_normalized_state.get("players", {}).get(_username, {})
	var server_pos := Vector3(float(me.get("x", 0.0)), float(me.get("y", 0.0)), float(me.get("z", 0.0)))
	var predicted_pos := Vector3.ZERO
	var correction_mag := 0.0
	var reconcile_seq := 0
	var reconciler_pending := 0
	var drift_ema := 0.0
	if local_reconciler != null:
		predicted_pos = Vector3(local_reconciler.value("x"), local_reconciler.value("y"), local_reconciler.value("z"))
		reconcile_seq = int(local_reconciler.reconcile_seq)
		reconciler_pending = int(local_reconciler.pending_count)
		correction_mag = float(local_reconciler.last_correction_mag)
		drift_ema = float(local_reconciler.drift_ema)
	var input_sent := 0
	var input_ack := 0
	var input_pending := 0
	var input_epoch := 0
	if input_handle != null:
		input_sent = int(input_handle.sent_count)
		input_ack = int(input_handle.last_processed)
		input_pending = int(input_handle.pending_count)
		input_epoch = int(input_handle.epoch)
	return {
		"connected": connected,
		"initial_state": _has_initial_state,
		"lifecycle": _last_lifecycle_event,
		"drop_count": _drop_count,
		"reconnect_count": _reconnect_count,
		"reconnect_gap_ms": _last_reconnect_gap_ms,
		"sdk_reconnecting": room != null and room.reconnecting,
		"steps_due": _last_steps_due,
		"steps_due_max": _max_steps_due,
		"input_sent": input_sent,
		"input_ack": input_ack,
		"input_pending": input_pending,
		"input_epoch": input_epoch,
		"reconcile_seq": reconcile_seq,
		"reconciler_pending": reconciler_pending,
		"last_correction_m": correction_mag,
		"drift_ema_m": drift_ema,
		"local_driving": _local_driving_vehicle,
		"server_position": [server_pos.x, server_pos.y, server_pos.z],
		"predicted_position": [predicted_pos.x, predicted_pos.y, predicted_pos.z],
	}

func _predict_server_step(ctx: Variant, state: Variant, command: Variant) -> void:
	if state.health <= 0.0 or _local_driving_vehicle: return
	var move_x := float(command.move_x)
	var move_z := float(command.move_z)
	var magnitude := maxf(sqrt(move_x * move_x + move_z * move_z), 1.0)
	var speed := 8.8 if float(command.sprint) > 0.5 else (2.5 if float(command.crouch) > 0.5 else 6.2)
	var yaw := float(command.yaw)
	var from := Vector3(state.x, state.y, state.z)
	state.vx = (move_x * cos(yaw) - move_z * sin(yaw)) / magnitude * speed
	state.vz = (-move_x * sin(yaw) - move_z * cos(yaw)) / magnitude * speed
	var jump_requested := float(command.jump) > 0.5
	var idle_candidate := move_x == 0.0 and move_z == 0.0 and not jump_requested and absf(state.vy) <= 0.000001
	var current_floor: Variant = WorldGeometry.floor_height(state.x, state.z, state.y + 0.1) if jump_requested or idle_candidate else null
	var has_floor := current_floor != null
	var grounded_height: float = state.y if current_floor == null else float(current_floor)
	# The server's fixed step resolves the stationary capsule and clears velocity
	# when it starts exactly on the walkable floor with zero vertical speed. Only
	# that exact fixed point may skip the sweep: small height/velocity differences
	# still produce a distinct authoritative vertical result and use full physics.
	if idle_candidate and has_floor and absf(state.y - grounded_height) <= 0.000001:
		state.vx = 0.0
		state.vy = 0.0
		state.vz = 0.0
		return
	if jump_requested and absf(state.vy) < 0.001 and state.y <= grounded_height + 0.03:
		state.vy = 6.2
	state.vy -= 18.0 * ctx.dt
	var requested: Vector3 = from + Vector3(state.vx, state.vy, state.vz) * ctx.dt
	var resolved: Vector3 = WorldGeometry.resolve_move(from, requested)
	state.x = resolved.x
	state.y = resolved.y
	state.z = resolved.z
	state.vx = (state.x - from.x) / ctx.dt
	state.vz = (state.z - from.z) / ctx.dt
	var resolved_floor: Variant = WorldGeometry.floor_height(state.x, state.z, state.y + 0.1)
	var floor_height: float = state.y if resolved_floor == null else float(resolved_floor)
	if state.y <= floor_height + 0.03 and state.vy < 0.0:
		state.vy = 0.0

func _apply_local_reconciler() -> void:
	if local_reconciler == null: return
	var main := get_parent()
	if main == null or not "player" in main: return
	var player = main.player
	if not is_instance_valid(player) or player.is_driving: return
	player.global_position = Vector3(local_reconciler.value("x"), local_reconciler.value("y"), local_reconciler.value("z"))
	var predicted_state = local_reconciler.state
	if predicted_state != null:
		player.velocity = Vector3(predicted_state.vx, predicted_state.vy, predicted_state.vz)

func _on_message(kind: Variant, payload: Variant) -> void:
	if not payload is Dictionary: return
	var msg: Dictionary = payload
	match String(kind):
		"fire":
			fire_received.emit(String(msg.get("shooter", "")), _vec(msg.get("origin", [])), _vec(msg.get("hit", [])), _vec(msg.get("normal", [])), bool(msg.get("wall", false)))
		"hit_confirmed": hit_confirmed.emit()
		"kill_confirmed": kill_confirmed.emit()
		"damage": damage_received.emit(String(msg.get("target", "")), _vec(msg.get("pos", [])), _vec(msg.get("direction", [])), int(msg.get("amount", 0)))
		"respawn": respawn_received.emit(_vec(msg.get("pos", msg)))
		"grenade": grenade_received.emit(String(msg.get("shooter", "")), _vec(msg.get("pos", [])), _vec(msg.get("vel", [])), int(msg.get("id", 0)), String(msg.get("throwable", "frag")))
		"explosion": explosion_received.emit(int(msg.get("id", 0)), _vec(msg.get("pos", [])), String(msg.get("throwable", "frag")))

func _vec(value: Variant) -> Vector3:
	if value is Vector3: return value
	if value is Array and value.size() >= 3: return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary: return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
	return Vector3.ZERO

func disconnect_from() -> void:
	_want_connection = false
	if room != null:
		room.leave()
	room = null
	client = null
	input_handle = null
	predictor = null
	_local_driving_vehicle = false
	_set_connected(false)

func _process(delta: float) -> void:
	if room == null: return
	if not connected:
		if _want_connection and _drop_started_ms > 0 and Time.get_ticks_msec() - _drop_started_ms > CLIENT_RECONNECT_GRACE_MS:
			_drop_started_ms = 0
			_want_connection = false
			connection_error.emit("Colyseus reconnection timed out")
		return
	if input_handle == null: return
	if Input.is_action_just_pressed("jump"):
		_jump_pending = true
	var steps_due: int = predictor.tick() if predictor != null else 1
	_last_steps_due = maxi(steps_due, 0)
	_max_steps_due = maxi(_max_steps_due, _last_steps_due)
	for _step in range(_last_steps_due):
		_send_input_step()
	_apply_local_reconciler()

func _send_input_step() -> void:
	var data = input_handle.data
	data.move_x = Input.get_axis("move_left", "move_right")
	data.move_z = Input.get_axis("move_back", "move_forward")
	data.yaw = _desired_quat.get_euler().y
	data.pitch = _desired_pitch
	data.jump = 1.0 if _jump_pending else 0.0
	data.sprint = 1.0 if Input.is_action_pressed("sprint") else 0.0
	data.crouch = 1.0 if Input.is_action_pressed("crouch") else 0.0
	var sequence: int = input_handle.send()
	if sequence > 0:
		input_sequence = sequence
		_jump_pending = false
	var now := Time.get_ticks_msec()
	if now - _last_meta_ms >= 100:
		room.send_message("state_meta", {"animation": _desired_animation, "weapon": _desired_weapon})
		_last_meta_ms = now

func send_state(pos: Vector3, quat: Quaternion, anim: String, weapon: String) -> void:
	if not _valid(pos): return
	_desired_quat = quat
	_desired_animation = anim
	_desired_weapon = weapon

func send_aim_pitch(value: float) -> void:
	if is_finite(value): _desired_pitch = clampf(value, -1.55, 1.55)

func send_fire(origin: Vector3, hit: Vector3, normal: Vector3, wall: bool, shot_id: int = 0, yaw: float = 0.0, pitch: float = 0.0) -> void:
	if room != null: room.send_message("fire", {"origin": _arr(origin), "hit": _arr(hit), "normal": _arr(normal), "wall": wall, "shot_id": shot_id, "yaw": yaw, "pitch": pitch})

func send_fire_with_aim(origin: Vector3, hit: Vector3, normal: Vector3, wall: bool, shot_id: int, yaw: float, pitch: float) -> void:
	send_fire(origin, hit, normal, wall, shot_id, yaw, pitch)

func send_hit(target: String, damage: int, shot_id: int = 0, view_time_ms: int = 0) -> void:
	if room != null: room.send_message("hit", {"target": target, "damage": damage, "shot_id": shot_id, "view_time_ms": view_time_ms})

func send_reload() -> void:
	if room != null: room.send_message("reload", {})

func send_switch(wid: String) -> void:
	_desired_weapon = wid
	if room != null: room.send_message("switch", {"weapon": wid})

func send_loadout(primary: String, secondary: String, throwable: String) -> void:
	if room != null: room.send_message("loadout", {"primary": primary, "secondary": secondary, "throwable": throwable})

func send_respawn() -> void:
	if room != null: room.send_message("respawn", {})

func send_grenade(pos: Vector3, velocity: Vector3, kind: String = "frag") -> void:
	if room != null: room.send_message("grenade", {"pos": _arr(pos), "vel": _arr(velocity), "throwable": kind})

func send_vehicle_seat(id: String, enter: bool) -> void:
	if room != null: room.send_message("vehicle_seat", {"id": id, "enter": enter})

func send_vehicle_input(throttle: float, steer: float, brake: bool, gear: int) -> void:
	if room != null: room.send_message("vehicle_input", {"throttle": throttle, "steer": steer, "brake": brake, "gear": gear})

func send_ping_now() -> void:
	current_ping = int(room.clock.rtt()) if room != null else 0

func _arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]
