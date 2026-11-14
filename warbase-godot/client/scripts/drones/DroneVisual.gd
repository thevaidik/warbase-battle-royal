class_name DroneVisual
extends Node3D
## Procedural drone hardware. Ground gear extends to the floor beneath the hit sphere.

const PayloadBuilderScript = preload("res://scripts/drones/DronePayloadBuilder.gd")
const DroneMeshScript = preload("res://scripts/drones/DroneMesh.gd")
const DroneVisualResourcesScript = preload("res://scripts/drones/DroneVisualResources.gd")
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
const TIRE_RADIUS := 0.142
const TIRE_WIDTH := 0.092
const WHEEL_HUB_Y := -0.065
const TRACK_BOTTOM_Y := -0.161
var friendly := true
var weapon_id := "ak47"
var chassis_id := "quad"
var dead := false
var crash_hidden := false
var payload_enabled := true
var _track_shoes: Array[Node3D] = []
var _steer_parts: Array[Node3D] = []
var _wheel_struts: Array[Node3D] = []
var _prev_rolling_speed := 0.0
var _last_motion_yaw := 0.0
var _motion_yaw_initialized := false
var _turret: Node3D
var _velocity := Vector3.ZERO
var _body: Node3D
var _bank_root: Node3D
var _payload_gimbal: Node3D
var _payload: Node3D
var _left_mount: Node3D
var _right_mount: Node3D
var _center_mount: Node3D
var _primary_weapon := "ak47"
var _secondary_weapon := ""
var _tertiary_weapon := "hmg"
var _recoil_kick := 0.0

func kick_recoil(amount: float = 0.035) -> void:
	_recoil_kick = minf(_recoil_kick + amount, 0.095)
var _rotor: Node3D
var _rotor_player: AnimationPlayer
var _aim_pitch := 0.0
var _aim_yaw := 0.0
var _team_trim: MeshInstance3D
var _team_leds: Array[MeshInstance3D] = []
var _attachment_sets: Dictionary = {}
var _rolling_parts: Array[Node3D] = []
var _built_friendly := false
var _built_primary := ""
var _built_secondary := ""
var _built_chassis := ""
var _is_built := false
var deferred_construction := false
static var _heat_material: StandardMaterial3D

func is_built() -> bool:
	return _is_built and is_instance_valid(_body)

func get_primary_weapon() -> String:
	return _primary_weapon

func get_secondary_weapon() -> String:
	return _secondary_weapon

func get_active_weapon() -> String:
	return weapon_id

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
	if deferred_construction: return
	var parent = get_parent()
	if is_instance_valid(parent) and parent.get_meta("deferred_visual", false):
		deferred_construction = true
		return
	if not is_instance_valid(_body): configure(friendly, weapon_id, chassis_id)

func configure(is_friendly: bool, selected_weapon: String = "ak47", selected_chassis: String = "quad", legacy_payload_id: String = "", secondary_weapon: String = "", tertiary_weapon: String = "") -> void:
	var target_friendly: bool = is_friendly
	var target_weapon: String = legacy_payload_id if PAYLOAD_IDS.has(legacy_payload_id) else (selected_weapon if PAYLOAD_IDS.has(selected_weapon) else "ak47")
	var target_secondary: String = secondary_weapon if PAYLOAD_IDS.has(secondary_weapon) and secondary_weapon != target_weapon else ""
	var target_tertiary: String = tertiary_weapon if PAYLOAD_IDS.has(tertiary_weapon) else (GameState.selected_tertiary if GameState != null and PAYLOAD_IDS.has(GameState.selected_tertiary) else "hmg")
	var target_chassis: String = selected_chassis if CHASSIS.has(selected_chassis) else "quad"

	prepare_body(target_friendly, target_chassis)
	prepare_payloads(target_weapon, target_secondary, target_weapon, target_tertiary)
	finalize_visual()

func prepare_body(is_friendly: bool, selected_chassis: String) -> void:
	scale = Vector3.ONE * DISPLAY_SCALE
	friendly = is_friendly
	chassis_id = selected_chassis if CHASSIS.has(selected_chassis) else "quad"
	if not is_inside_tree(): return
	if _is_built and is_instance_valid(_body) and _built_friendly == friendly and _built_chassis == chassis_id:
		return
	_rebuild_body()
	_built_friendly = friendly
	_built_chassis = chassis_id

