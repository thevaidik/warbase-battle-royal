extends SceneTree

const LIFECYCLE_SOURCE_PATH := "/tmp/warbase-memory-lifecycle-node.gd"
const CYCLE_COUNT := 8

func recordPerformance(label: String) -> Dictionary:
	var sample := {
		"label": label,
		"object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"object_resource_count": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"static_memory_bytes": int(OS.get_static_memory_usage()),
	}
	print("LIFECYCLE_MEMORY " + JSON.stringify(sample))
	return sample

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not root.has_node("GameState"):
		push_error("Lifecycle runner requires the WarBase Godot project autoloads")
		quit(1)
		return
	var rows: Array[Dictionary] = []
	rows.append(recordPerformance("baseline"))
	var lifecycle_script := GDScript.new()
	lifecycle_script.source_code = FileAccess.get_file_as_string(LIFECYCLE_SOURCE_PATH)
	var load_error := lifecycle_script.reload()
	if load_error != OK:
		push_error("Unable to load lifecycle node script from " + LIFECYCLE_SOURCE_PATH)
		quit(1)
		return
	for cycle_index in range(1, CYCLE_COUNT + 1):
		var cycle = lifecycle_script.new()
		root.add_child(cycle)
		var result: Dictionary = await cycle.run_once()
		cycle.free()
		await process_frame
		var sample := recordPerformance("after_cleanup_%02d" % cycle_index)
		sample["cycle"] = cycle_index
		sample["initial_state"] = bool(result.get("initial_state", false))
		rows.append(sample)
		if not bool(result.get("ok", false)):
			push_error("LIFECYCLE_FAILED cycle=%d error=%s" % [cycle_index, String(result.get("error", "unknown failure"))])
			quit(1)
			return
	print("LIFECYCLE_COMPLETE cycles=%d username=QA_LIFECYCLE room=industrial-public host=war.vaidik.blog/colyseus measurements=%s" % [CYCLE_COUNT, JSON.stringify(rows)])
	quit(0)
