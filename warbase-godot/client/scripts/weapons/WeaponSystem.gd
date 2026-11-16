class_name WarWeaponSystem
extends Node3D
const Missile := preload("res://scripts/drones/DroneMissile.gd")
signal fired(weapon_index: int)
signal hit_confirmed_editorial(target: String, damage: int, is_kill: bool, is_headshot: bool)

var player: WarPlayer
var camera: Camera3D
var net: WarNetwork
var world: Node3D

var active_index := 0
var ammo := 30
var reserve_ammo := 90
var is_reloading := false
var reload_t := 0.0
var spread := 1.5
var ads_t := 0.0
var ads_amount := 0.0
var _switch_t := 1.0
const SWITCH_DUR := 0.22
var is_firing := false

var _shot_seq := 0
var _pending_shots: Array = []
var _ammo_store: Dictionary = {}
var _reserve_store: Dictionary = {}
var _bolt_cycle := 0.0
var _burst_count := 0
var _last_shot_time := -10.0
var _throw_anim_t := 0.0
const THROW_ANIM_DUR := 0.42

func play_grenade_throw() -> void:
	_throw_anim_t = THROW_ANIM_DUR

var _last_fire_by_mount: Dictionary = {}
var _offhand_trigger_ready := true
var _offhand_reload_until := 0.0
var dual_fire := false
var drone_thermal := false
var drone_zoom_index := 0
const DRONE_ZOOM_LEVELS := [2, 4, 8]
var _can_fire_semi := true
var _tracers: Array = []
var _tracer_idx := 0
var _pending_impacts: Array = []
const MUZZLE_SPEEDS := {"ak47":715.0, "m4":900.0, "mp5":400.0, "pistol":340.0, "dmr":820.0, "m2010":850.0, "hmg":890.0, "laser":2400.0}
var _flash_light: OmniLight3D
var _flash_mesh: MeshInstance3D
var _flash_t := 0.0
var _time := 0.0
var _tracer_container: Node3D
var _tracer_mat: StandardMaterial3D
var _laser_mat: StandardMaterial3D
const TRACER_POOL := 64
const MAX_DECALS := 32
const SPARK_POOL := 24
const DUST_POOL := 8

var locked_target: Node3D = null
var lock_progress: float = 0.0
var is_locked: bool = false
var _lock_scan_timer: float = 0.0

var _sparks: Array = []
var _spark_idx := 0
var _spark_container: Node3D

var _dusts: Array = []
var _dust_idx := 0
var _dust_container: Node3D
var _drone_effects: Node

var _hitscan_query: PhysicsRayQueryParameters3D = null
var _decals: Array[WeakRef] = []

static var _spark_mesh: SphereMesh = null
static var _spark_mat: StandardMaterial3D = null

static var _dust_mesh: SphereMesh = null
static var _decal_mesh: QuadMesh = null
static var _decal_mat: StandardMaterial3D = null

const CASING_POOL := 16
var _casings: Array[Dictionary] = []
var _casing_idx := 0
var _casing_container: Node3D
static var _casing_mesh: CylinderMesh = null
static var _casing_mat: StandardMaterial3D = null
static var _blast_crater_mesh: QuadMesh = null
static var _blast_crater_texture: ImageTexture = null

func current_config() -> Dictionary:
	return GameState.WEAPONS[active_index]

func reset_after_respawn() -> void:
	clear_pending_shots()
	_restock_ammo()
	is_reloading = false
	reload_t = 0.0
	ads_t = 0.0
	ads_amount = 0.0
	_bolt_cycle = 0.0
	_burst_count = 0
	_switch_t = 0.0
	_last_fire_by_mount.clear()
	_offhand_reload_until = 0.0
	_offhand_trigger_ready = true
	drone_thermal = false

func drone_zoom() -> int:
	return DRONE_ZOOM_LEVELS[drone_zoom_index]

func drone_optic_fov() -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(GameState.BASE_FOV) * 0.5) / float(drone_zoom())))

func can_dual_fire() -> bool:
	return GameState.practice_mode or (is_instance_valid(net) and net.supports_dual_payload)

func _offhand_index() -> int:
	var equipped := GameState.equipped_indices()
	for idx in equipped:
		if idx != active_index:
			return idx
	return equipped[0]

func payload_status(index: int) -> Vector3i:
	var id := GameState.weapon_id_for_index(index)
	if index == active_index:
		return Vector3i(ammo, reserve_ammo, int(is_reloading))
	return Vector3i(int(_ammo_store.get(id, 0)), int(_reserve_store.get(id, 0)), int(_offhand_reload_until > _time))

