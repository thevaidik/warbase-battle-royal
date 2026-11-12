package engine

import (
	"fmt"
	"google.golang.org/protobuf/proto"
	"math"
	"sync"
	"testing"
	"time"
)

func fire(id uint64) *FireEvent { return &FireEvent{OriginY: 1.2, HitY: 1.2, HitZ: -5, ShotId: id} }
func TestFireCadence(t *testing.T) {
	for id, weapon := range Weapons {
		t.Run(id, func(t *testing.T) {
			p := NewPlayer("shooter")
			p.ActiveWeapon = weapon
			p.AmmoCount = weapon.MagSize
			if err := p.ValidateFireRay(fire(1)); err != nil {
				t.Fatal(err)
			}
			if err := p.ValidateFireRay(fire(2)); err == nil {
				t.Fatal("accepted immediate second shot")
			}
			if p.AmmoCount != weapon.MagSize-1 {
				t.Fatal("rejected shot spent ammo")
			}
			p.NextShotTime = time.Now().Add(-time.Second)
			if err := p.ValidateFireRay(fire(3)); err != nil {
				t.Fatal(err)
			}
			if err := p.ValidateFireRay(fire(3)); err == nil {
				t.Fatal("accepted replayed shot ID")
			}
		})
	}
}
func TestHitIsSingleUseAndServerDamage(t *testing.T) {
	p, target := NewPlayer("shooter"), NewPlayer("target")
	target.State.Z = -5
	if _, err := p.ValidateAndApplyHit(target, 100); err == nil {
		t.Fatal("hit without shot")
	}
	if err := p.ValidateFireRay(fire(1)); err != nil {
		t.Fatal(err)
	}
	if _, err := p.ValidateAndApplyHit(target, 9999); err != nil {
		t.Fatal(err)
	}
	if target.State.Health != 100-int32(p.ActiveWeapon.DamageForZone(5, "torso")) {
		t.Fatalf("server did not derive torso damage: %d", target.State.Health)
	}
	if _, err := p.ValidateAndApplyHit(target, 34); err == nil {
		t.Fatal("reused a shot")
	}
	p.NextShotTime = time.Now().Add(-time.Second)
	_ = p.ValidateFireRay(fire(2))
	target.State.X = 10000
	if _, err := p.ValidateAndApplyHit(target, 34); err == nil {
		t.Fatal("accepted distant hit")
	}
}
func TestFireCoordinates(t *testing.T) {
	for _, value := range []float32{float32(math.NaN()), float32(math.Inf(1)), 10000} {
		p := NewPlayer("p")
		event := fire(1)
		event.OriginX = value
		if err := p.ValidateFireRay(event); err == nil {
			t.Fatal("accepted invalid origin")
		}
	}
}
func TestReload(t *testing.T) {
	p := NewPlayer("p")
	p.AmmoCount = 1
	if err := p.ValidateAndApplyReload(); err != nil {
		t.Fatal(err)
	}
	if err := p.ValidateFireRay(fire(1)); err == nil {
		t.Fatal("fired during reload")
	}
	p.ReloadStart = time.Now().Add(-3 * time.Second)
	if err := p.ValidateFireRay(fire(2)); err != nil {
		t.Fatal(err)
	}
	if p.AmmoCount != 29 {
		t.Fatal("reload did not refill magazine")
	}
}
func sendTest(m *Match, s *GameSession, event *ClientEvent) {
	data, _ := proto.Marshal(event)
	m.processMessage(Message{Session: s, SenderID: s.PlayerID, RoomID: s.RoomID, Data: data})
}
func fixture(t *testing.T) (*Match, *Room, *GameSession, *Player) {
	t.Helper()
	m := NewMatch()
	room := m.rooms["industrial-public"]
	s := NewGameSession(m, nil, "probe", room.ID)
	room.Sessions[s] = true
	m.sessions[s] = true
	sendTest(m, s, &ClientEvent{Event: &ClientEvent_StateUpdate{StateUpdate: &PlayerStateUpdate{}}})
	return m, room, s, &room.PlayerEntities[0]
}
func TestRespawnAndTeleport(t *testing.T) {
	m, room, s, p := fixture(t)
	p.State.Health = 25
	p.AmmoCount = 3
	sendTest(m, s, &ClientEvent{Event: &ClientEvent_RespawnRequest{RespawnRequest: &RespawnRequestEvent{}}})
	if p.State.Health != 25 || p.AmmoCount != 3 {
		t.Fatal("living player gained free health/ammo")
	}
	initial := p.State.X
	for i := 0; i < 8; i++ {
		sendTest(m, s, &ClientEvent{Event: &ClientEvent_StateUpdate{StateUpdate: &PlayerStateUpdate{X: 1000, Y: 1, Z: 1000, Animation: "death"}}})
	}
	if p.State.X != initial {
		t.Fatal("repeated teleport bypassed validation")
	}
	p.State.IsDead = true
	p.DeathTime = time.Now()
	sendTest(m, s, &ClientEvent{Event: &ClientEvent_RespawnRequest{RespawnRequest: &RespawnRequestEvent{}}})
	if !p.State.IsDead {
		t.Fatal("respawned before delay")
	}
	p.DeathTime = time.Now().Add(-4 * time.Second)
	sendTest(m, s, &ClientEvent{Event: &ClientEvent_RespawnRequest{RespawnRequest: &RespawnRequestEvent{}}})
	if p.State.IsDead || p.State.Health != 100 || p.AmmoCount != 30 {
		t.Fatal("eligible respawn failed")
	}
	if room.Geometry == nil || len(room.Geometry.spawns) == 0 {
		t.Fatal("missing authored map spawns")
	}
}
func TestFinishedRoundRejectsFire(t *testing.T) {
	m, room, s, p := fixture(t)
	p.State.X, p.State.Y, p.State.Z = 0, 0, 0
	p.DrawUntil = time.Time{}
	room.Geometry = &mapGeometry{}
	room.State = "FINISHED"
	sendTest(m, s, &ClientEvent{Event: &ClientEvent_Fire{Fire: fire(1)}})
	if p.AmmoCount != 30 {
		t.Fatal("fired in finished round")
	}
}
func TestAtomicAdmission(t *testing.T) {
	m := NewMatch()
	go m.Run()
	defer m.Stop()
	var wg sync.WaitGroup
	var accepted int
	var mu sync.Mutex
	for i := 0; i < 32; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			s := NewGameSession(m, nil, "same-name", "industrial-public")
			if m.Register(s) == nil {
				mu.Lock()
				accepted++
				mu.Unlock()
			}
			_ = m.IsUsernameTaken("industrial-public", "same-name")
		}()
	}
	wg.Wait()
	if accepted != 1 {
		t.Fatalf("admitted %d sessions with same identity", accepted)
	}
}
func TestJoinLeaveRace(t *testing.T) {
	m := NewMatch()
	go m.Run()
	defer m.Stop()
	var wg sync.WaitGroup
	for i := 0; i < 60; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			id := fmt.Sprintf("probe-%d", i)
			s := NewGameSession(m, nil, id, "industrial-public")
			if err := m.Register(s); err != nil {
				t.Error(err)
				return
			}
			data, _ := proto.Marshal(&ClientEvent{Event: &ClientEvent_StateUpdate{StateUpdate: &PlayerStateUpdate{}}})
			m.Broadcast(Message{Session: s, SenderID: id, RoomID: s.RoomID, Data: data})
			_ = m.IsUsernameTaken(s.RoomID, id)
			m.ListActiveRooms()
			m.Unregister(s)
		}(i)
	}
	wg.Wait()
}
func TestMapOcclusion(t *testing.T) {
	wall := triangle{vector{-2, 0, -2}, vector{2, 0, -2}, vector{0, 4, -2}}
	g := &mapGeometry{root: buildCollision([]triangle{wall})}
	if !g.blocked(vector{0, 1, 0}, vector{0, 1, -5}) {
		t.Fatal("shot passed through wall")
	}
	if g.blocked(vector{0, 1, 0}, vector{5, 1, 0}) {
		t.Fatal("clear shot blocked")
	}
	for _, id := range []string{"industrial", "village", "arena", "shipment", "loft"} {
		g := geometryFor(id)
		if g == nil || g.root == nil || len(g.spawns) < 2 {
			t.Fatalf("missing map %s", id)
		}
	}
}

