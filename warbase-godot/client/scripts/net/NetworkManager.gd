class_name WarNetwork
extends Node
## WebSocket client speaking the battle-royale protobuf binary protocol.
## Mirrors client/src/network/NetworkManager.ts: reconnect backoff, 1s ping, NaN guard.

signal state_received(state: Dictionary)
signal fire_received(shooter: String, origin: Vector3, hit: Vector3, normal: Vector3, wall: bool)
signal hit_confirmed()
signal kill_confirmed()
signal grenade_received(shooter: String, pos: Vector3, vel: Vector3, grenade_id: int, kind: String)
signal explosion_received(grenade_id: int, pos: Vector3, kind: String)
signal damage_received(target: String, pos: Vector3, direction: Vector3, amount: int)
signal respawn_received(pos: Vector3)
signal connection_changed(connected: bool)
signal connection_error(reason: String)

var ws := WebSocketPeer.new()
var connected := false
var current_ping := 0
var _reconnect_attempts := 0
var _max_reconnect := 10
var _want_connection := false
var _username := "Player"
var _room := "industrial-public"
var _host := "localhost:8081"
var _ping_t := 0.0
var _ping_sent_ms := 0
var _reconnect_t := -1.0
var _connect_started_ms := 0
var _last_state_ms := 0
var _last_pong_ms := 0
var _last_delivery_sequence := 0
var _last_ack_sent := 0
var _healthy_since_ms := 0
var _compression_stream: StreamPeerGZIP
var input_sequence := 0
var _sent_positions: Dictionary = {}
var _inflight_inputs: Array[int] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func take_acknowledged_position(sequence: int) -> Variant:
	var result = _sent_positions.get(sequence)
	for key in _sent_positions.keys():
		if key <= sequence: _sent_positions.erase(key)
	return result

func _drop_stalled_connection() -> void:
	if not _want_connection: return
	# Replacing the peer discards queued TCP/browser traffic on the old connection.
	ws.close()
	_compression_stream = StreamPeerGZIP.new()
	_compression_stream.start_decompression(false,262145)
	ws = WebSocketPeer.new()
	_set_connected(false)
	_schedule_reconnect()


func connect_to(username: String, room: String, host: String) -> void:
	ws.close()
	_reconnect_t = -1.0
	_username = username
	_room = room
	_host = host
	_want_connection = true
	_reconnect_attempts = 0
	_do_connect()

func _do_connect() -> void:
	_compression_stream = StreamPeerGZIP.new()
	_compression_stream.start_decompression(false,262145)
	ws = WebSocketPeer.new()
	_connect_started_ms = Time.get_ticks_msec()
	_last_state_ms = 0
	_last_pong_ms = 0
	_last_delivery_sequence = 0
	_last_ack_sent = 0
	_healthy_since_ms = 0
	_sent_positions.clear()
	_inflight_inputs.clear()
	var scheme := "wss"
	if _host.begins_with("localhost") or _host.begins_with("127."):
		scheme = "ws"
		
	# In web browser: auto-detect current location host & protocol
	if OS.has_feature("web"):
		var web_host = JavaScriptBridge.eval("window.location.host")
		var web_proto = JavaScriptBridge.eval("window.location.protocol")
		if String(web_proto) == "https:":
			scheme = "wss"
		else:
			scheme = "ws"
		if web_host != null and not String(web_host).is_empty():
			var h_str := String(web_host)
			_host = h_str
			
	var clean_host := _host.trim_prefix("https://").trim_prefix("http://").trim_prefix("wss://").trim_prefix("ws://").trim_suffix("/")
	var cid := _load_or_make_cid()
	var url := "%s://%s/connect?user=%s&room=%s&cid=%s" % [scheme, clean_host, _username.uri_encode(), _room.uri_encode(), cid]
	if not OS.has_feature("web"):
		ws.handshake_headers = PackedStringArray([
			"User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) WarBase-Client/2.4"
		])
	var err := ws.connect_to_url(url)
	if err != OK:
		push_warning("WS connect error: %s" % err)
		_schedule_reconnect()

func _load_or_make_cid() -> String:
	var path := "user://warbase_cid.txt"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			var c := f.get_as_text().strip_edges()
			if not c.is_empty():
				return c
	var c := "%x%x" % [randi(), randi()]
	var f2 := FileAccess.open(path, FileAccess.WRITE)
	if f2:
		f2.store_string(c)
	return c

func disconnect_from() -> void:
	_reconnect_t = -1.0
	_want_connection = false
	ws.close()
	_set_connected(false)

func _set_connected(v: bool) -> void:
	if connected != v:
		connected = v
		connection_changed.emit(v)

func _process(delta: float) -> void:
	ws.poll()
	var now := Time.get_ticks_msec()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not connected:
			_send(WarProto.encode_delivery_ack(0))
			_last_state_ms = now
			_last_pong_ms = now
			_ping_t = 1.0
			_set_connected(true)
		# A packet burst must not monopolize a rendered frame.
		var processed := 0
		var processing_peer := ws
		while ws.get_available_packet_count() > 0 and processed < 64:
			_handle(ws.get_packet())
			if ws != processing_peer: return
			processed += 1
		if _last_delivery_sequence > _last_ack_sent:
			if _send(WarProto.encode_delivery_ack(_last_delivery_sequence)):
				_last_ack_sent = _last_delivery_sequence
		_ping_t += delta
		if _ping_t >= 1.0:
			_ping_t = 0.0
			_ping_sent_ms = now
			_send(WarProto.encode_ping(now))
		if now - _last_state_ms > 5000 or now - _last_pong_ms > 5000:
			_drop_stalled_connection()
			return
		if _healthy_since_ms > 0 and now - _healthy_since_ms > 10000:
			_reconnect_attempts = 0
	elif st == WebSocketPeer.STATE_CONNECTING and now - _connect_started_ms > 10000:
		_drop_stalled_connection()
		return
	elif st == WebSocketPeer.STATE_CLOSED or st == WebSocketPeer.STATE_CLOSING:
		if st == WebSocketPeer.STATE_CLOSED and ws.get_close_code() == 1008 and _want_connection:
			_want_connection = false
			connection_error.emit(ws.get_close_reason())
		_set_connected(false)
		if _want_connection and _reconnect_t < 0.0: _schedule_reconnect()
	if _want_connection and _reconnect_t >= 0.0:
		_reconnect_t -= delta
		if _reconnect_t < 0.0: _do_connect()

