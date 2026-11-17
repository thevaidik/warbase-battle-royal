class_name ColyseusWorldGeometry
extends RefCounted
## Authored map geometry and movement helpers for the Colyseus client.
##
## Uses the same BVH, capsule/triangle closest-feature contacts, 8 mm skin,
## substeps, support normals and 0.45 m grounded step as the TypeScript server.

const DATA_DIR := "res://assets/data/maps/"
const INDUSTRIAL_FALLBACK_PATH := "res://assets/data/industrial.json.gz"
const Capsule := preload("res://scripts/net/CapsuleContact.gd")
const PLAYABLE_MAPS: Array[String] = ["football", "industrial", "village", "arena", "dust2", "nuketown", "canyon", "military_base", "ghost_city"]
const NODE_STRIDE := 10
const SWEEP_EPSILON := 0.0001

static var _loaded := false
static var _loaded_map := ""
static var _map_override := ""
static var _vertices := PackedFloat32Array()
static var _triangle_a := PackedVector3Array()
static var _triangle_edge_1 := PackedVector3Array()
static var _triangle_edge_2 := PackedVector3Array()
static var _triangle_unit_normal := PackedVector3Array()
static var _nodes := PackedFloat32Array()
static var _order := PackedInt32Array()
static var _flight_prop_vertices := PackedFloat32Array()
static var _flight_prop_bounds: Array[Dictionary] = []
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
	_triangle_a.clear()
	_triangle_edge_1.clear()
	_triangle_edge_2.clear()
	_triangle_unit_normal.clear()
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
	var triangle_count := _vertices.size() / 9
	_triangle_a.resize(triangle_count)
	_triangle_edge_1.resize(triangle_count)
	_triangle_edge_2.resize(triangle_count)
	_triangle_unit_normal.resize(triangle_count)
	for triangle_index in triangle_count:
		var offset := triangle_index * 9
		var a := Vector3(_vertices[offset], _vertices[offset + 1], _vertices[offset + 2])
		var edge_1 := Vector3(_vertices[offset + 3], _vertices[offset + 4], _vertices[offset + 5]) - a
		var edge_2 := Vector3(_vertices[offset + 6], _vertices[offset + 7], _vertices[offset + 8]) - a
		var normal := edge_1.cross(edge_2)
		var length := normal.length()
		_triangle_a[triangle_index] = a
		_triangle_edge_1[triangle_index] = edge_1
		_triangle_edge_2[triangle_index] = edge_2
		_triangle_unit_normal[triangle_index] = Vector3.ZERO if length == 0.0 else normal / length
	for entry in data.get("spawns", []):
		if entry is Array and entry.size() == 3 and is_finite(float(entry[0])) and is_finite(float(entry[1])) and is_finite(float(entry[2])):
			_spawns.append(Vector3(float(entry[0]), float(entry[1]), float(entry[2])))
	if _spawns.is_empty():
		push_error("ColyseusWorldGeometry: no authored %s spawns" % map_name)
		return
	_loaded_map = map_name
	_loaded = true
	_build_flight_props(data.get("vehicles", []))


