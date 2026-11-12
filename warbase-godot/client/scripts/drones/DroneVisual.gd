class_name DroneVisual
extends Node3D
## Procedural drone hardware. Ground gear extends to the floor beneath the hit sphere.

const PayloadBuilderScript = preload("res://scripts/drones/DronePayloadBuilder.gd")
const DroneMeshScript = preload("res://scripts/drones/DroneMesh.gd")
const Finish := preload("res://scripts/drones/DroneFinish.gd")
const PAYLOAD_IDS := ["ak47", "pistol", "m2010", "hmg", "m4", "mp5", "dmr", "aim9", "agm114"]
const CHASSIS := ["quad", "wheels", "tracked", "heli", "wing"]
const LABELS := {"quad":"Vanguard", "wheels":"Vanguard", "tracked":"Vanguard", "heli":"Vanguard", "wing":"Vanguard"}
const BANK_LIMIT := deg_to_rad(10.0)
const BANK_RESPONSE := 7.5
const BODY_SCALE := 0.96
const DISPLAY_SCALE := 1.10
const GROUND_HULL_DROP := 0.115
const GROUND_CONTACT_DEPTH := GameState.DRONE_RADIUS + 0.008
const TIRE_RADIUS := 0.058
const WHEEL_HUB_Y := -0.10
const TRACK_BOTTOM_Y := -0.165
var friendly := true
var weapon_id := "ak47"
var chassis_id := "quad"
var dead := false
var crash_hidden := false
var payload_enabled := true
var _velocity := Vector3.ZERO
var _body: Node3D
var _bank_root: Node3D
var _payload_gimbal: Node3D
var _payload: Node3D
var _left_mount: Node3D
var _right_mount: Node3D
var _primary_weapon := "ak47"
var _secondary_weapon := ""
var _rotor: Node3D
var _rotor_player: AnimationPlayer
var _aim_pitch := 0.0
var _aim_yaw := 0.0
var _team_trim: MeshInstance3D
var _team_leds: Array[MeshInstance3D] = []
var _attachment_sets: Dictionary = {}
var _rolling_parts: Array[Node3D] = []
static var _heat_material: StandardMaterial3D

func set_thermal_signature(on: bool) -> void:
	if _heat_material == null and on:
		_heat_material = StandardMaterial3D.new()
		_heat_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# Encoded for the thermal compositor. The screen pass displays it as heat.
		_heat_material.albedo_color = Color("f020d1")
	for node in find_children("*", "MeshInstance3D", true, false):
		node.material_overlay = _heat_material if on else null

func _ready() -> void:
	add_to_group("drone_thermal_signatures")
	call_deferred("_configure_default_if_needed")

func _configure_default_if_needed() -> void:
	if not is_instance_valid(_body): configure(friendly, weapon_id, chassis_id)

func configure(is_friendly: bool, selected_weapon: String = "ak47", selected_chassis: String = "quad", legacy_payload_id: String = "", secondary_weapon: String = "") -> void:
	scale = Vector3.ONE * DISPLAY_SCALE
	friendly = is_friendly
	weapon_id = legacy_payload_id if PAYLOAD_IDS.has(legacy_payload_id) else (selected_weapon if PAYLOAD_IDS.has(selected_weapon) else "ak47")
	_primary_weapon = weapon_id
	_secondary_weapon = secondary_weapon if PAYLOAD_IDS.has(secondary_weapon) and secondary_weapon != weapon_id else ""
	chassis_id = selected_chassis if CHASSIS.has(selected_chassis) else "quad"
	if not is_inside_tree(): return
	_rebuild_body()
	_rebuild_payloads()

func set_chassis(selected_chassis: String) -> void:
	if not CHASSIS.has(selected_chassis): return
	chassis_id = selected_chassis
	if is_inside_tree():
		_rebuild_body()
		_rebuild_payloads()

