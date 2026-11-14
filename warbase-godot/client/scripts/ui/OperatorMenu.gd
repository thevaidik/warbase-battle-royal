extends HBoxContainer

const StudioSky := preload("res://scripts/drones/HangarStudio.gdshader")
const StandShadow := preload("res://scripts/drones/HangarShadow.gdshader")

var _scene: Node3D
var _drone: Node3D
var _preview_surface: TextureRect
var _preview_viewport: SubViewport
var _preview_camera: Camera3D
var _stand: Node3D
var _stats: Label
var _payload_label: Label
var _chassis_buttons: HBoxContainer
var _payload_picker: OptionButton
var _secondary_picker: OptionButton
var _tertiary_picker: OptionButton
var _tertiary_heading: Label
var _throwable_picker: OptionButton
var _preview_t := 0.0
var _orbit_yaw := 0.08
var _orbit_dragging := false
var _has_orbited := false

func _ready() -> void:
	add_theme_constant_override("separation", 24)
	_build_preview()
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 320
	panel.add_theme_stylebox_override("panel", WarUI.panel(WarUI.PANEL, WarUI.LINE, 24))
	add_child(panel)
	WarUI.decorate(panel, WarUI.CYAN)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 10)
	scroll.add_child(info)
	var heading := Label.new()
	heading.text = "DRONE HANGAR"
	heading.add_theme_color_override("font_color", WarUI.ACCENT)
	info.add_child(heading)
	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 16)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_stats)
	_chassis_buttons = HBoxContainer.new()
	_chassis_buttons.add_theme_constant_override("separation", 6)
	for chassis in ["wheels", "tracked", "heli", "wing"]:
		var button := Button.new()
		button.text = {"wheels":"WHEELS", "tracked":"TRACKS", "heli":"HELI", "wing":"WING"}[chassis]
		button.toggle_mode = true
		button.button_pressed = chassis == GameState.selected_drone_chassis
		button.pressed.connect(_select_chassis.bind(chassis))
		_chassis_buttons.add_child(button)
	info.add_child(_chassis_buttons)
	var primary_heading := Label.new()
	primary_heading.text = "PRIMARY WEAPON  /  LEFT"
	primary_heading.add_theme_color_override("font_color", WarUI.ACCENT)
	info.add_child(primary_heading)
	_payload_picker = OptionButton.new()
	for config in GameState.WEAPONS:
		var weapon_id := String(config["id"])
		_payload_picker.add_item(String(config["name"]))
		_payload_picker.set_item_metadata(_payload_picker.item_count - 1, weapon_id)
	_payload_picker.item_selected.connect(_select_payload)
	_payload_picker.tooltip_text = "Select your primary weapon."
	info.add_child(_payload_picker)
	var secondary_heading := Label.new()
	secondary_heading.text = "SECONDARY WEAPON  /  RIGHT"
	secondary_heading.add_theme_color_override("font_color", WarUI.ACCENT)
	info.add_child(secondary_heading)
	_secondary_picker = OptionButton.new()
	for config in GameState.WEAPONS:
		var weapon_id := String(config["id"])
		_secondary_picker.add_item(String(config["name"]))
		_secondary_picker.set_item_metadata(_secondary_picker.item_count - 1, weapon_id)
	_secondary_picker.item_selected.connect(_select_secondary)
	info.add_child(_secondary_picker)
	_tertiary_heading = Label.new()
	_tertiary_heading.text = "TERTIARY WEAPON  /  CENTER TURRET"
	_tertiary_heading.add_theme_color_override("font_color", WarUI.ACCENT)
	info.add_child(_tertiary_heading)
	_tertiary_picker = OptionButton.new()
	for config in GameState.WEAPONS:
		var weapon_id := String(config["id"])
		_tertiary_picker.add_item(String(config["name"]))
		_tertiary_picker.set_item_metadata(_tertiary_picker.item_count - 1, weapon_id)
	_tertiary_picker.item_selected.connect(_select_tertiary)
	info.add_child(_tertiary_picker)
	var throwable_heading := Label.new()
	throwable_heading.text = "GADGETS"
	throwable_heading.add_theme_color_override("font_color", WarUI.ACCENT)
	info.add_child(throwable_heading)
	_throwable_picker = OptionButton.new()
	for id in GameState.THROWABLES:
		_throwable_picker.add_item(String(GameState.THROWABLES[id]["name"]))
		_throwable_picker.set_item_metadata(_throwable_picker.item_count - 1, id)
	_throwable_picker.item_selected.connect(_select_throwable)
	info.add_child(_throwable_picker)
	var tip := Label.new()
	_payload_label = tip
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_color_override("font_color", WarUI.MUTED)
	info.add_child(tip)
	refresh()

