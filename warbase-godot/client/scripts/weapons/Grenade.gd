class_name WarGrenade
extends Node3D
## Studio-grade M67 Frag Grenade.
## Realistic tumble physics, authentic spoon release, impact bounce,
## high-yield fragmentation blast VFX, camera trauma shake, and radial damage.

signal exploded(pos: Vector3)

var fuse := 3.0
var blast_radius := 8.5
var blast_damage := 90.0
var throwable_id := "frag"
var _t := 0.0
var _done := false
var _last_bounce := -1.0
var linear_velocity := Vector3.ZERO
var angular_velocity := Vector3.ZERO
const Ballistics = preload("res://scripts/weapons/GrenadeBallistics.gd")



static func throw(world: Node, pos: Vector3, vel: Vector3, spin: Vector3 = Vector3.ZERO, kind: String = "frag") -> WarGrenade:
	var scene := load("res://scenes/Grenade.tscn") as PackedScene
	var g := scene.instantiate() as WarGrenade
	g.configure(kind)
	world.add_child(g)
	g.global_position = pos
	g.linear_velocity = vel
	g.angular_velocity = spin if spin.length() > 0.1 else Vector3(randf_range(16.0, 24.0), randf_range(-8.0, 8.0), randf_range(-6.0, 6.0))
	return g

func configure(kind: String) -> void:
	throwable_id = kind
	var config: Dictionary = GameState.THROWABLES.get(kind, GameState.THROWABLES["frag"])
	fuse = config["fuse"]
	blast_radius = config["radius"]
	blast_damage = config["damage"]
	if kind == "impact":
		var body := get_node_or_null("ModelRoot/Body") as MeshInstance3D
		if body:
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("384249")
			material.metallic = 0.55
			material.roughness = 0.6
			body.material_override = material
		var stripe := get_node_or_null("ModelRoot/HazardStripe") as MeshInstance3D
		if stripe:
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("d48742")
			stripe.material_override = material

func _ready() -> void:
	add_to_group("grenades")
	for node_name in ["ModelRoot/FuseWick", "ModelRoot/FuseLight"]:
		var indicator = get_node_or_null(node_name)
		if indicator: indicator.visible = false


func _play_bounce(speed: float) -> void:
	if _t - _last_bounce < 0.08 or speed < 1.0: return
	_last_bounce = _t
	var audio := get_node_or_null("/root/Audio")
	if audio and audio.has_method("grenade_bounce"): audio.grenade_bounce()

func _physics_process(delta: float) -> void:
	if _done:
		return
	var steps := maxi(1, ceili(delta / Ballistics.STEP))
	var dt := delta / steps
	var space := get_world_3d().direct_space_state
	for i in steps:
		_t += dt
		var armed := throwable_id == "impact" and _t >= 0.18
		var result := Ballistics.step(space, global_position, linear_velocity, dt, armed)
		global_position = result.position
		linear_velocity = result.velocity
		if result.contact:
			_play_bounce(result.impact_speed)
			angular_velocity *= 0.65 if result.impact_speed > 1.5 else maxf(0.0, 1.0 - 8.0 * dt)
			if armed and GameState.practice_mode:
				_done = true
				_detonate()
				return
		var model := get_node_or_null("ModelRoot") as Node3D
		if model:
			model.rotation += angular_velocity * dt
		angular_velocity *= maxf(0.0, 1.0 - 0.12 * dt)
	
	if not GameState.practice_mode and _t >= 6.0:
		queue_free()
		return
	if GameState.practice_mode and _t >= fuse:
		_done = true
		_detonate()