func _rebuild_body() -> void:
	if is_instance_valid(_bank_root):
		remove_child(_bank_root)
		_bank_root.queue_free()
	_bank_root = Node3D.new(); _bank_root.name = "BankVisual"; add_child(_bank_root)
	_body = Node3D.new(); _body.name = "Vanguard" if friendly else "Raider"; _bank_root.add_child(_body)
	_body.scale = Vector3.ONE * BODY_SCALE
	if _uses_ground_gear():
		_bank_root.position.y = -GROUND_HULL_DROP
	_team_trim = null; _team_leds.clear(); _rotor = null; _rotor_player = null
	_attachment_sets.clear()
	_rolling_parts.clear()
	var armor := _mat(Color("596a77") if friendly else Color("847b73"), 0.74, 0.36)
	var dark := _mat(Color("28323b"), 0.42, 0.57)
	var armor_panel := _mat(Color("8b9ba7") if friendly else Color("a29787"), 0.79, 0.31)
	var accent := Color("61d6d1") if friendly else Color("e77770")
	# Common protected centerline and camera/sensor nose.
	var hull := MeshInstance3D.new()
	hull.name = "ArmoredHull"
	hull.mesh = DroneMeshScript.hull()
	hull.material_override = armor
	_body.add_child(hull)
	_box(_body, "SensorHousing", Vector3(0.117, 0.056, 0.065), Vector3(0, -0.014, -0.191), dark)
	_box(_body, "SensorBrow", Vector3(0.125, 0.013, 0.045), Vector3(0, 0.015, -0.201), armor_panel, Vector3(0.14, 0, 0))
	_box(_body, "LowerKeel", Vector3(0.152, 0.031, 0.254), Vector3(0, -0.043, 0.016), dark)
	for side in [-1.0, 1.0]:
		var rail := _box(_body, "HardpointRail", Vector3(0.045, 0.030, 0.147), Vector3(side * 0.129, -0.036, -0.045), dark)
		rail.rotation.y = side * 0.12
	# Overlapping chamfered armor shoulders add a segmented silhouette over the
	# smooth central pressure shell without increasing the hitbox radius.
	for side in [-1.0,1.0]:
		_box(_body,"ArmoredShoulderPanel",Vector3(0.11,0.052,0.15),Vector3(side*0.085,0.009,0.025),armor_panel,Vector3(0,side*0.11,0))
		_box(_body,"ShoulderPanelSeam",Vector3(0.003,0.023,0.09),Vector3(side*0.143,0.008,0.025),dark)
		for fastener in [-1.0,1.0]:
			_cylinder(_body,"ShoulderPanelFastener",0.0035,0.004,Vector3(side*0.143,0.026,0.025+fastener*0.052),_mat(Color("bdc0a4"),0.75,0.28))
	_add_airframe_details(armor, dark)
	# The common hull has one exterior mobility kit. Legacy quad IDs use heli.
	match chassis_id:
		"wheels":
			_build_wheels(armor, dark)
		"tracked":
			_build_tracked(armor, dark)
		"wing":
			_build_wing(armor, dark)
		_:
			_build_heli(armor, dark)
	# Identify the team with a thin top stripe and paired low intensity lamps.
	_team_trim = _box(_bank_root, "TeamSurfaceTrim", Vector3(0.20,0.009,0.022), Vector3(0,0.067,0.02), _mat(accent,0.25,0.4,true))
	for side in [-1.0,1.0]:
		var led := _box(_body,"TeamStatusLED",Vector3(0.018,0.012,0.018),Vector3(side*0.19,-0.035,0.13),_mat(accent,0.1,0.35,true))
		_team_leds.append(led)
	_batch_static_meshes(_body)
	if is_instance_valid(_rotor):
		_rotor_player = AnimationPlayer.new(); _rotor_player.name="AnimationPlayer"; _body.add_child(_rotor_player)
		var library := AnimationLibrary.new(); var animation := Animation.new(); animation.length=0.18; animation.loop_mode=Animation.LOOP_LINEAR
		var track := animation.add_track(Animation.TYPE_VALUE); animation.track_set_path(track, NodePath("HeliDeployment/Rotor:rotation:y")); animation.track_insert_key(track,0.0,0.0); animation.track_insert_key(track,0.18,TAU)
		library.add_animation("rotor-spin",animation); _rotor_player.add_animation_library("",library)
		_rotor_player.play("rotor-spin")

