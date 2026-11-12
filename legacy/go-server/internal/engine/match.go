package engine

import (
	"errors"
	"log"
	"math"
	"math/rand/v2"
	"sort"
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
type registration struct {
	session *GameSession
	result  chan error
}

type Message struct {
	Event    *ClientEvent
	Session  *GameSession
	SenderID string
	RoomID   string
	Data     []byte
}

type Room struct {
	Vehicles           map[string]*serverVehicle
	TimeOfDay          string
	RandomTime         bool
	Bots               map[string]bool
	BotSequence        int
	Navigation         *navigation
	navigationStarted  bool
	preparedNavigation atomic.Pointer[navigation]
	botCount           atomic.Int32
	Grenades           []*serverGrenade
	NextGrenade        uint64
	Geometry           *mapGeometry
	ID                 string
	Name               string
	MapName            string
	PlayerEntities     []Player
	PlayerIndices      map[string]int
	CachedGameState    *GameState
	CachedServerMsg    *ServerMessage
	playerCount        atomic.Int32
	Sessions           map[*GameSession]bool
	EmptySince         time.Time
	IsPermanent        bool
	wasOccupied        bool
	Mode               string
	State              string
	ScoreTeamA         int32
	ScoreTeamB         int32
	WinnerID           string
	StateTimer         time.Time
	ReplicationMgr     *ReplicationManager
}

// Initial joins may need the optional 50 MB map before opening a connection.
func (r *Room) emptyExpired(now time.Time) bool {
	if r.IsPermanent || r.playerCount.Load() > 0 {
		return false
	}
	grace := 5 * time.Minute
	if r.wasOccupied {
		grace = time.Minute
	}
	return now.Sub(r.EmptySince) > grace
}

func NewRoom(id string, name string, mapName string, mode string) *Room {
	room := &Room{
		TimeOfDay: []string{"dawn", "noon", "dusk", "overcast"}[rand.IntN(4)], RandomTime: true,
		Bots:            make(map[string]bool),
		Geometry:        geometryFor(mapName),
		ID:              id,
		Name:            name,
		MapName:         mapName,
		Mode:            mode,
		State:           "PLAYING",
		PlayerEntities:  make([]Player, 0, 128),
		PlayerIndices:   make(map[string]int),
		CachedGameState: &GameState{Players: make(map[string]*PlayerState), RoomMode: mode, RoomState: "PLAYING", MapName: mapName, ProtocolVersion: 5},
		CachedServerMsg: &ServerMessage{},
		Sessions:        make(map[*GameSession]bool),
		EmptySince:      time.Now(),
		ReplicationMgr:  NewReplicationManager(),
	}
	room.initVehicles()
	return room
}

type RespawnRequest struct {
	PlayerID string
	RoomID   string
}

// Match maintains the set of active game sessions and orchestrates the game loop.
type Match struct {
	sessions      map[*GameSession]bool // Plain English: Tracking active player sessions
	rooms         map[string]*Room
	roomsMutex    sync.RWMutex
	broadcast     chan Message
	register      chan registration
	unregister    chan *GameSession
	activePlayers atomic.Int32
	stop          chan struct{}
	done          chan struct{}
	stopOnce      sync.Once
	lastTick      atomic.Int64
	snapshotTick  uint64
}

func NewMatch() *Match {
	m := &Match{
		stop: make(chan struct{}), done: make(chan struct{}),
		broadcast:  make(chan Message, 4096),
		register:   make(chan registration, 128),
		unregister: make(chan *GameSession, 128),
		sessions:   make(map[*GameSession]bool),
		rooms:      make(map[string]*Room),
	}
	m.seedDefaultRoomsLocked()
	return m
}

func (m *Match) seedDefaultRoomsLocked() {
	defaults := []struct {
		id, name, mapName, mode string
	}{
		{"industrial-public", "Industrial Zone (Public)", "industrial", "TDM"},
		{"resoforge-public", "ResoForge Yard (Public)", "resoforge", "TDM"},
		{"football-public", "Football Stadium (Public)", "football", "TDM"},
		{"village-public", "Village Outpost (Public)", "village", "FFA"},
		{"arena-public", "Game Arena (Public)", "arena", "FFA"},
		{"shipment-public", "Shipment (Public)", "shipment", "FFA"},
		{"dust2-public", "Industrial Recon (Public)", "dust2", "FFA"},
		{"canyon-public", "Canyon (Public)", "canyon", "FFA"},
		{"desert_oasis-public", "Desert Oasis (Public)", "desert_oasis", "FFA"},
		{"nuketown-public", "Industrial Outpost (Public)", "nuketown", "FFA"},
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
	ID          string `json:"id"`
	Name        string `json:"name"`
	MapName     string `json:"map"`
	Mode        string `json:"mode"`
	PlayerCount int    `json:"playerCount"`
	BotCount    int    `json:"botCount"`
	Capacity    int    `json:"capacity"`
	TimeOfDay   string `json:"timeOfDay"`
}

func (m *Match) CreateRoom(name string, mapName string, mode string, times ...string) *Room {
	id := uuid.New().String()
	if mode == "" {
		mode = "FFA"
	}
	room := NewRoom(id, name, mapName, mode)
	if len(times) > 0 && times[0] != "" {
		room.TimeOfDay = times[0]
		if room.TimeOfDay == "night" {
			room.TimeOfDay = "overcast"
		}
		room.RandomTime = false
	}

	m.roomsMutex.Lock()
	if len(m.rooms) >= 256 {
		m.roomsMutex.Unlock()
		return nil
	}
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
			PlayerCount: len(room.Sessions),
			BotCount:    int(room.botCount.Load()),
			Capacity:    64,
			TimeOfDay:   room.TimeOfDay,
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
	for session := range room.Sessions {
		if session.PlayerID == username {
			return true
		}
	}
	return false
}

// Exported methods to allow external HTTP handlers to interact with the Match
func (m *Match) Register(s *GameSession) error {
	result := make(chan error, 1)
	select {
	case m.register <- registration{session: s, result: result}:
	case <-m.done:
		return errors.New("server stopped")
	}
	select {
	case err := <-result:
		return err
	case <-m.done:
		return errors.New("server stopped")
	}
}

func (m *Match) Unregister(s *GameSession) {
	select {
	case m.unregister <- s:
	case <-m.done:
	}
}

func (m *Match) Broadcast(msg Message) {
	select {
	case m.broadcast <- msg:
	case <-m.done:
	}
}

// Helper to send events without re-locking
func (m *Match) sendDirectEventLocked(room *Room, playerID string, event *ServerMessage) {
	if outData, err := proto.Marshal(event); err == nil {
		for session := range room.Sessions {
			if session.PlayerID == playerID {
				session.EnqueueDirectEvent(outData)
				break
			}
		}
	}
}

func (m *Match) Healthy() bool { return time.Since(time.Unix(0, m.lastTick.Load())) < 2*time.Second }

func (m *Match) Stop() { m.stopOnce.Do(func() { close(m.stop) }); <-m.done }

func (m *Match) Run() {
	defer close(m.done)
	defer m.lastTick.Store(0)
	m.lastTick.Store(time.Now().UnixNano())
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
		case <-m.stop:
			m.roomsMutex.Lock()
			for session := range m.sessions {
				session.SafeClose()
				if session.networkConn != nil {
					session.networkConn.Close()
				}
			}
			m.roomsMutex.Unlock()
			return
		case request := <-m.register:
			session := request.session

			m.roomsMutex.Lock()
			room, ok := m.rooms[session.RoomID]
			if !ok {
				m.roomsMutex.Unlock()
				request.result <- errors.New("room no longer exists; refresh the room list")
				continue
			}
			if len(m.sessions) >= 1024 || len(room.Sessions) >= 64 {
				m.roomsMutex.Unlock()
				request.result <- errors.New("server or room is full")
				continue
			}
			duplicate := false
			for active := range room.Sessions {
				if active.PlayerID == session.PlayerID {
					duplicate = true
					break
				}
			}
			if duplicate {
				m.roomsMutex.Unlock()
				request.result <- errors.New("username already in use")
				continue
			}
			m.sessions[session] = true
			m.activePlayers.Add(1)
			room.Sessions[session] = true
			m.roomsMutex.Unlock()
			request.result <- nil

		case session := <-m.unregister:
			m.roomsMutex.Lock()
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

			room, ok := m.rooms[session.RoomID]

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
						room.notifyDeparture(session.PlayerID)
						room.playerCount.Add(-1)

						if room.playerCount.Load() == 0 {
							room.EmptySince = time.Now()
						}
					}
				}
			}

			m.roomsMutex.Unlock()
			log.Printf("Player %s disconnected from room %s", session.PlayerID, session.RoomID)

		case message := <-m.broadcast:
			m.processMessage(message)
		case <-ticker.C:
			// Replace obsolete incoming transforms instead of building a seconds-long input backlog.
			m.roomsMutex.RLock()
			inputs := make([]Message, 0, len(m.sessions))
			for session := range m.sessions {
				if state := session.pendingState.Swap(nil); state != nil {
					inputs = append(inputs, Message{Session: session, SenderID: session.PlayerID, RoomID: session.RoomID, Event: &ClientEvent{Event: &ClientEvent_StateUpdate{StateUpdate: state}}})
				}
				if vehicle := session.pendingVehicle.Swap(nil); vehicle != nil {
					inputs = append(inputs, Message{Session: session, SenderID: session.PlayerID, RoomID: session.RoomID, Event: &ClientEvent{Event: &ClientEvent_VehicleInput{VehicleInput: vehicle}}})
				}
			}
			m.roomsMutex.RUnlock()
			for _, input := range inputs {
				m.processMessage(input)
			}
			m.snapshotTick++
			m.lastTick.Store(time.Now().UnixNano())
			// Process each room separately
			now := time.Now()
			var emptyRooms []string

			m.roomsMutex.Lock()
			for _, room := range m.rooms {
				// Preserve newly created rooms while a client downloads its map.
				if room.emptyExpired(now) {
					emptyRooms = append(emptyRooms, room.ID)
					continue
				}

				m.syncBots(room)
				// Skip simulation when no humans are connected
				if len(room.Sessions) == 0 {
					continue
				}

				// Check match state
				if room.State == "FINISHED" && now.After(room.StateTimer) {
					// Reset the match
					room.State = "PLAYING"
					if room.RandomTime {
						room.TimeOfDay = []string{"dawn", "noon", "dusk", "overcast"}[rand.IntN(4)]
					}
					room.ScoreTeamA = 0
					room.ScoreTeamB = 0
					room.WinnerID = ""
					room.CachedGameState.RoomState = room.State
					room.CachedGameState.ScoreTeamA = 0
					room.CachedGameState.ScoreTeamB = 0
					room.CachedGameState.WinnerId = ""

					room.initVehicles()
					// Reset all players
					for i := range room.PlayerEntities {
						player := &room.PlayerEntities[i]
						player.State.Kills = 0
						player.State.Deaths = 0
						m.respawnPlayer(room, player)
					}
				}

				room.CachedGameState.TimeOfDay = room.TimeOfDay
				m.advanceVehicles(room, now, 1.0/60.0)
				m.advanceGrenades(room, 1.0/60.0)
				m.advanceBots(room, now, 1.0/60.0)
				// Resolve naturally completed reloads
				for i := range room.PlayerEntities {
					player := &room.PlayerEntities[i]
					player.advanceRecovery(now, 1.0/60.0)
					if player.IsReloading && now.Sub(player.ReloadStart) >= player.ActiveWeapon.ReloadTime {
						player.IsReloading = false
						player.AmmoCount = player.ActiveWeapon.MagSize
						player.AmmoStore[player.ActiveWeapon.ID] = player.AmmoCount
					}
				}

				for i := range room.PlayerEntities {
					p := &room.PlayerEntities[i]
					p.State.GrenadesRemaining = int32(p.GrenadesRemaining)
					p.State.SpawnProtected = now.Before(p.ProtectedUntil)
					p.State.AmmoCount = int32(p.AmmoCount)
					p.State.IsReloading = p.IsReloading
				}
				// Spatial Area of Interest (AOI) & Tiered Priority Replication
				if m.snapshotTick%3 == 0 {
					room.ReplicationMgr.BroadcastRoomState(room)
				}
			}
			m.roomsMutex.Unlock()

			// Perform Garbage Collection of Empty Rooms
			if len(emptyRooms) > 0 {
				m.roomsMutex.Lock()
				for _, id := range emptyRooms {
					room, ok := m.rooms[id]
					// Final check in case someone joined between RUnlock and Lock
					if ok && room.emptyExpired(time.Now()) {
						delete(m.rooms, id)
						log.Printf("Garbage collected empty room: %s", id)
					}
				}
				m.roomsMutex.Unlock()
			}
		}
	}
}

