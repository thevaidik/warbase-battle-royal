package engine

import "testing"

func TestIndustrialRoadsAndAuthoredBoundaries(t *testing.T) {
	for _, id := range []string{"industrial", "dust2", "nuketown", "canyon"} {
		t.Run(id, func(t *testing.T) {
			g := geometryFor(id)
			for _, z := range []float32{-20, 20, 35} {
				if g.movementBlocked(vector{67, 0.5, z}, vector{73, 0.5, z}) {
					t.Errorf("invisible wall still blocks east road at z=%g", z)
				}
				if !g.movementBlocked(vector{77, 0.5, z}, vector{81, 0.5, z}) {
					t.Errorf("visible perimeter fence lost movement collision at z=%g", z)
				}
			}
			if !g.movementBlocked(vector{-12, 1.1, -10}, vector{-8, 1.1, -10}) {
				t.Fatal("warehouse wall lost movement collision")
			}
		})
	}
}
