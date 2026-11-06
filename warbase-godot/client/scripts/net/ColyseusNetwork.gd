class_name WarColyseusNetwork
extends WarNetwork
## Colyseus SDK adapter. Inputs are staged through the SDK's reflected buffered
## input channel; decoded room state and lifecycle events feed WarNetwork's API.

const SchemaTypes := preload("res://scripts/net/ColyseusSchema.gd")
const AdmissionSession := preload("res://scripts/net/AdmissionSession.gd")
const WorldGeometry := preload("res://scripts/net/ColyseusWorldGeometry.gd")
const RemotePoseTiming := preload("res://scripts/qa/RemotePoseTiming.gd")
const VehiclePrediction := preload("res://scripts/net/ColyseusVehiclePrediction.gd")
# Leave one second of margin before the server's 15-second seat-reconnection expiry.
const CLIENT_RECONNECT_GRACE_MS := 14000
const PREDICTION_MOVE_CACHE_LIMIT := 4096
# Prediction is initialized only after the decoded state/controller. Both
# runtime targets passed short, default and production-TTL expiry checks.
const GRENADE_EVENT_PREDICTION_ENABLED := true
const GRENADE_WEB_EVENT_PREDICTION_VERIFIED := true

var client
var room
var predictor
var grenade_events
var input_handle
var local_reconciler
var _reconciled_instance
var _composite_prediction := false
var _prediction_car_names: Array[String] = []
var _vehicle_gear := 1
var _gameplay_input_enabled := true
var _last_normalized_state: Dictionary = {}
var _state_callbacks
var _room_signal_bindings: Array[Dictionary] = []
var _state_callback_failed := false
var _state_callback_handles: Array[int] = []
var _object_callback_handles: Dictionary = {}
var _nested_callback_handles: Dictionary = {}
var _player_state_cache: Dictionary = {}
var _vehicle_state_cache: Dictionary = {}
var _objective_state_cache: Dictionary = {}
var _schema_instances := {"player": {}, "vehicle": {}, "objective": {}}
var _dirty_schema_objects := {"player": {}, "vehicle": {}, "objective": {}}
var _state_cache_conversion_counts := {"player": 0, "vehicle": 0, "objective": 0}
var _state_cache_entity_conversions: Dictionary = {}
var _has_initial_state := false
var _last_meta_ms := 0
var _sent_animation := ""
var _sent_weapon := ""
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
var _connection_generation := 0
var _awaiting_fresh_state := false
var _reconnect_transport_ready := false
var _input_epoch_before_drop := -1
var _jump_pending := false
var _drop_count := 0
var _reconnect_count := 0
var _last_reconnect_gap_ms := -1
var _last_lifecycle_event := ""
var _last_steps_due := 0
var _max_steps_due := 0
var _qa_timing := false
var _qa_step_us := 0
var _qa_step_count := 0
var _qa_step_max_us := 0
var _qa_vehicle_us := 0
var _qa_vehicle_count := 0
var _qa_vehicle_max_us := 0
var _qa_state_us := 0
var _qa_state_count := 0
var _qa_state_max_us := 0
var _prediction_move_cache: Dictionary = {}
var _prediction_cache_map := ""
var _qa_move_cache_hits := 0
var _qa_move_cache_misses := 0
var _qa_remote_pose_timing
var _next_grenade_request_id := 0
var _want_connection := false
var _username := "Player"
var _room := "industrial-public"
var _host := "localhost:8081"
var _admission_endpoint := ""
var _admission_token := ""

func connect_to(username: String, room_name: String, host: String) -> void:
	disconnect_from()
	_gameplay_input_enabled = true
	_sent_animation = ""
	_sent_weapon = ""
	grenade_events = null
	_qa_timing = _qa_timing or "qa_official" in OS.get_cmdline_user_args()
	_qa_step_us = 0
	_qa_step_count = 0
	_qa_step_max_us = 0
	_qa_vehicle_us = 0
	_qa_vehicle_count = 0
	_qa_vehicle_max_us = 0
	_qa_state_us = 0
	_qa_state_count = 0
	_qa_state_max_us = 0
	_prediction_move_cache.clear()
	_prediction_cache_map = ""
	_qa_move_cache_hits = 0
	_qa_move_cache_misses = 0
	_qa_remote_pose_timing = RemotePoseTiming.new() if _qa_timing else null
	_connection_generation += 1
	var generation := _connection_generation
	_username = username
	_room = room_name
	_host = host
	_want_connection = true
	_has_initial_state = false
	_awaiting_fresh_state = false
	_input_epoch_before_drop = -1
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
	_admission_endpoint = AdmissionSession.canonical_endpoint(endpoint)
	_admission_token = ""
	client = Colyseus.Client.new(endpoint)
	AdmissionSession.ensure(client, _admission_endpoint, _on_admission_ready.bind(username, room_name, generation))