func _register_attachment_set(key: String, nodes: Array[Node]) -> void:
	var module := Node3D.new()
	module.name = key.capitalize() + "Deployment"
	_body.add_child(module)
	for node in nodes:
		if is_instance_valid(node): node.reparent(module,true)
	match key:
		"wheels":
			module.position.y = -_ground_gear_drop(WHEEL_HUB_Y - TIRE_RADIUS)
		"tracked":
			module.position.y = -_ground_gear_drop(TRACK_BOTTOM_Y)
	_attachment_sets[key] = [module]

func _uses_ground_gear() -> bool:
	return chassis_id == "wheels" or chassis_id == "tracked"

func _ground_gear_drop(bottom_y: float) -> float:
	return (GROUND_CONTACT_DEPTH / DISPLAY_SCALE - GROUND_HULL_DROP) / BODY_SCALE + bottom_y

func _add_airframe_details(armor: Material, dark: Material) -> void:
	# Recessed dorsal electronics bay and replaceable split armor panels.
	var panel_finish := _mat(Color("465765"), 0.66, 0.46)
	var titanium := _mat(Color("bac4c8"), 0.83, 0.30)
	var marking := _mat(Color("bf8449"), 0.35, 0.48)
	var optic_glass := _mat(Color("27404e"), 0.68, 0.13)
	_box(_body,"DorsalBay",Vector3(0.21,0.008,0.18),Vector3(0,0.063,-0.026),dark)
	for side in [-1.0,1.0]:
		_box(_body,"DorsalArmor",Vector3(0.088,0.006,0.145),Vector3(side*0.051,0.070,-0.026),panel_finish)
		_box(_body,"ShoulderRail",Vector3(0.009,0.009,0.16),Vector3(side*0.116,0.058,-0.018),titanium)
		for index in 4:
			_box(_body,"HeatExchangerSlot",Vector3(0.058,0.003,0.005),Vector3(side*0.051,0.075,0.005+index*0.015),dark)
		for fore in [-1.0,1.0]:
			_cylinder(_body,"ArmorLock",0.004,0.003,Vector3(side*0.080,0.075,-0.026+fore*0.059),titanium)
		_box(_body, "SideServicePlate", Vector3(0.009, 0.026, 0.095), Vector3(side * 0.134, -0.009, 0.052), dark)
		for slot in 4:
			_box(_body, "SideVent", Vector3(0.004, 0.011, 0.007), Vector3(side * 0.140, -0.009, 0.030 + slot * 0.013), titanium, Vector3(-0.31, 0, 0))
		_box(_body, "HardpointStripe", Vector3(0.006, 0.013, 0.033), Vector3(side * 0.152, -0.029, -0.048), marking)
	_box(_body,"FrontBumper",Vector3(0.21,0.025,0.015),Vector3(0,-0.035,-0.154),dark)
	# Nose camera: armored bezel, lens and twin ranging apertures.
	_cylinder(_body, "CameraBezel", 0.022, 0.013, Vector3(0, -0.014, -0.226), titanium, Vector3(PI/2, 0, 0))
	_cylinder(_body, "LensRetainer", 0.018, 0.009, Vector3(0, -0.014, -0.233), dark, Vector3(PI/2, 0, 0))
	_ellipsoid(_body, "CameraGlass", Vector3(0.029, 0.029, 0.008), Vector3(0, -0.014, -0.237), optic_glass)
	for side in [-1.0,1.0]:
		_cylinder(_body,"RangeSensor",0.006,0.009,Vector3(side*0.039,-0.014,-0.224),optic_glass,Vector3(PI/2,0,0))
		_cylinder(_body,"PanelFastener",0.0045,0.003,Vector3(side*0.102,0.063,0.03),dark)
		_box(_body,"AccessPanelSeam",Vector3(0.004,0.002,0.12),Vector3(side*0.105,0.062,0.02),dark)
	# Fine cooling slots and a raised service hatch on the dorsal spine.
	_box(_body,"ServiceHatch",Vector3(0.11,0.006,0.075),Vector3(0,0.064,0.035),dark)
	for slot in range(5):
		_box(_body,"CoolingVent",Vector3(0.005,0.002,0.047),Vector3(-0.032+slot*0.016,0.068,0.035),armor)
	for side in [-1.0,1.0]:
		for fore in [-1.0,1.0]:
			_cylinder(_body,"HatchBolt",0.004,0.004,Vector3(side*0.048,0.068,0.035+fore*0.028),armor)

