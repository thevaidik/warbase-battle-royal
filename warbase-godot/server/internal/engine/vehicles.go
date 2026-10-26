package engine

import (
	"fmt"
	"math"
	"time"
)

type serverVehicle struct {
	state                *VehicleState
	spawn                [4]float32
	throttle, steer      float32
	brake                bool
	gear                 int
	inputAt, destroyedAt time.Time
	roadkill             map[string]time.Time
}

func (r *Room) initVehicles() {
	r.Vehicles = make(map[string]*serverVehicle)
	r.CachedGameState.Vehicles = make(map[string]*VehicleState)
	if r.Geometry == nil {
		return
	}
	for i, spawn := range r.Geometry.vehicleSpawns {
		id := fmt.Sprintf("CAR_%d", i)
		state := &VehicleState{Id: id, X: spawn[0], Y: spawn[1], Z: spawn[2], Yaw: spawn[3], Health: 1200}
		if y, ok := r.groundAt(vector{state.X, state.Y, state.Z}); ok {
			state.Y = y
		}
		v := &serverVehicle{state: state, spawn: [4]float32{state.X, state.Y, state.Z, state.Yaw}, gear: 1, roadkill: map[string]time.Time{}}
		r.Vehicles[id] = v
		r.CachedGameState.Vehicles[id] = state
	}
}

func (r *Room) groundAt(p vector) (float32, bool) {
	a, b := vector{p[0], p[1] + 2.5, p[2]}, vector{p[0], p[1] - 5, p[2]}
	fraction, normal, hit := r.Geometry.trace(a, b)
	if !hit || math.Abs(float64(normal[1])) < 0.65 {
		return 0, false
	}
	return a[1] + (b[1]-a[1])*fraction + 0.08, true
}

func (m *Match) enterVehicle(r *Room, p *Player, id string) bool {
	v := r.Vehicles[id]
	if v == nil || p.State.IsDead || p.State.DrivingVehicleId != "" || v.state.Driver != "" || v.state.Health <= 0 || r.State != "PLAYING" {
		return false
	}
	if distance(position(p), vector{v.state.X, v.state.Y, v.state.Z}) > 4.8 || r.Geometry.blocked(eye(p), vector{v.state.X, v.state.Y + 1.3, v.state.Z}) {
		return false
	}
	v.state.Driver = p.ID
	v.throttle = 0
	v.steer = 0
	v.state.Speed = 0
	v.inputAt = time.Now()
	p.State.DrivingVehicleId = id
	p.State.Animation = "drive"
	p.State.WeaponId = "vehicle"
	p.PendingHit = false
	p.IsReloading = false
	p.ProtectedUntil = time.Time{}
	p.State.X, p.State.Y, p.State.Z = v.state.X, v.state.Y, v.state.Z
	return true
}

func (m *Match) releaseVehicle(r *Room, p *Player) {
	if v := r.Vehicles[p.State.DrivingVehicleId]; v != nil && v.state.Driver == p.ID {
		v.state.Driver = ""
		v.throttle = 0
		v.steer = 0
		v.state.Speed = 0
	}
	p.State.DrivingVehicleId = ""
	p.State.WeaponId = p.ActiveWeapon.ID
	p.State.Animation = "idle"
	if p.State.IsDead {
		p.State.Animation = "death"
	}
	p.DrawUntil = time.Now().Add(220 * time.Millisecond)
}

func (m *Match) exitVehicle(r *Room, p *Player) bool {
	v := r.Vehicles[p.State.DrivingVehicleId]
	if v == nil || v.state.Driver != p.ID {
		return false
	}
	from := vector{v.state.X, v.state.Y, v.state.Z}
	s, c := float32(math.Sin(float64(v.state.Yaw))), float32(math.Cos(float64(v.state.Yaw)))
	for _, offset := range []vector{{-2.2, 0, 0}, {2.2, 0, 0}, {0, 0, 3.3}, {0, 0, -3.3}} {
		at := vector{from[0] + c*offset[0] + s*offset[2], from[1], from[2] - s*offset[0] + c*offset[2]}
		if y, ok := r.groundAt(at); ok && !r.Geometry.movementBlocked(from, at) {
			at[1] = y
			p.State.X, p.State.Y, p.State.Z = at[0], at[1], at[2]
			m.releaseVehicle(r, p)
			return true
		}
	}
	return false
}

