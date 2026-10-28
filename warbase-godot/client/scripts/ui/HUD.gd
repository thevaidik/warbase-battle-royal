class_name WarHUD
extends CanvasLayer
## AAA In-game Tactical HUD.
## Ported from Babylon GUI overlays + SwiftUI HUDView with best Godot 4.3+ practices:
## Custom-drawn military sniper reticle, directional damage indicators, pulsing low-health vignette,
## dynamic crosshairs, animated hitmarkers, killfeed, responsive scoreboard, and pause settings.

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
var ammo_label: Label
var equipment_label: Label
var weapon_label: Label
var killfeed_box: VBoxContainer
var score_label: Label
var scope_overlay: Control
var death_panel: PanelContainer
var death_label: Label
var respawn_label: Label
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
var reload_label: Label
var optic_label: Label
var player_header_label: Label
var match_info_label: Label
var low_hp_vignette: ColorRect
var damage_overlay: Control

var vehicle_prompt_panel: PanelContainer
var vehicle_hud_panel: PanelContainer
var _veh_speed_label: Label
var _veh_gear_label: Label
var _veh_armor_label: Label
var _veh_armor_bar: ProgressBar
var _veh_prompt_label: Label

var _hit_t := 0.0
var _feed: Array = []
var _damage_arcs: Array = []
var _damage_blood: Array = []
const BloodTexture = preload("res://scripts/weapons/BloodTexture.gd")
var _hurt_flash_t := 0.0
var _low_hp_pulse := 0.0
var _fps_timer := 0.0

