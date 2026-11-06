class_name WarUI
extends RefCounted
## Shared visual language for lobby, combat HUD, and overlays.
const BACKGROUND := Color("0a0e10")
const PANEL := Color("12191c")
const RAISED := Color("202c2e")
const LINE := Color("344649")
const TEXT := Color("eef3e9")
const MUTED := Color("a0b2b6")
const ACCENT := Color("c6ff5a")
const CYAN := Color("69dce7")
const SUCCESS := Color("8ce7ba")
const DANGER := Color("ff7665")
const DISPLAY_FONT = preload("res://assets/fonts/Rajdhani-SemiBold.ttf")
const FRAME = preload("res://scripts/ui/WarUIFrame.gd")
static var _theme: Theme

static func panel(background: Color = PANEL, border: Color = LINE, padding: int = 0, radius: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style

static func theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	_theme.default_font = ThemeDB.fallback_font
	_theme.default_font_size = 15
	_theme.set_font("font", "Button", DISPLAY_FONT)
	_theme.set_font_size("font_size", "Button", 20)
	_theme.set_color("font_color", "LineEdit", TEXT)
	_theme.set_color("caret_color", "LineEdit", ACCENT)
	_theme.set_color("selection_color", "LineEdit", Color("3c5843"))
	_theme.set_color("font_color", "Label", TEXT)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var background := RAISED if state == "hover" else PANEL
		var border := ACCENT if state in ["focus", "pressed", "hover"] else LINE
		_theme.set_stylebox(state, "Button", panel(background, border, 12))
		_theme.set_color("font_" + state + "_color", "Button", TEXT if state != "disabled" else MUTED.darkened(0.3))
	_theme.set_color("font_color", "Button", TEXT)
	_theme.set_stylebox("normal", "LineEdit", panel(BACKGROUND, LINE, 10))
	_theme.set_stylebox("focus", "LineEdit", panel(BACKGROUND, ACCENT, 10))
	var track := panel(Color("42565e"), Color("42565e"), 0, 3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	_theme.set_stylebox("slider", "HSlider", track)
	_theme.set_stylebox("grabber_area", "HSlider", panel(ACCENT, ACCENT, 0, 3))
	_theme.set_stylebox("grabber_area_highlight", "HSlider", panel(ACCENT.lightened(0.15), ACCENT, 0, 3))
	_theme.set_stylebox("background", "ProgressBar", panel(LINE, LINE, 0, 2))
	_theme.set_stylebox("fill", "ProgressBar", panel(ACCENT, ACCENT, 0, 2))
	return _theme

static func primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", panel(ACCENT, ACCENT, 14))
	button.add_theme_font_override("font", DISPLAY_FONT)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_stylebox_override("hover", panel(ACCENT.lightened(0.13), ACCENT.lightened(0.13), 14))
	button.add_theme_stylebox_override("pressed", panel(ACCENT.darkened(0.12), ACCENT, 14))
	button.add_theme_color_override("font_color", BACKGROUND)
	button.add_theme_color_override("font_hover_color", BACKGROUND)
	button.add_theme_color_override("font_pressed_color", BACKGROUND)

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
