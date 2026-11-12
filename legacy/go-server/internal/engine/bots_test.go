package engine

import (
	"math/rand/v2"
	"testing"
	"time"
)

func TestOnlineBotPopulation(t *testing.T) {
	m, room, session, _ := fixture(t)
	room.Navigation = navigationFor(room.Geometry)
	m.syncBots(room)
	if len(room.Bots) != 7 || len(room.PlayerEntities) != 8 {
		t.Fatalf("expected human + 7 bots, got %d entities", len(room.PlayerEntities))
	}
	for _, p := range room.PlayerEntities {
		if p.Bot != nil && (!p.HasSpawned || p.ActiveWeapon.RPM == 0 || p.State.Health != 100) {
			t.Fatal("uninitialised AI")
		}
	}
	for i := 0; i < 7; i++ {
		room.Sessions[NewGameSession(m, nil, string(rune('a'+i)), room.ID)] = true
	}
	m.syncBots(room)
	if len(room.Bots) != 0 || len(room.PlayerEntities) != 1 {
		t.Fatal("bots did not yield to humans")
	}
	clear(room.Sessions)
	delete(m.sessions, session)
	m.syncBots(room)
	if room.botCount.Load() != 0 {
		t.Fatal("empty room retained bots")
	}
	if room.CachedGameState.Players["probe"] == nil {
		t.Fatal("bot removal lost human state")
	}
}

func TestNavigationRoutesAroundWall(t *testing.T) {
	floor := []triangle{{vector{-12, 0, -12}, vector{12, 0, -12}, vector{12, 0, 12}}, {vector{-12, 0, -12}, vector{12, 0, 12}, vector{-12, 0, 12}}}
	wall := []triangle{{vector{0, 0, -6}, vector{0, 4, -6}, vector{0, 4, 6}}, {vector{0, 0, -6}, vector{0, 4, 6}, vector{0, 0, 6}}}
	g := &mapGeometry{spawns: []vector{{-6, 0, 0}, {6, 0, 0}}, root: buildCollision(append(floor, wall...))}
	n := buildNavigation(g)
	path := n.path(n.nearest(vector{-6, 0.05, 0}, g), n.nearest(vector{6, 0.05, 0}, g))
	if len(path) < 3 {
		t.Fatal("no path around obstacle")
	}
	for i := 1; i < len(path); i++ {
		if g.movementBlocked(n.nodes[path[i-1]].position, n.nodes[path[i]].position) {
			t.Fatal("path cuts through wall")
		}
	}
	if !g.blocked(vector{-6, 1, 0}, vector{6, 1, 0}) {
		t.Fatal("fixture has no occlusion")
	}
}

func TestAuthoredMapNavigation(t *testing.T) {
	for _, name := range []string{"industrial", "village", "arena", "resoforge", "shipment", "desert_oasis"} {
		t.Run(name, func(t *testing.T) {
			g := geometryFor(name)
			start := time.Now()
			n := navigationFor(g)
			accessible := 0
			for _, p := range g.spawns {
				if n.nearest(p, g) >= 0 {
					accessible++
				}
			}
			t.Logf("nodes=%d reachable spawns=%d/%d build=%s", len(n.nodes), accessible, len(g.spawns), time.Since(start))
			if len(n.nodes) < 10 || accessible == 0 {
				t.Fatal("map has no usable bot navigation")
			}
		})
	}
}

