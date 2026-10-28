package engine

import (
	"testing"
	"time"
)

func TestTraceShotPlayerHitUsesExactOlderViewPose(t *testing.T) {
	now := time.Now()
	target := NewPlayer("target")
	target.State.X, target.State.Z, target.State.Rw = 1.5, -5, 1
	target.State.X = 0
	viewAt := now.Add(-300 * time.Millisecond)
	target.recordHitPose(viewAt)
	target.State.X = 1.5
	if _, _, hit := tracePlayerHit(vector{0, 1.2, 0}, vector{0, 1.2, -10}, position(target), [4]float32{0, 0, 0, 1}); hit {
		t.Fatal("current-pose trace unexpectedly hit the laterally displaced target")
	}
	shooter := testViewTimeShooter(viewAt, 400*time.Millisecond)
	zone, _, hit := traceShotPlayerHit(shooter, target, now)
	if !hit || zone != "torso" {
		t.Fatalf("historical chest shot returned zone=%q hit=%v; want torso", zone, hit)
	}
}

func TestTraceShotPlayerHitDoesNotSearchForBetterPose(t *testing.T) {
	now := time.Now()
	target := NewPlayer("target")
	target.State.Z, target.State.Rw = -5, 1
	target.State.X = 0
	target.recordHitPose(now.Add(-300 * time.Millisecond))
	target.State.X = 1.5
	viewAt := now.Add(-100 * time.Millisecond)
	target.recordHitPose(viewAt)
	target.State.X = 0
	shooter := testViewTimeShooter(viewAt, 400*time.Millisecond)
	if zone, _, hit := traceShotPlayerHit(shooter, target, now); hit {
		t.Fatalf("viewed later miss was retargeted to an earlier %q hit", zone)
	}
}

func TestTraceShotPlayerHitHonorsViewTimeAndRewindBounds(t *testing.T) {
	now := time.Now()
	t.Run("legacy zero timestamp is current only", func(t *testing.T) {
		target := movingPoseTarget(now, []struct {
			at time.Time
			x  float32
		}{{now.Add(-100 * time.Millisecond), 0}})
		shooter := testViewTimeShooter(time.Time{}, 400*time.Millisecond)
		if _, _, hit := traceShotPlayerHit(shooter, target, now); hit {
			t.Fatal("zero timestamp rewound to an old pose")
		}
	})
	t.Run("zero window rejects explicit old pose", func(t *testing.T) {
		target := movingPoseTarget(now, []struct {
			at time.Time
			x  float32
		}{{now.Add(-100 * time.Millisecond), 0}})
		shooter := testViewTimeShooter(now.Add(-100*time.Millisecond), 0)
		if _, _, hit := traceShotPlayerHit(shooter, target, now); hit {
			t.Fatal("zero rewind window accepted an old pose")
		}
	})
	t.Run("sample outside budget", func(t *testing.T) {
		target := movingPoseTarget(now, []struct {
			at time.Time
			x  float32
		}{{now.Add(-400 * time.Millisecond), 0}})
		shooter := testViewTimeShooter(now.Add(-400*time.Millisecond), 300*time.Millisecond)
		if _, _, hit := traceShotPlayerHit(shooter, target, now); hit {
			t.Fatal("accepted a hit older than the allowed RTT budget")
		}
	})
	t.Run("window above hard cap", func(t *testing.T) {
		target := NewPlayer("target")
		target.State.Rw = 1
		viewAt := now.Add(-700 * time.Millisecond)
		target.State.X = 0
		target.recordHitPose(viewAt)
		target.State.X = 1.5
		shooter := testViewTimeShooter(viewAt, 2*time.Second)
		if _, _, hit := traceShotPlayerHit(shooter, target, now); hit {
			t.Fatal("accepted a shot with a rewind window above the hard cap")
		}
	})
	t.Run("age beyond hard cap", func(t *testing.T) {
		target := NewPlayer("target")
		target.State.Rw = 1
		viewAt := now.Add(-753 * time.Millisecond)
		target.State.X = 0
		target.recordHitPose(viewAt)
		target.State.X = 1.5
		shooter := testViewTimeShooter(viewAt, maxHitRewind)
		if _, _, hit := traceShotPlayerHit(shooter, target, now); hit {
			t.Fatal("accepted a pose older than the maximum rewind age")
		}
	})
	t.Run("future timestamp rejected", func(t *testing.T) {
		target := NewPlayer("target")
		target.State.Z, target.State.Rw = -5, 1
		target.recordHitPose(now)
		shooter := testViewTimeShooter(now.Add(time.Millisecond), 100*time.Millisecond)
		if _, _, hit := traceShotPlayerHit(shooter, target, now); hit {
			t.Fatal("accepted a future view timestamp")
		}
	})
}

