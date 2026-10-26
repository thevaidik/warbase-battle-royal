extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- TESTING CAR-TO-CAR DRIVE COLLISION WITH ACTION PRESS ---")
	
	# Create floor
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
	
	var jeep_scene: PackedScene = load("res://scenes/CombatJeep.tscn")
	var jeep1: WarCombatJeep = jeep_scene.instantiate()
	jeep1.position = Vector3(0.0, 0.5, 0.0)
	root.add_child(jeep1)
	
	var jeep2: WarCombatJeep = jeep_scene.instantiate()
	jeep2.position = Vector3(0.0, 0.5, -15.0)
	root.add_child(jeep2)
	
	for i in 15:
		await physics_frame
		
	print("Car 1 initial pos: ", jeep1.global_position)
	print("Car 2 initial pos: ", jeep2.global_position)
	
	# Create dummy driver
	var dummy_driver := Node3D.new()
	root.add_child(dummy_driver)
	jeep1.enter_vehicle(dummy_driver)
	
	# Ensure actions exist
	if not InputMap.has_action("move_forward"):
		InputMap.add_action("move_forward")
	if not InputMap.has_action("move_back"):
		InputMap.add_action("move_back")
	if not InputMap.has_action("move_left"):
		InputMap.add_action("move_left")
	if not InputMap.has_action("move_right"):
		InputMap.add_action("move_right")
	if not InputMap.has_action("jump"):
		InputMap.add_action("jump")
		
	Input.action_press("move_forward")
	
	var min_distance := 999.0
	var collision_detected := false
	
	for frame in 300: # 5 seconds
		await physics_frame
		
		var d := jeep1.global_position.distance_to(jeep2.global_position)
		if d < min_distance:
			min_distance = d
		if d < 5.5:
			collision_detected = true
			print("COLLISION ZONE REACHED at frame %d! dist=%.2f, car1_z=%.2f, car2_z=%.2f, car1_vel=%.2f, car2_vel=%.2f" % [
				frame, d, jeep1.global_position.z, jeep2.global_position.z, jeep1.linear_velocity.length(), jeep2.linear_velocity.length()
			])
		# Check if Car 1 went past Car 2
		if jeep1.global_position.z < jeep2.global_position.z - 2.0:
			print("PENETRATION DETECTED at frame %d! Car 1 passed through Car 2!" % frame)
			break
			
	Input.action_release("move_forward")
	print("Test complete. Min distance between cars: ", min_distance)
	print("Car 1 final pos: ", jeep1.global_position, " vel: ", jeep1.linear_velocity)
	print("Car 2 final pos: ", jeep2.global_position, " vel: ", jeep2.linear_velocity)
	quit()
