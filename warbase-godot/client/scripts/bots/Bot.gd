class_name WarBot
extends CharacterBody3D
## Studio Military Tactical Combat AI.
## Features:
## 1. Sensory Perception: 140 Vision Cone, 360 close-proximity radar, and auditory sensing (gunfire, footsteps).
## 2. Dynamic Tactical States: Patrol, Investigate, Flank, Combat Engage, Tactical Cover Retreat.
## 3. Real-Time Cover Evaluation: Radial raycasts to locate physical occlusion when wounded or under fire.
## 4. Ballistic Predictive Leading: Leads moving targets based on velocity vector and bullet flight time.
## 5. Burst-Fire Cadence: 3-5 round disciplined rifle bursts with authentic recoil climb.
## 6. Squad Coordination: Pincer flanking, role assignment, and synchronized crossfire.

signal died(bot_name: String, killer: String, is_headshot: bool, source: String)

const SCENE: PackedScene = preload("res://scenes/Bot.tscn")
const DroneFlight = preload("res://scripts/drones/DroneFlight.gd")
const HIT_RADIUS := WarGameState.DRONE_HIT_RADIUS

enum AIState {
	PATROL,
	INVESTIGATE,
	ENGAGE,
	FLANK,
	COVER,
	PINCER
}

var health := 100.0
var max_health := 100.0
var speed := 4.2
var bot_name := "BOT"
var team := "B"
var dead := false
var kills := 0
var deaths := 0
var _killed_by_bullet := false

var _target: Node3D
var _state: AIState = AIState.PATROL
var _state_timer := 0.0
var _is_wandering := false
var _wander_target := Vector3.ZERO
var _cover_target := Vector3.ZERO
var _flank_side := 1.0
var _flank_timer := 0.0

# Sensory & Memory
var _last_known_pos := Vector3.ZERO
var _has_seen_target := false
var _memory_timer := 0.0
var _reaction_timer := 0.0
var _has_acquired_target := false
var _los_timer := 0.0
var _cached_los := false

# Burst-Fire Weapon Mechanics
var _burst_rounds_left := 0
var _burst_shot_interval := 0.0
var _burst_cooldown := 0.0
var _burst_recoil_climb := 0.0

# Visuals & Components
var _hitbox_areas: Array[Area3D] = []
var _weapon_model: Node3D
var _nameplate: Label3D
var _los_query: PhysicsRayQueryParameters3D = null
var _floor_probe_timer := 0.0
var _hover_altitude := 0.8
var _aim_pitch := 0.0

@onready var drone: DroneVisual = $DroneVisual
var anim: AnimationPlayer

static func create_bot(bname: String, _pos: Vector3, bteam: String = "B") -> WarBot:
	var b := SCENE.instantiate() as WarBot
	b.bot_name = bname
	b.team = bteam
	b.name = "bot_%s" % bname
	b.position = _pos
	return b

func _ready() -> void:
	collision_layer = 2 # Soldier / Combatant layer (matches Player.gd)
	collision_mask = 1 | 4 # Collide with World (1) and Vehicles (4)
	_flank_side = 1.0 if (randf() > 0.5) else -1.0
	
	# Pre-allocated ray query for zero-allocation AI vision checks
	_los_query = PhysicsRayQueryParameters3D.new()
	_los_query.collision_mask = 1 | 4
	_los_query.exclude = [get_rid()]
	
	_setup_weapon()
	var initial_floor = ColyseusWorldGeometry.floor_height(global_position.x, global_position.z, global_position.y + 8.0)
	if initial_floor != null:
		_hover_altitude = float(initial_floor) + 0.9
	
	_nameplate = Label3D.new()
	WarUI.configure_nameplate(_nameplate)
	_nameplate.position = Vector3(0, 0.65, 0)
	WarUI.refresh_nameplate(_nameplate, bot_name, GameState.selected_mode != "FFA" and team == GameState.local_team, true)
	add_child(_nameplate)
	
	_setup_drone_hitbox()


