extends SceneTree

const Contact = preload("res://scripts/net/CapsuleContact.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", message)

func triangle(a: Vector3, b: Vector3, c: Vector3) -> PackedFloat32Array:
	return PackedFloat32Array([a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z])

func run() -> void:
	var floor := triangle(Vector3(-5, 0, -5), Vector3(5, 0, -5), Vector3(0, 0, 5))
	var floor_contact := Contact.capsule_triangle(Vector3(0, -0.1, 0), 0.5, 1.8, floor, 0)
	check(not floor_contact.is_empty(), "capsule overlaps floor triangle")
	if not floor_contact.is_empty():
		check(absf(float(floor_contact.depth) - 0.1) < 0.001 and Vector3(floor_contact.normal).dot(Vector3.UP) > 0.999, "floor contact returns upward normal and penetration depth")

	var wall := triangle(Vector3(0, -5, -5), Vector3(0, 5, -5), Vector3(0, 0, 5))
	var wall_contact := Contact.capsule_triangle(Vector3(0.4, 0, 0), 0.5, 1.8, wall, 0)
	check(not wall_contact.is_empty(), "capsule overlaps a vertical wall")
	if not wall_contact.is_empty():
		check(absf(float(wall_contact.depth) - 0.1) < 0.001 and Vector3(wall_contact.normal).dot(Vector3.RIGHT) > 0.999, "wall contact resolves away from the surface")

	var slope := triangle(Vector3(-5, -5, -5), Vector3(5, 5, -5), Vector3(0, 0, 5))
	var slope_contact := Contact.capsule_triangle(Vector3(0, -0.1, 0), 0.5, 1.8, slope, 0)
	check(not slope_contact.is_empty(), "capsule overlaps a sloped triangle")
	if not slope_contact.is_empty():
		check(Vector3(slope_contact.normal).length_squared() > 0.99 and Vector3(slope_contact.normal).y > 0.0, "slope contact has a unit normal oriented toward the capsule")

	check(Contact.capsule_triangle(Vector3(0, 3, 0), 0.5, 1.8, floor, 0).is_empty(), "separated capsule and floor return no contact")
	var crossing := Contact.capsule_triangle(Vector3(0, 0, 0), 0.5, 1.8, wall, 0)
	check(not crossing.is_empty() and absf(float(crossing.depth) - 0.5) < 0.001, "capsule axis segment crossing a wall plane is detected")
	check(Contact.capsule_triangle(Vector3(0, 0, 0), 0.5, 1.8, PackedFloat32Array([0, 0, 0, 1, 0, 0, 2, 0, 0]), 0).is_empty(), "degenerate triangle returns no contact")
	print("CAPSULE CONTACT TEST: %d failures" % failures)
	quit(failures)