func setup(p: WarPlayer, cam: Camera3D, net_ref: WarNetwork, world_ref: Node3D) -> void:
	player = p
	camera = cam
	net = net_ref
	world = world_ref
	_drone_effects = get_tree().get_first_node_in_group("drone_combat_effects")
	
	active_index = GameState.starting_weapon_index()

	var cfg := current_config()
	_restock_ammo()
	spread = float(cfg["base_spread"])
	if net and net.connected:
		net.send_switch(String(cfg["id"]))
	_sync_drone_payload()
	
	# Dedicated container for bullets/tracers in world
	_tracer_container = Node3D.new()
	_tracer_container.name = "TracerPool"
	world_ref.add_child(_tracer_container)
	
	# Pool tracers so sustained dual fire does not allocate scene nodes.
	var tracer_box := BoxMesh.new()
	tracer_box.size = Vector3(0.018, 0.018, 1.0)
	_tracer_mat = StandardMaterial3D.new()
	_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer_mat.albedo_color = Color(1.0, 0.86, 0.58)
	_tracer_mat.emission_enabled = true
	_tracer_mat.emission = Color(1.0, 0.70, 0.35)
	_tracer_mat.emission_energy_multiplier = 1.8
	
	_laser_mat = StandardMaterial3D.new()
	_laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_laser_mat.albedo_color = Color("00e5ff")
	_laser_mat.emission_enabled = true
	_laser_mat.emission = Color("00e5ff")
	_laser_mat.emission_energy_multiplier = 4.2
	for i in TRACER_POOL:
		var mi := MeshInstance3D.new()
		mi.mesh = tracer_box
		mi.material_override = _tracer_mat
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_tracer_container.add_child(mi)
		_tracers.append({"node": mi, "t": 0.0, "dur": 0.0, "from": Vector3.ZERO, "to": Vector3.ZERO, "active": false, "is_laser": false})
		
	# Query world/vehicle solids and anatomical combatant areas. Exclude layer 2:
	# a bot's broad CharacterBody capsule would otherwise mask its layer-4 hitboxes.
	_hitscan_query = PhysicsRayQueryParameters3D.new()
	_hitscan_query.collide_with_areas = true
	_hitscan_query.collide_with_bodies = true
	_hitscan_query.collision_mask = 1 | 4
	# Pre-allocate spark pool
	_spark_container = Node3D.new()
	_spark_container.name = "SparkPool"
	world_ref.add_child(_spark_container)
	if not _spark_mesh:
		_spark_mesh = SphereMesh.new()
		_spark_mesh.radius = 0.024
		_spark_mesh.height = 0.048
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
	add_child(_flash_mesh)
	
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.85, 0.4)
	_flash_light.light_energy = 3.5
	_flash_light.omni_range = 3.5
	_flash_light.visible = false
	add_child(_flash_light)

	_casing_container = Node3D.new()
	_casing_container.name = "CasingContainer"
	add_child(_casing_container)
	if not _casing_mesh:
		_casing_mesh = CylinderMesh.new()
		_casing_mesh.top_radius = 0.006
		_casing_mesh.bottom_radius = 0.006
		_casing_mesh.height = 0.035
		_casing_mesh.radial_segments = 6
	if not _casing_mat:
		_casing_mat = StandardMaterial3D.new()
		_casing_mat.albedo_color = Color(0.92, 0.78, 0.32)
		_casing_mat.metallic = 0.92
		_casing_mat.roughness = 0.22
	for i in range(CASING_POOL):
		var mi := MeshInstance3D.new()
		mi.mesh = _casing_mesh
		mi.material_override = _casing_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		_casing_container.add_child(mi)
		_casings.append({"node": mi, "vel": Vector3.ZERO, "rot_axis": Vector3.RIGHT, "rot_speed": 0.0, "active": false, "age": 0.0, "bounced": false})

func _muzzle_global(weapon_id: String = "") -> Vector3:
	var visual := player.get("_drone_visual") as Node3D
	if is_instance_valid(visual):
		return visual.call("get_muzzle_global", weapon_id)
	return player.global_position - player.global_basis.z * 0.3

func _sync_drone_payload() -> void:
	if not is_instance_valid(player): return
	var visual := player.get("_drone_visual") as Node
	if is_instance_valid(visual) and visual.has_method("set_weapon"):
		var id := GameState.weapon_id_for_index(active_index)
		if active_index in GameState.equipped_indices():
			visual.call("set_loadout", GameState.selected_primary, GameState.selected_secondary, id, GameState.selected_tertiary)
		else:
			visual.call("set_weapon", id)
		if player.has_method("_mask_local_drone_hardware"): player.call("_mask_local_drone_hardware", visual)

