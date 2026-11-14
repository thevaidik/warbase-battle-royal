class_name WarHUD
extends CanvasLayer
## AAA In-game Tactical HUD.
## Ported from Babylon GUI overlays + SwiftUI HUDView with best Godot 4.3+ practices:
## Custom-drawn military sniper reticle, directional damage indicators, pulsing low-health vignette,
## dynamic crosshairs, animated hitmarkers, killfeed, responsive scoreboard, and pause settings.

signal redeploy_pressed
signal deploy_pressed
signal resume_pressed
signal quit_pressed
signal scoreboard_closed

var _bot_damage_btn: Button
var _pause_bot_btn: Button

var _connection_status: Label

func set_connection_status(message: String) -> void:
	if not is_instance_valid(_connection_status): return
	_connection_status.text = message
	_connection_status.visible = not message.is_empty()

var _menu_scrim: ColorRect
var _practice_bar: PanelContainer
var _controls_hint: Label
var cross_dot: ColorRect
var cross_lines: Array[ColorRect] = []
var hitmarker: Label
var hitmarker_scale: float = 1.0
var health_bar: ProgressBar
var health_label: Label
var _hull_critical_label: Label
var chassis_armor_label: Label
var equipment_label: Label
var killfeed_box: VBoxContainer
var score_label: Label
var objective_strip: HBoxContainer
var objective_labels: Array[Label] = []
var _sensor_reticle: DroneSensorReticle
var _thermal_feed: ColorRect
var _cinematic_lens: ColorRect
var _payload_cards: Array[Dictionary] = []
var _fire_mode_label: Label
var _thumbnail_material := CanvasItemMaterial.new()
var death_panel: PanelContainer
var death_label: Label
var killer_card: HBoxContainer
var killer_detail: Label
var killer_viewport: SubViewport
var killer_drone: Node3D
var respawn_label: Label
var _redeploy_actions: HBoxContainer
var _redeploy_button: Button
var _editor_deploy_button: Button
var _drone_editor: PanelContainer
var _editor_preview: Control
var _redeploy_seconds := 3
var _redeploy_pending := false
var pause_panel: PanelContainer
var board_panel: PanelContainer
var board_list: VBoxContainer
var audit_box: VBoxContainer
var _audit_lbl_status: Label
var _audit_lbl_frame: Label
var _audit_lbl_render: Label
var _audit_lbl_memory: Label
var _audit_lbl_physics: Label
var _audit_lbl_verdict: Label
var _current_ping := 0
var _audit_timer := 0.0
var ping_label: Label
var fps_label: Label
var optic_label: Label
var player_header_label: Label
var match_info_label: Label
var drone_telemetry_label: Label
var low_hp_vignette: ColorRect
var damage_overlay: Control
var _tactical_radar: TacticalRadar
var _compass_ribbon: CompassRibbon
var _missile_alert_box: PanelContainer
var _missile_alert_label: Label
var _missile_lock_timer := 0.0
var _low_hull_alarm_timer := 0.0
var _radio_chatter: RadioChatter
var _ability_name_label: Label
var _ability_status_label: Label
var _ability_bar: ProgressBar

var _hit_t := 0.0
var _feed: Array = []
var _damage_arcs: Array = []
var _hurt_flash_t := 0.0
var _low_hp_pulse := 0.0
var _fps_timer := 0.0

class TacticalRadar extends Control:
	var player_pos := Vector3.ZERO
	var player_yaw := 0.0
	var radar_range := 100.0
	var contacts: Array[Dictionary] = []
	var objectives: Array[Dictionary] = []
	var sweep_angle := 0.0
	var missile_threat := false
	var missile_threat_dir := Vector3.ZERO
	var missile_threat_dist := 0

	func _ready() -> void:
		custom_minimum_size = Vector2(104, 104)
		size = Vector2(104, 104)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func update_sweep(delta: float) -> void:
		sweep_angle = fmod(sweep_angle + delta * 2.6, TAU)
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius := 48.0
		var bg_col := Color(0.015, 0.035, 0.045, 0.88)
		draw_circle(center, radius, bg_col)
		
		# Radar range grid rings (33m, 66m, 100m)
		draw_arc(center, radius, 0, TAU, 32, WarUI.LINE, 1.2, true)
		draw_arc(center, radius * 0.66, 0, TAU, 24, Color(0.12, 0.24, 0.28, 0.35), 1.0, true)
		draw_arc(center, radius * 0.33, 0, TAU, 20, Color(0.12, 0.24, 0.28, 0.35), 1.0, true)
		draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(0.12, 0.24, 0.28, 0.25), 1.0)
		draw_line(center - Vector2(0, radius), center + Vector2(0, radius), Color(0.12, 0.24, 0.28, 0.25), 1.0)

		# Rotating radar sweep line with phosphor fade
		var sweep_dir := Vector2(cos(sweep_angle), sin(sweep_angle))
		draw_line(center, center + sweep_dir * radius, Color(0.25, 0.95, 0.85, 0.55), 1.4, true)
		draw_arc(center, radius * 0.85, sweep_angle - 0.45, sweep_angle, 6, Color(0.25, 0.95, 0.85, 0.12), 8.0)

		# Cardinal perimeter labels (N, E, S, W) relative to player yaw
		var font := get_theme_default_font()
		var cardinals := [
			{"label": "N", "angle": -player_yaw - PI * 0.5, "col": WarUI.CYAN},
			{"label": "E", "angle": -player_yaw, "col": Color(0.55, 0.65, 0.70, 0.7)},
			{"label": "S", "angle": -player_yaw + PI * 0.5, "col": Color(0.55, 0.65, 0.70, 0.7)},
			{"label": "W", "angle": -player_yaw + PI, "col": Color(0.55, 0.65, 0.70, 0.7)}
		]
		for card in cardinals:
			var cpt := center + Vector2(cos(card["angle"]), sin(card["angle"])) * (radius - 5.0)
			draw_string(font, cpt + Vector2(-3, 3), card["label"], HORIZONTAL_ALIGNMENT_CENTER, -1, 9, card["col"])

		# Player heading arrow
		var p_top := center + Vector2(0, -5.5)
		var p_left := center + Vector2(-3.5, 3.5)
		var p_right := center + Vector2(3.5, 3.5)
		var p_indent := center + Vector2(0, 1.0)
		draw_colored_polygon(PackedVector2Array([p_top, p_right, p_indent, p_left]), WarUI.CYAN)

		# Inbound missile alert strobe on radar
		if missile_threat:
			var pulse := sin(Time.get_ticks_msec() * 0.015) * 0.4 + 0.6
			draw_arc(center, radius + 2.0, 0, TAU, 32, Color(1.0, 0.2, 0.1, pulse), 2.2, true)
			var rx := missile_threat_dir.x * cos(player_yaw) - missile_threat_dir.z * sin(player_yaw)
			var rz := missile_threat_dir.x * sin(player_yaw) + missile_threat_dir.z * cos(player_yaw)
			var ang := atan2(-rz, rx) - PI * 0.5
			var edge_pt := center + Vector2(cos(ang), sin(ang)) * radius
			var in_pt := center + Vector2(cos(ang), sin(ang)) * (radius - 12.0)
			draw_line(edge_pt, in_pt, Color(1.0, 0.2, 0.1, 0.95), 2.5)
			draw_circle(in_pt, 3.5, Color(1.0, 0.2, 0.1, pulse))

		# Objectives
		for obj in objectives:
			var opos: Vector3 = obj.get("pos", Vector3.ZERO)
			var rel := opos - player_pos
			var rx := rel.x * cos(player_yaw) - rel.z * sin(player_yaw)
			var rz := rel.x * sin(player_yaw) + rel.z * cos(player_yaw)
			var dist_m := Vector2(rx, rz).length()
			var screen_dist := minf(radius - 8.0, (dist_m / radar_range) * radius)
			var angle := atan2(-rz, rx) - PI * 0.5
			var pt := center + Vector2(cos(angle), sin(angle)) * screen_dist
			var col: Color = obj.get("color", Color.WHITE)
			draw_circle(pt, 5.0, Color(0.02, 0.04, 0.05, 0.9))
			draw_arc(pt, 5.0, 0, TAU, 12, col, 1.2, true)
			var lbl: String = obj.get("label", "")
			if not lbl.is_empty():
				draw_string(font, pt + Vector2(-3, 4), lbl, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, col)

		# Contacts (drones, tanks, bots)
		for c in contacts:
			var cpos: Vector3 = c.get("pos", Vector3.ZERO)
			var rel := cpos - player_pos
			var rx := rel.x * cos(player_yaw) - rel.z * sin(player_yaw)
			var rz := rel.x * sin(player_yaw) + rel.z * cos(player_yaw)
			var dist_m := Vector2(rx, rz).length()
			if dist_m > radar_range: continue
			var screen_dist := (dist_m / radar_range) * (radius - 4.0)
			var angle := atan2(-rz, rx) - PI * 0.5
			var pt := center + Vector2(cos(angle), sin(angle)) * screen_dist
			var is_friend: bool = c.get("friendly", false)
			if is_friend:
				draw_circle(pt, 3.0, WarUI.CYAN)
			else:
				var d_poly := PackedVector2Array([
					pt + Vector2(0, -3.8),
					pt + Vector2(3.8, 0),
					pt + Vector2(0, 3.8),
					pt + Vector2(-3.8, 0)
				])
				draw_colored_polygon(d_poly, WarUI.DANGER)

