class_name WarGrenadeBallistics
extends RefCounted
## Same constants and swept flight model as server/internal/engine/grenade.go.
const GRAVITY := 9.81
const AIR_DRAG := 0.035
const RADIUS := 0.06
const RESTITUTION := 0.35
const TANGENT_RETENTION := 0.70
const GROUND_FRICTION := 10.0
const STEP := 1.0 / 120.0
const OFFSETS := [Vector3.ZERO, Vector3.RIGHT * RADIUS, Vector3.LEFT * RADIUS, Vector3.UP * RADIUS, Vector3.DOWN * RADIUS, Vector3.FORWARD * RADIUS, Vector3.BACK * RADIUS]

static func launch_velocity(direction: Vector3, movement: Vector3) -> Vector3:
	var dir := direction.normalized()
	var loft := 6.0 * clampf(1.0 - absf(dir.y), 0.0, 1.0)
	return (dir * 20.0 + Vector3.UP * loft + movement * 0.45).limit_length(29.0)

static func sweep(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var closest := 2.0
	var normal := Vector3.ZERO
	var motion := to - from
	var length_sq := motion.length_squared()
	if length_sq < 0.000000001: return {}
	for offset in OFFSETS:
		var ray := PhysicsRayQueryParameters3D.create(from + offset, to + offset, 1)
		ray.hit_back_faces = true
		var hit := space.intersect_ray(ray)
		if hit.is_empty(): continue
		var fraction: float = (Vector3(hit.position) - from - offset).dot(motion) / length_sq
		if fraction < closest:
			closest = maxf(0.0, fraction)
			normal = hit.normal
	if closest > 1.0: return {}
	if motion.dot(normal) > 0.0: normal = -normal
	return {"fraction":closest, "normal":normal}

static func step(space: PhysicsDirectSpaceState3D, at: Vector3, velocity: Vector3, dt: float, stop_on_contact: bool = false) -> Dictionary:
	velocity.y -= GRAVITY * dt * 0.5
	velocity *= maxf(0.0, 1.0 - AIR_DRAG * dt)
	var remaining := dt
	var contacted := false
	var impact_speed := 0.0
	for bounce in 4:
		var end := at + velocity * remaining
		var hit := sweep(space, at, end)
		if hit.is_empty():
			at = end
			break
		contacted = true
		var normal: Vector3 = hit.normal
		at = at.lerp(end, hit.fraction) + normal * 0.002
		var incoming := velocity.dot(normal)
		impact_speed = maxf(impact_speed, -incoming)
		if stop_on_contact:
			return {"position":at, "velocity":Vector3.ZERO, "contact":true, "impact_speed":impact_speed}
		var tangent := velocity - normal * incoming
		if -incoming > 1.5:
			velocity = tangent * TANGENT_RETENTION - normal * incoming * RESTITUTION
		else:
			velocity = tangent
		remaining *= 1.0 - float(hit.fraction)
		if remaining < 0.00001: break
	velocity.y -= GRAVITY * dt * 0.5
	# Resolve resting support every step: contact gaps must not disable friction.
	if absf(velocity.y) < 1.0:
		var support := sweep(space, at, at + Vector3.DOWN * 0.025)
		if not support.is_empty() and Vector3(support.normal).y > 0.65:
			var normal: Vector3 = support.normal
			at += Vector3.DOWN * 0.025 * float(support.fraction) + normal * 0.002
			velocity = (velocity - normal * velocity.dot(normal)).move_toward(Vector3.ZERO, GROUND_FRICTION * dt)
			contacted = true
	return {"position":at, "velocity":velocity, "contact":contacted, "impact_speed":impact_speed}
