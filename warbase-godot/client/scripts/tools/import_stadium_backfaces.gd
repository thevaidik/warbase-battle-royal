extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var data := FileAccess.get_file_as_bytes("/private/tmp/warbase-stadium-backfaces.bin")
	var count := data.decode_u32(0)
	var p := data.slice(4,4+count*12).to_float32_array()
	var n := data.slice(4+count*12,4+count*24).to_float32_array()
	var uv := data.slice(4+count*24).to_float32_array()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var texcoords := PackedVector2Array()
	# glTF uses counter-clockwise front faces; Godot uses clockwise.
	for vertex in count:
		var corner := vertex % 3
		var i := vertex - corner + ([0, 2, 1][corner] as int)
		vertices.append(Vector3(p[i*3],p[i*3+1],p[i*3+2]))
		normals.append(Vector3(n[i*3],n[i*3+1],n[i*3+2]))
		texcoords.append(Vector2(uv[i*2],uv[i*2+1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = texcoords
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var error := ResourceSaver.save(mesh,"res://assets/maps/football_backfaces.res",ResourceSaver.FLAG_COMPRESS)
	print("STADIUM BACKFACES: triangles=",count/3," saved=",error==OK)
	quit(error)