class ScopeReticle extends Control:
	var is_steady := false
	var stamina := 1.0
	var compass_deg := 0.0
	var magnification := 4
	var field_of_view := 22.0
	var sniper := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		get_viewport().size_changed.connect(queue_redraw)

	func _draw() -> void:
		var vp := get_viewport_rect().size
		var center := vp * 0.5
		var unit := clampf(vp.y / 720.0, 0.75, 2.0)
		var accent := Color(0.95, 0.25, 0.16, 0.95)
		if magnification <= 2:
			# The physical sight supplies its housing; a small collimated dot stays on the shot axis.
			draw_circle(center, 3.0 * unit, Color(0.0, 0.0, 0.0, 0.6))
			draw_circle(center, 1.35 * unit, accent)
			return
		var radius := minf(vp.x, vp.y) * 0.43
		# A continuous circular aperture, including all four corners of the screen.
		var outside := vp.length()
		for i in 128:
			var v0 := Vector2.from_angle(TAU * float(i) / 128.0)
			var v1 := Vector2.from_angle(TAU * float(i + 1) / 128.0)
			draw_colored_polygon(PackedVector2Array([center + v0 * radius, center + v0 * outside, center + v1 * outside, center + v1 * radius]), Color(0.015, 0.018, 0.022))
		draw_arc(center, radius, 0.0, TAU, 128, Color(0.09, 0.10, 0.12), 7.0 * unit, true)
		for i in 10:
			draw_arc(center, radius - float(i) * 2.0 * unit, 0.0, TAU, 128, Color(0, 0, 0, 0.22 * (1.0 - float(i) / 10.0)), 2.5 * unit, true)
		var ink := Color(0.025, 0.028, 0.03, 0.95)
		var gap := 5.0 * unit
		for axis in [Vector2.RIGHT, Vector2.DOWN]:
			for sign_value in [-1.0, 1.0]:
				draw_line(center + axis * gap * sign_value, center + axis * (radius - 18.0 * unit) * sign_value, Color(1, 1, 1, 0.30), 2.2 * unit, true)
				draw_line(center + axis * gap * sign_value, center + axis * (radius - 18.0 * unit) * sign_value, ink, 1.0 * unit, true)
		# Angular marks: each short division is 2 mrad, independent of resolution and zoom.
		var mil := vp.y * 0.001 / (2.0 * tan(deg_to_rad(field_of_view) * 0.5))
		for i in range(-12, 13):
			if i == 0 or absf(float(i * 2) * mil) >= radius - 24.0 * unit:
				continue
			var tick := (4.5 if i % 5 == 0 else 2.0) * unit
			for axis in [Vector2.RIGHT, Vector2.DOWN]:
				var at: Vector2 = center + axis * float(i * 2) * mil
				var normal := Vector2(-axis.y, axis.x)
				draw_line(at - normal * tick, at + normal * tick, ink, 1.0 * unit, true)
		draw_circle(center, 1.4 * unit, accent)
		var font := ThemeDB.fallback_font
		var caption := "%d×  •  [V] ZOOM" % magnification
		var caption_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * unit))
		draw_string(font, Vector2(center.x - caption_size.x * 0.5, center.y + radius + 29.0 * unit), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * unit), Color(0.72, 0.77, 0.80))
		if sniper:
			var bar := Rect2(center + Vector2(-70.0, radius - 38.0) * unit, Vector2(140.0, 3.0) * unit)
			draw_rect(bar, Color(0.08, 0.10, 0.12, 0.65))
			bar.size.x *= clampf(stamina, 0.0, 1.0)
			draw_rect(bar, Color(0.42, 0.8, 0.66) if is_steady else Color(0.68, 0.72, 0.75))
			var hint := "STEADY" if is_steady else "[SHIFT] STEADY AIM"
			draw_string(font, center + Vector2(-65, radius - 48) * unit, hint, HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * unit), Color(0.7, 0.75, 0.78))

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
			draw_rect(Rect2(Vector2.ZERO, vp), Color(0.45, 0.005, 0.002, flash * 0.07))
		for stain in hud_ref._damage_blood:
			var extent: Vector2 = Vector2.ONE * float(stain.radius) * minf(vp.x,vp.y) * 3.0
			draw_texture_rect(BloodTexture.get_texture(), Rect2(stain.position * vp - extent * 0.5, extent), false, Color(0.35, 0.005, 0.004, minf(1.0, stain.life) * stain.opacity))
		var center := vp * 0.5
		var radius := minf(vp.x, vp.y) * 0.38
		for arc in hud_ref._damage_arcs:
			var ang: float = float(arc["angle"])
			var alpha: float = float(arc["life"]) / 1.5
			var col := Color(0.9, 0.15, 0.15, clampf(alpha, 0.0, 0.8))
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
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func build() -> void:
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
	low_hp_vignette.color = Color(0.7, 0.0, 0.0, 0.0)
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
	hitmarker = _mk_label("X", 28, Color.WHITE)
	hitmarker.set_anchors_preset(Control.PRESET_CENTER)
	hitmarker.position = Vector2(-12, -24)
	hitmarker.modulate.a = 0.0
	hitmarker.z_index = 3
	hitmarker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hitmarker)
	
	# Restrained combat panels remain legible over bright and dark environments.

	var health_card := PanelContainer.new()
	health_card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	health_card.position = Vector2(28, -122)
	health_card.custom_minimum_size = Vector2(210, 94)
	health_card.z_index = 2
	health_card.add_theme_stylebox_override("panel", WarUI.panel(Color(0.035, 0.055, 0.065, 0.88), WarUI.LINE, 14))
	add_child(health_card)
	var hb := VBoxContainer.new()
	hb.z_index = 2
	hb.add_theme_constant_override("separation", 4)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_card.add_child(hb)
	hb.add_child(_mk_label("VITALS / HEALTH", 11, WarUI.MUTED))
	
	health_label = _mk_label("100", 30, Color.WHITE)
	hb.add_child(health_label)
	
	health_bar = ProgressBar.new()
	health_bar.min_value = 0
	health_bar.max_value = 100
	health_bar.value = 100
	health_bar.custom_minimum_size = Vector2(180, 4)
	health_bar.show_percentage = false
	hb.add_child(health_bar)
	
	# Tactical Bottom-Right HUD: Weapon & Ammo
	var ammo_card := PanelContainer.new()
	ammo_card.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_card.position = Vector2(-284, -150)
	ammo_card.custom_minimum_size = Vector2(256, 122)
	ammo_card.z_index = 2
	ammo_card.add_theme_stylebox_override("panel", WarUI.panel(Color(0.035, 0.055, 0.065, 0.88), WarUI.LINE, 14))
	add_child(ammo_card)
	var ab := VBoxContainer.new()
	ab.z_index = 2
	ab.add_theme_constant_override("separation", 2)
	ab.alignment = BoxContainer.ALIGNMENT_END
	ab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_card.add_child(ab)
	
	equipment_label = _mk_label("", 11, WarUI.ACCENT)
	ab.add_child(equipment_label)
	weapon_label = _mk_label("AK-47", 15, WarUI.MUTED)
	ab.add_child(weapon_label)
	
	ammo_label = _mk_label("30 / 30", 34, Color.WHITE)
	ab.add_child(ammo_label)
	
	reload_label = _mk_label("RELOADING...", 14, Color.YELLOW)
	reload_label.visible = false
	ab.add_child(reload_label)
	
	ping_label = _mk_label("", 12, Color(0.65, 0.65, 0.65))
	ab.add_child(ping_label)
	
	fps_label = _mk_label("", 11, WarUI.MUTED)
	fps_label.visible = false
	ab.add_child(fps_label)
	
	optic_label = _mk_label("[V] 2X OPTIC  /  [R] RELOAD", 11, WarUI.ACCENT)
	ab.add_child(optic_label)
	
	var identity := PanelContainer.new()
	identity.position = Vector2(28, 24)
	identity.add_theme_stylebox_override("panel", WarUI.panel(Color(0.035, 0.055, 0.065, 0.82), WarUI.LINE, 12))
	add_child(identity)
	var identity_column := VBoxContainer.new()
	identity_column.add_theme_constant_override("separation", 4)
	identity.add_child(identity_column)
	player_header_label = _mk_label(GameState.username, 14, WarUI.TEXT)
	identity_column.add_child(player_header_label)
	match_info_label = _mk_label("OFFLINE PRACTICE", 11, WarUI.ACCENT)
	identity_column.add_child(match_info_label)
	var score_position := CenterContainer.new()
	score_position.set_anchors_preset(Control.PRESET_TOP_WIDE)
	score_position.offset_top = 24
	add_child(score_position)
	score_label = _mk_label("", 19, WarUI.TEXT)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_position.add_child(score_label)
	killfeed_box = VBoxContainer.new()
	killfeed_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	killfeed_box.position = Vector2(-448, 28)
	killfeed_box.custom_minimum_size = Vector2(420, 110)
	killfeed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	killfeed_box.add_theme_constant_override("separation", 6)
	add_child(killfeed_box)
	_controls_hint = _mk_label("WASD  MOVE    RMB  AIM    R  RELOAD    WHEEL / 1–2  WEAPONS    TAB  SCORE", 11, Color(0.8, 0.85, 0.83, 0.65))
	_controls_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_controls_hint.position = Vector2(-250, -34)
	_controls_hint.custom_minimum_size.x = 500
	_controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_controls_hint)
	# High-Fidelity Custom Sniper Scope Overlay
	scope_overlay = ScopeReticle.new()
	scope_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope_overlay.visible = false
	add_child(scope_overlay)
	
	# Death Screen
	death_panel = PanelContainer.new()
	death_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_panel.visible = false
	add_child(death_panel)
	
	var dv := VBoxContainer.new()
	dv.alignment = BoxContainer.ALIGNMENT_CENTER
	death_panel.add_child(dv)
	
	death_label = _mk_label("OPERATOR DOWN", 48, Color(0.95, 0.2, 0.2))
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dv.add_child(death_label)
	
	respawn_label = _mk_label("Re-deploying in 3s...", 18, Color(0.8, 0.8, 0.8))
	respawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dv.add_child(respawn_label)
	
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
	
	var pv := VBoxContainer.new()
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.add_theme_constant_override("separation", 10)
	pause_panel.add_child(pv)
	
	var pt := _mk_label("PAUSED", 26, Color.WHITE)
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
			feed(" Peaceful Mode: Bot Damage OFF — Walk in Peace!", Color(0.3, 0.95, 0.4))
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
			feed(" Peaceful Mode: Bot Damage OFF — Walk & Drive in Peace!", Color(0.3, 0.95, 0.4))
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

	var sc_title := _mk_label("OPERATORS", 12, Color(0.7, 0.82, 0.95))
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
	# 1. Proximity Enter Prompt (Centered lower-mid screen)
	var prompt_ctr := CenterContainer.new()
	prompt_ctr.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_ctr.position = Vector2(-250, -210)
	prompt_ctr.custom_minimum_size = Vector2(500, 50)
	prompt_ctr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt_ctr)

	vehicle_prompt_panel = PanelContainer.new()
	var vp_style := StyleBoxFlat.new()
	vp_style.bg_color = Color(0.05, 0.07, 0.10, 0.88)
	vp_style.border_color = Color(0.25, 0.85, 1.0, 0.9)
	vp_style.set_border_width_all(2)
	vp_style.set_corner_radius_all(6)
	vp_style.content_margin_left = 18
	vp_style.content_margin_right = 18
	vp_style.content_margin_top = 8
	vp_style.content_margin_bottom = 8
	vehicle_prompt_panel.add_theme_stylebox_override("panel", vp_style)
	vehicle_prompt_panel.visible = false
	prompt_ctr.add_child(vehicle_prompt_panel)

	_veh_prompt_label = _mk_label(" PRESS [E] TO DRIVE COMBAT JEEP ", 14, Color(0.3, 0.95, 1.0))
	vehicle_prompt_panel.add_child(_veh_prompt_label)

	# 2. In-Vehicle Speedometer & Turret Dashboard (Bottom Center)
	var vhud_ctr := CenterContainer.new()
	vhud_ctr.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	vhud_ctr.position = Vector2(-320, -118)
	vhud_ctr.custom_minimum_size = Vector2(640, 100)
	vhud_ctr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vhud_ctr)

	vehicle_hud_panel = PanelContainer.new()
	var vh_style := StyleBoxFlat.new()
	vh_style.bg_color = Color(0.04, 0.05, 0.07, 0.92)
	vh_style.border_color = Color(0.25, 0.55, 0.95, 0.8)
	vh_style.set_border_width_all(2)
	vh_style.set_corner_radius_all(8)
	vh_style.content_margin_left = 22
	vh_style.content_margin_right = 22
	vh_style.content_margin_top = 10
	vh_style.content_margin_bottom = 10
	vehicle_hud_panel.add_theme_stylebox_override("panel", vh_style)
	vehicle_hud_panel.visible = false
	vhud_ctr.add_child(vehicle_hud_panel)

	var vh_box := VBoxContainer.new()
	vh_box.add_theme_constant_override("separation", 6)
	vehicle_hud_panel.add_child(vh_box)

	var vh_row := HBoxContainer.new()
	vh_row.add_theme_constant_override("separation", 24)
	vh_box.add_child(vh_row)

	# Left: Speed & Transmission
	var spd_box := VBoxContainer.new()
	spd_box.add_theme_constant_override("separation", 2)
	vh_row.add_child(spd_box)

	_veh_speed_label = _mk_label("0 KM/H", 26, Color(0.35, 0.95, 1.0))
	spd_box.add_child(_veh_speed_label)

	_veh_gear_label = _mk_label("GEAR: 1", 12, Color(0.7, 0.85, 0.95))
	spd_box.add_child(_veh_gear_label)

	# Center: Armor Gauge & Turret Status
	var arm_box := VBoxContainer.new()
	arm_box.custom_minimum_size = Vector2(260, 0)
	arm_box.add_theme_constant_override("separation", 4)
	vh_row.add_child(arm_box)

	_veh_armor_label = _mk_label("ARMOR: 800 / 800", 13, Color(0.35, 1.0, 0.5))
	arm_box.add_child(_veh_armor_label)

	_veh_armor_bar = ProgressBar.new()
	_veh_armor_bar.min_value = 0.0
	_veh_armor_bar.max_value = 800.0
	_veh_armor_bar.value = 800.0
	_veh_armor_bar.custom_minimum_size = Vector2(260, 8)
	_veh_armor_bar.show_percentage = false
	arm_box.add_child(_veh_armor_bar)

	var turr_lbl := _mk_label("ARMORED TRANSPORT  •  [E] EXIT", 11, Color(1.0, 0.85, 0.2))
	arm_box.add_child(turr_lbl)

	# Bottom hint line
	var ctrl_hint := _mk_label("[W/S] DRIVE/BRAKE  •  [1] GEAR 1 (CLIMB)  •  [2] GEAR 2 (SPEED)  •  [SPACE] DRIFT  •  [C] VIEW  •  [E] EXIT", 10, Color(0.65, 0.72, 0.8))
	ctrl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vh_box.add_child(ctrl_hint)

