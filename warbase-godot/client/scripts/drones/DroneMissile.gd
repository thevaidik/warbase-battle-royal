extends Node3D
## Visual flight follows the server launch event. Practice mode resolves hits locally.

const Payloads := preload("res://scripts/drones/DronePayloadBuilder.gd")

var velocity := Vector3.ZERO
var remaining := 0.0
var shooter: CharacterBody3D
var damage := 0.0

static func launch(parent: Node3D, weapon: String, origin: Vector3, direction: Vector3, speed: float, duration: float, offline_shooter: CharacterBody3D = null, offline_damage: float = 0.0) -> Node3D:
	var missile := new()
	missile.velocity = direction.normalized() * speed
	missile.remaining = duration
	missile.shooter = offline_shooter
	missile.damage = offline_damage
	missile.add_child(Payloads.missile_body(weapon))
	parent.add_child(missile)
	missile.global_position = origin
	var up := Vector3.RIGHT if absf(direction.normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP
	missile.look_at(origin + direction, up)
	return missile

func _physics_process(delta: float) -> void:
	var elapsed := minf(delta, remaining)
	var destination := global_position + velocity * elapsed
	if is_instance_valid(shooter):
		var query := PhysicsRayQueryParameters3D.create(global_position, destination, 5, [shooter.get_rid()])
		query.collide_with_areas = true
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var collider: Object = hit["collider"]
			var actor := (collider as Node).get_parent() if collider is Area3D and collider.has_meta("hitbox") else collider
			if actor is WarBot:
				actor.take_damage(damage, "torso", GameState.username, "missile")
			burst(get_parent(), hit["position"])
			queue_free()
			return
	global_position = destination
	remaining -= elapsed
	if remaining <= 0.0:
		if is_instance_valid(shooter):
			burst(get_parent(), global_position)
		queue_free()

static func burst(parent: Node3D, at: Vector3) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree(): return
	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	mesh.radial_segments = 12
	mesh.rings = 5
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.50, 0.13, 0.88)
	flash.mesh = mesh
	flash.material_override = material
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flash)
	flash.global_position = at
	var effect := flash.create_tween().set_parallel(true)
	effect.tween_property(flash, "scale", Vector3.ONE * 6.0, 0.22)
	effect.tween_property(material, "albedo_color:a", 0.0, 0.22)
	effect.chain().tween_callback(flash.queue_free)
