class_name WarRemote
extends Node3D
## Interpolated remote player: AnimatedSoldier rig with authentic textures,
## dynamically equipped 3D weapon model, anatomical hitboxes, billboard nameplate,
## and 60Hz server state interpolation. Mirrors MultiplayerEntities.ts.

const SCENE: PackedScene = preload("res://scenes/RemotePlayer.tscn")
const VEHICLE_MODEL: PackedScene = preload("res://assets/models/armored_combat_van.glb")
const SkeletalHitboxesScript: Script = preload("res://scripts/core/skeletal_hitboxes.gd")

static var _remote_weapon_scenes: Dictionary = {}

static func _shared_weapon(wid: String) -> Node3D:
	if not _remote_weapon_scenes.has(wid):
		var model := WeaponView.build(wid)
		for child in model.find_children("*","Node",true,false): child.owner = model
		var packed := PackedScene.new()
		packed.pack(model)
		model.free()
		_remote_weapon_scenes[wid] = packed
	return (_remote_weapon_scenes[wid] as PackedScene).instantiate() as Node3D

var player_id := ""
var team := "A"
var weapon_id := "ak47"
var current_anim := ""
var health := 100.0
var hit_view_time_ms := 0
var _hit_react := 0.0
var dead := false
var is_driving := false

var _buf: Array = []
var _render_delay := 0.065
var _equipped_gun: Node3D
var _vehicle_root: Node3D
var _claimed_jeep: Node3D
var _hitbox_areas: Array[Area3D] = []
var _hitbox_helper: Node
var _head_area: Area3D
var _torso_area: Area3D
var _limb_areas: Array[Area3D] = []
var _beacons: Array[MeshInstance3D] = []
var _lod_timer := 0.0
var _current_lod := 0

@onready var soldier: Node3D = $Soldier
@onready var anim: AnimationPlayer = $Soldier/AnimationPlayer
@onready var name_label: Label3D = $Nameplate

static func create(pid: String, st: Dictionary) -> WarRemote:
	var r := SCENE.instantiate() as WarRemote
	r.player_id = pid
	r.name = "remote_%s" % pid
	r.set_meta("init_state", st)
	return r

func _ready() -> void:
	var st: Dictionary = get_meta("init_state", {})
	team = String(st.get("team", "A"))
	var init_wep := String(st.get("weapon", "ak47"))
	if init_wep != "vehicle" and not init_wep.is_empty():
		weapon_id = init_wep
	
	# Enable linear looping on continuous motion animations
	if anim:
		for anim_name in ["Rifle Idle", "Rifle Run", "Firing walk Rifle", "Strafe Left", "Strafe Right", "Walking Backwards"]:
			if anim.has_animation(anim_name):
				anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR

	# Tactical team shoulder beacons
	_setup_team_visuals()
	if GameState.practice_mode: _setup_vehicle_visual()
	
	var sld := get_node_or_null("Soldier")
	if sld:
		_sanitize_soldier_materials(sld)
	
	# Replace default Gun child with weapon viewmodel in right hand bone socket
	var old_gun := get_node_or_null("Gun")
	if old_gun:
		old_gun.queue_free()
	_update_equipped_weapon(weapon_id)
	
	# Anatomical hitboxes
	var hit_skeleton := soldier.get_node_or_null("Armature/Skeleton3D") as Skeleton3D
	_hitbox_helper = SkeletalHitboxesScript.new()
	_hitbox_areas = _hitbox_helper.setup(self, hit_skeleton, player_id)
	for area in _hitbox_areas:
		match String(area.get_meta("zone", "")):
			"head":
				if not is_instance_valid(_head_area): _head_area = area
			"torso":
				if not is_instance_valid(_torso_area): _torso_area = area
			_:
				_limb_areas.append(area)
	
	if is_instance_valid(name_label):
		name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_label.no_depth_test = false
		name_label.render_priority = 10
		name_label.outline_render_priority = 9
		name_label.outline_size = 12
		name_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.95)
		name_label.pixel_size = 0.0055
		name_label.font_size = 48
		name_label.position = Vector3(0, 2.30, 0)
		name_label.modulate = Color(0.35, 0.65, 1.0) if _is_friendly() else Color(1.0, 0.35, 0.3)
		name_label.text = " %s  [%d HP]" % [player_id, int(health)]
		
	push_state(st)

