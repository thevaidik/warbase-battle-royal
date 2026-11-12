extends SceneTree
var first: WarNetwork
var second: WarNetwork
var states := [{}, {}]
var positions := [Vector3.ZERO, Vector3.ZERO]
var failures := 0
var sends := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, description: String) -> void:
	print("ONLINE ", "PASS " if value else "FAIL ", description)
	if not value: failures += 1
func _process(_delta: float) -> bool:
	if first and first.connected:
		sends += 1
		first.send_state(positions[0], Quaternion.IDENTITY, "idle", "ak47")
	if second and second.connected:
		second.send_state(positions[1], Quaternion.IDENTITY, "idle", "ak47")
	return false
func run() -> void:
	for i in 2:
		var net := WarNetwork.new()
		root.add_child(net)
		net.respawn_received.connect(func(pos: Vector3) -> void: positions[i] = pos)
		net.state_received.connect(func(state: Dictionary) -> void:
			var roster: Dictionary = states[i].get("players", {})
			roster.merge(state.get("players", {}), true)
			states[i] = state
			states[i]["players"] = roster
		)
		if i == 0: first = net
		else: second = net
		net.connect_to("sync_alpha" if i == 0 else "sync_bravo", "industrial-public", "localhost:18091")
	var deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		if states[0].get("players", {}).size() >= 2 and states[1].get("players", {}).size() >= 2: break
		await create_timer(0.05).timeout
	print("ONLINE debug sends=", sends, " roster0=", states[0].get("players", {}).keys(), " roster1=", states[1].get("players", {}).keys())
	check(states[0].get("players", {}).has("sync_bravo") and states[1].get("players", {}).has("sync_alpha"), "two clients share the same room roster")
	check(int(states[0].get("protocol_version", 0)) == 2, "matching protocol negotiated")
	first.send_grenade(positions[0] + Vector3(0, 1.0, 0), Vector3.ZERO)
	await create_timer(4.0).timeout
	var players_a: Dictionary = states[0].get("players", {})
	var players_b: Dictionary = states[1].get("players", {})
	var hp_a := int(players_a.get("sync_alpha", {}).get("health", 100))
	var hp_b := int(players_b.get("sync_alpha", {}).get("health", 100))
	print("ONLINE observed health=", hp_a, "/", hp_b, " positions=", positions)
	check(hp_a < 100 and hp_a == hp_b, "both clients observe server grenade damage")
	first.disconnect_from()
	second.disconnect_from()
	await create_timer(0.1).timeout
	print("ONLINE TEST: ", failures, " failures")
	quit(1 if failures else 0)
