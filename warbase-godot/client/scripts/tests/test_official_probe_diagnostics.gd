extends SceneTree

const ProbeScript := preload("res://scripts/qa/OfficialProbe.gd")

func _initialize() -> void:
	var probe = ProbeScript.new()
	probe.elapsed = 2.5
	probe._record_phase_error("walking", 1.25, Vector3(1, 2, 3), Vector3.ZERO)
	probe._record_phase_error("walking", 3.0, Vector3(3, 2, 3), Vector3.ZERO)
	probe._record_phase_error("respawn_grace", 0.5, Vector3(0, 1, 0), Vector3.ZERO)
	probe._record_phase_error("driving_vehicle_render", 4.0, Vector3(4, 0, 0), Vector3.ZERO)
	probe._mark_event("vehicle_exited", {"prediction": {"input_pending": 2, "input_ack": 30}})
	var walking: Dictionary = probe.phase_position_errors.get("walking", {})
	var driving: Dictionary = probe.phase_position_errors.get("driving_vehicle_render", {})
	if int(walking.get("count", 0)) != 2 or float(walking.get("max_m", 0.0)) != 3.0:
		push_error("Walking error bucket did not preserve its samples")
		quit(1)
		return
	if int(driving.get("count", 0)) != 1 or int(driving.get("over_2_5m", 0)) != 1:
		push_error("Vehicle render error was not isolated from player walking error")
		quit(1)
		return
	if probe.phase_position_errors.get("respawn_grace", {}).get("count", 0) != 1:
		push_error("Respawn grace bucket was not recorded independently")
		quit(1)
		return
	if probe.event_markers.size() != 1 or probe.event_markers[0].get("event", "") != "vehicle_exited":
		push_error("Event marker was not timestamped")
		quit(1)
		return
	print("OFFICIAL_PROBE_DIAGNOSTICS_OK walk=2 respawn=1 vehicle=1 event=1")
	quit(0)