func try_fire() -> void:
	if not GameState.online_ready or player.is_dead or player.is_driving or _switch_t < SWITCH_DUR or _throw_anim_t > 0.0:
		return
	# Both barrels use the same sight line for this trigger sample.
	var aim := camera.global_transform
	_fire_mount(active_index, aim)
	if dual_fire and can_dual_fire():
		_fire_mount(_offhand_index(), aim)

func _fire_mount(index: int, aim: Transform3D) -> void:
	var offhand := index != active_index
	if (offhand and _offhand_reload_until > _time) or (not offhand and (is_reloading or _bolt_cycle > 0.0)):
		return
	var cfg: Dictionary = GameState.WEAPONS[index]
	var id := String(cfg["id"])
	var loaded := int(_ammo_store[id]) if offhand else ammo
	if loaded <= 0:
		if offhand: _start_offhand_reload()
		else: start_reload()
		return
	var now := _time
	var interval: float = 60.0 / float(cfg["fire_rate"])
	if now - float(_last_fire_by_mount.get(index, -10.0)) + 0.001 < interval:
		return
	if not bool(cfg["is_auto"]) and not (_offhand_trigger_ready if offhand else _can_fire_semi):
		return

	player.end_spawn_protection()
	_last_fire_by_mount[index] = now
	if offhand: _offhand_trigger_ready = false
	else: _can_fire_semi = false
	_shot_seq += 1
	if net and net.connected:
		_pending_shots.append({"id": _shot_seq, "weapon": id})
	_ammo_store[id] = loaded - 1
	if not offhand: ammo = loaded - 1
	var wire_weapon := id if dual_fire and can_dual_fire() else ""
	_burst_count = _burst_count + 1 if now - _last_shot_time < 0.25 else 1
	_last_shot_time = now
	if not offhand and index == 2:
		_bolt_cycle = interval
	if cfg.has("missile_speed"):
		_launch_missile(cfg, aim, wire_weapon)
		fired.emit(index)
		return
	Audio.shoot(String(cfg["id"]))
	if is_instance_valid(player) and player.get("_drone_visual") != null:
		var vis = player.get("_drone_visual")
		if vis and vis.has_method("kick_recoil"): vis.kick_recoil(0.040)
	
	# Auditory perception stimulus for bots
	if world and world.has_node("Bots"):
		var bm = world.get_node("Bots")
		if bm and bm.has_method("report_noise"):
			bm.report_noise(player.global_position, 48.0)
	
	# Recoil kick values
	var is_ads := ads_amount > 0.5
	var ads_mult: float = float(cfg["ads_recoil_mult"]) if is_ads else 1.0
	# Hitscan cone from camera
	var cam_pos := aim.origin
	var cam_dir := -aim.basis.z.normalized()
	var movement := clampf(Vector2(player.velocity.x, player.velocity.z).length() / GameState.WALK_SPEED, 0.0, 1.5)
	var accuracy := lerpf(1.0, float(cfg["ads_spread_mult"]), ads_amount)
	var cone := float(cfg["base_spread"]) if offhand else spread
	var shot_spread := cone * accuracy + movement * lerpf(0.65, 0.12, ads_amount)
	var spread_rad := deg_to_rad(shot_spread)
	# Bloom affects subsequent rounds; the first settled shot uses the settled cone.
	if not offhand: spread = minf(spread + float(cfg["bloom_per_shot"]), float(cfg["max_spread"]))
	var ang := randf() * TAU
	var r := sqrt(randf()) * sin(spread_rad)
	var right := aim.basis.x.normalized()
	var up := aim.basis.y.normalized()
	var dir := (cam_dir + right * cos(ang) * r + up * sin(ang) * r).normalized()
	
	var shot_origin := _muzzle_global(id)
	_eject_casing(shot_origin, aim)
	_hitscan_query.from = cam_pos
	_hitscan_query.to = cam_pos + dir * 300.0
	_hitscan_query.exclude = [player.get_rid()]
	var space := world.get_world_3d().direct_space_state
	var hit := space.intersect_ray(_hitscan_query)
	# Resolve the muzzle-to-aim path too: the camera cannot fire a barrel through cover.
	var aim_point: Vector3 = hit.get("position", cam_pos + dir * 300.0)
	_hitscan_query.from = shot_origin
	_hitscan_query.to = aim_point
	_hitscan_query.exclude = [player.get_rid()]
	var muzzle_hit := space.intersect_ray(_hitscan_query)
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
				spawn_hull_hit(hit_pos, dir)
				var is_now_dead: bool = bot_node.dead if "dead" in bot_node else false
				hit_confirmed_editorial.emit(target, dmg, is_now_dead and not was_dead, is_head)
			else:
				hit_confirmed_editorial.emit(target, dmg, false, is_head)
				
			has_hit_target = true
			hit_target = target
			hit_dmg = dmg
		else:
			hit_wall = true
			queue_impact(hit_pos, hit_norm, shot_origin.distance_to(hit_pos) / float(MUZZLE_SPEEDS.get(cfg["id"], 715.0)))
			
	# Muzzle visual & tracer
	var start := shot_origin
	_spawn_tracer(start, hit_pos, id)
	if not offhand: _flash(start, dir)
	
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
		var physical_dir := (aim_point - start).normalized()
		if physical_dir.is_zero_approx(): physical_dir = cam_dir
		net.send_fire(start, hit_pos, hit_norm, hit_wall, _shot_seq,
			atan2(-physical_dir.x, -physical_dir.z), -asin(clampf(physical_dir.y, -1.0, 1.0)), wire_weapon)
		if has_hit_target and not hit_target.is_empty():
			net.send_hit(hit_target, hit_dmg, _shot_seq, hit_view_time_ms)
	fired.emit(index)