func show_damage_blood(amount: float) -> void:
	_hurt_flash_t = 0.28
	for i in 5:
		var left := randf() > 0.5
		var position := Vector2(randf_range(0.01, 0.12) if left else randf_range(0.88, 0.99), randf_range(0.1, 0.9))
		var radius := randf_range(0.02, 0.04) * clampf(amount / 25.0, 0.7, 1.5)
		_damage_blood.append({"position":position,"radius":radius,"life":1.8,"opacity":randf_range(0.25,0.45)})
	while _damage_blood.size() > 20: _damage_blood.pop_front()
	if is_instance_valid(damage_overlay): damage_overlay.queue_redraw()

func add_damage_indicator(rel_dir: Vector3) -> void:
	# Calculate 2D screen angle for incoming fire
	var angle := atan2(rel_dir.x, -rel_dir.z) - PI / 2.0
	_damage_arcs.append({"angle": angle, "life": 1.5})
	if is_instance_valid(damage_overlay):
		damage_overlay.queue_redraw()

func set_crosshair(spread_px: float, ads: float) -> void:
	var gap: float = 6.0 + spread_px * 2.5
	gap *= (1.0 - ads * 0.7)
	cross_lines[0].position = Vector2(-1, -gap - 10)
	cross_lines[1].position = Vector2(-1, gap)
	cross_lines[2].position = Vector2(-gap - 10, -1)
	cross_lines[3].position = Vector2(gap, -1)
	# Smoothly fade out hipfire crosshair as weapon raises to sight (zero pop)
	var alpha := clampf(1.0 - ads * 2.2, 0.0, 1.0)
	var vis := alpha > 0.01
	for l in cross_lines:
		l.visible = vis
		l.modulate.a = alpha
	if cross_dot:
		cross_dot.visible = vis
		cross_dot.modulate.a = alpha

