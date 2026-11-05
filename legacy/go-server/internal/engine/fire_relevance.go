package engine

// Only remote cosmetic fire is sampled. Nearby shots and passing bullets always
// retain their effects. Damage, ammunition and hit validation are unaffected.
func relevantFire(room *Room, viewerID string, fire *FireEvent) bool {
	index, ok := room.PlayerIndices[viewerID]
	if !ok {
		return false
	}
	viewer := room.PlayerEntities[index].State
	px, py, pz := viewer.X, viewer.Y+1.6, viewer.Z
	dx, dy, dz := fire.OriginX-px, fire.OriginY-py, fire.OriginZ-pz
	originDistance := dx*dx + dy*dy + dz*dz
	if originDistance <= 35*35 {
		return true
	}
	vx, vy, vz := fire.HitX-fire.OriginX, fire.HitY-fire.OriginY, fire.HitZ-fire.OriginZ
	length := vx*vx + vy*vy + vz*vz
	fraction := float32(0)
	if length > 0 {
		fraction = max(float32(0), min(float32(1), -(dx*vx+dy*vy+dz*vz)/length))
	}
	dx += fraction * vx
	dy += fraction * vy
	dz += fraction * vz
	if dx*dx+dy*dy+dz*dz <= 12*12 {
		return true
	}
	return originDistance <= 120*120 && fire.ShotId%2 == 1
}
