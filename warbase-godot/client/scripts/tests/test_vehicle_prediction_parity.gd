extends Node
const Prediction := preload("res://scripts/net/ColyseusVehiclePrediction.gd")
const Geometry := preload("res://scripts/net/ColyseusWorldGeometry.gd")

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/vehicle-prediction-fixtures.json"))
	var failures := 0
	var samples := 0
	for map_data: Dictionary in fixture.maps:
		Geometry.set_map_override(String(map_data.map))
		if map_data.steps.is_empty(): continue
		var traces: Array = [{"steps": map_data.steps}]
		if map_data.has("collision_case"): traces.append(map_data.collision_case)
		for trace: Dictionary in traces:
			var world := {"player": {"vehicle_index": int(map_data.driver.vehicle_index), "vehicle_generation": int(map_data.driver.vehicle_generation), "x": 0.0, "y": 0.0, "z": 0.0, "vx": 0.0, "vy": 0.0, "vz": 0.0}}
			var names: Array[String] = []
			for initial: Dictionary in map_data.initialVehicles:
				names.append(String(initial.id))
				world[String(initial.id)] = initial.duplicate(true)
			var car: Dictionary = world["CAR_%d" % int(map_data.driver.vehicle_index)]
			car.driver_generation = map_data.driver.vehicle_generation
			if trace.has("start"):
				car.x = trace.start[0]
				car.y = trace.start[1]
				car.z = trace.start[2]
				car.yaw = trace.yaw
			for expected: Dictionary in trace.steps:
				var command := {"vehicle_throttle": expected.throttle, "vehicle_steer": expected.steer, "vehicle_brake": 1.0 if expected.brake else 0.0, "vehicle_gear": expected.gear, "vehicle_index": map_data.driver.vehicle_index, "vehicle_generation": map_data.driver.vehicle_generation}
				Prediction.step(world, command, 1.0 / 60.0, names)
				samples += 1
				var error := Vector3(car.x, car.y, car.z).distance_to(Vector3(expected.x, expected.y, expected.z))
				if error > float(fixture.tolerances.position_metres) or absf(float(car.yaw) - float(expected.yaw)) > float(fixture.tolerances.yaw_radians) or absf(float(car.speed) - float(expected.speed)) > float(fixture.tolerances.speed_metres_per_second):
					push_error("Vehicle callback mismatch %s tick=%d position_error=%f speed=%f expected=%f" % [map_data.map, expected.tick, error, car.speed, expected.speed])
					failures += 1
					break
	Geometry.set_map_override("")
	print("VEHICLE_PREDICTION_PARITY samples=%d failures=%d" % [samples, failures])
	get_tree().quit(1 if failures else 0)