func TestCoalescedSnapshotsPreserveAOI(t *testing.T) {
	s := NewGameSession(nil, nil, "viewer", "room")
	encode := func(players map[string]*PlayerState) []byte {
		data, _ := proto.Marshal(&ServerMessage{Message: &ServerMessage_GameState{GameState: &GameState{Players: players}}})
		return data
	}
	s.EnqueueStateUpdate(encode(map[string]*PlayerState{"far": {X: 50}, "near": {X: 1}}))
	s.EnqueueStateUpdate(encode(map[string]*PlayerState{"near": {X: 2}}))
	message := &ServerMessage{}
	_ = proto.Unmarshal(<-s.stateQueue, message)
	if len(message.GetGameState().Players) != 2 || message.GetGameState().Players["near"].X != 2 {
		t.Fatal("coalescing lost rare entities or newest transforms")
	}
}

func TestGrenadeAuthority(t *testing.T) {
	m, room, s, p := fixture(t)
	room.Geometry = &mapGeometry{spawns: []vector{{0, 0, 0}}}
	p.State.X, p.State.Y, p.State.Z = 0, 0, 0
	throw := func() {
		sendTest(m, s, &ClientEvent{Event: &ClientEvent_ThrowGrenade{ThrowGrenade: &ThrowGrenadeEvent{Py: 1, Vz: -2}}})
	}
	throw()
	throw()
	if len(room.Grenades) != 1 || p.GrenadesRemaining != 1 {
		t.Fatal("grenade cooldown or inventory ignored")
	}
	p.LastGrenadeTime = time.Now().Add(-2 * time.Second)
	throw()
	p.LastGrenadeTime = time.Now().Add(-2 * time.Second)
	throw()
	if len(room.Grenades) != 2 || p.GrenadesRemaining != 0 {
		t.Fatal("unlimited grenades")
	}
	target := NewPlayer("victim")
	target.State.Z = -1
	target.State.Health = 80
	room.PlayerIndices[target.ID] = len(room.PlayerEntities)
	room.PlayerEntities = append(room.PlayerEntities, *target)
	m.explodeGrenade(room, &serverGrenade{id: 1, owner: p.ID, pos: vector{0, 0.9, -1}})
	if !target.State.IsDead || target.State.Health != 0 {
		t.Fatal("server did not resolve lethal explosion")
	}
}