func prepare_payloads(pri: String, sec: String = "", active: String = "", tert: String = "") -> void:
	var target_pri := pri if PAYLOAD_IDS.has(pri) else "ak47"
	var target_sec := sec if PAYLOAD_IDS.has(sec) and sec != target_pri else ""
	var target_tert := tert if PAYLOAD_IDS.has(tert) else (GameState.selected_tertiary if GameState != null and PAYLOAD_IDS.has(GameState.selected_tertiary) else "hmg")
	var target_active := active if PAYLOAD_IDS.has(active) else target_pri
	_primary_weapon = target_pri
	_secondary_weapon = target_sec
	_tertiary_weapon = target_tert
	weapon_id = target_active
	if not is_inside_tree(): return
	if _built_primary == target_pri and _built_secondary == target_sec and is_instance_valid(_left_mount):
		_select_active_mount()
		return
	_rebuild_payloads()
	_built_primary = target_pri
	_built_secondary = target_sec
	_select_active_mount()

func finalize_visual() -> void:
	_is_built = true
	deferred_construction = false
	visible = true
	_apply_visual_lod()
	_select_active_mount()

func set_chassis(selected_chassis: String) -> void:
	if not CHASSIS.has(selected_chassis): return
	if selected_chassis == chassis_id and _is_built and is_instance_valid(_body): return
	chassis_id = selected_chassis
	if is_inside_tree():
		_rebuild_body()
		_rebuild_payloads()
		_built_chassis = chassis_id
		_is_built = true

func _rebuild_body() -> void:
	if is_instance_valid(_bank_root):
		remove_child(_bank_root)
		_bank_root.queue_free()
	_bank_root = Node3D.new(); _bank_root.name = "BankVisual"; add_child(_bank_root)
	_body = Node3D.new(); _body.name = "Vanguard" if friendly else "Raider"; _bank_root.add_child(_body)
	_body.scale = Vector3.ONE * BODY_SCALE
	_body.set_meta("batch_cache_key", "body_%s_%s" % [chassis_id, "friendly" if friendly else "enemy"])
	if _uses_ground_gear():
		_bank_root.position.y = -GROUND_HULL_DROP
	if is_instance_valid(_turret): _turret.position.y = 0.065 - (GROUND_HULL_DROP if _uses_ground_gear() else 0.0)
	_team_trim = null; _team_leds.clear(); _rotor = null; _rotor_player = null
	_attachment_sets.clear()
	_rolling_parts.clear()
	_track_shoes.clear()
	_steer_parts.clear()
	_wheel_struts.clear()
	_motion_yaw_initialized = false
	var armor := _mat(Color("4d5a64") if friendly else Color("6e655c"), 0.74, 0.38)
	var dark := _mat(Color("222a30"), 0.45, 0.60)
	var armor_panel := _mat(Color("63727d") if friendly else Color("7f7466"), 0.78, 0.34)
	var accent := Color("4a7282") if friendly else Color("8a6b58")
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
	_apply_visual_lod()

