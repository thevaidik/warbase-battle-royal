extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- CHECKING FINITE TRANSFORMS ON ALL NODES ---")
	
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node = main_scene.instantiate()
	root.add_child(main)
	
	for i in 10:
		await process_frame
		
	# Deploy to match
	main.menu.join_btn.pressed.emit()
	
	for i in 30:
		await process_frame
		await physics_frame
		
	print("Match running. Checking all 3D nodes for non-finite transforms...")
	var bad_count := 0
	_check_finite(main, bad_count)
	print("Finished checking. Bad non-finite nodes found: ", bad_count)
	quit()

func _check_finite(node: Node, bad_count: int) -> void:
	if node is Node3D:
		var n3d := node as Node3D
		var p := n3d.position
		var r := n3d.rotation
		var s := n3d.scale
		var gp := n3d.global_position
		if not (p.is_finite() and r.is_finite() and s.is_finite() and gp.is_finite()):
			print("NON-FINITE DETECTED: ", n3d.get_path(), " pos=", p, " rot=", r, " scale=", s, " gp=", gp)
			bad_count += 1
	for c in node.get_children():
		_check_finite(c, bad_count)