func _setup_weapon() -> void:
	drone.configure(GameState.selected_mode != "FFA" and team == GameState.local_team, "ak47")
	_weapon_model = drone.get_payload()

func _setup_drone_hitbox() -> void:
	var area := Area3D.new()
	area.name = "BotDroneHitbox"
	area.set_meta("hitbox", true)
	area.set_meta("player_id", bot_name)
	area.set_meta("zone", "torso")
	area.set_meta("mult", 1.0)
	area.set_meta("from_bone", "coarse_body")
	area.set_meta("to_bone", "coarse_body")
	area.set_meta("radius", HIT_RADIUS)
	area.collision_layer = 4
	area.collision_mask = 0
	area.monitorable = true
	area.monitoring = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = HIT_RADIUS
	shape.shape = sphere
	area.add_child(shape)
	add_child(area)
	_hitbox_areas = [area]
	if is_instance_valid(_los_query):
		_los_query.exclude = [get_rid(), area.get_rid()]

func set_target(t: Node3D) -> void:
	_target = t

func _get_gs() -> Node:
	return get_node_or_null("/root/GameState")

# ==============================================================================
# SENSORY PERCEPTION SYSTEM
# ==============================================================================
func _has_sensory_detection() -> bool:
	var gs := _get_gs()
	if gs and not gs.bot_damage_enabled:
		return false
	if not is_instance_valid(_target) or not is_inside_tree() or dead:
		return false
	if _los_timer > 0.0:
		return _cached_los
		
	_los_timer = randf_range(0.10, 0.14)
	var from := global_position
	var to: Vector3 = _target.global_position
	var dist := from.distance_to(to)
	
	# Beyond max sensory range
	if dist > 55.0:
		_cached_los = false
		return false
		
	# Check 140-degree forward vision cone vs 360-degree close-proximity radar
	var to_dir := (to - from).normalized()
	to_dir.y = 0.0
	to_dir = to_dir.normalized()
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var angle := forward.angle_to(to_dir)
	
	# Close proximity radar: within 5.5m, bot detects target regardless of facing
	var in_fov := (angle < deg_to_rad(70.0)) or (dist < 5.5)
	if not in_fov:
		_cached_los = false
		return false
		
	# Physical raycast for geometry occlusion
	var w := get_world_3d()
	if not w:
		_cached_los = false
		return false
	_los_query.from = from
	_los_query.to = to
	var hit := w.direct_space_state.intersect_ray(_los_query)
	
	if hit.is_empty():
		_cached_los = true
	else:
		_cached_los = float(hit.get("position", to).distance_to(from)) >= dist - 0.6
		
	if _cached_los:
		_last_known_pos = _target.global_position
		_has_seen_target = true
		_memory_timer = 6.0
		
	return _cached_los

## Auditory perception: called when player shoots, sprints, or throws grenades
func hear_noise(noise_pos: Vector3, noise_radius: float) -> void:
	var gs := _get_gs()
	if dead or (gs and not gs.bot_damage_enabled):
		return
	var d := global_position.distance_to(noise_pos)
	if d <= noise_radius:
		# If not currently engaged with direct LOS, turn and investigate noise
		if _state != AIState.ENGAGE and _state != AIState.COVER:
			_last_known_pos = noise_pos
			_has_seen_target = true
			_memory_timer = 5.0
			_state = AIState.INVESTIGATE
			_state_timer = randf_range(3.0, 5.0)

## Squad radio call: called by BotManager when another squadmate spots an enemy
func receive_squad_alert(spotted_pos: Vector3, assigned_role: String) -> void:
	if dead or _state == AIState.ENGAGE or _state == AIState.COVER:
		return
	_last_known_pos = spotted_pos
	_has_seen_target = true
	_memory_timer = 6.0
	if assigned_role == "flanker_left":
		_flank_side = -1.0
		_state = AIState.FLANK
		_state_timer = 4.0
	elif assigned_role == "flanker_right":
		_flank_side = 1.0
		_state = AIState.FLANK
		_state_timer = 4.0
	else:
		_state = AIState.PINCER
		_state_timer = 4.0

