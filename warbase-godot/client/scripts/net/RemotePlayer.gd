class_name WarRemote
extends Node3D
## Render-time replicated drone actor. Root transform and the centered sphere
## belong to networking/gameplay; DroneVisual owns only the airframe presentation.

const SCENE: PackedScene = preload("res://scenes/RemotePlayer.tscn")
const HIT_RADIUS := WarGameState.DRONE_HIT_RADIUS

var player_id := ""
var team := "A"
var weapon_id := "ak47"
var primary_payload := ""
var secondary_payload := ""
var mobility_mode := "heli"
var current_anim := ""
var health := 100.0
var hit_view_time_ms := 0
var dead := false
var is_driving := false
var sdk_pose_driven := false
var server_authoritative_remote_pose := false

var _buf: Array = []
var _render_delay := 0.065
var _hit_react := 0.0
var _shot_kick := 0.0
var _weapon_aim_target := Vector3.ZERO
var _weapon_aim_until_ms := 0
var _lod_timer := 0.0
var _current_lod := 0
var _hitbox_areas: Array[Area3D] = []
var health_label: Label3D
var _head_area: Area3D
var _torso_area: Area3D
var _limb_areas: Array[Area3D] = []
var _previous_render_position := Vector3.ZERO
var _visual_velocity := Vector3.ZERO
var _remote_pitch := 0.0
var _remote_roll := 0.0
var _remote_suspension: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _contact_shadow: MeshInstance3D
var _remote_engine_audio: AudioStreamPlayer3D
var _remote_critical_smoke_timer := 0.0
var _remote_flash_light: OmniLight3D

func _update_remote_ground_surface(dt: float) -> void:
	if mobility_mode not in ["tracked", "wheels"] or dead:
		_remote_pitch = move_toward(_remote_pitch, 0.0, 4.0 * dt)
		_remote_roll = move_toward(_remote_roll, 0.0, 4.0 * dt)
		for i in range(4):
			_remote_suspension[i] = move_toward(_remote_suspension[i], 0.0, 6.0 * dt)
		return
	var forward := Vector3(-sin(global_rotation.y), 0, -cos(global_rotation.y))
	var right := Vector3(cos(global_rotation.y), 0, -sin(global_rotation.y))
	var is_wheels := mobility_mode == "wheels"
	var wheelbase := 0.20 if is_wheels else 0.26
	var track_width := 0.26 if is_wheels else 0.19
	var offsets: Array[Vector3] = [
		forward * wheelbase - right * track_width,  # 0: FL
		forward * wheelbase + right * track_width,  # 1: FR
		-forward * wheelbase - right * track_width, # 2: RL
		-forward * wheelbase + right * track_width, # 3: RR
	]
	var hits_y: Array[float] = []
	for i in range(4):
		var sample_pt := global_position + offsets[i]
		var f: Variant = ColyseusWorldGeometry.floor_height(sample_pt.x, sample_pt.z, sample_pt.y + 0.6)
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
	_remote_pitch = move_toward(_remote_pitch, target_pitch, 8.0 * dt)
	_remote_roll = move_toward(_remote_roll, target_roll, 8.0 * dt)
	for i in range(4):
		var ref_y := front_y if i < 2 else rear_y
		var disp := clampf(hits_y[i] - ref_y, -0.08, 0.08)
		_remote_suspension[i] = move_toward(_remote_suspension[i], disp, 10.0 * dt)

@onready var drone: DroneVisual = $DroneVisual
@onready var name_label: Label3D = $Nameplate

static func create(pid: String, st: Dictionary, deferred: bool = false) -> WarRemote:
	var remote := SCENE.instantiate() as WarRemote
	remote.player_id = pid
	remote.name = "remote_%s" % pid
	remote.set_meta("init_state", st)
	if deferred:
		remote.set_meta("deferred_visual", true)
		var d = remote.get_node_or_null("DroneVisual")
		if is_instance_valid(d):
			d.deferred_construction = true
			d.visible = false
	return remote