func _detonate() -> void:
	var origin := global_position
	exploded.emit(origin)
	var audio := get_node_or_null("/root/Audio")
	if audio and audio.has_method("explosion"):
		audio.explosion()
	
	var parent_node := get_parent()
	if is_instance_valid(parent_node):
		var bm = parent_node.get_node_or_null("Bots")
		if bm and bm.has_method("report_noise"):
			bm.report_noise(origin, 60.0)
			
		# 1. High-Energy Central Fireball Burst
		var burst := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.75
		sm.height = 1.5
		burst.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.55, 0.12)
		burst.material_override = m
		burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent_node.add_child(burst)
		burst.global_position = origin
		
		# 2. Expanding Shockwave Ring (Flat on ground)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.8
		tm.outer_radius = 1.2
		tm.rings = 16
		tm.ring_segments = 12
		ring.mesh = tm
		var rmat := StandardMaterial3D.new()
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rmat.albedo_color = Color(1.0, 0.85, 0.45, 0.75)
		rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = rmat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent_node.add_child(ring)
		ring.global_position = origin + Vector3(0, 0.08, 0)
		
		# 3. Dynamic Flash Lighting with high falloff
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.72, 0.35)
		light.light_energy = 8.5
		light.omni_range = 18.0
		parent_node.add_child(light)
		light.global_position = origin + Vector3(0, 0.4, 0)
		
		# 4. Billowing Smoke Plumes
		for i in 6:
			var smoke := MeshInstance3D.new()
			var ssm := SphereMesh.new()
			ssm.radius = 0.4
			ssm.height = 0.8
			smoke.mesh = ssm
			var smat := StandardMaterial3D.new()
			smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			smat.albedo_color = Color(0.25, 0.23, 0.22, 0.65)
			smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			smoke.material_override = smat
			smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent_node.add_child(smoke)
			smoke.global_position = origin + Vector3(randf_range(-0.5, 0.5), randf_range(0.2, 0.8), randf_range(-0.5, 0.5))
			var stw := get_tree().create_tween()
			var target_pos := smoke.global_position + Vector3(randf_range(-2.5, 2.5), randf_range(1.5, 3.5), randf_range(-2.5, 2.5))
			stw.tween_property(smoke, "global_position", target_pos, 0.95)
			stw.set_parallel(true)
			stw.tween_property(smoke, "scale", Vector3(2.5, 2.5, 2.5), 0.95)
			stw.tween_property(smat, "albedo_color:a", 0.0, 0.95)
			stw.chain().tween_callback(smoke.queue_free)
		
		# 5. Flying Shrapnel Sparks
		for i in 14:
			var spark := MeshInstance3D.new()
			var spm := SphereMesh.new()
			spm.radius = 0.04
			spm.height = 0.08
			spark.mesh = spm
			var smat := StandardMaterial3D.new()
			smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			smat.albedo_color = Color(1.0, 0.85, 0.3, 0.95)
			spark.material_override = smat
			spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent_node.add_child(spark)
			spark.global_position = origin
			var dir := Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1)).normalized()
			var dist := randf_range(4.0, 8.5)
			var tw := get_tree().create_tween()
			tw.tween_property(spark, "global_position", origin + dir * dist, 0.5)
			tw.chain().tween_callback(spark.queue_free)
			
		# Animate fireball, shockwave, and flash light decay
		var tw2 := get_tree().create_tween()
		tw2.tween_property(burst, "scale", Vector3(2.6, 2.6, 2.6), 0.28)
		tw2.set_parallel(true)
		tw2.tween_property(m, "albedo_color", Color(0.18, 0.12, 0.10, 0.0), 0.28)
		tw2.tween_property(ring, "scale", Vector3(4.5, 1.0, 4.5), 0.35)
		tw2.tween_property(rmat, "albedo_color:a", 0.0, 0.35)
		tw2.tween_property(light, "light_energy", 0.0, 0.32)
		tw2.chain().tween_callback(burst.queue_free)
		tw2.tween_callback(ring.queue_free)
		tw2.tween_callback(light.queue_free)
		
		# 6. Apply Screen Shake Trauma to Local Player based on blast proximity
		var local_player: Node3D = parent_node.get_node_or_null("Player") as Node3D
		if is_instance_valid(local_player) and local_player.has_method("apply_grenade_shake"):
			var dist_to_player: float = local_player.global_position.distance_to(origin)
			if dist_to_player < 26.0:
				var trauma: float = (1.0 - (dist_to_player / 26.0)) * 0.65
				local_player.apply_grenade_shake(trauma)
				if local_player.has_method("apply_recoil"):
					local_player.apply_recoil(randf_range(-0.06, 0.06) * trauma, randf_range(-0.06, 0.06) * trauma)
		
	if not GameState.practice_mode:
		queue_free()
		return
	# 7. Radial Blast Physics to RigidBodies and Characters
	var params := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = blast_radius
	params.shape = sphere
	params.transform = Transform3D(Basis(), origin)
	params.collision_mask = 0xFFFFFFFF
	var space := get_world_3d().direct_space_state
	var hits := space.intersect_shape(params, 32)
	
	var damaged_nodes: Array[Node] = []
	for h in hits:
		var c: Object = h.get("collider")
		if c == self or c == null:
			continue
		if c is RigidBody3D:
			var rb := c as RigidBody3D
			var d: Vector3 = rb.global_position - origin
			var dist := d.length()
			if dist >= 0.01:
				var mult := 1.0 - dist / blast_radius
				rb.apply_central_impulse(d.normalized() * 40.0 * mult * rb.mass * 0.5 + Vector3.UP * 6.0 * mult)
				
		var target_node: Node = null
		if c.has_method("take_explosion"):
			target_node = c as Node
		elif c is Area3D and (c as Node).get_parent() and (c as Node).get_parent().has_method("take_explosion"):
			target_node = (c as Node).get_parent()
		if target_node and is_instance_valid(target_node) and not damaged_nodes.has(target_node):
			damaged_nodes.append(target_node)
			var dd: float = (target_node as Node3D).global_position.distance_to(origin)
			if dd <= blast_radius:
				target_node.take_explosion(blast_damage * (1.0 - dd / blast_radius))
				
	queue_free()