class CompassRibbon extends Control:
	var player_yaw := 0.0
	var player_pos := Vector3.ZERO
	var objectives: Array[Dictionary] = []
	var missile_warning := false
	var missile_dist := 0

	func _ready() -> void:
		custom_minimum_size = Vector2(360, 24)
		size = Vector2(360, 24)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var center_x := w * 0.5
		var font := get_theme_default_font()
		
		draw_rect(Rect2(0, 0, w, h), Color(0.015, 0.035, 0.045, 0.75))
		draw_line(Vector2(0, h), Vector2(w, h), Color(0.12, 0.28, 0.32, 0.6), 1.0)
		draw_line(Vector2(0, 0), Vector2(w, 0), Color(0.12, 0.28, 0.32, 0.6), 1.0)
		
		var cur_pts := PackedVector2Array([
			Vector2(center_x, 6),
			Vector2(center_x - 4, 0),
			Vector2(center_x + 4, 0)
		])
		draw_colored_polygon(cur_pts, WarUI.CYAN)
		
		var yaw_deg := fposmod(-rad_to_deg(player_yaw), 360.0)
		var px_per_deg := 2.2
		var visible_deg := (w * 0.5) / px_per_deg
		
		var start_deg := int(floor((yaw_deg - visible_deg) / 5.0)) * 5
		var end_deg := int(ceil((yaw_deg + visible_deg) / 5.0)) * 5
		
		var d := start_deg
		while d <= end_deg:
			var normalized_deg := fposmod(float(d), 360.0)
			var diff := float(d) - yaw_deg
			var x := center_x + diff * px_per_deg
			if x >= 0 and x <= w:
				if int(normalized_deg) % 45 == 0:
					var card_label := ""
					var col := WarUI.TEXT
					match int(normalized_deg):
						0, 360: card_label = "N"; col = WarUI.CYAN
						45: card_label = "NE"
						90: card_label = "E"
						135: card_label = "SE"
						180: card_label = "S"
						225: card_label = "SW"
						270: card_label = "W"
						315: card_label = "NW"
					draw_line(Vector2(x, h - 8), Vector2(x, h), col, 1.4)
					draw_string(font, Vector2(x - 6, h - 10), card_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, col)
				elif int(normalized_deg) % 15 == 0:
					draw_line(Vector2(x, h - 5), Vector2(x, h), Color(0.35, 0.55, 0.60, 0.5), 1.0)
				else:
					draw_line(Vector2(x, h - 3), Vector2(x, h), Color(0.20, 0.35, 0.40, 0.35), 1.0)
			d += 5

		for obj in objectives:
			var opos: Vector3 = obj.get("pos", Vector3.ZERO)
			var rel := opos - player_pos
			var angle_rad := atan2(rel.x, -rel.z)
			var target_deg := fposmod(rad_to_deg(angle_rad), 360.0)
			var deg_diff := fposmod(target_deg - yaw_deg + 180.0, 360.0) - 180.0
			var obj_x := center_x + deg_diff * px_per_deg
			if obj_x >= 12 and obj_x <= w - 12:
				var col: Color = obj.get("color", Color.WHITE)
				var lbl: String = obj.get("label", "")
				draw_circle(Vector2(obj_x, 12), 5.0, Color(0.02, 0.04, 0.05, 0.9))
				draw_arc(Vector2(obj_x, 12), 5.0, 0, TAU, 12, col, 1.2, true)
				draw_string(font, Vector2(obj_x - 3, 16), lbl, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, col)

		if missile_warning:
			var pulse := sin(Time.get_ticks_msec() * 0.02) * 0.5 + 0.5
			var alert_text := "⚠️ MISSILE [%dM] ⚠️" % missile_dist
			draw_string(font, Vector2(center_x - 55, 16), alert_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1.0, 0.2, 0.1, pulse))

class RadioChatter extends VBoxContainer:
	var _lines: Array[Label] = []

	func _ready() -> void:
		custom_minimum_size = Vector2(320, 80)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_constant_override("separation", 2)

	func post_message(callsign: String, message: String, color: Color) -> void:
		var time_str := Time.get_time_string_from_system()
		var short_time := time_str.substr(0, 5) if time_str.length() >= 5 else "00:00"
		var text := "[%s] %s: %s" % [short_time, callsign.to_upper(), message]
		var lbl := Label.new()
		lbl.text = text
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", color)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(lbl)
		_lines.append(lbl)
		if _lines.size() > 4:
			var old: Label = _lines.pop_front()
			if is_instance_valid(old):
				old.queue_free()
		var tw := create_tween()
		tw.tween_interval(5.2)
		tw.tween_property(lbl, "modulate:a", 0.0, 0.8)
		tw.tween_callback(func() -> void:
			if is_instance_valid(lbl):
				_lines.erase(lbl)
				lbl.queue_free()
		)