func TestMovementDoesNotCrossWall(t *testing.T) {
	g := &mapGeometry{root: buildCollision([]triangle{{vector{-3, 0, -1}, vector{3, 0, -1}, vector{0, 5, -1}}})}
	if !g.movementBlocked(vector{0, 0, 0}, vector{0, 0, -2}) {
		t.Fatal("movement crossed map collision")
	}
	if g.movementBlocked(vector{0, 0, 0}, vector{0.1, 0, 0}) {
		t.Fatal("clear movement blocked")
	}
}

func TestOccludedShotAcknowledgesAmmoWithoutDamage(t *testing.T) {
	m, room, s, p := fixture(t)
	p.State.X, p.State.Y, p.State.Z = 0, 0, 0
	p.DrawUntil = time.Time{}
	room.Geometry = &mapGeometry{root: buildCollision([]triangle{{vector{-3, 0, -2}, vector{3, 0, -2}, vector{0, 5, -2}}})}
	sendTest(m, s, &ClientEvent{Event: &ClientEvent_Fire{Fire: fire(1)}})
	if p.State.LastShotId != 1 || p.AmmoCount != 29 || p.PendingHit {
		t.Fatal("occluded shot must acknowledge, spend ammo, and reject damage")
	}
}

func TestWeaponHeadshotDamage(t *testing.T) {
	for id, cfg := range Weapons {
		t.Run(id, func(t *testing.T) {
			shooter, target := NewPlayer("shooter"), NewPlayer("target")
			shooter.ActiveWeapon = cfg
			shooter.AmmoCount = cfg.MagSize
			target.State.Z = -5
			target.State.Health = 500
			event := fire(1)
			event.OriginY = 1.65
			event.HitY = 1.65
			if err := shooter.ValidateFireRay(event); err != nil {
				t.Fatal(err)
			}
			if _, err := shooter.ValidateAndApplyHit(target, 1); err != nil {
				t.Fatal(err)
			}
			expected := 500 - int32(math.Round(float64(cfg.Damage)*cfg.HeadshotMultiplier))
			if target.State.Health != expected {
				t.Fatalf("incorrect headshot damage: %d", target.State.Health)
			}
		})
	}
}