var _is_fallback_visual := false
var _fallback_hull: MeshInstance3D
static var _shared_fallback_mesh: Mesh
static var _shared_fallback_mat_friendly: Material
static var _shared_fallback_mat_enemy: Material

func attach_fallback_visual() -> void:
	if is_instance_valid(drone):
		drone.deferred_construction = true
		drone.visible = false
	if not is_instance_valid(_fallback_hull):
		_fallback_hull = MeshInstance3D.new()
		_fallback_hull.name = "FallbackHull"
		if _shared_fallback_mesh == null:
			var box := BoxMesh.new()
			box.size = Vector3(0.35, 0.12, 0.40)
			_shared_fallback_mesh = box
		if _shared_fallback_mat_friendly == null:
			var m_f := StandardMaterial3D.new()
			m_f.albedo_color = Color("596a77")
			m_f.roughness = 0.5
			_shared_fallback_mat_friendly = m_f
			var m_e := StandardMaterial3D.new()
			m_e.albedo_color = Color("847b73")
			m_e.roughness = 0.5
			_shared_fallback_mat_enemy = m_e
		_fallback_hull.mesh = _shared_fallback_mesh
		_fallback_hull.material_override = _shared_fallback_mat_friendly if _is_friendly() else _shared_fallback_mat_enemy
		_fallback_hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_fallback_hull)
	_is_fallback_visual = true

func _apply_visual_loadout() -> void:
	if not is_instance_valid(drone) or drone.deferred_construction: return
	var pri := primary_payload
	var sec := secondary_payload
	var active_w := weapon_id
	if pri.is_empty() and not active_w.is_empty():
		pri = active_w
	drone.configure(_is_friendly(), pri, mobility_mode, "", sec)
	if not active_w.is_empty() and active_w != pri:
		drone.set_weapon(active_w)
	if dead:
		drone.set_crash_hidden(true)
	if _current_lod > 0:
		drone.set_visual_lod(_current_lod)

func step_visual_upgrade(st: Dictionary = {}, stage: int = 0) -> int:
	if not st.is_empty():
		team = String(st.get("team", team))
		var new_w := String(st.get("weapon", weapon_id))
		if not new_w.is_empty() and new_w != "vehicle":
			weapon_id = new_w
		primary_payload = String(st.get("primary_payload", st.get("primary", primary_payload)))
		secondary_payload = String(st.get("secondary_payload", st.get("secondary", secondary_payload)))
		mobility_mode = String(st.get("mobility_mode", st.get("chassis", mobility_mode)))
		dead = bool(st.get("is_dead", false)) or String(st.get("anim", "")) == "death"

	var pri := primary_payload
	var sec := secondary_payload
	var active_w := weapon_id
	if pri.is_empty() and not active_w.is_empty():
		pri = active_w

	match stage:
		0:
			if is_instance_valid(drone):
				drone.prepare_body(_is_friendly(), mobility_mode)
			return 1
		1:
			if is_instance_valid(drone):
				drone.prepare_payloads(pri, sec, active_w)
			return 2
		2:
			if is_instance_valid(_fallback_hull):
				_fallback_hull.queue_free()
				_fallback_hull = null
			_is_fallback_visual = false
			set_meta("deferred_visual", false)
			if is_instance_valid(drone):
				drone.finalize_visual()
				if not active_w.is_empty() and active_w != pri:
					drone.set_weapon(active_w)
				if dead:
					drone.set_crash_hidden(true)
				if _current_lod > 0:
					drone.set_visual_lod(_current_lod)
			return -1
	return -1

func upgrade_to_full_visual(st: Dictionary = {}) -> void:
	step_visual_upgrade(st, 0)
	step_visual_upgrade(st, 1)
	step_visual_upgrade(st, 2)

