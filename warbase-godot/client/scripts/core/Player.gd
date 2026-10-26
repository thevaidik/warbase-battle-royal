class_name WarPlayer
extends CharacterBody3D
## AAA FPS player controller.
## Ported from client/src/ecs/systems/PlayerMovementSystem.ts with best Godot 4.3+ practices:
## Smooth stair step climbing, landing compression, strafe tilt, procedural footsteps,
## responsive coyote jump buffer, dynamic ADS zoom lerping, and damage feedback.

signal died
signal respawned
signal damaged(attacker_dir: Vector3, amount: float)

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay

var yaw := 0.0
var pitch := 0.0
var is_crouching := false
var is_sprinting := false
var is_grounded := false
var is_dead := false
var jump_cooldown := 0.0
var coyote := 0.0
var current_fov := GameState.BASE_FOV
var stand_height := 1.8
var crouch_height := 1.2
var stand_cam_y := 1.65
var crouch_cam_y := 1.05
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)
var health := 100.0
var _since_damage := 0.0
var _spawn_protection := 2.5
var is_driving := false

func set_driving(driving: bool) -> void:
	_step_active = false
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
var _step_dist := 0.0
var _step_active := false
var _step_target_y := 0.0
var _stand_clear_shape: CapsuleShape3D
var _land_dip := 0.0
var _land_pitch := 0.0
var _jump_kick_pitch := 0.0
var _jump_kick_dip := 0.0
var _air_tilt_pitch := 0.0
var _camera_roll := 0.0
var _air_roll := 0.0
var _step_query_low: PhysicsRayQueryParameters3D
var _step_query_high: PhysicsRayQueryParameters3D

func _ready() -> void:
	_col = $CollisionShape3D
	_col.shape = _col.shape.duplicate()
	_stand_clear_shape = CapsuleShape3D.new()
	_stand_clear_shape.radius = 0.4
	_stand_clear_shape.height = stand_height - 0.02
	collision_layer = 2
	collision_mask = 1 | 4
	camera.fov = GameState.BASE_FOV
	camera.current = true
	camera.far = 650.0
	camera.near = 0.08
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# Professional slope & obstacle handling configuration
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(60.0)
	floor_constant_speed = true
	floor_block_on_wall = false
	floor_stop_on_slope = false
	wall_min_slide_angle = deg_to_rad(0.0)
	safe_margin = 0.08
	
	# Pre-allocated zero-overhead physics queries for 120Hz obstacle climbing
	_step_query_low = PhysicsRayQueryParameters3D.new()
	_step_query_low.exclude = [get_rid()]
	_step_query_low.collision_mask = 1
	
	_step_query_high = PhysicsRayQueryParameters3D.new()
	_step_query_high.exclude = [get_rid()]
	_step_query_high.collision_mask = 1

var aim_sway := Vector2.ZERO
var recoil_pitch := 0.0
var recoil_yaw := 0.0
var _shake_trauma := 0.0

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
	yaw -= dx * sens
	pitch -= dy * sens
	pitch = clampf(pitch, -PI / 2.1, PI / 2.1)
	rotation.y = yaw + recoil_yaw
	head.rotation.x = clampf(pitch + recoil_pitch, -PI / 2.1, PI / 2.1)