func _exit_tree() -> void:
	_release_claimed_map_jeep()

func _setup_vehicle_visual() -> void:
	_vehicle_root = Node3D.new()
	_vehicle_root.name = "RemoteVehicleRoot"
	_vehicle_root.visible = false
	add_child(_vehicle_root)
	if VEHICLE_MODEL:
		var inst := VEHICLE_MODEL.instantiate() as Node3D
		if inst:
			inst.name = "ArmoredCombatVanMesh"
			inst.rotation.y = deg_to_rad(-90.0)
			inst.position = Vector3.ZERO
			_vehicle_root.add_child(inst)
			var floor_node := inst.find_child("floor", true, false)
			if floor_node:
				floor_node.visible = false
				
	# Solid vehicle collision body for fallback remote vehicle
	var fallback_col_body := AnimatableBody3D.new()
	fallback_col_body.name = "FallbackVehicleCollider"
	fallback_col_body.collision_layer = 4
	fallback_col_body.collision_mask = 1 | 4
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.3, 1.10, 5.0)
	col_shape.shape = box
	col_shape.position = Vector3(0.0, 0.95, 0.0)
	fallback_col_body.add_child(col_shape)
	_vehicle_root.add_child(fallback_col_body)

func _set_driving_state(driving: bool) -> void:
	if is_driving == driving:
		return
	is_driving = driving
	if is_instance_valid(soldier):
		if driving:
			# Seat driver inside the enclosed armored combat van cabin so body never floats outside
			soldier.position = Vector3(-0.55, 0.55, -0.35)
			soldier.scale = Vector3(0.82, 0.82, 0.82)
		else:
			soldier.position = Vector3.ZERO
			soldier.scale = Vector3.ONE
	if is_instance_valid(_equipped_gun):
		_equipped_gun.visible = (not driving) and (not dead)
	for b in _beacons:
		if is_instance_valid(b):
			b.visible = (not driving) and (_current_lod < 2)
	for area in _hitbox_areas:
		if is_instance_valid(area): area.collision_layer = 0 if driving or dead else 4
	if is_instance_valid(name_label):
		name_label.position = Vector3(0, 3.20, 0) if driving else Vector3(0, 2.30, 0)
	if not GameState.practice_mode:
		if is_instance_valid(soldier): soldier.visible = not driving
		if is_instance_valid(_vehicle_root): _vehicle_root.visible = false
		return
	if driving:
		_claim_nearby_map_jeep()
		if is_instance_valid(_vehicle_root):
			_vehicle_root.visible = true
	else:
		_release_claimed_map_jeep()
		if is_instance_valid(_vehicle_root):
			_vehicle_root.visible = false

func _claim_nearby_map_jeep() -> void:
	if is_instance_valid(_claimed_jeep) or not is_inside_tree():
		return
	var best_jeep: Node3D = null
	var best_d := 12.0
	for j in get_tree().get_nodes_in_group("combat_jeeps"):
		if is_instance_valid(j) and j is Node3D and not bool(j.get("is_driven")):
			var d := global_position.distance_to((j as Node3D).global_position)
			if d < best_d:
				best_d = d
				best_jeep = j as Node3D
	if best_jeep:
		_claimed_jeep = best_jeep
		# Disable map jeep so it never runs local physics input or fights network replication
		_claimed_jeep.visible = false
		_claimed_jeep.process_mode = Node.PROCESS_MODE_DISABLED

func _release_claimed_map_jeep() -> void:
	if not is_instance_valid(_claimed_jeep):
		_claimed_jeep = null
		return
	_claimed_jeep.global_position = global_position
	_claimed_jeep.global_transform.basis = global_transform.basis
	_claimed_jeep.process_mode = Node.PROCESS_MODE_INHERIT
	if _claimed_jeep is RigidBody3D:
		var rb := _claimed_jeep as RigidBody3D
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
		rb.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		rb.freeze = true
	if _claimed_jeep is CollisionObject3D:
		(_claimed_jeep as CollisionObject3D).collision_layer = 4
		(_claimed_jeep as CollisionObject3D).collision_mask = 1 | 4
	_claimed_jeep.visible = true
	_claimed_jeep = null

func _is_friendly() -> bool:
	if GameState.selected_mode == "FFA":
		return false
	return team == GameState.local_team

