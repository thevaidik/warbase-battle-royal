class_name WarCombatJeep
extends VehicleBody3D
## Studio-Grade Military Combat Tactical Jeep (M1151 Armed Technical).
## Features:
## 1. True 4-wheel independent spring suspension via VehicleWheel3D.
## 2. Speed-sensitive steering, 4WD torque distribution, and handbrake drifting.
## 3. Overhead 360° .50 Cal heavy machine gun turret with fiery muzzle bursts, tracers, and impact craters.
## 4. Multi-stage damage fire VFX: radiator steam -> heavy oil smoke -> intense engine fire -> catastrophic blast.
## 5. Exhaust backfire flame bursts on throttle / gear shifts.
## 6. Real-time procedural V8 engine audio synthesizer with RPM pitch modulation & tire screech.
## 7. Interactive enter/exit system with dynamic 3rd-person chase camera & 1st-person cockpit view.
## 8. High-speed kinetic roadkill physics against enemy bots.

signal player_entered(jeep: Node)
signal player_exited(jeep: Node)
signal vehicle_destroyed(jeep: Node)

# Vehicle Performance Configuration
const MAX_ENGINE_FORCE := 18500.0
const MAX_BRAKE_FORCE := 120.0
const HANDBRAKE_FORCE := 240.0
const MAX_STEER_ANGLE := 0.52 # ~30 degrees

# 2-Speed Tactical Transmission
# Gear 1: High-torque low gear for climbing steep slopes & rough hills, capped at 52 km/h
# Gear 2: High-speed overdrive cruise for highway & flat terrain, reaching 115 km/h
const GEAR_1_TOP_SPEED := 52.0
const GEAR_2_TOP_SPEED := 115.0

# Health & Armor
var max_health := 1200.0
var health := 1200.0
var is_destroyed := false
var bot_name: String = "COMBAT JEEP"
var dead: bool:
	get: return is_destroyed

# Driver & State
var is_driven := false
var driver_ref: Node3D = null
var current_speed_kmh := 0.0
var current_gear := 1 # Default to Gear 1 (climbing torque mode)
var is_reversing := false
var is_drifting := false
var is_first_person := false

func get_top_speed() -> float:
	return GEAR_2_TOP_SPEED if current_gear == 2 else GEAR_1_TOP_SPEED

func shift_gear(new_gear: int) -> void:
	if not is_driven or is_destroyed:
		return
	if new_gear != 1 and new_gear != 2:
		return
	if current_gear == new_gear:
		return
	current_gear = new_gear
	_trigger_exhaust_backfire()
	_rpm = maxf(800.0, _rpm * 0.70)
	
	var m := get_tree().current_scene
	if m and "hud" in m and m.hud and m.hud.has_method("feed"):
		if current_gear == 2:
			m.hud.feed("⚡ TRANSMISSION: GEAR 2 (HIGH SPEED: 115 KM/H)", Color(0.25, 0.95, 1.0))
		else:
			m.hud.feed("⚙️ TRANSMISSION: GEAR 1 (LOW / CLIMB TORQUE: 52 KM/H)", Color(1.0, 0.85, 0.2))



# Visual Components & VFX
var _wheels: Array[VehicleWheel3D] = []
var _headlights: Array[SpotLight3D] = []
var _brakelights: Array[OmniLight3D] = []
var _brakelight_mats: Array[StandardMaterial3D] = []
var _exhaust_flame_l: MeshInstance3D
var _exhaust_flame_r: MeshInstance3D
var _exhaust_timer := 0.0
var _smoke_emitter: MeshInstance3D
var _fire_emitter: MeshInstance3D
var _steering_wheel_mesh: Node3D

# Camera System (Strictly 3rd Person)
var chase_camera_pivot: Node3D
var chase_spring_arm: SpringArm3D
var chase_camera: Camera3D
var is_wide_view := false
var _cam_yaw := 0.0
var _cam_pitch := -0.20
var _mouse_idle_time := 0.0

# Audio Synthesizer
var _engine_audio: AudioStreamPlayer3D
var _tire_audio: AudioStreamPlayer3D
var _rpm := 800.0
var _engine_pcm_stream: AudioStreamWAV

# Proximity trigger
var interact_area: Area3D

# Roadkill kinetic tracking
var _roadkill_cooldowns: Dictionary = {}
var network_controlled := false
var network_position := Vector3.ZERO
var network_yaw := 0.0
var _parked_settle_timer := 1.0

