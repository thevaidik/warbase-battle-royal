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
	main._reconcile_after_sequence = 0
	var me := {"x":baseline.x,"y":baseline.y,"z":baseline.z,"health":100,"ammo":30,"weapon":"ak47","team":"A"}
	var snapshot := {"protocol_version":4,"map_name":"industrial","players":{state.username:me},"vehicles":{},"time_of_day":"noon"}
	for seq in range(1,4):
		main.net._sent_positions[seq] = baseline
		me["ack_input_sequence"] = seq
		main._on_state(snapshot)
	check(main.player.global_position.is_equal_approx(current),"latency does not correct five metres of valid later movement")
	main.net.input_sequence = 6
	for seq in range(4,7):
		main.net._sent_positions[seq] = current
		me["ack_input_sequence"] = seq
		main._on_state(snapshot)
	check(main.player.global_position.is_equal_approx(baseline),"repeated rejected inputs still enforce the authoritative position")
	main.net._sent_positions[7] = current
	main._on_net_respawn(baseline+Vector3.UP*.2)
	check(main.net._sent_positions.is_empty(),"respawn cannot reconcile against pre-death positions")
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
	var player_bytes := WarProto._f32f(1,12)+WarProto._tag(23,0)+WarProto._varint(42)
	var entry := WarProto._strf(1,"QA_RECOVERY")+WarProto._len(2,player_bytes)
	var game := WarProto._len(1,entry)
	var respawn := WarProto._len(1,WarProto._f32f(1,5))
	var pong := WarProto._len(6,WarProto._tag(1,0)+WarProto._varint(12))
	var batch := WarProto._len(1,game)+WarProto._len(3,respawn)+WarProto._len(3,pong)+WarProto._tag(4,0)+WarProto._varint(17)
	var decoded := WarProto.decode_frame(batch)
	check(decoded.sequence==17 and decoded.messages.size()==3,"all events survive a batched delivery frame")
	var compressed := WarProto._len(5,batch.compress(FileAccess.COMPRESSION_GZIP))+WarProto._tag(4,0)+WarProto._varint(17)
	var expanded := WarProto.decode_frame(compressed)
	check(expanded.sequence==17 and expanded.messages.size()==3,"native gzip delivery retains the snapshot and every event")
	check(decoded.messages[0].kind=="respawn" and decoded.messages[1].kind=="pong" and decoded.messages[2].kind=="game_state","events precede the newest world state")
	check(decoded.messages[2].players.QA_RECOVERY.ack_input_sequence==42,"input acknowledgement survives binary decoding")
	main.net._username = state.username
	main.net._inflight_inputs.assign([1,2,3,4,5,6,7,8])
	var flow := snapshot.duplicate(true)
	flow.kind = "game_state"
	flow.players[state.username].ack_input_sequence = 5
	main.net._dispatch_message(flow)
	check(main.net._inflight_inputs==[6,7,8],"state acknowledgements release only consumed movement and driving inputs")
	var remote_script = load("res://scripts/net/RemotePlayer.gd")
	var first_weapon: Node3D = remote_script._shared_weapon("ak47")
	var second_weapon: Node3D = remote_script._shared_weapon("ak47")
	var meshes_a := first_weapon.find_children("*","MeshInstance3D",true,false)
	var meshes_b := second_weapon.find_children("*","MeshInstance3D",true,false)
	check(first_weapon!=second_weapon and not meshes_a.is_empty() and meshes_a[0].mesh==meshes_b[0].mesh,"remote weapons share immutable mesh resources with independent nodes")
	first_weapon.free()
	second_weapon.free()
	var stream := StreamPeerGZIP.new()
	check(stream.start_decompression(false,262145)==OK,"stream decoder starts with bounded memory")
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/stream-fixture.json"))
	for fixture in fixtures:
		var streamed := WarProto.decode_frame(Marshalls.base64_to_raw(fixture.frame),stream)
		check(not streamed.get("error",false) and streamed.sequence==int(fixture.sequence) and is_equal_approx(float(streamed.messages.back().players.p00.x),float(fixture.x)),"Go gzip stream fragment %d decodes in Godot"%int(fixture.sequence))
	var oversized := WarProto._len(5,PackedByteArray([1]))+WarProto._tag(6,0)+WarProto._varint(1)+WarProto._tag(7,0)+WarProto._varint(262145)
	check(WarProto.decode_frame(oversized,stream).get("error",false),"oversized stream frames are rejected before decompression")
	stream = StreamPeerGZIP.new()
	stream.start_decompression(false,262145)
	check(WarProto.decode_frame(Marshalls.base64_to_raw(fixtures[0].frame),stream).sequence==1,"reconnecting resets compression history")
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
	var removal_wire := WarProto.decode_server(WarProto._len(1,WarProto._strf(11,"gone")))
	check(removal_wire.removed_players==["gone"],"explicit player departures survive binary decoding")
	var expired := MeshInstance3D.new()
	var weak: WeakRef = weakref(expired)
	expired.free()
	main.weapons._decals.clear()
	for index in main.weapons.MAX_DECALS: main.weapons._decals.append(weak)
	main.weapons._spawn_impact(Vector3(-20,1,-10),Vector3.UP)
	check(main.weapons._decals.size()==1 and main.weapons._decals[0].get_ref()!=null,"expired blood stains cannot break later bullet impacts")
	main._on_conn(false)
	check(not state.online_ready and main.hud._connection_status.visible,"connection interruption has a persistent synchronization banner")
	main._return_after_connection_error("Test room expired")
	check(main.phase==main.Phase.MENU and main.menu.visible,"terminal connection error returns to the room picker")
	print("NETWORK RECOVERY TEST: %d failures"%failures)
	quit(failures)
