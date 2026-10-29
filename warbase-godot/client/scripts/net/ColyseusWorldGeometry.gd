class_name ColyseusWorldGeometry
extends RefCounted
## Authored map geometry and movement helpers for the Colyseus client.
##
## Uses the same triangle source, prebuilt BVH nodes, capsule sample points,
## axis order, ray tolerances, and 0.45 m step as the TypeScript server helper.
## The capsule sweep is a deterministic approximation; it does not implement
## Godot's native safe margin, floor snap, velocity/gravity, or crouch capsule.

const DATA_DIR := "res://assets/data/maps/"
const INDUSTRIAL_FALLBACK_PATH := "res://assets/data/industrial.json.gz"
const PLAYABLE_MAPS: Array[String] = ["football", "resoforge", "industrial", "village", "arena", "shipment", "dust2", "nuketown", "canyon", "desert_oasis"]
const NODE_STRIDE := 10
const SPOKES := 12
const CAPSULE_LEVELS: Array[float] = [0.08, 0.24, 0.4, 0.9, 1.4, 1.56, 1.72]
const MOVE_CANDIDATE_LIMIT := 12
const SWEEP_EPSILON := 0.0001

static var _loaded := false
static var _loaded_map := ""
static var _map_override := ""
static var _vertices := PackedFloat32Array()
static var _nodes := PackedFloat32Array()
static var _order := PackedInt32Array()
static var _spawns: Array[Vector3] = []
static var _ray_stack: Array[int] = []
static var _move_candidate_stack: Array[int] = []
static var _move_candidate_triangles: Array[int] = []


static func _ensure_data() -> void:
	var map_name := _map_override
	if map_name.is_empty():
		var tree := Engine.get_main_loop() as SceneTree
		var game_state := tree.root.get_node_or_null("GameState") if tree != null else null
		map_name = String(game_state.get("selected_map")) if game_state != null else "industrial"
	map_name = map_name.strip_edges().to_lower()
	if not PLAYABLE_MAPS.has(map_name):
		map_name = "industrial"
	if _loaded and _loaded_map == map_name:
		return
	_loaded = false
	_loaded_map = ""
	_vertices.clear()
	_nodes.clear()
	_order.clear()
	_spawns.clear()
	var data_path := DATA_DIR + map_name + ".json.gz"
	if not FileAccess.file_exists(data_path) and map_name == "industrial":
		data_path = INDUSTRIAL_FALLBACK_PATH
	var packed := FileAccess.get_file_as_bytes(data_path)
	if packed.is_empty():
		push_error("ColyseusWorldGeometry: cannot read authored map %s" % data_path)
		return
	var decoded := packed.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	if decoded.is_empty():
		push_error("ColyseusWorldGeometry: cannot decompress %s geometry" % map_name)
		return
	var data: Variant = JSON.parse_string(decoded.get_string_from_utf8())
	if not data is Dictionary:
		push_error("ColyseusWorldGeometry: invalid %s geometry JSON" % map_name)
		return
	_vertices = PackedFloat32Array(data.get("triangles", []))
	_nodes = PackedFloat32Array(data.get("nodes", []))
	_order = PackedInt32Array(data.get("order", []))
	if _vertices.is_empty() or _vertices.size() % 9 != 0 or _nodes.is_empty() or _nodes.size() % NODE_STRIDE != 0 or _order.size() != _vertices.size() / 9:
		push_error("ColyseusWorldGeometry: invalid %s BVH dimensions" % map_name)
		_vertices.clear()
		_nodes.clear()
		_order.clear()
		return
	for entry in data.get("spawns", []):
		if entry is Array and entry.size() == 3 and is_finite(float(entry[0])) and is_finite(float(entry[1])) and is_finite(float(entry[2])):
			_spawns.append(Vector3(float(entry[0]), float(entry[1]), float(entry[2])))
	if _spawns.is_empty():
		push_error("ColyseusWorldGeometry: no authored %s spawns" % map_name)
		return
	_loaded_map = map_name
	_loaded = true


