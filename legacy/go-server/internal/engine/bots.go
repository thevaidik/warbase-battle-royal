package engine

import (
	"fmt"
	"math"
	"math/rand/v2"
	"time"

	"google.golang.org/protobuf/proto"
)

// Online AI runs only on the authority. Its perception is deliberately imperfect:
// sight requires visibility, hearing supplies a last-known location, and shooting
// obeys the same magazines, reloads, cadence, occlusion and damage as humans.
type botBrain struct {
	intent                                             string
	evadeUntil, progressAt                             time.Time
	escapeGoal, progressPoint                          vector
	reposition                                         bool
	target                                             string
	lastKnown                                          vector
	seenUntil, reactAt, perceiveAt, planAt, burstUntil time.Time
	visible                                            bool
	path                                               []int
	waypoint, role, shots                              int
	rng                                                *rand.Rand
}

func (m *Match) syncBots(room *Room) {
	humans := len(room.Sessions)
	desired := max(0, 8-humans)
	if humans == 0 {
		desired = 0
	}
	// Human capacity is unchanged; AI yields slots as people arrive.
	for i := len(room.PlayerEntities) - 1; i >= 0; i-- {
		p := &room.PlayerEntities[i]
		if p.Bot == nil || len(room.Bots) <= desired {
			continue
		}
		id := p.ID
		last := len(room.PlayerEntities) - 1
		room.PlayerEntities[i] = room.PlayerEntities[last]
		room.PlayerIndices[room.PlayerEntities[i].ID] = i
		room.PlayerEntities = room.PlayerEntities[:last]
		delete(room.PlayerIndices, id)
		delete(room.CachedGameState.Players, id)
		delete(room.Bots, id)
		room.notifyDeparture(id)
	}
	if len(room.Bots) >= desired {
		room.botCount.Store(int32(len(room.Bots)))
		return
	}
	if room.Navigation == nil {
		if !room.navigationStarted {
			room.navigationStarted = true
			geometry := room.Geometry
			go func() { room.preparedNavigation.Store(navigationFor(geometry)) }()
		}
		room.Navigation = room.preparedNavigation.Load()
		if room.Navigation == nil {
			room.botCount.Store(int32(len(room.Bots)))
			return
		}
	}
	for len(room.Bots) < desired {
		room.BotSequence++
		id := fmt.Sprintf("[BOT] %s-%02d", []string{"VIPER", "KESTREL", "GHOST", "ROOK", "NOMAD", "LYNX", "WRAITH"}[(room.BotSequence-1)%7], room.BotSequence)
		p := NewPlayer(id)
		p.Bot = &botBrain{role: room.BotSequence % 3, rng: rand.New(rand.NewPCG(uint64(room.BotSequence), hashID(room.ID)))}
		weapons := []string{"m4", "mp5", "ak47", "dmr"}
		p.ActiveWeapon = Weapons[weapons[(room.BotSequence-1)%len(weapons)]]
		p.State.WeaponId = p.ActiveWeapon.ID
		p.State.Team = "NONE"
		if room.Mode == "TDM" {
			a, b := 0, 0
			for _, other := range room.PlayerEntities {
				if other.State.Team == "A" {
					a++
				} else if other.State.Team == "B" {
					b++
				}
			}
			p.State.Team = "A"
			if a > b {
				p.State.Team = "B"
			}
		}
		room.PlayerIndices[id] = len(room.PlayerEntities)
		room.PlayerEntities = append(room.PlayerEntities, *p)
		room.CachedGameState.Players[id] = p.State
		room.Bots[id] = true
		m.respawnPlayer(room, &room.PlayerEntities[len(room.PlayerEntities)-1])
	}
	room.botCount.Store(int32(len(room.Bots)))
}

func enemies(room *Room, a, b *Player) bool {
	return a.ID != b.ID && !b.State.IsDead && (room.Mode != "TDM" || a.State.Team != b.State.Team || a.State.Team == "NONE")
}