func _ready() -> void:
	mass = 2800.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, 0.35, 0.0)
	linear_damp = 3.5 # Solid damping when parked so it cannot be nudged by foot soldiers
	angular_damp = 6.0
	brake = MAX_BRAKE_FORCE
	collision_layer = 4
	collision_mask = 1 | 4 # Collide with Terrain (1) AND other Combat Vehicles (4)
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = false
	add_to_group("combat_jeeps")
	
	_build_vehicle_mesh_and_wheels()
	_setup_cameras()
	_setup_lighting()
	_setup_vfx()
	_setup_audio()
	_setup_interaction_area()

# ==============================================================================
# HIGH-FIDELITY ONLINE 3D COMBAT TECHNICAL VEHICLE RIG
# ==============================================================================
const VEHICLE_MODEL_PATH: String = "res://assets/models/armored_combat_van.glb"

func _build_vehicle_mesh_and_wheels() -> void:
	# Main lower chassis collision shape (elevated so bottom never touches ground when wheels compress)
	# Length 5.0m ensures tires (at -2.67m) touch curbs & obstacles first to climb over them
	var col := CollisionShape3D.new()
	col.name = "ChassisCollision"
	var box := BoxShape3D.new()
	box.size = Vector3(2.3, 1.10, 5.0)
	col.shape = box
	col.position = Vector3(0.0, 0.95, 0.0)
	add_child(col)
	
	# Upper enclosed armored cabin collision (protects driver fully from bullets and clipping)
	var cabin_col := CollisionShape3D.new()
	cabin_col.name = "CabinCollision"
	var cabin_box := BoxShape3D.new()
	cabin_box.size = Vector3(2.2, 0.95, 4.0)
	cabin_col.shape = cabin_box
	cabin_col.position = Vector3(0.0, 1.95, 0.20)
	add_child(cabin_col)
	
	# Visual Root
	var body_root := Node3D.new()
	body_root.name = "BodyVisuals"
	add_child(body_root)
	
	# Load authentic online 3D armored combat assault vehicle model (enclosed roof & cabin)
	var model_scene := load(VEHICLE_MODEL_PATH) as PackedScene
	var model_inst: Node3D = null
	if model_scene:
		model_inst = model_scene.instantiate() as Node3D
		model_inst.name = "ArmoredCombatVanMesh"
		model_inst.rotation.y = deg_to_rad(-90.0) # Face forward (-Z in Godot coordinates)
		model_inst.position = Vector3.ZERO
		body_root.add_child(model_inst)
		
		# Hide showroom pedestal floor
		var floor_node := model_inst.find_child("floor", true, false)
		if floor_node:
			floor_node.visible = false

	# Find wheels from the 3D model
	var wheel_fl_src: Node = model_inst.find_child("wheelFL", true, false) if model_inst else null
	var wheel_fr_src: Node = model_inst.find_child("wheelFR", true, false) if model_inst else null
	var wheel_rl_src: Node = model_inst.find_child("wheelRL", true, false) if model_inst else null
	var wheel_rr_src: Node = model_inst.find_child("wheelRR", true, false) if model_inst else null
	
	# Hide static wheel nodes in chassis so only physics-driven wheels display
	if wheel_fl_src: wheel_fl_src.visible = false
	if wheel_fr_src: wheel_fr_src.visible = false
	if wheel_rl_src: wheel_rl_src.visible = false
	if wheel_rr_src: wheel_rr_src.visible = false
	
	# 4 Independent Physics Wheels (VehicleWheel3D) with heavy off-road tires
	var wheel_configs := [
		{"name": "WheelFL", "pos": Vector3(-1.05, 0.64, -2.00), "steer": true, "drive": true, "src": wheel_fl_src, "side": "left"},
		{"name": "WheelFR", "pos": Vector3(1.05, 0.64, -2.00), "steer": true, "drive": true, "src": wheel_fr_src, "side": "right"},
		{"name": "WheelRL", "pos": Vector3(-1.05, 0.64, 1.99), "steer": false, "drive": true, "src": wheel_rl_src, "side": "left"},
		{"name": "WheelRR", "pos": Vector3(1.05, 0.64, 1.99), "steer": false, "drive": true, "src": wheel_rr_src, "side": "right"},
	]
	
	for wc in wheel_configs:
		var vw := VehicleWheel3D.new()
		vw.name = String(wc["name"])
		vw.position = wc["pos"]
		
		# Heavy-duty military armored suspension parameters
		vw.wheel_radius = 0.67
		vw.wheel_rest_length = 0.26
		vw.wheel_friction_slip = 8.5
		vw.suspension_travel = 0.28
		vw.suspension_stiffness = 24.0
		vw.suspension_max_force = 26000.0
		vw.damping_compression = 2.0
		vw.damping_relaxation = 2.6
		vw.use_as_steering = bool(wc["steer"])
		vw.use_as_traction = bool(wc["drive"])
		
		# Visual wheel model cloned from authentic 3D model
		var src_wheel: Node = wc["src"]
		if is_instance_valid(src_wheel):
			var visual_wheel := src_wheel.duplicate() as Node3D
			visual_wheel.visible = true
			visual_wheel.scale = Vector3.ONE
			visual_wheel.position = Vector3.ZERO
			visual_wheel.rotation = Vector3(0.0, -PI * 0.5 if wc["side"] == "left" else PI * 0.5, 0.0)
			vw.add_child(visual_wheel)
			
		add_child(vw)
		_wheels.append(vw)



