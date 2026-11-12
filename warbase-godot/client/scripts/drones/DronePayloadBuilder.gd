extends RefCounted
## Aircraft-style display meshes with arcade proportions.

const Meshes = preload("res://scripts/drones/DroneMesh.gd")
const Finish := preload("res://scripts/drones/DroneFinish.gd")
const CANNONS := {
	"ak47": [6, 0.23, 0.042],
	"pistol": [3, 0.17, 0.038],
	"m2010": [7, 0.29, 0.050],
	"hmg": [5, 0.25, 0.046],
	"m4": [1, 0.20, 0.036],
	"mp5": [4, 0.18, 0.043],
	"dmr": [1, 0.27, 0.046],
}
static var _mounted_meshes: Dictionary = {}
static var _missile_meshes: Dictionary = {}

static func build(weapon_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "AircraftPayload"
	root.set_meta("weapon_id", weapon_id)
	if _mounted_meshes.has(weapon_id):
		var cached: Dictionary = _mounted_meshes[weapon_id]
		_add_mesh(root, cached.mesh)
		var marker := Node3D.new()
		marker.name = "Muzzle"
		marker.position = cached.muzzle
		root.add_child(marker)
		return root
	var casing := _finish(Color("39444b"), 0.55, 0.41)
	var mount := _finish(Color("75858d"), 0.7, 0.35)
	_panel(root, Vector3(0.067, 0.018, 0.115), Vector3(0, 0.049, 0.008), mount)
	_panel(root, Vector3(0.040, 0.028, 0.093), Vector3(0, 0.033, 0.008), casing)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	root.add_child(muzzle)
	if weapon_id in ["aim9", "agm114"]:
		root.add_child(missile_body(weapon_id))
		muzzle.position.z = -0.169
	else:
		var profile: Array = CANNONS.get(weapon_id, CANNONS["ak47"])
		_build_cannon(root, int(profile[0]), float(profile[1]), float(profile[2]), casing, mount)
		muzzle.position.z = -float(profile[1]) + 0.075
	_mounted_meshes[weapon_id] = {"mesh": _bake_mesh(root, muzzle), "muzzle": muzzle.position}
	return root

static func _build_cannon(root: Node3D, barrels: int, length: float, collar: float, casing: Material, steel: Material) -> void:
	var bore := _finish(Color("10181c"), 0.3, 0.72)
	var accent := _finish(Color("9a8151"), 0.4, 0.52)
	_axial(root, collar * 1.06, 0.115, Vector3(0, 0, 0.034), casing)
	_axial(root, collar * 0.94, 0.016, Vector3(0, 0, 0.094), steel)
	_axial(root, collar * 0.91, 0.014, Vector3(0, 0, -0.022), accent)
	var extension := length - 0.098
	var muzzle_z := 0.075 - length
	for barrel in barrels:
		var angle := TAU * float(barrel) / float(barrels)
		var offset := Vector3(cos(angle), sin(angle), 0) * (collar * 0.56 if barrels > 1 else 0.0)
		var radius := collar * (0.18 if barrels > 1 else 0.44)
		_axial(root, radius, extension, offset + Vector3(0, 0, muzzle_z + extension * 0.5), steel)
		_axial(root, radius * 0.66, 0.002, offset + Vector3(0, 0, muzzle_z - 0.001), bore)
	if barrels > 1:
		_axial(root, collar * 0.77, 0.013, Vector3(0, 0, muzzle_z + 0.026), casing)
	else:
		_axial(root, collar * 0.60, 0.030, Vector3(0, 0, muzzle_z + 0.034), casing)
	for side in [-1.0, 1.0]:
		_panel(root, Vector3(0.011, 0.024, 0.063), Vector3(side * collar, 0.008, 0.024), steel)

static func missile_body(weapon_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "MissileBody"
	if _missile_meshes.has(weapon_id):
		_add_mesh(root, _missile_meshes[weapon_id])
		return root
	var sidewinder := weapon_id == "aim9"
	var shell := _finish(Color("c8d1d1") if sidewinder else Color("5f654d"), 0.22, 0.50)
	var bands := _finish(Color("b39b49"), 0.30, 0.47)
	var graphite := _finish(Color("25303a"), 0.40, 0.40)
	var radius := 0.021 if sidewinder else 0.026
	_axial(root, radius, 0.265, Vector3(0, 0, 0.010), shell)
	_axial(root, radius, 0.042, Vector3(0, 0, -0.143), graphite, 0.006)
	_axial(root, radius + 0.001, 0.012, Vector3(0, 0, -0.067), bands)
	_axial(root, radius + 0.001, 0.010, Vector3(0, 0, 0.059), bands)
	_axial(root, radius * 0.79, 0.016, Vector3(0, 0, 0.147), graphite)
	for quarter in 4:
		var fin := Node3D.new()
		fin.rotation.z = quarter * PI / 2.0
		root.add_child(fin)
		_panel(fin, Vector3(0.007, 0.038, 0.047), Vector3(0, radius + 0.009, 0.101), shell, Vector3(-0.34, 0, 0))
		if sidewinder:
			_panel(fin, Vector3(0.006, 0.023, 0.031), Vector3(0, radius + 0.006, -0.090), shell, Vector3(-0.26, 0, 0))
	_missile_meshes[weapon_id] = _bake_mesh(root)
	return root

static func _add_mesh(root: Node3D, mesh: ArrayMesh) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)

static func _bake_mesh(root: Node3D, marker: Node3D = null) -> ArrayMesh:
	var batches: Dictionary = {}
	_collect_meshes(root, Transform3D.IDENTITY, batches)
	var mesh := ArrayMesh.new()
	for material in batches:
		var tool: SurfaceTool = batches[material]
		tool.set_material(material)
		tool.commit(mesh)
	for child in root.get_children():
		if child != marker: child.free()
	_add_mesh(root, mesh)
	return mesh

static func _collect_meshes(node: Node3D, transform: Transform3D, batches: Dictionary) -> void:
	if node is MeshInstance3D:
		for index in node.mesh.get_surface_count():
			var material: Material = node.material_override if node.material_override != null else node.mesh.surface_get_material(index)
			if not batches.has(material):
				var new_batch := SurfaceTool.new()
				new_batch.begin(Mesh.PRIMITIVE_TRIANGLES)
				batches[material] = new_batch
			var batch: SurfaceTool = batches[material]
			batch.append_from(node.mesh, index, transform)
	for child in node.get_children():
		if child is Node3D:
			_collect_meshes(child, transform * child.transform, batches)

static func _finish(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	Finish.apply_metal_grain(material)
	return material

static func _panel(parent: Node3D, size: Vector3, at: Vector3, material: Material, angles := Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = Meshes.panel(size)
	instance.position = at
	instance.rotation = angles
	instance.material_override = material
	parent.add_child(instance)

static func _axial(parent: Node3D, radius: float, length: float, at: Vector3, material: Material, nose_radius := -1.0) -> void:
	var shape := CylinderMesh.new()
	shape.radial_segments = 16
	shape.rings = 1
	shape.top_radius = radius if nose_radius < 0.0 else nose_radius
	shape.bottom_radius = radius
	shape.height = length
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.position = at
	instance.rotation.x = -PI / 2.0
	instance.material_override = material
	parent.add_child(instance)
