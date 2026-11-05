package engine

import "google.golang.org/protobuf/encoding/protowire"

func encodedEvent(data []byte) []byte {
	for len(data) > 0 {
		number, kind, n := protowire.ConsumeTag(data)
		if n < 0 {
			return nil
		}
		data = data[n:]
		if number == 2 && kind == protowire.BytesType {
			value, n := protowire.ConsumeBytes(data)
			if n < 0 {
				return nil
			}
			return value
		}
		n = protowire.ConsumeFieldValue(number, kind, data)
		if n < 0 {
			return nil
		}
		data = data[n:]
	}
	return nil
}
func isCosmeticEvent(data []byte) bool {
	event := encodedEvent(data)
	if len(event) == 0 {
		return false
	}
	number, kind, n := protowire.ConsumeTag(event)
	return n > 0 && number == 2 && kind == protowire.BytesType
}

func (s *GameSession) enqueuePlayerDeparture(id string) {
	s.snapshotMu.Lock()
	defer s.snapshotMu.Unlock()
	if s.pendingDepartures == nil {
		s.pendingDepartures = make(map[string]bool)
	}
	// Older clients use their existing TTL cleanup and may never drain this map.
	if len(s.pendingDepartures) >= 256 {
		for old := range s.pendingDepartures {
			delete(s.pendingDepartures, old)
			break
		}
	}
	s.pendingDepartures[id] = true
	delete(s.pendingPlayers, id)
}
func (room *Room) notifyDeparture(id string) {
	for session := range room.Sessions {
		session.enqueuePlayerDeparture(id)
	}
}

func (s *GameSession) enqueueWireSnapshot(metadata []byte, visible map[string]*PlayerState, encoded map[string][]byte, vehicles ...map[string][]byte) {
	s.snapshotMu.Lock()
	defer s.snapshotMu.Unlock()
	if s.pendingPlayers == nil {
		s.pendingPlayers = make(map[string][]byte, len(visible))
	}
	if len(vehicles) > 0 {
		if s.pendingVehicles == nil {
			s.pendingVehicles = make(map[string][]byte)
		}
		for id, entry := range vehicles[0] {
			s.pendingVehicles[id] = entry
		}
	}
	s.pendingMetadata = metadata
	for id := range visible {
		delete(s.pendingDepartures, id)
		if entry, ok := encoded[id]; ok {
			s.pendingPlayers[id] = entry
		}
	}
}
func (s *GameSession) takeWireSnapshot() []byte {
	s.snapshotMu.Lock()
	if s.pendingMetadata == nil {
		s.snapshotMu.Unlock()
		return nil
	}
	players, vehicles, departures, metadata := s.pendingPlayers, s.pendingVehicles, s.pendingDepartures, s.pendingMetadata
	s.pendingPlayers = nil
	s.pendingDepartures = nil
	s.pendingVehicles = nil
	s.pendingMetadata = nil
	s.snapshotMu.Unlock()
	body := make([]byte, 0, len(metadata)+len(players)*90)
	for _, entry := range players {
		body = protowire.AppendTag(body, 1, protowire.BytesType)
		body = protowire.AppendBytes(body, entry)
	}
	for _, entry := range vehicles {
		body = protowire.AppendTag(body, 10, protowire.BytesType)
		body = protowire.AppendBytes(body, entry)
	}
	for id := range departures {
		body = protowire.AppendTag(body, 11, protowire.BytesType)
		body = protowire.AppendString(body, id)
	}
	body = append(body, metadata...)
	outer := protowire.AppendTag(nil, 1, protowire.BytesType)
	return protowire.AppendBytes(outer, body)
}
