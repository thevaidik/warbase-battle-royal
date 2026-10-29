class_name WarWeaponSystem
extends Node3D
## AAA Hitscan weapon system.
## Ported from client/src/physics/WeaponSystem.ts with best Godot 4.3+ practices:
## Continuous ADS lerping, tactile 3-phase reload animations, dynamic spring recoil,
## brass shell casings, hitscan ballistics, localized bot damage, and sound design.

signal ammo_changed(ammo: int, mag: int)
signal fired(weapon_index: int)
signal hit_confirmed_editorial(target: String, damage: int, is_kill: bool, is_headshot: bool)
signal scope_magnification_changed(zoom_x: int)

var player: WarPlayer
var camera: Camera3D
var sway_root: Node3D
var net: WarNetwork
var world: Node3D

var active_index := 0
var ammo := 30
var is_reloading := false
var reload_t := 0.0
var spread := 1.5
var ads_t := 0.0
var ads_amount := 0.0
var _switch_t := 1.0
const SWITCH_DUR := 0.22
var is_firing := false

var scope_zoom_levels: Array[int] = [2, 4, 8]
var scope_idx := 0
var _v_pressed_last := false
var _bolt_kick := 0.0
var breath_stamina := 1.0
var is_holding_breath := false
var is_inspecting := false
var inspect_t := 0.0
const INSPECT_DURATION := 3.2
var _i_pressed_last := false
var _shot_seq := 0
var _pending_shots: Array = []
var _ammo_store: Dictionary = {}
var _zoom_store: Dictionary = {}
var _breath_exhausted := false
var _bolt_cycle := 0.0
var _burst_count := 0
var _last_shot_time := -10.0
var _throw_anim_t := 0.0
const THROW_ANIM_DUR := 0.42

func play_grenade_throw() -> void:
	_throw_anim_t = THROW_ANIM_DUR

var _recoil_x := 0.0
var _recoil_y := 0.0
var _vel_x := 0.0
var _vel_y := 0.0
var _last_fire := -10.0
var _can_fire_semi := true
var _sway_x := 0.0
var _sway_y := 0.0
var _bob_t := 0.0
var _kick_z := 0.0
var _kick_rx := 0.0
var _air_lag_y := 0.0
var _air_lag_rx := 0.0
var _views: Array[Node3D] = []
var _tracers: Array = []
var _tracer_idx := 0
var _pending_impacts: Array = []
const MUZZLE_SPEEDS := {"ak47":715.0, "m4":900.0, "mp5":400.0, "pistol":340.0, "dmr":820.0, "m2010":850.0, "hmg":890.0}
var _flash_light: OmniLight3D
var _flash_mesh: MeshInstance3D
var _flash_t := 0.0
var _time := 0.0
var _tracer_container: Node3D
const TRACER_POOL := 32
const MAX_DECALS := 32
const CASING_POOL := 16
const SPARK_POOL := 24
const DUST_POOL := 8

var _casings: Array = []
var _casing_idx := 0
var _casing_container: Node3D

var _sparks: Array = []
var _spark_idx := 0
var _spark_container: Node3D

var _dusts: Array = []
var _bloods: Array = []
var _blood_idx := 0
var _blood_container: Node3D
const BLOOD_POOL := 48
const BloodTexture = preload("res://scripts/weapons/BloodTexture.gd")
var _dust_idx := 0
var _dust_container: Node3D

var _hitscan_query: PhysicsRayQueryParameters3D = null
var _decals: Array[WeakRef] = []

static var _casing_mesh: CylinderMesh = null
static var _casing_mat: StandardMaterial3D = null

static var _spark_mesh: SphereMesh = null
static var _spark_mat: StandardMaterial3D = null

static var _dust_mesh: SphereMesh = null
static var _decal_mesh: QuadMesh = null
static var _decal_mat: StandardMaterial3D = null

func current_config() -> Dictionary:
	return GameState.WEAPONS[active_index]

func _scope_levels() -> Array:
	return current_config().get("zoom_levels", [4, 8] if active_index == 2 else ([2, 4] if active_index == 0 else [1]))

func get_current_scope_zoom() -> int:
	var levels := _scope_levels()
	return int(levels[scope_idx % levels.size()])

func get_current_ads_fov() -> float:
	if get_current_scope_zoom() == 1:
		return float(current_config()["ads_fov"])
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(GameState.BASE_FOV) * 0.5) / float(get_current_scope_zoom())))

func is_scoped() -> bool:
	return get_current_scope_zoom() >= 4

func reset_after_respawn() -> void:
	_pending_shots.clear()
	_ammo_store.clear()
	for weapon in GameState.WEAPONS:
		_ammo_store[weapon["id"]] = int(weapon["mag_size"])
	ammo = int(current_config()["mag_size"])
	is_reloading = false
	reload_t = 0.0
	ads_t = 0.0
	ads_amount = 0.0
	_bolt_cycle = 0.0
	_burst_count = 0
	_switch_t = 0.0
	_last_fire = _time
	is_holding_breath = false
	player.aim_sway = Vector2.ZERO

func cycle_scope_magnification() -> void:
	if _scope_levels().size() < 2:
		return
	scope_idx = (scope_idx + 1) % _scope_levels().size()
	_zoom_store[active_index] = scope_idx
	Audio.click()
	scope_magnification_changed.emit(get_current_scope_zoom())

