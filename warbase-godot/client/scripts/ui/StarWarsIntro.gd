class_name WarStarWarsIntro
extends CanvasLayer
## Cinematic Star Wars perspective rolling crawl telling the lore of WARBOTS.
## Features starry cosmos background, shrinking title, 3D perspective rolling text, and smooth skip controls.

signal intro_finished

const DISPLAY_FONT = preload("res://assets/fonts/Rajdhani-SemiBold.ttf")

var _root: Control
var _starfield: Control
var _prologue: Label
var _title_center: CenterContainer
var _title_label: Label
var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _crawler_pivot: Node3D
var _crawl_label: Label3D
var _top_fade: ColorRect
var _skip_btn: Button

var _stars: Array[Dictionary] = []
var _time := 0.0
var _skipping := false
var _crawl_speed := 0.38
var _crawl_start_y := -4.2
var _crawl_target_y := 14.0

const CRAWL_TEXT := """Episode I
THE CONQUEST INITIATIVE

It is a dark era of relentless technological escalation.
Human combatants have abandoned the frontlines, leaving scorched
industrial complexes, ruined stadiums, and desolate desert canyons
to autonomous legions of unmanned combat warframes.

Remote operators guide these deadly machines from hardened command
bunkers: heavy armored tanks, high-traction wheeled assault trucks,
agile combat helicopters, and supersonic fixed-wing interceptors.

Control of each contested warzone hinges on four strategic nodes:
Alpha, Bravo, Charlie, and Delta. Securing and defending these
capture perimeters bleeds the enemy's reinforcement tickets until
total sector dominance is achieved.

Calibrate your neural optics. Arm your weapon payload.
Welcome to WARBOTS."""

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if DisplayServer.get_name() == "headless" or "--autotest" in OS.get_cmdline_user_args():
		_finish_instantly()
		return
	
	_build_ui()
	_init_stars(240)
	get_viewport().size_changed.connect(_on_viewport_resized)

func _finish_instantly() -> void:
	call_deferred("_emit_and_free")

func _emit_and_free() -> void:
	intro_finished.emit()
	queue_free()

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "IntroRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	
	# Cosmic background
	var bg := ColorRect.new()
	bg.color = Color("040609")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	
	# Twinkling starfield
	_starfield = Control.new()
	_starfield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_starfield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_starfield.draw.connect(_draw_stars)
	_root.add_child(_starfield)
	
	# 3D SubViewport for true Star Wars perspective crawl
	_viewport_container = SubViewportContainer.new()
	_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_viewport_container)
	
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.handle_input_locally = false
	_viewport.gui_disable_input = true
	_viewport_container.add_child(_viewport)
	
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.85, 3.8)
	cam.rotation_degrees = Vector3(-19.0, 0, 0)
	cam.fov = 64.0
	_viewport.add_child(cam)
	
	_crawler_pivot = Node3D.new()
	_crawler_pivot.rotation_degrees = Vector3(-54.0, 0, 0)
	_viewport.add_child(_crawler_pivot)
	
	_crawl_label = Label3D.new()
	_crawl_label.font = DISPLAY_FONT
	_crawl_label.font_size = 40
	_crawl_label.pixel_size = 0.0072
	_crawl_label.width = 860.0
	_crawl_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_crawl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crawl_label.modulate = Color("e5b83b") # Iconic Star Wars crawl amber-gold
	_crawl_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.95)
	_crawl_label.outline_size = 6
	_crawl_label.text = CRAWL_TEXT
	_crawl_label.position = Vector3(0, _crawl_start_y, 0)
	_crawler_pivot.add_child(_crawl_label)
	
	# Top fade gradient: smooth dissolution into infinite cosmic horizon
	_top_fade = ColorRect.new()
	_top_fade.anchor_left = 0.0
	_top_fade.anchor_right = 1.0
	_top_fade.anchor_top = 0.0
	_top_fade.anchor_bottom = 0.38
	_top_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad_mat := ShaderMaterial.new()
	grad_mat.shader = _build_horizon_fade_shader()
	_top_fade.material = grad_mat
	_root.add_child(_top_fade)
	
	# Opening prologue ("A LONG TIME IN THE FUTURE...")
	_prologue = Label.new()
	_prologue.text = "A LONG TIME IN THE FUTURE,\nIN A CONTESTED SECTOR FAR AWAY..."
	_prologue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prologue.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prologue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prologue.add_theme_font_override("font", DISPLAY_FONT)
	_prologue.add_theme_font_size_override("font_size", 28)
	_prologue.add_theme_color_override("font_color", Color("69dce7"))
	_prologue.modulate.a = 0.0
	_prologue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_prologue)
	
	# Huge WARBOTS title that recedes into the distance
	_title_center = CenterContainer.new()
	_title_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_title_center)
	
	_title_label = Label.new()
	_title_label.text = "WARBOTS"
	_title_label.add_theme_font_override("font", DISPLAY_FONT)
	_title_label.add_theme_font_size_override("font_size", 104)
	_title_label.add_theme_color_override("font_color", Color("e5b83b"))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.pivot_offset = Vector2(240, 60)
	_title_label.modulate.a = 0.0
	_title_center.add_child(_title_label)
	
	# Sleek Neumorphic skip button at bottom-right
	_skip_btn = Button.new()
	_skip_btn.text = "SKIP INTRO  ›"
	_skip_btn.anchor_left = 1.0
	_skip_btn.anchor_top = 1.0
	_skip_btn.anchor_right = 1.0
	_skip_btn.anchor_bottom = 1.0
	_skip_btn.offset_left = -174
	_skip_btn.offset_top = -64
	_skip_btn.offset_right = -24
	_skip_btn.offset_bottom = -20
	_skip_btn.custom_minimum_size = Vector2(150, 44)
	_skip_btn.focus_mode = Control.FOCUS_NONE
	_skip_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	WarUI.neumorphic_button(_skip_btn, false, 20)
	_skip_btn.pressed.connect(skip)
	_root.add_child(_skip_btn)

