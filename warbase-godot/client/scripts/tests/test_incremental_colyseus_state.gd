extends Node

const Adapter := preload("res://scripts/net/ColyseusNetwork.gd")
const TEST_HOST := "127.0.0.1:18196"

var _adapter
var _second_adapter
var _username := ""
var _second_username := ""
var _finished := false
var _patch_sent := false
var _vehicle_scalars_patch_sent := false
var _vehicle_scalars_verified := false
var _vehicle_scalars_started_ms := 0
var _counts_before_vehicle_scalars: Dictionary = {}
var _root_patch_sent := false
var _remote_pose_wait_started := false
var _remote_pose_verified := false
var _second_removed := false
var _reconnect_started := false
var _reconnect_verified := false
var _prediction_mode_stage := 0
var _baseline_entity_counts: Dictionary = {}
var _counts_before_root_patch: Dictionary = {}

func _ready() -> void:
	call_deferred("_start")

func _start() -> void:
	for action in ["move_left", "move_right", "move_back", "move_forward", "jump", "sprint", "crouch"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	_username = "Incremental_%d" % Time.get_ticks_msec()
	_second_username = _username + "_peer"
	_adapter = _make_adapter(1)
	_adapter.connect_to(_username, "industrial-public", TEST_HOST)
	get_tree().create_timer(20.0).timeout.connect(func(): _fail("timed out waiting for callback contract"))

func _make_adapter(index: int):
	var adapter = Adapter.new()
	get_tree().root.add_child(adapter)
	adapter.connection_error.connect(_fail)
	adapter.state_received.connect(_on_state.bind(index))
	return adapter

func _on_state(state: Dictionary, index: int) -> void:
	if _finished: return
	if index != 1: return
	if int(state.get("protocol_version", 0)) != 8 or String(state.get("map_name", "")) != "industrial":
		_fail("unexpected fixture state header: %s" % state)
		return
	var players: Dictionary = state.get("players", {})
	var diagnostics: Dictionary = _adapter.get_state_conversion_diagnostics()
	if not bool(diagnostics.get("callbacks_available", false)):
		_fail("SDK schema callbacks unavailable; callback conversion contract not exercised: %s" % diagnostics)
		return
	if not players.has(_username): return

	if _second_adapter == null:
		var vehicles: Dictionary = state.get("vehicles", {})
		var objectives: Dictionary = state.get("objectives", {})
		if int(state.get("score_a", -1)) != 0 or int(state.get("tickets_a", -1)) != 500:
			_fail("initial root values were not decoded: %s" % state)
			return
		if not vehicles.has("CAR_TEST") or vehicles.CAR_TEST.get("pos") != Vector3(1, 2, 3):
			_fail("initial vehicle coordinate was not normalized: %s" % vehicles)
			return
		if not objectives.has("A") or not is_equal_approx(float(objectives.A.get("progress", -1)), 0.125):
			_fail("initial objective missing or stale: %s" % objectives)
		var counts: Dictionary = diagnostics.get("entity_conversions", {})
		if int(counts.get("player", 0)) != 1 or int(counts.get("vehicle", 0)) != 1 or int(counts.get("objective", 0)) != 1:
			_fail("initial cache was not populated once per entity: %s" % counts)
		_baseline_entity_counts = diagnostics.get("entity_conversion_counts", {}).duplicate(true)
		_second_adapter = _make_adapter(2)
		_second_adapter.connect_to(_second_username, "industrial-public", TEST_HOST)
		return

	if not _patch_sent and players.has(_second_username):
		_adapter.room.send_message("qa_patch", {"target": _second_username})
		_patch_sent = true
		return
	if _patch_sent and not _vehicle_scalars_patch_sent and not _root_patch_sent and int(state.get("score_a", 0)) == 1:
		if int(state.get("tickets_a", 0)) != 499:
			_fail("root ticket change was lost: %s" % state)
			return
		var peer: Dictionary = players.get(_second_username, {})
		var objective: Dictionary = state.get("objectives", {}).get("A", {})
		if int(peer.get("health", -1)) != 87 or String(peer.get("anim", "")) != "run":
			_fail("changed player cache did not refresh all fields: %s" % peer)
			return
		var raw_peer: Dictionary = _adapter._player_state_cache.get(_second_username, {})
		if int(raw_peer.get("health", -1)) != 87 or int(raw_peer.get("x", -1)) != 11 or String(raw_peer.get("animation", "")) != "run":
			_fail("raw cached player snapshot did not preserve authoritative values: %s" % raw_peer)
			return
		if not is_equal_approx(float(objective.get("progress", -1)), 0.375):
			_fail("objective cache change was stale: %s" % objective)
			return
		var changed_counts: Dictionary = _adapter.get_state_conversion_diagnostics().get("entity_conversion_counts", {})
		if int(changed_counts.get("player:" + _username, 0)) != int(_baseline_entity_counts.get("player:" + _username, 0)):
			_fail("unmodified local player was reconverted during peer update: %s" % changed_counts)
			return
		if int(changed_counts.get("player:" + _second_username, 0)) != 2 or int(changed_counts.get("vehicle:CAR_TEST", 0)) != 1 or int(changed_counts.get("objective:A", 0)) != 2:
			_fail("player/objective patch converted an unrelated vehicle or missed a changed entity: %s" % changed_counts)
			return
		if not _vehicle_scalars_patch_sent:
			_vehicle_scalars_patch_sent = true
			_vehicle_scalars_started_ms = Time.get_ticks_msec()
			_counts_before_vehicle_scalars = changed_counts.duplicate(true)
			_adapter.room.send_message("qa_vehicle_scalars", {})
			_wait_for_vehicle_scalars_patch()
		return
	if _vehicle_scalars_patch_sent and not _vehicle_scalars_verified and not _root_patch_sent and int(state.get("score_a", 0)) == 1:
		var vehicle: Dictionary = state.get("vehicles", {}).get("CAR_TEST", {})
		if vehicle.get("pos") != Vector3(12, 2, 34):
			if Time.get_ticks_msec() - _vehicle_scalars_started_ms < 2000: return
			_fail("in-place vehicle scalar-only patches did not converge: %s" % vehicle)
			return
		if Vector3(float(vehicle.get("x", 0)), float(vehicle.get("y", 0)), float(vehicle.get("z", 0))) != Vector3(12, 2, 34):
			_fail("normalized vehicle position differs from decoded scalar coordinates: %s" % vehicle)
			return
		var raw_vehicle: Dictionary = _adapter._vehicle_state_cache.get("CAR_TEST", {})
		if raw_vehicle.has("pos") or Vector3(float(raw_vehicle.get("x", 0)), float(raw_vehicle.get("y", 0)), float(raw_vehicle.get("z", 0))) != Vector3(12, 2, 34):
			_fail("raw scalar cache was missed or polluted by presentation aliases: %s" % raw_vehicle)
			return
		var array_counts: Dictionary = _adapter.get_state_conversion_diagnostics().get("entity_conversion_counts", {})
		if int(array_counts.get("vehicle:CAR_TEST", 0)) <= int(_counts_before_vehicle_scalars.get("vehicle:CAR_TEST", 0)) or int(array_counts.get("player:" + _username, 0)) != int(_counts_before_vehicle_scalars.get("player:" + _username, 0)) or int(array_counts.get("player:" + _second_username, 0)) != int(_counts_before_vehicle_scalars.get("player:" + _second_username, 0)) or int(array_counts.get("objective:A", 0)) != int(_counts_before_vehicle_scalars.get("objective:A", 0)):
			_fail("array-only update did not target only the changed vehicle: %s" % array_counts)
			return
		_vehicle_scalars_verified = true
		_root_patch_sent = true
		_counts_before_root_patch = array_counts.duplicate(true)
		_adapter.room.send_message("qa_root_patch", {})
		return
	if _root_patch_sent and not _second_removed and int(state.get("score_a", 0)) == 2:
		var after_root_patch: Dictionary = _adapter.get_state_conversion_diagnostics().get("entity_conversion_counts", {})
		for entity_key in _counts_before_root_patch:
			if int(_counts_before_root_patch[entity_key]) != int(after_root_patch.get(entity_key, -1)):
				_fail("root scalar patch reconverted an entity")
				return
		if int(state.get("tickets_a", 0)) != 498:
			_fail("root score/ticket patch did not propagate: %s" % state)
			return
		var normalized_peer: Dictionary = state.get("players", {}).get(_second_username, {})
		if int(normalized_peer.get("health", -1)) != 87 or String(normalized_peer.get("anim", "")) != "run":
			_fail("later root-only patch corrupted normalized player fields: %s" % normalized_peer)
			return
		var preserved_raw_peer: Dictionary = _adapter._player_state_cache.get(_second_username, {})
		if int(preserved_raw_peer.get("x", -1)) != 11 or int(preserved_raw_peer.get("health", -1)) != 87:
			_fail("SDK pose interpolation mutated the raw cached snapshot: %s" % preserved_raw_peer)
			return
		if not _remote_pose_wait_started:
			_remote_pose_wait_started = true
			_wait_for_remote_pose_without_state_patch()
		return
	if _second_removed and _second_username in state.get("removed_players", []):
		if players.has(_second_username):
			_fail("removed player remained in normalized players: %s" % players.keys())
			return
		var removed_diagnostics: Dictionary = _adapter.get_state_conversion_diagnostics()
		if int(removed_diagnostics.get("cache_sizes", {}).get("players", -1)) != 1 or int(removed_diagnostics.get("object_callback_count", -1)) != 3 or removed_diagnostics.get("entity_conversion_counts", {}).has("player:" + _second_username):
			_fail("removed player's callback/cache was retained: %s" % removed_diagnostics)
		if not _reconnect_started:
			_reconnect_started = true
			_adapter.disconnect_from()
			var cleanup: Dictionary = _adapter.get_state_conversion_diagnostics()
			var empty_cache: Dictionary = cleanup.get("cache_sizes", {})
			if int(empty_cache.get("players", -1)) != 0 or int(empty_cache.get("vehicles", -1)) != 0 or int(empty_cache.get("objectives", -1)) != 0 or int(cleanup.get("object_callback_count", -1)) != 0 or cleanup.get("callbacks_available", true):
				_fail("disconnect left cached schema references/callbacks behind: %s" % cleanup)
				return
			_reconnect_after_leave()
		return
	if _reconnect_started and not _reconnect_verified and players.has(_username):
		if players.has(_second_username):
			_fail("reconnected adapter exposed an alias from its previous room")
			return
		if int(diagnostics.get("cache_sizes", {}).get("players", 0)) != 1:
			_fail("reconnected cache did not rebuild from the new room: %s" % diagnostics)
		_reconnect_verified = true
		if _adapter.local_reconciler == null or _adapter._composite_prediction:
			_fail("on-foot state did not bind the SDK entity reconciler")
			return
		_prediction_mode_stage = 1
		_adapter.room.send_message("qa_prediction_mode", {"driving":true})
		return
	if _reconnect_verified and _prediction_mode_stage == 1 and not String(players.get(_username, {}).get("driving_vehicle", "")).is_empty():
		if not _adapter._composite_prediction or _adapter.local_reconciler == null or _adapter.local_reconciler.world == null:
			_fail("vehicle entry did not bind the SDK composite reconciler")
			return
		_prediction_mode_stage = 2
		_adapter.room.send_message("qa_prediction_mode", {"driving":false})
		return
	if _reconnect_verified and _prediction_mode_stage == 2 and String(players.get(_username, {}).get("driving_vehicle", "")).is_empty():
		if _adapter._composite_prediction or _adapter.local_reconciler == null or _adapter.local_reconciler.world != null:
			_fail("vehicle exit did not restore the SDK entity reconciler")
			return
		_prediction_mode_stage = 3
		_finish_success()

func _wait_for_remote_pose_without_state_patch() -> void:
	var deadline := Time.get_ticks_msec() + 2500
	while not _finished and Time.get_ticks_msec() < deadline:
		var pose: Dictionary = _adapter.get_sdk_remote_poses().get(_second_username, {})
		if not pose.is_empty() and absf(float(pose.get("x", 0.0)) - 11.0) <= 0.15:
			_remote_pose_verified = true
			_second_adapter.disconnect_from()
			_second_removed = true
			return
		await get_tree().process_frame
	if not _finished: _fail("SDK remote pose did not converge to cached x=11 without another state patch")

func _wait_for_vehicle_scalars_patch() -> void:
	await get_tree().create_timer(2.0).timeout
	if not _finished and not _vehicle_scalars_verified:
		_fail("in-place vehicle ArraySchema callback did not produce the final position")

func _reconnect_after_leave() -> void:
	await get_tree().create_timer(0.3).timeout
	if not _finished: _adapter.connect_to(_username, "industrial-public", TEST_HOST)

func _finish_success() -> void:
	if _finished: return
	if not _remote_pose_verified:
		_fail("SDK remote pose convergence was not verified")
		return
	_finished = true
	print("INCREMENTAL_COLYSEUS_STATE_OK callbacks=true root_scalars=true player_add_change_remove=true vehicle_scalars=true objective_change=true cleanup_reconnect=true flat_composite_handoff=true")
	_adapter.disconnect_from()
	if _second_adapter != null: _second_adapter.disconnect_from()
	get_tree().quit(0)

func _fail(reason: String) -> void:
	if _finished: return
	_finished = true
	push_error("INCREMENTAL_COLYSEUS_STATE_FAILED " + reason)
	if _adapter != null: _adapter.disconnect_from()
	if _second_adapter != null: _second_adapter.disconnect_from()
	get_tree().quit(1)
