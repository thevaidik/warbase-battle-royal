class_name WeaponView
extends Node3D
## Studio-grade tactical firearm viewmodels with authentic mechanical anatomy.
## Built with military-spec dimensions, reciprocating bolts/slides, precision iron sights,
## tactile Picatinny rails, Leupold Mark 4 optic, and non-reflective matte PBR finishes.

static var _mat_cache: Dictionary = {}

static func _mat(
	color: Color, 
	metallic: Variant = 0.0, 
	rough: float = 0.5, 
	specular: float = 0.5, 
	rim_amount: float = 0.35, 
	emission: Color = Color.BLACK, 
	energy: float = 0.0
) -> StandardMaterial3D:
	var met: float = 0.92 if (metallic is bool and metallic) else (0.0 if metallic is bool else float(metallic))
	var key := "%s_%.2f_%.3f_%.2f_%.2f_%s_%.2f" % [color.to_html(true), met, rough, specular, rim_amount, emission.to_html(true), energy]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if color.a < 0.98:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic = met
		m.roughness = clampf(rough, 0.02, 1.0)
		m.metallic_specular = specular
	else:
		m.metallic = met
		m.roughness = clampf(rough, 0.04, 1.0)
		m.metallic_specular = specular
		if met > 0.1:
			m.rim_enabled = true
			m.rim = rim_amount
			m.rim_tint = 0.5
		elif rough < 0.5:
			m.clearcoat_enabled = true
			m.clearcoat = 0.35
			m.clearcoat_roughness = 0.25
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	_mat_cache[key] = m
	return m