func _ready() -> void:
	add_to_group("remote_players")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var st: Dictionary = get_meta("init_state", {})
	team = String(st.get("team", "A"))
	weapon_id = String(st.get("weapon", "ak47"))
	primary_payload = String(st.get("primary_payload", st.get("primary", "")))
	secondary_payload = String(st.get("secondary_payload", st.get("secondary", "")))
	mobility_mode = String(st.get("mobility_mode", "heli"))
	if weapon_id.is_empty() or weapon_id == "vehicle":
		weapon_id = "ak47"
	var deferred: bool = bool(get_meta("deferred_visual", false))
	if deferred:
		attach_fallback_visual()
	elif is_instance_valid(drone):
		_apply_visual_loadout()
	_setup_server_authoritative_hitbox()
	_contact_shadow = MeshInstance3D.new()
	_contact_shadow.name = "RemoteContactShadow"
	_contact_shadow.mesh = load("res://scripts/drones/DroneVisualResources.gd").get_shadow_mesh()
	_contact_shadow.material_override = load("res://scripts/drones/DroneVisualResources.gd").get_shadow_material()
	_contact_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_contact_shadow)
	_remote_engine_audio = AudioStreamPlayer3D.new()
	_remote_engine_audio.name = "RemoteEngineAudio"
	_remote_engine_audio.unit_size = 6.0
	_remote_engine_audio.max_distance = 45.0
	_remote_engine_audio.volume_db = -12.0
	_remote_engine_audio.bus = "Master"
	_remote_engine_audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(_remote_engine_audio)
	_remote_flash_light = OmniLight3D.new()
	_remote_flash_light.name = "RemoteFlashLight"
	_remote_flash_light.light_color = Color(1.0, 0.88, 0.45)
	_remote_flash_light.light_energy = 0.0
	_remote_flash_light.omni_range = 6.0
	_remote_flash_light.visible = false
	add_child(_remote_flash_light)
	if is_instance_valid(name_label):
		WarUI.configure_nameplate(name_label)
		name_label.position = Vector3(0.0, 0.65, 0.0)
		WarUI.refresh_nameplate(name_label, player_id, _is_friendly(), player_id.begins_with("[BOT] "))
		if not is_instance_valid(health_label):
			health_label = Label3D.new()
			health_label.name = "HealthBadge"
			health_label.position = Vector3(0.0, -0.16, 0.0)
			WarUI.configure_health_badge(health_label)
			name_label.add_child(health_label)
		WarUI.refresh_health_badge(health_label, int(health), _is_friendly())
	push_state(st)

func use_server_authoritative_remote_pose() -> void:
	server_authoritative_remote_pose = true

func _setup_server_authoritative_hitbox() -> void:
	var area := Area3D.new()
	area.name = "server_authoritative_body_hint"
	area.set_meta("hitbox", true)
	area.set_meta("player_id", player_id)
	area.set_meta("zone", "torso")
	area.set_meta("mult", 1.0)
	area.set_meta("from_bone", "coarse_body")
	area.set_meta("to_bone", "coarse_body")
	area.set_meta("radius", HIT_RADIUS)
	area.collision_layer = 4
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	var collision := CollisionShape3D.new()
	collision.name = "CenteredDroneHitShape"
	var sphere := SphereShape3D.new()
	sphere.radius = HIT_RADIUS
	collision.shape = sphere
	area.add_child(collision)
	add_child(area)
	_hitbox_areas = [area]
	_torso_area = area

func _is_friendly() -> bool:
	if GameState.selected_mode == "FFA":
		return false
	return team == GameState.local_team

func _set_driving_state(driving: bool) -> void:
	# Retained for the network/gameplay contract. Drone actors never enter a
	# human-in-vehicle presentation state.
	is_driving = driving

