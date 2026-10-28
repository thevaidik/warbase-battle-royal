package engine

import (
	"bytes"
	"compress/gzip"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"google.golang.org/protobuf/encoding/protowire"
	"google.golang.org/protobuf/proto"
)

var deliveryCompressors = sync.Pool{New: func() any { w, _ := gzip.NewWriterLevel(nil, gzip.BestSpeed); return w }}

func compressDelivery(data []byte, sequence uint64) []byte {
	if len(data) < 512 {
		return data
	}
	var buffer bytes.Buffer
	compressor := deliveryCompressors.Get().(*gzip.Writer)
	compressor.Reset(&buffer)
	compressor.Write(data)
	compressor.Close()
	deliveryCompressors.Put(compressor)
	if buffer.Len()+32 >= len(data) {
		return data
	}
	wrapped, _ := proto.Marshal(&ServerMessage{DeliverySequence: sequence, CompressedPayload: buffer.Bytes()})
	return wrapped
}

// Four outstanding frames bound shared-uplink queueing across a full room.
// The ordered WebSocket carries one opt-in gzip stream per connection. Keeping
// its dictionary avoids recompressing unchanged fields in every world snapshot.
// Older clients retain independent gzip frames.
type deliveryStream struct {
	output bytes.Buffer
	writer *gzip.Writer
}

func (s *GameSession) compressFrame(data []byte, sequence uint64) []byte {
	if !s.streamCompression.Load() {
		return compressDelivery(data, sequence)
	}
	if s.compressionStream == nil {
		stream := &deliveryStream{}
		stream.writer, _ = gzip.NewWriterLevel(&stream.output, 3)
		s.compressionStream = stream
	}
	stream := s.compressionStream
	stream.output.Reset()
	_, _ = stream.writer.Write(data)
	_ = stream.writer.Flush()
	wrapped, _ := proto.Marshal(&ServerMessage{DeliverySequence: sequence, CompressedPayload: stream.output.Bytes(), CompressionKind: 1, UncompressedSize: uint32(len(data))})
	return wrapped
}

const deliveryWindow = 4
const streamDeliveryWindow = 6
const deliveryTimeout = 5 * time.Second

func (s *GameSession) recordSentAt(sequence uint64, sentAt time.Time) {
	if sequence == 0 {
		return
	}
	s.sentFramesMu.Lock()
	s.sentFrames[sequence%uint64(len(s.sentFrames))] = sentFrameRecord{sequence: sequence, sentAt: sentAt}
	s.sentFramesMu.Unlock()
}

func (s *GameSession) sentAtFor(sequence uint64) (time.Time, bool) {
	if sequence == 0 {
		return time.Time{}, false
	}
	s.sentFramesMu.Lock()
	record := s.sentFrames[sequence%uint64(len(s.sentFrames))]
	s.sentFramesMu.Unlock()
	if record.sequence != sequence || record.sentAt.IsZero() {
		return time.Time{}, false
	}
	return record.sentAt, true
}

// Clients opt in explicitly. Old clients keep their original wire format.
func (s *GameSession) acknowledgeDelivery(sequence uint64) {
	s.acknowledgeDeliveryAt(sequence, time.Now())
}

func (s *GameSession) acknowledgeDeliveryAt(sequence uint64, ackAt time.Time) bool {
	if sequence > s.lastSent.Load() {
		return false
	}
	previous := s.lastAck.Load()
	var sentAt time.Time
	if sequence > previous {
		var ok bool
		sentAt, ok = s.sentAtFor(sequence)
		if !ok || ackAt.Before(sentAt) {
			return false
		}
	}
	if !s.deliveryAware.Load() {
		s.lastAckAt.Store(ackAt.UnixNano())
		if s.deliveryAware.CompareAndSwap(false, true) {
			close(s.deliveryStarted)
		}
	}
	for sequence > previous {
		if s.lastAck.CompareAndSwap(previous, sequence) {
			sample := ackAt.Sub(sentAt)
			if sample > 0 {
				s.updateRTT(sample)
			}
			s.lastAckAt.Store(ackAt.UnixNano())
			return true
		}
		previous = s.lastAck.Load()
	}
	return false
}

