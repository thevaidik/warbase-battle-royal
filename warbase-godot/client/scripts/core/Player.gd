class_name WarPlayer
extends CharacterBody3D
signal died
signal respawned
signal damaged(attacker_dir: Vector3, amount: float)

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
var yaw := 0.0
var pitch := 0.0
var body_yaw := 0.0
var body_yaw_rate := 0.0
var flight_pitch := 0.0
var flight_pitch_rate := 0.0
var is_sprinting := false
var is_dead := false
var current_fov := GameState.BASE_FOV
var health := 100.0
var max_health := 100.0
var ground_roll := 0.0
var wheel_suspension: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _since_damage := 0.0
var _spawn_protection := 2.5
var _dust_timer := 0.0
var _downdraft_timer := 0.0
var is_driving := false
var colyseus_authoritative_sim := false:
	set(enabled):
		colyseus_authoritative_sim = enabled
		# SDK display poses are already interpolated and written per render frame.
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF if enabled else Node.PHYSICS_INTERPOLATION_MODE_INHERIT
		if is_inside_tree(): reset_physics_interpolation()

func set_driving(driving: bool) -> void:
	is_driving = driving
	visible = not driving
	if is_instance_valid(_col):
		_col.disabled = driving
	if driving:
		collision_layer = 0
		collision_mask = 0
		velocity = Vector3.ZERO
		process_mode = Node.PROCESS_MODE_DISABLED
	else:
		collision_layer = 2
		collision_mask = 1 | 4
		velocity = Vector3.ZERO
		process_mode = Node.PROCESS_MODE_INHERIT

var _col: CollisionShape3D
func _ready() -> void:
	add_to_group("local_player")
	_col = $CollisionShape3D
	collision_layer = 2
	collision_mask = 1 | 4
	max_health = float(GameState.max_health_for_chassis(GameState.selected_drone_chassis))
	health = max_health
	camera.fov = GameState.BASE_FOV
	camera.current = true
	camera.far = 650.0
	camera.near = 0.08
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	head.position = Vector3(0,0.18,0)
	camera.position = Vector3(0,0.25,2.2)
	_drone_visual = load("res://scripts/drones/DroneVisual.gd").new()
	add_child(_drone_visual)
	_drone_visual.configure(true,GameState.weapon_id_for_index(GameState.starting_weapon_index()),GameState.selected_drone_chassis,"",GameState.selected_secondary)
	_drone_visual.set_payload_visible(true)
	_mask_local_drone_hardware(_drone_visual)
	_drone_camera_shape = SphereShape3D.new()
	_drone_camera_shape.radius = 0.18
	_drone_camera_sweep = PhysicsShapeQueryParameters3D.new()
	_drone_camera_sweep.shape = _drone_camera_shape
	_drone_camera_sweep.collision_mask = 1 | 4
	_drone_camera_sweep.collide_with_areas = false
	_drone_camera_sweep.collide_with_bodies = true
	_drone_camera_sweep.exclude = [get_rid()]
	_target_ray.exclude = [get_rid()]
	_target_ray.collision_mask = 1 | 4
	_target_ray.collide_with_areas = true
	_contact_shadow = MeshInstance3D.new()
	_contact_shadow.name = "PlayerContactShadow"
	_contact_shadow.mesh = load("res://scripts/drones/DroneVisualResources.gd").get_shadow_mesh()
	_contact_shadow.material_override = load("res://scripts/drones/DroneVisualResources.gd").get_shadow_material()
	_contact_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_contact_shadow)
	_engine_audio = AudioStreamPlayer3D.new()
	_engine_audio.name = "PlayerEngineAudio"
	_engine_audio.bus = "Master"
	_engine_audio.max_distance = 60.0
	_engine_audio.unit_size = 8.0
	_engine_audio.autoplay = false
	add_child(_engine_audio)
