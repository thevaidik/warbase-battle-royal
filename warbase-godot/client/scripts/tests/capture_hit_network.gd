extends "res://scripts/net/NetworkManager.gd"
## Test-only network sink that records semantic weapon events without a socket.

var sent_events: Array[Dictionary] = []

func send_fire(origin: Vector3, hit: Vector3, normal: Vector3, wall: bool, shot_id: int = 0, yaw: float = 0.0, pitch: float = 0.0) -> void:
	sent_events.append({"type": "fire", "origin": origin, "hit": hit, "normal": normal, "wall": wall, "shot_id": shot_id, "yaw": yaw, "pitch": pitch})

func send_hit(target: String, damage: int, shot_id: int = 0, view_time_ms: int = 0) -> void:
	sent_events.append({"type": "hit", "target": target, "damage": damage, "shot_id": shot_id, "view_time_ms": view_time_ms})
