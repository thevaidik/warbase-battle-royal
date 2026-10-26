extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- TESTING DYNAMIC CAR WITH EXTENDED CHASSIS COLLISION ---")
	
	# Floor
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0xFFFFFFFF
	var floor_col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	floor_col.shape = box
	floor_col.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_col)
	root.add_child(floor_body)
	
	# Local Jeep
	var jeep_scene: PackedScene = load("res://scenes/CombatJeep.tscn")
	var jeep1: WarCombatJeep = jeep_scene.instantiate()
	jeep1.position = Vector3(0.0, 0.5, 0.0)
	root.add_child(jeep1)
	
	# Adjust chassis collision to cover bumper down to 0.40m
	var ch_col: CollisionShape3D = jeep1.get_node("ChassisCollision")
	var ch_box: BoxShape3D = ch_col.shape
	ch_box.size = Vector3(2.3, 1.10, 5.0)
	ch_col.position = Vector3(0.0, 0.95, 0.0)
	
	# Remote AnimatableBody3D
	var remote_car := AnimatableBody3D.new()
	remote_car.position = Vector3(0.0, 0.0, -15.0)
	remote_car.collision_layer = 4
	remote_car.collision_mask = 1 | 4
	var col_shape := CollisionShape3D.new()
	var col_box := BoxShape3D.new()
	col_box.size = Vector3(2.3, 1.10, 5.0)
	col_shape.shape = col_box
	col_shape.position = Vector3(0.0, 0.95, 0.0)
	remote_car.add_child(col_shape)
	root.add_child(remote_car)
	
	for i in 15:
		await physics_frame
		
	print("Car 1 initial pos: ", jeep1.global_position)
	print("Remote Car initial pos: ", remote_car.global_position)
	
	# Driver enters
	var dummy_driver := Node3D.new()
	root.add_child(dummy_driver)
	jeep1.enter_vehicle(dummy_driver)
	
	if not InputMap.has_action("move_forward"):
		InputMap.add_action("move_forward")
	Input.action_press("move_forward")
	
	var min_distance := 999.0
	var penetrated := false
	
	for frame in 300:
		await physics_frame
		var d := jeep1.global_position.distance_to(remote_car.global_position)
		if d < min_distance:
			min_distance = d
		if jeep1.global_position.z < remote_car.global_position.z - 2.0:
			penetrated = true
			print("PENETRATION DETECTED at frame %d! dist=%.2f" % [frame, d])
			break
			
	Input.action_release("move_forward")
	print("Test complete. Min distance between cars: ", min_distance)
	print("Penetrated through remote car: ", penetrated)
	print("Car 1 final pos: ", jeep1.global_position, " vel: ", jeep1.linear_velocity)
	quit()