class DroneSensorReticle extends Control:
	var readout := ""
	var sensor_mode := ""
	var thermal := false
	var on_target := false

	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var center := size * 0.5
		var extent := Vector2(minf(236.0, size.x * 0.28), minf(144.0, size.y * 0.25))
		var ink := Color("d8f3ed") if thermal else Color("b9f5e7")
		var edge := Color(0.025, 0.07, 0.07, 0.85)
		for side in [-1.0, 1.0]:
			for vertical in [-1.0, 1.0]:
				var corner := center + extent * Vector2(side, vertical)
				var horizontal_end := corner - Vector2(side * 22.0, 0.0)
				var vertical_end := corner - Vector2(0.0, vertical * 22.0)
				draw_line(corner, horizontal_end, edge, 4.0, true)
				draw_line(corner, vertical_end, edge, 4.0, true)
				draw_line(corner, horizontal_end, ink, 1.3, true)
				draw_line(corner, vertical_end, ink, 1.3, true)
			var axis := Vector2(side, 0)
			draw_line(center + axis * 8.0, center + axis * 33.0, edge, 4.0, true)
			draw_line(center + axis * 8.0, center + axis * 33.0, ink, 1.3, true)
			for step in [14.0, 21.0, 28.0]:
				var tick := center + axis * float(step)
				draw_line(tick, tick + Vector2(0, 4), ink, 1.2, true)
		draw_line(center + Vector2(0, 9), center + Vector2(0, 24), edge, 4.0, true)
		draw_line(center + Vector2(0, 9), center + Vector2(0, 24), ink, 1.3, true)
		draw_circle(center, 3.5, edge, true, -1.0, true)
		draw_circle(center, 1.9, Color("ff9e67") if on_target else ink, true, -1.0, true)
		var font := get_theme_default_font()
		var title_pos := center + Vector2(-extent.x + 8.0, -extent.y + 22.0)
		var info_pos := center + Vector2(-extent.x + 8.0, extent.y - 12.0)
		for line in [[title_pos, sensor_mode], [info_pos, readout]]:
			draw_string_outline(font, line[0], line[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, edge)
			draw_string(font, line[0], line[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)

class DamageIndicator extends Control:
	var hud_ref: WarHUD
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if get_viewport():
			get_viewport().size_changed.connect(queue_redraw)
		
	func _draw() -> void:
		if hud_ref == null:
			return
		var vp: Vector2 = get_viewport_rect().size
		if vp.x <= 0.0 or vp.y <= 0.0:
			vp = size if (size.x > 0.0 and size.y > 0.0) else Vector2(1280.0, 720.0)
		var flash := clampf(hud_ref._hurt_flash_t / 0.28, 0.0, 1.0)
		if flash > 0:
			draw_rect(Rect2(Vector2.ZERO, vp), Color(0.015, 0.22, 0.28, flash * 0.08))
		var center := vp * 0.5
		var radius := minf(vp.x, vp.y) * 0.38
		for arc in hud_ref._damage_arcs:
			var ang: float = float(arc["angle"])
			var alpha: float = float(arc["life"]) / 1.5
			var col := Color(0.35, 0.88, 1.0, clampf(alpha, 0.0, 0.8))
			draw_arc(center, radius, ang - 0.35, ang + 0.35, 16, col, 8.0)

func _ready() -> void:
	layer = 10
	build()
	WarUI.apply(self)
	GameState.bot_damage_toggled.connect(func(_enabled: bool) -> void:
		_update_bot_damage_btn()
		_update_pause_bot_btn()
	)

func _mk_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size >= 19: WarUI.heading(l)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func build() -> void:
	_thermal_feed = ColorRect.new()
	_thermal_feed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_thermal_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_thermal_feed.z_index = -10
	_thermal_feed.visible = false
	var filter := ShaderMaterial.new()
	filter.shader = preload("res://scripts/ui/DroneThermal.gdshader")
	_thermal_feed.material = filter
	add_child(_thermal_feed)

	_cinematic_lens = ColorRect.new()
	_cinematic_lens.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cinematic_lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cinematic_lens.z_index = -9
	var lens_filter := ShaderMaterial.new()
	lens_filter.shader = preload("res://scripts/ui/CinematicLens.gdshader")
	_cinematic_lens.material = lens_filter
	add_child(_cinematic_lens)
	_connection_status = _mk_label("", 20, WarUI.ACCENT)
	_connection_status.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_connection_status.position = Vector2(-320,100)
	_connection_status.size = Vector2(640,50)
	_connection_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_connection_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_connection_status.visible = false
	add_child(_connection_status)
	# Low Health Vignette
	low_hp_vignette = ColorRect.new()
	low_hp_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	low_hp_vignette.color = Color(0.0, 0.28, 0.38, 0.0)
	low_hp_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(low_hp_vignette)
	
	# Directional Damage Overlay
	var dmg_ctrl := DamageIndicator.new()
	dmg_ctrl.hud_ref = self
	add_child(dmg_ctrl)
	damage_overlay = dmg_ctrl
	
	# Dynamic Crosshair Center
	var center := Control.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	
	for data in [[0, -14, 2, 10], [0, 6, 2, 10], [-16, -2, 10, 2], [8, -2, 10, 2]]:
		var r := ColorRect.new()
		r.color = Color.WHITE
		r.position = Vector2(data[0], data[1])
		r.size = Vector2(data[2], data[3])
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(r)
		cross_lines.append(r)
		
	var dot := ColorRect.new()
	dot.color = Color.WHITE
	dot.position = Vector2(-1, -1)
	dot.size = Vector2(2, 2)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(dot)
	cross_dot = dot
	
	# Hitmarker Label
	hitmarker = _mk_label("✕", 28, Color.WHITE)
	hitmarker.set_anchors_preset(Control.PRESET_CENTER)
	hitmarker.position = Vector2(-75, -28)
	hitmarker.custom_minimum_size = Vector2(150, 32)
	hitmarker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hitmarker.modulate.a = 0.0
	hitmarker.z_index = 3
	hitmarker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hitmarker)
	
	# Restrained combat panels remain legible over bright and dark environments.

	var health_card := PanelContainer.new()
	health_card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	health_card.position = Vector2(28, -150)
	health_card.custom_minimum_size = Vector2(226, 122)
	health_card.z_index = 2
	health_card.add_theme_stylebox_override("panel", WarUI.panel(Color(0.035, 0.055, 0.06, 0.92), WarUI.LINE, 16))
	add_child(health_card)
	WarUI.decorate(health_card, WarUI.CYAN)
	var hb := VBoxContainer.new()
	hb.z_index = 2
	hb.add_theme_constant_override("separation", 4)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_card.add_child(hb)
	var chassis_name := GameState.selected_drone_chassis
	var init_max := GameState.max_health_for_chassis(chassis_name)
	hb.add_child(_mk_label("+  DRONE HULL", 12, WarUI.CYAN))
	
	health_label = _mk_label(str(init_max), 46, Color.WHITE)
	hb.add_child(health_label)
	
	health_bar = ProgressBar.new()
	health_bar.min_value = 0
	health_bar.max_value = init_max
	health_bar.value = init_max
	health_bar.custom_minimum_size = Vector2(190, 5)
	health_bar.show_percentage = false
	hb.add_child(health_bar)
	
	chassis_armor_label = _mk_label(_armor_label_text(chassis_name, init_max), 11, WarUI.MUTED)
	hb.add_child(chassis_armor_label)
	
	_hull_critical_label = _mk_label("⚠ HULL CRITICAL", 11, Color("ff3333"))
	_hull_critical_label.visible = false
	hb.add_child(_hull_critical_label)

	# Ability / Mobility Gadget Card (Positioned beside health card at bottom-left)
	var ability_card := PanelContainer.new()
	ability_card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ability_card.position = Vector2(266, -112)
	ability_card.custom_minimum_size = Vector2(156, 84)
	ability_card.z_index = 2
	ability_card.add_theme_stylebox_override("panel", WarUI.panel(Color(0.035, 0.055, 0.06, 0.92), WarUI.LINE, 12))
	add_child(ability_card)
	WarUI.decorate(ability_card, WarUI.ACCENT)
	var ab_box := VBoxContainer.new()
	ab_box.z_index = 2
	ab_box.add_theme_constant_override("separation", 3)
	ab_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ability_card.add_child(ab_box)
	_ability_name_label = _mk_label("[F] GADGET", 11, WarUI.ACCENT)
	ab_box.add_child(_ability_name_label)
	_ability_status_label = _mk_label("READY", 20, WarUI.CYAN)
	ab_box.add_child(_ability_status_label)
	_ability_bar = ProgressBar.new()
	_ability_bar.min_value = 0.0
	_ability_bar.max_value = 1.0
	_ability_bar.value = 1.0
	_ability_bar.custom_minimum_size = Vector2(120, 4)
	_ability_bar.show_percentage = false
	ab_box.add_child(_ability_bar)
	
	# Tactical Bottom-Right HUD: Weapon & Ammo
	var ammo_card := PanelContainer.new()
	ammo_card.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_card.offset_left = -316
	ammo_card.offset_right = -28
	ammo_card.offset_top = -224
	ammo_card.offset_bottom = -28
	ammo_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ammo_card.custom_minimum_size = Vector2(274, 152)
	ammo_card.z_index = 2
	ammo_card.add_theme_stylebox_override("panel", WarUI.panel(Color(0.035, 0.055, 0.06, 0.92), WarUI.LINE, 16))
	add_child(ammo_card)
	WarUI.decorate(ammo_card, WarUI.ACCENT)
	var ab := VBoxContainer.new()
	ab.z_index = 2
	ab.add_theme_constant_override("separation", 2)
	ab.alignment = BoxContainer.ALIGNMENT_END
	ab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_card.add_child(ab)
	
	equipment_label = _mk_label("", 11, WarUI.ACCENT)
	ab.add_child(equipment_label)
	_payload_cards.append(_build_payload_card(ab, "1", "PRIMARY"))
	_payload_cards.append(_build_payload_card(ab, "2", "SECONDARY"))
	_payload_cards.append(_build_payload_card(ab, "3", "TERTIARY"))
	_fire_mode_label = _mk_label("3  BOTH", 11, WarUI.MUTED)
	ab.add_child(_fire_mode_label)
	ping_label = _mk_label("", 12, Color(0.65, 0.65, 0.65))
	ab.add_child(ping_label)
	
	fps_label = _mk_label("", 11, WarUI.MUTED)
	fps_label.visible = false
	ab.add_child(fps_label)
	
	optic_label = _mk_label("RMB OPTIC   V ZOOM   T THERMAL   R RELOAD", 11, WarUI.ACCENT)
	ab.add_child(optic_label)
	
	var identity := PanelContainer.new()
	identity.position = Vector2(28, 24)
	identity.add_theme_stylebox_override("panel", WarUI.panel(Color(0.035, 0.055, 0.06, 0.9), WarUI.LINE, 12))
	add_child(identity)
	WarUI.decorate(identity, WarUI.CYAN)
	var identity_column := VBoxContainer.new()
	identity_column.add_theme_constant_override("separation", 4)
	identity.add_child(identity_column)
	player_header_label = _mk_label(GameState.username, 14, WarUI.TEXT)
	identity_column.add_child(player_header_label)
	match_info_label = _mk_label("OFFLINE PRACTICE", 11, WarUI.ACCENT)
	identity_column.add_child(match_info_label)
	_tactical_radar = TacticalRadar.new()
	_tactical_radar.position = Vector2(28, 88)
	add_child(_tactical_radar)
	_radio_chatter = RadioChatter.new()
	_radio_chatter.position = Vector2(28, 204)
	add_child(_radio_chatter)

	_compass_ribbon = CompassRibbon.new()
	_compass_ribbon.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_compass_ribbon.position = Vector2(-180, 2)
	_compass_ribbon.custom_minimum_size = Vector2(360, 24)
	add_child(_compass_ribbon)

	_missile_alert_box = PanelContainer.new()
	_missile_alert_box.set_anchors_preset(Control.PRESET_CENTER)
	_missile_alert_box.position = Vector2(-220, 75)
	_missile_alert_box.custom_minimum_size = Vector2(440, 48)
	_missile_alert_box.add_theme_stylebox_override("panel", WarUI.panel(Color(0.25, 0.04, 0.04, 0.92), Color(1.0, 0.2, 0.1, 0.9), 10))
	_missile_alert_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_missile_alert_box.visible = false
	_missile_alert_label = _mk_label("⚠️ MISSILE LOCK-ON DETECTED · DEPLOY COUNTERMEASURES [F/C] ⚠️", 13, Color(1.0, 0.85, 0.8))
	_missile_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_missile_alert_box.add_child(_missile_alert_label)
	add_child(_missile_alert_box)
	var score_position := CenterContainer.new()
	score_position.set_anchors_preset(Control.PRESET_TOP_WIDE)
	score_position.offset_top = 20
	add_child(score_position)
	score_label = _mk_label("", 24, WarUI.TEXT)
	score_label.add_theme_stylebox_override("normal", WarUI.panel(Color(0.035, 0.055, 0.06, 0.9), WarUI.LINE, 6))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_position.add_child(score_label)
	objective_strip = HBoxContainer.new()
	objective_strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	objective_strip.offset_top = 66
	objective_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	objective_strip.add_theme_constant_override("separation", 8)
	objective_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for code in ["A", "B", "C", "D"]:
		var item := _mk_label(code + "  ·  NEUTRAL", 12, WarUI.MUTED)
		item.add_theme_stylebox_override("normal", WarUI.panel(Color(0.035, 0.055, 0.06, 0.9), WarUI.LINE, 8))
		item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.custom_minimum_size.x = 94
		objective_labels.append(item)
		objective_strip.add_child(item)
	objective_strip.visible = false
	add_child(objective_strip)
	drone_telemetry_label = _mk_label("ALT  0.0 m    /    SPD  0 m/s", 14, WarUI.CYAN)
	drone_telemetry_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	drone_telemetry_label.position = Vector2(-330, 256)
	drone_telemetry_label.custom_minimum_size = Vector2(300, 24)
	drone_telemetry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(drone_telemetry_label)
	killfeed_box = VBoxContainer.new()
	killfeed_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	killfeed_box.position = Vector2(-328, 134)
	killfeed_box.custom_minimum_size = Vector2(300, 110)
	killfeed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	killfeed_box.add_theme_constant_override("separation", 6)
	add_child(killfeed_box)
	_controls_hint = _mk_label("WASD FLIGHT   SPACE ASCEND   CTRL DESCEND   SHIFT BOOST   M MAP   TAB BOARD   ESC MENU", 11, Color(0.8, 0.85, 0.83, 0.65))
	_controls_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_controls_hint.position = Vector2(-440, -34)
	_controls_hint.custom_minimum_size.x = 880
	_controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_controls_hint)
	_sensor_reticle = DroneSensorReticle.new()
	_sensor_reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sensor_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sensor_reticle.visible = false
	add_child(_sensor_reticle)

	# Death Screen
	death_panel = PanelContainer.new()
	death_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_panel.visible = false
	death_panel.add_theme_stylebox_override("panel", WarUI.panel(Color(0.03, 0.035, 0.04, 0.17), Color.TRANSPARENT))
	add_child(death_panel)
	
	var dv := VBoxContainer.new()
	dv.alignment = BoxContainer.ALIGNMENT_CENTER
	death_panel.add_child(dv)
	dv.size_flags_vertical = Control.SIZE_SHRINK_END
	dv.add_theme_constant_override("separation", 5)

	death_label = _mk_label("DRONE LOST", 40, WarUI.DANGER)
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dv.add_child(death_label)
	
	killer_card = HBoxContainer.new()
	killer_card.alignment = BoxContainer.ALIGNMENT_CENTER
	killer_card.add_theme_constant_override("separation", 14)
	dv.add_child(killer_card)
	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(132, 82)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	killer_viewport = SubViewport.new()
	killer_viewport.size = Vector2i(264, 164)
	killer_viewport.own_world_3d = true
	killer_viewport.transparent_bg = true
	killer_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	killer_card.add_child(picture)
	picture.texture = killer_viewport.get_texture()
	var camera := Camera3D.new()
	killer_viewport.add_child(camera)
	camera.transform = Transform3D().looking_at(Vector3(-0.75, -0.43, -1.15), Vector3.UP)
	camera.position = Vector3(0.75, 0.43, 1.15)
	killer_drone = load("res://scripts/drones/DroneVisual.gd").new()
	killer_viewport.add_child(killer_drone)
	killer_drone.configure(false, "ak47", "quad")
	killer_detail = _mk_label("", 17, WarUI.TEXT)
	killer_detail.custom_minimum_size.x = 300
	killer_card.add_child(killer_detail)
	killer_card.visible = false
	respawn_label = _mk_label("Re-deploying in 3s...", 18, Color(0.8, 0.8, 0.8))
	respawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dv.add_child(respawn_label)
	_redeploy_actions = HBoxContainer.new()
	_redeploy_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_redeploy_actions.add_theme_constant_override("separation", 12)
	dv.add_child(_redeploy_actions)
	var edit := Button.new()
	edit.text = "EDIT DRONE"
	edit.pressed.connect(_open_drone_editor)
	_redeploy_actions.add_child(edit)
	_redeploy_button = Button.new()
	_redeploy_button.text = "REDEPLOY"
	WarUI.primary(_redeploy_button)
	_redeploy_button.pressed.connect(func() -> void: redeploy_pressed.emit())
	_redeploy_actions.add_child(_redeploy_button)
	for label in [death_label, respawn_label]:
		label.add_theme_color_override("font_outline_color", Color("151d21"))
		label.add_theme_constant_override("outline_size", 5)
	var bottom_margin := Control.new()
	bottom_margin.custom_minimum_size.y = 54
	dv.add_child(bottom_margin)

	_menu_scrim = ColorRect.new()
	_menu_scrim.color = Color(0.015, 0.025, 0.03, 0.8)
	_menu_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_scrim.z_index = 9
	_menu_scrim.visible = false
	add_child(_menu_scrim)
	# Pause Menu with Live Settings
	var pause_overlay := CenterContainer.new()
	pause_overlay.z_index = 10
	pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pause_overlay)
	
	pause_panel = PanelContainer.new()
	pause_panel.custom_minimum_size = Vector2(440, 340)
	pause_panel.add_theme_stylebox_override("panel", WarUI.panel(WarUI.PANEL, WarUI.LINE, 28))
	pause_panel.visible = false
	pause_overlay.add_child(pause_panel)
	WarUI.decorate(pause_panel, WarUI.CYAN)
	
	var pv := VBoxContainer.new()
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.add_theme_constant_override("separation", 10)
	pause_panel.add_child(pv)
	
	var pt := _mk_label("TACTICAL PAUSE", 34, Color.WHITE)
	pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(pt)
	
	# Sensitivity Slider
	var sens_box := HBoxContainer.new()
	sens_box.add_child(_mk_label("SENSITIVITY", 12, Color.LIGHT_GRAY))
	var sens_slider := HSlider.new()
	sens_slider.min_value = 0.0005
	sens_slider.max_value = 0.006
	sens_slider.step = 0.0001
	sens_slider.value = GameState.BASE_SENSITIVITY
	sens_slider.custom_minimum_size = Vector2(180, 20)
	sens_slider.value_changed.connect(func(v: float) -> void:
		GameState.BASE_SENSITIVITY = v
		GameState.save_settings())
	sens_box.add_child(sens_slider)
	pv.add_child(sens_box)
	
	pv.add_child(_mk_label("AUDIO DISABLED", 12, Color.LIGHT_GRAY))
	
	var pause_bot_btn := Button.new()
	pause_bot_btn.custom_minimum_size = Vector2(0, 36)
	_pause_bot_btn = pause_bot_btn
	_update_pause_bot_btn()
	pause_bot_btn.pressed.connect(func() -> void:
		Audio.ui_btn_click()
		GameState.toggle_bot_damage()
		_update_bot_damage_btn()
		_update_pause_bot_btn()
		if GameState.bot_damage_enabled:
			feed(" Combat Mode: Bot Damage Enabled", Color(1.0, 0.45, 0.25))
		else:
			feed(" Peaceful Mode: Bot Damage OFF — Fly in Peace!", Color(0.3, 0.95, 0.4))
	)
	pv.add_child(pause_bot_btn)
	
	var resume_btn := Button.new()
	resume_btn.text = "RESUME GAME   [ESC]"
	WarUI.primary(resume_btn)
	resume_btn.custom_minimum_size = Vector2(0, 36)
	resume_btn.pressed.connect(func() -> void: resume_pressed.emit())
	pv.add_child(resume_btn)
	
	var quit_btn := Button.new()
	quit_btn.text = "Return to lobby"
	quit_btn.custom_minimum_size = Vector2(0, 36)
	quit_btn.pressed.connect(func() -> void: quit_pressed.emit())
	pv.add_child(quit_btn)
	
	# Scoreboard & Live Performance Audit Diagnostic Hub (TAB)
	var board_overlay := CenterContainer.new()
	board_overlay.z_index = 10
	board_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board_overlay)
	
	board_panel = PanelContainer.new()
	board_panel.custom_minimum_size = Vector2(760, 500)
	board_panel.visible = false
	board_overlay.add_child(board_panel)

	var b_style := StyleBoxFlat.new()
	b_style.bg_color = WarUI.PANEL
	b_style.border_color = WarUI.LINE
	b_style.set_border_width_all(2)
	b_style.set_corner_radius_all(6)
	b_style.content_margin_left = 18
	b_style.content_margin_right = 18
	b_style.content_margin_top = 16
	b_style.content_margin_bottom = 16
	board_panel.add_theme_stylebox_override("panel", b_style)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	board_panel.add_child(main_vbox)

	# Global Header Row
	var top_hdr := HBoxContainer.new()
	main_vbox.add_child(top_hdr)

	var tab_title := _mk_label("MATCH SCOREBOARD", 21, WarUI.TEXT)
	top_hdr.add_child(tab_title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hdr.add_child(spacer)

	_audit_lbl_status = _mk_label(" AUDIT: 120Hz ULTRA-FLUID", 13, Color(0.2, 1.0, 0.4))
	top_hdr.add_child(_audit_lbl_status)
	_audit_lbl_status.visible = false

	# Peaceful Mode & Bot Damage Control Bar
	var peace_bar := PanelContainer.new()
	_practice_bar = peace_bar
	var pb_style := StyleBoxFlat.new()
	pb_style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	pb_style.border_color = Color(0.25, 0.38, 0.55, 0.75)
	pb_style.set_border_width_all(1)
	pb_style.set_corner_radius_all(5)
	pb_style.content_margin_left = 14
	pb_style.content_margin_right = 14
	pb_style.content_margin_top = 8
	pb_style.content_margin_bottom = 8
	peace_bar.add_theme_stylebox_override("panel", pb_style)
	main_vbox.add_child(peace_bar)

	var pb_hbox := HBoxContainer.new()
	pb_hbox.add_theme_constant_override("separation", 14)
	peace_bar.add_child(pb_hbox)

	var pb_lbl := _mk_label("BOT BEHAVIOR:", 12, Color(0.7, 0.75, 0.85))
	pb_hbox.add_child(pb_lbl)

	var bot_dmg_btn := Button.new()
	bot_dmg_btn.custom_minimum_size = Vector2(290, 38)
	bot_dmg_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_bot_damage_btn = bot_dmg_btn
	_update_bot_damage_btn()
	bot_dmg_btn.pressed.connect(func() -> void:
		Audio.ui_btn_click()
		GameState.toggle_bot_damage()
		_update_bot_damage_btn()
		_update_pause_bot_btn()
		if GameState.bot_damage_enabled:
			feed(" Combat Mode: Bot Damage Enabled", Color(1.0, 0.45, 0.25))
		else:
			feed(" Peaceful Mode: Bot Damage OFF — Fly in Peace!", Color(0.3, 0.95, 0.4))
	)
	pb_hbox.add_child(bot_dmg_btn)

	var pb_hint := _mk_label("Hotkey: [P]", 11, Color(0.55, 0.65, 0.75))
	pb_hbox.add_child(pb_hint)

	var pb_spacer := Control.new()
	pb_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb_hbox.add_child(pb_spacer)

	var resume_board_btn := Button.new()
	resume_board_btn.text = " RESUME GAME [TAB / ESC]"
	resume_board_btn.custom_minimum_size = Vector2(180, 34)
	resume_board_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	resume_board_btn.pressed.connect(func() -> void:
		Audio.ui_btn_click()
		hide_board()
	)
	pb_hbox.add_child(resume_board_btn)

	# Dual Column Content Container
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(cols)

	# Left Column: Combat Roster / Scoreboard
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(420, 0)
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left_vbox)

	var sc_title := _mk_label("PILOTS", 12, Color(0.7, 0.82, 0.95))
	left_vbox.add_child(sc_title)

	var sc_scroll := ScrollContainer.new()
	sc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(sc_scroll)

	board_list = VBoxContainer.new()
	board_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_list.add_theme_constant_override("separation", 4)
	sc_scroll.add_child(board_list)

	# Vertical Divider
	var div := ColorRect.new()
	div.color = Color(0.2, 0.25, 0.35, 0.5)
	div.custom_minimum_size = Vector2(1, 0)
	div.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(div)
	div.visible = false

	# Right Column: Real-Time Hardware & Engine Telemetry
	audit_box = VBoxContainer.new()
	audit_box.custom_minimum_size = Vector2.ZERO
	audit_box.visible = false
	audit_box.add_theme_constant_override("separation", 8)
	cols.add_child(audit_box)

	var aud_hdr := _mk_label("LIVE HARDWARE & ENGINE AUDIT METRICS", 13, Color(0.4, 0.9, 1.0))
	audit_box.add_child(aud_hdr)

	_audit_lbl_frame = _mk_label("", 11, Color(0.9, 0.92, 0.95))
	audit_box.add_child(_audit_lbl_frame)

	_audit_lbl_render = _mk_label("", 11, Color(0.9, 0.92, 0.95))
	audit_box.add_child(_audit_lbl_render)

	_audit_lbl_memory = _mk_label("", 11, Color(0.9, 0.92, 0.95))
	audit_box.add_child(_audit_lbl_memory)

	_audit_lbl_physics = _mk_label("", 11, Color(0.9, 0.92, 0.95))
	audit_box.add_child(_audit_lbl_physics)

	_audit_lbl_verdict = _mk_label(" VERDICT: 120HZ COMPLIANT", 12, Color(0.3, 0.95, 0.4))
	audit_box.add_child(_audit_lbl_verdict)

	# ==========================================================
	# TACTICAL COMBAT JEEP / VEHICLE HUD OVERLAY
	# ==========================================================