func setup(p: WarPlayer, cam: Camera3D, sway: Node3D, net_ref: WarNetwork, world_ref: Node3D) -> void:
	player = p
	camera = cam
	sway_root = sway
	net = net_ref
	world = world_ref
	
	active_index = GameState.starting_weapon_index()

	# Tactical viewmodel scale: slightly smaller (~15%) for clean sightlines & reduced screen clutter
	const VIEWMODEL_SCALE := Vector3(0.85, 0.85, 0.85)

	# Build viewmodels for all registered weapons
	for i in GameState.WEAPONS.size():
		var v: Node3D = WeaponView.build(GameState.weapon_id_for_index(i))
		v.scale = VIEWMODEL_SCALE
		v.visible = (i == active_index)
		sway_root.add_child(v)
		_views.append(v)
		
	# Studio-grade viewmodel lighting (Key & Rim)
	# Ensures firearm always catches realistic metallic highlights, chamfer glints,
	# and mechanical depth in all environments, matching AAA titles like Battlefield.
	var key_light := OmniLight3D.new()
	key_light.name = "ViewmodelKeyLight"
	key_light.position = Vector3(0.35, 0.40, -0.25)
	key_light.light_color = Color(1.0, 0.96, 0.90)
	key_light.light_energy = 0.45
	key_light.omni_range = 1.8
	key_light.omni_attenuation = 1.0
	key_light.shadow_enabled = false
	sway_root.add_child(key_light)
	
	var rim_light := OmniLight3D.new()
	rim_light.name = "ViewmodelRimLight"
	rim_light.position = Vector3(-0.40, 0.25, -0.45)
	rim_light.light_color = Color(0.75, 0.88, 1.0)
	rim_light.light_energy = 0.2
	rim_light.omni_range = 1.6
	rim_light.omni_attenuation = 1.0
	rim_light.shadow_enabled = false
	sway_root.add_child(rim_light)
		
	var cfg := current_config()
	ammo = int(cfg["mag_size"])
	spread = float(cfg["base_spread"])
	for weapon in GameState.WEAPONS:
		_ammo_store[weapon["id"]] = int(weapon["mag_size"])
	if net and net.connected:
		net.send_switch(String(cfg["id"]))
	
	# Dedicated container for bullets/tracers in world
	_tracer_container = Node3D.new()
	_tracer_container.name = "TracerPool"
	world_ref.add_child(_tracer_container)
	
	# Pre-allocate tracer pool with trajectory-aligned aerodynamic laser projectiles
	var tracer_box := BoxMesh.new()
	tracer_box.size = Vector3(0.007, 0.007, 1.0)
	for i in TRACER_POOL:
		var mi := MeshInstance3D.new()
		mi.mesh = tracer_box
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.86, 0.58)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.70, 0.35)
		m.emission_energy_multiplier = 1.8
		mi.material_override = m
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_tracer_container.add_child(mi)
		_tracers.append({"node": mi, "t": 0.0, "dur": 0.0, "from": Vector3.ZERO, "to": Vector3.ZERO, "active": false})
		
	# Query world/vehicle solids and anatomical combatant areas. Exclude layer 2:
	# a bot's broad CharacterBody capsule would otherwise mask its layer-4 hitboxes.
	_hitscan_query = PhysicsRayQueryParameters3D.new()
	_hitscan_query.collide_with_areas = true
	_hitscan_query.collide_with_bodies = true
	_hitscan_query.collision_mask = 1 | 4
	
	# Pre-allocate casing pool
	_casing_container = Node3D.new()
	_casing_container.name = "CasingPool"
	world_ref.add_child(_casing_container)
	if not _casing_mesh:
		_casing_mesh = CylinderMesh.new()
		_casing_mesh.top_radius = 0.007
		_casing_mesh.bottom_radius = 0.007
		_casing_mesh.height = 0.035
	if not _casing_mat:
		_casing_mat = StandardMaterial3D.new()
		_casing_mat.albedo_color = Color(0.88, 0.75, 0.28)
		_casing_mat.metallic = 0.95
		_casing_mat.roughness = 0.25
	for i in CASING_POOL:
		var cmi := MeshInstance3D.new()
		cmi.mesh = _casing_mesh
		cmi.material_override = _casing_mat
		cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cmi.visible = false
		_casing_container.add_child(cmi)
		_casings.append({"node": cmi, "vel": Vector3.ZERO, "rot_vel": Vector3.ZERO, "t": 0.0, "dur": 0.38, "active": false})

	# Pre-allocate spark pool
	_spark_container = Node3D.new()
	_spark_container.name = "SparkPool"
	world_ref.add_child(_spark_container)
	if not _spark_mesh:
		_spark_mesh = SphereMesh.new()
		_spark_mesh.radius = 0.02
		_spark_mesh.height = 0.04
	if not _spark_mat:
		_spark_mat = StandardMaterial3D.new()
		_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_spark_mat.albedo_color = Color(1.0, 0.75, 0.25)
	for i in SPARK_POOL:
		var smi := MeshInstance3D.new()
		smi.mesh = _spark_mesh
		smi.material_override = _spark_mat
		smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		smi.visible = false
		_spark_container.add_child(smi)
		_sparks.append({"node": smi, "vel": Vector3.ZERO, "t": 0.0, "dur": 0.22, "active": false})

	# Pre-allocate dust pool
	_dust_container = Node3D.new()
	_dust_container.name = "DustPool"
	world_ref.add_child(_dust_container)
	if not _dust_mesh:
		_dust_mesh = SphereMesh.new()
		_dust_mesh.radius = 0.08
		_dust_mesh.height = 0.16
	var shared_dust_mat := StandardMaterial3D.new()
	shared_dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shared_dust_mat.albedo_color = Color(0.7, 0.68, 0.65, 0.45)
	shared_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in DUST_POOL:
		var dmi := MeshInstance3D.new()
		dmi.mesh = _dust_mesh
		dmi.material_override = shared_dust_mat
		dmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dmi.visible = false
		_dust_container.add_child(dmi)
		_dusts.append({"node": dmi, "t": 0.0, "dur": 0.35, "normal": Vector3.UP, "start_pos": Vector3.ZERO, "active": false})
		
	_blood_container = Node3D.new()
	_blood_container.name = "BloodPool"
	world_ref.add_child(_blood_container)
	var droplet := SphereMesh.new()
	droplet.radius = 0.018
	droplet.height = 0.036
	droplet.radial_segments = 6
	droplet.rings = 3
	var blood_material := StandardMaterial3D.new()
	blood_material.albedo_color = Color(0.38, 0.025, 0.018, 0.85)
	blood_material.roughness = 0.9
	blood_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in BLOOD_POOL:
		var particle := MeshInstance3D.new()
		particle.mesh = droplet
		particle.material_override = blood_material
		particle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particle.visible = false
		_blood_container.add_child(particle)
		_bloods.append({"node":particle, "active":false, "t":0.0, "dur":0.25, "vel":Vector3.ZERO})

	# Muzzle flash
	_flash_mesh = MeshInstance3D.new()
	var flash_quad := QuadMesh.new()
	flash_quad.size = Vector2(0.16, 0.16)
	_flash_mesh.mesh = flash_quad
	var flash_shader := Shader.new()
	flash_shader.code = "shader_type spatial; render_mode unshaded, blend_add, cull_disabled, depth_draw_never; void fragment(){ vec2 p=UV*2.0-1.0; float r=length(p); float a=atan(p.y,p.x); float lobes=0.45+0.35*pow(abs(cos(a*3.0)),5.0); float flare=1.0-smoothstep(lobes*0.25,lobes,r); float core=1.0-smoothstep(0.03,0.22,r); ALBEDO=mix(vec3(1.0,0.38,0.08),vec3(1.0,0.94,0.75),core); EMISSION=ALBEDO*2.0; ALPHA=clamp(flare+core,0.0,1.0); }"
	var fm := ShaderMaterial.new()
	fm.shader = flash_shader
	_flash_mesh.material_override = fm
	_flash_mesh.visible = false
	sway_root.add_child(_flash_mesh)
	
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.85, 0.4)
	_flash_light.light_energy = 3.5
	_flash_light.omni_range = 3.5
	_flash_light.visible = false
	sway_root.add_child(_flash_light)

