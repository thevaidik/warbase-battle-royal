package engine

import (
	"log"
	"math"
	"math/rand"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/google/uuid"
	"google.golang.org/protobuf/proto"
)

func isValidFloat32(f float32) bool {
	return !math.IsNaN(float64(f)) && !math.IsInf(float64(f), 0)
}

// Internal server wrapper to identify who sent a raw network packet
type Message struct {
	SenderID string
	RoomID   string
	Data     []byte
}

type Room struct {
	ID              string
	Name            string
	MapName         string
	PlayerEntities  []Player
	PlayerIndices   map[string]int
	CachedGameState *GameState
	CachedServerMsg *ServerMessage
	playerCount     atomic.Int32
	Sessions        map[*GameSession]bool
	EmptySince      time.Time
	IsPermanent     bool
	Mode            string
	State           string
	ScoreTeamA      int32
	ScoreTeamB      int32
	WinnerID        string
	StateTimer      time.Time
}

func NewRoom(id string, name string, mapName string, mode string) *Room {
	return &Room{
		ID:              id,
		Name:            name,
		MapName:         mapName,
		Mode:            mode,
		State:           "PLAYING",
		PlayerEntities:  make([]Player, 0, 128),
		PlayerIndices:   make(map[string]int),
		CachedGameState: &GameState{Players: make(map[string]*PlayerState), RoomMode: mode, RoomState: "PLAYING"},
		CachedServerMsg: &ServerMessage{},
		Sessions:        make(map[*GameSession]bool),
		EmptySince:      time.Now(),
	}
}

type RespawnRequest struct {
	PlayerID string
	RoomID   string
}

// Match maintains the set of active game sessions and orchestrates the game loop.
type Match struct {
	sessions    map[*GameSession]bool // Plain English: Tracking active player sessions
	rooms       map[string]*Room
	roomsMutex  sync.RWMutex
	broadcast   chan Message
	register      chan *GameSession
	unregister    chan *GameSession
	activePlayers atomic.Int32
}

func NewMatch() *Match {
	m := &Match{
		broadcast:   make(chan Message),
		register:    make(chan *GameSession),
		unregister:  make(chan *GameSession),
		sessions:    make(map[*GameSession]bool),
		rooms:       make(map[string]*Room),
	}
	m.seedDefaultRoomsLocked()
	return m
}

func (m *Match) seedDefaultRoomsLocked() {
	defaults := []struct {
		id, name, mapName, mode string
	}{
		{"industrial-public", "Industrial Zone (Public)", "industrial", "TDM"},
		{"village-public", "Village Outpost (Public)", "village", "FFA"},
		{"arena-public", "Game Arena (Public)", "arena", "FFA"},
	}
	for _, d := range defaults {
		if _, exists := m.rooms[d.id]; !exists {
			r := NewRoom(d.id, d.name, d.mapName, d.mode)
			r.IsPermanent = true
			m.rooms[d.id] = r
		}
	}
}

type RoomInfo struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	MapName    string `json:"map"`
	Mode       string `json:"mode"`
	PlayerCount int   `json:"playerCount"`
}

func (m *Match) CreateRoom(name string, mapName string, mode string) *Room {
	id := uuid.New().String()
	if mode == "" {
		mode = "FFA"
	}
	room := NewRoom(id, name, mapName, mode)
	
	m.roomsMutex.Lock()
	m.rooms[id] = room
	m.roomsMutex.Unlock()
	
	return room
}