const DroneFlight = preload("res://scripts/drones/DroneFlight.gd")
var _drone_visual: Node3D
var _contact_shadow: MeshInstance3D
var _engine_audio: AudioStreamPlayer3D
var ability_cooldown := 0.0
const ABILITY_COOLDOWN_MAX := 10.0
var ability_active_timer := 0.0
var nitro_active := false
var airbrake_active := false
var _hull_critical_timer := 0.0
signal ability_activated(chassis: String, cooldown_max: float)
var _crash_focus: Node3D
var drone_range_m := 300.0
var _drone_camera_sweep: PhysicsShapeQueryParameters3D
var _drone_camera_shape: SphereShape3D
var _target_ray := PhysicsRayQueryParameters3D.new()
var aim_sway := Vector2.ZERO
var recoil_pitch := 0.0
var recoil_yaw := 0.0
var _shake_trauma := 0.0
var crosshair_on_enemy := false

func apply_recoil(p_kick: float, y_kick: float) -> void:
	recoil_pitch = clampf(recoil_pitch + p_kick, -0.25, 0.25)
	recoil_yaw += y_kick

func apply_grenade_shake(trauma: float) -> void:
	_shake_trauma = clampf(_shake_trauma + trauma, 0.0, 1.0)

func apply_look(dx: float, dy: float, ads_input: Variant = 0.0) -> void:
	if is_dead or is_driving:
		return
	var ads_weight: float = (float(ads_input) if (ads_input is float or ads_input is int) else (1.0 if ads_input else 0.0))
	var zoom_scale: float = clampf(tan(deg_to_rad(camera.fov) * 0.5) / tan(deg_to_rad(GameState.BASE_FOV) * 0.5), 0.08, 1.0)
	var sens: float = GameState.BASE_SENSITIVITY * lerpf(1.0, zoom_scale, clampf(ads_weight, 0.0, 1.0))
	if crosshair_on_enemy:
		sens *= 0.78
	yaw -= dx * sens
	pitch -= dy * sens
	pitch = clampf(pitch, -PI / 2.1, PI / 2.1)
	rotation.y = body_yaw + recoil_yaw
	head.rotation.x = clampf(pitch + recoil_pitch, -PI / 2.1, PI / 2.1)

func _process(delta: float) -> void:
	delta = clampf(delta,0.0,0.05)
	if is_dead:
		_update_drone_chase_camera()
		current_fov = lerpf(current_fov, GameState.BASE_FOV, 1.0 - exp(-9.0 * delta))
		camera.fov = current_fov
		if is_instance_valid(_crash_focus) and camera.global_position.distance_squared_to(_crash_focus.global_position) > 0.22:
			var aim := (_crash_focus.global_position - camera.global_position).normalized()
			var up := Vector3.UP if absf(aim.y) < 0.97 else camera.global_basis.x
			var target := Basis.looking_at(aim, up).get_rotation_quaternion()
			camera.global_basis = Basis(camera.global_basis.get_rotation_quaternion().slerp(target, 1.0 - exp(-9.0 * delta)))
		return
	if GameState.practice_mode:
		_since_damage += delta
		_spawn_protection = maxf(0.0,_spawn_protection-delta)
		if not is_dead and _since_damage>=5.0: health=minf(max_health,health+15.0*delta)
	recoil_pitch = lerpf(recoil_pitch,0.0,1.0-exp(-14.0*delta))
	recoil_yaw = lerpf(recoil_yaw,0.0,1.0-exp(-14.0*delta))
	rotation.y = body_yaw
	head.position = Vector3(0,0.18,0)
	head.rotation = Vector3(clampf(pitch+recoil_pitch,-1.48,1.48),wrapf(yaw - body_yaw + recoil_yaw, -PI, PI),0)
	var wsys := get_node_or_null("../WeaponSystem")
	_update_drone_chase_camera(wsys.ads_amount if wsys else 0.0)
	var target_fov := GameState.BASE_FOV
	if wsys and wsys.ads_amount>0.001: target_fov = lerpf(GameState.BASE_FOV, wsys.drone_optic_fov(), wsys.ads_amount)
	elif is_sprinting: target_fov += GameState.SPRINT_FOV_BOOST
	current_fov = lerpf(current_fov,target_fov,1.0-exp(-18.0*delta))
	camera.fov = current_fov
	_shake_trauma = maxf(0.0,_shake_trauma-delta*3.0)
	camera.rotation = Vector3.ZERO
	if is_instance_valid(_drone_visual):
		_drone_visual.apply_motion(velocity,rotation.y,flight_pitch,is_dead,ground_roll,wheel_suspension)
		if _drone_visual.has_method("aim_payload_at"):
			_drone_visual.call("aim_payload_at", _drone_crosshair_target(), wsys != null and wsys.dual_fire)
	if is_instance_valid(_contact_shadow):
		if is_dead or not visible:
			_contact_shadow.visible = false
		else:
			_contact_shadow.visible = true
			var chassis := GameState.selected_drone_chassis
			var is_ground := chassis in ["tracked", "wheels"]
			var ground_y: Variant = ColyseusWorldGeometry.floor_height(global_position.x, global_position.z, global_position.y + 0.5)
			if ground_y != null:
				var altitude := maxf(0.0, global_position.y - float(ground_y))
				_contact_shadow.global_position = Vector3(global_position.x, float(ground_y) + 0.015, global_position.z)
				var alpha_scale := clampf(1.0 - altitude / 4.0, 0.0, 1.0)
				var base_scale := 1.15 if chassis == "wheels" else (1.05 if is_ground else 0.90)
				var expand := 1.0 + altitude * 0.25
				_contact_shadow.scale = Vector3(base_scale * expand, 1.0, (base_scale * 1.2 if is_ground else base_scale) * expand)
				_contact_shadow.visible = alpha_scale > 0.02
			else:
				_contact_shadow.visible = false
	_update_engine_audio(delta)