func _process(delta: float) -> void:
	if is_dead:
		head.position.y = move_toward(head.position.y, 0.65, delta * 2.0)
		camera.rotation.z = lerpf(camera.rotation.z, -0.16, clampf(delta * 4.0, 0.0, 1.0))
		return
	if is_driving:
		return
	if GameState.practice_mode:
		_since_damage += delta
		_spawn_protection = maxf(0, _spawn_protection - delta)
		if _since_damage >= 5.0: health = minf(100, health + 15.0 * delta)
	delta = minf(delta, 0.05)
	# High-refresh per-frame camera recoil recovery and orientation
	recoil_pitch = lerpf(recoil_pitch, 0.0, 14.0 * delta)
	recoil_yaw = lerpf(recoil_yaw, 0.0, 14.0 * delta)
	rotation.y = yaw + recoil_yaw
	head.rotation.x = clampf(pitch + recoil_pitch, -PI / 2.1, PI / 2.1)
	
	# Dynamic jump & landing spring mechanics (AAA grounded physics)
	_land_dip = lerpf(_land_dip, 0.0, 14.0 * delta)
	_jump_kick_dip = lerpf(_jump_kick_dip, 0.0, 16.0 * delta)
	_land_pitch = lerpf(_land_pitch, 0.0, 14.0 * delta)
	_jump_kick_pitch = lerpf(_jump_kick_pitch, 0.0, 12.0 * delta)
	
	if is_grounded:
		_air_tilt_pitch = lerpf(_air_tilt_pitch, 0.0, 14.0 * delta)
		_air_roll = lerpf(_air_roll, 0.0, 14.0 * delta)
	else:
		var target_air_pitch := clampf(-velocity.y * 0.004, -0.028, 0.028)
		_air_tilt_pitch = lerpf(_air_tilt_pitch, target_air_pitch, 8.0 * delta)
		var ix := Input.get_axis("move_left", "move_right")
		var target_air_roll := -ix * 0.035
		_air_roll = lerpf(_air_roll, target_air_roll, 10.0 * delta)

	var target_head_y := (crouch_cam_y if is_crouching else stand_cam_y) - _land_dip - _jump_kick_dip
	head.position.y = lerpf(head.position.y, target_head_y, 16.0 * delta)
	
	# Head aiming pitch (true weapon raycast axis)
	head.rotation.x = clampf(pitch + recoil_pitch, -PI / 2.1, PI / 2.1)
	
	head.rotation.z = 0.0
	# Blast trauma screen shake decay
	if _shake_trauma > 0.001:
		_shake_trauma = maxf(0.0, _shake_trauma - 2.8 * delta)
		var shake_p := _shake_trauma * _shake_trauma
		head.rotation.z = (randf() * 2.0 - 1.0) * shake_p * 0.12
		head.rotation.x += (randf() * 2.0 - 1.0) * shake_p * 0.08
	
	# Camera local rotation: procedural body physics (jump tilt, landing nod, roll)
	var wsys := get_node_or_null("../WeaponSystem")
	var ads_weight: float = wsys.ads_amount if wsys else 0.0
	camera.rotation.x = (_land_pitch + _jump_kick_pitch + _air_tilt_pitch) * (1.0 - ads_weight * 0.9) + aim_sway.y
	camera.rotation.y = aim_sway.x
	
	# Strafe camera roll (stabilized during ADS for accurate sight alignment)
	var ix := Input.get_axis("move_left", "move_right")
	var roll_damp := (0.35 if (wsys and wsys.ads_amount > 0.3) else 1.0)
	var target_roll := -ix * 0.02 * roll_damp + (_air_roll if not is_grounded else 0.0)
	_camera_roll = lerpf(_camera_roll, target_roll, 12.0 * delta)
	camera.rotation.z = _camera_roll
	
	# Silky smooth continuous FOV transition matching S-curve
	var target_fov := GameState.BASE_FOV
	if wsys and wsys.ads_amount > 0.001:
		var ads_fov: float = wsys.get_current_ads_fov() if wsys.has_method("get_current_ads_fov") else float(wsys.current_config()["ads_fov"])
		target_fov = lerpf(GameState.BASE_FOV, ads_fov, wsys.ads_amount)
	elif is_sprinting:
		target_fov = GameState.BASE_FOV + GameState.SPRINT_FOV_BOOST
	current_fov = lerpf(current_fov, target_fov, clampf(24.0 * delta, 0.0, 1.0))
	camera.fov = current_fov

