package engine

import "math"

// Keep spawn selection local to authored play areas, but give a full room more
// than a handful of identical positions. Ground, headroom and the route from
// the authored spawn are checked once; live occupancy is scored on each spawn.
func (g *mapGeometry) safeSpawnCandidates() []vector {
	g.spawnOnce.Do(func() {
		g.spawnCandidates = append(g.spawnCandidates, g.spawns...)
		if g.root == nil {
			return
		}
		for _, base := range g.spawns {
			for x := -3; x <= 3; x++ {
				for z := -3; z <= 3; z++ {
					if x == 0 && z == 0 {
						continue
					}
					at := vector{base[0] + float32(x)*1.4, base[1], base[2] + float32(z)*1.4}
					from, to := vector{at[0], base[1] + 0.6, at[2]}, vector{at[0], base[1] - 0.6, at[2]}
					f, n, hit := g.trace(from, to)
					if !hit || math.Abs(float64(n[1])) < 0.7 {
						continue
					}
					at[1] = from[1] + (to[1]-from[1])*f + 0.05
					if g.movementBlocked(base, at) {
						continue
					}
					clear := true
					for _, offset := range []vector{{0, 0, 0}, {.4, 0, 0}, {-.4, 0, 0}, {0, 0, .4}, {0, 0, -.4}} {
						a := vector{at[0] + offset[0], at[1] + .15, at[2] + offset[2]}
						b := vector{a[0], at[1] + 1.8, a[2]}
						if _, _, blocked := g.trace(a, b); blocked {
							clear = false
							break
						}
					}
					if clear {
						g.spawnCandidates = append(g.spawnCandidates, at)
					}
				}
			}
		}
	})
	return g.spawnCandidates
}