static func _box(parent: Node3D, name: String, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = mat
	parent.add_child(mi)
	return mi

static func _cyl(parent: Node3D, name: String, radius: float, height: float, pos: Vector3, mat: Material, rot: Vector3 = Vector3(PI / 2.0, 0, 0)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = mat
	parent.add_child(mi)
	return mi

static func build(weapon_id: String) -> Node3D:
	var root: Node3D
	match weapon_id:
		"m4", "mp5", "dmr": root = build_modern(weapon_id)
		"m2010": root = build_m2010()
		"pistol": root = build_pistol()
		"hmg": root = build_hmg()
		_: root = build_ak47()
	_detail_weapon(root, weapon_id)
	_merge_static_parts(root)
	return root

static func build_modern(weapon_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = weapon_id
	var compact := weapon_id == "mp5"
	var marksman := weapon_id == "dmr"
	var metal := _mat(Color("343c40"), 0.88, 0.35)
	var polymer := _mat(Color("242a2c"), 0.05, 0.78)
	var furniture := _mat(Color("796d52") if marksman else Color("343b39"), 0.1, 0.72)
	var silver := _mat(Color("889292"), 0.92, 0.3)
	var barrel_end := -0.63 if compact else (-1.02 if marksman else -0.85)
	_box(root, "UpperReceiver", Vector3(0.065, 0.10, 0.29), Vector3(0, 0.035, 0), metal)
	_box(root, "LowerReceiver", Vector3(0.058, 0.055, 0.19), Vector3(0, -0.035, 0.04), polymer)
	_box(root, "PistolGrip", Vector3(0.045, 0.16, 0.065), Vector3(0, -0.13, 0.10), polymer, Vector3(-0.22, 0, 0))
	_box(root, "TriggerGuard", Vector3(0.043, 0.009, 0.07), Vector3(0, -0.09, 0.035), metal)
	_box(root, "StockTube", Vector3(0.032, 0.035, 0.23), Vector3(0, 0.025, 0.25), metal)
	_box(root, "AdjustableStock", Vector3(0.052, 0.105, 0.19), Vector3(0, 0, 0.36), furniture)
	_box(root, "ButtPad", Vector3(0.055, 0.13, 0.024), Vector3(0, -0.012, 0.46), polymer)
	_box(root, "Handguard", Vector3(0.061, 0.075, 0.22 if compact else 0.39), Vector3(0, 0.025, -0.29 if compact else -0.37), furniture)
	for slot in (4 if compact else 7):
		var z := -0.20 - float(slot) * 0.045
		_box(root, "VentLeft", Vector3(0.003, 0.014, 0.023), Vector3(-0.032, 0.04, z), polymer)
		_box(root, "VentRight", Vector3(0.003, 0.014, 0.023), Vector3(0.032, 0.04, z), polymer)
	_cyl(root, "Barrel", 0.012, 0.23, Vector3(0, 0.025, barrel_end + 0.12), metal)
	_cyl(root, "MuzzleBrake", 0.021 if marksman else 0.017, 0.055, Vector3(0, 0.025, barrel_end), metal)
	var magazine := Node3D.new()
	magazine.name = "magazine"
	root.add_child(magazine)
	_box(magazine, "MagazineBody", Vector3(0.032 if compact else 0.049, 0.20 if compact else 0.16, 0.045 if compact else 0.074), Vector3(0, -0.14, -0.06), polymer, Vector3(-0.08, 0, 0))
	var bolt := Node3D.new()
	bolt.name = "boltCarrier"
	root.add_child(bolt)
	_box(bolt, "BoltCarrier", Vector3(0.005, 0.022, 0.085), Vector3(0.034, 0.05, 0), silver)
	for rail in 8:
		_box(root, "RailTooth", Vector3(0.037, 0.009, 0.012), Vector3(0, 0.094, 0.11 - float(rail)*0.035), metal)
	# Keep the aiming axis at y=.14, matching the 0.85 viewmodel scale and ADS offset.
	if marksman:
		_cyl(root, "ScopeTube", 0.023, 0.22, Vector3(0, 0.14, -0.02), polymer)
		_cyl(root, "ScopeObjective", 0.034, 0.055, Vector3(0, 0.14, -0.145), metal)
		_cyl(root, "ScopeEyepiece", 0.030, 0.045, Vector3(0, 0.14, 0.105), metal)
		_box(root, "ScopeMount", Vector3(0.035, 0.032, 0.14), Vector3(0, 0.106, -0.02), metal)
	else:
		_box(root, "ReflexBase", Vector3(0.045, 0.02, 0.07), Vector3(0, 0.107, -0.03), metal)
		for side in [-1.0, 1.0]:
			_box(root, "ReflexFrame", Vector3(0.004, 0.047, 0.04), Vector3(side*0.024, 0.14, -0.03), metal)
		_box(root, "ReflexTop", Vector3(0.052, 0.004, 0.04), Vector3(0, 0.164, -0.03), metal)
		_box(root, "ReflexDot", Vector3(0.0018, 0.0018, 0.001), Vector3(0, 0.14, -0.052), _mat(Color.RED, 0.0, 0.2, 0.0, 0.0, Color.RED, 2.0))
	for data in [["Muzzle", Vector3(0, 0.025, barrel_end-0.04)], ["Ejector", Vector3(0.04, 0.05, 0)]]:
		var marker := Marker3D.new()
		marker.name = data[0]
		marker.position = data[1]
		root.add_child(marker)
	return root

static func _merge_static_parts(root: Node3D) -> void:
	# Keep mechanical pivots and markers, batch static geometry by shared material.
	var groups: Dictionary = {}
	for child in root.get_children():
		if child is MeshInstance3D and child.mesh and child.material_override != null:
			var material: Material = child.material_override
			if not groups.has(material): groups[material] = []
			groups[material].append(child)
		elif child is Node3D:
			_merge_static_parts(child)
	for material in groups:
		var parts: Array = groups[material]
		if parts.size() < 2:
			continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in parts:
			for i in part.mesh.get_surface_count():
				surface.append_from(part.mesh, i, part.transform)
		var merged := MeshInstance3D.new()
		merged.name = "BatchedParts"
		merged.mesh = surface.commit()
		merged.material_override = material
		merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(merged)
		for part in parts: part.free()

# ==============================================================================
# AK-47 TACTICAL ASSAULT RIFLE
# ==============================================================================
static func build_ak47() -> Node3D:
	var root := Node3D.new()
	root.name = "ak47"
	
	# Battlefield Military Spec PBR Palette (Authentic Stamped Gunmetal & Russian Birch)
	var receiver_metal := _mat(Color(0.28, 0.29, 0.31), 0.92, 0.32, 0.60, 0.45) # Milled blued gunmetal receiver
	var dust_cover_metal := _mat(Color(0.24, 0.25, 0.27), 0.90, 0.30, 0.55, 0.40) # Stamped ribbed sheet cover
	var bolt_metal := _mat(Color(0.72, 0.74, 0.76), 0.96, 0.18, 0.75, 0.60) # Polished chrome/stainless bolt carrier
	var barrel_steel := _mat(Color(0.26, 0.27, 0.29), 0.94, 0.26, 0.65, 0.50) # Cold hammer-forged steel barrel
	var mag_steel := _mat(Color(0.24, 0.25, 0.27), 0.90, 0.34, 0.55, 0.40) # Ribbed 30-round steel mag
	var walnut_wood := _mat(Color(0.54, 0.25, 0.10), 0.0, 0.40, 0.40, 0.25) # Varnished Russian birch laminate
	var dark_walnut := _mat(Color(0.40, 0.18, 0.08), 0.0, 0.44, 0.35, 0.20) # Palm swell grain accent
	var bakelite_grip := _mat(Color(0.46, 0.19, 0.08), 0.0, 0.38, 0.45, 0.30) # Authentic orange/red Bakelite grip
	var sight_post_white := _mat(Color(0.96, 0.96, 0.94), 0.0, 0.25, 0.5, 0.2, Color(1.0, 1.0, 0.9), 1.5)
	var optic_hood := _mat(Color(0.20, 0.21, 0.23), 0.86, 0.38, 0.50, 0.35) # Hard-anodized aircraft aluminum hood
	var optic_body := _mat(Color(0.23, 0.24, 0.26), 0.84, 0.40, 0.45, 0.35) # Optic mounting clamp
	var holo_glass := _mat(Color(0.25, 0.75, 0.95, 0.03), 0.05, 0.02, 0.50, 0.10)
	var holo_reticle := _mat(Color(1.0, 0.20, 0.15), 0.0, 0.05, 0.0, 0.0, Color(1.0, 0.15, 0.12), 4.5)
	
	# 1. Stamped Steel Receiver Group
	_box(root, "receiver", Vector3(0.066, 0.098, 0.44), Vector3(0, 0.015, -0.02), receiver_metal)
	# Magazine well side reinforcement dimples
	_box(root, "magWellDimpleL", Vector3(0.003, 0.022, 0.045), Vector3(-0.034, 0.01, -0.12), dust_cover_metal)
	_box(root, "magWellDimpleR", Vector3(0.003, 0.022, 0.045), Vector3(0.034, 0.01, -0.12), dust_cover_metal)
	# Trunnion assembly rivets
	for rz in [-0.20, -0.16, 0.12, 0.16]:
		_cyl(root, "rivet_%f" % rz, 0.0035, 0.068, Vector3(0, 0.045, rz), dust_cover_metal, Vector3(0, 0, PI / 2.0))
	# Fire selector lever on right side (+X), clicked down to AUTO position
	_box(root, "selectorLever", Vector3(0.005, 0.018, 0.12), Vector3(0.036, 0.032, 0.04), dust_cover_metal, Vector3(-PI / 24.0, 0, 0))
	_cyl(root, "selectorPivot", 0.008, 0.01, Vector3(0.036, 0.036, 0.09), receiver_metal, Vector3(0, 0, PI / 2.0))
	
	# 2. Ribbed Stamped Dust Cover & Takedown Button
	_box(root, "dustCover", Vector3(0.060, 0.042, 0.42), Vector3(0, 0.076, -0.02), dust_cover_metal)
	# 3 Stamped strengthening ribs along the dust cover spine
	for rz in [-0.12, -0.02, 0.08]:
		_box(root, "coverRib_%f" % rz, Vector3(0.048, 0.006, 0.065), Vector3(0, 0.098, rz), receiver_metal)
	# Rear takedown spring latch button
	_box(root, "takedownButton", Vector3(0.024, 0.024, 0.025), Vector3(0, 0.076, 0.20), receiver_metal)
	
	# 3. Reciprocating Bolt Carrier & Charging Handle (Animated on Fire!)
	var bolt := Node3D.new()
	bolt.name = "boltCarrier"
	root.add_child(bolt)
	# Visible cylindrical bolt body in ejection port (+X)
	_cyl(bolt, "boltBody", 0.018, 0.18, Vector3(0.022, 0.052, -0.04), bolt_metal)
	_box(bolt, "boltFace", Vector3(0.018, 0.028, 0.06), Vector3(0.028, 0.052, -0.08), bolt_metal)
	# Authentic curved tactical charging handle protruding on right side
	_cyl(bolt, "handleStem", 0.007, 0.042, Vector3(0.048, 0.055, -0.08), barrel_steel, Vector3(0, 0, PI / 2.0))
	_cyl(bolt, "handleKnob", 0.011, 0.028, Vector3(0.072, 0.055, -0.08), receiver_metal, Vector3(0, 0, PI / 2.0))
	
	# 4. Trigger Mechanism & Ergonomics
	_box(root, "triggerGuard", Vector3(0.032, 0.048, 0.085), Vector3(0, -0.058, 0.06), receiver_metal)
	_box(root, "trigger", Vector3(0.014, 0.034, 0.018), Vector3(0, -0.048, 0.052), barrel_steel, Vector3(-PI / 6.0, 0, 0))
	# Magazine paddle release lever
	_box(root, "magReleasePaddle", Vector3(0.016, 0.032, 0.012), Vector3(0, -0.042, -0.068), receiver_metal, Vector3(PI / 8.0, 0, 0))
	
	# 5. Contoured Bakelite Pistol Grip
	_box(root, "gripUpper", Vector3(0.046, 0.075, 0.065), Vector3(0, -0.082, 0.14), bakelite_grip, Vector3(PI / 9.5, 0, 0))
	_box(root, "gripLower", Vector3(0.044, 0.075, 0.062), Vector3(0, -0.138, 0.165), bakelite_grip, Vector3(PI / 10.5, 0, 0))
	_box(root, "gripCap", Vector3(0.046, 0.012, 0.064), Vector3(0, -0.176, 0.178), receiver_metal, Vector3(PI / 10.5, 0, 0))
	
	# 6. Laminated Walnut Buttstock
	_box(root, "stockWrist", Vector3(0.050, 0.075, 0.14), Vector3(0, -0.005, 0.26), walnut_wood, Vector3(-PI / 36.0, 0, 0))
	_box(root, "stockComb", Vector3(0.052, 0.105, 0.22), Vector3(0, -0.028, 0.42), walnut_wood, Vector3(-PI / 28.0, 0, 0))
	_box(root, "buttplate", Vector3(0.056, 0.115, 0.024), Vector3(0, -0.038, 0.535), receiver_metal)
	_cyl(root, "stockSlingSwivel", 0.005, 0.028, Vector3(0, -0.082, 0.44), barrel_steel, Vector3(0, 0, PI / 2.0))
	
	# 7. Curved 30-Round Steel Magazine (Animated on Reload!)
	var mag := Node3D.new()
	mag.name = "magazine"
	root.add_child(mag)
	_box(mag, "magTop", Vector3(0.052, 0.11, 0.092), Vector3(0, -0.095, -0.12), mag_steel, Vector3(PI / 12.0, 0, 0))
	_box(mag, "magMid", Vector3(0.050, 0.12, 0.092), Vector3(0, -0.185, -0.145), mag_steel, Vector3(PI / 7.0, 0, 0))
	_box(mag, "magBottom", Vector3(0.048, 0.10, 0.092), Vector3(0, -0.270, -0.182), mag_steel, Vector3(PI / 5.2, 0, 0))
	# Horizontal stamped reinforcement ribs
	for mry in [-0.12, -0.17, -0.22, -0.26]:
		_box(mag, "magRib_%f" % mry, Vector3(0.054, 0.012, 0.088), Vector3(0, mry, -0.12 + (mry + 0.12) * 0.35), receiver_metal, Vector3(PI / 6.5, 0, 0))
	_box(mag, "magFloorplate", Vector3(0.052, 0.018, 0.105), Vector3(0, -0.315, -0.202), receiver_metal, Vector3(PI / 5.2, 0, 0))
	
	# 8. Wooden Handguards & Gas System
	# Lower handguard with ergonomic palm swell
	_box(root, "lowerHandguardRear", Vector3(0.068, 0.068, 0.14), Vector3(0, 0.015, -0.32), dark_walnut)
	_box(root, "lowerHandguardPalm", Vector3(0.076, 0.072, 0.12), Vector3(0, 0.012, -0.42), walnut_wood)
	# Upper handguard over gas tube
	_box(root, "upperHandguard", Vector3(0.060, 0.046, 0.22), Vector3(0, 0.064, -0.37), walnut_wood)
	# Steel handguard retaining cap with locking lever
	_box(root, "handguardCap", Vector3(0.064, 0.072, 0.018), Vector3(0, 0.038, -0.485), receiver_metal)
	
	# 9. Stepped Barrel, Gas Block & Cleaning Rod
	_cyl(root, "barrel", 0.013, 0.58, Vector3(0, 0.022, -0.55), barrel_steel)
	_cyl(root, "gasTube", 0.015, 0.26, Vector3(0, 0.058, -0.37), barrel_steel)
	# AK Gas block connecting barrel to gas tube at 45 degree angle
	_box(root, "gasBlock", Vector3(0.036, 0.058, 0.045), Vector3(0, 0.042, -0.52), receiver_metal)
	# Steel cleaning rod under barrel
	_cyl(root, "cleaningRod", 0.0035, 0.46, Vector3(0, -0.008, -0.52), barrel_steel)
	_box(root, "bayonetLug", Vector3(0.018, 0.018, 0.035), Vector3(0, 0.002, -0.53), dust_cover_metal)
	
	# 10. Tactical Receiver Mount & Picatinny Top Rail
	# Left-side dovetail optics bracket (Zenitco B-13 style)
	_box(root, "opticMountBracketL", Vector3(0.008, 0.062, 0.14), Vector3(-0.038, 0.064, -0.04), receiver_metal)
	_box(root, "opticMountBridge", Vector3(0.038, 0.010, 0.14), Vector3(-0.018, 0.100, -0.04), receiver_metal)
	# Full-length Mil-STD-1913 Picatinny top rail over dust cover
	_box(root, "opticPicatinnyRail", Vector3(0.026, 0.012, 0.18), Vector3(0, 0.105, -0.04), optic_body)
	for rz in [-0.11, -0.08, -0.05, -0.02, 0.01, 0.04]:
		_box(root, "railSlot_%f" % rz, Vector3(0.028, 0.004, 0.008), Vector3(0, 0.111, rz), optic_hood)
		
	# 11. Tactical Holographic CQB Optic (EOTech 553 Style)
	# Aluminum base riser & dual cross-bolt mounting clamp
	_box(root, "holoBaseClamp", Vector3(0.038, 0.014, 0.12), Vector3(0, 0.116, -0.05), optic_body)
	_cyl(root, "holoBolt1", 0.005, 0.042, Vector3(0, 0.116, -0.08), receiver_metal, Vector3(0, 0, PI / 2.0))
	_cyl(root, "holoBolt2", 0.005, 0.042, Vector3(0, 0.116, -0.02), receiver_metal, Vector3(0, 0, PI / 2.0))
	_box(root, "holoQDLatch", Vector3(0.006, 0.012, 0.032), Vector3(-0.021, 0.116, -0.05), receiver_metal)
	
	# Protective Aluminum Hood / Shroud (Wide Aperture centered at y = 0.140, z = -0.05)
	_box(root, "holoHoodLeft", Vector3(0.0035, 0.046, 0.095), Vector3(-0.025, 0.140, -0.05), optic_hood)
	_box(root, "holoHoodRight", Vector3(0.0035, 0.046, 0.095), Vector3(0.025, 0.140, -0.05), optic_hood)
	_box(root, "holoHoodTop", Vector3(0.0535, 0.0035, 0.095), Vector3(0, 0.163, -0.05), optic_hood)
	_box(root, "holoHoodBottom", Vector3(0.050, 0.004, 0.095), Vector3(0, 0.117, -0.05), optic_hood)
	
	# Transparent Optical Sight Glass (Clean, crystal-clear view through window)
	_box(root, "holoSightGlass", Vector3(0.046, 0.042, 0.001), Vector3(0, 0.140, -0.005), holo_glass)
	
	# Battery Compartment Cylinder (Forward AA Housing below window)
	_cyl(root, "holoBatteryHousing", 0.008, 0.065, Vector3(0, 0.112, -0.11), optic_body)
	_cyl(root, "holoBatteryCap", 0.009, 0.010, Vector3(0, 0.112, -0.142), optic_hood)
	
	# Windage & Elevation Turret Dials
	_cyl(root, "holoElevationTurret", 0.006, 0.008, Vector3(0, 0.165, -0.05), optic_body, Vector3(0, 0, 0))
	_cyl(root, "holoWindageTurret", 0.006, 0.008, Vector3(0.028, 0.140, -0.05), optic_body, Vector3(0, 0, PI / 2.0))
	
	# 12. Backup Iron Sights (Lower 1/3 Co-Witness)
	# Rear Sight Base & Leaf
	_box(root, "rearSightBase", Vector3(0.042, 0.036, 0.08), Vector3(0, 0.075, -0.22), receiver_metal)
	_box(root, "rearSightRamp", Vector3(0.028, 0.018, 0.065), Vector3(0, 0.088, -0.22), dust_cover_metal, Vector3(PI / 24.0, 0, 0))
	_box(root, "rearSightBladeL", Vector3(0.010, 0.014, 0.008), Vector3(-0.010, 0.095, -0.215), barrel_steel)
	_box(root, "rearSightBladeR", Vector3(0.010, 0.014, 0.008), Vector3(0.010, 0.095, -0.215), barrel_steel)
	
	# Front Sight Tower, Hooded Wings & Post (y = 0.095 in lower 1/3)
	_box(root, "frontSightBlock", Vector3(0.036, 0.062, 0.038), Vector3(0, 0.052, -0.78), receiver_metal)
	_cyl(root, "frontSightDrum", 0.012, 0.038, Vector3(0, 0.078, -0.78), dust_cover_metal, Vector3(0, 0, PI / 2.0))
	_box(root, "frontSightWingL", Vector3(0.006, 0.036, 0.016), Vector3(-0.014, 0.098, -0.78), receiver_metal)
	_box(root, "frontSightWingR", Vector3(0.006, 0.036, 0.016), Vector3(0.014, 0.098, -0.78), receiver_metal)
	_box(root, "frontSightPost", Vector3(0.004, 0.022, 0.004), Vector3(0, 0.095, -0.78), sight_post_white)
	
	# 13. Slanted AKM Muzzle Compensator
	_box(root, "muzzleCompBody", Vector3(0.026, 0.026, 0.048), Vector3(0, 0.022, -0.87), barrel_steel)
	_box(root, "muzzleSlantFace", Vector3(0.024, 0.028, 0.022), Vector3(0, 0.026, -0.89), dust_cover_metal, Vector3(-PI / 6.0, 0, 0))
	
	# 12. Tactical Markers
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.022, -0.92)
	root.add_child(muzzle)
	
	var ejector := Marker3D.new()
	ejector.name = "Ejector"
	ejector.position = Vector3(0.055, 0.055, -0.08)
	root.add_child(ejector)
	
	return root

# ==============================================================================
# M2010 ENHANCED TACTICAL SNIPER RIFLE
# ==============================================================================
static func build_m2010() -> Node3D:
	var root := Node3D.new()
	root.name = "m2010"
	
	# Military Precision PBR Palette (Battlefield Sniper Aesthetic)
	var fde_chassis := _mat(Color(0.50, 0.42, 0.30), 0.80, 0.36, 0.55, 0.45) # Flat Dark Earth anodized aluminum
	var black_nitride := _mat(Color(0.24, 0.25, 0.27), 0.92, 0.30, 0.60, 0.45) # Black nitride steel
	var fluted_steel := _mat(Color(0.35, 0.36, 0.39), 0.95, 0.22, 0.70, 0.55) # Match-grade fluted stainless barrel
	var matte_poly := _mat(Color(0.18, 0.18, 0.20), 0.0, 0.65, 0.25, 0.15) # Tactical high-impact polymer
	var rail_black := _mat(Color(0.22, 0.23, 0.25), 0.88, 0.35, 0.55, 0.40) # MIL-STD-1913 Picatinny rails
	var glass_coated := _mat(Color(0.08, 0.38, 0.52), 0.60, 0.06, 0.80, 0.30, Color(0.06, 0.45, 0.65), 1.5) # Multi-coated sapphire lens
	var turret_accent := _mat(Color(0.32, 0.33, 0.36), 0.94, 0.26, 0.65, 0.50) # CNC machined knurled turrets
	var bolt_chrome := _mat(Color(0.72, 0.74, 0.76), 0.96, 0.16, 0.75, 0.60) # Spiral fluted machined bolt
	
	# 1. CNC Machined Aluminum Receiver & Chassis
	_box(root, "chassisCore", Vector3(0.072, 0.098, 0.46), Vector3(0, 0.035, -0.14), fde_chassis)
	_box(root, "magWell", Vector3(0.058, 0.085, 0.13), Vector3(0, -0.036, -0.16), fde_chassis)
	# Ambidextrous paddle magazine release
	_box(root, "magReleasePaddle", Vector3(0.018, 0.035, 0.014), Vector3(0, -0.042, -0.09), black_nitride, Vector3(PI / 8.0, 0, 0))
	
	# Detachable 5-Round AICS Steel Box Magazine (Animated on Reload!)
	var mag := Node3D.new()
	mag.name = "magazine"
	root.add_child(mag)
	_box(mag, "magBody", Vector3(0.046, 0.13, 0.105), Vector3(0, -0.095, -0.16), black_nitride)
	_box(mag, "magBaseplate", Vector3(0.050, 0.016, 0.115), Vector3(0, -0.162, -0.16), matte_poly)
	
	# 2. Skeletonized Folding Stock with Adjustable Cheek Riser
	_box(root, "stockHinge", Vector3(0.055, 0.065, 0.04), Vector3(0, 0.025, 0.10), black_nitride)
	_box(root, "stockUpperSpine", Vector3(0.044, 0.035, 0.28), Vector3(0, 0.042, 0.25), fde_chassis)
	_box(root, "stockLowerStrut", Vector3(0.038, 0.028, 0.26), Vector3(0, -0.022, 0.24), fde_chassis, Vector3(-PI / 28.0, 0, 0))
	# Adjustable cheek riser with dual knurled locking wheels
	_box(root, "cheekRiser", Vector3(0.048, 0.048, 0.15), Vector3(0, 0.082, 0.24), matte_poly)
	_cyl(root, "cheekWheel1", 0.009, 0.054, Vector3(0, 0.058, 0.19), turret_accent, Vector3(0, 0, PI / 2.0))
	_cyl(root, "cheekWheel2", 0.009, 0.054, Vector3(0, 0.058, 0.29), turret_accent, Vector3(0, 0, PI / 2.0))
	# Pachmayr rubber recoil buttpad
	_box(root, "buttpadBase", Vector3(0.052, 0.135, 0.025), Vector3(0, 0.015, 0.39), black_nitride)
	_box(root, "buttpadRubber", Vector3(0.056, 0.145, 0.032), Vector3(0, 0.015, 0.415), matte_poly)
	
	# Tactical Pistol Grip & Trigger
	_box(root, "grip", Vector3(0.046, 0.145, 0.062), Vector3(0, -0.068, 0.03), matte_poly, Vector3(PI / 10.0, 0, 0))
	_box(root, "triggerGuard", Vector3(0.032, 0.048, 0.085), Vector3(0, -0.032, -0.04), black_nitride)
	_box(root, "trigger", Vector3(0.012, 0.032, 0.016), Vector3(0, -0.025, -0.042), black_nitride, Vector3(-PI / 8.0, 0, 0))
	
	# 3. Heavy Bolt Action Mechanism (Reciprocating Node `boltCarrier`)
	var bolt := Node3D.new()
	bolt.name = "boltCarrier"
	root.add_child(bolt)
	_cyl(bolt, "boltBody", 0.016, 0.24, Vector3(0, 0.042, -0.06), bolt_chrome)
	_cyl(bolt, "boltShroud", 0.018, 0.045, Vector3(0, 0.042, 0.075), black_nitride)
	# Oversized teardrop tactical bolt handle on right side
	_cyl(bolt, "boltStem", 0.008, 0.065, Vector3(0.044, 0.048, 0.06), black_nitride, Vector3(0, 0, PI / 2.3))
	_cyl(bolt, "boltKnob", 0.015, 0.035, Vector3(0.078, 0.038, 0.06), turret_accent, Vector3(0, 0, PI / 2.3))
	
	# 4. Octagonal Free-Float Handguard & Full-Length Picatinny Rails
	_box(root, "handguard", Vector3(0.074, 0.074, 0.42), Vector3(0, 0.042, -0.48), fde_chassis)
	# Continuous MIL-STD-1913 top Picatinny rail
	_box(root, "topRail", Vector3(0.034, 0.015, 0.62), Vector3(0, 0.088, -0.34), rail_black)
	_box(root, "sideRailL", Vector3(0.012, 0.026, 0.32), Vector3(-0.042, 0.042, -0.48), rail_black)
	_box(root, "sideRailR", Vector3(0.012, 0.026, 0.32), Vector3(0.042, 0.042, -0.48), rail_black)
	
	# 5. Heavy Match-Grade Fluted Barrel & AAC Titan Muzzle Brake
	_cyl(root, "barrel", 0.019, 0.94, Vector3(0, 0.045, -0.84), fluted_steel)
	# 4 Flute accent ridges giving authentic CNC machined fluting look
	for a in [0.0, PI / 2.0, PI, 3.0 * PI / 2.0]:
		_cyl(root, "flute_%f" % a, 0.004, 0.68, Vector3(cos(a) * 0.019, 0.045 + sin(a) * 0.019, -0.80), black_nitride)
	# AAC Titan-QD Muzzle Brake with dual side blast ports
	_box(root, "muzzleBrake", Vector3(0.044, 0.044, 0.14), Vector3(0, 0.045, -1.32), black_nitride)
	_box(root, "brakeBaffle1", Vector3(0.052, 0.028, 0.018), Vector3(0, 0.045, -1.28), black_nitride)
	_box(root, "brakeBaffle2", Vector3(0.052, 0.028, 0.018), Vector3(0, 0.045, -1.33), black_nitride)
	_cyl(root, "brakeCrown", 0.014, 0.015, Vector3(0, 0.045, -1.395), black_nitride)
	
	# 6. Folding Tactical Harris Bipod
	_box(root, "bipodMount", Vector3(0.042, 0.025, 0.06), Vector3(0, -0.005, -0.62), black_nitride)
	_cyl(root, "bipodLegL", 0.008, 0.20, Vector3(-0.038, 0.01, -0.58), black_nitride, Vector3(PI / 2.0, 0, -0.14))
	_cyl(root, "bipodLegR", 0.008, 0.20, Vector3(0.038, 0.01, -0.58), black_nitride, Vector3(PI / 2.0, 0, 0.14))
	
	# 7. Precision Leupold Mark 4 34mm Tactical Optic (Optical Axis at y = 0.142)
	# One-piece cantilever dual-ring mount with clamping hex nuts
	_box(root, "scopeMountBase", Vector3(0.044, 0.018, 0.28), Vector3(0, 0.104, -0.16), rail_black)
	_box(root, "scopeRingFront", Vector3(0.048, 0.048, 0.036), Vector3(0, 0.142, -0.26), rail_black)
	_box(root, "scopeRingRear", Vector3(0.048, 0.048, 0.036), Vector3(0, 0.142, -0.06), rail_black)
	# 34mm Main scope tube
	_cyl(root, "scopeTube", 0.022, 0.42, Vector3(0, 0.142, -0.16), black_nitride)
	# 50mm Objective bell & sunshade
	_cyl(root, "scopeObjectiveCone", 0.032, 0.08, Vector3(0, 0.142, -0.36), black_nitride)
	_cyl(root, "scopeSunshade", 0.032, 0.08, Vector3(0, 0.142, -0.42), black_nitride)
	_cyl(root, "scopeLensGlass", 0.029, 0.01, Vector3(0, 0.142, -0.45), glass_coated)
	# Ocular bell with magnification power throw lever
	_cyl(root, "scopeEyepiece", 0.026, 0.09, Vector3(0, 0.142, 0.04), black_nitride)
	_cyl(root, "powerThrowLever", 0.006, 0.032, Vector3(0.028, 0.142, 0.01), turret_accent, Vector3(0, 0, PI / 2.5))
	# Tactical Tall Turrets (Elevation top, Windage right, Parallax left)
	_cyl(root, "elevationTurret", 0.017, 0.034, Vector3(0, 0.178, -0.16), turret_accent, Vector3.ZERO)
	_cyl(root, "windageTurret", 0.017, 0.034, Vector3(0.036, 0.142, -0.16), turret_accent, Vector3(0, 0, PI / 2.0))
	_cyl(root, "parallaxTurret", 0.017, 0.034, Vector3(-0.036, 0.142, -0.16), turret_accent, Vector3(0, 0, -PI / 2.0))
	
	# 8. Tactical Markers
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.045, -1.41)
	root.add_child(muzzle)
	
	var ejector := Marker3D.new()
	ejector.name = "Ejector"
	ejector.position = Vector3(0.052, 0.055, -0.12)
	root.add_child(ejector)
	
	return root

# ==============================================================================
# PISTOL .50 COMBAT TACTICAL
# ==============================================================================
static func build_pistol() -> Node3D:
	var root := Node3D.new()
	root.name = "pistol"
	
	# Tactical Metal & Combat Polymer Palette (Battlefield .50 Caliber Pistol)
	var slide_nitride := _mat(Color(0.32, 0.33, 0.36), 0.94, 0.26, 0.65, 0.50) # Milled brushed steel slide
	var frame_poly := _mat(Color(0.18, 0.18, 0.20), 0.0, 0.65, 0.25, 0.15) # Tactical molded polymer frame
	var barrel_steel := _mat(Color(0.58, 0.60, 0.64), 0.96, 0.18, 0.75, 0.55) # Polished match-grade target barrel
	var tritium_green := _mat(Color(0.2, 1.0, 0.35), 0.0, 0.20, 0.5, 0.2, Color(0.15, 1.0, 0.35), 0.7)
	var small_steel := _mat(Color(0.35, 0.36, 0.39), 0.92, 0.28, 0.60, 0.45) # Steel controls, slide stop & takedown pin
	
	# 1. Ergonomic Polymer Frame Group
	_box(root, "frameSpine", Vector3(0.048, 0.042, 0.22), Vector3(0, 0.008, -0.06), frame_poly)
	# Integrated Picatinny accessory rail under dustcover
	_box(root, "accessoryRail", Vector3(0.042, 0.014, 0.09), Vector3(0, -0.014, -0.13), frame_poly)
	_box(root, "railSlot", Vector3(0.044, 0.008, 0.012), Vector3(0, -0.014, -0.12), small_steel)
	# Undercut trigger guard & combat trigger
	_box(root, "triggerGuard", Vector3(0.028, 0.045, 0.075), Vector3(0, -0.028, -0.05), frame_poly)
	_box(root, "trigger", Vector3(0.012, 0.028, 0.016), Vector3(0, -0.022, -0.04), small_steel, Vector3(-PI / 6.0, 0, 0))
	# Beavertail grip with textured stippling panels
	_box(root, "grip", Vector3(0.042, 0.14, 0.064), Vector3(0, -0.078, 0.02), frame_poly, Vector3(PI / 11.0, 0, 0))
	_box(root, "gripBeaverTail", Vector3(0.040, 0.035, 0.042), Vector3(0, 0.012, 0.06), frame_poly, Vector3(-PI / 8.0, 0, 0))
	# Ambidextrous slide stop & takedown levers
	_box(root, "slideStopL", Vector3(0.005, 0.012, 0.032), Vector3(-0.026, 0.028, -0.03), small_steel)
	_box(root, "takedownPin", Vector3(0.052, 0.014, 0.014), Vector3(0, 0.015, -0.08), small_steel)
	
	# Detachable Magazine with Extended Tactical Baseplate (Animated on Reload!)
	var mag := Node3D.new()
	mag.name = "magazine"
	root.add_child(mag)
	_box(mag, "magBody", Vector3(0.036, 0.12, 0.052), Vector3(0, -0.082, 0.02), small_steel, Vector3(PI / 11.0, 0, 0))
	_box(mag, "magBaseplate", Vector3(0.045, 0.024, 0.078), Vector3(0, -0.148, 0.036), frame_poly, Vector3(PI / 11.0, 0, 0))
	
	# 2. CNC Machined Steel Slide Group (Reciprocating Node `slide`!)
	var slide := Node3D.new()
	slide.name = "slide"
	root.add_child(slide)
	_box(slide, "slideBody", Vector3(0.050, 0.052, 0.26), Vector3(0, 0.042, -0.06), slide_nitride)
	# Chamfered slide nose
	_box(slide, "slideNoseBevel", Vector3(0.048, 0.048, 0.025), Vector3(0, 0.042, -0.18), slide_nitride)
	# Rear angled cocking serrations (5 cuts)
	for i in 5:
		var sz := 0.015 + float(i) * 0.008
		_box(slide, "serrationR_%d" % i, Vector3(0.052, 0.038, 0.004), Vector3(0, 0.042, sz), small_steel)
	# Front tactical press-check serrations (4 cuts)
	for i in 4:
		var sz := -0.12 - float(i) * 0.008
		_box(slide, "serrationF_%d" % i, Vector3(0.052, 0.038, 0.004), Vector3(0, 0.042, sz), small_steel)
	# Ejection port cutout & extractor claw
	_box(slide, "ejectionPort", Vector3(0.045, 0.025, 0.055), Vector3(0.015, 0.052, -0.02), barrel_steel)
	_box(slide, "extractorClaw", Vector3(0.006, 0.012, 0.024), Vector3(0.026, 0.052, -0.01), small_steel)
	
	# Match-Grade Barrel with Target Recessed Crown
	_cyl(slide, "barrel", 0.014, 0.22, Vector3(0, 0.038, -0.12), barrel_steel)
	_cyl(slide, "targetCrown", 0.016, 0.012, Vector3(0, 0.038, -0.228), barrel_steel)
	
	# 3. Combat 3-Dot Tritium Night Sights (Aligned for True ADS at y = 0.075!)
	# Novak-style rear sight base with twin green tritium dots
	_box(slide, "rearSightBase", Vector3(0.042, 0.008, 0.024), Vector3(0, 0.058, 0.06), small_steel)
	_box(slide, "rearSightLeft", Vector3(0.010, 0.024, 0.024), Vector3(-0.018, 0.070, 0.06), small_steel)
	_box(slide, "rearSightRight", Vector3(0.010, 0.024, 0.024), Vector3(0.018, 0.070, 0.06), small_steel)
	_box(slide, "rearDotL", Vector3(0.005, 0.005, 0.004), Vector3(-0.014, 0.075, 0.07), tritium_green)
	_box(slide, "rearDotR", Vector3(0.005, 0.005, 0.004), Vector3(0.014, 0.075, 0.07), tritium_green)
	# Dovetailed front sight post with center green tritium dot
	_box(slide, "frontSightBase", Vector3(0.012, 0.014, 0.022), Vector3(0, 0.065, -0.17), small_steel)
	_box(slide, "frontDot", Vector3(0.005, 0.005, 0.004), Vector3(0, 0.075, -0.16), tritium_green)
	
	# 4. Tactical Markers
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.038, -0.25)
	root.add_child(muzzle)
	
	var ejector := Marker3D.new()
	ejector.name = "Ejector"
	ejector.position = Vector3(0.035, 0.048, -0.02)
	root.add_child(ejector)
	
	return root

