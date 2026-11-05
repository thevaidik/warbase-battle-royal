package engine

import (
	"log"
	"time"
)

// Keep validation intact without allowing denied/repeated input to turn the
// simulation loop into an unbounded synchronous Docker logging workload.
func logRejected(p *Player, kind string, reason error) {
	p.RejectedEvents++
	if time.Since(p.LastValidationLog) < 2*time.Second {
		return
	}
	log.Printf("Validation denied for %s: %s (%v); rejected since last log=%d", p.ID, kind, reason, p.RejectedEvents)
	p.LastValidationLog = time.Now()
	p.RejectedEvents = 0
}
