extends Node
var adapter = preload("res://scripts/net/ColyseusNetwork.gd").new()
var username := ""
var failed := false

func _ready() -> void:
	Engine.max_fps = 60
	username = "SeatReconnect_%d" % (Time.get_ticks_msec() % 10000)
	add_child(adapter)
	adapter.connect_to(username, "industrial-public", "127.0.0.1:18195")
	await run()

func run() -> void:
	if not await until(func(): return adapter.connected and adapter.local_reconciler != null and adapter.uses_projectile_spawns("grenade_projectiles")): return
	adapter.send_vehicle_seat("CAR_0", true)
	if not await until(func(): return me().get("driving_vehicle", "") == "CAR_0"): return
	var generation := int(me().vehicle_generation)
	Input.action_press("move_forward")
	await get_tree().create_timer(0.6).timeout
	Input.action_release("move_forward")
	if not check(predict_grenade(9101), "pre-drop event was not created"): return
	adapter.room.drop()
	if not await until(func(): return adapter._drop_count == 1): return
	if not await until(func(): return adapter.connected and adapter._reconnect_count == 1 and adapter.local_reconciler != null and adapter.uses_projectile_spawns("grenade_projectiles")): return
	if not check(me().get("driving_vehicle", "") == "" and int(me().vehicle_index) == -1 and int(me().vehicle_generation) > generation, "reconnect retained old seat"): return
	if not check(adapter.projectile_views().is_empty(), "reconnect retained old predicted grenade"): return
	adapter.send_vehicle_seat("CAR_0", true)
	if not await until(func(): return me().get("driving_vehicle", "") == "CAR_0"): return
	var ack_before := int(adapter.input_handle.last_processed)
	Input.action_press("move_forward")
	await get_tree().create_timer(0.6).timeout
	Input.action_release("move_forward")
	if not check(int(adapter.input_handle.last_processed) > ack_before, "reconnected input ACK did not advance"): return
	adapter.room.send_message("qa_kill_driver", {})
	if not await until(func(): return bool(me().get("is_dead", false)) and me().get("driving_vehicle", "") == ""): return
	if not check(int(me().vehicle_index) == -1 and String(adapter._last_normalized_state.vehicles.CAR_0.driver).is_empty(), "death retained occupied seat"): return
	# An unresolved spawn after a reconnect exercises the replacement collection
	# and predictor through its complete production expiry, while dead.
	if not check(predict_grenade(9102), "post-reconnect channel missing"): return
	if not await until(func(): return adapter.projectile_views().is_empty(), 7500): return
	print("NATIVE_VEHICLE_RECONNECT_OK drive; drop; fresh seat generation; input ACK resumed; death cleared seat; replacement grenade collection expired safely")
	adapter.disconnect_from()
	get_tree().quit()

func predict_grenade(request_id: int) -> bool:
	return adapter._projectile_prediction.spawn("grenade_projectiles", request_id, "frag", Vector3(0, 5, 0), Vector3.UP)

func me() -> Dictionary:
	return adapter._last_normalized_state.get("players", {}).get(username, {})

func until(predicate: Callable, timeout_ms: int = 10000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return check(bool(predicate.call()), "condition deadline, state=" + str(me()))

func check(ok: bool, message: String) -> bool:
	if ok: return true
	failed = true
	Input.action_release("move_forward")
	print("NATIVE_VEHICLE_RECONNECT_FAILED ", message)
	adapter.disconnect_from()
	get_tree().quit(1)
	return false
