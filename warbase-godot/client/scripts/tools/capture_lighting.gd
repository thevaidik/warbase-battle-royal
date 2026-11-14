extends Node

@onready var root := get_tree().root

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.msaa_3d = Viewport.MSAA_2X
	var map_id := "industrial"
	var label := "baseline"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("map="): map_id = argument.trim_prefix("map=")
		if argument.begins_with("label="): label = argument.trim_prefix("label=")
	var builder := WarMapBuilder.new()
	root.add_child(builder)
	var spawns := builder.build(map_id)
	if spawns.is_empty(): get_tree().quit(1); return
	builder.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = spawns[0] + Vector3(0, 3, 0)
	camera.look_at(camera.position + Vector3(1, -0.12, -1))
	camera.current = true
	camera.fov = 75
	var records: Array = []
	for preset in ["dawn", "noon", "dusk", "overcast"]:
		builder.apply_time_of_day(preset)
		for frame in 30: await get_tree().process_frame
		var timings: Array[float] = []
		var previous := Time.get_ticks_usec()
		for frame in 120:
			await get_tree().process_frame
			var current := Time.get_ticks_usec()
			timings.append(float(current - previous) / 1000.0)
			previous = current
		timings.sort()
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("/tmp/warbase-" + label + "-" + map_id + "-" + preset + ".png")
		records.append({"map":map_id,"preset":preset,"p50_ms":timings[60],"p95_ms":timings[114],"p99_ms":timings[118],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"note":"Static native capture, not populated match or browser benchmark"})
	var output := FileAccess.open("/tmp/warbase-" + label + "-" + map_id + ".json", FileAccess.WRITE)
	output.store_string(JSON.stringify(records, "\t"))
	get_tree().quit()