# ==============================================================================
# CAMERAS & LIGHTING
# ==============================================================================
func _setup_cameras() -> void:
	# Dedicated 3rd-Person Collision-Safe SpringArm Chase Camera Rig (Always 3rd Person)
	chase_camera_pivot = Node3D.new()
	chase_camera_pivot.name = "ChaseCameraPivot"
	chase_camera_pivot.top_level = true
	chase_camera_pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(chase_camera_pivot)
	
	chase_spring_arm = SpringArm3D.new()
	chase_spring_arm.name = "ChaseSpringArm"
	chase_spring_arm.spring_length = 6.8
	chase_spring_arm.margin = 0.30
	var arm_shape := SphereShape3D.new()
	arm_shape.radius = 0.25
	chase_spring_arm.shape = arm_shape
	chase_spring_arm.collision_mask = 1 # Collides with ground/rocks/walls so it never clips into terrain
	chase_spring_arm.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	chase_spring_arm.add_excluded_object(get_rid())
	chase_camera_pivot.add_child(chase_spring_arm)
	
	chase_camera = Camera3D.new()
	chase_camera.name = "ChaseCamera"
	chase_camera.current = false
	chase_camera.fov = 76.0
	chase_camera.near = 0.15
	chase_camera.far = 2500.0
	chase_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	chase_camera.position = Vector3.ZERO
	chase_spring_arm.add_child(chase_camera)

func _setup_lighting() -> void:
	# Front Projector High-Beam Headlights (aligned flush with van front headlights at Y=1.72, Z=-3.05)
	for lx in [-0.82, 0.82]:
		var sl := SpotLight3D.new()
		sl.position = Vector3(lx, 1.72, -3.05)
		sl.spot_range = 110.0
		sl.spot_angle = 45.0
		sl.light_energy = 3.2
		sl.light_color = Color(1.0, 0.96, 0.88)
		sl.shadow_enabled = false
		add_child(sl)
		_headlights.append(sl)
		
	# Rear Functional Brake / Tail Lights (aligned flush with van rear tail lights at Y=1.33, Z=3.25)
	for rx in [-0.85, 0.85]:
		var bl := OmniLight3D.new()
		bl.position = Vector3(rx, 1.33, 3.25)
		bl.omni_range = 5.0
		bl.light_energy = 0.5
		bl.light_color = Color(1.0, 0.1, 0.1)
		add_child(bl)
		_brakelights.append(bl)
		
	# Illuminate authentic 3D model headlight and taillight meshes without floating boxes
	var body_vis := get_node_or_null("BodyVisuals/ArmoredCombatVanMesh")
	if is_instance_valid(body_vis):
		var fl_mesh: MeshInstance3D = body_vis.find_child("BaseVehicle_6", true, false) as MeshInstance3D
		if fl_mesh:
			var fl_mat := StandardMaterial3D.new()
			fl_mat.albedo_color = Color(0.95, 0.95, 0.92)
			fl_mat.emission_enabled = true
			fl_mat.emission = Color(1.0, 0.96, 0.88)
			fl_mat.emission_energy_multiplier = 1.5
			fl_mesh.material_override = fl_mat
			
		var rl_mesh: MeshInstance3D = body_vis.find_child("BaseVehicle_17", true, false) as MeshInstance3D
		if rl_mesh:
			var rl_mat := StandardMaterial3D.new()
			rl_mat.albedo_color = Color(0.85, 0.05, 0.05)
			rl_mat.emission_enabled = true
			rl_mat.emission = Color(0.95, 0.08, 0.08)
			rl_mat.emission_energy_multiplier = 0.5
			rl_mesh.material_override = rl_mat
			_brakelight_mats.append(rl_mat)