func _muzzle_global() -> Vector3:
	if active_index < _views.size():
		var v: Node3D = _views[active_index]
		var mz := v.get_node_or_null("Muzzle")
		if mz:
			return (mz as Node3D).global_position
	return sway_root.global_position + -sway_root.global_transform.basis.z * 0.6

func resolve_same_actor_center_through_limb(space: PhysicsDirectSpaceState3D, query: PhysicsRayQueryParameters3D, first_hit: Dictionary) -> Dictionary:
	if first_hit.is_empty():
		return first_hit
	var first_collider: Object = first_hit.get("collider")
	if not first_collider is Area3D or not first_collider.has_meta("hitbox"):
		return first_hit
	var first_zone := String(first_collider.get_meta("zone", ""))
	if first_zone != "arm" and first_zone != "leg":
		return first_hit
	var actor := (first_collider as Node).get_parent()
	if actor == null:
		return first_hit
	var excluded: Array[RID] = []
	for rid in query.exclude:
		excluded.append(rid)
	var added_limb := false
	for child in actor.get_children():
		if child is Area3D and child.has_meta("hitbox") and String(child.get_meta("zone", "")) in ["arm", "leg"]:
			excluded.append((child as Area3D).get_rid())
			added_limb = true
	if not added_limb:
		return first_hit
	query.exclude = excluded
	var deeper_hit := space.intersect_ray(query)
	if deeper_hit.is_empty():
		return first_hit
	var deeper_collider: Object = deeper_hit.get("collider")
	if not deeper_collider is Area3D or not deeper_collider.has_meta("hitbox"):
		return first_hit
	if (deeper_collider as Node).get_parent() != actor:
		return first_hit
	if String(deeper_collider.get_meta("zone", "")) not in ["head", "torso", "stomach"]:
		return first_hit
	return deeper_hit

func _ejector_global() -> Transform3D:
	if active_index < _views.size():
		var v: Node3D = _views[active_index]
		var ej := v.get_node_or_null("Ejector")
		if ej:
			return (ej as Node3D).global_transform
	return sway_root.global_transform

func try_fire() -> void:
	if not GameState.online_ready or is_reloading or player.is_dead or player.is_driving or _switch_t < SWITCH_DUR or _bolt_cycle > 0.0 or _throw_anim_t > 0.0:
		return
	is_inspecting = false
	inspect_t = 0.0
	var cfg := current_config()
	if ammo <= 0:
		Audio.dry()
		start_reload()
		return
		
	var now := _time
	var interval: float = 60.0 / float(cfg["fire_rate"])
	if now - _last_fire + 0.001 < interval:
		return
	if not bool(cfg["is_auto"]) and not _can_fire_semi:
		return
		
	player.end_spawn_protection()
	_last_fire = now
	_can_fire_semi = false
	_shot_seq += 1
	if net and net.connected:
		_pending_shots.append({"id": _shot_seq, "weapon": String(cfg["id"])})
	ammo -= 1
	_ammo_store[String(cfg["id"])] = ammo
	_burst_count = _burst_count + 1 if now - _last_shot_time < 0.25 else 1
	_last_shot_time = now
	if active_index == 2:
		_bolt_cycle = interval
	ammo_changed.emit(ammo, int(cfg["mag_size"]))
	Audio.shoot(String(cfg["id"]))
	
	# Auditory perception stimulus for bots
	if world and world.has_node("Bots"):
		var bm = world.get_node("Bots")
		if bm and bm.has_method("report_noise"):
			bm.report_noise(player.global_position, 48.0)
	
	# Recoil kick values
	var is_ads := ads_amount > 0.5
	var ads_mult: float = float(cfg["ads_recoil_mult"]) if is_ads else 1.0
	_vel_y += float(cfg["recoil_vertical"]) * ads_mult * 25.0
	_vel_x += randf_range(-1.0, 1.0) * float(cfg["recoil_horizontal"]) * ads_mult * 25.0
	_kick_z = 0.016 if is_ads else 0.045
	_kick_rx = deg_to_rad(1.6) if is_ads else deg_to_rad(3.6)
	_bolt_kick = 1.0
	
	# Hitscan cone from camera
	var cam_pos := camera.global_position
	var cam_dir := -camera.global_transform.basis.z.normalized()
	var movement := clampf(Vector2(player.velocity.x, player.velocity.z).length() / GameState.WALK_SPEED, 0.0, 1.5)
	var accuracy := lerpf(1.0, float(cfg["ads_spread_mult"]), ads_amount)
	var shot_spread := spread * accuracy + movement * lerpf(0.65, 0.12, ads_amount)
	if not player.is_grounded:
		shot_spread += 2.0
	if player.is_crouching:
		shot_spread *= 0.75
	var spread_rad := deg_to_rad(shot_spread)
	# Bloom affects subsequent rounds; the first settled shot uses the settled cone.
	spread = minf(spread + float(cfg["bloom_per_shot"]), float(cfg["max_spread"]))
	var ang := randf() * TAU
	var r := sqrt(randf()) * sin(spread_rad)
	var right := camera.global_transform.basis.x.normalized()
	var up := camera.global_transform.basis.y.normalized()
	var dir := (cam_dir + right * cos(ang) * r + up * sin(ang) * r).normalized()
	
	var shot_origin := _muzzle_global()
	_hitscan_query.from = cam_pos
	_hitscan_query.to = cam_pos + dir * 300.0
	_hitscan_query.exclude = [player.get_rid()]
	var space := world.get_world_3d().direct_space_state
	var hit := space.intersect_ray(_hitscan_query)
	hit = resolve_same_actor_center_through_limb(space, _hitscan_query, hit)
	# Resolve the muzzle-to-aim path too: the camera cannot fire a barrel through cover.
	var aim_point: Vector3 = hit.get("position", cam_pos + dir * 300.0)
	_hitscan_query.from = shot_origin
	_hitscan_query.to = aim_point
	_hitscan_query.exclude = [player.get_rid()]
	var muzzle_hit := space.intersect_ray(_hitscan_query)
	muzzle_hit = resolve_same_actor_center_through_limb(space, _hitscan_query, muzzle_hit)
	# The muzzle path is the physical shot path used by the server, so its nearest
	# intersection also determines the client-side zone and damage feedback.
	if not muzzle_hit.is_empty():
		hit = muzzle_hit
	var hit_pos: Vector3 = cam_pos + dir * 300.0
	var hit_norm := Vector3.UP
	var hit_wall := false
	var has_hit_target := false
	var hit_target := ""
	var hit_dmg := 0
	var hit_view_time_ms := 0
	
	if not hit.is_empty():
		hit_pos = hit["position"]
		hit_norm = hit["normal"]
		var collider: Object = hit["collider"]
		
		var is_hitbox: bool = collider and collider.has_meta("hitbox")
		var is_character: bool = collider and collider.has_method("take_damage")
		
		if is_hitbox or is_character:
			var target: String = ""
			var zone: String = "torso"
			var bot_node: Node = null
			
			if is_hitbox:
				target = collider.get_meta("player_id", "")
				zone = collider.get_meta("zone", "torso")
				bot_node = (collider as Node).get_parent() if collider is Node else null
			else:
				bot_node = collider as Node
				target = String(bot_node.get_meta("server_vehicle_id", "")) if bot_node.has_meta("server_vehicle_id") else (bot_node.bot_name if "bot_name" in bot_node else (bot_node.player_id if "player_id" in bot_node else "BOT"))
				zone = "torso"
			if is_instance_valid(bot_node) and bot_node.has_method("get_hit_view_time_ms"):
				hit_view_time_ms = int(bot_node.get_hit_view_time_ms())
				
			var dmg := GameState.damage_for_zone(cfg, shot_origin.distance_to(hit_pos), zone)
			var is_head := (zone == "head")
			
			# Check if hitting a local bot
			if bot_node is WarBot:
				var was_dead: bool = bot_node.dead if "dead" in bot_node else false
				bot_node.take_damage(float(dmg), zone, GameState.username, "gun")
				spawn_blood(hit_pos, dir)
				var is_now_dead: bool = bot_node.dead if "dead" in bot_node else false
				hit_confirmed_editorial.emit(target, dmg, is_now_dead and not was_dead, is_head)
			else:
				hit_confirmed_editorial.emit(target, dmg, false, is_head)
				
			has_hit_target = true
			hit_target = target
			hit_dmg = dmg
		else:
			hit_wall = true
			queue_impact(hit_pos, hit_norm, _muzzle_global().distance_to(hit_pos) / float(MUZZLE_SPEEDS.get(cfg["id"], 715.0)))
			
	# Muzzle visual & tracer
	var start := shot_origin
	_spawn_tracer(start, hit_pos)
	_flash(start, dir)
	_eject_shell()
	
	# Dynamic camera recoil kick with smooth spring recovery
	var cam_kick_y := float(cfg["recoil_vertical"]) * ads_mult * 0.4
	var recoil_side := sin(float(_burst_count) * 1.7) * 0.75 + randf_range(-0.25, 0.25)
	var cam_kick_x := recoil_side * float(cfg["recoil_horizontal"]) * ads_mult * 0.4
	if player.has_method("apply_recoil"):
		player.apply_recoil(cam_kick_y, cam_kick_x)
	else:
		player.pitch = clampf(player.pitch + cam_kick_y, -PI / 2.1, PI / 2.1)
		player.yaw += cam_kick_x
		player.rotation.y = player.yaw
		player.head.rotation.x = player.pitch
	
	if net and net.connected:
		if net.has_method("send_aim_pitch"):
			var fire_yaw := atan2(-cam_dir.x, -cam_dir.z)
			var fire_pitch := -asin(clampf(cam_dir.y, -1.0, 1.0))
			net.call("send_fire_with_aim", start, hit_pos, hit_norm, hit_wall, _shot_seq, fire_yaw, fire_pitch)
		else:
			net.send_fire(start, hit_pos, hit_norm, hit_wall, _shot_seq)
		if has_hit_target and not hit_target.is_empty():
			net.send_hit(hit_target, hit_dmg, _shot_seq, hit_view_time_ms)
	fired.emit(active_index)