func _on_admission_ready(token: String, error: Variant, username: String, room_name: String, generation: int) -> void:
	if generation != _connection_generation or not _want_connection: return
	if error != null:
		var status := int(error.get("code", -1)) if error is Dictionary else -1
		var detail := String(error.get("message", "")) if error is Dictionary else String(error)
		if OS.has_feature("editor") and status == 404 and AdmissionSession.is_loopback_endpoint(_admission_endpoint):
			push_warning("Colyseus admission endpoint returned 404; allowing unsigned editor fixture connection")
		else:
			_want_connection = false
			client = null
			_set_connected(false)
			connection_error.emit("Unable to obtain Colyseus admission ticket" + (": " + detail if not detail.is_empty() else ""))
			return
	_admission_token = token
	room = client.join_or_create("battle", {
		"username": username,
		"protocol_version": 7,
		"room": room_name,
		"map": GameState.selected_map,
		"mode": GameState.selected_mode,
		"time_of_day": GameState.selected_time,
	})
	if room == null:
		_want_connection = false
		connection_error.emit("Unable to create Colyseus room connection")
		return
	room.set_state_type(SchemaTypes.RoomState)
	_connect_room_signal(room, &"joined", _on_joined.bind(room, generation))
	_connect_room_signal(room, &"state_changed", _on_state_changed.bind(room, generation))
	_connect_room_signal(room, &"message_received", _on_message.bind(room, generation))
	_connect_room_signal(room, &"error", _on_room_error.bind(room, generation))
	_connect_room_signal(room, &"left", _on_room_left.bind(room, generation))
	_connect_room_signal(room, &"dropped", _on_room_dropped.bind(room, generation))
	_connect_room_signal(room, &"reconnected", _on_joined.bind(room, generation))

func _connect_room_signal(source_room: Variant, signal_name: StringName, callback: Callable) -> void:
	source_room.connect(signal_name, callback)
	_room_signal_bindings.append({"room": source_room, "signal": signal_name, "callback": callback})

func _disconnect_room_signals() -> void:
	# Bound generation guards keep the emitting RefCounted room as an argument.
	# Break that room -> callback -> room cycle on terminal teardown.
	for binding in _room_signal_bindings:
		var source_room: Variant = binding["room"]
		if is_instance_valid(source_room) and source_room.is_connected(binding["signal"], binding["callback"]):
			source_room.disconnect(binding["signal"], binding["callback"])
	_room_signal_bindings.clear()

func _exit_tree() -> void:
	disconnect_from()

func _is_current_room(source_room: Variant, generation: int) -> bool:
	return generation == _connection_generation and source_room != null and source_room == room and _want_connection

func _on_room_error(code: int, message: String, source_room: Variant, generation: int) -> void:
	if not _is_current_room(source_room, generation): return
	if code == 401: AdmissionSession.invalidate(_admission_endpoint, _admission_token)
	_fail_current_room(message if not message.is_empty() else "Colyseus room error %d" % code, source_room, generation, "error")

func _on_room_left(_code: int, reason: String, source_room: Variant, generation: int) -> void:
	if _qa_timing: print("QA_ROOM_LEFT code=%d reason=%s" % [_code, reason])
	if not _is_current_room(source_room, generation): return
	_fail_current_room("Colyseus room closed: " + reason, source_room, generation, "left", false)

func _on_room_dropped(_code: int, _reason: String, source_room: Variant, generation: int) -> void:
	if not _is_current_room(source_room, generation): return
	if grenade_events != null: grenade_events.clear()
	grenade_events = null
	_clear_incremental_state_cache()
	_drop_started_ms = maxi(Time.get_ticks_msec(), 1)
	_drop_count += 1
	_input_epoch_before_drop = int(input_handle.epoch) if input_handle != null else -1
	_awaiting_fresh_state = true
	_reconnect_transport_ready = false
	_has_initial_state = false
	_last_lifecycle_event = "dropped"
	_set_connected(false)

func _fail_current_room(reason: String, source_room: Variant, generation: int, event: String, should_leave := true) -> void:
	if not _is_current_room(source_room, generation): return
	if grenade_events != null: grenade_events.clear()
	grenade_events = null
	_clear_incremental_state_cache()
	_disconnect_room_signals()
	# Invalidate callbacks before leave(), which can synchronously emit `left`.
	_connection_generation += 1
	_want_connection = false
	_drop_started_ms = 0
	_awaiting_fresh_state = false
	_reconnect_transport_ready = false
	_last_lifecycle_event = event
	room = null
	client = null
	input_handle = null
	predictor = null
	local_reconciler = null
	_reconciled_instance = null
	_composite_prediction = false
	_prediction_car_names.clear()
	_last_normalized_state = {}
	_prediction_move_cache.clear()
	_prediction_cache_map = ""
	_has_initial_state = false
	_local_driving_vehicle = false
	_admission_token = ""
	_set_connected(false)
	source_room.set_reconnection_options({"enabled": false})
	if should_leave: source_room.leave()
	connection_error.emit(reason)

