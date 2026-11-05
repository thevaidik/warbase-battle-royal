package engine

import "math"

// hitboxTolerance allows small float and transform rounding differences while
// keeping the server's hit regions close to the client collision shapes.
const hitboxTolerance = 0.02

type hitZone struct {
	name   string
	kind   byte
	center [3]float64
	size   [3]float64
	height float64
	radius float64
}

var playerHitZones = [...]hitZone{
	{name: "head", kind: 'c', center: [3]float64{0, 1.62, 0}, height: 0.38, radius: 0.12},
	{name: "torso", kind: 'b', center: [3]float64{0, 1.05, 0}, size: [3]float64{0.42, 0.6, 0.32}},
	{name: "torso", kind: 'b', center: [3]float64{0, 1.39, 0}, size: [3]float64{0.16, 0.10, 0.14}},
	{name: "stomach", kind: 'b', center: [3]float64{0, 0.72, 0}, size: [3]float64{0.40, 0.20, 0.30}},
	{name: "arm", kind: 'c', center: [3]float64{-0.3, 1.2, 0}, height: 0.26, radius: 0.07},
	{name: "arm", kind: 'c', center: [3]float64{0.3, 1.2, 0}, height: 0.26, radius: 0.07},
	{name: "leg", kind: 'c', center: [3]float64{-0.12, 0.45, 0}, height: 0.6, radius: 0.09},
	{name: "leg", kind: 'c', center: [3]float64{0.12, 0.45, 0}, height: 0.6, radius: 0.09},
}

// tracePlayerHit returns the nearest intersected anatomical zone and the
// normalized distance along a finite world-space shot segment. targetRotation
// uses the PlayerState quaternion order [x, y, z, w].
func tracePlayerHit(origin, end, targetPosition vector, targetRotation [4]float32) (zone string, fraction float32, ok bool) {
	if !finiteVec(origin) || !finiteVec(end) || !finiteVec(targetPosition) {
		return "", 0, false
	}
	qx, qy, qz, qw := float64(targetRotation[0]), float64(targetRotation[1]), float64(targetRotation[2]), float64(targetRotation[3])
	if !finite(qx) || !finite(qy) || !finite(qz) || !finite(qw) {
		return "", 0, false
	}
	qLen := math.Sqrt(qx*qx + qy*qy + qz*qz + qw*qw)
	if qLen < 1e-6 {
		// The client also treats an uninitialized zero quaternion as identity.
		qx, qy, qz, qw = 0, 0, 0, 1
	} else {
		qx, qy, qz, qw = qx/qLen, qy/qLen, qz/qLen, qw/qLen
	}

	startWorld := dvec{float64(origin[0]), float64(origin[1]), float64(origin[2])}
	endWorld := dvec{float64(end[0]), float64(end[1]), float64(end[2])}
	base := dvec{float64(targetPosition[0]), float64(targetPosition[1]), float64(targetPosition[2])}
	start := rotateByQuaternion(subD(startWorld, base), -qx, -qy, -qz, qw)
	finish := rotateByQuaternion(subD(endWorld, base), -qx, -qy, -qz, qw)
	if lengthSquaredD(subD(finish, start)) < 1e-12 {
		return "", 0, false
	}

	best := math.Inf(1)
	boxTolerance := hitboxTolerance / math.Sqrt(3)
	for _, hitbox := range playerHitZones {
		var t float64
		var intersects bool
		center := dvec{hitbox.center[0], hitbox.center[1], hitbox.center[2]}
		if hitbox.kind == 'b' {
			// Expanding each face by this amount bounds corner tolerance to 2cm.
			half := dvec{hitbox.size[0]/2 + boxTolerance, hitbox.size[1]/2 + boxTolerance, hitbox.size[2]/2 + boxTolerance}
			t, intersects = segmentBox(start, finish, center, half)
		} else {
			t, intersects = segmentCapsule(start, finish, center, hitbox.height, hitbox.radius+hitboxTolerance)
		}
		if intersects && t < best {
			best = t
			zone = hitbox.name
			ok = true
		}
	}
	if !ok {
		return "", 0, false
	}
	return zone, float32(best), true
}

type dvec struct{ x, y, z float64 }

func (v dvec) at(t float64) dvec { return dvec{v.x * t, v.y * t, v.z * t} }

