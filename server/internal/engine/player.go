package engine

import (
	"errors"
	"time"
)

// Player represents the server's authoritative internal view
type Player struct {
	ID    string
	State *PlayerState

	// Authoritative Weapon & Ammo State
	ActiveWeapon WeaponConfig
	AmmoCount    int
	AmmoStore    map[string]int

	// Timestamps for anti-cheat validation
	LastShotTime time.Time
	IsReloading  bool
	ReloadStart  time.Time
	DeathTime    time.Time
}

func NewPlayer(id string) *Player {
	defaultWeapon := Weapons["ak47"]
	ammoStore := make(map[string]int)
	for name, config := range Weapons {
		ammoStore[name] = config.MagSize
	}
	
	return &Player{
		ID: id,
		State: &PlayerState{
			Health:    100,
			Animation: "idle",
			WeaponId:  "ak47",
		},
		ActiveWeapon: defaultWeapon,
		AmmoCount:    defaultWeapon.MagSize,
		AmmoStore:    ammoStore,
		LastShotTime: time.Now().Add(-time.Hour), // Ensure they can shoot immediately
	}
}

func (p *Player) ValidateAndApplyFire() error {
	if p.State.IsDead {
		return errors.New("dead players cannot shoot")
	}

	now := time.Now()

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

	// 2. Validate Fire Rate (RPM) — clamp tolerance so high-RPM (600) doesn't become negative
	minInterval := time.Duration(float64(time.Minute) / float64(p.ActiveWeapon.RPM))
	threshold := minInterval - 200*time.Millisecond
	if threshold < 0 {
		threshold = 0
	}
	if now.Sub(p.LastShotTime) < threshold {
		return errors.New("firing rate exceeds limits (hacking detected)")
	}

	// 3. Validate Ammo
	if p.AmmoCount <= 0 {
		return errors.New("no ammo remaining")
	}

	// Apply
	p.AmmoCount--
	p.AmmoStore[p.ActiveWeapon.ID] = p.AmmoCount
	p.LastShotTime = now
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
	if p.State.IsDead {
		return false, errors.New("shooter is dead")
	}
	if target.State.IsDead {
		return false, errors.New("target is already dead")
	}
	if p.IsReloading {
		return false, errors.New("shooter was reloading")
	}
	if p.ID == target.ID {
		return false, errors.New("cannot shoot yourself")
	}

	// Basic cheat check: e.g. 3x headshot mult
	maxDamage := int(float64(p.ActiveWeapon.Damage) * 3.0)
	if clientDamage <= 0 || clientDamage > maxDamage {
		return false, errors.New("invalid or impossible damage")
	}

	target.State.Health -= int32(clientDamage)
	if target.State.Health <= 0 {
		target.State.Health = 0
		target.State.IsDead = true
		target.State.Deaths++
		target.State.Animation = "death"
		target.DeathTime = time.Now()
		p.State.Kills++
		return true, nil
	}
	return false, nil
}
