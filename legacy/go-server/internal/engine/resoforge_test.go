package engine

import "testing"

func TestResoforgeMapSpawnsAndNavigation(t *testing.T) {
	loadGeometry()
	g, ok := geometryMaps["resoforge"]
	if !ok || len(g.spawns) != 12 {
		t.Fatal("ResoForge is missing its own map geometry and spawns")
	}
	n := navigationFor(g)
	for _, p := range g.spawns {
		if n.nearest(p, g) < 0 {
			t.Errorf("spawn %v has no reachable bot navigation", p)
		}
		if _, _, hit := g.trace(vector{p[0], p[1] + 0.1, p[2]}, vector{p[0], p[1] - 0.3, p[2]}); !hit {
			t.Errorf("spawn %v has no ground", p)
		}
	}
	// Both ends of the yard must connect through at least one flank lane.
	a, b := n.nearest(g.spawns[0], g), n.nearest(g.spawns[6], g)
	if a < 0 || b < 0 || len(n.path(a, b)) == 0 {
		t.Fatal("map ends have no connecting bot route")
	}
	t.Logf("ResoForge: %d navigation nodes, all 12 spawns accessible", len(n.nodes))
}
