extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- TESTING BOT VS VEHICLE DISPLACEMENT ---")
	
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
	
	# Jeep
	var jeep_scene: PackedScene = load("res://scenes/CombatJeep.tscn")
	var jeep1: WarCombatJeep = jeep_scene.instantiate()
	jeep1.position = Vector3(0.0, 0.5, 0.0)
	root.add_child(jeep1)
	
	# Extended collision
	var ch_col: CollisionShape3D = jeep1.get_node("ChassisCollision")
	var ch_box: BoxShape3D = ch_col.shape
	ch_box.size = Vector3(2.3, 1.10, 5.0)
	ch_col.position = Vector3(0.0, 0.95, 0.0)
	
	for i in 20:
		await physics_frame
		
	print("Jeep parked pos: ", jeep1.global_position, " freeze: ", jeep1.freeze)
	var parked_initial_pos := jeep1.global_position
	
	# Spawn 3 bots running straight into the parked car from front, back, and side
	var bot_scene: PackedScene = load("res://scenes/Bot.tscn")
	var bot_front: WarBot = bot_scene.instantiate()
	bot_front.position = Vector3(0.0, 0.5, -4.0)
	root.add_child(bot_front)
	
	var bot_side: WarBot = bot_scene.instantiate()
	bot_side.position = Vector3(2.5, 0.5, 0.0)
	root.add_child(bot_side)
	
	for i in 5:
		await physics_frame
		
	for frame in 120: # 2 full seconds of bots running into parked car
		bot_front.velocity = Vector3(0.0, 0.0, 6.0) # Run +Z into car front
		bot_front.move_and_slide()
		bot_side.velocity = Vector3(-6.0, 0.0, 0.0) # Run -X into car side
		bot_side.move_and_slide()
		await physics_frame
		
	var parked_displacement := jeep1.global_position.distance_to(parked_initial_pos)
	print("Displacement of PARKED jeep after 120 frames of 2 bots ramming it: %.4f m" % parked_displacement)
	print("  Jeep pos: ", jeep1.global_position)
	print("  Bot front pos: ", bot_front.global_position)
	print("  Bot side pos: ", bot_side.global_position)
	
	# Now test DRIVEN jeep (driver entered)
	var dummy_driver := Node3D.new()
	root.add_child(dummy_driver)
	jeep1.enter_vehicle(dummy_driver)
	print("\nDriver entered jeep. freeze: ", jeep1.freeze, " is_driven: ", jeep1.is_driven)
	var driven_initial_pos := jeep1.global_position
	
	# 2 seconds of bots ramming the driven jeep while driver is stationary
	for frame in 120:
		bot_front.velocity = Vector3(0.0, 0.0, 6.0)
		bot_front.move_and_slide()
		bot_side.velocity = Vector3(-6.0, 0.0, 0.0)
		bot_side.move_and_slide()
		await physics_frame
		
	var driven_displacement := jeep1.global_position.distance_to(driven_initial_pos)
	print("Displacement of DRIVEN jeep after 120 frames of 2 bots ramming it: %.4f m" % driven_displacement)
	print("  Jeep pos: ", jeep1.global_position)
	print("  Bot front pos: ", bot_front.global_position)
	print("  Bot side pos: ", bot_side.global_position)
	
	quit()
