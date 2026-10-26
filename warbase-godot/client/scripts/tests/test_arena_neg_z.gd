extends SceneTree

var ticks := 0
var mb = null

func _process(delta: float) -> bool:
	ticks += 1
	if ticks == 1:
		mb = WarMapBuilder.new()
		root.add_child(mb)
		mb.build("arena")
		return false
	if ticks == 3:
		var space = root.get_world_3d().direct_space_state
		for x in [-26.0, -20.0, -15.0, -9.0]:
			for z in [-3.0, -7.5, -15.0, -22.0]:
				var ray = PhysicsRayQueryParameters3D.new()
				ray.from = Vector3(x, 10.0, z)
				ray.to = Vector3(x, -5.0, z)
				ray.collision_mask = 1
				var hit = space.intersect_ray(ray)
				print("At (", x, ", ", z, ") -> ground Y=", hit.get("position", "NONE"))
		return true
	return false