func _on_joined(source_room: Variant, generation: int) -> void:
	if not _is_current_room(source_room, generation): return
	_sent_animation = ""
	_sent_weapon = ""
	if _drop_started_ms > 0 and Time.get_ticks_msec() - _drop_started_ms >= CLIENT_RECONNECT_GRACE_MS:
		_fail_current_room("Colyseus reconnection timed out", source_room, generation, "timeout")
		return
	var was_reconnecting := _drop_started_ms > 0 or _awaiting_fresh_state
	if was_reconnecting:
		_reconnect_count += 1
		_last_reconnect_gap_ms = Time.get_ticks_msec() - _drop_started_ms
		_last_lifecycle_event = "reconnected"
	else:
		_last_lifecycle_event = "joined"
	_want_connection = true
	_reconnect_transport_ready = was_reconnecting
	# The SDK's default min-uptime rejects reconnects for rooms dropped soon
	# after joining. The server explicitly allows reconnect windows, so avoid
	# discarding a valid seat on short-lived network interruption.
	room.set_reconnection_options({"min_uptime_ms": 0})
	input_handle = room.input()
	if input_handle == null:
		_fail_current_room("Colyseus server did not declare buffered inputs", source_room, generation, "error")
		return
	predictor = Colyseus.Predict.of(room)
	_begin_incremental_state_cache()
	predictor.attach_all("players", {
		"x": Colyseus.Predict.LERP,
		"y": Colyseus.Predict.LERP,
		"z": Colyseus.Predict.LERP,
		"yaw": {"mode": Colyseus.Predict.LERP, "angle": true},
	}, _username)
	local_reconciler = null
	_reconciled_instance = null
	_awaiting_fresh_state = was_reconnecting
	if not was_reconnecting: _set_connected(true)

func _clear_incremental_state_cache() -> void:
	if _state_callbacks != null:
		for handle in _state_callback_handles:
			if handle >= 0: _state_callbacks.remove(handle)
	_state_callback_handles.clear()
	for handle in _object_callback_handles.values():
		if handle >= 0 and _state_callbacks != null: _state_callbacks.remove(handle)
	_object_callback_handles.clear()
	for handle in _nested_callback_handles.values():
		if handle >= 0 and _state_callbacks != null: _state_callbacks.remove(handle)
	_nested_callback_handles.clear()
	_state_callbacks = null
	_state_callback_failed = false
	_player_state_cache.clear()
	_vehicle_state_cache.clear()
	_objective_state_cache.clear()
	_schema_instances = {"player": {}, "vehicle": {}, "objective": {}}
	_dirty_schema_objects = {"player": {}, "vehicle": {}, "objective": {}}
	_state_cache_conversion_counts = {"player": 0, "vehicle": 0, "objective": 0}
	_state_cache_entity_conversions.clear()

func _begin_incremental_state_cache() -> void:
	_clear_incremental_state_cache()
	_state_callbacks = Colyseus.Callbacks.of(room)
	if _state_callbacks == null: return
	_state_callback_handles.append(_state_callbacks.on_add("players", _on_player_added))
	_state_callback_handles.append(_state_callbacks.on_remove("players", _on_player_removed))
	_state_callback_handles.append(_state_callbacks.on_add("vehicles", _on_vehicle_added))
	_state_callback_handles.append(_state_callbacks.on_remove("vehicles", _on_vehicle_removed))
	_state_callback_handles.append(_state_callbacks.on_add("objectives", _on_objective_added))
	_state_callback_handles.append(_state_callbacks.on_remove("objectives", _on_objective_removed))
	for handle in _state_callback_handles:
		if handle < 0: _state_callback_failed = true

func _watch_schema_object(schema: Variant, kind: String, key: String) -> void:
	_schema_instances[kind][key] = schema
	_mark_schema_object_dirty(kind, key, schema)
	if _state_callbacks == null: return
	var mark_dirty := func():
		if is_instance_valid(self) and _state_callbacks != null:
			_mark_schema_object_dirty(kind, key, schema)
	var handle: int = _state_callbacks.on_change(schema, mark_dirty)
	if handle < 0: _state_callback_failed = true
	_object_callback_handles[kind + ":" + key] = handle

func _mark_schema_object_dirty(kind: String, key: String, schema: Variant) -> void:
	if _schema_instances.get(kind, {}).get(key) == schema:
		_dirty_schema_objects[kind][key] = schema

func _flush_incremental_state_cache() -> void:
	for kind in ["player", "vehicle", "objective"]:
		var cache: Dictionary = _cache_for_kind(kind)
		var dirty: Dictionary = _dirty_schema_objects[kind]
		for key in dirty:
			var schema: Variant = dirty[key]
			if _schema_instances[kind].get(key) != schema: continue
			cache[key] = SchemaTypes.to_dictionary(schema)
			_record_entity_conversion(kind, key)
		dirty.clear()

func _cache_for_kind(kind: String) -> Dictionary:
	match kind:
		"player": return _player_state_cache
		"vehicle": return _vehicle_state_cache
		"objective": return _objective_state_cache
	return {}

func _record_entity_conversion(kind: String, key: String) -> void:
	_state_cache_conversion_counts[kind] += 1
	var entity_key := kind + ":" + key
	_state_cache_entity_conversions[entity_key] = int(_state_cache_entity_conversions.get(entity_key, 0)) + 1

func _on_player_added(player: Variant, key: String) -> void:
	_watch_schema_object(player, "player", key)

func _on_player_removed(_player: Variant, key: String) -> void:
	_player_state_cache.erase(key)
	_schema_instances["player"].erase(key)
	_dirty_schema_objects["player"].erase(key)
	_remove_object_callback("player", key)

func _on_vehicle_added(vehicle: Variant, key: String) -> void:
	_watch_schema_object(vehicle, "vehicle", key)

func _on_vehicle_removed(_vehicle: Variant, key: String) -> void:
	_vehicle_state_cache.erase(key)
	_schema_instances["vehicle"].erase(key)
	_dirty_schema_objects["vehicle"].erase(key)
	_remove_object_callback("vehicle", key)

func _on_objective_added(objective: Variant, key: String) -> void:
	_watch_schema_object(objective, "objective", key)