func _sync_anim(server_anim: String, is_dead: bool, _phase: float = 0.0) -> void:
	# State strings remain accepted for backend compatibility; rotors loop
	# continuously and never switch to human firing, running, or death clips.
	current_anim = "death" if is_dead else server_anim

func take_damage(dmg: float, _zone: String = "torso") -> void:
	if dead:
		return
	health = maxf(0.0, health - dmg)
	if health <= 0.0:
		dead = true
		_sync_anim("death", true)
		if is_instance_valid(name_label):
			name_label.visible = false
		if is_instance_valid(drone):
			drone.begin_crash(_visual_velocity)
		for area in _hitbox_areas:
			if is_instance_valid(area):
				area.monitorable = false
				area.collision_layer = 0

func take_explosion(dmg: float) -> void:
	take_damage(dmg, "torso")

func _safe_pos(state: Dictionary) -> Vector3:
	var x := float(state.get("x", 0.0))
	var y := float(state.get("y", 0.0))
	var z := float(state.get("z", 0.0))
	if not (is_finite(x) and is_finite(y) and is_finite(z)):
		return global_position
	return Vector3(x, y, z)

func _safe_quat(state: Dictionary) -> Quaternion:
	var rx := float(state.get("rx", 0.0))
	var ry := float(state.get("ry", 0.0))
	var rz := float(state.get("rz", 0.0))
	var rw := float(state.get("rw", 1.0))
	if not (is_finite(rx) and is_finite(ry) and is_finite(rz) and is_finite(rw)):
		return Quaternion.IDENTITY
	var q := Quaternion(rx, ry, rz, rw)
	var lsq := q.length_squared()
	if lsq < 0.0001 or not is_finite(lsq):
		return Quaternion.IDENTITY
	return q / sqrt(lsq)

func get_hit_view_time_ms() -> int:
	return hit_view_time_ms

func _lerp_pose_time_ms(a: Dictionary, b: Dictionary, weight: float) -> int:
	var first := int(a.get("pose_time_ms", 0))
	var last := int(b.get("pose_time_ms", first))
	return first + int(round(float(last - first) * clampf(weight, 0.0, 1.0)))

func _project_snapshot_weight(previous: Vector3, latest: Vector3, rendered: Vector3) -> float:
	var segment := latest - previous
	if segment.length_squared() < 0.000001:
		return 1.0
	return clampf((rendered - previous).dot(segment) / segment.length_squared(), 0.0, 1.0)