func (s *GameSession) updateRTT(sample time.Duration) {
	for previous := s.rttNanos.Load(); ; previous = s.rttNanos.Load() {
		next := int64(sample)
		if previous > 0 {
			next = previous*7/8 + int64(sample)/8
		}
		if s.rttNanos.CompareAndSwap(previous, next) {
			return
		}
	}
}

// hitRewindWindow estimates the server-side rewind budget from validated frame RTT.
func (s *GameSession) hitRewindWindow(distanceMetres float64) time.Duration {
	return s.hitRewindWindowAt(distanceMetres, time.Now())
}

func (s *GameSession) hitRewindWindowAt(distanceMetres float64, now time.Time) time.Duration {
	lastAckNanos := s.lastAckAt.Load()
	if lastAckNanos == 0 {
		return 0
	}
	lastAckAt := time.Unix(0, lastAckNanos)
	if now.Before(lastAckAt) || now.Sub(lastAckAt) >= deliveryTimeout {
		return 0
	}
	rtt := time.Duration(s.rttNanos.Load())
	if rtt <= 0 {
		return 0
	}
	renderDelay := 280 * time.Millisecond
	switch {
	case distanceMetres <= 35:
		renderDelay = 80 * time.Millisecond
	case distanceMetres <= 120:
		renderDelay = 120 * time.Millisecond
	}
	window := rtt + renderDelay + 50*time.Millisecond
	if window > 750*time.Millisecond {
		return 750 * time.Millisecond
	}
	return window
}

func (s *GameSession) deliveryAvailable(now time.Time) bool {
	window := uint64(deliveryWindow)
	if s.streamCompression.Load() {
		window = streamDeliveryWindow
	}
	return s.lastSent.Load()-s.lastAck.Load() < window && now.Sub(time.Unix(0, s.lastAckAt.Load())) < deliveryTimeout
}

// One frame carries the newest snapshot and a bounded batch of events. The
// acknowledgement window also bounds bytes queued inside TCP/proxy buffers,
// where a size-one application snapshot queue cannot remove stale traffic.
func (s *GameSession) nextDeliveryFrame() []byte {
	data := s.takeWireSnapshot()
	if len(data) == 0 {
		select {
		case state, ok := <-s.stateQueue:
			if ok {
				data = append([]byte(nil), state...)
			}
		default:
		}
	}
	count := 0
	for _, queue := range []chan []byte{s.eventQueue, s.cosmeticQueue} {
		for count < 32 {
			select {
			case encoded, ok := <-queue:
				if !ok {
					goto drained
				}
				if event := encodedEvent(encoded); event != nil {
					data = protowire.AppendTag(data, 3, protowire.BytesType)
					data = protowire.AppendBytes(data, event)
					count++
				}
			default:
				goto drained
			}
		}
	drained:
	}
	if len(data) == 0 {
		return nil
	}
	sequence := s.lastSent.Add(1)
	data = protowire.AppendTag(data, 4, protowire.VarintType)
	data = protowire.AppendVarint(data, sequence)
	return s.compressFrame(data, sequence)
}

func (s *GameSession) streamBoundedUpdates() {
	defer func() {
		if s.compressionStream != nil {
			_ = s.compressionStream.writer.Close()
			s.compressionStream = nil
		}
	}()
	s.networkConn.EnableWriteCompression(false) // gzip also serves native clients; avoid double compression.
	ticker := time.NewTicker(time.Second / 20)
	defer ticker.Stop()
	for {
		select {
		case <-s.done:
			return
		case now := <-ticker.C:
			if now.Sub(time.Unix(0, s.lastAckAt.Load())) >= deliveryTimeout {
				s.recordDeliveryFailure("ack_timeout", nil)
				return
			}
			if !s.deliveryAvailable(now) {
				continue
			}
			data := s.nextDeliveryFrame()
			if len(data) == 0 {
				continue
			}
			s.networkConn.SetWriteDeadline(now.Add(2 * time.Second))
			s.recordSentAt(s.lastSent.Load(), time.Now())
			if err := s.networkConn.WriteMessage(websocket.BinaryMessage, data); err != nil {
				s.recordDeliveryFailure("write_failed", err)
				return
			}
		}
	}
}
