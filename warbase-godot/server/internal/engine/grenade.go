package engine

import (
	"google.golang.org/protobuf/proto"
	"math"
	"time"
)

type serverGrenade struct {
	kind          string
	id            uint64
	owner         string
	pos, velocity vector
	age           float32
}

// Keep these values in sync with GrenadeBallistics.gd. Sweeps include the body
// radius so fast throws cannot tunnel through thin walls or clip their edges.
const grenadeGravity float32 = 9.81
const grenadeAirDrag float32 = 0.035
const grenadeRadius float32 = 0.06
const grenadeRestitution float32 = 0.35
const grenadeTangentRetention float32 = 0.70
const grenadeGroundFriction float32 = 10

func (g *mapGeometry) grenadeTrace(from, to vector) (float32, vector, bool) {
	closest := float32(2)
	normal := vector{}
	for _, offset := range []vector{{}, {grenadeRadius, 0, 0}, {-grenadeRadius, 0, 0}, {0, grenadeRadius, 0}, {0, -grenadeRadius, 0}, {0, 0, grenadeRadius}, {0, 0, -grenadeRadius}} {
		a := vector{from[0] + offset[0], from[1] + offset[1], from[2] + offset[2]}
		b := vector{to[0] + offset[0], to[1] + offset[1], to[2] + offset[2]}
		if fraction, n, hit := g.trace(a, b); hit && fraction < closest {
			closest, normal = fraction, n
		}
	}
	if dot(sub(to, from), normal) > 0 {
		normal = vector{-normal[0], -normal[1], -normal[2]}
	}
	return closest, normal, closest <= 1
}

func stepGrenade(geometry *mapGeometry, g *serverGrenade, dt float32) bool {
	g.velocity[1] -= grenadeGravity * dt * 0.5
	for axis := range g.velocity {
		g.velocity[axis] *= max(float32(0), 1-grenadeAirDrag*dt)
	}
	remaining := dt
	for bounce := 0; bounce < 4; bounce++ {
		end := vector{g.pos[0] + g.velocity[0]*remaining, g.pos[1] + g.velocity[1]*remaining, g.pos[2] + g.velocity[2]*remaining}
		fraction, normal, hit := geometry.grenadeTrace(g.pos, end)
		if !hit {
			g.pos = end
			break
		}
		step := sub(end, g.pos)
		for axis := range g.pos {
			g.pos[axis] += step[axis]*fraction + normal[axis]*0.002
		}
		if g.kind == "impact" && g.age >= 0.18 {
			g.velocity = vector{}
			return true
		}
		incoming := dot(g.velocity, normal)
		tangent := vector{g.velocity[0] - normal[0]*incoming, g.velocity[1] - normal[1]*incoming, g.velocity[2] - normal[2]*incoming}
		if -incoming > 1.5 {
			for axis := range g.velocity {
				g.velocity[axis] = tangent[axis]*grenadeTangentRetention - normal[axis]*incoming*grenadeRestitution
			}
		} else {
			g.velocity = tangent
		}
		remaining *= 1 - fraction
		if remaining < 0.00001 {
			break
		}
	}
	g.velocity[1] -= grenadeGravity * dt * 0.5
	if math.Abs(float64(g.velocity[1])) < 1 {
		end := vector{g.pos[0], g.pos[1] - 0.025, g.pos[2]}
		if fraction, normal, hit := geometry.grenadeTrace(g.pos, end); hit && normal[1] > 0.65 {
			g.pos[1] -= 0.025 * fraction
			for axis := range g.pos {
				g.pos[axis] += normal[axis] * 0.002
			}
			projection := dot(g.velocity, normal)
			tangent := vector{g.velocity[0] - normal[0]*projection, g.velocity[1] - normal[1]*projection, g.velocity[2] - normal[2]*projection}
			speed := float32(math.Sqrt(float64(dot(tangent, tangent))))
			factor := float32(0)
			if speed > 0 {
				factor = max(float32(0), 1-grenadeGroundFriction*dt/speed)
			}
			for axis := range g.velocity {
				g.velocity[axis] = tangent[axis] * factor
			}
		}
	}
	return false
}

