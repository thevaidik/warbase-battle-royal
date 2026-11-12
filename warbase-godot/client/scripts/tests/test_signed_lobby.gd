extends Node
const Lobby = preload("res://scripts/net/LobbyAdapter.gd")
const Network = preload("res://scripts/net/ColyseusNetwork.gd")
var lobby
var network
var saw_listing := false
var saw_state := false
var done := false
func _ready() -> void:
	GameState.server_host = "127.0.0.1:18301"
	for action in ["move_left", "move_right", "move_back", "move_forward", "jump", "sprint", "crouch"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	lobby = Lobby.new()
	add_child(lobby)
	lobby.listing_changed.connect(on_listing)
	lobby.availability_changed.connect(func(available):
		if available and network == null:
			network = Network.new()
			add_child(network)
			network.connection_error.connect(fail)
			network.state_received.connect(func(state):
				if state.get("players", {}).has("signed-native"):
					saw_state = true
					finish_if_ready())
			network.connect_to("signed-native", "industrial-public", GameState.server_host))
	lobby.start()
	get_tree().create_timer(15).timeout.connect(func(): fail("signed native lobby deadline"))
func on_listing(data: Array) -> void:
	if data.size() >= 3 and data[0] == "+":
		var listing: Dictionary = data[2]
		if listing.get("metadata", {}).get("room") == "industrial-public" and int(listing.get("clients", 0)) == 1:
			saw_listing = true
			finish_if_ready()
func finish_if_ready() -> void:
	if done or not saw_listing or not saw_state: return
	done = true
	print("SIGNED_NATIVE_LOBBY_OK admission=true battle_state=true realtime_occupancy=true")
	network.disconnect_from()
	lobby.stop()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
func fail(message: String) -> void:
	if done: return
	done = true
	push_error("SIGNED_NATIVE_LOBBY_FAILED " + message)
	if network != null: network.disconnect_from()
	lobby.stop()
	get_tree().quit(1)