func _build_tracked(armor: Material, dark: Material) -> void:
	var modules:Array[Node]=[_box(_body,"TrackSuspension",Vector3(0.29,0.050,0.34),Vector3(0,-0.075,0.02),armor)]
	var rubber := _mat(Color("14191b"), 0.0, 0.86)
	var shoe_metal := _mat(Color("89939a"), 0.36, 0.66)
	for side in [-1.0,1.0]:
		# Open belt with rounded ends leaves the road wheels visible.
		var belt := MeshInstance3D.new()
		belt.name = "ContinuousTrack"
		belt.mesh = DroneMeshScript.track_belt()
		belt.material_override = rubber
		belt.position = Vector3(side * 0.19, -0.105, 0.03)
		_body.add_child(belt)
		modules.append(belt)
		var perimeter := 0.62 + TAU * 0.057
		for i in 44:
			var distance := perimeter * float(i) / 44.0
			var point := DroneMeshScript.track_point(distance)
			var tangent := (DroneMeshScript.track_point(fmod(distance + 0.0001, perimeter)) - point).normalized()
			var pos := Vector3(side * 0.19, -0.105 + point.y, 0.03 + point.x)
			modules.append(_box(_body, "TrackShoe", Vector3(0.108,0.010,0.013), pos, shoe_metal, Vector3(-atan2(tangent.y, tangent.x),0,0)))
		for z in [-0.13,0.16]:
			var wheel_pos := Vector3(side*0.205,-0.105,z)
			var road_wheel := _cylinder(_body,"RoadWheel",0.039,0.025,wheel_pos,rubber,Vector3(0,0,PI/2))
			modules.append(road_wheel)
			road_wheel.set_meta("mobility_profile","tracked")
			_rolling_parts.append(road_wheel)
			modules.append(_cylinder(_body,"RoadWheelHub",0.022,0.029,wheel_pos+Vector3(side*0.003,0,0),armor,Vector3(0,0,PI/2)))
			for bolt in range(6):
				var angle := TAU * float(bolt) / 6.0
				modules.append(_cylinder(_body,"RoadWheelBolt",0.003,0.004,Vector3(side*0.222,-0.105+sin(angle)*0.015,z+cos(angle)*0.015),dark,Vector3(0,0,PI/2)))
			var upper_mount := Vector3(side*0.12, _ground_gear_drop(TRACK_BOTTOM_Y), z)
			modules.append(_rod_between(_body, "SuspensionLink", upper_mount, wheel_pos + Vector3(0, 0.025, 0), 0.009, armor))
	_register_attachment_set("tracked",modules)

func _build_wheels(armor: Material, dark: Material) -> void:
	var modules: Array[Node] = []
	for side in [-1.0, 1.0]:
		for fore in [-1.0, 1.0]:
			var hub := Vector3(side * 0.17, WHEEL_HUB_Y, fore * 0.13)
			var wheel := Node3D.new()
			wheel.name = "WheelAssembly"
			_body.add_child(wheel)
			wheel.position = hub
			wheel.set_meta("mobility_profile", "wheels")
			modules.append(wheel)
			_rolling_parts.append(wheel)
			_cylinder(wheel, "Tire", TIRE_RADIUS, 0.028, Vector3.ZERO, dark, Vector3(0, 0, PI / 2))
			_cylinder(wheel, "WheelHub", 0.030, 0.032, Vector3.ZERO, armor, Vector3(0, 0, PI / 2))
			for lug in range(8):
				var angle := TAU * float(lug) / 8.0
				var tread_pos := Vector3(0, cos(angle), sin(angle)) * 0.053
				_box(wheel, "TireTread", Vector3(0.034, 0.008, 0.012), tread_pos, armor, Vector3(angle, 0, 0))
			for bolt in range(5):
				var angle := TAU * float(bolt) / 5.0
				var bolt_pos := Vector3(side * 0.018, sin(angle) * 0.018, cos(angle) * 0.018)
				_cylinder(wheel, "RimBolt", 0.003, 0.004, bolt_pos, dark, Vector3(0, 0, PI / 2))
			var upper_mount := Vector3(side * 0.11, _ground_gear_drop(WHEEL_HUB_Y - TIRE_RADIUS), fore * 0.11)
			modules.append(_rod_between(_body, "SuspensionStrut", upper_mount, hub, 0.012, armor))
	_register_attachment_set("wheels", modules)

