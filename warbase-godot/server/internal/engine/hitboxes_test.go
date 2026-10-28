package engine

import (
	"math"
	"testing"
	"time"
)

func TestTracePlayerHitAllAnatomicalZones(t *testing.T) {
	cases := []struct {
		name string
		from vector
		to   vector
		zone string
	}{
		{name: "head", from: vector{0, 1.62, 2}, to: vector{0, 1.62, -2}, zone: "head"},
		{name: "torso", from: vector{0, 1.05, 2}, to: vector{0, 1.05, -2}, zone: "torso"},
		{name: "stomach", from: vector{0, 0.72, 2}, to: vector{0, 0.72, -2}, zone: "stomach"},
		{name: "left arm", from: vector{-0.3, 1.2, 2}, to: vector{-0.3, 1.2, -2}, zone: "arm"},
		{name: "right arm", from: vector{0.3, 1.2, 2}, to: vector{0.3, 1.2, -2}, zone: "arm"},
		{name: "left leg", from: vector{-0.12, 0.45, 2}, to: vector{-0.12, 0.45, -2}, zone: "leg"},
		{name: "right leg", from: vector{0.12, 0.45, 2}, to: vector{0.12, 0.45, -2}, zone: "leg"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			zone, fraction, hit := tracePlayerHit(tc.from, tc.to, vector{}, [4]float32{0, 0, 0, 1})
			if !hit || zone != tc.zone || fraction < 0 || fraction > 1 {
				t.Fatalf("trace returned zone=%q fraction=%g hit=%v; want %q", zone, fraction, hit, tc.zone)
			}
		})
	}
}

func TestTracePlayerHitMissesOutsideCompactShapes(t *testing.T) {
	cases := []struct {
		name string
		from vector
		to   vector
	}{
		{name: "outside torso width", from: vector{0.24, 1.05, 2}, to: vector{0.24, 1.05, -2}},
		{name: "outside head radius", from: vector{0.15, 1.62, 2}, to: vector{0.15, 1.62, -2}},
		{name: "above head", from: vector{0, 2.0, 2}, to: vector{0, 2.0, -2}},
		{name: "below leg", from: vector{0, -0.2, 2}, to: vector{0, -0.2, -2}},
		{name: "outside narrow neck width", from: vector{0.18, 1.38, 2}, to: vector{0.18, 1.38, -2}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if zone, _, hit := tracePlayerHit(tc.from, tc.to, vector{}, [4]float32{0, 0, 0, 1}); hit {
				t.Fatalf("unexpected hit in %q", zone)
			}
		})
	}
}

func TestTracePlayerHitNeckUsesTorsoDamage(t *testing.T) {
	zone, _, hit := tracePlayerHit(vector{0, 1.38, 2}, vector{0, 1.38, -2}, vector{}, [4]float32{0, 0, 0, 1})
	if !hit || zone != "torso" {
		t.Fatalf("neck shot returned zone=%q hit=%v; want torso damage", zone, hit)
	}
}

func TestFirstPlayerOnShotUsesAnatomicalHitsAndKeepsFriendlyBlocking(t *testing.T) {
	shooter, broadMiss := NewPlayer("shooter"), NewPlayer("broad-miss")
	broadMiss.State.X = 0.3
	broadMiss.State.Z = -5
	room := &Room{PlayerEntities: []Player{*shooter, *broadMiss}}
	if hit := firstPlayerOnShot(room, &room.PlayerEntities[0], vector{0, 1.62, 0}, vector{0, 1.62, -10}); hit != nil {
		t.Fatalf("broad cylinder falsely hit outside anatomical boxes: %q", hit.ID)
	}

	friend, enemy := NewPlayer("friend"), NewPlayer("enemy")
	friend.State.Team, friend.State.Z = "A", -3
	enemy.State.Team, enemy.State.Z = "B", -6
	shooter.State.Team = "A"
	room.PlayerEntities = []Player{*shooter, *friend, *enemy}
	hit := firstPlayerOnShot(room, &room.PlayerEntities[0], vector{0, 1.62, 0}, vector{0, 1.62, -10})
	if hit == nil || hit.ID != "friend" {
		t.Fatalf("friendly body did not remain first shot blocker: got %v", hit)
	}
}