func _launch_missile(config: Dictionary, aim: Transform3D, wire_weapon: String) -> void:
	var start := _muzzle_global(String(config["id"]))
	var aim_direction := -aim.basis.z.normalized()
	var query := PhysicsRayQueryParameters3D.create(aim.origin, aim.origin + aim_direction * 300.0, 5, [player.get_rid()])
	query.collide_with_areas = true
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	var aim_point: Vector3 = hit.get("position", query.to)
	var direction := (aim_point - start).normalized()
	if direction.dot(aim_direction) <= 0.0: direction = aim_direction
	
	# Active auto-lock guidance
	var chosen_target: Node3D = locked_target if (is_locked or lock_progress > 0.4) else null
	if chosen_target != null and is_instance_valid(chosen_target):
		var to_tgt := ((chosen_target.global_position + Vector3.UP * 0.35) - start).normalized()
		if to_tgt.dot(aim_direction) > 0.35:
			direction = to_tgt
			
	if net and net.connected:
		net.predict_missile(_shot_seq, String(config["id"]), start, direction * float(config["missile_speed"]))
		net.send_fire(start, aim_point, Vector3.ZERO, false, _shot_seq,
			atan2(-direction.x, -direction.z), -asin(clampf(direction.y, -1.0, 1.0)), wire_weapon)
	else:
		var speed := float(config["missile_speed"])
		Missile.launch(world, String(config["id"]), start, direction, speed, float(config["missile_range"]) / speed, player, float(config["damage"]), chosen_target)

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

func spawn_hull_hit(pos: Vector3, direction: Vector3, intensity: float = 1.0) -> void:
	if is_instance_valid(_drone_effects):
		_drone_effects.call("hit", pos, direction, intensity)
	var normal := -direction.normalized() if direction.is_finite() else Vector3.UP
	_spawn_impact(pos, normal, 2 * clampi(roundi(2.0 * intensity), 1, 4), false, true)

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
	var is_laser := weapon_id == "laser"
	var speed := 2400.0 if is_laser else float(MUZZLE_SPEEDS.get(weapon_id, 715.0))
	var slot: Dictionary = _tracers[_tracer_idx]
	_tracer_idx = (_tracer_idx + 1) % TRACER_POOL
	slot["from"] = a
	slot["to"] = b
	slot["t"] = 0.0
	slot["dur"] = 0.065 if is_laser else maxf(d / speed, 0.016)
	slot["length"] = (d * 0.98) if is_laser else minf(d * 0.8, speed * 0.012)
	slot["is_laser"] = is_laser
	slot["active"] = true
	var mi: MeshInstance3D = slot["node"]
	mi.material_override = _laser_mat if is_laser else _tracer_mat
	mi.global_position = a
	var direction := (b-a).normalized()
	mi.look_at(b, Vector3.UP if absf(direction.y) < 0.95 else Vector3.RIGHT)
	mi.scale = Vector3(1, 1, minf(0.2, d * 0.5))
	mi.visible = true
	var viewport := get_viewport()
	if viewport != null:
		var camera := viewport.get_camera_3d()
		if camera != null:
			var cam_pos := camera.global_position
			var ab := b - a
			var len_sq := ab.length_squared()
			if len_sq > 0.01:
				var t := clampf((cam_pos - a).dot(ab) / len_sq, 0.0, 1.0)
				var nearest_point := a + ab * t
				var dist := cam_pos.distance_to(nearest_point)
				if dist < 3.8 and a.distance_to(cam_pos) > 2.5:
					Audio.supersonic_crack(clampf(-dist * 2.0, -8.0, 0.0))