func _drone_crosshair_target() -> Vector3:
	var ray_from := camera.global_position
	var ray_to := ray_from - camera.global_transform.basis.z.normalized() * 300.0
	_target_ray.from = ray_from
	_target_ray.to = ray_to
	var hit := get_world_3d().direct_space_state.intersect_ray(_target_ray)
	crosshair_on_enemy = false
	if not is_dead and not hit.is_empty():
		var target: Variant = hit["collider"]
		if target is Area3D and target.has_meta("hitbox"):
			target = target.get_parent()
		if target is WarBot or target is WarRemote:
			var team_game := GameState.selected_mode in ["TDM", "CONQUEST"]
			crosshair_on_enemy = not target.dead and (not team_game or target.team != GameState.local_team)
	var point := Vector3(hit.position) if not hit.is_empty() else ray_to
	drone_range_m = ray_from.distance_to(point)
	return point

func _update_drone_chase_camera(optic_weight := 0.0) -> void:
	if _drone_camera_sweep == null or not is_inside_tree(): return
	var offset := head.global_basis * Vector3(0, 0.25, 2.2) * (1.0 - optic_weight)
	_drone_camera_sweep.transform = Transform3D(Basis.IDENTITY, head.global_position)
	_drone_camera_sweep.motion = offset
	var space := get_world_3d().direct_space_state
	var start_overlap := not space.intersect_shape(_drone_camera_sweep, 1).is_empty()
	var travel := space.cast_motion(_drone_camera_sweep)
	var safe_fraction := 0.0 if start_overlap else (float(travel[0]) if travel.size() >= 2 and travel[1] < 1.0 else 1.0)
	camera.global_position = head.global_position + offset * maxf(0.0, safe_fraction - 0.02)
	if is_instance_valid(_drone_visual): _drone_visual.visible = not is_dead and camera.global_position.distance_to(global_position) >= 0.65

func apply_authoritative_motion(next_velocity: Vector3, sprinting: bool) -> void:
	velocity = next_velocity
	is_sprinting = sprinting