func (m *Match) advanceVehicles(r *Room, now time.Time, dt float32) {
	for _, v := range r.Vehicles {
		s := v.state
		if s.Health <= 0 {
			if now.Sub(v.destroyedAt) > 20*time.Second {
				s.Health = 1200
				s.X, s.Y, s.Z, s.Yaw = v.spawn[0], v.spawn[1], v.spawn[2], v.spawn[3]
			}
			continue
		}
		idx, ok := r.PlayerIndices[s.Driver]
		if !ok || r.PlayerEntities[idx].State.IsDead || r.PlayerEntities[idx].State.DrivingVehicleId != s.Id {
			s.Driver = ""
			s.Speed = 0
			continue
		}
		p := &r.PlayerEntities[idx]
		if r.State != "PLAYING" || now.Sub(v.inputAt) > 300*time.Millisecond {
			v.throttle = 0
			v.steer = 0
			v.brake = true
		}
		cap := float32(14.4)
		if v.gear == 2 {
			cap = 22
		}
		acceleration := v.throttle*9 - s.Speed*0.24
		if v.brake {
			acceleration -= s.Speed * 6
		}
		s.Speed = max(-6, min(cap, s.Speed+acceleration*dt))
		if math.Abs(float64(s.Speed)) < 0.05 && v.throttle == 0 {
			s.Speed = 0
		}
		yaw := s.Yaw - v.steer*s.Speed/5*dt
		from := vector{s.X, s.Y, s.Z}
		to := vector{s.X - float32(math.Sin(float64(yaw)))*s.Speed*dt, s.Y, s.Z - float32(math.Cos(float64(yaw)))*s.Speed*dt}
		blocked := false
		// Sweep chassis corners against static map geometry, not the rendered model.
		for _, offset := range []vector{{0, 0, 0}, {-1.1, 0, -2.4}, {1.1, 0, -2.4}, {-1.1, 0, 2.4}, {1.1, 0, 2.4}} {
			rot := vector{float32(math.Cos(float64(yaw)))*offset[0] + float32(math.Sin(float64(yaw)))*offset[2], 0, -float32(math.Sin(float64(yaw)))*offset[0] + float32(math.Cos(float64(yaw)))*offset[2]}
			a, b := vector{from[0] + rot[0], from[1], from[2] + rot[2]}, vector{to[0] + rot[0], to[1], to[2] + rot[2]}
			for _, other := range r.Vehicles {
				if other != v {
					if _, hit := vehicleRay(other, vector{b[0], b[1] + 0.9, b[2]}, vector{b[0], b[1] + 0.9, b[2]}); hit {
						blocked = true
						break
					}
				}
			}
			if r.Geometry.movementBlocked(a, b) {
				blocked = true
				break
			}
		}
		if y, supported := r.groundAt(to); !blocked && supported && math.Abs(float64(y-from[1])) < 0.6 {
			s.X, s.Y, s.Z, s.Yaw = to[0], y, to[2], yaw
		} else {
			s.Speed = 0
		}
		p.State.X, p.State.Y, p.State.Z = s.X, s.Y, s.Z
		p.State.Ry, p.State.Rw = float32(math.Sin(float64(s.Yaw)/2)), float32(math.Cos(float64(s.Yaw)/2))
		p.State.Animation = "drive"
		p.State.WeaponId = "vehicle"
		if math.Abs(float64(s.Speed)) > 5 {
			for i := range r.PlayerEntities {
				target := &r.PlayerEntities[i]
				if !enemies(r, p, target) || target.State.DrivingVehicleId != "" || now.Before(target.ProtectedUntil) || now.Sub(v.roadkill[target.ID]) < time.Second {
					continue
				}
				if distance(position(p), position(target)) < 2 {
					v.roadkill[target.ID] = now
					target.State.Health = 0
					target.State.IsDead = true
					target.State.Deaths++
					target.DeathTime = now
					target.State.Animation = "death"
					p.State.Kills++
					m.recordKill(r, p)
				}
			}
		}
	}
}

