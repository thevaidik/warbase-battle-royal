class_name ColyseusVehiclePrediction
extends RefCounted
## Game simulation callback for Colyseus Predict.sim. The SDK owns history,
## authoritative adoption, input replay and correction smoothing.
const Geometry := preload("res://scripts/net/ColyseusWorldGeometry.gd")
const CHASSIS := [Vector3.ZERO, Vector3(-1.1, 0, -2.4), Vector3(1.1, 0, -2.4), Vector3(-1.1, 0, 2.4), Vector3(1.1, 0, 2.4)]
const RAYS := [Vector3(0, 0.9, 0), Vector3(-0.25, 0.9, 0), Vector3(0.25, 0.9, 0), Vector3(0, 0.9, -0.25), Vector3(0, 0.9, 0.25)]
static var _ray_cache_limit := 8192
static var _ray_cache_map := ""
static var _ray_cache: Dictionary = {}
static var _ray_cache_size := 0
static var _ray_cache_enabled := true
static var _ray_cache_hits := 0
static var _ray_cache_misses := 0

## Prediction replays often issue identical map queries. Cache the exact
## nearest-hit dictionary by exact endpoints; never quantize collision input.
static func set_ray_cache_enabled(enabled: bool) -> void:
	_ray_cache_enabled = enabled

static func set_ray_cache_limit(limit: int) -> void:
	_ray_cache_limit = maxi(1, limit)
	_ray_cache.clear()
	_ray_cache_size = 0

static func clear_ray_cache() -> void:
	_ray_cache.clear()
	_ray_cache_size = 0
	_ray_cache_map = Geometry.get_loaded_map()
	_ray_cache_hits = 0
	_ray_cache_misses = 0

static func ray_cache_stats() -> Dictionary:
	return {"hits": _ray_cache_hits, "misses": _ray_cache_misses, "size": _ray_cache_size}

static func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	if not _ray_cache_enabled:
		_ray_cache_misses += 1
		return Geometry._raycast(from, to)
	var map_name := Geometry.get_loaded_map()
	if map_name != _ray_cache_map:
		_ray_cache.clear()
		_ray_cache_size = 0
		_ray_cache_map = map_name
	var by_to: Dictionary = _ray_cache.get(from, {})
	if by_to.has(to):
		_ray_cache_hits += 1
		return by_to[to]
	_ray_cache_misses += 1
	var hit: Dictionary = Geometry._raycast(from, to)
	if _ray_cache_size >= _ray_cache_limit:
		_ray_cache.clear()
		_ray_cache_size = 0
		by_to = {}
	by_to[to] = hit
	_ray_cache[from] = by_to
	_ray_cache_size += 1
	return hit

static func ground_at(at: Vector3) -> Variant:
	var from := at + Vector3.UP * 2.5
	var to := at - Vector3.UP * 5.0
	var hit: Dictionary = _raycast(from, to)
	if hit.is_empty() or absf(Vector3(hit.normal).y) < 0.65: return null
	return from.y + (to.y - from.y) * float(hit.fraction) + 0.08

static func _blocked(from: Vector3, to: Vector3) -> bool:
	for offset: Vector3 in RAYS:
		var hit: Dictionary = _raycast(from + offset, to + offset)
		if not hit.is_empty() and float(hit.fraction) > 0.0001: return true
	return false

static func _inside_car(other: Variant, point: Vector3) -> bool:
	var c := cos(float(other.yaw))
	var s := sin(float(other.yaw))
	var dx := point.x - float(other.x)
	var dz := point.z - float(other.z)
	var local := Vector3(c * dx - s * dz, point.y - float(other.y), s * dx + c * dz)
	return local.x >= -1.2 and local.x <= 1.2 and local.y >= 0.15 and local.y <= 2.5 and local.z >= -2.6 and local.z <= 2.6

static func step(world: Variant, command: Variant, dt: float, car_names: Array[String]) -> void:
	var player: Variant = world.get("player")
	var id := "CAR_%d" % int(player.vehicle_index)
	if not car_names.has(id): return
	var car: Variant = world.get(id)
	if car == null or float(car.health) <= 0.0: return
	var valid_seat := int(command.vehicle_index) == int(player.vehicle_index) and int(command.vehicle_generation) == int(player.vehicle_generation) and int(player.vehicle_generation) == int(car.driver_generation)
	var throttle := clampf(float(command.vehicle_throttle), -1.0, 1.0) if valid_seat else 0.0
	var steer := clampf(float(command.vehicle_steer), -1.0, 1.0) if valid_seat else 0.0
	var brake := float(command.vehicle_brake) > 0.5 if valid_seat else true
	if valid_seat: car.gear = 2.0 if float(command.vehicle_gear) == 2.0 else 1.0
	var elapsed := clampf(dt, 0.0, 0.1)
	var speed := float(car.speed)
	var acceleration := throttle * 9.0 - speed * 0.24
	if brake: acceleration -= speed * 6.0
	speed = clampf(speed + acceleration * elapsed, -6.0, 22.0 if int(car.gear) == 2 else 14.4)
	if absf(speed) < 0.05 and throttle == 0.0: speed = 0.0
	var yaw := float(car.yaw) - steer * speed / 5.0 * elapsed
	var from := Vector3(car.x, car.y, car.z)
	var to := from + Vector3(-sin(yaw), 0, -cos(yaw)) * speed * elapsed
	var blocked := false
	for offset: Vector3 in CHASSIS:
		var rotated := Vector3(cos(yaw) * offset.x + sin(yaw) * offset.z, 0, -sin(yaw) * offset.x + cos(yaw) * offset.z)
		var a := from + rotated
		var b := to + rotated
		for other_id in car_names:
			if other_id != id and _inside_car(world.get(other_id), b + Vector3.UP * 0.9):
				blocked = true
				break
		if blocked or _blocked(a, b):
			blocked = true
			break
	var ground: Variant = ground_at(to)
	if not blocked and ground != null and absf(float(ground) - from.y) < 0.6:
		car.x = to.x
		car.y = float(ground)
		car.z = to.z
		car.yaw = yaw
		car.speed = speed
	else:
		car.speed = 0.0
	player.x = car.x
	player.y = car.y
	player.z = car.z
	player.vx = -sin(float(car.yaw)) * float(car.speed)
	player.vy = 0.0
	player.vz = -cos(float(car.yaw)) * float(car.speed)
