extends SceneTree

func _initialize() -> void:
	var builder_script = load("res://scripts/drones/DronePayloadBuilder.gd")
	if builder_script == null:
		quit(1)
		return
	for weapon_id in ["ak47","pistol","m2010","hmg","m4","mp5","dmr"]:
		var payload = builder_script.build(weapon_id)
		assert(payload.get_meta("weapon_id") == weapon_id)
		assert(payload.find_child("Muzzle",true,false) is Node3D)
		payload.free()
	print("DRONE_PAYLOAD_BUILDER_OK")
	quit()
