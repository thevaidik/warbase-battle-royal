extends SceneTree

func _process(delta: float) -> bool:
	var scn = load("res://assets/maps/fps_shooter_game_arena_map_v3.glb")
	if not scn:
		print("ERROR: could not load arena glb")
		return true
	var inst = scn.instantiate()
	root.add_child(inst)
	_print_tree(inst, "")
	return true

func _print_tree(n: Node, indent: String):
	if n is MeshInstance3D:
		print(indent, n.name, " [MeshInstance3D] aabb=", n.mesh.get_aabb() if n.mesh else "no mesh", " pos=", n.position)
	else:
		print(indent, n.name, " [", n.get_class(), "]")
	for c in n.get_children():
		_print_tree(c, indent + "  ")