func flash_hull_damage() -> void:
	_hurt_flash_t = 0.28
	damage_overlay.queue_redraw()

func add_damage_indicator(rel_dir: Vector3) -> void:
	# Calculate 2D screen angle for incoming fire
	var angle := atan2(rel_dir.x, -rel_dir.z) - PI / 2.0
	_damage_arcs.append({"angle": angle, "life": 1.5})
	if is_instance_valid(damage_overlay):
		damage_overlay.queue_redraw()

func set_crosshair(spread_px: float, ads: float, on_enemy: bool = false) -> void:
	var gap: float = 6.0 + spread_px * 2.5
	gap *= (1.0 - ads * 0.7)
	cross_lines[0].position = Vector2(-1, -gap - 10)
	cross_lines[1].position = Vector2(-1, gap)
	cross_lines[2].position = Vector2(-gap - 10, -1)
	cross_lines[3].position = Vector2(gap, -1)
	# Smoothly fade out hipfire crosshair as weapon raises to sight (zero pop)
	var alpha := clampf(1.0 - ads * 1.5, 0.0, 1.0)
	var vis := alpha > 0.01
	var tint := WarUI.DANGER if on_enemy else Color.WHITE
	tint.a = alpha
	for l in cross_lines:
		l.visible = vis
		l.modulate = tint
	if cross_dot:
		cross_dot.visible = vis
		cross_dot.modulate = tint