# ==============================================================================
# HEAVY MACHINE GUN (HMG / .50 CAL M2)
# ==============================================================================
static func build_hmg() -> Node3D:
	var root := Node3D.new()
	root.name = "hmg"
	var steel := _mat(Color("3d4447"), 0.86, 0.34)
	var dark := _mat(Color("22292b"), 0.2, 0.76)
	var tan := _mat(Color("6c7156"), 0.1, 0.8)
	var brass := _mat(Color("b49a55"), 0.7, 0.35)
	_box(root, "Receiver", Vector3(0.085, 0.11, 0.35), Vector3(0, 0.02, 0), steel)
	_box(root, "FeedCover", Vector3(0.08, 0.023, 0.29), Vector3(0, 0.086, -0.02), dark)
	_cyl(root, "CoverHinge", 0.011, 0.09, Vector3(0, 0.08, 0.12), steel, Vector3(0, 0, PI/2))
	_box(root, "StockBuffer", Vector3(0.032, 0.04, 0.16), Vector3(0, 0.025, 0.24), steel)
	_box(root, "Stock", Vector3(0.06, 0.13, 0.21), Vector3(0, -0.005, 0.38), tan)
	_box(root, "ButtPad", Vector3(0.065, 0.145, 0.025), Vector3(0, -0.005, 0.49), dark)
	_box(root, "Grip", Vector3(0.045, 0.145, 0.065), Vector3(0, -0.11, 0.11), dark, Vector3(-0.2, 0, 0))
	_box(root, "Handguard", Vector3(0.074, 0.07, 0.30), Vector3(0, 0.015, -0.32), tan)
	_cyl(root, "Barrel", 0.017, 0.38, Vector3(0, 0.03, -0.63), steel)
	for i in 12:
		_cyl(root, "CoolingFin", 0.024, 0.008, Vector3(0, 0.03, -0.48-float(i)*0.018), dark)
	for side in [-1.0, 1.0]:
		for i in 6:
			_box(root, "HeatShieldSlot", Vector3(0.002, 0.018, 0.025), Vector3(side*0.038, 0.03, -0.22-float(i)*0.04), dark)
		_box(root, "FoldedBipod", Vector3(0.013, 0.014, 0.27), Vector3(side*0.034, -0.034, -0.51), steel)
	_box(root, "CarryHandle", Vector3(0.018, 0.02, 0.17), Vector3(0.04, 0.13, -0.28), dark)
	_box(root, "HandleMount", Vector3(0.018, 0.08, 0.018), Vector3(0.04, 0.10, -0.20), steel)
	var magazine := Node3D.new()
	magazine.name = "magazine"
	root.add_child(magazine)
	_box(magazine, "SoftAmmoBox", Vector3(0.13, 0.16, 0.15), Vector3(-0.085, -0.09, -0.045), tan)
	_box(magazine, "AmmoBoxLid", Vector3(0.14, 0.018, 0.16), Vector3(-0.085, 0, -0.045), dark)
	for i in 8:
		_cyl(magazine, "BeltRound", 0.005, 0.06, Vector3(-0.12+float(i)*0.013, 0.065, -0.045), brass)
	var bolt := Node3D.new()
	bolt.name = "boltCarrier"
	root.add_child(bolt)
	_box(bolt, "Bolt", Vector3(0.008, 0.025, 0.09), Vector3(0.044, 0.035, 0.02), steel)
	for side in [-1.0, 1.0]:
		_box(root, "RearSight", Vector3(0.004, 0.026, 0.008), Vector3(side*0.012, 0.097, 0.10), dark)
	_box(root, "FrontPost", Vector3(0.004, 0.06, 0.007), Vector3(0, 0.068, -0.73), steel)
	_cyl(root, "FlashHider", 0.025, 0.06, Vector3(0, 0.03, -0.82), dark)
	for data in [["Muzzle", Vector3(0, 0.03, -0.86)], ["Ejector", Vector3(0.05, 0.04, 0.02)]]:
		var marker := Marker3D.new()
		marker.name = data[0]
		marker.position = data[1]
		root.add_child(marker)
	return root

