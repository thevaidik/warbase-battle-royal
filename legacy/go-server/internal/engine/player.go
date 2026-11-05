package engine

import (
	"errors"
	"time"
)

// Player represents the server's authoritative internal view
type Player struct {
	LastValidationLog                               time.Time
	RejectedEvents                                  uint64
	LastImpactPoint, LastImpactDirection            vector
	SelectedPrimary, SelectedSecondary, ThrowableID string
	LoadoutApplied                                  bool
	ProtectedUntil, LastDamageTime                  time.Time
	RegenRemainder                                  float32
	Bot                                             *botBrain
	GrenadesRemaining                               int
	ID                                              string
	State                                           *PlayerState

	// Authoritative Weapon & Ammo State
	ActiveWeapon WeaponConfig
	AmmoCount    int
	AmmoStore    map[string]int
	CadenceStore map[string]time.Time
	DrawUntil    time.Time

	// Timestamps for anti-cheat validation
	LastShotTime    time.Time
	NextShotTime    time.Time
	LastMoveTime    time.Time
	MoveBudget      float32
	LastGrenadeTime time.Time
	PendingHit      bool
	ShotOrigin      [3]float32
	ShotEnd         [3]float32
	ShotID          uint64
	HitRewindWindow time.Duration
	HitViewTime     time.Time
	hitHistory      hitPoseHistory
	animationName   string
	animationStart  time.Time
	IsReloading     bool
	ReloadStart     time.Time
	DeathTime       time.Time
	HasSpawned      bool
	OutOfRangeTicks int

	// Spatial dormancy & delta tracking
	LastX    float32
	LastY    float32
	LastZ    float32
	LastAnim string
}

func NewPlayer(id string) *Player {
	defaultWeapon := Weapons["ak47"]
	ammoStore := make(map[string]int)
	for name, config := range Weapons {
		ammoStore[name] = config.MagSize
	}

	return &Player{
		ID:              id,
		SelectedPrimary: "ak47", SelectedSecondary: "pistol", ThrowableID: "frag",
		State: &PlayerState{
			Health:    100,
			Animation: "idle",
			WeaponId:  "ak47",
		},
		ActiveWeapon: defaultWeapon,
		AmmoCount:    defaultWeapon.MagSize,
		AmmoStore:    ammoStore,
		CadenceStore: make(map[string]time.Time),
		LastShotTime: time.Now().Add(-time.Hour), // Ensure they can shoot immediately
	}
}

func (p *Player) ValidateAndApplyFire() error {
	return p.validateAndApplyFireAt(time.Now())
}

func (p *Player) validateAndApplyFireAt(now time.Time) error {
	if p.State.IsDead || p.State.DrivingVehicleId != "" {
		return errors.New("cannot fire while dead or driving")
	}
	if now.Before(p.DrawUntil) {
		return errors.New("weapon is still being drawn")
	}

	// 1. Validate Reload Status
	if p.IsReloading {
		if now.Sub(p.ReloadStart) >= p.ActiveWeapon.ReloadTime {
			// Reload naturally completed
			p.IsReloading = false
			p.AmmoCount = p.ActiveWeapon.MagSize
			p.AmmoStore[p.ActiveWeapon.ID] = p.AmmoCount
		} else {
			return errors.New("cannot shoot while reloading")
		}
	}

	// Preserve cadence across packet jitter without granting sustained extra RPM.
	interval := time.Minute / time.Duration(p.ActiveWeapon.RPM)
	grace := 35 * time.Millisecond
	if halfInterval := interval / 2; halfInterval < grace {
		grace = halfInterval
	}
	if !p.NextShotTime.IsZero() && now.Add(grace).Before(p.NextShotTime) {
		return errors.New("firing rate exceeds limit")
	}

	// 3. Validate Ammo
	if p.AmmoCount <= 0 {
		return errors.New("no ammo remaining")
	}

	// Apply
	p.AmmoCount--
	p.AmmoStore[p.ActiveWeapon.ID] = p.AmmoCount
	p.LastShotTime = now
	if p.NextShotTime.IsZero() || now.Sub(p.NextShotTime) > interval {
		p.NextShotTime = now
	}
	p.NextShotTime = p.NextShotTime.Add(interval)
	p.CadenceStore[p.ActiveWeapon.ID] = p.NextShotTime
	p.PendingHit = true
	return nil
}

