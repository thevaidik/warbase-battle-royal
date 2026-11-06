extends SceneTree
## Authoring and release gate: scene collision, replicated geometry and spawn clearance.
const AUTHORING = preload("res://scripts/tools/export_server_maps.gd")
const MAPS := ["football","resoforge","industrial","village","arena","shipment","dust2","nuketown","canyon","desert_oasis"]
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); print("CHECK FAIL ",message)
func run() -> void:
	var report := {"maps":[],"spawn_count":0,"failures":[]}
	var builder_script = load("res://scripts/maps/MapBuilder.gd")
	var downloader = load("res://scripts/maps/MapDownload.gd")
	check(not await downloader.ensure_loaded(root, "unsupported-map", Callable()), "unknown maps fail closed")
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
			check(id in ["industrial","dust2","nuketown"],id+": unexpected Industrial alias")
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
		report.maps.append({"map":id,"spawns":spawns.size(),"failures":failures.size()-before})
		report.spawn_count+=spawns.size()
		print("MAP_INTEGRITY ",id," failures=",failures.size()-before)
		builder.free();await physics_frame
	report.failures=failures
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("report="):
			var output:=FileAccess.open(arg.trim_prefix("report="),FileAccess.WRITE)
			if output: output.store_string(JSON.stringify(report))
	print("ALL_MAP_INTEGRITY_OK maps=10 spawns=",report.spawn_count," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
