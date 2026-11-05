package engine

import (
	"container/heap"
	"math"
	"sync"
)

// A shared, collision-derived walk graph. Separate floors remain separate nodes.
type navNode struct {
	position vector
	edges    []int
}
type navigation struct{ nodes []navNode }

var navigationCache sync.Map

func navigationFor(g *mapGeometry) *navigation {
	build := sync.OnceValue(func() *navigation { return buildNavigation(g) })
	entry, _ := navigationCache.LoadOrStore(g, build)
	return entry.(func() *navigation)()
}

func distance(a, b vector) float32 {
	d := sub(a, b)
	return float32(math.Sqrt(float64(dot(d, d))))
}
func position(p *Player) vector { return vector{p.State.X, p.State.Y, p.State.Z} }
func eye(p *Player) vector      { return vector{p.State.X, p.State.Y + 1.35, p.State.Z} }

func buildNavigation(g *mapGeometry) *navigation {
	nav := &navigation{}
	if g == nil || len(g.spawns) == 0 {
		return nav
	}
	low, high := g.spawns[0], g.spawns[0]
	for _, p := range g.spawns {
		for k := range p {
			low[k] = min(low[k], p[k])
			high[k] = max(high[k], p[k])
		}
	}
	step := g.navStep
	if step <= 0 {
		step = 2
	}
	cells := map[[2]int][]int{}
	minX, maxX := int(math.Floor(float64((low[0]-10)/step))), int(math.Ceil(float64((high[0]+10)/step)))
	minZ, maxZ := int(math.Floor(float64((low[2]-10)/step))), int(math.Ceil(float64((high[2]+10)/step)))
	for x := minX; x <= maxX; x++ {
		for z := minZ; z <= maxZ; z++ {
			origin, end := vector{float32(x) * step, high[1] + 1, float32(z) * step}, vector{float32(x) * step, low[1] - 3, float32(z) * step}
			for layer := 0; layer < 8 && origin[1] > end[1]; layer++ {
				fraction, normal, hit := g.trace(origin, end)
				if !hit {
					break
				}
				y := origin[1] + (end[1]-origin[1])*fraction
				origin[1] = y - 0.08
				if math.Abs(float64(normal[1])) < 0.7 {
					continue
				}
				p := vector{end[0], y + 0.05, end[2]}
				clear := true
				for _, offset := range []vector{{0, 0, 0}, {0.32, 0, 0}, {-0.32, 0, 0}, {0, 0, 0.32}, {0, 0, -0.32}} {
					a := vector{p[0] + offset[0], p[1] + 0.15, p[2] + offset[2]}
					b := vector{a[0], p[1] + 1.8, a[2]}
					if _, _, blocked := g.trace(a, b); blocked {
						clear = false
						break
					}
				}
				if !clear {
					continue
				}
				cells[[2]int{x, z}] = append(cells[[2]int{x, z}], len(nav.nodes))
				nav.nodes = append(nav.nodes, navNode{position: p})
			}
		}
	}
	for cell, indices := range cells {
		for _, i := range indices {
			for _, delta := range [][2]int{{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}} {
				for _, j := range cells[[2]int{cell[0] + delta[0], cell[1] + delta[1]}] {
					a, b := nav.nodes[i].position, nav.nodes[j].position
					if math.Abs(float64(a[1]-b[1])) > 0.6 || g.movementBlocked(a, b) {
						continue
					}
					// Reject edges across pits, ledges, and diagonal gaps.
					mid := vector{(a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2}
					if _, _, supported := g.trace(vector{mid[0], mid[1] + 0.3, mid[2]}, vector{mid[0], mid[1] - 0.65, mid[2]}); !supported {
						continue
					}
					nav.nodes[i].edges = append(nav.nodes[i].edges, j)
				}
			}
		}
	}
	return nav
}

func (n *navigation) nearest(p vector, g *mapGeometry) int {
	best, score := -1, float32(9)
	for i, node := range n.nodes {
		d := distance(p, node.position)
		if d < score && math.Abs(float64(p[1]-node.position[1])) < 1 && !g.movementBlocked(p, node.position) {
			best, score = i, d
		}
	}
	return best
}

type navItem struct {
	id    int
	score float32
}
type navHeap []navItem

func (h navHeap) Len() int           { return len(h) }
func (h navHeap) Less(i, j int) bool { return h[i].score < h[j].score }
func (h navHeap) Swap(i, j int)      { h[i], h[j] = h[j], h[i] }
func (h *navHeap) Push(x any)        { *h = append(*h, x.(navItem)) }
func (h *navHeap) Pop() any          { old := *h; x := old[len(old)-1]; *h = old[:len(old)-1]; return x }

func (n *navigation) path(start, goal int, blocked ...func(vector) bool) []int {
	if start < 0 || goal < 0 {
		return nil
	}
	frontier := &navHeap{{start, 0}}
	cost, previous := map[int]float32{start: 0}, map[int]int{start: -1}
	for expanded := 0; frontier.Len() > 0 && expanded < 6000; expanded++ {
		current := heap.Pop(frontier).(navItem).id
		if current == goal {
			path := []int{}
			for current != -1 {
				path = append(path, current)
				current = previous[current]
			}
			for a, b := 0, len(path)-1; a < b; a, b = a+1, b-1 {
				path[a], path[b] = path[b], path[a]
			}
			return path
		}
		for _, next := range n.nodes[current].edges {
			if len(blocked) > 0 && blocked[0](n.nodes[next].position) {
				continue
			}
			candidate := cost[current] + distance(n.nodes[current].position, n.nodes[next].position)
			if old, ok := cost[next]; !ok || candidate < old {
				cost[next], previous[next] = candidate, current
				heap.Push(frontier, navItem{next, candidate + distance(n.nodes[next].position, n.nodes[goal].position)})
			}
		}
	}
	return nil
}