# ==============================================================================
# DYNAMIC TACTICAL COVER EVALUATION
# ==============================================================================
func _find_best_cover() -> Vector3:
	var w := get_world_3d()
	if not w or not is_instance_valid(_target):
		return global_position
		
	var target_center := _target.global_position
	var best_pos := global_position
	var best_score := -9999.0
	
	# Test six same-altitude flight positions behind nearby map geometry.
	# High-performance tactical sampling: 6 queries instead of 32 queries
	var sample_dist := 7.0
	for i in 6:
		var ang := (TAU / 6.0) * float(i)
		var offset: Vector3 = Vector3(cos(ang), 0.0, sin(ang)) * sample_dist
		var candidate: Vector3 = global_position + offset
		var resolved_candidate := ColyseusWorldGeometry.resolve_flight_move(global_position, candidate, GameState.DRONE_RADIUS)
		if resolved_candidate.distance_to(candidate) > 0.5:
			continue
		# Check the drone-center ray to the target drone's center.
		var los_q := PhysicsRayQueryParameters3D.create(candidate, target_center)
		los_q.collision_mask = 1
		los_q.exclude = [get_rid()]
		var los_hit := w.direct_space_state.intersect_ray(los_q)
		
		# A point is valid cover IF geometry blocks line of sight to target
		var provides_cover: bool = not los_hit.is_empty() and float(los_hit.get("position", target_center).distance_to(candidate)) < candidate.distance_to(target_center) - 0.5
		if provides_cover:
			# Score: prefers closer cover that maintains reasonable tactical distance from target
			candidate = resolved_candidate
			var dist_to_bot: float = global_position.distance_to(candidate)
			var dist_to_target: float = candidate.distance_to(_target.global_position)
			var score: float = 100.0 - dist_to_bot * 2.0 + clampf(dist_to_target, 8.0, 25.0)
			if score > best_score:
				best_score = score
				best_pos = candidate
				
	return best_pos

# ==============================================================================
# DAMAGE & ELIMINATION
# ==============================================================================
func take_damage(dmg: float, zone: String = "torso", killer: String = "", source: String = "gun") -> void:
	if dead:
		return
	health -= dmg
		
	# Under fire: turn toward target immediately & alert squad
	if is_instance_valid(_target):
		_last_known_pos = _target.global_position
		_has_seen_target = true
		_memory_timer = 6.0
		var to_attacker := (_target.global_position - global_position).normalized()
		rotation.y = atan2(-to_attacker.x, -to_attacker.z)
		
		# Broadcast to squadmates
		var mgr := get_parent()
		if mgr and mgr.has_method("squad_alert"):
			mgr.squad_alert(_last_known_pos, self)
			
	# Tactical retreat: when health drops below 45, prioritize cover
	if health < 45.0 and _state != AIState.COVER:
		if _cover_target == Vector3.ZERO or global_position.distance_to(_cover_target) < 1.5:
			_cover_target = _find_best_cover()
		_state = AIState.COVER
		_state_timer = randf_range(3.0, 5.0)
		
	if health <= 0.0:
		health = 0.0
		dead = true
		deaths += 1
		var gs := _get_gs()
		var default_user: String = gs.username if (gs and "username" in gs) else "OPERATOR"
		var actual_killer := killer if not killer.is_empty() else default_user
		died.emit(bot_name, actual_killer, zone == "head", source)
		
		for a in _hitbox_areas:
			if is_instance_valid(a):
				a.monitorable = false
				a.collision_layer = 0
		var main_col := get_node_or_null("CollisionShape3D") as CollisionShape3D
		if main_col:
			main_col.set_deferred("disabled", true)
		if is_instance_valid(_nameplate):
			_nameplate.visible = false
		if is_instance_valid(drone):
			drone.begin_crash(velocity)
		if is_instance_valid(_weapon_model):
			_weapon_model.visible = false

		var tw := get_tree().create_tween()
		tw.tween_interval(3.0)
		tw.tween_callback(func() -> void:
			if is_instance_valid(self) and dead:
				var m := get_parent()
				var sp: Vector3 = m.get_spawn_point() if (m and m.has_method("get_spawn_point")) else global_position
				respawn_at(sp)
		)