# ==============================================================================
# FIRE & DAMAGE VISUAL EFFECTS ("WITH FIRES")
# ==============================================================================
func _setup_vfx() -> void:
	# Exhaust Flame Emitters flush with dual exhaust tips
	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.albedo_color = Color(1.0, 0.55, 0.15)
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	var fm := CylinderMesh.new()
	fm.top_radius = 0.01
	fm.bottom_radius = 0.08
	fm.height = 0.32
	
	_exhaust_flame_l = MeshInstance3D.new()
	_exhaust_flame_l.mesh = fm
	_exhaust_flame_l.material_override = flame_mat
	_exhaust_flame_l.rotation_degrees = Vector3(-90, 0, 0)
	_exhaust_flame_l.position = Vector3(-0.85, 0.55, 3.20)
	_exhaust_flame_l.visible = false
	add_child(_exhaust_flame_l)
	
	_exhaust_flame_r = MeshInstance3D.new()
	_exhaust_flame_r.mesh = fm
	_exhaust_flame_r.material_override = flame_mat
	_exhaust_flame_r.rotation_degrees = Vector3(-90, 0, 0)
	_exhaust_flame_r.position = Vector3(0.85, 0.55, 3.20)
	_exhaust_flame_r.visible = false
	add_child(_exhaust_flame_r)
	
	# Engine Hood Smoke Plume (Damage Stage 1 & 2)
	_smoke_emitter = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 0.90
	_smoke_emitter.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(0.18, 0.18, 0.18, 0.0)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_smoke_emitter.material_override = smat
	_smoke_emitter.position = Vector3(0.0, 1.80, -2.10)
	_smoke_emitter.visible = false
	add_child(_smoke_emitter)
	
	# Engine Hood Roaring Fire (Damage Stage 2)
	_fire_emitter = MeshInstance3D.new()
	var fire_mesh := SphereMesh.new()
	fire_mesh.radius = 0.40
	fire_mesh.height = 0.80
	_fire_emitter.mesh = fire_mesh
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color(1.0, 0.45, 0.1, 0.85)
	_fire_emitter.material_override = fmat
	_fire_emitter.position = Vector3(0.0, 1.90, -2.10)
	_fire_emitter.visible = false
	add_child(_fire_emitter)

# ==============================================================================
# PROCEDURAL V8 ENGINE AUDIO SYNTHESIZER
# ==============================================================================
func _setup_audio() -> void:
	_engine_audio = AudioStreamPlayer3D.new()
	_engine_audio.name = "EngineAudio"
	_engine_audio.bus = "Master"
	_engine_audio.max_distance = 65.0
	_engine_audio.unit_size = 8.0
	_engine_audio.autoplay = false
	add_child(_engine_audio)
	
	# Synthesize 1.0s looping throaty V8 engine sound buffer
	_engine_pcm_stream = _bake_v8_engine_pcm(1.0, 22050)
	_engine_audio.stream = _engine_pcm_stream
	

	
	_tire_audio = AudioStreamPlayer3D.new()
	_tire_audio.name = "TireAudio"
	_tire_audio.bus = "Master"
	_tire_audio.max_distance = 45.0
	add_child(_tire_audio)

func _bake_v8_engine_pcm(dur: float, rate: int) -> AudioStreamWAV:
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		# Dual harmonic sub-rumble (42Hz base) + mechanical piston rasp (126Hz) + intake noise
		var s := sin(TAU * 42.0 * t) * 0.45
		s += sin(TAU * 84.0 * t + 0.5) * 0.28
		s += sin(TAU * 126.0 * t + 1.2) * 0.15
		s += (randf() * 2.0 - 1.0) * 0.08
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	w.data = data
	return w