func _on_objective_removed(_objective: Variant, key: String) -> void:
	_objective_state_cache.erase(key)
	_schema_instances["objective"].erase(key)
	_dirty_schema_objects["objective"].erase(key)
	_remove_object_callback("objective", key)

func _remove_object_callback(kind: String, key: String) -> void:
	var callback_key := kind + ":" + key
	_state_cache_entity_conversions.erase(callback_key)
	if _object_callback_handles.has(callback_key):
		var handle: int = _object_callback_handles[callback_key]
		if handle >= 0 and _state_callbacks != null: _state_callbacks.remove(handle)
		_object_callback_handles.erase(callback_key)
	var nested_key := callback_key + ":pos"
	if _nested_callback_handles.has(nested_key):
		var nested_handle: int = _nested_callback_handles[nested_key]
		if nested_handle >= 0 and _state_callbacks != null: _state_callbacks.remove(nested_handle)
		_nested_callback_handles.erase(nested_key)

func _snapshot_incremental_state(decoded: Variant) -> Variant:
	if decoded == null: return null
	if _state_callbacks == null or _state_callback_failed:
		var complete: Variant = SchemaTypes.to_dictionary(decoded)
		if complete is Dictionary:
			_player_state_cache = complete.get("players", {}).duplicate(true)
			_vehicle_state_cache = complete.get("vehicles", {}).duplicate(true)
			_objective_state_cache = complete.get("objectives", {}).duplicate(true)
		return complete
	var state := {
		"protocol_version": decoded.get("protocol_version"),
		"map_name": decoded.get("map_name"),
		"time_of_day": decoded.get("time_of_day"),
		"room_mode": decoded.get("room_mode"),
		"score_a": decoded.get("score_a"),
		"score_b": decoded.get("score_b"),
		"winner": decoded.get("winner"),
		"tickets_a": decoded.get("tickets_a"),
		"tickets_b": decoded.get("tickets_b"),
		"room_state": decoded.get("room_state"),
	}
	# Keep the cache itself private until each normalized player is copied below;
	# that avoids rebuilding a second full set of nested player dictionaries.
	state["players"] = _player_state_cache
	state["vehicles"] = _vehicle_state_cache.duplicate(true)
	state["objectives"] = _objective_state_cache.duplicate(true)
	return state

## QA diagnostics used by the incremental-schema callback regression scene.
func get_state_conversion_diagnostics() -> Dictionary:
	return {
		"callbacks_available": _state_callbacks != null and not _state_callback_failed,
		"cache_sizes": {
			"players": _player_state_cache.size(),
			"vehicles": _vehicle_state_cache.size(),
			"objectives": _objective_state_cache.size(),
		},
		"entity_conversions": _state_cache_conversion_counts.duplicate(true),
		"entity_conversion_counts": _state_cache_entity_conversions.duplicate(true),
		"object_callback_count": _object_callback_handles.size() + _nested_callback_handles.size(),
	}

