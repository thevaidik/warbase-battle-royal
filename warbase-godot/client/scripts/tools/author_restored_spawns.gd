extends SceneTree
## Offline authoring using Godot's ray/shape queries; runtime reads fixed spawns.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/restored-map-authoring.json"))
	var builder_script = load("res://scripts/maps/MapBuilder.gd")
	for id in metadata:
		var container := Node3D.new();root.add_child(container)
		var scene: Node3D = load("res://assets/maps/restored/"+id+".scn").instantiate();container.add_child(scene)
		var helper = builder_script.new();helper._add_trimesh_collision(scene,true)
		for shape in scene.find_children("*","CollisionShape3D",true,false):
			if shape.shape is ConcavePolygonShape3D: shape.shape.backface_collision=true
		await physics_frame;await physics_frame
		var box: Array=metadata[id].bounds
		var cells := {};var step_size:=3.0
		var space:=root.get_world_3d().direct_space_state
		var capsule:=CapsuleShape3D.new();capsule.radius=0.4;capsule.height=1.8
		for ix in range(ceili((float(box[0])+1.0)/step_size),floori((float(box[0])+float(box[3])-1.0)/step_size)+1):
			for iz in range(ceili((float(box[2])+1.0)/step_size),floori((float(box[2])+float(box[5])-1.0)/step_size)+1):
				var x:=ix*step_size;var z:=iz*step_size
				var ray:=PhysicsRayQueryParameters3D.create(Vector3(x,float(box[4])+5,z),Vector3(x,-1,z),1)
				var hit:=space.intersect_ray(ray)
				if hit.is_empty() or absf(hit.normal.y)<0.7:continue
				var point: Vector3=hit.position+Vector3.UP*0.06
				var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform.origin=point+Vector3.UP*0.9;query.collision_mask=1
				if not space.intersect_shape(query).is_empty():continue
				var exits:=0
				for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
					query.motion=direction*0.6
					if space.cast_motion(query)[0]>0.99:exits+=1
				if exits>=3:cells[Vector2i(ix,iz)]=point
		var remaining:=cells.duplicate();var largest:Array=[]
		while not remaining.is_empty():
			var first:Vector2i=remaining.keys()[0];var queue:Array=[first];remaining.erase(first);var component:Array=[];var index:=0
			while index<queue.size():
				var key:Vector2i=queue[index];index+=1;component.append(cells[key])
				for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
					var next:Vector2i=key+offset
					if remaining.has(next) and absf(cells[key].y-cells[next].y)<=1.0:remaining.erase(next);queue.append(next)
			if component.size()>largest.size():largest=component
		assert(largest.size()>=12,"Insufficient connected safe ground: "+id)
		# Farthest-point distribution within the connected component.
		var selected:Array=[]
		largest.sort_custom(func(a:Vector3,b:Vector3)->bool:return a.length_squared()<b.length_squared())
		selected.append(largest[0])
		while selected.size()<12:
			var best:Vector3=largest[0];var best_distance:=-1.0
			for candidate:Vector3 in largest:
				var distance:=INF
				for chosen:Vector3 in selected:distance=minf(distance,candidate.distance_squared_to(chosen))
				if distance>best_distance:best_distance=distance;best=candidate
			selected.append(best)
		metadata[id].spawns=[]
		for point:Vector3 in selected:metadata[id].spawns.append([point.x,point.y,point.z])
		metadata[id].connected_ground_samples=largest.size()
		print("RESTORED_SPAWNS ",id," samples=",largest.size()," spawns=",selected.size())
		helper.free();container.free();await physics_frame
	var file:=FileAccess.open("res://assets/data/restored-map-authoring.json",FileAccess.WRITE);file.store_string(JSON.stringify(metadata,"  "))
	quit()
