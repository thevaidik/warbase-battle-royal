extends Node
## Integration probe for the live Main/Colyseus path in a real CONQUEST room.

const MainScene := preload("res://scenes/Main.tscn")
const TIMEOUT_SECONDS := 35.0

enum Phase { WAIT_JOIN, WAIT_NEUTRAL_INPUT, WAIT_MOVEMENT, DONE }

var _main
var _phase := Phase.WAIT_JOIN
var _elapsed := 0.0
var _phase_elapsed := 0.0
var _start_position := Vector3.ZERO
var _start_ack := 0
var _start_sent := 0
var _shots_before := 0
var _grenades_before := 0
var _grenade_cooldown_before := 0.0
var _local_fire_events := 0
var _username := ""

func _ready() -> void:
	Engine.max_fps = 60
	call_deferred("_start")

func _start() -> void:
	_username = "QA_CQ_%03d" % (Time.get_ticks_msec() % 1000)
	GameState.username = _username
	GameState.room_id = "QA_CONQUEST_LIVE"
	GameState.server_host = OS.get_environment("COLYSEUS_TEST_HOST")
	if GameState.server_host.is_empty(): GameState.server_host = "127.0.0.1:18194"
	GameState.selected_map = "industrial"
	GameState.selected_mode = "CONQUEST"
	GameState.selected_time = "noon"
	GameState.practice_mode = false
	_main = MainScene.instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_main.menu.visible = false
	_main.net.connection_error.connect(func(reason: String) -> void: _fail("connection error: " + reason))
	_main.net.fire_received.connect(func(shooter: String, _origin: Vector3, _hit: Vector3, _normal: Vector3, _wall: bool) -> void:
		if shooter == _username: _local_fire_events += 1
	)
	_main.net.state_received.connect(_on_room_state)
	_main._start_match()
	print("CONQUEST_MAIN_SETUP username=%s room=%s host=%s" % [_username, GameState.room_id, GameState.server_host])

func _on_room_state(state: Dictionary) -> void:
	if not state.is_empty() and String(state.get("room_mode", "")) != "CONQUEST":
		_fail("server room mode was not CONQUEST: " + String(state.get("room_mode", "")))