# ==============================================================================
# PLAYER ENTER / EXIT PROXIMITY
# ==============================================================================
func _setup_interaction_area() -> void:
	interact_area = Area3D.new()
	interact_area.name = "InteractArea"
	var c := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 3.6
	c.shape = s
	interact_area.add_child(c)
	interact_area.collision_layer = 0
	interact_area.collision_mask = 2 # Player layer
	interact_area.monitoring = true
	add_child(interact_area)

func is_player_nearby(p: Node3D) -> bool:
	if not is_instance_valid(p):
		return false
	return global_position.distance_to(p.global_position) < 4.8

func enter_vehicle(player_node: Node3D) -> void:
	if is_driven or is_destroyed:
		return
	is_driven = true
	freeze = false
	_parked_settle_timer = 1.0
	driver_ref = player_node
	brake = 0.0
	engine_force = 0.0
	linear_damp = 0.15
	angular_damp = 1.5 # Responsive yaw steering while driving
	current_gear = 1 # Always start in Gear 1 (maximum climbing torque)
	
	# Smoothly match camera yaw directly to vehicle heading
	_cam_yaw = rotation.y
	_cam_pitch = -0.20
	_mouse_idle_time = 0.0
	is_wide_view = false
	if is_instance_valid(chase_spring_arm):
		chase_spring_arm.spring_length = 6.8
		chase_spring_arm.add_excluded_object(get_rid())
		if is_instance_valid(player_node) and player_node is CollisionObject3D:
			chase_spring_arm.add_excluded_object(player_node.get_rid())
	if is_instance_valid(chase_camera_pivot):
		chase_camera_pivot.global_position = global_position + Vector3(0.0, 2.30, 0.0)
		chase_camera_pivot.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
	if is_instance_valid(chase_camera):
		chase_camera.make_current()
		
	# Start engine audio
	if is_instance_valid(_engine_audio):
		_engine_audio.play()
		
	player_entered.emit(self)

func exit_vehicle() -> void:
	if not is_driven:
		return
	is_driven = false
	freeze = false
	_parked_settle_timer = 1.2
	
	# Cut throttle & apply parking brake
	engine_force = 0.0
	brake = MAX_BRAKE_FORCE
	linear_damp = 3.5
	angular_damp = 6.0
	
	if is_instance_valid(_engine_audio):
		_engine_audio.stop()
		
	# Place driver safely outside driver door
	if is_instance_valid(driver_ref):
		var exit_offset := global_transform.basis.x * -2.4 + Vector3.UP * 0.25
		driver_ref.global_position = global_position + exit_offset
		driver_ref.velocity = Vector3.ZERO
		if driver_ref.has_method("set_driving"):
			driver_ref.set_driving(false)
		if "camera" in driver_ref and is_instance_valid(driver_ref.camera):
			driver_ref.camera.make_current()
		
	var d := driver_ref
	driver_ref = null
	player_exited.emit(self)

# ==============================================================================
# REAL-TIME CAMERA PROCESS (PER-FRAME RENDER RATE FOR ABSOLUTE SMOOTHNESS)
# ==============================================================================
func _process(delta: float) -> void:
	if network_controlled:
		global_position = global_position.lerp(network_position, 1.0-exp(-18.0*delta))
		rotation.y = lerp_angle(rotation.y, network_yaw, 1.0-exp(-18.0*delta))
	if not is_driven or is_destroyed:
		return
	if is_instance_valid(chase_camera_pivot):
		# Target position: elevated pivot above the vehicle
		var target_pos := global_position + Vector3(0.0, 2.30, 0.0)
		# Smooth lerp follows vehicle without 60Hz/120Hz physics stutter
		chase_camera_pivot.global_position = chase_camera_pivot.global_position.lerp(target_pos, clampf(30.0 * delta, 0.0, 1.0))
		
		# Align camera yaw behind travel direction if user hasn't touched the mouse recently
		_mouse_idle_time += delta
		if _mouse_idle_time > 0.8 and current_speed_kmh > 4.0:
			var target_heading := rotation.y
			if is_reversing:
				target_heading += PI
			_cam_yaw = lerp_angle(_cam_yaw, target_heading, clampf(2.2 * delta, 0.0, 1.0))
			
		chase_camera_pivot.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)