func _register_attachment_set(key: String, nodes: Array[Node]) -> void:
	var module := Node3D.new()
	module.name = key.capitalize() + "Deployment"
	module.set_meta("batch_cache_key", "module_%s_%s" % [key, "friendly" if friendly else "enemy"])
	_body.add_child(module)
	for node in nodes:
		if is_instance_valid(node): node.reparent(module,true)
	match key:
		"wheels":
			module.position.y = -_ground_gear_drop(WHEEL_HUB_Y - (TIRE_RADIUS + 0.0152))
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
		var shoes := MultiMeshInstance3D.new()
		shoes.name = "InstancedTrackShoes"
		shoes.multimesh = MultiMesh.new()
		shoes.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		shoes.multimesh.mesh = DroneMeshScript.panel(Vector3(0.108,0.010,0.013))
		shoes.multimesh.instance_count = 44
		shoes.material_override = shoe_metal
		shoes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shoes.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		shoes.set_meta("side", side)
		shoes.set_meta("phase", 0.0)
		_body.add_child(shoes)
		_track_shoes.append(shoes)
		modules.append(shoes)
		_update_track_instances(shoes, 0.0)
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
	var tire_rubber := _mat(Color("16191c"), 0.04, 0.94)
	var rim_alloy := _mat(Color("3a4248"), 0.85, 0.32)
	var beadlock_ring := _mat(Color("464e56"), 0.82, 0.28)
	var caliper_gunmetal := _mat(Color("282d32"), 0.72, 0.36)
	var rotor_steel := _mat(Color("8a939a"), 0.92, 0.22)
	var spring_color := _mat(Color("202428"), 0.45, 0.55)
	for fore in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			var hub := Vector3(side * 0.235, WHEEL_HUB_Y, fore * 0.165)
			var strut_mount := Node3D.new()
			strut_mount.name = "MonsterStrutMount"
			strut_mount.set_meta("batch_cache_key", "strut_s%.0f_f%.0f" % [side, fore])
			_body.add_child(strut_mount)
			strut_mount.position = hub
			modules.append(strut_mount)
			_wheel_struts.append(strut_mount)
			var steer_node := Node3D.new()
			steer_node.name = "MonsterSteerNode"
			steer_node.set_meta("batch_cache_key", "steer_s%.0f" % side)
			strut_mount.add_child(steer_node)
			if fore < 0.0:
				_steer_parts.append(steer_node)
			var wheel := Node3D.new()
			wheel.name = "MonsterWheelAssembly"
			wheel.set_meta("batch_cache_key", "wheel_%s_s%.0f_f%.0f" % ["friendly" if friendly else "enemy", side, fore])
			steer_node.add_child(wheel)
			wheel.set_meta("mobility_profile", "wheels")
			wheel.set_meta("side", side)
			wheel.set_meta("fore", fore)
			modules.append(wheel)
			_rolling_parts.append(wheel)
			_cylinder(wheel, "TireCarcass", TIRE_RADIUS, TIRE_WIDTH, Vector3.ZERO, tire_rubber, Vector3(0, 0, PI / 2))
			_cylinder(wheel, "InnerBevel", TIRE_RADIUS * 0.97, TIRE_WIDTH * 0.15, Vector3(side * (TIRE_WIDTH * 0.42), 0, 0), tire_rubber, Vector3(0, 0, PI / 2))
			for lug in range(14):
				var angle: float = TAU * float(lug) / 14.0
				var chevron_angle: float = side * 0.32
				var lug_pos := Vector3(0, cos(angle), sin(angle)) * (TIRE_RADIUS - 0.002)
				_box(wheel, "MonsterLug", Vector3(TIRE_WIDTH * 0.72, 0.016, 0.026), lug_pos, tire_rubber, Vector3(angle, 0, chevron_angle))
				var cleat_pos := Vector3(side * (TIRE_WIDTH * 0.44), cos(angle) * (TIRE_RADIUS * 0.88), sin(angle) * (TIRE_RADIUS * 0.88))
				_box(wheel, "SideBite", Vector3(0.012, 0.014, 0.022), cleat_pos, tire_rubber, Vector3(angle, 0, 0))
			_cylinder(wheel, "RimBarrel", 0.076, TIRE_WIDTH * 0.90, Vector3.ZERO, rim_alloy, Vector3(0, 0, PI / 2))
			_cylinder(wheel, "BeadlockRing", 0.084, 0.014, Vector3(side * (TIRE_WIDTH * 0.44), 0, 0), beadlock_ring, Vector3(0, 0, PI / 2))
			for bolt in range(10):
				var b_angle: float = TAU * float(bolt) / 10.0
				var b_pos := Vector3(side * (TIRE_WIDTH * 0.455), sin(b_angle) * 0.078, cos(b_angle) * 0.078)
				_cylinder(wheel, "BeadBolt", 0.0035, 0.006, b_pos, dark, Vector3(0, 0, PI / 2))
			for spoke in range(6):
				var s_angle: float = TAU * float(spoke) / 6.0
				var s_pos := Vector3(side * (TIRE_WIDTH * 0.30), sin(s_angle) * 0.046, cos(s_angle) * 0.046)
				_box(wheel, "RimSpoke", Vector3(0.018, 0.012, 0.040), s_pos, rim_alloy, Vector3(s_angle, 0, 0))
			_cylinder(wheel, "CenterHub", 0.034, 0.040, Vector3(side * (TIRE_WIDTH * 0.35), 0, 0), armor, Vector3(0, 0, PI / 2))
			for l in range(6):
				var l_angle: float = TAU * float(l) / 6.0
				var l_pos := Vector3(side * (TIRE_WIDTH * 0.40), sin(l_angle) * 0.022, cos(l_angle) * 0.022)
				_cylinder(wheel, "LugNut", 0.004, 0.008, l_pos, dark, Vector3(0, 0, PI / 2))
			_cylinder(wheel, "LockingDial", 0.014, 0.010, Vector3(side * (TIRE_WIDTH * 0.42), 0, 0), _mat(Color("3c444a") if friendly else Color("48453e"), 0.7, 0.35), Vector3(0, 0, PI / 2))
			_cylinder(steer_node, "BrakeRotor", 0.065, 0.008, Vector3(side * (TIRE_WIDTH * 0.14), 0, 0), rotor_steel, Vector3(0, 0, PI / 2))
			_box(steer_node, "BrakeCaliper", Vector3(0.026, 0.032, 0.044), Vector3(side * (TIRE_WIDTH * 0.14), 0.048, 0.018), caliper_gunmetal)
			var upper_mount := Vector3(side * 0.12, _ground_gear_drop(WHEEL_HUB_Y - TIRE_RADIUS) + 0.05, fore * 0.14)
			modules.append(_rod_between(_body, "ShockBody", upper_mount, hub, 0.015, dark))
			modules.append(_rod_between(_body, "ShockShaft", upper_mount.lerp(hub, 0.5), hub, 0.009, _mat(Color("e8ecef"), 0.98, 0.1)))
			for coil in range(5):
				var c_t: float = 0.22 + float(coil) * 0.13
				var coil_pos := upper_mount.lerp(hub, c_t)
				modules.append(_cylinder(_body, "SpringCoil", 0.022, 0.008, coil_pos, spring_color, Vector3(0, 0, PI / 2)))
			modules.append(_rod_between(_body, "ControlArmLower", Vector3(side * 0.08, -0.05, fore * 0.14), hub + Vector3(0, -0.03, 0), 0.011, armor))
			modules.append(_rod_between(_body, "ControlArmUpper", Vector3(side * 0.08, 0.01, fore * 0.14), hub + Vector3(0, 0.03, 0), 0.010, armor))
	_register_attachment_set("wheels", modules)

