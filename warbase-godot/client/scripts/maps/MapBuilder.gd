class_name WarMapBuilder
extends Node3D
## Map assembly and shared daylight profiles for drone combat.

var spawn_points: Array[Vector3] = []
var _active_map := "industrial"

const JEEP_SCENE: PackedScene = preload("res://scenes/CombatJeep.tscn")

static var _sanitized_mat_cache: Dictionary = {}

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

func _build_shipment_collision(inst: Node3D) -> void:
	for body in inst.find_children("*", "StaticBody3D", true, false): body.free()
	
	var meshes: Array[MeshInstance3D] = []
	_find_mesh_instances(inst, meshes)
	
	for mi in meshes:
		var n := mi.name.to_lower()
		if n.begins_with("cargo"):
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
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.create_trimesh_collision()
		elif n.begins_with("wall"):
			mi.create_trimesh_collision()


const RESTORED_MAPS := ["dust2","nuketown","canyon","military_base","ghost_city"]
const MAP_GLBS := {
	"industrial":"res://assets/maps/low_poly_industrial_zone.glb",
	"resoforge":"res://assets/maps/resoforge_tdm.glb",
	"football":"res://assets/maps/football.glb",
	"village":"res://assets/maps/village_lowres.glb",
	"arena":"res://assets/maps/fps_shooter_game_arena_map_v3.glb",
	"shipment":"res://assets/maps/shipment.glb",
	"dust2":"res://assets/maps/restored/dust2.scn",
	"nuketown":"res://assets/maps/restored/nuketown.scn",
	"canyon":"res://assets/maps/restored/canyon.scn",
	"military_base":"res://assets/maps/restored/military_base.scn",
	"ghost_city":"res://assets/maps/restored/ghost_city.scn",
}

func _build_restored(root_node: Node3D, map_id: String) -> void:
	var scene: PackedScene = load(MAP_GLBS[map_id])
	if scene == null: push_error("Map resource unavailable: " + map_id); return
	var inst: Node3D = scene.instantiate();root_node.add_child(inst)
	_add_trimesh_collision(inst,true)
	_sanitize_glb_materials(inst)
	var authoring: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/restored-map-authoring.json"))
	var box:Array=authoring[map_id].bounds
	set_meta("tactical_bounds",AABB(Vector3(box[0],box[1],box[2]),Vector3(box[3],box[4],box[5])))
	for at: Array in authoring[map_id].spawns: spawn_points.append(Vector3(at[0],at[1],at[2]))
	_build_sky(root_node,map_id)
	apply_time_of_day(GameState.selected_time)
	for shape in inst.find_children("*","CollisionShape3D",true,false):
		if shape.shape is ConcavePolygonShape3D: shape.shape.backface_collision=true
	for light in root_node.find_children("*","Light3D",true,false):
		if not light is DirectionalLight3D: light.shadow_enabled=false