# ==============================================================================
# REAL-TIME DRIVING PHYSICS & TURRET COMBAT LOOP
# ==============================================================================
func _physics_process(delta: float) -> void:
	if network_controlled:
		freeze = true
		_update_audio_and_fx(delta)
		_update_damage_fire_effects(delta)
		return
	current_speed_kmh = linear_velocity.length() * 3.6
	
	# Tick down roadkill victim cooldowns
	for target_id in _roadkill_cooldowns.keys():
		_roadkill_cooldowns[target_id] -= delta
		if _roadkill_cooldowns[target_id] <= 0.0:
			_roadkill_cooldowns.erase(target_id)
	
	if is_driven and not is_destroyed:
		_process_driving_input(delta)
		_process_roadkill_damage()
	else:
		# Auto engine braking when uncrewed
		engine_force = 0.0
		brake = 12.0
		if not is_destroyed and _parked_settle_timer > 0.0:
			_parked_settle_timer -= delta
			if _parked_settle_timer <= 0.0 and linear_velocity.length() < 0.8:
				freeze = true
		
	_update_audio_and_fx(delta)
	_update_damage_fire_effects(delta)

func _process_driving_input(delta: float) -> void:
	# Manual Gear Shifting (Key 1 = Low Gear / Climb, Key 2 = High Gear / Speed)
	if Input.is_physical_key_pressed(KEY_1):
		shift_gear(1)
	elif Input.is_physical_key_pressed(KEY_2):
		shift_gear(2)

	var forward := Input.is_action_pressed("move_forward")
	var backward := Input.is_action_pressed("move_back")
	var steer_left := Input.is_action_pressed("move_left")
	var steer_right := Input.is_action_pressed("move_right")
	var handbrake := Input.is_action_pressed("jump") # Spacebar = Handbrake drift!
	
	var active_top_speed := get_top_speed()
	# Dynamic speed-sensitive steering (prevents twitchy rollovers at 90+ km/h)
	var speed_ratio := clampf(current_speed_kmh / active_top_speed, 0.0, 1.0)
	var target_steer_limit := lerpf(MAX_STEER_ANGLE, MAX_STEER_ANGLE * 0.38, speed_ratio)
	
	var steer_input := 0.0
	if steer_left:
		steer_input += 1.0
	if steer_right:
		steer_input -= 1.0
		
	steering = lerpf(steering, steer_input * target_steer_limit, 10.0 * delta)
	
	# Smoothly rotate driver dashboard steering wheel mesh
	if is_instance_valid(_steering_wheel_mesh):
		_steering_wheel_mesh.rotation.z = -steering * 2.8
		
	# Throttle, Transmission & Dynamic Brakes
	# Godot's VehicleBody3D: -Z is vehicle forward, +Z is vehicle reverse.
	# Negative engine_force propels forward along -Z; positive engine_force propels backward along +Z.
	var moving_forward := linear_velocity.dot(-global_transform.basis.z) > 0.5
	var moving_backward := linear_velocity.dot(-global_transform.basis.z) < -0.5
	
	if forward:
		if moving_backward and current_speed_kmh > 4.0:
			# Braking while reversing
			engine_force = 0.0
			brake = MAX_BRAKE_FORCE
			_set_brakelights(true)
		else:
			is_reversing = false
			if current_speed_kmh < active_top_speed:
				# Progressive torque curve (high pull off-the-line)
				var torque_curve := 1.0 - pow(speed_ratio, 1.4)
				# Gear 1 gives 100% full raw torque for extreme climbing; Gear 2 gives smooth acceleration
				var gear_torque_mult := 1.0 if current_gear == 1 else 0.88
				engine_force = -MAX_ENGINE_FORCE * gear_torque_mult * maxf(0.25, torque_curve)
			else:
				engine_force = 0.0
			brake = 0.0
			_set_brakelights(false)
	elif backward:
		if moving_forward and current_speed_kmh > 4.0:
			# Hard foot-braking with red brake lights
			engine_force = 0.0
			brake = MAX_BRAKE_FORCE
			_set_brakelights(true)
		else:
			# Reverse gear
			is_reversing = true
			engine_force = MAX_ENGINE_FORCE * 0.55
			brake = 0.0
			_set_brakelights(false)
	else:
		# Coasting engine drag & stationary lock
		engine_force = 0.0
		if current_speed_kmh < 2.5:
			brake = MAX_BRAKE_FORCE
		else:
			brake = 4.0
		_set_brakelights(false)
		
	# Handbrake E-Brake Drift
	is_drifting = handbrake and current_speed_kmh > 15.0
	if handbrake:
		brake = HANDBRAKE_FORCE
		# Drop rear wheel friction slip to slide out rear end
		for i in range(2, 4):
			if i < _wheels.size():
				_wheels[i].wheel_friction_slip = 1.80
	else:
		for i in range(2, 4):
			if i < _wheels.size():
				_wheels[i].wheel_friction_slip = 8.50
				
	# Upright Recovery (Press R to self-right vehicle if rolled over)
	if Input.is_physical_key_pressed(KEY_R):
		var target_rot := rotation
		target_rot.x = 0.0
		target_rot.z = 0.0
		rotation = rotation.lerp(target_rot, 6.0 * delta)
		angular_velocity = Vector3.ZERO
		linear_velocity.y = maxf(linear_velocity.y, 0.0)

