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
const SkeletalHitboxesScript: Script = preload("res://scripts/core/skeletal_hitboxes.gd")

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
var _jump_cooldown := 0.0

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
var _current_anim := ""
var _hitbox_areas: Array[Area3D] = []
var _hitbox_helper: Node
var _weapon_model: Node3D
var _bone_attachment: BoneAttachment3D
var _nameplate: Label3D
var _los_query: PhysicsRayQueryParameters3D = null

@onready var soldier: Node3D = $Soldier
@onready var anim: AnimationPlayer = $Soldier/AnimationPlayer

static func create_bot(bname: String, _pos: Vector3, bteam: String = "B") -> WarBot:
	var b := SCENE.instantiate() as WarBot
	b.bot_name = bname
	b.team = bteam
	b.name = "bot_%s" % bname
	return b

func _ready() -> void:
	collision_layer = 2 # Soldier / Combatant layer (matches Player.gd)
	collision_mask = 1 | 4 # Collide with World (1) and Vehicles (4)
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(46.0)
	floor_constant_speed = true
	_flank_side = 1.0 if (randf() > 0.5) else -1.0
	_jump_cooldown = randf_range(1.5, 3.5)
	
	# Pre-allocated ray query for zero-allocation AI vision checks
	_los_query = PhysicsRayQueryParameters3D.new()
	_los_query.collision_mask = 1 | 4
	_los_query.exclude = [get_rid()]
	
	if anim:
		for anim_name in ["Rifle Idle", "Rifle Run", "Firing walk Rifle", "Strafe Left", "Strafe Right", "Walking Backwards"]:
			if anim.has_animation(anim_name):
				anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		if anim.has_animation("Rifle Jump"):
			anim.get_animation("Rifle Jump").loop_mode = Animation.LOOP_NONE
				
	_setup_team_visuals()
	_sanitize_soldier_materials(soldier)
	_setup_weapon()
	
	_nameplate = Label3D.new()
	_nameplate.text = " %s  [100]" % bot_name
	_nameplate.font_size = 28
	_nameplate.pixel_size = 0.0032
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nameplate.no_depth_test = false
	_nameplate.render_priority = 10
	_nameplate.outline_render_priority = 9
	_nameplate.outline_size = 10
	_nameplate.outline_modulate = Color(0.0, 0.0, 0.0, 0.95)
	_nameplate.position = Vector3(0, 2.18, 0)
	_nameplate.modulate = Color(1.0, 0.35, 0.3) if team == "B" else Color(0.35, 0.65, 1.0)
	add_child(_nameplate)
	
	var hit_skeleton := soldier.get_node_or_null("Armature/Skeleton3D") as Skeleton3D
	_hitbox_helper = SkeletalHitboxesScript.new()
	_hitbox_areas = _hitbox_helper.setup(self, hit_skeleton, bot_name)
	
	_play("Rifle Idle")

func _setup_weapon() -> void:
	var skel: Skeleton3D = soldier.get_node_or_null("Armature/Skeleton3D") as Skeleton3D
	_weapon_model = WeaponView.build("ak47")
	_weapon_model.name = "BotWeapon"
	
	if skel and skel.find_bone("mixamorig_RightHand") != -1:
		_bone_attachment = BoneAttachment3D.new()
		_bone_attachment.bone_name = "mixamorig_RightHand"
		_bone_attachment.name = "RightHandSocket"
		skel.add_child(_bone_attachment)
		# Armature in AnimatedSoldier has a scale of (0.01, 0.01, 0.01)
		# Scaling by 72.0 inside Skeleton3D produces a nicely proportioned military rifle in the hand
		_weapon_model.scale = Vector3(72.0, 72.0, 72.0)
		_weapon_model.position = Vector3(2.0, -4.0, 1.0)
		_weapon_model.rotation_degrees = Vector3(90.0, 106.0, 0.0)
		_bone_attachment.add_child(_weapon_model)
	else:
		_weapon_model.scale = Vector3(0.85, 0.85, 0.85)
		_weapon_model.position = Vector3(0.22, 1.22, -0.32)
		add_child(_weapon_model)

func _setup_team_visuals() -> void:
	var beacon_color := Color(1.0, 0.2, 0.15) if team == "B" else Color(0.2, 0.5, 1.0)
	var beacon_mat := StandardMaterial3D.new()
	beacon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beacon_mat.albedo_color = beacon_color
	
	for offset in [Vector3(-0.25, 1.45, 0.0), Vector3(0.25, 1.45, 0.0)]:
		var beacon := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.035
		bm.height = 0.07
		beacon.mesh = bm
		beacon.position = offset
		beacon.material_override = beacon_mat
		add_child(beacon)

