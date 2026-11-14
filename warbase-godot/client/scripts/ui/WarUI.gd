class_name WarUI
extends RefCounted
## Shared visual language for lobby, combat HUD, and overlays.
## Provides dark-mode Neumorphic soft UI styling with tactile depths, bevels, and pill geometry.

const BACKGROUND := Color("090d12")
const PANEL := Color("11171f")
const RAISED := Color("161e27")
const HOVER := Color("1c2632")
const INSET := Color("0a0e13")
const LINE := Color("23303d")
const TEXT := Color("eef3e9")
const MUTED := Color("8fa2aa")
const ACCENT := Color("c6ff5a")
const CYAN := Color("69dce7")
const SUCCESS := Color("8ce7ba")
const DANGER := Color("ff7665")
const DISPLAY_FONT = preload("res://assets/fonts/Rajdhani-SemiBold.ttf")
const FRAME = preload("res://scripts/ui/WarUIFrame.gd")

static var _theme: Theme

static func panel(background: Color = PANEL, border: Color = LINE, padding: int = 0, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style

static func neumorphic_style(state: String = "normal", radius: int = 14, is_primary: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(12)
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	
	if is_primary:
		match state:
			"normal":
				style.bg_color = Color("142827")
				style.border_color = CYAN
				style.set_border_width_all(2)
				style.border_blend = false
				style.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
				style.shadow_size = 10
				style.shadow_offset = Vector2(2, 4)
			"hover":
				style.bg_color = Color("1a3837")
				style.border_color = ACCENT
				style.set_border_width_all(2)
				style.border_blend = false
				style.shadow_color = Color(0.41, 0.9, 0.72, 0.35)
				style.shadow_size = 14
				style.shadow_offset = Vector2(0, 4)
			"pressed":
				style.bg_color = Color("0d1d1d")
				style.border_color = Color("3db078")
				style.set_border_width_all(2)
				style.border_blend = false
				style.shadow_color = Color(0, 0, 0, 0)
				style.shadow_size = 0
				style.content_margin_top = 12
				style.content_margin_bottom = 8
			_:
				style.bg_color = Color("0e1819")
				style.border_color = Color("1b3333")
				style.set_border_width_all(1)
		return style

	match state:
		"normal":
			style.bg_color = RAISED
			style.border_width_top = 2
			style.border_width_left = 2
			style.border_width_bottom = 1
			style.border_width_right = 1
			style.border_color = Color(1.0, 1.0, 1.0, 0.08)
			style.border_blend = true
			style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
			style.shadow_size = 8
			style.shadow_offset = Vector2(3, 4)
		"hover":
			style.bg_color = HOVER
			style.border_width_top = 2
			style.border_width_left = 2
			style.border_width_bottom = 1
			style.border_width_right = 1
			style.border_color = Color(0.41, 0.86, 0.9, 0.4)
			style.border_blend = true
			style.shadow_color = Color(0.0, 0.0, 0.0, 0.75)
			style.shadow_size = 12
			style.shadow_offset = Vector2(0, 5)
		"pressed":
			# Inset depressed state
			style.bg_color = INSET
			style.border_width_top = 2
			style.border_width_left = 2
			style.border_width_bottom = 1
			style.border_width_right = 1
			style.border_color = Color(0.0, 0.0, 0.0, 0.85)
			style.border_blend = true
			style.shadow_color = Color(0, 0, 0, 0)
			style.shadow_size = 0
			style.content_margin_top = 14
			style.content_margin_bottom = 8
		"disabled":
			style.bg_color = Color("0d1117")
			style.border_color = Color(0.2, 0.25, 0.3, 0.3)
			style.set_border_width_all(1)
			style.shadow_size = 0
		"focus":
			style.bg_color = HOVER
			style.set_border_width_all(2)
			style.border_color = CYAN
			style.border_blend = false
			style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
			style.shadow_size = 8
			style.shadow_offset = Vector2(0, 3)
	return style

static func neumorphic_panel(background: Color = PANEL, radius: int = 16, recessed: bool = false, border: Color = LINE) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(radius)
	if recessed:
		style.bg_color = INSET
		style.border_width_top = 2
		style.border_width_left = 2
		style.border_width_bottom = 1
		style.border_width_right = 1
		style.border_color = Color(0.0, 0.0, 0.0, 0.8)
		style.border_blend = true
		style.shadow_size = 0
	else:
		style.bg_color = background
		style.border_width_top = 2
		style.border_width_left = 2
		style.border_width_bottom = 1
		style.border_width_right = 1
		style.border_color = Color(1.0, 1.0, 1.0, 0.07)
		style.border_blend = true
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
		style.shadow_size = 14
		style.shadow_offset = Vector2(3, 5)
	return style

static func neumorphic_button(button: Button, is_primary: bool = false, radius: int = 14) -> void:
	button.add_theme_font_override("font", DISPLAY_FONT)
	button.add_theme_font_size_override("font_size", 20 if not is_primary else 22)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(st, neumorphic_style(st, radius, is_primary))
	button.add_theme_color_override("font_color", Color("f0f5fa") if is_primary else TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", CYAN if not is_primary else ACCENT)
	button.add_theme_color_override("font_disabled_color", MUTED.darkened(0.4))

static func neumorphic_tab(button: Button, is_active: bool, radius: int = 16) -> void:
	button.add_theme_font_override("font", DISPLAY_FONT)
	button.add_theme_font_size_override("font_size", 18)
	if is_active:
		var active_style := neumorphic_style("pressed", radius)
		active_style.border_color = CYAN
		active_style.border_width_left = 3
		button.add_theme_stylebox_override("normal", active_style)
		button.add_theme_stylebox_override("hover", active_style)
		button.add_theme_color_override("font_color", CYAN)
	else:
		button.add_theme_stylebox_override("normal", neumorphic_style("normal", radius))
		button.add_theme_stylebox_override("hover", neumorphic_style("hover", radius))
		button.add_theme_color_override("font_color", MUTED)
	button.add_theme_stylebox_override("pressed", neumorphic_style("pressed", radius))

static func neumorphic_chassis_button(button: Button, is_selected: bool, radius: int = 12) -> void:
	button.add_theme_font_override("font", DISPLAY_FONT)
	button.add_theme_font_size_override("font_size", 16)
	if is_selected:
		var sel_style := neumorphic_style("pressed", radius)
		sel_style.border_color = ACCENT
		sel_style.set_border_width_all(2)
		button.add_theme_stylebox_override("normal", sel_style)
		button.add_theme_stylebox_override("hover", sel_style)
		button.add_theme_color_override("font_color", ACCENT)
	else:
		button.add_theme_stylebox_override("normal", neumorphic_style("normal", radius))
		button.add_theme_stylebox_override("hover", neumorphic_style("hover", radius))
		button.add_theme_color_override("font_color", MUTED)
	button.add_theme_stylebox_override("pressed", neumorphic_style("pressed", radius))

static func theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	_theme.default_font = DISPLAY_FONT
	_theme.default_font_size = 15
	_theme.set_font("font", "Button", DISPLAY_FONT)
	_theme.set_font_size("font_size", "Button", 19)
	_theme.set_color("font_color", "LineEdit", TEXT)
	_theme.set_color("caret_color", "LineEdit", ACCENT)
	_theme.set_color("selection_color", "LineEdit", Color("3c5843"))
	_theme.set_color("font_color", "Label", TEXT)
	
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		_theme.set_stylebox(state, "Button", neumorphic_style(state, 14))
		_theme.set_color("font_" + state + "_color", "Button", TEXT if state != "disabled" else MUTED.darkened(0.3))
	_theme.set_color("font_hover_color", "Button", Color.WHITE)
	_theme.set_color("font_pressed_color", "Button", CYAN)
	_theme.set_color("font_color", "Button", TEXT)
	
	# Inset neumorphic well for LineEdit
	var line_normal := neumorphic_panel(INSET, 12, true)
	line_normal.set_content_margin_all(10)
	var line_focus := neumorphic_panel(INSET, 12, true)
	line_focus.border_color = CYAN
	line_focus.set_border_width_all(2)
	line_focus.set_content_margin_all(10)
	_theme.set_stylebox("normal", "LineEdit", line_normal)
	_theme.set_stylebox("focus", "LineEdit", line_focus)
	
	var track := panel(Color("1e2a36"), Color("1e2a36"), 0, 4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	_theme.set_stylebox("slider", "HSlider", track)
	_theme.set_stylebox("grabber_area", "HSlider", panel(ACCENT, ACCENT, 0, 4))
	_theme.set_stylebox("grabber_area_highlight", "HSlider", panel(ACCENT.lightened(0.15), ACCENT, 0, 4))
	_theme.set_stylebox("background", "ProgressBar", panel(Color("151e27"), Color("151e27"), 0, 4))
	_theme.set_stylebox("fill", "ProgressBar", panel(ACCENT, ACCENT, 0, 4))
	return _theme

static func primary(button: Button) -> void:
	neumorphic_button(button, true, 24)

static func apply(node: Node) -> void:
	for child in node.get_children():
		if child is Control and not child.get_parent() is Control:
			child.theme = theme()
		apply(child)

static func heading(label: Label) -> void:
	label.add_theme_font_override("font", DISPLAY_FONT)

static func decorate(control: Control, color: Color = ACCENT, backdrop: bool = false) -> void:
	var frame := FRAME.new()
	frame.accent = color
	frame.backdrop = backdrop
	if control is PanelContainer:
		var box := control.get_theme_stylebox("panel")
		frame.bleed = Vector4(box.get_content_margin(SIDE_LEFT), box.get_content_margin(SIDE_TOP), box.get_content_margin(SIDE_RIGHT), box.get_content_margin(SIDE_BOTTOM))
	control.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func configure_nameplate(label: Label3D) -> void:
	label.font = DISPLAY_FONT
	label.font_size = 40
	label.pixel_size = 0.0042
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.render_priority = 10
	label.outline_render_priority = 9
	label.outline_size = 6
	label.outline_modulate = Color(0.025, 0.04, 0.045, 0.95)

static func refresh_nameplate(label: Label3D, identity: String, friendly: bool, ai: bool = false) -> void:
	var callsign := identity.trim_prefix("[BOT] ").strip_edges().to_upper()
	var caption := callsign + "  / AI" if ai or identity.begins_with("[BOT] ") else callsign
	if label.text != caption: label.text = caption
	var colour := CYAN if friendly else DANGER
	if label.modulate != colour: label.modulate = colour

static func configure_health_badge(label: Label3D) -> void:
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font = DISPLAY_FONT
	label.font_size = 18
	label.pixel_size = 0.003
	label.outline_size = 4
	label.outline_modulate = Color(0.02, 0.03, 0.035, 0.9)

static func refresh_health_badge(label: Label3D, hp: int, friendly: bool) -> void:
	var text := "%d HP" % hp
	if label.text != text: label.text = text
	var colour := CYAN if friendly else DANGER
	if label.modulate != colour: label.modulate = colour