func _process(delta: float) -> void:
	if is_instance_valid(_drone):
		_preview_t += delta
		_drone.rotation.y = _orbit_yaw if _has_orbited else _orbit_yaw + sin(_preview_t * 0.36) * 0.13

func _build_preview() -> void:
	_preview_surface = TextureRect.new()
	_preview_surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_surface.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_preview_surface.mouse_default_cursor_shape = Control.CURSOR_DRAG
	add_child(_preview_surface)
	_preview_viewport = SubViewport.new()
	_preview_viewport.own_world_3d = true
	_preview_viewport.msaa_3d = Viewport.MSAA_4X
	_preview_viewport.scaling_3d_scale = 1.0
	_preview_surface.add_child(_preview_viewport)
	_preview_surface.texture = _preview_viewport.get_texture()
	_scene = Node3D.new()
	_preview_viewport.add_child(_scene)
	_preview_camera = Camera3D.new()
	_preview_camera.fov = 36.0
	_preview_camera.near = 0.02
	_preview_camera.far = 12.0
	_scene.add_child(_preview_camera)
	_build_studio()
	var orbit_hint := Label.new()
	orbit_hint.text = "Drag to rotate"
	orbit_hint.add_theme_color_override("font_color", WarUI.MUTED)
	orbit_hint.add_theme_font_size_override("font_size", 13)
	orbit_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_surface.add_child(orbit_hint)
	orbit_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	orbit_hint.position += Vector2(16, -14)
	_preview_surface.gui_input.connect(_orbit_preview)
	_preview_surface.resized.connect(_resize_preview)
	get_window().size_changed.connect(_resize_preview, CONNECT_DEFERRED)
	visibility_changed.connect(_update_preview_visibility)
	_resize_preview.call_deferred()
	_update_preview_visibility()

func _resize_preview() -> void:
	var panel_size := _preview_surface.size
	if minf(panel_size.x, panel_size.y) < 2.0: return
	var screen_size := Vector2(get_window().size)
	var canvas_size := get_viewport().get_visible_rect().size
	var pixel_scale := screen_size / canvas_size.max(Vector2.ONE)
	var quality := maxf(1.45 if not OS.has_feature("web") else 1.0, maxf(pixel_scale.x, pixel_scale.y))
	var limit := Vector2(1680.0, 1200.0) if not OS.has_feature("web") else Vector2(1440.0, 1050.0)
	var sample_scale := minf(quality, minf(limit.x / panel_size.x, limit.y / panel_size.y))
	var render_size := Vector2i((panel_size * sample_scale).round()).max(Vector2i(2, 2))
	if _preview_viewport.size != render_size: _preview_viewport.size = render_size
	var aspect := panel_size.x / panel_size.y
	var ground_gear := GameState.selected_drone_chassis in ["wheels", "tracked"]
	var distance := maxf(1.37 if ground_gear else 1.31, 0.47 / (maxf(aspect, 0.20) * tan(deg_to_rad(_preview_camera.fov * 0.5))))
	var focus := Vector3(0, -0.15 if ground_gear else -0.095, 0)
	_preview_camera.position = focus + Vector3(0.54, 0.42, -1.0).normalized() * distance
	_preview_camera.look_at(focus)