## Optional explicit selection for standalone geometry fixtures and tools.
static func set_map_override(map_name: String = "") -> void:
	_map_override = map_name.strip_edges().to_lower()
	_loaded = false


static func get_authored_spawns() -> Array[Vector3]:
	_ensure_data()
	return _spawns.duplicate()


static func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


static func _box_intersects(node_index: int, origin: Vector3, delta: Vector3, limit: float) -> bool:
	var offset := node_index * NODE_STRIDE
	var low := 0.0
	var high := minf(1.0, limit)
	for axis in range(3):
		var minimum: float = _nodes[offset + axis]
		var maximum: float = _nodes[offset + 3 + axis]
		var origin_axis: float = origin[axis]
		var delta_axis: float = delta[axis]
		if absf(delta_axis) < 0.000000001:
			if origin_axis < minimum or origin_axis > maximum:
				return false
			continue
		var first := (minimum - origin_axis) / delta_axis
		var last := (maximum - origin_axis) / delta_axis
		if first > last:
			var swap := first
			first = last
			last = swap
		low = maxf(low, first)
		high = minf(high, last)
		if low > high:
			return false
	return true


static func _triangle_hit(triangle_index: int, origin: Vector3, delta: Vector3) -> Dictionary:
	var offset := triangle_index * 9
	var a := Vector3(_vertices[offset], _vertices[offset + 1], _vertices[offset + 2])
	var edge_1 := Vector3(_vertices[offset + 3], _vertices[offset + 4], _vertices[offset + 5]) - a
	var edge_2 := Vector3(_vertices[offset + 6], _vertices[offset + 7], _vertices[offset + 8]) - a
	var h := delta.cross(edge_2)
	var determinant := edge_1.dot(h)
	if absf(determinant) < 0.000000001:
		return {}
	var inverse := 1.0 / determinant
	var from_a := origin - a
	var u := inverse * from_a.dot(h)
	if u < 0.0 or u > 1.0:
		return {}
	var q := from_a.cross(edge_1)
	var v := inverse * delta.dot(q)
	if v < 0.0 or u + v > 1.0:
		return {}
	var fraction := inverse * edge_2.dot(q)
	if fraction < 0.0 or fraction > 1.0:
		return {}
	var normal := edge_1.cross(edge_2)
	var length := normal.length()
	if length == 0.0:
		return {}
	return {"fraction": fraction, "normal": normal / length}


static func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	_ensure_data()
	if _nodes.is_empty() or not _finite_vector(from) or not _finite_vector(to):
		return {}
	var delta := to - from
	var nearest := 2.0
	var best := {}
	# Collision/prediction calls run synchronously on the main thread. Keep the
	# traversal scratch capacity between rays instead of allocating 91 stacks
	# for every capsule sweep.
	_ray_stack.clear()
	_ray_stack.append(0)
	while not _ray_stack.is_empty():
		var node_index: int = _ray_stack.pop_back()
		var offset := node_index * NODE_STRIDE
		if not _box_intersects(node_index, from, delta, nearest):
			continue
		var left := int(_nodes[offset + 6])
		var right := int(_nodes[offset + 7])
		var start := int(_nodes[offset + 8])
		var count := int(_nodes[offset + 9])
		if count > 0:
			for index in range(start, start + count):
				var candidate := _triangle_hit(_order[index], from, delta)
				if not candidate.is_empty() and float(candidate["fraction"]) < nearest:
					nearest = float(candidate["fraction"])
					best = candidate
		else:
			if left >= 0:
				_ray_stack.append(left)
			if right >= 0:
				_ray_stack.append(right)
	return best


static func _triangle_bounds_overlap(triangle_index: int, minimum: Vector3, maximum: Vector3) -> bool:
	var offset := triangle_index * 9
	for axis in range(3):
		var a: float = _vertices[offset + axis]
		var b: float = _vertices[offset + 3 + axis]
		var c: float = _vertices[offset + 6 + axis]
		if minf(a, minf(b, c)) > maximum[axis] or maxf(a, maxf(b, c)) < minimum[axis]:
			return false
	return true