func TestTraceShotPlayerHitInterpolatesBetweenSamples(t *testing.T) {
	now := time.Now()
	target := NewPlayer("target")
	target.State.Z, target.State.Rw = -5, 1
	for _, sample := range []struct {
		at time.Time
		x  float32
	}{{now.Add(-100 * time.Millisecond), -0.4}, {now.Add(-50 * time.Millisecond), 0.4}} {
		target.State.X = sample.x
		target.recordHitPose(sample.at)
	}
	target.State.X = 1.5
	if _, _, hit := tracePlayerHit(vector{0, 1.2, 0}, vector{0, 1.2, -10}, position(target), [4]float32{0, 0, 0, 1}); hit {
		t.Fatal("current-pose trace unexpectedly hit")
	}
	shooter := testViewTimeShooter(now.Add(-75*time.Millisecond), 200*time.Millisecond)
	zone, _, hit := traceShotPlayerHit(shooter, target, now)
	if !hit || zone != "torso" {
		t.Fatalf("interpolated hit returned zone=%q hit=%v; want torso", zone, hit)
	}
}

func TestHitPoseHistoryClearsOnRespawnDeathDriverTeleportAndGap(t *testing.T) {
	base := time.Now()
	t.Run("respawn", func(t *testing.T) {
		m := NewMatch()
		room := NewRoom("respawn-history", "history", "industrial", "FFA")
		p := NewPlayer("target")
		p.hitHistory.count = 2
		m.respawnPlayer(room, p)
		if p.hitHistory.count != 0 {
			t.Fatal("respawn retained old hit poses")
		}
	})
	for _, tc := range []struct {
		name  string
		setup func(*Player)
	}{
		{name: "death", setup: func(p *Player) { p.State.IsDead = true }},
		{name: "driver", setup: func(p *Player) { p.State.DrivingVehicleId = "vehicle" }},
	} {
		t.Run(tc.name, func(t *testing.T) {
			p := NewPlayer("target")
			p.State.Rw = 1
			p.recordHitPose(base)
			tc.setup(p)
			p.recordHitPose(base.Add(50 * time.Millisecond))
			if p.hitHistory.count != 0 {
				t.Fatalf("%s retained %d poses", tc.name, p.hitHistory.count)
			}
		})
	}
	for _, tc := range []struct {
		name string
		move float32
		gap  time.Duration
	}{
		{name: "teleport", move: 9, gap: 50 * time.Millisecond},
		{name: "stale recording gap", move: 0, gap: maxHitRewind + time.Millisecond},
	} {
		t.Run(tc.name, func(t *testing.T) {
			p := NewPlayer("target")
			p.State.Rw = 1
			p.recordHitPose(base)
			p.State.X = tc.move
			p.recordHitPose(base.Add(tc.gap))
			if p.hitHistory.count != 1 {
				t.Fatalf("%s should clear discontinuous history, count=%d", tc.name, p.hitHistory.count)
			}
		})
	}
}

func TestHitPoseHistoryIsBounded(t *testing.T) {
	p := NewPlayer("target")
	p.State.Rw = 1
	base := time.Now()
	for i := 0; i < len(p.hitHistory.poses)+8; i++ {
		p.State.X = float32(i) * 0.1
		p.recordHitPose(base.Add(time.Duration(i) * 50 * time.Millisecond))
	}
	if p.hitHistory.count != len(p.hitHistory.poses) {
		t.Fatalf("history count=%d, want bounded capacity %d", p.hitHistory.count, len(p.hitHistory.poses))
	}
	oldest := p.hitHistory.poses[p.hitHistory.next]
	wantOldest := base.Add(8 * 50 * time.Millisecond)
	if !oldest.at.Equal(wantOldest) {
		t.Fatalf("oldest retained pose at %v, want %v", oldest.at, wantOldest)
	}
}

