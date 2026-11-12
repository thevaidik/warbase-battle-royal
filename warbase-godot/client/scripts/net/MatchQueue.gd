extends Node

const AdmissionSession = preload("res://scripts/net/AdmissionSession.gd")

signal status_changed(message: String, active: bool)
signal seat_ready(reservation: Dictionary, map: String)

var _client
var _room
var _generation := 0
var _map := ""
var _deadline: Timer
var active := false
var _seat_received := false

func _ready() -> void:
	_deadline = Timer.new()
	_deadline.one_shot = true
	_deadline.timeout.connect(func() -> void: stop("Matchmaking timed out. Try again."))
	add_child(_deadline)

func start(endpoint: String, map: String, username: String) -> void:
	if active: return
	active = true
	_map = map
	_generation += 1
	_client = Colyseus.Client.new(endpoint)
	_deadline.start(30.0)
	status_changed.emit("Joining queue…", true)
	AdmissionSession.ensure(_client, endpoint, _on_admitted.bind(username, _generation))

func _on_admitted(token: String, error: Variant, username: String, generation: int) -> void:
	if generation != _generation or not active: return
	if error != null or token.is_empty():
		stop("Could not join matchmaking.")
		return
	_room = _client.join_or_create("conquest_queue", {
		"username": username,
		"map": _map,
		"protocol_version": WarGameState.GAME_PROTOCOL_VERSION,
	})
	if _room == null:
		stop("Could not open matchmaking.")
		return
	_room.message_received.connect(_on_message.bind(generation))
	_room.error.connect(_on_error.bind(generation))
	_room.left.connect(_on_closed.bind(generation))
	_room.dropped.connect(_on_closed.bind(generation))

func _on_message(kind: Variant, payload: Variant, generation: int) -> void:
	if generation != _generation or not active or _seat_received: return
	match String(kind):
		"clients":
			status_changed.emit("%d / 4 players · bots fill open slots" % int(payload), true)
		"seat":
			if not payload is Dictionary or String(payload.get("sessionId", "")).is_empty() or String(payload.get("roomId", "")).is_empty():
				stop("Matchmaking returned an invalid seat.")
				return
			_seat_received = true
			_deadline.stop()
			status_changed.emit("Match found. Deploying…", true)
			seat_ready.emit(payload, _map)

func confirm() -> void:
	if _room != null and _seat_received:
		_room.send_message("confirm", {})
	stop()

func stop(message: String = "") -> void:
	_generation += 1
	active = false
	_seat_received = false
	if is_instance_valid(_deadline): _deadline.stop()
	var old_room = _room
	_room = null
	_client = null
	if old_room != null: old_room.leave()
	if is_inside_tree(): status_changed.emit(message, false)

func _on_error(_code: int, message: String, generation: int) -> void:
	if generation == _generation: stop(message if not message.is_empty() else "Matchmaking unavailable.")

func _on_closed(_code: int, _reason: String, generation: int) -> void:
	if generation == _generation and not _seat_received: stop("Queue disconnected. Try again.")

func _exit_tree() -> void:
	stop()