func flash_hitmarker(hit_type_or_kill: Variant = false, is_headshot: bool = false) -> void:
	if not is_instance_valid(hitmarker):
		return
	var type_str := "normal"
	if hit_type_or_kill is bool:
		type_str = "kill" if hit_type_or_kill else ("crit" if is_headshot else "normal")
	elif hit_type_or_kill is String:
		type_str = hit_type_or_kill

	match type_str:
		"kill":
			hitmarker.text = "☠ ELIMINATED"
			hitmarker.modulate = Color(1.0, 0.25, 0.25)
			hitmarker_scale = 1.35
			_hit_t = 0.42
		"crit":
			hitmarker.text = ">> CRITICAL <<"
			hitmarker.modulate = Color(1.0, 0.55, 0.15)
			hitmarker_scale = 1.2
			_hit_t = 0.28
		"deflect":
			hitmarker.text = "🛡 DEFLECT"
			hitmarker.modulate = Color(0.35, 0.85, 1.0)
			hitmarker_scale = 1.1
			_hit_t = 0.22
		_: # "normal"
			hitmarker.text = "✕"
			hitmarker.modulate = Color(0.95, 0.98, 1.0)
			hitmarker_scale = 1.0
			_hit_t = 0.18
	hitmarker.modulate.a = 1.0

func show_missile_lock(_id: int, dist: int, dir: Vector3) -> void:
	_missile_lock_timer = 2.4
	if is_instance_valid(_missile_alert_box):
		_missile_alert_box.visible = true
		if is_instance_valid(_missile_alert_label):
			_missile_alert_label.text = "⚠️ INBOUND MISSILE [%dM] · EVADE OR SMOKE [F/C] ⚠️" % dist
	if is_instance_valid(_tactical_radar):
		_tactical_radar.missile_threat = true
		_tactical_radar.missile_threat_dir = dir
		_tactical_radar.missile_threat_dist = dist
		_tactical_radar.queue_redraw()
	if is_instance_valid(_compass_ribbon):
		_compass_ribbon.missile_warning = true
		_compass_ribbon.missile_dist = dist
		_compass_ribbon.queue_redraw()

func clear_missile_lock(_id: int = 0) -> void:
	_missile_lock_timer = 0.0
	if is_instance_valid(_missile_alert_box):
		_missile_alert_box.visible = false
	if is_instance_valid(_tactical_radar):
		_tactical_radar.missile_threat = false
		_tactical_radar.queue_redraw()
	if is_instance_valid(_compass_ribbon):
		_compass_ribbon.missile_warning = false
		_compass_ribbon.queue_redraw()

func _armor_label_text(chassis: String, max_hp: int) -> String:
	match chassis:
		"tracked": return "TANK ARMOR  •  %d HP (MAX)" % max_hp
		"wheels": return "MONSTER 4x4  •  %d HP (HEAVY)" % max_hp
		"heli": return "GUNSHIP HELI  •  %d HP (AERO)" % max_hp
		"wing": return "INTERCEPTOR JET  •  %d HP (LIGHT)" % max_hp
		_: return "VANGUARD  •  %d HP" % max_hp

func set_health(h: int, max_h: int = -1) -> void:
	if max_h > 0:
		health_bar.max_value = max_h
		if is_instance_valid(chassis_armor_label):
			chassis_armor_label.text = _armor_label_text(GameState.selected_drone_chassis, max_h)
	var max_val := maxf(1.0, float(health_bar.max_value))
	health_label.text = str(h)
	health_bar.value = h
	var ratio := float(h) / max_val
	health_label.add_theme_color_override("font_color", Color.WHITE if ratio > 0.3 else Color(1.0, 0.3, 0.3))

func set_drone_mobility(chassis: String) -> void:
	var max_hp := GameState.max_health_for_chassis(chassis)
	health_bar.max_value = max_hp
	if is_instance_valid(chassis_armor_label):
		chassis_armor_label.text = _armor_label_text(chassis, max_hp)
	var movement_hint := "WASD DRIVE" if chassis in ["wheels", "tracked"] else "WASD FLIGHT   SPACE ASCEND   CTRL DESCEND   SHIFT BOOST"
	_controls_hint.text = movement_hint + "   M MAP   TAB BOARD   ESC MENU"

