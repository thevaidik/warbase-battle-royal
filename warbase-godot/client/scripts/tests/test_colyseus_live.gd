extends Node
## Bounded live smoke for the pinned SDK transport, typed state, buffered input,
## and native rollback reconciler. Run against the local Colyseus server.

const Adapter := preload("res://scripts/net/ColyseusNetwork.gd")

var _adapter
var _second_adapter
var _username := ""
var _second_username := ""
var _finished := false
var _test_host := "localhost:8081"
var _second_started := false
var _reconnect_started := false
var _saw_drop := false
var _reconnected := false
var _waiting_for_removal := false
var _removal_seen := false
var _pose_clock_verified := false
var _fire_phase_started := false
var _fire_phase_progressed := false
var _fire_phase_start := 0.0
var _yaw_wrap_verified := false
var _yaw_wrap_failed := false
var _yaw_wrap_change_requested := false
var _yaw_wrap_negative_snapshot_seen := false
var _yaw_wrap_baseline_samples := 0
var _yaw_wrap_good_samples := 0
var _yaw_wrap_bad_samples := 0
var _yaw_wrap_trace: Array[Dictionary] = []
var _ready_peers := {1: false, 2: false}
var _sent_counts := {1: 0, 2: 0}
var _ack_counts := {1: 0, 2: 0}
var _reconcile_sequences := {1: 0, 2: 0}
var _second_initial_input_epoch := -1
var _reconnect_diagnostics: Dictionary = {}

func _ready() -> void:
	call_deferred("_start")

