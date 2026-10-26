extends SceneTree

var frames := 0
var elapsed := 0.0

func _init() -> void:
	GameState.selected_map = "city"
	call_deferred("_load_main")

func _load_main() -> void:
	change_scene_to_file("res://scenes/Main.tscn")

func _process(delta: float) -> bool:
	elapsed += delta
	frames += 1
	if elapsed >= 2.0:
		print("=== COMPETITIVE PERFORMANCE BENCHMARK ===")
		print("FPS: ", Engine.get_frames_per_second())
		print("Frame Time: ", 1000.0 / maxf(float(Engine.get_frames_per_second()), 1.0), " ms")
		print("Process Time: ", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, " ms")
		print("Physics Time: ", Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, " ms")
		print("Draw Calls: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		print("Objects in Frame: ", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		print("Video Memory: ", Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1024.0 / 1024.0, " MB")
		quit()
		return true
	return false