func (m *Match) ListActiveRooms() []RoomInfo {
	m.roomsMutex.Lock()
	m.seedDefaultRoomsLocked()
	m.roomsMutex.Unlock()

	m.roomsMutex.RLock()
	defer m.roomsMutex.RUnlock()
	
	rooms := make([]RoomInfo, 0, len(m.rooms))
	for _, room := range m.rooms {
		rooms = append(rooms, RoomInfo{
			ID:          room.ID,
			Name:        room.Name,
			MapName:     room.MapName,
			Mode:        room.Mode,
			PlayerCount: int(room.playerCount.Load()),
		})
	}
	
	// Sort rooms consistently: by PlayerCount descending, then Name ascending
	sort.Slice(rooms, func(i, j int) bool {
		if rooms[i].PlayerCount != rooms[j].PlayerCount {
			return rooms[i].PlayerCount > rooms[j].PlayerCount
		}
		return rooms[i].Name < rooms[j].Name
	})
	
	return rooms
}

func (m *Match) getRoom(roomID string) (*Room, bool) {
	m.roomsMutex.RLock()
	defer m.roomsMutex.RUnlock()
	room, ok := m.rooms[roomID]
	return room, ok
}

// GetTotalActivePlayers returns the number of players actively connected to the game loop
func (m *Match) GetTotalActivePlayers() int {
	return int(m.activePlayers.Load())
}

// IsUsernameTaken checks if a username is currently connected to a specific room
func (m *Match) IsUsernameTaken(roomID, username string) bool {
	m.roomsMutex.RLock()
	defer m.roomsMutex.RUnlock()
	room, ok := m.rooms[roomID]
	if !ok {
		return false
	}
	// Check if this username is in the room's PlayerIndices map (which tracks active entities)
	// We do this instead of iterating sessions for O(1) speed.
	_, taken := room.PlayerIndices[username]
	return taken
}

// Exported methods to allow external HTTP handlers to interact with the Match
func (m *Match) Register(s *GameSession) {
	m.register <- s
}

func (m *Match) Unregister(s *GameSession) {
	m.unregister <- s
}

func (m *Match) Broadcast(msg Message) {
	m.broadcast <- msg
}

// Helper to send events without re-locking
func (m *Match) sendDirectEventLocked(room *Room, playerID string, event *ServerMessage) {
	if outData, err := proto.Marshal(event); err == nil {
		for session := range room.Sessions {
			if session.PlayerID == playerID {
				select {
				case session.outputQueue <- outData:
				default:
				}
				break
			}
		}
	}
}

