extends SceneTree
var Adapter
func _initialize() -> void: call_deferred("run")
func capture(adapter) -> Dictionary:
	return {"room":weakref(adapter.room), "native_room":weakref(adapter.room._native), "root":weakref(adapter.room.get_state()), "client":weakref(adapter.client._native)}
func cycle(index: int) -> Dictionary:
	var adapter = Adapter.new()
	root.add_child(adapter)
	adapter.connect_to("Lifecycle_%d" % index, "industrial-public", "127.0.0.1:18196")
	var deadline := Time.get_ticks_msec() + 12000
	while not adapter.connected and Time.get_ticks_msec() < deadline: await process_frame
	if not adapter.connected: return {"error":"join deadline"}
	await create_timer(0.1).timeout
	var refs: Dictionary = capture(adapter)
	adapter.disconnect_from()
	adapter.queue_free()
	await create_timer(0.2).timeout
	var result := {"cycle":index,"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT)),"bytes":OS.get_static_memory_usage()}
	for key in refs: result[key + "_retained"] = refs[key].get_ref() != null
	return result
func run() -> void:
	Adapter = load("res://scripts/net/ColyseusNetwork.gd")
	for index in 10:
		var row: Dictionary = await cycle(index)
		print("SCHEMA_LIFECYCLE " + JSON.stringify(row))
		if row.has("error") or not row.has("cycle"): quit(1);return
	for reject in [true, false]:
		var adapter = Adapter.new()
		root.add_child(adapter)
		var flags := {"error":false}
		adapter.connection_error.connect(func(_reason): flags.error = true)
		adapter.connect_to("Reject_case" if reject else "Cancel_case", "industrial-public", "127.0.0.1:18196")
		var deadline := Time.get_ticks_msec() + 12000
		while adapter.room == null and not flags.error and Time.get_ticks_msec() < deadline: await process_frame
		var room_ref: WeakRef = weakref(adapter.room) if adapter.room != null else null
		var native_ref: WeakRef = weakref(adapter.room._native) if adapter.room != null else null
		if reject:
			while not flags.error and Time.get_ticks_msec() < deadline: await process_frame
		adapter.disconnect_from()
		adapter.queue_free()
		await create_timer(2.0).timeout
		var result := {"case":"reject" if reject else "cancel", "error_seen":flags.error, "room_retained":room_ref != null and room_ref.get_ref() != null, "native_room_retained":native_ref != null and native_ref.get_ref() != null}
		print("SCHEMA_LIFECYCLE_EDGE " + JSON.stringify(result))
	quit(0)
