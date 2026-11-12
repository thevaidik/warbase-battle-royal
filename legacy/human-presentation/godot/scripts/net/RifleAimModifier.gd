class_name RifleAimModifier
extends SkeletonModifier3D
## Rotates the upper body toward the actor's aim without moving the root or legs.

const SPINE_BONE := "mixamorig_Spine1"
const RIGHT_HAND_BONE := "mixamorig_RightHand"

@export var actor: Node3D
@export var gun: Node3D
@export var pitch: float = 0.0
@export var enabled_aim: bool = false

var _spine_bone := -1
var _right_hand_bone := -1

func _ready() -> void:
	_cache_bones()

func _cache_bones() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	_spine_bone = skeleton.find_bone(SPINE_BONE)
	_right_hand_bone = skeleton.find_bone(RIGHT_HAND_BONE)

func _process_modification() -> void:
	if not enabled_aim or not is_instance_valid(actor) or not is_instance_valid(gun):
		return
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	if _spine_bone < 0 or _right_hand_bone < 0:
		_cache_bones()
	if _spine_bone < 0 or _right_hand_bone < 0:
		return
	apply_alignment(skeleton, gun, pitch, actor, _spine_bone, _right_hand_bone)

## Returns the normalized world-space correction axis from one direction to another.
## For parallel directions this is zero; for opposite directions it picks a stable axis.
static func correction_axis(current_forward: Vector3, desired_forward: Vector3) -> Vector3:
	var current := current_forward.normalized()
	var desired := desired_forward.normalized()
	var axis := current.cross(desired)
	if axis.length_squared() > 0.000001:
		return axis.normalized()
	if current.dot(desired) >= 0.0:
		return Vector3.ZERO
	var fallback := current.cross(Vector3.UP)
	if fallback.length_squared() <= 0.000001:
		fallback = current.cross(Vector3.RIGHT)
	return fallback.normalized()

## Applies one transient, world-space direction correction to Spine1.
## SkeletonModifier3D calls this after animation playback, so animation remains the
## source pose on the next frame and the legs/root are not changed.
static func apply_alignment(
	skeleton: Skeleton3D,
	gun: Node3D,
	angle_pitch: float,
	actor_node: Node3D,
	spine_idx: int = -1,
	right_hand_idx: int = -1
) -> bool:
	if skeleton == null or gun == null or actor_node == null:
		return false
	if spine_idx < 0:
		spine_idx = skeleton.find_bone(SPINE_BONE)
	if right_hand_idx < 0:
		right_hand_idx = skeleton.find_bone(RIGHT_HAND_BONE)
	if spine_idx < 0 or right_hand_idx < 0:
		return false

	var right_hand_pose := skeleton.get_bone_global_pose(right_hand_idx)
	var current_forward := (skeleton.global_basis * right_hand_pose.basis * gun.basis * Vector3(0.0, 0.0, -1.0)).normalized()
	angle_pitch = clampf(angle_pitch, -1.2, 1.2)
	var desired_local := Vector3(0.0, -sin(angle_pitch), -cos(angle_pitch))
	var desired_forward := (actor_node.global_basis * desired_local).normalized()
	if current_forward.length_squared() <= 0.000001 or desired_forward.length_squared() <= 0.000001:
		return false

	var correction := Quaternion(current_forward, desired_forward)
	var skeleton_basis := skeleton.global_basis.orthonormalized()
	var local_correction := skeleton_basis.inverse() * Basis(correction) * skeleton_basis
	var spine_pose := skeleton.get_bone_global_pose(spine_idx)
	spine_pose.basis = local_correction * spine_pose.basis
	skeleton.set_bone_global_pose(spine_idx, spine_pose)
	return true
