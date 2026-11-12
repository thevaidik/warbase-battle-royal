extends Node
## Presentation of an authoritative collision impulse. Never moves the chassis,
## changes prediction state, or creates client-side vehicle authority.
var _vehicle: Node3D
var _body: Node3D
var _camera: Camera3D
var _body_rest := Vector3.ZERO
var _camera_rest := Vector3.ZERO
var _angle := Vector2.ZERO
var _velocity := Vector2.ZERO

func setup(vehicle: Node3D, body: Node3D, camera: Camera3D) -> void:
	_vehicle = vehicle
	_body = body
	_camera = camera
	if is_instance_valid(_body): _body_rest = _body.rotation
	if is_instance_valid(_camera): _camera_rest = _camera.rotation

func kick(normal: Vector3, closing_speed: float) -> void:
	if not is_instance_valid(_vehicle) or not normal.is_finite() or not is_finite(closing_speed) or closing_speed < 2.0: return
	var local := _vehicle.global_basis.orthonormalized().inverse() * normal.normalized()
	var strength := clampf(closing_speed * 0.035, 0.07, 0.5)
	_velocity += Vector2(local.z, -local.x) * strength
	_velocity = _velocity.limit_length(0.7)

func _process(delta: float) -> void:
	if not is_instance_valid(_vehicle): return
	var elapsed := clampf(delta, 0.0, 0.1)
	var steps := maxi(1, ceili(elapsed * 120.0))
	var dt := elapsed / steps
	for _step in steps:
		_velocity += (-95.0 * _angle - 18.0 * _velocity) * dt
		_angle += _velocity * dt
		_angle.x = clampf(_angle.x, -0.05, 0.05)
		_angle.y = clampf(_angle.y, -0.05, 0.05)
	if is_instance_valid(_body): _body.rotation = _body_rest + Vector3(_angle.x, 0, _angle.y)
	if is_instance_valid(_camera):
		_camera.rotation = _camera_rest + Vector3(_angle.x * 0.65, 0, _angle.y * 0.45) if bool(_vehicle.get("is_driven")) else _camera_rest
