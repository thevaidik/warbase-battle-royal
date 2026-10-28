extends Node
## Bone-following anatomical hit areas shared by local bots and remote players.

const CAPSULES := [
	{"from": "mixamorig_Head", "to": "mixamorig_HeadTop_End", "zone": "head", "mult": 2.5, "radius": 0.10, "trim": 0.25},
	{"from": "mixamorig_Neck", "to": "mixamorig_Head", "zone": "torso", "mult": 1.0, "radius": 0.08},
	{"from": "mixamorig_Spine1", "to": "mixamorig_Neck", "zone": "torso", "mult": 1.0, "radius": 0.18},
	{"from": "mixamorig_Hips", "to": "mixamorig_Spine1", "zone": "stomach", "mult": 0.84, "radius": 0.17},
	{"from": "mixamorig_LeftArm", "to": "mixamorig_LeftForeArm", "zone": "arm", "mult": 0.84, "radius": 0.085},
	{"from": "mixamorig_LeftForeArm", "to": "mixamorig_LeftHand", "zone": "arm", "mult": 0.84, "radius": 0.07},
	{"from": "mixamorig_RightArm", "to": "mixamorig_RightForeArm", "zone": "arm", "mult": 0.84, "radius": 0.085},
	{"from": "mixamorig_RightForeArm", "to": "mixamorig_RightHand", "zone": "arm", "mult": 0.84, "radius": 0.07},
	{"from": "mixamorig_LeftUpLeg", "to": "mixamorig_LeftLeg", "zone": "leg", "mult": 0.84, "radius": 0.10},
	{"from": "mixamorig_LeftLeg", "to": "mixamorig_LeftFoot", "zone": "leg", "mult": 0.84, "radius": 0.09},
	{"from": "mixamorig_LeftFoot", "to": "mixamorig_LeftToeBase", "zone": "leg", "mult": 0.84, "radius": 0.09},
	{"from": "mixamorig_RightUpLeg", "to": "mixamorig_RightLeg", "zone": "leg", "mult": 0.84, "radius": 0.10},
	{"from": "mixamorig_RightLeg", "to": "mixamorig_RightFoot", "zone": "leg", "mult": 0.84, "radius": 0.09},
	{"from": "mixamorig_RightFoot", "to": "mixamorig_RightToeBase", "zone": "leg", "mult": 0.84, "radius": 0.09},
]

var _actor: Node3D
var _skeleton: Skeleton3D
var _player_id := ""
var _bone_indices: Dictionary = {}
var _areas: Array[Area3D] = []
var _shapes: Array[CapsuleShape3D] = []

func setup(actor: Node3D, skeleton: Skeleton3D, player_id: String) -> Array[Area3D]:
	_actor = actor
	_skeleton = skeleton
	_player_id = player_id
	process_priority = 1000
	for descriptor in CAPSULES:
		for bone_name in [String(descriptor["from"]), String(descriptor["to"])]:
			var bone_index := _skeleton.find_bone(bone_name)
			assert(bone_index >= 0, "missing hitbox bone: " + bone_name)
			_bone_indices[bone_name] = bone_index
		var radius := float(descriptor["radius"])
		var capsule := CapsuleShape3D.new()
		capsule.radius = radius
		capsule.height = radius * 2.0
		var area := Area3D.new()
		area.name = "hitbox_%s_%s" % [descriptor["zone"], _areas.size()]
		area.set_meta("hitbox", true)
		area.set_meta("player_id", _player_id)
		area.set_meta("zone", descriptor["zone"])
		area.set_meta("mult", descriptor["mult"])
		area.set_meta("from_bone", descriptor["from"])
		area.set_meta("to_bone", descriptor["to"])
		area.set_meta("radius", radius)
		area.collision_layer = 4
		area.collision_mask = 0
		area.monitoring = false
		area.monitorable = true
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		collision.shape = capsule
		area.add_child(collision)
		_actor.add_child(area)
		_areas.append(area)
		_shapes.append(capsule)
	_actor.add_child(self)
	update_from_skeleton()
	return _areas

func _process(_delta: float) -> void:
	update_from_skeleton()

func update_from_skeleton() -> void:
	if not is_instance_valid(_actor) or not is_instance_valid(_skeleton):
		return
	for index in _areas.size():
		var area := _areas[index]
		if not is_instance_valid(area):
			continue
		var descriptor: Dictionary = CAPSULES[index]
		var from_pos := _actor.to_local(_skeleton.global_transform * _skeleton.get_bone_global_pose(_bone_indices[descriptor["from"]]).origin)
		var to_pos := _actor.to_local(_skeleton.global_transform * _skeleton.get_bone_global_pose(_bone_indices[descriptor["to"]]).origin)
		if float(descriptor.get("trim", 0.0)) > 0.0:
			var trim := float(descriptor["trim"])
			var segment := to_pos - from_pos
			from_pos += segment * trim
			to_pos -= segment * trim
		var segment := to_pos - from_pos
		var length := segment.length()
		var radius := float(descriptor["radius"])
		var shape := _shapes[index]
		shape.height = maxf(radius * 2.0, length + radius * 2.0)
		var direction := segment.normalized() if length > 0.0001 else Vector3.UP
		var rotation := Quaternion(Vector3.UP, direction)
		area.transform = Transform3D(Basis(rotation), (from_pos + to_pos) * 0.5)
