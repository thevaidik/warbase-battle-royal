extends SceneTree
## Bounded synthetic clearance regression using the mounted drone payloads.
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	print("CHECK ", "PASS " if value else "FAIL ", description)
	if not value:
		failures += 1

func run() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var game_state = root.get_node("GameState")
	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	var player = player_scene.instantiate()
	world_root.add_child(player)
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var weapon_script: Script = load("res://scripts/weapons/WeaponSystem.gd")
	var system = weapon_script.new()
	world_root.add_child(system)
	system.setup(player, camera, null, world_root)
	system._switch_t = 1.0
	await physics_frame
	var drone_visual := player.get("_drone_visual") as Node
	var payload_muzzles_valid := is_instance_valid(drone_visual) and drone_visual.has_method("get_muzzle_global") and drone_visual.has_method("set_weapon")
	for weapon in game_state.WEAPONS:
		var weapon_id := String(weapon["id"])
		system.active_index = game_state.weapon_index_for_id(weapon_id)
		system._sync_drone_payload()
		await process_frame
		if is_instance_valid(drone_visual) and drone_visual.has_method("get_muzzle_global"):
			var muzzle: Vector3 = drone_visual.call("get_muzzle_global")
			var visual_weapon_id := String(drone_visual.get("weapon_id"))
			payload_muzzles_valid = payload_muzzles_valid and muzzle.is_finite() and muzzle.distance_to(player.global_position) <= game_state.DRONE_RADIUS and visual_weapon_id == weapon_id and system._muzzle_global().is_equal_approx(muzzle)
		else:
			payload_muzzles_valid = false
	check(payload_muzzles_valid, "all mounted payloads expose finite hull-contained muzzles and switch together")
	world_root.queue_free()
	await process_frame
	print("WEAPON CLEARANCE TEST: ", failures, " failures")
	quit(1 if failures > 0 else 0)