func (m *Match) advanceBots(room *Room, now time.Time, dt float32) {
	if room.State != "PLAYING" {
		return
	}
	for i := range room.PlayerEntities {
		if room.State != "PLAYING" {
			break
		}
		p := &room.PlayerEntities[i]
		brain := p.Bot
		if brain == nil {
			continue
		}
		if p.State.IsDead {
			if now.Sub(p.DeathTime) >= 3*time.Second {
				m.respawnPlayer(room, p)
				brain.path = nil
				brain.target = ""
				brain.visible = false
				brain.reactAt = now.Add(600 * time.Millisecond)
			}
			continue
		}
		if !now.Before(brain.perceiveAt) {
			brain.perceiveAt = now.Add(time.Duration(140+brain.rng.IntN(80)) * time.Millisecond)
			brain.visible = false
			m.perceiveGrenades(room, p, now)
			best := float32(math.MaxFloat32)
			for j := range room.PlayerEntities {
				target := &room.PlayerEntities[j]
				if !enemies(room, p, target) {
					continue
				}
				d := distance(position(p), position(target))
				if d > 70 {
					continue
				}
				to := sub(position(target), position(p))
				forward := vector{-2 * p.State.Ry * p.State.Rw, 0, 2*p.State.Ry*p.State.Ry - 1}
				inView := d < 10 || dot(to, forward) > d*0.05
				visible := inView && !room.visionBlocked(eye(p), eye(target), target.ID)
				score := d
				if target.ID == brain.target {
					score *= 0.8
				}
				if visible && score < best {
					best = score
					if brain.target != target.ID {
						brain.reactAt = now.Add(time.Duration(450+brain.rng.IntN(300)) * time.Millisecond)
						brain.shots = 0
					}
					brain.target = target.ID
					brain.lastKnown = position(target)
					brain.seenUntil = now.Add(3 * time.Second)
					brain.visible = true
				} else if !brain.visible && d < 35 && now.Sub(target.LastShotTime) < 250*time.Millisecond {
					brain.lastKnown = position(target)
					brain.seenUntil = now.Add(2 * time.Second)
				}
			}
			// Radio shares a location, never permission to fire through cover.
			if brain.visible && room.Mode == "TDM" {
				for j := range room.PlayerEntities {
					ally := &room.PlayerEntities[j]
					if ally.Bot != nil && ally.ID != p.ID && ally.State.Team == p.State.Team && !ally.Bot.visible && distance(position(p), position(ally)) < 35 {
						ally.Bot.lastKnown = brain.lastKnown
						ally.Bot.seenUntil = now.Add(2 * time.Second)
					}
				}
			}
		}
		if p.AmmoCount == 0 || (!brain.visible && p.AmmoCount < p.ActiveWeapon.MagSize/2) {
			_ = p.ValidateAndApplyReload()
		}
		if !now.Before(brain.planAt) {
			brain.planAt = now.Add(time.Duration(650+brain.rng.IntN(300)) * time.Millisecond)
			m.planBot(room, p, now)
		}
		m.moveBot(room, p, now, dt)
		if !now.Before(brain.evadeUntil) && brain.visible && now.After(brain.reactAt) && !p.IsReloading && now.After(brain.burstUntil) {
			if idx, ok := room.PlayerIndices[brain.target]; ok {
				target := &room.PlayerEntities[idx]
				if enemies(room, p, target) && !room.visionBlocked(eye(p), eye(target), target.ID) {
					m.fireBot(room, p, target, now)
				}
			}
		}
	}
}

