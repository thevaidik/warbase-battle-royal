extends RefCounted
## Shared chamfered armor panels: bevels catch light without textures or shaders.

static var _cache: Dictionary = {}
static var _wing_cache: Dictionary = {}
static var _hull: ArrayMesh

static func hull() -> ArrayMesh:
	if _hull != null: return _hull
	var sections := [
		Vector4(-0.182, 0.059, 0.021, -0.019),
		Vector4(-0.176, 0.070, 0.029, -0.025),
		Vector4(-0.105, 0.123, 0.061, -0.049),
		Vector4(0.075, 0.137, 0.062, -0.058),
		Vector4(0.156, 0.096, 0.041, -0.043),
		Vector4(0.162, 0.088, 0.034, -0.036),
	]
	var rings: Array[PackedVector3Array] = []
	for section in sections:
		var ring := PackedVector3Array()
		var half_width: float = section.y
		var top: float = section.z
		var bottom: float = section.w
		for point in [
			Vector2(-half_width * 0.72, top), Vector2(half_width * 0.72, top),
			Vector2(half_width, top * 0.47), Vector2(half_width * 0.94, bottom * 0.55),
			Vector2(half_width * 0.58, bottom), Vector2(-half_width * 0.58, bottom),
			Vector2(-half_width * 0.94, bottom * 0.55), Vector2(-half_width, top * 0.47),
		]:
			ring.append(Vector3(point.x, point.y, section.x))
		rings.append(ring)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in rings.size() - 1:
		for i in 8:
			var next := (i + 1) % 8
			var a := rings[segment][i]
			var b := rings[segment][next]
			var c := rings[segment + 1][next]
			_quad(tool, [a, b, c, rings[segment + 1][i]], -(b - a).cross(c - a).normalized())
	var rear: PackedVector3Array = rings.back()
	for i in range(1, 7):
		_triangle(tool, rings[0][0], rings[0][i], rings[0][i + 1], Vector3.FORWARD)
		_triangle(tool, rear[0], rear[i], rear[i + 1], Vector3.BACK)
	tool.index()
	_hull = tool.commit()
	return _hull

static func swept_wing(side: float) -> ArrayMesh:
	if _wing_cache.has(side): return _wing_cache[side]
	# Root and tip profiles share a thin trailing edge and a raised upper panel.
	var root := [
		Vector3(side * 0.10, 0.006, -0.115), Vector3(side * 0.10, 0.027, -0.022),
		Vector3(side * 0.10, 0.005, 0.145), Vector3(side * 0.10, -0.014, -0.015),
	]
	var tip := [
		Vector3(side * 0.369, 0.011, 0.050), Vector3(side * 0.369, 0.017, 0.073),
		Vector3(side * 0.369, 0.011, 0.113), Vector3(side * 0.369, 0.006, 0.072),
	]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var next := (i + 1) % 4
		var a: Vector3 = root[i]
		var b: Vector3 = root[next]
		var c: Vector3 = tip[next]
		var d: Vector3 = tip[i]
		var normal := (b - a).cross(c - a).normalized() * side
		_quad(tool, [a, b, c, d], normal)
	_quad(tool, root, Vector3(-side, 0, 0))
	_quad(tool, tip, Vector3(side, 0, 0))
	tool.index()
	var mesh := tool.commit()
	_wing_cache[side] = mesh
	return mesh

static func panel(size: Vector3) -> ArrayMesh:
	if _cache.has(size): return _cache[size]
	var half := size * 0.5
	var bevel := minf(size.x, minf(size.y, size.z)) * 0.16
	var inset := half - Vector3.ONE * bevel
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Six large armor faces.
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for side in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = side
			var corners: Array[Vector3] = []
			for signs in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var point := Vector3.ZERO
				point[axis] = half[axis] * side
				point[u] = inset[u] * signs.x
				point[v] = inset[v] * signs.y
				corners.append(point)
			_quad(tool, corners, normal)
	# Twelve edge strips.
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for su in [-1.0,1.0]:
			for sv in [-1.0,1.0]:
				var a := Vector3.ZERO
				a[axis] = -inset[axis]
				a[u] = half[u] * su
				a[v] = inset[v] * sv
				var b := a
				b[axis] = inset[axis]
				var c := b
				c[u] = inset[u] * su
				c[v] = half[v] * sv
				var d := c
				d[axis] = -inset[axis]
				var normal := Vector3.ZERO
				normal[u] = su
				normal[v] = sv
				_quad(tool, [a,b,c,d], normal.normalized())
	# Eight triangular corner caps.
	for x in [-1.0,1.0]:
		for y in [-1.0,1.0]:
			for z in [-1.0,1.0]:
				var signs := Vector3(x,y,z)
				var a := inset * signs
				var b := a
				var c := a
				a.x = half.x * x
				b.y = half.y * y
				c.z = half.z * z
				_triangle(tool,a,b,c,signs.normalized())
	tool.index()
	var mesh := tool.commit()
	_cache[size] = mesh
	return mesh

static func _quad(tool: SurfaceTool, points: Array, normal: Vector3) -> void:
	_triangle(tool,points[0],points[1],points[2],normal)
	_triangle(tool,points[0],points[2],points[3],normal)

static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	# Godot front faces use clockwise winding.
	var points := [a,c,b] if (b-a).cross(c-a).dot(normal) > 0 else [a,b,c]
	for point in points:
		tool.set_normal(normal)
		tool.add_vertex(point)

static var _track: ArrayMesh

static func track_belt() -> ArrayMesh:
	if _track != null: return _track
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 48:
		var a := TAU * float(i) / 48.0
		var b := TAU * float(i + 1) / 48.0
		var za := 0.155 if cos(a) >= 0.0 else -0.155
		var zb := 0.155 if cos(b) >= 0.0 else -0.155
		var outer_a := Vector3(0, sin(a) * 0.056, za + cos(a) * 0.056)
		var outer_b := Vector3(0, sin(b) * 0.056, zb + cos(b) * 0.056)
		var inner_a := Vector3(0, sin(a) * 0.043, za + cos(a) * 0.043)
		var inner_b := Vector3(0, sin(b) * 0.043, zb + cos(b) * 0.043)
		var left := Vector3(-0.047, 0, 0)
		var right := -left
		var normal := Vector3(0, sin((a+b)*0.5), cos((a+b)*0.5))
		_quad(tool, [outer_a+left,outer_b+left,outer_b+right,outer_a+right], normal)
		_quad(tool, [inner_a+left,inner_b+left,inner_b+right,inner_a+right], -normal)
		for edge in [left,right]:
			_quad(tool,[outer_a+edge,outer_b+edge,inner_b+edge,inner_a+edge],edge.normalized())
	tool.index()
	_track = tool.commit()
	return _track

static func track_point(distance: float) -> Vector2:
	var radius := 0.057
	var arc := PI * radius
	if distance < 0.31:
		return Vector2(-0.155 + distance, radius)
	distance -= 0.31
	if distance < arc:
		var angle := PI / 2.0 - distance / radius
		return Vector2(0.155 + cos(angle) * radius, sin(angle) * radius)
	distance -= arc
	if distance < 0.31:
		return Vector2(0.155 - distance, -radius)
	distance -= 0.31
	var angle := -PI / 2.0 - distance / radius
	return Vector2(-0.155 + cos(angle) * radius, sin(angle) * radius)
