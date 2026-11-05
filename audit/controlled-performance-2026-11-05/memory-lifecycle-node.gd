extends Node

const NetworkAdapter := preload("res://scripts/net/ColyseusNetwork.gd")
const OFFICIAL_HOST := "war.vaidik.blog/colyseus"

var network
var username := "QA_LIFECYCLE"
var received_initial_state := false
var failure_reason := ""
var cleaning_up := false

func _on_state(state: Dictionary) -> void:
	var players: Dictionary = state.get("players", {})
	if players.has(username):
		received_initial_state = true

func _on_connection_error(reason: String) -> void:
	failure_reason = reason

func _on_connection_changed(is_connected: bool) -> void:
	if not is_connected and received_initial_state and not cleaning_up and failure_reason.is_empty():
		failure_reason = "connection dropped during lifecycle hold"

func freeNet() -> void:
	if network == null:
		return
	network.queue_free()
	await get_tree().process_frame
	network = null

func run_once() -> Dictionary:
	received_initial_state = false
	failure_reason = ""
	cleaning_up = false
	GameState.server_host = OFFICIAL_HOST
	GameState.username = username
	GameState.selected_map = "industrial"
	GameState.practice_mode = false
	network = NetworkAdapter.new()
	get_tree().root.add_child(network)
	network.state_received.connect(_on_state)
	network.connection_error.connect(_on_connection_error)
	network.connection_changed.connect(_on_connection_changed)
	network.connect_to(username, "industrial-public", OFFICIAL_HOST)

	var deadline_ms := Time.get_ticks_msec() + 15000
	while not received_initial_state and failure_reason.is_empty() and Time.get_ticks_msec() < deadline_ms:
		await get_tree().process_frame
	if not received_initial_state and failure_reason.is_empty():
		failure_reason = "initial-state deadline exceeded (15 seconds)"
	if failure_reason.is_empty():
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(network) or not network.connected:
			failure_reason = "network disconnected during one-second hold"

	cleaning_up = true
	if is_instance_valid(network):
		network.disconnect_from()
		await get_tree().create_timer(0.5).timeout
		await freeNet()
	return {"ok": failure_reason.is_empty(), "error": failure_reason, "initial_state": received_initial_state}
