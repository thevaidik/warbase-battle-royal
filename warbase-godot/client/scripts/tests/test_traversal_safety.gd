extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", message)
func box(parent: Node, at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	body.position = at
	return body
func run() -> void:
	var state = root.get_node("GameState")
	state.practice_mode = true
	state.online_ready = true
	state.selected_map = "football"
	var builder = load("res://scripts/maps/MapBuilder.gd").new()
	root.add_child(builder)
	builder.build("football")
	var two_sided := true
	for col in builder.find_children("*","CollisionShape3D",true,false):
		if col.shape is ConcavePolygonShape3D: two_sided = two_sided and col.shape.backface_collision
	check(two_sided, "map collision blocks both sides like the authority")
	builder.free()
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := box(world,Vector3(0,-0.1,0),Vector3(30,0.2,40))
	var step := box(world,Vector3(0,0.15,-3),Vector3(4,0.3,2))
	var player = load("res://scenes/Player.tscn").instantiate()
	world.add_child(player)
	player.position = Vector3(0,0.1,0)
	for i in 15: await physics_frame
	var high := 0.0
	Input.action_press("move_forward")
	for i in 90:
		await physics_frame
		high = maxf(high, player.position.y)
	Input.action_release("move_forward")
	check(player.position.z < -4.5 and high >= 0.3 and high < 0.6, "capsule climbs a low step without mantling or clipping")
	var ceiling := box(world,Vector3(0,1.9,-3),Vector3(4,0.2,2))
	player.position = Vector3(0,0.1,0)
	player.velocity = Vector3.ZERO
	player._step_active = false
	player.reset_physics_interpolation()
	for i in 15: await physics_frame
	Input.action_press("move_forward")
	for i in 75: await physics_frame
	Input.action_release("move_forward")
	check(player.position.z > -2.5 and player.position.y < 0.2, "low ceiling rejects the entire step-up capsule")
	step.free()
	ceiling.position.y = 1.5
	player.position = Vector3(0,0.08,-3)
	player.velocity = Vector3.ZERO
	player.is_crouching = true
	player._col.shape.height = 1.2
	player._col.position.y = 0.6
	player.reset_physics_interpolation()
	for i in 25: await physics_frame
	check(player.is_crouching and player._col.shape.height < 1.3, "releasing crouch cannot grow the body into a ceiling")
	player.position = Vector3(0,0.1,2)
	player.reset_physics_interpolation()
	for i in 30: await physics_frame
	check(not player.is_crouching and player._col.shape.height > 1.7, "standing resumes after clearing low cover")
	ceiling.free()
	floor_body.position.y = -6.1
	player.position = Vector3(0,-5.8,2)
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	for i in 30: await physics_frame
	check(player.position.y < -5 and player.position.y > -7, "valid stadium surfaces below -4m do not trigger a teleport")
	world.free()
	print("TRAVERSAL SAFETY TEST: %d failures" % failures)
	quit(failures)
