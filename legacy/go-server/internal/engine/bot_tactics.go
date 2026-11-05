package engine

import (
	"math"
	"time"
)

// Threat awareness uses visible grenades, not knowledge of hidden projectiles.
func (m *Match) perceiveGrenades(r *Room, p *Player, now time.Time) {
	if r.Navigation == nil {
		return
	}
	b := p.Bot
	for _, g := range r.Grenades {
		radius := float32(8.5)
		if g.kind == "impact" {
			radius = 5.5
		}
		if g.age < 0.2 || distance(position(p), g.pos) > radius+3.5 || r.Geometry.blocked(eye(p), vector{g.pos[0], g.pos[1] + 0.15, g.pos[2]}) {
			continue
		}
		if now.Before(b.evadeUntil) && distance(b.escapeGoal, g.pos) > radius+1.5 {
			b.evadeUntil = now.Add(900 * time.Millisecond)
			continue
		}
		best := float32(math.MaxFloat32)
		var escape vector
		for _, node := range r.Navigation.nodes {
			d := distance(position(p), node.position)
			if d > 14 || distance(node.position, g.pos) < radius+1.5 || math.Abs(float64(node.position[1]-p.State.Y)) > 0.7 || r.vehicleMovementBlocked(node.position, node.position) {
				continue
			}
			if d < best && !r.Geometry.movementBlocked(position(p), node.position) {
				best = d
				escape = node.position
			}
		}
		if best < float32(math.MaxFloat32) {
			b.escapeGoal = escape
			b.evadeUntil = now.Add(900 * time.Millisecond)
			b.planAt = time.Time{}
		}
	}
}

// Nearby alternatives avoid squadmates bunching into the same doorway. Only
// known enemy locations are used, so searching never follows an unseen player.
func (r *Room) spacedApproach(p *Player, goal vector, fallback int, cover bool) int {
	best := float32(math.MaxFloat32)
	for i, node := range r.Navigation.nodes {
		cost := distance(goal, node.position)
		if cost > 4 || math.Abs(float64(node.position[1]-goal[1])) > 0.9 || r.vehicleMovementBlocked(node.position, node.position) {
			continue
		}
		if cover && !r.visionBlocked(vector{p.Bot.lastKnown[0], p.Bot.lastKnown[1] + 1.35, p.Bot.lastKnown[2]}, vector{node.position[0], node.position[1] + 1.35, node.position[2]}, p.ID) {
			continue
		}
		if r.Mode == "TDM" {
			for j := range r.PlayerEntities {
				ally := &r.PlayerEntities[j]
				if ally.ID != p.ID && !ally.State.IsDead && ally.State.Team == p.State.Team {
					cost += max(0, 3-distance(node.position, position(ally))) * 3
				}
			}
		}
		if cost < best {
			best = cost
			fallback = i
		}
	}
	return fallback
}