func _on_state_changed(source_room: Variant, generation: int) -> void:
	if not _is_current_room(source_room, generation): return
	if _drop_started_ms > 0 and Time.get_ticks_msec() - _drop_started_ms >= CLIENT_RECONNECT_GRACE_MS:
		_fail_current_room("Colyseus reconnection timed out", source_room, generation, "timeout")
		return
	if _awaiting_fresh_state and not _reconnect_transport_ready: return
	var timing_start := Time.get_ticks_usec() if _qa_timing else 0
	var ready_after_state := false
	var decoded = source_room.get_state()
	if _state_callbacks != null and not _state_callback_failed:
		_flush_incremental_state_cache()
	var state = _snapshot_incremental_state(decoded)
	if state is Dictionary:
		if not _has_initial_state:
			var players: Dictionary = state.get("players", {})
			if int(state.get("protocol_version", 0)) != 7:
				_fail_current_room("Server and client versions differ. Update the game and server together.", source_room, generation, "version")
				return
			if not players.has(_username): return
			_has_initial_state = true
			if _awaiting_fresh_state:
				_awaiting_fresh_state = false
				_reconnect_transport_ready = false
				_drop_started_ms = 0
				ready_after_state = true
		var authoritative_map := String(state.get("map_name", ""))
		if not authoritative_map.is_empty():
			WorldGeometry.set_map_override(authoritative_map)
		var instances: Dictionary = decoded.get("players") if decoded != null else {}
		var normalized_players := {}
		for player_id in instances:
			# Never normalize into the raw authoritative snapshot. SDK interpolation
			# and aliases belong to this per-emission copy only.
			var player_state: Dictionary = _player_state_cache.get(String(player_id), {}).duplicate(true)
			if player_state.is_empty(): continue
			var public_id := String(player_state.get("username", player_id))
			var pose_rotation := Quaternion(Vector3.UP, float(player_state.get("yaw", 0.0)))
			player_state["rx"] = pose_rotation.x
			player_state["ry"] = pose_rotation.y
			player_state["rz"] = pose_rotation.z
			player_state["rw"] = pose_rotation.w
			player_state["anim"] = player_state.get("animation", "idle")
			player_state["weapon"] = player_state.get("weapon_id", "ak47")
			if predictor != null and instances.has(player_id):
				var instance = instances[player_id]
				if public_id == _username and input_handle != null and (instance != _reconciled_instance or _composite_prediction != (int(player_state.get("vehicle_index", -1)) >= 0)):
					_reconciled_instance = instance
					# Use the SDK's smaller entity reconciler on foot. The multi-part
					# world is needed only while driving and colliding with vehicles.
					local_reconciler = null
					_prediction_car_names.clear()
					_composite_prediction = int(player_state.get("vehicle_index", -1)) >= 0
					if _composite_prediction:
						var composite_world := {"player": instance}
						var vehicle_instances: Dictionary = decoded.get("vehicles")
						for car_id in vehicle_instances:
							_prediction_car_names.append(String(car_id))
							composite_world[String(car_id)] = vehicle_instances[car_id]
						local_reconciler = predictor.sim({"input": input_handle, "world": composite_world, "step": Callable(self, "_predict_composite_step"), "smooth_ms": 80.0, "snap": 1.5})
					else:
						local_reconciler = predictor.reconciler(instance, {"input": input_handle, "fields": ["x", "y", "z", "vx", "vy", "vz", "health"], "step": Callable(self, "_predict_infantry_step"), "smooth_ms": 80.0, "snap": 1.5})
					# A room may report joined before its first state/controller is
					# available. Bind event lifetime to the initialized prediction epoch.
					if _grenade_prediction_enabled() and local_reconciler != null and grenade_events == null:
						grenade_events = predictor.define_event({"ttl_ms": 5000.0, "on_reject": _on_grenade_event_rejected})
				if public_id != _username:
					for field in ["x", "y", "z"]:
						var predicted: float = predictor.value(instance, field)
						if is_finite(predicted): player_state[field] = predicted
			normalized_players[public_id] = player_state
		var local_player_state: Dictionary = normalized_players.get(_username, {})
		if bool(_last_normalized_state.get("players", {}).get(_username, {}).get("is_dead", false)) and not bool(local_player_state.get("is_dead", false)):
			_sent_animation = ""
			_sent_weapon = ""
		_local_driving_vehicle = not String(local_player_state.get("driving_vehicle", "")).is_empty()
		var removed_players: Array[String] = []
		for previous_id in _last_normalized_state.get("players", {}).keys():
			if not normalized_players.has(previous_id): removed_players.append(String(previous_id))
		state["removed_players"] = removed_players
		state["players"] = normalized_players
		var normalized_vehicles: Dictionary = state.get("vehicles", {})
		for vehicle_id in normalized_vehicles.keys():
			var vehicle_state: Dictionary = normalized_vehicles[vehicle_id]
			vehicle_state["pos"] = Vector3(float(vehicle_state.get("x", 0.0)), float(vehicle_state.get("y", 0.0)), float(vehicle_state.get("z", 0.0)))
		state["vehicles"] = normalized_vehicles
		_last_normalized_state = state
		if ready_after_state: _set_connected(true)
		state_received.emit(state)
		_apply_local_reconciler()
		if _qa_timing:
			var elapsed := Time.get_ticks_usec() - timing_start
			_qa_state_us += elapsed
			_qa_state_count += 1
			_qa_state_max_us = maxi(_qa_state_max_us, elapsed)

func get_sdk_remote_poses() -> Dictionary:
	var timing_start := Time.get_ticks_usec() if _qa_timing else 0
	var players: Dictionary = _last_normalized_state.get("players", {})
	if players.is_empty():
		if _qa_timing: _qa_remote_pose_timing.record(Time.get_ticks_usec() - timing_start, 0)
		return {}
	var decoded = room.get_state() if room != null and predictor != null else null
	var instances: Dictionary = decoded.get("players") if decoded != null else {}
	var render_time_ms := float(room.clock.render_now()) if room != null and predictor != null else 0.0
	var sdk_server_time_ms := float(room.clock.server_now()) if room != null and predictor != null else 0.0
	var poses := {}
	for username in players:
		if username == _username: continue
		# Rendering consumes pose/animation fields only; inventory, score and
		# loadout data stay in the state cache instead of being copied every frame.
		var source: Dictionary = players[username]
		var pose := {
			"x": source.get("x", 0.0), "y": source.get("y", 0.0), "z": source.get("z", 0.0),
			"yaw": source.get("yaw", 0.0), "anim": source.get("anim", "idle"),
			"animation_time": source.get("animation_time", 0.0),
			"pose_time_ms": source.get("pose_time_ms", render_time_ms),
			"is_dead": source.get("is_dead", false),
		}
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
	if _qa_timing: _qa_remote_pose_timing.record(Time.get_ticks_usec() - timing_start, poses.size())
	return poses

## Explicit QA report; ordinary gameplay does not allocate timing samples or summaries.
func get_remote_pose_preparation_diagnostics() -> Dictionary:
	return _qa_remote_pose_timing.summary() if _qa_timing and _qa_remote_pose_timing != null else {"enabled": false}

