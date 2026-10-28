package engine

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

type combatFixtureRow struct {
	Weapon string  `json:"weapon"`
	RangeM float64 `json:"range_m"`
	Zone   string  `json:"zone"`
	Damage int     `json:"damage"`
}

func combatFixtureJSON() ([]byte, error) {
	weaponIDs := []string{"ak47", "m4", "mp5", "hmg", "pistol", "dmr", "m2010"}
	ranges := []float64{0, 10, 20, 35, 55, 100, 150, 300}
	zones := []string{"head", "torso", "stomach", "arm", "leg"}
	rows := make([]combatFixtureRow, 0, len(weaponIDs)*len(ranges)*len(zones))
	for _, id := range weaponIDs {
		weapon, ok := Weapons[id]
		if !ok {
			return nil, os.ErrNotExist
		}
		for _, metres := range ranges {
			for _, zone := range zones {
				rows = append(rows, combatFixtureRow{
					Weapon: id,
					RangeM: metres,
					Zone:   zone,
					Damage: weapon.DamageForZone(metres, zone),
				})
			}
		}
	}
	data, err := json.MarshalIndent(rows, "", "  ")
	if err != nil {
		return nil, err
	}
	return append(data, '\n'), nil
}

func TestCombatFixtureMatchesLiveWeaponConfigs(t *testing.T) {
	fixture, err := combatFixtureJSON()
	if err != nil {
		t.Fatal(err)
	}
	path := os.Getenv("WARBASE_COMBAT_FIXTURE")
	if path != "" {
		if !filepath.IsAbs(path) {
			t.Fatal("WARBASE_COMBAT_FIXTURE must be an absolute path")
		}
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, fixture, 0o644); err != nil {
			t.Fatal(err)
		}
		return
	}

	path = "../../../client/scripts/tests/combat-fixture.json"
	checkedIn, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read cross-runtime combat fixture %s: %v", path, err)
	}
	if !bytes.Equal(checkedIn, fixture) {
		t.Fatalf("cross-runtime combat fixture %s differs from live Go weapon configs; regenerate with WARBASE_COMBAT_FIXTURE=/absolute/path/%s", path, filepath.Base(path))
	}
}