func TestTracePlayerHitAcceptsShapeSurfaceAndRejectsNonFiniteGeometry(t *testing.T) {
	// Both lines run along the exact unexpanded client shape surface.
	if zone, _, hit := tracePlayerHit(vector{0.21, 1.05, 2}, vector{0.21, 1.05, -2}, vector{}, [4]float32{0, 0, 0, 1}); !hit || zone != "torso" {
		t.Fatalf("exact torso surface missed: zone=%q hit=%v", zone, hit)
	}
	if zone, _, hit := tracePlayerHit(vector{0.12, 1.62, 2}, vector{0.12, 1.62, -2}, vector{}, [4]float32{0, 0, 0, 1}); !hit || zone != "head" {
		t.Fatalf("exact head surface missed: zone=%q hit=%v", zone, hit)
	}
	for _, bad := range []vector{{float32(math.NaN()), 1, 2}, {0, float32(math.Inf(1)), 2}} {
		if _, _, hit := tracePlayerHit(bad, vector{0, 1, -2}, vector{}, [4]float32{0, 0, 0, 1}); hit {
			t.Fatalf("accepted non-finite endpoint %v", bad)
		}
	}
	if _, _, hit := tracePlayerHit(vector{0, 1, 2}, vector{0, 1, -2}, vector{}, [4]float32{float32(math.NaN()), 0, 0, 1}); hit {
		t.Fatal("accepted non-finite target rotation")
	}
}

func TestTracePlayerHitUsesRotatedTargetPose(t *testing.T) {
	angle := math.Pi / 2
	rotation := [4]float32{0, float32(math.Sin(angle / 2)), 0, float32(math.Cos(angle / 2))}
	center := vector{8, 2, -3}
	from := rotateTestPoint(vector{0, 1.05, 2}, center, rotation)
	to := rotateTestPoint(vector{0, 1.05, -2}, center, rotation)
	zone, _, hit := tracePlayerHit(from, to, center, rotation)
	if !hit || zone != "torso" {
		t.Fatalf("side-facing target shot missed: zone=%q hit=%v", zone, hit)
	}

	// A ray from the other side still intersects the back of the same torso box.
	from = rotateTestPoint(vector{0, 1.05, -2}, center, rotation)
	to = rotateTestPoint(vector{0, 1.05, 2}, center, rotation)
	zone, _, hit = tracePlayerHit(from, to, center, rotation)
	if !hit || zone != "torso" {
		t.Fatalf("back-facing shot missed: zone=%q hit=%v", zone, hit)
	}
}

func rotateTestPoint(local, center vector, rotation [4]float32) vector {
	rotated := rotateByQuaternion(dvec{float64(local[0]), float64(local[1]), float64(local[2])}, float64(rotation[0]), float64(rotation[1]), float64(rotation[2]), float64(rotation[3]))
	return vector{center[0] + float32(rotated.x), center[1] + float32(rotated.y), center[2] + float32(rotated.z)}
}

func TestValidateAndApplyHitUsesServerZoneDamageAndProtectsDriver(t *testing.T) {
	shooter, target := NewPlayer("shooter"), NewPlayer("target")
	target.State.Z = -5
	target.State.Rw = 1
	shooter.ActiveWeapon = Weapons["ak47"]
	if err := shooter.ValidateFireRay(&FireEvent{ShotId: 1, OriginY: 1.62, HitY: 1.62, HitZ: -5}); err != nil {
		t.Fatal(err)
	}
	if _, err := shooter.ValidateAndApplyHit(target, 9999); err != nil {
		t.Fatal(err)
	}
	if want := int32(100 - shooter.ActiveWeapon.DamageForZone(5, "head")); target.State.Health != want {
		t.Fatalf("headshot health=%d, want %d", target.State.Health, want)
	}

	shooter.NextShotTime = shooter.NextShotTime.Add(-time.Second)
	target.State.DrivingVehicleId = "vehicle"
	if err := shooter.ValidateFireRay(&FireEvent{ShotId: 2, OriginY: 1.05, HitY: 1.05, HitZ: -5}); err != nil {
		t.Fatal(err)
	}
	if _, err := shooter.ValidateAndApplyHit(target, 9999); err == nil {
		t.Fatal("accepted hit on a target inside a vehicle")
	}
}