func _build_heli(armor: Material, dark: Material) -> void:
	var modules:Array[Node]=[]
	modules.append(_box(_body,"TailBoom",Vector3(0.045,0.045,0.22),Vector3(0,0.015,0.20),armor))
	modules.append(_box(_body,"TailFin",Vector3(0.018,0.09,0.04),Vector3(0,0.035,0.29),dark))
	modules.append(_box(_body,"TailBoomSeam",Vector3(0.003,0.003,0.12),Vector3(0.025,0.039,0.20),dark))
	_rotor = Node3D.new(); _rotor.name="Rotor"; _rotor.position=Vector3(0,0.12,0.015); _body.add_child(_rotor)
	_box(_rotor,"RotorBlade",Vector3(0.48,0.008,0.025),Vector3.ZERO,dark)
	var cross_blade := _box(_rotor,"RotorBlade",Vector3(0.48,0.008,0.025),Vector3.ZERO,dark)
	cross_blade.rotation.y=PI/2
	_cylinder(_rotor,"RotorHub",0.022,0.025,Vector3(0,0.008,0),armor)
	modules.append(_rotor)
	modules.append(_cylinder(_body,"RotorMast",0.012,0.12,Vector3(0,0.08,0.015),dark))
	for side in [-1.0,1.0]: modules.append(_box(_body,"LandingRunner",Vector3(0.025,0.012,0.32),Vector3(side*0.16,-0.15,0.03),dark))
	_register_attachment_set("heli",modules)

func _build_wing(armor: Material, dark: Material) -> void:
	var modules: Array[Node] = []
	var exhaust := _mat(Color("91a7aa"), 0.75, 0.34)
	for side in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		wing.name = "SweptWing"
		wing.mesh = DroneMeshScript.swept_wing(side)
		wing.material_override = armor
		wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_body.add_child(wing)
		modules.append(wing)
		modules.append(_box(_body, "WingRootFairing", Vector3(0.075, 0.050, 0.23), Vector3(side * 0.121, 0.008, 0.014), dark))
		modules.append(_box(_body, "TailFin", Vector3(0.016, 0.095, 0.088), Vector3(side * 0.091, 0.048, 0.236), armor, Vector3(0, 0, -side * 0.30)))
		modules.append(_cylinder(_body, "ThrustHousing", 0.026, 0.124, Vector3(side * 0.16, 0.008, 0.115), dark, Vector3(PI / 2, 0, 0)))
		modules.append(_cylinder(_body, "ThrustTrim", 0.020, 0.010, Vector3(side * 0.16, 0.008, 0.179), exhaust, Vector3(PI / 2, 0, 0)))
		var lamp_color := Color("64c9e8") if side < 0 else Color("e66b56")
		modules.append(_box(_body, "NavigationLamp", Vector3(0.014, 0.008, 0.015), Vector3(side * 0.361, 0.015, 0.076), _mat(lamp_color, 0.1, 0.3, true)))
	_register_attachment_set("wing", modules)