func respawn_at(pos: Vector3) -> void:
	global_position = pos + Vector3(0, 0.9, 0)
	velocity = Vector3.ZERO
	health = 100.0
	dead = false
	_is_wandering = false
	_state = AIState.PATROL
	_state_timer = randf_range(1.0, 3.0)
	_burst_cooldown = randf_range(0.5, 1.0)
	_reaction_timer = 0.0
	_has_acquired_target = false
	
	for a in _hitbox_areas:
		if is_instance_valid(a):
			a.monitorable = true
			a.collision_layer = 4
	var main_col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if main_col:
		main_col.set_deferred("disabled", false)
	if is_instance_valid(_nameplate):
		WarUI.refresh_nameplate(_nameplate, bot_name, GameState.selected_mode != "FFA" and team == GameState.local_team, true)
		_nameplate.visible = true
	if is_instance_valid(_weapon_model):
		_weapon_model.visible = true
	if is_instance_valid(drone):
		drone.configure(GameState.selected_mode != "FFA" and team == GameState.local_team, "ak47")
		drone.set_crash_hidden(false)
		_weapon_model = drone.get_payload()


func take_explosion(dmg: float) -> void:
	var gs := _get_gs()
	var user: String = gs.username if (gs and "username" in gs) else "OPERATOR"
	take_damage(dmg, "torso", user, "grenade")

