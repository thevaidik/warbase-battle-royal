class_name WarLoadoutMenu
extends Control

signal closed
var slot := "primary"
var _slots: Dictionary = {}
var _catalog: GridContainer
var _title: Label
var _details: Label
var _preview: SubViewport
var _model_root: Node3D
var _preview_model: Node3D

func _ready() -> void:
	theme = WarUI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = WarUI.BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 0)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 12)
	layout.add_child(slots)
	for id in ["primary", "secondary", "throwable"]:
		var button := _button("", _select_slot.bind(id))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 82
		slots.add_child(button)
		_slots[id] = button
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	layout.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_catalog = GridContainer.new()
	_catalog.columns = 2
	_catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog.add_theme_constant_override("h_separation", 12)
	_catalog.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_catalog)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 300
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.7
	panel.add_theme_stylebox_override("panel", WarUI.panel(WarUI.PANEL, WarUI.LINE, 16))
	body.add_child(panel)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 12)
	panel.add_child(info)
	info.add_child(_label("EQUIPMENT PREVIEW", 12, WarUI.ACCENT))
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(220, 100)
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(container)
	_preview = SubViewport.new()
	_preview.size = Vector2i(500, 300)
	_preview.own_world_3d = true
	_preview.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(_preview)
	_model_root = Node3D.new()
	_preview.add_child(_model_root)
	var camera := Camera3D.new()
	camera.position = Vector3(1.35, 0.60, 1.3)
	_model_root.add_child(camera)
	camera.look_at(Vector3(0, 0, -0.22))
	camera.fov = 34
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = WarUI.PANEL
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("dbe4e8")
	environment.environment.ambient_light_energy = 0.75
	_model_root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 1.8
	_model_root.add_child(light)
	_title = _label("", 25)
	info.add_child(_title)
	_details = _label("", 14, WarUI.MUTED)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_details)
	_refresh()
	visible = false

func _label(text: String, font_size: int, color: Color = WarUI.TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(func() -> void:
		Audio.ui_btn_click()
		callback.call()
	)
	return button

func open() -> void:
	visible = true
	_refresh()

func _close() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if false and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func _select_slot(id: String) -> void:
	slot = id
	_refresh()

func choose(id: String) -> void:
	GameState.equip(slot, id)
	_refresh()

func _refresh() -> void:
	var names := {}
	for weapon in GameState.WEAPONS: names[weapon["id"]] = weapon["name"]
	for id in _slots:
		var selected_id := _equipped(id)
		var name_text := String(GameState.THROWABLES[selected_id]["name"]) if id == "throwable" else String(names[selected_id])
		_slots[id].text = id.to_upper() + "\n" + name_text
		_slots[id].add_theme_stylebox_override("normal", WarUI.panel(WarUI.RAISED if slot == id else WarUI.PANEL, WarUI.ACCENT if slot == id else WarUI.LINE, 14))
	for child in _catalog.get_children():
		_catalog.remove_child(child)
		child.queue_free()
	if slot == "throwable":
		for id in GameState.THROWABLES:
			var equipment: Dictionary = GameState.THROWABLES[id]
			_card(id, equipment["name"], equipment["description"], "2 PER LIFE")
	else:
		for weapon in GameState.WEAPONS:
			var category := "SEMI-AUTO" if not weapon["is_auto"] else "AUTOMATIC"
			_card(weapon["id"], weapon["name"], "%d DAMAGE   /   %d RPM\n%d ROUNDS   /   %.1fs RELOAD" % [weapon["damage"], weapon["fire_rate"], weapon["mag_size"], weapon["reload_time"]], category)
	_update_preview(_equipped(slot))

func _equipped(id: String) -> String:
	if id == "primary": return GameState.selected_primary
	if id == "secondary": return GameState.selected_secondary
	return GameState.selected_throwable

func _card(id: String, title: String, details: String, category: String) -> void:
	var selected := _equipped(slot) == id
	var card := _button("", choose.bind(id))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 128)
	card.add_theme_stylebox_override("normal", WarUI.panel(WarUI.RAISED if selected else WarUI.PANEL, WarUI.ACCENT if selected else WarUI.LINE, 14))
	_catalog.add_child(card)
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 16
	content.offset_top = 14
	content.offset_right = -16
	content.offset_bottom = -14
	content.add_theme_constant_override("separation", 7)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	for label in [_label("EQUIPPED" if selected else category, 11, WarUI.ACCENT), _label(title, 18), _label(details, 12, WarUI.MUTED)]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(label)

func _update_preview(id: String) -> void:
	if is_instance_valid(_preview_model): _preview_model.queue_free()
	if slot == "throwable":
		var grenade: Node = load("res://scenes/Grenade.tscn").instantiate()
		grenade.configure(id)
		_preview_model = grenade.get_node("ModelRoot").duplicate()
		grenade.free()
		_preview_model.scale = Vector3.ONE * 4
		_preview_model.position.z = -0.2
		_title.text = GameState.THROWABLES[id]["name"]
		_details.text = GameState.THROWABLES[id]["description"] + "\n[G] Throw. Restocked on respawn."
	else:
		var config: Dictionary = GameState.WEAPONS[GameState.weapon_index_for_id(id)]
		_preview_model = WeaponView.build(id)
		_title.text = config["name"]
		_details.text = "%d rounds • %.1fs reload\n%d RPM • %s" % [config["mag_size"], config["reload_time"], config["fire_rate"], "Automatic" if config["is_auto"] else "Semi-automatic"]
	_model_root.add_child(_preview_model)
