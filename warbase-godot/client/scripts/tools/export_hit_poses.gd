extends SceneTree
## Re-bake the shared animated hit proxy bone points from the shipped soldier rig.

const FPS := 30
const BONES := [
	"mixamorig_Head", "mixamorig_HeadTop_End", "mixamorig_Neck", "mixamorig_Spine1",
	"mixamorig_Spine2", "mixamorig_Hips", "mixamorig_LeftArm", "mixamorig_LeftForeArm",
	"mixamorig_LeftHand", "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand",
	"mixamorig_LeftUpLeg", "mixamorig_LeftLeg", "mixamorig_LeftFoot", "mixamorig_LeftToeBase",
	"mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_RightFoot", "mixamorig_RightToeBase",
]
const CLIPS := {
	"idle": {"animation": "Rifle Idle", "loop": true},
	"run": {"animation": "Rifle Run", "loop": true},
	"firing walk": {"animation": "Firing walk Rifle", "loop": true},
	"firing": {"animation": "Firing Rifle", "loop": false},
	"jump": {"animation": "Rifle Jump", "loop": false},
}

func _initialize() -> void:
	call_deferred("_bake")

func _bone_vector(actor: Node3D, skeleton: Skeleton3D, bone_index: int) -> Array:
	var world_point := skeleton.global_transform * skeleton.get_bone_global_pose(bone_index).origin
	var local_point := actor.to_local(world_point)
	return [snappedf(local_point.x, 0.00001), snappedf(local_point.y, 0.00001), snappedf(local_point.z, 0.00001)]

func _write_text(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write pose data: %s (%s)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(content)
	file.close()
	return true

func _bake() -> void:
	var packed := load("res://scenes/RemotePlayer.tscn") as PackedScene
	if packed == null:
		push_error("Could not load RemotePlayer scene")
		quit(1)
		return
	var actor := packed.instantiate() as Node3D
	root.add_child(actor)
	await process_frame
	var skeleton := actor.get_node("Soldier/Armature/Skeleton3D") as Skeleton3D
	var anim := actor.get_node("Soldier/AnimationPlayer") as AnimationPlayer
	var indices: Array[int] = []
	for bone_name in BONES:
		var index := skeleton.find_bone(bone_name)
		if index < 0:
			push_error("Pose bake is missing rig bone: %s" % bone_name)
			quit(1)
			return
		indices.append(index)
	var clips_out := {}
	for clip_name in CLIPS:
		var descriptor: Dictionary = CLIPS[clip_name]
		var animation_name := String(descriptor["animation"])
		if not anim.has_animation(animation_name):
			push_error("Pose bake is missing animation: %s" % animation_name)
			quit(1)
			return
		var animation := anim.get_animation(animation_name)
		var frame_count := int(ceil(animation.length * FPS)) + 1
		var frames: Array = []
		anim.speed_scale = 0.0
		anim.play(animation_name, 0.0)
		for frame_index in frame_count:
			var timestamp := minf(float(frame_index) / FPS, animation.length)
			anim.seek(timestamp, true)
			await process_frame
			skeleton.force_update_all_bone_transforms()
			var points: Array = []
			for bone_index in indices:
				points.append(_bone_vector(actor, skeleton, bone_index))
			frames.append(points)
		clips_out[clip_name] = {
			"length": animation.length,
			"loop": bool(descriptor["loop"]),
			"frames": frames,
		}
	var document := {"fps": FPS, "bones": BONES, "clips": clips_out}
	var serialized := JSON.stringify(document, "\t", false) + "\n"
	var client_path := "res://assets/data/soldier_hit_poses.json"
	var server_path := ProjectSettings.globalize_path("res://../server/internal/engine/soldier_hit_poses.json")
	if not _write_text(client_path, serialized) or not _write_text(server_path, serialized):
		quit(1)
		return
	print("BAKED SOLDIER POSES: %d bones, %d clips at %d Hz (%d bytes)" % [BONES.size(), clips_out.size(), FPS, serialized.to_utf8_buffer().size()])
	actor.free()
	quit(0)