# ==============================================================================
# TACTICAL BEHAVIOR & MOVEMENT LOOP
# ==============================================================================
func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector3.ZERO
		return
		
	_state_timer -= delta
	_flank_timer -= delta
	_los_timer -= delta
	_memory_timer -= delta
	_burst_shot_interval -= delta
	_burst_cooldown -= delta
	
	var has_direct_los := _has_sensory_detection()
	
	# Target acquisition reaction delay (humanized 160ms reaction latency)
	if has_direct_los:
		if not _has_acquired_target:
			_reaction_timer = randf_range(0.45, 0.75)
			_has_acquired_target = true
		else:
			_reaction_timer = maxf(0.0, _reaction_timer - delta)
	else:
		_has_acquired_target = false
		
	# State Transitions
	if has_direct_los and _reaction_timer <= 0.0:
		if health < 45.0 and _state == AIState.COVER:
			# Stay in cover if low HP
			pass
		else:
			var d: float = global_position.distance_to(_target.global_position)
			if d < 28.0:
				if _state != AIState.ENGAGE and _state != AIState.FLANK:
					_state = AIState.ENGAGE
					_flank_timer = randf_range(1.5, 3.0)
			else:
				if _state != AIState.FLANK and _state != AIState.ENGAGE:
					_state = AIState.FLANK
	elif _memory_timer > 0.0:
		# Lost sight but remembers last known position: sweep and investigate
		if _state == AIState.ENGAGE:
			_state = AIState.INVESTIGATE
			_state_timer = _memory_timer
	else:
		if _state != AIState.PATROL:
			_state = AIState.PATROL
			_state_timer = randf_range(1.0, 3.0)
			
	var target_vel := Vector3.ZERO
	var turn_speed := 9.0
	
	match _state:
		AIState.PATROL:
			if _state_timer <= 0.0:
				_is_wandering = not _is_wandering
				if _is_wandering:
					var rand_offset := Vector3(randf_range(-14.0, 14.0), 0.0, randf_range(-14.0, 14.0))
					_wander_target = global_position + rand_offset
					_state_timer = randf_range(3.0, 6.0)
				else:
					_state_timer = randf_range(1.5, 3.5)
					
			if _is_wandering:
				var to_dest := _wander_target - global_position
				to_dest.y = 0.0
				var dist := to_dest.length()
				if dist > 1.2:
					var wish_dir := to_dest.normalized()
					var target_yaw := atan2(-wish_dir.x, -wish_dir.z)
					var diff := wrapf(target_yaw - rotation.y, -PI, PI)
					rotation.y += diff * minf(1.0, turn_speed * 0.7 * delta)
					
					var facing := -global_transform.basis.z
					facing.y = 0.0
					target_vel = facing.normalized() * (speed * 0.55)
					if absf(diff) > deg_to_rad(40.0):
						target_vel *= 0.3

				else:
					_is_wandering = false
					_state_timer = randf_range(1.5, 3.0)

		AIState.INVESTIGATE:
			var to_lkp := _last_known_pos - global_position
			to_lkp.y = 0.0
			var dist := to_lkp.length()
			if dist > 2.0:
				var wish_dir := to_lkp.normalized()
				var target_yaw := atan2(-wish_dir.x, -wish_dir.z)
				var diff := wrapf(target_yaw - rotation.y, -PI, PI)
				rotation.y += diff * minf(1.0, turn_speed * delta)
				
				var facing := -global_transform.basis.z
				facing.y = 0.0
				target_vel = facing.normalized() * (speed * 0.8)

			else:
				# Arrived at last known position: hold and scan 360
				rotation.y += delta * 1.5

				if _state_timer <= 0.0:
					_state = AIState.PATROL
					
		AIState.ENGAGE:
			if is_instance_valid(_target):
				var to_target := _target.global_position - global_position
				to_target.y = 0.0
				var dist := to_target.length()
				var wish_dir := to_target.normalized()
				var target_yaw := atan2(-wish_dir.x, -wish_dir.z)
				var diff := wrapf(target_yaw - rotation.y, -PI, PI)
				rotation.y += diff * minf(1.0, 12.0 * delta)
				
				var facing := -global_transform.basis.z
				facing.y = 0.0
				facing = facing.normalized()
				var strafe_right := facing.cross(Vector3.UP).normalized()
				
				if _flank_timer <= 0.0:
					_flank_timer = randf_range(1.2, 2.4)
					_flank_side = -_flank_side if randf() < 0.6 else _flank_side
					
				if dist < 6.0:
					# Close-range defense: backpedal rapidly while shooting
					target_vel = -facing * (speed * 0.85)

				elif dist > 24.0:
					# Long range: advance in bounding sprint
					target_vel = (facing * 0.8 + strafe_right * (_flank_side * 0.4)).normalized() * speed

				else:
					# Mid-range: erratic tactical strafe
					target_vel = strafe_right * (_flank_side * speed * 0.75)
		AIState.FLANK:
			if is_instance_valid(_target):
				var to_target := _target.global_position - global_position
				to_target.y = 0.0
				var dist := to_target.length()
				
				# Flank vector angled 60 degrees laterally
				var tangent := to_target.cross(Vector3.UP).normalized() * _flank_side
				var flank_wish := (tangent * 0.75 + to_target.normalized() * 0.55).normalized()
				
				var target_yaw := atan2(-flank_wish.x, -flank_wish.z)
				var diff := wrapf(target_yaw - rotation.y, -PI, PI)
				rotation.y += diff * minf(1.0, 10.0 * delta)
				
				target_vel = flank_wish * speed

				
				if has_direct_los and dist < 20.0:
					_state = AIState.ENGAGE
					
		AIState.COVER:
			var to_cover := _cover_target - global_position
			to_cover.y = 0.0
			var dist := to_cover.length()
			if dist > 1.2:
				var wish_dir := to_cover.normalized()
				var target_yaw := atan2(-wish_dir.x, -wish_dir.z)
				var diff := wrapf(target_yaw - rotation.y, -PI, PI)
				rotation.y += diff * minf(1.0, 10.0 * delta)
				
				target_vel = wish_dir * (speed * 1.1) # Sprint to cover

			else:
				# In cover: face outward towards last known target position and hold
				if is_instance_valid(_target):
					var to_t := _last_known_pos - global_position
					to_t.y = 0.0
					rotation.y = atan2(-to_t.normalized().x, -to_t.normalized().z)

				if _state_timer <= 0.0:
					# Re-engage once regrouped
					_state = AIState.ENGAGE
					
		AIState.PINCER:
			var to_lkp := _last_known_pos - global_position
			to_lkp.y = 0.0
			var wish_dir := to_lkp.normalized()
			var target_yaw := atan2(-wish_dir.x, -wish_dir.z)
			var diff := wrapf(target_yaw - rotation.y, -PI, PI)
			rotation.y += diff * minf(1.0, 10.0 * delta)
			target_vel = wish_dir * speed

			if has_direct_los:
				_state = AIState.ENGAGE
				
	# Free flight uses the same map mesh collision resolver and 0.4 m radius as
	# player drones. Hover just above the floor when idle; during combat maintain
	# a modest vertical offset from the target instead of walking or jumping.
	var desired := target_vel
	if is_instance_valid(_target) and (_state == AIState.ENGAGE or _state == AIState.FLANK):
		desired.y = clampf((_target.global_position.y + 0.4 - global_position.y) * 1.5, -3.0, 3.0)
	else:
		_floor_probe_timer -= delta
		if _floor_probe_timer <= 0.0:
			_floor_probe_timer = 0.5
			var floor_value = ColyseusWorldGeometry.floor_height(global_position.x, global_position.z, global_position.y + 8.0)
			if floor_value != null:
				_hover_altitude = float(floor_value) + 0.9
		desired.y = clampf((_hover_altitude - global_position.y) * 2.0, -3.0, 3.0)
	_update_weapon_aim(delta, has_direct_los)
	var c := cos(rotation.y)
	var s := sin(rotation.y)
	var command := {
		"move_x": desired.x * c - desired.z * s,
		"move_y": desired.y / 6.0,
		"move_z": -desired.x * s - desired.z * c,
		"yaw": rotation.y,
		"sprint": 0.0
	}
	var flight: Dictionary = DroneFlight.step(global_position, velocity, command, delta)
	global_position = flight.position
	velocity = flight.velocity
	if is_instance_valid(drone):
		drone.apply_motion(velocity, rotation.y, _aim_pitch, false)
	if _state == AIState.ENGAGE and has_direct_los:
		_process_burst_fire(delta)