static func _build_flight_props(vehicles: Array) -> void:
	_flight_prop_vertices.clear()
	_flight_prop_bounds.clear()
	var faces := [[0,2,1],[0,3,2],[4,5,6],[4,6,7],[0,1,5],[0,5,4],[3,7,6],[3,6,2],[0,4,7],[0,7,3],[1,2,6],[1,6,5]]
	for spawn in vehicles:
		var from := Vector3(spawn[0],spawn[1]+2.5,spawn[2])
		var hit := _raycast(from,Vector3(spawn[0],spawn[1]-5.0,spawn[2]))
		var base_y: float = float(spawn[1])
		if not hit.is_empty() and absf(Vector3(hit.normal).y)>=0.65: base_y=from.y-7.5*float(hit.fraction)+0.08
		for bounds in [[Vector3(-1.15,0.4,-2.5),Vector3(1.15,1.5,2.5)],[Vector3(-1.1,1.475,-1.8),Vector3(1.1,2.425,2.2)]]:
			var lo: Vector3=bounds[0];var hi: Vector3=bounds[1]
			var c:=cos(float(spawn[3]));var ss:=sin(float(spawn[3]))
			var points: Array[Vector3] = []
			for point in [Vector3(lo.x,lo.y,lo.z),Vector3(hi.x,lo.y,lo.z),Vector3(hi.x,hi.y,lo.z),Vector3(lo.x,hi.y,lo.z),Vector3(lo.x,lo.y,hi.z),Vector3(hi.x,lo.y,hi.z),Vector3(hi.x,hi.y,hi.z),Vector3(lo.x,hi.y,hi.z)]:
				points.append(Vector3(float(spawn[0])+c*point.x+ss*point.z,base_y+point.y,float(spawn[2])-ss*point.x+c*point.z))
			var minimum:=points[0];var maximum:=points[0]
			for point in points: minimum=minimum.min(point);maximum=maximum.max(point)
			_flight_prop_bounds.append({"min":minimum,"max":maximum,"first":_flight_prop_vertices.size()/9})
			for face in faces:
				for index in face:
					var point: Vector3=points[index]
					_flight_prop_vertices.append_array(PackedFloat32Array([point.x,point.y,point.z]))

static func _contact_triangle(at: Vector3,radius: float,height: float,triangle: int,margin: float) -> Dictionary:
	return Capsule.capsule_triangle(at,radius,height,_flight_prop_vertices if triangle<0 else _vertices,-triangle-1 if triangle<0 else triangle,margin)

## Optional explicit selection for standalone geometry fixtures and tools.
static func set_map_override(map_name: String = "") -> void:
	var normalized := map_name.strip_edges().to_lower()
	if normalized == _map_override:
		return
	_map_override = normalized
	_loaded = false


static func get_authored_spawns() -> Array[Vector3]:
	_ensure_data()
	return _spawns.duplicate()

static func get_loaded_map() -> String:
	_ensure_data()
	return _loaded_map

static func settled_vertical_velocity(vy: float, requested_y: float, resolved_y: float, grounded: bool) -> float:
	if vy < 0.0 and grounded: return 0.0
	if vy > 0.0 and resolved_y < requested_y - 0.001: return 0.0
	return vy


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


static func _triangle_fraction(triangle_index: int, origin: Vector3, delta: Vector3) -> float:
	var a := _triangle_a[triangle_index]
	var edge_1 := _triangle_edge_1[triangle_index]
	var edge_2 := _triangle_edge_2[triangle_index]
	var h := delta.cross(edge_2)
	var determinant := edge_1.dot(h)
	if absf(determinant) < 0.000000001:
		return -1.0
	var inverse := 1.0 / determinant
	var from_a := origin - a
	var u := inverse * from_a.dot(h)
	if u < 0.0 or u > 1.0:
		return -1.0
	var q := from_a.cross(edge_1)
	var v := inverse * delta.dot(q)
	if v < 0.0 or u + v > 1.0:
		return -1.0
	var fraction := inverse * edge_2.dot(q)
	if fraction < 0.0 or fraction > 1.0:
		return -1.0
	var normal := _triangle_unit_normal[triangle_index]
	if normal == Vector3.ZERO:
		return -1.0
	return fraction


# Compatibility helper for triangle parity diagnostics; hot paths use a scalar.
static func _triangle_hit(triangle_index: int, origin: Vector3, delta: Vector3) -> Dictionary:
	var fraction := _triangle_fraction(triangle_index, origin, delta)
	return {} if fraction < 0.0 else {"fraction": fraction, "normal": _triangle_unit_normal[triangle_index]}


