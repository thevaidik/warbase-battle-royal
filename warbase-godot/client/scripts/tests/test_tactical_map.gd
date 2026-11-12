extends Node3D

const TacticalMapScript := preload("res://scripts/ui/TacticalMap.gd")

func _ready() -> void:
	var floor_mesh := MeshInstance3D.new()
	var floor := BoxMesh.new()
	floor.size = Vector3(80, 1, 80)
	floor_mesh.mesh = floor
	floor_mesh.position.y = -0.5
	add_child(floor_mesh)
	for x in [-24.0, 0.0, 24.0]:
		for z in [-24.0, 0.0, 24.0]:
			var block := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(5, 8, 5)
			block.mesh = mesh
			block.position = Vector3(x, 4, z)
			add_child(block)
	var player := Node3D.new()
	player.position = Vector3(-20, 0, 18)
	add_child(player)
	var overlay := TacticalMapScript.new()
	add_child(overlay)
	overlay.configure(self, self, player)
	assert(overlay.map_bounds.position.x <= -40 and overlay.map_bounds.end.x >= 40, "overview must include the whole map mesh bounds")
	var points: Array = []
	for i in 4:
		points.append({"id":char(65 + i), "x":-24.0 + i * 16.0, "y":0.0, "z":-12.0 + i * 8.0, "owner":"A" if i == 0 else "B" if i == 3 else "", "capturing_team":"B", "progress":0.25 * i, "contested":i == 2})
	overlay.set_objectives(points)
	assert(not overlay.visible, "map starts closed")
	assert(overlay.map_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "closed map does not render")
	overlay.set_open(true)
	assert(overlay.visible, "M toggle opens the map")
	assert(overlay.objectives.size() == 4, "all four objective positions are available")
	assert(overlay.map_viewport.render_target_update_mode == SubViewport.UPDATE_ONCE, "open map captures loaded geometry once")
	overlay.set_open(false)
	assert(not overlay.visible, "map closes")
	assert(overlay.map_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "closed map rendering is disabled")
	print("TACTICAL_MAP_TEST_OK objectives=4 snapshot=once overhead_closed=disabled")
	get_tree().quit()
