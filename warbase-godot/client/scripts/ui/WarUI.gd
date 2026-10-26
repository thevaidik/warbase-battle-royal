class_name WarUI
extends RefCounted
## Shared visual language for lobby, combat HUD, and overlays.
const BACKGROUND := Color("0b1115")
const PANEL := Color("121b21")
const RAISED := Color("1a272e")
const LINE := Color("2b3a40")
const TEXT := Color("edf1e9")
const MUTED := Color("91a2a8")
const ACCENT := Color("dfba77")
const SUCCESS := Color("87b7a0")
const DANGER := Color("e28776")
static var _theme: Theme

static func panel(background: Color = PANEL, border: Color = LINE, padding: int = 0, radius: int = 8) -> StyleBoxFlat:
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
	_theme.default_font_size = 14
	_theme.set_color("font_color", "Label", TEXT)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var background := RAISED if state == "hover" else PANEL
		var border := ACCENT if state == "focus" or state == "pressed" else LINE
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
