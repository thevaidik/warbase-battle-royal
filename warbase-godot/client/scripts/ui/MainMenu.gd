class_name WarMenu
extends CanvasLayer
## Map-led lobby with a shared theme and explicit online/practice states.
signal deploy_requested

enum FeatureTab { HOME, LOADOUT, OPERATOR, SETTINGS }
var current_tab := FeatureTab.HOME
var root: Control
var main_layout: VBoxContainer
var name_edit: LineEdit
var status_pill: Label
var rooms_box: VBoxContainer
var refresh_btn: Button
var selected_server_label: Label
var join_btn: Button
var drawer_panel: PanelContainer
var drawer_title: Label
var drawer_content: VBoxContainer
var tab_buttons: Dictionary = {}
var loadout_menu: Control
var create_modal: PanelContainer
var create_name_edit: LineEdit
var create_map_id := "industrial"
var create_mode_id := "FFA"
var create_map_btns: Dictionary = {}
var create_mode_btns: Dictionary = {}
var toast_panel: PanelContainer
var toast_label: Label
var toast_tween: Tween
var _server_list: Array = []
var _selected_room_id := "industrial-public"
var _probe_t := 0.0
var _server_online := false
var _refreshing := false
var _hero_image: TextureRect
var _hero_title: Label
var _hero_description: Label
var _hero_mode: Label
var _room_count: Label
var _workspace: HBoxContainer
var _pages: Control
var _home_page: VBoxContainer
var _operator_page: Control
var _settings_page: PanelContainer
var _practice: CheckButton
var create_time_id := "noon"
const PLAYABLE_MAPS := ["football", "resoforge", "industrial", "village", "arena", "shipment", "dust2", "nuketown", "canyon", "desert_oasis"]
const MAP_NAMES := {"football":"Football Stadium", "resoforge":"ResoForge Yard", "industrial":"Industrial zone", "village":"Village outpost", "arena":"Combat arena", "shipment":"Shipment", "dust2":"Industrial recon", "canyon":"Canyon", "desert_oasis":"Desert oasis", "nuketown":"Industrial outpost"}
const MAP_DESCRIPTIONS := {"football":"Pitch, entrances and wide concourses. Source: kyrox.", "resoforge":"Layered cover. Flanking lanes. Map by ResoForge · CC BY 4.0.", "industrial":"Warehouses. Long sightlines. Close encounters.", "village":"Rural lanes and open ground. Choose your approach.", "arena":"Fast rotations through a compact combat arena.", "shipment":"Tight container lanes. Every corner counts."}

func _ready() -> void:
	_selected_room_id = GameState.room_id
	layer = 20
	if OS.has_feature("web"):
		var host = JavaScriptBridge.eval("window.location.host")
		if host != null: GameState.server_host = String(host)
	build_lobby()
	get_viewport().size_changed.connect(_on_window_resized)
	_probe_server()
	refresh_rooms()

func _process(delta: float) -> void:
	if not visible: return
	_probe_t += delta
	if _probe_t >= 8.0:
		_probe_t = 0.0
		_probe_server()
		refresh_rooms()