func (p *Player) ValidateAndApplyReload() error {
	if p.State.IsDead {
		return errors.New("dead players cannot reload")
	}
	if p.IsReloading {
		return errors.New("already reloading")
	}
	if p.AmmoCount == p.ActiveWeapon.MagSize {
		return errors.New("magazine already full")
	}

	p.IsReloading = true
	p.ReloadStart = time.Now()
	return nil
}

// Returns (isKill, error)
func (p *Player) ValidateAndApplyHit(target *Player, clientDamage int) (bool, error) {
	return p.validateAndApplyHitAt(target, clientDamage, time.Now())
}

func (p *Player) validateAndApplyHitAt(target *Player, clientDamage int, now time.Time) (bool, error) {
	if p.State.IsDead {
		return false, errors.New("shooter is dead")
	}
	if target.State.IsDead {
		return false, errors.New("target is already dead")
	}
	if target.State.DrivingVehicleId != "" {
		return false, errors.New("target is inside a vehicle")
	}
	if p.IsReloading || !p.PendingHit || now.Sub(p.LastShotTime) > 800*time.Millisecond {
		return false, errors.New("no unconsumed shot")
	}
	// One accepted firing event can resolve damage only once.
	p.PendingHit = false
	origin := vector(p.ShotOrigin)
	end := vector(p.ShotEnd)
	zone, fraction, hit := traceShotPlayerHit(p, target, now)
	if !hit {
		return false, errors.New("shot misses target")
	}
	if now.Before(target.ProtectedUntil) {
		return false, errors.New("target has spawn protection")
	}
	dx, dy, dz := end[0]-origin[0], end[1]-origin[1], end[2]-origin[2]
	hitPoint := vector{origin[0] + fraction*dx, origin[1] + fraction*dy, origin[2] + fraction*dz}
	damage := p.ActiveWeapon.DamageForZone(float64(distance(origin, hitPoint)), zone)
	// Damage comes from the server; clientDamage is not trusted.
	_ = clientDamage

	target.LastImpactPoint = hitPoint
	length := float32(distance(origin, end))
	if length <= 0 || !finite(float64(length)) {
		return false, errors.New("invalid shot segment")
	}
	target.LastImpactDirection = vector{dx / length, dy / length, dz / length}
	target.LastDamageTime = now
	target.RegenRemainder = 0
	target.State.Health -= int32(damage)
	if target.State.Health <= 0 {
		target.State.Health = 0
		target.State.IsDead = true
		target.State.Deaths++
		target.State.Animation = "death"
		target.DeathTime = now
		p.State.Kills++
		return true, nil
	}
	return false, nil
}

// ValidateFireRay ties accepted shots to finite, nearby origins and a bounded range.
func (p *Player) ValidateFireRay(f *FireEvent) error {
	return p.validateFireRayAt(f, time.Now())
}

func (p *Player) validateFireRayAt(f *FireEvent, now time.Time) error {
	if f == nil {
		return errors.New("missing fire event")
	}
	if f.ShotId == 0 || f.ShotId <= p.State.LastShotId {
		return errors.New("stale shot")
	}
	p.State.LastShotId = f.ShotId
	values := []float32{f.OriginX, f.OriginY, f.OriginZ, f.HitX, f.HitY, f.HitZ, f.NormalX, f.NormalY, f.NormalZ}
	for _, v := range values {
		if !isValidFloat32(v) {
			return errors.New("invalid fire coordinates")
		}
	}
	ox, oy, oz := f.OriginX-p.State.X, f.OriginY-p.State.Y, f.OriginZ-p.State.Z
	dx, dy, dz := f.HitX-f.OriginX, f.HitY-f.OriginY, f.HitZ-f.OriginZ
	if ox*ox+oy*oy+oz*oz > 9 || dx*dx+dy*dy+dz*dz > 305*305 || dx*dx+dy*dy+dz*dz < 0.001 {
		return errors.New("impossible fire ray")
	}
	if err := p.validateAndApplyFireAt(now); err != nil {
		return err
	}
	p.ProtectedUntil = time.Time{}
	p.ShotID = f.ShotId
	p.ShotOrigin = [3]float32{f.OriginX, f.OriginY, f.OriginZ}
	p.ShotEnd = [3]float32{f.HitX, f.HitY, f.HitZ}
	return nil
}

func (p *Player) advanceRecovery(now time.Time, dt float32) {
	if p.State.IsDead || p.State.Health >= 100 || now.Sub(p.LastDamageTime) < 5*time.Second {
		return
	}
	p.RegenRemainder += 15 * dt
	heal := int32(p.RegenRemainder)
	p.RegenRemainder -= float32(heal)
	p.State.Health = min(100, p.State.Health+heal)
}