func subD(a, b dvec) dvec { return dvec{a.x - b.x, a.y - b.y, a.z - b.z} }

func lengthSquaredD(v dvec) float64 { return v.x*v.x + v.y*v.y + v.z*v.z }

func finite(v float64) bool { return !math.IsNaN(v) && !math.IsInf(v, 0) }

func finiteVec(v vector) bool {
	return finite(float64(v[0])) && finite(float64(v[1])) && finite(float64(v[2]))
}

func rotateByQuaternion(v dvec, x, y, z, w float64) dvec {
	// q*v*q^-1, expressed as two cross products. q is normalized by caller.
	tx := 2 * (y*v.z - z*v.y)
	ty := 2 * (z*v.x - x*v.z)
	tz := 2 * (x*v.y - y*v.x)
	return dvec{
		v.x + w*tx + (y*tz - z*ty),
		v.y + w*ty + (z*tx - x*tz),
		v.z + w*tz + (x*ty - y*tx),
	}
}

func segmentBox(start, end, center, half dvec) (float64, bool) {
	delta := subD(end, start)
	lo, hi := 0.0, 1.0
	startsInside := true
	starts := [3]float64{start.x - center.x, start.y - center.y, start.z - center.z}
	deltas := [3]float64{delta.x, delta.y, delta.z}
	halves := [3]float64{half.x, half.y, half.z}
	for axis := 0; axis < 3; axis++ {
		if math.Abs(starts[axis]) > halves[axis] {
			startsInside = false
		}
		if math.Abs(deltas[axis]) < 1e-12 {
			if math.Abs(starts[axis]) > halves[axis] {
				return 0, false
			}
			continue
		}
		a := (-halves[axis] - starts[axis]) / deltas[axis]
		b := (halves[axis] - starts[axis]) / deltas[axis]
		if a > b {
			a, b = b, a
		}
		if a > lo {
			lo = a
		}
		if b < hi {
			hi = b
		}
		if lo > hi {
			return 0, false
		}
	}
	if startsInside {
		return 0, true
	}
	return lo, hi >= 0 && lo <= 1
}

func segmentCapsule(start, end, center dvec, height, radius float64) (float64, bool) {
	delta := subD(end, start)
	rel := subD(start, center)
	axisHalf := math.Max(0, height/2-radius)
	if pointCapsuleDistanceSquared(rel, axisHalf) <= radius*radius {
		return 0, true
	}
	best := math.Inf(1)
	// Intersect the finite cylindrical section.
	a := delta.x*delta.x + delta.z*delta.z
	b := 2 * (rel.x*delta.x + rel.z*delta.z)
	c := rel.x*rel.x + rel.z*rel.z - radius*radius
	if a > 1e-12 {
		disc := b*b - 4*a*c
		if disc >= 0 {
			sqrtDisc := math.Sqrt(disc)
			for _, t := range [2]float64{(-b - sqrtDisc) / (2 * a), (-b + sqrtDisc) / (2 * a)} {
				y := rel.y + t*delta.y
				if t >= 0 && t <= 1 && math.Abs(y) <= axisHalf && t < best {
					best = t
				}
			}
		}
	}
	// The rounded capsule ends are spheres centered at the cylinder endpoints.
	for _, y := range [2]float64{-axisHalf, axisHalf} {
		if t, hit := segmentSphere(rel, delta, dvec{0, y, 0}, radius); hit && t < best {
			best = t
		}
	}
	return best, best <= 1
}

func pointCapsuleDistanceSquared(point dvec, axisHalf float64) float64 {
	y := math.Max(-axisHalf, math.Min(axisHalf, point.y))
	dx, dy, dz := point.x, point.y-y, point.z
	return dx*dx + dy*dy + dz*dz
}

func segmentSphere(start, delta, center dvec, radius float64) (float64, bool) {
	rel := subD(start, center)
	a := lengthSquaredD(delta)
	b := 2 * (rel.x*delta.x + rel.y*delta.y + rel.z*delta.z)
	c := lengthSquaredD(rel) - radius*radius
	disc := b*b - 4*a*c
	if disc < 0 || a < 1e-12 {
		return 0, false
	}
	t := (-b - math.Sqrt(disc)) / (2 * a)
	if t < 0 {
		t = (-b + math.Sqrt(disc)) / (2 * a)
	}
	return t, t >= 0 && t <= 1
}
