class_name WarProto
extends RefCounted
## Minimal protobuf encoder/decoder for the WarBase battle-royale schema.
## Recovered from client/src/network/packets.d.ts (pre-theatre schema).
## Only implements the fields the game uses. Server-compatible binary wire format.

# ClientEvent oneof field numbers
const CE_STATE := 1
const CE_HIT := 2
const CE_FIRE := 3
const CE_RELOAD := 4
const CE_SWITCH := 5
const CE_RESPAWN := 6
const CE_GRENADE := 7
const CE_PING := 8

static func _varint(v: int) -> PackedByteArray:
	var out := PackedByteArray()
	var x := v
	if x < 0:
		x = 0
	while x >= 0x80:
		out.append((x & 0x7F) | 0x80)
		x >>= 7
	out.append(x & 0x7F)
	return out

static func _tag(field: int, wire: int) -> PackedByteArray:
	return _varint((field << 3) | wire)

static func _f32(v: float) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(4)
	out.encode_float(0, v)
	return out

static func _str(s: String) -> PackedByteArray:
	var b := s.to_utf8_buffer()
	return _varint(b.size()) + b

static func _len(field: int, payload: PackedByteArray) -> PackedByteArray:
	return _tag(field, 2) + _varint(payload.size()) + payload

static func _f32f(field: int, v: float) -> PackedByteArray:
	return _tag(field, 5) + _f32(v)

static func _i32f(field: int, v: int) -> PackedByteArray:
	return _tag(field, 0) + _varint(v & 0xFFFFFFFF)

static func _strf(field: int, s: String) -> PackedByteArray:
	if s.is_empty():
		return PackedByteArray()
	return _len(field, s.to_utf8_buffer())

static func _boolf(field: int, b: bool) -> PackedByteArray:
	if not b:
		return PackedByteArray()
	return _tag(field, 0) + _varint(1)

static func encode_state(x: float, y: float, z: float, rx: float, ry: float, rz: float, rw: float, anim: String, ping: int, weapon: String, input_sequence: int = 0) -> PackedByteArray:
	var p := PackedByteArray()
	p += _f32f(1, x); p += _f32f(2, y); p += _f32f(3, z)
	p += _f32f(4, rx); p += _f32f(5, ry); p += _f32f(6, rz); p += _f32f(7, rw)
	p += _strf(8, anim)
	p += _strf(9, "godot")
	p += _i32f(10, ping)
	p += _strf(11, weapon)
	p += _tag(12, 0) + _varint(input_sequence)
	return _len(CE_STATE, p)

static func encode_hit(target: String, damage: int, shot_id: int = 0, view_time_ms: int = 0) -> PackedByteArray:
	var p := PackedByteArray()
	p += _strf(1, target)
	p += _i32f(2, damage)
	p += _i32f(3, shot_id)
	if view_time_ms > 0:
		p += _tag(4, 0) + _varint(view_time_ms)
	return _len(CE_HIT, p)

static func encode_fire(o: Vector3, h: Vector3, n: Vector3, wall: bool, shot_id: int = 0) -> PackedByteArray:
	var p := PackedByteArray()
	p += _f32f(1, o.x); p += _f32f(2, o.y); p += _f32f(3, o.z)
	p += _f32f(4, h.x); p += _f32f(5, h.y); p += _f32f(6, h.z)
	p += _f32f(7, n.x); p += _f32f(8, n.y); p += _f32f(9, n.z)
	p += _boolf(10, wall)
	p += _i32f(11, shot_id)
	return _len(CE_FIRE, p)

static func encode_reload() -> PackedByteArray:
	return _len(CE_RELOAD, PackedByteArray())

static func encode_switch(wid: String) -> PackedByteArray:
	var p := PackedByteArray()
	p += _strf(1, wid)
	return _len(CE_SWITCH, p)

static func encode_respawn() -> PackedByteArray:
	return _len(CE_RESPAWN, PackedByteArray())