# ==============================================================================
# BALLISTIC PREDICTIVE BURST FIRE SYSTEM
# ==============================================================================
func _predicted_target_position(from_position: Vector3) -> Vector3:
	if not is_instance_valid(_target):
		return from_position
	var target_velocity: Vector3 = _target.velocity if "velocity" in _target else Vector3.ZERO
	var distance := from_position.distance_to(_target.global_position)
	return _target.global_position + target_velocity * (distance / 280.0)

func _update_weapon_aim(delta: float, has_direct_los: bool) -> void:
	if not is_instance_valid(_target):
		_aim_pitch = move_toward(_aim_pitch, 0.0, delta * 2.0)
		return
	var origin := drone.get_muzzle_global() if is_instance_valid(drone) else global_position
	var target_position := _predicted_target_position(origin)
	var aim_vector := target_position - origin
	var horizontal_distance := Vector2(aim_vector.x, aim_vector.z).length()
	if horizontal_distance < 0.001 and absf(aim_vector.y) < 0.001:
		return
	var target_yaw := atan2(-aim_vector.x, -aim_vector.z)
	var yaw_error := wrapf(target_yaw - rotation.y, -PI, PI)
	var yaw_rate := 10.0 if has_direct_los else 6.0
	rotation.y += yaw_error * minf(1.0, yaw_rate * delta)
	var target_pitch := clampf(atan2(aim_vector.y, maxf(horizontal_distance, 0.001)), -1.50, 1.50)
	var pitch_rate := 9.0 if has_direct_los else 5.0
	_aim_pitch = move_toward(_aim_pitch, target_pitch, pitch_rate * delta)