func _build_heli(armor: Material, dark: Material) -> void:
	var modules:Array[Node]=[]
	modules.append(_box(_body,"TailBoom",Vector3(0.045,0.045,0.22),Vector3(0,0.015,0.20),armor))
	modules.append(_box(_body,"TailFin",Vector3(0.018,0.09,0.04),Vector3(0,0.035,0.29),dark))
	modules.append(_box(_body,"TailBoomSeam",Vector3(0.003,0.003,0.12),Vector3(0.025,0.039,0.20),dark))
	_rotor = Node3D.new(); _rotor.name="Rotor"; _rotor.position=Vector3(0,0.12,0.015); _rotor.set_meta("batch_cache_key", "rotor_%s" % ("friendly" if friendly else "enemy")); _body.add_child(_rotor)
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
	return DroneVisualResourcesScript.get_material(color, metallic, roughness, emissive)

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

func _get_mesh_lod_tier(cname: String) -> int:
	if cname.begins_with("ShoulderPanelFastener") or cname.begins_with("HatchBolt") \
			or cname.begins_with("HeatExchangerSlot") or cname.begins_with("ArmorLock") \
			or cname.begins_with("SideVent") or cname.begins_with("BeadBolt") \
			or cname.begins_with("LugNut") or cname.begins_with("RoadWheelBolt") \
			or cname.begins_with("PanelFastener") or cname.begins_with("BeadlockRing") \
			or cname.begins_with("LockingDial"):
		return 1
	elif cname.begins_with("CoolingVent") or cname.begins_with("AccessPanelSeam") \
			or cname.begins_with("ServiceHatch") or cname.begins_with("DorsalBay") \
			or cname.begins_with("TailBoomSeam") or cname.begins_with("SideBite") \
			or cname.begins_with("HardpointStripe") or cname.begins_with("ShoulderRail"):
		return 2
	return 0

