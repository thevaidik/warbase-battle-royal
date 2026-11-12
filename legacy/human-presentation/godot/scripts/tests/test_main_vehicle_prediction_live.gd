extends Node
## Real Main + BattleRoom vehicle integration probe. The paired server is
## warbase-colyseus/repro/composite/main_vehicle_server.ts on port 18195.

const MainScene := preload("res://scenes/Main.tscn")
const DRIVE_SECONDS := 2.5
const WALK_SECONDS := 1.5
const TIMEOUT_SECONDS := 25.0
const POSITION_EPSILON := 0.12

enum Phase { WAIT_JOIN, WAIT_SEAT, DRIVE, WAIT_EXIT, WALK_PREP, WALK, DONE }

var _main
var _phase := Phase.WAIT_JOIN
var _elapsed := 0.0
var _phase_elapsed := 0.0
var _seat_requested := false
var _exit_requested := false
var _username := ""
var _drive_start := Vector3.ZERO
var _walk_start := Vector3.ZERO
var _car_at_exit := Vector3.ZERO
var _ack_at_drive_start := 0
var _ack_at_drive_end := 0
var _max_vehicle_pose_error := 0.0
var _pose_samples := 0
var _failure := ""
var _latency_ms := 0.0
var _max_pending := 0
var _corrections: Array[float] = []
var _last_reconcile_sequence := -1
var _previous_car_pose := Vector3.ZERO
var _display_steps: Array[float] = []

func _ready() -> void:
	Engine.max_fps = 60
	_latency_ms = maxf(0.0, float(OS.get_environment("COLYSEUS_VEHICLE_LATENCY_MS")))
	call_deferred("_start")

func _start() -> void:
	_username = "VHC_%03d" % (Time.get_ticks_msec() % 1000)
	GameState.username = _username
	GameState.room_id = "industrial-public"
	GameState.server_host = "127.0.0.1:18195"
	GameState.selected_map = "industrial"
	GameState.practice_mode = false
	_main = MainScene.instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_main.menu.visible = false
	_main.net.connection_error.connect(func(reason: String) -> void: _fail("connection error: " + reason))
	_main._start_match()
	print("MAIN_VEHICLE_SETUP username=%s host=%s" % [_username, GameState.server_host])

func _process(delta: float) -> void:
	if _phase == Phase.DONE or _main == null: return
	_elapsed += delta
	_phase_elapsed += delta
	if _elapsed > TIMEOUT_SECONDS:
		_fail("timed out phase=%s connected=%s online_ready=%s room=%s" % [_phase, _main.net.connected, GameState.online_ready, _main.net.room != null])
		return
	match _phase:
		Phase.WAIT_JOIN:
			if not _main.net.connected or not GameState.online_ready or _main.net.local_reconciler == null: return
			if not _main._online_vehicles.has("CAR_0"): return
			if _seat_requested: return
			if _latency_ms > 0.0: _main.net.room.set_latency(_latency_ms, 20.0)
			_seat_requested = true
			_main.net.send_vehicle_seat("CAR_0", true)
			_phase = Phase.WAIT_SEAT
			_phase_elapsed = 0.0
			print("MAIN_VEHICLE_SEAT_REQUESTED sent=%d ack=%d" % [_main.net.input_handle.sent_count, _main.net.input_handle.last_processed])
		Phase.WAIT_SEAT:
			var me := _local_player_state()
			if String(me.get("driving_vehicle", "")) == "CAR_0" and _main.current_driven_jeep != null:
				if not _main.net.is_vehicle_prediction_active("CAR_0"):
					_fail("server seat entered but the composite vehicle controller is inactive")
					return
				if not _vehicle().network_controlled or not _vehicle().freeze:
					_fail("networked jeep physics was not frozen; duplicate local controller may be active")
					return
				_drive_start = _vehicle().global_position
				_previous_car_pose = _drive_start
				_ack_at_drive_start = _main.net.input_handle.last_processed
				Input.action_press("move_forward")
				Input.action_press("move_right")
				_phase = Phase.DRIVE
				_phase_elapsed = 0.0
				print("MAIN_VEHICLE_DRIVE_STARTED server_driver=%s pose=%s" % [String(_vehicle_state().get("driver", "")), _drive_start])
			elif _phase_elapsed > 6.0:
				_fail("server did not establish CAR_0 seat: " + str(me))
		Phase.DRIVE:
			_track_vehicle_pose()
			if not _main.net.is_vehicle_prediction_active("CAR_0"):
				_fail("composite vehicle controller dropped while seated")
				return
			if _phase_elapsed >= DRIVE_SECONDS:
				Input.action_release("move_forward")
				Input.action_release("move_right")
				_ack_at_drive_end = _main.net.input_handle.last_processed
				_main.net.send_vehicle_seat("", false)
				_exit_requested = true
				_phase = Phase.WAIT_EXIT
				_phase_elapsed = 0.0
				print("MAIN_VEHICLE_EXIT_REQUESTED sent=%d ack=%d" % [_main.net.input_handle.sent_count, _ack_at_drive_end])
		Phase.WAIT_EXIT:
			var me := _local_player_state()
			if String(me.get("driving_vehicle", "")) == "" and _main.current_driven_jeep == null:
				if _main.net.is_vehicle_prediction_active("CAR_0"):
					_fail("vehicle prediction remained active after authoritative seat exit")
					return
				_car_at_exit = _vehicle().global_position
				_walk_start = _main.player.global_position
				Input.action_press("move_forward")
				_phase = Phase.WALK_PREP
				_phase_elapsed = 0.0
				print("MAIN_VEHICLE_EXIT_CONFIRMED server_driver=%s player=%s" % [String(_vehicle_state().get("driver", "")), _walk_start])
			elif _phase_elapsed > 6.0:
				_fail("server did not acknowledge vehicle seat exit: " + str(me))
		Phase.WALK_PREP:
			# Let the just-exited client prediction blend to the authoritative
			# parked vehicle pose before measuring for stale buffered controls.
			if _phase_elapsed >= 0.45:
				_car_at_exit = _vehicle().global_position
				_phase = Phase.WALK
				_phase_elapsed = 0.0
		Phase.WALK:
			if _phase_elapsed >= WALK_SECONDS:
				Input.action_release("move_forward")
				_finish_walk()

