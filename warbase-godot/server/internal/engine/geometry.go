package engine

import (
	"bytes"
	"compress/gzip"
	"embed"
	"encoding/json"
	"math"
	"sort"
	"sync"
)

//go:embed maps.json.gz
var mapFiles embed.FS

type vector [3]float32

func sub(a, b vector) vector  { return vector{a[0] - b[0], a[1] - b[1], a[2] - b[2]} }
func dot(a, b vector) float32 { return a[0]*b[0] + a[1]*b[1] + a[2]*b[2] }
func cross(a, b vector) vector {
	return vector{a[1]*b[2] - a[2]*b[1], a[2]*b[0] - a[0]*b[2], a[0]*b[1] - a[1]*b[0]}
}

type triangle struct{ a, b, c vector }
type bounds struct{ min, max vector }
type collisionNode struct {
	box         bounds
	left, right *collisionNode
	faces       []triangle
}
type mapGeometry struct {
	spawnOnce       sync.Once
	spawnCandidates []vector
	navStep         float32
	vehicleSpawns   [][4]float32
	spawns          []vector
	root            *collisionNode
}

var geometryOnce sync.Once
var geometryMaps map[string]*mapGeometry

func loadGeometry() {
	geometryOnce.Do(func() {
		data, err := mapFiles.ReadFile("maps.json.gz")
		if err != nil {
			panic(err)
		}
		var encoded map[string]struct {
			NavStep   float32      `json:"nav_step"`
			Spawns    []vector     `json:"spawns"`
			Vehicles  [][4]float32 `json:"vehicles"`
			Triangles []float32    `json:"triangles"`
		}
		reader, err := gzip.NewReader(bytes.NewReader(data))
		if err != nil {
			panic(err)
		}
		defer reader.Close()
		if err = json.NewDecoder(reader).Decode(&encoded); err != nil {
			panic(err)
		}
		geometryMaps = make(map[string]*mapGeometry)
		for name, entry := range encoded {
			faces := make([]triangle, 0, len(entry.Triangles)/9)
			for i := 0; i+8 < len(entry.Triangles); i += 9 {
				v := entry.Triangles[i : i+9]
				faces = append(faces, triangle{vector{v[0], v[1], v[2]}, vector{v[3], v[4], v[5]}, vector{v[6], v[7], v[8]}})
			}
			geometryMaps[name] = &mapGeometry{navStep: entry.NavStep, spawns: entry.Spawns, root: buildCollision(faces), vehicleSpawns: entry.Vehicles}
		}
	})
}
func geometryFor(name string) *mapGeometry {
	loadGeometry()
	if g := geometryMaps[name]; g != nil {
		return g
	}
	return geometryMaps["industrial"]
}
func buildCollision(faces []triangle) *collisionNode {
	if len(faces) == 0 {
		return nil
	}
	n := &collisionNode{box: bounds{min: vector{math.MaxFloat32, math.MaxFloat32, math.MaxFloat32}, max: vector{-math.MaxFloat32, -math.MaxFloat32, -math.MaxFloat32}}}
	for _, t := range faces {
		for _, v := range []vector{t.a, t.b, t.c} {
			for k := 0; k < 3; k++ {
				if v[k] < n.box.min[k] {
					n.box.min[k] = v[k]
				}
				if v[k] > n.box.max[k] {
					n.box.max[k] = v[k]
				}
			}
		}
	}
	if len(faces) <= 12 {
		n.faces = faces
		return n
	}
	axis := 0
	for k := 1; k < 3; k++ {
		if n.box.max[k]-n.box.min[k] > n.box.max[axis]-n.box.min[axis] {
			axis = k
		}
	}
	sort.Slice(faces, func(i, j int) bool {
		return faces[i].a[axis]+faces[i].b[axis]+faces[i].c[axis] < faces[j].a[axis]+faces[j].b[axis]+faces[j].c[axis]
	})
	mid := len(faces) / 2
	n.left = buildCollision(faces[:mid])
	n.right = buildCollision(faces[mid:])
	return n
}
func (b bounds) intersects(origin, delta vector, limit float32) bool {
	low, high := float32(0), min(float32(1), limit)
	for k := 0; k < 3; k++ {
		if math.Abs(float64(delta[k])) < 1e-8 {
			if origin[k] < b.min[k] || origin[k] > b.max[k] {
				return false
			}
			continue
		}
		a := (b.min[k] - origin[k]) / delta[k]
		c := (b.max[k] - origin[k]) / delta[k]
		if a > c {
			a, c = c, a
		}
		if a > low {
			low = a
		}
		if c < high {
			high = c
		}
		if low > high {
			return false
		}
	}
	return true
}
func triangleFraction(t triangle, origin, delta vector) (float32, bool) {
	e1, e2 := sub(t.b, t.a), sub(t.c, t.a)
	h := cross(delta, e2)
	det := dot(e1, h)
	if math.Abs(float64(det)) < 1e-8 {
		return 0, false
	}
	inv := 1 / det
	s := sub(origin, t.a)
	u := inv * dot(s, h)
	if u < 0 || u > 1 {
		return 0, false
	}
	q := cross(s, e1)
	v := inv * dot(delta, q)
	if v < 0 || u+v > 1 {
		return 0, false
	}
	fraction := inv * dot(e2, q)
	return fraction, fraction >= 0 && fraction <= 1
}
func (n *collisionNode) ray(origin, delta vector, nearest *float32, normal *vector) {
	if n == nil || !n.box.intersects(origin, delta, *nearest) {
		return
	}
	for _, face := range n.faces {
		if t, ok := triangleFraction(face, origin, delta); ok && t < *nearest {
			*nearest = t
			nrm := cross(sub(face.b, face.a), sub(face.c, face.a))
			length := float32(math.Sqrt(float64(dot(nrm, nrm))))
			if length > 0 {
				*normal = vector{nrm[0] / length, nrm[1] / length, nrm[2] / length}
			}
		}
	}
	n.left.ray(origin, delta, nearest, normal)
	n.right.ray(origin, delta, nearest, normal)
}
func (g *mapGeometry) blocked(origin, end vector) bool {
	if g == nil {
		return true
	}
	delta := sub(end, origin)
	length := float32(math.Sqrt(float64(dot(delta, delta))))
	if length < 0.05 {
		return false
	}
	nearest := float32(2)
	normal := vector{}
	g.root.ray(origin, delta, &nearest, &normal)
	return nearest > 0.02/length && nearest < 1-0.04/length
}

func (g *mapGeometry) trace(origin, end vector) (float32, vector, bool) {
	nearest := float32(2)
	normal := vector{}
	g.root.ray(origin, sub(end, origin), &nearest, &normal)
	return nearest, normal, nearest <= 1
}

func (g *mapGeometry) movementBlocked(from, to vector) bool {
	// Sweep several samples across the standing capsule's torso, independently of rendering LOD.
	for _, offset := range []vector{{0, 0.9, 0}, {-0.25, 0.9, 0}, {0.25, 0.9, 0}, {0, 0.9, -0.25}, {0, 0.9, 0.25}} {
		a := vector{from[0] + offset[0], from[1] + offset[1], from[2] + offset[2]}
		b := vector{to[0] + offset[0], to[1] + offset[1], to[2] + offset[2]}
		if fraction, _, hit := g.trace(a, b); hit && fraction > 0.0001 {
			return true
		}
	}
	return false
}