func push_state(st: Dictionary) -> void:
	var initial := _buf.is_empty()
	var now := Time.get_ticks_msec() / 1000.0
	_buf.append({"t": now, "st": st.duplicate()})
	if _buf.size() > 10:
		_buf.pop_front()
	if _buf.size() == 1 and st.has("x"):
		global_position = _safe_pos(st)
	var anim_str := String(st.get("anim", "idle"))
	var new_weapon := String(st.get("weapon", weapon_id))
	var new_mode := String(st.get("mobility_mode", mobility_mode))
	var old_team := team
	if not new_weapon.is_empty() and new_weapon != "vehicle" and new_weapon != weapon_id:
		weapon_id = new_weapon
	primary_payload = String(st.get("primary_payload", st.get("primary", primary_payload)))
	secondary_payload = String(st.get("secondary_payload", st.get("secondary", secondary_payload)))
	if new_mode != mobility_mode and ["quad", "wheels", "tracked", "heli", "wing"].has(new_mode):
		mobility_mode = new_mode
		if is_instance_valid(drone) and not drone.deferred_construction: drone.set_chassis(mobility_mode)
	health = float(st.get("health", health))
	var was_dead := dead
	dead = bool(st.get("is_dead", false)) or anim_str == "death"
	team = String(st.get("team", team))
	if team != old_team and is_instance_valid(drone) and not drone.deferred_construction:
		_apply_visual_loadout()
	if is_instance_valid(drone) and not drone.deferred_construction:
		if dead and not drone.crash_hidden:
			if initial:
				drone.set_crash_hidden(true)
			else:
				var crash_velocity := Vector3(float(st.get("vx", _visual_velocity.x)), float(st.get("vy", _visual_velocity.y)), float(st.get("vz", _visual_velocity.z)))
				drone.begin_crash(crash_velocity if crash_velocity.length_squared() > 0.04 else _visual_velocity)
		elif not dead and drone.crash_hidden:
			drone.set_crash_hidden(false)
		if primary_payload.is_empty():
			drone.set_weapon(weapon_id)
		else:
			drone.set_loadout(primary_payload, secondary_payload, weapon_id)
		if mobility_mode in ["tracked", "wheels"]:
			drone.apply_motion(_visual_velocity, rotation.y, _remote_pitch, dead, _remote_roll, _remote_suspension)
		else:
			drone.apply_motion(_visual_velocity, rotation.y, -float(st.get("pitch", 0.0)), dead)
		_apply_weapon_aim()
	_sync_anim(anim_str, dead, float(st.get("animation_time", 0.0)))
	if dead and not was_dead:
		if is_instance_valid(name_label):
			name_label.visible = false
		for area in _hitbox_areas:
			if is_instance_valid(area):
				area.monitorable = false
				area.collision_layer = 0
	elif not dead and was_dead:
		for area in _hitbox_areas:
			if is_instance_valid(area):
				area.monitorable = true
				area.collision_layer = 4
		if is_instance_valid(name_label):
			_update_nameplate_visibility()
	if is_instance_valid(name_label):
		WarUI.refresh_nameplate(name_label, player_id, _is_friendly(), player_id.begins_with("[BOT] "))
		if is_instance_valid(health_label):
			WarUI.refresh_health_badge(health_label, int(health), _is_friendly())

func react_to_shot(target: Vector3 = Vector3.INF) -> void:
	if not dead:
		_shot_kick = 1.0
		if is_instance_valid(_remote_flash_light):
			_remote_flash_light.visible = true
			_remote_flash_light.light_energy = 3.0
			var tw := create_tween()
			tw.tween_property(_remote_flash_light, "light_energy", 0.0, 0.06)
			tw.tween_callback(func() -> void:
				if is_instance_valid(_remote_flash_light):
					_remote_flash_light.visible = false
			)
		if target.is_finite():
			_weapon_aim_target = target
			_weapon_aim_until_ms = Time.get_ticks_msec() + 1200

func _apply_weapon_aim() -> void:
	if not dead and is_instance_valid(drone) and Time.get_ticks_msec() < _weapon_aim_until_ms:
		drone.aim_payload_at(_weapon_aim_target)

func react_to_hit() -> void:
	if not dead:
		_hit_react = 0.18

func _apply_shot_recoil(delta: float) -> void:
	_shot_kick = move_toward(_shot_kick, 0.0, delta * 9.0)

