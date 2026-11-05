extends Node
const Prediction := preload("res://scripts/net/ColyseusVehiclePrediction.gd")
const Geometry := preload("res://scripts/net/ColyseusWorldGeometry.gd")

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/vehicle-prediction-fixtures.json"))
	var outputs: Array[Array] = []
	var elapsed_us: Array[int] = []
	var suite_failures: Array[int] = []
	var suite_samples: Array[int] = []
	for cache_limit in [0, 512, 4096, 8192]:
		var enabled: bool = cache_limit > 0
		Prediction.set_ray_cache_enabled(enabled)
		if enabled: Prediction.set_ray_cache_limit(cache_limit)
		Prediction.clear_ray_cache()
		var failures := 0
		var samples := 0
		var output: Array = []
		var started := Time.get_ticks_usec()
		for map_data: Dictionary in fixture.maps:
			Geometry.set_map_override(String(map_data.map))
			if map_data.steps.is_empty(): continue
			for replay_round in 2:
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
						output.append([car.x, car.y, car.z, car.yaw, car.speed])
						var error := Vector3(car.x, car.y, car.z).distance_to(Vector3(expected.x, expected.y, expected.z))
						if error > float(fixture.tolerances.position_metres) or absf(float(car.yaw) - float(expected.yaw)) > float(fixture.tolerances.yaw_radians) or absf(float(car.speed) - float(expected.speed)) > float(fixture.tolerances.speed_metres_per_second):
							push_error("Vehicle callback mismatch cache_limit=%d %s replay=%d tick=%d position_error=%f speed=%f expected=%f" % [cache_limit, map_data.map, replay_round, expected.tick, error, car.speed, expected.speed])
							failures += 1
							break
		elapsed_us.append(Time.get_ticks_usec() - started)
		suite_failures.append(failures)
		suite_samples.append(samples)
		outputs.append(output)
		print("VEHICLE_RAY_CACHE limit=%d elapsed_us=%d stats=%s" % [cache_limit, elapsed_us.back(), Prediction.ray_cache_stats()])
	for index in range(1, outputs.size()):
		if outputs[0] != outputs[index]:
			push_error("Vehicle fixture traces differ for cache limit %d" % [ [0, 512, 4096, 8192][index] ])
			suite_failures[index] += 1
	var failures := 0
	for count in suite_failures: failures += count
	Prediction.set_ray_cache_limit(8192)
	Prediction.clear_ray_cache()
	Geometry.set_map_override("industrial")
	Prediction.ground_at(Vector3(0.0, 0.0, 0.0))
	if int(Prediction.ray_cache_stats().size) != 1:
		push_error("Vehicle ray cache did not record the first map query")
		failures += 1
	Geometry.set_map_override("village")
	Prediction.ground_at(Vector3(0.0, 0.0, 0.0))
	if int(Prediction.ray_cache_stats().size) != 1:
		push_error("Vehicle ray cache retained queries after changing maps")
		failures += 1
	Geometry.set_map_override("industrial")
	Prediction.ground_at(Vector3(0.0, 0.0, 0.0))
	if int(Prediction.ray_cache_stats().size) != 1:
		push_error("Vehicle ray cache did not invalidate when returning to a previous map")
		failures += 1
	Prediction.set_ray_cache_limit(2)
	Prediction.clear_ray_cache()
	for index in range(3):
		Prediction.ground_at(Vector3(float(index), 0.0, 0.0))
	if int(Prediction.ray_cache_stats().size) > 2:
		push_error("Vehicle ray cache exceeded its configured entry limit")
		failures += 1
	Geometry.set_map_override("")
	Prediction.set_ray_cache_enabled(true)
	Prediction.set_ray_cache_limit(8192)
	Prediction.clear_ray_cache()
	print("VEHICLE_PREDICTION_PARITY samples=%d timings_us=%s failures=%d" % [suite_samples[0], elapsed_us, failures])
	get_tree().quit(1 if failures else 0)
