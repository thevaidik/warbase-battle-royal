class_name WarMapBuilder
extends Node3D
## Tactical FPS map orchestrator with Bullet Force inspired warm daylight.
## Ultra-optimized: zero heavy procedural geometry outside map boundaries.
## 100% matte PBR materials: dry weathered concrete, matte tarmac, zero plastic shine.
## Warm golden sunlight with earth-bounce ambient fill (no cold/blue wash).

var spawn_points: Array[Vector3] = []

const JEEP_SCENE: PackedScene = preload("res://scenes/CombatJeep.tscn")

static var _asphalt_mat: StandardMaterial3D = null
static var _concrete_mat: StandardMaterial3D = null
static var _sanitized_mat_cache: Dictionary = {}
static var _dust2_tex_cache: Array[Texture2D] = []

static func asphalt_mat() -> StandardMaterial3D:
	if not _asphalt_mat:
		_asphalt_mat = StandardMaterial3D.new()
		_asphalt_mat.albedo_color = Color(0.18, 0.18, 0.19)
		_asphalt_mat.roughness = 0.92
		_asphalt_mat.metallic = 0.0
		_asphalt_mat.metallic_specular = 0.05
		_asphalt_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return _asphalt_mat

static func concrete_mat() -> StandardMaterial3D:
	if not _concrete_mat:
		_concrete_mat = StandardMaterial3D.new()
		_concrete_mat.albedo_color = Color(0.42, 0.40, 0.37)
		_concrete_mat.roughness = 0.94
		_concrete_mat.metallic = 0.0
		_concrete_mat.metallic_specular = 0.05
		_concrete_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return _concrete_mat

func _spawn_jeep(pos: Vector3, rot_y: float, parent: Node3D) -> Node3D:
	var jeep := JEEP_SCENE.instantiate() as Node3D
	jeep.position = pos
	jeep.rotation.y = rot_y
	parent.add_child(jeep)
	return jeep