func _setup_team_visuals() -> void:
	var beacon_color := Color(0.2, 0.5, 1.0) if _is_friendly() else Color(1.0, 0.2, 0.15)
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
		_beacons.append(beacon)

func _update_equipped_weapon(wid: String) -> void:
	if wid == "vehicle" or wid.is_empty():
		return
	if is_instance_valid(_equipped_gun):
		_equipped_gun.queue_free()
	_equipped_gun = _shared_weapon(wid)
	_equipped_gun.name = "RemoteGun"
	_equipped_gun.visible = (not is_driving) and (not dead)
	
	var skel: Skeleton3D = soldier.get_node_or_null("Armature/Skeleton3D") as Skeleton3D
	if skel and skel.find_bone("mixamorig_RightHand") != -1:
		var bone_attach := skel.get_node_or_null("RightHandSocket") as BoneAttachment3D
		if bone_attach == null:
			bone_attach = BoneAttachment3D.new()
			bone_attach.bone_name = "mixamorig_RightHand"
			bone_attach.name = "RightHandSocket"
			skel.add_child(bone_attach)
		# Armature in AnimatedSoldier has a scale of (0.01, 0.01, 0.01)
		# Scaling by 72.0 inside Skeleton3D produces a nicely proportioned military rifle in the hand
		_equipped_gun.scale = Vector3(72.0, 72.0, 72.0)
		_equipped_gun.position = Vector3(2.0, -4.0, 1.0)
		_equipped_gun.rotation_degrees = Vector3(90.0, 106.0, 0.0)
		bone_attach.add_child(_equipped_gun)
	else:
		_equipped_gun.scale = Vector3(0.72, 0.72, 0.72)
		_equipped_gun.position = Vector3(0.20, 1.20, -0.30)
		add_child(_equipped_gun)

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

func _anim_for(server_anim: String, is_dead: bool) -> String:
	if is_dead:
		return "Dying"
	match server_anim:
		"death":
			return "Dying"
		"firing":
			return "Firing Rifle"
		"firing walk":
			return "Firing walk Rifle"
		"run":
			return "Rifle Run"
		"jump":
			return "Rifle Jump"
		_:
			return "Rifle Idle"

func _sync_anim(server_anim: String, is_dead: bool, phase: float = 0.0) -> void:
	var target := _anim_for(server_anim, is_dead)
	if is_dead:
		if target != current_anim:
			current_anim = target
			if anim and anim.has_animation(target):
				anim.speed_scale = 1.0
				anim.play(target, 0.2)
		return
	if target != current_anim:
		current_anim = target
		if anim and anim.has_animation(target):
			anim.speed_scale = 0.0
			anim.play(target, 0.0)
	if anim and anim.has_animation(target):
		var clip := anim.get_animation(target)
		var seek_time := phase
		if clip.loop_mode != Animation.LOOP_NONE and clip.length > 0.0001:
			seek_time = fposmod(phase, clip.length)
		else:
			seek_time = clampf(phase, 0.0, clip.length)
		anim.seek(seek_time, true)
		var hit_skeleton := soldier.get_node_or_null("Armature/Skeleton3D") as Skeleton3D
		if is_instance_valid(hit_skeleton): hit_skeleton.force_update_all_bone_transforms()
		if is_instance_valid(_hitbox_helper): _hitbox_helper.update_from_skeleton()

func take_damage(dmg: float, _zone: String = "torso") -> void:
	if dead:
		return
	health = maxf(0.0, health - dmg)
	if is_instance_valid(name_label):
		name_label.text = " %s  [%d HP]" % [player_id, int(health)]
		if health <= 0.0:
			name_label.visible = false
	if health <= 0.0:
		dead = true
		_sync_anim("death", true)
		if is_instance_valid(_equipped_gun):
			_equipped_gun.visible = false
		for a in _hitbox_areas:
			if is_instance_valid(a):
				a.monitorable = false
				a.collision_layer = 0

func take_explosion(dmg: float) -> void:
	take_damage(dmg, "torso")

func _safe_pos(s: Dictionary) -> Vector3:
	var x := float(s.get("x", 0.0))
	var y := float(s.get("y", 0.0))
	var z := float(s.get("z", 0.0))
	if not (is_finite(x) and is_finite(y) and is_finite(z)):
		return global_position
	return Vector3(x, y, z)

