class_name WarMultiplayer
extends Node3D
## Remote player lifecycle + remote fire visuals.
## Mirrors client/src/network/MultiplayerEntities.ts triggerFire + updateNetworkState.

var remotes: Dictionary = {}
var net: WarNetwork
var world: Node3D
var local_name := ""

func setup(net_ref: WarNetwork, world_ref: Node3D, lname: String) -> void:
	net = net_ref
	world = world_ref
	local_name = lname
	net.state_received.connect(_on_state)
	net.fire_received.connect(_on_fire)
	net.grenade_received.connect(_on_grenade)
	net.explosion_received.connect(_on_explosion)

func _on_state(state: Dictionary) -> void:
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
			var r := WarRemote.create(pid, st)
			r.set_meta("last_seen", now_ms)
			remotes[pid] = r
			world.add_child(r)
			var pos := Vector3(float(st.get("x", 0.0)), float(st.get("y", 0.0)), float(st.get("z", 0.0)))
			r.global_position = pos
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
	for r in remotes.values():
		(r as WarRemote).interpolate(delta)

func _on_fire(shooter: String, origin: Vector3, hit: Vector3, normal: Vector3, wall: bool) -> void:
	if shooter == local_name:
		return
	var main := get_tree().current_scene
	if main and main.has_method("remote_shoot_fx"):
		main.remote_shoot_fx(origin, hit, normal, wall, remotes[shooter].weapon_id if remotes.has(shooter) else "ak47")

func _on_grenade(_shooter: String, pos: Vector3, vel: Vector3, grenade_id: int, kind: String) -> void:
	var main := get_tree().current_scene
	if main and main.has_method("spawn_grenade"):
		var grenade = main.spawn_grenade(pos, vel, Vector3.ZERO, kind)
		grenade.set_meta("server_id", grenade_id)

func clear() -> void:
	for r in remotes.values():
		if is_instance_valid(r):
			(r as Node).queue_free()
	remotes.clear()

func _on_explosion(grenade_id: int, pos: Vector3, kind: String) -> void:
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
	grenade.global_position = pos
	grenade._done = true
	grenade._detonate()
