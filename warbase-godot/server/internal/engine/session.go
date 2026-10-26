package engine

import (
	"log"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gorilla/websocket"
	"google.golang.org/protobuf/proto"
)

const (
	networkWriteWait      = 10 * time.Second
	networkPongWait       = 60 * time.Second
	networkPingPeriod     = (networkPongWait * 9) / 10
	maxNetworkMessageSize = 65536
)

// GameSession acts as the bridge between a physical network connection and the active Match.
type GameSession struct {
	match        *Match
	networkConn  *websocket.Conn
	eventQueue   chan []byte // Direct events (Pong, HitConfirmed, KillConfirmed, Respawn, Fire, Grenade)
	stateQueue   chan []byte // World snapshots (capacity 1, auto-evicting to eliminate bufferbloat)
	PlayerID     string
	RoomID       string
	closeOnce    sync.Once
	pendingState atomic.Pointer[PlayerStateUpdate]
}

// NewGameSession initializes a new websocket client safely
func NewGameSession(match *Match, conn *websocket.Conn, playerID string, roomID string) *GameSession {
	return &GameSession{
		match:       match,
		networkConn: conn,
		eventQueue:  make(chan []byte, 64),
		stateQueue:  make(chan []byte, 1),
		PlayerID:    playerID,
		RoomID:      roomID,
	}
}

func (s *GameSession) SafeClose() {
	s.closeOnce.Do(func() {
		close(s.eventQueue)
		close(s.stateQueue)
	})
}

// EnqueueDirectEvent sends a critical direct event without delay
func (s *GameSession) EnqueueDirectEvent(data []byte) {
	select {
	case s.eventQueue <- data:
	default:
		log.Printf("Warning: event queue full for %s", s.PlayerID)
	}
}

// EnqueueStateUpdate queues the latest world snapshot; if the network loop hasn't sent the previous snapshot,
// the stale snapshot is immediately dropped so latency never builds up!
func (s *GameSession) EnqueueStateUpdate(data []byte) {
	select {
	case s.stateQueue <- data:
	default:
		// Drain stale snapshot
		select {
		case stale := <-s.stateQueue:
			// AOI packets are partial: preserve entities from an unsent packet when coalescing.
			oldMessage, newMessage := &ServerMessage{}, &ServerMessage{}
			if proto.Unmarshal(stale, oldMessage) == nil && proto.Unmarshal(data, newMessage) == nil {
				oldState, newState := oldMessage.GetGameState(), newMessage.GetGameState()
				if oldState != nil && newState != nil {
					if newState.Players == nil {
						newState.Players = make(map[string]*PlayerState)
					}
					for id, state := range oldState.Players {
						if _, exists := newState.Players[id]; !exists {
							newState.Players[id] = state
						}
					}
					if combined, err := proto.Marshal(newMessage); err == nil {
						data = combined
					}
				}
			}
		default:
		}
		// Insert newest snapshot
		select {
		case s.stateQueue <- data:
		default:
		}
	}
}

// ListenForPlayerInputs runs continuously in the background, catching packets from the browser.
func (s *GameSession) ListenForPlayerInputs() {
	defer func() {
		if err := recover(); err != nil {
			log.Printf("Panic in ListenForPlayerInputs for %s: %v", s.PlayerID, err)
		}
		s.match.Unregister(s) // Using exported method to maintain clean boundaries
		s.networkConn.Close()
	}()
	s.networkConn.SetReadLimit(maxNetworkMessageSize)
	s.networkConn.SetReadDeadline(time.Now().Add(networkPongWait))
	s.networkConn.SetPongHandler(func(string) error {
		s.networkConn.SetReadDeadline(time.Now().Add(networkPongWait))
		return nil
	})

	tokens := 180.0
	lastRefill := time.Now()
	for {
		_, message, err := s.networkConn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("network error for player %s: %v", s.PlayerID, err)
			}
			break
		}

		now := time.Now()
		tokens += now.Sub(lastRefill).Seconds() * 120
		if tokens > 180 {
			tokens = 180
		}
		lastRefill = now
		if tokens < 1 {
			return
		}
		tokens--
		// Broadcast to the match using the exported Broadcast method.
		// Note: The text trimming logic was removed per your friend's update.
		event := &ClientEvent{}
		if proto.Unmarshal(message, event) != nil {
			continue
		}
		if state := event.GetStateUpdate(); state != nil {
			s.pendingState.Store(state)
			continue
		}
		s.match.Broadcast(Message{Session: s, SenderID: s.PlayerID, RoomID: s.RoomID, Event: event})
	}
}

// StreamUpdatesToPlayer pushes server state updates back to the browser.
func (s *GameSession) StreamUpdatesToPlayer() {
	ticker := time.NewTicker(networkPingPeriod)
	defer func() {
		if err := recover(); err != nil {
			log.Printf("Panic in StreamUpdatesToPlayer for %s: %v", s.PlayerID, err)
		}
		ticker.Stop()
		s.networkConn.Close()
	}()

	for {
		select {
		case eventMsg, ok := <-s.eventQueue:
			if !ok {
				s.networkConn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			s.networkConn.SetWriteDeadline(time.Now().Add(networkWriteWait))
			if err := s.networkConn.WriteMessage(websocket.BinaryMessage, eventMsg); err != nil {
				return
			}
		case stateMsg, ok := <-s.stateQueue:
			if !ok {
				s.networkConn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			s.networkConn.SetWriteDeadline(time.Now().Add(networkWriteWait))
			if err := s.networkConn.WriteMessage(websocket.BinaryMessage, stateMsg); err != nil {
				return
			}
		case <-ticker.C:
			s.networkConn.SetWriteDeadline(time.Now().Add(networkWriteWait))
			if err := s.networkConn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
