extends SceneTree

func _process(delta: float) -> bool:
	var mb = WarMapBuilder.new()
	root.add_child(mb)
	var spawns = mb.build("arena")
	var space = root.get_world_3d().direct_space_state
	
	# Raycast straight down from Y=50 down to Y=-50
	var ray = PhysicsRayQueryParameters3D.new()
	ray.from = Vector3(-15.0, 50.0, 5.0)
	ray.to = Vector3(-15.0, -50.0, 5.0)
	ray.collision_mask = 1
	var hit = space.intersect_ray(ray)
	print("Arena raycast from ( -15, 50, 5 ) hit: ", hit)
	
	# Check children of GLBMap
	var glb = root.find_child("GLBMap", true, false)
	if glb:
		print("GLBMap class: ", glb.get_class(), " children: ", glb.get_child_count())
		for c in glb.get_children():
			print("  Child: ", c.name, " class: ", c.get_class(), " pos: ", c.position if c is Node3D else "")
			if c is StaticBody3D:
				print("    StaticBody col count: ", c.get_child_count())
	return true