func interpolate(delta: float = 0.016) -> void:
	if sdk_pose_driven:
		return
	_update_remote_ground_surface(delta)
	_apply_shot_recoil(delta)
	_hit_react = maxf(0.0, _hit_react - delta)
	if health > 0.0 and health <= 25.0 and not dead:
		_remote_critical_smoke_timer += delta
		if _remote_critical_smoke_timer >= 0.25:
			_remote_critical_smoke_timer = 0.0
			var effects = get_tree().get_first_node_in_group("drone_combat_effects")
			if effects and effects.has_method("emit_critical_hull_smoke"):
				var rear_offset := global_transform.basis.z * 0.35 + Vector3.UP * 0.12
				effects.call("emit_critical_hull_smoke", global_position + rear_offset, _visual_velocity)
	_lod_timer += delta
	if _lod_timer >= 0.2:
		_lod_timer = 0.0
		_update_distance_lod()
	if _buf.size() < 2:
		if _buf.size() == 1:
			var state: Dictionary = _buf[0]["st"]
			global_position = _safe_pos(state)
			quaternion = _safe_quat(state)
			_render_animation(state, state, 0.0)
		return
	var render_time := Time.get_ticks_msec() / 1000.0 - _render_delay
	var index := 0
	while index < _buf.size() - 1 and float(_buf[index + 1]["t"]) < render_time:
		index += 1
	if index >= _buf.size() - 1:
		var latest: Dictionary = _buf.back()["st"]
		var previous: Dictionary = _buf[maxi(0, _buf.size() - 2)]["st"]
		var target_position := _safe_pos(latest)
		if global_position.distance_to(target_position) > 8.0:
			global_position = target_position
		else:
			global_position = global_position.lerp(target_position, clampf(24.0 * delta, 0.0, 1.0))
		var target_rotation := _safe_quat(latest)
		quaternion = quaternion.slerp(target_rotation, clampf(24.0 * delta, 0.0, 1.0)).normalized()
		var pose_weight := _project_snapshot_weight(_safe_pos(previous), target_position, global_position)
		_render_animation(previous, latest, pose_weight)
		return
	var a: Dictionary = _buf[index]["st"]
	var b: Dictionary = _buf[index + 1]["st"]
	var t0 := float(_buf[index]["t"])
	var t1 := float(_buf[index + 1]["t"])
	if t1 - t0 < 0.000001:
		_render_animation(b, b, 0.0)
		return
	var weight := clampf((render_time - t0) / (t1 - t0), 0.0, 1.0)
	var p0 := _safe_pos(a)
	var p1 := _safe_pos(b)
	global_position = p1 if p0.distance_to(p1) > 8.0 else p0.lerp(p1, weight)
	quaternion = _safe_quat(a).slerp(_safe_quat(b), weight).normalized()
	_render_animation(a, b, weight)

func apply_sdk_pose(st: Dictionary, delta: float = 0.016) -> void:
	sdk_pose_driven = true
	_update_remote_ground_surface(delta)
	_apply_shot_recoil(delta)
	_hit_react = maxf(0.0, _hit_react - delta)
	_lod_timer += delta
	if _lod_timer >= 0.2:
		_lod_timer = 0.0
		_update_distance_lod()
	global_position = _safe_pos(st)
	quaternion = _safe_quat(st)
	hit_view_time_ms = int(st.get("pose_time_ms", Time.get_ticks_msec()))
	dead = bool(st.get("is_dead", false))
	for area in _hitbox_areas:
		if is_instance_valid(area):
			area.monitorable = not dead
			area.collision_layer = 0 if dead else 4
	if is_instance_valid(drone):
		if mobility_mode in ["tracked", "wheels"]:
			drone.apply_motion(_visual_velocity, rotation.y, _remote_pitch, dead, _remote_roll, _remote_suspension)
		else:
			drone.apply_motion(_visual_velocity, rotation.y, -float(st.get("pitch", 0.0)), dead)
		_apply_weapon_aim()
	if dead:
		_sync_anim("death", true)
	else:
		_render_animation(st, st, 0.0)

