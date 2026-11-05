extends Node

const MainScene := preload("res://scenes/Main.tscn")

func _ready() -> void:
	call_deferred("_check_default")

func _check_default() -> void:
	var main = MainScene.instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await get_tree().process_frame
	var script_path := String(main.net.get_script().resource_path) if main.net != null else ""
	if script_path.ends_with("scripts/net/ColyseusNetwork.gd"):
		print("DEFAULT_BACKEND_OK", script_path)
		get_tree().quit(0)
	else:
		push_error("DEFAULT_BACKEND_FAILED: %s" % script_path)
		get_tree().quit(1)
