extends SceneTree
class Vehicle extends Node3D:
	var is_driven := true
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if not value: failures += 1
	print("CHECK ","PASS " if value else "FAIL ",label)
func run() -> void:
	var vehicle := Vehicle.new();root.add_child(vehicle)
	vehicle.position = Vector3(3,2,4)
	var body := Node3D.new();vehicle.add_child(body)
	var camera := Camera3D.new();vehicle.add_child(camera)
	var response = load("res://scripts/vehicles/VehicleImpactResponse.gd").new()
	vehicle.add_child(response);response.setup(vehicle,body,camera);response.set_process(false)
	var authoritative_pose := vehicle.transform
	response.kick(Vector3.FORWARD,12.0)
	response._process(1.0/60.0)
	check(body.rotation.length() > 0.001 and camera.rotation.length() > 0.001,"real collision produces body and driver camera impulse")
	for _frame in 20: response._process(1.0/30.0)
	check(body.rotation.length() < 0.05 and camera.rotation.length() < 0.05,"impact reaction remains bounded")
	check(vehicle.transform == authoritative_pose,"visual impact never changes authoritative chassis pose")
	for _frame in 240: response._process(1.0/60.0)
	check(body.rotation.length()<0.0001 and camera.rotation.length()<0.0001,"damped response settles without perpetual shaking")
	response.kick(Vector3.FORWARD,0.4);response._process(1.0/60.0)
	check(body.rotation.length()<0.0001,"low speed wall pressure cannot repeatedly shake camera")
	vehicle.is_driven=false;response.kick(Vector3.RIGHT,15.0);response._process(1.0/60.0)
	check(camera.rotation.length()<0.0001,"spectator vehicle impacts do not kick inactive driver camera")
	vehicle.free()
	print("VEHICLE_IMPACT_RESPONSE failures=",failures)
	quit(failures)