func (m *Match) Run() {
	defer func() {
		if err := recover(); err != nil {
			log.Printf("CRITICAL PANIC in Match.Run(): %v", err)
		}
	}()
	// Your friend upgraded the tick rate to 60Hz!
	ticker := time.NewTicker(time.Second / 60)
	defer ticker.Stop()

	for {
		select {
		case session := <-m.register:
			m.sessions[session] = true
			m.activePlayers.Add(1)
			
			m.roomsMutex.Lock()
			room, ok := m.rooms[session.RoomID]
			if !ok {
				log.Printf("Auto-creating room %s for connecting player %s", session.RoomID, session.PlayerID)
				mapName := "industrial"
				if strings.Contains(strings.ToLower(session.RoomID), "village") {
					mapName = "village"
				} else if strings.Contains(strings.ToLower(session.RoomID), "arena") {
					mapName = "arena"
				}
				roomName := "Custom Match (" + session.RoomID[:min(8, len(session.RoomID))] + ")"
				room = NewRoom(session.RoomID, roomName, mapName, "FFA")
				m.rooms[session.RoomID] = room
			}
			room.Sessions[session] = true
			m.roomsMutex.Unlock()

		case session := <-m.unregister:
			if _, ok := m.sessions[session]; ok {
				delete(m.sessions, session)
				m.activePlayers.Add(-1)
				session.SafeClose()
			}

			// Zombie fix: Always try to delete player state, even if session was forcefully evicted.
			// To avoid fast-reconnect bugs, ensure no other active session has the same ID.
			stillConnected := false
			for s := range m.sessions {
				if s.PlayerID == session.PlayerID && s.RoomID == session.RoomID {
					stillConnected = true
					break
				}
			}
			
			m.roomsMutex.RLock()
			room, ok := m.rooms[session.RoomID]
			m.roomsMutex.RUnlock()
			
			if ok {
				delete(room.Sessions, session)
				
				if !stillConnected {
					idx, pOk := room.PlayerIndices[session.PlayerID]
					if pOk {
						lastIdx := len(room.PlayerEntities) - 1
						if idx != lastIdx {
							// Swap last player into deleted spot
							room.PlayerEntities[idx] = room.PlayerEntities[lastIdx]
							// Update the moved player's index in the map
							room.PlayerIndices[room.PlayerEntities[idx].ID] = idx
						}
						// Pop the last element
						room.PlayerEntities = room.PlayerEntities[:lastIdx]
						delete(room.PlayerIndices, session.PlayerID)
						delete(room.CachedGameState.Players, session.PlayerID)
						room.playerCount.Add(-1)
						
						if room.playerCount.Load() == 0 {
							room.EmptySince = time.Now()
						}
					}
				}
			}

			log.Printf("Player %s disconnected from room %s", session.PlayerID, session.RoomID)

		case message := <-m.broadcast:
			m.roomsMutex.RLock()
			room, ok := m.rooms[message.RoomID]
			m.roomsMutex.RUnlock()
			if !ok {
				continue
			}

			var clientEvent ClientEvent
			if err := proto.Unmarshal(message.Data, &clientEvent); err == nil {

				switch event := clientEvent.Event.(type) {
				case *ClientEvent_StateUpdate:
					// SECURITY FIX: Ignore stateUpdate.ID to prevent spoofing
					idx, ok := room.PlayerIndices[message.SenderID]
					if !ok {
						newPlayer := NewPlayer(message.SenderID)
						// Assign Team for TDM
						if room.Mode == "TDM" {
							teamACount := 0
							teamBCount := 0
							for i := range room.PlayerEntities {
								if room.PlayerEntities[i].State.Team == "A" {
									teamACount++
								} else if room.PlayerEntities[i].State.Team == "B" {
									teamBCount++
								}
							}
							if teamACount <= teamBCount {
								newPlayer.State.Team = "A"
							} else {
								newPlayer.State.Team = "B"
							}
						} else {
							newPlayer.State.Team = "NONE"
						}
						
						room.PlayerEntities = append(room.PlayerEntities, *newPlayer)
						idx = len(room.PlayerEntities) - 1
						room.PlayerIndices[message.SenderID] = idx
						room.CachedGameState.Players[message.SenderID] = room.PlayerEntities[idx].State
						room.playerCount.Add(1)
					}
					player := &room.PlayerEntities[idx]

					if player.State.IsDead {
						player.State.Animation = "death"
					} else {
						// Update client-authoritative values (positions, rotations, anim)
						if isValidFloat32(event.StateUpdate.X) && isValidFloat32(event.StateUpdate.Y) && isValidFloat32(event.StateUpdate.Z) {
							player.State.X = event.StateUpdate.X
							player.State.Y = event.StateUpdate.Y
							player.State.Z = event.StateUpdate.Z
						}
						if isValidFloat32(event.StateUpdate.Rx) && isValidFloat32(event.StateUpdate.Ry) && isValidFloat32(event.StateUpdate.Rz) && isValidFloat32(event.StateUpdate.Rw) {
							player.State.Rx = event.StateUpdate.Rx
							player.State.Ry = event.StateUpdate.Ry
							player.State.Rz = event.StateUpdate.Rz
							player.State.Rw = event.StateUpdate.Rw
						}
						player.State.Animation = event.StateUpdate.Animation
						player.State.PlatformId = event.StateUpdate.PlatformId
						player.State.Ping = event.StateUpdate.Ping
						if event.StateUpdate.WeaponId != "" {
							player.State.WeaponId = event.StateUpdate.WeaponId
						}
					}

				case *ClientEvent_Ping:
					pongMsg := &ServerMessage{
						Message: &ServerMessage_ServerEvent{
							ServerEvent: &ServerEvent{
								Event: &ServerEvent_Pong{
									Pong: &ServerPongEvent{
										ClientTime: event.Ping.ClientTime,
									},
								},
							},
						},
					}
					m.sendDirectEventLocked(room, message.SenderID, pongMsg)

				case *ClientEvent_Hit:
					targetIdx, okTarget := room.PlayerIndices[event.Hit.TargetId]
					shooterIdx, okShooter := room.PlayerIndices[message.SenderID]
					log.Printf("[Room %s] Received Hit: Shooter=%s, Target=%s, Damage=%d", message.RoomID, message.SenderID, event.Hit.TargetId, event.Hit.Damage)

					if okTarget && okShooter {
						target := &room.PlayerEntities[targetIdx]
						shooter := &room.PlayerEntities[shooterIdx]

						if room.Mode == "TDM" && shooter.State.Team == target.State.Team && shooter.State.Team != "NONE" {
							// Friendly fire disabled
							continue
						}

						isKill, err := shooter.ValidateAndApplyHit(target, int(event.Hit.Damage))
						if err != nil {
							log.Printf("Hit Invalid: %s", err.Error())
						}
						if err == nil {
							// Valid hit! Send feedback to shooter
							if isKill {
								// Check win condition
								if room.Mode == "FFA" {
									if shooter.State.Kills >= 30 {
										room.State = "FINISHED"
										room.WinnerID = shooter.ID
										room.StateTimer = time.Now().Add(10 * time.Second)
										room.CachedGameState.RoomState = room.State
										room.CachedGameState.WinnerId = room.WinnerID
									}
								} else if room.Mode == "TDM" {
									if shooter.State.Team == "A" {
										room.ScoreTeamA++
										room.CachedGameState.ScoreTeamA = room.ScoreTeamA
										if room.ScoreTeamA >= 60 {
											room.State = "FINISHED"
											room.WinnerID = "A"
											room.StateTimer = time.Now().Add(10 * time.Second)
											room.CachedGameState.RoomState = room.State
											room.CachedGameState.WinnerId = room.WinnerID
										}
									} else if shooter.State.Team == "B" {
										room.ScoreTeamB++
										room.CachedGameState.ScoreTeamB = room.ScoreTeamB
										if room.ScoreTeamB >= 60 {
											room.State = "FINISHED"
											room.WinnerID = "B"
											room.StateTimer = time.Now().Add(10 * time.Second)
											room.CachedGameState.RoomState = room.State
											room.CachedGameState.WinnerId = room.WinnerID
										}
									}
								}

								// It was a lethal shot
								m.sendDirectEventLocked(room, shooter.ID, &ServerMessage{
									Message: &ServerMessage_ServerEvent{
										ServerEvent: &ServerEvent{
											Event: &ServerEvent_KillConfirmed{},
										},
									},
								})
								// Target's client will send a RespawnRequest in 3 seconds.
							} else {
								// Normal hit
								m.sendDirectEventLocked(room, shooter.ID, &ServerMessage{
									Message: &ServerMessage_ServerEvent{
										ServerEvent: &ServerEvent{
											Event: &ServerEvent_HitConfirmed{},
										},
									},
								})
							}
						} else {
							log.Printf("Hit denied from %s: %v", shooter.ID, err)
						}
					}

				case *ClientEvent_Fire:
					idx, ok := room.PlayerIndices[message.SenderID]
					if ok {
						shooter := &room.PlayerEntities[idx]
						if err := shooter.ValidateAndApplyFire(); err == nil {
							f := event.Fire
							// Valid! Broadcast to everyone else IN THIS ROOM
							fireMsg := &ServerMessage{
								Message: &ServerMessage_ServerEvent{
									ServerEvent: &ServerEvent{
										Event: &ServerEvent_Fire{
											Fire: &ServerFireEvent{
												ShooterId: message.SenderID,
												OriginX:   f.GetOriginX(),
												OriginY:   f.GetOriginY(),
												OriginZ:   f.GetOriginZ(),
												HitX:      f.GetHitX(),
												HitY:      f.GetHitY(),
												HitZ:      f.GetHitZ(),
												NormalX:   f.GetNormalX(),
												NormalY:   f.GetNormalY(),
												NormalZ:   f.GetNormalZ(),
												HitWall:   f.GetHitWall(),
											},
										},
									},
								},
							}
							if outData, err := proto.Marshal(fireMsg); err == nil {
								for session := range room.Sessions {
									if session.PlayerID != message.SenderID {
										select {
										case session.outputQueue <- outData:
										default:
										}
									}
								}
							}
						} else {
							log.Printf("Fire denied from %s: %v", shooter.ID, err)
						}
					}

				case *ClientEvent_Reload:
					idx, ok := room.PlayerIndices[message.SenderID]
					if ok {
						shooter := &room.PlayerEntities[idx]
						if err := shooter.ValidateAndApplyReload(); err != nil {
							log.Printf("Reload denied from %s: %v", shooter.ID, err)
						}
					}

				case *ClientEvent_SwitchWeapon:
					idx, ok := room.PlayerIndices[message.SenderID]
					if ok {
						shooter := &room.PlayerEntities[idx]
						if !shooter.State.IsDead {
							if weapon, wOk := Weapons[event.SwitchWeapon.WeaponId]; wOk {
								shooter.ActiveWeapon = weapon
								shooter.State.WeaponId = event.SwitchWeapon.WeaponId
								if savedAmmo, hasSaved := shooter.AmmoStore[weapon.ID]; hasSaved {
									shooter.AmmoCount = savedAmmo
								} else {
									shooter.AmmoCount = weapon.MagSize
								}
								shooter.IsReloading = false
							}
						}
					}
					
				case *ClientEvent_RespawnRequest:
					idx, ok := room.PlayerIndices[message.SenderID]
					if ok {
						player := &room.PlayerEntities[idx]
						if player.State.IsDead && !player.DeathTime.IsZero() && time.Since(player.DeathTime) >= 2900*time.Millisecond {
							player.State.IsDead = false
							player.State.Health = 100
							player.State.Animation = "idle"
							player.IsReloading = false
							player.AmmoCount = player.ActiveWeapon.MagSize
							player.AmmoStore[player.ActiveWeapon.ID] = player.AmmoCount
							player.DeathTime = time.Time{}

							newX := (rand.Float64() * 6) - 3
							newZ := (rand.Float64() * 6) - 3
							
							player.State.X = float32(newX)
							player.State.Y = 10
							player.State.Z = float32(newZ)

							respawnEvt := &ServerMessage{
								Message: &ServerMessage_ServerEvent{
									ServerEvent: &ServerEvent{
										Event: &ServerEvent_Respawn{
											Respawn: &RespawnEvent{
												X: float32(newX),
												Y: 10,
												Z: float32(newZ),
											},
										},
									},
								},
							}
							m.sendDirectEventLocked(room, message.SenderID, respawnEvt)
						}
					}

				case *ClientEvent_ThrowGrenade:
					// Broadcast to everyone else IN THIS ROOM
					grenadeMsg := &ServerMessage{
						Message: &ServerMessage_ServerEvent{
							ServerEvent: &ServerEvent{
								Event: &ServerEvent_ThrowGrenade{
									ThrowGrenade: &ServerThrowGrenadeEvent{
										ShooterId: message.SenderID,
										Px:        event.ThrowGrenade.Px,
										Py:        event.ThrowGrenade.Py,
										Pz:        event.ThrowGrenade.Pz,
										Vx:        event.ThrowGrenade.Vx,
										Vy:        event.ThrowGrenade.Vy,
										Vz:        event.ThrowGrenade.Vz,
									},
								},
							},
						},
					}
					if outData, err := proto.Marshal(grenadeMsg); err == nil {
						for session := range room.Sessions {
							if session.PlayerID != message.SenderID {
								select {
								case session.outputQueue <- outData:
								default:
								}
							}
						}
					}
				}

			}
		case <-ticker.C:
			// Process each room separately
			now := time.Now()
			var emptyRooms []string

			m.roomsMutex.RLock()
			for _, room := range m.rooms {
				// Mark for GC if non-permanent and empty for 30s
				if !room.IsPermanent && room.playerCount.Load() == 0 && now.Sub(room.EmptySince) > 30*time.Second {
					emptyRooms = append(emptyRooms, room.ID)
					continue
				}

				// Check match state
				if room.State == "FINISHED" && now.After(room.StateTimer) {
					// Reset the match
					room.State = "PLAYING"
					room.ScoreTeamA = 0
					room.ScoreTeamB = 0
					room.WinnerID = ""
					room.CachedGameState.RoomState = room.State
					room.CachedGameState.ScoreTeamA = 0
					room.CachedGameState.ScoreTeamB = 0
					room.CachedGameState.WinnerId = ""

					// Reset all players
					for i := range room.PlayerEntities {
						player := &room.PlayerEntities[i]
						player.State.Kills = 0
						player.State.Deaths = 0
						player.State.Health = 100
						player.State.IsDead = false
						player.State.Animation = "idle"
						player.IsReloading = false
						if player.ActiveWeapon.ID != "" {
							player.AmmoCount = player.ActiveWeapon.MagSize
							player.AmmoStore[player.ActiveWeapon.ID] = player.AmmoCount
						}
						player.DeathTime = time.Time{}

						// Force Respawn
						newX := (rand.Float64() * 6) - 3
						newZ := (rand.Float64() * 6) - 3
						player.State.X = float32(newX)
						player.State.Y = 10
						player.State.Z = float32(newZ)
						
						respawnEvt := &ServerMessage{
							Message: &ServerMessage_ServerEvent{
								ServerEvent: &ServerEvent{
									Event: &ServerEvent_Respawn{
										Respawn: &RespawnEvent{
											X: float32(newX),
											Y: 10,
											Z: float32(newZ),
										},
									},
								},
							},
						}
						m.sendDirectEventLocked(room, player.ID, respawnEvt)
					}
				}

				// Resolve naturally completed reloads
				for i := range room.PlayerEntities {
					player := &room.PlayerEntities[i]
					if player.IsReloading && now.Sub(player.ReloadStart) >= player.ActiveWeapon.ReloadTime {
						player.IsReloading = false
						player.AmmoCount = player.ActiveWeapon.MagSize
						player.AmmoStore[player.ActiveWeapon.ID] = player.AmmoCount
					}
				}

				// Update cached broadcast payload
				room.CachedServerMsg.Message = &ServerMessage_GameState{
					GameState: room.CachedGameState,
				}
				stateData, err := proto.Marshal(room.CachedServerMsg)

				if err == nil {
					// O(1) broadcast: Only iterate over sessions inside this specific room
					for session := range room.Sessions {
						select {
						case session.outputQueue <- stateData:
						default:
							delete(m.sessions, session)
							delete(room.Sessions, session)
							session.SafeClose()
							// Evict from room immediately to prevent zombies
							go m.Unregister(session)
						}
					}
				}
			}
			m.roomsMutex.RUnlock()

			// Perform Garbage Collection of Empty Rooms
			if len(emptyRooms) > 0 {
				m.roomsMutex.Lock()
				for _, id := range emptyRooms {
					room, ok := m.rooms[id]
					// Final check in case someone joined between RUnlock and Lock
					if ok && room.playerCount.Load() == 0 && time.Since(room.EmptySince) > 1*time.Minute {
						delete(m.rooms, id)
						log.Printf("Garbage collected empty room: %s", id)
					}
				}
				m.roomsMutex.Unlock()
			}
		}
	}
}