func (m *Match) planBot(room *Room, p *Player, now time.Time) {
	b, n := p.Bot, room.Navigation
	if n == nil || len(n.nodes) == 0 {
		return
	}
	start := n.nearest(position(p), room.Geometry)
	goal := b.lastKnown
	b.intent = "search"
	if now.Before(b.evadeUntil) {
		goal = b.escapeGoal
		b.intent = "evade"
	} else if b.reposition {
		b.reposition = false
		b.intent = "reposition"
		best := float32(math.MaxFloat32)
		for _, node := range n.nodes {
			d := distance(position(p), node.position)
			if d < 3 || d > 7 || room.vehicleMovementBlocked(node.position, node.position) {
				continue
			}
			cost := d + float32(b.rng.Float64()*3)
			if cost < best {
				goal = node.position
				best = cost
			}
		}
	} else if now.After(b.seenUntil) {
		if b.waypoint < len(b.path) {
			return
		}
		b.intent = "patrol"
		goal = room.Geometry.spawns[b.rng.IntN(len(room.Geometry.spawns))]
	} else if b.visible {
		to := sub(b.lastKnown, position(p))
		d := max(distance(b.lastKnown, position(p)), 1)
		if p.IsReloading || p.State.Health < 35 {
			b.intent = "cover"
			goal = vector{p.State.X - to[0]/d*8, p.State.Y, p.State.Z - to[2]/d*8}
			// Seek reachable hard cover that breaks the enemy's line of fire.
			best := float32(math.MaxFloat32)
			for _, node := range n.nodes {
				cost := distance(position(p), node.position)
				if cost < 3 || cost > 12 || cost >= best {
					continue
				}
				if room.Geometry.blocked(vector{b.lastKnown[0], b.lastKnown[1] + 1.35, b.lastKnown[2]}, vector{node.position[0], node.position[1] + 1.35, node.position[2]}) {
					goal = node.position
					best = cost
				}
			}
		} else {
			b.intent = "engage"
			// Different roles pressure different angles rather than forming a queue.
			rangeWanted := float32(12)
			if p.ActiveWeapon.ID == "mp5" {
				rangeWanted = 7
			}
			if p.ActiveWeapon.ID == "dmr" {
				rangeWanted = 24
			}
			lateral := float32(b.role-1) * 6
			goal = vector{b.lastKnown[0] - to[0]/d*rangeWanted - to[2]/d*lateral, b.lastKnown[1], b.lastKnown[2] - to[2]/d*rangeWanted + to[0]/d*lateral}
		}
	}
	if b.intent == "search" && distance(position(p), b.lastKnown) < 2.5 {
		angle := b.rng.Float64() * math.Pi * 2
		goal = vector{b.lastKnown[0] + float32(math.Cos(angle))*4, b.lastKnown[1], b.lastKnown[2] + float32(math.Sin(angle))*4}
	}
	end := n.nearest(goal, room.Geometry)
	if b.intent != "evade" {
		end = room.spacedApproach(p, goal, end, b.intent == "cover")
	}

	if end < 0 {
		end = n.nearest(b.lastKnown, room.Geometry)
	}
	b.path = n.path(start, end, func(at vector) bool { return room.vehicleMovementBlocked(at, at) })
	b.waypoint = 0
}

func (m *Match) moveBot(room *Room, p *Player, now time.Time, dt float32) {
	b, n := p.Bot, room.Navigation
	if n == nil {
		return
	}
	p.State.Animation = "idle"
	if b.progressAt.IsZero() || distance(position(p), b.progressPoint) > 0.35 {
		b.progressAt = now
		b.progressPoint = position(p)
	}
	if b.waypoint < len(b.path) && now.Sub(b.progressAt) > 1500*time.Millisecond {
		b.reposition = true
		b.planAt = time.Time{}
		b.progressAt = now
	}
	if b.waypoint < len(b.path) {
		goal := n.nodes[b.path[b.waypoint]].position
		from := position(p)
		d := distance(from, goal)
		if d < 0.18 {
			b.waypoint++
		} else {
			speed := float32(4.8)
			if now.Before(b.evadeUntil) {
				speed = 5.5
			}
			if p.IsReloading {
				speed = 3.2
			}
			amount := min(1, speed*dt/d)
			to := vector{from[0] + (goal[0]-from[0])*amount, from[1] + (goal[1]-from[1])*amount, from[2] + (goal[2]-from[2])*amount}
			if !room.Geometry.movementBlocked(from, to) && !room.vehicleMovementBlocked(from, to) {
				p.State.X, p.State.Y, p.State.Z = to[0], to[1], to[2]
				p.State.Animation = "run"
				if !b.visible {
					faceBot(p, goal)
				}
			} else {
				b.path = nil
				b.planAt = time.Time{}
			}
		}
	}
	if b.visible {
		faceBot(p, b.lastKnown)
	}
}

func faceBot(p *Player, goal vector) {
	yaw := math.Atan2(float64(p.State.X-goal[0]), float64(p.State.Z-goal[2]))
	p.State.Rx, p.State.Rz = 0, 0
	p.State.Ry, p.State.Rw = float32(math.Sin(yaw/2)), float32(math.Cos(yaw/2))
}

