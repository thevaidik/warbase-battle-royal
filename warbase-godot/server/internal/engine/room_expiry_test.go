package engine

import (
	"testing"
	"time"
)

func TestEmptyRoomAllowsInitialMapDownload(t *testing.T) {
	now := time.Now()
	r := &Room{EmptySince: now}
	if r.emptyExpired(now.Add(2 * time.Minute)) {
		t.Fatal("room expired during optional map download")
	}
	if !r.emptyExpired(now.Add(6 * time.Minute)) {
		t.Fatal("unused rooms never expire")
	}
	r.wasOccupied = true
	if r.emptyExpired(now.Add(30*time.Second)) || !r.emptyExpired(now.Add(61*time.Second)) {
		t.Fatal("used room cleanup grace incorrect")
	}
	r.playerCount.Store(1)
	if r.emptyExpired(now.Add(time.Hour)) {
		t.Fatal("occupied room expired")
	}
	r.playerCount.Store(0)
	r.IsPermanent = true
	if r.emptyExpired(now.Add(time.Hour)) {
		t.Fatal("public room expired")
	}
}