static func encode_grenade(p_: Vector3, v: Vector3, kind: String = "frag") -> PackedByteArray:
	var p := PackedByteArray()
	p += _f32f(1, p_.x); p += _f32f(2, p_.y); p += _f32f(3, p_.z)
	p += _f32f(4, v.x); p += _f32f(5, v.y); p += _f32f(6, v.z)
	return _len(CE_GRENADE, p + _strf(7, kind))

static func encode_loadout(primary: String, secondary: String, throwable: String) -> PackedByteArray:
	return _len(9, _strf(1, primary) + _strf(2, secondary) + _strf(3, throwable))

static func encode_vehicle_seat(id: String, enter: bool) -> PackedByteArray:
	return _len(10, _strf(1, id) + _boolf(2, enter))

static func encode_vehicle_input(throttle: float, steer: float, brake: bool, gear: int, input_sequence: int = 0) -> PackedByteArray:
	return _len(11, _f32f(1, throttle) + _f32f(2, steer) + _boolf(3, brake) + _i32f(4, gear) + _tag(5,0) + _varint(input_sequence))

static func encode_delivery_ack(sequence: int) -> PackedByteArray:
	return _len(12, _tag(1, 0) + _varint(sequence) + _boolf(2,true))

static func encode_ping(ms: int) -> PackedByteArray:
	var p := PackedByteArray()
	p += _tag(1, 0) + _varint(ms)
	return _len(CE_PING, p)

# --- Decoder ---

class _Reader:
	var d: PackedByteArray
	var pos := 0
	func _init(data: PackedByteArray) -> void:
		d = data
	func eof() -> bool:
		return pos >= d.size()
	func read_varint() -> int:
		var shift := 0
		var res := 0
		while pos < d.size():
			var b := d[pos]
			pos += 1
			res |= (b & 0x7F) << shift
			if b & 0x80 == 0:
				break
			shift += 7
		return res
	func read_f32() -> float:
		var v := d.slice(pos, pos + 4)
		pos += 4
		return v.decode_float(0)
	func read_bytes(n: int) -> PackedByteArray:
		var v := d.slice(pos, pos + n)
		pos += n
		return v
	func read_str() -> String:
		var n := read_varint()
		return read_bytes(n).get_string_from_utf8()

static func _parse_msg(data: PackedByteArray) -> Dictionary:
	var r := _Reader.new(data)
	var out := {}
	while not r.eof():
		var tag := r.read_varint()
		var field := tag >> 3
		var wire := tag & 7
		match wire:
			0:
				out[field] = r.read_varint()
			1:
				out[field] = r.read_bytes(8)
			2:
				var n: int = r.read_varint()
				out[field] = r.read_bytes(n)
			5:
				out[field] = r.read_f32()
			_:
				break
	return out

## Returns Dictionary {kind: String, ...}. kind in game_state/fire/hit_confirmed/
## kill_confirmed/grenade/respawn/pong/unknown
static func decode_frame(data: PackedByteArray, stream: StreamPeerGZIP = null) -> Dictionary:
	var envelope := _parse_msg(data)
	if envelope.has(5):
		var compressed: PackedByteArray = envelope[5]
		var unpacked: PackedByteArray
		var kind := int(envelope.get(6,0))
		if kind == 1:
			var size := int(envelope.get(7,0))
			if stream == null or size <= 0 or size > 262144: return {"error":true,"messages":[]}
			var written := stream.put_partial_data(compressed)
			if written[0] != OK or written[1] != compressed.size() or stream.get_available_bytes() != size: return {"error":true,"messages":[]}
			var result := stream.get_data(size)
			if result[0] != OK: return {"error":true,"messages":[]}
			unpacked = result[1]
		elif kind == 0:
			unpacked = compressed.decompress_dynamic(262144,FileAccess.COMPRESSION_GZIP)
		else: return {"error":true,"messages":[]}
		if unpacked.is_empty() or _parse_msg(unpacked).has(5): return {"error":true,"sequence":0,"messages":[]}
		return _decode_uncompressed_frame(unpacked)
	return _decode_uncompressed_frame(data)