func (m *Match) fireBot(room *Room, p, target *Player, now time.Time) {
	b := p.Bot
	origin := eye(p)
	d := distance(origin, eye(target))
	// Aim error grows with distance; no instant head tracking or guaranteed hits.
	errorRadius := float32(0.24) + d*0.022
	end := vector{b.lastKnown[0] + float32(b.rng.NormFloat64())*errorRadius, b.lastKnown[1] + 1.05 + float32(b.rng.NormFloat64())*errorRadius, b.lastKnown[2] + float32(b.rng.NormFloat64())*errorRadius}
	delta := sub(end, origin)
	length := distance(origin, end)
	if length < 0.1 {
		return
	}
	for k := range end {
		end[k] = origin[k] + delta[k]*min(300/length, 1.08)
	}
	f := &FireEvent{ShotId: p.State.LastShotId + 1, OriginX: origin[0], OriginY: origin[1], OriginZ: origin[2], HitX: end[0], HitY: end[1], HitZ: end[2]}
	if p.validateFireRayAt(f, now) != nil {
		return
	}
	if fraction, normal, hit := room.Geometry.trace(origin, end); hit {
		for k := range end {
			end[k] = origin[k] + (end[k]-origin[k])*fraction
		}
		f.HitWall = true
		f.NormalX, f.NormalY, f.NormalZ = normal[0], normal[1], normal[2]
	}
	var hitCar *serverVehicle
	nearestCar := float32(2)
	for _, vehicle := range room.Vehicles {
		if fraction, hit := vehicleRay(vehicle, origin, end); hit && fraction < nearestCar {
			hitCar = vehicle
			nearestCar = fraction
		}
	}
	if hitCar != nil {
		for k := range end {
			end[k] = origin[k] + (end[k]-origin[k])*nearestCar
		}
		m.damageVehicle(room, p, hitCar, int32(p.ActiveWeapon.DamageAtRange(float64(distance(origin, end)))))
	}
	p.ShotEnd = [3]float32(end)
	// The first anatomical hit wins, including friendly bodies that block shots.
	victim := firstPlayerOnShot(room, p, origin, end)
	if hitCar == nil && victim != nil && enemies(room, p, victim) && !room.Geometry.blocked(origin, eye(victim)) {
		previousHealth := victim.State.Health
		if killed, err := p.ValidateAndApplyHit(victim, 0); err == nil {
			m.broadcastDamage(room, p, victim, previousHealth-victim.State.Health)
			if killed {
				m.recordKill(room, p)
			}
		}
	}
	p.PendingHit = false
	f.HitX, f.HitY, f.HitZ = end[0], end[1], end[2]
	event := &ServerMessage{Message: &ServerMessage_ServerEvent{ServerEvent: &ServerEvent{Event: &ServerEvent_Fire{Fire: &ServerFireEvent{ShooterId: p.ID, OriginX: origin[0], OriginY: origin[1], OriginZ: origin[2], HitX: end[0], HitY: end[1], HitZ: end[2], HitWall: f.HitWall, NormalX: f.NormalX, NormalY: f.NormalY, NormalZ: f.NormalZ}}}}}
	if data, err := proto.Marshal(event); err == nil {
		for session := range room.Sessions {
			session.EnqueueDirectEvent(data)
		}
	}
	b.shots++
	if b.shots >= 2+b.role {
		b.shots = 0
		b.burstUntil = now.Add(time.Duration(450+b.rng.IntN(350)) * time.Millisecond)
	}
}

func firstPlayerOnShot(room *Room, shooter *Player, origin, end vector) *Player {
	var victim *Player
	nearest := float32(math.MaxFloat32)
	for i := range room.PlayerEntities {
		other := &room.PlayerEntities[i]
		if other.ID == shooter.ID || other.State.IsDead || other.State.DrivingVehicleId != "" {
			continue
		}
		pose := currentHitPose(other, time.Now())
		if _, fraction, hit := traceAnimatedPlayerHit(origin, end, pose.position, pose.rotation, pose.animation, pose.phase); hit && fraction < nearest {
			victim = other
			nearest = fraction
		}
	}
	return victim
}

// Called once after authoritative damage has incremented the shooter's kills.
func (m *Match) recordKill(room *Room, shooter *Player) {
	winner := ""
	if room.Mode == "FFA" && shooter.State.Kills >= 30 {
		winner = shooter.ID
	}
	if room.Mode == "TDM" {
		if shooter.State.Team == "A" {
			room.ScoreTeamA++
		} else if shooter.State.Team == "B" {
			room.ScoreTeamB++
		}
		if room.ScoreTeamA >= 60 {
			winner = "A"
		}
		if room.ScoreTeamB >= 60 {
			winner = "B"
		}
	}
	if winner != "" {
		room.State = "FINISHED"
		room.WinnerID = winner
		room.StateTimer = time.Now().Add(10 * time.Second)
	}
	room.CachedGameState.ScoreTeamA = room.ScoreTeamA
	room.CachedGameState.ScoreTeamB = room.ScoreTeamB
	room.CachedGameState.RoomState = room.State
	room.CachedGameState.WinnerId = room.WinnerID
}
