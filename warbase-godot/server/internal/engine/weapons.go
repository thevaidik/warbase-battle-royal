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
	"m4":  {ID: "m4", Damage: 20, HeadshotMultiplier: 1.8, RPM: 750, MagSize: 30, ReloadTime: 2200 * time.Millisecond},
	"mp5": {ID: "mp5", Damage: 17, HeadshotMultiplier: 1.6, RPM: 850, MagSize: 30, ReloadTime: 1800 * time.Millisecond},
	"dmr": {ID: "dmr", Damage: 40, HeadshotMultiplier: 1.7, RPM: 240, MagSize: 20, ReloadTime: 2600 * time.Millisecond},
	"ak47": {
		ID:                 "ak47",
		Damage:             22,
		HeadshotMultiplier: 1.8,
		RPM:                600,
		ReloadTime:         2500 * time.Millisecond,
		MagSize:            30,
	},
	"pistol": {
		ID:                 "pistol",
		Damage:             24,
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
		Damage:             26,
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
	start, end, minimum := 15.0, 70.0, 0.55
	if w.ID == "mp5" {
		start, end, minimum = 10, 45, 0.45
	}
	if w.ID == "pistol" {
		start, end, minimum = 10, 50, 0.5
	}
	if w.ID == "dmr" || w.ID == "m2010" {
		start, end, minimum = 35, 150, 0.75
	}
	fraction := math.Max(0, math.Min(1, (metres-start)/(end-start)))
	return int(math.Round(float64(w.Damage) * (1 - fraction*(1-minimum))))
}
