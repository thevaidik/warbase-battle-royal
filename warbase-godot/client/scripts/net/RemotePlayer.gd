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
var _lod_timer := 0.0
var _current_lod := 0
var _hitbox_areas: Array[Area3D] = []
var _head_area: Area3D
var _torso_area: Area3D
var _limb_areas: Array[Area3D] = []
var _previous_render_position := Vector3.ZERO
var _visual_velocity := Vector3.ZERO

@onready var drone: DroneVisual = $DroneVisual
@onready var name_label: Label3D = $Nameplate

static func create(pid: String, st: Dictionary) -> WarRemote:
	var remote := SCENE.instantiate() as WarRemote
	remote.player_id = pid
	remote.name = "remote_%s" % pid
	remote.set_meta("init_state", st)
	return remote

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var st: Dictionary = get_meta("init_state", {})
	team = String(st.get("team", "A"))
	weapon_id = String(st.get("weapon", "ak47"))
	mobility_mode = String(st.get("mobility_mode", "heli"))
	if weapon_id.is_empty() or weapon_id == "vehicle":
		weapon_id = "ak47"
	if is_instance_valid(drone):
		drone.configure(_is_friendly(), weapon_id, mobility_mode)
	_setup_server_authoritative_hitbox()
	if is_instance_valid(name_label):
		WarUI.configure_nameplate(name_label)
		name_label.position = Vector3(0.0, 0.65, 0.0)
		WarUI.refresh_nameplate(name_label, player_id, _is_friendly())
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
	primary_payload = String(st.get("primary_payload", primary_payload))
	secondary_payload = String(st.get("secondary_payload", secondary_payload))
	if new_mode != mobility_mode and ["quad", "wheels", "tracked", "heli", "wing"].has(new_mode):
		mobility_mode = new_mode
		if is_instance_valid(drone): drone.set_chassis(mobility_mode)
	health = float(st.get("health", health))
	var was_dead := dead
	dead = bool(st.get("is_dead", false)) or anim_str == "death"
	team = String(st.get("team", team))
	if team != old_team and is_instance_valid(drone):
		drone.configure(_is_friendly(), weapon_id, mobility_mode)
	if is_instance_valid(drone):
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
		drone.apply_motion(_visual_velocity, rotation.y, -float(st.get("pitch", 0.0)), dead)
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
		WarUI.refresh_nameplate(name_label, player_id, _is_friendly())

func react_to_shot() -> void:
	if not dead:
		_shot_kick = 1.0

func react_to_hit() -> void:
	if not dead:
		_hit_react = 0.18

func _apply_shot_recoil(delta: float) -> void:
	_shot_kick = move_toward(_shot_kick, 0.0, delta * 9.0)

func interpolate(delta: float = 0.016) -> void:
	if sdk_pose_driven:
		return
	_apply_shot_recoil(delta)
	_hit_react = maxf(0.0, _hit_react - delta)
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
		drone.apply_motion(_visual_velocity, rotation.y, -float(st.get("pitch", 0.0)), dead)
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
		drone.apply_motion(_visual_velocity, yaw, -pitch, dead)
	var state_anim := String(a.get("anim", "idle")) if weight < 0.5 else String(b.get("anim", "idle"))
	_sync_anim(state_anim, dead)

func _update_distance_lod() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var distance := global_position.distance_to(camera.global_position)
	var camera_inside := Vector2(global_position.x - camera.global_position.x, global_position.z - camera.global_position.z).length() < 0.65 and absf(global_position.y - camera.global_position.y) < 0.7
	if is_instance_valid(drone):
		drone.visible = not camera_inside and not drone.crash_hidden
	_render_delay = 0.08 if distance <= 35.0 else (0.12 if distance <= 120.0 else 0.28)
	_set_lod(2 if distance > 120.0 else (1 if distance > 45.0 else 0))
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
	_current_lod = new_lod
	for area in _hitbox_areas:
		if is_instance_valid(area):
			area.collision_layer = 0 if dead else 4
