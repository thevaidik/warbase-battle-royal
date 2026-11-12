extends "res://scripts/net/NetworkManager.gd"

var captured_fire: Dictionary = {}

func send_aim_pitch(_pitch: float) -> void:
	pass

func send_fire(origin: Vector3, hit: Vector3, normal: Vector3, wall: bool, shot_id: int = 0, yaw: float = 0.0, pitch: float = 0.0, _weapon: String = "") -> void:
	captured_fire = {"origin": origin, "hit": hit, "normal": normal, "wall": wall, "shot_id": shot_id, "yaw": yaw, "pitch": pitch}