func set_drone_telemetry(speed_mps: float, altitude: float) -> void:
	if not is_instance_valid(drone_telemetry_label): return
	drone_telemetry_label.text = "ALT  %4.1f m    /    SPD  %2.0f m/s" % [maxf(0.0, altitude), maxf(0.0, speed_mps)]

func _build_payload_card(parent: VBoxContainer, key: String, slot_name: String) -> Dictionary:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 0)
	row.add_child(identity)
	var slot := _mk_label("%s  %s" % [key, slot_name], 11, WarUI.MUTED)
	identity.add_child(slot)
	var thumbnail := TextureRect.new()
	thumbnail.custom_minimum_size = Vector2(112, 38)
	thumbnail.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	thumbnail.material = _thumbnail_material
	thumbnail.z_index = 1
	identity.add_child(thumbnail)
	var title := _mk_label("", 12, WarUI.TEXT)
	identity.add_child(title)
	var values := VBoxContainer.new()
	values.alignment = BoxContainer.ALIGNMENT_CENTER
	values.add_theme_constant_override("separation", 0)
	row.add_child(values)
	var loaded := _mk_label("", 27, WarUI.TEXT)
	loaded.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	loaded.custom_minimum_size.x = 76
	values.add_child(loaded)
	var reserve := _mk_label("", 11, WarUI.MUTED)
	reserve.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	values.add_child(reserve)
	return {"panel": panel, "slot": slot, "title": title, "thumbnail": thumbnail, "loaded": loaded,
		"reserve": reserve, "id": "", "selected": null, "status": Vector3i(-1, -1, -1),
		"lit_style": WarUI.panel(Color("202c2b"), Color("61764c"), 6),
		"dim_style": WarUI.panel(Color("10191d"), Color("2f3b42"), 6)}

func update_payload_cards(system: WarWeaponSystem) -> void:
	var equipped := GameState.equipped_indices()
	var both := system.dual_fire and system.can_dual_fire()
	var is_tank := GameState.selected_drone_chassis == "tracked"
	for slot in _payload_cards.size():
		var card := _payload_cards[slot]
		if slot >= equipped.size():
			card.panel.visible = false
			continue
		card.panel.visible = true
		var index := equipped[slot]
		var config: Dictionary = GameState.WEAPONS[index]
		var id := String(config["id"])
		if card.id != id:
			card.id = id
			card.title.text = String(config["name"])
			card.thumbnail.texture = load("res://assets/ui/payloads/%s.png" % id)
			card.status = Vector3i(-1, -1, -1)
		var selected := both or system.active_index == index
		if card.selected != selected:
			card.selected = selected
			card.panel.add_theme_stylebox_override("panel", card.lit_style if selected else card.dim_style)
			card.slot.add_theme_color_override("font_color", WarUI.ACCENT if selected else WarUI.MUTED)
		var status := system.payload_status(index)
		if card.status == status: continue
		card.status = status
		card.loaded.text = "%02d" % status.x
		card.loaded.add_theme_color_override("font_color", WarUI.DANGER if status.x == 0 else WarUI.TEXT)
		card.reserve.text = "%02d RESERVE" % status.y if status.z == 0 else "RELOADING"
		card.reserve.add_theme_color_override("font_color", WarUI.MUTED if status.z == 0 else WarUI.ACCENT)
	_fire_mode_label.visible = system.can_dual_fire()
	var fire_key := "4" if is_tank else "3"
	var fire_mode := "%s  BOTH ACTIVE" % fire_key if both else "%s  BOTH" % fire_key
	if _fire_mode_label.text != fire_mode:
		_fire_mode_label.text = fire_mode
		_fire_mode_label.add_theme_color_override("font_color", WarUI.ACCENT if both else WarUI.MUTED)

func set_drone_sensor(on: bool, thermal: bool = false, zoom: int = 2, meters: float = 300.0, on_target: bool = false) -> void:
	if not is_instance_valid(_sensor_reticle): return
	_sensor_reticle.visible = on
	_thermal_feed.visible = on and thermal
	if is_instance_valid(_cinematic_lens):
		_cinematic_lens.visible = not (on and thermal)
	if not on: return
	for line in cross_lines: line.visible = false
	if is_instance_valid(cross_dot): cross_dot.visible = false
	var mode := "%s  /  %d×" % ["THERMAL" if thermal else "OPTICAL", zoom]
	var readout := ("RNG  %03d m" % roundi(meters) if meters < 299.0 else "RNG  —") + "     V ZOOM   T THERMAL"
	if _sensor_reticle.on_target != on_target or _sensor_reticle.sensor_mode != mode or _sensor_reticle.readout != readout:
		_sensor_reticle.on_target = on_target
		_sensor_reticle.thermal = thermal
		_sensor_reticle.sensor_mode = mode
		_sensor_reticle.readout = readout
		_sensor_reticle.queue_redraw()


func update_player_header(p_name: String = "", team: String = "", mode: String = "") -> void:
	if is_instance_valid(player_header_label):
		var nm := p_name if not p_name.is_empty() else GameState.username
		player_header_label.text = nm.to_upper()
	if is_instance_valid(match_info_label):
		var tm := team if not team.is_empty() else GameState.local_team
		var md := mode if not mode.is_empty() else GameState.selected_mode
		match_info_label.text = ("OFFLINE" if GameState.practice_mode else ("%s / %s" % [md, tm])) + "  •  " + GameState.time_label(GameState.selected_time)

func show_elimination(killer: String, victim: String, weapon: String) -> void:
	var weapon_tag := weapon.to_upper()
	if weapon_tag.is_empty(): weapon_tag = "KINETIC"
	var is_me_killer := killer == GameState.username
	var is_me_victim := victim == GameState.username
	var col := Color("ff5252") if is_me_victim else (Color("50fa7b") if is_me_killer else Color("d1d5db"))
	feed("%s  [%s]  ➔  %s" % [killer.to_upper(), weapon_tag, victim.to_upper()], col)

func show_killer_card(killer: String, weapon: String, chassis: String) -> void:
	if not is_instance_valid(killer_card): return
	var valid_chassis := chassis if chassis in ["quad", "wheels", "tracked", "heli", "wing"] else "quad"
	killer_detail.text = "ELIMINATED BY  " + killer.to_upper() + "\n" + weapon.to_upper() + "  •  " + chassis.to_upper() + " (" + str(GameState.max_health_for_chassis(valid_chassis)) + " HP CLASS)"
	killer_drone.configure(false, weapon, valid_chassis)
	killer_card.visible = true
	killer_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func feed(text: String, color: Color = Color.WHITE) -> void:
	var l := _mk_label(text, 14, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color.lerp(WarUI.TEXT, 0.5))
	killfeed_box.add_child(l)
	_feed.append(l)
	if _feed.size() > 5:
		var old: Label = _feed.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var tw := get_tree().create_tween()
	tw.tween_interval(3.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void:
		if is_instance_valid(l):
			l.queue_free()
			_feed.erase(l)
	)

func post_radio_chatter(callsign: String, message: String, color_key: Variant = "cyan") -> void:
	if not is_instance_valid(_radio_chatter):
		return
	var col := WarUI.CYAN
	if color_key is Color:
		col = color_key
	elif color_key is String:
		match color_key.to_lower():
			"amber", "orange": col = Color("ffaa33")
			"danger", "red": col = WarUI.DANGER
			"success", "green": col = WarUI.SUCCESS
			"muted": col = WarUI.MUTED
			"accent": col = WarUI.ACCENT
			_: col = WarUI.CYAN
	_radio_chatter.post_message(callsign, message, col)

func set_score(mode: String, a: int, b: int, team: String, winner: String) -> void:
	if mode == "CONQUEST":
		objective_strip.visible = true
		score_label.text = "A  %03d     /     CONQUEST     /     %03d  B%s" % [a, b, ("    WINNER: " + winner) if not winner.is_empty() else ""]
	elif mode == "TDM":
		objective_strip.visible = false
		score_label.text = "A  %03d     /     TEAM DEATHMATCH     /     %03d  B%s" % [a, b, ("    WINNER: " + winner) if not winner.is_empty() else ""]
	else:
		objective_strip.visible = false
		score_label.text = "" if winner.is_empty() else (" WINNER: " + winner)

func set_conquest_objectives(points: Array) -> void:
	if is_instance_valid(_tactical_radar):
		var radar_objs: Array[Dictionary] = []
		for p in points:
			if p is Dictionary and p.has("position"):
				var owner := String(p.get("owner", ""))
				var contested := bool(p.get("contested", false))
				var col := Color("ffad61") if contested else (Color("54b5ff") if owner == "A" else (Color("ff6659") if owner == "B" else Color("c4cdd1")))
				radar_objs.append({
					"pos": p["position"],
					"label": String(p.get("id", "")).to_upper(),
					"color": col
				})
		_tactical_radar.objectives = radar_objs
		if is_instance_valid(_compass_ribbon):
			_compass_ribbon.objectives = radar_objs
	if not is_instance_valid(objective_strip): return
	for index in objective_labels.size():
		var label := objective_labels[index]
		if index >= points.size() or not points[index] is Dictionary:
			label.text = "%s  ·  --" % char(65 + index)
			label.add_theme_color_override("font_color", Color("929da3"))
			continue
		var point: Dictionary = points[index]
		var code := String(point.get("id", char(65 + index))).to_upper()
		var owner := String(point.get("owner", ""))
		var progress := float(point.get("progress", 0.0))
		var contested := bool(point.get("contested", false))
		var team_color := Color("54b5ff") if owner == "A" else Color("ff6659") if owner == "B" else Color("c4cdd1")
		label.text = "%s  ·  %s%s" % [code, "CONTESTED" if contested else ("TEAM " + owner if not owner.is_empty() else "NEUTRAL"), "  %d%%" % roundi(progress * 100.0) if progress > 0.01 else ""]
		label.add_theme_color_override("font_color", Color("ffad61") if contested else team_color)