func _batch_static_meshes(parent: Node3D) -> void:
	for child in parent.get_children():
		if child is Node3D and not child is MeshInstance3D: _batch_static_meshes(child)

	var cache_key: String = parent.get_meta("batch_cache_key", "")
	var cached_groups: Variant = DroneVisualResourcesScript.get_batched_meshes(cache_key) if not cache_key.is_empty() else null

	var original_instances: Array[MeshInstance3D] = []
	for child in parent.get_children():
		if not child is MeshInstance3D: continue
		var instance := child as MeshInstance3D
		if instance.mesh == null or _track_shoes.has(instance) or _rolling_parts.has(instance) or _team_leds.has(instance): continue
		original_instances.append(instance)

	if cached_groups != null:
		for group in cached_groups:
			var merged := MeshInstance3D.new()
			merged.name = group.get("name", "BatchedStaticHardware")
			merged.set_meta("visual_lod_tier", int(group.get("tier", 0)))
			merged.mesh = group["mesh"]
			merged.material_override = group["material"]
			merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(merged)
		for instance in original_instances: instance.free()
		return

	var groups: Dictionary = {}
	for instance in original_instances:
		var tier := _get_mesh_lod_tier(String(instance.name))
		for surface in instance.mesh.get_surface_count():
			var material := instance.material_override if instance.material_override != null else instance.mesh.surface_get_material(surface)
			if material == null: continue
			var key := "%d_%d" % [tier, material.get_instance_id()]
			if not groups.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				var group_name := "BatchedStaticCore"
				if tier == 1:
					group_name = "BatchedStaticDetailSmall"
				elif tier == 2:
					group_name = "BatchedStaticDetailMedium"
				groups[key] = {"tool": tool, "material": material, "tier": tier, "name": group_name}
			groups[key]["tool"].append_from(instance.mesh, surface, instance.transform)

	if not groups.is_empty():
		DroneVisualResourcesScript.record_merge()

	var committed_cache: Array = []
	for group in groups.values():
		var merged := MeshInstance3D.new()
		merged.name = group["name"]
		merged.set_meta("visual_lod_tier", int(group["tier"]))
		merged.mesh = group["tool"].commit()
		merged.material_override = group["material"]
		merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(merged)
		if not cache_key.is_empty():
			committed_cache.append({
				"mesh": merged.mesh,
				"material": group["material"],
				"name": group["name"],
				"tier": group["tier"]
			})

	if not cache_key.is_empty():
		DroneVisualResourcesScript.set_batched_meshes(cache_key, committed_cache)

	for instance in original_instances: instance.free()

func _rebuild_payloads() -> void:
	if not is_instance_valid(_turret):
		_turret = Node3D.new()
		_turret.name = "WeaponTurret"
		_turret.position.y = 0.065 - (GROUND_HULL_DROP if _uses_ground_gear() else 0.0)
		add_child(_turret)
		_cylinder(_turret, "TurretBearing", 0.083, 0.026, Vector3.ZERO, _mat(Color("343f48"), 0.75, 0.38))
		_box(_turret, "TurretArmor", Vector3(0.19,0.055,0.15), Vector3(0,0.022,0), _mat(Color("66727b"), 0.72, 0.4))
	for mount in [_left_mount, _right_mount, _center_mount]:
		if is_instance_valid(mount):
			mount.get_parent().remove_child(mount)
			mount.queue_free()
	_left_mount = _build_mount(_primary_weapon, -1.0)
	_right_mount = _build_mount(_secondary_weapon, 1.0) if not _secondary_weapon.is_empty() else null
	_center_mount = _build_center_mount(_tertiary_weapon) if (chassis_id == "tracked" and not _tertiary_weapon.is_empty()) else null
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
	mount.position = Vector3(side * 0.152, 0.025, -0.045)
	mount.add_child(model)
	_turret.add_child(mount)
	return mount