func TestValidateAndApplyHitUsesHistoricalZoneAndDamage(t *testing.T) {
	shooter, target := NewPlayer("shooter"), NewPlayer("target")
	target.State.Z, target.State.Rw = -5, 1
	now := time.Now()
	target.recordHitPose(now.Add(-300 * time.Millisecond))
	target.State.X = 1.5
	shooter.HitRewindWindow = 400 * time.Millisecond
	shooter.HitViewTime = now.Add(-300 * time.Millisecond)
	shooter.ActiveWeapon = Weapons["ak47"]
	fireEvent := &FireEvent{ShotId: 1, OriginY: 1.2, HitY: 1.2, HitZ: -10}
	if err := shooter.ValidateFireRay(fireEvent); err != nil {
		t.Fatal(err)
	}
	if _, err := shooter.ValidateAndApplyHit(target, 1); err != nil {
		t.Fatalf("valid historical hit rejected: %v", err)
	}
	wantHealth := int32(100 - shooter.ActiveWeapon.DamageForZone(4.84, "torso"))
	if target.State.Health != wantHealth {
		t.Fatalf("historical torso health=%d, want %d", target.State.Health, wantHealth)
	}
}

func TestMatchKeepsOcclusionAndFriendlyFireChecksWithRewind(t *testing.T) {
	t.Run("wall", func(t *testing.T) {
		m, room, session, shooter := fixture(t)
		shooter.State.X, shooter.State.Y, shooter.State.Z = 0, 0, 0
		shooter.State.Rw = 1
		shooter.DrawUntil = time.Time{}
		target := NewPlayer("target")
		target.State.Z, target.State.Rw = -5, 1
		viewAt := time.Now().Add(-300 * time.Millisecond)
		target.recordHitPose(viewAt)
		target.State.X = 1.5
		room.PlayerIndices[target.ID] = len(room.PlayerEntities)
		room.PlayerEntities = append(room.PlayerEntities, *target)
		room.Vehicles = nil
		room.Geometry = &mapGeometry{root: buildCollision([]triangle{{vector{-2, 0, -2}, vector{-2, 3, -2}, vector{2, 3, -2}}, {vector{-2, 0, -2}, vector{2, 3, -2}, vector{2, 0, -2}}})}
		session.rttNanos.Store(int64(300 * time.Millisecond))
		session.lastAckAt.Store(time.Now().UnixNano())
		origin, end := vector{0, 1.2, 0}, vector{0, 1.2, -10}
		sendTest(m, session, &ClientEvent{Event: &ClientEvent_Fire{Fire: &FireEvent{ShotId: 1, OriginX: origin[0], OriginY: origin[1], OriginZ: origin[2], HitX: end[0], HitY: end[1], HitZ: end[2]}}})
		shooter = &room.PlayerEntities[room.PlayerIndices[session.PlayerID]]
		if shooter.HitRewindWindow <= 0 || shooter.PendingHit {
			t.Fatal("wall fixture did not retain a rewind window while rejecting shot damage")
		}
		sendTest(m, session, &ClientEvent{Event: &ClientEvent_Hit{Hit: &HitEvent{TargetId: target.ID, ShotId: 1, Damage: 999, ViewTimeMs: uint64(viewAt.UnixMilli())}}})
		if got := room.PlayerEntities[room.PlayerIndices[target.ID]].State.Health; got != 100 {
			t.Fatalf("wall-occluded historical shot dealt damage: health=%d", got)
		}
	})
	t.Run("friendly fire", func(t *testing.T) {
		m, room, session, shooter := fixture(t)
		shooter.State.X, shooter.State.Y, shooter.State.Z = 0, 0, 0
		shooter.DrawUntil = time.Time{}
		room.Mode = "TDM"
		room.Geometry = &mapGeometry{}
		room.Vehicles = nil
		shooter.State.Team, shooter.State.Rw = "A", 1
		target := NewPlayer("teammate")
		target.State.Team, target.State.Z, target.State.Rw = "A", -5, 1
		target.recordHitPose(time.Now().Add(-300 * time.Millisecond))
		target.State.X = 1.5
		room.PlayerIndices[target.ID] = len(room.PlayerEntities)
		room.PlayerEntities = append(room.PlayerEntities, *target)
		session.rttNanos.Store(int64(300 * time.Millisecond))
		session.lastAckAt.Store(time.Now().UnixNano())
		origin, end := vector{0, 1.2, 0}, vector{0, 1.2, -10}
		sendTest(m, session, &ClientEvent{Event: &ClientEvent_Fire{Fire: &FireEvent{ShotId: 1, OriginX: origin[0], OriginY: origin[1], OriginZ: origin[2], HitX: end[0], HitY: end[1], HitZ: end[2]}}})
		shooter = &room.PlayerEntities[room.PlayerIndices[session.PlayerID]]
		if shooter.HitRewindWindow <= 0 {
			t.Fatal("friendly-fire fixture did not enable rewind")
		}
		sendTest(m, session, &ClientEvent{Event: &ClientEvent_Hit{Hit: &HitEvent{TargetId: target.ID, ShotId: 1, Damage: 999}}})
		if got := room.PlayerEntities[room.PlayerIndices[target.ID]].State.Health; got != 100 {
			t.Fatalf("historical shot damaged teammate: health=%d", got)
		}
	})
}

