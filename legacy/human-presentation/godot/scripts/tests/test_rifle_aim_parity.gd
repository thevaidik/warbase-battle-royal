extends SceneTree

const AimModifier := preload("res://scripts/net/RifleAimModifier.gd")
const BONES := [
	"mixamorig_Head", "mixamorig_HeadTop_End", "mixamorig_Neck", "mixamorig_Spine1",
	"mixamorig_Spine2", "mixamorig_Hips", "mixamorig_LeftArm", "mixamorig_LeftForeArm",
	"mixamorig_LeftHand", "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand",
	"mixamorig_LeftUpLeg", "mixamorig_LeftLeg", "mixamorig_LeftFoot", "mixamorig_LeftToeBase",
	"mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_RightFoot", "mixamorig_RightToeBase",
]
const CLIP_NAMES := {"firing": "Firing Rifle", "firing walk": "Firing walk Rifle"}
const POSITION_TOLERANCE := 0.005
const AIM_ANGLE_TOLERANCE := deg_to_rad(0.25)

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS: " if ok else "FAIL: ", message)

func _fixture_path() -> String:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--fixture" and index + 1 < args.size():
			return args[index + 1]
		if args[index].begins_with("--fixture="):
			return args[index].trim_prefix("--fixture=")
	return OS.get_environment("WARBASE_RIFLE_AIM_FIXTURE")

func _bone_local_position(actor: Node3D, skeleton: Skeleton3D, bone_idx: int) -> Vector3:
	var world_position := skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx).origin
	return actor.to_local(world_position)

func _disable_aim_modifiers(actor: Node3D) -> void:
	for node in actor.find_children("*", "SkeletonModifier3D", true, false):
		if node.get("enabled_aim") != null:
			node.set("enabled_aim", false)

func _native_points(actor: Node3D, skeleton: Skeleton3D, indices: Array[int]) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for bone_idx in indices:
		points.append(_bone_local_position(actor, skeleton, bone_idx))
	return points

func run() -> void:
	var fixture_path := _fixture_path()
	if fixture_path.is_empty():
		check(false, "pass --fixture /tmp/warbase-rifle-aim-fixtures.json")
		quit(1)
		return
	if not FileAccess.file_exists(fixture_path):
		check(false, "fixture exists: %s" % fixture_path)
		quit(1)
		return
	var fixture = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	if not fixture is Dictionary or not fixture.has("bones") or not fixture.has("cases"):
		check(false, "fixture has bones and cases")
		quit(1)
		return
	check(fixture.get("version", 0) == 1, "fixture schema version is 1")
	check(fixture.bones == BONES, "fixture bone order matches native rig order")
	check(fixture.cases.size() == 12, "fixture covers 12 animation, phase, and pitch combinations")
	if fixture.bones != BONES:
		quit(1)
		return

	# Load the real remote scene to include its Soldier rotation and equipped rifle socket.
	var packed := load("res://scenes/RemotePlayer.tscn") as PackedScene
	if packed == null:
		check(false, "RemotePlayer.tscn loads")
		quit(1)
		return
	var actor := packed.instantiate() as Node3D
	root.add_child(actor)
	await process_frame
	var skeleton := actor.get_node("Soldier/Armature/Skeleton3D") as Skeleton3D
	var anim := actor.get_node("Soldier/AnimationPlayer") as AnimationPlayer
	var gun := actor.get("_equipped_gun") as Node3D
	check(skeleton != null and anim != null and gun != null, "remote soldier, animation player, and equipped rifle are available")
	if skeleton == null or anim == null or gun == null:
		actor.queue_free()
		quit(1)
		return

	var indices: Array[int] = []
	for bone_name in BONES:
		var bone_idx := skeleton.find_bone(bone_name)
		if bone_idx < 0:
			check(false, "native rig contains %s" % bone_name)
			actor.queue_free()
			quit(1)
			return
		indices.append(bone_idx)
	var head_idx := skeleton.find_bone("mixamorig_Head")
	var spine_idx := skeleton.find_bone("mixamorig_Spine1")
	var right_hand_idx := skeleton.find_bone("mixamorig_RightHand")
	var left_foot_idx := skeleton.find_bone("mixamorig_LeftFoot")
	var right_foot_idx := skeleton.find_bone("mixamorig_RightFoot")

	for item in fixture.cases:
		var animation_key := String(item.get("animation", ""))
		var animation_name := String(CLIP_NAMES.get(animation_key, ""))
		var phase := float(item.get("phase", -1.0))
		var pitch := float(item.get("pitch", 999.0))
		var label := "%s t=%.1f pitch=%.1f" % [animation_key, phase, pitch]
		if animation_name.is_empty() or not anim.has_animation(animation_name):
			check(false, "%s maps to a native animation" % label)
			continue
		if item.get("points", []).size() != BONES.size():
			check(false, "%s fixture has all 20 bone points" % label)
			continue

		_disable_aim_modifiers(actor)
		anim.speed_scale = 0.0
		anim.play(animation_name, 0.0)
		anim.seek(phase, true)
		await process_frame
		skeleton.force_update_all_bone_transforms()
		var base_points := _native_points(actor, skeleton, indices)
		var base_left_foot := base_points[indices.find(left_foot_idx)]
		var base_right_foot := base_points[indices.find(right_foot_idx)]
		var base_upper_head := base_points[indices.find(head_idx)]

		var applied := AimModifier.apply_alignment(skeleton, gun, pitch, actor, spine_idx, right_hand_idx)
		check(applied, "%s applies native Spine1 correction" % label)
		skeleton.force_update_all_bone_transforms()
		var points := _native_points(actor, skeleton, indices)
		var max_error := 0.0
		var worst_bone := ""
		for point_index in BONES.size():
			var expected := Vector3(item.points[point_index][0], item.points[point_index][1], item.points[point_index][2])
			var error := points[point_index].distance_to(expected)
			if error > max_error:
				max_error = error
				worst_bone = BONES[point_index]
		check(max_error <= POSITION_TOLERANCE, "%s matches all hitbox points (max %.6fm at %s)" % [label, max_error, worst_bone])
		check(points[indices.find(left_foot_idx)].distance_to(base_left_foot) <= 0.0001, "%s preserves left foot" % label)
		check(points[indices.find(right_foot_idx)].distance_to(base_right_foot) <= 0.0001, "%s preserves right foot" % label)
		check(points[indices.find(head_idx)].distance_to(base_upper_head) > 0.0001, "%s modifies upper hit pose" % label)

		# BoneAttachment's rendered global transform refreshes in the modifier callback;
		# derive its current barrel axis from the final right-hand pose and local gun basis.
		var final_hand_pose := skeleton.get_bone_global_pose(right_hand_idx)
		var actual_forward := (skeleton.global_basis * final_hand_pose.basis * gun.basis * Vector3(0.0, 0.0, -1.0)).normalized()
		var desired_forward := (actor.global_basis * Vector3(0.0, -sin(pitch), -cos(pitch))).normalized()
		var aim_error := actual_forward.angle_to(desired_forward)
		check(aim_error <= AIM_ANGLE_TOLERANCE, "%s rifle direction error %.3f deg" % [label, rad_to_deg(aim_error)])

		# The next sample starts from AnimationPlayer's authored pose; do not carry
		# this transient correction into another fixture case.
		_disable_aim_modifiers(actor)
		anim.seek(phase, true)
		skeleton.force_update_all_bone_transforms()

	actor.queue_free()
	print("RIFLE AIM SERVER/NATIVE PARITY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
