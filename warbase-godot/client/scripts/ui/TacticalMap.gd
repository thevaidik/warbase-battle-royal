class_name WarTacticalMap
extends Control
## On-demand top-down view of the loaded map with server-owned conquest markers.

const TEAM_A := Color(0.24, 0.68, 1.0)
const TEAM_B := Color(1.0, 0.29, 0.23)
const NEUTRAL := Color(0.78, 0.82, 0.84)

var world_root: Node3D
var map_root: Node3D
var local_player: Node3D
var objectives: Array = []
var map_bounds := AABB(Vector3(-32, -2, -32), Vector3(64, 20, 64))
var map_camera: Camera3D
var map_viewport: SubViewport
var _map_draw: Control
var _summary: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.035, 0.96)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 24
	frame.offset_top = 24
	frame.offset_right = -24
	frame.offset_bottom = -24
	frame.add_theme_stylebox_override("panel", _panel_style())
	add_child(frame)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 14)
	frame.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "TACTICAL MAP  /  CONQUEST"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("dce7eb"))
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_summary = Label.new()
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_summary.add_theme_font_size_override("font_size", 13)
	_summary.add_theme_color_override("font_color", Color("9baeb8"))
	header.add_child(_summary)
	var body := Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.clip_contents = true
	column.add_child(body)
	map_viewport = SubViewport.new()
	map_viewport.size = Vector2i(900, 520)
	map_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	map_viewport.transparent_bg = false
	map_viewport.own_world_3d = false
	_map_draw = Control.new()
	_map_draw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_draw.draw.connect(_draw_map)
	var viewport_holder := SubViewportContainer.new()
	viewport_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_holder.stretch = true
	viewport_holder.add_child(map_viewport)
	body.add_child(viewport_holder)
	var footer := Label.new()
	footer.text = "A / B / C / D  OBJECTIVES     •     BLUE / RED  TEAMS     •     [M] OR [ESC] CLOSE"
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color("81939d"))
	column.add_child(footer)
	body.add_child(_map_draw)
	_map_draw.z_index = 1

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.065, 0.08, 0.98)
	style.border_color = Color(0.27, 0.42, 0.49)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style

func configure(world: Node3D, map_builder: Node3D, player: Node3D) -> void:
	world_root = world
	map_root = map_builder
	local_player = player
	map_bounds = _find_bounds(map_builder)
	_ensure_camera()

func set_objectives(value: Array) -> void:
	objectives = value.duplicate(true)
	if is_instance_valid(_map_draw): _map_draw.queue_redraw()
	if is_instance_valid(_summary):
		var a := 0
		var b := 0
		for objective in objectives:
			if not objective is Dictionary: continue
			var owner := String(objective.get("owner", ""))
			if owner == "A": a += 1
			elif owner == "B": b += 1
		_summary.text = "A %d  /  %d B" % [a, b]

func set_open(open: bool) -> void:
	visible = open
	if is_instance_valid(map_viewport):
		map_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if open else SubViewport.UPDATE_DISABLED
	if open:
		_ensure_camera()
		_fit_camera()
		map_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_map_draw.queue_redraw()

func _ensure_camera() -> void:
	if not is_instance_valid(world_root) or is_instance_valid(map_camera): return
	map_camera = Camera3D.new()
	map_camera.name = "TacticalMapCamera"
	map_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	map_camera.cull_mask = 0xFFFFF
	map_viewport.world_3d = get_viewport().world_3d
	map_viewport.add_child(map_camera)

func _find_bounds(root: Node) -> AABB:
	var bounds := AABB()
	var found := false
	for node in root.find_children("*", "VisualInstance3D", true, false):
		var visual := node as VisualInstance3D
		if visual == null or visual.name == "SafetyFloor": continue
		var box := visual.get_aabb()
		var world_box := AABB(visual.global_transform * box.position, Vector3.ZERO)
		for corner in [Vector3.ZERO, Vector3(box.size.x, 0, 0), Vector3(0, box.size.y, 0), Vector3(0, 0, box.size.z), Vector3(box.size.x, box.size.y, 0), Vector3(box.size.x, 0, box.size.z), Vector3(0, box.size.y, box.size.z), box.size]:
			var point: Vector3 = visual.global_transform * (box.position + corner)
			world_box = world_box.expand(point)
		if not found:
			bounds = world_box
			found = true
		else:
			bounds = bounds.merge(world_box)
	if not found or bounds.size.x < 4.0 or bounds.size.z < 4.0:
		return AABB(Vector3(-32, -2, -32), Vector3(64, 20, 64))
	var pad := Vector3(maxf(bounds.size.x * 0.05, 3), 2, maxf(bounds.size.z * 0.05, 3))
	return AABB(bounds.position - pad, bounds.size + pad * 2)

func _fit_camera() -> void:
	if not is_instance_valid(map_camera): return
	var center := map_bounds.get_center()
	center.y = map_bounds.position.y
	var height := maxf(map_bounds.size.x, map_bounds.size.z) * 1.2 + map_bounds.size.y
	map_camera.global_position = Vector3(center.x, map_bounds.position.y + height, center.z)
	map_camera.look_at(center, Vector3(0, 0, -1))
	var aspect := float(map_viewport.size.x) / maxf(1.0, float(map_viewport.size.y))
	map_camera.size = maxf(map_bounds.size.z, map_bounds.size.x / aspect) * 1.12
	map_camera.near = 0.1
	map_camera.far = maxf(height * 2.5, 500.0)
	map_camera.make_current()
	map_viewport.world_3d = get_viewport().world_3d

func _draw_map() -> void:
	if not visible: return
	var size := _map_draw.size
	if size.x < 2 or size.y < 2: return
	if not is_instance_valid(map_camera): return
	var pixel_ratio := size / Vector2(map_viewport.size)
	for objective in objectives:
		if not objective is Dictionary: continue
		var pos := Vector3(float(objective.get("x", 0)), float(objective.get("y", 0)), float(objective.get("z", 0)))
		var point := map_camera.unproject_position(pos) * pixel_ratio
		var owner := String(objective.get("owner", ""))
		var col := TEAM_A if owner == "A" else TEAM_B if owner == "B" else NEUTRAL
		var contested := bool(objective.get("contested", false))
		var territory_radius := (map_camera.unproject_position(pos + Vector3.RIGHT * float(objective.get("radius", 12.0))) * pixel_ratio).distance_to(point)
		_map_draw.draw_circle(point, territory_radius, Color(col.r, col.g, col.b, 0.10))
		_map_draw.draw_arc(point, territory_radius, 0, TAU, 48, Color(col.r, col.g, col.b, 0.45), 1.0, true)
		_map_draw.draw_circle(point, 16, Color(0.01, 0.02, 0.025, 0.92))
		_map_draw.draw_arc(point, 13, 0, TAU, 32, Color(1.0, 0.5, 0.2) if contested else col, 3.0, true)
		var progress := clampf(float(objective.get("progress", 0)), 0.0, 1.0)
		if progress > 0.01: _map_draw.draw_arc(point, 9, -PI / 2, -PI / 2 + TAU * progress, 24, Color(0.95, 0.82, 0.35), 3.0, true)
		var code := String(objective.get("id", "?")).to_upper()
		_map_draw.draw_string(ThemeDB.fallback_font, point + Vector2(-4, 5), code, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	if is_instance_valid(local_player):
		var p := local_player.global_position
		var marker := map_camera.unproject_position(p) * pixel_ratio
		_map_draw.draw_colored_polygon(PackedVector2Array([marker + Vector2(0, -10), marker + Vector2(7, 8), marker + Vector2(-7, 8)]), Color(1, 1, 1))