func TestFriendlyClaimCannotRetargetEnemyBehind(t *testing.T) {
	m, room, session, _ := newRewindShieldMatch(t)
	friend := newRewindMatchTarget("friend", "A", -3, 0, time.Now())
	enemy := newRewindMatchTarget("enemy", "B", -6, 0, time.Now())
	appendRewindTargets(room, friend, enemy)
	fireRewindTestShot(m, session, 1)

	sendTest(m, session, &ClientEvent{Event: &ClientEvent_Hit{Hit: &HitEvent{TargetId: "friend", ShotId: 1}}})
	if room.PlayerEntities[room.PlayerIndices[session.PlayerID]].PendingHit {
		t.Fatal("friendly claim did not consume its shot")
	}
	sendTest(m, session, &ClientEvent{Event: &ClientEvent_Hit{Hit: &HitEvent{TargetId: "enemy", ShotId: 1, Damage: 999}}})
	if got := room.PlayerEntities[room.PlayerIndices["enemy"]].State.Health; got != 100 {
		t.Fatalf("replayed shot retargeted the enemy behind a friendly: health=%d", got)
	}
}

func TestDirectEnemyClaimIsBlockedByFriendlyInFront(t *testing.T) {
	m, room, session, _ := newRewindShieldMatch(t)
	appendRewindTargets(room,
		newRewindMatchTarget("friend", "A", -3, 0, time.Now()),
		newRewindMatchTarget("enemy", "B", -6, 0, time.Now()),
	)
	fireRewindTestShot(m, session, 1)
	sendTest(m, session, &ClientEvent{Event: &ClientEvent_Hit{Hit: &HitEvent{TargetId: "enemy", ShotId: 1, Damage: 999}}})
	if got := room.PlayerEntities[room.PlayerIndices["enemy"]].State.Health; got != 100 {
		t.Fatalf("direct enemy claim passed through friendly body: health=%d", got)
	}
	if room.PlayerEntities[room.PlayerIndices[session.PlayerID]].PendingHit {
		t.Fatal("blocked shot claim was not consumed")
	}
}

func TestShotBlockerUsesMatchingHistoricalPose(t *testing.T) {
	now := time.Now()
	shotAt := now.Add(-300 * time.Millisecond)
	shooter, target, friend := NewPlayer("shooter"), NewPlayer("target"), NewPlayer("friend")
	shooter.ShotOrigin = [3]float32{0, 1.2, 0}
	shooter.ShotEnd = [3]float32{0, 1.2, -10}
	shooter.HitRewindWindow = 400 * time.Millisecond
	shooter.HitViewTime = shotAt
	target.State.Z, target.State.Rw = -8, 1
	target.State.X = 0
	target.recordHitPose(shotAt)
	target.State.X = 1.5
	friend.State.Z, friend.State.Rw = -3, 1
	friend.State.X = 0
	friend.recordHitPose(shotAt)
	friend.State.X = 1.5 // Outside the lane now, but blocked the shot at shotAt.
	room := &Room{PlayerEntities: []Player{*shooter, *target, *friend}}
	if !shotBlockedByPlayer(room, &room.PlayerEntities[0], &room.PlayerEntities[1], now) {
		t.Fatal("friendly at the historical target-hit time did not block the rewound target")
	}

	// Invert the blocker movement: its old pose was clear, and only its current
	// pose is in the lane. It must not become a shield retroactively.
	friendInRoom := &room.PlayerEntities[2]
	friendInRoom.State.X = 1.5
	friendInRoom.hitHistory = hitPoseHistory{}
	friendInRoom.recordHitPose(shotAt)
	friendInRoom.State.X = 0
	if shotBlockedByPlayer(room, &room.PlayerEntities[0], &room.PlayerEntities[1], now) {
		t.Fatal("current friendly pose blocked a shot that passed before it entered the lane")
	}
}