func vehicleRay(v *serverVehicle, from, to vector) (float32, bool) {
	s, c := float32(math.Sin(float64(v.state.Yaw))), float32(math.Cos(float64(v.state.Yaw)))
	local := func(a vector) vector {
		x, z := a[0]-v.state.X, a[2]-v.state.Z
		return vector{c*x - s*z, a[1] - v.state.Y, s*x + c*z}
	}
	a, b := local(from), local(to)
	d := sub(b, a)
	box := bounds{min: vector{-1.2, 0.15, -2.6}, max: vector{1.2, 2.5, 2.6}}
	low, high := float32(0), float32(1)
	for k := 0; k < 3; k++ {
		if math.Abs(float64(d[k])) < 1e-8 {
			if a[k] < box.min[k] || a[k] > box.max[k] {
				return 0, false
			}
			continue
		}
		x, y := (box.min[k]-a[k])/d[k], (box.max[k]-a[k])/d[k]
		if x > y {
			x, y = y, x
		}
		low = max(low, x)
		high = min(high, y)
		if low > high {
			return 0, false
		}
	}
	return low, true
}

func (m *Match) damageVehicle(r *Room, shooter *Player, v *serverVehicle, damage int32) {
	if v.state.Health <= 0 {
		return
	}
	if idx, ok := r.PlayerIndices[v.state.Driver]; ok && r.Mode == "TDM" && r.PlayerEntities[idx].State.Team == shooter.State.Team {
		return
	}
	v.state.Health = max(0, v.state.Health-damage)
	if v.state.Health == 0 {
		v.destroyedAt = time.Now()
		v.state.Speed = 0
		if idx, ok := r.PlayerIndices[v.state.Driver]; ok {
			driver := &r.PlayerEntities[idx]
			if !driver.State.IsDead {
				driver.State.Health = 0
				driver.State.IsDead = true
				driver.State.Deaths++
				driver.State.Animation = "death"
				driver.DeathTime = time.Now()
				shooter.State.Kills++
				m.recordKill(r, shooter)
			}
			m.releaseVehicle(r, driver)
		}
	}
}

func (m *Match) hitVehicle(r *Room, p *Player, v *serverVehicle, shotID uint64) {
	if p.State.IsDead || !p.PendingHit || p.ShotID != shotID || time.Since(p.LastShotTime) > 800*time.Millisecond {
		return
	}
	p.PendingHit = false
	if _, hit := vehicleRay(v, vector(p.ShotOrigin), vector(p.ShotEnd)); !hit || r.Geometry.blocked(vector(p.ShotOrigin), vector(p.ShotEnd)) {
		return
	}
	m.damageVehicle(r, p, v, int32(p.ActiveWeapon.DamageAtRange(float64(distance(vector(p.ShotOrigin), vector(p.ShotEnd))))))
}

func (r *Room) vehicleMovementBlocked(from, to vector) bool {
	for _, v := range r.Vehicles {
		if _, hit := vehicleRay(v, vector{from[0], from[1] + 0.9, from[2]}, vector{to[0], to[1] + 0.9, to[2]}); hit {
			return true
		}
	}
	return false
}
func (r *Room) visionBlocked(from, to vector, targetID string) bool {
	if r.Geometry.blocked(from, to) {
		return true
	}
	for _, v := range r.Vehicles {
		if v.state.Driver == targetID {
			continue
		}
		if _, hit := vehicleRay(v, from, to); hit {
			return true
		}
	}
	return false
}