func _build_center_mount(id: String) -> Node3D:
	var model := PayloadBuilderScript.build(id)
	var bounds := _payload_bounds(model)
	var center := bounds.get_center()
	var radius := 0.0
	for corner in _aabb_corners(bounds):
		radius = maxf(radius, center.distance_to(corner))
	var scale_factor := 0.12 / maxf(radius, 0.0001)
	model.scale = Vector3.ONE * scale_factor
	model.position = -center * scale_factor
	var mount := Node3D.new()
	mount.name = "TertiaryCenter"
	mount.position = Vector3(0.0, 0.065, -0.02)
	mount.add_child(model)
	_turret.add_child(mount)
	return mount

func _select_active_mount() -> void:
	if is_instance_valid(_payload_gimbal):
		_payload_gimbal.rotation = Vector3.ZERO
	if weapon_id == _secondary_weapon and is_instance_valid(_right_mount):
		_payload_gimbal = _right_mount
	elif chassis_id == "tracked" and weapon_id == _tertiary_weapon and is_instance_valid(_center_mount):
		_payload_gimbal = _center_mount
	else:
		_payload_gimbal = _left_mount
	_payload = _payload_gimbal.get_child(0) as Node3D if is_instance_valid(_payload_gimbal) else null
	if is_instance_valid(_payload_gimbal):
		_payload_gimbal.rotation = Vector3(_aim_pitch, _aim_yaw, 0.0)
	_update_payload_visibility()

func set_loadout(primary: String, secondary: String, active: String, tertiary: String = "") -> void:
	primary = primary if PAYLOAD_IDS.has(primary) else "ak47"
	secondary = secondary if PAYLOAD_IDS.has(secondary) and secondary != primary else ""
	if tertiary.is_empty() and GameState != null:
		tertiary = GameState.selected_tertiary if PAYLOAD_IDS.has(GameState.selected_tertiary) else "hmg"
	var changed := primary != _primary_weapon or secondary != _secondary_weapon or tertiary != _tertiary_weapon
	var next_weapon := active if active == primary or (not secondary.is_empty() and active == secondary) or (chassis_id == "tracked" and not tertiary.is_empty() and active == tertiary) else primary
	var active_changed := weapon_id != next_weapon
	_primary_weapon = primary
	_secondary_weapon = secondary
	_tertiary_weapon = tertiary
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
	if node is MultiMeshInstance3D:
		var instances := (node as MultiMeshInstance3D).multimesh
		if instances != null and instances.mesh != null:
			for index in instances.instance_count:
				for corner in _aabb_corners(instances.mesh.get_aabb()): points.append(t * instances.get_instance_transform(index) * corner)
	if node is MeshInstance3D and (node as MeshInstance3D).mesh!=null:
		for p in _aabb_corners((node as MeshInstance3D).get_aabb()): points.append(t*p)
	for child in node.get_children(): _collect_mesh_bounds(child,t,points)

func _aabb_corners(b: AABB) -> Array[Vector3]:
	var a:Array[Vector3]=[]; for x in [b.position.x,b.end.x]:
		for y in [b.position.y,b.end.y]:
			for z in [b.position.z,b.end.z]: a.append(Vector3(x,y,z))
	return a

func set_weapon(selected_weapon: String) -> void:
	if selected_weapon == _primary_weapon or selected_weapon == _secondary_weapon or (chassis_id == "tracked" and selected_weapon == _tertiary_weapon):
		set_loadout(_primary_weapon, _secondary_weapon, selected_weapon, _tertiary_weapon)
	else:
		set_loadout(selected_weapon, "", selected_weapon, "")

func set_payload_visible(visible: bool) -> void:
	payload_enabled = visible
	_update_payload_visibility()

func _update_payload_visibility() -> void:
	if is_instance_valid(_left_mount): _left_mount.get_child(0).visible = payload_enabled and not dead
	if is_instance_valid(_right_mount): _right_mount.get_child(0).visible = payload_enabled and not dead
	if is_instance_valid(_center_mount): _center_mount.get_child(0).visible = payload_enabled and not dead