func TestHitPoseLookupDoesNotInterpolateAcrossRespawnOrTeleport(t *testing.T) {
	now := time.Now()
	oldAt := now.Add(-200 * time.Millisecond)
	t.Run("respawn", func(t *testing.T) {
		m := NewMatch()
		room := NewRoom("pose-respawn", "pose", "industrial", "FFA")
		p := NewPlayer("target")
		p.State.Rw = 1
		p.recordHitPose(oldAt)
		m.respawnPlayer(room, p)
		if _, ok := poseForHitAt(p, now, oldAt); ok {
			t.Fatal("pose lookup interpolated through respawn")
		}
	})
	t.Run("teleport", func(t *testing.T) {
		p := NewPlayer("target")
		p.State.Rw = 1
		p.recordHitPose(oldAt)
		p.State.X = 10
		p.recordHitPose(now.Add(-100 * time.Millisecond))
		if _, ok := poseForHitAt(p, now, oldAt); ok {
			t.Fatal("pose lookup interpolated through teleport")
		}
	})
}

func newRewindShieldMatch(t *testing.T) (*Match, *Room, *GameSession, *Player) {
	t.Helper()
	m, room, session, shooter := fixture(t)
	room.Mode = "TDM"
	room.Geometry = &mapGeometry{}
	room.Vehicles = nil
	shooter.State.X, shooter.State.Y, shooter.State.Z = 0, 0, 0
	shooter.State.Team, shooter.State.Rw = "A", 1
	shooter.DrawUntil = time.Time{}
	session.rttNanos.Store(int64(300 * time.Millisecond))
	session.lastAckAt.Store(time.Now().UnixNano())
	return m, room, session, shooter
}

func newRewindMatchTarget(id, team string, z, x float32, poseAt time.Time) *Player {
	p := NewPlayer(id)
	p.State.Team, p.State.Z, p.State.X, p.State.Rw = team, z, x, 1
	p.recordHitPose(poseAt.Add(-300 * time.Millisecond))
	return p
}

func appendRewindTargets(room *Room, targets ...*Player) {
	for _, target := range targets {
		room.PlayerIndices[target.ID] = len(room.PlayerEntities)
		room.PlayerEntities = append(room.PlayerEntities, *target)
	}
}

func fireRewindTestShot(m *Match, session *GameSession, shotID uint64) {
	origin, end := vector{0, 1.2, 0}, vector{0, 1.2, -10}
	sendTest(m, session, &ClientEvent{Event: &ClientEvent_Fire{Fire: &FireEvent{ShotId: shotID, OriginX: origin[0], OriginY: origin[1], OriginZ: origin[2], HitX: end[0], HitY: end[1], HitZ: end[2]}}})
}

func movingPoseTarget(now time.Time, samples []struct {
	at time.Time
	x  float32
}) *Player {
	p := NewPlayer("target")
	p.State.Z, p.State.Rw = -5, 1
	for _, sample := range samples {
		p.State.X = sample.x
		p.recordHitPose(sample.at)
	}
	p.State.X = 1.5
	return p
}

func BenchmarkTraceShotPlayerHitHistorical(b *testing.B) {
	now := time.Now()
	target := NewPlayer("target")
	target.State.Z, target.State.Rw = -5, 1
	for i := 0; i < len(target.hitHistory.poses); i++ {
		at := now.Add(time.Duration(i-len(target.hitHistory.poses)+1) * 50 * time.Millisecond)
		target.State.X = 1.5
		if i == len(target.hitHistory.poses)-8 {
			target.State.X = 0
		}
		target.recordHitPose(at)
	}
	target.State.X = 1.5
	shooter := testViewTimeShooter(now.Add(-350*time.Millisecond), 750*time.Millisecond)
	if _, _, hit := traceShotPlayerHit(shooter, target, now); !hit {
		b.Fatal("benchmark fixture did not hit the historical pose")
	}
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		traceShotPlayerHit(shooter, target, now)
	}
}

func testViewTimeShooter(viewAt time.Time, window time.Duration) *Player {
	shooter := NewPlayer("shooter")
	shooter.ShotOrigin = [3]float32{0, 1.2, 0}
	shooter.ShotEnd = [3]float32{0, 1.2, -10}
	shooter.HitViewTime = viewAt
	shooter.HitRewindWindow = window
	return shooter
}
