extends RefCounted
const Geometry = preload("res://scripts/net/ColyseusWorldGeometry.gd")
const RADIUS := 0.4
const SPAWN_OFFSET := 0.9
const MAX_ALTITUDE := 120.0
const GRAVITY := 18.0
const GROUND_STEP_HEIGHT := 0.22
## Ordered to match DRONE_MOBILITY_MODES on the server.
const MOBILITY_MODES := ["quad", "wheels", "tracked", "heli", "wing"]

## Explicit climb keys override mouse flight. Otherwise pitch guides powered flight.
static func climb_input(mode: String, throttle: float, pitch: float) -> float:
	if mode in ["tracked", "wheels"]:
		return 0.0
	var manual := Input.get_axis("drone_down", "drone_up")
	if not is_zero_approx(manual) or (throttle <= 0.0 and mode != "wing"):
		return manual
	return clampf(pitch / deg_to_rad(18.0 if mode == "wing" else 28.0), -1.0, 1.0)

static func step(position: Vector3, velocity: Vector3, command: Variant, dt: float) -> Dictionary:
	var elapsed := clampf(dt,0.0,0.1)
	if not is_finite(elapsed) or elapsed==0.0 or not position.is_finite() or not velocity.is_finite(): return {"position":position,"velocity":Vector3.ZERO}
	var x := clampf(float(command.move_x),-1.0,1.0)
	var y := clampf(float(command.move_y),-1.0,1.0)
	var z := clampf(float(command.move_z),-1.0,1.0)
	var yaw := float(command.yaw)
	if not is_finite(x) or not is_finite(y) or not is_finite(z) or not is_finite(yaw): return {"position":position,"velocity":Vector3.ZERO}
	var mode := "quad"
	if command is Dictionary:
		mode = String(command.get("mobility_mode", "quad"))
	else:
		var mobility_index: Variant = command.get("mobility_index")
		if mobility_index != null and is_finite(float(mobility_index)):
			var index := int(mobility_index)
			if index >= 0 and index < MOBILITY_MODES.size() and float(index) == float(mobility_index):
				mode = MOBILITY_MODES[index]
	if mode not in MOBILITY_MODES: mode = "quad"
	if mode == "tracked": x = 0.0
	var ground := mode == "tracked" or mode == "wheels"
	var wing := mode == "wing"
	var magnitude := maxf(1.0,sqrt(x*x+z*z) if ground or wing else sqrt(x*x+y*y+z*z))
	var speed := 14.0 if float(command.sprint)>0.5 else 8.0
	var vertical := 9.0 if float(command.sprint)>0.5 else 6.0
	if ground: speed = 4.5 if mode == "tracked" else 6.0
	elif wing: speed = 17.0 if float(command.sprint)>0.5 else 11.0
	elif mode == "heli": vertical = 10.0 if float(command.sprint)>0.5 else 7.0
	if mode == "quad": vertical = 9.0 if float(command.sprint)>0.5 else 6.0
	var c := cos(yaw);var s := sin(yaw)
	var horizontal_target_x := (x*c-z*s)/magnitude*speed
	var horizontal_target_z := (-x*s-z*c)/magnitude*speed
	var target := Vector3(horizontal_target_x, 0.0 if ground else y / magnitude * vertical, horizontal_target_z)
	var response := 1.0-exp(-(12.0 if x==0.0 and y==0.0 and z==0.0 else (6.0 if ground else 9.0))*elapsed)
	var next := velocity.lerp(target,response)
	if mode == "tracked":
		var forward := Vector3(-s, 0.0, -c)
		var current_speed := velocity.dot(forward)
		var desired_speed := z * (2.4 if z < 0.0 else 4.5)
		var braking := is_zero_approx(z) or current_speed * desired_speed < 0.0
		var traction := 18.0 if braking else 9.0
		next = forward * move_toward(current_speed, desired_speed, traction * elapsed)
	if wing or mode == "heli":
		var forward := Vector3(-s, 0, -c)
		var right := Vector3(c, 0, -s)
		var forward_speed := velocity.dot(forward)
		var sideways_speed := velocity.dot(right)
		if wing:
			# Engine thrust, drag and lift act on the existing flight velocity.
			var throttle := maxf(0.0, z)
			var thrust := (16.0 if float(command.sprint) > 0.5 else 10.5) * throttle
			var drag := (0.065 + 0.045 * absf(y) + (0.16 if z < 0.0 else 0.0)) * absf(forward_speed) * forward_speed
			var lift_authority := clampf(pow(maxf(0.0, forward_speed) / 8.0, 2.0), 0.0, 1.0)
			var climb_target := y * 9.0 * lift_authority
			next = forward * (forward_speed + (thrust - drag) * elapsed)
			next += right * sideways_speed * exp(-1.8 * elapsed)
			var climb_response := 1.0 - exp(-4.0 * elapsed)
			next.y = clampf(lerpf(velocity.y, climb_target, climb_response) - GRAVITY * (1.0 - lift_authority) * elapsed, -15.0, 9.0)
		else:
			# Tilt generates lateral acceleration. Collective and hover assist control lift.
			var tilt := Vector2(x, maxf(0.0, z)).limit_length()
			var thrust := 16.0 if float(command.sprint) > 0.5 else 12.0
			var horizontal_drag := 2.8 if tilt.is_zero_approx() else 1.4
			var retention := exp(-horizontal_drag * elapsed)
			next = Vector3(velocity.x, 0, velocity.z) * retention
			next += (right * tilt.x + forward * tilt.y) * thrust * elapsed
			var climb_target := y * vertical
			if z < 0.0 and is_zero_approx(y):
				climb_target = z * 2.5
			next.y = move_toward(velocity.y, climb_target, 15.0 * elapsed)
	if ground: next.y = velocity.y-GRAVITY*elapsed
	var requested := position+next*elapsed
	requested.y=minf(MAX_ALTITUDE,requested.y)
	var resolved := Geometry.resolve_flight_move(position, requested, RADIUS, GROUND_STEP_HEIGHT if ground else 0.0)
	var actual := (resolved-position)/elapsed
	for axis in 3:
		if absf(resolved[axis]-requested[axis])<=0.0006: actual[axis]=next[axis]
		if absf(actual[axis])<0.025 or (axis==1 and next.y>0.0 and requested.y==MAX_ALTITUDE): actual[axis]=0.0
	if ground: actual.y = minf(0.0, actual.y)
	return {"position":resolved,"velocity":actual}
