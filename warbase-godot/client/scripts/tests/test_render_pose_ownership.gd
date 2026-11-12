extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if not value: failures += 1
	print("CHECK ","PASS " if value else "FAIL ",label)
func run() -> void:
	var player = load("res://scenes/Player.tscn").instantiate()
	player.colyseus_authoritative_sim = true
	root.add_child(player)
	check(player.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF,"SDK-driven drone opts out of physics interpolation")
	player.colyseus_authoritative_sim = false
	check(player.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_INHERIT,"local drone preserves native physics interpolation")
	player.free()
	print("RENDER_POSE_OWNERSHIP failures=",failures)
	quit(failures)
