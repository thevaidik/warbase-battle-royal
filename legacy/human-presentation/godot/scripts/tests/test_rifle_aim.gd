extends SceneTree

const AIM_SCRIPT := preload("res://scripts/net/RifleAimModifier.gd")
const CLIPS := ["Firing Rifle", "Firing walk Rifle"]
const PHASES := [0.1, 0.2]
const YAWS := [0.0, 1.0]
const PITCHES := [-0.3, 0.3]
const ALIGN_TOLERANCE := deg_to_rad(0.25)
const RESTORE_TOLERANCE := deg_to_rad(0.05)

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS: " if ok else "FAIL: ", message)

func _bone_world_position(skeleton: Skeleton3D, bone_idx: int) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx).origin

func _gun_forward(skeleton: Skeleton3D, gun: Node3D, right_hand_idx: int) -> Vector3:
	var hand_pose := skeleton.get_bone_global_pose(right_hand_idx)
	return (skeleton.global_basis * hand_pose.basis * gun.basis * Vector3(0.0, 0.0, -1.0)).normalized()

func _sample_pose(anim: AnimationPlayer, skeleton: Skeleton3D, clip: String, phase: float) -> void:
	var animation := anim.get_animation(clip)
	anim.speed_scale = 0.0
	anim.play(clip, 0.0)
	anim.seek(minf(phase, animation.length), true)
	skeleton.force_update_all_bone_transforms()
	await process_frame

func run() -> void:
	# Load the GLB directly so RemotePlayer.gd's self-preload cycle is not involved.
	var packed := load("res://assets/models/AnimatedSoldier.glb") as PackedScene
	if packed == null:
		check(false, "AnimatedSoldier.glb loads")
		quit(1)
		return
	var actor := Node3D.new()
	root.add_child(actor)
	var soldier := packed.instantiate() as Node3D
	actor.add_child(soldier)
	var skeleton := soldier.get_node("Armature/Skeleton3D") as Skeleton3D
	var anim := soldier.get_node("AnimationPlayer") as AnimationPlayer
	var right_hand_idx := skeleton.find_bone("mixamorig_RightHand")
	var left_foot_idx := skeleton.find_bone("mixamorig_LeftFoot")
	var right_foot_idx := skeleton.find_bone("mixamorig_RightFoot")
	check(skeleton != null and anim != null, "soldier skeleton and AnimationPlayer are available")
	check(right_hand_idx >= 0 and left_foot_idx >= 0 and right_foot_idx >= 0, "required hand and foot bones are available")
	if right_hand_idx < 0 or left_foot_idx < 0 or right_foot_idx < 0:
		quit(1)
		return

	var socket := BoneAttachment3D.new()
	socket.name = "RightHandSocket"
	socket.bone_name = "mixamorig_RightHand"
	skeleton.add_child(socket)
	var gun := Node3D.new()
	gun.name = "TestGun"
	gun.scale = Vector3.ONE * 72.0
	gun.position = Vector3(2.0, -4.0, 1.0)
	gun.rotation_degrees = Vector3(90.0, 106.0, 0.0)
	socket.add_child(gun)
	var modifier = AIM_SCRIPT.new()
	modifier.actor = actor
	modifier.gun = gun
	modifier.enabled_aim = false
	skeleton.add_child(modifier)
	await process_frame

	for clip in CLIPS:
		if not anim.has_animation(clip):
			check(false, "%s animation is available" % clip)
			continue
		for phase in PHASES:
			for yaw in YAWS:
				for aim_pitch in PITCHES:
					actor.rotation.y = yaw
					actor.position = Vector3(3.0, 0.0, -2.0)
					modifier.enabled_aim = false
					modifier.pitch = aim_pitch
					await _sample_pose(anim, skeleton, clip, phase)
					var left_before := _bone_world_position(skeleton, left_foot_idx)
					var right_before := _bone_world_position(skeleton, right_foot_idx)
					var root_position_before := actor.global_position
					var root_rotation_before := actor.global_basis
					var baseline_forward := _gun_forward(skeleton, gun, right_hand_idx)

					modifier.enabled_aim = true
					await process_frame
					var desired_local := Vector3(0.0, -sin(aim_pitch), -cos(aim_pitch))
					var desired_forward := (actor.global_basis * desired_local).normalized()
					var actual_forward := (-gun.global_basis.z).normalized()
					var error := actual_forward.angle_to(desired_forward)
					var label := "%s t=%.1f yaw=%.1f pitch=%.1f" % [clip, phase, yaw, aim_pitch]
					check(error <= ALIGN_TOLERANCE, "%s aligns gun (error %.3f deg)" % [label, rad_to_deg(error)])
					check(_bone_world_position(skeleton, left_foot_idx).distance_to(left_before) < 0.0001, "%s preserves left foot" % label)
					check(_bone_world_position(skeleton, right_foot_idx).distance_to(right_before) < 0.0001, "%s preserves right foot" % label)
					check(actor.global_position.is_equal_approx(root_position_before) and actor.global_basis.is_equal_approx(root_rotation_before), "%s preserves actor root" % label)

					modifier.enabled_aim = false
					await process_frame
					var restored_forward := _gun_forward(skeleton, gun, right_hand_idx)
					check(restored_forward.angle_to(baseline_forward) <= RESTORE_TOLERANCE, "%s disabling aim restores animated gun pose" % label)
					check(AIM_SCRIPT.correction_axis(Vector3.FORWARD, Vector3.FORWARD) == Vector3.ZERO, "%s parallel correction axis is zero" % label)

	modifier.enabled_aim = false
	actor.queue_free()
	print("RIFLE AIM MODIFIER TEST: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
