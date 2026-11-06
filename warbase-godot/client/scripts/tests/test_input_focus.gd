extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", label)
func run() -> void:
	var net = load("res://scripts/net/ColyseusNetwork.gd").new()
	root.add_child(net)
	await process_frame
	Input.action_press("move_forward")
	Input.action_press("move_right")
	net._jump_pending = true
	net._on_focus_exited()
	check(not Input.is_action_pressed("move_forward") and not Input.is_action_pressed("move_right"), "focus loss releases held movement")
	check(not net._window_focused and not net._jump_pending, "unfocused frames cannot submit movement or a queued jump")
	Input.action_press("move_back")
	net.set_gameplay_input_enabled(false)
	check(not Input.is_action_pressed("move_back"), "opening gameplay overlays clears stale held actions")
	net.get_window().focus_entered.emit()
	check(net._window_focused and not net._gameplay_input_enabled, "focus regain does not unpause gameplay")
	net.queue_free()
	await process_frame
	print("INPUT_FOCUS_TEST failures=", failures)
	quit(failures)
