extends SceneTree
## Procedural AAA Map Generator for WarBase Drone Warfare:
## 1. "cosmodrome" — Titan Orbital Launch Facility & Subterranean Flame Trench
## 2. "dam"        — Black Rock Hydro Dam & Canyon Gorge
## 3. "skyline"    — Neo Skyline Twin Skyscraper Metropolis & Skybridges

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("--- GENERATING AAA DRONE WARFARE MAPS ---")
	generate_cosmodrome()
	generate_dam()
	generate_skyline()
	print("--- ALL 3 MAPS GENERATED SUCCESSFULLY ---")
	quit(0)

# Helper for PBR materials
func create_mat(albedo: Color, rough: float = 0.7, metal: float = 0.0, emit: Color = Color.BLACK, emit_energy: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = rough
	mat.metallic = metal
	if emit != Color.BLACK and emit_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emit
		mat.emission_energy_multiplier = emit_energy
	return mat

# Helper to create a MeshInstance3D box
func add_box(parent: Node, name: String, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	if mat: mi.material_override = mat
	mi.position = pos
	if rot != Vector3.ZERO:
		mi.rotation = rot
	parent.add_child(mi)
	return mi

# Helper to create a MeshInstance3D cylinder
func add_cylinder(parent: Node, name: String, radius: float, height: float, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 16
	mi.mesh = cm
	if mat: mi.material_override = mat
	mi.position = pos
	if rot != Vector3.ZERO:
		mi.rotation = rot
	parent.add_child(mi)
	return mi

# Helper to create a MeshInstance3D sphere
func add_sphere(parent: Node, name: String, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	if mat: mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

# ==============================================================================
# MAP 1: COSMODROME (Titan Orbital Launch Facility)
# ==============================================================================
func generate_cosmodrome() -> void:
	print("Building Cosmodrome...")
	var root := Node3D.new()
	root.name = "CosmodromeMap"

	# Materials
	var mat_tarmac := create_mat(Color(0.24, 0.25, 0.26), 0.88, 0.05)
	var mat_concrete := create_mat(Color(0.68, 0.67, 0.65), 0.82, 0.0)
	var mat_concrete_dark := create_mat(Color(0.45, 0.44, 0.42), 0.85, 0.0)
	var mat_gantry_steel := create_mat(Color(0.82, 0.24, 0.14), 0.40, 0.65) # Aerospace Orange
	var mat_rocket_white := create_mat(Color(0.92, 0.94, 0.96), 0.25, 0.85)
	var mat_rocket_black := create_mat(Color(0.12, 0.12, 0.14), 0.50, 0.40)
	var mat_tank_white := create_mat(Color(0.86, 0.88, 0.90), 0.35, 0.20)
	var mat_pipe_steel := create_mat(Color(0.55, 0.58, 0.62), 0.30, 0.80)
	var mat_hazard := create_mat(Color(0.90, 0.75, 0.15), 0.60, 0.10)
	var mat_beacon_red := create_mat(Color(1.0, 0.1, 0.1), 0.20, 0.0, Color(1.0, 0.05, 0.05), 4.5)
	var mat_beacon_green := create_mat(Color(0.1, 1.0, 0.3), 0.20, 0.0, Color(0.1, 1.0, 0.3), 3.5)

	# 1. Main Launch Apron Tarmac (180m x 180m at Y=0.0)
	add_box(root, "Tarmac_South", Vector3(180, 0.3, 70), Vector3(0, 0, 45), mat_tarmac)
	add_box(root, "Tarmac_North", Vector3(180, 0.3, 70), Vector3(0, 0, -45), mat_tarmac)
	add_box(root, "Tarmac_East", Vector3(70, 0.3, 40), Vector3(55, 0, 0), mat_tarmac)
	add_box(root, "Tarmac_West", Vector3(70, 0.3, 40), Vector3(-55, 0, 0), mat_tarmac)

	# 2. Flame Exhaust Trench (running North-South under the launch table from Z=-45 to Z=+45)
	# Trench floor at Y = -7.0m, depth = 7m, width = 18m
	add_box(root, "Trench_Floor", Vector3(18, 0.4, 90), Vector3(0, -7.0, 0), mat_concrete_dark)
	add_box(root, "Trench_Wall_W", Vector3(2, 7.5, 90), Vector3(-10, -3.4, 0), mat_concrete)
	add_box(root, "Trench_Wall_E", Vector3(2, 7.5, 90), Vector3(10, -3.4, 0), mat_concrete)
	# Trench access ramps on North and South ends (slope from Y=0.15 down to Y=-7.0 over 20m)
	add_box(root, "Trench_Ramp_S", Vector3(16, 0.4, 21), Vector3(0, -3.5, 45), mat_concrete_dark, Vector3(deg_to_rad(-19.0), 0, 0))
	add_box(root, "Trench_Ramp_N", Vector3(16, 0.4, 21), Vector3(0, -3.5, -45), mat_concrete_dark, Vector3(deg_to_rad(19.0), 0, 0))
	# Central Flame Deflector Wedge (double 35 deg wedge at Z=0)
	add_box(root, "Deflector_S", Vector3(16, 0.6, 12), Vector3(0, -4.5, 4.5), mat_pipe_steel, Vector3(deg_to_rad(-35.0), 0, 0))
	add_box(root, "Deflector_N", Vector3(16, 0.6, 12), Vector3(0, -4.5, -4.5), mat_pipe_steel, Vector3(deg_to_rad(35.0), 0, 0))

	# 3. Elevated Launch Table (Center X=0, Z=0, Top surface Y=9.0)
	# 4 Corner support pillars (each 6m x 6m x 9m)
	add_box(root, "Pillar_SW", Vector3(6, 9.0, 6), Vector3(-15, 4.5, 15), mat_concrete)
	add_box(root, "Pillar_SE", Vector3(6, 9.0, 6), Vector3(15, 4.5, 15), mat_concrete)
	add_box(root, "Pillar_NW", Vector3(6, 9.0, 6), Vector3(-15, 4.5, -15), mat_concrete)
	add_box(root, "Pillar_NE", Vector3(6, 9.0, 6), Vector3(15, 4.5, -15), mat_concrete)
	# Launch Table Decks (leaving central 18m exhaust hole)
	add_box(root, "Deck_West", Vector3(10, 1.2, 38), Vector3(-14, 8.4, 0), mat_concrete)
	add_box(root, "Deck_East", Vector3(10, 1.2, 38), Vector3(14, 8.4, 0), mat_concrete)
	add_box(root, "Deck_South", Vector3(18, 1.2, 10), Vector3(0, 8.4, 14), mat_concrete)
	add_box(root, "Deck_North", Vector3(18, 1.2, 10), Vector3(0, 8.4, -14), mat_concrete)
	# 4 Corner vehicle/personnel ramps up to the launch table (from Y=0.15 to Y=9.0)
	add_box(root, "Ramp_SE", Vector3(5, 0.4, 25), Vector3(21, 4.5, 16), mat_concrete_dark, Vector3(deg_to_rad(21.0), 0, 0))
	add_box(root, "Ramp_SW", Vector3(5, 0.4, 25), Vector3(-21, 4.5, 16), mat_concrete_dark, Vector3(deg_to_rad(21.0), 0, 0))
	add_box(root, "Ramp_NE", Vector3(5, 0.4, 25), Vector3(21, 4.5, -16), mat_concrete_dark, Vector3(deg_to_rad(-21.0), 0, 0))
	add_box(root, "Ramp_NW", Vector3(5, 0.4, 25), Vector3(-21, 4.5, -16), mat_concrete_dark, Vector3(deg_to_rad(-21.0), 0, 0))

	# 4. Giant Orbital Rocket (Centered at X=0, Z=0, standing from Y=9.0 to Y=68.0)
	# Central Core Booster
	add_cylinder(root, "Rocket_Core", 3.2, 44.0, Vector3(0, 31.0, 0), mat_rocket_white)
	# Interstage / engine skirt
	add_cylinder(root, "Rocket_Skirt", 3.4, 4.0, Vector3(0, 11.0, 0), mat_rocket_black)
	add_cylinder(root, "Rocket_Interstage", 3.3, 3.0, Vector3(0, 38.0, 0), mat_rocket_black)
	# Nose fairing cone
	add_cylinder(root, "Rocket_Fairing", 3.0, 12.0, Vector3(0, 58.0, 0), mat_rocket_white)
	# 4 Strap-on Boosters
	add_cylinder(root, "Booster_E", 1.4, 28.0, Vector3(4.2, 23.0, 0), mat_rocket_white)
	add_cylinder(root, "Booster_W", 1.4, 28.0, Vector3(-4.2, 23.0, 0), mat_rocket_white)
	add_cylinder(root, "Booster_N", 1.4, 28.0, Vector3(0, 23.0, -4.2), mat_rocket_white)
	add_cylinder(root, "Booster_S", 1.4, 28.0, Vector3(0, 23.0, 4.2), mat_rocket_white)

	# 5. Launch Umbilical Service Gantry (Steel lattice tower at X=15, Z=0, height 62m)
	# 4 Gantry Corner Legs
	add_box(root, "Gantry_Leg_NW", Vector3(1.2, 60.0, 1.2), Vector3(12.0, 39.0, -3.5), mat_gantry_steel)
	add_box(root, "Gantry_Leg_NE", Vector3(1.2, 60.0, 1.2), Vector3(18.0, 39.0, -3.5), mat_gantry_steel)
	add_box(root, "Gantry_Leg_SW", Vector3(1.2, 60.0, 1.2), Vector3(12.0, 39.0, 3.5), mat_gantry_steel)
	add_box(root, "Gantry_Leg_SE", Vector3(1.2, 60.0, 1.2), Vector3(18.0, 39.0, 3.5), mat_gantry_steel)
	# Gantry Cross Decks & Walkways
	for y_level in [18.0, 28.0, 38.0, 48.0, 58.0, 68.0]:
		add_box(root, "Gantry_Deck_%d" % int(y_level), Vector3(8.0, 0.8, 8.5), Vector3(15.0, y_level, 0), mat_gantry_steel)
	# Swing-away Umbilical Arms (connecting gantry to rocket at Y=28, Y=44, Y=56)
	add_box(root, "Umbilical_Arm_1", Vector3(12.0, 1.0, 1.2), Vector3(8.0, 24.0, 0), mat_gantry_steel)
	add_box(root, "Umbilical_Arm_2", Vector3(12.0, 1.0, 1.2), Vector3(8.0, 40.0, 0), mat_gantry_steel)
	add_box(root, "Umbilical_Arm_3", Vector3(12.0, 1.0, 1.2), Vector3(8.0, 52.0, 0), mat_gantry_steel)
	# Top Crane Jib & Lightning Mast
	add_box(root, "Gantry_Crane_Boom", Vector3(20.0, 1.2, 1.4), Vector3(12.0, 70.0, 0), mat_gantry_steel)
	add_cylinder(root, "Lightning_Mast", 0.3, 12.0, Vector3(15.0, 75.0, 0), mat_pipe_steel)
	add_sphere(root, "Aviation_Beacon", 0.6, Vector3(15.0, 81.2, 0), mat_beacon_red)

	# 6. Cryogenic Storage Tank Farm (West Sector, X=-46, Z=0)
	# 4 Giant Spherical Pressure Vessels
	add_sphere(root, "Cryo_Sphere_1", 5.2, Vector3(-46.0, 6.5, -12.0), mat_tank_white)
	add_sphere(root, "Cryo_Sphere_2", 5.2, Vector3(-46.0, 6.5, 12.0), mat_tank_white)
	add_sphere(root, "Cryo_Sphere_3", 4.2, Vector3(-60.0, 5.5, -6.0), mat_tank_white)
	add_sphere(root, "Cryo_Sphere_4", 4.2, Vector3(-60.0, 5.5, 6.0), mat_tank_white)
	# Tank support pedestals
	add_cylinder(root, "Cryo_Ped_1", 3.2, 3.0, Vector3(-46.0, 1.5, -12.0), mat_concrete)
	add_cylinder(root, "Cryo_Ped_2", 3.2, 3.0, Vector3(-46.0, 1.5, 12.0), mat_concrete)
	# Cryo Pipe Bridge (running from tanks toward launch table)
	add_box(root, "Pipe_Bridge_H", Vector3(28.0, 0.8, 1.4), Vector3(-32.0, 6.0, 0), mat_pipe_steel)
	add_cylinder(root, "Pipe_Pylon_1", 0.4, 6.0, Vector3(-32.0, 3.0, 0), mat_pipe_steel)
	add_cylinder(root, "Pipe_Pylon_2", 0.4, 6.0, Vector3(-22.0, 3.0, 0), mat_pipe_steel)

	# 7. Telemetry Tracking Radar (North-East X=42, Z=-42)
	add_cylinder(root, "Radar_Base", 4.5, 6.0, Vector3(42.0, 3.0, -42.0), mat_concrete)
	add_cylinder(root, "Radar_Yoke", 1.8, 4.0, Vector3(42.0, 8.0, -42.0), mat_pipe_steel)
	add_cylinder(root, "Radar_Dish", 7.5, 0.6, Vector3(42.0, 12.0, -42.0), mat_tank_white, Vector3(deg_to_rad(45.0), 0, deg_to_rad(25.0)))
	add_sphere(root, "Radar_Beacon", 0.4, Vector3(42.0, 16.5, -42.0), mat_beacon_green)

	# 8. Command Control Bunker (South-West X=-42, Z=42)
	add_box(root, "Bunker_Main", Vector3(20.0, 4.5, 18.0), Vector3(-42.0, 2.25, 42.0), mat_concrete)
	# Sloped blast roof & parapet
	add_box(root, "Bunker_Roof", Vector3(21.0, 0.6, 19.0), Vector3(-42.0, 4.6, 42.0), mat_concrete_dark)
	# Armored blast blast door frame
	add_box(root, "Bunker_Blast_Door", Vector3(4.0, 3.0, 0.8), Vector3(-32.0, 1.5, 42.0), mat_hazard)

	# 9. Perimeter Blast Barrier Walls & Light Masts
	add_box(root, "Wall_North", Vector3(180.0, 4.0, 2.0), Vector3(0, 2.0, -80.0), mat_concrete)
	add_box(root, "Wall_South", Vector3(180.0, 4.0, 2.0), Vector3(0, 2.0, 80.0), mat_concrete)
	add_box(root, "Wall_West", Vector3(2.0, 4.0, 160.0), Vector3(-80.0, 2.0, 0), mat_concrete)
	add_box(root, "Wall_East", Vector3(2.0, 4.0, 160.0), Vector3(80.0, 2.0, 0), mat_concrete)

	save_map_scene(root, "res://assets/maps/cosmodrome.scn")

# ==============================================================================
# MAP 2: DAM (Black Rock Hydroelectric Mega-Dam)
# ==============================================================================
func generate_dam() -> void:
	print("Building Dam...")
	var root := Node3D.new()
	root.name = "DamMap"

	# Materials
	var mat_granite := create_mat(Color(0.38, 0.36, 0.34), 0.95, 0.0)
	var mat_dam_face := create_mat(Color(0.64, 0.62, 0.60), 0.85, 0.0)
	var mat_road := create_mat(Color(0.22, 0.23, 0.25), 0.90, 0.02)
	var mat_concrete := create_mat(Color(0.58, 0.57, 0.55), 0.82, 0.0)
	var mat_steel_pipe := create_mat(Color(0.32, 0.35, 0.38), 0.40, 0.75)
	var mat_water := create_mat(Color(0.08, 0.28, 0.35), 0.15, 0.4)
	var mat_beacon_red := create_mat(Color(1.0, 0.1, 0.1), 0.20, 0.0, Color(1.0, 0.05, 0.05), 4.5)
	var mat_beacon_amber := create_mat(Color(1.0, 0.65, 0.1), 0.20, 0.0, Color(1.0, 0.6, 0.05), 3.5)

	# 1. Riverbed Floor & Canyon Bottom (Z > 10, Y = 0.0)
	add_box(root, "Riverbed", Vector3(120, 0.3, 80), Vector3(0, 0, 50), mat_granite)
	# Reservoir Water Surface (North sector Z < 0, Y = 34.0)
	add_box(root, "Reservoir_Water", Vector3(120, 0.4, 70), Vector3(0, 34.0, -45), mat_water)

	# 2. Canyon Rock Cliff Walls (East at X=+60, West at X=-60, Height 46m)
	# West Mountain Wall
	add_box(root, "Cliff_West_Lower", Vector3(30, 24.0, 160), Vector3(-65, 12.0, 0), mat_granite)
	add_box(root, "Cliff_West_Upper", Vector3(25, 24.0, 160), Vector3(-68, 36.0, 0), mat_granite)
	# East Mountain Wall
	add_box(root, "Cliff_East_Lower", Vector3(30, 24.0, 160), Vector3(65, 12.0, 0), mat_granite)
	add_box(root, "Cliff_East_Upper", Vector3(25, 24.0, 160), Vector3(68, 36.0, 0), mat_granite)

	# 3. Monolithic Dam Wall Structure (Spanning X=-50 to X=+50 at Z=0 to Z=16)
	# Main curved monolithic concrete face (40m high, 100m wide)
	add_box(root, "Dam_Base_Block", Vector3(100, 38.0, 18), Vector3(0, 19.0, 8), mat_dam_face)
	# Angled Downstream Spillway Face (slope 40 deg from Y=38 down to Y=2 over 25m)
	add_box(root, "Spillway_Slope_W", Vector3(32, 1.5, 36), Vector3(-25, 18.0, 22), mat_dam_face, Vector3(deg_to_rad(-42.0), 0, 0))
	add_box(root, "Spillway_Slope_E", Vector3(32, 1.5, 36), Vector3(25, 18.0, 22), mat_dam_face, Vector3(deg_to_rad(-42.0), 0, 0))
	add_box(root, "Spillway_Chute_Center", Vector3(26, 1.5, 38), Vector3(0, 18.0, 22), mat_concrete, Vector3(deg_to_rad(-42.0), 0, 0))

	# 4. Upper Dam Crest Roadway (2-lane highway spanning gorge at Y=38.0, top surface Y=38.15)
	add_box(root, "Dam_Crest_Road", Vector3(100, 0.4, 12), Vector3(0, 38.0, 0), mat_road)
	# Roadside Safety Parapets / Barriers
	add_box(root, "Parapet_Downstream", Vector3(100, 1.2, 0.6), Vector3(0, 38.8, 6.0), mat_concrete)
	add_box(root, "Parapet_Upstream", Vector3(100, 1.2, 0.6), Vector3(0, 38.8, -6.0), mat_concrete)
	# Road Light Posts with glowing beacons
	for x_pos in [-40.0, -20.0, 0.0, 20.0, 40.0]:
		add_cylinder(root, "Light_Pole_%d" % int(x_pos), 0.15, 5.0, Vector3(x_pos, 40.5, 5.8), mat_steel_pipe)
		add_sphere(root, "Light_Beacon_%d" % int(x_pos), 0.35, Vector3(x_pos, 43.2, 5.8), mat_beacon_amber)

	# 5. Turbine Generator Powerhouse (Canyon base Z=38, Y=0 to Y=12)
	add_box(root, "Powerhouse_Main", Vector3(44, 10.0, 22), Vector3(0, 5.0, 38), mat_concrete)
	# Powerhouse Flat Roof with 2 Open Drone Skylights / Ingress Shafts
	add_box(root, "Powerhouse_Roof_W", Vector3(14, 0.8, 22), Vector3(-15, 10.4, 38), mat_dam_face)
	add_box(root, "Powerhouse_Roof_E", Vector3(14, 0.8, 22), Vector3(15, 10.4, 38), mat_dam_face)
	add_box(root, "Powerhouse_Roof_Mid", Vector3(44, 0.8, 6), Vector3(0, 10.4, 38), mat_dam_face)
	# Interior turbine generator cylinders
	add_cylinder(root, "Turbine_Gen_1", 3.0, 4.0, Vector3(-10, 2.0, 38), mat_steel_pipe)
	add_cylinder(root, "Turbine_Gen_2", 3.0, 4.0, Vector3(0, 2.0, 38), mat_steel_pipe)
	add_cylinder(root, "Turbine_Gen_3", 3.0, 4.0, Vector3(10, 2.0, 38), mat_steel_pipe)

	# 6. Giant Penstock Steel Pipes (Descending dam face into powerhouse)
	for x_pipe in [-10.0, 0.0, 10.0]:
		add_cylinder(root, "Penstock_%d" % int(x_pipe), 1.8, 34.0, Vector3(x_pipe, 18.0, 18), mat_steel_pipe, Vector3(deg_to_rad(-45.0), 0, 0))

	# 7. Reservoir Intake Towers (North sector Z=-24, Y=34 to Y=42)
	add_cylinder(root, "Intake_Tower_W", 4.5, 14.0, Vector3(-16.0, 38.0, -22.0), mat_concrete)
	add_cylinder(root, "Intake_Tower_E", 4.5, 14.0, Vector3(16.0, 38.0, -22.0), mat_concrete)
	# Walkway Bridges connecting intake towers to the dam crest
	add_box(root, "Intake_Bridge_W", Vector3(2.5, 0.6, 16.0), Vector3(-16.0, 38.2, -14.0), mat_concrete)
	add_box(root, "Intake_Bridge_E", Vector3(2.5, 0.6, 16.0), Vector3(16.0, 38.2, -14.0), mat_concrete)
	add_sphere(root, "Intake_Beacon_W", 0.5, Vector3(-16.0, 45.5, -22.0), mat_beacon_red)
	add_sphere(root, "Intake_Beacon_E", 0.5, Vector3(16.0, 45.5, -22.0), mat_beacon_red)

	# 8. High-Voltage Transformer Switchyard (East Canyon Floor X=36, Z=58)
	add_box(root, "Substation_Pad", Vector3(20, 0.4, 24), Vector3(36, 0.2, 58), mat_concrete)
	add_box(root, "Transformer_1", Vector3(4, 4.0, 4), Vector3(32, 2.2, 54), mat_steel_pipe)
	add_box(root, "Transformer_2", Vector3(4, 4.0, 4), Vector3(32, 2.2, 62), mat_steel_pipe)
	add_box(root, "Transformer_3", Vector3(4, 4.0, 4), Vector3(40, 2.2, 58), mat_steel_pipe)

	save_map_scene(root, "res://assets/maps/dam.scn")

# ==============================================================================
# MAP 3: SKYLINE (Neo Skyline Cyber Metropolis)
# ==============================================================================
func generate_skyline() -> void:
	print("Building Skyline...")
	var root := Node3D.new()
	root.name = "SkylineMap"

	# Materials
	var mat_street := create_mat(Color(0.18, 0.19, 0.20), 0.90, 0.05)
	var mat_plaza := create_mat(Color(0.60, 0.62, 0.64), 0.70, 0.10)
	var mat_tower_steel := create_mat(Color(0.20, 0.22, 0.26), 0.35, 0.85)
	var mat_tower_glass := create_mat(Color(0.08, 0.18, 0.28), 0.15, 0.90)
	var mat_skybridge := create_mat(Color(0.25, 0.28, 0.32), 0.30, 0.80)
	var mat_crane_yellow := create_mat(Color(0.95, 0.75, 0.10), 0.45, 0.30)
	var mat_concrete := create_mat(Color(0.55, 0.54, 0.52), 0.85, 0.0)
	var mat_neon_cyan := create_mat(Color(0.0, 0.85, 1.0), 0.15, 0.0, Color(0.0, 0.85, 1.0), 4.5)
	var mat_neon_magenta := create_mat(Color(1.0, 0.08, 0.65), 0.15, 0.0, Color(1.0, 0.08, 0.65), 4.5)
	var mat_beacon_red := create_mat(Color(1.0, 0.1, 0.1), 0.20, 0.0, Color(1.0, 0.05, 0.05), 4.5)

	# 1. Ground Street Level & Plazas (Y = 0.0, top surface Y = 0.15)
	# Street Plaza West (X < -10)
	add_box(root, "Plaza_West", Vector3(65, 0.3, 160), Vector3(-45, 0, 0), mat_plaza)
	# Street Plaza East (X > 10)
	add_box(root, "Plaza_East", Vector3(65, 0.3, 160), Vector3(45, 0, 0), mat_plaza)
	# North & South Cross Plazas (crossing over highway)
	add_box(root, "Plaza_North", Vector3(25, 0.3, 30), Vector3(0, 0, -65), mat_street)
	add_box(root, "Plaza_South", Vector3(25, 0.3, 30), Vector3(0, 0, 65), mat_street)

	# 2. Sunken Transit Highway Underpass (running North-South along Z from Z=-50 to Z=+50)
	# Depth = 6m, floor at Y = -6.0m, width = 18m
	add_box(root, "Underpass_Floor", Vector3(18, 0.4, 100), Vector3(0, -6.0, 0), mat_street)
	add_box(root, "Underpass_Wall_W", Vector3(2, 6.5, 100), Vector3(-10, -2.8, 0), mat_concrete)
	add_box(root, "Underpass_Wall_E", Vector3(2, 6.5, 100), Vector3(10, -2.8, 0), mat_concrete)
	# Highway access ramps on North and South
	add_box(root, "Underpass_Ramp_S", Vector3(16, 0.4, 20), Vector3(0, -3.0, 50), mat_street, Vector3(deg_to_rad(-18.0), 0, 0))
	add_box(root, "Underpass_Ramp_N", Vector3(16, 0.4, 20), Vector3(0, -3.0, -50), mat_street, Vector3(deg_to_rad(18.0), 0, 0))
	# Street-Level Bridge Overpasses connecting West & East Plazas at Z=-22, Z=0, Z=+22
	add_box(root, "Bridge_Overpass_C", Vector3(22, 0.8, 12), Vector3(0, 0, 0), mat_concrete)
	add_box(root, "Bridge_Overpass_N", Vector3(22, 0.8, 10), Vector3(0, 0, -26), mat_concrete)
	add_box(root, "Bridge_Overpass_S", Vector3(22, 0.8, 10), Vector3(0, 0, 26), mat_concrete)

	# 3. Tower Alpha (West Skyscraper, X = -28, Z = 0, Height 52m, Top at Y = 52.0)
	# Footprint: 26m x 26m
	add_box(root, "Tower_Alpha_Base", Vector3(28, 12.0, 28), Vector3(-28, 6.0, 0), mat_concrete)
	add_box(root, "Tower_Alpha_Core", Vector3(26, 40.0, 26), Vector3(-28, 32.0, 0), mat_tower_glass)
	# Structural steel corners & spandrels
	add_box(root, "Tower_Alpha_Col_SW", Vector3(1.5, 52.0, 1.5), Vector3(-40.5, 26.0, 12.5), mat_tower_steel)
	add_box(root, "Tower_Alpha_Col_SE", Vector3(1.5, 52.0, 1.5), Vector3(-15.5, 26.0, 12.5), mat_tower_steel)
	add_box(root, "Tower_Alpha_Col_NW", Vector3(1.5, 52.0, 1.5), Vector3(-40.5, 26.0, -12.5), mat_tower_steel)
	add_box(root, "Tower_Alpha_Col_NE", Vector3(1.5, 52.0, 1.5), Vector3(-15.5, 26.0, -12.5), mat_tower_steel)
	# Rooftop Parapet & Plant Room
	add_box(root, "Tower_Alpha_Roof_Plant", Vector3(14, 4.0, 14), Vector3(-28, 54.0, 0), mat_concrete)
	# Tower Crane atop Tower Alpha
	add_box(root, "Crane_Mast", Vector3(1.2, 16.0, 1.2), Vector3(-28, 60.0, 0), mat_crane_yellow)
	add_box(root, "Crane_Jib_Arm", Vector3(28.0, 1.0, 1.0), Vector3(-14, 68.0, 0), mat_crane_yellow)
	add_sphere(root, "Crane_Beacon", 0.5, Vector3(-28, 68.5, 0), mat_beacon_red)

	# 4. Tower Bravo (East Skyscraper, X = +28, Z = 0, Height 46m, Top at Y = 46.0)
	# Footprint: 26m x 26m
	add_box(root, "Tower_Bravo_Base", Vector3(28, 12.0, 28), Vector3(28, 6.0, 0), mat_concrete)
	add_box(root, "Tower_Bravo_Core", Vector3(26, 34.0, 26), Vector3(28, 29.0, 0), mat_tower_glass)
	# Rooftop Helipad Deck (Point A Objective!)
	add_cylinder(root, "Bravo_Heli_Pad", 10.0, 0.6, Vector3(28, 46.3, 0), mat_concrete)
	add_cylinder(root, "Bravo_Heli_Ring", 9.2, 0.7, Vector3(28, 46.35, 0), mat_neon_cyan)
	add_sphere(root, "Bravo_Beacon_1", 0.4, Vector3(28 + 8, 46.8, 8), mat_beacon_red)
	add_sphere(root, "Bravo_Beacon_2", 0.4, Vector3(28 - 8, 46.8, -8), mat_beacon_red)

	# 5. Dual Transit Skybridges (Connecting Tower Alpha and Tower Bravo)
	# Lower Skybridge at Y = 22.0m (Length 34m spanning X=-15 to X=+15)
	add_box(root, "Skybridge_Lower_Floor", Vector3(32, 0.6, 6), Vector3(0, 22.0, 0), mat_skybridge)
	add_box(root, "Skybridge_Lower_Roof", Vector3(32, 0.6, 6), Vector3(0, 26.5, 0), mat_skybridge)
	add_box(root, "Skybridge_Lower_Glass_N", Vector3(32, 4.0, 0.4), Vector3(0, 24.2, -2.8), mat_tower_glass)
	add_box(root, "Skybridge_Lower_Glass_S", Vector3(32, 4.0, 0.4), Vector3(0, 24.2, 2.8), mat_tower_glass)
	# Upper High-Altitude Skybridge at Y = 38.0m
	add_box(root, "Skybridge_Upper_Floor", Vector3(32, 0.6, 5), Vector3(0, 38.0, 0), mat_skybridge)
	add_box(root, "Skybridge_Upper_Roof", Vector3(32, 0.6, 5), Vector3(0, 42.0, 0), mat_skybridge)
	add_box(root, "Skybridge_Upper_Glass", Vector3(32, 3.6, 0.4), Vector3(0, 40.0, -2.3), mat_tower_glass)

	# 6. North & South Commercial Mid-Rises (Surrounding Blocks)
	# North Office Block (Z = -48, X = 0, Height 22m)
	add_box(root, "Office_North_Core", Vector3(36, 22.0, 20), Vector3(0, 11.0, -48), mat_tower_glass)
	add_box(root, "Office_North_Roof", Vector3(38, 0.8, 22), Vector3(0, 22.4, -48), mat_concrete)
	# South Tech Hub (Z = +48, X = 0, Height 24m)
	add_box(root, "Tech_South_Core", Vector3(36, 24.0, 20), Vector3(0, 12.0, 48), mat_tower_glass)
	add_box(root, "Tech_South_Roof", Vector3(38, 0.8, 22), Vector3(0, 24.4, 48), mat_concrete)

	# 7. Holographic Neon Billboards
	add_box(root, "Neon_Sign_Alpha_N", Vector3(16.0, 5.0, 0.4), Vector3(-28.0, 18.0, -14.2), mat_neon_cyan)
	add_box(root, "Neon_Sign_Bravo_S", Vector3(16.0, 5.0, 0.4), Vector3(28.0, 18.0, 14.2), mat_neon_magenta)
	add_box(root, "Neon_Sign_Bridge", Vector3(0.4, 3.0, 5.0), Vector3(0.0, 24.2, 0.0), mat_neon_cyan)

	# 8. Perimeter Road Dividers
	add_box(root, "Wall_Plaza_W", Vector3(1.2, 2.5, 160), Vector3(-78, 1.25, 0), mat_concrete)
	add_box(root, "Wall_Plaza_E", Vector3(1.2, 2.5, 160), Vector3(78, 1.25, 0), mat_concrete)

	save_map_scene(root, "res://assets/maps/skyline.scn")

func save_map_scene(root: Node3D, path: String) -> void:
	# Recursively set owner for all children so PackedScene packs every node
	set_owner_recursive(root, root)
	var scene := PackedScene.new()
	var result := scene.pack(root)
	if result != OK:
		push_error("Failed to pack scene for %s, error code %d" % [path, result])
		return
	var save_err := ResourceSaver.save(scene, path)
	if save_err != OK:
		push_error("Failed to save scene to %s, error code %d" % [path, save_err])
	else:
		print("Successfully saved AAA scene to: ", path)

func set_owner_recursive(node: Node, scene_owner: Node) -> void:
	for c in node.get_children():
		c.owner = scene_owner
		set_owner_recursive(c, scene_owner)
