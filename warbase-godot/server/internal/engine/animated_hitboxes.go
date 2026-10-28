package engine

import (
	_ "embed"
	"encoding/json"
	"math"
	"sync"
)

//go:embed soldier_hit_poses.json
var soldierHitPoseJSON []byte

type bakedSoldierHitPoses struct {
	FPS   float64                        `json:"fps"`
	Bones []string                       `json:"bones"`
	Clips map[string]bakedSoldierHitClip `json:"clips"`
}

type bakedSoldierHitClip struct {
	Length float64        `json:"length"`
	Loop   bool           `json:"loop"`
	Frames [][][3]float32 `json:"frames"`
}

type bakedPoseFrame [20][3]float32

type animatedCapsuleDef struct {
	from, to string
	zone     string
	radius   float64
	trim     float64
}

var animatedCapsuleDefs = [...]animatedCapsuleDef{
	{from: "mixamorig_Head", to: "mixamorig_HeadTop_End", zone: "head", radius: 0.10, trim: 0.25},
	{from: "mixamorig_Neck", to: "mixamorig_Head", zone: "torso", radius: 0.08},
	{from: "mixamorig_Spine1", to: "mixamorig_Neck", zone: "torso", radius: 0.18},
	{from: "mixamorig_Hips", to: "mixamorig_Spine1", zone: "stomach", radius: 0.17},
	{from: "mixamorig_LeftArm", to: "mixamorig_LeftForeArm", zone: "arm", radius: 0.085},
	{from: "mixamorig_LeftForeArm", to: "mixamorig_LeftHand", zone: "arm", radius: 0.07},
	{from: "mixamorig_RightArm", to: "mixamorig_RightForeArm", zone: "arm", radius: 0.085},
	{from: "mixamorig_RightForeArm", to: "mixamorig_RightHand", zone: "arm", radius: 0.07},
	{from: "mixamorig_LeftUpLeg", to: "mixamorig_LeftLeg", zone: "leg", radius: 0.10},
	{from: "mixamorig_LeftLeg", to: "mixamorig_LeftFoot", zone: "leg", radius: 0.09},
	{from: "mixamorig_LeftFoot", to: "mixamorig_LeftToeBase", zone: "leg", radius: 0.09},
	{from: "mixamorig_RightUpLeg", to: "mixamorig_RightLeg", zone: "leg", radius: 0.10},
	{from: "mixamorig_RightLeg", to: "mixamorig_RightFoot", zone: "leg", radius: 0.09},
	{from: "mixamorig_RightFoot", to: "mixamorig_RightToeBase", zone: "leg", radius: 0.09},
}

var soldierHitPoseOnce sync.Once
var soldierHitPoseData bakedSoldierHitPoses
var soldierHitPoseErr error
var soldierHitBoneIndices map[string]int

func loadSoldierHitPoses() (bakedSoldierHitPoses, error) {
	soldierHitPoseOnce.Do(func() {
		soldierHitPoseErr = json.Unmarshal(soldierHitPoseJSON, &soldierHitPoseData)
		if soldierHitPoseErr != nil {
			return
		}
		if soldierHitPoseData.FPS <= 0 || len(soldierHitPoseData.Bones) != len(bakedPoseFrame{}) || len(soldierHitPoseData.Clips) == 0 {
			soldierHitPoseErr = errInvalidSoldierHitPoseData
			return
		}
		soldierHitBoneIndices = make(map[string]int, len(soldierHitPoseData.Bones))
		for i, bone := range soldierHitPoseData.Bones {
			if bone == "" {
				soldierHitPoseErr = errInvalidSoldierHitPoseData
				return
			}
			if _, exists := soldierHitBoneIndices[bone]; exists {
				soldierHitPoseErr = errInvalidSoldierHitPoseData
				return
			}
			soldierHitBoneIndices[bone] = i
		}
		for _, capsule := range animatedCapsuleDefs {
			if _, ok := soldierHitBoneIndices[capsule.from]; !ok {
				soldierHitPoseErr = errInvalidSoldierHitPoseData
				return
			}
			if _, ok := soldierHitBoneIndices[capsule.to]; !ok {
				soldierHitPoseErr = errInvalidSoldierHitPoseData
				return
			}
		}
		for _, clip := range soldierHitPoseData.Clips {
			if clip.Length <= 0 || len(clip.Frames) < 2 {
				soldierHitPoseErr = errInvalidSoldierHitPoseData
				return
			}
			for _, frame := range clip.Frames {
				if len(frame) != len(soldierHitPoseData.Bones) {
					soldierHitPoseErr = errInvalidSoldierHitPoseData
					return
				}
				for _, point := range frame {
					if !finite(float64(point[0])) || !finite(float64(point[1])) || !finite(float64(point[2])) {
						soldierHitPoseErr = errInvalidSoldierHitPoseData
						return
					}
				}
			}
		}
	})
	return soldierHitPoseData, soldierHitPoseErr
}