func set_qa_timing(enabled: bool) -> void:
	_qa_timing = enabled
	_qa_remote_pose_timing = RemotePoseTiming.new() if enabled else null

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
		predicted_pos = get_predicted_player_position()
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
		"awaiting_fresh_state": _awaiting_fresh_state,
		"input_epoch_before_drop": _input_epoch_before_drop,
		"sdk_reconnecting": room != null and room.reconnecting,
		"steps_due": _last_steps_due,
		"steps_due_max": _max_steps_due,
		"input_sent": input_sent,
		"input_ack": input_ack,
		"input_pending": input_pending,
		"input_epoch": input_epoch,
		"qa_prediction_step_count": _qa_step_count,
		"qa_prediction_step_mean_us": float(_qa_step_us) / maxi(_qa_step_count, 1),
		"qa_prediction_step_max_us": _qa_step_max_us,
		"qa_vehicle_step_count": _qa_vehicle_count,
		"qa_vehicle_step_mean_us": float(_qa_vehicle_us) / maxi(_qa_vehicle_count, 1),
		"qa_vehicle_step_max_us": _qa_vehicle_max_us,
		"qa_vehicle_ray_cache": VehiclePrediction.ray_cache_stats() if _qa_timing else {},
		"qa_state_count": _qa_state_count,
		"qa_state_mean_us": float(_qa_state_us) / maxi(_qa_state_count, 1),
		"qa_state_max_us": _qa_state_max_us,
		"qa_move_cache_hits": _qa_move_cache_hits,
		"qa_move_cache_misses": _qa_move_cache_misses,
		"reconcile_seq": reconcile_seq,
		"reconciler_pending": reconciler_pending,
		"last_correction_max_numeric": correction_mag,
		"drift_ema_numeric": drift_ema,
		"local_driving": _local_driving_vehicle,
		"server_position": [server_pos.x, server_pos.y, server_pos.z],
		"predicted_position": [predicted_pos.x, predicted_pos.y, predicted_pos.z],
	}

func _profiled_predict_server_step(ctx: Variant, state: Variant, command: Variant) -> void:
	var started := Time.get_ticks_usec()
	_predict_server_step(ctx, state, command)
	var elapsed := Time.get_ticks_usec() - started
	_qa_step_us += elapsed
	_qa_step_count += 1
	_qa_step_max_us = maxi(_qa_step_max_us, elapsed)

func _resolve_prediction_move(from: Vector3, to: Vector3) -> Vector3:
	# Reuse only an exactly identical sweep on the same static map. A replay
	# starting from a different server position still runs the collision solver.
	var map_name := WorldGeometry.get_loaded_map()
	if map_name != _prediction_cache_map:
		_prediction_move_cache.clear()
		_prediction_cache_map = map_name
	if map_name.is_empty(): return WorldGeometry.resolve_move(from, to)
	var key := [from, to]
	if _prediction_move_cache.has(key):
		if _qa_timing: _qa_move_cache_hits += 1
		return _prediction_move_cache[key]
	if _qa_timing: _qa_move_cache_misses += 1
	var result: Vector3 = WorldGeometry.resolve_move(from, to)
	if _prediction_move_cache.size() >= PREDICTION_MOVE_CACHE_LIMIT:
		_prediction_move_cache.clear()
	_prediction_move_cache[key] = result
	return result

func _predict_server_step(ctx: Variant, state: Variant, command: Variant) -> void:
	if state.health <= 0.0: return
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
	if jump_requested and has_floor and absf(state.vy) < 0.001 and state.y >= grounded_height - 0.06 and state.y <= grounded_height + 0.3:
		state.vy = 6.2
	state.vy -= 18.0 * ctx.dt
	var requested: Vector3 = from + Vector3(state.vx, state.vy, state.vz) * ctx.dt
	var resolved: Vector3 = _resolve_prediction_move(from, requested)
	state.x = resolved.x
	state.y = resolved.y
	state.z = resolved.z
	state.vx = (state.x - from.x) / ctx.dt
	state.vz = (state.z - from.z) / ctx.dt
	var resolved_floor: Variant = WorldGeometry.floor_height(state.x, state.z, state.y + 0.1)
	state.vy = WorldGeometry.settled_vertical_velocity(float(state.vy), requested.y, resolved.y, resolved_floor)

func _predict_composite_step(ctx: Variant, world: Variant, command: Variant) -> void:
	var state: Variant = world.get("player")
	if state == null or float(state.health) <= 0.0: return
	if int(state.vehicle_index) >= 0:
		var started := Time.get_ticks_usec() if _qa_timing else 0
		VehiclePrediction.step(world, command, float(ctx.dt), _prediction_car_names)
		if _qa_timing:
			var elapsed := Time.get_ticks_usec() - started
			_qa_vehicle_us += elapsed
			_qa_vehicle_count += 1
			_qa_vehicle_max_us = maxi(_qa_vehicle_max_us, elapsed)
	else:
		_predict_infantry_step(ctx, state, command)

func _predict_infantry_step(ctx: Variant, state: Variant, command: Variant) -> void:
	var infantry_command: Variant = command
	if int(command.vehicle_index) >= 0:
		infantry_command = {"move_x": 0.0, "move_z": 0.0, "jump": 0.0, "sprint": 0.0, "crouch": 0.0, "yaw": float(command.yaw)}
	if _qa_timing: _profiled_predict_server_step(ctx, state, infantry_command)
	else: _predict_server_step(ctx, state, infantry_command)

func get_predicted_player_position() -> Vector3:
	if local_reconciler == null: return Vector3.ZERO
	var prefix := "player." if _composite_prediction else ""
	return Vector3(local_reconciler.value(prefix + "x"), local_reconciler.value(prefix + "y"), local_reconciler.value(prefix + "z"))

func is_vehicle_prediction_active(id: String) -> bool:
	if not connected or local_reconciler == null or not _composite_prediction: return false
	var me: Dictionary = _last_normalized_state.get("players", {}).get(_username, {})
	return String(me.get("driving_vehicle", "")) == id and _prediction_car_names.has(id)