func _mk_label(text: String, font_size: int = 14, color: Color = WarUI.TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", maxi(font_size, 12))
	label.add_theme_color_override("font_color", color)
	return label

func _style_panel(background: Color, border: Color = WarUI.LINE, radius: int = 8, border_width: int = 1) -> StyleBoxFlat:
	var style := WarUI.panel(background, border, 0, radius)
	style.set_border_width_all(border_width)
	return style

func _make_interactive(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	for child in control.find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _margin(parent: Node, padding: int) -> MarginContainer:
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, padding)
	parent.add_child(margin)
	return margin

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.mouse_entered.connect(func() -> void: Audio.ui_btn_hover())
	button.pressed.connect(func() -> void:
		Audio.ui_btn_click()
		callback.call()
	)
	return button

func build_lobby() -> void:
	root = Control.new()
	root.name = "LobbyRoot"
	root.theme = WarUI.theme()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = WarUI.BACKGROUND
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var outer := _margin(root, 24)
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_layout = VBoxContainer.new()
	main_layout.name = "MainLayout"
	main_layout.add_theme_constant_override("separation", 18)
	outer.add_child(main_layout)
	_build_header(main_layout)
	_pages = Control.new()
	_pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_layout.add_child(_pages)
	_home_page = VBoxContainer.new()
	_home_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_home_page.add_theme_constant_override("separation", 18)
	_pages.add_child(_home_page)
	_workspace = HBoxContainer.new()
	_workspace.add_theme_constant_override("separation", 20)
	_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_home_page.add_child(_workspace)
	_build_center_servers(_workspace)
	_build_feature_drawer(_workspace)
	_build_bottom_bar(_home_page)
	loadout_menu = preload("res://scripts/ui/LoadoutMenu.gd").new()
	_pages.add_child(loadout_menu)
	_operator_page = preload("res://scripts/ui/OperatorMenu.gd").new()
	_pages.add_child(_operator_page)
	_settings_page = PanelContainer.new()
	_settings_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_page.add_theme_stylebox_override("panel", WarUI.panel(WarUI.PANEL, WarUI.LINE, 24))
	_pages.add_child(_settings_page)
	_build_create_server_modal()
	_build_toast_banner()
	_switch_tab(FeatureTab.HOME)
	_update_footer_selection()
	_on_window_resized()

func _build_header(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 62
	header.add_theme_constant_override("separation", 28)
	parent.add_child(header)
	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 2)
	brand.add_child(_mk_label("W A R B A S E", 25, WarUI.TEXT))
	brand.add_child(_mk_label("TACTICAL MULTIPLAYER", 12, WarUI.MUTED))
	header.add_child(brand)
	var separator := VSeparator.new()
	header.add_child(separator)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 6)
	header.add_child(navigation)
	for item in [[FeatureTab.HOME,"Home"], [FeatureTab.LOADOUT,"Loadout"], [FeatureTab.OPERATOR,"Operator"], [FeatureTab.SETTINGS,"Settings"]]:
		var tab: int = item[0]
		var button := _button(item[1], func() -> void:
			_switch_tab(tab)
		)
		button.custom_minimum_size = Vector2(84, 40)
		navigation.add_child(button)
		tab_buttons[tab] = button
	header.add_spacer(false)
	var identity := VBoxContainer.new()
	identity.add_theme_constant_override("separation", 4)
	status_pill = _mk_label("CONNECTING", 12, WarUI.MUTED)
	status_pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	identity.add_child(status_pill)
	name_edit = LineEdit.new()
	name_edit.text = GameState.username
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(170, 34)
	name_edit.tooltip_text = "Your callsign: 3–16 letters, numbers, underscores or hyphens."
	name_edit.text_changed.connect(func(text: String) -> void: GameState.username = text.to_upper())
	identity.add_child(name_edit)
	header.add_child(identity)

