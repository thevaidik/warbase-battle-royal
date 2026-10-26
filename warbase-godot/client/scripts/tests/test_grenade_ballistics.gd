extends SceneTree
const Flight = preload("res://scripts/weapons/GrenadeBallistics.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", message)
func add_box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	root.add_child(body)
	body.position = at
	return body
func run() -> void:
	add_box(Vector3(0, -0.1, 0), Vector3(200, 0.2, 200))
	var wall := add_box(Vector3(5, 2, 20), Vector3(0.04, 4, 8))
	await physics_frame
	await physics_frame
	var space = root.get_world_3d().direct_space_state
	var at := Vector3(0, 1.6, 0)
	var velocity := Flight.launch_velocity(Vector3.RIGHT, Vector3.ZERO)
	check(velocity == Vector3(20, 6, 0), "level aim has a deliberate overhand loft")
	check(Flight.launch_velocity(Vector3.UP, Vector3.ZERO).y == 20, "vertical aim keeps vertical throw control")
	var first_contact := -1
	var landing_x := 0.0
	for i in 720:
		var result := Flight.step(space, at, velocity, Flight.STEP)
		at = result.position
		velocity = result.velocity
		if i == 119:
			check(absf(at.x - 19.65) < 0.15 and at.y > 2.5, "grenade retains speed and follows a ballistic arc after one second")
		if result.contact and first_contact < 0:
			first_contact = i
			landing_x = at.x
			check(velocity.y > 2.0 and velocity.x > 12.0, "first impact bounces without erasing forward momentum")
	check(first_contact > 150 and landing_x > 26 and landing_x < 31, "level throw lands roughly 28 metres away")
	check(at.y >= 0.05 and at.x < 45.0 and velocity.length() < 0.15, "grenade settles on the floor without sinking or rolling indefinitely")
	var hit := Flight.step(space, Vector3(4, 1.5, 20), Vector3(29, 0, 0), 0.1)
	check(hit.contact and hit.position.x < 5 and hit.velocity.x < 0, "sweep rebounds from a thin wall without tunnelling")
	var impact := Flight.step(space, Vector3(4, 1.5, 20), Vector3(29, 0, 0), 0.1, true)
	check(impact.contact and impact.velocity == Vector3.ZERO, "armed impact grenade stops on first contact")
	var grenade_script = load("res://scripts/weapons/Grenade.gd")
	var grenade = grenade_script.throw(root, Vector3(0, 2, 0), Vector3(20, 6, 0))
	check(grenade.get_class() == "Node3D", "visual grenade uses the shared flight model")
	grenade.free()
	wall.free()
	print("GRENADE BALLISTICS TEST: %d failures; landing_x=%.3f final=%s" % [failures, landing_x, at])
	quit(failures)
