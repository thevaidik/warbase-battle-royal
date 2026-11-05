package engine

import (
	"bytes"
	"compress/gzip"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"testing"

	"google.golang.org/protobuf/proto"
)

func TestStreamDeliveryRetainsDictionaryAndFrameBoundaries(t *testing.T) {
	s := NewGameSession(nil, nil, "p", "r")
	s.streamCompression.Store(true)
	var source bytes.Buffer
	var reader *gzip.Reader
	var fixtures []map[string]any
	var streamed, independent int
	for frame := 1; frame <= 30; frame++ {
		players := map[string]*PlayerState{}
		for i := 0; i < 64; i++ {
			players[fmt.Sprintf("p%02d", i)] = &PlayerState{X: float32(i) + float32(frame)*.05, Y: 1.2, Z: float32(i % 9), Rw: 1, Health: 100, WeaponId: "ak47", Team: "A", AckInputSequence: uint64(frame)}
		}
		body, _ := proto.Marshal(&ServerMessage{DeliverySequence: uint64(frame), Message: &ServerMessage_GameState{GameState: &GameState{Players: players}}})
		encoded := s.compressFrame(body, uint64(frame))
		streamed += len(encoded)
		independent += len(compressDelivery(body, uint64(frame)))
		envelope := &ServerMessage{}
		if err := proto.Unmarshal(encoded, envelope); err != nil || envelope.CompressionKind != 1 || int(envelope.UncompressedSize) != len(body) {
			t.Fatal("invalid stream frame")
		}
		source.Write(envelope.CompressedPayload)
		if reader == nil {
			var err error
			reader, err = gzip.NewReader(&source)
			if err != nil {
				t.Fatal(err)
			}
			defer reader.Close()
		}
		decoded := make([]byte, len(body))
		if _, err := io.ReadFull(reader, decoded); err != nil || !bytes.Equal(decoded, body) {
			t.Fatalf("stream frame %d corrupt or lost its boundary: %v", frame, err)
		}
		if frame <= 3 {
			fixtures = append(fixtures, map[string]any{"frame": base64.StdEncoding.EncodeToString(encoded), "sequence": frame, "x": float64(players["p00"].X)})
		}
	}
	if streamed >= independent*8/10 {
		t.Fatalf("history did not reduce representative traffic: stream=%d independent=%d", streamed, independent)
	}
	t.Logf("30 frame bytes: stream=%d independent=%d", streamed, independent)
	if path := os.Getenv("WARBASE_STREAM_FIXTURE"); path != "" {
		data, _ := json.Marshal(fixtures)
		if err := os.WriteFile(path, data, 0644); err != nil {
			t.Fatal(err)
		}
	}
	_ = s.compressionStream.writer.Close()
}
