package engine

import (
	"bytes"
	"compress/gzip"
	"fmt"
	"google.golang.org/protobuf/encoding/protowire"
	"google.golang.org/protobuf/proto"
	"io"
	"testing"
	"time"
)

func deliveryState(x float32) []byte {
	b, _ := proto.Marshal(&ServerMessage{Message: &ServerMessage_GameState{GameState: &GameState{Players: map[string]*PlayerState{"p": {X: x}}}}})
	return b
}
func TestDeliveryWindowBoundsTransportBacklog(t *testing.T) {
	s := NewGameSession(nil, nil, "p", "r")
	s.acknowledgeDelivery(0)
	for i := 0; i < deliveryWindow; i++ {
		if !s.deliveryAvailable(time.Now()) {
			t.Fatal("window stopped early")
		}
		s.EnqueueStateUpdate(deliveryState(float32(i)))
		s.nextDeliveryFrame()
	}
	if s.deliveryAvailable(time.Now()) {
		t.Fatal("unacknowledged frames can accumulate in transport")
	}
	s.acknowledgeDelivery(999)
	if s.deliveryAvailable(time.Now()) {
		t.Fatal("future acknowledgement bypassed flow control")
	}
	s.acknowledgeDelivery(deliveryWindow)
	if !s.deliveryAvailable(time.Now()) {
		t.Fatal("acknowledgement did not release window")
	}
	for i := 0; i < 200; i++ {
		s.EnqueueStateUpdate(deliveryState(float32(i)))
	}
	frame := &ServerMessage{}
	proto.Unmarshal(s.nextDeliveryFrame(), frame)
	if frame.GetGameState().Players["p"].X != 199 {
		t.Fatal("resuming delivered an old transform")
	}
	s.lastAckAt.Store(time.Now().Add(-6 * time.Second).UnixNano())
	if s.deliveryAvailable(time.Now()) {
		t.Fatal("stalled connection remains playable")
	}
}
func TestDeliveryBatchKeepsCriticalEventsAheadOfCosmetics(t *testing.T) {
	s := NewGameSession(nil, nil, "p", "r")
	s.acknowledgeDelivery(0)
	for i := 0; i < 1000; i++ {
		b, _ := proto.Marshal(&ServerMessage{Message: &ServerMessage_ServerEvent{ServerEvent: &ServerEvent{Event: &ServerEvent_Fire{Fire: &ServerFireEvent{ShooterId: "p"}}}}})
		s.EnqueueDirectEvent(b)
	}
	critical, _ := proto.Marshal(&ServerMessage{Message: &ServerMessage_ServerEvent{ServerEvent: &ServerEvent{Event: &ServerEvent_Respawn{Respawn: &RespawnEvent{X: 42}}}}})
	s.EnqueueDirectEvent(critical)
	s.EnqueueStateUpdate(deliveryState(42))
	frame := &ServerMessage{}
	proto.Unmarshal(s.nextDeliveryFrame(), frame)
	if len(frame.Events) != 32 || frame.Events[0].GetRespawn() == nil || frame.Events[0].GetRespawn().X != 42 {
		t.Fatal("cosmetics crowded out authoritative respawn")
	}
	if frame.GetGameState() == nil {
		t.Fatal("event burst crowded out world state")
	}
	s.SafeClose()
	s.nextDeliveryFrame() // closed queues must not spin forever.
}
func TestSpawnCandidatesSeparateFullRoomAndClearMap(t *testing.T) {
	m := NewMatch()
	r := NewRoom("spawn-test", "Spawn Test", "industrial", "TDM")
	occupied := []vector{}
	for i := 0; i < 64; i++ {
		p := NewPlayer(string(rune('A' + i)))
		r.PlayerEntities = append(r.PlayerEntities, *p)
		m.respawnPlayer(r, &r.PlayerEntities[i])
		at := position(&r.PlayerEntities[i])
		for _, other := range occupied {
			if distance(at, other) < .9 {
				t.Fatalf("spawn %d overlaps an occupied body: %v", i, at)
			}
		}
		occupied = append(occupied, at)
	}
}
func TestProcessedInputAcknowledgementIncludesRejectedMovement(t *testing.T) {
	m, r, s, p := fixture(t)
	initial := p.State.X
	sendTest(m, s, &ClientEvent{Event: &ClientEvent_StateUpdate{StateUpdate: &PlayerStateUpdate{X: 10000, Y: 1, Rw: 1, InputSequence: 17}}})
	if r.PlayerEntities[r.PlayerIndices[s.PlayerID]].State.AckInputSequence != 17 {
		t.Fatal("rejected input never acknowledged")
	}
	if p.State.X != initial {
		t.Fatal("invalid movement accepted")
	}
}

