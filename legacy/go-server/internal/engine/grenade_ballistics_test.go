package engine

import (
	"math"
	"testing"
)

func grenadeTestFloor() *mapGeometry {
	return &mapGeometry{root: buildCollision([]triangle{{vector{-100, 0, -100}, vector{100, 0, -100}, vector{100, 0, 100}}, {vector{-100, 0, -100}, vector{100, 0, 100}, vector{-100, 0, 100}}})}
}
func TestGrenadeBallisticArcBounceAndRest(t *testing.T) {
	g := &serverGrenade{kind: "frag", pos: vector{0, 1.6, 0}, velocity: vector{20, 6, 0}}
	geometry := grenadeTestFloor()
	first := -1
	for i := 0; i < 720; i++ {
		stepGrenade(geometry, g, 1.0/120)
		if i == 119 && (math.Abs(float64(g.pos[0]-19.65)) > 0.15 || g.pos[1] < 2.5) {
			t.Fatalf("lost ballistic flight: %+v", g)
		}
		if first < 0 && g.velocity[1] > 0 && i > 130 {
			first = i
			if g.pos[0] < 26 || g.pos[0] > 31 || g.velocity[0] < 12 || g.velocity[1] < 2 {
				t.Fatalf("bad first bounce: %+v", g)
			}
		}
	}
	if first < 150 || g.pos[1] < 0.05 || g.pos[0] > 45 || dot(g.velocity, g.velocity) > 0.15*0.15 {
		t.Fatalf("did not settle on visible floor: %+v first=%d", g, first)
	}
	t.Logf("landing frame=%d final=%v", first, g.pos)
}
func TestGrenadeThinWallAndImpact(t *testing.T) {
	geometry := &mapGeometry{root: buildCollision([]triangle{{vector{5, 0, -5}, vector{5, 4, -5}, vector{5, 4, 5}}, {vector{5, 0, -5}, vector{5, 4, 5}, vector{5, 0, 5}}})}
	for _, kind := range []string{"frag", "impact"} {
		g := &serverGrenade{kind: kind, age: 0.3, pos: vector{4, 1.5, 0}, velocity: vector{29, 0, 0}}
		impact := stepGrenade(geometry, g, 0.1)
		if g.pos[0] >= 5 || (kind == "frag" && g.velocity[0] >= 0) || impact != (kind == "impact") {
			t.Fatalf("thin wall/impact failed: %+v impact=%v", g, impact)
		}
	}
}