func _physics_process(delta: float) -> void:
	if is_dead or is_driving or not GameState.online_ready:
		velocity = Vector3.ZERO
		return
	if ability_cooldown > 0.0:
		ability_cooldown = maxf(0.0, ability_cooldown - delta)
	if ability_active_timer > 0.0:
		ability_active_timer = maxf(0.0, ability_active_timer - delta)
		if ability_active_timer <= 0.0:
			nitro_active = false
			airbrake_active = false
	if nitro_active:
		var fwd := Vector3(-sin(body_yaw), 0, -cos(body_yaw))
		velocity += fwd * (22.0 * delta)
	elif airbrake_active:
		velocity = velocity.move_toward(Vector3.ZERO, 38.0 * delta)
	if health > 0.0 and health <= max_health * 0.25 and not is_dead:
		_hull_critical_timer += delta
		if _hull_critical_timer >= 0.20:
			_hull_critical_timer = 0.0
			var effects = get_tree().get_first_node_in_group("drone_combat_effects")
			if effects and effects.has_method("emit_critical_hull_smoke"):
				var rear_offset := Vector3(sin(body_yaw), 0.12, cos(body_yaw)) * 0.35
				effects.call("emit_critical_hull_smoke", global_position + rear_offset, velocity)
	var chassis := GameState.selected_drone_chassis
	var tracked := chassis in ["tracked", "wheels"]
	if not tracked and not is_dead and is_inside_tree():
		_downdraft_timer = maxf(0.0, _downdraft_timer - delta)
		if _downdraft_timer <= 0.0:
			_downdraft_timer = 0.16
			var world_3d := get_world_3d()
			if world_3d:
				var space_state := world_3d.direct_space_state
				var ray_down := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 4.5, 1, [get_rid()])
				var hit := space_state.intersect_ray(ray_down)
				if not hit.is_empty():
					var effects = get_tree().get_first_node_in_group("drone_combat_effects")
					if effects and effects.has_method("ground_dust"):
						var ground_pos: Vector3 = hit["position"]
						if global_position.distance_to(ground_pos) > 0.4:
							var dust_vel := Vector3(randf_range(-1.2, 1.2), 0.15, randf_range(-1.2, 1.2))
							effects.ground_dust(ground_pos, dust_vel)
	var steer := Input.get_axis("move_left", "move_right")
	var throttle := Input.get_axis("move_back", "move_forward")
	if tracked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and get_window().has_focus():
		var steering_rate := lerpf(2.2, 1.4, clampf(velocity.length() / 4.8, 0.0, 1.0))
		var forward_speed := velocity.dot(Vector3(-sin(body_yaw), 0, -cos(body_yaw)))
		var is_reversing := throttle < -0.05 or (throttle <= 0.05 and forward_speed < -0.25)
		if chassis == "wheels":
			var speed_sign := -1.0 if is_reversing else (1.0 if forward_speed > 0.1 else (1.0 if throttle >= 0.0 else -1.0))
			steering_rate = speed_sign * lerpf(2.0, 1.1, clampf(absf(forward_speed) / 14.5, 0.0, 1.0))
		elif is_reversing:
			steering_rate = -steering_rate
		body_yaw_rate = move_toward(body_yaw_rate, -steer * steering_rate, 4.0 * delta)
	var turn_limit := 1.35 if chassis in ["tracked", "wheels"] else (1.7 if chassis == "wing" else 2.4)
	var turn_accel := 3.6 if chassis in ["tracked", "wheels"] else 4.0
	var yaw_error := wrapf(yaw - body_yaw, -PI, PI)
	if not tracked:
		body_yaw_rate = move_toward(body_yaw_rate, clampf(yaw_error * 2.2, -turn_limit, turn_limit), turn_accel * delta)
	elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not get_window().has_focus():
		body_yaw_rate = move_toward(body_yaw_rate, 0.0, 4.0 * delta)
	body_yaw = wrapf(body_yaw + body_yaw_rate * delta, -PI, PI)
	if tracked:
		_update_ground_surface(delta)
	else:
		ground_roll = move_toward(ground_roll, 0.0, 6.0 * delta)
		for i in range(4):
			wheel_suspension[i] = move_toward(wheel_suspension[i], 0.0, 8.0 * delta)
		var pitch_target := clampf(pitch, -0.55, 0.55) if chassis == "wing" else 0.0
		flight_pitch_rate = move_toward(flight_pitch_rate, clampf((pitch_target - flight_pitch) * 3.0, -1.6, 1.6), 3.2 * delta)
		flight_pitch = clampf(flight_pitch + flight_pitch_rate * delta, -0.65, 0.65)
	if colyseus_authoritative_sim: return
	var vertical_input := DroneFlight.climb_input(chassis, throttle, flight_pitch)
	var command := {"move_x": 0.0 if tracked else steer, "move_z": throttle, "move_y": vertical_input, "yaw": body_yaw, "sprint": 1.0 if Input.is_action_pressed("sprint") else 0.0, "mobility_mode": chassis}
	var flight := DroneFlight.step(global_position,velocity,command,delta)
	global_position = flight.position
	velocity = flight.velocity
	is_sprinting = command.sprint>0.5