func build(map_name: String) -> Array[Vector3]:
	_active_map = map_name
	spawn_points.clear()
	_sanitized_mat_cache.clear()
	for c in get_children():
		c.queue_free()
	var root := Node3D.new()
	root.name = "MapRoot"
	add_child(root)
	if not MAP_GLBS.has(map_name):
		push_error("Unsupported map: " + map_name)
		return []
	if map_name in RESTORED_MAPS:
		_build_restored(root,map_name)
		return spawn_points
	var key := map_name
	
	var extent := 48.0
	var center := Vector3.ZERO
	
	if MAP_GLBS.has(key):
		var glb_path: String = MAP_GLBS[key]
		var glb: PackedScene = load(glb_path) as PackedScene
		if glb:
			var inst := glb.instantiate() as Node3D
			inst.name = "GLBMap"
			root.add_child(inst)
			if key == "resoforge": inst.scale = Vector3.ONE * 3.0
			
			if key == "shipment":
				_build_shipment_collision(inst)
				_sanitize_glb_materials(inst)

			# Shipment has authored primitive collision, so avoid replacing it with a full trimesh.
			if key != "shipment":
				_add_trimesh_collision(inst, key in ["resoforge", "football", "village"])
				_sanitize_glb_materials(inst)
			if key == "football": _theme_football(inst)
			
			# Fall-catcher safety barrier below map (deep safety net only if player clips out of bounds)
			var safety := StaticBody3D.new()
			safety.name = "SafetyFloor"
			var sc := CollisionShape3D.new()
			var sb := BoxShape3D.new()
			sb.size = Vector3(500,1.0,500)
			sc.shape = sb
			sc.position.y = -15.0
			safety.add_child(sc)
			root.add_child(safety)
			
			match key:
				"shipment":
					extent = 24.0
					center = Vector3.ZERO
					spawn_points = [
						Vector3(-19.2929, 0.08, -19.2929),
						Vector3(-17.5, 0.1296, -2.0),
						Vector3(-16.0, 0.08, 18.0),
						Vector3(-12.0, 0.08, 4.0),
						Vector3(-7.8087, 0.08, -19.5381),
						Vector3(-6.0, 0.08, 14.0),
						Vector3(-2.0, 0.1302, 16.0),
						Vector3(4.0, 0.08, -18.0),
						Vector3(8.0, 0.08, -10.0),
						Vector3(10.0, 0.08, 8.0),
						Vector3(14.0, 0.08, -16.0),
						Vector3(18.1913, 0.08, -19.5381),
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
					# Spawn jeeps in wide open road lanes with >10m clearance away from props & buildings
					_spawn_jeep(Vector3(35.0, 0.5, -20.0), 0.0, root)
					_spawn_jeep(Vector3(-35.0, 0.5, -20.0), PI, root)
					spawn_points = [
						Vector3(-14.0, 0.08, -8.0),
						Vector3(18.0, 0.08, 8.0),
						Vector3(-8.0, 0.08, -14.0),
						Vector3(8.0, 0.3506, 18.0),
						Vector3(-25.0, 0.08, 10.0),
						Vector3(25.0, 0.08, -10.0),
						Vector3(0.0, 0.08, -12.0),
						Vector3(0.0, 0.08, 12.0),
						Vector3(-13.6464, 0.3838, 16.3536),
						Vector3(14.0, 0.08, -16.0),
						Vector3(-6.0, 0.08, 2.0),
						Vector3(6.0, 0.08, -2.0),
					]
				"arena":
					extent = 36.0
					center = Vector3(-15.0, 0.0, -15.0)
					spawn_points = [
						Vector3(-25.5, 1.08, -3.0),
						Vector3(-26.0, 1.0799, -7.5),
						Vector3(-20.0, 1.0799, -3.0),
						Vector3(-20.0, 1.0799, -7.5),
						Vector3(-15.0, 1.0799, -3.0),
						Vector3(-15.0, 1.0799, -7.5),
						Vector3(-9.0, 1.0799, -3.0),
						Vector3(-9.0, 1.0799, -7.5),
						Vector3(-3.5, 1.08, -3.5),
						Vector3(-4.3827, 1.0799, -7.4239),
						Vector3(-14.8087, 1.08, -4.5381),
						Vector3(-21.8087, 1.08, -4.5381),
					]
	_build_sky(root, key)
	apply_time_of_day(GameState.selected_time)
	for collider in find_children("*", "CollisionShape3D", true, false):
		if collider.shape is ConcavePolygonShape3D: collider.shape.backface_collision = true
	for light in find_children("*", "Light3D", true, false):
		if not light is DirectionalLight3D: light.shadow_enabled = false
	return spawn_points

func _sanitize_glb_materials(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		for surface in node.mesh.get_surface_count():
			var original: Material = node.get_active_material(surface)
			if original is StandardMaterial3D:
				var key := original.get_instance_id()
				if not _sanitized_mat_cache.has(key):
					var material: StandardMaterial3D = original.duplicate()
					material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
					material.cull_mode=BaseMaterial3D.CULL_DISABLED
					_sanitized_mat_cache[key]=material
				node.set_surface_override_material(surface,_sanitized_mat_cache[key])
	for child in node.get_children(): _sanitize_glb_materials(child)

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
		# Alpine Natural Daylight
		pm.sky_top_color = Color(0.24, 0.34, 0.46)
		pm.sky_horizon_color = Color(0.70, 0.74, 0.78)
		pm.ground_horizon_color = Color(0.40, 0.42, 0.40)
		pm.ground_bottom_color = Color(0.12, 0.12, 0.10)
		pm.sun_angle_max = 32.0
		pm.sun_curve = 0.08
	elif map_name == "arena":
		# Tactical Stadium Overcast
		pm.sky_top_color = Color(0.26, 0.32, 0.40)
		pm.sky_horizon_color = Color(0.68, 0.71, 0.74)
		pm.ground_horizon_color = Color(0.36, 0.37, 0.38)
		pm.ground_bottom_color = Color(0.10, 0.10, 0.11)
		pm.sun_angle_max = 28.0
		pm.sun_curve = 0.10
	elif map_name in ["dust2", "warzone", "desert_road", "canyon", "desert_oasis"]:
		# Arid Cinematic Desert (Muted sand haze, desaturated sky)
		pm.sky_top_color = Color(0.25, 0.36, 0.48)
		pm.sky_horizon_color = Color(0.76, 0.73, 0.68)
		pm.ground_horizon_color = Color(0.50, 0.46, 0.40)
		pm.ground_bottom_color = Color(0.14, 0.12, 0.10)
		pm.sun_angle_max = 36.0
		pm.sun_curve = 0.07
	elif map_name == "shipment":
		# Coastal Harbor Slate Overcast
		pm.sky_top_color = Color(0.25, 0.31, 0.38)
		pm.sky_horizon_color = Color(0.66, 0.70, 0.73)
		pm.ground_horizon_color = Color(0.34, 0.35, 0.36)
		pm.ground_bottom_color = Color(0.10, 0.10, 0.11)
		pm.sun_angle_max = 28.0
		pm.sun_curve = 0.10
	elif map_name == "nuketown":
		# Subdued Suburban Daylight
		pm.sky_top_color = Color(0.26, 0.36, 0.48)
		pm.sky_horizon_color = Color(0.72, 0.75, 0.76)
		pm.ground_horizon_color = Color(0.44, 0.43, 0.40)
		pm.ground_bottom_color = Color(0.11, 0.11, 0.10)
		pm.sun_angle_max = 32.0
		pm.sun_curve = 0.08
	else:
		# Industrial & Default Metropolis
		pm.sky_top_color = Color(0.25, 0.34, 0.45)
		pm.sky_horizon_color = Color(0.71, 0.74, 0.77)
		pm.ground_horizon_color = Color(0.38, 0.39, 0.39)
		pm.ground_bottom_color = Color(0.11, 0.11, 0.12)
		pm.sun_angle_max = 32.0
		pm.sun_curve = 0.08
		
	sky.sky_material = pm
	env.sky = sky
	
	# Film-grade Ambient Lighting: Natural sky bounce fill
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.65
	env.ambient_light_color = Color(0.55, 0.58, 0.62)
	env.ambient_light_energy = 0.65
	
	# Sky reflections for authentic metallic surfaces (guns, steel silos, vehicle panels)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	
	# Film-grade ACES Tonemapper with warm cinematic contrast
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.02
	env.tonemap_white = 5.8
	
	# Cinema Color Grading Adjustments (Harmonized, desaturated film stock)
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.88
	env.adjustment_contrast = 1.10
	env.adjustment_brightness = 1.02
	
	# Screen Space Ambient Occlusion for grounded contact shadows under vehicles & structures
	var is_desktop := not OS.has_feature("web")
	var quality: String = GameState.graphics_quality if GameState != null else "high"
	env.ssao_enabled = is_desktop and quality != "low"
	env.ssao_radius = 1.25
	env.ssao_intensity = 1.75
	env.ssao_power = 1.35
	env.ssao_detail = 0.5
	env.ssao_horizon = 0.06
	
	# Screen Space Indirect Lighting (Fast diffuse bounce) - Gated to ultra to eliminate compute thermal load
	env.ssil_enabled = is_desktop and quality in ["ultra"]
	env.ssil_radius = 2.4
	env.ssil_intensity = 0.55
	
	# Screen Space Reflections (Glossy metal armor & wet road reflections) - Gated to ultra to keep GPU cool
	env.ssr_enabled = is_desktop and quality in ["ultra"]
	env.ssr_max_steps = 32
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 1.8
	env.ssr_depth_tolerance = 0.25
	
	# SDFGI: Real-Time Ray-Marched Global Illumination
	if is_desktop and quality in ["ultra"]:
		env.sdfgi_enabled = true
		env.sdfgi_use_occlusion = true
		env.sdfgi_bounce_feedback = 0.45
		env.sdfgi_cascades = 4
		env.sdfgi_min_cell_size = 0.35
		env.sdfgi_cascade0_distance = 14.0
		env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	
	# Subtle Tactical Evening Bloom (Sun specular glints, vehicle headlights, muzzle flashes)
	env.glow_enabled = is_desktop
	env.glow_normalized = true
	env.glow_intensity = 0.20
	env.glow_bloom = 0.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.05
	
	# Cohesive Natural Atmospheric Fog (Matches horizon sky color)
	env.fog_enabled = true
	if map_name in ["dust2", "warzone", "desert_road", "canyon", "desert_oasis"]:
		env.fog_light_color = Color(0.74, 0.72, 0.68)
		env.fog_density = 0.0005 if map_name == "canyon" else 0.00075
	elif map_name == "arena":
		env.fog_light_color = Color(0.68, 0.71, 0.74)
		env.fog_density = 0.0008
	elif map_name == "shipment":
		env.fog_light_color = Color(0.66, 0.70, 0.73)
		env.fog_density = 0.0008
	else:
		env.fog_light_color = Color(0.71, 0.74, 0.77)
		env.fog_density = 0.00065
	env.fog_light_energy = 0.55
	env.fog_aerial_perspective = 0.70
	
	# 3D Froxel Ray-Marched Volumetric Fog (God rays piercing through cranes & structures)
	if is_desktop and quality in ["ultra"]:
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.0065
		env.volumetric_fog_albedo = env.fog_light_color
		env.volumetric_fog_emission_energy = 0.04
		env.volumetric_fog_anisotropy = 0.35
		env.volumetric_fog_temporal_reprojection_enabled = true
		env.volumetric_fog_temporal_reprojection_amount = 0.92
		env.volumetric_fog_ambient_inject = 0.15
	
	var hemi := WorldEnvironment.new()
	hemi.environment = env
	root.add_child(hemi)
	
	# Directional Sunlight: Natural daylight (5600K-5800K), soft balanced warm white
	var sun := DirectionalLight3D.new()
	if map_name == "village":
		sun.rotation = Vector3(deg_to_rad(-18.0), deg_to_rad(52.0), 0)
		sun.light_energy = 1.45
		sun.light_color = Color(1.0, 0.97, 0.92)
	elif map_name == "arena":
		sun.rotation = Vector3(deg_to_rad(-24.0), deg_to_rad(-120.0), 0)
		sun.light_energy = 1.35
		sun.light_color = Color(0.98, 0.98, 1.0)
	elif map_name == "city":
		sun.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(-55.0), 0)
		sun.light_energy = 1.45
		sun.light_color = Color(1.0, 0.97, 0.92)
	elif map_name == "dust2":
		sun.rotation = Vector3(deg_to_rad(-22.0), deg_to_rad(-48.0), 0)
		sun.light_energy = 1.50
		sun.light_color = Color(1.0, 0.96, 0.90)
	elif map_name == "nuketown":
		sun.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(38.0), 0)
		sun.light_energy = 1.45
		sun.light_color = Color(1.0, 0.97, 0.92)
	elif map_name in ["canyon", "warzone", "desert_road", "desert_oasis"]:
		sun.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(-35.0), 0)
		sun.light_energy = 1.50
		sun.light_color = Color(1.0, 0.96, 0.90)
	else: # industrial and default
		sun.rotation = Vector3(deg_to_rad(-22.0), deg_to_rad(-42.0), 0)
		sun.light_energy = 1.45
		sun.light_color = Color(1.0, 0.97, 0.92)
		
	# Cascaded PCSS Soft Directional Shadows
	sun.shadow_enabled = is_desktop and map_name != "football" and quality != "low"
	sun.directional_shadow_max_distance = 65.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.50
	sun.directional_shadow_fade_start = 0.8
	sun.shadow_bias = 0.02
	sun.shadow_normal_bias = 1.6
	sun.shadow_opacity = 0.88
	sun.shadow_blur = 1.2
	root.add_child(sun)
	
	if map_name == "arena":
		_add_arena_accents(root)