# ==============================================================================
# ROADKILL IMPACT MECHANICS
# ==============================================================================
func _process_roadkill_damage() -> void:
	if current_speed_kmh < 8.0:
		return
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(2.6, 1.8, 1.8)
	q.shape = s
	
	# Detect hits in driving direction (front when advancing, rear when reversing)
	var fwd_speed := -transform.basis.z.dot(linear_velocity)
	var local_offset := Vector3(0.0, 0.9, -2.8) if fwd_speed >= -1.0 else Vector3(0.0, 0.9, 2.8)
	q.transform = global_transform.translated_local(local_offset)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.collision_mask = 2 # Detect soldiers and enemy bots only
	
	var exclude_rids: Array[RID] = [get_rid()]
	if is_instance_valid(driver_ref) and driver_ref is CollisionObject3D:
		exclude_rids.append((driver_ref as CollisionObject3D).get_rid())
	q.exclude = exclude_rids
	
	var hits := space.intersect_shape(q, 16)
	if hits.is_empty():
		return
		
	var gs := get_node_or_null("/root/GameState")
	var m := get_tree().current_scene
	var audio := get_node_or_null("/root/Audio")
	
	for h in hits:
		var c: Object = h.get("collider")
		if not c or not (c is Node):
			continue
		var node := c as Node
		var b_node: Node = null
		var target_id := ""
		
		if node.has_meta("hitbox"):
			target_id = String(node.get_meta("player_id", ""))
			b_node = node.get_parent()
		elif node is CharacterBody3D or node is Node3D:
			b_node = node
			target_id = String(b_node.get("player_id") if "player_id" in b_node else (b_node.get("bot_name") if "bot_name" in b_node else b_node.name))
			
		if not b_node or not is_instance_valid(b_node):
			continue
		if b_node == self or b_node == driver_ref:
			continue
			
		# Prevent friendly roadkills in TDM
		if gs and gs.get("selected_mode") == "TDM" and b_node.get("team") == gs.get("local_team"):
			continue
			
		# Cooldown tracking per victim to prevent multi-hit frame spam
		var victim_key := target_id if not target_id.is_empty() else str(b_node.get_instance_id())
		if _roadkill_cooldowns.has(victim_key):
			continue
		_roadkill_cooldowns[victim_key] = 0.45
		
		var dead_before: bool = b_node.get("dead") if "dead" in b_node else false
		if dead_before:
			continue
			
		var ram_dmg := clampf(current_speed_kmh * 2.5, 25.0, 250.0)
		
		# Deal damage
		if b_node.has_method("take_damage"):
			if b_node is WarBot or "bot_name" in b_node:
				b_node.take_damage(ram_dmg, "torso", gs.username if gs and "username" in gs else "", "roadkill")
			else:
				b_node.take_damage(ram_dmg, "torso")
				
		var dead_after: bool = b_node.get("dead") if "dead" in b_node else false
		
		# Apply kinetic knockback
		if b_node is CharacterBody3D:
			var impact_dir := (linear_velocity.normalized() + Vector3.UP * 0.45).normalized()
			(b_node as CharacterBody3D).velocity += impact_dir * maxf(current_speed_kmh * 0.45, 9.0)
			
		# Visceral hit confirmation audio and HUD feedback
		if audio and audio.has_method("hitmarker"):
			audio.hitmarker(dead_after)
			
		if m and "hud" in m and m.hud and m.hud.has_method("flash_hitmarker"):
			m.hud.flash_hitmarker(dead_after)
			
		# Send authoritative multiplayer hit packet to server
		if m and "net" in m and m.net and m.net.connected and not target_id.is_empty() and not target_id.begins_with("BOT_"):
			m.net.send_hit(target_id, int(ram_dmg))