func get_payload() -> Node3D: return _payload

func aim_payload_at(world_point: Vector3, both := false) -> void:
	if not world_point.is_finite() or not is_instance_valid(_payload_gimbal): return
	if is_instance_valid(_turret):
		var direction := global_basis.inverse() * (world_point - _turret.global_position)
		_turret.rotation.y = atan2(-direction.x, -direction.z)
	_payload_gimbal.rotation = _mount_aim(_payload_gimbal, world_point)
	_aim_pitch = _payload_gimbal.rotation.x
	_aim_yaw = _payload_gimbal.rotation.y
	for mount in [_left_mount, _right_mount, _center_mount]:
		if is_instance_valid(mount) and mount != _payload_gimbal:
			mount.rotation = _mount_aim(mount, world_point) if both else Vector3.ZERO

func _mount_aim(mount: Node3D, world_point: Vector3) -> Vector3:
	var direction := (mount.get_parent() as Node3D).global_basis.inverse() * (world_point - mount.global_position)
	if direction.length_squared() < 0.000001: return mount.rotation
	return Vector3(atan2(direction.y, Vector2(direction.x, direction.z).length()), atan2(-direction.x, -direction.z), 0.0)

func get_muzzle_global(mount_weapon := "") -> Vector3:
	var gimbal := _payload_gimbal
	if mount_weapon == _primary_weapon: gimbal = _left_mount
	elif mount_weapon == _secondary_weapon and not mount_weapon.is_empty(): gimbal = _right_mount
	elif mount_weapon == _tertiary_weapon and chassis_id == "tracked" and is_instance_valid(_center_mount): gimbal = _center_mount
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

var visual_lod := 0

func set_visual_lod(level: int) -> void:
	visual_lod = clampi(level, 0, 2)
	_apply_visual_lod()

func _apply_visual_lod() -> void:
	if not is_instance_valid(_body): return
	for child in _body.find_children("*", "MeshInstance3D", true, false):
		# Names are not identities: Godot renames same-tier material siblings.
		var tier := int(child.get_meta("visual_lod_tier", 0))
		if tier > 0:
			child.visible = visual_lod < tier
	# Keep rotor angular speed unchanged. Slowing the animation clock does
	# not reduce evaluation cost and is not an update-frequency optimization.
	if is_instance_valid(_rotor_player):
		_rotor_player.speed_scale = 1.0

func make_wreck_visual(parent: Node3D) -> Node3D:
	var model := Node3D.new()
	model.name = "DroneWreck"
	parent.add_child(model)
	# Preserve the assembled chassis and loadout. Mesh resources stay shared.
	for part in [_bank_root, _left_mount, _right_mount, _center_mount]:
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
		mesh.material_override = DroneVisualResourcesScript.get_wreck_material(original)
	return model

