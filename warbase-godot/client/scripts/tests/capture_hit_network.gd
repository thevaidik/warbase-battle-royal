extends "res://scripts/net/NetworkManager.gd"
## Test-only network sink for exercising real weapon fire without a socket.

var sent_packets: Array[PackedByteArray] = []

func _send(data: PackedByteArray, _replaceable: bool = false) -> bool:
	sent_packets.append(data)
	return true
