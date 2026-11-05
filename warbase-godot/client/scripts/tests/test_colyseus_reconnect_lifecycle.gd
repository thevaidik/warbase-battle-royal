extends Node
## Deterministic lifecycle checks for timeout, explicit leave, and stale callbacks.

const Adapter := preload("res://scripts/net/ColyseusNetwork.gd")
var net: Node

class FakeRoom extends RefCounted:
	var options: Dictionary = {}
	var leave_count := 0
	var reconnecting := true

	func set_reconnection_options(value: Dictionary) -> void:
		options.merge(value, true)

	func leave() -> void:
		leave_count += 1

func _ready() -> void:
	_run()

func _run() -> void:
	var adapter = Adapter.new()
	net = adapter
	add_child(adapter)
	adapter.set_process(false)
	var errors: Array[String] = []
	adapter.connection_error.connect(func(reason: String) -> void: errors.append(reason))

	# Expiry leaves the SDK room, disables its retry loop, and emits one error.
	var expired_room := FakeRoom.new()
	adapter.room = expired_room
	adapter._connection_generation = 4
	adapter._want_connection = true
	adapter._drop_started_ms = maxi(Time.get_ticks_msec(), 1)
	adapter._awaiting_fresh_state = true
	var deadline := Time.get_ticks_msec() + Adapter.CLIENT_RECONNECT_GRACE_MS + 1
	while Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.05).timeout
	adapter._process(0.0)
	if not _check(adapter.room == null and not adapter._want_connection, "timeout did not end the session"): return
	if not _check(expired_room.options.get("enabled", true) == false and expired_room.leave_count == 1, "timeout did not cancel SDK reconnect and leave once"): return
	if not _check(errors.size() == 1 and not adapter.connected, "timeout did not emit exactly one terminal error"): return
	adapter._on_joined(expired_room, 4)
	if not _check(errors.size() == 1 and adapter.room == null and not adapter.connected, "late reconnect revived an expired session"): return

	# User leave while reconnecting invalidates callbacks without reporting an error.
	var leaving_room := FakeRoom.new()
	adapter.room = leaving_room
	adapter._connection_generation = 12
	adapter._want_connection = true
	adapter._drop_started_ms = Time.get_ticks_msec()
	adapter._awaiting_fresh_state = true
	adapter.disconnect_from()
	adapter._on_joined(leaving_room, 12)
	if not _check(leaving_room.options.get("enabled", true) == false and leaving_room.leave_count == 1, "explicit leave did not stop reconnect"): return
	if not _check(adapter.room == null and not adapter._want_connection and errors.size() == 1, "late callback revived an explicitly left session"): return

	# A callback from a replaced room cannot mutate the current session.
	var replaced_room := FakeRoom.new()
	var current_room := FakeRoom.new()
	adapter.room = current_room
	adapter._connection_generation = 21
	adapter._want_connection = true
	adapter._connection_generation = 22
	adapter._on_joined(replaced_room, 21)
	adapter._on_message("identity", {"username": "OLD"}, replaced_room, 21)
	if not _check(adapter.room == current_room and adapter._want_connection and not adapter.connected, "old room callback changed the replacement session"): return
	if not _check(adapter._username != "OLD", "old room identity changed the replacement session"): return
	adapter._on_message("identity", {"username": "NORMALIZED"}, current_room, 22)
	if not _check(adapter._username == "NORMALIZED" and GameState.username == "NORMALIZED", "server identity was not applied before state readiness"): return

	adapter.disconnect_from()
	adapter.free()
	print("COLYSEUS_RECONNECT_LIFECYCLE_TEST_OK timeout=final late_success=ignored leave=final replaced_room=ignored")
	get_tree().quit(0)

func _check(condition: bool, message: String) -> bool:
	if condition: return true
	push_error("COLYSEUS_RECONNECT_LIFECYCLE_TEST_FAILED: " + message)
	get_tree().quit(1)
	return false
