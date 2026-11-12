extends Node3D
## Match-local presentation. Wrecks and debris never enter combat collision or replication.

const MAX_WRECKS := 10
const SMOKE_LIMIT := 88
const DEBRIS_LIMIT := 48
const WRECK_LIFETIME := 4.8

class Particle:
	var node: MeshInstance3D
	var material: StandardMaterial3D
	var velocity := Vector3.ZERO
	var age := 0.0
	var life := 0.0
	var width := 0.0
	var tint := Color.WHITE

class Wreck:
	var model: Node3D
	var velocity := Vector3.ZERO
	var angular := Vector3.ZERO
	var age := 0.0
	var next_plume := 0.0
	var next_ember := 0.0
	var rest_height := 0.0
	var grounded := false

var _smoke: Array[Particle] = []
var _debris: Array[Particle] = []
var _wrecks: Array[Wreck] = []
var _smoke_cursor := 0
var _debris_cursor := 0
var _ray := PhysicsRayQueryParameters3D.new()
static var _smoke_texture: ImageTexture

func _ready() -> void:
	name = "DroneCombatEffects"
	add_to_group("drone_combat_effects")
	_ray.collision_mask = 1
	set_physics_process(false)
	var quad := QuadMesh.new()
	var fragment := BoxMesh.new()
	fragment.size = Vector3(0.036, 0.023, 0.075)
	for index in SMOKE_LIMIT:
		_smoke.append(_make_particle(quad, true))
	for index in DEBRIS_LIMIT:
		_debris.append(_make_particle(fragment, false))

func _make_particle(mesh: Mesh, is_smoke: bool) -> Particle:
	var particle := Particle.new()
	particle.node = MeshInstance3D.new()
	particle.node.mesh = mesh
	particle.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particle.node.hide()
	particle.material = StandardMaterial3D.new()
	particle.material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if is_smoke:
		particle.material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		particle.material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		particle.material.albedo_texture = _get_smoke_texture()
	particle.node.material_override = particle.material
	add_child(particle.node)
	return particle

