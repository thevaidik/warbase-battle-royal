package engine

import (
	"hash/fnv"
	"sync"

	"google.golang.org/protobuf/proto"
)

const (
	// Area of Interest (AOI) squared distance thresholds (in meters²)
	NearDistSq = 75.0 * 75.0   // <= 75m: Full 30Hz tick replication (combat / auditory zone)
	MidDistSq  = 220.0 * 220.0 // 75m - 220m: 10Hz tick replication (medium engagement zone)
	// > 220m: 3Hz tick replication (horizon / strategic zone)

	// Movement dormancy threshold (squared meters)
	// If a player moves less than 5cm, their position is considered stationary
	StationaryMoveSq = 0.05 * 0.05
)

// ReplicationManager handles spatial partitioning, Area of Interest (AOI) culling,
// frequency throttling, and tailored message encoding.
type ReplicationManager struct {
	tickCount uint64
	mu        sync.Mutex
}

func NewReplicationManager() *ReplicationManager {
	return &ReplicationManager{}
}

// hashID produces a deterministic 64-bit hash of an entity ID to phase-interleave updates across ticks
func hashID(id string) uint64 {
	h := fnv.New64a()
	h.Write([]byte(id))
	return h.Sum64()
}

// BroadcastRoomState partitions entities per session based on spatial proximity and priority
func (rm *ReplicationManager) BroadcastRoomState(room *Room) {
	rm.mu.Lock()
	rm.tickCount++
	currentTick := rm.tickCount
	rm.mu.Unlock()

	// If 4 or fewer players in room, send full snapshot to all (negligible bandwidth)
	numPlayers := len(room.PlayerEntities)
	if numPlayers <= 4 {
		room.CachedServerMsg.Message = &ServerMessage_GameState{
			GameState: room.CachedGameState,
		}
		stateData, err := proto.Marshal(room.CachedServerMsg)
		if err == nil {
			for session := range room.Sessions {
				session.EnqueueStateUpdate(stateData)
			}
		}
		return
	}

	// For 5+ players (up to 60 players + 30 vehicles):
	// Iterate through each session and build a tailored Area of Interest (AOI) snapshot
	for session := range room.Sessions {
		viewerID := session.PlayerID

		// Find viewer's entity (if any)
		var viewer *Player
		vIdx, hasV := room.PlayerIndices[viewerID]
		if hasV && vIdx < len(room.PlayerEntities) {
			viewer = &room.PlayerEntities[vIdx]
		}

		// Prepare tailored player map for this viewer
		tailoredPlayers := make(map[string]*PlayerState, 32)

		if viewer == nil {
			// Spectator or loading client: sample a subset of players
			for i := range room.PlayerEntities {
				p := &room.PlayerEntities[i]
				pHash := hashID(p.ID)
				if (currentTick+pHash)%3 == 0 {
					tailoredPlayers[p.ID] = p.State
				}
			}
		} else {
			vX := viewer.State.X
			vZ := viewer.State.Z

			for i := range room.PlayerEntities {
				target := &room.PlayerEntities[i]

				// 1. Viewer always receives their own latest authoritative state
				if target.ID == viewerID {
					tailoredPlayers[target.ID] = target.State
					continue
				}

				// 2. Compute 2D horizontal distance squared
				dx := target.State.X - vX
				dz := target.State.Z - vZ
				distSq := dx*dx + dz*dz

				// 3. Check if target is stationary (camped or parked vehicle)
				isMoving := false
				moveDeltaSq := (target.State.X-target.LastX)*(target.State.X-target.LastX) +
					(target.State.Y-target.LastY)*(target.State.Y-target.LastY) +
					(target.State.Z-target.LastZ)*(target.State.Z-target.LastZ)
				if moveDeltaSq > StationaryMoveSq || target.State.Animation != target.LastAnim || target.IsReloading || target.State.IsDead {
					isMoving = true
				}

				tHash := hashID(target.ID)

				// 4. Multi-tiered Area of Interest replication logic
				shouldInclude := false

				if distSq <= NearDistSq {
					// NEAR TIER (< 75m):
					// Active players -> 30 Hz (every tick)
					// Stationary players -> 10 Hz (every 3rd tick)
					if isMoving {
						shouldInclude = true
					} else {
						shouldInclude = (currentTick+tHash)%3 == 0
					}
				} else if distSq <= MidDistSq {
					// MID TIER (75m - 220m):
					// Active players -> 10 Hz (every 3rd tick)
					// Stationary players -> 2 Hz (every 30th tick keepalive)
					if isMoving {
						shouldInclude = (currentTick+tHash)%3 == 0
					} else {
						shouldInclude = (currentTick+tHash)%15 == 0
					}
				} else {
					// FAR TIER (> 220m):
					// Active players -> 3 Hz (every 10th tick)
					// Stationary players -> 1 Hz (every 30th tick keepalive)
					if isMoving {
						shouldInclude = (currentTick+tHash)%10 == 0
					} else {
						shouldInclude = (currentTick+tHash)%30 == 0
					}
				}

				if shouldInclude {
					tailoredPlayers[target.ID] = target.State
				}
			}
		}

		// Construct tailored snapshot message
		snapshot := &ServerMessage{
			Message: &ServerMessage_GameState{
				GameState: &GameState{
					Players:    tailoredPlayers,
					RoomMode:   room.Mode,
					RoomState:  room.State,
					ScoreTeamA: room.ScoreTeamA,
					ScoreTeamB: room.ScoreTeamB,
					WinnerId:   room.WinnerID,
					MapName:    room.MapName, ProtocolVersion: 4, TimeOfDay: room.TimeOfDay, Vehicles: room.CachedGameState.Vehicles,
				},
			},
		}

		data, err := proto.Marshal(snapshot)
		if err == nil {
			session.EnqueueStateUpdate(data)
		}
	}

	// Update players' LastX, LastY, LastZ, LastAnim for dormancy tracking in subsequent ticks
	for i := range room.PlayerEntities {
		p := &room.PlayerEntities[i]
		p.LastX = p.State.X
		p.LastY = p.State.Y
		p.LastZ = p.State.Z
		p.LastAnim = p.State.Animation
	}
}