func _add_arena_accents(root: Node3D) -> void:
	var center_light := OmniLight3D.new()
	center_light.light_color = Color(1.0, 0.96, 0.90)
	center_light.light_energy = 2.0
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
		l.light_color = Color(0.96, 0.98, 1.0)
		l.light_energy = 1.2
		l.omni_range = 14.0
		l.position = lamp_points[i]
		root.add_child(l)


func apply_time_of_day(preset: String) -> void:
	var profiles := {
		"dawn": [Color(0.28, 0.35, 0.45), Color(0.72, 0.71, 0.69), Color(0.98, 0.94, 0.88), -14.0, 1.20, 0.50],
		"noon": [Color(0.26, 0.38, 0.52), Color(0.72, 0.77, 0.81), Color(1.0, 0.98, 0.94), -58.0, 1.40, 0.55],
		"dusk": [Color(0.22, 0.26, 0.36), Color(0.76, 0.62, 0.50), Color(1.0, 0.90, 0.78), -16.0, 1.25, 0.48],
		"overcast": [Color(0.40, 0.46, 0.52), Color(0.70, 0.74, 0.78), Color(0.95, 0.97, 0.99), -46.0, 1.10, 0.72]
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
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		environment.ambient_light_sky_contribution = 0.65
		environment.ambient_light_color = profile[1]
		environment.ambient_light_energy = profile[5]
		var arid := _active_map in ["dust2", "canyon"]
		var haze_color: Color = profile[1]
		if arid: haze_color = haze_color.lerp(Color("7a7368"), 0.16)
		environment.fog_light_color = haze_color
		# Distance haze follows weather while preserving foreground target contrast.
		environment.fog_density = 0.0008 if preset == "overcast" else (0.0006 if preset in ["dawn", "dusk"] else 0.00030)
		environment.fog_density *= 1.25 if arid else (0.7 if _active_map == "football" else 1.0)
		environment.fog_sun_scatter = 0.12 if preset == "overcast" else 0.30
		environment.fog_light_energy = 0.60
		if environment.volumetric_fog_enabled:
			environment.volumetric_fog_albedo = haze_color
			environment.volumetric_fog_density = 0.009 if preset == "overcast" else (0.007 if preset in ["dawn", "dusk"] else 0.004)
		environment.tonemap_mode = Environment.TONE_MAPPER_ACES
		environment.tonemap_exposure = 1.02
		environment.tonemap_white = 5.8
		environment.adjustment_enabled = true
		environment.adjustment_saturation = 0.88
		environment.adjustment_contrast = 1.10
		environment.adjustment_brightness = 1.02
		environment.glow_hdr_threshold = 1.1
	for node in find_children("*", "DirectionalLight3D", true, false):
		node.rotation_degrees.x = profile[3]
		node.light_color = profile[2]
		node.light_energy = profile[4]
