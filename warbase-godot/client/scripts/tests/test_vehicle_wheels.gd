extends SceneTree
## Frozen physics wheels must never detach the rendered online tyres.
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error("CHECK FAIL: " + message)
func run() -> void:
 var car = load("res://scenes/CombatJeep.tscn").instantiate()
 car.network_controlled = true
 car.position = Vector3(30, 1, 40)
 car.network_position = car.position
 root.add_child(car)
 for i in 5: await physics_frame
 check(car._wheel_visual_mounts.size() == 4, "four visible tyre mounts")
 for target in [Vector3(70, 1, 80), Vector3(-25, 4, -50)]:
  car.network_position = target
  car.network_yaw += 1.1
  car.current_speed_kmh = 36.0
  for i in 30: await physics_frame
  for i in 4:
   var mount: Node3D = car._wheel_visual_mounts[i]
   var expected: Vector3 = car.global_transform * car._wheel_mount_positions[i]
   check(mount.global_position.distance_to(expected) < 0.01, "tyre follows translated and turning online car")
   check(mount.is_visible_in_tree(), "tyre mount remains visible")
   var visual: Node3D = mount.get_child(0)
   check(visual.is_visible_in_tree() and visual.get_child_count() >= 3, "imported rubber, rim and hub retained")
   check(absf(visual.transform.basis.determinant()) > 0.99, "imported wheel basis is not collapsed")
 check(absf(car._network_wheel_roll) > 0.1, "moving online tyres rotate")
 car.current_speed_kmh = 0.0
 var previous_roll: float = car._network_wheel_roll
 for i in 10: await physics_frame
 check(is_equal_approx(car._network_wheel_roll, previous_roll), "parked tyres stop rotating")
 car.network_controlled = false
 for i in 5: await physics_frame
 for i in 4:
  check(car._wheel_visual_mounts[i].transform.is_equal_approx(car._wheels[i].transform), "offline visuals follow actual suspension")
 car.queue_free()
 await process_frame
 print("VEHICLE WHEEL TEST: %d failures" % failures)
 quit(1 if failures else 0)
