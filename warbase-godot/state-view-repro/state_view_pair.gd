extends Node
## A single process owns both peers, avoiding premature peer exit in the old probe.
const Types = preload("res://state_view_schema.gd")
var clients: Array = []
var rooms: Array = []
var filtered := true
var endpoint := "ws://127.0.0.1:8097"
var room_id := ""
var failed := false
var phase := "initial"

func _ready() -> void:
	endpoint = OS.get_environment("STATE_VIEW_ENDPOINT") if not OS.get_environment("STATE_VIEW_ENDPOINT").is_empty() else endpoint
	room_id = OS.get_environment("STATE_VIEW_ROOM_ID")
	filtered = OS.get_environment("STATE_VIEW_FILTERED") != "false"
	if OS.has_feature("web"):
		room_id = String(JavaScriptBridge.eval("new URLSearchParams(location.search).get('room') || ''"))
		filtered = String(JavaScriptBridge.eval("new URLSearchParams(location.search).get('filtered') || ''")) != "false"
	call_deferred("run")

func plain(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = plain(value[key])
		return result
	if value is Array:
		return value.map(plain)
	if value is Object and value.has_method("to_dictionary"):
		return plain(value.to_dictionary())
	return value

func state(index: int) -> Dictionary:
	var raw = rooms[index].get_state()
	return {} if raw == null else plain(raw)

func join_peer(index: int) -> void:
	var client = Colyseus.Client.new(endpoint)
	var room = client.join_by_id(room_id, {"name": "alice" if index == 0 else "bob"})
	room.set_state_type(Types.RoomState)
	room.joined.connect(func(): room.set_reconnection_options({"min_uptime_ms": 0}))
	room.error.connect(func(code, message): fail("join %d %s" % [code, message]))
	if index >= rooms.size():
		clients.append(client)
		rooms.append(room)
	else:
		clients[index] = client
		rooms[index] = room

func wait_for(check: Callable) -> bool:
	var deadline = Time.get_ticks_msec() + 12000
	while not failed and Time.get_ticks_msec() < deadline:
		if check.call(): return true
		await get_tree().create_timer(0.025).timeout
	fail("lifecycle deadline phase=%s a=%s b=%s" % [phase, state(0), state(1)])
	return false

func verify() -> bool:
	for index in [0, 1]:
		var players: Dictionary = state(index).get("players", {})
		if not players.has("alice") or not players.has("bob"): return false
		for name in ["alice", "bob"]:
			var own = name == ("alice" if index == 0 else "bob")
			if players[name].get("publicValue") != "public:" + name: return false
			var secret = String(players[name].get("ownerSecret", ""))
			if own or not filtered:
				if secret != "secret:" + name: return false
			elif secret == "secret:" + name:
				fail("private field leaked")
				return false
	return true

func run() -> void:
	if room_id.is_empty():
		fail("room ID required")
		return
	join_peer(0)
	join_peer(1)
	if not await wait_for(verify): return
	phase = "reconnect"
	if not OS.has_feature("web"):
		var reconnect_seen := {"done": false}
		rooms[0].reconnected.connect(func(): reconnect_seen.done = true, CONNECT_ONE_SHOT)
		rooms[0].drop()
		if not await wait_for(func(): return reconnect_seen.done and verify()): return
	phase = "bob removal"
	rooms[1].leave()
	if not await wait_for(func(): return not state(0).get("players", {}).has("bob")): return
	phase = "bob rejoin"
	join_peer(1)
	if not await wait_for(verify): return
	phase = "alice removal"
	rooms[0].leave()
	if not await wait_for(func(): return not state(1).get("players", {}).has("alice")): return
	join_peer(0)
	if not await wait_for(verify): return
	for room in rooms: room.leave()
	print("STATEVIEW_PAIR_OK filtered=%s public_peers=true private_owner=true removal_rejoin=true" % filtered)
	if not OS.has_feature("web"): get_tree().quit()

func fail(message: String) -> void:
	if failed: return
	failed = true
	push_error("STATEVIEW_PAIR_FAILED " + message)
	for room in rooms: room.leave()
	if not OS.has_feature("web"): get_tree().quit(1)