func _apply_local_vehicle_reconciler() -> void:
	var main := get_parent()
	if not _composite_prediction or local_reconciler == null or main == null or not "_online_vehicles" in main: return
	for id in _prediction_car_names:
		if not is_vehicle_prediction_active(id) or not main._online_vehicles.has(id): continue
		var vehicle = main._online_vehicles[id]
		if not is_instance_valid(vehicle): continue
		var at := Vector3(local_reconciler.value(id + ".x"), local_reconciler.value(id + ".y"), local_reconciler.value(id + ".z"))
		var yaw: float = local_reconciler.value(id + ".yaw")
		if not _valid(at) or not is_finite(yaw): continue
		vehicle.global_position = at
		vehicle.rotation.y = yaw
		vehicle.network_position = at
		vehicle.network_yaw = yaw
		var speed: float = local_reconciler.value(id + ".speed")
		vehicle.current_speed_kmh = absf(speed) * 3.6
		vehicle.is_reversing = speed < 0.0

func _apply_local_reconciler() -> void:
	if local_reconciler == null: return
	_apply_local_vehicle_reconciler()
	var main := get_parent()
	if main == null or not "player" in main: return
	var player = main.player
	if not is_instance_valid(player) or player.is_driving: return
	player.global_position = get_predicted_player_position()
	var predicted_state: Variant = local_reconciler.world.get("player") if _composite_prediction else local_reconciler.state
	if predicted_state != null:
		var predicted_velocity := Vector3(predicted_state.vx, predicted_state.vy, predicted_state.vz)
		# CharacterBody.is_on_floor() is not refreshed by authoritative pose writes.
		# Use the same authored floor as prediction to drive local body feedback.
		var floor_value: Variant = WorldGeometry.floor_height(predicted_state.x, predicted_state.z, predicted_state.y + 0.1)
		var ground_gap: float = predicted_state.y - float(floor_value) if floor_value != null else INF
		var grounded := ground_gap >= -0.06 and ground_gap <= 0.3 and absf(predicted_velocity.y) <= 0.1
		var crouching := Input.is_action_pressed("crouch")
		var sprinting := Input.is_action_pressed("sprint") and grounded and Vector2(predicted_velocity.x, predicted_velocity.z).length() > 0.5
		player.apply_authoritative_motion(predicted_velocity, grounded, crouching, sprinting)

func _on_message(kind: Variant, payload: Variant, source_room: Variant, generation: int) -> void:
	if not _is_current_room(source_room, generation): return
	if not payload is Dictionary: return
	var msg: Dictionary = payload
	if String(kind) == "identity":
		# The server normalizes display names before using them as player keys.
		# Apply its identity before waiting for the matching state entry.
		var canonical_name := String(msg.get("username", ""))
		if not canonical_name.is_empty():
			_username = canonical_name
			var scene := get_tree().current_scene if is_inside_tree() else null
			if scene != null and "net" in scene and scene.net == self:
				GameState.username = canonical_name
		return
	if not connected: return
	match String(kind):
		"fire":
			fire_received.emit(String(msg.get("shooter", "")), _vec(msg.get("origin", [])), _vec(msg.get("hit", [])), _vec(msg.get("normal", [])), bool(msg.get("wall", false)))
		"hit_confirmed": hit_confirmed.emit()
		"kill_confirmed": kill_confirmed.emit()
		"damage": damage_received.emit(String(msg.get("target", "")), _vec(msg.get("pos", [])), _vec(msg.get("direction", [])), int(msg.get("amount", 0)))
		"respawn": respawn_received.emit(_vec(msg.get("pos", msg)))
		"grenade": _on_grenade_message(msg)
		"grenade_rejected": _settle_grenade_rejection(int(msg.get("request_id", 0)))
		"explosion": explosion_received.emit(int(msg.get("id", 0)), _vec(msg.get("pos", [])), String(msg.get("throwable", "frag")))

func _vec(value: Variant) -> Vector3:
	if value is Vector3: return value
	if value is Array and value.size() >= 3: return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary: return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
	return Vector3.ZERO

func _on_grenade_message(msg: Dictionary) -> void:
	var shooter := String(msg.get("shooter", ""))
	var request_id := int(msg.get("request_id", 0))
	if request_id > 0 and shooter == _username and grenade_events != null:
		grenade_events.confirm(str(request_id))
	grenade_received.emit(shooter, _vec(msg.get("pos", [])), _vec(msg.get("vel", [])), int(msg.get("id", 0)), String(msg.get("throwable", "frag")), request_id)

func disconnect_from() -> void:
	_want_connection = false
	if grenade_events != null: grenade_events.clear()
	grenade_events = null
	# Invalidate bound signal callbacks before leaving: leave() may emit `left`
	# immediately, and an SDK reconnect callback may already be queued.
	_connection_generation += 1
	var old_room = room
	_disconnect_room_signals()
	_clear_incremental_state_cache()
	room = null
	client = null
	input_handle = null
	predictor = null
	local_reconciler = null
	_reconciled_instance = null
	_last_normalized_state = {}
	_prediction_move_cache.clear()
	_prediction_cache_map = ""
	_has_initial_state = false
	_awaiting_fresh_state = false
	_reconnect_transport_ready = false
	_drop_started_ms = 0
	_input_epoch_before_drop = -1
	_local_driving_vehicle = false
	_admission_token = ""
	_admission_endpoint = ""
	_set_connected(false)
	if old_room != null:
		old_room.set_reconnection_options({"enabled": false})
		old_room.leave()

