extends Node
## Bounded end-to-end candidate check: real Main, Industrial, Player, two peers.

const MainScene := preload("res://scenes/Main.tscn")
const Adapter := preload("res://scripts/net/ColyseusNetwork.gd")

var _main
var _peer
var _started_peer := false
var _began := false
var _begin_elapsed := 0.0
var _start_position := Vector3.ZERO
var _elapsed := 0.0
var _finished := false
var _main_name := ""
var _peer_name := ""

func _ready() -> void:
	call_deferred("_start")

func _start() -> void:
	_main_name = "MAIN_%03d" % (Time.get_ticks_msec() % 1000)
	_peer_name = "PEER_%03d" % ((Time.get_ticks_msec() + 1) % 1000)
	GameState.username = _main_name
	GameState.room_id = "industrial-public"
	var configured_host := OS.get_environment("COLYSEUS_TEST_HOST")
	GameState.server_host = configured_host if not configured_host.is_empty() else "127.0.0.1:8081"
	GameState.selected_map = "industrial"
	GameState.practice_mode = false
	_main = MainScene.instantiate()
	_main._use_colyseus = true
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_main.menu.visible = false
	print("MAIN_SETUP backend=", _main.net.get_script().resource_path, " practice=", GameState.practice_mode, " host=", GameState.server_host)
	_main.net.connection_error.connect(func(reason: String) -> void: print("MAIN_NETWORK_ERROR ", reason))
	_main.net.connection_changed.connect(func(value: bool) -> void: print("MAIN_CONNECTION_CHANGED ", value))
	_main.net.state_received.connect(func(state: Dictionary) -> void: print("MAIN_STATE players=", state.get("players", {}).keys(), " protocol=", state.get("protocol_version", -1), " map=", state.get("map_name", "")))
	_main._start_match()
	print("MAIN_MATCH_STARTED connected=", _main.net.connected, " room=", _main.net.room != null)

func _process(delta: float) -> void:
	if _finished or _main == null: return
	_elapsed += delta
	if _elapsed > 18.0:
		_finish(false, "timed out waiting for Main/player integration connected=%s online_ready=%s room=%s" % [_main.net.connected, GameState.online_ready, _main.net.room != null])
		return
	if not _main.net.connected or not GameState.online_ready or _main.net.local_reconciler == null:
		return
	if not _began:
		_began = true
		_begin_elapsed = _elapsed
		_start_position = _main.player.global_position
		Input.action_press("move_forward")
	if not _started_peer:
		_started_peer = true
		_peer = Adapter.new()
		add_child(_peer)
		_peer.connection_error.connect(func(reason: String) -> void: _finish(false, reason))
		_peer.connect_to(_peer_name, "industrial-public", GameState.server_host)
	if _elapsed - _begin_elapsed < 3.0: return
	Input.action_release("move_forward")
	var moved: float = _start_position.distance_to(_main.player.global_position)
	var expected := Vector3(_main.net.local_reconciler.value("x"), _main.net.local_reconciler.value("y"), _main.net.local_reconciler.value("z"))
	var pose_matches: bool = _main.player.global_position.distance_to(expected) < 0.02
	var remote_ready: bool = _main.mp.remotes.has(_peer_name)
	var remote: WarRemote = _main.mp.remotes.get(_peer_name) if remote_ready else null
	var sdk_pose_active := remote != null and remote.sdk_pose_driven
	var coarse_server_hit_hint := remote != null and remote.server_authoritative_remote_pose and remote._hitbox_areas.size() == 1 and String(remote._hitbox_areas[0].get_meta("from_bone", "")) == "coarse_body"
	if not _main.player.colyseus_authoritative_sim:
		_finish(false, "candidate did not disable local CharacterBody movement")
	elif moved < 0.35:
		_finish(false, "authoritative input did not move the real Player (%0.3f m; processing=%s predictor=%s tick=%d sent=%d ack=%d reconcile=%d in=(%.1f,%.1f) predicted=(%.2f,%.2f,%.2f) actual=%s)" % [moved, _main.net.is_processing(), _main.net.predictor != null, _main.net.predictor.tick() if _main.net.predictor != null else -1, _main.net.input_handle.sent_count, _main.net.input_handle.last_processed, _main.net.local_reconciler.reconcile_seq, _main.net.input_handle.data.move_x, _main.net.input_handle.data.move_z, expected.x, expected.y, expected.z, _main.player.global_position])
	elif not pose_matches:
		_finish(false, "Player transform did not follow SDK reconciler pose")
	elif not sdk_pose_active:
		_finish(false, "remote soldier did not use SDK-rendered pose")
	elif not coarse_server_hit_hint:
		_finish(false, "candidate remote did not use its coarse client hit hint")
	else:
		_finish(true, "moved=%0.2f m reconciled remote=%s coarse_hit_hint=true" % [moved, _peer_name])

func _finish(ok: bool, detail: String) -> void:
	if _finished: return
	_finished = true
	Input.action_release("move_forward")
	print("COLYSEUS_MAIN_SMOKE_", "OK" if ok else "FAILED", " ", detail)
	if _peer != null: _peer.disconnect_from()
	if _main != null and is_instance_valid(_main.net): _main.net.disconnect_from()
	get_tree().quit(0 if ok else 1)
