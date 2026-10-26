extends SceneTree

func _process(delta: float) -> bool:
	var scn = load("res://assets/maps/fps_shooter_game_arena_map_v3.glb")
	var inst = scn.instantiate()
	root.add_child(inst)
	for c in inst.find_children("*", "MeshInstance3D"):
		var mi = c as MeshInstance3D
		if mi.mesh:
			var faces = mi.mesh.get_faces()
			var aabb = mi.mesh.get_aabb()
			print(mi.name, " global_trans=", mi.global_transform, " mesh_aabb=", aabb)
	return true