## Gather exact vertex-AABB candidates once for the full movement envelope.
## Returning false means the set exceeded the small-cache limit and callers
## should use the original per-ray BVH traversal instead.
static func _prepare_move_candidates(from: Vector3, to: Vector3, radius: float, height: float) -> bool:
	_move_candidate_triangles.clear()
	_move_candidate_stack.clear()
	if _nodes.is_empty():
		return false
	var bounds_min := Vector3(minf(from.x, to.x) - radius - SWEEP_EPSILON, minf(from.y, to.y) + 0.08 - SWEEP_EPSILON, minf(from.z, to.z) - radius - SWEEP_EPSILON)
	var bounds_max := Vector3(maxf(from.x, to.x) + radius + SWEEP_EPSILON, maxf(from.y, to.y) + 0.45 + minf(height, 1.72) + SWEEP_EPSILON, maxf(from.z, to.z) + radius + SWEEP_EPSILON)
	_move_candidate_stack.append(0)
	while not _move_candidate_stack.is_empty():
		var node_index: int = _move_candidate_stack.pop_back()
		var offset := node_index * NODE_STRIDE
		var overlaps := true
		for axis in range(3):
			if _nodes[offset + axis] > bounds_max[axis] or _nodes[offset + 3 + axis] < bounds_min[axis]:
				overlaps = false
				break
		if not overlaps:
			continue
		var left := int(_nodes[offset + 6])
		var right := int(_nodes[offset + 7])
		var start := int(_nodes[offset + 8])
		var count := int(_nodes[offset + 9])
		if count > 0:
			for index in range(start, start + count):
				var triangle_index := _order[index]
				if not _triangle_bounds_overlap(triangle_index, bounds_min, bounds_max):
					continue
				_move_candidate_triangles.append(triangle_index)
				if _move_candidate_triangles.size() > MOVE_CANDIDATE_LIMIT:
					_move_candidate_triangles.clear()
					_move_candidate_stack.clear()
					return false
		else:
			# Same traversal order as _raycast: right child is popped first.
			if left >= 0:
				_move_candidate_stack.append(left)
			if right >= 0:
				_move_candidate_stack.append(right)
	_move_candidate_stack.clear()
	return true


static func _raycast_move_candidates(from: Vector3, to: Vector3) -> Dictionary:
	if not _finite_vector(from) or not _finite_vector(to):
		return {}
	var delta := to - from
	var nearest := 2.0
	var best := {}
	for triangle_index in _move_candidate_triangles:
		var candidate := _triangle_hit(triangle_index, from, delta)
		if not candidate.is_empty() and float(candidate["fraction"]) < nearest:
			nearest = float(candidate["fraction"])
			best = candidate
	return best


static func ray_blocked(from: Vector3, to: Vector3) -> bool:
	if not _finite_vector(from) or not _finite_vector(to):
		return true
	var length := from.distance_to(to)
	if length < 0.05:
		return false
	var hit := _raycast(from, to)
	if hit.is_empty():
		return false
	var fraction: float = hit["fraction"]
	return fraction > 0.02 / length and fraction < 1.0 - 0.04 / length


## Highest walkable surface on the selected authored map beneath from_y, or null.
static func floor_height(x: float, z: float, from_y: float = 100.0) -> Variant:
	if not is_finite(x) or not is_finite(z) or not is_finite(from_y):
		return null
	var hit := _raycast(Vector3(x, from_y, z), Vector3(x, -100.0, z))
	if hit.is_empty() or absf(hit["normal"].y) < 0.5:
		return null
	return from_y + (-100.0 - from_y) * float(hit["fraction"])