func (m *Match) processMessage(message Message) {
	m.roomsMutex.Lock()
	room, ok := m.rooms[message.RoomID]
	defer m.roomsMutex.Unlock()
	if !ok {
		return
	}

	if message.Session != nil && !m.sessions[message.Session] {
		return
	}
	for once := true; once; once = false {

		clientEvent := message.Event
		if clientEvent == nil {
			clientEvent = &ClientEvent{}
			if proto.Unmarshal(message.Data, clientEvent) != nil {
				return
			}
		}
		{

			switch event := clientEvent.Event.(type) {
			case *ClientEvent_Loadout:
				l := event.Loadout
				if l == nil {
					continue
				}
				if _, ok := Weapons[l.Primary]; !ok {
					continue
				}
				if _, ok := Weapons[l.Secondary]; !ok || l.Primary == l.Secondary {
					continue
				}
				if l.Throwable != "frag" && l.Throwable != "impact" {
					continue
				}
				idx, exists := room.PlayerIndices[message.SenderID]
				if !exists {
					idx = m.addHuman(room, message.SenderID)
				}
				p := &room.PlayerEntities[idx]
				if p.LoadoutApplied || p.State.LastShotId > 0 {
					continue
				}
				p.SelectedPrimary, p.SelectedSecondary, p.ThrowableID = l.Primary, l.Secondary, l.Throwable
				p.LoadoutApplied = true
				p.ActiveWeapon = Weapons[l.Primary]
				p.State.WeaponId = l.Primary
				p.AmmoCount = p.AmmoStore[l.Primary]
			case *ClientEvent_VehicleSeat:
				if idx, ok := room.PlayerIndices[message.SenderID]; ok && event.VehicleSeat != nil {
					p := &room.PlayerEntities[idx]
					if event.VehicleSeat.Enter {
						m.enterVehicle(room, p, event.VehicleSeat.VehicleId)
					} else {
						m.exitVehicle(room, p)
					}
				}
			case *ClientEvent_VehicleInput:
				if idx, ok := room.PlayerIndices[message.SenderID]; ok && event.VehicleInput != nil {
					p := &room.PlayerEntities[idx]
					input := event.VehicleInput
					p.State.AckInputSequence = max(p.State.AckInputSequence, input.InputSequence)
					if v := room.Vehicles[p.State.DrivingVehicleId]; v != nil && v.state.Driver == p.ID && isValidFloat32(input.Throttle) && isValidFloat32(input.Steer) && math.Abs(float64(input.Throttle)) <= 1 && math.Abs(float64(input.Steer)) <= 1 {
						v.throttle = input.Throttle
						v.steer = input.Steer
						v.brake = input.Brake
						v.inputAt = time.Now()
						v.gear = int(input.Gear)
						if v.gear != 2 {
							v.gear = 1
						}
					}
				}
			case *ClientEvent_StateUpdate:
				// SECURITY FIX: Ignore stateUpdate.ID to prevent spoofing
				idx, ok := room.PlayerIndices[message.SenderID]
				if !ok {
					m.addHuman(room, message.SenderID)
					continue
				}
				player := &room.PlayerEntities[idx]
				player.State.AckInputSequence = max(player.State.AckInputSequence, event.StateUpdate.InputSequence)

				if player.State.IsDead || player.State.DrivingVehicleId != "" {
					continue
				} else {
					// Update positions with speed clamp (anti-teleport + browser stutter recovery)
					if isValidFloat32(event.StateUpdate.X) && isValidFloat32(event.StateUpdate.Y) && isValidFloat32(event.StateUpdate.Z) {
						dx := event.StateUpdate.X - player.State.X
						dy := event.StateUpdate.Y - player.State.Y
						dz := event.StateUpdate.Z - player.State.Z
						dist2 := dx*dx + dy*dy + dz*dz
						now := time.Now()
						elapsed := now.Sub(player.LastMoveTime).Seconds()
						if elapsed > 0.25 {
							elapsed = 0.25
						}
						speed := float32(12)

						player.MoveBudget += speed * float32(elapsed)
						if player.MoveBudget > speed*0.25+0.3 {
							player.MoveBudget = speed*0.25 + 0.3
						}
						player.LastMoveTime = now
						distance := float32(math.Sqrt(float64(dist2)))
						inBounds := math.Abs(float64(event.StateUpdate.X)) <= 1100 && math.Abs(float64(event.StateUpdate.Z)) <= 1100 && event.StateUpdate.Y >= -150 && event.StateUpdate.Y <= 300
						if inBounds && distance <= player.MoveBudget && !room.Geometry.movementBlocked(vector{player.State.X, player.State.Y, player.State.Z}, vector{event.StateUpdate.X, event.StateUpdate.Y, event.StateUpdate.Z}) && !room.vehicleMovementBlocked(position(player), vector{event.StateUpdate.X, event.StateUpdate.Y, event.StateUpdate.Z}) {
							player.MoveBudget -= distance
							player.State.X = event.StateUpdate.X
							player.State.Y = event.StateUpdate.Y
							player.State.Z = event.StateUpdate.Z
						}
					}
					if isValidFloat32(event.StateUpdate.Rx) && isValidFloat32(event.StateUpdate.Ry) && isValidFloat32(event.StateUpdate.Rz) && isValidFloat32(event.StateUpdate.Rw) {
						player.State.Rx = event.StateUpdate.Rx
						player.State.Ry = event.StateUpdate.Ry
						player.State.Rz = event.StateUpdate.Rz
						player.State.Rw = event.StateUpdate.Rw
					}
					switch event.StateUpdate.Animation {
					case "idle", "run", "firing", "firing walk", "jump":
						player.State.Animation = event.StateUpdate.Animation
					default:
						player.State.Animation = "idle"
					}
					if len(event.StateUpdate.PlatformId) <= 24 {
						player.State.PlatformId = event.StateUpdate.PlatformId
					}
					player.State.Ping = event.StateUpdate.Ping

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
				if room.State != "PLAYING" {
					continue
				}
				if v := room.Vehicles[event.Hit.TargetId]; v != nil {
					if idx, ok := room.PlayerIndices[message.SenderID]; ok {
						m.hitVehicle(room, &room.PlayerEntities[idx], v, event.Hit.ShotId)
					}
					continue
				}
				targetIdx, okTarget := room.PlayerIndices[event.Hit.TargetId]
				shooterIdx, okShooter := room.PlayerIndices[message.SenderID]
				// firm: hit without recent fire is spam — require fire window (500ms), unless driving vehicle
				if okShooter {
					shooterTmp := &room.PlayerEntities[shooterIdx]
					isDriving := shooterTmp.State.Animation == "drive" || shooterTmp.State.WeaponId == "vehicle"
					if !isDriving && time.Since(shooterTmp.LastShotTime) > 800*time.Millisecond {
						logRejected(shooterTmp, "hit", errors.New("no recent fire"))
						continue
					}
				}

				if okTarget && okShooter {
					target := &room.PlayerEntities[targetIdx]
					shooter := &room.PlayerEntities[shooterIdx]

					if event.Hit.ShotId != shooter.ShotID || !shooter.PendingHit {
						continue
					}
					if room.Mode == "TDM" && shooter.State.Team == target.State.Team && shooter.State.Team != "NONE" {
						shooter.PendingHit = false
						continue
					}
					hitTime := time.Now()
					shooter.HitViewTime = time.Time{}
					if event.Hit.ViewTimeMs > 0 {
						if event.Hit.ViewTimeMs > uint64(hitTime.UnixMilli()) || shooter.HitRewindWindow <= 0 {
							shooter.PendingHit = false
							continue
						}
						shooter.HitViewTime = time.UnixMilli(int64(event.Hit.ViewTimeMs))
					}
					if shotBlockedByPlayer(room, shooter, target, hitTime) {
						shooter.PendingHit = false
						continue
					}
					previousHealth := target.State.Health
					isKill, err := shooter.validateAndApplyHitAt(target, int(event.Hit.Damage), hitTime)
					if err == nil {
						m.broadcastDamage(room, shooter, target, previousHealth-target.State.Health)
						// Valid hit! Send feedback to shooter
						if isKill {
							m.recordKill(room, shooter)

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
						logRejected(shooter, "hit", err)
					}
				}

			case *ClientEvent_Fire:
				if room.State != "PLAYING" {
					continue
				}
				idx, ok := room.PlayerIndices[message.SenderID]
				if ok {
					shooter := &room.PlayerEntities[idx]
					firing := event.Fire
					if firing == nil {
						continue
					}
					if err := shooter.ValidateFireRay(event.Fire); err == nil {
						f := event.Fire
						// Occluded shots still spend ammo and acknowledge their ID; only damage is rejected.
						origin, end := vector{f.OriginX, f.OriginY, f.OriginZ}, vector{f.HitX, f.HitY, f.HitZ}
						shooter.HitRewindWindow = 0
						shooter.HitViewTime = time.Time{}
						if message.Session != nil {
							shooter.HitRewindWindow = message.Session.hitRewindWindow(float64(distance(origin, end)))
						}
						for _, vehicle := range room.Vehicles {
							if fraction, hit := vehicleRay(vehicle, origin, end); hit && fraction > 0.001 && fraction < 0.999 {
								delta := sub(end, origin)
								for k := range end {
									end[k] = origin[k] + delta[k]*min(1, fraction+0.001)
								}
								f.HitX, f.HitY, f.HitZ = end[0], end[1], end[2]
								shooter.ShotEnd = [3]float32(end)
								f.HitWall = true
							}
						}

						if room.Geometry.blocked(origin, end) {
							shooter.PendingHit = false
							if fraction, normal, hit := room.Geometry.trace(origin, end); hit {
								delta := sub(end, origin)
								f.HitX = origin[0] + delta[0]*fraction
								f.HitY = origin[1] + delta[1]*fraction
								f.HitZ = origin[2] + delta[2]*fraction
								f.NormalX, f.NormalY, f.NormalZ = normal[0], normal[1], normal[2]
								f.HitWall = true
							}
						}
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
								if session.PlayerID != message.SenderID && relevantFire(room, session.PlayerID, f) {
									session.EnqueueDirectEvent(outData)
								}
							}
						}
					} else {
						logRejected(shooter, "fire", err)
					}
				}

			case *ClientEvent_Reload:
				idx, ok := room.PlayerIndices[message.SenderID]
				if ok {
					shooter := &room.PlayerEntities[idx]
					if err := shooter.ValidateAndApplyReload(); err != nil {
						logRejected(shooter, "reload", err)
					}
				}

			case *ClientEvent_SwitchWeapon:
				idx, ok := room.PlayerIndices[message.SenderID]
				if ok {
					shooter := &room.PlayerEntities[idx]
					if !shooter.State.IsDead && shooter.State.DrivingVehicleId == "" {
						if weapon, wOk := Weapons[event.SwitchWeapon.WeaponId]; wOk && (shooter.Bot != nil || weapon.ID == shooter.SelectedPrimary || weapon.ID == shooter.SelectedSecondary) {
							shooter.ActiveWeapon = weapon
							shooter.NextShotTime = shooter.CadenceStore[weapon.ID]
							shooter.DrawUntil = time.Now().Add(220 * time.Millisecond)
							shooter.State.WeaponId = event.SwitchWeapon.WeaponId
							if savedAmmo, hasSaved := shooter.AmmoStore[weapon.ID]; hasSaved {
								shooter.AmmoCount = savedAmmo
							} else {
								shooter.AmmoCount = weapon.MagSize
							}
							shooter.IsReloading = false
							shooter.PendingHit = false
						}
					}
				}

			case *ClientEvent_RespawnRequest:
				idx, ok := room.PlayerIndices[message.SenderID]
				if ok {
					player := &room.PlayerEntities[idx]
					canRespawn := player.State.IsDead && !player.DeathTime.IsZero() && time.Since(player.DeathTime) >= 3*time.Second && room.State == "PLAYING"
					if canRespawn {
						m.respawnPlayer(room, player)
					}
				}

			case *ClientEvent_ThrowGrenade:
				// firm: validate grenade (dead, NaN, distance, rate)
				if idx, ok := room.PlayerIndices[message.SenderID]; ok {
					pl := &room.PlayerEntities[idx]
					if pl.State.IsDead || pl.State.DrivingVehicleId != "" || pl.GrenadesRemaining <= 0 || room.State != "PLAYING" {
						continue
					}
					if !isValidFloat32(event.ThrowGrenade.Px) || !isValidFloat32(event.ThrowGrenade.Py) || !isValidFloat32(event.ThrowGrenade.Pz) || !isValidFloat32(event.ThrowGrenade.Vx) || !isValidFloat32(event.ThrowGrenade.Vy) || !isValidFloat32(event.ThrowGrenade.Vz) {
						continue
					}
					vx, vy, vz := event.ThrowGrenade.Vx, event.ThrowGrenade.Vy, event.ThrowGrenade.Vz
					vlen := vx*vx + vy*vy + vz*vz
					if vlen > 900 { // 30m/s squared
						continue
					}
					if time.Since(pl.LastGrenadeTime) < time.Second {
						continue
					}
					pl.LastGrenadeTime = time.Now()
					// distance from player < 4m
					dx := event.ThrowGrenade.Px - pl.State.X
					dy := event.ThrowGrenade.Py - pl.State.Y
					dz := event.ThrowGrenade.Pz - pl.State.Z
					if dx*dx+dy*dy+dz*dz > 16 {
						continue
					}
					if event.ThrowGrenade.ThrowableId != "" && event.ThrowGrenade.ThrowableId != pl.ThrowableID {
						continue
					}
					if room.Geometry.blocked(eye(pl), vector{event.ThrowGrenade.Px, event.ThrowGrenade.Py, event.ThrowGrenade.Pz}) {
						continue
					}
					event.ThrowGrenade.ThrowableId = pl.ThrowableID
					pl.ProtectedUntil = time.Time{}
					pl.GrenadesRemaining--
				} else {
					continue
				}
				room.NextGrenade++
				grenadeID := room.NextGrenade
				room.Grenades = append(room.Grenades, &serverGrenade{kind: event.ThrowGrenade.ThrowableId, id: grenadeID, owner: message.SenderID, pos: vector{event.ThrowGrenade.Px, event.ThrowGrenade.Py, event.ThrowGrenade.Pz}, velocity: vector{event.ThrowGrenade.Vx, event.ThrowGrenade.Vy, event.ThrowGrenade.Vz}})

				// Broadcast to everyone else IN THIS ROOM
				grenadeMsg := &ServerMessage{
					Message: &ServerMessage_ServerEvent{
						ServerEvent: &ServerEvent{
							Event: &ServerEvent_ThrowGrenade{
								ThrowGrenade: &ServerThrowGrenadeEvent{
									ShooterId:   message.SenderID,
									GrenadeId:   grenadeID,
									ThrowableId: event.ThrowGrenade.ThrowableId,
									Px:          event.ThrowGrenade.Px,
									Py:          event.ThrowGrenade.Py,
									Pz:          event.ThrowGrenade.Pz,
									Vx:          event.ThrowGrenade.Vx,
									Vy:          event.ThrowGrenade.Vy,
									Vz:          event.ThrowGrenade.Vz,
								},
							},
						},
					},
				}
				if outData, err := proto.Marshal(grenadeMsg); err == nil {
					for session := range room.Sessions {
						session.EnqueueDirectEvent(outData)
					}
				}
			}

		}
	}
}

