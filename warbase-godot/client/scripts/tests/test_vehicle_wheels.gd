extends SceneTree
## Frozen physics wheels must never detach the rendered online tyres.
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error("CHECK FAIL: " + message)
func run() -> void:
 var steer_angles: Array[float] = []
 for steer_input in [-0.35, 0.35]:
  var forward_travel := 0.2
  var forward_yaw := -forward_travel * tan(steer_input) / 3.99
  var reverse_travel := -forward_travel
  var reverse_yaw := -reverse_travel * tan(steer_input) / 3.99
  var forward_angle: float = load("res://scripts/vehicles/CombatJeep.gd")._network_steer_from_motion(forward_yaw, forward_travel)
  var reverse_angle: float = load("res://scripts/vehicles/CombatJeep.gd")._network_steer_from_motion(reverse_yaw, reverse_travel)
  check(is_equal_approx(forward_angle, reverse_angle), "front tyres keep steering orientation when travel reverses")
  steer_angles.append(forward_angle)
 check(steer_angles[0] * steer_angles[1] < 0.0, "left and right front tyre orientation stay opposite")
 var car = load("res://scenes/CombatJeep.tscn").instantiate()
 car.network_controlled = true
 check(car.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF, "online render-owned jeep disables physics interpolation for its inherited branch")
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
 check(car.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_INHERIT, "offline jeep restores inherited physics interpolation")
 for i in 5: await physics_frame
 for i in 4:
  check(car._wheel_visual_mounts[i].transform.is_equal_approx(car._wheels[i].transform), "offline visuals follow actual suspension")
 car.queue_free()
 await process_frame
 print("VEHICLE WHEEL TEST: %d failures" % failures)
 quit(1 if failures else 0)