func _track_vehicle_pose() -> void:
	var expected := Vector3(_main.net.local_reconciler.value("CAR_0.x"), _main.net.local_reconciler.value("CAR_0.y"), _main.net.local_reconciler.value("CAR_0.z"))
	var error: float = _vehicle().global_position.distance_to(expected)
	_max_vehicle_pose_error = maxf(_max_vehicle_pose_error, error)
	_pose_samples += 1
	_display_steps.append(_vehicle().global_position.distance_to(_previous_car_pose))
	_previous_car_pose = _vehicle().global_position
	_max_pending = maxi(_max_pending, _main.net.input_handle.sent_count - _main.net.input_handle.last_processed)
	var controller = _main.net.local_reconciler
	if controller.reconcile_seq != _last_reconcile_sequence:
		_last_reconcile_sequence = controller.reconcile_seq
		var correction := float(controller.last_correction_mag)
		if not is_finite(correction):
			_fail("non-finite vehicle reconciliation correction")
			return
		_corrections.append(correction)

func _finish_walk() -> void:
	var car_drift: float = _vehicle().global_position.distance_to(_car_at_exit)
	var player_walk: float = _main.player.global_position.distance_to(_walk_start)
	var predicted_player: Vector3 = _main.net.get_predicted_player_position()
	var player_pose_error: float = _main.player.global_position.distance_to(predicted_player)
	var sent: int = _main.net.input_handle.sent_count
	var ack: int = _main.net.input_handle.last_processed
	var driver := String(_vehicle_state().get("driver", ""))
	var network_car_error: float = _vehicle().global_position.distance_to(_vehicle().network_position)
	var drive_distance: float = _vehicle().global_position.distance_to(_drive_start)
	var valid: bool = drive_distance > 1.0 and _ack_at_drive_end > _ack_at_drive_start and _pose_samples > 30 and _max_vehicle_pose_error < POSITION_EPSILON and car_drift < 0.08 and network_car_error < POSITION_EPSILON and player_walk > 0.1 and player_pose_error < POSITION_EPSILON and driver.is_empty() and sent > ack
	var detail := "drive=%0.2fm ack=%d->%d pose_error_max=%0.4fm samples=%d car_drift_after_exit=%0.4fm network_pose_error=%0.4fm foot_move=%0.2fm foot_pose_error=%0.4fm server_driver='%s' sent=%d ack=%d" % [drive_distance, _ack_at_drive_start, _ack_at_drive_end, _max_vehicle_pose_error, _pose_samples, car_drift, network_car_error, player_walk, player_pose_error, driver, sent, ack]
	_corrections.sort()
	var p95 := _corrections[mini(_corrections.size() - 1, floori(_corrections.size() * 0.95))] if not _corrections.is_empty() else 0.0
	_display_steps.sort()
	var display_p95 := _display_steps[mini(_display_steps.size() - 1, floori(_display_steps.size() * 0.95))] if not _display_steps.is_empty() else 0.0
	var display_max: float = _display_steps.back() if not _display_steps.is_empty() else 0.0
	# SDK aggregate correction includes sequence/seat fields; it is not metres.
	detail += " latency_ms=%.0f max_pending=%d sdk_aggregate_correction_p95=%.4f display_step_p95=%.4fm display_step_max=%.4fm" % [_latency_ms, _max_pending, p95, display_p95, display_max]
	valid = valid and _max_pending < 90 and display_max < 4.0
	_finish(valid, detail)

func _local_player_state() -> Dictionary:
	return _main.net._last_normalized_state.get("players", {}).get(_username, {})

func _vehicle_state() -> Dictionary:
	return _main.net._last_normalized_state.get("vehicles", {}).get("CAR_0", {})

func _vehicle():
	return _main._online_vehicles.get("CAR_0")

func _finish(ok: bool, detail: String) -> void:
	if _phase == Phase.DONE: return
	_phase = Phase.DONE
	Input.action_release("move_forward")
	Input.action_release("move_right")
	print("MAIN_VEHICLE_PREDICTION_%s %s" % ["OK" if ok else "FAILED", detail])
	if _main != null and is_instance_valid(_main.net): _main.net.disconnect_from()
	get_tree().quit(0 if ok else 1)

func _fail(message: String) -> void:
	_failure = message
	_finish(false, message)
