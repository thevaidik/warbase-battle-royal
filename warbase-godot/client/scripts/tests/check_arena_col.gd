extends SceneTree

var ticks := 0

func _process(delta: float) -> bool:
	ticks += 1
	if ticks == 1:
		var scn = load("res://assets/maps/fps_shooter_game_arena_map_v3.glb")
		var inst = scn.instantiate()
		root.add_child(inst)
		var mb = WarMapBuilder.new()
		mb._add_trimesh_collision(inst)
		_find_col(inst, "")
		return false
	if ticks == 3:
		return true
	return false

func _find_col(n: Node, indent: String):
	if n is CollisionShape3D:
		print(indent, "CollisionShape3D in ", n.get_parent().name, " shape: ", n.shape.get_class(), " faces: ", n.shape.get_faces().size() if n.shape is ConcavePolygonShape3D else 0)
		print(indent, "  global_transform: ", (n.get_parent() as Node3D).global_transform)
	for c in n.get_children():
		_find_col(c, indent + "  ")
