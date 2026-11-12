class_name WarObjectiveMarkers
extends Control
## Screen badges paired with world-space capture beacons.

var points: Array = []
var player: Node3D
var suppressed := false
var markers: Array[Dictionary] = []
var _elapsed := 0.0
var _beacons: Node3D
var _beam_mesh: CylinderMesh
var _ring_mesh: TorusMesh

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
	_sync_beacons()
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
		if not target.is_finite(): continue
		var camera_target := camera.global_transform.affine_inverse() * target
		# Perspective division is undefined on the camera plane. Use camera-space
		# direction for points behind/on it and project only points in front.
		var behind := camera_target.z >= -0.001
		var position := center
		var direction := Vector2.ZERO
		if behind:
			var projection := camera.get_camera_projection()
			direction = Vector2(camera_target.x * projection.x.x * center.x, -camera_target.y * projection.y.y * center.y)
		else:
			position = camera.unproject_position(target)
			direction = position - center
		if not direction.is_finite(): continue
		var edge := behind or absf(direction.x) > limits.x or absf(direction.y) > limits.y
		if edge:
			if direction.length_squared() < 0.01: direction = Vector2.DOWN
			var ratio := maxf(absf(direction.x) / limits.x, absf(direction.y) / limits.y)
			position = center + direction / maxf(ratio, 0.001)
		var color := _objective_color(point)
		markers.append({"position":position, "direction":direction.normalized(), "edge":edge,
			"id":String(point.get("id", "?")), "color":color,
			"distance":roundi(player.global_position.distance_to(ground)),
			"progress":clampf(float(point.get("progress", 0)), 0, 1), "contested":bool(point.get("contested", false))})
	queue_redraw()

func _exit_tree() -> void:
	if is_instance_valid(_beacons): _beacons.queue_free()

func _objective_color(point: Dictionary) -> Color:
	if bool(point.get("contested", false)): return Color("ffad61")
	match String(point.get("owner", "")):
		"A": return Color("54b5ff")
		"B": return Color("ff6659")
		_: return Color("d3dde1")

func _sync_beacons() -> void:
	if not is_instance_valid(player) or not player.is_inside_tree(): return
	if not is_instance_valid(_beacons):
		if points.is_empty(): return
		_beacons = Node3D.new()
		_beacons.name = "ObjectiveBeacons"
		player.get_parent().add_child(_beacons)
		_beam_mesh = CylinderMesh.new()
		_beam_mesh.height = 4.0
		_beam_mesh.top_radius = 0.10
		_beam_mesh.bottom_radius = 0.25
		_beam_mesh.radial_segments = 12
		_beam_mesh.rings = 1
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.86
		_ring_mesh.outer_radius = 0.98
		_ring_mesh.rings = 24
		_ring_mesh.ring_segments = 6
	_beacons.visible = not suppressed
	var visible_count := 0
	for value in points:
		if not value is Dictionary: continue
		var point: Dictionary = value
		var ground := Vector3(float(point.get("x", 0)), float(point.get("y", 0)), float(point.get("z", 0)))
		if not ground.is_finite(): continue
		var beacon: Node3D
		if visible_count < _beacons.get_child_count():
			beacon = _beacons.get_child(visible_count) as Node3D
		else:
			beacon = Node3D.new()
			_beacons.add_child(beacon)
			_add_beacon_mesh(beacon, _beam_mesh, Vector3.UP * 2.0)
			_add_beacon_mesh(beacon, _ring_mesh, Vector3.UP * 0.06)
		visible_count += 1
		beacon.visible = true
		if beacon.get_meta("objective_position", Vector3.INF) != ground:
			beacon.set_meta("objective_position", ground)
			var floor: Variant = ColyseusWorldGeometry.floor_height(ground.x, ground.z, ground.y + 0.25)
			beacon.global_position = Vector3(ground.x, float(floor) if floor != null else ground.y, ground.z)
		var color := _objective_color(point)
		var beam: StandardMaterial3D = beacon.get_child(0).material_override
		var ring: StandardMaterial3D = beacon.get_child(1).material_override
		beam.albedo_color = Color(color, 0.27)
		ring.albedo_color = Color(color, 0.84)
	for index in range(visible_count, _beacons.get_child_count()):
		_beacons.get_child(index).visible = false

func _add_beacon_mesh(beacon: Node3D, mesh: Mesh, offset: Vector3) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.position = offset
	beacon.add_child(part)

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
