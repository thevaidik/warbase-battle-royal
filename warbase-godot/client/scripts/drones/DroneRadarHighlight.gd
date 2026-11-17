class_name DroneRadarHighlight
extends Node3D
## 3D tactical radar signature highlight that attaches to a locked target drone.

var target_node: Node3D = null
var is_locked: bool = false
var lock_progress: float = 0.0

var _pulse_ring: MeshInstance3D
var _sweep_disc: MeshInstance3D
var _fresnel_sphere: MeshInstance3D
var _label: Label3D
var _pulse_t := 0.0
var _pulse_mat: StandardMaterial3D
var _sweep_mat: StandardMaterial3D
var _fresnel_mat: StandardMaterial3D

func _init() -> void:
	name = "DroneRadarHighlight"
	
	# 1. Concentric pulsing radar ping wave
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.65
	ring_mesh.outer_radius = 0.78
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 6
	_pulse_mat = StandardMaterial3D.new()
	_pulse_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pulse_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pulse_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_pulse_ring = MeshInstance3D.new()
	_pulse_ring.mesh = ring_mesh
	_pulse_ring.material_override = _pulse_mat
	_pulse_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_pulse_ring)
	
	# 2. Rotating radar sweep indicator
	var sweep_mesh := CylinderMesh.new()
	sweep_mesh.top_radius = 0.95
	sweep_mesh.bottom_radius = 0.95
	sweep_mesh.height = 0.04
	sweep_mesh.radial_segments = 16
	_sweep_mat = StandardMaterial3D.new()
	_sweep_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sweep_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sweep_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_sweep_disc = MeshInstance3D.new()
	_sweep_disc.mesh = sweep_mesh
	_sweep_disc.material_override = _sweep_mat
	_sweep_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sweep_disc)
	
	# 3. Holographic Fresnel hull highlight envelope
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.62
	sphere_mesh.height = 0.62 * 2.0
	sphere_mesh.radial_segments = 16
	sphere_mesh.rings = 8
	_fresnel_mat = StandardMaterial3D.new()
	_fresnel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fresnel_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fresnel_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fresnel_sphere = MeshInstance3D.new()
	_fresnel_sphere.mesh = sphere_mesh
	_fresnel_sphere.material_override = _fresnel_mat
	_fresnel_sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fresnel_sphere)
	
	# 4. 3D Floating Tactical Seeker Tag
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 18
	_label.outline_size = 4
	_label.outline_modulate = Color(0.02, 0.04, 0.06, 0.95)
	_label.position = Vector3(0, 0.72, 0)
	add_child(_label)

func update_lock_state(target: Node3D, locked: bool, progress: float, cam_pos: Vector3) -> void:
	target_node = target
	is_locked = locked
	lock_progress = progress
	if not is_inside_tree() or not is_instance_valid(target_node):
		visible = false
		return
		
	visible = true
	global_position = target_node.global_position + Vector3.UP * 0.35
	var dist_m := roundi(global_position.distance_to(cam_pos))
	
	var theme_color: Color
	if is_locked:
		theme_color = Color("ff2844") # Intense radar lock red
		_label.text = "▲ [ ◈ RADAR LOCK · %dM ◈ ] ▲" % dist_m
	else:
		theme_color = Color("ff9f1c") # Acquiring amber
		var prog_bars := ""
		var filled := clampi(roundi(progress * 5.0), 1, 5)
		for i in range(5):
			prog_bars += "■" if i < filled else "·"
		_label.text = "▲ [ SEEKER %s · %dM ] ▲" % [prog_bars, dist_m]
		
	_label.modulate = theme_color

func _process(delta: float) -> void:
	if not visible: return
	if not is_inside_tree() or not is_instance_valid(target_node):
		visible = false
		return
	global_position = target_node.global_position + Vector3.UP * 0.35
	_pulse_t += delta
	
	# Animate expanding radar pulse wave
	var pulse_phase := fmod(_pulse_t * 2.2, 1.0)
	var ring_scale := 0.75 + pulse_phase * 1.15
	_pulse_ring.scale = Vector3(ring_scale, 1.0, ring_scale)
	var alpha_fade := (1.0 - pulse_phase) * (0.85 if is_locked else 0.55)
	
	var col := Color("ff2844") if is_locked else Color("ff9f1c")
	_pulse_mat.albedo_color = Color(col, alpha_fade)
	
	# Rotate radar sweep disc
	_sweep_disc.rotate_y(delta * 5.5)
	var sweep_pulse := 0.25 + 0.15 * sin(_pulse_t * 8.0)
	_sweep_mat.albedo_color = Color(col, sweep_pulse if is_locked else 0.12)
	
	# Pulse holographic hull sphere
	var hull_alpha := 0.22 + 0.12 * sin(_pulse_t * 6.0) if is_locked else (0.08 * lock_progress)
	_fresnel_mat.albedo_color = Color(col, hull_alpha)
