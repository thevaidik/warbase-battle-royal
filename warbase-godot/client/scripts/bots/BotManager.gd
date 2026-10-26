class_name WarBotManager
extends Node3D
## Tactical Bot Squad Manager.
## Coordinates AI squads, assigns flanking & pincer maneuvers,
## and routes sensory stimuli (audio gunfire, footsteps).

signal bot_eliminated(bot_name: String, killer: String, is_headshot: bool, source: String)

var bots: Array[WarBot] = []
var target_count := 7
var player: Node3D
var spawn_points: Array[Vector3] = []
var _respawn_t := 0.0
var _bot_seq := 0

func setup(p: Node3D, points: Array[Vector3]) -> void:
	player = p
	spawn_points = points
	for i in target_count:
		spawn_bot()

func get_spawn_point() -> Vector3:
	if not spawn_points.is_empty():
		var jitter := 0.7 if GameState.selected_map in ["loft", "shipment"] else 2.0
		return spawn_points[randi() % spawn_points.size()] + Vector3(randf_range(-jitter, jitter), 0.0, randf_range(-jitter, jitter))
	return Vector3(randf_range(-20, 20), 0.5, randf_range(-20, 20))

func spawn_bot() -> void:
	_bot_seq += 1
	var pos := get_spawn_point()
	var b := WarBot.create_bot("BOT_%d" % _bot_seq, pos, "B")
	add_child(b)
	b.global_position = pos + Vector3(0, 0.2, 0)
	b.set_target(player)
	b.died.connect(func(bname: String, killer: String, is_head: bool, src: String) -> void:
		bot_eliminated.emit(bname, killer, is_head, src)
	)
	bots.append(b)

## Squad radio alert: spotter coordinates pincer flank with nearby squadmates
func squad_alert(spotted_pos: Vector3, spotter: WarBot) -> void:
	var squadmates: Array[WarBot] = []
	for b in bots:
		if is_instance_valid(b) and not b.dead and b != spotter:
			if b.global_position.distance_to(spotted_pos) < 45.0:
				squadmates.append(b)
				
	# Sort closest squadmates and assign flanking roles
	var role_idx := 0
	for mate in squadmates:
		var role := "pincer"
		if role_idx == 0:
			role = "flanker_left"
		elif role_idx == 1:
			role = "flanker_right"
		mate.receive_squad_alert(spotted_pos, role)
		role_idx += 1

## Audio perception stimulus: notifies bots within hearing distance
func report_noise(origin: Vector3, radius: float) -> void:
	for b in bots:
		if is_instance_valid(b) and not b.dead:
			b.hear_noise(origin, radius)

func _process(delta: float) -> void:
	_respawn_t += delta
	var kept: Array[WarBot] = []
	for b in bots:
		if is_instance_valid(b):
			kept.append(b)
	bots = kept
	
	if bots.size() < target_count and is_instance_valid(player) and not (player as WarPlayer).is_dead:
		_respawn_t += delta
		if _respawn_t > 3.0:
			_respawn_t = 0.0
			spawn_bot()

func clear() -> void:
	for b in bots:
		if is_instance_valid(b):
			b.queue_free()
	bots.clear()

func get_roster_dict() -> Dictionary:
	var res: Dictionary = {}
	for b in bots:
		if is_instance_valid(b):
			res[b.bot_name] = {
				"name": b.bot_name,
				"kills": b.kills,
				"deaths": b.deaths,
				"health": int(maxf(0.0, b.health)),
				"team": b.team
			}
	return res
