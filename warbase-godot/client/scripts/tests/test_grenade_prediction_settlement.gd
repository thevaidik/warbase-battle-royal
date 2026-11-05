extends Node3D

var _adapter := preload("res://scripts/net/ColyseusNetwork.gd").new()
var _network := preload("res://scripts/net/NetworkManager.gd").new()
var _manager := preload("res://scripts/net/MultiplayerManager.gd").new()

func _ready() -> void:
	add_child(_adapter)
	add_child(_network)
	add_child(_manager)
	_manager.setup(_adapter, self, "grenade-test")
	_adapter._username = "grenade-test"
	_run()

func spawn_grenade(pos: Vector3, vel: Vector3, spin: Vector3 = Vector3.ZERO, kind: String = "frag") -> WarGrenade:
	return WarGrenade.throw(self, pos, vel, spin, kind)

func _run() -> void:
	var predicted := spawn_grenade(Vector3(1, 5, 1), Vector3(10, 4, 1))
	_manager.register_predicted_grenade(41, predicted)
	predicted.global_position = Vector3(4, 4, 1)
	predicted.linear_velocity = Vector3(8, -1, 0.8)
	_manager._on_grenade("grenade-test", Vector3(1.2, 5, 1.1), Vector3(10.5, 4.1, 1), 701, "frag", 41)
	if not _check(_manager._pending_grenades.is_empty(), "accepted event did not settle the pending request"): return
	if not _check(predicted.get_meta("server_id", -1) == 701, "accepted event did not adopt the predicted node"): return
	if not _check(predicted.global_position.is_equal_approx(Vector3(4.2, 4, 1.1)), "adoption rewound elapsed grenade flight"): return
	if not _check(predicted.linear_velocity.is_equal_approx(Vector3(8.5, -0.9, 0.8)), "adoption failed to correct velocity without resetting flight"): return
	var grenade_count := get_tree().get_nodes_in_group("grenades").size()
	_manager._on_grenade("grenade-test", Vector3.ZERO, Vector3.ZERO, 701, "frag", 41)
	if not _check(get_tree().get_nodes_in_group("grenades").size() == grenade_count, "duplicate confirmation spawned another grenade"): return

	var rejected := spawn_grenade(Vector3(0, 3, 0), Vector3(1, 2, 0))
	_manager.register_predicted_grenade(42, rejected)
	_adapter._on_grenade_event_rejected("42")
	if not _check(_manager._pending_grenades.is_empty(), "SDK rejection callback left a pending cosmetic"): return
	await get_tree().process_frame
	if not _check(not is_instance_valid(rejected), "rejected cosmetic was not retired"): return

	var disconnected := spawn_grenade(Vector3(0, 3, 0), Vector3(1, 2, 0))
	_manager.register_predicted_grenade(43, disconnected)
	_manager._on_connection_changed(false)
	await get_tree().process_frame
	if not _check(_manager._pending_grenades.is_empty() and not is_instance_valid(disconnected), "disconnect did not retire pending cosmetics"): return

	var respawned := spawn_grenade(Vector3(0, 3, 0), Vector3(1, 2, 0))
	_manager.register_predicted_grenade(44, respawned)
	_manager.clear_pending_grenades() # Main._on_net_respawn calls this path.
	await get_tree().process_frame
	if not _check(_manager._pending_grenades.is_empty() and not is_instance_valid(respawned), "respawn did not retire pending cosmetics"): return

	var live_username := "GrenadeTTL_%d" % (Time.get_ticks_msec() % 1000000)
	_manager.local_name = live_username
	var live_host := OS.get_environment("COLYSEUS_TEST_HOST")
	if live_host.is_empty(): live_host = "localhost:18194"
	_adapter.connect_to(live_username, "industrial-public", live_host)
	var connect_deadline := Time.get_ticks_msec() + 10000
	while (not _adapter.connected or _adapter.local_reconciler == null or _adapter.grenade_events == null) and Time.get_ticks_msec() < connect_deadline:
		await get_tree().process_frame
	if not _check(_adapter.connected and _adapter.predictor != null, "could not connect to the local Colyseus test server"): return
	if not _check(_adapter.predict_grenade(9001), "initialized native EventChannel did not predict"): return
	var rejected_ids: Array[int] = []
	_adapter.grenade_rejected.connect(func(request_id: int) -> void: rejected_ids.append(request_id))
	var sdk_rejected := spawn_grenade(Vector3(0, 3, 0), Vector3(1, 2, 0))
	_manager.register_predicted_grenade(9001, sdk_rejected)
	_adapter.grenade_events.reject("9001")
	await get_tree().process_frame
	if not _check(rejected_ids.has(9001), "SDK EventChannel reject did not emit its rejection callback"): return
	if not _check(_manager._pending_grenades.is_empty() and not is_instance_valid(sdk_rejected), "SDK rejection callback did not retire the pending cosmetic"): return

	var live_player: Dictionary = _adapter._last_normalized_state.get("players", {}).get(live_username, {})
	if not _check(not live_player.is_empty(), "server state did not include the connected test player"): return
	var launch_pos := Vector3(float(live_player.x), float(live_player.y) + 1.2, float(live_player.z))
	var authoritative_events: Array[Dictionary] = []
	_adapter.grenade_received.connect(func(shooter: String, pos: Vector3, vel: Vector3, grenade_id: int, kind: String, request_id: int) -> void:
		authoritative_events.append({"shooter": shooter, "id": grenade_id, "request_id": request_id}))
	var sent_request_id := _adapter.send_grenade(launch_pos, Vector3(0, 2, 0), "frag")
	if not _check(sent_request_id > 0, "native throw did not create a predicted request"): return
	var live_predicted := spawn_grenade(launch_pos, Vector3(0, 2, 0))
	_manager.register_predicted_grenade(sent_request_id, live_predicted)
	var grenade_deadline := Time.get_ticks_msec() + 3000
	while authoritative_events.is_empty() and Time.get_ticks_msec() < grenade_deadline:
		await get_tree().process_frame
	if not _check(not authoritative_events.is_empty(), "server did not return the authoritative grenade spawn"): return
	var authoritative_event: Dictionary = authoritative_events.back()
	if not _check(int(authoritative_event.request_id) == sent_request_id and int(authoritative_event.id) > 0, "server did not confirm the predicted request"): return
	var rendered_server_grenade := false
	for grenade in get_tree().get_nodes_in_group("grenades"):
		if int(grenade.get_meta("server_id", -1)) == int(authoritative_event.id): rendered_server_grenade = true
	if not _check(rendered_server_grenade, "authoritative broadcast did not create the local visual"): return
	if not _check(live_predicted.get_meta("server_id", -1) == int(authoritative_event.id) and _adapter.grenade_events.pending_count == 0, "confirmation did not adopt the same cosmetic and settle the SDK event"): return
	var inventory_deadline := Time.get_ticks_msec() + 1000
	while int(_adapter._last_normalized_state.players[live_username].get("grenades", 2)) > 1 and Time.get_ticks_msec() < inventory_deadline:
		await get_tree().process_frame
	if not _check(int(_adapter._last_normalized_state.players[live_username].get("grenades", 2)) <= 1, "throw did not consume authoritative inventory"): return
	# Exercise the production 5-second TTL with the actual composite prediction
	# loop, not a second custom timer/rejection implementation.
	if not _check(_adapter.predict_grenade(9002), "expiry request was not accepted"): return
	var expired := spawn_grenade(Vector3(0, 3, 0), Vector3.ZERO)
	_manager.register_predicted_grenade(9002, expired)
	var expiry_deadline := Time.get_ticks_msec() + 7000
	while not rejected_ids.has(9002) and Time.get_ticks_msec() < expiry_deadline:
		await get_tree().process_frame
	await get_tree().process_frame
	if not _check(rejected_ids.has(9002) and _adapter.grenade_events.pending_count == 0 and not is_instance_valid(expired), "production TTL did not retire the unresolved cosmetic safely"): return

	_manager._on_explosion(702, Vector3.ZERO, "frag")
	await get_tree().process_frame
	var grenade_count_after_first_explosion := get_tree().get_nodes_in_group("grenades").size()
	_manager._on_explosion(702, Vector3.ONE, "frag")
	await get_tree().process_frame
	if not _check(get_tree().get_nodes_in_group("grenades").size() == grenade_count_after_first_explosion, "duplicate explosion replayed the cosmetic blast"): return

	print("GRENADE_PREDICTION_SETTLEMENT_TEST_OK adoption=continuous duplicate_confirmation=ignored rejection=retired disconnect=retired respawn=retired explosion=once prediction=native_enabled ttl=expired inventory=authoritative")
	_manager.clear()
	_adapter.disconnect_from()
	for child in get_children(): child.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)

func _check(condition: bool, message: String) -> bool:
	if condition: return true
	push_error("GRENADE_PREDICTION_SETTLEMENT_TEST_FAILED: " + message)
	get_tree().quit(1)
	return false
