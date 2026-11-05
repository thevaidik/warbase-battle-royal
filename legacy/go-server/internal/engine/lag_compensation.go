package engine

import (
	"math"
	"time"
)

const maxHitRewind = 750 * time.Millisecond

// The ring holds more than a second of 20 Hz authoritative poses. It never
// contains client-supplied target positions or grows with match duration.
type hitPose struct {
	at        time.Time
	position  vector
	rotation  [4]float32
	animation string
	phase     float64
}

type hitPoseHistory struct {
	poses [32]hitPose
	next  int
	count int
}

func currentHitPose(p *Player, at time.Time) hitPose {
	phase := float64(p.State.AnimationTime)
	if p.animationName == p.State.Animation && !p.animationStart.IsZero() {
		phase = max(0, at.Sub(p.animationStart).Seconds())
	} else if p.animationName != "" && p.animationName != p.State.Animation {
		phase = 0
	}
	return hitPose{at: at, position: position(p), rotation: [4]float32{p.State.Rx, p.State.Ry, p.State.Rz, p.State.Rw}, animation: p.State.Animation, phase: phase}
}

func (p *Player) recordHitPose(at time.Time) {
	if p == nil || p.State == nil {
		return
	}
	p.State.PoseTimeMs = uint64(at.UnixMilli())
	if p.State.IsDead || p.State.DrivingVehicleId != "" {
		p.hitHistory = hitPoseHistory{}
		return
	}
	if p.animationName != p.State.Animation || p.animationStart.IsZero() {
		p.animationName = p.State.Animation
		p.animationStart = at
	}
	p.State.AnimationTime = float32(max(0, at.Sub(p.animationStart).Seconds()))
	h := &p.hitHistory
	pose := currentHitPose(p, at)
	if !finiteVec(pose.position) {
		return
	}
	if h.count > 0 {
		last := h.poses[(h.next+len(h.poses)-1)%len(h.poses)]
		if !at.After(last.at) {
			return
		}
		// Never invent a path across a teleport or an interrupted pose stream.
		if distance(last.position, pose.position) > 8 || at.Sub(last.at) > maxHitRewind {
			*h = hitPoseHistory{}
		}
	}
	h.poses[h.next] = pose
	h.next = (h.next + 1) % len(h.poses)
	if h.count < len(h.poses) {
		h.count++
	}
}

func interpolateHitPose(a, b hitPose, at time.Time) hitPose {
	k := float32(0)
	if b.at.After(a.at) {
		k = float32(at.Sub(a.at).Seconds() / b.at.Sub(a.at).Seconds())
	}
	k = max(0, min(1, k))
	p := hitPose{at: at}
	if a.animation == b.animation {
		p.animation = a.animation
		p.phase = a.phase + (b.phase-a.phase)*float64(k)
	} else if k < 0.5 {
		p.animation, p.phase = a.animation, a.phase
	} else {
		p.animation, p.phase = b.animation, b.phase
	}
	for axis := range p.position {
		p.position[axis] = a.position[axis] + (b.position[axis]-a.position[axis])*k
	}
	// Normalized quaternion lerp follows the short arc and is sufficient over
	// the small intervals between authoritative samples.
	var dotProduct float32
	for axis := range a.rotation {
		dotProduct += a.rotation[axis] * b.rotation[axis]
	}
	sign := float32(1)
	if dotProduct < 0 {
		sign = -1
	}
	var square float64
	for axis := range p.rotation {
		p.rotation[axis] = a.rotation[axis] + (b.rotation[axis]*sign-a.rotation[axis])*k
		square += float64(p.rotation[axis] * p.rotation[axis])
	}
	if square > 0 {
		length := float32(math.Sqrt(square))
		for axis := range p.rotation {
			p.rotation[axis] /= length
		}
	}
	return p
}

// traceShotPlayerHit tests exactly the pose the client reported viewing. A
// legacy shot with no view timestamp is checked against the current pose only;
// the server never searches a time interval for a more favorable hit.
func traceShotPlayerHit(shooter, target *Player, now time.Time) (zone string, fraction float32, hit bool) {
	if shooter == nil || target == nil || shooter.State == nil || target.State == nil || !finiteVec(vector(shooter.ShotOrigin)) || !finiteVec(vector(shooter.ShotEnd)) {
		return "", 0, false
	}
	origin, end := vector(shooter.ShotOrigin), vector(shooter.ShotEnd)
	viewAt := shooter.HitViewTime
	if viewAt.IsZero() {
		pose := currentHitPose(target, now)
		return traceAnimatedPlayerHit(origin, end, pose.position, pose.rotation, pose.animation, pose.phase)
	}
	window := shooter.HitRewindWindow
	if window <= 0 || window > maxHitRewind || viewAt.After(now) || now.Sub(viewAt) > window+2*time.Millisecond {
		return "", 0, false
	}
	pose, ok := poseForHitAt(target, now, viewAt)
	if !ok {
		return "", 0, false
	}
	return traceAnimatedPlayerHit(origin, end, pose.position, pose.rotation, pose.animation, pose.phase)
}

// poseForHitAt uses the same time for every body on a shot, so a friendly that
// moved since firing neither becomes a new shield nor permits shooting through
// its old position. It never interpolates across a respawn or teleport.
func poseForHitAt(p *Player, now, at time.Time) (hitPose, bool) {
	if p == nil || p.State == nil || at.After(now) || now.Sub(at) > maxHitRewind+2*time.Millisecond {
		return hitPose{}, false
	}
	newer := currentHitPose(p, now)
	if at.Equal(now) || now.Sub(at) <= 2*time.Millisecond {
		return newer, true
	}
	h := &p.hitHistory
	if h.count == 0 {
		return hitPose{}, false
	}
	var oldest hitPose
	for i := 0; i < h.count; i++ {
		older := h.poses[(h.next+len(h.poses)-1-i)%len(h.poses)]
		if older.at.After(newer.at) {
			continue
		}
		oldest = older
		if !at.Before(older.at) {
			if newer.at.Sub(older.at) > maxHitRewind || distance(older.position, newer.position) > 8 {
				return hitPose{}, false
			}
			return interpolateHitPose(older, newer, at), true
		}
		newer = older
	}
	// Replicated PoseTimeMs is integer milliseconds, so its timestamp may
	// precede the stored sub-millisecond sample by less than one millisecond.
	if !oldest.at.IsZero() && oldest.at.Sub(at) <= 2*time.Millisecond && now.Sub(oldest.at) <= maxHitRewind {
		return oldest, true
	}
	return hitPose{}, false
}

func shotBlockedByPlayer(room *Room, shooter, target *Player, now time.Time) bool {
	origin, end := vector(shooter.ShotOrigin), vector(shooter.ShotEnd)
	_, targetFraction, hit := traceShotPlayerHit(shooter, target, now)
	if !hit {
		return false // The ordinary hit validator will consume and reject the miss.
	}
	at := shooter.HitViewTime
	if at.IsZero() {
		at = now
	}
	for i := range room.PlayerEntities {
		other := &room.PlayerEntities[i]
		if other.ID == shooter.ID || other.ID == target.ID || other.State.IsDead || other.State.DrivingVehicleId != "" {
			continue
		}
		pose, available := poseForHitAt(other, now, at)
		if !available {
			continue
		}
		if _, fraction, blocks := traceAnimatedPlayerHit(origin, end, pose.position, pose.rotation, pose.animation, pose.phase); blocks && fraction < targetFraction-0.00001 {
			return true
		}
	}
	return false
}