func _safe_quat(s: Dictionary) -> Quaternion:
	var rx := float(s.get("rx", 0.0))
	var ry := float(s.get("ry", 0.0))
	var rz := float(s.get("rz", 0.0))
	var rw := float(s.get("rw", 1.0))
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
	var now := Time.get_ticks_msec() / 1000.0
	_buf.append({"t": now, "st": st})
	if _buf.size() > 10:
		_buf.pop_front()
		
	if global_position == Vector3.ZERO and st.has("x"):
		global_position = _safe_pos(st)

	var anim_str := String(st.get("anim", "idle"))
	var new_wep := String(st.get("weapon", weapon_id))
	var driving_now := (anim_str == "drive" or new_wep == "vehicle")

	health = float(st.get("health", 100))
	var was_dead := dead
	dead = bool(st.get("is_dead", false)) or anim_str == "death"
	team = String(st.get("team", team))
	
	if not driving_now and new_wep != "vehicle" and not new_wep.is_empty() and new_wep != weapon_id:
		weapon_id = new_wep
		_update_equipped_weapon(weapon_id)
	
	_set_driving_state(driving_now and not dead)
	
	if dead and not was_dead:
		var main = get_tree().current_scene
		if main and main.has_method("spawn_death_blood"): main.spawn_death_blood(global_position)
		# Play death animation and disable hitboxes
		_sync_anim("death", true)
		if is_instance_valid(_equipped_gun):
			_equipped_gun.visible = false
		if is_instance_valid(name_label):
			name_label.visible = false
		for a in _hitbox_areas:
			if is_instance_valid(a):
				a.monitorable = false
				a.collision_layer = 0
	elif not dead and was_dead:
		# Re-enable upon respawn
		if is_instance_valid(_equipped_gun):
			_equipped_gun.visible = not is_driving
		if is_instance_valid(name_label):
			name_label.visible = (_current_lod < 2)
		for a in _hitbox_areas:
			if is_instance_valid(a):
				a.monitorable = true
				a.collision_layer = 4
		_sync_anim(anim_str, false, float(st.get("animation_time", 0.0)))
				
	if is_node_ready() and not dead:
		if _buf.size() == 1:
			_sync_anim(anim_str, false, float(st.get("animation_time", 0.0)))
		if is_instance_valid(name_label):
			name_label.visible = (_current_lod < 2)
			name_label.modulate = Color(0.35, 0.65, 1.0) if _is_friendly() else Color(1.0, 0.35, 0.3)
			name_label.text = " %s  [%d]" % [player_id, int(maxf(0.0, health))]

func react_to_hit() -> void:
	if not dead: _hit_react = 0.18

func interpolate(delta: float = 0.016) -> void:
	_hit_react = maxf(0, _hit_react - delta)
	if is_instance_valid(soldier): soldier.rotation.z = sin((1.0 - _hit_react/0.18) * PI) * 0.035 if _hit_react > 0 else 0.0
	_lod_timer += delta
	if _lod_timer >= 0.2:
		_lod_timer = 0.0
		_update_distance_lod()

	var snap_dist := 25.0 if is_driving else 8.0

	if _buf.size() < 2:
		if _buf.size() == 1:
			var s: Dictionary = _buf[0]["st"]
			global_position = _safe_pos(s)
			quaternion = _safe_quat(s)
			_render_animation(s, s, 0.0)
		_sync_claimed_jeep_transform()
		return
	var rt: float = Time.get_ticks_msec() / 1000.0 - _render_delay
	var i := 0
	while i < _buf.size() - 1 and float(_buf[i + 1]["t"]) < rt:
		i += 1
	if i >= _buf.size() - 1:
		# Render time caught up to latest state — frame-rate independent smooth lerp
		var latest: Dictionary = _buf.back()["st"]
		var previous: Dictionary = _buf[maxi(0, _buf.size() - 2)]["st"]
		var target_pos := _safe_pos(latest)
		if global_position.distance_to(target_pos) > snap_dist:
			global_position = target_pos
		else:
			global_position = global_position.lerp(target_pos, clampf(24.0 * delta, 0.0, 1.0))
		var q_latest := _safe_quat(latest)
		var cur_q := quaternion
		if not cur_q.is_normalized():
			cur_q = cur_q.normalized() if cur_q.length_squared() > 0.0001 else Quaternion.IDENTITY
		var slerped := cur_q.slerp(q_latest, clampf(24.0 * delta, 0.0, 1.0))
		if slerped.length_squared() > 0.0001:
			quaternion = slerped.normalized()
		_sync_claimed_jeep_transform()
		var pose_weight := _project_snapshot_weight(_safe_pos(previous), target_pos, global_position)
		_render_animation(previous, latest, pose_weight)
		return
	var s0: Dictionary = _buf[i]["st"]
	var s1: Dictionary = _buf[i + 1]["st"]
	var t0: float = _buf[i]["t"]
	var t1: float = _buf[i + 1]["t"]
	if t1 - t0 < 0.000001:
		_render_animation(s1, s1, 0.0)
		return
	var k := clampf((rt - t0) / (t1 - t0), 0.0, 1.0)
	var p0 := _safe_pos(s0)
	var p1 := _safe_pos(s1)
	# Snap immediately on teleport/respawn instead of gliding across walls
	if p0.distance_to(p1) > snap_dist:
		global_position = p1
	else:
		global_position = p0.lerp(p1, k)
	var q0 := _safe_quat(s0)
	var q1 := _safe_quat(s1)
	var interp_q := q0.slerp(q1, k)
	if interp_q.length_squared() > 0.0001:
		quaternion = interp_q.normalized()
	_sync_claimed_jeep_transform()
	_render_animation(s0, s1, k)