static func _get_smoke_texture() -> ImageTexture:
	if _smoke_texture != null: return _smoke_texture
	var texture_size := 64
	var image := Image.create(texture_size, texture_size, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 4919
	noise.frequency = 0.115
	for y in texture_size:
		for x in texture_size:
			var uv := Vector2(x, y) / float(texture_size - 1) * 2.0 - Vector2.ONE
			var turbulence := noise.get_noise_2d(x, y)
			var rim := uv.length() + turbulence * 0.28
			var density := (1.0 - smoothstep(0.22, 0.91, rim)) * (0.69 + turbulence * 0.30)
			var shading := 0.78 - uv.y * 0.17 + turbulence * 0.16
			image.set_pixel(x, y, Color(shading, shading, shading, density))
	image.generate_mipmaps()
	_smoke_texture = ImageTexture.create_from_image(image)
	return _smoke_texture

func hit(position: Vector3, direction: Vector3, intensity: float) -> void:
	if not position.is_finite(): return
	var strength := clampf(intensity, 0.65, 2.0)
	var drift := -direction.normalized() if direction.is_finite() else Vector3.ZERO
	for index in (2 if strength < 1.25 else 3):
		var offset := Vector3(randf_range(-0.11, 0.11), randf_range(0.09, 0.24), randf_range(-0.11, 0.11))
		_emit_smoke(position + offset, drift * 0.42 + Vector3.UP * randf_range(0.32, 0.68),
			randf_range(0.68, 1.02), randf_range(0.32, 0.55) * sqrt(strength), Color(0.46, 0.43, 0.39, 0.85))
	set_physics_process(true)

func crash(source: Node3D, velocity: Vector3) -> Node3D:
	if not source.global_position.is_finite(): return null
	if _wrecks.size() >= MAX_WRECKS:
		_wrecks.pop_front().model.queue_free()
	var wreck := Wreck.new()
	wreck.model = source.call("make_wreck_visual", self) as Node3D
	wreck.model.global_transform = source.global_transform
	var forward := -source.global_basis.z.normalized()
	wreck.velocity = velocity.limit_length(16.0) + forward * 1.3 + Vector3.UP * 0.9
	var side := -1.0 if randf() < 0.5 else 1.0
	wreck.angular = Vector3(randf_range(-1.9, -0.9), side * 0.7, side * randf_range(2.1, 3.5))
	_wrecks.append(wreck)
	_burst(wreck.model.global_position, wreck.velocity * 0.2, false)
	set_physics_process(true)
	return wreck.model

func _burst(position: Vector3, drift: Vector3, ground_impact: bool) -> void:
	var tint := Color(0.32, 0.30, 0.28, 0.9) if ground_impact else Color(0.24, 0.22, 0.21, 0.96)
	_emit_smoke(position + Vector3.UP * 0.14, drift * 0.12, 0.24, 0.97, Color(1.0, 0.54, 0.17, 1.0))
	for index in 5:
		var velocity := Vector3(randf_range(-1.5, 1.5), randf_range(0.22, 1.28), randf_range(-1.5, 1.5))
		_emit_smoke(position + velocity * 0.12, velocity + drift * 0.18,
			randf_range(1.3, 2.0), randf_range(0.63, 1.02), tint)
	for index in (9 if ground_impact else 13):
		var direction := Vector3(randf_range(-1.0, 1.0), randf_range(0.12, 1.0), randf_range(-1.0, 1.0)).normalized()
		var debris := _debris[_debris_cursor]
		_debris_cursor = (_debris_cursor + 1) % _debris.size()
		var ember := Color(1.0, randf_range(0.45, 0.82), 0.16)
		_start(debris, position + direction * 0.17, direction * randf_range(1.8, 5.5) + drift,
			randf_range(0.36, 0.88), randf_range(0.54, 1.3), ember)
		debris.node.rotation = direction * TAU

func _emit_smoke(position: Vector3, velocity: Vector3, life: float, width: float, tint: Color) -> void:
	var smoke := _smoke[_smoke_cursor]
	_smoke_cursor = (_smoke_cursor + 1) % _smoke.size()
	_start(smoke, position, velocity, life, width, tint)

func _start(particle: Particle, position: Vector3, velocity: Vector3, life: float, width: float, tint: Color) -> void:
	particle.age = 0.0
	particle.life = life
	particle.width = width
	particle.velocity = velocity
	particle.tint = tint
	particle.node.global_position = position
	particle.node.scale = Vector3.ONE * width
	particle.material.albedo_color = tint
	particle.node.show()

func _physics_process(delta: float) -> void:
	for index in range(_wrecks.size() - 1, -1, -1):
		var wreck := _wrecks[index]
		wreck.age += delta
		if wreck.age >= WRECK_LIFETIME:
			wreck.model.queue_free()
			_wrecks.remove_at(index)
			continue
		_advance_wreck(wreck, delta)
	var active := _advance_particles(_smoke, delta, true)
	active = _advance_particles(_debris, delta, false) or active
	if _wrecks.is_empty() and not active: set_physics_process(false)

func _advance_wreck(wreck: Wreck, delta: float) -> void:
	var model := wreck.model
	if not wreck.grounded:
		wreck.velocity.y -= 11.0 * delta
		wreck.velocity *= exp(-0.58 * delta)
		var end := model.global_position + wreck.velocity * delta
		var travel := end - model.global_position
		_ray.from = model.global_position
		_ray.to = end + travel.normalized() * 0.25
		var contact := get_world_3d().direct_space_state.intersect_ray(_ray)
		if contact.is_empty():
			model.global_position = end
			model.rotation += wreck.angular * delta
		else:
			var normal: Vector3 = contact.normal
			model.global_position = Vector3(contact.position) + normal * 0.39
			_burst(Vector3(contact.position) + normal * 0.12, wreck.velocity * 0.28, true)
			wreck.grounded = normal.y > 0.55
			wreck.velocity = wreck.velocity.slide(normal) * 0.27 + normal * 0.8
			wreck.angular *= 0.28
			if wreck.grounded:
				wreck.rest_height = float(contact.position.y) + _ground_clearance(wreck)
	if wreck.grounded:
		model.rotation.x = lerp_angle(model.rotation.x, -0.24, delta * 5.0)
		model.rotation.z = lerp_angle(model.rotation.z, signf(wreck.angular.z) * 0.32, delta * 5.0)
		model.global_position.y = lerpf(model.global_position.y, wreck.rest_height, delta * 7.0)
		if wreck.age < 3.0 and wreck.age >= wreck.next_ember:
			wreck.next_ember = wreck.age + randf_range(0.17, 0.31)
			var outlet := model.to_global(Vector3(0.065, 0.07, 0.09))
			_emit_smoke(outlet, Vector3.UP * 0.72, 0.27, 0.28, Color(1.0, 0.46, 0.09, 0.94))
	if wreck.age < 3.35 and wreck.age >= wreck.next_plume:
		wreck.next_plume = wreck.age + (0.18 if wreck.grounded else 0.105)
		var drift := Vector3(randf_range(-0.23, 0.23), randf_range(0.55, 1.03), randf_range(-0.23, 0.23))
		_emit_smoke(model.global_position + Vector3.UP * 0.18, drift + wreck.velocity * (0.0 if wreck.grounded else 0.11),
			1.65, 0.60 if wreck.grounded else 0.48, Color(0.23, 0.22, 0.22, 0.82))

func _ground_clearance(wreck: Wreck) -> float:
	var model := wreck.model
	var rest_angles := Vector3(-0.24, model.rotation.y, signf(wreck.angular.z) * 0.32)
	var rest_basis := Basis.from_euler(rest_angles).scaled(model.scale)
	var rest := Transform3D(rest_basis, Vector3.ZERO) * model.global_transform.affine_inverse()
	var lowest := 0.0
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree(): continue
		var bounds: AABB = (rest * mesh.global_transform) * mesh.get_aabb()
		lowest = minf(lowest, bounds.position.y)
	return clampf(-lowest + 0.015, 0.10, 0.56)

func _advance_particles(pool: Array[Particle], delta: float, is_smoke: bool) -> bool:
	var active := false
	for particle in pool:
		if not particle.node.visible: continue
		particle.age += delta
		if particle.age >= particle.life:
			particle.node.hide()
			continue
		active = true
		var progress := particle.age / particle.life
		particle.node.global_position += particle.velocity * delta
		if is_smoke:
			particle.node.scale = Vector3.ONE * particle.width * (0.68 + 1.52 * progress)
			var tint := particle.tint
			tint.a *= (1.0 - smoothstep(0.1, 1.0, progress))
			particle.material.albedo_color = tint
		else:
			particle.velocity.y -= 8.0 * delta
			particle.node.rotation += Vector3(5.0, 7.0, 4.0) * delta
			particle.node.scale = Vector3.ONE * particle.width * (1.0 - 0.7 * progress)
			particle.material.albedo_color = particle.tint.lerp(Color("343031"), progress)
	return active