static func _capsule_blocked(from: Vector3, to: Vector3, radius: float, height: float, horizontal_only: bool = false, use_move_candidates: bool = false) -> bool:
	# A zero-length sweep cannot hit a triangle: the ray/triangle determinant is
	# zero for every sample. Avoid constructing 7 x 13 degenerate rays on axes
	# that did not move; this preserves the exact collision result.
	if from == to:
		return false
	var delta_y := to.y - from.y
	for y_offset in CAPSULE_LEVELS:
		if y_offset > height:
			continue
		var ring_radius := radius
		if y_offset < radius:
			ring_radius = sqrt(maxf(0.0, radius * radius - pow(radius - y_offset, 2.0)))
		elif y_offset > height - radius:
			ring_radius = sqrt(maxf(0.0, radius * radius - pow(y_offset - (height - radius), 2.0)))
		for spoke in range(SPOKES + 1):
			var angle := 0.0 if spoke == SPOKES else (2.0 * PI * float(spoke)) / float(SPOKES)
			var offset_x := 0.0 if spoke == SPOKES else cos(angle) * ring_radius
			var offset_z := 0.0 if spoke == SPOKES else sin(angle) * ring_radius
			var offset := Vector3(offset_x, y_offset, offset_z)
			var sample_from := from + offset
			var sample_to := to + offset
			var hit := _raycast_move_candidates(sample_from, sample_to) if use_move_candidates else _raycast(sample_from, sample_to)
			if hit.is_empty() or float(hit["fraction"]) <= 0.0001:
				continue
			if horizontal_only and absf(delta_y) < 0.000001 and absf(hit["normal"].y) >= 0.5:
				continue
			return true
	return false


## Feet-origin capsule motion with axis sliding and a 0.45 m grounded step.
static func resolve_move(from: Vector3, to: Vector3, radius: float = 0.4, height: float = 1.8, use_candidate_cache: bool = true) -> Vector3:
	_ensure_data()
	if not _finite_vector(from):
		return _spawns[0] if not _spawns.is_empty() else Vector3.ZERO
	if not _finite_vector(to) or not is_finite(radius) or not is_finite(height) or radius <= 0.0 or height < 2.0 * radius:
		return from
	radius = minf(radius, 1.5)
	height = minf(height, 4.0)
	var use_move_candidates := use_candidate_cache and _prepare_move_candidates(from, to, radius, height)
	var position := from
	var step_height := 0.45
	var target_floor: Variant = floor_height(to.x, to.z, position.y + step_height)
	if target_floor != null and float(target_floor) > position.y + 0.03 and float(target_floor) <= position.y + step_height:
		var stepped_from := Vector3(position.x, float(target_floor), position.z)
		var stepped_target := Vector3(to.x, float(target_floor), to.z)
		if not _capsule_blocked(position, stepped_from, radius, height, false, use_move_candidates) and not _capsule_blocked(stepped_from, stepped_target, radius, height, true, use_move_candidates):
			position = stepped_target

	for axis in [0, 2]:
		var current := position
		var destination := Vector3(to.x, position.y, position.z) if axis == 0 else Vector3(position.x, position.y, to.z)
		if not _capsule_blocked(current, destination, radius, height, true, use_move_candidates):
			position = destination
			continue
		var safe := 0.0
		var blocked := 1.0
		for _iteration in range(10):
			var middle := (safe + blocked) * 0.5
			var candidate := Vector3(position.x + (destination.x - position.x) * middle, position.y, position.z) if axis == 0 else Vector3(position.x, position.y, position.z + (destination.z - position.z) * middle)
			if _capsule_blocked(current, candidate, radius, height, true, use_move_candidates):
				blocked = middle
			else:
				safe = middle
		if axis == 0:
			position.x += (destination.x - position.x) * safe
		else:
			position.z += (destination.z - position.z) * safe

	var floor: Variant = floor_height(position.x, position.z, maxf(position.y, to.y) + step_height)
	var target_y := to.y
	if floor != null and target_y <= float(floor) and position.y >= float(floor) - step_height:
		target_y = float(floor)
	var vertical_target := Vector3(position.x, target_y, position.z)
	if not _capsule_blocked(position, vertical_target, radius, height, false, use_move_candidates):
		position = vertical_target
	else:
		var safe := 0.0
		var blocked := 1.0
		for _iteration in range(10):
			var middle := (safe + blocked) * 0.5
			var candidate := Vector3(position.x, position.y + (target_y - position.y) * middle, position.z)
			if _capsule_blocked(position, candidate, radius, height, false, use_move_candidates):
				blocked = middle
			else:
				safe = middle
		position.y += (target_y - position.y) * safe
	return position
