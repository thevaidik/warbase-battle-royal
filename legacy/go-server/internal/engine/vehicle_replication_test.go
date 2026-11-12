package engine

import (
	"fmt"
	"testing"

	"google.golang.org/protobuf/proto"
)

func TestVehicleReplicationBaselineDeltasAndCoalescing(t *testing.T) {
	r := &Room{MapName: "industrial", PlayerIndices: map[string]int{}, Sessions: map[*GameSession]bool{}, CachedGameState: &GameState{Players: map[string]*PlayerState{}, Vehicles: map[string]*VehicleState{}}, CachedServerMsg: &ServerMessage{}}
	for i := 0; i < 5; i++ {
		id := fmt.Sprint(i)
		p := NewPlayer(id)
		r.PlayerIndices[id] = i
		r.PlayerEntities = append(r.PlayerEntities, *p)
		r.CachedGameState.Players[id] = p.State
	}
	r.CachedGameState.Vehicles["a"] = &VehicleState{Id: "a", X: 1, Health: 1200}
	r.CachedGameState.Vehicles["b"] = &VehicleState{Id: "b", X: 2, Health: 1200}
	s := NewGameSession(nil, nil, "0", "test")
	s.acknowledgeDelivery(0)
	r.Sessions[s] = true
	rm := NewReplicationManager()
	read := func(session *GameSession) *GameState {
		t.Helper()
		message := &ServerMessage{}
		if err := proto.Unmarshal(session.takeWireSnapshot(), message); err != nil || message.GetGameState() == nil {
			t.Fatalf("invalid snapshot: %v", err)
		}
		return message.GetGameState()
	}
	rm.BroadcastRoomState(r)
	if len(read(s).Vehicles) != 2 {
		t.Fatal("joining client missing parked cars")
	}
	rm.BroadcastRoomState(r)
	if len(read(s).Vehicles) != 0 {
		t.Fatal("unchanged cars waste every snapshot")
	}
	r.CachedGameState.Vehicles["a"].Driver = "0"
	r.CachedGameState.Vehicles["a"].X = 8
	rm.BroadcastRoomState(r)
	r.CachedGameState.Vehicles["b"].Health = 900
	rm.BroadcastRoomState(r)
	rm.BroadcastRoomState(r) // No new changes must not erase queued updates.
	state := read(s)
	if len(state.Vehicles) != 2 || state.Vehicles["a"].Driver != "0" || state.Vehicles["a"].X != 8 || state.Vehicles["b"].Health != 900 {
		t.Fatal("backpressure lost a movement, seat or damage update")
	}
	late := NewGameSession(nil, nil, "1", "test")
	late.acknowledgeDelivery(0)
	r.Sessions[late] = true
	legacy := NewGameSession(nil, nil, "2", "test")
	r.Sessions[legacy] = true
	rm.BroadcastRoomState(r)
	if len(read(late).Vehicles) != 2 {
		t.Fatal("late join did not receive full vehicle baseline")
	}
	message := &ServerMessage{}
	if err := proto.Unmarshal(<-legacy.stateQueue, message); err != nil || len(message.GetGameState().Vehicles) != 2 {
		t.Fatal("legacy client lost its complete vehicle snapshot")
	}
}
