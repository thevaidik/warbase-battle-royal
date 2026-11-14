extends Node

const TimingScript := preload("res://scripts/qa/RemotePoseTiming.gd")
const NetScript := preload("res://scripts/net/ColyseusNetwork.gd")
const MultiplayerScript := preload("res://scripts/net/MultiplayerManager.gd")

class ProbeRemote extends WarRemote:
	var applied := 0
	func apply_sdk_pose(_state: Dictionary, _delta: float = 0.016) -> void:
		applied += 1

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_histogram()
	_test_pose_ownership_and_per_frame_instrumentation()
	_test_cache_lifecycle_and_single_frame_dedup()
	if failures.is_empty():
		print("REMOTE_POSE_TIMING_TESTS_OK")
		get_tree().quit(0)
	else:
		for failure in failures: push_error(failure)
		get_tree().quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _test_histogram() -> void:
	var timing = TimingScript.new()
	timing.record(40, 2)
	timing.record(100, 3)
	timing.record(200, 1)
	var summary: Dictionary = timing.summary()
	_check(int(summary.samples) == 3, "timing sample count")
	_check(is_equal_approx(float(summary.mean_us), 340.0 / 3.0), "timing arithmetic mean")
	_check(int(summary.max_us) == 200, "timing maximum")
	_check(int(summary.p50_us_upper_bound) == 100, "timing p50 bucket")
	_check(int(summary.p95_us_upper_bound) == 250, "timing p95 bucket")
	_check(int(summary.max_items) == 3, "timing maximum remote count")

func _test_pose_ownership_and_per_frame_instrumentation() -> void:
	var net = NetScript.new()
	net._username = "local"
	net._last_normalized_state = {"players": {
		"local": {"x": 0.0, "y": 1.0, "z": 0.0},
		"peer": {"x": 4.0, "y": 1.0, "z": -3.0, "yaw": 0.5, "anim": "run", "inventory_blob": "not render data", "animation_time": 1.25, "pose_time_ms": 1000},
	}}
	net.set_qa_timing(true)
	var poses: Dictionary = net.get_sdk_remote_poses()
	_check(poses.size() == 1 and poses.has("peer"), "remote pose set excludes the local player")
	_check(is_equal_approx(float(poses.get("peer", {}).get("x", -1.0)), 4.0), "remote pose position")
	_check(not poses["peer"].has("inventory_blob"), "per-frame render poses exclude inventory payloads")
	_check(poses["peer"].get("anim") == "run", "render poses preserve animation state")
	poses["peer"]["x"] = 99.0
	_check(is_equal_approx(float(net._last_normalized_state.players.peer.x), 4.0), "pose output does not mutate the retained snapshot")
	var prep: Dictionary = net.get_remote_pose_preparation_diagnostics()
	_check(int(prep.samples) == 1 and int(prep.max_items) == 1, "per-frame preparation diagnostics")

	var world := Node3D.new()
	var multiplayer = MultiplayerScript.new()
	multiplayer.setup(net, world, "local", true)
	var remote = ProbeRemote.new()
	remote.player_id = "peer"
	remote.use_server_authoritative_remote_pose()
	multiplayer.remotes["peer"] = remote
	multiplayer._process(1.0 / 60.0)
	var application: Dictionary = multiplayer.get_remote_pose_application_diagnostics()
	_check(int(application.samples) == 1 and int(application.max_items) == 1, "per-frame application diagnostics")
	_check(remote.applied == 1, "remote application loop ran once")
	_check(is_equal_approx(float(net._last_normalized_state.players.peer.x), 4.0), "remote application preserves the retained snapshot")
	multiplayer.free()
	remote.free()
	world.free()
	net.free()

func _test_cache_lifecycle_and_single_frame_dedup() -> void:
	var net = NetScript.new()
	net._username = "local"
	net._last_normalized_state = {"players": {
		"local": {"x": 0.0, "y": 1.0, "z": 0.0},
		"peer": {"x": 5.0, "y": 2.0, "z": -1.0, "yaw": 0.0, "anim": "run"},
		"peer2": {"x": 10.0, "y": 0.0, "z": 2.0, "yaw": 1.57, "anim": "idle"}
	}}
	net.set_qa_timing(true)

	# 1. First call in frame 10
	var poses1 = net.prepare_remote_poses_for_frame(10)
	var prep1: Dictionary = net.get_remote_pose_preparation_diagnostics()
	_check(int(prep1.samples) == 1, "first call in frame 10 prepares poses")
	_check(poses1.size() == 2, "initial remote pose count")

	# 2. Second call in same frame 10 (dedup)
	var poses2 = net.prepare_remote_poses_for_frame(10)
	var prep2: Dictionary = net.get_remote_pose_preparation_diagnostics()
	_check(int(prep2.samples) == 1, "two getters in one frame perform only one preparation")
	_check(poses1 == poses2, "cached dictionary instance returned")

	# 3. get_sdk_remote_pose(username) reads cached entry without triggering new preparation
	var single = net.get_sdk_remote_pose("peer", 10)
	var prep3: Dictionary = net.get_remote_pose_preparation_diagnostics()
	_check(int(prep3.samples) == 1, "get_sdk_remote_pose in same frame does not trigger preparation")
	_check(is_equal_approx(float(single.get("x", 0.0)), 5.0), "get_sdk_remote_pose returns correct coordinates")

	# 4. Next frame 11 triggers preparation
	var poses_f11 = net.prepare_remote_poses_for_frame(11)
	var prep4: Dictionary = net.get_remote_pose_preparation_diagnostics()
	_check(int(prep4.samples) == 2, "advancing frame triggers preparation")

	# 5. Remote departure removes from cache
	net._last_normalized_state = {"players": {
		"local": {"x": 0.0, "y": 1.0, "z": 0.0},
		"peer": {"x": 6.0, "y": 2.0, "z": -1.0, "yaw": 0.0, "anim": "run"}
	}}
	var poses_f12 = net.prepare_remote_poses_for_frame(12)
	_check(not poses_f12.has("peer2"), "departed remote peer2 removed from cache")
	_check(poses_f12.has("peer"), "remaining remote peer retained in cache")

	# 6. Reconnect invalidates cache
	net.disconnect_from()
	_check(net._remote_pose_cache.is_empty(), "cache cleared on disconnect")
	net.free()