func _sanitize_soldier_materials(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var mat = mi.get_surface_override_material(s)
				if not mat:
					mat = mi.mesh.surface_get_material(s)
				if mat is StandardMaterial3D:
					var m: StandardMaterial3D = mat.duplicate()
					m.roughness = clampf(m.roughness, 0.88, 0.98)
					m.metallic_specular = 0.05
					m.metallic = 0.0
					mi.set_surface_override_material(s, m)
	for c in n.get_children():
		_sanitize_soldier_materials(c)

func _play(anim_name: String) -> void:
	if _current_anim == anim_name or (dead and anim_name != "Dying"):
		return
	_current_anim = anim_name
	if anim and anim.has_animation(anim_name):
		anim.play(anim_name, 0.22)

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
	var from := global_position + Vector3(0, 1.5, 0)
	var to: Vector3 = _target.global_position + Vector3(0, 1.2, 0)
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
		
	var target_eye: Vector3 = _target.global_position + Vector3(0, 1.4, 0)
	var best_pos := global_position
	var best_score := -9999.0
	
	# Test 6 candidate sample points (6 radial directions at 7.0m)
	# High-performance tactical sampling: 6 queries instead of 32 queries
	var sample_dist := 7.0
	for i in 6:
		var ang := (TAU / 6.0) * float(i)
		var offset: Vector3 = Vector3(cos(ang), 0.0, sin(ang)) * sample_dist
		var candidate: Vector3 = global_position + offset
		
		# Ensure candidate is over solid ground
		var ground_q := PhysicsRayQueryParameters3D.create(candidate + Vector3(0, 1.0, 0), candidate - Vector3(0, 2.0, 0))
		ground_q.collision_mask = 1
		ground_q.exclude = [get_rid()]
		var g_hit := w.direct_space_state.intersect_ray(ground_q)
		if g_hit.is_empty():
			continue
		candidate.y = float(g_hit.get("position", candidate).y)
		
		# Check line of sight from candidate to target
		var test_eye: Vector3 = candidate + Vector3(0, 1.3, 0)
		var los_q := PhysicsRayQueryParameters3D.create(test_eye, target_eye)
		los_q.collision_mask = 1
		los_q.exclude = [get_rid()]
		var los_hit := w.direct_space_state.intersect_ray(los_q)
		
		# A point is valid cover IF geometry blocks line of sight to target
		var provides_cover: bool = not los_hit.is_empty() and float(los_hit.get("position", target_eye).distance_to(test_eye)) < test_eye.distance_to(target_eye) - 0.5
		if provides_cover:
			# Score: prefers closer cover that maintains reasonable tactical distance from target
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
	if is_instance_valid(_nameplate):
		_nameplate.text = " %s  [%d]" % [bot_name, int(maxf(0.0, health))]
		
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
			
	# Evasive reaction bunny-hop when taking fire
	if is_on_floor() and _jump_cooldown <= 0.4 and randf() < 0.55:
		velocity.y = 5.2
		_jump_cooldown = randf_range(2.0, 3.8)
		_play("Rifle Jump")
			
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
		if is_instance_valid(_weapon_model):
			_weapon_model.visible = false
			
		var main = get_tree().current_scene
		if main and main.has_method("spawn_death_blood"): main.spawn_death_blood(global_position)
		_play("Dying")
		var tw := get_tree().create_tween()
		tw.tween_interval(3.0)
		tw.tween_callback(func() -> void:
			if is_instance_valid(self) and dead:
				var m := get_parent()
				var sp: Vector3 = m.get_spawn_point() if (m and m.has_method("get_spawn_point")) else global_position
				respawn_at(sp)
		)

func respawn_at(pos: Vector3) -> void:
	global_position = pos + Vector3(0, 0.2, 0)
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
		_nameplate.text = " %s  [100]" % bot_name
		_nameplate.visible = true
	if is_instance_valid(_weapon_model):
		_weapon_model.visible = true
	_play("Rifle Idle")

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
	_jump_cooldown -= delta
	
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
					_play("Rifle Run")
				else:
					_is_wandering = false
					_state_timer = randf_range(1.5, 3.0)
					_play("Rifle Idle")
			else:
				_play("Rifle Idle")
				
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
				_play("Firing walk Rifle")
			else:
				# Arrived at last known position: hold and scan 360
				rotation.y += delta * 1.5
				_play("Rifle Idle")
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
					_play("Walking Backwards")
				elif dist > 24.0:
					# Long range: advance in bounding sprint
					target_vel = (facing * 0.8 + strafe_right * (_flank_side * 0.4)).normalized() * speed
					_play("Firing walk Rifle")
				else:
					# Mid-range: erratic tactical strafe
					target_vel = strafe_right * (_flank_side * speed * 0.75)
					if _flank_side > 0.0:
						_play("Strafe Right")
					else:
						_play("Strafe Left")
						
				# Execute disciplined burst fire
				_process_burst_fire(delta)
				
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
				_play("Rifle Run")
				
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
				_play("Rifle Run")
			else:
				# In cover: face outward towards last known target position and hold
				if is_instance_valid(_target):
					var to_t := _last_known_pos - global_position
					to_t.y = 0.0
					rotation.y = atan2(-to_t.normalized().x, -to_t.normalized().z)
				_play("Rifle Idle")
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
			_play("Rifle Run")
			if has_direct_los:
				_state = AIState.ENGAGE
				
	# Physics velocity integration
	var accel := 16.0 if target_vel.length() > 0.1 else 24.0
	velocity.x = move_toward(velocity.x, target_vel.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, accel * delta)
	
	# Dynamic Athletic Jump Triggers:
	if is_on_floor() and _jump_cooldown <= 0.0:
		# 1. Obstacle Vaulting: when moving forward and encountering a wall or curb (never vehicles)
		if is_on_wall() and target_vel.length() > 0.8:
			var hit_vehicle := false
			for i in get_slide_collision_count():
				var col := get_slide_collision(i)
				var c := col.get_collider()
				if c and (c.is_in_group("combat_jeeps") or ("collision_layer" in c and c.collision_layer & 4 != 0)):
					hit_vehicle = true
					break
			if not hit_vehicle:
				velocity.y = 5.4
				_jump_cooldown = 1.6
				_play("Rifle Jump")
		# 2. Combat Evasive Strafe / Bunny-Hop: during intense firefight
		elif (_state == AIState.ENGAGE or _state == AIState.FLANK):
			if randf() < 0.45:
				velocity.y = 5.2
				_jump_cooldown = randf_range(2.4, 4.5)
				_play("Rifle Jump")
			else:
				_jump_cooldown = 1.0
		# 3. Patrol / Observation Hopping: athletic terrain traversal
		elif target_vel.length() > 1.2 and randf() < 0.20:
			velocity.y = 4.8
			_jump_cooldown = randf_range(5.0, 8.5)
			_play("Rifle Jump")

	if not is_on_floor():
		velocity.y -= 18.0 * delta
		if velocity.y > -2.0:
			_play("Rifle Jump")
	else:
		if velocity.y < 0.0:
			velocity.y = -0.5
			
	move_and_slide()
	
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider and (collider.is_in_group("combat_jeeps") or ("collision_layer" in collider and collider.collision_layer & 4 != 0)):
			var normal := col.get_normal()
			if velocity.dot(-normal) > 0.0:
				velocity -= normal * velocity.dot(normal)
	
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	if _current_anim in ["Rifle Run", "Firing walk Rifle", "Strafe Left", "Strafe Right", "Walking Backwards"]:
		anim.speed_scale = clampf(horiz_speed / maxf(0.1, speed * 0.7), 0.7, 1.3)
	elif _current_anim == "Rifle Jump":
		anim.speed_scale = 1.1
	else:
		anim.speed_scale = 1.0
		
	if global_position.y < -5.0:
		take_damage(999.0, "torso")

# ==============================================================================
# BALLISTIC PREDICTIVE BURST FIRE SYSTEM
# ==============================================================================
func _process_burst_fire(_delta: float) -> void:
	if not is_instance_valid(_target) or dead or not _has_sensory_detection():
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
	if (gs and not gs.bot_damage_enabled) or not is_instance_valid(_target) or dead:
		return
		
	var from := global_position + Vector3(0, 1.25, 0)
	if is_instance_valid(_weapon_model):
		var mz := _weapon_model.get_node_or_null("Muzzle")
		if mz:
			from = (mz as Node3D).global_position
			
	var target_chest := _target.global_position + Vector3(0, 1.15, 0)
	var dist := from.distance_to(target_chest)
	
	# Predictive aim: calculate player velocity and lead the target
	var player_vel: Vector3 = _target.velocity if "velocity" in _target else Vector3.ZERO
	var bullet_flight_time: float = dist / 280.0
	var predicted_lead := player_vel * bullet_flight_time
	
	# Aim dispersion with authentic recoil climb
	var bloom := randf_range(0.12, 0.28)
	var dispersion := Vector3(randf_range(-bloom, bloom), randf_range(-bloom * 0.5, bloom * 0.5) + _burst_recoil_climb, randf_range(-bloom, bloom))
	var to: Vector3 = target_chest + predicted_lead + dispersion
	
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
