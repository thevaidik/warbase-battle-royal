extends Node
## Verifies replicated animation sampling never throttles root poses or hit timestamps.

var failures := 0

func check(ok: bool, label: String) -> void:
	print("CHECK ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func _ready() -> void:
	call_deferred("run")

func _make_pose(x: float, phase: float, timestamp: int) -> Dictionary:
	return {"x": x, "y": 0.0, "z": 0.0, "rx": 0.0, "ry": 0.0, "rz": 0.0, "rw": 1.0,
		"anim": "run", "animation_time": phase, "pose_time_ms": timestamp}

func run() -> void:
	var camera := Camera3D.new()
	get_tree().root.add_child(camera)
	camera.current = true

	var remote := load("res://scenes/RemotePlayer.tscn").instantiate() as WarRemote
	remote.use_server_authoritative_remote_pose()
	get_tree().root.add_child(remote)
	remote.global_position = Vector3(60.0, 0.0, 0.0)
	remote.apply_sdk_pose(_make_pose(60.0, 0.2, 1000))
	var player: AnimationPlayer = remote.get_node("Soldier/AnimationPlayer")
	var first_sample := player.current_animation_position
	check(player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL,
		"far authoritative animation uses manual callback mode")
	for _frame in range(4):
		await get_tree().process_frame
	check(is_equal_approx(player.current_animation_position, first_sample),
		"far animation phase stays frozen across actual process frames")
	remote.apply_sdk_pose(_make_pose(61.0, 0.8, 1100))
	check(is_equal_approx(remote.global_position.x, 61.0), "far remote root position remains per-frame")
	check(remote.get_hit_view_time_ms() == 1100, "far remote authoritative hit time remains per-frame")
	check(is_equal_approx(player.current_animation_position, first_sample), "far cosmetic animation waits between samples")
	remote._server_anim_next_sample_usec = Time.get_ticks_usec() - 1
	remote.apply_sdk_pose(_make_pose(62.0, 1.1, 1200))
	check(is_equal_approx(player.current_animation_position, fposmod(1.1, player.get_animation("Rifle Run").length)),
		"far animation catches up to latest authoritative phase")
	check(is_equal_approx(remote.global_position.x, 62.0) and remote.get_hit_view_time_ms() == 1200,
		"far animation sampling leaves root and hit time current")

	remote.global_position = Vector3(45.0, 0.0, 0.0)
	remote.apply_sdk_pose(_make_pose(45.0, 0.3, 1300))
	remote.apply_sdk_pose(_make_pose(45.0, 0.6, 1400))
	check(player.callback_mode_process == remote._server_anim_original_callback_mode,
		"45m near boundary restores the original callback mode")
	for _frame in range(4):
		await get_tree().process_frame
	check(player.current_animation_position > 0.3,
		"near animation resumes actual automatic phase advancement")

	var offline := load("res://scenes/RemotePlayer.tscn").instantiate() as WarRemote
	get_tree().root.add_child(offline)
	offline._sync_anim("run", false, 0.25)
	var offline_player: AnimationPlayer = offline.get_node("Soldier/AnimationPlayer")
	offline._sync_anim("run", false, 0.75)
	check(is_instance_valid(offline.get("_hitbox_helper")), "offline animated hitboxes remain enabled")
	check(is_equal_approx(offline_player.current_animation_position,
		fposmod(0.75, offline_player.get_animation("Rifle Run").length)), "offline animation retains full phase sampling")

	if failures == 0:
		print("REMOTE_ANIMATION_BUDGET_TESTS_OK")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
