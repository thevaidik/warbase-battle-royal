extends SceneTree

const Geometry = preload("res://scripts/net/ColyseusWorldGeometry.gd")
const Flight = preload("res://scripts/drones/DroneFlight.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Geometry.set_map_override("industrial")
	var floor: Variant = Geometry.floor_height(0.0,0.0,10.0)
	if floor == null:
		check(false,"industrial test point has ground support")
		quit(1); return
	var pos := Vector3(0.0,float(floor)+Flight.RADIUS,0.0)
	var tracked_velocity := Vector3.ZERO
	for _tick in range(60):
		var result: Dictionary = Flight.step(pos,tracked_velocity,{"move_x":0.0,"move_y":1.0,"move_z":1.0,"yaw":0.0,"sprint":0.0,"mobility_mode":"tracked"},1.0/60.0)
		pos=result.position;tracked_velocity=result.velocity
	check(absf(pos.y-(float(floor)+Flight.RADIUS))<0.02 and absf(tracked_velocity.y)<0.001,"tracked profile follows terrain with a .4m body support height")
	var wheels_pos := Vector3(0.0,float(floor)+Flight.RADIUS,0.0)
	var wheels_velocity := Vector3.ZERO
	for _tick in range(60):
		var result: Dictionary = Flight.step(wheels_pos,wheels_velocity,{"move_x":0.0,"move_y":1.0,"move_z":1.0,"yaw":0.0,"sprint":0.0,"mobility_mode":"wheels"},1.0/60.0)
		wheels_pos=result.position;wheels_velocity=result.velocity
	check(absf(wheels_pos.y-(float(floor)+Flight.RADIUS))<0.02 and absf(wheels_velocity.z)>absf(tracked_velocity.z),"wheeled profile stays grounded and moves faster than tracks")
	var wing_pos := Vector3(0.0,40.0,0.0)
	var wing_velocity := Vector3.ZERO
	for _tick in range(20):
		var result: Dictionary = Flight.step(wing_pos,wing_velocity,{"move_x":0.0,"move_y":1.0,"move_z":0.0,"yaw":0.0,"sprint":0.0,"mobility_mode":"wing"},1.0/60.0)
		wing_pos=result.position;wing_velocity=result.velocity
	check(wing_velocity.y<0.0,"wing profile falls before reaching forward airspeed")
	Geometry.set_map_override("")
	print("DRONE_MOBILITY_TEST failures=",failures)
	quit(failures)
