package engine

import (
	"bytes"
	"math"
	"os"
	"path/filepath"
	"strconv"
	"testing"
)

func TestServerAndClientBakedHitPosesAreIdentical(t *testing.T) {
	clientPath := filepath.Join("..", "..", "..", "client", "assets", "data", "soldier_hit_poses.json")
	clientData, err := os.ReadFile(clientPath)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(clientData, soldierHitPoseJSON) {
		t.Fatal("server baked soldier hit poses differ from the client source")
	}
	poses, err := loadSoldierHitPoses()
	if err != nil {
		t.Fatal(err)
	}
	if poses.FPS != 30 || len(poses.Bones) != 20 {
		t.Fatalf("unexpected baked pose metadata: fps=%g bones=%d", poses.FPS, len(poses.Bones))
	}
	for _, animation := range []string{"idle", "run", "firing walk", "firing", "jump"} {
		clip, ok := poses.Clips[animation]
		if !ok || len(clip.Frames) < 2 {
			t.Fatalf("missing baked animation %q", animation)
		}
	}
}

func TestTraceAnimatedPlayerHitTracksHeadAcrossAnimation(t *testing.T) {
	poses, err := loadSoldierHitPoses()
	if err != nil {
		t.Fatal(err)
	}
	boneIndex := make(map[string]int, len(poses.Bones))
	for i, name := range poses.Bones {
		boneIndex[name] = i
	}
	targetPosition := vector{7, 2, -4}
	rotation := [4]float32{0, float32(0.38268343), 0, float32(0.92387953)}
	for _, sample := range []struct {
		animation string
		phase     float64
	}{
		{animation: "idle", phase: 0},
		{animation: "idle", phase: 4.3},
		{animation: "run", phase: 0},
		{animation: "run", phase: 0.35},
		{animation: "jump", phase: 0.17},
		{animation: "jump", phase: 0.60},
	} {
		t.Run(sample.animation+"/"+formatPhase(sample.phase), func(t *testing.T) {
			pose, ok := sampleBakedClip(poses.Clips[sample.animation], sample.phase)
			if !ok {
				t.Fatal("could not sample baked pose")
			}
			fromIndex, toIndex := boneIndex["mixamorig_Head"], boneIndex["mixamorig_HeadTop_End"]
			from, to := toDVec(pose[fromIndex]), toDVec(pose[toIndex])
			delta := subD(to, from)
			from = addD(from, delta.at(0.25))
			to = addD(to, delta.at(0.75))
			point := addD(from, subD(to, from).at(0.82))
			direction, _, ok := normalizeD(crossD(subD(to, from), dvec{0, 0, 1}))
			if !ok {
				t.Fatal("could not form a head test ray")
			}
			startLocal := addD(point, direction.at(2))
			endLocal := subD(point, direction.at(2))
			startWorld := animatedTestToWorld(startLocal, targetPosition, rotation)
			endWorld := animatedTestToWorld(endLocal, targetPosition, rotation)
			zone, _, hit := traceAnimatedPlayerHit(startWorld, endWorld, targetPosition, rotation, sample.animation, sample.phase)
			if !hit || zone != "head" {
				t.Fatalf("animated head ray returned zone=%q hit=%v", zone, hit)
			}
			if sample.animation == "run" {
				if _, _, staticHit := tracePlayerHit(startWorld, endWorld, targetPosition, rotation); staticHit {
					t.Fatal("legacy upright head volume unexpectedly hit the animated running head")
				}
			}
		})
	}
}