var errInvalidSoldierHitPoseData = animatedHitboxError("invalid baked soldier hit pose data")

type animatedHitboxError string

func (e animatedHitboxError) Error() string { return string(e) }

// traceAnimatedPlayerHit intersects a finite shot segment with capsules built
// from the sampled animated skeleton pose. targetRotation uses [x,y,z,w].
func traceAnimatedPlayerHit(origin, end, targetPosition vector, targetRotation [4]float32, animation string, phaseSeconds float64) (zone string, fraction float32, ok bool) {
	if !finiteVec(origin) || !finiteVec(end) || !finiteVec(targetPosition) || !finite(phaseSeconds) {
		return "", 0, false
	}
	// Reject distant rays before loading/interpolating the skeleton. This
	// conservative world-space box contains all baked clips and rotations.
	if !segmentIntersectsPlayerBroadphase(origin, end, targetPosition) {
		return "", 0, false
	}
	poseData, err := loadSoldierHitPoses()
	if err != nil {
		return "", 0, false
	}
	clip, found := poseData.Clips[animation]
	if !found {
		clip, found = poseData.Clips["idle"]
		if !found {
			return "", 0, false
		}
	}
	pose, valid := sampleBakedClip(clip, phaseSeconds)
	if !valid {
		return "", 0, false
	}
	qx, qy, qz, qw := float64(targetRotation[0]), float64(targetRotation[1]), float64(targetRotation[2]), float64(targetRotation[3])
	if !finite(qx) || !finite(qy) || !finite(qz) || !finite(qw) {
		return "", 0, false
	}
	qLength := math.Sqrt(qx*qx + qy*qy + qz*qz + qw*qw)
	if qLength < 1e-6 {
		qx, qy, qz, qw = 0, 0, 0, 1
	} else {
		qx, qy, qz, qw = qx/qLength, qy/qLength, qz/qLength, qw/qLength
	}
	base := dvec{float64(targetPosition[0]), float64(targetPosition[1]), float64(targetPosition[2])}
	startWorld := dvec{float64(origin[0]), float64(origin[1]), float64(origin[2])}
	endWorld := dvec{float64(end[0]), float64(end[1]), float64(end[2])}
	startLocal := rotateByQuaternion(subD(startWorld, base), -qx, -qy, -qz, qw)
	endLocal := rotateByQuaternion(subD(endWorld, base), -qx, -qy, -qz, qw)
	if lengthSquaredD(subD(endLocal, startLocal)) < 1e-12 {
		return "", 0, false
	}

	best := math.Inf(1)
	bestPriority := -1
	for _, capsule := range animatedCapsuleDefs {
		fromIndex := soldierHitBoneIndices[capsule.from]
		toIndex := soldierHitBoneIndices[capsule.to]
		from := toDVec(pose[fromIndex])
		to := toDVec(pose[toIndex])
		if capsule.trim > 0 {
			delta := subD(to, from)
			from = addD(from, delta.at(capsule.trim))
			to = addD(to, delta.at(1-capsule.trim))
		}
		alignedStart, alignedEnd, axisLength, validAxis := alignSegmentToCapsule(startLocal, endLocal, from, to)
		if !validAxis {
			continue
		}
		if hitFraction, hit := segmentCapsule(alignedStart, alignedEnd, dvec{}, axisLength+2*capsule.radius, capsule.radius+hitboxTolerance); hit {
			priority := animatedZonePriority(capsule.zone)
			if priority > bestPriority || priority == bestPriority && hitFraction < best {
				best = hitFraction
				bestPriority = priority
				zone = capsule.zone
				ok = true
			}
		}
	}
	if !ok {
		return "", 0, false
	}
	return zone, float32(best), true
}