func _process(delta: float) -> void:
	if _phase == Phase.DONE or _main == null: return
	_elapsed += delta
	_phase_elapsed += delta
	if _elapsed > TIMEOUT_SECONDS:
		_fail("timed out phase=%s connected=%s online_ready=%s" % [_phase, _main.net.connected, GameState.online_ready])
		return
	match _phase:
		Phase.WAIT_JOIN:
			if not _main.net.connected or not GameState.online_ready or _main.net.local_reconciler == null: return
			if _main.net.input_handle == null: return
			var state: Dictionary = _main.net._last_normalized_state
			var players: Dictionary = state.get("players", {})
			var objectives_value: Variant = state.get("objectives", {})
			var objectives: Dictionary = objectives_value if objectives_value is Dictionary else {}
			var me: Dictionary = players.get(_username, {})
			if objectives.size() != 4: return
			if int(state.get("tickets_a", -1)) != 500 or int(state.get("tickets_b", -1)) != 500: return
			if String(me.get("team", "")) not in ["A", "B"]: return
			if not is_instance_valid(_main.tactical_map):
				_fail("CONQUEST Main did not create the tactical map")
				return
			if not _main.hud.objective_strip.visible or _main.hud.objective_labels.size() != 4:
				_fail("Conquest HUD objective strip is not active")
				return
			var objective_by_id: Dictionary = {}
			for objective in objectives.values():
				if objective is Dictionary:
					objective_by_id[String(objective.get("id", ""))] = objective
			for code in ["A", "B", "C", "D"]:
				if not objective_by_id.has(code):
					_fail("server is missing objective " + code)
					return
				var point: Dictionary = objective_by_id[code]
				for coordinate in ["x", "y", "z", "radius"]:
					if not is_finite(float(point.get(coordinate, NAN))):
						_fail("objective %s has invalid %s position/radius" % [code, coordinate])
						return
				var marker: Vector2 = _main.tactical_map.map_camera.unproject_position(Vector3(float(point.x), float(point.y), float(point.z)))
				if not is_finite(marker.x) or not is_finite(marker.y):
					_fail("objective %s projected to a non-finite map marker" % code)
				if not _main.tactical_map.objectives.any(func(item: Dictionary) -> bool: return String(item.get("id", "")) == code):
					_fail("objective %s is absent from map marker data" % code)
					return
			if not _main.hud.score_label.text.contains("TICKETS"):
				_fail("Conquest score header is not displaying team tickets")
				return
			_main._toggle_tactical_map()
			if not _main._tactical_map_open or not _main.tactical_map.visible:
				_fail("M map toggle did not open the overlay")
				return
			if _main.tactical_map.map_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
				_fail("map viewport is rendering continuously instead of taking a snapshot")
				return
			_shots_before = _main.weapons._shot_seq
			_grenades_before = GameState.throwables_remaining
			_grenade_cooldown_before = _main._grenade_cd
			Input.action_press("move_forward")
			Input.action_press("move_right")
			Input.action_press("jump")
			Input.action_press("sprint")
			Input.action_press("fire")
			Input.action_press("grenade")
			var grenade_key := InputEventKey.new()
			grenade_key.keycode = KEY_G
			grenade_key.physical_keycode = KEY_G
			grenade_key.pressed = true
			_main._input(grenade_key)
			var fire_click := InputEventMouseButton.new()
			fire_click.button_index = MOUSE_BUTTON_LEFT
			fire_click.pressed = true
			_main._input(fire_click)
			var eye: Vector3 = _main.player.global_position + Vector3.UP * 1.2
			var aim: Vector3 = -_main.player.camera.global_transform.basis.z
			_main.net.send_fire(eye, eye + aim * 100.0, Vector3.UP, false, _main.weapons._shot_seq + 1, _main.player.yaw, _main.player.pitch)
			_phase_elapsed = 0.0
			_phase = Phase.WAIT_NEUTRAL_INPUT
			print("CONQUEST_MAIN_JOIN_OK team=%s objectives=4 tickets=500 map_open=true" % String(me.get("team", "")))
		Phase.WAIT_NEUTRAL_INPUT:
			if _phase_elapsed < 0.4: return
			var data = _main.net.input_handle.data
			var neutral := is_zero_approx(float(data.move_x)) and is_zero_approx(float(data.move_z)) and is_zero_approx(float(data.jump)) and is_zero_approx(float(data.sprint)) and is_zero_approx(float(data.crouch)) and is_zero_approx(float(data.vehicle_throttle)) and is_zero_approx(float(data.vehicle_steer))
			if not neutral:
				_fail("SDK buffered input was not neutral while map open: move=(%s,%s) jump=%s sprint=%s vehicle=(%s,%s)" % [data.move_x, data.move_z, data.jump, data.sprint, data.vehicle_throttle, data.vehicle_steer])
				return
			if _main.weapons._shot_seq != _shots_before:
				_fail("weapon fired while map was open")
				return
			if _local_fire_events > 0:
				_fail("network fire message escaped the gameplay input gate while map was open")
				return
			if GameState.throwables_remaining != _grenades_before:
				_fail("grenade count changed while map was open")
				return
			if not is_equal_approx(_main._grenade_cd, _grenade_cooldown_before):
				_fail("grenade cooldown changed while map was open")
				return
			if _main.net._gameplay_input_enabled:
				_fail("network gameplay input gate remained enabled while the map was open")
				return
			_main._toggle_tactical_map()
			if _main._tactical_map_open or _main.tactical_map.visible:
				_fail("map did not close")
				return
			if not _main.net._gameplay_input_enabled:
				_fail("network gameplay input gate did not re-enable after map close")
				return
			if _main.tactical_map.map_viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED:
				_fail("closed map viewport is still rendering")
				return
			Input.action_release("fire")
			Input.action_release("grenade")
			Input.action_release("jump")
			Input.action_release("sprint")
			_start_position = _main.player.global_position
			_start_ack = int(_main.net.input_handle.last_processed)
			_start_sent = int(_main.net.input_handle.sent_count)
			_phase_elapsed = 0.0
			_phase = Phase.WAIT_MOVEMENT
			print("CONQUEST_MAIN_MAP_GATE_OK neutral_input=true shot_seq=%d grenades=%d" % [_shots_before, _grenades_before])
		Phase.WAIT_MOVEMENT:
			if _phase_elapsed < 1.0: return
			Input.action_release("move_forward")
			Input.action_release("move_right")
			var moved: float = _start_position.distance_to(_main.player.global_position)
			var ack := int(_main.net.input_handle.last_processed)
			var sent := int(_main.net.input_handle.sent_count)
			var prediction_position: Vector3 = _main.net.get_predicted_player_position()
			var pose_error: float = _main.player.global_position.distance_to(prediction_position)
			if moved < 0.25:
				_fail("movement did not resume after close: moved=%0.3fm sent=%d ack=%d input=%s" % [moved, sent, ack, _main.net._gameplay_input_enabled])
				return
			if ack <= _start_ack or sent <= _start_sent:
				_fail("SDK input acknowledgements did not progress after close: sent=%d->%d ack=%d->%d" % [_start_sent, sent, _start_ack, ack])
				return
			if pose_error > 0.15:
				_fail("player pose did not follow SDK prediction after close: error=%0.3fm" % pose_error)
				return
			_finish(true, "team=%s objectives=4 moved=%0.2fm sent=%d->%d ack=%d->%d pose_error=%0.3fm" % [String(_main.net._last_normalized_state.players[_username].team), moved, _start_sent, sent, _start_ack, ack, pose_error])

func _finish(ok: bool, detail: String) -> void:
	if _phase == Phase.DONE: return
	_phase = Phase.DONE
	for action in ["move_forward", "move_right", "jump", "sprint", "fire", "grenade"]: Input.action_release(action)
	print("CONQUEST_MAIN_LIVE_%s %s" % ["OK" if ok else "FAILED", detail])
	if _main != null and is_instance_valid(_main.net): _main.net.disconnect_from()
	get_tree().quit(0 if ok else 1)

func _fail(reason: String) -> void:
	_finish(false, reason)
