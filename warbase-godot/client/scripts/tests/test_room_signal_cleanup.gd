extends Node
class FakeRoom extends RefCounted:
	signal joined
var callback_count := 0
func _ready() -> void:
	call_deferred("run")
func on_joined(_source: Variant) -> void:
	callback_count += 1
func exercise(network: Node) -> WeakRef:
	var fake := FakeRoom.new()
	network._connect_room_signal(fake, &"joined", on_joined.bind(fake))
	fake.joined.emit()
	assert(callback_count == 1)
	network.disconnect_from()
	fake.joined.emit()
	assert(callback_count == 1)
	return weakref(fake)
func run() -> void:
	var network := preload("res://scripts/net/ColyseusNetwork.gd").new()
	get_tree().root.add_child(network)
	# Return from the frame that created the temporary Signal/Callable values
	# before checking reference ownership.
	var weak: WeakRef = exercise(network)
	assert(weak.get_ref() == null, "terminal teardown must release the bound room")
	network.queue_free()
	await get_tree().process_frame
	print("ROOM_SIGNAL_CLEANUP_OK")
	get_tree().quit()
