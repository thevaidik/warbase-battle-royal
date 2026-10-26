extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- TESTING BOT JUMPING ONTO JEEP ---")
	
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
	
	var jeep_scene: PackedScene = load("res://scenes/CombatJeep.tscn")
	var jeep1: WarCombatJeep = jeep_scene.instantiate()
	jeep1.position = Vector3(0.0, 0.5, 0.0)
	root.add_child(jeep1)
	
	for i in 20:
		await physics_frame
		
	var bot_scene: PackedScene = load("res://scenes/Bot.tscn")
	var bot: WarBot = bot_scene.instantiate()
	bot.position = Vector3(0.0, 0.5, -3.2) # Front of car
	root.add_child(bot)
	
	var dummy_driver := Node3D.new()
	root.add_child(dummy_driver)
	jeep1.enter_vehicle(dummy_driver)
	
	for i in 5:
		await physics_frame
		
	print("Initial jeep pos: ", jeep1.global_position, " bot pos: ", bot.global_position)
	
	# Simulate bot walking toward car and triggering obstacle jump
	for frame in 180:
		bot.velocity.z = 5.0 # Walk toward Z=0
		if bot.is_on_wall():
			bot.velocity.y = 5.4 # Obstacle jump
		bot.move_and_slide()
		await physics_frame
		if frame % 30 == 0:
			print("Frame %d: Jeep Y=%.2f, Bot Y=%.2f, Bot on_floor=%s, Bot on_wall=%s" % [
				frame, jeep1.global_position.y, bot.global_position.y, bot.is_on_floor(), bot.is_on_wall()
			])
			
	print("Final jeep pos: ", jeep1.global_position, " vel: ", jeep1.linear_velocity)
	quit()
