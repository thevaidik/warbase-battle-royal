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
	ws = WebSocketPeer.new()
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
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not connected:
			_set_connected(true)
		_reconnect_attempts = 0
		while ws.get_available_packet_count() > 0:
			var pkt := ws.get_packet()
			_handle(pkt)
		_ping_t += delta
		if _ping_t >= 1.0:
			_ping_t = 0.0
			_ping_sent_ms = int(Time.get_ticks_msec())
			_send(WarProto.encode_ping(_ping_sent_ms))
	elif st == WebSocketPeer.STATE_CLOSED or st == WebSocketPeer.STATE_CLOSING:
		if st == WebSocketPeer.STATE_CLOSED and ws.get_close_code() == 1008 and _want_connection:
			_want_connection = false
			connection_error.emit(ws.get_close_reason())
		_set_connected(false)
		if _want_connection:
			if _reconnect_t < 0.0:
				_schedule_reconnect()
	if _want_connection and _reconnect_t >= 0.0:
		_reconnect_t -= delta
		if _reconnect_t < 0.0:
			_do_connect()

func _schedule_reconnect() -> void:
	if _reconnect_attempts >= _max_reconnect:
		_want_connection = false
		connection_error.emit("Unable to reconnect")
		return
	var delay: float = min(pow(2.0, _reconnect_attempts), 10.0)
	_reconnect_attempts += 1
	_reconnect_t = delay

func _handle(pkt: PackedByteArray) -> void:
	var msg := WarProto.decode_server(pkt)
	match msg.get("kind", "unknown"):
		"game_state":
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

func _send(data: PackedByteArray) -> void:
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	ws.send(data)

func _valid(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)

func send_state(pos: Vector3, quat: Quaternion, anim: String, weapon: String) -> void:
	if not _valid(pos):
		return
	_send(WarProto.encode_state(pos.x, pos.y, pos.z, quat.x, quat.y, quat.z, quat.w, anim, current_ping, weapon))

func send_fire(o: Vector3, h: Vector3, n: Vector3, wall: bool, shot_id: int = 0) -> void:
	_send(WarProto.encode_fire(o, h, n, wall, shot_id))

func send_hit(target: String, damage: int, shot_id: int = 0) -> void:
	_send(WarProto.encode_hit(target, damage, shot_id))

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
	_send(WarProto.encode_vehicle_input(throttle, steer, brake, gear))

func send_ping_now() -> void:
	_ping_sent_ms = int(Time.get_ticks_msec())
	_send(WarProto.encode_ping(_ping_sent_ms))