func segmentIntersectsPlayerBroadphase(origin, end, position vector) bool {
	// Actor-local bounds: x/z +/-1.5m and y -1m..3m around the root.
	center := [3]float64{float64(position[0]), float64(position[1]), float64(position[2])}
	lowOffset := [3]float64{-1.5, -1, -1.5}
	highOffset := [3]float64{1.5, 3, 1.5}
	enter, leave := float64(0), float64(1)
	for axis := range origin {
		delta := float64(end[axis]) - float64(origin[axis])
		start := float64(origin[axis])
		low, high := center[axis]+lowOffset[axis], center[axis]+highOffset[axis]
		if math.Abs(delta) < 1e-12 {
			if start < low || start > high {
				return false
			}
			continue
		}
		a, b := (low-start)/delta, (high-start)/delta
		if a > b {
			a, b = b, a
		}
		enter = math.Max(enter, a)
		leave = math.Min(leave, b)
		if enter > leave {
			return false
		}
	}
	return leave >= 0 && enter <= 1
}

func animatedZonePriority(zone string) int {
	switch zone {
	case "head":
		return 4
	case "torso":
		return 3
	case "stomach":
		return 2
	case "arm", "leg":
		return 1
	default:
		return 0
	}
}

func sampleBakedClip(clip bakedSoldierHitClip, phaseSeconds float64) (bakedPoseFrame, bool) {
	if clip.Length <= 0 || len(clip.Frames) < 2 || !finite(phaseSeconds) {
		return bakedPoseFrame{}, false
	}
	phase := phaseSeconds
	if clip.Loop {
		phase = math.Mod(phase, clip.Length)
		if phase < 0 {
			phase += clip.Length
		}
	} else {
		phase = math.Max(0, math.Min(clip.Length, phase))
	}
	framePosition := phase / clip.Length * float64(len(clip.Frames)-1)
	first := int(math.Floor(framePosition))
	if first >= len(clip.Frames)-1 {
		var pose bakedPoseFrame
		if len(clip.Frames[len(clip.Frames)-1]) != len(pose) {
			return bakedPoseFrame{}, false
		}
		copy(pose[:], clip.Frames[len(clip.Frames)-1])
		return pose, true
	}
	second := first + 1
	blend := float32(framePosition - float64(first))
	var pose bakedPoseFrame
	if len(clip.Frames[second]) != len(pose) {
		return bakedPoseFrame{}, false
	}
	for bone := range pose {
		for axis := range pose[bone] {
			pose[bone][axis] = clip.Frames[first][bone][axis] + (clip.Frames[second][bone][axis]-clip.Frames[first][bone][axis])*blend
		}
	}
	return pose, true
}

func toDVec(point [3]float32) dvec {
	return dvec{float64(point[0]), float64(point[1]), float64(point[2])}
}

func addD(a, b dvec) dvec { return dvec{a.x + b.x, a.y + b.y, a.z + b.z} }

func dotD(a, b dvec) float64 { return a.x*b.x + a.y*b.y + a.z*b.z }

func crossD(a, b dvec) dvec {
	return dvec{a.y*b.z - a.z*b.y, a.z*b.x - a.x*b.z, a.x*b.y - a.y*b.x}
}

func normalizeD(v dvec) (dvec, float64, bool) {
	length := math.Sqrt(lengthSquaredD(v))
	if length < 1e-9 || !finite(length) {
		return dvec{}, 0, false
	}
	return dvec{v.x / length, v.y / length, v.z / length}, length, true
}

func alignSegmentToCapsule(rayStart, rayEnd, capsuleStart, capsuleEnd dvec) (dvec, dvec, float64, bool) {
	axis, axisLength, ok := normalizeD(subD(capsuleEnd, capsuleStart))
	if !ok {
		return dvec{}, dvec{}, 0, false
	}
	reference := dvec{0, 0, 1}
	if math.Abs(axis.z) > 0.9 {
		reference = dvec{1, 0, 0}
	}
	xAxis, _, ok := normalizeD(crossD(reference, axis))
	if !ok {
		return dvec{}, dvec{}, 0, false
	}
	zAxis := crossD(xAxis, axis)
	center := dvec{(capsuleStart.x + capsuleEnd.x) / 2, (capsuleStart.y + capsuleEnd.y) / 2, (capsuleStart.z + capsuleEnd.z) / 2}
	align := func(point dvec) dvec {
		relative := subD(point, center)
		return dvec{dotD(relative, xAxis), dotD(relative, axis), dotD(relative, zAxis)}
	}
	return align(rayStart), align(rayEnd), axisLength, true
}
