extends Node3D

const GRENADES := "grenade_projectiles"
var _adapter := preload("res://scripts/net/ColyseusNetwork.gd").new()
var _manager := preload("res://scripts/net/MultiplayerManager.gd").new()
var _username := "grenade-test"

func _ready() -> void:
	add_child(_adapter)
	add_child(_manager)
	_manager.setup(_adapter, self, _username)
	_run()

func spawn_grenade(pos: Vector3, vel: Vector3, spin: Vector3 = Vector3.ZERO, kind: String = "frag") -> WarGrenade:
	return WarGrenade.throw(self, pos, vel, spin, kind)

func _run() -> void:
	var host := OS.get_environment("COLYSEUS_TEST_HOST")
	if host.is_empty(): host = "127.0.0.1:18301"
	_adapter.connect_to(_username, "industrial-public", host)
	if not await _until(func(): return _adapter.connected and _adapter.uses_projectile_spawns(GRENADES), "spawn collection unavailable"): return
	_adapter.room.set_latency(120.0)
	var player: Dictionary = _adapter._last_normalized_state.players[_username]
	var origin := Vector3(float(player.x), float(player.y) + 0.25, float(player.z))
	var velocity := Vector3(0, 8, -4)
	_adapter.send_grenade(origin, velocity, "frag")
	var key := _pending_key()
	if not _check(not key.is_empty(), "grenade did not appear before the server patch"): return
	_manager._render_projectiles(0.0)
	var visual: Node3D = _manager._projectile_nodes[key]
	await get_tree().create_timer(0.06).timeout
	var advancing := _entry(key)
	if not _check(not advancing.is_empty() and int(advancing["server_id"]) == 0 and Vector3(advancing["position"]).distance_to(origin) > 0.02,
		"local projectile did not move before the delayed server patch"): return
	if not await _until(func(): return _entry(key).get("server_id", 0) > 0, "grenade did not retain its spawn ID on confirmation"): return
	if not _check(_manager._projectile_nodes[key] == visual, "confirmed spawn replaced the original visual"): return

	_adapter.send_grenade(origin + Vector3.UP * 50.0, velocity, "frag")
	var rejected_key := _pending_key()
	if not _check(not rejected_key.is_empty(), "rejection fixture did not predict"): return
	if not await _until(func(): return _entry(rejected_key).is_empty(), "rejected grenade remained visible"): return
	if not _check(not _entry(key).is_empty(), "rejecting a throw removed a confirmed grenade"): return

	await get_tree().create_timer(0.95).timeout
	if not _check(_adapter._projectile_prediction.spawn(GRENADES, 9001, "frag", origin, velocity), "expiry fixture did not predict"): return
	var expiry_key := _pending_key()
	if not await _until(func(): return _entry(expiry_key).is_empty(), "unconfirmed spawn did not expire", 2500): return
	_adapter.disconnect_from()
	if not _check(_adapter.projectile_views().is_empty() and _manager._projectile_nodes.is_empty(), "disconnect left projectile state behind"): return
	print("GRENADE_PREDICTION_SETTLEMENT_TEST_OK stable_sdk_id rejection expiry disconnect")
	get_tree().quit()

func _pending_key() -> String:
	for view in _adapter.projectile_views():
		if view["collection"] == GRENADES and int(view["server_id"]) == 0:
			return view["key"]
	return ""

func _entry(key: String) -> Dictionary:
	for view in _adapter.projectile_views():
		if view["key"] == key: return view
	return {}

func _until(predicate: Callable, message: String, timeout_ms := 5000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return _check(bool(predicate.call()), message)

func _check(condition: bool, message: String) -> bool:
	if condition: return true
	push_error("GRENADE_PREDICTION_SETTLEMENT_TEST_FAILED: " + message)
	get_tree().quit(1)
	return false