func TestDeliveryCompressionPreservesBatchedEvents(t *testing.T) {
	frame := &ServerMessage{DeliverySequence: 42, Message: &ServerMessage_GameState{GameState: &GameState{Players: map[string]*PlayerState{}}}, Events: []*ServerEvent{{Event: &ServerEvent_Pong{Pong: &ServerPongEvent{ClientTime: 123}}}}}
	for i := 0; i < 64; i++ {
		frame.GetGameState().Players[fmt.Sprintf("peer_%02d", i)] = &PlayerState{X: float32(i), WeaponId: "ak47", Animation: "run", Health: 100, Team: "A"}
	}
	raw, _ := proto.Marshal(frame)
	packed := compressDelivery(raw, 42)
	if len(packed) >= len(raw) {
		t.Fatal("full-room payload was not reduced")
	}
	envelope := &ServerMessage{}
	proto.Unmarshal(packed, envelope)
	reader, err := gzip.NewReader(bytes.NewReader(envelope.CompressedPayload))
	if err != nil {
		t.Fatal(err)
	}
	defer reader.Close()
	decoded, err := io.ReadAll(reader)
	if err != nil {
		t.Fatal(err)
	}
	actual := &ServerMessage{}
	proto.Unmarshal(decoded, actual)
	if !proto.Equal(frame, actual) {
		t.Fatal("compression changed authoritative data")
	}
}

func TestFullRoomCriticalBurstPreservesEveryEvent(t *testing.T) {
	s := NewGameSession(nil, nil, "p", "r")
	s.acknowledgeDelivery(0)
	// A 64-player blast can produce a launch/explosion plus damage or respawn
	// notifications before the next network flush. These must not disappear.
	for i := int64(1); i <= 128; i++ {
		data, _ := proto.Marshal(&ServerMessage{Message: &ServerMessage_ServerEvent{ServerEvent: &ServerEvent{Event: &ServerEvent_Pong{Pong: &ServerPongEvent{ClientTime: i}}}}})
		s.EnqueueDirectEvent(data)
	}
	seen := map[int64]bool{}
	for i := 0; i < 4; i++ {
		message := &ServerMessage{}
		if err := proto.Unmarshal(s.nextDeliveryFrame(), message); err != nil {
			t.Fatal(err)
		}
		if len(message.CompressedPayload) > 0 {
			reader, err := gzip.NewReader(bytes.NewReader(message.CompressedPayload))
			if err != nil {
				t.Fatal(err)
			}
			data, err := io.ReadAll(reader)
			reader.Close()
			if err != nil {
				t.Fatal(err)
			}
			proto.Unmarshal(data, message)
		}
		for _, event := range message.Events {
			seen[event.GetPong().ClientTime] = true
		}
	}
	if len(seen) != 128 {
		t.Fatalf("critical full-room burst lost events: got %d", len(seen))
	}
}

func TestWireSnapshotCoalescesImmutableEntriesWithoutLosingAOI(t *testing.T) {
	s := NewGameSession(nil, nil, "near", "r")
	encode := func(id string, x float32) []byte {
		state, _ := proto.Marshal(&PlayerState{X: x, AckInputSequence: 17})
		entry := protowire.AppendTag(nil, 1, protowire.BytesType)
		entry = protowire.AppendString(entry, id)
		entry = protowire.AppendTag(entry, 2, protowire.BytesType)
		return protowire.AppendBytes(entry, state)
	}
	metadata, _ := proto.Marshal(&GameState{ProtocolVersion: 4, MapName: "industrial"})
	s.enqueueWireSnapshot(metadata, map[string]*PlayerState{"near": {}, "far": {}}, map[string][]byte{"near": encode("near", 1), "far": encode("far", 99)})
	s.enqueueWireSnapshot(metadata, map[string]*PlayerState{"near": {}}, map[string][]byte{"near": encode("near", 2)})
	actual := &ServerMessage{}
	if err := proto.Unmarshal(s.takeWireSnapshot(), actual); err != nil {
		t.Fatal(err)
	}
	state := actual.GetGameState()
	if state.Players["near"].X != 2 || state.Players["far"].X != 99 || state.MapName != "industrial" || state.Players["near"].AckInputSequence != 17 {
		t.Fatal("wire coalescing lost the newest pose, rare AOI entity, metadata, or input acknowledgement")
	}
}
