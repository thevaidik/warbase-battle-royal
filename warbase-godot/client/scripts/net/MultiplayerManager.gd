class_name WarMultiplayer
extends Node3D
## Remote player lifecycle + remote fire visuals.
## Mirrors client/src/network/MultiplayerEntities.ts triggerFire + updateNetworkState.

var remotes: Dictionary = {}
var _pending_remotes: Dictionary = {}
const RemotePoseTiming := preload("res://scripts/qa/RemotePoseTiming.gd")
var _qa_pose_application_timing
var net: WarNetwork
var world: Node3D
var local_name := ""
var _pending_grenades: Dictionary = {}
var _exploded_grenade_ids: Dictionary = {}
var _exploded_grenade_order: Array[int] = []
const MAX_REMEMBERED_EXPLOSIONS := 256

func setup(net_ref: WarNetwork, world_ref: Node3D, lname: String, qa_timing: bool = false) -> void:
	net = net_ref
	world = world_ref
	local_name = lname
	_qa_pose_application_timing = RemotePoseTiming.new() if qa_timing else null
	if net.has_method("set_qa_timing"):
		net.set_qa_timing(qa_timing)
	net.state_received.connect(_on_state)
	net.fire_received.connect(_on_fire)
	net.grenade_received.connect(_on_grenade)
	net.grenade_rejected.connect(_on_grenade_rejected)
	net.connection_changed.connect(_on_connection_changed)
	net.explosion_received.connect(_on_explosion)

func _on_state(state: Dictionary) -> void:
	for pid in state.get("removed_players",[]):
		_pending_remotes.erase(pid)
		if remotes.has(pid):
			if is_instance_valid(remotes[pid]): remotes[pid].queue_free()
			remotes.erase(pid)
		GameState.players.erase(pid)
	var players: Dictionary = state.get("players", {})
	for pid in players.keys():
		if pid == local_name or pid == GameState.username:
			var s_p: Dictionary = players[pid]
			var local_k: int = int(s_p.get("kills", 0))
			var local_d: int = int(s_p.get("deaths", 0))
			var current_hp := 100
			var main_scene = get_tree().current_scene
			if main_scene and "player" in main_scene and is_instance_valid(main_scene.player):
				current_hp = int(main_scene.player.health)
			else:
				current_hp = int(s_p.get("health", 100))
			GameState.players[pid] = {
				"name": GameState.username,
				"kills": local_k,
				"deaths": local_d,
				"health": current_hp,
				"team": String(s_p.get("team", GameState.local_team))
			}
		else:
			GameState.players[pid] = players[pid]
	GameState.score_a = int(state.get("score_a", 0))
	GameState.score_b = int(state.get("score_b", 0))
	GameState.winner_id = String(state.get("winner", ""))
	var mode := String(state.get("room_mode", "FFA"))
	var now_ms := Time.get_ticks_msec()
	for pid in players.keys():
		if pid == local_name or pid == GameState.username:
			continue
		var st: Dictionary = players[pid]
		if not remotes.has(pid):
			_pending_remotes[pid] = {"state":st,"seen":now_ms}
		else:
			var r: WarRemote = remotes[pid]
			r.set_meta("last_seen", now_ms)
			r.push_state(st)
			
	# Garbage collect remote players not seen for > 3.0 seconds
	# (Grace period supports multi-tiered 15Hz and 4Hz spatial updates without despawn flicker)
	var stale_pids: Array = []
	for pid in remotes.keys():
		var r: WarRemote = remotes[pid]
		var last_seen: int = r.get_meta("last_seen", now_ms)
		if now_ms - last_seen > 3000:
			stale_pids.append(pid)
			
	for pid in stale_pids:
		var r: WarRemote = remotes[pid]
		if is_instance_valid(r):
			r.queue_free()
		remotes.erase(pid)
		if GameState.players.has(pid):
			GameState.players.erase(pid)

	if players.has(local_name):
		var me: Dictionary = players[local_name]
		GameState.local_team = String(me.get("team", "A"))
		if me.has("kills"):
			GameState.local_kills = int(me.get("kills"))
		if me.has("deaths"):
			GameState.local_deaths = int(me.get("deaths"))

func _process(delta: float) -> void:
	var sdk_remote_poses: Dictionary = net.get_sdk_remote_poses() if net.has_method("get_sdk_remote_poses") else {}
	# Join bursts must not build dozens of skinned soldiers and guns in one frame.
	var created := 0
	for pid in _pending_remotes.keys():
		if created >= 1: break
		var pending: Dictionary = _pending_remotes[pid]
		_pending_remotes.erase(pid)
		if Time.get_ticks_msec() - int(pending.seen) > 3000: continue
		var st: Dictionary = pending.state
		var remote := WarRemote.create(pid,st)
		if net.has_method("get_sdk_remote_poses"):
			remote.use_server_authoritative_remote_pose()
		remote.set_meta("last_seen",pending.seen)
		remotes[pid] = remote
		world.add_child(remote)
		remote.global_position = Vector3(float(st.get("x",0)),float(st.get("y",0)),float(st.get("z",0)))
		created += 1
	var apply_started := Time.get_ticks_usec() if _qa_pose_application_timing != null else 0
	for r in remotes.values():
		var remote := r as WarRemote
		if not sdk_remote_poses.is_empty():
			var pose: Dictionary = sdk_remote_poses.get(remote.player_id, {})
			if not pose.is_empty():
				remote.apply_sdk_pose(pose, delta)
			else:
				remote.interpolate(delta)
		else:
			remote.interpolate(delta)
	if _qa_pose_application_timing != null:
		_qa_pose_application_timing.record(Time.get_ticks_usec() - apply_started, remotes.size())

