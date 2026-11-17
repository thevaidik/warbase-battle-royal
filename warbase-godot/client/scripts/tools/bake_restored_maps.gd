extends SceneTree
## Offline static batching: retain materials/UVs while reducing tiny mesh nodes.
const SOURCES := {"dust2":["dust2",1.0],"military_base":["military_base",0.015],"canyon":["devils_canyon",3.0]}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/restored-map-authoring.json"))
	var selected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("map="): selected = arg.trim_prefix("map=")
	for id in SOURCES:
		if not selected.is_empty() and selected != id: continue
		var source: Node3D = load("res://assets/maps/"+SOURCES[id][0]+".glb").instantiate()
		root.add_child(source)
		source.scale *= float(SOURCES[id][1])
		var meshes: Array[Node] = source.find_children("*","MeshInstance3D",true,false)
		var bounds: AABB = meshes[0].global_transform * meshes[0].get_aabb()
		for mesh in meshes: bounds = bounds.merge(mesh.global_transform * mesh.get_aabb())
		var origin := Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
		var batches := {}
		for mesh in meshes:
			var transform: Transform3D = mesh.global_transform
			transform.origin -= origin
			var centre: Vector3 = transform * mesh.get_aabb().get_center()
			for surface in mesh.mesh.get_surface_count():
				var material: Material = mesh.get_active_material(surface)
				var key := "%d:%d:%d:%d" % [floori(centre.x/24.0),floori(centre.z/24.0),material.get_instance_id() if material else 0,mesh.mesh.surface_get_format(surface)]
				if not batches.has(key):
					var tool := SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.set_material(material)
					batches[key] = tool
				batches[key].append_from(mesh.mesh,surface,transform)
		var baked := Node3D.new();baked.name="RestoredMap"
		for key in batches:
			var mesh := MeshInstance3D.new();mesh.name="StaticBatch_%d" % baked.get_child_count()
			mesh.mesh=batches[key].commit();baked.add_child(mesh);mesh.owner=baked
		var packed := PackedScene.new();assert(packed.pack(baked)==OK)
		assert(ResourceSaver.save(packed,"res://assets/maps/restored/"+id+".scn")==OK)
		metadata[id]={"source":SOURCES[id][0],"source_sha256":FileAccess.get_sha256("res://assets/maps/"+SOURCES[id][0]+".glb"),"scale":SOURCES[id][1],"bounds":[-bounds.size.x/2,0,-bounds.size.z/2,bounds.size.x,bounds.size.y,bounds.size.z],"source_meshes":meshes.size(),"batches":baked.get_child_count()}
		if id=="nuketown":metadata[id].bounds=[-31.5,0.0,-21.5,63.0,bounds.size.y,43.0]
		print("RESTORED_BAKE ",id," source_meshes=",meshes.size()," batches=",baked.get_child_count()," bounds=",bounds.size)
		baked.free();source.free()
	var file:=FileAccess.open("res://assets/data/restored-map-authoring.json",FileAccess.WRITE);file.store_string(JSON.stringify(metadata,"  "))
	quit()