static func _detail_weapon(root: Node3D, id: String) -> void:
	var steel := _mat(Color("525b60"), 0.84, 0.42)
	var inset := _mat(Color("192023"), 0.3, 0.68)
	var brass := _mat(Color("b59a5d"), 0.7, 0.35)
	# Pins, selectors, bolt recesses and trigger geometry share materials for batching.
	for side in [-1.0, 1.0]:
		for z in [-0.10, 0.04, 0.12]:
			_cyl(root, "ReceiverPin", 0.004, 0.003, Vector3(side*0.036, 0.035, z), steel, Vector3(0,0,PI/2))
			_box(root, "PinSlot", Vector3(0.0035, 0.0014, 0.005), Vector3(side*0.038, 0.035, z), inset)
	_box(root, "EjectionRecess", Vector3(0.002, 0.025, 0.075), Vector3(0.035, 0.048, -0.035), inset)
	_box(root, "ChamberGlint", Vector3(0.003, 0.005, 0.018), Vector3(0.037, 0.04, -0.04), brass)
	_box(root, "Trigger", Vector3(0.008, 0.035, 0.008), Vector3(0, -0.072, 0.04), steel, Vector3(0.18,0,0))
	for side in [-1.0, 1.0]:
		_box(root, "TriggerGuardSide", Vector3(0.005, 0.006, 0.08), Vector3(side*0.021,-0.095,0.035), inset)
	_box(root, "Selector", Vector3(0.006, 0.008, 0.036), Vector3(-0.039, 0.005, 0.08), steel, Vector3(0.4,0,0))
	var mag := root.get_node_or_null("magazine")
	if mag:
		for i in 4:
			_box(mag, "MagazineRib", Vector3(0.052, 0.003, 0.07), Vector3(0, -0.07-float(i)*0.022,-0.06), inset)
	if id in ["m4", "mp5", "dmr"]:
		for i in 6:
			_box(root, "GripTexture", Vector3(0.047, 0.003, 0.06), Vector3(0, -0.08-float(i)*0.014,0.1), steel)
		_box(root, "StockLatch", Vector3(0.048, 0.012, 0.08), Vector3(0,-0.058,0.32), steel)
		for i in 4:
			_box(root, "RailSide", Vector3(0.071, 0.007, 0.018), Vector3(0,0.01,-0.22-float(i)*0.04), inset)