func _build_center_servers(parent: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	parent.add_child(column)
	var hero := PanelContainer.new()
	hero.name = "SelectedMap"
	hero.custom_minimum_size.y = 228
	hero.clip_contents = true
	hero.add_theme_stylebox_override("panel", WarUI.panel(WarUI.PANEL, WarUI.LINE))
	column.add_child(hero)
	var art := Control.new()
	art.custom_minimum_size.y = 228
	hero.add_child(art)
	_hero_image = TextureRect.new()
	_hero_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.add_child(_hero_image)
	_hero_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ float a=mix(0.12,0.94,smoothstep(0.15,1.0,UV.y)); COLOR=vec4(0.025,0.04,0.05,a); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	shade.material = material
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content := _margin(art, 24)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	content.add_child(info)
	var browse := HBoxContainer.new()
	browse.add_child(_mk_label("SELECTED OPERATION", 12, WarUI.ACCENT))
	browse.add_spacer(false)
	browse.add_child(_button("‹", func() -> void: _cycle_map(-1)))
	browse.add_child(_mk_label("CHANGE MAP", 12, WarUI.MUTED))
	browse.add_child(_button("›", func() -> void: _cycle_map(1)))
	info.add_child(browse)
	info.add_spacer(false)
	_hero_mode = _mk_label("TEAM DEATHMATCH", 12, WarUI.ACCENT)
	info.add_child(_hero_mode)
	_hero_title = _mk_label("INDUSTRIAL ZONE", 34, WarUI.TEXT)
	info.add_child(_hero_title)
	_hero_description = _mk_label("Warehouses. Long sightlines. Close encounters.", 14, Color("bac6c8"))
	_hero_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_hero_description)
	var room_header := HBoxContainer.new()
	room_header.add_child(_mk_label("SERVERS ONLINE", 13, WarUI.TEXT))
	room_header.add_spacer(false)
	_room_count = _mk_label("", 12, WarUI.MUTED)
	room_header.add_child(_room_count)
	refresh_btn = _button("Refresh", refresh_rooms)
	refresh_btn.custom_minimum_size = Vector2(86, 34)
	room_header.add_child(refresh_btn)
	column.add_child(room_header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	rooms_box = VBoxContainer.new()
	rooms_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rooms_box.add_theme_constant_override("separation", 8)
	scroll.add_child(rooms_box)

func _build_feature_drawer(parent: HBoxContainer) -> void:
	drawer_panel = PanelContainer.new()
	drawer_panel.custom_minimum_size.x = 330
	drawer_panel.add_theme_stylebox_override("panel", WarUI.panel(WarUI.PANEL, WarUI.LINE, 20))
	parent.add_child(drawer_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	drawer_panel.add_child(column)
	drawer_title = _mk_label("YOUR LOADOUT", 13, WarUI.ACCENT)
	column.add_child(drawer_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	drawer_content = VBoxContainer.new()
	drawer_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_content.add_theme_constant_override("separation", 12)
	scroll.add_child(drawer_content)

func _switch_tab(tab: int) -> void:
	current_tab = tab
	_home_page.visible = tab == FeatureTab.HOME
	loadout_menu.visible = tab == FeatureTab.LOADOUT
	_operator_page.visible = tab == FeatureTab.OPERATOR
	_settings_page.visible = tab == FeatureTab.SETTINGS
	for key in tab_buttons:
		var button: Button = tab_buttons[key]
		button.add_theme_stylebox_override("normal", WarUI.panel(WarUI.RAISED if key == tab else WarUI.BACKGROUND, WarUI.ACCENT if key == tab else WarUI.BACKGROUND, 12))
	if tab == FeatureTab.LOADOUT: loadout_menu.open()
	if tab == FeatureTab.OPERATOR: _operator_page.refresh()
	if tab == FeatureTab.SETTINGS:
		for child in _settings_page.get_children(): _settings_page.remove_child(child); child.queue_free()
		var settings := VBoxContainer.new()
		settings.add_theme_constant_override("separation", 16)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_settings_page.add_child(scroll)
		settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(settings)
		var home_drawer := drawer_content
		drawer_content = settings
		_build_settings_content()
		drawer_content = home_drawer
	_populate_drawer()

func _populate_drawer() -> void:
	for child in drawer_content.get_children():
		drawer_content.remove_child(child)
		child.queue_free()
	drawer_title.text = "EQUIPPED LOADOUT"
	_build_loadout_content()

func _build_loadout_content() -> void:
	drawer_content.add_child(_mk_label("Built your way.", 24))
	for entry in [["PRIMARY", GameState.selected_primary], ["SECONDARY", GameState.selected_secondary]]:
		drawer_content.add_child(_mk_label(entry[0], 12, WarUI.ACCENT))
		var config: Dictionary = GameState.WEAPONS[GameState.weapon_index_for_id(entry[1])]
		drawer_content.add_child(_mk_label(config["name"], 21))
		drawer_content.add_child(_mk_label("%d RPM  /  %d ROUNDS" % [config["fire_rate"], config["mag_size"]], 12, WarUI.MUTED))
		drawer_content.add_child(HSeparator.new())
	drawer_content.add_child(_mk_label("THROWABLE", 12, WarUI.ACCENT))
	drawer_content.add_child(_mk_label(GameState.THROWABLES[GameState.selected_throwable]["name"], 18))
	var customize := _button("Customize loadout  ›", func() -> void: _switch_tab(FeatureTab.LOADOUT))
	WarUI.primary(customize)
	drawer_content.add_child(customize)
	var note := _mk_label("Any weapon in either slot.
[1] Primary  [2] Secondary  [G] Throwable", 13, WarUI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drawer_content.add_child(note)

func _cycle_map(direction: int) -> void:
	var index := PLAYABLE_MAPS.find(GameState.selected_map)
	_select_map(PLAYABLE_MAPS[posmod(index + direction, PLAYABLE_MAPS.size())])

func _select_map(id: String) -> void:
	# Prefer the actual room's ID and mode over an assumed public room name.
	for room in _server_list:
		if String(room.get("map", "")) == id:
			_select_server(room)
			return
	GameState.selected_map = id
	GameState.selected_mode = "TDM" if id == "industrial" else "FFA"
	GameState.room_id = id + "-public"
	_update_footer_selection()
	_render_servers()

func _build_settings_content() -> void:
	drawer_content.add_child(_mk_label("Make it feel right.", 21))
	drawer_content.add_child(_mk_label("MOUSE SENSITIVITY", 12, WarUI.MUTED))
	var sensitivity := HSlider.new()
	sensitivity.min_value = 0.0005
	sensitivity.max_value = 0.006
	sensitivity.step = 0.0001
	sensitivity.value = GameState.BASE_SENSITIVITY
	sensitivity.custom_minimum_size.y = 32
	sensitivity.value_changed.connect(func(value: float) -> void:
		GameState.BASE_SENSITIVITY = value
		GameState.save_settings()
	)
	drawer_content.add_child(sensitivity)
	drawer_content.add_child(_mk_label("AUDIO DISABLED", 12, WarUI.MUTED))
	drawer_content.add_child(_mk_label("ONLINE SERVICE", 12, WarUI.MUTED))
	var host := LineEdit.new()
	host.text = GameState.server_host
	host.placeholder_text = "localhost:8081"
	host.custom_minimum_size.y = 40
	host.text_submitted.connect(func(value: String) -> void:
		if not value.strip_edges().is_empty():
			GameState.server_host = value.strip_edges()
			_probe_server()
			refresh_rooms()
	)
	drawer_content.add_child(host)
	drawer_content.add_child(_mk_label("Press Enter to apply the service address.", 12, WarUI.MUTED))
	drawer_content.add_child(HSeparator.new())
	for text in ["WASD  Move    SPACE  Jump", "RMB  Aim    V  Magnification", "R  Reload    G  Grenade", "TAB  Scoreboard    ESC  Pause"]:
		drawer_content.add_child(_mk_label(text, 13, WarUI.MUTED))

func _build_bottom_bar(parent: VBoxContainer) -> void:
	var footer := HBoxContainer.new()
	footer.custom_minimum_size.y = 62
	footer.add_theme_constant_override("separation", 12)
	parent.add_child(footer)
	footer.add_child(_button("Create match", _open_create_server_modal))
	var selection := VBoxContainer.new()
	selection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection.alignment = BoxContainer.ALIGNMENT_CENTER
	selected_server_label = _mk_label("", 14)
	selection.add_child(selected_server_label)
	selection.add_child(_mk_label("Online servers include AI and human players", 12, WarUI.MUTED))
	footer.add_child(selection)
	_practice = CheckButton.new()
	_practice.text = "Offline"
	_practice.tooltip_text = "Optional offline sandbox. Online servers already include AI."
	_practice.toggled.connect(func(_on: bool) -> void: _update_footer_selection())
	footer.add_child(_practice)
	join_btn = _button("JOIN SERVER", func() -> void:
		GameState.practice_mode = _practice.button_pressed
		deploy_requested.emit()
	)
	join_btn.custom_minimum_size = Vector2(186, 52)
	WarUI.primary(join_btn)
	footer.add_child(join_btn)

func _on_window_resized() -> void:
	if not is_instance_valid(root): return
	drawer_panel.custom_minimum_size.x = 290 if root.get_viewport_rect().size.x < 1150 else 330
	if is_instance_valid(create_modal) and create_modal.visible:
		create_modal.position = (root.size - create_modal.size) * 0.5

func _render_servers() -> void:
	for child in rooms_box.get_children():
		rooms_box.remove_child(child)
		child.queue_free()
	_room_count.text = "%d OPERATIONS" % _server_list.size()
	for room in _server_list:
		var id := String(room.get("id", ""))
		var map_id := String(room.get("map", "industrial"))
		var selected := id == GameState.room_id
		var card := _button("", func() -> void: _select_server(room))
		card.custom_minimum_size.y = 66
		card.add_theme_stylebox_override("normal", WarUI.panel(WarUI.RAISED if selected else WarUI.PANEL, WarUI.ACCENT if selected else WarUI.LINE))
		var content := _margin(card, 12)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		content.add_child(row)
		var picture := TextureRect.new()
		picture.custom_minimum_size = Vector2(76, 40)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.texture = _map_texture(map_id)
		row.add_child(picture)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var title := _mk_label(String(room.get("name", MAP_NAMES.get(map_id, map_id))), 15)
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		info.add_child(title)
		info.add_child(_mk_label(("TEAM DEATHMATCH" if room.get("mode", "FFA") == "TDM" else "FREE FOR ALL") + "  •  " + GameState.time_label(String(room.get("timeOfDay", "noon"))), 12, WarUI.MUTED))
		var count := int(room.get("playerCount", 0))
		var bot_count := int(room.get("botCount", 0))
		var occupancy := _mk_label(("%d PLAYERS / %d AI" % [count, bot_count] if count > 0 else "AI FILL READY") if _server_online else "PRACTICE", 13, WarUI.ACCENT if selected else WarUI.MUTED)
		occupancy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(occupancy)
		_make_interactive(card)
		rooms_box.add_child(card)

func _map_texture(map_id: String) -> Texture2D:
	var path := "res://assets/ui/maps/" + map_id + ".png"
	if not ResourceLoader.exists(path): path = "res://assets/ui/maps/industrial.png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

func _select_server(room: Dictionary) -> void:
	GameState.practice_mode = false
	GameState.room_id = String(room.get("id", "industrial-public"))
	GameState.selected_map = String(room.get("map", "industrial"))
	GameState.selected_time = String(room.get("timeOfDay", "noon"))
	GameState.selected_mode = String(room.get("mode", "FFA"))
	_selected_room_id = GameState.room_id
	_update_footer_selection()
	_render_servers()

func _update_footer_selection() -> void:
	if not is_instance_valid(join_btn): return
	var map_id := GameState.selected_map
	_hero_title.text = String(MAP_NAMES.get(map_id, map_id)).to_upper()
	_hero_description.text = String(MAP_DESCRIPTIONS.get(map_id, "Find your angle. Control the encounter."))
	_hero_image.texture = _map_texture(map_id)
	_hero_mode.text = ("TEAM DEATHMATCH" if GameState.selected_mode == "TDM" else "FREE FOR ALL") + "  •  " + GameState.time_label(GameState.selected_time)
	selected_server_label.text = String(MAP_NAMES.get(map_id, map_id)) + "  /  " + GameState.selected_mode
	join_btn.disabled = not _server_online and not _practice.button_pressed
	join_btn.text = "START OFFLINE" if _practice.button_pressed else "JOIN SERVER"
	join_btn.tooltip_text = "Connect to an available service, or choose offline practice." if not _server_online else "Join the selected match"

func _api_request(path: String, callback: Callable, method: int = HTTPClient.METHOD_GET, payload: String = "") -> void:
	var request := HTTPRequest.new()
	request.timeout = 4.0
	add_child(request)
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		request.queue_free()
		var data: Variant = null
		if result == HTTPRequest.RESULT_SUCCESS and not body.is_empty():
			var json := JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK: data = json.data
		callback.call(code if result == HTTPRequest.RESULT_SUCCESS else 0, data)
	)
	var candidate_backend := _uses_colyseus_candidate()
	var host := GameState.server_host.trim_prefix("https://").trim_prefix("http://").trim_prefix("wss://").trim_prefix("ws://").trim_suffix("/")
	if candidate_backend and host.ends_with("/colyseus"):
		host = host.trim_suffix("/colyseus")
	var scheme := "http" if host.begins_with("localhost") or host.begins_with("127.") else "https"
	if OS.has_feature("web"): scheme = String(JavaScriptBridge.eval("window.location.protocol")).trim_suffix(":")
	var api_path := ("/colyseus" if candidate_backend else "") + path
	var error := request.request(scheme + "://" + host + api_path, PackedStringArray(["Content-Type: application/json"]), method, payload)
	if error != OK:
		request.queue_free()
		callback.call(0, null)

func _uses_colyseus_candidate() -> bool:
	var app := get_parent()
	if app != null and "_use_colyseus" in app and app.get("_use_colyseus") == true:
		return true
	if OS.has_feature("web"):
		var web_backend := String(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('backend') || ''")).to_lower()
		var web_qa_colyseus := String(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa_colyseus') || ''"))
		var web_path := String(JavaScriptBridge.eval("window.location.pathname"))
		return web_backend == "colyseus" or web_backend == "qa_colyseus" or web_qa_colyseus == "1" or web_path == "/colyseus" or web_path.begins_with("/colyseus/")
	return false

func _probe_server() -> void:
	_api_request("/healthcheck", func(code: int, _data: Variant) -> void:
		_server_online = code == 200
		status_pill.text = "SERVICE ONLINE" if _server_online else "OFFLINE / PRACTICE READY"
		status_pill.tooltip_text = GameState.server_host
		status_pill.add_theme_color_override("font_color", WarUI.SUCCESS if _server_online else WarUI.MUTED)
		_update_footer_selection()
		_render_servers()
	)

func refresh_rooms() -> void:
	if _refreshing: return
	_refreshing = true
	_api_request("/api/rooms", func(code: int, data: Variant) -> void:
		_refreshing = false
		_server_list = data.get("rooms", []) if code == 200 and data is Dictionary else []
		_server_list = _server_list.filter(func(room: Dictionary) -> bool: return room.get("map", "") in PLAYABLE_MAPS)
		if _server_list.is_empty():
			for id in PLAYABLE_MAPS:
				_server_list.append({"id":id + "-public", "name":MAP_NAMES[id], "map":id, "mode":"TDM" if id == "industrial" else "FFA"})
		for room in _server_list:
			if String(room.get("id", "")) == GameState.room_id:
				GameState.selected_mode = String(room.get("mode", "FFA"))
				GameState.selected_time = String(room.get("timeOfDay", "noon"))
		_update_footer_selection()
		_render_servers()
	)

func _execute_create_server() -> void:
	var match_name := create_name_edit.text.strip_edges()
	if match_name.is_empty(): match_name = GameState.username + "'s Match"
	create_modal.visible = false
	_api_request("/api/rooms", func(code: int, data: Variant) -> void:
		if code != 201 or not data is Dictionary or not data.has("room_id"):
			_show_toast("Match could not be created. Check the service and try again.", false)
			return
		GameState.room_id = String(data["room_id"])
		GameState.selected_map = create_map_id
		GameState.selected_time = create_time_id
		GameState.selected_mode = create_mode_id
		_selected_room_id = GameState.room_id
		_update_footer_selection()
		refresh_rooms()
		_show_toast("Match created. Ready to deploy.")
	, HTTPClient.METHOD_POST, JSON.stringify({"name":match_name, "map":create_map_id, "mode":create_mode_id, "timeOfDay":create_time_id}))

func _build_create_server_modal() -> void:
	create_modal = PanelContainer.new()
	create_modal.set_anchors_preset(Control.PRESET_CENTER)
	create_modal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	create_modal.grow_vertical = Control.GROW_DIRECTION_BOTH
	create_modal.custom_minimum_size = Vector2(460, 410)
	create_modal.visible = false
	create_modal.add_theme_stylebox_override("panel", _style_panel(WarUI.PANEL, WarUI.LINE, 8, 2))
	root.add_child(create_modal)
	
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_top", 16)
	m.add_theme_constant_override("margin_bottom", 16)
	create_modal.add_child(m)
	
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 10)
	m.add_child(mv)
	
	var title_row := HBoxContainer.new()
	title_row.add_child(_mk_label("CREATE A MATCH", 15, WarUI.ACCENT))
	title_row.add_spacer(false)
	var x_btn := Button.new()
	x_btn.text = "X"
	x_btn.custom_minimum_size = Vector2(26, 26)
	x_btn.pressed.connect(func() -> void:
		Audio.ui_btn_click()
		create_modal.visible = false
	)
	_make_interactive(x_btn)
	title_row.add_child(x_btn)
	mv.add_child(title_row)
	
	# Server Name input
	mv.add_child(_mk_label("MATCH NAME", 10, Color(0.60, 0.68, 0.78)))
	create_name_edit = LineEdit.new()
	create_name_edit.text = "%s's Match" % GameState.username
	create_name_edit.custom_minimum_size = Vector2(0, 32)
	create_name_edit.add_theme_stylebox_override("normal", _style_panel(Color(0.11, 0.13, 0.18), Color(0.22, 0.28, 0.36)))
	mv.add_child(create_name_edit)
	
	# Map Selection
	mv.add_child(_mk_label("CHOOSE YOUR MAP", 10, Color(0.60, 0.68, 0.78)))
	var maps := []
	for id in PLAYABLE_MAPS: maps.append({"id":id,"name":MAP_NAMES[id].to_upper()})
	var map_grid := GridContainer.new()
	map_grid.columns = 2
	map_grid.add_theme_constant_override("separation", 5)
	for mp in maps:
		var mid: String = mp["id"]
		var btn := Button.new()
		btn.text = mp["name"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 30)
		btn.mouse_entered.connect(func() -> void: Audio.ui_btn_hover())
		btn.pressed.connect(func() -> void:
			Audio.ui_btn_click()
			create_map_id = mid
			_update_create_modal_highlights()
		)
		_make_interactive(btn)
		map_grid.add_child(btn)
		create_map_btns[mid] = btn
	mv.add_child(map_grid)
	
	# Mode Selection
	mv.add_child(_mk_label("OPERATION MODE", 10, Color(0.60, 0.68, 0.78)))
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	for md in [{"id": "FFA", "name": "FREE FOR ALL"}, {"id": "TDM", "name": "TEAM DEATHMATCH"}]:
		var mid: String = md["id"]
		var btn := Button.new()
		btn.text = md["name"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 30)
		btn.mouse_entered.connect(func() -> void: Audio.ui_btn_hover())
		btn.pressed.connect(func() -> void:
			Audio.ui_btn_click()
			create_mode_id = mid
			_update_create_modal_highlights()
		)
		_make_interactive(btn)
		mode_row.add_child(btn)
		create_mode_btns[mid] = btn
	mv.add_child(mode_row)
	mv.add_child(_mk_label("TIME OF DAY", 12, WarUI.ACCENT))
	var time_select := OptionButton.new()
	for id in GameState.TIMES:
		time_select.add_item(GameState.time_label(id))
		time_select.set_item_metadata(time_select.item_count - 1, id)
	time_select.select(1)
	time_select.item_selected.connect(func(index: int) -> void: create_time_id = time_select.get_item_metadata(index))
	mv.add_child(time_select)

	
	mv.add_spacer(false)
	
	# Action row
	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 10)
	
	var cancel_btn := Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.custom_minimum_size = Vector2(0, 36)
	cancel_btn.pressed.connect(func() -> void:
		Audio.ui_btn_click()
		create_modal.visible = false
	)
	_make_interactive(cancel_btn)
	act_row.add_child(cancel_btn)
	
	var launch_btn := Button.new()
	WarUI.primary(launch_btn)
	launch_btn.text = "CREATE MATCH"
	launch_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	launch_btn.custom_minimum_size = Vector2(0, 36)
	launch_btn.add_theme_stylebox_override("normal", _style_panel(Color("715e3f"), WarUI.ACCENT, 5))
	launch_btn.pressed.connect(func() -> void:
		_execute_create_server()
	)
	_make_interactive(launch_btn)
	act_row.add_child(launch_btn)
	mv.add_child(act_row)
	
	_update_create_modal_highlights()

func _open_create_server_modal() -> void:
	if is_instance_valid(create_name_edit):
		create_name_edit.text = "%s's Match" % GameState.username
	create_modal.visible = true
	create_modal.position = (root.size - create_modal.size) * 0.5
	_update_create_modal_highlights()

func _update_create_modal_highlights() -> void:
	for mid in create_map_btns:
		var btn: Button = create_map_btns[mid]
		var is_sel: bool = (mid == create_map_id)
		var bg := Color(0.18, 0.24, 0.34) if is_sel else Color(0.10, 0.12, 0.16)
		var border := WarUI.ACCENT if is_sel else Color(0.20, 0.25, 0.32)
		btn.add_theme_stylebox_override("normal", _style_panel(bg, border, 4, 2 if is_sel else 1))
	for mid in create_mode_btns:
		var btn: Button = create_mode_btns[mid]
		var is_sel: bool = (mid == create_mode_id)
		var bg := Color(0.18, 0.24, 0.34) if is_sel else Color(0.10, 0.12, 0.16)
		var border := WarUI.ACCENT if is_sel else Color(0.20, 0.25, 0.32)
		btn.add_theme_stylebox_override("normal", _style_panel(bg, border, 4, 2 if is_sel else 1))


func _build_toast_banner() -> void:
	toast_panel = PanelContainer.new()
	toast_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_panel.offset_left = 60
	toast_panel.offset_right = -60
	toast_panel.offset_top = -60
	toast_panel.custom_minimum_size = Vector2(0, 44)
	toast_panel.visible = false
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_theme_stylebox_override("panel", _style_panel(Color(0.12, 0.22, 0.16, 0.98), Color(0.25, 0.95, 0.45), 6, 2))
	root.add_child(toast_panel)
	
	toast_label = _mk_label("MAP CREATED", 12, Color(0.3, 1.0, 0.5))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_child(toast_label)

func _show_toast(msg: String, is_success: bool = true) -> void:
	if not is_instance_valid(toast_panel):
		return
	toast_label.text = msg
	var bg_col := Color(0.10, 0.22, 0.15, 0.98) if is_success else Color(0.25, 0.10, 0.10, 0.98)
	var border_col := Color(0.25, 0.95, 0.45) if is_success else Color(0.95, 0.3, 0.25)
	toast_panel.add_theme_stylebox_override("panel", _style_panel(bg_col, border_col, 6, 2))
	
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()
		
	toast_panel.visible = true
	toast_panel.offset_top = -60
	toast_tween = create_tween()
	toast_tween.tween_property(toast_panel, "offset_top", 10.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	toast_tween.tween_interval(2.8)
	toast_tween.tween_property(toast_panel, "offset_top", -60.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	toast_tween.tween_callback(func() -> void:
		if is_instance_valid(toast_panel):
			toast_panel.visible = false
	)

# ==============================================================================
# SERVER PROBING & REFRESH
# ==============================================================================