func configure_redeploy(available: bool) -> void:
	close_drone_editor()
	_redeploy_actions.visible = available
	_redeploy_seconds = -1
	update_redeploy(3, false)

func is_editing_drone() -> bool:
	return is_instance_valid(_drone_editor) and _drone_editor.visible

func close_drone_editor() -> void:
	if is_instance_valid(_drone_editor): _drone_editor.hide()

func _open_drone_editor() -> void:
	if not death_panel.visible or _redeploy_pending: return
	if not is_instance_valid(_drone_editor):
		_drone_editor = PanelContainer.new()
		_drone_editor.z_index = 12
		_drone_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_drone_editor.add_theme_stylebox_override("panel", WarUI.panel(WarUI.BACKGROUND, WarUI.LINE, 28))
		add_child(_drone_editor)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 16)
		_drone_editor.add_child(content)
		var title := _mk_label("REDEPLOYMENT", 27, WarUI.TEXT)
		content.add_child(title)
		_editor_preview = preload("res://scripts/ui/OperatorMenu.gd").new()
		_editor_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(_editor_preview)
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 12)
		actions.alignment = BoxContainer.ALIGNMENT_END
		content.add_child(actions)
		var back := Button.new()
		back.text = "BACK"
		back.pressed.connect(close_drone_editor)
		actions.add_child(back)
		_editor_deploy_button = Button.new()
		WarUI.primary(_editor_deploy_button)
		_editor_deploy_button.pressed.connect(func() -> void: redeploy_pressed.emit())
		actions.add_child(_editor_deploy_button)
		_drone_editor.theme = WarUI.theme()
	_drone_editor.show()
	_editor_preview.refresh()
	_update_redeploy_buttons()

func update_redeploy(seconds: int, pending: bool) -> void:
	if seconds == _redeploy_seconds and pending == _redeploy_pending: return
	_redeploy_seconds = seconds
	_redeploy_pending = pending
	respawn_label.text = "Deploying…" if pending else (
		("Ready to redeploy" if seconds == 0 else "Redeploy available in %ds" % seconds)
		if _redeploy_actions.visible else "Re-deploying in %ds…" % seconds)
	_update_redeploy_buttons()

func _update_redeploy_buttons() -> void:
	var text := "REDEPLOY  ·  %ds" % _redeploy_seconds if _redeploy_seconds > 0 else "REDEPLOY"
	for button in [_redeploy_button, _editor_deploy_button]:
		if not is_instance_valid(button): continue
		button.text = text
		button.disabled = _redeploy_seconds > 0 or _redeploy_pending

func set_dead(dead: bool, _secs: int) -> void:
	if not dead:
		close_drone_editor()
		_hurt_flash_t = 0.0
		if is_instance_valid(damage_overlay): damage_overlay.queue_redraw()
	death_panel.visible = dead
	if dead:
		for line in cross_lines: line.hide()
		if is_instance_valid(cross_dot): cross_dot.hide()

func _format_num(n: int) -> String:
	if n >= 1000000:
		return "%.2fM" % (float(n) / 1000000.0)
	elif n >= 1000:
		return "%.1fK" % (float(n) / 1000.0)
	return str(n)

func _refresh_scoreboard(players: Dictionary, me: String) -> void:
	for c in board_list.get_children():
		board_list.remove_child(c)
		c.queue_free()
	
	# Header Row
	var hdr := HBoxContainer.new()
	var h_op := _mk_label("PILOT", 11, Color(0.65, 0.7, 0.75))
	h_op.custom_minimum_size = Vector2(290, 0)
	hdr.add_child(h_op)
	var h_k := _mk_label("ELIMS", 11, Color(0.65, 0.7, 0.75))
	h_k.custom_minimum_size = Vector2(82, 0)
	hdr.add_child(h_k)
	var h_d := _mk_label("LOSSES", 11, Color(0.65, 0.7, 0.75))
	h_d.custom_minimum_size = Vector2(82, 0)
	hdr.add_child(h_d)
	var h_hp := _mk_label("HULL", 11, Color(0.65, 0.7, 0.75))
	h_hp.custom_minimum_size = Vector2(88, 0)
	hdr.add_child(h_hp)
	var h_tm := _mk_label("TEAM", 11, Color(0.65, 0.7, 0.75))
	hdr.add_child(h_tm)
	board_list.add_child(hdr)

	var rows: Array = []
	for pid in players.keys():
		var p_val = players[pid]
		var p: Dictionary = p_val.duplicate() if p_val is Dictionary else {}
		p["id"] = str(pid)
		rows.append(p)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("kills", 0)) > int(b.get("kills", 0)))

	for p in rows:
		var pid_str := String(p.get("id", ""))
		var nm := String(p.get("name", pid_str))
		if nm.is_empty() or nm == "?":
			nm = pid_str
		var is_me := (nm == me or pid_str == me)
		var kills: int = int(p.get("kills", 0))
		var deaths: int = int(p.get("deaths", 0))
		var health_val: int = int(p.get("health", 0))
		var team: String = String(p.get("team", "A"))

		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 32
		var col_txt := WarUI.ACCENT if is_me else WarUI.TEXT
		
		var l_op := _mk_label((" " if is_me else "  ") + nm, 14, col_txt)
		l_op.custom_minimum_size = Vector2(290, 0)
		row.add_child(l_op)
		
		var l_k := _mk_label(str(kills), 14, col_txt)
		l_k.custom_minimum_size = Vector2(82, 0)
		row.add_child(l_k)
		
		var l_d := _mk_label(str(deaths), 14, col_txt)
		l_d.custom_minimum_size = Vector2(82, 0)
		row.add_child(l_d)
		
		var l_hp := _mk_label(str(health_val) + "%", 14, WarUI.SUCCESS if health_val > 50 else (WarUI.ACCENT if health_val > 25 else WarUI.DANGER))
		l_hp.custom_minimum_size = Vector2(88, 0)
		row.add_child(l_hp)
		
		var l_tm := _mk_label("Team " + team, 13, Color(0.3, 0.7, 1.0) if team == "A" else Color(1.0, 0.4, 0.4))
		row.add_child(l_tm)
		
		board_list.add_child(row)

func _update_audit_telemetry() -> void:
	if not is_instance_valid(_audit_lbl_frame):
		return
	var fps := Engine.get_frames_per_second()
	var frame_ms := 1000.0 / maxf(float(fps), 1.0)
	var proc_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var objs := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var vram_mb := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0)
	
	var ram_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	var peak_ram_mb := Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / (1024.0 * 1024.0)
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	
	var phys_objs := int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
	var col_pairs := int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))
	
	# Status header with OS focus awareness
	var is_focused := DisplayServer.window_is_focused(0)
	if not is_focused:
		_audit_lbl_status.text = " AUDIT: WINDOW INACTIVE (macOS throttles background apps to ~20 FPS)"
		_audit_lbl_status.modulate = Color(1.0, 0.75, 0.2)
	elif fps >= 55:
		_audit_lbl_status.text = " AUDIT: 60Hz+ FLUID (%.1fms)" % frame_ms
		_audit_lbl_status.modulate = Color(0.25, 0.95, 0.45)
	else:
		_audit_lbl_status.text = " AUDIT: FRAME DROP DETECTED (%.1fms)" % frame_ms
		_audit_lbl_status.modulate = Color(1.0, 0.3, 0.3)
		
	_audit_lbl_frame.text = " FRAME DISPATCH & TIMINGS\n  Current FPS: %d FPS  |  Frame Delta: %.2f ms (Budget: 16.6ms)\n  Render CPU: %.2f ms  |  Physics Step: %.2f ms" % [fps, frame_ms, proc_ms, phys_ms]
	
	_audit_lbl_render.text = " GPU PIPELINE & GEOMETRY\n  Draw Calls: %d  (Budget <1500)  |  3D Meshes: %d\n  Triangles: %s  |  VRAM: %.1f MB" % [draw_calls, objs, _format_num(prims), vram_mb]
	
	_audit_lbl_memory.text = " MEMORY & SCENE GRAPH\n  Static RAM: %.1f MB  |  Peak: %.1f MB\n  Scene Nodes: %d" % [ram_mb, peak_ram_mb, nodes]
	
	_audit_lbl_physics.text = " SIMULATION & NETWORK\n  Active Bodies: %d  |  Collision Pairs: %d\n  Physics Target: 60 Hz  |  Net Ping: %d ms" % [phys_objs, col_pairs, _current_ping]
	
	# Bottleneck Reason Analysis
	var reasons: Array[String] = []
	if not is_focused:
		reasons.append("WINDOW UNFOCUSED (Click inside game window to unlock full 60Hz)")
	if draw_calls > 1500:
		reasons.append("HIGH DRAW CALLS (%d)" % draw_calls)
	if proc_ms > 12.0:
		reasons.append("SCRIPT CPU LOAD (%.1fms)" % proc_ms)
	if phys_ms > 10.0:
		reasons.append("PHYSICS BROADPHASE (%.1fms)" % phys_ms)
	if _current_ping > 90:
		reasons.append("HIGH NETWORK PING (%dms)" % _current_ping)
	if frame_ms > 16.6 and reasons.is_empty():
		reasons.append("GPU FILLRATE / SHADER BOUND")
		
	if reasons.is_empty():
		_audit_lbl_verdict.text = " AUDIT VERDICT: 60Hz+ FLUID (NO BOTTLENECK)"
		_audit_lbl_verdict.modulate = Color(0.3, 0.95, 0.4)
	else:
		_audit_lbl_verdict.text = " BOTTLENECK: " + " • ".join(reasons)
		_audit_lbl_verdict.modulate = Color(1.0, 0.45, 0.2)

