extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://assets/maps/resoforge_tdm.glb").instantiate()
	root.add_child(scene)
	var bounds := AABB()
	var count := 0
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mi.global_transform * mi.get_aabb()
		bounds = box if count == 0 else bounds.merge(box)
		count += 1
	print("MAP BOUNDS: ",bounds," MESHES: ",count)
	quit()