func (m *Match) respawnPlayer(room *Room, p *Player) {
	spawn := vector{0, 1, 0}
	bestDistance := float32(-1)
	// Choose a clear authored spawn farthest from existing opponents.
	if room.Geometry != nil {
		for _, candidate := range room.Geometry.safeSpawnCandidates() {
			if room.vehicleMovementBlocked(candidate, candidate) {
				continue
			}
			if p.Bot != nil && room.Navigation != nil && room.Navigation.nearest(candidate, room.Geometry) < 0 {
				continue
			}
			nearest := float32(math.MaxFloat32)
			for i := range room.PlayerEntities {
				other := &room.PlayerEntities[i]
				if other.ID == p.ID || other.State.IsDead {
					continue
				}
				dx, dz := other.State.X-candidate[0], other.State.Z-candidate[2]
				d := dx*dx + dz*dz
				if d < nearest {
					nearest = d
				}
			}
			if nearest > bestDistance {
				bestDistance = nearest
				spawn = candidate
			}
		}
	}
	p.State.X, p.State.Y, p.State.Z = spawn[0], spawn[1]+0.2, spawn[2]
	if p.State.DrivingVehicleId != "" {
		m.releaseVehicle(room, p)
	}
	p.hitHistory = hitPoseHistory{}
	p.HitRewindWindow = 0
	p.HitViewTime = time.Time{}
	p.animationStart = time.Time{}
	p.animationName = ""
	p.State.AnimationTime = 0
	p.State.Health = 100
	p.State.IsDead = false
	p.State.Animation = "idle"
	p.IsReloading = false
	p.PendingHit = false
	p.DeathTime = time.Time{}
	p.HasSpawned = true
	p.ProtectedUntil = time.Now().Add(2500 * time.Millisecond)
	p.LastDamageTime = time.Now()
	p.RegenRemainder = 0
	p.LastMoveTime = time.Now()
	p.MoveBudget = 1
	p.NextShotTime = time.Time{}
	p.CadenceStore = make(map[string]time.Time)
	p.DrawUntil = time.Now().Add(220 * time.Millisecond)
	p.GrenadesRemaining = 2
	for id, cfg := range Weapons {
		p.AmmoStore[id] = cfg.MagSize
	}
	p.AmmoCount = p.ActiveWeapon.MagSize
	m.sendDirectEventLocked(room, p.ID, &ServerMessage{Message: &ServerMessage_ServerEvent{ServerEvent: &ServerEvent{Event: &ServerEvent_Respawn{Respawn: &RespawnEvent{X: p.State.X, Y: p.State.Y, Z: p.State.Z}}}}})
}

func (m *Match) addHuman(room *Room, id string) int {
	newPlayer := NewPlayer(id)
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
	idx := len(room.PlayerEntities) - 1
	room.PlayerIndices[id] = idx
	room.CachedGameState.Players[id] = room.PlayerEntities[idx].State
	room.playerCount.Add(1)
	room.wasOccupied = true
	m.respawnPlayer(room, &room.PlayerEntities[idx])
	return idx
}