static func _decode_uncompressed_frame(data: PackedByteArray) -> Dictionary:
	var reader := _Reader.new(data)
	var messages: Array[Dictionary] = []
	var snapshot := PackedByteArray()
	var sequence := 0
	while not reader.eof():
		var tag := reader.read_varint()
		var field := tag >> 3
		match tag & 7:
			0:
				var value := reader.read_varint()
				if field == 4: sequence = value
			1: reader.read_bytes(8)
			2:
				var size := reader.read_varint()
				var payload := reader.read_bytes(size)
				if field == 1: snapshot = payload
				elif field in [2, 3]: messages.append(decode_server(_len(2, payload)))
			5: reader.read_f32()
			_: return {"sequence":0,"messages":[]}
	# Discrete events precede the newest authoritative world state.
	if not snapshot.is_empty(): messages.append(decode_server(_len(1,snapshot)))
	return {"sequence":sequence,"messages":messages}

static func decode_server(data: PackedByteArray) -> Dictionary:
	var top := _parse_msg(data)
	if top.has(1):
		var r := _Reader.new(top[1])
		var players := {}
		var vehicles := {}
		var removed_players: Array[String] = []
		var room_mode := "FFA"
		var room_state := "PLAYING"
		var score_a := 0
		var score_b := 0
		var winner := ""
		var map_name := ""
		var protocol_version := 0
		var time_of_day := "noon"
		while not r.eof():
			var tag := r.read_varint()
			var field := tag >> 3
			var wire := tag & 7
			match wire:
				0:
					var val := r.read_varint()
					if field == 4:
						score_a = val
					elif field == 5:
						score_b = val
					elif field == 8:
						protocol_version = val
				1:
					r.read_bytes(8)
				2:
					var n: int = r.read_varint()
					var b := r.read_bytes(n)
					if field == 1:
						var er := _Reader.new(b)
						var key := ""
						var val_bytes := PackedByteArray()
						while not er.eof():
							var et := er.read_varint()
							var ef := et >> 3
							var ew := et & 7
							match ew:
								0:
									er.read_varint()
								1:
									er.read_bytes(8)
								2:
									var n2: int = er.read_varint()
									var b2 := er.read_bytes(n2)
									if ef == 1:
										key = b2.get_string_from_utf8()
									elif ef == 2:
										val_bytes = b2
								5:
									er.read_f32()
								_:
									break
						if not key.is_empty():
							players[key] = _parse_player(val_bytes)
					elif field == 10:
						var entry := _parse_msg(b)
						var key: String = entry.get(1, PackedByteArray()).get_string_from_utf8()
						var car := _parse_msg(entry.get(2, PackedByteArray()))
						vehicles[key] = {"driver":car.get(2, PackedByteArray()).get_string_from_utf8(), "pos":Vector3(car.get(3,0.0),car.get(4,0.0),car.get(5,0.0)), "yaw":car.get(6,0.0), "speed":car.get(7,0.0), "health":car.get(8,0)}
					elif field == 11:
						removed_players.append(b.get_string_from_utf8())
					elif field == 2:
						room_mode = b.get_string_from_utf8()
					elif field == 3:
						room_state = b.get_string_from_utf8()
					elif field == 6:
						winner = b.get_string_from_utf8()
					elif field == 7:
						map_name = b.get_string_from_utf8()
					elif field == 9:
						time_of_day = b.get_string_from_utf8()
				5:
					r.read_f32()
				_:
					break
		return {
			"kind": "game_state",
			"players": players, "vehicles":vehicles,"removed_players":removed_players,
			"room_mode": room_mode,
			"room_state": room_state,
			"score_a": score_a,
			"score_b": score_b,
			"winner": winner,
			"map_name": map_name, "protocol_version": protocol_version, "time_of_day": time_of_day,
		}
	if top.has(2):
		var se := _parse_msg(top[2])
		for f in [1, 2, 3, 4, 5, 6, 7, 8]:
			if se.has(f):
				var e := _parse_msg(se[f])
				match f:
					1:
						return {"kind": "respawn", "x": e.get(1, 0.0), "y": e.get(2, 0.0), "z": e.get(3, 0.0)}
					2:
						return {
							"kind": "fire", "shooter": e.get(1, PackedByteArray()).get_string_from_utf8() if e.get(1) is PackedByteArray else "",
							"origin": Vector3(e.get(2, 0.0), e.get(3, 0.0), e.get(4, 0.0)),
							"hit": Vector3(e.get(5, 0.0), e.get(6, 0.0), e.get(7, 0.0)),
							"normal": Vector3(e.get(8, 0.0), e.get(9, 0.0), e.get(10, 0.0)),
							"wall": e.get(11, 0) == 1,
						}
					3:
						return {"kind": "hit_confirmed"}
					4:
						return {"kind": "kill_confirmed"}
					5:
						return {
							"kind": "grenade", "shooter": e.get(1, PackedByteArray()).get_string_from_utf8() if e.get(1) is PackedByteArray else "",
							"id": int(e.get(8, 0)),
							"throwable": e.get(9, PackedByteArray()).get_string_from_utf8() if e.get(9) is PackedByteArray else "frag",
							"pos": Vector3(e.get(2, 0.0), e.get(3, 0.0), e.get(4, 0.0)),
							"vel": Vector3(e.get(5, 0.0), e.get(6, 0.0), e.get(7, 0.0)),
						}
					6:
						return {"kind": "pong", "t": e.get(1, 0)}
					7:
						return {"kind": "explosion", "throwable": e.get(6, PackedByteArray()).get_string_from_utf8() if e.get(6) is PackedByteArray else "frag", "id": int(e.get(1, 0)), "pos": Vector3(e.get(3, 0.0), e.get(4, 0.0), e.get(5, 0.0))}
					8:
						return {"kind":"damage", "target":e.get(1, PackedByteArray()).get_string_from_utf8(), "pos":Vector3(e.get(2,0.0),e.get(3,0.0),e.get(4,0.0)), "direction":Vector3(e.get(5,0.0),e.get(6,0.0),e.get(7,0.0)), "amount":int(e.get(8,0))}
	return {"kind": "unknown"}