static func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	_ensure_data()
	if _nodes.is_empty() or not _finite_vector(from) or not _finite_vector(to):
		return {}
	var delta := to - from
	var nearest := 2.0
	var best_index := -1
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
				var triangle_index := _order[index]
				var fraction := _triangle_fraction(triangle_index, from, delta)
				if fraction >= 0.0 and fraction < nearest:
					nearest = fraction
					best_index = triangle_index
		else:
			if left >= 0:
				_ray_stack.append(left)
			if right >= 0:
				_ray_stack.append(right)
	return {} if best_index < 0 else {"fraction": nearest, "normal": _triangle_unit_normal[best_index]}


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
## Bounds include the complete lower hemisphere, step and head clearance.
static func _prepare_move_candidates(from: Vector3, to: Vector3, radius: float, height: float, step_height: float = 0.5) -> bool:
	_move_candidate_triangles.clear()
	_move_candidate_stack.clear()
	if _nodes.is_empty():
		return false
	var bounds_min := Vector3(minf(from.x, to.x) - radius - step_height - SWEEP_EPSILON, minf(from.y, to.y) - step_height - radius - SWEEP_EPSILON, minf(from.z, to.z) - radius - step_height - SWEEP_EPSILON)
	var bounds_max := Vector3(maxf(from.x, to.x) + radius + step_height + SWEEP_EPSILON, maxf(from.y, to.y) + step_height + height + radius + SWEEP_EPSILON, maxf(from.z, to.z) + radius + step_height + SWEEP_EPSILON)
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
		else:
			# Same traversal order as _raycast: right child is popped first.
			if left >= 0:
				_move_candidate_stack.append(left)
			if right >= 0:
				_move_candidate_stack.append(right)
	_move_candidate_stack.clear()
	return true


## Return an owned candidate list because grounded/step-up queries reuse the traversal scratch.
static func _capsule_candidates(from: Vector3, to: Vector3, radius: float, height: float, step_height: float) -> Array[int]:
	_prepare_move_candidates(from, to, radius, height, step_height)
	return _move_candidate_triangles.duplicate()


static func _capsule_contacts(at: Vector3, radius: float, height: float, margin: float, candidates: Array[int]) -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	for triangle_index in candidates:
		var contact: Dictionary = _contact_triangle(at, radius, height, triangle_index, margin)
		if not contact.is_empty(): contacts.append(contact)
	return contacts


## A walkable map surface must support the lower capsule hemisphere.
static func is_grounded(at: Vector3, radius: float = 0.4, height: float = 1.8) -> bool:
	_ensure_data()
	if not _finite_vector(at) or _nodes.is_empty(): return false
	var candidates := _capsule_candidates(at, at, radius + 0.06, height, 0.0)
	for contact in _capsule_contacts(at, radius, height, 0.055, candidates):
		if (Vector3(contact.normal).y >= 0.5 or (absf(float(contact.surface_normal_y)) >= 0.5 and Vector3(contact.normal).y > 0.05)) and float(contact.depth) <= 0.09: return true
	return false


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


## Feet-origin capsule contacts, sliding, and grounded stepping.
static func resolve_flight_move(from: Vector3, to: Vector3, radius: float = 0.4, step_height: float = 0.0) -> Vector3:
	var result := resolve_move(from - Vector3.UP*radius, to - Vector3.UP*radius, radius, radius * 2.0, true, step_height > 0.0, step_height, true)
	return result + Vector3.UP*radius

static func _canonical_move(p: Vector3) -> Vector3:
	return Vector3(floorf(p.x*1000.0+0.5)/1000.0, floorf(p.y*1000.0+0.5)/1000.0, floorf(p.z*1000.0+0.5)/1000.0)