func _eject_casing(origin: Vector3, aim: Transform3D) -> void:
	if _casings.is_empty(): return
	var slot: Dictionary = _casings[_casing_idx]
	_casing_idx = (_casing_idx + 1) % CASING_POOL
	var mi: MeshInstance3D = slot["node"]
	var right := aim.basis.x.normalized()
	var up := aim.basis.y.normalized()
	var forward := -aim.basis.z.normalized()
	mi.global_position = origin - forward * 0.12 + right * 0.08
	slot["vel"] = right * randf_range(2.0, 3.5) + up * randf_range(1.2, 2.2) - forward * randf_range(0.2, 0.6)
	slot["rot_axis"] = (right * randf() + up * randf() + forward * randf()).normalized()
	slot["rot_speed"] = randf_range(16.0, 32.0)
	slot["active"] = true
	slot["age"] = 0.0
	slot["bounced"] = false
	mi.visible = true

static func _get_blast_crater_texture() -> ImageTexture:
	if _blast_crater_texture != null: return _blast_crater_texture
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var u := (float(x) / float(size - 1)) * 2.0 - 1.0
			var v := (float(y) / float(size - 1)) * 2.0 - 1.0
			var d := sqrt(u * u + v * v)
			var a := clampf(1.0 - smoothstep(0.2, 1.0, d), 0.0, 1.0)
			var noise_val := (sin(u * 12.0) * cos(v * 12.0)) * 0.12
			a = clampf(a + noise_val, 0.0, 0.88)
			img.set_pixel(x, y, Color(0.04, 0.03, 0.02, a))
	_blast_crater_texture = ImageTexture.create_from_image(img)
	return _blast_crater_texture

func spawn_blast_crater(pos: Vector3, radius: float = 1.2) -> void:
	if not is_instance_valid(world): return
	var space := world.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.5, pos + Vector3.DOWN * 2.5, 1)
	var hit := space.intersect_ray(query)
	if hit.is_empty(): return
	var hit_pos: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	if not _blast_crater_mesh:
		_blast_crater_mesh = QuadMesh.new()
		_blast_crater_mesh.size = Vector2(radius * 2.0, radius * 2.0)
	var decal := MeshInstance3D.new()
	decal.mesh = _blast_crater_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _get_blast_crater_texture()
	decal.material_override = mat
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(decal)
	decal.global_position = hit_pos + normal * 0.015
	if absf(normal.y) < 0.98:
		decal.look_at(hit_pos + normal, Vector3.UP)
	else:
		decal.rotation = Vector3(-PI * 0.5, randf() * TAU, 0.0)
	_track_decal(decal)

func _spawn_impact(pos: Vector3, normal: Vector3, spark_count := 4, surface_hit := true, is_metal := false) -> void:
	if normal.is_zero_approx(): normal = Vector3.UP
	var count := spark_count
	# Pooled directional spark burst.
	for i in count:
		var slot: Dictionary = _sparks[_spark_idx]
		_spark_idx = (_spark_idx + 1) % SPARK_POOL
		var mi: MeshInstance3D = slot["node"]
		mi.global_position = pos + normal * 0.03
		var spread_dir := (normal * randf_range(0.8, 1.4) + Vector3(randf_range(-1, 1), randf_range(-0.4, 1), randf_range(-1, 1))).normalized()
		var speed := randf_range(3.5, 6.0) if is_metal else randf_range(2.2, 4.0)
		slot["vel"] = spread_dir * speed + Vector3.DOWN * 1.2
		slot["t"] = 0.0
		slot["dur"] = 0.28 if is_metal else 0.22
		slot["active"] = true
		mi.visible = true
		
	if not surface_hit: return
	# Zero-allocation pooled dust / smoke puff
	var dslot: Dictionary = _dusts[_dust_idx]
	_dust_idx = (_dust_idx + 1) % DUST_POOL
	var dmi: MeshInstance3D = dslot["node"]
	dmi.global_position = pos + normal * 0.05
	dmi.scale = Vector3.ONE * (0.8 if not is_metal else 0.3)
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

func start_reload() -> void:
	var cfg := current_config()
	if not GameState.online_ready or is_reloading or ammo >= int(cfg["mag_size"]) or reserve_ammo <= 0 or player.is_dead or player.is_driving:
		return
	is_reloading = true
	reload_t = 0.0
	if net and net.connected:
		net.send_reload()
	Audio.reload()

func _start_offhand_reload() -> void:
	if _offhand_reload_until > _time: return
	var index := _offhand_index()
	var config: Dictionary = GameState.WEAPONS[index]
	var id := String(config["id"])
	if int(_ammo_store[id]) >= int(config["mag_size"]) or int(_reserve_store[id]) <= 0: return
	_offhand_reload_until = _time + float(config["reload_time"])
	if net and net.connected: net.send_reload(id)

