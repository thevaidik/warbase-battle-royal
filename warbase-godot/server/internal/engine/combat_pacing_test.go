package engine

import (
	"math"
	"testing"
	"time"
)

func TestCombatPacingAndFalloff(t *testing.T) {
	for _, id := range []string{"ak47", "m4", "mp5", "hmg"} {
		weapon := Weapons[id]
		hits := int(math.Ceil(100 / float64(weapon.Damage)))
		ttk := float64(hits-1) * 60 / float64(weapon.RPM)
		if ttk < 0.30 || ttk > 0.6 {
			t.Fatalf("%s torso TTK outside pacing target: %.3fs", id, ttk)
		}
		if weapon.DamageAtRange(100) >= weapon.Damage || weapon.DamageAtRange(300) < 1 {
			t.Fatalf("invalid range damage for %s", id)
		}
	}
}

func TestRecoveryAndSpawnProtection(t *testing.T) {
	p, target := NewPlayer("shooter"), NewPlayer("target")
	target.State.Z = -5
	target.ProtectedUntil = time.Now().Add(time.Second)
	if err := p.ValidateFireRay(fire(1)); err != nil {
		t.Fatal(err)
	}
	if _, err := p.ValidateAndApplyHit(target, 999); err == nil || target.State.Health != 100 {
		t.Fatal("spawn protection ignored")
	}
	if !p.ProtectedUntil.IsZero() {
		t.Fatal("shooting retained invulnerability")
	}
	now := time.Now()
	target.State.Health = 40
	target.LastDamageTime = now
	target.advanceRecovery(now.Add(4*time.Second), 1)
	if target.State.Health != 40 {
		t.Fatal("healed during recovery delay")
	}
	target.advanceRecovery(now.Add(6*time.Second), 1)
	if target.State.Health != 55 {
		t.Fatal("incorrect recovery rate")
	}
	target.advanceRecovery(now.Add(7*time.Second), 10)
	if target.State.Health != 100 {
		t.Fatal("recovery exceeded maximum health")
	}
	target.State.IsDead = true
	target.State.Health = 0
	target.advanceRecovery(now.Add(20*time.Second), 1)
	if target.State.Health != 0 {
		t.Fatal("dead player regenerated")
	}
}

func TestCustomLoadoutAuthority(t *testing.T) {
	m, room, s, _ := fixture(t)
	sendTest(m, s, &ClientEvent{Event: &ClientEvent_Loadout{Loadout: &LoadoutEvent{Primary: "dmr", Secondary: "mp5", Throwable: "impact"}}})
	p := &room.PlayerEntities[room.PlayerIndices[s.PlayerID]]
	if p.ActiveWeapon.ID != "dmr" || p.ThrowableID != "impact" || p.AmmoCount != 20 {
		t.Fatal("custom loadout was not applied")
	}
	sendTest(m, s, &ClientEvent{Event: &ClientEvent_SwitchWeapon{SwitchWeapon: &SwitchWeaponEvent{WeaponId: "hmg"}}})
	if p.ActiveWeapon.ID != "dmr" {
		t.Fatal("equipped unselected weapon")
	}
	sendTest(m, s, &ClientEvent{Event: &ClientEvent_SwitchWeapon{SwitchWeapon: &SwitchWeaponEvent{WeaponId: "mp5"}}})
	if p.ActiveWeapon.ID != "mp5" {
		t.Fatal("could not switch to selected secondary")
	}
	sendTest(m, s, &ClientEvent{Event: &ClientEvent_Loadout{Loadout: &LoadoutEvent{Primary: "hmg", Secondary: "pistol", Throwable: "frag"}}})
	if p.ActiveWeapon.ID != "mp5" || p.ThrowableID != "impact" {
		t.Fatal("repeated loadout changed live inventory")
	}
}

func TestImpactGrenadeTimingAndDamage(t *testing.T) {
	m := NewMatch()
	room := NewRoom("test", "test", "industrial", "FFA")
	room.Geometry = &mapGeometry{root: buildCollision([]triangle{{vector{-10, 0, -10}, vector{10, 0, -10}, vector{10, 0, 10}}, {vector{-10, 0, -10}, vector{10, 0, 10}, vector{-10, 0, 10}}})}
	room.Grenades = []*serverGrenade{{id: 1, kind: "impact", pos: vector{0, 0.02, 0}, velocity: vector{0, -5, 0}, age: 0.2}}
	target := NewPlayer("target")
	target.State.Z = 1
	room.PlayerEntities = []Player{*target}
	m.advanceGrenades(room, 1.0/60)
	if len(room.Grenades) != 0 || target.State.Health >= 100 || target.State.IsDead {
		t.Fatal("impact grenade timing or balanced damage incorrect")
	}
}
