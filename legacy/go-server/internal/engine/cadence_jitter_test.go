package engine

import (
	"testing"
	"time"
)

var cadenceTestWeaponIDs = []string{"ak47", "m4", "mp5", "hmg", "pistol", "dmr", "m2010"}

func cadenceTestPlayer(weapon WeaponConfig) *Player {
	p := NewPlayer("cadence-test")
	p.ActiveWeapon = weapon
	p.AmmoCount = 1000
	p.AmmoStore[weapon.ID] = p.AmmoCount
	return p
}

func TestAllWeaponsRejectImmediateSecondShot(t *testing.T) {
	base := time.Unix(1_800_000_000, 0)
	for _, id := range cadenceTestWeaponIDs {
		t.Run(id, func(t *testing.T) {
			p := cadenceTestPlayer(Weapons[id])
			if err := p.validateAndApplyFireAt(base); err != nil {
				t.Fatalf("first shot was rejected: %v", err)
			}
			ammo := p.AmmoCount
			if err := p.validateAndApplyFireAt(base); err == nil {
				t.Fatal("immediate second shot was accepted")
			}
			if p.AmmoCount != ammo {
				t.Fatal("rejected shot consumed ammunition")
			}
		})
	}
}

func TestAllWeaponsKeepCadencePhaseUnderAlternatingArrivalJitter(t *testing.T) {
	base := time.Unix(1_800_000_000, 0)
	for _, id := range cadenceTestWeaponIDs {
		t.Run(id, func(t *testing.T) {
			weapon := Weapons[id]
			interval := time.Minute / time.Duration(weapon.RPM)
			p := cadenceTestPlayer(weapon)
			for shot := 0; shot < 30; shot++ {
				offset := time.Duration(0)
				if shot > 0 {
					offset = 16 * time.Millisecond
					if shot%2 == 1 {
						offset = -16 * time.Millisecond
					}
				}
				now := base.Add(time.Duration(shot)*interval + offset)
				if err := p.validateAndApplyFireAt(now); err != nil {
					t.Fatalf("legal shot %d rejected at %s relative to cadence: %v", shot+1, offset, err)
				}
			}
			if want := base.Add(30 * interval); !p.NextShotTime.Equal(want) {
				t.Fatalf("cadence phase moved: next shot at %s, want %s", p.NextShotTime, want)
			}
		})
	}
}

func TestAllWeaponsBoundAcceptedShotsAtTwiceRPMAttempts(t *testing.T) {
	base := time.Unix(1_800_000_000, 0)
	duration := 2 * time.Second
	for _, id := range cadenceTestWeaponIDs {
		t.Run(id, func(t *testing.T) {
			weapon := Weapons[id]
			interval := time.Minute / time.Duration(weapon.RPM)
			grace := 35 * time.Millisecond
			if halfInterval := interval / 2; halfInterval < grace {
				grace = halfInterval
			}
			p := cadenceTestPlayer(weapon)
			accepted := 0
			attemptEvery := interval / 2
			for elapsed := time.Duration(0); elapsed <= duration; elapsed += attemptEvery {
				if err := p.validateAndApplyFireAt(base.Add(elapsed)); err == nil {
					accepted++
				}
			}
			maximum := int((duration+grace)/interval) + 1
			if accepted > maximum {
				t.Fatalf("accepted %d shots during %s at 2x RPM attempts, theoretical maximum is %d", accepted, duration, maximum)
			}
		})
	}
}