func _render_animation(a: Dictionary, b: Dictionary, weight: float) -> void:
	hit_view_time_ms = _lerp_pose_time_ms(a, b, weight)
	if dead:
		return
	var anim_a := String(a.get("anim", "idle"))
	var anim_b := String(b.get("anim", anim_a))
	var selected := anim_a if weight < 0.5 or anim_a == anim_b else anim_b
	var phase_a := float(a.get("animation_time", 0.0))
	var phase_b := float(b.get("animation_time", phase_a))
	var phase := lerpf(phase_a, phase_b, weight) if anim_a == anim_b else (phase_a if selected == anim_a else phase_b)
	_sync_anim(selected, false, phase)

func _sync_claimed_jeep_transform() -> void:
	pass

func _update_distance_lod() -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return
	var d := global_position.distance_to(cam.global_position)
	# Fade out only the intersecting third-person presentation; hitboxes stay authoritative.
	var camera_inside := Vector2(global_position.x-cam.global_position.x, global_position.z-cam.global_position.z).length() < 0.65 and absf(global_position.y+1.1-cam.global_position.y) < 1.2
	if is_instance_valid(soldier): soldier.visible = not camera_inside and not (is_driving and not GameState.practice_mode)
	if is_instance_valid(_equipped_gun): _equipped_gun.visible = not camera_inside and not is_driving and not dead
	_render_delay = 0.08 if d <= 35.0 else (0.12 if d <= 120.0 else 0.28)
	if d > 120.0:
		_set_lod(2)
	elif d > 45.0:
		_set_lod(1)
	else:
		_set_lod(0)
	if is_instance_valid(name_label):
		name_label.visible = not dead and d >= 2.0 and d <= 60.0

func _set_lod(new_lod: int) -> void:
	if is_driving:
		for area in _hitbox_areas:
			if is_instance_valid(area): area.collision_layer = 0
		return
	if dead:
		return
	var lod_changed := _current_lod != new_lod
	_current_lod = new_lod
	# Collision stays anatomically complete at every visual distance. Only
	# presentation details are reduced by LOD.
	for area in _hitbox_areas:
		if is_instance_valid(area): area.collision_layer = 4
	if not lod_changed:
		return

	match _current_lod:
		0: # Near (<45m): Full fidelity and beacons active
			if is_instance_valid(name_label):
				name_label.visible = true
				name_label.outline_size = 12
			for b in _beacons:
				if is_instance_valid(b):
					b.visible = not is_driving
		1: # Mid (45m - 120m): Simplify nameplate outline
			if is_instance_valid(name_label):
				name_label.visible = true
				name_label.outline_size = 0
			for b in _beacons:
				if is_instance_valid(b):
					b.visible = not is_driving
		2: # Far (>120m): Hide beacons and far billboard
			if is_instance_valid(name_label):
				name_label.visible = false
			for b in _beacons:
				if is_instance_valid(b):
					b.visible = false
