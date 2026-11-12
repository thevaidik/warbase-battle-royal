package engine

import "testing"

func TestFireRelevancePreservesNearbyDanger(t *testing.T) {
	r := &Room{PlayerIndices: map[string]int{"p": 0}, PlayerEntities: []Player{{State: &PlayerState{}}}}
	for _, c := range []struct {
		name string
		fire *FireEvent
		want bool
	}{
		{"nearby", &FireEvent{OriginX: 10, HitX: 11, ShotId: 2}, true},
		{"passing bullet", &FireEvent{OriginX: 80, HitX: -80, ShotId: 2}, true},
		{"distant sampled tracer", &FireEvent{OriginX: 80, HitX: 81, ShotId: 1}, true},
		{"distant alternate tracer", &FireEvent{OriginX: 80, HitX: 81, ShotId: 2}, false},
		{"outside hearing", &FireEvent{OriginX: 150, HitX: 151, ShotId: 1}, false},
	} {
		t.Run(c.name, func(t *testing.T) {
			if relevantFire(r, "p", c.fire) != c.want {
				t.Fatal("incorrect relevance")
			}
		})
	}
}