func _build_horizon_fade_shader() -> Shader:
	var s := Shader.new()
	s.code = """shader_type canvas_item;
void fragment() {
	// Gradient from pure dark void at top to completely transparent below
	float fade = 1.0 - smoothstep(0.0, 1.0, UV.y);
	COLOR = vec4(0.015, 0.023, 0.035, fade * 0.98);
}"""
	return s

func _init_stars(count: int) -> void:
	_stars.clear()
	for i in count:
		_stars.append({
			"pos": Vector2(randf(), randf()),
			"radius": randf_range(0.8, 2.4),
			"alpha": randf_range(0.3, 0.9),
			"speed": randf_range(1.5, 4.0),
			"phase": randf_range(0.0, TAU),
			"tint": Color(randf_range(0.85, 1.0), randf_range(0.9, 1.0), randf_range(0.95, 1.0))
		})

func _draw_stars() -> void:
	var sz := _starfield.size
	for s in _stars:
		var twinkle: float = sin(_time * float(s["speed"]) + float(s["phase"])) * 0.35 + 0.65
		var col: Color = s["tint"]
		col.a = float(s["alpha"]) * twinkle
		var pt: Vector2 = Vector2(float(s["pos"].x) * sz.x, float(s["pos"].y) * sz.y)
		_starfield.draw_circle(pt, float(s["radius"]), col)

func _process(delta: float) -> void:
	_time += delta
	_starfield.queue_redraw()
	
	# Timeline orchestration
	if _time < 3.2:
		# Phase 0: Prologue fades in (0..1s), holds (1..2.2s), fades out (2.2..3.2s)
		if _time < 1.0:
			_prologue.modulate.a = _time / 1.0
		elif _time < 2.2:
			_prologue.modulate.a = 1.0
		else:
			_prologue.modulate.a = maxf(0.0, 1.0 - (_time - 2.2) / 1.0)
		_title_label.modulate.a = 0.0
	elif _time < 7.5:
		# Phase 1: WARBOTS title appears and recedes into space
		_prologue.modulate.a = 0.0
		var title_t := _time - 3.2
		if title_t < 1.2:
			_title_label.modulate.a = title_t / 1.2
			_title_label.scale = Vector2.ONE
		else:
			var shrink_t := (title_t - 1.2) / 3.1
			var sc := maxf(0.001, pow(1.0 - shrink_t, 2.8))
			_title_label.scale = Vector2(sc, sc)
			_title_label.modulate.a = maxf(0.0, 1.0 - shrink_t)
	else:
		# Phase 2: Iconic 3D perspective rolling crawl
		_prologue.modulate.a = 0.0
		_title_label.modulate.a = 0.0
		var crawl_t := _time - 7.5
		_crawl_label.position.y = _crawl_start_y + crawl_t * _crawl_speed
		
		# Auto-finish once crawl reaches target height
		if _crawl_label.position.y >= _crawl_target_y:
			skip()

func _unhandled_input(event: InputEvent) -> void:
	if _skipping: return
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
			get_viewport().set_input_as_handled()
			skip()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		skip()

func skip() -> void:
	if _skipping: return
	_skipping = true
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_root, "modulate:a", 0.0, 0.45)
	tw.finished.connect(_emit_and_free)

func _on_viewport_resized() -> void:
	if is_instance_valid(_title_label):
		_title_label.pivot_offset = _title_label.size * 0.5