func _update_preview_visibility() -> void:
	var shown := is_visible_in_tree()
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if shown else SubViewport.UPDATE_DISABLED
	set_process(shown)
	if not shown: _orbit_dragging = false

func _orbit_preview(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_orbit_dragging = event.pressed
	elif event is InputEventMouseMotion and _orbit_dragging:
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_orbit_dragging = false
			return
		_has_orbited = true
		_orbit_yaw = wrapf(_orbit_yaw - event.relative.x * 0.012, -PI, PI)
	elif event is InputEventScreenDrag:
		_has_orbited = true
		_orbit_yaw = wrapf(_orbit_yaw - event.relative.x * 0.012, -PI, PI)

func _build_studio() -> void:
	var sky_material := ShaderMaterial.new()
	sky_material.shader = StudioSky
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_128 if OS.has_feature("web") else Sky.RADIANCE_SIZE_256
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.sky = sky
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("192630")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c1d8eb")
	environment.ambient_light_energy = 0.26
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.0
	environment.ssao_enabled = not OS.has_feature("web")
	environment.ssao_radius = 0.055
	environment.ssao_intensity = 0.7
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_scene.add_child(world_environment)
	_add_studio_light(Vector3(-46, -32, 0), Color("fff0dd"), 1.15)
	_add_studio_light(Vector3(-25, 138, 0), Color("abcfff"), 1.35)
	_add_studio_light(Vector3(-14, 28, 0), Color("d3e2f5"), 0.40)
	_stand = Node3D.new()
	_scene.add_child(_stand)
	_add_stand_layer(0.42, 0.032, -0.024, Color("10191f"), 0.58, 0.49)
	_add_stand_layer(0.408, 0.009, -0.006, Color("596870"), 0.85, 0.35)
	_add_stand_layer(0.393, 0.006, 0.001, Color("25323c"), 0.48, 0.60)
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = StandShadow
	var shadow_mesh := PlaneMesh.new()
	shadow_mesh.size = Vector2(0.66, 0.62)
	var shadow := MeshInstance3D.new()
	shadow.mesh = shadow_mesh
	shadow.material_override = shadow_material
	shadow.position.y = 0.005
	_stand.add_child(shadow)

func _add_studio_light(angles: Vector3, tint: Color, energy: float) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = angles
	light.light_color = tint
	light.light_energy = energy
	_scene.add_child(light)

func _add_stand_layer(radius: float, height: float, y: float, finish: Color, metallic: float, roughness: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 80
	mesh.rings = 1
	var material := StandardMaterial3D.new()
	material.albedo_color = finish
	material.metallic = metallic
	material.roughness = roughness
	var layer := MeshInstance3D.new()
	layer.mesh = mesh
	layer.material_override = material
	layer.position.y = y
	_stand.add_child(layer)

func _select_chassis(chassis: String) -> void:
	GameState.selected_drone_chassis = chassis
	GameState.save_settings()
	refresh()

func _select_payload(index: int) -> void:
	var weapon_id := String(_payload_picker.get_item_metadata(index))
	GameState.equip("primary", weapon_id)
	refresh()

func _select_secondary(index: int) -> void:
	GameState.equip("secondary", String(_secondary_picker.get_item_metadata(index)))
	refresh()

func _select_tertiary(index: int) -> void:
	GameState.equip("tertiary", String(_tertiary_picker.get_item_metadata(index)))
	refresh()

func _select_throwable(index: int) -> void:
	GameState.equip("throwable", String(_throwable_picker.get_item_metadata(index)))
	refresh()

func refresh() -> void:
	if not is_instance_valid(_scene): return
	if is_instance_valid(_payload_picker):
		for index in _payload_picker.item_count:
			if String(_payload_picker.get_item_metadata(index)) == GameState.selected_primary:
				_payload_picker.select(index)
				break
	if is_instance_valid(_secondary_picker):
		for index in _secondary_picker.item_count:
			if String(_secondary_picker.get_item_metadata(index)) == GameState.selected_secondary:
				_secondary_picker.select(index)
				break
	var is_tank: bool = GameState.selected_drone_chassis == "tracked"
	if is_instance_valid(_tertiary_heading): _tertiary_heading.visible = is_tank
	if is_instance_valid(_tertiary_picker):
		_tertiary_picker.visible = is_tank
		if is_tank:
			for index in _tertiary_picker.item_count:
				if String(_tertiary_picker.get_item_metadata(index)) == GameState.selected_tertiary:
					_tertiary_picker.select(index)
					break
	var chassis_labels := {
		"tracked": "HEAVY TANK CHASSIS  •  220 HP (MAX ARMOR)",
		"wheels": "MONSTER 4x4 TRUCK  •  170 HP (HEAVY ARMOR)",
		"heli": "GUNSHIP HELICOPTER  •  100 HP (AERO ARMOR)",
		"wing": "INTERCEPTOR JET  •  75 HP (LIGHT ARMOR)",
	}
	var label: String = chassis_labels.get(GameState.selected_drone_chassis, "VANGUARD / HELICOPTER ROTOR")
	for index in _throwable_picker.item_count:
		if String(_throwable_picker.get_item_metadata(index)) == GameState.selected_throwable:
			_throwable_picker.select(index)
			break
	if GameState.selected_drone_chassis == "wheels":
		_payload_label.text = "W/S drive and reverse. A/D turn monster wheels. 170 HP Heavy Armor."
	elif GameState.selected_drone_chassis == "tracked":
		_payload_label.text = "W/S drive and reverse. A/D turn tracks (opposite in reverse). 220 HP Max Armor."
	elif GameState.selected_drone_chassis == "heli":
		_payload_label.text = "W moves forward. S descends slowly. Space/Ctrl adjust altitude. 100 HP Balanced."
	elif GameState.selected_drone_chassis == "wing":
		_payload_label.text = "Hold W and pitch to fly. High speed, 75 HP Light Interceptor."
	else:
		_payload_label.text = "Hold W and aim up or down to fly. Space/Ctrl override climb."
	var selected_weapon_index := GameState.weapon_index_for_id(GameState.selected_primary)
	var selected_weapon: Dictionary = GameState.WEAPONS[selected_weapon_index]
	if selected_weapon.has("missile_speed"):
		_stats.text = "%s\n%.0f direct damage  •  %d per rack  •  Unguided" % [label, selected_weapon["damage"], selected_weapon["mag_size"]]
	else:
		_stats.text = "%s\n%.0f damage  •  %.0f RPM  •  %d round mag" % [label, selected_weapon["damage"], selected_weapon["fire_rate"], selected_weapon["mag_size"]]
	for button in _chassis_buttons.get_children():
		if button is Button:
			var chassis_by_label := {"WHEELS":"wheels","TRACKS":"tracked","HELI":"heli","WING":"wing"}
			button.button_pressed = String(chassis_by_label.get(button.text,"")) == GameState.selected_drone_chassis
	if is_instance_valid(_drone):
		_scene.remove_child(_drone)
		_drone.queue_free()
	var visual_script := load("res://scripts/drones/DroneVisual.gd")
	if visual_script == null:
		push_warning("DroneVisual.gd is not available for the hangar preview")
		return
	_drone = Node3D.new()
	_drone.set_script(visual_script)
	_scene.add_child(_drone)
	_drone.call("configure", true, GameState.selected_primary, GameState.selected_drone_chassis, "", GameState.selected_secondary, GameState.selected_tertiary)
	_drone.call("set_inspection_pose")
	var is_ground_mode: bool = GameState.selected_drone_chassis in ["wheels", "tracked"]
	_stand.position.y = -0.412 if is_ground_mode else -0.345
	_resize_preview()