static func resolve_move(from: Vector3, to: Vector3, radius: float = 0.4, height: float = 1.8, use_candidate_cache: bool = true, allow_step: bool = true, step_height: float = 0.45, drone_move: bool = false) -> Vector3:
	_ensure_data()
	if not _finite_vector(from):
		return _spawns[0] if not _spawns.is_empty() else Vector3.ZERO
	if not _finite_vector(to) or not is_finite(radius) or not is_finite(height) or radius <= 0.0 or height < 2.0 * radius:
		return from
	radius = minf(radius, 1.5)
	height = minf(height, 4.0)
	var grounded := allow_step and is_grounded(from, radius, height)
	# Candidate caching is deterministic and unbounded; the flag remains for call-site compatibility.
	var candidates := _capsule_candidates(from, to, radius, height, maxf(0.5, step_height))
	if not allow_step or drone_move:
		for box in _flight_prop_bounds:
			var lo: Vector3=box.min;var hi: Vector3=box.max
			if hi.x<minf(from.x,to.x)-radius-0.5 or lo.x>maxf(from.x,to.x)+radius+0.5 or hi.y<minf(from.y,to.y)-0.5 or lo.y>maxf(from.y,to.y)+height+0.5 or hi.z<minf(from.z,to.z)-radius-0.5 or lo.z>maxf(from.z,to.z)+radius+0.5: continue
			for index in 12: candidates.append(-(int(box.first)+index+1))
	var skin := 0.008
	var delta := to - from
	var count := maxi(1, ceili(delta.length() / minf(radius * 0.25, 0.1)))
	if count > 512: return from
	var recover := func(start: Vector3) -> Vector3:
		var position := start
		for _iteration in range(4):
			var corrected := false
			for triangle_index in candidates:
				var hit: Dictionary = _contact_triangle(position, radius, height, triangle_index, skin)
				if hit.is_empty() or float(hit.depth) <= 0.000001: continue
				position += Vector3(hit.normal) * float(hit.depth)
				corrected = true
			if not corrected: break
		return position
	var attempt := func(previous: Vector3, desired: Vector3) -> Vector3:
		var next: Vector3 = recover.call(desired)
		if next.distance_to(desired) > 0.2: return previous
		for contact in _capsule_contacts(next, radius, height, skin, candidates):
			if float(contact.depth) > 0.001: return previous
		return next
	var advance := func(previous: Vector3, desired: Vector3) -> Vector3:
		var next: Vector3 = attempt.call(previous, desired)
		if _canonical_move(next) != _canonical_move(previous): return next
		var result := previous
		for axis in [1,0,2]:
			var amount: float = desired[axis] - previous[axis]
			if amount == 0.0: continue
			var target := result
			target[axis] += amount
			result = attempt.call(result, target)
		return result
	var position: Vector3 = advance.call(from, from)
	for _substep in range(count):
		position = advance.call(position, position + delta / float(count))
	var horizontal := Vector2(delta.x, delta.z).length()
	if grounded and horizontal == 0.0 and delta.y <= 0.0: return _canonical_move(advance.call(from, from))
	var step_tolerance := minf(0.01, horizontal * 0.25) if drone_move else 0.01
	if grounded and delta.y <= 0.0 and horizontal > 0.000001 and Vector2(position.x - from.x, position.z - from.z).dot(Vector2(delta.x,delta.z)) / horizontal < horizontal - step_tolerance:
		var up := Vector3(from.x, from.y + step_height, from.z)
		if _capsule_contacts(up, radius, height, skin, candidates).is_empty():
			var step := up
			for _substep in range(count):
				step = advance.call(step, step + Vector3(delta.x, 0.0, delta.z) / float(count))
			var clear := true
			var lift := 0.1
			while lift < step_height:
				var contacts := _capsule_contacts(Vector3(from.x, from.y + lift, from.z), radius, height, 0.0, candidates)
				for contact in contacts:
					if Vector3(contact.normal).y < -0.5:
						clear = false
						break
				if not clear: break
				lift += 0.1
			if clear:
				for _lower_step in range(6):
					step = advance.call(step, step + Vector3.DOWN * (step_height / 6.0))
				if Vector2(step.x - position.x, step.z - position.z).dot(Vector2(delta.x,delta.z)) / horizontal > 0.001 and is_grounded(step, radius, height):
					position = step
	return _canonical_move(position)