func TestTraceAnimatedPlayerHitTracksLimbsAndRejectsMisses(t *testing.T) {
	poses, err := loadSoldierHitPoses()
	if err != nil {
		t.Fatal(err)
	}
	boneIndex := make(map[string]int, len(poses.Bones))
	for i, name := range poses.Bones {
		boneIndex[name] = i
	}
	clip := poses.Clips["run"]
	phase := 0.21
	pose, ok := sampleBakedClip(clip, phase)
	if !ok {
		t.Fatal("could not sample running pose")
	}
	for _, tc := range []struct {
		name string
		from string
		to   string
		zone string
	}{
		{name: "left forearm", from: "mixamorig_LeftArm", to: "mixamorig_LeftForeArm", zone: "arm"},
		{name: "right shin", from: "mixamorig_RightLeg", to: "mixamorig_RightFoot", zone: "leg"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			point := midpoint(pose[boneIndex[tc.from]], pose[boneIndex[tc.to]])
			axis := subD(toDVec(pose[boneIndex[tc.to]]), toDVec(pose[boneIndex[tc.from]]))
			direction, _, ok := normalizeD(crossD(axis, dvec{0, 1, 0}))
			if !ok {
				direction, _, ok = normalizeD(crossD(axis, dvec{0, 0, 1}))
			}
			if !ok {
				t.Fatal("could not form limb ray")
			}
			start := addD(point, direction.at(2))
			end := subD(point, direction.at(2))
			zone, _, hit := traceAnimatedPlayerHit(vectorFromD(start), vectorFromD(end), vector{}, [4]float32{0, 0, 0, 1}, "run", phase)
			if !hit || zone != tc.zone {
				t.Fatalf("%s ray returned zone=%q hit=%v", tc.name, zone, hit)
			}
		})
	}

	// A ray displaced well beyond the sampled skeleton must stay a miss.
	head := pose[boneIndex["mixamorig_Head"]]
	start := vector{head[0] + 1, head[1], head[2] + 2}
	end := vector{head[0] + 1, head[1], head[2] - 2}
	if zone, _, hit := traceAnimatedPlayerHit(start, end, vector{}, [4]float32{0, 0, 0, 1}, "run", phase); hit {
		t.Fatalf("off-skeleton ray hit %q", zone)
	}
}

func TestTraceAnimatedPlayerHitPromotesLimbWhenSamePlayerBodyIsReached(t *testing.T) {
	t.Run("arm to chest", func(t *testing.T) {
		// At this idle pose the right forearm is the first surface on the ray;
		// the torso capsule lies farther along the same finite segment.
		armZone, _, armHit := traceAnimatedPlayerHit(vector{1, 1.25, 0.02}, vector{0.3, 1.25, 0.02}, vector{}, [4]float32{0, 0, 0, 1}, "idle", 0)
		if !armHit || armZone != "arm" {
			t.Fatalf("finite arm-only segment returned zone=%q hit=%v", armZone, armHit)
		}
		zone, _, hit := traceAnimatedPlayerHit(vector{1, 1.25, 0.02}, vector{-1, 1.25, 0.02}, vector{}, [4]float32{0, 0, 0, 1}, "idle", 0)
		if !hit || zone != "torso" {
			t.Fatalf("arm followed by chest returned zone=%q hit=%v; want torso", zone, hit)
		}
	})

	t.Run("arm to head", func(t *testing.T) {
		// In this jump pose, a ray through the right arm continues into the head.
		// The short finite segment ends before the head; extending it reaches it.
		rotation := [4]float32{0, 0, 0, 1}
		poses, err := loadSoldierHitPoses()
		if err != nil {
			t.Fatal(err)
		}
		pose, ok := sampleBakedClip(poses.Clips["jump"], 0.33)
		if !ok {
			t.Fatal("could not sample jump pose")
		}
		indexes := soldierHitBoneIndices
		armCenter := midpoint(pose[indexes["mixamorig_RightArm"]], pose[indexes["mixamorig_RightForeArm"]])
		headFrom := toDVec(pose[indexes["mixamorig_Head"]])
		headTo := toDVec(pose[indexes["mixamorig_HeadTop_End"]])
		headDelta := subD(headTo, headFrom)
		headFrom = addD(headFrom, headDelta.at(0.25))
		headTo = addD(headFrom, headDelta.at(0.5))
		headCenter := addD(headFrom, subD(headTo, headFrom).at(0.5))
		direction, _, ok := normalizeD(subD(headCenter, armCenter))
		if !ok {
			t.Fatal("could not form arm-to-head ray")
		}
		start := addD(armCenter, direction.at(-0.3))
		shortEnd := addD(armCenter, direction.at(0.05))
		fullEnd := addD(headCenter, direction.at(0.25))
		shortZone, _, shortHit := traceAnimatedPlayerHit(vectorFromD(start), vectorFromD(shortEnd), vector{}, rotation, "jump", 0.33)
		if !shortHit || shortZone == "head" {
			t.Fatalf("finite segment ending before head returned zone=%q hit=%v", shortZone, shortHit)
		}
		zone, _, hit := traceAnimatedPlayerHit(vectorFromD(start), vectorFromD(fullEnd), vector{}, rotation, "jump", 0.33)
		if !hit || zone != "head" {
			t.Fatalf("arm followed by head returned zone=%q hit=%v; want head", zone, hit)
		}
	})
}