func _start() -> void:
	var configured_host := OS.get_environment("COLYSEUS_TEST_HOST")
	if not configured_host.is_empty(): _test_host = configured_host
	for action in ["move_left", "move_right", "move_back", "move_forward", "jump", "sprint", "crouch"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	_username = "SDK_%06d" % (Time.get_ticks_msec() % 1000000)
	_second_username = "SDK_%06d" % ((Time.get_ticks_msec() + 1) % 1000000)
	_adapter = _make_adapter(1, _username)
	_adapter.connect_to(_username, "industrial-public", _test_host)
	get_tree().create_timer(17.0).timeout.connect(_timeout)

func _make_adapter(index: int, username: String):
	var adapter = Adapter.new()
	get_tree().root.add_child(adapter)
	adapter.connection_error.connect(_fail)
	adapter.state_received.connect(_on_state.bind(index))
	return adapter

func _on_state(state: Dictionary, index: int) -> void:
	if _finished: return
	if int(state.get("protocol_version", 0)) != 5 or String(state.get("map_name", "")) != "industrial":
		_fail("unexpected room schema/version: %s" % state)
		return
	var adapter = _adapter if index == 1 else _second_adapter
	var username = _username if index == 1 else _second_username
	if adapter == null or not state.get("players", {}).has(username): return
	var player: Dictionary = state.players[username]
	if index == 1 and not _second_started:
		_second_started = true
		_second_adapter = _make_adapter(2, _second_username)
		_second_adapter._desired_animation = "run"
		_second_adapter.send_state(Vector3.ZERO, Quaternion(Vector3.UP, 3.12), "run", "ak47")
		_second_adapter.connection_changed.connect(_on_second_connection)
		_second_adapter.connect_to(_second_username, "industrial-public", _test_host)
		_set_fire_after_delay()
		_set_wrap_yaw_after_delay()
	var other_username = _second_username if index == 1 else _username
	if index == 1 and state.get("players", {}).has(_second_username):
		var remote_state: Dictionary = state.players[_second_username]
		var remote_poses: Dictionary = _adapter.get_sdk_remote_poses()
		var remote_pose: Dictionary = remote_poses.get(_second_username, {})
		var server_yaw := float(remote_state.get("yaw", 0.0))
		var rendered_yaw := float(remote_pose.get("yaw", 0.0))
		if not _yaw_wrap_change_requested:
			# The initial 0 -> +pi transition is not a wrap-boundary regression;
			# it legitimately passes through smaller magnitudes. Establish a
			# settled +pi baseline before asking for the +pi -> -pi transition.
			if server_yaw > 3.0 and absf(rendered_yaw) > 2.8:
				_yaw_wrap_baseline_samples += 1
			else:
				_yaw_wrap_baseline_samples = 0
		elif server_yaw < -3.0:
			_yaw_wrap_negative_snapshot_seen = true
		if _yaw_wrap_change_requested and _yaw_wrap_negative_snapshot_seen:
			if _yaw_wrap_trace.size() < 100:
				_yaw_wrap_trace.append({"t_ms": Time.get_ticks_msec(), "server_yaw": server_yaw, "rendered_yaw": rendered_yaw})
			if absf(rendered_yaw) > 2.8:
				_yaw_wrap_good_samples += 1
				_yaw_wrap_bad_samples = 0
				if _yaw_wrap_good_samples >= 3: _yaw_wrap_verified = true
			elif absf(rendered_yaw) < 2.0:
				_yaw_wrap_bad_samples += 1
				_yaw_wrap_good_samples = 0
				if _yaw_wrap_bad_samples >= 3: _yaw_wrap_failed = true
		if String(remote_state.get("animation", "")) == "firing":
			var pose: Dictionary = remote_pose
			var clock_check: Dictionary = _adapter.get_pose_clock_diagnostics()
			if clock_check.get("coherent", false) and absf(float(clock_check.get("render_delta_ms", INF))) <= 500.0:
				_pose_clock_verified = true
			if not pose.is_empty():
				var phase := float(pose.get("animation_time", 0.0))
				if not _fire_phase_started:
					_fire_phase_started = true
					_fire_phase_start = phase
				elif phase > _fire_phase_start + 0.15:
					_fire_phase_progressed = true
	if int(player.get("ack_input_sequence", 0)) >= 1 and adapter.local_reconciler != null and adapter.local_reconciler.reconcile_seq >= 1 and state.get("players", {}).has(other_username):
		_ready_peers[index] = true
		if index == 2 and _second_initial_input_epoch < 0:
			_second_initial_input_epoch = int(adapter.input_handle.epoch)
		_sent_counts[index] = maxi(_sent_counts[index], adapter.input_handle.sent_count)
		_ack_counts[index] = maxi(_ack_counts[index], adapter.input_handle.last_processed)
		_reconcile_sequences[index] = maxi(_reconcile_sequences[index], adapter.local_reconciler.reconcile_seq)
	if index == 1 and _waiting_for_removal and _second_username in state.get("removed_players", []):
		_removal_seen = true
		_finish_success()
		return
	if _ready_peers[1] and _ready_peers[2] and not _reconnect_started:
		_reconnect_started = true
		_drop_after_room_uptime()
	if index == 2 and _saw_drop and adapter.connected and state.get("players", {}).has(_username) and state.get("players", {}).has(_second_username) and adapter.local_reconciler != null:
		_reconnect_diagnostics = adapter.get_prediction_diagnostics()
		if int(_reconnect_diagnostics.get("drop_count", 0)) != 1 or int(_reconnect_diagnostics.get("reconnect_count", 0)) != 1 or String(_reconnect_diagnostics.get("lifecycle", "")) != "reconnected" or not bool(_reconnect_diagnostics.get("initial_state", false)) or int(_reconnect_diagnostics.get("input_epoch", -1)) <= _second_initial_input_epoch:
			_fail("reconnect lifecycle/policy state was inconsistent: %s" % _reconnect_diagnostics)
			return
		_reconnected = true
		_sent_counts[2] = maxi(_sent_counts[2], adapter.input_handle.sent_count)
		_ack_counts[2] = maxi(_ack_counts[2], adapter.input_handle.last_processed)
		_reconcile_sequences[2] = maxi(_reconcile_sequences[2], adapter.local_reconciler.reconcile_seq)
		_waiting_for_removal = true
		_second_adapter.disconnect_from()
	if _reconnected and _removal_seen:
		_finish_success()

func _on_second_connection(is_connected: bool) -> void:
	print("COLYSEUS_RECONNECT_CONNECTION_STATE ", is_connected, " saw_drop=", _saw_drop, " reconnecting=", _second_adapter.room.reconnecting if _second_adapter != null and _second_adapter.room != null else false)
	if not is_connected: _saw_drop = true

func _drop_after_room_uptime() -> void:
	await get_tree().create_timer(5.0).timeout
	if not _finished and _second_adapter != null and _second_adapter.connected:
		_second_adapter.room.drop()

func _set_fire_after_delay() -> void:
	await get_tree().create_timer(1.5).timeout
	if not _finished and _second_adapter != null:
		_second_adapter._desired_animation = "firing"

func _set_wrap_yaw_after_delay() -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while not _finished and _second_adapter != null and _yaw_wrap_baseline_samples < 3 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not _finished and _second_adapter != null and _yaw_wrap_baseline_samples >= 3:
		await get_tree().create_timer(0.2).timeout
		_yaw_wrap_change_requested = true
		_second_adapter.send_state(Vector3.ZERO, Quaternion(Vector3.UP, -3.12), "run", "ak47")
	elif not _finished:
		_yaw_wrap_failed = true
		push_error("Yaw wrap test never reached a settled +pi baseline")

func _finish_success() -> void:
	if _finished: return
	if not _pose_clock_verified or not _fire_phase_progressed or not _yaw_wrap_verified or _yaw_wrap_failed:
		var clock_check: Dictionary = _adapter.get_pose_clock_diagnostics()
		_fail("SDK clock/animation/yaw interpolation did not verify (raw=%0.1f ms server_offset=%0.1f ms render_delta=%0.1f ms coherent=%s phase_progress=%s yaw_wrap=%s yaw_failed=%s yaw_trace=%s)" % [clock_check.get("raw_delta_ms", INF), clock_check.get("server_offset_ms", INF), clock_check.get("render_delta_ms", INF), clock_check.get("coherent", false), _fire_phase_progressed, _yaw_wrap_verified, _yaw_wrap_failed, _yaw_wrap_trace])
		return
	_finished = true
	var clock_check: Dictionary = _adapter.get_pose_clock_diagnostics()
	print("COLYSEUS_LIVE_SMOKE_OK peers=2 sent=", _sent_counts[1], "/", _sent_counts[2], " ack=", _ack_counts[1], "/", _ack_counts[2], " reconcile_seq=", _reconcile_sequences[1], "/", _reconcile_sequences[2], " reconnect=", _reconnected, " reconnect_gap_ms=", _reconnect_diagnostics.get("reconnect_gap_ms", -1), " input_epoch=", _reconnect_diagnostics.get("input_epoch", -1), " input_pending=", _reconnect_diagnostics.get("input_pending", -1), " removal=", _removal_seen, " pose_clock_raw_delta_ms=", clock_check.get("raw_delta_ms", INF), " pose_clock_server_offset_ms=", clock_check.get("server_offset_ms", INF), " pose_clock_render_delta_ms=", clock_check.get("render_delta_ms", INF), " phase_progress=", _fire_phase_progressed, " yaw_wrap=", _yaw_wrap_verified)
	_adapter.disconnect_from()
	if _second_adapter != null: _second_adapter.disconnect_from()
	get_tree().quit(0)

func _fail(reason: String) -> void:
	if _finished: return
	_finished = true
	push_error("COLYSEUS_LIVE_SMOKE_FAILED: " + reason)
	if _adapter != null: _adapter.disconnect_from()
	if _second_adapter != null: _second_adapter.disconnect_from()
	get_tree().quit(1)

func _timeout() -> void:
	if _finished: return
	_finished = true
	push_error("COLYSEUS_LIVE_SMOKE_TIMEOUT peers=%s/%s reconcile=%s/%s reconnect=%s removal=%s saw_drop=%s connected=%s reconnecting=%s clock=%s phase=%s yaw=%s" % [_ready_peers[1], _ready_peers[2], _adapter.local_reconciler != null, _second_adapter != null and _second_adapter.local_reconciler != null, _reconnected, _removal_seen, _saw_drop, _second_adapter != null and _second_adapter.connected, _second_adapter != null and _second_adapter.room != null and _second_adapter.room.reconnecting, _pose_clock_verified, _fire_phase_progressed, _yaw_wrap_verified])
	if _adapter != null: _adapter.disconnect_from()
	if _second_adapter != null: _second_adapter.disconnect_from()
	get_tree().quit(2)
