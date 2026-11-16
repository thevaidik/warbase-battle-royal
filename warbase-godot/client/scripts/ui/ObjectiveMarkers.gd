class_name WarObjectiveMarkers
extends Control
## Screen badges paired with world-space capture beacons.

var points: Array = []
var player: Node3D
var suppressed := false
var markers: Array[Dictionary] = []
var _elapsed := 0.0
var _prev_ownership: Dictionary = {}
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
		markers.append({
			"position": position,
			"direction": direction.normalized(),
			"edge": edge,
			"id": String(point.get("id", "?")),
			"color": color,
			"distance": roundi(player.global_position.distance_to(ground)),
			"progress": clampf(float(point.get("progress", 0)), 0, 1),
			"contested": bool(point.get("contested", false))
		})
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
		_beam_mesh.radial_segments = 16
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
			_add_beacon_mesh(beacon, _ring_mesh, Vector3.UP * 0.04)
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
		beam.emission_enabled = true
		beam.emission = color
		beam.emission_energy_multiplier = 2.0
		ring.albedo_color = Color(color, 0.72)
		ring.emission_enabled = true
		ring.emission = color
		ring.emission_energy_multiplier = 2.5
		var id := String(point.get("id", str(visible_count)))
		var current_owner := String(point.get("owner", ""))
		if _prev_ownership.has(id):
			var prev_owner: String = _prev_ownership[id]
			if prev_owner != current_owner:
				var local_team := GameState.local_team if "local_team" in GameState else "A"
				var captured_by_us := current_owner == local_team
				Audio.objective_alert(captured_by_us)
				var main = get_tree().current_scene
				if main and main.has_node("HUD"):
					var team_label := "TEAM " + current_owner if not current_owner.is_empty() else "NEUTRAL"
					var chatter_col := "cyan" if current_owner == local_team else ("danger" if not current_owner.is_empty() else "muted")
					main.get_node("HUD").call("post_radio_chatter", "HQ", "Objective %s secured by %s." % [id.to_upper(), team_label], chatter_col)
		_prev_ownership[id] = current_owner
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
	var time_ms := Time.get_ticks_msec()
	var center := size * 0.5
	
	for marker in markers:
		# Vision filtering: do not render points that are clamped to screen edges or behind camera.
		# Objectives show smoothly when the user faces them in world space.
		if marker.get("edge", false):
			continue
			
		var pos: Vector2 = marker["position"]
		var base_color: Color = marker["color"]
		var dist_to_center := pos.distance_to(center)
		var alpha: float = clampf(dist_to_center / 80.0, 0.45, 1.0)
		if alpha <= 0.01: continue
		
		var is_cont: bool = bool(marker.get("contested", false))
		var progress: float = float(marker.get("progress", 0.0))
		var id_str: String = String(marker.get("id", "?")).to_upper()
		var dist_m: int = int(marker.get("distance", 0))
		
		# Contested dynamic energy pulsing
		var pulse := 0.75 + 0.25 * sin(time_ms * 0.012)
		var theme_color := Color(base_color, alpha)
		if is_cont:
			theme_color = Color(Color("ffaa00"), alpha * pulse)
			
		# 1. Dark holographic badge backdrop (Chamfered Diamond)
		var badge_radius := 18.0
		var bg_color := Color(0.015, 0.025, 0.045, 0.82 * alpha)
		var diamond := PackedVector2Array([
			pos + Vector2(0, -badge_radius),
			pos + Vector2(badge_radius, 0),
			pos + Vector2(0, badge_radius),
			pos + Vector2(-badge_radius, 0)
		])
		draw_colored_polygon(diamond, bg_color)
		
		# 2. Glowing inner boundary outline
		draw_polyline(PackedVector2Array([
			pos + Vector2(0, -badge_radius),
			pos + Vector2(badge_radius, 0),
			pos + Vector2(0, badge_radius),
			pos + Vector2(-badge_radius, 0),
			pos + Vector2(0, -badge_radius)
		]), Color(theme_color, 0.45 * alpha), 1.5, true)
		
		# 3. Tactical Cyber Brackets around the Diamond [ A ]
		var bracket_offset := 23.0
		var bracket_len := 6.0
		var bracket_color := Color(theme_color, 0.90 * alpha)
		
		# Top-Left Bracket
		draw_polyline(PackedVector2Array([
			pos + Vector2(-bracket_offset, -bracket_offset + bracket_len),
			pos + Vector2(-bracket_offset, -bracket_offset),
			pos + Vector2(-bracket_offset + bracket_len, -bracket_offset)
		]), bracket_color, 1.8, true)
		# Top-Right Bracket
		draw_polyline(PackedVector2Array([
			pos + Vector2(bracket_offset - bracket_len, -bracket_offset),
			pos + Vector2(bracket_offset, -bracket_offset),
			pos + Vector2(bracket_offset, -bracket_offset + bracket_len)
		]), bracket_color, 1.8, true)
		# Bottom-Left Bracket
		draw_polyline(PackedVector2Array([
			pos + Vector2(-bracket_offset, bracket_offset - bracket_len),
			pos + Vector2(-bracket_offset, bracket_offset),
			pos + Vector2(-bracket_offset + bracket_len, bracket_offset)
		]), bracket_color, 1.8, true)
		# Bottom-Right Bracket
		draw_polyline(PackedVector2Array([
			pos + Vector2(bracket_offset - bracket_len, bracket_offset),
			pos + Vector2(bracket_offset, bracket_offset),
			pos + Vector2(bracket_offset, bracket_offset - bracket_len)
		]), bracket_color, 1.8, true)
		
		# 4. Circular Capture Sweep Arc (Active Capture Meter)
		var meter_radius := 27.0
		if progress > 0.0:
			# Background meter track
			draw_arc(pos, meter_radius, 0, TAU, 32, Color(1, 1, 1, 0.12 * alpha), 2.0, true)
			# Active progress arc
			var start_angle := -PI * 0.5
			var sweep_angle := TAU * progress
			var prog_color := Color("ffbb33") if is_cont else Color("00e5ff")
			draw_arc(pos, meter_radius, start_angle, start_angle + sweep_angle, 32, Color(prog_color, 0.95 * alpha), 2.5, true)
			# Glowing head of progress
			var head_pos := pos + Vector2(cos(start_angle + sweep_angle), sin(start_angle + sweep_angle)) * meter_radius
			draw_circle(head_pos, 2.5, Color(1, 1, 1, alpha))
		
		# 5. High-Impact Center Objective Code (A, B, C...)
		var font_size := 18
		var str_size := font.get_string_size(id_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos := pos + Vector2(-str_size.x * 0.5, str_size.y * 0.32)
		draw_string_outline(font, text_pos, id_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 3, Color(0, 0, 0, 0.9 * alpha))
		draw_string(font, text_pos, id_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1, 1, 1, alpha))
		
		# 6. Sleek Distance / Status Pill below marker
		var pill_text := "%dm" % dist_m
		var pill_color := Color(0.85, 0.92, 1.0, alpha)
		if is_cont:
			pill_text = "CONTESTED · %dm" % dist_m
			pill_color = Color("ffaa00")
			
		var sub_font_size := 11
		var pill_text_size := font.get_string_size(pill_text, HORIZONTAL_ALIGNMENT_CENTER, -1, sub_font_size)
		var pill_pad := Vector2(7.0, 3.0)
		var pill_rect := Rect2(
			pos.x - pill_text_size.x * 0.5 - pill_pad.x,
			pos.y + bracket_offset + 5.0,
			pill_text_size.x + pill_pad.x * 2.0,
			pill_text_size.y + pill_pad.y * 2.0
		)
		# Draw dark frosted backdrop pill
		draw_rect(pill_rect, Color(0.015, 0.03, 0.05, 0.85 * alpha), true)
		draw_rect(pill_rect, Color(theme_color, 0.35 * alpha), false, 1.0)
		
		var pill_text_pos := Vector2(
			pos.x - pill_text_size.x * 0.5,
			pos.y + bracket_offset + 5.0 + pill_pad.y + pill_text_size.y * 0.8
		)
		draw_string(font, pill_text_pos, pill_text, HORIZONTAL_ALIGNMENT_CENTER, -1, sub_font_size, Color(pill_color, alpha))
