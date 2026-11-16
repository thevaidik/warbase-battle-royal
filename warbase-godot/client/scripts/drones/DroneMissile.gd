extends Node3D
## Visual flight follows the server launch event. Practice mode resolves hits locally.

const Payloads := preload("res://scripts/drones/DronePayloadBuilder.gd")

var velocity := Vector3.ZERO
var remaining := 0.0
var _trail_distance := 0.0
var shooter: CharacterBody3D
var damage := 0.0
var target_node: Node3D = null

static func launch(parent: Node3D, weapon: String, origin: Vector3, direction: Vector3, speed: float, duration: float, offline_shooter: CharacterBody3D = null, offline_damage: float = 0.0, target: Node3D = null) -> Node3D:
	var missile := new()
	missile.velocity = direction.normalized() * speed
	missile.remaining = duration
	missile.shooter = offline_shooter
	missile.damage = offline_damage
	missile.target_node = target
	missile.add_child(Payloads.missile_body(weapon))
	parent.add_child(missile)
	missile.global_position = origin
	var up := Vector3.RIGHT if absf(direction.normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP
	missile.look_at(origin + direction, up)
	return missile

func _physics_process(delta: float) -> void:
	# Active proportional navigation / pursuit guidance toward locked target
	if is_instance_valid(target_node) and remaining > 0.0:
		var target_pos := target_node.global_position + Vector3.UP * 0.35
		var to_target := (target_pos - global_position).normalized()
		var speed := velocity.length()
		var turn_rate := 5.2 # rad/sec
		var cur_dir := velocity.normalized()
		var new_dir := cur_dir.slerp(to_target, minf(1.0, turn_rate * delta)).normalized()
		velocity = new_dir * speed
		var up := Vector3.RIGHT if absf(new_dir.dot(Vector3.UP)) > 0.95 else Vector3.UP
		look_at(global_position + velocity, up)
		
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
	var travel := global_position.distance_to(destination)
	var effects := get_tree().get_first_node_in_group("drone_combat_effects")
	var sample_distance := 0.6 - _trail_distance
	var emitted := 0
	while sample_distance <= travel and emitted < 12:
		if effects: effects.call("missile_trail", global_position.lerp(destination, sample_distance / maxf(travel, 0.0001)))
		sample_distance += 0.6
		emitted += 1
	_trail_distance = fmod(_trail_distance + travel, 0.6)
	global_position = destination
	remaining -= elapsed
	if remaining <= 0.0:
		if is_instance_valid(shooter):
			burst(get_parent(), global_position)
		queue_free()

static func burst(parent: Node3D, at: Vector3) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree(): return
	var effects := parent.get_tree().get_first_node_in_group("drone_combat_effects")
	if effects: effects.call("missile_explosion", at)
