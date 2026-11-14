extends Node

const MultiplayerScript = preload("res://scripts/net/MultiplayerManager.gd")
const RemoteScript = preload("res://scripts/net/RemotePlayer.gd")

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var world := Node3D.new()
	add_child(world)

	var multiplayer = MultiplayerScript.new()
	add_child(multiplayer)
	multiplayer.set_process(false)
	multiplayer.world = world
	multiplayer.local_name = "local_player"

	# Test 1: 63 simultaneous remotes arrive in state
	var players_data := {}
	for i in range(63):
		players_data["bot_%02d" % i] = {
			"team": "B",
			"weapon": "ak47",
			"x": float(i),
			"y": 1.0,
			"z": -float(i)
		}
	var state := {"players": players_data, "removed_players": []}
	multiplayer._on_state(state)

	# All 63 must exist as actor nodes with valid hitboxes immediately
	_check(multiplayer.remotes.size() == 63, "all 63 remotes created immediately in remotes dictionary")
	var hitboxes_ok := true
	var fallbacks_ok := true
	for pid in players_data.keys():
		var r: WarRemote = multiplayer.remotes.get(pid)
		if r == null or not is_instance_valid(r):
			hitboxes_ok = false
			break
		if r._hitbox_areas.is_empty() or not r._hitbox_areas[0].monitorable:
			hitboxes_ok = false
		if not r._is_fallback_visual or r._fallback_hull == null:
			fallbacks_ok = false

	_check(hitboxes_ok, "all 63 remotes expose immediate server-authoritative hitboxes")
	_check(fallbacks_ok, "all 63 remotes attach lightweight fallback hull")

	# R1 Regression Test: Await frames without processing queue; assert zero full bodies auto-construct
	for f in range(3):
		await get_tree().process_frame
	var premature_bodies := 0
	for pid in players_data.keys():
		var r: WarRemote = multiplayer.remotes.get(pid)
		if is_instance_valid(r.drone) and r.drone.is_built():
			premature_bodies += 1
	_check(premature_bodies == 0, "deferred actors do not auto-construct bodies when queue is paused (%d built)" % premature_bodies)

	var diags := multiplayer.get_remote_queue_diagnostics()
	_check(int(diags.pending_jobs) == 63, "63 jobs pending in visual build queue")

	# Test 2: Process frames progressively drain the queue
	for frame in range(120):
		multiplayer._process(1.0 / 60.0)
		await get_tree().process_frame
		if multiplayer._pending_build_jobs.is_empty():
			break

	var diags_after := multiplayer.get_remote_queue_diagnostics()
	_check(int(diags_after.pending_jobs) == 0, "all 63 remotes eventually upgraded to full visual")
	_check(int(diags_after.completed_jobs) == 63, "all 63 jobs completed")

	# Verify full visuals upgraded
	var all_upgraded := true
	for pid in players_data.keys():
		var r: WarRemote = multiplayer.remotes.get(pid)
		if r._is_fallback_visual or r._fallback_hull != null or not r.drone.visible:
			all_upgraded = false
			break
	_check(all_upgraded, "all remotes converted from fallback hull to full drone visual")

	# Test 3: Player leaving before construction cancels job cleanly
	multiplayer.clear()
	_check(multiplayer.remotes.is_empty(), "remotes cleared after clear()")
	_check(multiplayer._pending_build_jobs.is_empty(), "pending build jobs cleared after clear()")

	var churn_players := {
		"churn_0": {"team": "B", "weapon": "ak47", "x": 0.0, "y": 0.0, "z": 0.0},
		"churn_1": {"team": "B", "weapon": "m4", "x": 1.0, "y": 0.0, "z": 0.0}
	}
	multiplayer._on_state({"players": churn_players, "removed_players": []})
	_check(multiplayer.remotes.size() == 2, "churn remotes created")

	# Now churn_0 leaves before process finishes
	multiplayer._on_state({"players": {"churn_1": churn_players["churn_1"]}, "removed_players": ["churn_0"]})
	_check(not multiplayer.remotes.has("churn_0"), "departed churn_0 removed from remotes")
	_check(not multiplayer._pending_build_jobs.has("churn_0"), "departed churn_0 removed from pending build jobs")

	for frame in range(5):
		multiplayer._process(1.0 / 60.0)
		await get_tree().process_frame
		if not multiplayer.remotes.get("churn_1")._is_fallback_visual:
			break
	_check(multiplayer.remotes.has("churn_1") and not multiplayer.remotes.get("churn_1")._is_fallback_visual, "remaining churn_1 upgraded successfully")

	# Test 4: Dual payload and active secondary weapon preservation (R3)
	var dual_payload_player := {
		"dual_test": {
			"team": "B",
			"primary_payload": "m4",
			"secondary_payload": "pistol",
			"weapon": "pistol",
			"mobility_mode": "wheels",
			"x": 5.0, "y": 1.0, "z": 5.0
		}
	}
	multiplayer._on_state({"players": dual_payload_player, "removed_players": []})
	_check(multiplayer.remotes.has("dual_test"), "dual_test remote created")
	var dual_remote: WarRemote = multiplayer.remotes.get("dual_test")
	_check(dual_remote.primary_payload == "m4" and dual_remote.secondary_payload == "pistol" and dual_remote.weapon_id == "pistol",
		"pre-upgrade payloads stored accurately on remote actor")

	# Drain queue until dual_test is upgraded
	for frame in range(10):
		multiplayer._process(1.0 / 60.0)
		await get_tree().process_frame
		if not dual_remote._is_fallback_visual:
			break

	_check(not dual_remote._is_fallback_visual, "dual_test upgraded from fallback")
	_check(dual_remote.drone.get_primary_weapon() == "m4", "primary payload m4 preserved after upgrade")
	_check(dual_remote.drone.get_secondary_weapon() == "pistol", "secondary payload pistol preserved after upgrade")
	_check(dual_remote.drone.get_active_weapon() == "pistol", "active weapon pistol preserved after upgrade")
	_check(is_instance_valid(dual_remote.drone._left_mount), "primary left mount built")
	_check(is_instance_valid(dual_remote.drone._right_mount), "secondary right mount built")

	# Test 5: Cold-variant tracked drone staged upgrade timing (F1)
	const DroneVisualResourcesScript := preload("res://scripts/drones/DroneVisualResources.gd")
	DroneVisualResourcesScript.clear_cache()
	multiplayer.clear()
	var cold_player := {
		"cold_tracked": {
			"team": "B",
			"primary_payload": "m4",
			"secondary_payload": "pistol",
			"weapon": "pistol",
			"mobility_mode": "tracked",
			"x": 0.0, "y": 0.0, "z": 0.0
		}
	}
	multiplayer._on_state({"players": cold_player, "removed_players": []})
	_check(multiplayer.remotes.has("cold_tracked"), "cold_tracked remote created")
	var cold_remote: WarRemote = multiplayer.remotes.get("cold_tracked")

	# Wait two frames with queue paused to confirm no premature auto-build
	for f in range(2):
		await get_tree().process_frame
	_check(not is_instance_valid(cold_remote.drone) or not cold_remote.drone.is_built(), "cold remote unbuilt while queue paused")

	# Drain through stages across frames
	var cold_frames := 0
	while cold_frames < 20 and cold_remote._is_fallback_visual:
		multiplayer._process(1.0 / 60.0)
		await get_tree().process_frame
		cold_frames += 1

	_check(not cold_remote._is_fallback_visual, "cold tracked remote upgraded from fallback across stages")
	_check(cold_remote.drone.get_secondary_weapon() == "pistol", "cold tracked remote secondary is pistol")
	var cold_diags := multiplayer.get_remote_queue_diagnostics()
	_check(int(cold_diags.completed_stages) > 0, "cold stages recorded in queue diagnostics")
	_check(int(cold_diags.max_stage_us) > 0, "max_stage_us recorded for cold stage")

	# Test 6: Warm mixed-chassis timing contract (all warm stages must complete under budget)
	DroneVisualResourcesScript.prewarm(world)
	multiplayer.clear()
	var mixed_players := {}
	var chassis_list := ["heli", "wheels", "tracked", "wing"]
	for idx in range(16):
		var ch: String = chassis_list[idx % chassis_list.size()]
		mixed_players["mixed_%d" % idx] = {
			"team": "A" if idx % 2 == 0 else "B",
			"primary_payload": "ak47" if idx % 2 == 0 else "m4",
			"secondary_payload": "pistol" if idx % 3 == 0 else "",
			"weapon": "ak47",
			"mobility_mode": ch,
			"x": float(idx), "y": 0.0, "z": float(idx)
		}
	multiplayer._on_state({"players": mixed_players, "removed_players": []})
	_check(multiplayer.remotes.size() == 16, "16 mixed-chassis remotes created")

	# Drain warm queue and assert stage time contract
	for frame in range(60):
		multiplayer._process(1.0 / 60.0)
		await get_tree().process_frame
		var cur_diags := multiplayer.get_remote_queue_diagnostics()
		if cur_diags.pending_jobs == 0:
			break

	var final_diags := multiplayer.get_remote_queue_diagnostics()
	_check(int(final_diags.pending_jobs) == 0, "all 16 mixed-chassis remotes drained")
	_check(int(final_diags.completed_jobs) >= 16, "all 16 jobs completed")
	_check(int(final_diags.completed_stages) >= 48, "all stages completed across mixed chassis")

	multiplayer.queue_free()
	world.queue_free()

	if failures.is_empty():
		print("REMOTE_BUILD_QUEUE_TEST_OK")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
