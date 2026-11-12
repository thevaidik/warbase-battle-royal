class_name WarMultiplayer
extends Node3D
## Remote player lifecycle + remote fire visuals.
## Mirrors client/src/network/MultiplayerEntities.ts triggerFire + updateNetworkState.

var remotes: Dictionary = {}
var _pending_remotes: Dictionary = {}
const RemotePoseTiming := preload("res://scripts/qa/RemotePoseTiming.gd")
const Missile := preload("res://scripts/drones/DroneMissile.gd")
const ProjectilePrediction := preload("res://scripts/net/ProjectilePrediction.gd")
var _qa_pose_application_timing
var net: WarNetwork
var world: Node3D
var local_name := ""
var _missiles: Dictionary = {}
var _projectile_nodes: Dictionary = {}
var _impacted_missiles: Dictionary = {}
var _impacted_missile_order: Array[int] = []
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
	net.connection_changed.connect(_on_connection_changed)
	net.explosion_received.connect(_on_explosion)
	net.missile_launched.connect(_on_missile_launch)
	net.missile_impacted.connect(_on_missile_impact)

func _on_missile_launch(id: int, weapon: String, position: Vector3, direction: Vector3, speed: float, duration: float) -> void:
	if net.uses_projectile_spawns(ProjectilePrediction.MISSILES): return
	if id <= 0 or not is_instance_valid(world) or not position.is_finite() or not direction.is_finite() or direction.is_zero_approx(): return
	if not (speed > 0.0 and speed < 120.0 and duration > 0.0 and duration < 5.0): return
	var projectile := Missile.launch(world, weapon, position, direction, speed, duration + 0.2)
	_missiles[id] = projectile
	projectile.tree_exited.connect(func() -> void:
		if _missiles.get(id) == projectile: _missiles.erase(id)
	, CONNECT_ONE_SHOT)

func _on_missile_impact(id: int, position: Vector3) -> void:
	if _impacted_missiles.has(id): return
	_impacted_missiles[id] = true
	_impacted_missile_order.append(id)
	if _impacted_missile_order.size() > MAX_REMEMBERED_EXPLOSIONS:
		_impacted_missiles.erase(_impacted_missile_order.pop_front())
	var projectile: Variant = _missiles.get(id)
	_missiles.erase(id)
	if is_instance_valid(projectile): projectile.queue_free()
	if position.is_finite(): Missile.burst(world, position)

func _clear_missiles() -> void:
	for projectile in _missiles.values():
		if is_instance_valid(projectile): projectile.queue_free()
	_missiles.clear()

func _render_projectiles(delta: float) -> void:
	if not is_instance_valid(net) or not net.connected or not is_instance_valid(world): return
	var live := {}
	for view in net.projectile_views():
		var key: String = view["key"]
		var id: int = view["server_id"]
		var position: Vector3 = view["position"]
		var velocity: Vector3 = view["velocity"]
		var grenade: bool = view["collection"] == ProjectilePrediction.GRENADES
		if id > 0 and ((_exploded_grenade_ids if grenade else _impacted_missiles).has(id)):
			continue
		live[key] = true
		var node: Node3D = _projectile_nodes.get(key)
		if not is_instance_valid(node):
			if id > 0:
				if grenade:
					for candidate in get_tree().get_nodes_in_group("grenades"):
						if int(candidate.get_meta("server_id", -1)) == id:
							node = candidate
							break
				else:
					node = _missiles.get(id)
			if not is_instance_valid(node) and grenade:
				node = WarGrenade.throw(world, position, velocity, Vector3.ZERO, view["kind"])
			elif not is_instance_valid(node):
				var direction := velocity.normalized() if not velocity.is_zero_approx() else Vector3.FORWARD
				node = Missile.launch(world, view["kind"], position, direction, velocity.length(), 1.0)
			node.set_physics_process(false)
			_projectile_nodes[key] = node
		node.global_position = node.global_position.lerp(position, 1.0 - exp(-32.0 * delta))
		node.set_meta("server_id", id)
		if grenade:
			var model := node.get_node_or_null("ModelRoot") as Node3D
			if model: model.rotation += Vector3(8.0, 2.5, 1.8) * delta
		elif id > 0:
			_missiles[id] = node
	for key in _projectile_nodes.keys():
		if live.has(key): continue
		var node: Node3D = _projectile_nodes[key]
		_projectile_nodes.erase(key)
		if not is_instance_valid(node): continue
		var id := int(node.get_meta("server_id", 0))
		if _missiles.get(id) == node: _missiles.erase(id)
		if node is WarGrenade and node._done: continue
		node.queue_free()

func _clear_projectile_nodes() -> void:
	for node in _projectile_nodes.values():
		if is_instance_valid(node): node.queue_free()
	_projectile_nodes.clear()

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
	_render_projectiles(delta)
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

func _on_fire(shooter: String, origin: Vector3, hit: Vector3, normal: Vector3, wall: bool, weapon: String) -> void:
	if remotes.has(shooter) and is_instance_valid(remotes[shooter]): remotes[shooter].react_to_shot()
	if shooter == local_name:
		return
	var main := get_tree().current_scene
	if main and main.has_method("remote_shoot_fx"):
		var effect_weapon := weapon if not weapon.is_empty() else (String(remotes[shooter].weapon_id) if remotes.has(shooter) else "ak47")
		main.remote_shoot_fx(origin, hit, normal, wall, effect_weapon)

func _on_grenade(_shooter: String, pos: Vector3, vel: Vector3, grenade_id: int, kind: String, _request_id: int) -> void:
	if net.uses_projectile_spawns(ProjectilePrediction.GRENADES) or _exploded_grenade_ids.has(grenade_id): return
	for grenade in get_tree().get_nodes_in_group("grenades"):
		if int(grenade.get_meta("server_id", -1)) == grenade_id: return
	var grenade := WarGrenade.throw(world, pos, vel, Vector3.ZERO, kind)
	grenade.set_meta("server_id", grenade_id)

func _on_connection_changed(connected: bool) -> void:
	if not connected:
		_clear_missiles()
		_clear_projectile_nodes()

func clear() -> void:
	_clear_projectile_nodes()
	_clear_missiles()
	_impacted_missiles.clear()
	_impacted_missile_order.clear()
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