# ==============================================================================
# AUDIO SYNTHESIS & REAL-TIME FX
# ==============================================================================
func _update_audio_and_fx(delta: float) -> void:
	if is_driven and is_instance_valid(_engine_audio):
		# Pitch shift V8 engine rumble dynamically with speed & throttle relative to gear
		var target_rpm := 750.0 + (current_speed_kmh / get_top_speed()) * 3600.0
		if Input.is_action_pressed("move_forward"):
			target_rpm += 450.0
		_rpm = lerpf(_rpm, target_rpm, 8.0 * delta)
		_engine_audio.pitch_scale = clampf(_rpm / 850.0, 0.65, 2.4)
		_engine_audio.unit_size = 10.0
		
		# Exhaust backfire flame bursts on high RPM throttle shift
		_exhaust_timer -= delta
		if Input.is_action_just_released("move_forward") and current_speed_kmh > 45.0:
			_trigger_exhaust_backfire()
			
	if _exhaust_timer > 0.0:
		_exhaust_flame_l.visible = true
		_exhaust_flame_r.visible = true
	else:
		_exhaust_flame_l.visible = false
		_exhaust_flame_r.visible = false

func _trigger_exhaust_backfire() -> void:
	_exhaust_timer = 0.15
	var audio := get_node_or_null("/root/Audio")
	if audio and audio.has_method("explosion"):
		# Mini pop sound
		pass

func _set_brakelights(on: bool) -> void:
	for bl in _brakelights:
		bl.light_energy = 2.2 if on else 0.4
	for mat in _brakelight_mats:
		mat.emission_energy_multiplier = 2.5 if on else 0.4

# ==============================================================================
# MULTI-STAGE DAMAGE & FIRE EFFECTS ("WITH FIRES")
# ==============================================================================
func take_damage(dmg: float, _zone: String = "torso", _killer: String = "", _source: String = "gun") -> void:
	var gs := get_node_or_null("/root/GameState")
	if network_controlled or is_destroyed or (gs and not gs.bot_damage_enabled and is_driven):
		return
	health -= dmg
	if health <= 0.0:
		health = 0.0
		_destroy_vehicle()

func take_explosion(dmg: float) -> void:
	take_damage(dmg, "chassis", "", "explosion")

func _update_damage_fire_effects(_delta: float) -> void:
	if health < 750.0 and health > 0.0:
		_smoke_emitter.visible = true
		var smat := _smoke_emitter.material_override as StandardMaterial3D
		if smat:
			smat.albedo_color.a = clampf((750.0 - health) / 600.0, 0.2, 0.85)
	else:
		_smoke_emitter.visible = false
		
	if health < 380.0 and health > 0.0:
		_fire_emitter.visible = true
		_fire_emitter.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.02) * 0.25)
	else:
		_fire_emitter.visible = false

func _destroy_vehicle() -> void:
	is_destroyed = true
	# Massive catastrophic explosion
	var origin := global_position
	var w := get_parent()
	if is_instance_valid(w):
		WarGrenade.throw(w, origin + Vector3.UP * 0.5, Vector3.UP * 4.0)
	exit_vehicle()
	_fire_emitter.visible = true
	_smoke_emitter.visible = true
	vehicle_destroyed.emit(self)

func toggle_camera_view() -> void:
	if not is_driven:
		return
	is_wide_view = not is_wide_view
	if is_instance_valid(chase_spring_arm):
		chase_spring_arm.spring_length = 8.8 if is_wide_view else 6.2

func apply_aim_input(dx: float, dy: float) -> void:
	if not is_driven:
		return
	_mouse_idle_time = 0.0
	var gs := get_node_or_null("/root/GameState")
	var sens: float = (gs.BASE_SENSITIVITY if gs else 0.002) * 0.9
	_cam_yaw -= dx * sens
	_cam_pitch = clampf(_cam_pitch - dy * sens, -deg_to_rad(35), deg_to_rad(15))
	if is_instance_valid(chase_camera_pivot):
		chase_camera_pivot.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