func switch_weapon(idx: int) -> void:
	if idx not in GameState.equipped_indices() or idx == active_index or idx < 0 or idx >= GameState.WEAPONS.size() or player.is_dead:
		return
	_offhand_reload_until = 0.0
	_ammo_store[String(current_config()["id"])] = ammo
	is_reloading = false
	reload_t = 0.0
	active_index = idx
	_switch_t = 0.0
	_sync_drone_payload()
	var cfg := current_config()
	ammo = int(_ammo_store.get(String(cfg["id"]), cfg["mag_size"]))
	reserve_ammo = int(_reserve_store.get(String(cfg["id"]), _starting_reserve(cfg)))
	spread = float(cfg["base_spread"])
	_can_fire_semi = true
	if net and net.connected:
		net.send_switch(GameState.weapon_id_for_index(idx))

func _controls_enabled() -> bool:
	var scene := get_tree().current_scene
	var qa_input: bool = is_instance_valid(scene) and scene.get("_qa_active") == true
	return GameState.online_ready and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or qa_input) and not player.is_dead and not player.is_driving

func _input(event: InputEvent) -> void:
	if not is_instance_valid(player) or event.is_echo() or not _controls_enabled(): return
	if event.is_action_pressed("optic_zoom"):
		if Input.is_action_pressed("ads"):
			drone_zoom_index = (drone_zoom_index + 1) % DRONE_ZOOM_LEVELS.size()
	elif event.is_action_pressed("thermal") and Input.is_action_pressed("ads"):
		drone_thermal = not drone_thermal
	elif event.is_action_pressed("reload"):
		start_reload()
		if dual_fire and can_dual_fire(): _start_offhand_reload()
	elif event.is_action_pressed("weapon_3"):
		var equipped := GameState.equipped_indices()
		if equipped.size() >= 3:
			dual_fire = false
			switch_weapon(equipped[2])
		elif can_dual_fire():
			dual_fire = true
	elif (event.is_action_pressed("weapon_4") or (event is InputEventKey and event.pressed and event.keycode == KEY_4)) and can_dual_fire():
		dual_fire = not dual_fire
	elif event.is_action_pressed("weapon_1") or event.is_action_pressed("weapon_2"):
		dual_fire = false
		var slot := 0 if event.is_action_pressed("weapon_1") else 1
		switch_weapon(GameState.equipped_indices()[slot])
	elif event.is_action_pressed("next_weapon") or event.is_action_pressed("prev_weapon"):
		dual_fire = false
		var equipped := GameState.equipped_indices()
		var cur_pos := equipped.find(active_index)
		if cur_pos != -1:
			var dir := 1 if event.is_action_pressed("next_weapon") else -1
			var next_pos := (cur_pos + dir + equipped.size()) % equipped.size()
			switch_weapon(equipped[next_pos])
		else:
			switch_weapon(_offhand_index())

