package engine

import (
	"math/rand/v2"
	"testing"
	"time"
)

func TestSniperOneHitAtEveryRangeAndHeight(t *testing.T) {
	for _, metres := range []float32{5, 100, 250, 300} {
		for _, height := range []float32{0.35, 1, 1.7} {
			p, target := NewPlayer("shooter"), NewPlayer("target")
			p.ActiveWeapon = Weapons["m2010"]
			p.AmmoCount = 5
			target.State.Z = -metres
			hitX := float32(0)
			if height == 0.35 {
				hitX = 0.12 // Aim at the anatomical leg instead of the gap between the feet.
			}
			event := &FireEvent{ShotId: 1, OriginY: 1.6, HitX: hitX, HitY: height, HitZ: -metres}
			if err := p.ValidateFireRay(event); err != nil {
				t.Fatal(err)
			}
			if killed, err := p.ValidateAndApplyHit(target, 0); err != nil || !killed {
				t.Fatalf("sniper failed at %gm height %g: %v", metres, height, err)
			}
		}
	}
}

func TestBotEvadesVisibleGrenade(t *testing.T) {
	m := NewMatch()
	room := NewRoom("test", "test", "industrial", "FFA")
	floor := []triangle{{vector{-30, 0, -30}, vector{30, 0, -30}, vector{30, 0, 30}}, {vector{-30, 0, -30}, vector{30, 0, 30}, vector{-30, 0, 30}}}
	room.Geometry = &mapGeometry{spawns: []vector{{-8, 0, 0}, {8, 0, 0}}, root: buildCollision(floor)}
	room.Navigation = buildNavigation(room.Geometry)
	room.Vehicles = nil
	p := NewPlayer("bot")
	p.State.X = -3
	p.State.Y = 0.05
	p.Bot = &botBrain{rng: rand.New(rand.NewPCG(2, 4))}
	room.PlayerEntities = []Player{*p}
	room.PlayerIndices = map[string]int{p.ID: 0}
	room.Grenades = []*serverGrenade{{pos: vector{0, 0.1, 0}, age: 0.5}}
	now := time.Now()
	m.advanceBots(room, now, 1.0/60)
	brain := room.PlayerEntities[0].Bot
	if brain.intent != "evade" || len(brain.path) == 0 || distance(brain.escapeGoal, room.Grenades[0].pos) < 10 {
		t.Fatal("bot did not plan an escape outside the blast")
	}
	if room.PlayerEntities[0].AmmoCount != 30 {
		t.Fatal("bot fired while evading")
	}
}

func TestBotKeepsVisibleTarget(t *testing.T) {
	m := NewMatch()
	room := NewRoom("test", "test", "industrial", "FFA")
	room.Geometry = &mapGeometry{}
	room.Vehicles = nil
	p, a, b := NewPlayer("bot"), NewPlayer("current"), NewPlayer("slightly-nearer")
	p.Bot = &botBrain{target: a.ID, rng: rand.New(rand.NewPCG(1, 2)), reactAt: time.Now().Add(time.Second)}
	a.State.Z = -10
	b.State.Z = -9.5
	room.PlayerEntities = []Player{*p, *a, *b}
	room.PlayerIndices = map[string]int{p.ID: 0, a.ID: 1, b.ID: 2}
	m.advanceBots(room, time.Now(), 1.0/60)
	if p.Bot.target != a.ID {
		t.Fatal("bot abandoned its current visible target for a marginal distance change")
	}
}

func TestBotCannotSenseGrenadeThroughWall(t *testing.T) {
	m := NewMatch()
	room := NewRoom("test", "test", "industrial", "FFA")
	room.Geometry = &mapGeometry{root: buildCollision([]triangle{{vector{0, 0, -20}, vector{0, 4, -20}, vector{0, 4, 20}}, {vector{0, 0, -20}, vector{0, 4, 20}, vector{0, 0, 20}}})}
	room.Navigation = &navigation{nodes: []navNode{{position: vector{-12, 0.05, 0}}}}
	p := NewPlayer("bot")
	p.State.X = -3
	p.Bot = &botBrain{}
	room.Grenades = []*serverGrenade{{pos: vector{3, 0.1, 0}, age: 1}}
	m.perceiveGrenades(room, p, time.Now())
	if !p.Bot.evadeUntil.IsZero() {
		t.Fatal("AI reacted to a hidden grenade")
	}
}