func apply_motion(velocity: Vector3, yaw: float, pitch: float, is_dead: bool=false, ground_roll: float = 0.0, suspension_offsets: Array = []) -> void:
	_velocity=velocity if velocity.is_finite() else Vector3.ZERO; dead=is_dead; _aim_pitch=clampf(pitch,-1.55,1.55)
	if is_instance_valid(_payload_gimbal): _payload_gimbal.rotation=Vector3(_aim_pitch,_aim_yaw,0.0)
	if not is_instance_valid(_bank_root): return
	var local_velocity:=Vector3(cos(yaw)*_velocity.x-sin(yaw)*_velocity.z,0,sin(yaw)*_velocity.x+cos(yaw)*_velocity.z)
	var frame_dt := maxf(get_process_delta_time(), 0.0001)
	var rolling_speed := local_velocity.z
	var accel := (rolling_speed - _prev_rolling_speed) / frame_dt
	_prev_rolling_speed = rolling_speed
	var pitch_inertia := clampf(-accel * 0.012, -0.09, 0.09) if _uses_ground_gear() else 0.0
	if _uses_ground_gear():
		_bank_root.rotation.x = move_toward_angle(_bank_root.rotation.x, _aim_pitch + pitch_inertia - _recoil_kick * 1.5, 14.0 * frame_dt)
		_bank_root.rotation.z = move_toward_angle(_bank_root.rotation.z, ground_roll, 8.0 * frame_dt)
	elif chassis_id == "wing":
		var target:=clampf(-local_velocity.x*0.10,-BANK_LIMIT,BANK_LIMIT)
		if dead: target=clampf(target+deg_to_rad(7),-deg_to_rad(17),deg_to_rad(17))
		_bank_root.rotation.z=move_toward_angle(_bank_root.rotation.z,target,BANK_RESPONSE*frame_dt)
		_bank_root.rotation.x = move_toward(_bank_root.rotation.x, _aim_pitch * 0.45, 1.8 * frame_dt)
	else:
		var target:=clampf(-local_velocity.x*0.10,-BANK_LIMIT,BANK_LIMIT)
		if dead: target=clampf(target+deg_to_rad(7),-deg_to_rad(17),deg_to_rad(17))
		_bank_root.rotation.z=move_toward_angle(_bank_root.rotation.z,target,BANK_RESPONSE*frame_dt)
		_bank_root.rotation.x = move_toward(_bank_root.rotation.x, 0.0, 4.0 * frame_dt)
	if not suspension_offsets.is_empty():
		for idx in range(min(_wheel_struts.size(), suspension_offsets.size())):
			var strut := _wheel_struts[idx]
			if is_instance_valid(strut):
				strut.position.y = WHEEL_HUB_Y + float(suspension_offsets[idx])
	var turn_rate := clampf(wrapf(yaw - _last_motion_yaw, -PI, PI) / frame_dt, -3.0, 3.0) if _motion_yaw_initialized else 0.0
	_motion_yaw_initialized = true
	_last_motion_yaw = yaw
	var steer_target := clampf(-turn_rate * 0.22, -0.45, 0.45)
	for steer_node in _steer_parts:
		if is_instance_valid(steer_node):
			steer_node.rotation.y = move_toward_angle(steer_node.rotation.y, steer_target, 8.0 * frame_dt)
	if chassis_id == "tracked" and not dead:
		var perimeter := 0.62 + TAU * 0.057
		for shoe in _track_shoes:
			if not is_instance_valid(shoe): continue
			var side := float(shoe.get_meta("side"))
			var phase := fposmod(float(shoe.get_meta("phase")) + (rolling_speed / BODY_SCALE - side * turn_rate * 0.19) * frame_dt, perimeter)
			shoe.set_meta("phase", phase)
			_update_track_instances(shoe as MultiMeshInstance3D, phase)
	var movement_profile := "heli" if chassis_id == "quad" else chassis_id
	for wheel in _rolling_parts:
		if is_instance_valid(wheel) and String(wheel.get_meta("mobility_profile","")) == movement_profile:
			var radius := TIRE_RADIUS if movement_profile == "wheels" else 0.039
			wheel.rotate(Vector3.RIGHT, rolling_speed * frame_dt / (radius * BODY_SCALE))
	_recoil_kick = lerpf(_recoil_kick, 0.0, 1.0 - exp(-24.0 * frame_dt))
	if is_instance_valid(_payload_gimbal):
		_payload_gimbal.position.z = -0.045 + _recoil_kick
	_update_payload_visibility()
	for led in _team_leds: if is_instance_valid(led): led.visible=not dead

static func move_toward_angle(current: float, target: float, max_delta: float) -> float:
	var difference:=wrapf(target-current,-PI,PI)
	return current+difference if absf(difference)<=max_delta else current+signf(difference)*max_delta

func _update_track_instances(track: MultiMeshInstance3D, phase: float) -> void:
	var perimeter := 0.62 + TAU * 0.057
	var side := float(track.get_meta("side"))
	for index in track.multimesh.instance_count:
		var distance := fposmod(phase + perimeter * float(index) / 44.0, perimeter)
		var point := DroneMeshScript.track_point(distance)
		var tangent := (DroneMeshScript.track_point(fposmod(distance + 0.0001, perimeter)) - point).normalized()
		track.multimesh.set_instance_transform(index, Transform3D(Basis(Vector3.RIGHT, -atan2(tangent.y, tangent.x)), Vector3(side * 0.19, -0.105 + point.y, 0.03 + point.x)))
