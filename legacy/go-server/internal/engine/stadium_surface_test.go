package engine

import (
	"compress/gzip"
	"encoding/json"
	"math"
	"math/rand"
	"os"
	"testing"
)

// Coplanar cleanup may change triangulation but must not create walk/shoot holes.
func TestStadiumRepairPreservesSurfaceCoverage(t *testing.T) {
	file, err := os.Open("testdata/stadium-before-repair.json.gz")
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()
	reader, err := gzip.NewReader(file)
	if err != nil {
		t.Fatal(err)
	}
	defer reader.Close()
	var original struct {
		Triangles []float32 `json:"triangles"`
	}
	if err = json.NewDecoder(reader).Decode(&original); err != nil {
		t.Fatal(err)
	}
	faces := make([]triangle, 0, len(original.Triangles)/9)
	for i := 0; i < len(original.Triangles); i += 9 {
		v := original.Triangles[i : i+9]
		faces = append(faces, triangle{vector{v[0], v[1], v[2]}, vector{v[3], v[4], v[5]}, vector{v[6], v[7], v[8]}})
	}
	before := &mapGeometry{root: buildCollision(faces)}
	after := geometryFor("football")
	rng := rand.New(rand.NewSource(7081))
	for i := 0; i < 10000; i++ {
		x, y, z := rng.Float32()*175-82, rng.Float32()*42-12, rng.Float32()*205-90
		var from, to vector
		switch i % 3 {
		case 0:
			from, to = vector{x, 40, z}, vector{x, -20, z}
		case 1:
			from, to = vector{-100, y, z}, vector{110, y, z}
		case 2:
			from, to = vector{x, y, -105}, vector{x, y, 125}
		}
		a, _, hitA := before.trace(from, to)
		b, _, hitB := after.trace(from, to)
		errorMetres := float32(math.Abs(float64(a-b))) * distance(from, to)
		if hitA != hitB || (hitA && errorMetres > 0.002) {
			t.Fatalf("surface changed on ray %d %v -> %v: before=%v/%g after=%v/%g error=%gm", i, from, to, hitA, a, hitB, b, errorMetres)
		}
	}
	t.Log("10,000 ground/wall/roof rays preserve surface coverage within 2 mm")
}