func TestBotPerceptionOcclusionAndRespawn(t *testing.T) {
	m := NewMatch()
	room := NewRoom("test", "test", "industrial", "FFA")
	wall := []triangle{{vector{0, 0, -10}, vector{0, 4, -10}, vector{0, 4, 10}}, {vector{0, 0, -10}, vector{0, 4, 10}, vector{0, 0, 10}}}
	room.Geometry = &mapGeometry{spawns: []vector{{-5, 0, 0}}, root: buildCollision(wall)}
	p, target := NewPlayer("BOT:TEST"), NewPlayer("human")
	p.State.X = -5
	target.State.X = 5
	p.Bot = &botBrain{rng: rand.New(rand.NewPCG(1, 2))}
	faceBot(p, position(target))
	room.PlayerEntities = []Player{*p, *target}
	room.PlayerIndices = map[string]int{p.ID: 0, target.ID: 1}
	now := time.Now()
	m.advanceBots(room, now, 1.0/60)
	if room.PlayerEntities[0].Bot.visible || target.State.Health != 100 {
		t.Fatal("AI saw or shot through wall")
	}
	target = &room.PlayerEntities[1]
	target.LastShotTime = now
	room.PlayerEntities[0].Bot.perceiveAt = time.Time{}
	m.advanceBots(room, now, 1.0/60)
	if room.PlayerEntities[0].Bot.visible || room.PlayerEntities[0].Bot.lastKnown != position(target) || target.State.Health != 100 {
		t.Fatal("hearing must reveal a location without granting sight or damage")
	}
	room.Geometry.root = nil
	p = &room.PlayerEntities[0]
	p.Bot.perceiveAt = time.Time{}
	m.advanceBots(room, now, 1.0/60)
	if !p.Bot.visible || target.State.Health != 100 {
		t.Fatal("missing sight or skipped reaction delay")
	}
	p.State.IsDead = true
	p.DeathTime = now.Add(-4 * time.Second)
	m.advanceBots(room, now, 1.0/60)
	if p.State.IsDead || p.State.Health != 100 || p.AmmoCount != 30 {
		t.Fatal("bot respawn did not reset combat state")
	}
}

func TestBotsUseAuthorityAndRespectTeams(t *testing.T) {
	m := NewMatch()
	room := NewRoom("test", "test", "industrial", "TDM")
	room.Geometry = &mapGeometry{}
	p, target := NewPlayer("BOT:TEST"), NewPlayer("human")
	p.State.Team = "A"
	target.State.Team = "B"
	target.State.Z = -6
	p.Bot = &botBrain{rng: rand.New(rand.NewPCG(7, 9)), lastKnown: position(target)}
	room.PlayerEntities = []Player{*p, *target}
	room.PlayerIndices = map[string]int{p.ID: 0, target.ID: 1}
	p = &room.PlayerEntities[0]
	target = &room.PlayerEntities[1]
	now := time.Now()
	m.fireBot(room, p, target, now)
	if p.AmmoCount != 29 {
		t.Fatal("bot shot did not consume authoritative ammo")
	}
	ammo := p.AmmoCount
	m.fireBot(room, p, target, now)
	if p.AmmoCount != ammo {
		t.Fatal("bot bypassed RPM limit")
	}
	m.fireBot(room, p, target, now.Add(time.Minute/time.Duration(p.ActiveWeapon.RPM)))
	if p.AmmoCount != ammo-1 {
		t.Fatal("bot failed to fire after its legal cooldown")
	}
	if enemies(room, p, p) {
		t.Fatal("bot targets itself")
	}
	target.State.Team = "A"
	if enemies(room, p, target) {
		t.Fatal("bot targets teammate")
	}
	p.State.Kills = 1
	m.recordKill(room, p)
	if room.ScoreTeamA != 1 || room.CachedGameState.ScoreTeamA != 1 {
		t.Fatal("bot kill not scored")
	}
}

func TestColdNavigationDoesNotBlockLiveMatches(t *testing.T) {
	m, r, _, _ := fixture(t)
	geometry := &mapGeometry{}
	r.Geometry = geometry
	started, release := make(chan struct{}), make(chan struct{})
	navigationCache.Store(geometry, func() *navigation { close(started); <-release; return &navigation{} })
	defer navigationCache.Delete(geometry)
	defer close(release)
	done := make(chan struct{})
	go func() { m.syncBots(r); close(done) }()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("cold map blocked live match processing")
	}
	select {
	case <-started:
	case <-time.After(time.Second):
		t.Fatal("navigation preparation did not start")
	}
	if len(r.Bots) != 0 || r.preparedNavigation.Load() != nil {
		t.Fatal("bots spawned before their walk graph was ready")
	}
}
