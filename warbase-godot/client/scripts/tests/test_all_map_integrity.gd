extends SceneTree
## Authoring and release gate: scene collision, replicated geometry and spawn clearance.
const AUTHORING = preload("res://scripts/tools/export_server_maps.gd")
const SHARED_GEOMETRY = preload("res://scripts/net/ColyseusWorldGeometry.gd")
const DRONE_FLIGHT = preload("res://scripts/drones/DroneFlight.gd")
const MAPS := ["football","resoforge","industrial","village","arena","shipment","dust2","nuketown","canyon","military_base", "ghost_city"]
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); print("CHECK FAIL ",message)

func drone_command(frame: int) -> Dictionary:
	if frame < 45: return {"move_x":0.0,"move_y":0.0,"move_z":1.0,"yaw":0.37,"sprint":1.0 if frame >= 15 and frame < 30 else 0.0}
	if frame < 75: return {"move_x":0.0,"move_y":1.0,"move_z":0.0,"yaw":0.37,"sprint":0.0}
	if frame < 100: return {"move_x":1.0,"move_y":-1.0,"move_z":0.0,"yaw":0.37,"sprint":0.0}
	return {"move_x":0.0,"move_y":0.0,"move_z":0.0,"yaw":0.37,"sprint":0.0}

func run() -> void:
	var report := {"maps":[],"spawn_count":0,"failures":[],"dynamic_queries":0,"dynamic_overlap_failures":0,"dynamic_jump_requests":0,"dynamic_landings":0,"dynamic_first_failures":[],"drone_queries":0,"drone_overlap_failures":0,"drone_max_speed_error":0.0,"drone_max_altitude_error":0.0,"drone_first_failures":[]}
	var builder_script = load("res://scripts/maps/MapBuilder.gd")
	var downloader = load("res://scripts/maps/MapDownload.gd")
	check(not await downloader.ensure_loaded(root, "unsupported-map", Callable()), "unknown maps fail closed")
	var native_capsule := CapsuleShape3D.new()
	native_capsule.radius = 0.395
	native_capsule.height = 1.79
	var drone_sphere := SphereShape3D.new()
	drone_sphere.radius = 0.395
	check(ResourceLoader.exists("res://assets/drones/vanguard.glb"), "Vanguard drone model resource exists")
	check(ResourceLoader.exists("res://assets/drones/raider.glb"), "Raider drone model resource exists")
	var native_space := root.get_world_3d().direct_space_state
	for id in MAPS:
		var builder = builder_script.new();root.add_child(builder)
		var spawns: Array = builder.build(id)
		for jeep in get_nodes_in_group("combat_jeeps"): jeep.freeze = true
		await physics_frame
		await physics_frame
		var before := failures.size()
		check(not spawns.is_empty(),id+": authored spawns exist")
		check(ResourceLoader.exists("res://assets/ui/maps/"+id+".png"),id+": preview exists")
		var asset: String = builder_script.MAP_GLBS[id]
		if asset.ends_with("low_poly_industrial_zone.glb"):
			check(id == "industrial",id+": unexpected Industrial alias")
		for shape in builder.find_children("*","CollisionShape3D",true,false):
			if shape.disabled or not shape.get_parent() is StaticBody3D: continue
			if shape.get_parent().name == "SafetyFloor":
				check(shape.global_position.y < -10,id+": safety floor stays below play")
				continue
			var mesh = shape.get_parent()
			while mesh != null and not mesh is MeshInstance3D: mesh=mesh.get_parent()
			check(mesh != null and mesh.is_visible_in_tree(),id+": static collider has visible backing")
		var capsule := CapsuleShape3D.new();capsule.radius=0.4;capsule.height=1.8
		var space := root.get_world_3d().direct_space_state
		for i in spawns.size():
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=5;query.transform.origin=spawns[i]+Vector3.UP*0.9
			check(space.intersect_shape(query).is_empty(),id+": spawn %d intersects scenery or vehicle" % i)
			var exits := 0
			for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
				query.motion=direction*0.5
				var travel:=space.cast_motion(query)
				if travel.size()==2 and travel[0]>0.99:exits+=1
			check(exits>=2,id+": spawn %d has escape clearance" % i)
		SHARED_GEOMETRY.set_map_override(id)
		var dynamic_queries := 0
		var dynamic_overlap_failures := 0
		var dynamic_first_failures: Array[String] = []
		var dynamic_jump_requests := 0
		var dynamic_landings := 0
		var step_dt := 1.0 / 60.0
		var native_query := PhysicsShapeQueryParameters3D.new()
		native_query.shape = native_capsule
		native_query.collision_mask = 1
		for spawn_index in spawns.size():
			var position: Vector3 = spawns[spawn_index]
			var vertical_velocity := 0.0
			var jumped := false
			for frame in 150:
				if frame % 90 == 0 and absf(vertical_velocity) < 0.001 and SHARED_GEOMETRY.is_grounded(position):
					vertical_velocity = 6.2
					jumped = true
					dynamic_jump_requests += 1
				var walk_speed := 6.2 if frame < 75 else -6.2
				vertical_velocity -= 18.0 * step_dt
				var requested := position + Vector3(walk_speed * step_dt, vertical_velocity * step_dt, 0.0)
				var resolved: Vector3 = SHARED_GEOMETRY.resolve_move(position, requested)
				position = resolved
				if vertical_velocity < 0.0 and SHARED_GEOMETRY.is_grounded(position):
					if jumped:
						dynamic_landings += 1
						jumped = false
					vertical_velocity = 0.0
				elif vertical_velocity > 0.0 and resolved.y < requested.y - 0.001:
					vertical_velocity = 0.0
				if frame % 10 == 0 and position.y >= -10.0:
					dynamic_queries += 1
					native_query.transform.origin = position + Vector3.UP * 0.895
					var overlaps := native_space.intersect_shape(native_query, 4)
					if not overlaps.is_empty():
						dynamic_overlap_failures += 1
						if dynamic_first_failures.size() < 3:
							var collider_paths: Array[String] = []
							for overlap in overlaps:
								var collider: Object = overlap.get("collider")
								collider_paths.append(str(collider.get_path()) if collider is Node else str(collider))
							dynamic_first_failures.append("spawn=%d frame=%d feet=%s colliders=%s" % [spawn_index, frame, str(position), str(collider_paths)])
						if report.dynamic_first_failures.size() < 5:
							report.dynamic_first_failures.append("%s spawn=%d frame=%d feet=%s" % [id, spawn_index, frame, str(position)])
		check(dynamic_overlap_failures == 0, id+": native capsule overlaps=%d queries=%d first=%s" % [dynamic_overlap_failures, dynamic_queries, str(dynamic_first_failures)])
		report.dynamic_queries += dynamic_queries
		report.dynamic_overlap_failures += dynamic_overlap_failures
		report.dynamic_jump_requests += dynamic_jump_requests
		report.dynamic_landings += dynamic_landings
		var drone_queries := 0
		var drone_overlap_failures := 0
		var drone_speed_error := 0.0
		var drone_altitude_error := 0.0
		var drone_first_failures: Array[String] = []
		var drone_query := PhysicsShapeQueryParameters3D.new()
		drone_query.shape = drone_sphere
		drone_query.collision_mask = 1
		for spawn_index in spawns.size():
			var drone_position: Vector3 = spawns[spawn_index] + Vector3.UP * DRONE_FLIGHT.SPAWN_OFFSET
			var drone_velocity := Vector3.ZERO
			for frame in 120:
				var command := drone_command(frame)
				var result: Dictionary = DRONE_FLIGHT.step(drone_position, drone_velocity, command, step_dt)
				drone_position = result.position
				drone_velocity = result.velocity
				var speed_error := maxf(0.0, drone_velocity.length() - 14.0)
				var altitude_error := maxf(0.0, drone_position.y - 120.0)
				drone_speed_error = maxf(drone_speed_error, speed_error)
				drone_altitude_error = maxf(drone_altitude_error, altitude_error)
				check(speed_error <= 0.005, "%s spawn %d frame %d exceeds drone boost speed" % [id, spawn_index, frame])
				check(altitude_error <= 0.005, "%s spawn %d frame %d exceeds drone ceiling" % [id, spawn_index, frame])
				if (frame + 1) % 10 != 0: continue
				drone_queries += 1
				drone_query.transform.origin = drone_position
				var drone_overlaps := native_space.intersect_shape(drone_query, 4)
				if not drone_overlaps.is_empty():
					drone_overlap_failures += 1
					if drone_first_failures.size() < 3:
						var collider_paths: Array[String] = []
						for overlap in drone_overlaps:
							var collider: Object = overlap.get("collider")
							collider_paths.append(str(collider.get_path()) if collider is Node else str(collider))
						drone_first_failures.append("spawn=%d frame=%d center=%s colliders=%s" % [spawn_index, frame, str(drone_position), str(collider_paths)])
		check(drone_overlap_failures == 0, id+": native drone sphere overlaps=%d queries=%d first=%s" % [drone_overlap_failures, drone_queries, str(drone_first_failures)])
		report.drone_queries += drone_queries
		report.drone_overlap_failures += drone_overlap_failures
		report.drone_max_speed_error = maxf(report.drone_max_speed_error, drone_speed_error)
		report.drone_max_altitude_error = maxf(report.drone_max_altitude_error, drone_altitude_error)
		report.drone_first_failures.append_array(drone_first_failures.map(func(item: String) -> String: return id+" "+item))
		var file:=FileAccess.open("res://assets/data/maps/"+id+".json.gz",FileAccess.READ)
		check(file!=null,id+": prediction data exists")
		if file!=null:
			var payload=file.get_buffer(file.get_length()).decompress_dynamic(128*1024*1024,FileAccess.COMPRESSION_GZIP)
			var data: Variant=JSON.parse_string(payload.get_string_from_utf8())
			check(data is Dictionary,id+": valid prediction data")
			if data is Dictionary:
				check(data.get("name", "") == id, id+": geometry identity matches map")
				var triangles:=[];AUTHORING.collect(builder,triangles)
				check(PackedFloat32Array(triangles)==PackedFloat32Array(data.get("triangles",[])),id+": actual scene collision matches prediction data")
				check(spawns.size()==data.get("spawns",[]).size(),id+": spawn count matches prediction data")
				for i in mini(spawns.size(),data.get("spawns",[]).size()):
					var p: Array=data.spawns[i]
					check(spawns[i].distance_to(Vector3(p[0],p[1],p[2]))<0.0001,id+": authored spawn matches prediction data")
		report.maps.append({"map":id,"spawns":spawns.size(),"failures":failures.size()-before,"dynamic_queries":dynamic_queries,"dynamic_overlap_failures":dynamic_overlap_failures,"dynamic_jump_requests":dynamic_jump_requests,"dynamic_landings":dynamic_landings,"dynamic_first_failures":dynamic_first_failures,"drone_queries":drone_queries,"drone_overlap_failures":drone_overlap_failures,"drone_max_speed_error":drone_speed_error,"drone_max_altitude_error":drone_altitude_error,"drone_first_failures":drone_first_failures})
		report.spawn_count+=spawns.size()
		print("MAP_INTEGRITY ",id," failures=",failures.size()-before," dynamic_queries=",dynamic_queries," dynamic_overlaps=",dynamic_overlap_failures," dynamic_jumps=",dynamic_jump_requests," dynamic_landings=",dynamic_landings," drone_queries=",drone_queries," drone_overlaps=",drone_overlap_failures," drone_max_speed_error=",drone_speed_error," drone_max_altitude_error=",drone_altitude_error)
		builder.free();await physics_frame
	SHARED_GEOMETRY.set_map_override("")
	check(report.dynamic_jump_requests > 0, "dynamic capsule regression produced no grounded jump requests")
	check(report.dynamic_landings > 0, "dynamic capsule regression produced no jump landings")
	report.failures=failures
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("report="):
			var output:=FileAccess.open(arg.trim_prefix("report="),FileAccess.WRITE)
			if output: output.store_string(JSON.stringify(report))
	print("ALL_MAP_INTEGRITY_OK maps=",MAPS.size()," spawns=",report.spawn_count," drone_queries=",report.drone_queries," drone_overlaps=",report.drone_overlap_failures," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
