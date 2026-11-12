extends Node
## Two separate processes connect to the standalone probe room.
## Set STATE_VIEW_NAME to a unique name in each process.

const SchemaTypes := preload("res://state_view_schema.gd")

var _client
var _room
var _name := "godot_peer"
var _filtered := true
var _deadline_ms := 0
var _done := false
var _max_players_seen := 0
var _last_protocol := ""
var _last_player_names: Array = []

func _ready() -> void:
	_name = OS.get_environment("STATE_VIEW_NAME").strip_edges()
	if _name.is_empty(): _name = "godot_peer"
	_filtered = OS.get_environment("STATE_VIEW_FILTERED").to_lower() != "false"
	var endpoint := OS.get_environment("STATE_VIEW_ENDPOINT")
	if endpoint.is_empty(): endpoint = "ws://127.0.0.1:8097"
	var room_id := OS.get_environment("STATE_VIEW_ROOM_ID").strip_edges()
	if room_id.is_empty():
		_fail("set STATE_VIEW_ROOM_ID to the room ID printed by the probe server")
		return
	_client = Colyseus.Client.new(endpoint)
	_room = _client.join_by_id(room_id, {"name": _name})
	if _room == null:
		_fail("join_or_create returned null")
		return
	_room.set_state_type(SchemaTypes.RoomState)
	_room.joined.connect(func(): print("STATE_VIEW_GODOT_JOINED name=%s id=%s state=%s" % [_name, _room.get_id(), _room.get_state()]))
	_room.state_changed.connect(func(): print("STATE_VIEW_GODOT_PATCH name=%s state=%s" % [_name, _room.get_state()]))
	_room.error.connect(func(code: int, message: String): _fail("room error %d: %s" % [code, message]))
	_room.left.connect(func(code: int, reason: String): print("STATE_VIEW_GODOT_LEFT name=%s code=%d reason=%s" % [_name, code, reason]))
	_deadline_ms = Time.get_ticks_msec() + 10000

func _process(_delta: float) -> void:
	if _done or _room == null: return
	if Time.get_ticks_msec() >= _deadline_ms:
		_fail("timed out waiting for both peers; max_players=%d names=%s protocol=%s" % [_max_players_seen, _last_player_names, _last_protocol])
		return
	var raw_state = _room.get_state()
	if raw_state == null: return
	var state: Dictionary = _to_plain_dictionary(raw_state)
	var players: Dictionary = state.get("players", {})
	_max_players_seen = maxi(_max_players_seen, players.size())
	_last_protocol = String(state.get("protocol", ""))
	_last_player_names = players.keys()
	if players.size() < 2 or not players.has(_name): return
	print("STATE_VIEW_GODOT_TYPED_PLAYER name=%s type=%d value=%s" % [_name, typeof(players[_name]), players[_name]])
	var own: Dictionary = players[_name]
	if String(own.get("publicValue", "")) != "public:" + _name:
		_fail("owner public field did not decode: %s" % state)
		return
	if _filtered:
		if String(own.get("ownerSecret", "")) != "secret:" + _name:
			_fail("owner tagged field did not decode: %s" % state)
			return
		for peer_name in players:
			if peer_name != _name and String(players[peer_name].get("ownerSecret", "")) == "secret:" + String(peer_name):
				_fail("non-owner received another peer's tagged field: %s" % state)
				return
	else:
		for peer_name in players:
			if String(players[peer_name].get("ownerSecret", "")) != "secret:" + String(peer_name):
				_fail("unfiltered baseline omitted a field: %s" % state)
				return
	_done = true
	print("STATE_VIEW_GODOT_OK name=%s filtered=%s peers=%d protocol=%s" % [_name, _filtered, players.size(), state.get("protocol", "")])
	_room.leave()
	get_tree().quit(0)

func _fail(message: String) -> void:
	if _done: return
	_done = true
	push_error("STATE_VIEW_GODOT_FAIL name=%s %s" % [_name, message])
	if _room != null: _room.leave()
	get_tree().quit(1)

func _to_plain_dictionary(value: Variant) -> Variant:
	if value is Colyseus.Schema:
		return _to_plain_dictionary(value.to_dictionary())
	if value is Dictionary:
		var output := {}
		for key in value: output[key] = _to_plain_dictionary(value[key])
		return output
	if value is Array:
		var output := []
		for item in value: output.append(_to_plain_dictionary(item))
		return output
	return value
