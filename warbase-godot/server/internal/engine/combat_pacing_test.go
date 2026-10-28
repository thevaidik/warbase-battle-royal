package engine

import (
	"math"
	"testing"
	"time"
)

func TestCombatPacingAndFalloff(t *testing.T) {
	for _, id := range []string{"ak47", "m4", "mp5", "hmg"} {
		weapon := Weapons[id]
		hits := int(math.Ceil(100 / float64(weapon.DamageForZone(20, "torso"))))
		ttk := float64(hits-1) * 60 / float64(weapon.RPM)
		if ttk < 0.20 || ttk > 0.30 {
			t.Fatalf("%s torso TTK outside pacing target: %.3fs", id, ttk)
		}
	}
	mp5Hits := int(math.Ceil(100 / float64(Weapons["mp5"].DamageForZone(10, "torso"))))
	if ttk := float64(mp5Hits-1) * 60 / float64(Weapons["mp5"].RPM); ttk < 0.20 || ttk > 0.30 {
		t.Fatalf("MP5 close-range TTK outside pacing target: %.3fs", ttk)
	}
	if shots := int(math.Ceil(100 / float64(Weapons["ak47"].DamageForZone(20, "torso")))); shots != 3 {
		t.Fatalf("AK close-range shots-to-kill = %d, want 3", shots)
	}
	if shots := int(math.Ceil(100 / float64(Weapons["m4"].DamageForZone(20, "torso")))); shots != 4 {
		t.Fatalf("M4 close-range shots-to-kill = %d, want 4", shots)
	}
	if shots := int(math.Ceil(100 / float64(Weapons["mp5"].DamageForZone(10, "torso")))); shots != 4 {
		t.Fatalf("MP5 close-range shots-to-kill = %d, want 4", shots)
	}
	mediumCases := []struct {
		id     string
		rangeM float64
		shots  int
		ttkMS  int
	}{
		{"ak47", 55, 4, 300}, {"m4", 55, 5, 320}, {"hmg", 55, 4, 346}, {"mp5", 30, 6, 353},
	}
	for _, tc := range mediumCases {
		weapon := Weapons[tc.id]
		hits := int(math.Ceil(100 / float64(weapon.DamageForZone(tc.rangeM, "torso"))))
		ttkMS := int(math.Round(float64(hits-1) * 60_000 / float64(weapon.RPM)))
		if hits != tc.shots || ttkMS != tc.ttkMS {
			t.Errorf("%s at %.0fm: %d hits and %dms TTK, want %d hits and %dms", tc.id, tc.rangeM, hits, ttkMS, tc.shots, tc.ttkMS)
		}
	}
}

func TestWeaponDefinitionsFalloffAndHitZones(t *testing.T) {
	wantDamage := map[string]int{"ak47": 34, "m4": 25, "mp5": 25, "hmg": 34, "pistol": 34, "dmr": 50, "m2010": 100}
	wantRPM := map[string]int{"ak47": 600, "m4": 750, "mp5": 850, "hmg": 520, "pistol": 400, "dmr": 240, "m2010": 45}
	wantMag := map[string]int{"ak47": 30, "m4": 30, "mp5": 30, "hmg": 60, "pistol": 12, "dmr": 20, "m2010": 5}
	wantReload := map[string]time.Duration{
		"ak47": 2500 * time.Millisecond, "m4": 2200 * time.Millisecond, "mp5": 1800 * time.Millisecond,
		"hmg": 3400 * time.Millisecond, "pistol": 1500 * time.Millisecond, "dmr": 2600 * time.Millisecond, "m2010": 3200 * time.Millisecond,
	}
	if len(Weapons) != 7 {
		t.Fatalf("weapon definitions = %d, want 7", len(Weapons))
	}
	for id, damage := range wantDamage {
		weapon, ok := Weapons[id]
		if !ok || weapon.Damage != damage || weapon.RPM != wantRPM[id] || weapon.MagSize != wantMag[id] || weapon.ReloadTime != wantReload[id] {
			t.Fatalf("unexpected or missing weapon definition %q: %+v", id, weapon)
		}
	}
	falloffCases := []struct {
		id         string
		start, end float64
		endDamage  int
	}{
		{"ak47", 20, 90, 20}, {"m4", 20, 90, 15}, {"hmg", 20, 90, 20},
		{"mp5", 10, 45, 11}, {"pistol", 10, 50, 17}, {"dmr", 35, 150, 38},
	}
	for _, tc := range falloffCases {
		weapon := Weapons[tc.id]
		if weapon.DamageAtRange(tc.start) != weapon.Damage || weapon.DamageAtRange(tc.end) != tc.endDamage {
			t.Errorf("%s falloff endpoints: start=%d end=%d, want %d and %d", tc.id, weapon.DamageAtRange(tc.start), weapon.DamageAtRange(tc.end), weapon.Damage, tc.endDamage)
		}
		if weapon.DamageAtRange((tc.start+tc.end)/2) >= weapon.Damage || weapon.DamageAtRange(tc.end+100) != tc.endDamage {
			t.Errorf("%s falloff is not smooth and capped", tc.id)
		}
	}
	if Weapons["m2010"].DamageAtRange(500) != 100 {
		t.Fatal("sniper should not have range falloff")
	}
	checks := []struct {
		id, zone string
		metres   float64
		want     int
	}{
		{"ak47", "head", 20, 61}, {"ak47", "stomach", 20, 29}, {"ak47", "arm", 20, 29}, {"ak47", "leg", 20, 29},
		{"ak47", "unknown", 20, 34}, {"dmr", "leg", 35, 46}, {"m2010", "leg", 1000, 100}, {"m2010", "head", 1000, 180},
	}
	for _, tc := range checks {
		if got := Weapons[tc.id].DamageForZone(tc.metres, tc.zone); got != tc.want {
			t.Errorf("%s %s damage at %.0fm = %d, want %d", tc.id, tc.zone, tc.metres, got, tc.want)
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
