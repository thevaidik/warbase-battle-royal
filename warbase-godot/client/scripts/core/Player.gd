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
var _since_damage := 0.0
var _spawn_protection := 2.5
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
	_col = $CollisionShape3D
	collision_layer = 2
	collision_mask = 1 | 4
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
const DroneFlight = preload("res://scripts/drones/DroneFlight.gd")
var _drone_visual: Node3D
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
		if not is_dead and _since_damage>=5.0: health=minf(100.0,health+15.0*delta)
	recoil_pitch = lerpf(recoil_pitch,0.0,1.0-exp(-14.0*delta))
	recoil_yaw = lerpf(recoil_yaw,0.0,1.0-exp(-14.0*delta))
	rotation.y = yaw+recoil_yaw
	head.position = Vector3(0,0.18,0)
	head.rotation = Vector3(clampf(pitch+recoil_pitch,-1.48,1.48),0,0)
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
		_drone_visual.apply_motion(velocity,rotation.y,flight_pitch,is_dead)
		if _drone_visual.has_method("aim_payload_at"):
			_drone_visual.call("aim_payload_at", _drone_crosshair_target(), wsys != null and wsys.dual_fire)

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
	var chassis := GameState.selected_drone_chassis
	var tracked := chassis == "tracked"
	var steer := Input.get_axis("move_left", "move_right")
	if tracked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and get_window().has_focus():
		var steering_rate := lerpf(1.8, 1.1, clampf(velocity.length() / 4.5, 0.0, 1.0))
		yaw = wrapf(yaw - steer * steering_rate * delta, -PI, PI)
	var turn_limit := 0.85 if chassis in ["tracked", "wheels"] else (1.7 if chassis == "wing" else 2.4)
	var turn_accel := 1.8 if chassis in ["tracked", "wheels"] else 4.0
	var yaw_error := wrapf(yaw - body_yaw, -PI, PI)
	body_yaw_rate = move_toward(body_yaw_rate, clampf(yaw_error * 2.2, -turn_limit, turn_limit), turn_accel * delta)
	body_yaw = wrapf(body_yaw + body_yaw_rate * delta, -PI, PI)
	var pitch_target := clampf(pitch, -0.55, 0.55) if chassis == "wing" else 0.0
	flight_pitch_rate = move_toward(flight_pitch_rate, clampf((pitch_target - flight_pitch) * 3.0, -1.6, 1.6), 3.2 * delta)
	flight_pitch = clampf(flight_pitch + flight_pitch_rate * delta, -0.65, 0.65)
	if colyseus_authoritative_sim: return
	var throttle := Input.get_axis("move_back", "move_forward")
	var vertical_input := DroneFlight.climb_input(chassis, throttle, flight_pitch)
	var command := {"move_x": 0.0 if tracked else steer, "move_z": throttle, "move_y": vertical_input, "yaw": body_yaw, "sprint": 1.0 if Input.is_action_pressed("sprint") else 0.0, "mobility_mode": chassis}
	var flight := DroneFlight.step(global_position,velocity,command,delta)
	global_position = flight.position
	velocity = flight.velocity
	is_sprinting = command.sprint>0.5

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
	if is_instance_valid(_drone_visual):
		_crash_focus = _drone_visual.call("begin_crash", velocity) as Node3D
	died.emit()

func apply_deployed_chassis() -> void:
	if is_instance_valid(_drone_visual) and _drone_visual.get("chassis_id") != GameState.selected_drone_chassis:
		_drone_visual.call("set_chassis", GameState.selected_drone_chassis)

func respawn_at(pos: Vector3) -> void:
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
