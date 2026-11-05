package engine

import (
	"testing"
	"time"
)

func TestDeliveryRTTRejectsFutureMissingAndDuplicateACKs(t *testing.T) {
	s := &GameSession{deliveryStarted: make(chan struct{})}
	base := time.Unix(1_800_000_000, 0)
	s.lastSent.Store(1)
	s.recordSentAt(1, base)

	if s.acknowledgeDeliveryAt(2, base.Add(100*time.Millisecond)) {
		t.Fatal("accepted an ACK for a future frame")
	}
	if s.acknowledgeDeliveryAt(1, base.Add(-time.Millisecond)) {
		t.Fatal("accepted an ACK timestamp earlier than its send timestamp")
	}
	if got := s.rttNanos.Load(); got != 0 {
		t.Fatalf("invalid ACK changed trusted RTT: %s", time.Duration(got))
	}
	if s.lastAck.Load() != 0 {
		t.Fatal("invalid ACK advanced delivery state")
	}

	if !s.acknowledgeDeliveryAt(1, base.Add(100*time.Millisecond)) {
		t.Fatal("valid sent-frame ACK was rejected")
	}
	if got := time.Duration(s.rttNanos.Load()); got != 100*time.Millisecond {
		t.Fatalf("initial RTT = %s, want 100ms", got)
	}
	lastAckAt := s.lastAckAt.Load()
	if s.acknowledgeDeliveryAt(1, base.Add(900*time.Millisecond)) {
		t.Fatal("duplicate ACK was treated as advancing")
	}
	if got := time.Duration(s.rttNanos.Load()); got != 100*time.Millisecond {
		t.Fatalf("duplicate ACK inflated RTT to %s", got)
	}
	if s.lastAckAt.Load() != lastAckAt {
		t.Fatal("duplicate ACK refreshed the delivery timeout")
	}

	missing := &GameSession{deliveryStarted: make(chan struct{})}
	missing.lastSent.Store(1)
	if missing.acknowledgeDeliveryAt(1, base.Add(100*time.Millisecond)) {
		t.Fatal("accepted ACK without a matching sent timestamp")
	}
	if missing.deliveryAware.Load() || missing.lastAck.Load() != 0 {
		t.Fatal("ACK without a timestamp changed delivery state")
	}
}

func TestSentFrameTimestampRingIsBounded(t *testing.T) {
	s := &GameSession{}
	base := time.Unix(1_800_000_000, 0)
	for sequence := uint64(1); sequence <= uint64(len(s.sentFrames)+4); sequence++ {
		s.recordSentAt(sequence, base.Add(time.Duration(sequence)*time.Millisecond))
	}
	if _, ok := s.sentAtFor(1); ok {
		t.Fatal("old timestamp survived ring overwrite")
	}
	if got, ok := s.sentAtFor(5); !ok || !got.Equal(base.Add(5*time.Millisecond)) {
		t.Fatalf("retained timestamp = %v, %t; want frame 5 timestamp", got, ok)
	}
	last := uint64(len(s.sentFrames) + 4)
	if got, ok := s.sentAtFor(last); !ok || !got.Equal(base.Add(time.Duration(last)*time.Millisecond)) {
		t.Fatalf("latest timestamp = %v, %t; want frame %d", got, ok, last)
	}
}

func TestHitRewindWindowUsesTrustedSmoothedRTTAndCaps(t *testing.T) {
	s := &GameSession{deliveryStarted: make(chan struct{})}
	if got := s.hitRewindWindow(10); got != 0 {
		t.Fatalf("window without trusted RTT = %s, want zero", got)
	}
	base := time.Unix(1_800_000_000, 0)
	for i, sample := range []time.Duration{100 * time.Millisecond, 500 * time.Millisecond} {
		sequence := uint64(i + 1)
		s.lastSent.Store(sequence)
		s.recordSentAt(sequence, base)
		if !s.acknowledgeDeliveryAt(sequence, base.Add(sample)) {
			t.Fatalf("valid ACK for sample %d was rejected", i)
		}
	}
	if got := time.Duration(s.rttNanos.Load()); got != 150*time.Millisecond {
		t.Fatalf("smoothed RTT = %s, want 150ms", got)
	}
	for _, tc := range []struct {
		distance float64
		want     time.Duration
	}{
		{35, 280 * time.Millisecond},
		{35.01, 320 * time.Millisecond},
		{120, 320 * time.Millisecond},
		{120.01, 480 * time.Millisecond},
	} {
		if got := s.hitRewindWindowAt(tc.distance, base.Add(501*time.Millisecond)); got != tc.want {
			t.Errorf("window at %.2fm = %s, want %s", tc.distance, got, tc.want)
		}
	}

	capped := &GameSession{deliveryStarted: make(chan struct{})}
	capped.lastSent.Store(1)
	capped.recordSentAt(1, base)
	if !capped.acknowledgeDeliveryAt(1, base.Add(time.Second)) {
		t.Fatal("valid high-RTT ACK was rejected")
	}
	if got := capped.hitRewindWindowAt(500, base.Add(time.Second)); got != 750*time.Millisecond {
		t.Fatalf("far-range rewind window = %s, want capped 750ms", got)
	}
}

func TestHitRewindWindowExpiresWithStaleACK(t *testing.T) {
	s := &GameSession{deliveryStarted: make(chan struct{})}
	base := time.Unix(1_800_000_000, 0)
	s.lastSent.Store(1)
	s.recordSentAt(1, base)
	if !s.acknowledgeDeliveryAt(1, base.Add(100*time.Millisecond)) {
		t.Fatal("valid ACK was rejected")
	}
	if got := s.hitRewindWindowAt(10, base.Add(99*time.Millisecond)); got != 0 {
		t.Fatalf("window before the last ACK timestamp = %s, want zero", got)
	}
	if got := s.hitRewindWindowAt(10, base.Add(100*time.Millisecond+deliveryTimeout)); got != 0 {
		t.Fatalf("window for a stale ACK = %s, want zero", got)
	}
}