func show_board(players: Dictionary, me: String) -> void:
	board_panel.visible = true
	_menu_scrim.visible = true
	_practice_bar.visible = GameState.practice_mode
	_update_bot_damage_btn()
	_refresh_scoreboard(players, me)
	_update_audit_telemetry()

func hide_board() -> void:
	board_panel.visible = false
	_menu_scrim.visible = pause_panel.visible
	scoreboard_closed.emit()

func is_board_visible() -> bool:
	return is_instance_valid(board_panel) and board_panel.visible

func _update_bot_damage_btn() -> void:
	if not is_instance_valid(_bot_damage_btn): return
	_bot_damage_btn.text = "Bot damage: on" if GameState.bot_damage_enabled else "Bot damage: off"
	_bot_damage_btn.add_theme_stylebox_override("normal", WarUI.panel(WarUI.RAISED, WarUI.LINE, 10))
	_bot_damage_btn.add_theme_color_override("font_color", WarUI.ACCENT if GameState.bot_damage_enabled else WarUI.MUTED)

func _update_pause_bot_btn() -> void:
	if not is_instance_valid(_pause_bot_btn): return
	_pause_bot_btn.text = "Practice bot damage: on" if GameState.bot_damage_enabled else "Practice bot damage: off"
	_pause_bot_btn.modulate = Color.WHITE

func set_paused(paused: bool) -> void:
	pause_panel.visible = paused
	_menu_scrim.visible = paused or board_panel.visible
	_pause_bot_btn.visible = GameState.practice_mode

func set_ping(ms: int) -> void:
	_current_ping = ms
	ping_label.text = ("PING %dms" % ms) if ms > 0 else ""

func _process(delta: float) -> void:
	update_player_header()
	_update_ability_card()
	if not death_panel.visible:
		var players := get_tree().get_nodes_in_group("local_player")
		if not players.is_empty() and is_instance_valid(players[0]):
			var lp = players[0]
			var lp_pos: Vector3 = lp.global_position
			var lp_yaw: float = lp.body_yaw if "body_yaw" in lp else lp.global_rotation.y
			if is_instance_valid(_tactical_radar):
				_tactical_radar.player_pos = lp_pos
				_tactical_radar.player_yaw = lp_yaw
				_tactical_radar.update_sweep(delta)
				var contacts: Array[Dictionary] = []
				for rem in get_tree().get_nodes_in_group("remote_players"):
					if is_instance_valid(rem) and not rem.get("dead"):
						contacts.append({
							"pos": rem.global_position,
							"friendly": rem._is_friendly() if rem.has_method("_is_friendly") else false
						})
				_tactical_radar.contacts = contacts
				_tactical_radar.queue_redraw()
			if is_instance_valid(_compass_ribbon):
				_compass_ribbon.player_pos = lp_pos
				_compass_ribbon.player_yaw = lp_yaw
				if is_instance_valid(_tactical_radar):
					_compass_ribbon.objectives = _tactical_radar.objectives
				_compass_ribbon.queue_redraw()
	equipment_label.text = "[G] HOLD AIM · RELEASE THROW\n%s ×%d" % [GameState.THROWABLES[GameState.selected_throwable]["name"], GameState.throwables_remaining]
	_controls_hint.visible = not death_panel.visible and (not is_instance_valid(_sensor_reticle) or not _sensor_reticle.visible)
	
	if _missile_lock_timer > 0.0:
		_missile_lock_timer -= delta
		if _missile_lock_timer <= 0.0:
			clear_missile_lock()
		elif is_instance_valid(_missile_alert_box):
			var pulse := sin(Time.get_ticks_msec() * 0.018) * 0.35 + 0.65
			_missile_alert_box.modulate.a = pulse
	
	# Real-time hardware and engine audit telemetry + live combat roster refresh while TAB is held
	if is_instance_valid(board_panel) and board_panel.visible:
		_audit_timer -= delta
		if _audit_timer <= 0.0:
			_audit_timer = 0.25
			_update_audit_telemetry()
			var scene = get_tree().current_scene
			if scene and scene.has_method("get_full_scoreboard_roster"):
				_refresh_scoreboard(scene.get_full_scoreboard_roster(), GameState.username)

	_fps_timer -= delta
	if _fps_timer <= 0.0:
		_fps_timer = 0.2
		var fps := Engine.get_frames_per_second()
		var ms := 1000.0 / maxf(float(fps), 1.0)
		if is_instance_valid(fps_label):
			fps_label.text = "%d FPS (%.1fms)" % [fps, ms]
			if fps >= 55:
				fps_label.modulate = Color(0.4, 0.95, 0.4)
			elif fps >= 30:
				fps_label.modulate = Color(1.0, 0.85, 0.3)
			else:
				fps_label.modulate = Color(1.0, 0.35, 0.3)

	if _hit_t > 0.0:
		_hit_t -= delta
		if _hit_t <= 0.0:
			hitmarker.modulate.a = 0.0
		else:
			hitmarker.scale = Vector2.ONE * hitmarker_scale
			
	var had_damage_feedback := _hurt_flash_t > 0.0 or not _damage_arcs.is_empty()
	_hurt_flash_t = maxf(0.0, _hurt_flash_t - delta)
	if had_damage_feedback and is_instance_valid(damage_overlay): damage_overlay.queue_redraw()

	# Update damage arc indicators
	var kept_arcs: Array = []
	for arc in _damage_arcs:
		arc["life"] = float(arc["life"]) - delta
		if float(arc["life"]) > 0.0:
			kept_arcs.append(arc)
	if kept_arcs.size() != _damage_arcs.size():
		_damage_arcs = kept_arcs
		if is_instance_valid(damage_overlay):
			damage_overlay.queue_redraw()
			
	# Low health vignette pulsing
	var hp := float(health_bar.value)
	var max_val := maxf(1.0, float(health_bar.max_value))
	var is_critical := (hp / max_val) <= 0.25 and hp > 0.0
	if is_critical:
		_low_hull_alarm_timer -= delta
		if _low_hull_alarm_timer <= 0.0:
			Audio.low_hull_alarm()
			_low_hull_alarm_timer = 2.4
	else:
		_low_hull_alarm_timer = 0.0
	if is_instance_valid(_hull_critical_label):
		_hull_critical_label.visible = is_critical
		if is_critical:
			_hull_critical_label.modulate.a = sin(Time.get_ticks_msec() * 0.008) * 0.4 + 0.6
	if hp < 35.0 and hp > 0.0:
		_low_hp_pulse += delta * 4.0
		low_hp_vignette.color.a = (sin(_low_hp_pulse) * 0.5 + 0.5) * 0.25 * (1.0 - hp / 35.0)
	else:
		low_hp_vignette.color.a = 0.0

func _update_ability_card() -> void:
	if not is_instance_valid(_ability_name_label) or not is_instance_valid(_ability_status_label):
		return
	var players := get_tree().get_nodes_in_group("local_player")
	if players.is_empty() or not is_instance_valid(players[0]):
		return
	var lp = players[0]
	var chassis: String = GameState.selected_drone_chassis
	match chassis:
		"tracked": _ability_name_label.text = "[F/C] SMOKE SCREEN"
		"wheels": _ability_name_label.text = "[F] NITRO / [C] SMOKE"
		"heli": _ability_name_label.text = "[F] FLARE DECOY"
		"wing": _ability_name_label.text = "[F] AIRBRAKE"
		_: _ability_name_label.text = "[F] RECON PULSE"

	var cd: float = lp.get("ability_cooldown") if "ability_cooldown" in lp else 0.0
	var active_t: float = lp.get("ability_active_timer") if "ability_active_timer" in lp else 0.0
	var max_cd: float = lp.get("ABILITY_COOLDOWN_MAX") if "ABILITY_COOLDOWN_MAX" in lp else 10.0

	if active_t > 0.0:
		_ability_status_label.text = "ACTIVE %.1fs" % active_t
		_ability_status_label.add_theme_color_override("font_color", Color("ffaa33"))
		if is_instance_valid(_ability_bar):
			_ability_bar.value = active_t / 3.0
	elif cd > 0.0:
		_ability_status_label.text = "%.1fs" % cd
		_ability_status_label.add_theme_color_override("font_color", WarUI.MUTED)
		if is_instance_valid(_ability_bar):
			_ability_bar.value = 1.0 - (cd / maxf(max_cd, 0.001))
	else:
		_ability_status_label.text = "READY"
		_ability_status_label.add_theme_color_override("font_color", WarUI.CYAN)
		if is_instance_valid(_ability_bar):
			_ability_bar.value = 1.0

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		fps_label.visible = not fps_label.visible
