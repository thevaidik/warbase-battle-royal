class_name DroneVisualResources
extends RefCounted
## Shared resource factory and static geometry cache for procedural drones.
## Caches immutable materials and merged ArrayMesh geometries to avoid SurfaceTool
## rebuilds on repeated spawns.

const Finish := preload("res://scripts/drones/DroneFinish.gd")
const GEOMETRY_VERSION := 1

static var _material_cache: Dictionary = {}
static var _batched_mesh_cache: Dictionary = {}
static var _wreck_material_cache: Dictionary = {}
static var _shadow_material: StandardMaterial3D
static var _shadow_mesh: PlaneMesh
static var _merges := 0
static var _hits := 0
static var _misses := 0

static func get_wreck_material(original: StandardMaterial3D) -> StandardMaterial3D:
	if original == null: return null
	var key := str(original.get_instance_id())
	if _wreck_material_cache.has(key):
		return _wreck_material_cache[key]
	var finish := original.duplicate() as StandardMaterial3D
	finish.albedo_color = original.albedo_color.lerp(Color("252225"), 0.38)
	finish.roughness = maxf(original.roughness, 0.68)
	_wreck_material_cache[key] = finish
	return finish

static func get_material(color: Color, metallic: float, roughness: float, emissive: bool = false) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f_%s" % [color.to_html(), metallic, roughness, "1" if emissive else "0"]
	if _material_cache.has(key):
		return _material_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if emissive:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.65
	Finish.apply_metal_grain(m)
	_material_cache[key] = m
	return m

static func get_batched_meshes(cache_key: String) -> Variant:
	if _batched_mesh_cache.has(cache_key):
		_hits += 1
		return _batched_mesh_cache[cache_key]
	_misses += 1
	return null

static func set_batched_meshes(cache_key: String, entries: Array) -> void:
	_batched_mesh_cache[cache_key] = entries

static func record_merge() -> void:
	_merges += 1

static func get_stats() -> Dictionary:
	return {
		"version": GEOMETRY_VERSION,
		"cached_mesh_variants": _batched_mesh_cache.size(),
		"cached_materials": _material_cache.size(),
		"hits": _hits,
		"misses": _misses,
		"merges": _merges
	}

static func get_shadow_mesh() -> PlaneMesh:
	if _shadow_mesh == null:
		var pm := PlaneMesh.new()
		pm.size = Vector2(1.0, 1.0)
		_shadow_mesh = pm
	return _shadow_mesh

static func get_shadow_material() -> StandardMaterial3D:
	if _shadow_material == null:
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in range(32):
			for x in range(32):
				var dx := (float(x) + 0.5) / 16.0 - 1.0
				var dy := (float(y) + 0.5) / 16.0 - 1.0
				var r := sqrt(dx * dx + dy * dy)
				var alpha := clampf(1.0 - smoothstep(0.2, 1.0, r), 0.0, 1.0)
				img.set_pixel(x, y, Color(0.02, 0.02, 0.03, alpha * 0.72))
		var tex := ImageTexture.create_from_image(img)
		m.albedo_texture = tex
		_shadow_material = m
	return _shadow_material

static func clear_cache() -> void:
	_batched_mesh_cache.clear()
	_material_cache.clear()
	_wreck_material_cache.clear()
	_shadow_material = null
	_shadow_mesh = null
	_merges = 0
	_hits = 0
	_misses = 0

static func prewarm(parent_node: Node) -> void:
	if not is_instance_valid(parent_node): return
	var drone = load("res://scripts/drones/DroneVisual.gd").new()
	parent_node.add_child(drone)
	for is_friendly in [true, false]:
		for chassis in ["heli", "wheels", "tracked", "wing"]:
			drone.configure(is_friendly, "ak47", chassis)
	drone.queue_free()
