extends SceneTree

var ticks := 0
var mb = null

func _process(delta: float) -> bool:
	ticks += 1
	if ticks == 1:
		mb = WarMapBuilder.new()
		root.add_child(mb)
		mb.build("shipment")
		return false
	if ticks == 3:
		var space = root.get_world_3d().direct_space_state
		print("Scanning shipment for clear spawn points:")
		var valid = []
		for x in range(-20, 21, 2):
			for z in range(-20, 21, 2):
				var p = Vector3(x, 1.0, z)
				var pt_q = PhysicsPointQueryParameters3D.new()
				pt_q.position = p
				pt_q.collision_mask = 1
				if space.intersect_point(pt_q, 1).is_empty():
					var ray = PhysicsRayQueryParameters3D.new()
					ray.from = p + Vector3(0, 1, 0)
					ray.to = p - Vector3(0, 5, 0)
					ray.collision_mask = 1
					var hit = space.intersect_ray(ray)
					if not hit.is_empty() and abs(hit.position.y) < 0.2:
						valid.append(Vector3(x, 0.4, z))
		print("Found ", valid.size(), " clear floor points!")
		# Pick 12 evenly distributed points
		var chosen = []
		var step = max(1, valid.size() / 12)
		for i in 12:
			chosen.append(valid[i * step])
		print("Chosen 12 spawns: ", chosen)
		return true
	return false