func _process(delta: float) -> void:
	var elapsed := delta
	_time += elapsed
	_bolt_cycle = maxf(0.0, _bolt_cycle - elapsed)
	delta = minf(delta, 0.05)
	if not is_instance_valid(player):
		return
	var cfg := current_config()
	var input_enabled := _controls_enabled()
	is_firing = input_enabled and Input.is_action_pressed("fire")
	if not Input.is_action_pressed("fire"):
		_can_fire_semi = true
		_offhand_trigger_ready = true
		
	# Snappy military-spec ADS transition with quintic Perlin smootherstep easing
	var ads_target := 1.0 if input_enabled and Input.is_action_pressed("ads") else 0.0
	var ads_speed: float = float(cfg["ads_time"])
	ads_t = move_toward(ads_t, ads_target, delta / maxf(ads_speed, 0.01))
	var st: float = clampf(ads_t, 0.0, 1.0)
	ads_amount = st * st * st * (st * (st * 6.0 - 15.0) + 10.0)
	if _offhand_reload_until > 0.0 and _time >= _offhand_reload_until:
		_offhand_reload_until = 0.0
		if not player.colyseus_authoritative_sim:
			var other: Dictionary = GameState.WEAPONS[_offhand_index()]
			var other_id := String(other["id"])
			var moved := mini(int(other["mag_size"]) - int(_ammo_store[other_id]), int(_reserve_store[other_id]))
			_ammo_store[other_id] += moved
			_reserve_store[other_id] -= moved
	if is_firing: try_fire()

	_switch_t = minf(_switch_t + elapsed, SWITCH_DUR)
	_throw_anim_t = maxf(0.0, _throw_anim_t - elapsed)
	if is_reloading:
		reload_t += elapsed
		if reload_t >= float(cfg["reload_time"]):
			is_reloading = false
			if not player.colyseus_authoritative_sim:
				var transferred := mini(int(cfg["mag_size"]) - ammo, reserve_ammo)
				ammo += transferred
				reserve_ammo -= transferred
				_ammo_store[String(cfg["id"])] = ammo
				_reserve_store[String(cfg["id"])] = reserve_ammo
	if spread > float(cfg["base_spread"]):
		spread = float(cfg["base_spread"]) + (spread - float(cfg["base_spread"])) * exp(-float(cfg["bloom_recovery"]) * delta)

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

	# Missile seeker and auto-lock scanning
	if cfg.has("missile_speed") and input_enabled:
		_update_missile_lock(delta)
	else:
		locked_target = null
		lock_progress = 0.0
		is_locked = false

	# Tracers advancement
	for slot in _tracers:
		if not slot["active"]:
			continue
		slot["t"] = float(slot["t"]) + elapsed
		var mi: MeshInstance3D = slot["node"]
		var is_laser: bool = bool(slot.get("is_laser", false))
		if is_laser:
			const LASER_DUR := 0.065
			if float(slot["t"]) >= LASER_DUR:
				slot["active"] = false
				mi.visible = false
				continue
			var fade := 1.0 - (float(slot["t"]) / LASER_DUR)
			var start: Vector3 = slot["from"]
			var end: Vector3 = slot["to"]
			var full_len := start.distance_to(end)
			mi.global_position = (start + end) * 0.5
			var dir := (end - start).normalized()
			mi.look_at(end, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
			mi.scale = Vector3(1.6 * fade, 1.6 * fade, maxf(0.1, full_len))
			continue
			
		var dur: float = float(slot["dur"])
		const AFTERGLOW := 0.042
		if float(slot["t"]) >= dur + AFTERGLOW:
			slot["active"] = false
			mi.visible = false
			continue
		var k := minf(float(slot["t"]) / dur, 1.0)
		var start: Vector3 = slot["from"]
		var end: Vector3 = slot["to"]
		var pos := start.lerp(end, k)
		var direction := (end - start).normalized()
		var fade := 1.0 - smoothstep(dur, dur + AFTERGLOW, float(slot["t"]))
		var streak := minf(float(slot["length"]), start.distance_to(pos)) * fade
		mi.global_position = pos - direction * streak * 0.5
		var width := clampf(camera.global_position.distance_to(pos) * tan(deg_to_rad(camera.fov) * 0.5) * 0.18, 0.8, 16.0) * fade
		mi.scale = Vector3(width, width, maxf(0.03, streak))

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

	# Casing advancement
	for slot in _casings:
		if not slot["active"]:
			continue
		slot["age"] = float(slot["age"]) + delta
		if float(slot["age"]) > 2.2:
			slot["active"] = false
			slot["node"].visible = false
			continue
		var mi: MeshInstance3D = slot["node"]
		slot["vel"] = (slot["vel"] as Vector3) + Vector3.DOWN * 12.0 * delta
		var next_pos: Vector3 = mi.global_position + (slot["vel"] as Vector3) * delta
		if is_instance_valid(world) and world.get_world_3d():
			var space := world.get_world_3d().direct_space_state
			if space:
				var ray := PhysicsRayQueryParameters3D.create(mi.global_position, next_pos, 1)
				var hit := space.intersect_ray(ray)
				if not hit.is_empty():
					if not bool(slot["bounced"]):
						slot["bounced"] = true
						slot["vel"] = (slot["vel"] as Vector3).bounce(hit["normal"]) * 0.35
						Audio.casing()
					else:
						slot["vel"] = Vector3.ZERO
						slot["active"] = false
					next_pos = (hit["position"] as Vector3) + (hit["normal"] as Vector3) * 0.005
		mi.global_position = next_pos
		mi.rotate(slot["rot_axis"], float(slot["rot_speed"]) * delta)

func clear() -> void:
	_decals.clear()
	_pending_impacts.clear()
	if is_instance_valid(_tracer_container):
		_tracer_container.queue_free()
	_tracers.clear()
	if is_instance_valid(_spark_container):
		_spark_container.queue_free()
	_sparks.clear()
	if is_instance_valid(_dust_container):
		_dust_container.queue_free()
	_dusts.clear()
	if is_instance_valid(_casing_container):
		_casing_container.queue_free()
	_casings.clear()
func _starting_reserve(config: Dictionary) -> int:
	return int(config["mag_size"]) * (2 if config.has("missile_speed") else 3)

func _restock_ammo() -> void:
	for weapon in GameState.WEAPONS:
		var id := String(weapon["id"])
		_ammo_store[id] = int(weapon["mag_size"])
		_reserve_store[id] = _starting_reserve(weapon)
	var equipped := String(current_config()["id"])
	ammo = _ammo_store[equipped]
	reserve_ammo = _reserve_store[equipped]

func clear_pending_shots() -> void:
	_pending_shots.clear()

func reconcile_offhand_ammo(state: Dictionary) -> void:
	var id := String(state.get("weapon", ""))
	if id not in [GameState.selected_primary, GameState.selected_secondary, GameState.selected_tertiary]: return
	if id == GameState.weapon_id_for_index(_offhand_index()) and not bool(state.get("reloading", false)):
		_offhand_reload_until = 0.0
	reconcile_ammo(state)

func reconcile_ammo(state: Dictionary) -> void:
	var acknowledged := int(state.get("last_shot_id", 0))
	if not _pending_shots.is_empty():
		_pending_shots = _pending_shots.filter(func(shot: Dictionary) -> bool: return int(shot["id"]) > acknowledged)
	var weapon_id := String(state.get("weapon", ""))
	if not _ammo_store.has(weapon_id):
		return
	var pending := 0
	for shot in _pending_shots:
		if shot["weapon"] == weapon_id: pending += 1
	_ammo_store[weapon_id] = maxi(0, int(state.get("ammo", _ammo_store[weapon_id])) - pending)
	_reserve_store[weapon_id] = maxi(0, int(state.get("reserve_ammo", _reserve_store[weapon_id])))
	if weapon_id == String(current_config()["id"]):
		ammo = _ammo_store[weapon_id]
		reserve_ammo = _reserve_store[weapon_id]

func _update_missile_lock(delta: float) -> void:
	_lock_scan_timer += delta
	if _lock_scan_timer < 0.035: return
	_lock_scan_timer = 0.0
	
	var cam := camera
	if not is_instance_valid(cam): return
	var cam_pos := cam.global_position
	var cam_forward := -cam.global_transform.basis.z.normalized()
	
	var best_cand: Node3D = null
	var best_dot := 0.70 # ~45 degree forward acquisition cone
	
	# Check local AI bots
	if world and world.has_node("Bots"):
		var bm = world.get_node("Bots")
		if bm and "bots" in bm:
			for bot in bm.bots:
				if not is_instance_valid(bot) or (bot.has_method("is_dead") and bot.is_dead()) or ("dead" in bot and bot.dead):
					continue
				if "team" in bot and bot.team == GameState.local_team:
					continue
				var target_pt: Vector3 = bot.global_position + Vector3.UP * 0.4
				var to_bot := target_pt - cam_pos
				var d := to_bot.length()
				if d < 3.0 or d > 170.0: continue
				var dot := cam_forward.dot(to_bot.normalized())
				if dot > best_dot:
					_hitscan_query.from = cam_pos
					_hitscan_query.to = target_pt
					_hitscan_query.exclude = [player.get_rid()]
					var hit := world.get_world_3d().direct_space_state.intersect_ray(_hitscan_query)
					if hit.is_empty() or hit.get("collider") == bot or (hit.get("collider") is Node and hit.get("collider").get_parent() == bot):
						best_dot = dot
						best_cand = bot
						
	# Check remote human players
	if net and "remote_players" in net:
		for rp in net.remote_players.values():
			if not is_instance_valid(rp) or (rp.has_method("is_dead") and rp.is_dead()): continue
			if "team" in rp and rp.team == GameState.local_team: continue
			var target_pt: Vector3 = rp.global_position + Vector3.UP * 0.4
			var to_rp := target_pt - cam_pos
			var d := to_rp.length()
			if d < 3.0 or d > 170.0: continue
			var dot := cam_forward.dot(to_rp.normalized())
			if dot > best_dot:
				_hitscan_query.from = cam_pos
				_hitscan_query.to = target_pt
				_hitscan_query.exclude = [player.get_rid()]
				var hit := world.get_world_3d().direct_space_state.intersect_ray(_hitscan_query)
				if hit.is_empty() or hit.get("collider") == rp:
					best_dot = dot
					best_cand = rp
					
	# Check vehicles
	var vehicles := get_tree().get_nodes_in_group("combat_jeeps")
	for v in vehicles:
		if not is_instance_valid(v) or v == player: continue
		var target_pt: Vector3 = v.global_position + Vector3.UP * 0.6
		var to_v := target_pt - cam_pos
		var d := to_v.length()
		if d < 3.0 or d > 170.0: continue
		var dot := cam_forward.dot(to_v.normalized())
		if dot > best_dot:
			best_dot = dot
			best_cand = v
			
	if best_cand != null:
		if locked_target == best_cand:
			lock_progress = minf(1.0, lock_progress + delta * 2.8)
			if lock_progress >= 1.0 and not is_locked:
				is_locked = true
				Audio.missile_lock_warning()
		else:
			locked_target = best_cand
			lock_progress = 0.15
			is_locked = false
	else:
		lock_progress = maxf(0.0, lock_progress - delta * 4.5)
		if lock_progress <= 0.0:
			locked_target = null
			is_locked = false