func _update_ground_surface(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var forward := Vector3(-sin(body_yaw), 0, -cos(body_yaw))
	var right := Vector3(cos(body_yaw), 0, -sin(body_yaw))
	var chassis := GameState.selected_drone_chassis
	var is_wheels := chassis == "wheels"
	var wheelbase := 0.20 if is_wheels else 0.26
	var track_width := 0.26 if is_wheels else 0.19
	var offsets: Array[Vector3] = [
		forward * wheelbase - right * track_width,  # 0: Front-Left
		forward * wheelbase + right * track_width,  # 1: Front-Right
		-forward * wheelbase - right * track_width, # 2: Rear-Left
		-forward * wheelbase + right * track_width, # 3: Rear-Right
	]
	var hits_y: Array[float] = []
	var ray_query := PhysicsRayQueryParameters3D.new()
	ray_query.collision_mask = 1
	ray_query.exclude = [get_rid()]
	for i in range(4):
		var sample_pt: Vector3 = global_position + offsets[i]
		var origin: Vector3 = sample_pt + Vector3.UP * 0.8
		var target: Vector3 = sample_pt - Vector3.UP * 1.5
		ray_query.from = origin
		ray_query.to = target
		var hit: Dictionary = space.intersect_ray(ray_query) if space else {}
		if not hit.is_empty():
			hits_y.append(float(hit.position.y))
		else:
			var f: Variant = ColyseusWorldGeometry.floor_height(sample_pt.x, sample_pt.z, sample_pt.y + 0.5)
			if f != null:
				hits_y.append(float(f))
			else:
				hits_y.append(global_position.y - 0.4)
	var front_y := (hits_y[0] + hits_y[1]) * 0.5
	var rear_y := (hits_y[2] + hits_y[3]) * 0.5
	var dz := front_y - rear_y
	var target_pitch := clampf(atan2(dz, wheelbase * 2.0), -deg_to_rad(45.0), deg_to_rad(45.0))
	var left_y := (hits_y[0] + hits_y[2]) * 0.5
	var right_y := (hits_y[1] + hits_y[3]) * 0.5
	var dx := right_y - left_y
	var target_roll := clampf(atan2(dx, track_width * 2.0), -deg_to_rad(30.0), deg_to_rad(30.0))
	flight_pitch = move_toward(flight_pitch, target_pitch, 8.0 * delta)
	ground_roll = move_toward(ground_roll, target_roll, 8.0 * delta)
	for i in range(4):
		var ref_y := front_y if i < 2 else rear_y
		var disp := clampf(hits_y[i] - ref_y, -0.08, 0.08)
		wheel_suspension[i] = move_toward(wheel_suspension[i], disp, 12.0 * delta)
	_dust_timer = maxf(0.0, _dust_timer - delta)
	var spd := velocity.length()
	if spd > 1.2 and _dust_timer <= 0.0:
		_dust_timer = 0.09
		var effects = get_tree().get_first_node_in_group("drone_combat_effects")
		if effects and effects.has_method("ground_dust"):
			effects.ground_dust(global_position + offsets[2], -forward * spd * 0.25)
			effects.ground_dust(global_position + offsets[3], -forward * spd * 0.25)

func take_bot_damage(dmg: float, attacker_pos: Vector3 = Vector3.ZERO) -> void:
	if is_dead or _spawn_protection > 0 or not GameState.practice_mode or not GameState.bot_damage_enabled:
		return
	_since_damage = 0.0
	var final_dmg := dmg
	var dir := Vector3.ZERO
	if attacker_pos != Vector3.ZERO:
		dir = (attacker_pos - global_position).normalized()
		if GameState.selected_drone_chassis in ["tracked", "wheels"]:
			var is_top_attack := dir.y > 0.5736
			if not is_top_attack:
				var forward := Vector3(-sin(body_yaw), 0, -cos(body_yaw))
				var horizontal_dir := Vector3(dir.x, 0, dir.z).normalized()
				var cos_angle := forward.dot(horizontal_dir)
				if cos_angle > 0.5:
					final_dmg = roundf(dmg * 0.75)
					var effects = get_tree().get_first_node_in_group("drone_combat_effects")
					if effects and effects.has_method("deflect_sparks"):
						effects.call("deflect_sparks", global_position + forward * 0.35, forward)
					Audio.ricochet()
				elif cos_angle < -0.5:
					final_dmg = roundf(dmg * 1.5)
	health -= final_dmg
	Audio.hurt()
	damaged.emit(dir, final_dmg)
	if health <= 0.0:
		health = 0.0
		kill()

func take_damage(dmg: float, _zone: String = "torso") -> void:
	take_bot_damage(dmg)

func take_explosion(dmg: float) -> void:
	take_bot_damage(dmg)

func end_spawn_protection() -> void:
	_spawn_protection = 0.0

func heal_full() -> void:
	max_health = float(GameState.max_health_for_chassis(GameState.selected_drone_chassis))
	health = max_health
	_since_damage = 0.0
	_spawn_protection = 2.5

func kill() -> void:
	if is_dead:
		return
	is_dead = true
	if is_instance_valid(_drone_visual):
		_crash_focus = _drone_visual.call("begin_crash", velocity) as Node3D
	died.emit()

func apply_deployed_chassis() -> void:
	max_health = float(GameState.max_health_for_chassis(GameState.selected_drone_chassis))
	if is_instance_valid(_drone_visual) and _drone_visual.get("chassis_id") != GameState.selected_drone_chassis:
		_drone_visual.call("set_chassis", GameState.selected_drone_chassis)

func respawn_at(pos: Vector3) -> void:
	max_health = float(GameState.max_health_for_chassis(GameState.selected_drone_chassis))
	health = max_health
	ground_roll = 0.0
	wheel_suspension = [0.0, 0.0, 0.0, 0.0]
	_crash_focus = null
	if is_instance_valid(_drone_visual): _drone_visual.call("set_crash_hidden", false)
	global_position = pos
	velocity = Vector3.ZERO
	yaw = 0.0
	pitch = 0.0
	body_yaw = 0.0
	body_yaw_rate = 0.0
	flight_pitch = 0.0
	flight_pitch_rate = 0.0
	rotation.y = 0.0
	head.rotation.x = 0.0
	head.position = Vector3(0, 0.18, 0)
	camera.position = Vector3(0, 0.25, 2.2)
	camera.rotation = Vector3.ZERO
	recoil_pitch = 0.0
	recoil_yaw = 0.0
	reset_physics_interpolation()
	is_dead = false
	respawned.emit()

func _mask_local_drone_hardware(node: Node) -> void:
	if node is VisualInstance3D: node.layers |= 1
	for child in node.get_children(): _mask_local_drone_hardware(child)

func activate_ability() -> void:
	if is_dead or is_driving or ability_cooldown > 0.0:
		return
	ability_cooldown = ABILITY_COOLDOWN_MAX
	var chassis := GameState.selected_drone_chassis
	match chassis:
		"tracked":
			_deploy_smoke_screen()
		"wheels":
			_deploy_nitro_boost()
		"heli":
			_deploy_flares()
		"wing":
			_deploy_airbrake()
	ability_activated.emit(chassis, ABILITY_COOLDOWN_MAX)

func _deploy_smoke_screen() -> void:
	Audio.ability_activate("smoke")
	var effects = get_tree().get_first_node_in_group("drone_combat_effects")
	if effects and effects.has_method("deploy_smoke_screen"):
		effects.call("deploy_smoke_screen", global_position, 8)
	var main = get_tree().current_scene
	if main:
		if "net" in main and main.net and main.net.has_method("send_smoke"):
			main.net.send_smoke(global_position)
		if main.has_node("HUD"):
			main.get_node("HUD").call("post_radio_chatter", "TANK-1", "Deploying thermal smoke screen.", "amber")

func _deploy_nitro_boost() -> void:
	Audio.ability_activate("nitro")
	nitro_active = true
	ability_active_timer = 2.8
	var forward := Vector3(-sin(body_yaw), 0, -cos(body_yaw))
	velocity += forward * 6.5
	var effects = get_tree().get_first_node_in_group("drone_combat_effects")
	if effects and effects.has_method("deploy_nitro_burst"):
		effects.call("deploy_nitro_burst", global_position - forward * 0.4, -forward)
	var main = get_tree().current_scene
	if main and main.has_node("HUD"):
		main.get_node("HUD").call("post_radio_chatter", "WHEELS-1", "Nitro overdrive engaged!", "cyan")

func _deploy_flares() -> void:
	Audio.ability_activate("flares")
	var rear := Vector3(sin(body_yaw), 0, cos(body_yaw))
	var effects = get_tree().get_first_node_in_group("drone_combat_effects")
	if effects and effects.has_method("deploy_flares"):
		effects.call("deploy_flares", global_position + rear * 0.35, rear, 5)
	var main = get_tree().current_scene
	if main:
		if "net" in main and main.net and main.net.has_method("send_smoke"):
			main.net.send_smoke(global_position)
		if main.has_node("HUD"):
			main.get_node("HUD").call("post_radio_chatter", "HELI-1", "Flares deployed! Defending airspace.", "amber")

func _deploy_airbrake() -> void:
	Audio.ability_activate("airbrake")
	airbrake_active = true
	ability_active_timer = 0.8
	velocity *= 0.40
	var effects = get_tree().get_first_node_in_group("drone_combat_effects")
	if effects and effects.has_method("deploy_nitro_burst"):
		var rear := Vector3(sin(body_yaw), 0, cos(body_yaw))
		effects.call("deploy_nitro_burst", global_position, rear)
	var main = get_tree().current_scene
	if main and main.has_node("HUD"):
		main.get_node("HUD").call("post_radio_chatter", "JET-1", "Airbrake deployed for high-G turn.", "cyan")

func _unhandled_input(event: InputEvent) -> void:
	if is_dead or is_driving: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F or event.physical_keycode == KEY_F:
			activate_ability()
		elif event.keycode in [KEY_C, KEY_X] or event.physical_keycode in [KEY_C, KEY_X]:
			if GameState.selected_drone_chassis in ["tracked", "wheels"]:
				_deploy_smoke_screen()
			else:
				activate_ability()

func _update_engine_audio(delta: float) -> void:
	if not is_instance_valid(_engine_audio): return
	if is_dead or is_driving or not WarAudioManager.AUDIO_ENABLED or not is_inside_tree():
		if _engine_audio.playing: _engine_audio.stop()
		return
	var chassis := GameState.selected_drone_chassis
	var stream := Audio.get_engine_stream(chassis)
	if _engine_audio.stream != stream:
		_engine_audio.stream = stream
	if not _engine_audio.playing:
		_engine_audio.play()
	var speed := velocity.length()
	var target_pitch := 1.0
	match chassis:
		"tracked":
			target_pitch = clampf(0.85 + (speed / 8.5) * 0.50, 0.75, 1.55)
		"wheels":
			var throttle_add := 0.18 if Input.is_action_pressed("move_forward") else 0.0
			target_pitch = clampf(0.80 + (speed / 14.5) * 0.70 + throttle_add, 0.70, 1.85)
		"heli":
			target_pitch = clampf(0.92 + (speed / 12.0) * 0.28, 0.85, 1.35)
		"wing":
			target_pitch = clampf(0.85 + (speed / 18.0) * 0.55, 0.80, 1.65)
	_engine_audio.pitch_scale = lerpf(_engine_audio.pitch_scale, target_pitch, 6.0 * delta)