func flash_hitmarker(kill: bool, is_headshot: bool = false) -> void:
	hitmarker.text = "KILL" if kill else ("X" if not is_headshot else "+")
	hitmarker.modulate = Color(1.0, 0.2, 0.2) if (kill or is_headshot) else Color.WHITE
	hitmarker.modulate.a = 1.0
	_hit_t = 0.35 if kill else 0.18

func set_health(h: int) -> void:
	health_label.text = str(h)
	health_bar.value = h
	health_label.add_theme_color_override("font_color", Color.WHITE if h > 30 else Color(1.0, 0.3, 0.3))

func set_ammo(a: int, mag: int, wname: String, reloading: bool) -> void:
	ammo_label.text = "%02d / %02d" % [a, mag]
	ammo_label.add_theme_color_override("font_color", WarUI.DANGER if a == 0 else (WarUI.ACCENT if a <= mag / 4 else WarUI.TEXT))
	weapon_label.text = wname
	reload_label.visible = reloading

func update_player_header(p_name: String = "", team: String = "", mode: String = "") -> void:
	if is_instance_valid(player_header_label):
		var nm := p_name if not p_name.is_empty() else GameState.username
		player_header_label.text = nm.to_upper()
	if is_instance_valid(match_info_label):
		var tm := team if not team.is_empty() else GameState.local_team
		var md := mode if not mode.is_empty() else GameState.selected_mode
		match_info_label.text = ("OFFLINE" if GameState.practice_mode else ("%s / %s" % [md, tm])) + "  •  " + GameState.time_label(GameState.selected_time)