func _flash(pos: Vector3, _dir: Vector3) -> void:
	_flash_mesh.global_position = pos
	_flash_mesh.global_basis = camera.global_basis
	_flash_mesh.rotate_object_local(Vector3.FORWARD, randf_range(0.0, TAU))
	_flash_mesh.scale = Vector3(randf_range(0.45, 0.7), randf_range(0.45, 0.7), randf_range(0.8, 1.3))
	_flash_mesh.visible = true
	_flash_light.global_position = pos
	_flash_light.light_energy = randf_range(1.7, 2.5)
	_flash_light.visible = true
	_flash_t = 0.022

func _eject_shell() -> void:
	# Zero-allocation pooled brass casing
	var ej_xf := _ejector_global()
	var slot: Dictionary = _casings[_casing_idx]
	_casing_idx = (_casing_idx + 1) % CASING_POOL
	var mi: MeshInstance3D = slot["node"]
	mi.global_transform = ej_xf
	var eject_dir := (ej_xf.basis.x * randf_range(1.2, 1.8) + ej_xf.basis.y * randf_range(0.8, 1.4) + ej_xf.basis.z * randf_range(0.2, 0.6)).normalized()
	slot["vel"] = eject_dir * randf_range(2.0, 3.2) + Vector3.DOWN * 1.5
	slot["rot_vel"] = Vector3(randf_range(-14, 14), randf_range(-14, 14), randf_range(-14, 14))
	slot["t"] = 0.0
	slot["dur"] = 0.38
	slot["active"] = true
	mi.visible = true

func spawn_blood(pos: Vector3, direction: Vector3, intensity: float = 1.0) -> void:
	if _bloods.is_empty(): return
	for i in clampi(roundi(8 * intensity), 6, 20):
		var slot: Dictionary = _bloods[_blood_idx]
		_blood_idx = (_blood_idx + 1) % BLOOD_POOL
		var particle: MeshInstance3D = slot["node"]
		particle.global_position = pos
		particle.scale = Vector3.ONE * randf_range(0.8, 1.8)
		particle.visible = true
		slot["active"] = true
		slot["t"] = 0.0
		slot["dur"] = randf_range(0.30, 0.55)
		slot["vel"] = direction.normalized() * randf_range(1.0, 2.8) + Vector3(randf_range(-0.8,0.8), randf_range(0.1,1.2), randf_range(-0.8,0.8))

