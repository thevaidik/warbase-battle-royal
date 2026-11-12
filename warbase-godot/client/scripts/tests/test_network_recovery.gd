extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ",label)
func run() -> void:
	var qa_probe = load("res://scripts/qa/OfficialProbe.gd")
	check(qa_probe.can_instantiate(),"native and Web release QA probe compiles")
	var audio = root.get_node("Audio")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")) and audio.get_child_count()==0,"audio disabled without synthesizing or allocating sound players")
	var state = root.get_node("GameState")
	state.practice_mode = true
	state.selected_map = "industrial"
	state.username = "QA_RECOVERY"
	change_scene_to_file("res://scenes/Main.tscn")
	while current_scene == null: await process_frame
	var main = current_scene
	main._on_deploy()
	await physics_frame
	await physics_frame
	state.practice_mode = false
	var baseline := Vector3(-20,1,-10)
	var current := baseline + Vector3(0,0,-5)
	main.player.global_position = current
	var me := {"x":baseline.x,"y":baseline.y,"z":baseline.z,"health":100,"ammo":30,"weapon":"ak47","team":"A"}
	var snapshot := {"protocol_version":state.GAME_PROTOCOL_VERSION,"map_name":"industrial","players":{state.username:me},"vehicles":{},"time_of_day":"noon"}
	main.player.is_dead = true
	main.player.health = 0
	main.phase = main.Phase.DEAD
	main.player.set_meta("respawn_requested", true)
	me["is_dead"] = true
	me["health"] = 0
	main._on_state(snapshot)
	check(main.player.is_dead,"authoritative death cannot be bypassed by a pending respawn")
	me["is_dead"] = false
	me["health"] = 100
	main._on_state(snapshot)
	check(not main.player.is_dead and main.phase == main.Phase.PLAYING and main.player.health == 100,"authoritative living snapshot recovers a latched respawn screen")
	check(not main.player.get_meta("respawn_requested",true),"respawn recovery clears the outstanding request")
	var remote_script = load("res://scripts/net/RemotePlayer.gd")
	var first_remote: Node = remote_script.create("payload_a", {"team":"B", "weapon":"ak47", "x":-20.0, "y":1.0, "z":-10.0})
	var second_remote: Node = remote_script.create("payload_b", {"team":"B", "weapon":"ak47", "x":-18.0, "y":1.0, "z":-10.0})
	main.world.add_child(first_remote)
	main.world.add_child(second_remote)
	await process_frame
	first_remote.push_state({"team":"B", "weapon":"m4", "x":-20.0, "y":1.0, "z":-10.0})
	var first_visual: Node = first_remote.get("drone")
	var second_visual: Node = second_remote.get("drone")
	check(first_visual.get("weapon_id") == "m4" and second_visual.get("weapon_id") == "ak47" and first_visual.call("get_payload") != second_visual.call("get_payload"),
		"remote payload changes update one drone without mutating another actor")
	first_remote.free()
	second_remote.free()
	main.mp.set_process(false)
	main.mp.clear()
	var peers := {}
	for i in 20: peers["peer_%d"%i]={"x":float(i*2),"y":1.0,"z":-10.0,"health":100,"weapon":"ak47"}
	main.mp._on_state({"players":peers})
	check(main.mp.remotes.is_empty() and main.mp._pending_remotes.size()==20,"join bursts queue actor creation")
	main.mp._process(1.0/60)
	check(main.mp.remotes.size()==1,"one frame builds at most one remote actor")
	var removed_id: String = main.mp.remotes.keys()[0]
	main.mp._on_state({"players":{},"removed_players":[removed_id,"peer_19"]})
	check(not main.mp.remotes.has(removed_id) and not main.mp._pending_remotes.has("peer_19") and not state.players.has(removed_id),"departed actors and queued bots disappear without a three-second ghost")
	var expired := MeshInstance3D.new()
	var weak: WeakRef = weakref(expired)
	expired.free()
	main.weapons._decals.clear()
	for index in main.weapons.MAX_DECALS: main.weapons._decals.append(weak)
	main.weapons._spawn_impact(Vector3(-20,1,-10),Vector3.UP)
	check(main.weapons._decals.size()==1 and main.weapons._decals[0].get_ref()!=null,"expired impact decals cannot break later metallic hit effects")
	main._on_conn(false)
	check(not state.online_ready and main.hud._connection_status.visible,"connection interruption has a persistent synchronization banner")
	main._return_after_connection_error("Test room expired")
	check(main.phase==main.Phase.MENU and main.menu.visible,"terminal connection error returns to the room picker")
	print("NETWORK RECOVERY TEST: %d failures"%failures)
	quit(failures)
