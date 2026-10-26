extends SceneTree

var ticks := 0
var inst = null

func _process(delta: float) -> bool:
	ticks += 1
	if ticks == 1:
		var scn = load("res://assets/maps/fps_shooter_game_arena_map_v3.glb")
		inst = scn.instantiate()
		root.add_child(inst)
		var mb = WarMapBuilder.new()
		mb._add_trimesh_collision(inst)
		return false
	if ticks == 3:
		var space = root.get_world_3d().direct_space_state
		# Check raycast in unrotated arena from Y=30 to Y=-5
		for x in [-25.0, -15.0, -5.0]:
			for z in [2.0, 5.0, 8.0]:
				var ray = PhysicsRayQueryParameters3D.new()
				ray.from = Vector3(x, 25.0, z)
				ray.to = Vector3(x, -5.0, z)
				ray.collision_mask = 1
				var hit = space.intersect_ray(ray)
				print("Unrotated ray at (", x, ", ", z, ") -> hit: ", hit.get("position", "NONE"))
		return true
	return false