func get_remote_pose_application_diagnostics() -> Dictionary:
	return _qa_pose_application_timing.summary() if _qa_pose_application_timing != null else {"enabled": false}

func _on_fire(shooter: String, origin: Vector3, hit: Vector3, normal: Vector3, wall: bool) -> void:
	if shooter == local_name:
		return
	var main := get_tree().current_scene
	if main and main.has_method("remote_shoot_fx"):
		main.remote_shoot_fx(origin, hit, normal, wall, remotes[shooter].weapon_id if remotes.has(shooter) else "ak47")

func register_predicted_grenade(request_id: int, grenade: WarGrenade) -> void:
	if request_id <= 0 or not is_instance_valid(grenade): return
	grenade.set_meta("request_id", request_id)
	grenade.set_meta("prediction_pending", true)
	grenade.set_meta("predicted_launch_position", grenade.global_position)
	grenade.set_meta("predicted_launch_velocity", grenade.linear_velocity)
	_pending_grenades[request_id] = grenade

func _on_grenade(shooter: String, pos: Vector3, vel: Vector3, grenade_id: int, kind: String, request_id: int) -> void:
	var main := get_tree().current_scene
	if main and main.has_method("spawn_grenade"):
		var grenade: WarGrenade
		var is_local := shooter == local_name or shooter == GameState.username
		var had_pending_request := false
		if grenade_id > 0 and _exploded_grenade_ids.has(grenade_id): return
		if request_id > 0 and is_local and _pending_grenades.has(request_id):
			had_pending_request = true
			var pending_node: Variant = _pending_grenades[request_id]
			_pending_grenades.erase(request_id)
			if is_instance_valid(pending_node):
				grenade = pending_node as WarGrenade
				grenade.set_meta("prediction_pending", false)
				# Correct the predicted launch offset without rewinding elapsed flight.
				var predicted_origin: Vector3 = grenade.get_meta("predicted_launch_position", pos)
				var predicted_velocity: Vector3 = grenade.get_meta("predicted_launch_velocity", vel)
				grenade.global_position += pos - predicted_origin
				grenade.linear_velocity += vel - predicted_velocity
				grenade.set_meta("server_id", grenade_id)
				return
			# The local 6s cosmetic may have retired before a delayed acceptance.
			# In that case materialize the confirmed server projectile below.
		if request_id > 0 and is_local and not had_pending_request: return # Duplicate or stale confirmation.
		grenade = main.spawn_grenade(pos, vel, Vector3.ZERO, kind)
		grenade.set_meta("server_id", grenade_id)

func _on_grenade_rejected(request_id: int) -> void:
	if not _pending_grenades.has(request_id): return
	var pending_node: Variant = _pending_grenades[request_id]
	_pending_grenades.erase(request_id)
	if is_instance_valid(pending_node): (pending_node as WarGrenade).queue_free()

func _on_connection_changed(connected: bool) -> void:
	if not connected: clear_pending_grenades()

func clear_pending_grenades() -> void:
	for pending in _pending_grenades.values():
		if is_instance_valid(pending): (pending as WarGrenade).queue_free()
	_pending_grenades.clear()

func clear() -> void:
	clear_pending_grenades()
	_exploded_grenade_ids.clear()
	_exploded_grenade_order.clear()
	_pending_remotes.clear()
	for r in remotes.values():
		if is_instance_valid(r):
			(r as Node).queue_free()
	remotes.clear()

func _on_explosion(grenade_id: int, pos: Vector3, kind: String) -> void:
	if grenade_id > 0 and _exploded_grenade_ids.has(grenade_id): return
	if grenade_id > 0:
		_exploded_grenade_ids[grenade_id] = true
		_exploded_grenade_order.append(grenade_id)
		if _exploded_grenade_order.size() > MAX_REMEMBERED_EXPLOSIONS:
			_exploded_grenade_ids.erase(_exploded_grenade_order.pop_front())
	var main := get_tree().current_scene
	if not main or not main.has_method("spawn_grenade"):
		return
	var grenade: WarGrenade
	for candidate in get_tree().get_nodes_in_group("grenades"):
		if int(candidate.get_meta("server_id", -1)) == grenade_id:
			grenade = candidate
			break
	if not grenade:
		grenade = main.spawn_grenade(pos, Vector3.ZERO, Vector3.ZERO, kind)
	if grenade._done: return
	grenade.global_position = pos
	grenade._done = true
	grenade._detonate()