func spawn_death_blood(feet: Vector3) -> void:
	spawn_blood(feet + Vector3.UP * 0.85, Vector3.UP, 2.0)
	var query := PhysicsRayQueryParameters3D.create(feet + Vector3.UP, feet + Vector3.DOWN * 3.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or Vector3(hit.normal).y < 0.6: return
	var stain := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * randf_range(0.6, 1.0)
	stain.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_texture = BloodTexture.get_texture()
	material.albedo_color = Color(0.24, 0.008, 0.006, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 1.0
	material.metallic_specular = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	stain.material_override = material
	stain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(stain)
	var normal: Vector3 = hit.normal
	var tangent := normal.cross(Vector3.FORWARD).normalized()
	stain.global_transform = Transform3D(Basis(tangent, normal.cross(tangent), normal), hit.position + normal * 0.012)
	stain.rotate_object_local(Vector3.FORWARD, randf() * TAU)
	_track_decal(stain)
	var fade := stain.create_tween()
	fade.tween_interval(12.0)
	fade.tween_property(material, "albedo_color:a", 0.0, 6.0)
	fade.tween_callback(stain.queue_free)

func _track_decal(decal: MeshInstance3D) -> void:
	for index in range(_decals.size()-1,-1,-1):
		if not is_instance_valid(_decals[index].get_ref()): _decals.remove_at(index)
	_decals.append(weakref(decal))
	while _decals.size() > MAX_DECALS:
		var old = _decals.pop_front().get_ref()
		if is_instance_valid(old): old.queue_free()

func queue_impact(pos: Vector3, normal: Vector3, travel: float) -> void:
	if _pending_impacts.size() >= 64: _pending_impacts.pop_front()
	_pending_impacts.append({"pos":pos, "normal":normal, "remaining":travel})

func _spawn_tracer(a: Vector3, b: Vector3, weapon_id: String = "") -> void:
	var d := a.distance_to(b)
	if d < 0.1: return
	if weapon_id.is_empty(): weapon_id = String(current_config()["id"])
	var speed := float(MUZZLE_SPEEDS.get(weapon_id, 715.0))
	var slot: Dictionary = _tracers[_tracer_idx]
	_tracer_idx = (_tracer_idx + 1) % TRACER_POOL
	slot["from"] = a
	slot["to"] = b
	slot["t"] = 0.0
	slot["dur"] = maxf(d / speed, 0.016)
	slot["length"] = minf(d * 0.5, speed * 0.0018)
	slot["active"] = true
	var mi: MeshInstance3D = slot["node"]
	mi.global_position = a
	var direction := (b-a).normalized()
	mi.look_at(b, Vector3.UP if absf(direction.y) < 0.95 else Vector3.RIGHT)
	mi.scale = Vector3(1, 1, minf(0.2, d * 0.5))
	mi.visible = true

func _spawn_impact(pos: Vector3, normal: Vector3) -> void:
	# Zero-allocation pooled directional spark burst (5 sparks)
	for i in 2:
		var slot: Dictionary = _sparks[_spark_idx]
		_spark_idx = (_spark_idx + 1) % SPARK_POOL
		var mi: MeshInstance3D = slot["node"]
		mi.global_position = pos + normal * 0.03
		var spread_dir := (normal * randf_range(0.8, 1.4) + Vector3(randf_range(-1, 1), randf_range(-0.4, 1), randf_range(-1, 1))).normalized()
		slot["vel"] = spread_dir * randf_range(2.2, 4.0) + Vector3.DOWN * 1.2
		slot["t"] = 0.0
		slot["dur"] = 0.22
		slot["active"] = true
		mi.visible = true
		
	# Zero-allocation pooled dust / smoke puff
	var dslot: Dictionary = _dusts[_dust_idx]
	_dust_idx = (_dust_idx + 1) % DUST_POOL
	var dmi: MeshInstance3D = dslot["node"]
	dmi.global_position = pos + normal * 0.05
	dmi.scale = Vector3.ONE * 0.5
	dslot["start_pos"] = dmi.global_position
	dslot["normal"] = normal
	dslot["t"] = 0.0
	dslot["dur"] = 0.35
	dslot["active"] = true
	dmi.visible = true
		
	# Decal lifetime and capacity are managed through weak references.

	if not _decal_mesh:
		_decal_mesh = QuadMesh.new()
		_decal_mesh.size = Vector2(0.065, 0.065)
	if not _decal_mat:
		_decal_mat = StandardMaterial3D.new()
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0, 0.25, 0.55, 1])
		gradient.colors = PackedColorArray([Color(0.04, 0.035, 0.025, 0.95), Color(0.08, 0.07, 0.05, 0.85), Color(0.19, 0.16, 0.12, 0.45), Color(0.2, 0.17, 0.13, 0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 64
		texture.height = 64
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1, 0.5)
		_decal_mat.albedo_texture = texture
		_decal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_decal_mat.albedo_color = Color(0.08, 0.08, 0.08)
		_decal_mat.roughness = 1.0

	var di := MeshInstance3D.new()
	di.mesh = _decal_mesh
	di.material_override = _decal_mat
	di.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(di)
	di.global_position = pos + normal * 0.01
	var up_vec := Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT
	di.look_at(pos + normal, up_vec)
	_track_decal(di)

func start_inspect() -> void:
	if is_reloading or player.is_dead or ads_amount > 0.15:
		return
	is_inspecting = true
	inspect_t = 0.0

func start_reload() -> void:
	var cfg := current_config()
	if is_reloading or ammo >= int(cfg["mag_size"]) or player.is_dead:
		return
	is_inspecting = false
	inspect_t = 0.0
	is_reloading = true
	reload_t = 0.0
	if net and net.connected:
		net.send_reload()
	Audio.reload()

func switch_weapon(idx: int) -> void:
	if idx not in GameState.equipped_indices() or idx == active_index or idx < 0 or idx >= _views.size() or player.is_dead:
		return
	is_inspecting = false
	inspect_t = 0.0
	_ammo_store[String(current_config()["id"])] = ammo
	is_reloading = false
	reload_t = 0.0
	active_index = idx
	scope_idx = int(_zoom_store.get(idx, 0))
	_switch_t = 0.0
	ads_t = 0.0
	ads_amount = 0.0
	for i in _views.size():
		_views[i].visible = (i == idx)
	var cfg := current_config()
	ammo = int(_ammo_store.get(String(cfg["id"]), cfg["mag_size"]))
	spread = float(cfg["base_spread"])
	_can_fire_semi = true
	ammo_changed.emit(ammo, int(cfg["mag_size"]))
	if net and net.connected:
		net.send_switch(GameState.weapon_id_for_index(idx))

func _process(delta: float) -> void:
	var elapsed := delta
	_time += elapsed
	_bolt_cycle = maxf(0.0, _bolt_cycle - elapsed)
	delta = minf(delta, 0.05)
	if not is_instance_valid(player):
		return
	var cfg := current_config()
	var active_scene := get_tree().current_scene
	var qa_input: bool = is_instance_valid(active_scene) and active_scene.get("_qa_active") == true
	var input_enabled: bool = GameState.online_ready and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or qa_input) and not player.is_dead and not player.is_driving
	is_firing = input_enabled and Input.is_action_pressed("fire")
	if not input_enabled:
		player.aim_sway = Vector2.ZERO
		is_holding_breath = false
	
	if not Input.is_action_pressed("fire"):
		_can_fire_semi = true
		
	# Snappy military-spec ADS transition with quintic Perlin smootherstep easing
	var ads_target := 1.0 if input_enabled and Input.is_action_pressed("ads") and not is_reloading and _switch_t >= SWITCH_DUR and _throw_anim_t <= 0.0 else 0.0
	var ads_speed: float = float(cfg["ads_time"])
	ads_t = move_toward(ads_t, ads_target, delta / maxf(ads_speed, 0.01))
	var st: float = clampf(ads_t, 0.0, 1.0)
	ads_amount = st * st * st * (st * (st * 6.0 - 15.0) + 10.0)
	
	# Scope Magnification toggle (V key)
	var v_pressed := (Input.is_physical_key_pressed(KEY_V) and not _v_pressed_last)
	_v_pressed_last = Input.is_physical_key_pressed(KEY_V)
	if v_pressed and input_enabled:
		cycle_scope_magnification()
	
	# Fire handling
	if is_firing:
		try_fire()
		
	# Inspect Weapon input (I key)
	var i_pressed := Input.is_action_just_pressed("inspect") or (Input.is_physical_key_pressed(KEY_I) and not _i_pressed_last)
	_i_pressed_last = Input.is_physical_key_pressed(KEY_I)
	if i_pressed and input_enabled:
		start_inspect()
	if ads_amount > 0.15 or is_firing:
		is_inspecting = false
		inspect_t = 0.0
		
	# Reload & Weapon switch inputs
	if input_enabled and Input.is_action_just_pressed("reload"):
		start_reload()
	var equipped: Array[int] = GameState.equipped_indices()
	if input_enabled and Input.is_action_just_pressed("weapon_1"):
		switch_weapon(equipped[0])
	if input_enabled and Input.is_action_just_pressed("weapon_2"):
		switch_weapon(equipped[1])
	if input_enabled and (Input.is_action_just_pressed("next_weapon") or Input.is_action_just_pressed("prev_weapon")):
		switch_weapon(equipped[1] if active_index == equipped[0] else equipped[0])

	# 3-Phase Tactile Reload Animation
	var reload_offset := Vector3.ZERO
	var reload_rot := Vector3.ZERO
	if is_reloading:
		reload_t += elapsed
		var reload_dur: float = float(cfg["reload_time"])
		var progress := reload_t / reload_dur
		if progress < 0.22:
			var t := 0.5 - 0.5 * cos(progress / 0.22 * PI)
			reload_offset = Vector3(-0.02 * t, -0.20 * t, 0.02 * t)
			reload_rot = Vector3(0.40 * t, -0.15 * t, -0.18 * t)
		elif progress < 0.72:
			var bump := sin(clampf((progress - 0.63) / 0.08, 0.0, 1.0) * PI) * 0.012
			reload_offset = Vector3(-0.02, -0.20 + bump, 0.02)
			reload_rot = Vector3(0.40, -0.15, -0.18)
		else:
			var t := 0.5 + 0.5 * cos((progress - 0.72) / 0.28 * PI)
			reload_offset = Vector3(-0.02 * t, -0.20 * t, 0.02 * t)
			reload_rot = Vector3(0.40 * t, -0.15 * t, -0.18 * t)
			
		if reload_t >= reload_dur:
			is_reloading = false
			ammo = int(cfg["mag_size"])
			_ammo_store[String(cfg["id"])] = ammo
			ammo_changed.emit(ammo, int(cfg["mag_size"]))
			
	# Bloom recovery
	if spread > float(cfg["base_spread"]):
		spread = float(cfg["base_spread"]) + (spread - float(cfg["base_spread"])) * exp(-float(cfg["bloom_recovery"]) * delta)
		
	# Recoil spring physics
	var spring_x := _spring(_recoil_x, _vel_x, delta)
	var spring_y := _spring(_recoil_y, _vel_y, delta)
	_recoil_x = spring_x.x
	_vel_x = spring_x.y
	_recoil_y = spring_y.x
	_vel_y = spring_y.y
	
	# Dynamic bolt carrier / slide mechanical reciprocation
	if _bolt_kick > 0.0:
		_bolt_kick = maxf(0.0, _bolt_kick - delta * 24.0)
		if active_index < _views.size():
			var cur_view: Node3D = _views[active_index]
			var bolt_node: Node3D = cur_view.get_node_or_null("boltCarrier") as Node3D
			if bolt_node:
				bolt_node.position.z = _bolt_kick * 0.052
			var slide_node: Node3D = cur_view.get_node_or_null("slide") as Node3D
			if slide_node:
				slide_node.position.z = _bolt_kick * 0.038
				
	# Tactical magazine drop & insertion during reload
	if is_reloading and active_index < _views.size():
		var cur_view: Node3D = _views[active_index]
		var mag_node: Node3D = cur_view.get_node_or_null("magazine") as Node3D
		if mag_node:
			var progress := reload_t / maxf(float(cfg["reload_time"]), 0.1)
			if progress < 0.22:
				var mt := 0.5 - 0.5 * cos(progress / 0.22 * PI)
				mag_node.position.y = lerpf(0.0, -0.18, mt)
			elif progress < 0.65:
				mag_node.position.y = -0.18
			else:
				var mt := 0.5 - 0.5 * cos(clampf((progress - 0.65) / 0.25, 0.0, 1.0) * PI)
				mag_node.position.y = lerpf(-0.18, 0.0, mt)
	elif active_index < _views.size():
		var cur_view: Node3D = _views[active_index]
		var mag_node: Node3D = cur_view.get_node_or_null("magazine") as Node3D
		if mag_node and mag_node.position.y != 0.0:
			mag_node.position.y = 0.0
	
	# Viewmodel mouse sway & bobbing (calibrated for steady, grounded AAA feel)
	var mx := Input.get_last_mouse_velocity()
	var target_sway_x := clampf(-mx.x * 0.00003, -0.018, 0.018)
	var target_sway_y := clampf(-mx.y * 0.00003, -0.016, 0.016)
	_sway_x = lerpf(_sway_x, target_sway_x, minf(1.0, 16.0 * delta))
	_sway_y = lerpf(_sway_y, target_sway_y, minf(1.0, 16.0 * delta))
	
	var is_ply_grounded := is_instance_valid(player) and player.is_grounded
	var moving := (Input.is_action_pressed("move_forward") or Input.is_action_pressed("move_back") or Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right")) and is_ply_grounded
	if moving and not is_reloading:
		_bob_t += delta * (14.0 if Input.is_action_pressed("sprint") else 9.0)
	else:
		_bob_t = 0.0
		
	# Dynamic jump & vertical inertia physics
	var target_air_y := 0.0
	var target_air_rx := 0.0
	if is_instance_valid(player):
		var vy: float = player.velocity.y
		# Downward lag on upward launch, upward float on downward fall
		target_air_y = -clampf(vy * 0.008, -0.035, 0.030)
		target_air_rx = clampf(vy * 0.012, -0.040, 0.050)
		# Landing shock absorption
		if player.is_grounded and player._land_dip > 0.001:
			target_air_y -= player._land_dip * 0.45
			target_air_rx += player._land_dip * 0.35
	_air_lag_y = lerpf(_air_lag_y, target_air_y, clampf(14.0 * delta, 0.0, 1.0))
	_air_lag_rx = lerpf(_air_lag_rx, target_air_rx, clampf(12.0 * delta, 0.0, 1.0))
		
	# Breath exhaustion requires release and recovery, rather than toggling every frame.
	var breath_pressed: bool = input_enabled and Input.is_action_pressed("sprint")
	if not breath_pressed and breath_stamina >= 0.3:
		_breath_exhausted = false
	is_holding_breath = is_scoped() and ads_amount > 0.9 and breath_pressed and not _breath_exhausted and breath_stamina > 0.0 and Vector2(player.velocity.x, player.velocity.z).length() < 1.0
	if is_holding_breath:
		breath_stamina = maxf(0.0, breath_stamina - delta * 0.24)
		if breath_stamina <= 0.0:
			_breath_exhausted = true
	else:
		breath_stamina = minf(1.0, breath_stamina + delta * 0.22)
	var aim_amplitude := 0.0008 if active_index == 2 else 0.00018
	var steady_weight := 0.12 if is_holding_breath else 1.0
	var aim_drift := Vector2(sin(_time * 1.17), sin(_time * 0.83 + 0.7)) * aim_amplitude * steady_weight * ads_amount
	player.aim_sway = aim_drift if input_enabled else Vector2.ZERO

	# When aiming down sights, sway is eliminated so reticle remains rock-steady
	var ads_mult_sway := clampf(1.0 - ads_amount * 1.6, 0.0, 1.0) * (0.05 if is_holding_breath else 1.0)
	var amp := (0.005 if Input.is_action_pressed("sprint") else 0.0025) * ads_mult_sway
	var bob := Vector3(
		sin(_bob_t) * amp if moving else 0.0,
		(absf(cos(_bob_t)) * amp if moving else sin(_time * 1.5) * 0.001 * ads_mult_sway),
		_kick_z
	)
	_kick_z = lerpf(_kick_z, 0.0, minf(1.0, 15.0 * delta))
	_kick_rx = lerpf(_kick_rx, 0.0, minf(1.0, 15.0 * delta))
	
	# Procedural 3-phase weapon inspection choreography (I key)
	var inspect_pos := Vector3.ZERO
	var inspect_rot := Vector3.ZERO
	if is_inspecting and not is_reloading and ads_amount < 0.15:
		inspect_t += delta
		var progress := inspect_t / INSPECT_DURATION
		if progress >= 1.0:
			is_inspecting = false
			inspect_t = 0.0
		elif progress < 0.35:
			# Phase 1: Turn left side of receiver, bolt, and markings toward camera
			var t := progress / 0.35
			var ease_p1 := sin(t * PI * 0.5)
			inspect_pos = Vector3(-0.048, 0.024, 0.04) * ease_p1
			inspect_rot = Vector3(-0.12, 0.58, -0.42) * ease_p1
		elif progress < 0.70:
			# Phase 2: Tilt upward to inspect optic, chamber, and ejection port
			var t := (progress - 0.35) / 0.35
			var p1_pos := Vector3(-0.048, 0.024, 0.04)
			var p2_pos := Vector3(0.038, 0.042, 0.02)
			var p1_rot := Vector3(-0.12, 0.58, -0.42)
			var p2_rot := Vector3(0.36, -0.34, 0.35)
			inspect_pos = p1_pos.lerp(p2_pos, t)
			inspect_rot = p1_rot.lerp(p2_rot, t)
		else:
			# Phase 3: Smooth return to idle
			var t := (progress - 0.70) / 0.30
			var ease_p3 := cos(t * PI * 0.5)
			var p2_pos := Vector3(0.038, 0.042, 0.02)
			var p2_rot := Vector3(0.36, -0.34, 0.35)
			inspect_pos = p2_pos * ease_p3
			inspect_rot = p2_rot * ease_p3

	# Smooth continuous position lerp between Hip and ADS
	var hip_pos: Vector3 = cfg["hip_pos"]
	var ads_pos: Vector3 = cfg["ads_pos"]
	var base: Vector3 = hip_pos.lerp(ads_pos, ads_amount)
	
	# Procedural shoulder-tuck & sight alignment arc
	var ads_arc := sin(ads_amount * PI)
	var ads_arc_pos := Vector3(-0.010, -0.007, 0.014) * ads_arc
	var ads_arc_rot := Vector3(deg_to_rad(0.9), deg_to_rad(-0.6), deg_to_rad(1.2)) * ads_arc
	
	var inspect_weight := clampf(1.0 - ads_amount * 2.0, 0.0, 1.0)
	
	# Weapon switch / draw animation (quick tactical raise)
	var switch_offset := Vector3.ZERO
	var switch_rot := Vector3.ZERO
	if _switch_t < SWITCH_DUR:
		_switch_t += elapsed
		var sk := clampf(_switch_t / SWITCH_DUR, 0.0, 1.0)
		var s_inv := (1.0 - sk) * (1.0 - sk)
		switch_offset = Vector3(0.015 * s_inv, -0.14 * s_inv, 0.04 * s_inv)
		switch_rot = Vector3(deg_to_rad(12.0) * s_inv, deg_to_rad(-6.0) * s_inv, deg_to_rad(-8.0) * s_inv)
	
	# Grenade throw viewmodel reaction (weapon dips down and tilts as arm throws, then returns)
	var throw_offset := Vector3.ZERO
	var throw_rot := Vector3.ZERO
	if _throw_anim_t > 0.0:
		_throw_anim_t = maxf(0.0, _throw_anim_t - delta)
		var tp := 1.0 - (_throw_anim_t / THROW_ANIM_DUR)
		var curve := sin(tp * PI)
		throw_offset = Vector3(0.04 * curve, -0.22 * curve, 0.08 * curve)
		throw_rot = Vector3(-0.35 * curve, 0.18 * curve, -0.15 * curve)
	
	sway_root.position = base + ads_arc_pos + switch_offset + throw_offset + bob + reload_offset + inspect_pos * inspect_weight + Vector3(0.0, _air_lag_y * (1.0 - ads_amount), 0.0)
	sway_root.rotation = Vector3(
		_sway_y * ads_mult_sway + _kick_rx + _recoil_y * 0.1 + reload_rot.x + ads_arc_rot.x + switch_rot.x + throw_rot.x + inspect_rot.x * inspect_weight + _air_lag_rx * (1.0 - ads_amount),
		_sway_x * ads_mult_sway + _recoil_x * 0.1 + reload_rot.y + ads_arc_rot.y + switch_rot.y + throw_rot.y + inspect_rot.y * inspect_weight,
		-_sway_x * 0.08 * ads_mult_sway + reload_rot.z + ads_arc_rot.z + switch_rot.z + throw_rot.z + inspect_rot.z * inspect_weight
	)
	
	# Hide viewmodel when eye is fully seated against high-power scope so reticle is completely unobstructed
	if active_index < _views.size():
		var is_scoped := is_scoped() and ads_amount > 0.86
		_views[active_index].visible = not is_scoped
	
	# Flash decay
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash_mesh.visible = false
			_flash_light.visible = false
			
	for index in range(_pending_impacts.size()-1, -1, -1):
		_pending_impacts[index]["remaining"] -= elapsed
		if _pending_impacts[index]["remaining"] <= 0:
			_spawn_impact(_pending_impacts[index]["pos"], _pending_impacts[index]["normal"])
			_pending_impacts.remove_at(index)

	# Tracers advancement
	for slot in _tracers:
		if not slot["active"]:
			continue
		slot["t"] = float(slot["t"]) + elapsed
		var mi: MeshInstance3D = slot["node"]
		var dur: float = float(slot["dur"])
		if float(slot["t"]) >= dur:
			slot["active"] = false
			mi.visible = false
		else:
			var k: float = float(slot["t"]) / maxf(dur, 0.001)
			var pos: Vector3 = (slot["from"] as Vector3).lerp(slot["to"] as Vector3, k)
			var direction: Vector3 = ((slot["to"] as Vector3) - (slot["from"] as Vector3)).normalized()
			var travelled: float = (slot["from"] as Vector3).distance_to(pos)
			var streak := minf(float(slot["length"]), travelled)
			mi.global_position = pos - direction * streak * 0.5
			mi.scale.z = maxf(0.03, streak)
			var to_dir := (slot["to"] as Vector3) - mi.global_position
			if to_dir.length_squared() > 0.001:
				var up_v := Vector3.UP if absf(to_dir.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
				mi.look_at(slot["to"] as Vector3, up_v)

	for slot in _bloods:
		if not slot["active"]: continue
		slot["t"] += elapsed
		var particle: MeshInstance3D = slot["node"]
		if slot["t"] >= slot["dur"]:
			slot["active"] = false
			particle.visible = false
		else:
			var velocity: Vector3 = slot["vel"]
			velocity.y -= 8.0 * delta
			slot["vel"] = velocity
			particle.global_position += velocity * delta
			particle.scale *= maxf(0, 1.0 - 2.0 * delta)

	# Casings advancement (zero allocation)
	for slot in _casings:
		if not slot["active"]:
			continue
		slot["t"] = float(slot["t"]) + delta
		var mi: MeshInstance3D = slot["node"]
		var dur: float = float(slot["dur"])
		if float(slot["t"]) >= dur:
			slot["active"] = false
			mi.visible = false
			Audio.casing()
		else:
			slot["vel"] = (slot["vel"] as Vector3) + Vector3.DOWN * 18.0 * delta
			mi.global_position += (slot["vel"] as Vector3) * delta
			mi.rotation += (slot["rot_vel"] as Vector3) * delta

	# Sparks advancement (zero allocation)
	for slot in _sparks:
		if not slot["active"]:
			continue
		slot["t"] = float(slot["t"]) + delta
		var mi: MeshInstance3D = slot["node"]
		var dur: float = float(slot["dur"])
		if float(slot["t"]) >= dur:
			slot["active"] = false
			mi.visible = false
		else:
			slot["vel"] = (slot["vel"] as Vector3) + Vector3.DOWN * 12.0 * delta
			mi.global_position += (slot["vel"] as Vector3) * delta

	# Dust advancement (zero allocation)
	for slot in _dusts:
		if not slot["active"]:
			continue
		slot["t"] = float(slot["t"]) + delta
		var mi: MeshInstance3D = slot["node"]
		var dur: float = float(slot["dur"])
		if float(slot["t"]) >= dur:
			slot["active"] = false
			mi.visible = false
		else:
			var k: float = float(slot["t"]) / dur
			mi.scale = Vector3.ONE * lerpf(0.5, 2.2, k)
			mi.global_position = (slot["start_pos"] as Vector3) + (slot["normal"] as Vector3) * (0.16 * k)

func clear() -> void:
	_decals.clear()
	_pending_impacts.clear()
	if is_instance_valid(_tracer_container):
		_tracer_container.queue_free()
	_tracers.clear()
	if is_instance_valid(_casing_container):
		_casing_container.queue_free()
	_casings.clear()
	if is_instance_valid(_spark_container):
		_spark_container.queue_free()
	_sparks.clear()
	if is_instance_valid(_dust_container):
		_dust_container.queue_free()
	_dusts.clear()
	if is_instance_valid(_blood_container): _blood_container.queue_free()
	_bloods.clear()
	for v in _views:
		if is_instance_valid(v):
			v.queue_free()
	_views.clear()

static func _spring(position_value: float, velocity_value: float, delta: float) -> Vector2:
	# Exact critically damped solution remains stable through frame-time spikes.
	var omega := 18.0
	var decay := exp(-omega * delta)
	var c := velocity_value + omega * position_value
	return Vector2((position_value + c * delta) * decay, (velocity_value - omega * c * delta) * decay)

func reconcile_ammo(state: Dictionary) -> void:
	var acknowledged := int(state.get("last_shot_id", 0))
	_pending_shots = _pending_shots.filter(func(shot: Dictionary) -> bool: return int(shot["id"]) > acknowledged)
	var weapon_id := String(state.get("weapon", ""))
	if weapon_id != String(current_config()["id"]):
		return
	var pending := 0
	for shot in _pending_shots:
		if shot["weapon"] == weapon_id: pending += 1
	ammo = maxi(0, int(state.get("ammo", ammo)) - pending)
	_ammo_store[weapon_id] = ammo
