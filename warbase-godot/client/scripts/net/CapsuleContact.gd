class_name CapsuleContact
extends RefCounted
## Closest-feature contact between a vertical capsule and one packed triangle.
## Feet-origin capsule: its sphere centres are radius above its two ends.

static func capsule_triangle(feet: Vector3, radius: float, height: float, vertices: PackedFloat32Array, index: int, margin: float = 0.0) -> Dictionary:
	var offset := index * 9
	if index < 0 or offset + 8 >= vertices.size(): return {}
	var a := Vector3(vertices[offset], vertices[offset + 1], vertices[offset + 2])
	var b := Vector3(vertices[offset + 3], vertices[offset + 4], vertices[offset + 5])
	var c := Vector3(vertices[offset + 6], vertices[offset + 7], vertices[offset + 8])
	var extent := radius + margin
	if maxf(a.x,maxf(b.x,c.x)) < feet.x-extent or minf(a.x,minf(b.x,c.x)) > feet.x+extent or maxf(a.y,maxf(b.y,c.y)) < feet.y-margin or minf(a.y,minf(b.y,c.y)) > feet.y+height+margin or maxf(a.z,maxf(b.z,c.z)) < feet.z-extent or minf(a.z,minf(b.z,c.z)) > feet.z+extent: return {}
	var p := feet + Vector3.UP * radius
	var q := feet + Vector3.UP * (height - radius)
	var triangle_point := _point_triangle(p, a, b, c)
	var axis_point := p
	var best := p.distance_squared_to(triangle_point)
	var candidate := _point_triangle(q, a, b, c)
	var candidate_distance := q.distance_squared_to(candidate)
	if candidate_distance < best:
		best = candidate_distance
		axis_point = q
		triangle_point = candidate
	var pair := _closest_segments(p, q, a, b)
	if pair[2] < best:
		best = pair[2]
		axis_point = pair[0]
		triangle_point = pair[1]
	var pair_bc := _closest_segments(p, q, b, c)
	if pair_bc[2] < best:
		best = pair_bc[2]
		axis_point = pair_bc[0]
		triangle_point = pair_bc[1]
	var pair_ca := _closest_segments(p, q, c, a)
	if pair_ca[2] < best:
		best = pair_ca[2]
		axis_point = pair_ca[0]
		triangle_point = pair_ca[1]
	var normal := (b - a).cross(c - a)
	var normal_length := normal.length()
	if normal_length < 1e-10: return {}
	var direction := q - p
	var denominator := normal.dot(direction)
	if absf(denominator) > 1e-10:
		var t := normal.dot(a - p) / denominator
		if t >= 0.0 and t <= 1.0:
			var on_axis := p + direction * t
			var closest := _point_triangle(on_axis, a, b, c)
			if on_axis.distance_squared_to(closest) < 1e-12:
				axis_point = on_axis
				triangle_point = on_axis
				best = 0.0
	if best >= extent * extent: return {}
	var surface_normal_y := normal.y / normal_length
	var distance := sqrt(best)
	if distance > 1e-7:
		normal = (axis_point - triangle_point) / distance
	else:
		normal /= normal_length
		var middle := (p + q) * 0.5
		if normal.dot(middle - a) < 0.0: normal = -normal
	return {"normal": normal, "depth": extent - distance, "surface_normal_y": surface_normal_y}

static func _point_triangle(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := point - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0: return a
	var bp := point - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3: return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp := point - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6: return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and d4 - d3 >= 0.0 and d5 - d6 >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var inverse := 1.0 / (va + vb + vc)
	return a + ab * (vb * inverse) + ac * (vc * inverse)

static func _closest_segments(p: Vector3, q: Vector3, a: Vector3, b: Vector3) -> Array:
	var d1 := q - p
	var d2 := b - a
	var r := p - a
	var aa := d1.dot(d1)
	var ee := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if aa <= 1e-12 and ee <= 1e-12:
		return [p, a, p.distance_squared_to(a)]
	if aa <= 1e-12:
		t = clampf(f / ee, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		if ee <= 1e-12:
			s = clampf(-c / aa, 0.0, 1.0)
		else:
			var bb := d1.dot(d2)
			var denominator := aa * ee - bb * bb
			s = clampf((bb * f - c * ee) / denominator, 0.0, 1.0) if denominator > 1e-12 else 0.0
			t = (bb * s + f) / ee
			if t < 0.0:
				t = 0.0
				s = clampf(-c / aa, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((bb - c) / aa, 0.0, 1.0)
	var point_on_axis := p + d1 * s
	var point_on_edge := a + d2 * t
	return [point_on_axis, point_on_edge, point_on_axis.distance_squared_to(point_on_edge)]