func set_vehicle_prompt(vis: bool, text: String = " PRESS [E] TO DRIVE COMBAT JEEP ") -> void:
	if is_instance_valid(vehicle_prompt_panel):
		vehicle_prompt_panel.visible = vis
	if is_instance_valid(_veh_prompt_label):
		_veh_prompt_label.text = text

func set_vehicle_active(active: bool) -> void:
	if is_instance_valid(vehicle_hud_panel):
		vehicle_hud_panel.visible = active

func set_vehicle_stats(speed_kmh: float, gear: int, armor: float, max_armor: float, is_rev: bool) -> void:
	if not is_instance_valid(vehicle_hud_panel):
		return
	if is_instance_valid(_veh_speed_label):
		_veh_speed_label.text = "%3.0f KM/H" % absf(speed_kmh)
	if is_instance_valid(_veh_gear_label):
		if is_rev:
			_veh_gear_label.text = "GEAR: R"
			_veh_gear_label.modulate = Color(1.0, 0.4, 0.3)
		elif speed_kmh < 1.0:
			_veh_gear_label.text = "GEAR: N [G%d]" % gear
			_veh_gear_label.modulate = Color(0.8, 0.8, 0.8)
		elif gear == 1:
			_veh_gear_label.text = "GEAR: 1 [CLIMB]"
			_veh_gear_label.modulate = Color(1.0, 0.85, 0.2)
		elif gear == 2:
			_veh_gear_label.text = "GEAR: 2 [SPEED]"
			_veh_gear_label.modulate = Color(0.25, 0.95, 1.0)
	if is_instance_valid(_veh_armor_bar):
		_veh_armor_bar.max_value = max_armor
		_veh_armor_bar.value = armor
	if is_instance_valid(_veh_armor_label):
		_veh_armor_label.text = "ARMOR: %d / %d" % [int(armor), int(max_armor)]
		if armor < 250.0:
			_veh_armor_label.modulate = Color(1.0, 0.25, 0.25)
		elif armor < 500.0:
			_veh_armor_label.modulate = Color(1.0, 0.8, 0.2)
		else:
			_veh_armor_label.modulate = Color(0.35, 1.0, 0.5)

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

