class_name WarObjectiveMarkers
extends Control
## Four projected HUD badges; no extra cameras, meshes or physics queries.

var points: Array = []
var player: Node3D
var suppressed := false
var markers: Array[Dictionary] = []
var _elapsed := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.05: return
	_elapsed = 0.0
	refresh()

func refresh() -> void:
	markers.clear()
	var camera := get_viewport().get_camera_3d()
	if suppressed or not is_instance_valid(player) or not is_instance_valid(camera) or size.x < 140 or size.y < 240:
		queue_redraw()
		return
	var center := size * 0.5
	var limits := Vector2(maxf(1.0, center.x - 48.0), maxf(1.0, center.y - 160.0))
	for value in points:
		if not value is Dictionary: continue
		var point: Dictionary = value
		var ground := Vector3(float(point.get("x", 0)), float(point.get("y", 0)), float(point.get("z", 0)))
		var target := ground + Vector3.UP * 4.0
		var position := camera.unproject_position(target)
		var direction := position - center
		var behind := camera.is_position_behind(target)
		if behind: direction = -direction
		if not direction.is_finite(): continue
		var edge := behind or absf(direction.x) > limits.x or absf(direction.y) > limits.y
		if edge:
			if direction.length_squared() < 0.01: direction = Vector2.DOWN
			var ratio := maxf(absf(direction.x) / limits.x, absf(direction.y) / limits.y)
			position = center + direction / maxf(ratio, 0.001)
		var owner := String(point.get("owner", ""))
		var color := Color("54b5ff") if owner == "A" else Color("ff6659") if owner == "B" else Color("d3dde1")
		if bool(point.get("contested", false)): color = Color("ffad61")
		markers.append({"position":position, "direction":direction.normalized(), "edge":edge,
			"id":String(point.get("id", "?")), "color":color,
			"distance":roundi(player.global_position.distance_to(ground)),
			"progress":clampf(float(point.get("progress", 0)), 0, 1), "contested":bool(point.get("contested", false))})
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for marker in markers:
		var position: Vector2 = marker["position"]
		var color: Color = marker["color"]
		draw_circle(position, 19, Color(0.025, 0.045, 0.065, 0.9))
		draw_arc(position, 19, 0, TAU, 32, color, 2, true)
		if float(marker["progress"]) > 0:
			draw_arc(position, 23, -PI * 0.5, -PI * 0.5 + TAU * float(marker["progress"]), 32, Color("ffcd75"), 3, true)
		var code: String = marker["id"]
		draw_string(font, position + Vector2(-font.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x * 0.5, 7), code, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, color)
		var caption := "%dm" % int(marker["distance"])
		if bool(marker["contested"]): caption = "CONTESTED · " + caption
		var label_pos := position + Vector2(-font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x * 0.5, 39)
		draw_string_outline(font, label_pos, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.9))
		draw_string(font, label_pos, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		if bool(marker["edge"]):
			var direction: Vector2 = marker["direction"]
			var tip := position + direction * 31
			var side := direction.orthogonal() * 5
			draw_colored_polygon(PackedVector2Array([tip, tip - direction * 9 + side, tip - direction * 9 - side]), color)
