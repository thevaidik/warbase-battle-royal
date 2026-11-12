extends Node
## Isolated SDK regression. Never instantiated by gameplay; unresolved event
## expiry has crashed released native SDKs, so run in a bounded child process.
var adapter = preload("res://scripts/net/ColyseusNetwork.gd").new()
var rejected: Array[String] = []

func _ready() -> void:
	Engine.max_fps = 60
	add_child(adapter)
	var host := OS.get_environment("COLYSEUS_TEST_HOST")
	if host.is_empty(): host = "127.0.0.1:18195"
	adapter.connect_to("Expiry_%d" % (Time.get_ticks_msec() % 100000), "industrial-public", host)
	var deadline := Time.get_ticks_msec() + 10000
	while (not adapter.connected or adapter.local_reconciler == null) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not adapter.connected or adapter.local_reconciler == null:
		finish(false, "connection timeout")
		return
	adapter.set_gameplay_input_enabled(false)
	var born_clock: float = adapter.room.clock.server_now()
	var ttl := 150.0
	if not OS.get_environment("COLYSEUS_EVENT_TTL_MS").is_empty(): ttl = float(OS.get_environment("COLYSEUS_EVENT_TTL_MS"))
	var channel = adapter.predictor.define_event({"ttl_ms":ttl, "on_reject":func(key: String) -> void: rejected.append(key)})
	if channel == null or not channel.predict("expiry-regression"):
		finish(false, "channel did not accept prediction")
		return
	print("SDK_EVENT_EXPIRY_PENDING ttl_ms=%.0f sdk=%s" % [ttl, FileAccess.get_file_as_string("res://addons/colyseus/version.json").strip_edges()])
	deadline = Time.get_ticks_msec() + maxi(2000, int(ttl) + 1500)
	while rejected.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var ok: bool = rejected == ["expiry-regression"] and channel.pending_count == 0
	var detail := "ttl_ms=%.0f rejected=%s pending=%d clock_elapsed=%.1f sent=%d" % [ttl, rejected, channel.pending_count, adapter.room.clock.server_now() - born_clock, adapter.input_handle.sent_count]
	channel.clear()
	finish(ok, detail)

func finish(ok: bool, detail: String) -> void:
	print("SDK_EVENT_EXPIRY_%s %s" % ["OK" if ok else "FAILED", detail])
	adapter.disconnect_from()
	get_tree().quit(0 if ok else 1)