func _find_mesh_instances(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for c in node.get_children():
		_find_mesh_instances(c, out)

func _theme_football(inst: Node3D) -> void:
	var meshes: Array[MeshInstance3D] = []
	_find_mesh_instances(inst, meshes)
	for mi in meshes:
		for surface in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(surface) as StandardMaterial3D
			if mat:
				# Preserve the atlas's authored cut-outs and let room lighting affect it.
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				mat.alpha_scissor_threshold = 0.5
				mat.cull_mode = BaseMaterial3D.CULL_BACK
				mat.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		# Render missing rear surfaces without adding overlapping physics triangles.
		var rear_mesh := load("res://assets/maps/football_backfaces.res") as ArrayMesh
		if rear_mesh:
			var rear := MeshInstance3D.new()
			rear.name = "StadiumBackFaces"
			rear.mesh = rear_mesh
			rear.material_override = mi.get_active_material(0)
			mi.add_child(rear)

func _theme_dust2(inst: Node3D) -> void:
	if _dust2_tex_cache.is_empty():
		var tex_indices := [
			32, 33, 31, 21, 1, 0, 28, 2, 26, 29, 9, 11, 4, 5, 16, 18,
			6, 27, 23, 12, 15, 13, 14, 3, 25, 8, 10, 20, 30, 22, 17, 7
		]
		for idx in tex_indices:
			var p := "res://assets/maps/Dust2_material_%d.png" % idx
			if ResourceLoader.exists(p):
				_dust2_tex_cache.append(load(p) as Texture2D)
			
	var meshes: Array[MeshInstance3D] = []
	_find_mesh_instances(inst, meshes)
	for mi in meshes:
		if mi.mesh:
			var sc := mi.mesh.get_surface_count()
			for s in sc:
				if s < _dust2_tex_cache.size() and _dust2_tex_cache[s]:
					var mat := StandardMaterial3D.new()
					mat.albedo_texture = _dust2_tex_cache[s]
					mat.roughness = 0.92
					mat.metallic = 0.0
					mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
					mi.set_surface_override_material(s, mat)

static var _shipment_container_mats: Array[StandardMaterial3D] = []
static var _shipment_barrel_yellow: StandardMaterial3D = null
static var _shipment_barrel_red: StandardMaterial3D = null
static var _shipment_barrel_steel: StandardMaterial3D = null

func _get_shipment_materials() -> void:
	if _shipment_container_mats.is_empty():
		var colors: Array[Color] = [
			Color(0.12, 0.32, 0.58), # Oceanic Navy Blue (Hanjin / Maersk)
			Color(0.68, 0.18, 0.14), # Crimson Cargo Red (K-Line / CMA)
			Color(0.24, 0.34, 0.20), # Tactical Olive Green (Military)
			Color(0.82, 0.52, 0.12), # Safety Goldenrod / Hazard Orange
			Color(0.65, 0.38, 0.20), # Weathered Rust Orange
			Color(0.18, 0.44, 0.42), # Industrial Teal / Seafoam
			Color(0.48, 0.50, 0.52), # Gunmetal Grey
		]
		for c in colors:
			var m := StandardMaterial3D.new()
			m.albedo_color = c
			m.metallic = 0.65
			m.roughness = 0.55
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			_shipment_container_mats.append(m)
			
		_shipment_barrel_yellow = StandardMaterial3D.new()
		_shipment_barrel_yellow.albedo_color = Color(0.88, 0.65, 0.12)
		_shipment_barrel_yellow.roughness = 0.45
		_shipment_barrel_yellow.metallic = 0.6
		_shipment_barrel_yellow.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		
		_shipment_barrel_red = StandardMaterial3D.new()
		_shipment_barrel_red.albedo_color = Color(0.72, 0.20, 0.16)
		_shipment_barrel_red.roughness = 0.45
		_shipment_barrel_red.metallic = 0.6
		_shipment_barrel_red.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		
		_shipment_barrel_steel = StandardMaterial3D.new()
		_shipment_barrel_steel.albedo_color = Color(0.22, 0.24, 0.26)
		_shipment_barrel_steel.roughness = 0.50
		_shipment_barrel_steel.metallic = 0.8
		_shipment_barrel_steel.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

func _theme_shipment(inst: Node3D) -> void:
	_get_shipment_materials()
	var ground_asphalt := asphalt_mat()
	var wall_concrete := concrete_mat()
	
	var meshes: Array[MeshInstance3D] = []
	_find_mesh_instances(inst, meshes)
	
	var container_idx := 0
	var barrel_idx := 0
	for mi in meshes:
		var n := mi.name.to_lower()
		if n.begins_with("cargo"):
			var mat: StandardMaterial3D = _shipment_container_mats[container_idx % _shipment_container_mats.size()]
			mi.set_surface_override_material(0, mat)
			container_idx += 1
			# Fast box collider for closed containers, saving 100,000+ trimesh physics checks
			if not n.contains("open"):
				var sb := StaticBody3D.new()
				var col := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				var aabb := mi.get_aabb()
				bs.size = aabb.size
				col.shape = bs
				col.position = aabb.position + aabb.size * 0.5
				sb.add_child(col)
				mi.add_child(sb)
			else:
				# Only open containers get trimesh so players can enter
				mi.create_trimesh_collision()
		elif n.begins_with("barrel"):
			var b_mat: StandardMaterial3D = _shipment_barrel_yellow if barrel_idx % 3 == 0 else (_shipment_barrel_red if barrel_idx % 3 == 1 else _shipment_barrel_steel)
			mi.set_surface_override_material(0, b_mat)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			barrel_idx += 1
			# Accurate Cylinder collider centered to match barrel visual mesh
			var sb := StaticBody3D.new()
			var col := CollisionShape3D.new()
			var cs := CylinderShape3D.new()
			var aabb := mi.get_aabb()
			cs.radius = maxf(aabb.size.x, aabb.size.z) * 0.5
			cs.height = aabb.size.y
			col.shape = cs
			col.position = aabb.position + aabb.size * 0.5
			sb.add_child(col)
			mi.add_child(sb)
		elif n.begins_with("plane"):
			mi.set_surface_override_material(0, ground_asphalt)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.create_trimesh_collision()
		elif n.begins_with("wall"):
			mi.set_surface_override_material(0, wall_concrete)
			mi.create_trimesh_collision()


func _theme_village(inst: Node3D) -> void:
	# Fast primitive colliders for village decorative props (benches, street lamps, trees)
	# Replaces 161,000+ heavy concave polygon collision faces with 55 zero-cost primitive shapes
	var b_static := StaticBody3D.new()
	b_static.name = "VillagePropsCollision"
	inst.add_child(b_static)
	
	# 12 Benches (BoxShape3D)
	var bench_coords: Array[Vector3] = [
		Vector3(-20.05, 0.4, -3.75),
		Vector3(-20.11, 0.4, -6.76),
		Vector3(-20.08, 0.4, -5.26),
		Vector3(-19.97, 0.4, 2.96),
		Vector3(-20.02, 0.4, -0.05),
		Vector3(-20.00, 0.4, 1.45),
		Vector3(20.15, 0.4, -1.19),
		Vector3(20.21, 0.4, 1.82),
		Vector3(20.18, 0.4, 0.31),
		Vector3(20.01, 0.4, -7.90),
		Vector3(20.07, 0.4, -4.89),
		Vector3(20.04, 0.4, -6.40),
	]
	var bench_box := BoxShape3D.new()
	bench_box.size = Vector3(1.0, 0.8, 1.6)
	for b_pos in bench_coords:
		var c := CollisionShape3D.new()
		c.shape = bench_box
		c.position = b_pos
		b_static.add_child(c)
		
	# 15 Lamp Posts (CylinderShape3D)
	var lamp_coords: Array[Vector3] = [
		Vector3(78.56, 1.5, 26.77),
		Vector3(78.56, 1.5, -34.19),
		Vector3(-76.84, 1.5, 26.77),
		Vector3(-76.84, 1.5, -34.19),
		Vector3(47.66, 1.5, -92.30),
		Vector3(-50.60, 1.5, -92.30),
		Vector3(47.66, 1.5, 89.71),
		Vector3(-38.98, 1.5, 38.00),
		Vector3(1.43, 1.5, -2.64),
		Vector3(-1.48, 1.5, -2.77),
		Vector3(0.03, 1.5, -3.88),
		Vector3(-0.16, 1.5, -1.42),
		Vector3(-39.09, 1.5, -46.01),
		Vector3(44.13, 1.5, 38.00),
		Vector3(44.13, 1.5, -46.01),
	]
	var lamp_cyl := CylinderShape3D.new()
	lamp_cyl.radius = 0.25
	lamp_cyl.height = 3.0
	for l_pos in lamp_coords:
		var c := CollisionShape3D.new()
		c.shape = lamp_cyl
		c.position = l_pos
		b_static.add_child(c)
		
	# 28 Tree Trunks (CylinderShape3D)
	var tree_coords: Array[Vector3] = [
		Vector3(-0.33, 2.0, 0.12),
		Vector3(3.08, 2.0, -33.61),
		Vector3(4.78, 2.0, 65.17),
		Vector3(40.24, 2.0, 61.89),
		Vector3(40.24, 2.0, 15.15),
		Vector3(40.24, 2.0, -33.97),
		Vector3(-102.19, 2.0, 61.89),
		Vector3(-97.39, 2.0, 15.15),
		Vector3(-110.12, 2.0, -33.97),
		Vector3(-110.12, 2.0, 107.79),
		Vector3(-56.09, 2.0, 97.47),
		Vector3(-9.20, 2.0, 91.46),
		Vector3(34.25, 2.0, 97.47),
		Vector3(-9.20, 2.0, 118.49),
		Vector3(-73.26, 2.0, 120.01),
		Vector3(-124.48, 2.0, 85.39),
		Vector3(-124.48, 2.0, 40.88),
		Vector3(-124.48, 2.0, -13.23),
		Vector3(-124.48, 2.0, -49.56),
		Vector3(-68.53, 2.0, -42.81),
		Vector3(-8.70, 2.0, -62.71),
		Vector3(23.01, 2.0, -84.78),
		Vector3(64.64, 2.0, -52.27),
		Vector3(64.64, 2.0, -16.33),
		Vector3(64.64, 2.0, 43.45),
		Vector3(64.64, 2.0, 79.39),
		Vector3(-60.94, 2.0, -75.07),
		Vector3(-65.40, 2.0, 35.43),
	]
	var tree_cyl := CylinderShape3D.new()
	tree_cyl.radius = 0.45
	tree_cyl.height = 4.0
	for t_pos in tree_coords:
		var c := CollisionShape3D.new()
		c.shape = tree_cyl
		c.position = t_pos
		b_static.add_child(c)

func _desert_piece(parent: Node3D, piece_name: String, dimensions: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = piece_name
	var shape := BoxMesh.new()
	shape.size = dimensions
	mesh.mesh = shape
	mesh.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.96
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh

func _theme_desert_oasis(inst: Node3D, _root: Node3D) -> void:
	# Authored in metres; this arena has no dependency on the industrial asset.
	var sand := Color("c7a16c")
	var stone := Color("a17e53")
	_desert_piece(inst, "SandTerrain", Vector3(80, 1, 80), Vector3(0, -0.5, 0), sand)
	# Broken ruins make three routes through the centre, with gaps for flanking.
	for side in [-1.0, 1.0]:
		for z in [-10.0, 10.0]:
			_desert_piece(inst, "RuinWall", Vector3(1.2, 3.4, 8), Vector3(side * 8, 1.7, z), stone)
		for x in [-13.0, 13.0]:
			_desert_piece(inst, "BrokenWall", Vector3(6, 2.3, 1.2), Vector3(x, 1.15, side * 5), stone)
		for x in [-5.0, 5.0]:
			_desert_piece(inst, "TemplePillar", Vector3(1.4, 4, 1.4), Vector3(x, 2, side * 3), stone.lightened(0.1))
		_desert_piece(inst, "TempleLintel", Vector3(11.4, 0.7, 1.6), Vector3(0, 4.2, side * 3), stone)
	# Low cover and broad rock outcrops leave the authored spawns unobstructed.
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var at := Vector3(cos(angle) * 26, 1.8, sin(angle) * 26)
		var rock := _desert_piece(inst, "SandstoneOutcrop", Vector3(4.5, 3.6, 3.8), at, stone.darkened(0.12))
		rock.rotation.y = angle
	for at in [Vector3(-19, 0.6, -8), Vector3(19, 0.6, 8), Vector3(-3, 0.6, 16), Vector3(3, 0.6, -16)]:
		_desert_piece(inst, "LowCover", Vector3(3.5, 1.2, 1.4), at, stone)
	for at in [Vector3(-22, 0, -16), Vector3(22, 0, 16), Vector3(-20, 0, 18), Vector3(20, 0, -18)]:
		_desert_piece(inst, "PalmTrunk", Vector3(0.5, 5.5, 0.5), at + Vector3(0, 2.75, 0), Color("705337"))
		for leaf in 5:
			var foliage := _desert_piece(inst, "PalmFrond", Vector3(0.8, 0.18, 5), at + Vector3(0, 5.4, 0), Color("536c3e"))
			foliage.rotation.y = TAU * float(leaf) / 5.0

func _theme_loft(inst: Node3D, root: Node3D) -> void:
	# 1. Solid primitive colliders for Loft (Floors, Mezzanine, Interior walls, Tactical Cover, Perimeter)
	# Replaces 135 heavy trimesh concave polygon colliders with 12 zero-cost primitive Box colliders
	var bounds_parent := StaticBody3D.new()
	bounds_parent.name = "LoftColliders"
	
	var boxes: Array[Dictionary] = [
		# Floors & Mezzanine
		{"size": Vector3(16.0, 0.4, 12.0), "pos": Vector3(0.0, -0.2, 0.0)},   # Ground main floor
		{"size": Vector3(7.4, 0.4, 8.4), "pos": Vector3(3.33, 3.8, -8.76)},   # Upper mezzanine floor
		{"size": Vector3(7.4, 0.4, 8.4), "pos": Vector3(3.33, 7.3, -8.76)},   # Bedroom ceiling
		# Exterior Containment Walls
		{"size": Vector3(18.0, 1.0, 24.0), "pos": Vector3(0.0, 7.8, -4.0)},   # Overall roof barrier
		{"size": Vector3(18.0, 8.0, 1.0), "pos": Vector3(0.0, 3.8, 5.2)},     # South balcony glass wall
		{"size": Vector3(18.0, 8.0, 1.0), "pos": Vector3(0.0, 3.8, -13.0)},   # North exterior wall
		{"size": Vector3(1.0, 8.0, 22.0), "pos": Vector3(-7.2, 3.8, -4.0)},   # West exterior wall
		{"size": Vector3(1.0, 8.0, 22.0), "pos": Vector3(7.2, 3.8, -4.0)},    # East exterior wall
		# Interior Architectural Walls & Tactical Cover
		{"size": Vector3(14.0, 3.8, 0.2), "pos": Vector3(-0.01, 1.91, -4.96)}, # Lower interior divider wall
		{"size": Vector3(14.0, 4.0, 0.2), "pos": Vector3(0.08, 6.64, -8.64)},  # Upper bedroom back wall
		{"size": Vector3(4.8, 0.8, 3.0), "pos": Vector3(-3.7, 0.4, -1.5)},    # Living room sofa (tactical cover)
		{"size": Vector3(6.3, 0.8, 4.4), "pos": Vector3(-3.8, 4.3, -6.5)},    # Upstairs bed (tactical cover)
	]
	for b in boxes:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = b["size"]
		cs.shape = bs
		cs.position = b["pos"]
		bounds_parent.add_child(cs)
	root.add_child(bounds_parent)
	
	# Spiral staircase trimesh (the only trimesh in Loft, enabling smooth ascent to mezzanine)
	var stairs := inst.find_child("SpiralStairs", true, false) as MeshInstance3D
	if not stairs:
		stairs = inst.find_child("node_0_Material_003_0", true, false) as MeshInstance3D
	if stairs and stairs.mesh:
		stairs.create_trimesh_collision()
		
	# Warm Luxury Penthouse Interior Fill Light (1 central chandelier - avoids forward multi-pass explosion)
	var ol := OmniLight3D.new()
	ol.position = Vector3(0.0, 4.8, 0.0)
	ol.light_color = Color(1.0, 0.88, 0.72)
	ol.light_energy = 0.9
	ol.omni_range = 8.5
	ol.omni_attenuation = 1.0
	ol.shadow_enabled = false
	root.add_child(ol)

const MAP_GLBS := {
	"industrial": "res://assets/maps/low_poly_industrial_zone.glb",
	"resoforge": "res://assets/maps/resoforge_tdm.glb",
	"football": "res://assets/maps/football.glb",
	"village": "res://assets/maps/village_lowres.glb",
	"arena": "res://assets/maps/fps_shooter_game_arena_map_v3.glb",
	"shipment": "res://assets/maps/shipment.glb",
	"dust2": "res://assets/maps/low_poly_industrial_zone.glb",
	"nuketown": "res://assets/maps/low_poly_industrial_zone.glb",
	"warzone": "res://assets/maps/low_poly_industrial_zone.glb",
	"desert_road": "res://assets/maps/low_poly_industrial_zone.glb",
	"canyon": "res://assets/maps/low_poly_industrial_zone.glb",
	"desert_oasis": "", # Procedural desert arena, authored in metres.
}

func build(map_name: String) -> Array[Vector3]:
	spawn_points.clear()
	_sanitized_mat_cache.clear()
	for c in get_children():
		c.queue_free()
	var root := Node3D.new()
	root.name = "MapRoot"
	add_child(root)
	var key := map_name if MAP_GLBS.has(map_name) else "industrial"
	if key == "warzone" or key == "desert_road":
		key = "canyon"
	
	var extent := 48.0
	var center := Vector3.ZERO
	
	if MAP_GLBS.has(key):
		var glb_path: String = MAP_GLBS[key]
		var glb: PackedScene = null if key == "desert_oasis" else load(glb_path) as PackedScene
		if glb or key == "desert_oasis":
			var inst := Node3D.new() if key == "desert_oasis" else glb.instantiate() as Node3D
			inst.name = "DesertOasis" if key == "desert_oasis" else "GLBMap"
			root.add_child(inst)
			if key == "resoforge": inst.scale = Vector3.ONE * 3.0
			
			if key == "dust2":
				_theme_dust2(inst)
			elif key == "shipment":
				_theme_shipment(inst)
			elif key == "village":
				_theme_village(inst)
			elif key == "desert_oasis":
				_theme_desert_oasis(inst, root)
			elif key == "loft":
				_theme_loft(inst, root)
				
			# Shipment & Loft use ultra-fast primitive Box & Cylinder shapes to guarantee 240+ FPS and 0ms physics spikes
			if key != "shipment" and key != "loft":
				_add_trimesh_collision(inst, key in ["resoforge", "football"])
			if key != "shipment":
				_sanitize_glb_materials(inst)
			if key == "football": _theme_football(inst)
			
			# Fall-catcher safety barrier below map (deep safety net only if player clips out of bounds)
			var safety := StaticBody3D.new()
			safety.name = "SafetyFloor"
			var sc := CollisionShape3D.new()
			var sb := BoxShape3D.new()
			sb.size = Vector3(2200, 1.0, 2200) if key in ["canyon", "warzone", "desert_road"] else Vector3(500, 1.0, 500)
			sc.shape = sb
			sc.position.y = -120.0 if key == "canyon" else -15.0
			safety.add_child(sc)
			root.add_child(safety)
			
			match key:
				"city":
					extent = 100.0
					center = Vector3(-10.0, 0.0, 18.0)
					_add_perimeter_barriers(root, center, extent)
					_spawn_jeep(Vector3(12.0, 0.5, 8.0), 0.0, root)
					_spawn_jeep(Vector3(-30.0, 0.5, 25.0), deg_to_rad(90), root)
					_spawn_jeep(Vector3(35.0, 0.5, -15.0), deg_to_rad(-45), root)
					spawn_points = [
						Vector3(-10.0, 0.5, 4.0),
						Vector3(10.0, 0.5, 4.0),
						Vector3(25.0, 0.5, 6.0),
						Vector3(45.0, 0.5, 4.0),
						Vector3(60.0, 0.5, 8.0),
						Vector3(-5.0, 0.5, 18.0),
						Vector3(20.0, 0.5, 20.0),
						Vector3(35.0, 0.5, 16.0),
						Vector3(50.0, 0.5, 24.0),
						Vector3(-15.0, 0.5, 28.0),
						Vector3(15.0, 0.5, 36.0),
						Vector3(30.0, 0.5, 40.0),
					]
				"shipment":
					extent = 24.0
					center = Vector3.ZERO
					_add_perimeter_barriers(root, center, extent)
					spawn_points = [
						Vector3(-20.0, 0.4, -20.0),
						Vector3(-18.0, 0.4, -2.0),
						Vector3(-16.0, 0.4, 18.0),
						Vector3(-12.0, 0.4, 4.0),
						Vector3(-8.0, 0.4, -20.0),
						Vector3(-6.0, 0.4, 14.0),
						Vector3(-2.0, 0.4, 16.0),
						Vector3(4.0, 0.4, -18.0),
						Vector3(8.0, 0.4, -10.0),
						Vector3(10.0, 0.4, 8.0),
						Vector3(14.0, 0.4, -16.0),
						Vector3(18.0, 0.4, -20.0),
					]
				"dust2":
					extent = 65.0
					center = Vector3(8.0, 0.0, 28.0)
					# The industrial asset has a visible perimeter fence with mesh collision.
					# Extra square barriers cut across its playable roads and buildings.
					_spawn_jeep(Vector3(-10.0, 1.2, 4.0), 0.0, root)
					spawn_points = [
						Vector3(-10.0, 1.2, 4.0),
						Vector3(10.0, 1.2, 4.0),
						Vector3(25.0, 1.2, 6.0),
						Vector3(45.0, 1.2, 4.0),
						Vector3(60.0, 1.2, 8.0),
						Vector3(-5.0, 1.2, 18.0),
						Vector3(20.0, 1.2, 20.0),
						Vector3(35.0, 1.2, 16.0),
						Vector3(50.0, 1.2, 24.0),
						Vector3(-15.0, 1.2, 28.0),
						Vector3(15.0, 1.2, 36.0),
						Vector3(30.0, 1.2, 40.0),
					]
				"nuketown":
					extent = 35.0
					center = Vector3.ZERO
					# The industrial asset has a visible perimeter fence with mesh collision.
					# Extra square barriers cut across its playable roads and buildings.
					spawn_points = [
						Vector3(-24.0, 0.4, -14.0),
						Vector3(24.0, 0.4, 14.0),
						Vector3(-25.0, 0.4, 13.0),
						Vector3(25.0, 0.4, -13.0),
						Vector3(-19.0, 0.4, 9.0),
						Vector3(19.0, 0.4, -9.0),
						Vector3(-28.0, 0.4, 0.0),
						Vector3(28.0, 0.4, 0.0),
						Vector3(-8.0, 0.4, 12.0),
						Vector3(8.0, 0.4, -12.0),
						Vector3(-10.0, 0.4, -12.0),
						Vector3(10.0, 0.4, 12.0),
					]
				"football":
					extent = 110.0
					center = Vector3.ZERO
					spawn_points = [
						Vector3(-15, 3.7421, -25), Vector3(15, 3.7421, -25),
						Vector3(-15, 3.7421, 25), Vector3(15, 3.7421, 25),
						Vector3(-45, 2.1619, -45), Vector3(45, 2.1619, -45),
						Vector3(-45, 2.1619, 45), Vector3(45, 2.1619, 45),
						Vector3(-15, 2.1619, -65), Vector3(15, 2.1619, -65),
						Vector3(-15, 2.1619, 65), Vector3(15, 2.1619, 65),
					]

				"resoforge":
					extent = 28.0
					center = Vector3.ZERO
					spawn_points = [
						Vector3(-9, 0.15, -20), Vector3(0, 0.15, -20), Vector3(9, 0.15, -20),
						Vector3(-9, 0.15, -14), Vector3(0, 0.15, -14), Vector3(9, 0.15, -14),
						Vector3(-9, 0.15, 20), Vector3(0, 0.15, 20), Vector3(3, 0.15, 20),
						Vector3(-3, 0.15, 14), Vector3(3, 0.15, 14), Vector3(9, 0.15, 14),
					]

				"industrial":
					extent = 70.0
					center = Vector3.ZERO
					# The industrial asset has a visible perimeter fence with mesh collision.
					# Extra square barriers cut across its playable roads and buildings.
					# Spawn jeeps on wide open 50-meter highway avenues with clear driving lines
					_spawn_jeep(Vector3(-20.0, 0.5, 20.0), 0.0, root)
					_spawn_jeep(Vector3(20.0, 0.5, 20.0), deg_to_rad(90.0), root)
					spawn_points = [
						Vector3(-22.0, 1.3, -22.0),
						Vector3(-22.0, 1.3, 0.0),
						Vector3(-22.0, 1.3, 22.0),
						Vector3(0.0, 1.3, -22.0),
						Vector3(0.0, 1.3, 22.0),
						Vector3(22.0, 1.3, -22.0),
						Vector3(22.0, 1.3, 0.0),
						Vector3(22.0, 1.3, 22.0),
						Vector3(-12.0, 1.3, -12.0),
						Vector3(12.0, 1.3, -12.0),
						Vector3(-12.0, 1.3, 12.0),
						Vector3(12.0, 1.3, 12.0),
					]
				"village":
					extent = 130.0
					center = Vector3(0.0, 0.0, -20.0)
					_add_perimeter_barriers(root, center, extent)
					# Spawn jeeps in wide open road lanes with >10m clearance away from props & buildings
					_spawn_jeep(Vector3(35.0, 0.5, -20.0), 0.0, root)
					_spawn_jeep(Vector3(-35.0, 0.5, -20.0), PI, root)
					spawn_points = [
						Vector3(-14.0, 0.5, -8.0),
						Vector3(18.0, 0.5, 8.0),
						Vector3(-8.0, 0.5, -14.0),
						Vector3(8.0, 0.5, 18.0),
						Vector3(-25.0, 0.5, 10.0),
						Vector3(25.0, 0.5, -10.0),
						Vector3(0.0, 0.5, -12.0),
						Vector3(0.0, 0.5, 12.0),
						Vector3(-14.0, 0.5, 16.0),
						Vector3(14.0, 0.5, -16.0),
						Vector3(-6.0, 0.5, 2.0),
						Vector3(6.0, 0.5, -2.0),
					]
				"arena":
					extent = 36.0
					center = Vector3(-15.0, 0.0, -15.0)
					_add_perimeter_barriers(root, center, extent)
					spawn_points = [
						Vector3(-26.0, 1.1, -3.0),
						Vector3(-26.0, 1.1, -7.5),
						Vector3(-20.0, 1.1, -3.0),
						Vector3(-20.0, 1.1, -7.5),
						Vector3(-15.0, 1.1, -3.0),
						Vector3(-15.0, 1.1, -7.5),
						Vector3(-9.0, 1.1, -3.0),
						Vector3(-9.0, 1.1, -7.5),
						Vector3(-4.0, 1.1, -3.5),
						Vector3(-4.0, 1.7, -6.5),
						Vector3(-15.0, 1.1, -5.0),
						Vector3(-22.0, 1.1, -5.0),
					]
				"canyon":
					extent = 70.0
					center = Vector3.ZERO
					# The industrial asset has a visible perimeter fence with mesh collision.
					# Extra square barriers cut across its playable roads and buildings.
					_spawn_jeep(Vector3(-20.0, 0.5, 20.0), 0.0, root)
					_spawn_jeep(Vector3(20.0, 0.5, 20.0), deg_to_rad(90.0), root)
					spawn_points = [
						Vector3(-22.0, 1.3, -22.0),
						Vector3(-22.0, 1.3, 0.0),
						Vector3(-22.0, 1.3, 22.0),
						Vector3(0.0, 1.3, -22.0),
						Vector3(0.0, 1.3, 22.0),
						Vector3(22.0, 1.3, -22.0),
						Vector3(22.0, 1.3, 0.0),
						Vector3(22.0, 1.3, 22.0),
						Vector3(-12.0, 1.3, -12.0),
						Vector3(12.0, 1.3, -12.0),
						Vector3(-12.0, 1.3, 12.0),
						Vector3(12.0, 1.3, 12.0),
					]
				"desert_oasis":
					extent = 32.0
					center = Vector3.ZERO
					_add_perimeter_barriers(root, center, extent)
					_spawn_jeep(Vector3(0.0, 0.5, -12.0), 0.0, root)
					_spawn_jeep(Vector3(0.0, 0.5, 12.0), PI, root)
					spawn_points = [
						Vector3(-16.0, 0.5, -16.0),
						Vector3(16.0, 0.5, 16.0),
						Vector3(-16.0, 0.5, 16.0),
						Vector3(16.0, 0.5, -16.0),
						Vector3(0.0, 0.5, 18.0),
						Vector3(0.0, 0.5, -18.0),
						Vector3(18.0, 0.5, 0.0),
						Vector3(-20.0, 0.5, 0.0),
						Vector3(-8.0, 0.5, -10.0),
						Vector3(8.0, 0.5, -8.0),
						Vector3(-8.0, 0.5, 10.0),
						Vector3(8.0, 0.5, 8.0),
					]
				"loft":
					extent = 14.0
					center = Vector3(0.0, 0.0, -4.0)
					spawn_points = [
						# Ground Floor Living & Lounge (Y = 0.3 - 1.0)
						Vector3(0.0, 0.3, 1.5),
						Vector3(-3.0, 0.3, 1.5),
						Vector3(3.0, 0.3, 1.5),
						Vector3(0.0, 0.3, 3.2),
						Vector3(3.2, 0.3, -2.5),
						Vector3(-3.2, 1.0, -2.5),
						# Upper Mezzanine, Terrace & Catwalk (Y = 4.1 - 4.9)
						Vector3(3.0, 4.1, -8.5),
						Vector3(-3.5, 4.9, -6.0),
						Vector3(0.0, 4.1, -5.5),
						Vector3(3.0, 4.1, -11.0),
						Vector3(-3.5, 0.3, -4.0),
						Vector3(-1.0, 0.3, -3.2),
					]
	_build_sky(root, key)
	apply_time_of_day(GameState.selected_time)
	for collider in find_children("*", "CollisionShape3D", true, false):
		if collider.shape is ConcavePolygonShape3D: collider.shape.backface_collision = true
	for light in find_children("*", "Light3D", true, false):
		light.shadow_enabled = false
	return spawn_points

func _sanitize_glb_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			var aabb := mi.get_aabb()
			var node_nm := mi.name.to_lower()
			var is_exterior := node_nm.contains("023") or node_nm.contains("024") or node_nm.contains("025") or node_nm.contains("026") or node_nm.contains("027") or node_nm.contains("028") or node_nm.contains("029") or node_nm.contains("030") or node_nm.contains("031")
			# Esports optimization: skip small props and exterior skyscrapers from casting dynamic shadow cascades (saves 1500+ draw calls)
			if aabb.size.length() < 1.8 or is_exterior:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for s in mi.mesh.get_surface_count():
				var mat = mi.get_surface_override_material(s)
				if not mat:
					mat = mi.mesh.surface_get_material(s)
				if mat is StandardMaterial3D:
					var cache_id: int = mat.get_instance_id()
					if not _sanitized_mat_cache.has(cache_id):
						var m: StandardMaterial3D = mat.duplicate()
						# 1. 16x Anisotropic Filtering for crisp textures at all viewing angles
						m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
						# 2. Natural PBR response: preserve authentic metallic surfaces (containers, barrels, cars) while eliminating plastic glare
						var mat_res_nm: String = String(mat.resource_name).to_lower()
						var is_glass: bool = mat_res_nm.contains("glass") or mat_res_nm == "material.032"
						var is_exterior_mat: bool = mat_res_nm in ["material.023", "material.024", "material.025", "material.026", "material.027", "material.028", "material.029", "material.030", "material.031"]
						if is_glass:
							# Glass & transparent window panes: crystal clear with smooth specular reflection
							m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
							m.cull_mode = BaseMaterial3D.CULL_DISABLED
							m.roughness = 0.05
							m.metallic = 0.08
							m.metallic_specular = 0.85
							m.albedo_color = Color(0.68, 0.82, 0.95, 0.28)
						elif is_exterior_mat:
							# Exterior distant skyscrapers: single-sided backface culling, 0 metallic glare
							m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
							m.cull_mode = BaseMaterial3D.CULL_BACK
							m.roughness = 0.85
							m.metallic = 0.05
						else:
							# All interior walls, floors, ceilings & props: 100% solid opaque and two-sided (no see-through walls)
							m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
							m.cull_mode = BaseMaterial3D.CULL_DISABLED
							if m.metallic > 0.4:
								m.roughness = clampf(m.roughness, 0.35, 0.85)
								m.metallic = clampf(m.metallic, 0.4, 0.95)
								m.metallic_specular = 0.5
							else:
								m.roughness = clampf(m.roughness, 0.70, 1.0)
								m.metallic = clampf(m.metallic, 0.0, 0.15)
								m.metallic_specular = 0.15
						# 3. Normal mapping preserved without artificial wash-out
						if m.normal_texture:
							m.normal_enabled = true
							m.normal_scale = 1.0
						else:
							m.normal_enabled = false
						# 4. Tame pure untextured white surfaces (e.g. Arena Object_5)
						if not is_glass and m.albedo_texture == null and m.albedo_color.r > 0.82 and m.albedo_color.g > 0.82 and m.albedo_color.b > 0.82:
							m.albedo_color = Color(0.42, 0.40, 0.38, 1.0)
						_sanitized_mat_cache[cache_id] = m
					mi.set_surface_override_material(s, _sanitized_mat_cache[cache_id])
	for c in node.get_children():
		_sanitize_glb_materials(c)

func _add_perimeter_barriers(root: Node3D, center: Vector3, extent: float) -> void:
	var h_col := 14.0
	var th_col := 2.0
	var col_positions := [
		center + Vector3(0, h_col * 0.5, -extent),
		center + Vector3(0, h_col * 0.5, extent),
		center + Vector3(-extent, h_col * 0.5, 0),
		center + Vector3(extent, h_col * 0.5, 0)
	]
	var col_sizes := [
		Vector3(extent * 2.2, h_col, th_col),
		Vector3(extent * 2.2, h_col, th_col),
		Vector3(th_col, h_col, extent * 2.2),
		Vector3(th_col, h_col, extent * 2.2)
	]
	for i in 4:
		var wall := StaticBody3D.new()
		wall.name = "PerimeterWall_%d" % i
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = col_sizes[i]
		col.shape = bs
		wall.add_child(col)
		wall.position = col_positions[i]
		root.add_child(wall)

func _add_trimesh_collision(n: Node, exact: bool = false) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh and mi.mesh.get_faces().size() > 0:
			var aabb := mi.get_aabb()
			if exact or aabb.size.length() > 0.8:
				var nm := mi.name.to_lower()
				var p_nm := mi.get_parent().name.to_lower() if mi.get_parent() else ""
				if not exact and (nm.contains("sky") or nm.contains("outline") or nm.contains("cloud")):
					return
				# Filter out decorative props that have extreme polygon counts or foliage (village props have fast primitive colliders)
				if not exact and (nm.contains("lamp") or p_nm.contains("lamp") \
					or nm.contains("chair") or p_nm.contains("chair") \
					or nm.contains("tree") or p_nm.contains("tree") \
					or nm.contains("bench") or p_nm.contains("bench") \
					or nm.contains("kust") or nm.contains("branch") or nm.contains("leaf") or nm.contains("leaves") \
					or nm in ["object_15", "object_16", "object_18", "object_20"]):
					return
				# If prop is a box / container / crate, use solid seam-free BoxShape3D
				if not exact and (nm.contains("cargo") or nm.contains("container") or nm.contains("集装箱") or nm.contains("立方体") or nm.contains("crate") or (nm.contains("box") and not nm.contains("skybox"))):
					var sb := StaticBody3D.new()
					var col := CollisionShape3D.new()
					var bs := BoxShape3D.new()
					bs.size = aabb.size
					col.shape = bs
					col.position = aabb.position + aabb.size * 0.5
					sb.add_child(col)
					mi.add_child(sb)
				elif not exact and (nm.contains("barrel") or nm.contains("油桶")):
					var sb := StaticBody3D.new()
					var col := CollisionShape3D.new()
					var cs := CylinderShape3D.new()
					cs.radius = maxf(aabb.size.x, aabb.size.z) * 0.5
					cs.height = aabb.size.y
					col.shape = cs
					col.position = aabb.position + Vector3(aabb.size.x * 0.5, aabb.size.y * 0.5, aabb.size.z * 0.5)
					sb.add_child(col)
					mi.add_child(sb)
				else:
					var faces := mi.mesh.get_faces()
					if mi.transform.basis.determinant() < 0.0:
						for i in range(0, faces.size(), 3):
							var tmp := faces[i + 1]
							faces[i + 1] = faces[i + 2]
							faces[i + 2] = tmp
					var shape := ConcavePolygonShape3D.new()
					shape.set_faces(faces)
					var sb := StaticBody3D.new()
					var col := CollisionShape3D.new()
					col.shape = shape
					sb.add_child(col)
					mi.add_child(sb)
	for c in n.get_children():
		_add_trimesh_collision(c, exact)

func _build_sky(root: Node3D, map_name: String = "industrial") -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	
	# Godot 4 Native Procedural Sky: Cinematic Golden Hour / Evening Dusk Atmosphere
	var sky := Sky.new()
	var pm := ProceduralSkyMaterial.new()
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	
	if map_name == "village":
		# Alpine Golden Hour / Alpenglow (Warm rose-gold sun, coral horizon, deep twilight zenith)
		pm.sky_top_color = Color(0.12, 0.20, 0.44)
		pm.sky_horizon_color = Color(0.98, 0.60, 0.34)
		pm.ground_horizon_color = Color(0.48, 0.34, 0.26)
		pm.ground_bottom_color = Color(0.10, 0.08, 0.10)
		pm.sun_angle_max = 32.0
		pm.sun_curve = 0.08
	elif map_name == "arena":
		# Tactical Stadium Dusk (Dramatic amber dusk, deep indigo zenith)
		pm.sky_top_color = Color(0.10, 0.14, 0.32)
		pm.sky_horizon_color = Color(0.92, 0.52, 0.28)
		pm.ground_horizon_color = Color(0.40, 0.26, 0.22)
		pm.ground_bottom_color = Color(0.08, 0.07, 0.08)
		pm.sun_angle_max = 28.0
		pm.sun_curve = 0.10
	elif map_name in ["dust2", "warzone", "desert_road", "canyon", "desert_oasis"]:
		# Fiery Desert Sunset (Burning amber-gold horizon, deep desert twilight sapphire zenith)
		pm.sky_top_color = Color(0.14, 0.20, 0.42)
		pm.sky_horizon_color = Color(1.0, 0.56, 0.24)
		pm.ground_horizon_color = Color(0.54, 0.32, 0.20)
		pm.ground_bottom_color = Color(0.12, 0.08, 0.08)
		pm.sun_angle_max = 36.0
		pm.sun_curve = 0.07
	elif map_name == "shipment":
		# Harbor Dusk (Gritty coastal twilight, warm copper glow reflecting on wet asphalt & steel)
		pm.sky_top_color = Color(0.12, 0.16, 0.34)
		pm.sky_horizon_color = Color(0.92, 0.54, 0.30)
		pm.ground_horizon_color = Color(0.38, 0.28, 0.24)
		pm.ground_bottom_color = Color(0.09, 0.08, 0.10)
		pm.sun_angle_max = 28.0
		pm.sun_curve = 0.10
	elif map_name == "nuketown":
		# 1950s Suburban Golden Sunset (Nostalgic warm honey gold & peach horizon, cobalt twilight)
		pm.sky_top_color = Color(0.12, 0.22, 0.46)
		pm.sky_horizon_color = Color(0.98, 0.65, 0.36)
		pm.ground_horizon_color = Color(0.50, 0.36, 0.26)
		pm.ground_bottom_color = Color(0.10, 0.09, 0.10)
		pm.sun_angle_max = 32.0
		pm.sun_curve = 0.08
	elif map_name == "loft":
		# Luxury Penthouse Dusk: Warm golden hour skyline, deep indigo zenith, city glow
		pm.sky_top_color = Color(0.12, 0.18, 0.44)
		pm.sky_horizon_color = Color(0.98, 0.62, 0.35)
		pm.ground_horizon_color = Color(0.42, 0.30, 0.25)
		pm.ground_bottom_color = Color(0.10, 0.08, 0.10)
		pm.sun_angle_max = 30.0
		pm.sun_curve = 0.08
	else:
		# Metropolis Golden Hour (Warm golden amber avenues, long skyscraper shadows, twilight navy)
		pm.sky_top_color = Color(0.12, 0.18, 0.40)
		pm.sky_horizon_color = Color(0.96, 0.60, 0.34)
		pm.ground_horizon_color = Color(0.46, 0.32, 0.26)
		pm.ground_bottom_color = Color(0.10, 0.08, 0.10)
		pm.sun_angle_max = 32.0
		pm.sun_curve = 0.08
		
	sky.sky_material = pm
	env.sky = sky
	
	# Warm Earth-Bounce & Twilight Sky Ambient Fill (Preserves competitive clarity with rich evening mood)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.76, 0.68) if map_name == "loft" else (Color(0.68, 0.54, 0.48) if map_name != "arena" else Color(0.48, 0.38, 0.34))
	env.ambient_light_energy = 0.88 if map_name == "loft" else 0.62
	
	# Sky reflections for authentic metallic surfaces (guns, steel silos, vehicle panels)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	
	# Film-grade ACES Tonemapper with warm cinematic contrast
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 5.4
	
	# Screen Space Ambient Occlusion (Disabled for 120Hz e-sports frame rate & zero fillrate penalty)
	env.ssao_enabled = false
	
	# Subtle Tactical Evening Bloom (Sun specular glints, vehicle headlights, muzzle flashes)
	# On Web: disable multi-pass glow to eliminate WebGL 2.0 blit/framebuffer overhead
	env.glow_enabled = not OS.has_feature("web")
	env.glow_normalized = true
	env.glow_intensity = 0.26
	env.glow_bloom = 0.07
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 0.95
	
	# Radiant Golden Hour Atmospheric Haze
	env.fog_enabled = true
	if map_name in ["dust2", "warzone", "desert_road", "canyon", "desert_oasis"]:
		env.fog_light_color = Color(0.95, 0.58, 0.30)
		env.fog_density = 0.0006 if map_name == "canyon" else 0.0010
	elif map_name == "arena":
		env.fog_light_color = Color(0.78, 0.46, 0.28)
		env.fog_density = 0.0012
	elif map_name == "loft":
		env.fog_light_color = Color(0.94, 0.62, 0.38)
		env.fog_density = 0.0003
	else:
		env.fog_light_color = Color(0.92, 0.60, 0.36)
		env.fog_density = 0.0010
	env.fog_light_energy = 0.50
	env.fog_aerial_perspective = 0.65
	
	var hemi := WorldEnvironment.new()
	hemi.environment = env
	root.add_child(hemi)
	
	# Directional Evening Sun: Low horizon angle (-15° pitch), casting dramatic long golden shadows
	var sun := DirectionalLight3D.new()
	if map_name == "village":
		sun.rotation = Vector3(deg_to_rad(-14.0), deg_to_rad(52.0), 0)
		sun.light_energy = 1.65
		sun.light_color = Color(1.0, 0.78, 0.50)
	elif map_name == "arena":
		sun.rotation = Vector3(deg_to_rad(-18.0), deg_to_rad(-120.0), 0)
		sun.light_energy = 1.55
		sun.light_color = Color(1.0, 0.72, 0.44)
	elif map_name == "city":
		sun.rotation = Vector3(deg_to_rad(-15.0), deg_to_rad(-55.0), 0)
		sun.light_energy = 1.70
		sun.light_color = Color(1.0, 0.76, 0.48)
	elif map_name == "loft":
		sun.rotation = Vector3(deg_to_rad(-16.0), deg_to_rad(-65.0), 0)
		sun.light_energy = 1.70
		sun.light_color = Color(1.0, 0.78, 0.52)
	elif map_name == "dust2":
		sun.rotation = Vector3(deg_to_rad(-15.0), deg_to_rad(-48.0), 0)
		sun.light_energy = 1.65
		sun.light_color = Color(1.0, 0.76, 0.46)
	elif map_name == "nuketown":
		sun.rotation = Vector3(deg_to_rad(-15.0), deg_to_rad(38.0), 0)
		sun.light_energy = 1.65
		sun.light_color = Color(1.0, 0.80, 0.52)
	elif map_name in ["canyon", "warzone", "desert_road", "desert_oasis"]:
		sun.rotation = Vector3(deg_to_rad(-13.0), deg_to_rad(-35.0), 0)
		sun.light_energy = 1.75
		sun.light_color = Color(1.0, 0.72, 0.38)
	else: # industrial and default
		sun.rotation = Vector3(deg_to_rad(-16.0), deg_to_rad(-42.0), 0)
		sun.light_energy = 1.65
		sun.light_color = Color(1.0, 0.76, 0.48)
		
	# Disable real-time shadow maps to isolate movement-dependent wall flicker.
	sun.shadow_enabled = false
	root.add_child(sun)
	
	if map_name == "arena":
		_add_arena_accents(root)

func _add_arena_accents(root: Node3D) -> void:
	var center_light := OmniLight3D.new()
	center_light.light_color = Color(1.0, 0.85, 0.6)
	center_light.light_energy = 2.5
	center_light.omni_range = 22.0
	center_light.position = Vector3(0, 3.8, 0)
	root.add_child(center_light)
	
	var lamp_points := [
		Vector3(-18, 3.2, 5), Vector3(-18, 3.2, -5),
		Vector3(18, 3.2, 5), Vector3(18, 3.2, -5),
		Vector3(0, 3.2, 18), Vector3(0, 3.2, -18)
	]
	for i in lamp_points.size():
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.82, 0.6) if i % 2 == 0 else Color(0.85, 0.88, 1.0)
		l.light_energy = 1.6
		l.omni_range = 14.0
		l.position = lamp_points[i]
		root.add_child(l)


func apply_time_of_day(preset: String) -> void:
	var profiles := {
		"dawn": [Color("536c96"), Color("deb598"), Color("ffd6ae"), -12.0, 1.1, 0.42],
		"noon": [Color("4f97d2"), Color("c7deeb"), Color("fff7e8"), -62.0, 1.35, 0.5],
		"dusk": [Color("344b76"), Color("d9a27a"), Color("ffc78e"), -16.0, 1.15, 0.38],
		"overcast": [Color("718395"), Color("cad1d8"), Color("e4e9ee"), -48.0, 0.95, 0.7]
	}
	var profile: Array = profiles.get("overcast" if preset == "night" else preset, profiles["noon"])
	for node in find_children("*", "WorldEnvironment", true, false):
		var environment: Environment = node.environment
		var sky := environment.sky.sky_material as ProceduralSkyMaterial
		if sky:
			sky.sky_top_color = profile[0]
			sky.sky_horizon_color = profile[1]
			sky.ground_horizon_color = (profile[1] as Color).darkened(0.45)
			sky.ground_bottom_color = (profile[0] as Color).darkened(0.65)
		environment.ambient_light_color = profile[1]
		environment.ambient_light_energy = profile[5]
		environment.fog_light_color = profile[1]
		environment.fog_density = 0.0006
	for node in find_children("*", "DirectionalLight3D", true, false):
		node.rotation_degrees.x = profile[3]
		node.light_color = profile[2]
		node.light_energy = profile[4]