func _rod_between(parent: Node3D, name: String, start: Vector3, end: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var delta := end - start
	var rod := _cylinder(parent,name,radius,delta.length(),(start+end)*0.5,material)
	rod.quaternion = Quaternion(Vector3.UP,delta.normalized())
	return rod

func _mat(color: Color, metallic: float, roughness: float, emissive: bool=false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color=color; m.metallic=metallic; m.roughness=roughness
	if emissive: m.emission_enabled=true; m.emission=color; m.emission_energy_multiplier=0.65
	Finish.apply_metal_grain(m)
	return m

func set_inspection_pose() -> void:
	if is_instance_valid(_rotor_player):
		_rotor_player.seek(0.022, true)
		_rotor_player.pause()
	for node in find_children("*", "MeshInstance3D", true, false):
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var serial := Label3D.new()
	serial.text = "VANGUARD  07"
	serial.font_size = 32
	serial.pixel_size = 0.00035
	serial.outline_size = 0
	serial.modulate = Color("aebec9")
	serial.position = Vector3(0, 0.078, -0.053)
	serial.rotation = Vector3(-PI / 2.0, PI, 0)
	_body.add_child(serial)

func _ellipsoid(parent: Node3D, name: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name=name
	var mesh := SphereMesh.new()
	mesh.radius=0.5
	mesh.height=1.0
	mesh.radial_segments=16
	mesh.rings=8
	item.mesh=mesh
	item.scale=size
	item.position=pos
	item.material_override=material
	item.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(item)
	return item

func _box(parent: Node3D, name: String, size: Vector3, pos: Vector3, material: Material, rot: Vector3=Vector3.ZERO) -> MeshInstance3D:
	var item := MeshInstance3D.new(); item.name=name; item.mesh=DroneMeshScript.panel(size); item.position=pos; item.rotation=rot; item.material_override=material; item.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; parent.add_child(item); return item

func _cylinder(parent: Node3D, name: String, radius: float, height: float, pos: Vector3, material: Material, rot: Vector3=Vector3.ZERO) -> MeshInstance3D:
	var item := MeshInstance3D.new(); item.name=name; var mesh := CylinderMesh.new(); mesh.top_radius=radius; mesh.bottom_radius=radius; mesh.height=height; mesh.radial_segments=16; item.mesh=mesh; item.position=pos; item.rotation=rot; item.material_override=material; item.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; parent.add_child(item); return item

func _batch_static_meshes(parent: Node3D) -> void:
	for child in parent.get_children():
		if child is Node3D and not child is MeshInstance3D: _batch_static_meshes(child)
	var groups: Dictionary = {}
	var original_instances: Array[MeshInstance3D] = []
	for child in parent.get_children():
		if not child is MeshInstance3D: continue
		var instance := child as MeshInstance3D
		if instance.mesh == null or _rolling_parts.has(instance) or _team_leds.has(instance): continue
		original_instances.append(instance)
		for surface in instance.mesh.get_surface_count():
			var material := instance.material_override if instance.material_override != null else instance.mesh.surface_get_material(surface)
			if material == null: continue
			var key := str(material.get_instance_id())
			if not groups.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"tool":tool,"material":material}
			groups[key]["tool"].append_from(instance.mesh,surface,instance.transform)
	for group in groups.values():
		var merged := MeshInstance3D.new()
		merged.name = "BatchedStaticHardware"
		merged.mesh = group["tool"].commit()
		merged.material_override = group["material"]
		merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(merged)
	for instance in original_instances: instance.free()

func _rebuild_payloads() -> void:
	for mount in [_left_mount, _right_mount]:
		if is_instance_valid(mount):
			remove_child(mount)
			mount.queue_free()
	_left_mount = _build_mount(_primary_weapon, -1.0)
	_right_mount = _build_mount(_secondary_weapon, 1.0) if not _secondary_weapon.is_empty() else null
	_select_active_mount()
	if GameState.thermal_view: set_thermal_signature(true)

func _build_mount(id: String, side: float) -> Node3D:
	var model := PayloadBuilderScript.build(id)
	var bounds := _payload_bounds(model)
	var center := bounds.get_center()
	var radius := 0.0
	for corner in _aabb_corners(bounds):
		radius = maxf(radius, center.distance_to(corner))
	var scale_factor := 0.13 / maxf(radius, 0.0001)
	model.scale = Vector3.ONE * scale_factor
	model.position = -center * scale_factor
	var mount := Node3D.new()
	mount.name = "PrimaryLeft" if side < 0.0 else "SecondaryRight"
	mount.position = Vector3(side * 0.152, -0.075, -0.085)
	mount.add_child(model)
	add_child(mount)
	return mount

func _select_active_mount() -> void:
	if is_instance_valid(_payload_gimbal):
		_payload_gimbal.rotation = Vector3.ZERO
	_payload_gimbal = _right_mount if weapon_id == _secondary_weapon and is_instance_valid(_right_mount) else _left_mount
	_payload = _payload_gimbal.get_child(0) as Node3D if is_instance_valid(_payload_gimbal) else null
	if is_instance_valid(_payload_gimbal):
		_payload_gimbal.rotation = Vector3(_aim_pitch, _aim_yaw, 0.0)
	_update_payload_visibility()

func set_loadout(primary: String, secondary: String, active: String) -> void:
	primary = primary if PAYLOAD_IDS.has(primary) else "ak47"
	secondary = secondary if PAYLOAD_IDS.has(secondary) and secondary != primary else ""
	var changed := primary != _primary_weapon or secondary != _secondary_weapon
	var next_weapon := active if active == primary or (not secondary.is_empty() and active == secondary) else primary
	var active_changed := weapon_id != next_weapon
	_primary_weapon = primary
	_secondary_weapon = secondary
	weapon_id = next_weapon
	if not is_inside_tree() or not is_instance_valid(_bank_root): return
	if changed or not is_instance_valid(_left_mount):
		_rebuild_payloads()
	elif active_changed:
		_select_active_mount()

func _payload_bounds(root: Node) -> AABB:
	var points:Array[Vector3]=[]; _collect_mesh_bounds(root,Transform3D.IDENTITY,points)
	if points.is_empty(): return AABB(Vector3.ZERO,Vector3.ONE)
	var b:=AABB(points[0],Vector3.ZERO)
	for p in points: b=b.expand(p)
	return b

func _collect_mesh_bounds(node: Node, parent: Transform3D, points: Array[Vector3]) -> void:
	var t:=parent; if node is Node3D: t=parent*(node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh!=null:
		for p in _aabb_corners((node as MeshInstance3D).get_aabb()): points.append(t*p)
	for child in node.get_children(): _collect_mesh_bounds(child,t,points)

func _aabb_corners(b: AABB) -> Array[Vector3]:
	var a:Array[Vector3]=[]; for x in [b.position.x,b.end.x]:
		for y in [b.position.y,b.end.y]:
			for z in [b.position.z,b.end.z]: a.append(Vector3(x,y,z))
	return a

func set_weapon(selected_weapon: String) -> void:
	if selected_weapon == _primary_weapon or selected_weapon == _secondary_weapon:
		set_loadout(_primary_weapon, _secondary_weapon, selected_weapon)
	else:
		set_loadout(selected_weapon, "", selected_weapon)

func set_payload_visible(visible: bool) -> void:
	payload_enabled = visible
	_update_payload_visibility()

func _update_payload_visibility() -> void:
	if is_instance_valid(_left_mount): _left_mount.get_child(0).visible = payload_enabled and not dead
	if is_instance_valid(_right_mount): _right_mount.get_child(0).visible = payload_enabled and not dead

func get_payload() -> Node3D: return _payload

func aim_payload_at(world_point: Vector3, both := false) -> void:
	if not world_point.is_finite() or not is_instance_valid(_payload_gimbal): return
	_payload_gimbal.rotation = _mount_aim(_payload_gimbal, world_point)
	_aim_pitch = _payload_gimbal.rotation.x
	_aim_yaw = _payload_gimbal.rotation.y
	var other := _right_mount if _payload_gimbal == _left_mount else _left_mount
	if is_instance_valid(other):
		other.rotation = _mount_aim(other, world_point) if both else Vector3.ZERO

func _mount_aim(mount: Node3D, world_point: Vector3) -> Vector3:
	var direction := global_basis.inverse() * (world_point - mount.global_position)
	if direction.length_squared() < 0.000001: return mount.rotation
	return Vector3(atan2(direction.y, Vector2(direction.x, direction.z).length()), atan2(-direction.x, -direction.z), 0.0)

func get_muzzle_global(mount_weapon := "") -> Vector3:
	var gimbal := _payload_gimbal
	if mount_weapon == _primary_weapon: gimbal = _left_mount
	elif mount_weapon == _secondary_weapon and not mount_weapon.is_empty(): gimbal = _right_mount
	if is_instance_valid(gimbal):
		var muzzle := gimbal.get_child(0).find_child("Muzzle", true, false) as Node3D
		if is_instance_valid(muzzle): return muzzle.global_position
		return gimbal.to_global(Vector3(0, 0, -0.28))
	return to_global(Vector3(0, -0.08, -0.28))

func begin_crash(velocity: Vector3) -> Node3D:
	if crash_hidden: return null
	set_crash_hidden(true)
	var effects := get_tree().get_first_node_in_group("drone_combat_effects")
	if effects == null: return null
	return effects.call("crash", self, velocity if velocity.is_finite() else Vector3.ZERO) as Node3D

func set_crash_hidden(hidden: bool) -> void:
	crash_hidden = hidden
	visible = not hidden

func make_wreck_visual(parent: Node3D) -> Node3D:
	var model := Node3D.new()
	model.name = "DroneWreck"
	parent.add_child(model)
	# Preserve the assembled chassis and loadout. Mesh resources stay shared.
	for part in [_bank_root, _left_mount, _right_mount]:
		if is_instance_valid(part):
			var copy := part.duplicate(0) as Node3D
			copy.process_mode = Node.PROCESS_MODE_DISABLED
			model.add_child(copy)
	for led in [_team_trim] + _team_leds:
		if not is_instance_valid(led): continue
		var copy := model.get_node_or_null(get_path_to(led)) as MeshInstance3D
		if is_instance_valid(copy): copy.hide()
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = null
		var original := mesh.material_override as StandardMaterial3D
		if original == null or original.emission_enabled or original.metallic < 0.55: continue
		var finish := original.duplicate() as StandardMaterial3D
		finish.albedo_color = original.albedo_color.lerp(Color("252225"), 0.38)
		finish.roughness = maxf(original.roughness, 0.68)
		mesh.material_override = finish
	return model

func apply_motion(velocity: Vector3, yaw: float, pitch: float, is_dead: bool=false) -> void:
	_velocity=velocity if velocity.is_finite() else Vector3.ZERO; dead=is_dead; _aim_pitch=clampf(pitch,-1.55,1.55)
	if is_instance_valid(_payload_gimbal): _payload_gimbal.rotation=Vector3(_aim_pitch,_aim_yaw,0.0)
	if not is_instance_valid(_bank_root): return
	var local_velocity:=Vector3(cos(yaw)*_velocity.x-sin(yaw)*_velocity.z,0,sin(yaw)*_velocity.x+cos(yaw)*_velocity.z)
	var target:=clampf(-local_velocity.x*0.10,-BANK_LIMIT,BANK_LIMIT)
	if _uses_ground_gear(): target = 0.0
	elif dead: target=clampf(target+deg_to_rad(7),-deg_to_rad(17),deg_to_rad(17))
	_bank_root.rotation.z=move_toward_angle(_bank_root.rotation.z,target,BANK_RESPONSE*get_process_delta_time())
	if chassis_id == "wing":
		_bank_root.rotation.x = move_toward(_bank_root.rotation.x, _aim_pitch * 0.45, 1.8 * get_process_delta_time())
	var rolling_speed := local_velocity.z
	var movement_profile := "heli" if chassis_id == "quad" else chassis_id
	for wheel in _rolling_parts:
		if is_instance_valid(wheel) and String(wheel.get_meta("mobility_profile","")) == movement_profile:
			var radius := TIRE_RADIUS if movement_profile == "wheels" else 0.039
			wheel.rotate(Vector3.RIGHT, rolling_speed * get_process_delta_time() / (radius * BODY_SCALE))
	_update_payload_visibility()
	for led in _team_leds: if is_instance_valid(led): led.visible=not dead

static func move_toward_angle(current: float, target: float, max_delta: float) -> float:
	var difference:=wrapf(target-current,-PI,PI)
	return current+difference if absf(difference)<=max_delta else current+signf(difference)*max_delta