func _physics_process(delta: float) -> void:
	if is_dead or is_driving or not GameState.online_ready:
		velocity = Vector3.ZERO
		return
		
	jump_cooldown = maxf(0.0, jump_cooldown - delta)
	coyote = maxf(0.0, coyote - delta)
	var was_grounded := is_grounded
	is_grounded = is_on_floor()
	
	# Landing thump & knee shock compression feedback
	if not was_grounded and is_grounded and velocity.y <= -2.0:
		var impact: float = absf(velocity.y)
		_land_dip = clampf(impact * 0.016, 0.035, 0.12)
		_land_pitch = clampf(impact * 0.007, 0.025, 0.075)
		_air_roll = clampf(-velocity.x * 0.004, -0.025, 0.025)
		Audio.step()
	
	if was_grounded and not is_grounded:
		coyote = 0.12
		
	# Input direction
	var ix := Input.get_axis("move_left", "move_right")
	var iz := Input.get_axis("move_back", "move_forward")
	var wish := Vector3(ix, 0, iz)
	if wish.length() > 1.0:
		wish = wish.normalized()
		
	var fwd := -global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var right := global_transform.basis.x
	right.y = 0
	right = right.normalized()
	
	var wants_crouch := Input.is_action_pressed("crouch")
	is_crouching = wants_crouch or (is_crouching and not _can_stand())
	is_sprinting = Input.is_action_pressed("sprint") and iz > 0.1 and is_grounded and not is_crouching and not Input.is_action_pressed("ads")
	
	var speed := GameState.WALK_SPEED
	if is_sprinting:
		speed = GameState.SPRINT_SPEED
	if is_crouching:
		speed = GameState.CROUCH_SPEED
	if Input.is_action_pressed("ads"):
		speed *= 0.65
		
	var wsys := get_node_or_null("../WeaponSystem")
	if wsys and wsys.is_firing and is_grounded and not is_crouching:
		speed *= 0.6
	if iz < -0.1:
		speed *= 0.6
		
	var strafe_mult := 0.65
	var target := (fwd * wish.z + right * (wish.x * strafe_mult)) * speed
	var accel := 0.0
	if is_grounded:
		accel = 40.0 if wish.length() > 0.01 else 55.0
	else:
		accel = 22.0 if wish.length() > 0.01 else 6.0
		
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	
	# Gravity + jump (with dynamic floor snap management)
	if is_grounded:
		floor_snap_length = 0.35
		if velocity.y < 0.0:
			velocity.y = -0.5
		if Input.is_action_just_pressed("jump") and jump_cooldown <= 0.0:
			velocity.y = GameState.JUMP_IMPULSE
			jump_cooldown = 0.15
			coyote = 0.0
			floor_snap_length = 0.0
			_on_jump_takeoff()
	else:
		floor_snap_length = 0.0
		velocity.y -= gravity * delta
		if Input.is_action_just_pressed("jump") and coyote > 0.0 and jump_cooldown <= 0.0:
			velocity.y = GameState.JUMP_IMPULSE
			jump_cooldown = 0.15
			coyote = 0.0
			floor_snap_length = 0.0
			_on_jump_takeoff()
			
	# Step only onto a walkable ledge after validating the entire capsule path.
	var horiz_vel := Vector2(velocity.x, velocity.z).length()
	var wish_len := wish.length()
	if is_grounded and wish_len > 0.01:
		var space := get_world_3d().direct_space_state
		var move_dir := (fwd * wish.z + right * (wish.x * strafe_mult)).normalized()
		var max_step := 0.45
		var probe_distance := 0.52
		_step_query_low.from = global_position + Vector3.UP * 0.2
		_step_query_low.to = _step_query_low.from + move_dir * 0.65
		if not space.intersect_ray(_step_query_low).is_empty():
			_step_query_high.from = global_position + move_dir * probe_distance + Vector3.UP * max_step
			_step_query_high.to = global_position + move_dir * probe_distance + Vector3.UP * 0.02
			var top := space.intersect_ray(_step_query_high)
			if not top.is_empty() and Vector3(top.normal).y > 0.7:
				var rise: float = float(top.position.y) - global_position.y + 0.02
				if rise > 0.03 and rise <= max_step:
					var raised := global_transform.translated(Vector3.UP * rise)
					var clearance := PhysicsShapeQueryParameters3D.new()
					clearance.shape = _col.shape
					clearance.transform = _col.global_transform.translated(Vector3.UP * rise + move_dir * probe_distance)
					clearance.collision_mask = collision_mask
					clearance.exclude = [get_rid()]
					clearance.margin = 0.005
					if not test_move(global_transform, Vector3.UP * rise, null, 0.005) and not test_move(raised, move_dir * probe_distance, null, 0.005) and space.intersect_shape(clearance).is_empty():
						_step_active = true
						_step_target_y = global_position.y + rise

	if wish_len <= 0.01 or Input.is_action_just_pressed("jump"): _step_active = false
	if _step_active:
		var lift := minf(maxf(0, _step_target_y-global_position.y), 5.5*delta)
		if not test_move(global_transform, Vector3.UP*lift, null, 0.005):
			global_position.y += lift
			velocity.y = 0
			# Keep diagonal stair movement inside the authority's 12 m/s budget.
			var max_horizontal := sqrt(maxf(0.0, 144.0-pow(lift/maxf(delta,0.0001),2)))
			var horizontal := Vector2(velocity.x,velocity.z).limit_length(max_horizontal)
			velocity.x = horizontal.x
			velocity.z = horizontal.y
		else: _step_active = false
		if global_position.y >= _step_target_y-0.001: _step_active = false
	move_and_slide()
	
	# Procedural footstep audio cadence
	if is_grounded and horiz_vel > 0.5:
		_step_dist += horiz_vel * delta
		var interval := 1.7 if is_sprinting else (2.6 if is_crouching else 2.1)
		if _step_dist >= interval:
			_step_dist = 0.0
			Audio.step()
			if is_sprinting:
				var world_node := get_parent()
				if world_node and world_node.has_node("Bots"):
					var bm = world_node.get_node("Bots")
					if bm and bm.has_method("report_noise"):
						bm.report_noise(global_position, 14.0)
	else:
		_step_dist = 0.0
		
	# Void fall recovery: if player slips below the arena floor, teleport back to safe ground
	var fall_limit := -119.0 if GameState.selected_map == "canyon" else -14.0
	if global_position.y < fall_limit:
		_step_active = false
		var main := get_tree().current_scene
		if main and "map_builder" in main and main.map_builder and not main.map_builder.spawn_points.is_empty():
			var sps: Array[Vector3] = main.map_builder.spawn_points
			global_position = sps[0] + Vector3(0, 0.2, 0)
		else:
			global_position = Vector3(0, 1.0, 0)
		velocity = Vector3.ZERO
		
	# Crouch capsule height
	var target_h := crouch_height if is_crouching else stand_height
	var cap := _col.shape as CapsuleShape3D
	if cap:
		cap.height = lerpf(cap.height, target_h, 10.0 * delta)
		_col.position.y = cap.height * 0.5