func _render_animation(a: Dictionary, b: Dictionary, weight: float) -> void:
	hit_view_time_ms = _lerp_pose_time_ms(a, b, weight)
	var dt := maxf(0.001, float(b.get("pose_time_ms", 0)) - float(a.get("pose_time_ms", 0))) / 1000.0
	var p0 := _safe_pos(a)
	var p1 := _safe_pos(b)
	_visual_velocity = (p1 - p0) / dt if a != b else _visual_velocity.move_toward(Vector3.ZERO, 0.5)
	if not _visual_velocity.is_finite():
		_visual_velocity = Vector3.ZERO
	var yaw := global_rotation.y
	var pitch := float(b.get("pitch", a.get("pitch", 0.0)))
	if is_instance_valid(drone):
		if mobility_mode in ["tracked", "wheels"]:
			drone.apply_motion(_visual_velocity, yaw, _remote_pitch, dead, _remote_roll, _remote_suspension)
		else:
			drone.apply_motion(_visual_velocity, yaw, -pitch, dead)
		_apply_weapon_aim()
	if is_instance_valid(_contact_shadow):
		if dead or not visible:
			_contact_shadow.visible = false
		else:
			_contact_shadow.visible = true
			var is_ground := mobility_mode in ["tracked", "wheels"]
			var ground_y: Variant = ColyseusWorldGeometry.floor_height(global_position.x, global_position.z, global_position.y + 0.5)
			if ground_y != null:
				var altitude := maxf(0.0, global_position.y - float(ground_y))
				_contact_shadow.global_position = Vector3(global_position.x, float(ground_y) + 0.015, global_position.z)
				var alpha_scale := clampf(1.0 - altitude / 4.0, 0.0, 1.0)
				var base_scale := 1.15 if mobility_mode == "wheels" else (1.05 if is_ground else 0.90)
				var expand := 1.0 + altitude * 0.25
				_contact_shadow.scale = Vector3(base_scale * expand, 1.0, (base_scale * 1.2 if is_ground else base_scale) * expand)
				_contact_shadow.visible = alpha_scale > 0.02
			else:
				_contact_shadow.visible = false
	var state_anim := String(a.get("anim", "idle")) if weight < 0.5 else String(b.get("anim", "idle"))
	_sync_anim(state_anim, dead)
	if is_instance_valid(_remote_engine_audio):
		if dead or not visible or Audio.muted:
			if _remote_engine_audio.playing:
				_remote_engine_audio.stop()
		else:
			var stream: AudioStreamWAV = Audio.get_engine_stream(mobility_mode)
			if stream == null:
				if _remote_engine_audio.playing:
					_remote_engine_audio.stop()
			else:
				if _remote_engine_audio.stream != stream:
					_remote_engine_audio.stream = stream
				if not _remote_engine_audio.playing:
					_remote_engine_audio.play()
				var spd := _visual_velocity.length()
				_remote_engine_audio.pitch_scale = clampf(0.85 + (spd / 20.0) * 0.45, 0.75, 1.4)
				_remote_engine_audio.volume_db = lerpf(-14.0, -8.0, clampf(spd / 15.0, 0.0, 1.0))

func _update_distance_lod() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var distance := global_position.distance_to(camera.global_position)
	var camera_inside := Vector2(global_position.x - camera.global_position.x, global_position.z - camera.global_position.z).length() < 0.65 and absf(global_position.y - camera.global_position.y) < 0.7
	if is_instance_valid(drone):
		drone.visible = not camera_inside and not drone.crash_hidden
	_render_delay = 0.08 if distance <= 35.0 else (0.12 if distance <= 120.0 else 0.28)

	var target_lod := _current_lod
	if _current_lod == 0:
		if distance > 48.0:
			target_lod = 2 if distance > 125.0 else 1
	elif _current_lod == 1:
		if distance < 42.0:
			target_lod = 0
		elif distance > 125.0:
			target_lod = 2
	else:
		if distance < 115.0:
			target_lod = 1 if distance > 42.0 else 0

	_set_lod(target_lod)
	_update_nameplate_visibility()

func _update_nameplate_visibility() -> void:
	if not is_instance_valid(name_label):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		name_label.visible = not dead and _current_lod < 2
		return
	var distance := global_position.distance_to(camera.global_position)
	name_label.visible = not dead and distance >= 2.0 and distance <= 60.0

func _set_lod(new_lod: int) -> void:
	if new_lod != _current_lod:
		_current_lod = new_lod
		if is_instance_valid(drone) and drone.has_method("set_visual_lod"):
			drone.set_visual_lod(new_lod)
	for area in _hitbox_areas:
		if is_instance_valid(area):
			area.collision_layer = 0 if dead else 4
