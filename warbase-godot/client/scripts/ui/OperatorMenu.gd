extends HBoxContainer

var _scene: Node3D
var _operator: Node3D
var _name: Label
var _stats: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_constant_override("separation", 24)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(700, 600)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(viewport)
	_scene = Node3D.new()
	viewport.add_child(_scene)
	var camera := Camera3D.new()
	_scene.add_child(camera)
	camera.position = Vector3(1.5, 1.3, 3.6)
	camera.look_at(Vector3(0, 0.95, 0))
	camera.fov = 37
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = WarUI.PANEL
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c4d2df")
	environment.environment.ambient_light_energy = 0.7
	_scene.add_child(environment)
	for direction in [Vector3(-35, -25, 0), Vector3(-20, 130, 0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = direction
		light.light_energy = 1.2
		_scene.add_child(light)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 320
	panel.add_theme_stylebox_override("panel", WarUI.panel(WarUI.PANEL, WarUI.LINE, 24))
	add_child(panel)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 20)
	panel.add_child(info)
	var heading := Label.new()
	heading.text = "YOUR OPERATOR"
	heading.add_theme_color_override("font_color", WarUI.ACCENT)
	info.add_child(heading)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 25)
	info.add_child(_name)
	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 18)
	info.add_child(_stats)
	var tip := Label.new()
	tip.text = "Change your callsign above.\nYour equipped primary is shown."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_color_override("font_color", WarUI.MUTED)
	info.add_child(tip)
	refresh()

func refresh() -> void:
	if not is_instance_valid(_scene): return
	_name.text = GameState.username
	_stats.text = "SESSION RECORD\n\n%d eliminations\n%d deaths\n%.2f K/D" % [GameState.local_kills, GameState.local_deaths, float(GameState.local_kills) / maxf(1, GameState.local_deaths)]
	if is_instance_valid(_operator): _operator.queue_free()
	_operator = load("res://assets/models/AnimatedSoldier.glb").instantiate()
	_operator.rotation.y = 0
	_scene.add_child(_operator)
	var animation := _operator.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation and animation.has_animation("Rifle Idle"):
		animation.get_animation("Rifle Idle").loop_mode = Animation.LOOP_LINEAR
		animation.play("Rifle Idle")
	var gun := WeaponView.build(GameState.selected_primary)
	var skeleton := _operator.get_node_or_null("Armature/Skeleton3D") as Skeleton3D
	if skeleton and skeleton.find_bone("mixamorig_RightHand") >= 0:
		var socket := BoneAttachment3D.new()
		socket.bone_name = "mixamorig_RightHand"
		skeleton.add_child(socket)
		gun.scale = Vector3.ONE * 72
		gun.position = Vector3(2, -4, 1)
		gun.rotation_degrees = Vector3(90, 106, 0)
		socket.add_child(gun)
	else:
		gun.position = Vector3(0.2, 1.2, -0.3)
		gun.scale = Vector3.ONE * 0.72
		_operator.add_child(gun)
