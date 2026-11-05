package engine

import (
	"math"
	"time"
)

// WeaponConfig defines authoritative weapon properties
type WeaponConfig struct {
	ID                 string
	Damage             int
	HeadshotMultiplier float64
	RPM                int // Fire rate
	MagSize            int
	ReloadTime         time.Duration // e.g. 2500ms
}

// Authoritative definitions of all in-game weapons
var Weapons = map[string]WeaponConfig{
	"m4":  {ID: "m4", Damage: 25, HeadshotMultiplier: 1.8, RPM: 750, MagSize: 30, ReloadTime: 2200 * time.Millisecond},
	"mp5": {ID: "mp5", Damage: 25, HeadshotMultiplier: 1.6, RPM: 850, MagSize: 30, ReloadTime: 1800 * time.Millisecond},
	"dmr": {ID: "dmr", Damage: 50, HeadshotMultiplier: 1.7, RPM: 240, MagSize: 20, ReloadTime: 2600 * time.Millisecond},
	"ak47": {
		ID:                 "ak47",
		Damage:             34,
		HeadshotMultiplier: 1.8,
		RPM:                600,
		ReloadTime:         2500 * time.Millisecond,
		MagSize:            30,
	},
	"pistol": {
		ID:                 "pistol",
		Damage:             34,
		HeadshotMultiplier: 1.8,
		RPM:                400,
		ReloadTime:         1500 * time.Millisecond,
		MagSize:            12,
	},
	"m2010": {
		ID:                 "m2010",
		Damage:             100,
		HeadshotMultiplier: 1.8,
		RPM:                45,
		ReloadTime:         3200 * time.Millisecond,
		MagSize:            5,
	},
	"hmg": {
		ID:                 "hmg",
		Damage:             34,
		HeadshotMultiplier: 1.8,
		RPM:                520,
		ReloadTime:         3400 * time.Millisecond,
		MagSize:            60,
	},
}

// Smooth falloff preserves close-range weapon identity without laser damage at range.
func (w WeaponConfig) DamageAtRange(metres float64) int {
	if w.ID == "m2010" {
		return 100
	}
	start, end, minimum := 20.0, 90.0, 0.60
	if w.ID == "mp5" {
		start, end, minimum = 10, 45, 0.45
	}
	if w.ID == "pistol" {
		start, end, minimum = 10, 50, 0.5
	}
	if w.ID == "dmr" {
		start, end, minimum = 35, 150, 0.75
	}
	fraction := math.Max(0, math.Min(1, (metres-start)/(end-start)))
	return int(math.Round(float64(w.Damage) * (1 - fraction*(1-minimum))))
}

// DamageForZone applies the shared range and hit-zone rules. Unknown zones use torso damage.
func (w WeaponConfig) DamageForZone(metres float64, zone string) int {
	damage := float64(w.DamageAtRange(metres))
	switch zone {
	case "head":
		damage *= w.HeadshotMultiplier
	case "stomach", "arm", "leg":
		if w.ID == "dmr" {
			damage *= 0.91
		} else {
			damage *= 0.84
		}
	}
	if w.ID == "m2010" && damage < 100 {
		damage = 100
	}
	return int(math.Round(damage))
}
