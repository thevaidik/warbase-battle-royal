extends Node3D

func _ready() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 1.65, 0)
	camera.current = true
	var player := Node3D.new()
	add_child(player)
	var layer := CanvasLayer.new()
	add_child(layer)
	var overlay := preload("res://scripts/ui/ObjectiveMarkers.gd").new()
	overlay.player = player
	layer.add_child(overlay)
	overlay.points = [
		{"id":"A", "x":0, "y":0, "z":-30, "owner":"A"},
		{"id":"B", "x":200, "y":0, "z":-10, "owner":"B"},
		{"id":"C", "x":-10, "y":0, "z":30, "owner":"", "contested":true},
		{"id":"D", "x":0, "y":0, "z":-60, "owner":"", "progress":0.5}]
	await get_tree().process_frame
	overlay.refresh()
	assert(overlay.markers.size() == 4)
	assert(not overlay.markers[0]["edge"])
	assert(overlay.markers[1]["edge"] and overlay.markers[2]["edge"])
	assert(overlay.markers[0]["distance"] == 30)
	assert(overlay.markers[0]["color"] == Color("54b5ff"))
	assert(overlay.markers[1]["color"] == Color("ff6659"))
	assert(overlay.markers[2]["color"] == Color("ffad61"))
	assert(overlay.markers[3]["progress"] == 0.5)
	for marker in overlay.markers:
		assert(Rect2(Vector2.ZERO, overlay.size).has_point(marker["position"]))
	# Exact camera-plane objectives used to log a projection error every refresh.
	for depth in [0.0, -0.00001, 0.00001]:
		overlay.points = [{"id":"A", "x":20, "y":-2.35, "z":depth}]
		overlay.refresh()
		assert(overlay.markers.size() == 1)
		assert(overlay.markers[0]["edge"])
		assert(overlay.markers[0]["position"].is_finite())
		assert(overlay.markers[0]["direction"].x > 0.0)
		assert(Rect2(Vector2.ZERO, overlay.size).has_point(overlay.markers[0]["position"]))
	overlay.suppressed = true
	overlay.refresh()
	assert(overlay.markers.is_empty())
	print("OBJECTIVE_MARKERS_OK four badges; forward/edge/behind projection; ownership; distance; capture; map suppression")
	get_tree().quit()
