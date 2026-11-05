extends Node

const Geometry := preload("res://scripts/net/ColyseusWorldGeometry.gd")
const SAMPLES_PER_MAP := 128

func _ready() -> void:
	call_deferred("run")

func _old_triangle_hit(triangle_index: int, origin: Vector3, delta: Vector3) -> Dictionary:
	var offset := triangle_index * 9
	var a := Vector3(Geometry._vertices[offset], Geometry._vertices[offset + 1], Geometry._vertices[offset + 2])
	var edge_1 := Vector3(Geometry._vertices[offset + 3], Geometry._vertices[offset + 4], Geometry._vertices[offset + 5]) - a
	var edge_2 := Vector3(Geometry._vertices[offset + 6], Geometry._vertices[offset + 7], Geometry._vertices[offset + 8]) - a
	var h := delta.cross(edge_2)
	var determinant := edge_1.dot(h)
	if absf(determinant) < 0.000000001: return {}
	var inverse := 1.0 / determinant
	var from_a := origin - a
	var u := inverse * from_a.dot(h)
	if u < 0.0 or u > 1.0: return {}
	var q := from_a.cross(edge_1)
	var v := inverse * delta.dot(q)
	if v < 0.0 or u + v > 1.0: return {}
	var fraction := inverse * edge_2.dot(q)
	if fraction < 0.0 or fraction > 1.0: return {}
	var normal := edge_1.cross(edge_2)
	var length := normal.length()
	if length == 0.0: return {}
	return {"fraction": fraction, "normal": normal / length}

func _rays(a: Vector3, edge_1: Vector3, edge_2: Vector3, normal: Vector3) -> Array[Array]:
	var center := a + (edge_1 + edge_2) / 3.0
	var edge_midpoint := a + edge_1 * 0.5
	return [
		[center + normal * 2.0, center - normal * 2.0],
		[center - normal * 2.0, center + normal * 2.0],
		[edge_midpoint + normal * 2.0, edge_midpoint - normal * 2.0],
		[a + normal * 2.0, a - normal * 2.0],
		[center + normal, center + normal + edge_1 * 0.3],
		[center + normal * 2.0 + edge_1 * 4.0, center - normal * 2.0 + edge_1 * 4.0],
	]

func run() -> void:
	var failures := 0
	var rays_tested := 0
	var degenerate_samples := 0
	var old_elapsed := 0
	var new_elapsed := 0
	for map_name in Geometry.PLAYABLE_MAPS:
		Geometry.set_map_override(map_name)
		Geometry.get_loaded_map()
		var triangle_count: int = Geometry._vertices.size() / 9
		var stride := maxi(1, triangle_count / SAMPLES_PER_MAP)
		var selected := 0
		var ray_cases: Array[Array] = []
		for triangle_index in range(0, triangle_count, stride):
			if selected >= SAMPLES_PER_MAP: break
			selected += 1
			var a: Vector3 = Geometry._triangle_a[triangle_index]
			var edge_1: Vector3 = Geometry._triangle_edge_1[triangle_index]
			var edge_2: Vector3 = Geometry._triangle_edge_2[triangle_index]
			var normal: Vector3 = Geometry._triangle_unit_normal[triangle_index]
			if normal == Vector3.ZERO: degenerate_samples += 1
			for ray: Array in _rays(a, edge_1, edge_2, normal):
				var origin: Vector3 = ray[0]
				var delta: Vector3 = ray[1] - origin
				ray_cases.append([triangle_index, origin, delta])
		for test_case: Array in ray_cases:
			var triangle_index: int = test_case[0]
			var origin: Vector3 = test_case[1]
			var delta: Vector3 = test_case[2]
			var expected := _old_triangle_hit(triangle_index, origin, delta)
			var actual: Dictionary = Geometry._triangle_hit(triangle_index, origin, delta)
			rays_tested += 1
			if expected != actual:
				push_error("Precomputed triangle mismatch map=%s triangle=%d expected=%s actual=%s" % [map_name, triangle_index, expected, actual])
				failures += 1
		var old_started := Time.get_ticks_usec()
		for test_case: Array in ray_cases:
			var origin: Vector3 = test_case[1]
			var delta: Vector3 = test_case[2]
			_old_triangle_hit(int(test_case[0]), origin, delta)
		old_elapsed += Time.get_ticks_usec() - old_started
		var new_started := Time.get_ticks_usec()
		for test_case: Array in ray_cases:
			var origin: Vector3 = test_case[1]
			var delta: Vector3 = test_case[2]
			Geometry._triangle_hit(int(test_case[0]), origin, delta)
		new_elapsed += Time.get_ticks_usec() - new_started
	Geometry.set_map_override("industrial")
	Geometry.get_loaded_map()
	var degenerate_offset := 0
	var saved_vertices: Array[float] = []
	for component in 9:
		saved_vertices.append(Geometry._vertices[degenerate_offset + component])
	Geometry._triangle_a[0] = Vector3.ZERO
	Geometry._triangle_edge_1[0] = Vector3.ZERO
	Geometry._triangle_edge_2[0] = Vector3.ZERO
	Geometry._triangle_unit_normal[0] = Vector3.ZERO
	for component in 9: Geometry._vertices[degenerate_offset + component] = 0.0
	var degenerate_expected := _old_triangle_hit(0, Vector3.ONE, Vector3(-1, -1, -1))
	var degenerate_actual: Dictionary = Geometry._triangle_hit(0, Vector3.ONE, Vector3(-1, -1, -1))
	if degenerate_expected != degenerate_actual or not degenerate_actual.is_empty():
		push_error("Synthetic degenerate triangle behavior changed: %s vs %s" % [degenerate_expected, degenerate_actual])
		failures += 1
	for component in 9: Geometry._vertices[degenerate_offset + component] = saved_vertices[component]
	Geometry._triangle_a[0] = Vector3(Geometry._vertices[0], Geometry._vertices[1], Geometry._vertices[2])
	Geometry._triangle_edge_1[0] = Vector3(Geometry._vertices[3], Geometry._vertices[4], Geometry._vertices[5]) - Geometry._triangle_a[0]
	Geometry._triangle_edge_2[0] = Vector3(Geometry._vertices[6], Geometry._vertices[7], Geometry._vertices[8]) - Geometry._triangle_a[0]
	var restored_normal: Vector3 = Geometry._triangle_edge_1[0].cross(Geometry._triangle_edge_2[0])
	var restored_length := restored_normal.length()
	Geometry._triangle_unit_normal[0] = Vector3.ZERO if restored_length == 0.0 else restored_normal / restored_length
	if degenerate_samples == 0:
		print("WORLD_GEOMETRY_DEGENERATE authored=0 synthetic=1")
	Geometry.set_map_override("")
	print("WORLD_GEOMETRY_PRECOMPUTED maps=%d triangles_sampled=%d rays=%d degenerate=%d old_us=%d new_us=%d failures=%d" % [Geometry.PLAYABLE_MAPS.size(), SAMPLES_PER_MAP * Geometry.PLAYABLE_MAPS.size(), rays_tested, degenerate_samples, old_elapsed, new_elapsed, failures])
	get_tree().quit(1 if failures else 0)
