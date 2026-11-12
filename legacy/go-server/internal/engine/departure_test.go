package engine

import (
	"google.golang.org/protobuf/encoding/protowire"
	"google.golang.org/protobuf/proto"
	"testing"
)

func TestDepartureCoalescingRemovesStaleBodiesAndAllowsRejoin(t *testing.T) {
	s := NewGameSession(nil, nil, "p", "r")
	metadata, _ := proto.Marshal(&GameState{MapName: "industrial"})
	entry := protowire.AppendTag(nil, 1, protowire.BytesType)
	entry = protowire.AppendString(entry, "gone")
	entry = protowire.AppendTag(entry, 2, protowire.BytesType)
	entry = protowire.AppendBytes(entry, nil)
	s.enqueueWireSnapshot(metadata, map[string]*PlayerState{"gone": {}}, map[string][]byte{"gone": entry})
	s.enqueuePlayerDeparture("gone")
	s.enqueueWireSnapshot(metadata, nil, nil)
	message := &ServerMessage{}
	if err := proto.Unmarshal(s.takeWireSnapshot(), message); err != nil {
		t.Fatal(err)
	}
	state := message.GetGameState()
	if len(state.Players) != 0 || len(state.RemovedPlayerIds) != 1 || state.RemovedPlayerIds[0] != "gone" {
		t.Fatal("stale pose resurrected a departed player")
	}
	s.enqueuePlayerDeparture("gone")
	s.enqueueWireSnapshot(metadata, map[string]*PlayerState{"gone": {}}, map[string][]byte{"gone": entry})
	proto.Unmarshal(s.takeWireSnapshot(), message)
	if len(message.GetGameState().RemovedPlayerIds) != 0 || message.GetGameState().Players["gone"] == nil {
		t.Fatal("freshly rejoined player removed by old departure")
	}
}
