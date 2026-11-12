extends Node
class NativeSignals extends RefCounted:
	signal joined
	signal state_changed
	signal message_received(kind, data)
	signal error(code, reason)
	signal left(code, reason)
	signal dropped(code, reason)
	signal reconnected
class MessageRecorder extends RefCounted:
	var messages: Array = []
	func send_message(kind, data): messages.append([kind, data])
var received: Array = []
var failures := 0
func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("CHECK FAIL " + label)
func record_zero(event): received.append([event])
func record_two(first, second, event): received.append([event, first, second])
func exercise() -> Dictionary:
	var native := NativeSignals.new()
	var wrapper = Colyseus.Room.new(native)
	for event in [&"joined", &"state_changed", &"reconnected"]: wrapper.connect(event, record_zero.bind(event))
	for event in [&"message_received", &"error", &"left", &"dropped"]: wrapper.connect(event, record_two.bind(event))
	native.joined.emit(); native.state_changed.emit(); native.reconnected.emit()
	native.message_received.emit("hit", {"damage":37})
	native.error.emit(409, "upgrade"); native.left.emit(4000, "left"); native.dropped.emit(1006, "drop")
	check(received.size() == 7 and received[3] == [&"message_received", "hit", {"damage":37}] and received[6] == [&"dropped", 1006, "drop"], "relay order and payloads preserved")
	return {"native":native,"room":weakref(wrapper)}
func _ready() -> void: call_deferred("run")
func run() -> void:
	var refs := exercise()
	check(refs.room.get_ref() == null, "native forwarding must not retain the room")
	refs.native.joined.emit()
	check(received.size() == 7, "forwarding safely stops after wrapper destruction")
	var native_ref: WeakRef = weakref(refs.native)
	refs.clear()
	await get_tree().process_frame
	check(native_ref.get_ref() == null, "no native self-cycle remains")
	var network = preload("res://scripts/net/ColyseusNetwork.gd").new()
	add_child(network)
	var recorder := MessageRecorder.new()
	network.room = recorder
	for frame in 600: network._send_metadata_if_needed(100 + frame * 17)
	check(recorder.messages.size() == 1, "unchanged metadata is not resent every 100ms")
	network._desired_animation = "run"
	network._send_metadata_if_needed(11000)
	check(recorder.messages.size() == 2, "animation transition sends once")
	network._desired_weapon = "m2010"
	network._send_metadata_if_needed(11050)
	check(recorder.messages.size() == 2, "rapid metadata changes remain bounded")
	network._send_metadata_if_needed(11100)
	check(recorder.messages.size() == 3 and recorder.messages[2][1].weapon == "m2010", "latest weapon transition is delivered")
	network._sent_animation = ""; network._sent_weapon = ""
	network._send_metadata_if_needed(11200)
	check(recorder.messages.size() == 4, "lifecycle reset resends current presentation")
	network.room = null
	network.queue_free()
	print("SDK_ROOM_OWNERSHIP_OK failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