func _schedule_reconnect() -> void:
	if _reconnect_attempts >= _max_reconnect:
		_want_connection = false
		connection_error.emit("Unable to reconnect")
		return
	var delay: float = min(pow(2.0, _reconnect_attempts), 10.0)
	_reconnect_attempts += 1
	_reconnect_t = delay

func _handle(pkt: PackedByteArray) -> void:
	var frame := WarProto.decode_frame(pkt, _compression_stream)
	if frame.get("error",false):
		_drop_stalled_connection()
		return
	var sequence := int(frame.get("sequence",0))
	if sequence > 0:
		if sequence <= _last_delivery_sequence: return
		_last_delivery_sequence = sequence
	var source_peer := ws
	for msg in frame.get("messages",[]):
		_dispatch_message(msg)
		if ws != source_peer: return

func _dispatch_message(msg: Dictionary) -> void:
	match msg.get("kind", "unknown"):
		"game_state":
			var me: Dictionary = msg.get("players",{}).get(_username,{})
			var acknowledged := int(me.get("ack_input_sequence",0))
			while not _inflight_inputs.is_empty() and _inflight_inputs[0] <= acknowledged:
				_inflight_inputs.pop_front()
			_last_state_ms = Time.get_ticks_msec()
			state_received.emit(msg)
		"fire":
			fire_received.emit(msg["shooter"], msg["origin"], msg["hit"], msg["normal"], msg["wall"])
		"hit_confirmed":
			hit_confirmed.emit()
		"kill_confirmed":
			kill_confirmed.emit()
		"grenade":
			grenade_received.emit(msg["shooter"], msg["pos"], msg["vel"], msg.get("id", 0), msg.get("throwable", "frag"))
		"explosion":
			explosion_received.emit(msg["id"], msg["pos"], msg.get("throwable", "frag"))
		"damage":
			damage_received.emit(msg["target"], msg["pos"], msg["direction"], msg["amount"])
		"respawn":
			respawn_received.emit(Vector3(msg["x"], msg["y"], msg["z"]))
		"pong":
			current_ping = int(Time.get_ticks_msec()) - int(msg.get("t", 0))
			if current_ping > 5000:
				_drop_stalled_connection()
				return
			_last_pong_ms = Time.get_ticks_msec()
			if _healthy_since_ms == 0: _healthy_since_ms = _last_pong_ms

func _send(data: PackedByteArray, replaceable: bool = false) -> bool:
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN: return false
	var pending := ws.get_current_outbound_buffered_amount()
	if replaceable and pending > 8192: return false
	if pending > 32768:
		_drop_stalled_connection()
		return false
	return ws.send(data) == OK

func _valid(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)

func send_state(pos: Vector3, quat: Quaternion, anim: String, weapon: String) -> void:
	if not _valid(pos):
		return
	if _last_delivery_sequence > 0 and _inflight_inputs.size() >= 8: return
	input_sequence += 1
	if _send(WarProto.encode_state(pos.x, pos.y, pos.z, quat.x, quat.y, quat.z, quat.w, anim, current_ping, weapon, input_sequence), true):
		_sent_positions[input_sequence] = pos
		if _last_delivery_sequence > 0: _inflight_inputs.append(input_sequence)
		while _sent_positions.size() > 256: _sent_positions.erase(_sent_positions.keys()[0])

func send_fire(o: Vector3, h: Vector3, n: Vector3, wall: bool, shot_id: int = 0) -> void:
	_send(WarProto.encode_fire(o, h, n, wall, shot_id))

func send_hit(target: String, damage: int, shot_id: int = 0, view_time_ms: int = 0) -> void:
	_send(WarProto.encode_hit(target, damage, shot_id, view_time_ms))

func send_reload() -> void:
	_send(WarProto.encode_reload())

func send_switch(wid: String) -> void:
	_send(WarProto.encode_switch(wid))

func send_loadout(primary: String, secondary: String, throwable: String) -> void:
	_send(WarProto.encode_loadout(primary, secondary, throwable))

func send_respawn() -> void:
	_send(WarProto.encode_respawn())

func send_grenade(p: Vector3, v: Vector3, kind: String = "frag") -> void:
	_send(WarProto.encode_grenade(p, v, kind))

func send_vehicle_seat(id: String, enter: bool) -> void:
	_send(WarProto.encode_vehicle_seat(id, enter))

func send_vehicle_input(throttle: float, steer: float, brake: bool, gear: int) -> void:
	if _last_delivery_sequence > 0 and _inflight_inputs.size() >= 8: return
	input_sequence += 1
	if _send(WarProto.encode_vehicle_input(throttle, steer, brake, gear, input_sequence), true):
		if _last_delivery_sequence > 0: _inflight_inputs.append(input_sequence)

func send_ping_now() -> void:
	_ping_sent_ms = int(Time.get_ticks_msec())
	_send(WarProto.encode_ping(_ping_sent_ms))
