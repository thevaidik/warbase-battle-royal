extends SceneTree

const MAPS = [
	"arena",
	"industrial",
	"village",
	"city",
	"canyon"
]

func _process(delta: float) -> bool:
	for map_name in MAPS:
		print("\n>>> AUDITING MAP: ", map_name)
		var mb = WarMapBuilder.new()
		root.add_child(mb)
		var spawns = mb.build(map_name)
		var space = root.get_world_3d().direct_space_state
		
		var bad_spawns := 0
		for i in spawns.size():
			var sp: Vector3 = spawns[i]
			var point_q = PhysicsPointQueryParameters3D.new()
			point_q.position = sp + Vector3(0, 0.9, 0)
			point_q.collision_mask = 1
			var pt_hits = space.intersect_point(point_q, 8)
			if not pt_hits.is_empty():
				print("  [ERROR] Spawn ", i, " at ", sp, " is INSIDE COLLIDER: ", pt_hits[0].collider.name)
				bad_spawns += 1
				continue
				
			var ray = PhysicsRayQueryParameters3D.new()
			ray.from = sp + Vector3(0, 2.0, 0)
			ray.to = sp - Vector3(0, 10.0, 0)
			ray.collision_mask = 1
			var hit = space.intersect_ray(ray)
			if hit.is_empty():
				print("  [WARNING] Spawn ", i, " at ", sp, " has NO GROUND below!")
				bad_spawns += 1
			else:
				var g_y: float = hit.position.y
				var diff: float = sp.y - g_y
				if diff > 1.5 or diff < -0.2:
					print("  [WARNING] Spawn ", i, " at ", sp, " offset from ground (ground Y=", g_y, ", diff=", diff, ")")
					
		if bad_spawns == 0:
			print("  [OK] All ", spawns.size(), " player spawns clear and on solid ground.")
			
		var jeeps = root.get_tree().get_nodes_in_group("combat_jeeps")
		print("  Total combat jeeps: ", jeeps.size())
		for j in jeeps:
			var j_pos: Vector3 = j.global_position
			var j_ray = PhysicsRayQueryParameters3D.new()
			j_ray.from = j_pos + Vector3(0, 2.0, 0)
			j_ray.to = j_pos - Vector3(0, 15.0, 0)
			j_ray.collision_mask = 1
			var j_hit = space.intersect_ray(j_ray)
			if j_hit.is_empty():
				print("  [ERROR] Jeep at ", j_pos, " has NO GROUND below!")
			else:
				var g_y: float = j_hit.position.y
				var fwd = -j.global_transform.basis.z.normalized()
				var fwd_ray = PhysicsRayQueryParameters3D.new()
				fwd_ray.from = j_pos + Vector3(0, 1.2, 0)
				fwd_ray.to = j_pos + Vector3(0, 1.2, 0) + fwd * 8.0
				fwd_ray.collision_mask = 1
				var fwd_hit = space.intersect_ray(fwd_ray)
				var clear_d: float = fwd_hit.position.distance_to(j_pos) if not fwd_hit.is_empty() else 8.0
				print("  Jeep at ", j_pos, " ground Y=", g_y, " forward clearance=", clear_d, "m")
				if clear_d < 3.2:
					print("  [WARNING] Jeep at ", j_pos, " is facing a wall closer than 3.2m!")
					
		for j in jeeps:
			j.free()
		mb.free()
		for c in root.get_children():
			if c != root:
				c.queue_free()
	return true