func _can_stand() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _stand_clear_shape
	query.transform = Transform3D(global_basis, global_position + Vector3.UP * (stand_height * 0.5 + 0.01))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.margin = 0.005
	return get_world_3d().direct_space_state.intersect_shape(query).is_empty()

func take_bot_damage(dmg: float, attacker_pos: Vector3 = Vector3.ZERO) -> void:
	if is_dead or _spawn_protection > 0 or not GameState.practice_mode or not GameState.bot_damage_enabled:
		return
	_since_damage = 0.0
	health -= dmg
	Audio.hurt()
	var dir := Vector3.ZERO
	if attacker_pos != Vector3.ZERO:
		dir = (attacker_pos - global_position).normalized()
	damaged.emit(dir, dmg)
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
	health = 100.0
	_since_damage = 0.0
	_spawn_protection = 2.5

func kill() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit()

func respawn_at(pos: Vector3) -> void:
	_step_active = false
	global_position = pos + Vector3(0, 0.2, 0)
	velocity = Vector3.ZERO
	yaw = 0.0
	pitch = 0.0
	rotation.y = 0.0
	head.rotation.x = 0.0
	head.position.y = stand_cam_y
	camera.rotation = Vector3.ZERO
	_camera_roll = 0.0
	recoil_pitch = 0.0
	recoil_yaw = 0.0
	reset_physics_interpolation()
	is_dead = false
	respawned.emit()

func _on_jump_takeoff() -> void:
	# Kinetic leg spring compression & forward head nod impulse
	_jump_kick_dip = 0.035
	_jump_kick_pitch = deg_to_rad(-2.4)
	_air_roll = (randf() - 0.5) * deg_to_rad(1.2)
	Audio.step()