static func _parse_player(data: PackedByteArray) -> Dictionary:
	var f := _parse_msg(data)
	var s := func(i: int) -> String:
		return f.get(i, PackedByteArray()).get_string_from_utf8() if f.get(i) is PackedByteArray else ""
	var is_dead: bool = f.get(12, 0) == 1
	var has_rot: bool = f.has(4) or f.has(5) or f.has(6) or f.has(7)
	var default_rw: float = 0.0 if has_rot else 1.0
	return {
		"x": f.get(1, 0.0), "y": f.get(2, 0.0), "z": f.get(3, 0.0),
		"rx": f.get(4, 0.0), "ry": f.get(5, 0.0), "rz": f.get(6, 0.0), "rw": f.get(7, default_rw),
		"anim": s.call(8), "health": 0 if is_dead else f.get(9, 100), "kills": f.get(10, 0),
		"deaths": f.get(11, 0), "is_dead": is_dead,
		"driving_vehicle": s.call(22), "ack_input_sequence": int(f.get(23, 0)), "animation_time": float(f.get(24, 0.0)), "pose_time_ms": int(f.get(25, 0)),
		"platform": s.call(13), "ping": f.get(14, 0),
		"weapon": s.call(15), "team": s.call(16),
		"grenades": f.get(20, 0), "protected": f.get(21, 0) == 1,
		"ammo": f.get(17, 0), "reloading": f.get(18, 0) == 1, "last_shot_id": f.get(19, 0),
	}
