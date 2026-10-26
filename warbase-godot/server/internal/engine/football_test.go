package engine

import "testing"

func TestFootballMapNavigation(t *testing.T) {
	loadGeometry()
	g, ok := geometryMaps["football"]
	if !ok || len(g.spawns) != 12 {
		t.Fatal("football map is missing its own geometry/spawns")
	}
	n := navigationFor(g)
	for i, p := range g.spawns {
		node := n.nearest(p, g)
		connected := false
		if node >= 0 {
			connected = len(n.path(n.nearest(g.spawns[0], g), node)) > 0
		}
		t.Logf("spawn=%d p=%v nearest=%d connectedToPitch=%v", i, p, node, connected)
		if node < 0 {
			t.Errorf("spawn %d unreachable", i)
		}
		if !connected {
			t.Errorf("spawn %d is disconnected from the pitch", i)
		}
	}
	t.Logf("navigation nodes=%d", len(n.nodes))
}