func TestTraceAnimatedPlayerHitUsesAnimatedRotationAndPhaseRules(t *testing.T) {
	poses, err := loadSoldierHitPoses()
	if err != nil {
		t.Fatal(err)
	}
	clip := poses.Clips["jump"]
	pose, ok := sampleBakedClip(clip, clip.Length)
	if !ok {
		t.Fatal("could not sample clamped jump endpoint")
	}
	boneIndex := make(map[string]int, len(poses.Bones))
	for i, name := range poses.Bones {
		boneIndex[name] = i
	}
	from, to := toDVec(pose[boneIndex["mixamorig_Head"]]), toDVec(pose[boneIndex["mixamorig_HeadTop_End"]])
	axis := subD(to, from)
	from = addD(from, axis.at(0.25))
	to = addD(from, axis.at(0.5))
	point := addD(from, subD(to, from).at(0.8))
	direction, _, ok := normalizeD(crossD(subD(to, from), dvec{0, 0, 1}))
	if !ok {
		t.Fatal("could not form rotated jump head ray")
	}
	position := vector{11, 3, 6}
	rotation := [4]float32{0, 0.70710677, 0, 0.70710677}
	start := animatedTestToWorld(addD(point, direction.at(2)), position, rotation)
	end := animatedTestToWorld(subD(point, direction.at(2)), position, rotation)
	for _, phase := range []float64{-0.2, clip.Length, clip.Length + 0.2} {
		zone, _, hit := traceAnimatedPlayerHit(start, end, position, rotation, "jump", phase)
		if !hit || zone != "head" {
			t.Fatalf("non-looping jump endpoint phase %g returned zone=%q hit=%v", phase, zone, hit)
		}
	}
	if _, _, hit := traceAnimatedPlayerHit(start, end, position, rotation, "jump", math.NaN()); hit {
		t.Fatal("accepted non-finite animation phase")
	}
}

func BenchmarkTraceAnimatedPlayerHit(b *testing.B) {
	poses, err := loadSoldierHitPoses()
	if err != nil {
		b.Fatal(err)
	}
	pose, ok := sampleBakedClip(poses.Clips["run"], 0.35)
	if !ok {
		b.Fatal("could not sample running pose")
	}
	indexes := soldierHitBoneIndices
	from := toDVec(pose[indexes["mixamorig_Head"]])
	to := toDVec(pose[indexes["mixamorig_HeadTop_End"]])
	axis := subD(to, from)
	from = addD(from, axis.at(0.25))
	to = addD(from, axis.at(0.5))
	point := addD(from, subD(to, from).at(0.82))
	direction, _, ok := normalizeD(crossD(subD(to, from), dvec{0, 0, 1}))
	if !ok {
		b.Fatal("could not form head benchmark ray")
	}
	position := vector{7, 2, -4}
	rotation := [4]float32{0, 0.38268343, 0, 0.92387953}
	origin := animatedTestToWorld(addD(point, direction.at(2)), position, rotation)
	end := animatedTestToWorld(subD(point, direction.at(2)), position, rotation)
	if zone, _, hit := traceAnimatedPlayerHit(origin, end, position, rotation, "run", 0.35); !hit || zone != "head" {
		b.Fatalf("benchmark ray must hit the animated head: %q %t", zone, hit)
	}
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		traceAnimatedPlayerHit(origin, end, position, rotation, "run", 0.35)
	}
}

func midpoint(a, b [3]float32) dvec {
	return dvec{(float64(a[0]) + float64(b[0])) / 2, (float64(a[1]) + float64(b[1])) / 2, (float64(a[2]) + float64(b[2])) / 2}
}

func animatedTestToWorld(point dvec, position vector, rotation [4]float32) vector {
	world := rotateByQuaternion(point, float64(rotation[0]), float64(rotation[1]), float64(rotation[2]), float64(rotation[3]))
	return vector{position[0] + float32(world.x), position[1] + float32(world.y), position[2] + float32(world.z)}
}

func vectorFromD(point dvec) vector {
	return vector{float32(point.x), float32(point.y), float32(point.z)}
}

func formatPhase(phase float64) string {
	return strconv.FormatFloat(phase, 'f', 2, 64)
}