func _has_weapon_solution(max_error_degrees: float = 6.0) -> bool:
	if not is_instance_valid(_target) or not is_instance_valid(drone):
		return false
	var payload := drone.get_payload()
	if not is_instance_valid(payload):
		return false
	var origin := drone.get_muzzle_global()
	var target_vector := _predicted_target_position(origin) - origin
	if target_vector.length_squared() < 0.0001:
		return false
	var muzzle_forward := -payload.global_transform.basis.z.normalized()
	return muzzle_forward.angle_to(target_vector.normalized()) <= deg_to_rad(max_error_degrees)

func _process_burst_fire(_delta: float) -> void:
	if not is_instance_valid(_target) or dead or not _has_sensory_detection() or not _has_weapon_solution():
		_burst_rounds_left = 0
		return
		
	if _burst_rounds_left > 0:
		if _burst_shot_interval <= 0.0:
			_fire_single_bullet()
			_burst_rounds_left -= 1
			_burst_shot_interval = 0.10 # 600 RPM burst interval
			_burst_recoil_climb += 0.06
			if _burst_rounds_left <= 0:
				_burst_cooldown = randf_range(0.55, 0.95)
				_burst_recoil_climb = 0.0
	elif _burst_cooldown <= 0.0:
		# Start new 3-4 round burst
		_burst_rounds_left = randi_range(2, 3)
		_burst_shot_interval = 0.0
		_burst_recoil_climb = 0.0

func _fire_single_bullet() -> void:
	var gs := _get_gs()
	if (gs and not gs.bot_damage_enabled) or not is_instance_valid(_target) or dead or not _has_weapon_solution():
		return
	var from := drone.get_muzzle_global()
	var target_point := _predicted_target_position(from)
	var dist := from.distance_to(target_point)
	var muzzle_forward := -drone.get_payload().global_transform.basis.z.normalized()
	# Spread bends the actual muzzle direction by a small angle, so the tracer
	# follows the gimballed payload instead of inventing a separate rifle ray.
	var right := muzzle_forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.0001:
		right = muzzle_forward.cross(Vector3.RIGHT).normalized()
	var up := right.cross(muzzle_forward).normalized()
	var bloom := randf_range(0.002, 0.008)
	var spread_right := randf_range(-bloom, bloom)
	var spread_up := randf_range(-bloom * 0.5, bloom * 0.5) + _burst_recoil_climb * 0.005
	var shot_direction := (muzzle_forward + right * spread_right + up * spread_up).normalized()
	var to: Vector3 = from + shot_direction * maxf(dist, 1.0)
	
	var main := get_tree().current_scene
	if main and main.has_method("bot_shoot_fx"):
		main.bot_shoot_fx(from, to)
		
	if _target.has_method("take_bot_damage"):
		# Accuracy calculation: higher accuracy at close range, realistic drop-off at distance
		var hit_chance := clampf(0.85 - (dist / 40.0) * 0.45, 0.18, 0.75)
		if randf() < hit_chance:
			var prev_dead: bool = _target.is_dead if "is_dead" in _target else false
			_target.take_bot_damage(randf_range(8.0, 13.0), global_position)
			var now_dead: bool = _target.is_dead if "is_dead" in _target else false
			if now_dead and not prev_dead:
				kills += 1
				var m := get_tree().current_scene
				if m and "hud" in m and m.hud and m.hud.has_method("feed"):
					var user: String = gs.username if (gs and "username" in gs) else "OPERATOR"
					m.hud.feed("%s eliminated %s" % [bot_name, user], Color(1.0, 0.35, 0.3))