func set_score(mode: String, a: int, b: int, team: String, winner: String) -> void:
	if mode == "TDM":
		score_label.text = "TEAM A %d  •  %d TEAM B   [You: Team %s]%s" % [a, b, team, ("    WINNER: " + winner) if not winner.is_empty() else ""]
	else:
		score_label.text = "" if winner.is_empty() else (" WINNER: " + winner)

func set_scope(on: bool, weight: float = 1.0) -> void:
	var vis := on and weight > 0.005
	scope_overlay.visible = vis
	scope_overlay.modulate.a = clampf(weight, 0.0, 1.0)

func set_scope_magnification(mag: int, reflex: bool = false) -> void:
	if scope_overlay is ScopeReticle:
		var sr := scope_overlay as ScopeReticle
		if sr.magnification != mag:
			sr.magnification = mag
			sr.queue_redraw()
	if is_instance_valid(optic_label):
		optic_label.text = "[V] %dX OPTIC  /  [R] RELOAD" % mag if mag > 1 else ("1X REFLEX  /  [R] RELOAD" if reflex else "IRON SIGHTS  /  [R] RELOAD")

func update_scope_steady(steady: bool, stam: float, heading: float) -> void:
	if scope_overlay is ScopeReticle:
		var sr := scope_overlay as ScopeReticle
		sr.is_steady = steady
		sr.stamina = stam
		sr.compass_deg = heading
		sr.queue_redraw()

func set_dead(dead: bool, secs: int) -> void:
	if not dead:
		_damage_blood.clear()
		_hurt_flash_t = 0.0
		if is_instance_valid(damage_overlay): damage_overlay.queue_redraw()
	death_panel.visible = dead
	if dead:
		respawn_label.text = "Re-deploying in %ds..." % secs

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
	var h_op := _mk_label("OPERATOR", 11, Color(0.65, 0.7, 0.75))
	h_op.custom_minimum_size = Vector2(290, 0)
	hdr.add_child(h_op)
	var h_k := _mk_label("ELIMS", 11, Color(0.65, 0.7, 0.75))
	h_k.custom_minimum_size = Vector2(82, 0)
	hdr.add_child(h_k)
	var h_d := _mk_label("DEATHS", 11, Color(0.65, 0.7, 0.75))
	h_d.custom_minimum_size = Vector2(82, 0)
	hdr.add_child(h_d)
	var h_hp := _mk_label("HEALTH", 11, Color(0.65, 0.7, 0.75))
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
	equipment_label.text = "[G] HOLD AIM · RELEASE THROW\n%s ×%d" % [GameState.THROWABLES[GameState.selected_throwable]["name"], GameState.throwables_remaining]
	_controls_hint.visible = not scope_overlay.visible
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
			
	var had_damage_feedback := _hurt_flash_t > 0.0 or not _damage_blood.is_empty() or not _damage_arcs.is_empty()
	_hurt_flash_t = maxf(0.0, _hurt_flash_t - delta)
	for stain in _damage_blood: stain.life -= delta
	_damage_blood = _damage_blood.filter(func(stain: Dictionary) -> bool: return stain.life > 0)
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
	if hp < 35.0 and hp > 0.0:
		_low_hp_pulse += delta * 4.0
		low_hp_vignette.color.a = (sin(_low_hp_pulse) * 0.5 + 0.5) * 0.25 * (1.0 - hp / 35.0)
	else:
		low_hp_vignette.color.a = 0.0

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		fps_label.visible = not fps_label.visible
