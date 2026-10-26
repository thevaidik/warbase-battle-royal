package engine

import "google.golang.org/protobuf/proto"

// Cosmetic feedback is authoritative and best-effort; it cannot block simulation
// or displace gameplay with a second damage decision on the client.
func (m *Match) broadcastDamage(room *Room, shooter, target *Player, amount int32) {
	if amount <= 0 {
		return
	}
	p, d := target.LastImpactPoint, target.LastImpactDirection
	message := &ServerMessage{Message: &ServerMessage_ServerEvent{ServerEvent: &ServerEvent{Event: &ServerEvent_Damage{Damage: &DamageEvent{TargetId: target.ID, X: p[0], Y: p[1], Z: p[2], Dx: d[0], Dy: d[1], Dz: d[2], Amount: amount}}}}}
	data, err := proto.Marshal(message)
	if err != nil {
		return
	}
	for session := range room.Sessions {
		if session.PlayerID != shooter.ID && session.PlayerID != target.ID {
			idx, ok := room.PlayerIndices[session.PlayerID]
			if !ok || distance(position(&room.PlayerEntities[idx]), p) > 80 {
				continue
			}
		}
		select {
		case session.eventQueue <- data:
		default:
		}
	}
}