func _process(delta: float) -> void:
	if room == null: return
	if not connected:
		if _want_connection and _drop_started_ms > 0 and Time.get_ticks_msec() - _drop_started_ms >= CLIENT_RECONNECT_GRACE_MS:
			_fail_current_room("Colyseus reconnection timed out", room, _connection_generation, "timeout")
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
	data.move_x = Input.get_axis("move_left", "move_right") if _gameplay_input_enabled else 0.0
	data.move_z = Input.get_axis("move_back", "move_forward") if _gameplay_input_enabled else 0.0
	data.yaw = _desired_quat.get_euler().y
	data.pitch = _desired_pitch
	data.jump = 1.0 if _jump_pending and _gameplay_input_enabled else 0.0
	data.sprint = 1.0 if Input.is_action_pressed("sprint") and _gameplay_input_enabled else 0.0
	data.crouch = 1.0 if Input.is_action_pressed("crouch") and _gameplay_input_enabled else 0.0
	var me: Dictionary = _last_normalized_state.get("players", {}).get(_username, {})
	data.vehicle_index = float(me.get("vehicle_index", -1))
	data.vehicle_generation = float(me.get("vehicle_generation", 0))
	data.vehicle_throttle = Input.get_axis("move_back", "move_forward") if _local_driving_vehicle and _gameplay_input_enabled else 0.0
	data.vehicle_steer = Input.get_axis("move_left", "move_right") if _local_driving_vehicle and _gameplay_input_enabled else 0.0
	data.vehicle_brake = 1.0 if Input.is_action_pressed("jump") or not _local_driving_vehicle or not _gameplay_input_enabled else 0.0
	data.vehicle_gear = float(_vehicle_gear)
	var sequence: int = input_handle.send()
	if sequence > 0:
		input_sequence = sequence
		_jump_pending = false
	_send_metadata_if_needed(Time.get_ticks_msec())

func _send_metadata_if_needed(now: int) -> void:
	if room == null or now - _last_meta_ms < 100: return
	if _sent_animation == _desired_animation and _sent_weapon == _desired_weapon: return
	room.send_message("state_meta", {"animation": _desired_animation, "weapon": _desired_weapon})
	_sent_animation = _desired_animation
	_sent_weapon = _desired_weapon
	_last_meta_ms = now

func set_gameplay_input_enabled(enabled: bool) -> void:
	_gameplay_input_enabled = enabled
	if not enabled: _jump_pending = false

func send_state(pos: Vector3, quat: Quaternion, anim: String, weapon: String) -> void:
	if not _valid(pos): return
	_desired_quat = quat
	_desired_animation = anim
	_desired_weapon = weapon

func send_aim_pitch(value: float) -> void:
	if is_finite(value): _desired_pitch = clampf(value, -1.55, 1.55)

func send_fire(origin: Vector3, hit: Vector3, normal: Vector3, wall: bool, shot_id: int = 0, yaw: float = 0.0, pitch: float = 0.0) -> void:
	if room != null and _gameplay_input_enabled: room.send_message("fire", {"origin": _arr(origin), "hit": _arr(hit), "normal": _arr(normal), "wall": wall, "shot_id": shot_id, "yaw": yaw, "pitch": pitch})

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

func predict_grenade(request_id: int) -> bool:
	return _grenade_prediction_enabled() and grenade_events != null and grenade_events.predict(str(request_id))

func _grenade_prediction_enabled() -> bool:
	return GRENADE_EVENT_PREDICTION_ENABLED and (not OS.has_feature("web") or GRENADE_WEB_EVENT_PREDICTION_VERIFIED)

func _settle_grenade_rejection(request_id: int) -> void:
	if grenade_events != null and request_id > 0:
		grenade_events.reject(str(request_id))
	else:
		grenade_rejected.emit(request_id)

func _on_grenade_event_rejected(key: String) -> void:
	grenade_rejected.emit(int(key))

func send_grenade(pos: Vector3, velocity: Vector3, kind: String = "frag") -> int:
	if room == null or not _gameplay_input_enabled: return 0
	_next_grenade_request_id += 1
	var request_id := _next_grenade_request_id
	if not predict_grenade(request_id):
		# Let the reliable authoritative broadcast create the visible grenade.
		room.send_message("grenade", {"pos": _arr(pos), "vel": _arr(velocity), "throwable": kind, "request_id": 0})
		return 0
	room.send_message("grenade", {"pos": _arr(pos), "vel": _arr(velocity), "throwable": kind, "request_id": request_id})
	return request_id

func send_vehicle_seat(id: String, enter: bool) -> void:
	if room != null and _gameplay_input_enabled: room.send_message("vehicle_seat", {"id": id, "enter": enter})

func send_vehicle_input(throttle: float, steer: float, brake: bool, gear: int) -> void:
	# Controls are sampled once per SDK input tick; this legacy-shaped entry
	# point only stages the selected gear for Main's existing vehicle UI.
	_vehicle_gear = 2 if gear == 2 else 1

func send_ping_now() -> void:
	current_ping = int(room.clock.rtt()) if room != null else 0

func _arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]
