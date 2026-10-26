extends SceneTree

var elapsed := 0.0
var samples := 0

func _init() -> void:
	GameState.selected_map = "loft"
	call_deferred("_start")

func _start() -> void:
	change_scene_to_file("res://scenes/Main.tscn")

func _process(delta: float) -> bool:
	elapsed += delta
	
	# Wait for scene to load and deploy
	var main = current_scene
	if not main:
		return false
		
	# Automatically trigger deploy if still in menu
	if main.get("phase") == 0: # Phase.MENU
		main._on_deploy()
		print("AUDIT: Deployed to map=", GameState.selected_map)
		return false
		
	samples += 1
	if samples % 30 == 0:
		var fps := Engine.get_frames_per_second()
		var proc_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var phys_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var objs := Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		var prims := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var pairs := Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)
		var active_phys := Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
		var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		
		print("PERF_SAMPLE [%.1fs]: FPS=%d | Proc=%.2fms | Phys=%.2fms | DrawCalls=%d | Objs=%d | Prims=%d | PhysPairs=%d | ActivePhys=%d | Nodes=%d" % [
			elapsed, fps, proc_ms, phys_ms, draw_calls, objs, prims, pairs, active_phys, nodes
		])
		
	if elapsed >= 4.0:
		print("=== AUDIT SUMMARY ===")
		print("Final FPS: ", Engine.get_frames_per_second())
		print("Process Time: ", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, " ms")
		print("Physics Time: ", Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, " ms")
		print("Draw Calls: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		print("Objects Rendered: ", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		print("Primitives: ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		print("Collision Pairs: ", Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))
		quit(0)
		return true
	return false