func (m *Match) advanceGrenades(room *Room, dt float32) {
	alive := room.Grenades[:0]
	for _, g := range room.Grenades {
		if room.State != "PLAYING" {
			continue
		}
		steps := max(1, int(math.Ceil(float64(dt/(1.0/120)))))
		step := dt / float32(steps)
		exploded := false
		for i := 0; i < steps; i++ {
			g.age += step
			if stepGrenade(room.Geometry, g, step) {
				exploded = true
				break
			}
		}
		fuse := float32(3)
		if g.kind == "impact" {
			fuse = 1.8
		}
		if exploded || g.age >= fuse {
			m.explodeGrenade(room, g)
		} else {
			alive = append(alive, g)
		}
	}
	room.Grenades = alive
}
func (m *Match) explodeGrenade(room *Room, g *serverGrenade) {
	event := &ServerMessage{Message: &ServerMessage_ServerEvent{ServerEvent: &ServerEvent{Event: &ServerEvent_Explosion{Explosion: &ServerExplosionEvent{ThrowableId: g.kind, GrenadeId: g.id, ShooterId: g.owner, X: g.pos[0], Y: g.pos[1], Z: g.pos[2]}}}}}
	data, _ := proto.Marshal(event)
	for session := range room.Sessions {
		session.EnqueueDirectEvent(data)
	}
	radius, peak := float32(8.5), float32(90)
	if g.kind == "impact" {
		radius, peak = 5.5, 75
	}
	ownerIdx, hasOwner := room.PlayerIndices[g.owner]
	if hasOwner {
		for _, vehicle := range room.Vehicles {
			center := vector{vehicle.state.X, vehicle.state.Y + 1, vehicle.state.Z}
			d := distance(center, g.pos)
			if d < radius && !room.Geometry.blocked(g.pos, center) {
				m.damageVehicle(room, &room.PlayerEntities[ownerIdx], vehicle, int32(peak*4*(1-d/radius)))
			}
		}
	}

	for i := range room.PlayerEntities {
		target := &room.PlayerEntities[i]
		if target.State.IsDead || target.State.DrivingVehicleId != "" || time.Now().Before(target.ProtectedUntil) {
			continue
		}
		if hasOwner && room.Mode == "TDM" && target.ID != g.owner && target.State.Team == room.PlayerEntities[ownerIdx].State.Team {
			continue
		}
		center := vector{target.State.X, target.State.Y + 0.9, target.State.Z}
		delta := sub(center, g.pos)
		distance := float32(math.Sqrt(float64(dot(delta, delta))))
		if distance >= radius || room.Geometry.blocked(g.pos, center) {
			continue
		}
		damage := int32(peak * (1 - distance/radius))
		if damage <= 0 {
			continue
		}
		target.LastDamageTime = time.Now()
		target.RegenRemainder = 0
		target.State.Health -= damage
		if target.State.Health > 0 {
			continue
		}
		target.State.Health = 0
		target.State.IsDead = true
		target.State.Animation = "death"
		target.State.Deaths++
		target.DeathTime = time.Now()
		if hasOwner && target.ID != g.owner {
			owner := &room.PlayerEntities[ownerIdx]
			owner.State.Kills++
			if room.Mode == "TDM" {
				if owner.State.Team == "A" {
					room.ScoreTeamA++
				} else {
					room.ScoreTeamB++
				}
			}
			winner := ""
			if room.Mode == "FFA" && owner.State.Kills >= 30 {
				winner = owner.ID
			}
			if room.Mode == "TDM" && room.ScoreTeamA >= 60 {
				winner = "A"
			}
			if room.Mode == "TDM" && room.ScoreTeamB >= 60 {
				winner = "B"
			}
			if winner != "" {
				room.WinnerID = winner
				room.State = "FINISHED"
				room.StateTimer = time.Now().Add(10 * time.Second)
			}
			m.sendDirectEventLocked(room, owner.ID, &ServerMessage{Message: &ServerMessage_ServerEvent{ServerEvent: &ServerEvent{Event: &ServerEvent_KillConfirmed{KillConfirmed: &KillConfirmedEvent{}}}}})
		}
	}
	room.CachedGameState.ScoreTeamA = room.ScoreTeamA
	room.CachedGameState.ScoreTeamB = room.ScoreTeamB
	room.CachedGameState.RoomState = room.State
	room.CachedGameState.WinnerId = room.WinnerID
}
