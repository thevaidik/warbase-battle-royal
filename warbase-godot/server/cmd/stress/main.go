package main

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"math"
	"net/url"
	"os"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gorilla/websocket"
	"google.golang.org/protobuf/proto"
	"warbase-server/internal/engine"
)

var (
	serverHost  = flag.String("host", "localhost:8081", "Server address")
	roomID      = flag.String("room", "industrial-public", "Room to test")
	playerCount = flag.Int("players", 60, "Number of simulated players")
	transport   = flag.String("transport", "wss", "WebSocket scheme; ws only for private server-path diagnostics")
	streaming   = flag.Bool("stream", true, "Negotiate continuous gzip delivery")
	legacy      = flag.Bool("legacy", false, "Disable bounded frame acknowledgement for compatibility testing")
	drivers     = flag.Int("drivers", 8, "Peers seeking authored cars")
	combat      = flag.Bool("combat", true, "Generate fire and grenade traffic")
	output      = flag.String("output", "", "JSON report path")
	duration    = flag.Duration("duration", 10*time.Second, "Test duration")
)

func main() {
	flag.Parse()
	if *playerCount < 1 || *playerCount > 64 || *duration <= 0 || *duration > 30*time.Minute {
		log.Fatal("players must be 1..64 and duration 0..30m")
	}
	var samplesMu sync.Mutex
	var gaps, pings []float64
	var seats, exits, fireDeliveries, explosions, damage, peak, joined, errors atomic.Int64
	var carDistance float64
	var maxSpeed float32
	var drivenCars = map[string]bool{}
	reportPercentile := func(a []float64, p float64) float64 {
		if len(a) == 0 {
			return 0
		}
		sort.Float64s(a)
		return a[int(float64(len(a)-1)*p)]
	}

	log.Printf("=== BOUNDED MATCH TRAFFIC + REAL AUTHORITATIVE VEHICLE INPUT TEST ===")
	log.Printf("Target Host: %s | Room: %s | Simulated Players: %d | Duration: %v", *serverHost, *roomID, *playerCount, *duration)

	var (
		connectedPlayers atomic.Int32
		totalBytesSent   atomic.Int64
		totalBytesRecv   atomic.Int64
		totalPacketsSent atomic.Int64
		totalPacketsRecv atomic.Int64
	)

	var wg sync.WaitGroup
	stopChan := make(chan struct{})

	// Spawn simulated players
	for i := 0; i < *playerCount; i++ {
		wg.Add(1)
		playerID := fmt.Sprintf("BOT_STRESS_%02d", i)
		isDriver := i < *drivers // Eight peers try to reach available authored cars.

		go func(id string, driving bool) {
			defer wg.Done()

			u := url.URL{
				Scheme:   *transport,
				Host:     *serverHost,
				Path:     "/connect",
				RawQuery: fmt.Sprintf("user=%s&room=%s&cid=stress_%s", id, *roomID, id),
			}

			if strings.HasPrefix(*serverHost, "localhost") || strings.HasPrefix(*serverHost, "127.") {
				u.Scheme = "ws"
			}
			dialer := websocket.Dialer{HandshakeTimeout: 15 * time.Second}
			conn, _, err := dialer.Dial(u.String(), nil)
			if err != nil {
				errors.Add(1)
				log.Printf("[%s] Connection failed: %v", id, err)

				return
			}
			defer conn.Close()
			if !*legacy {
				b, _ := proto.Marshal(&engine.ClientEvent{Event: &engine.ClientEvent_DeliveryAck{DeliveryAck: &engine.DeliveryAckEvent{SupportsGzipStream: *streaming}}})
				conn.WriteMessage(websocket.BinaryMessage, b)
			}
			var latestDelivery atomic.Uint64
			var gzipInput bytes.Buffer
			var gzipStream *gzip.Reader

			active := connectedPlayers.Add(1)
			joined.Add(1)
			for old := peak.Load(); int64(active) > old; old = peak.Load() {
				if peak.CompareAndSwap(old, int64(active)) {
					break
				}
			}
			defer connectedPlayers.Add(-1)

			var positionMu sync.Mutex
			var ackedInput uint64
			var posX, posY, posZ float32
			var localX, localZ float32
			var predicted bool
			sentPositions := make(map[uint64][2]float32)
			var seat string
			var dead, ready bool
			var ammo, grenades int32
			cars := map[string]*engine.VehicleState{}
			foes := map[string]*engine.PlayerState{}
			myTeam := ""
			var previousSnapshot time.Time
			carPrevious := map[string]*engine.VehicleState{}
			readerDone := make(chan struct{})
			// Reader loop
			go func() {
				defer close(readerDone)
				for {
					_, msg, err := conn.ReadMessage()
					if err != nil {
						log.Printf("[%s] read ended: %v", id, err)
						return
					}
					serverMessage := &engine.ServerMessage{}
					if proto.Unmarshal(msg, serverMessage) == nil {
						if len(serverMessage.CompressedPayload) > 0 {
							var unpacked []byte
							if serverMessage.CompressionKind == 1 {
								size := int(serverMessage.UncompressedSize)
								if size <= 0 || size > 262144 {
									return
								}
								gzipInput.Write(serverMessage.CompressedPayload)
								if gzipStream == nil {
									gzipStream, err = gzip.NewReader(&gzipInput)
									if err != nil {
										return
									}
									defer gzipStream.Close()
								}
								unpacked = make([]byte, size)
								if _, err = io.ReadFull(gzipStream, unpacked); err != nil {
									return
								}
							} else if serverMessage.CompressionKind == 0 {
								reader, err := gzip.NewReader(bytes.NewReader(serverMessage.CompressedPayload))
								if err != nil {
									return
								}
								unpacked, err = io.ReadAll(io.LimitReader(reader, 262145))
								reader.Close()
								if err != nil || len(unpacked) > 262144 {
									return
								}
							} else {
								return
							}
							serverMessage = &engine.ServerMessage{}
							if proto.Unmarshal(unpacked, serverMessage) != nil {
								return
							}
						}
						if serverMessage.DeliverySequence > latestDelivery.Load() {
							latestDelivery.Store(serverMessage.DeliverySequence)
						}
						positionMu.Lock()
						if respawn := serverMessage.GetServerEvent().GetRespawn(); respawn != nil {
							posX = respawn.X
							posY = respawn.Y
							posZ = respawn.Z
							localX, localZ = posX, posZ
							clear(sentPositions)
						}
						if snapshot := serverMessage.GetGameState(); snapshot != nil {
							if state := snapshot.Players[id]; state != nil {
								posX, posY, posZ = state.X, state.Y, state.Z
								if !predicted || dead || state.IsDead || seat != "" {
									localX, localZ = posX, posZ
									predicted = true
									clear(sentPositions)
								} else if sent, ok := sentPositions[state.AckInputSequence]; ok {
									dx, dz := posX-sent[0], posZ-sent[1]
									if dx*dx+dz*dz > .35*.35 {
										localX += dx
										localZ += dz
									}
								}
								for sequence := range sentPositions {
									if sequence <= state.AckInputSequence {
										delete(sentPositions, sequence)
									}
								}
								ready = true
								dead = state.IsDead
								ammo = state.AmmoCount
								grenades = state.GrenadesRemaining
								ackedInput = state.AckInputSequence
								myTeam = state.Team
								if seat == "" && state.DrivingVehicleId != "" {
									seats.Add(1)
								}
								if seat != "" && state.DrivingVehicleId == "" {
									exits.Add(1)
								}
								seat = state.DrivingVehicleId
							}
							for k, v := range snapshot.Players {
								foes[k] = v
							}
							for k, v := range snapshot.Vehicles {
								cars[k] = v
							}
							samplesMu.Lock()
							if !previousSnapshot.IsZero() {
								gaps = append(gaps, float64(time.Since(previousSnapshot).Microseconds())/1000)
							}
							previousSnapshot = time.Now()
							if id == "BOT_STRESS_00" {
								for k, v := range snapshot.Vehicles {
									if previous := carPrevious[k]; previous != nil {
										dx, dz := v.X-previous.X, v.Z-previous.Z
										carDistance += math.Sqrt(float64(dx*dx + dz*dz))
									}
									carPrevious[k] = v
									maxSpeed = max(maxSpeed, float32(math.Abs(float64(v.Speed))))
									if v.Driver != "" {
										drivenCars[k] = true
									}
								}
							}
							samplesMu.Unlock()
						}
						events := serverMessage.Events
						if event := serverMessage.GetServerEvent(); event != nil {
							events = append(events, event)
						}
						for _, event := range events {
							if pong := event.GetPong(); pong != nil {
								samplesMu.Lock()
								pings = append(pings, float64(time.Now().UnixMilli()-pong.ClientTime))
								samplesMu.Unlock()
							}
							if event.GetFire() != nil {
								fireDeliveries.Add(1)
							}
							if event.GetExplosion() != nil {
								explosions.Add(1)
							}
							if event.GetDamage() != nil {
								damage.Add(1)
							}
						}
						positionMu.Unlock()
					}
					totalBytesRecv.Add(int64(len(msg)))
					totalPacketsRecv.Add(1)
				}
			}()

			// Writer loop at 60Hz
			ticker := time.NewTicker(time.Second / 30)
			defer ticker.Stop()

			// The authority chooses initial spawns; wait for its first state before moving.

			tick := 0
			shotID := uint64(0)
			var driveStarted time.Time
			var lastReload time.Time
			var inputSequence uint64
			lastAck := uint64(0)
			lastStep := time.Now()
			send := func(e *engine.ClientEvent) bool {
				data, err := proto.Marshal(e)
				if err != nil {
					return false
				}
				conn.SetWriteDeadline(time.Now().Add(3 * time.Second))
				if conn.WriteMessage(websocket.BinaryMessage, data) != nil {
					return false
				}
				totalBytesSent.Add(int64(len(data)))
				totalPacketsSent.Add(1)
				return true
			}

			for {
				select {
				case <-stopChan:
					return
				case <-readerDone:
					errors.Add(1)
					return
				case <-ticker.C:
					tick++
					now := time.Now()
					stepSeconds := min(now.Sub(lastStep).Seconds(), .1)
					lastStep = now
					if sequence := latestDelivery.Load(); sequence > lastAck && !(*legacy) {
						if !send(&engine.ClientEvent{Event: &engine.ClientEvent_DeliveryAck{DeliveryAck: &engine.DeliveryAckEvent{Sequence: sequence}}}) {
							return
						}
						lastAck = sequence
					}
					positionMu.Lock()
					if !ready {
						positionMu.Unlock()
						if tick%30 == 1 {
							send(&engine.ClientEvent{Event: &engine.ClientEvent_StateUpdate{StateUpdate: &engine.PlayerStateUpdate{Y: 1, Rw: 1, Animation: "idle", WeaponId: "ak47"}}})
						}
						continue
					}
					x, y, z := localX, posY, localZ
					seated, isDead, mag, remaining := seat, dead, ammo, grenades
					inputReady := *legacy || inputSequence-ackedInput < 8
					target := ""
					best := float32(1e9)
					var vx, vz float32
					if driving {
						for k, v := range cars {
							if v.Driver != "" || v.Health <= 0 {
								continue
							}
							d := (v.X-x)*(v.X-x) + (v.Z-z)*(v.Z-z)
							if d < best {
								target = k
								best = d
								vx = v.X
								vz = v.Z
							}
						}
					}
					fireTarget := ""
					aim := [3]float32{}
					closest := float32(45 * 45)
					for other, peer := range foes {
						if other == id || !strings.HasPrefix(other, "BOT_STRESS_") || peer.IsDead || peer.Team == myTeam {
							continue
						}
						dx, dz := peer.X-x, peer.Z-z
						if dist := dx*dx + dz*dz; dist < closest {
							closest = dist
							fireTarget = other
							aim = [3]float32{peer.X, peer.Y + 1, peer.Z}
						}
					}
					positionMu.Unlock()
					if tick%30 == 0 {
						if !send(&engine.ClientEvent{Event: &engine.ClientEvent_Ping{Ping: &engine.PingEvent{ClientTime: time.Now().UnixMilli()}}}) {
							return
						}
					}
					if isDead {
						if tick%30 == 0 {
							send(&engine.ClientEvent{Event: &engine.ClientEvent_RespawnRequest{RespawnRequest: &engine.RespawnRequestEvent{}}})
						}
						continue
					}
					if seated != "" {
						if driveStarted.IsZero() {
							driveStarted = time.Now()
						}
						seconds := time.Since(driveStarted).Seconds()
						throttle := float32(1)
						if int(seconds/8)%3 == 2 {
							throttle = -0.5
						}
						if !inputReady {
							continue
						}
						inputSequence++
						if !send(&engine.ClientEvent{Event: &engine.ClientEvent_VehicleInput{VehicleInput: &engine.VehicleInputEvent{InputSequence: inputSequence, Throttle: throttle, Steer: float32(math.Sin(seconds*.5) * .3), Gear: 1 + int32(int(seconds/10)%2)}}}) {
							return
						}
						if seconds > 25 && tick%30 == 0 {
							send(&engine.ClientEvent{Event: &engine.ClientEvent_VehicleSeat{VehicleSeat: &engine.VehicleSeatEvent{Enter: false}}})
						}
						continue
					}
					driveStarted = time.Time{}
					dx, dz := float32(math.Cos(float64(tick)/90)), float32(math.Sin(float64(tick)/90))
					if target != "" {
						dist := float32(math.Sqrt(float64(best)))
						if dist > .1 {
							dx = (vx - x) / dist
							dz = (vz - z) / dist
						}
						if dist < 4.5 && tick%20 == 0 {
							send(&engine.ClientEvent{Event: &engine.ClientEvent_VehicleSeat{VehicleSeat: &engine.VehicleSeatEvent{VehicleId: target, Enter: true}}})
						}
					}
					positionMu.Lock()
					localX += dx * float32(4.5*stepSeconds)
					localZ += dz * float32(4.5*stepSeconds)
					x, z = localX, localZ
					positionMu.Unlock()
					if inputReady {
						inputSequence++
						positionMu.Lock()
						sentPositions[inputSequence] = [2]float32{x, z}
						positionMu.Unlock()
						if !send(&engine.ClientEvent{Event: &engine.ClientEvent_StateUpdate{StateUpdate: &engine.PlayerStateUpdate{InputSequence: inputSequence, X: x, Y: y, Z: z, Rw: 1, Animation: "run", PlatformId: "bounded_qa", WeaponId: "ak47"}}}) {
							return
						}
					}
					if *combat && tick%6 == 0 {
						if mag == 0 && time.Since(lastReload) > 2500*time.Millisecond {
							lastReload = time.Now()
							send(&engine.ClientEvent{Event: &engine.ClientEvent_Reload{Reload: &engine.ReloadEvent{}}})
						} else if mag > 0 {
							shotID++
							send(&engine.ClientEvent{Event: &engine.ClientEvent_Fire{Fire: &engine.FireEvent{OriginX: x, OriginY: y + 1.6, OriginZ: z, HitX: aim[0], HitY: aim[1], HitZ: aim[2], ShotId: shotID}}})
							if fireTarget != "" {
								send(&engine.ClientEvent{Event: &engine.ClientEvent_Hit{Hit: &engine.HitEvent{TargetId: fireTarget, Damage: 25, ShotId: shotID}}})
							}
						}
					}
					if *combat && tick%600 == 0 && remaining > 0 {
						send(&engine.ClientEvent{Event: &engine.ClientEvent_ThrowGrenade{ThrowGrenade: &engine.ThrowGrenadeEvent{Px: x, Py: y + 1.6, Pz: z, Vx: dx * 15, Vy: 9, Vz: dz * 15, ThrowableId: "frag"}}})
					}

				}
			}
		}(playerID, isDriver)

		time.Sleep(20 * time.Millisecond) // Stagger connection ramp-up
	}

	log.Printf("All %d simulated players connecting...", *playerCount)

	// Sample metrics every second
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	startTime := time.Now()
	var lastSent, lastRecv int64
	var lastPktSent, lastPktRecv int64

	for {
		select {
		case <-ticker.C:
			elapsed := time.Since(startTime)
			if elapsed >= *duration {
				close(stopChan)
				wg.Wait()

				log.Printf("=== FINAL AUDIT RESULTS ===")
				log.Printf("Total Duration: %v", elapsed)
				log.Printf("Peak Players: %d; joined=%d; errors=%d", peak.Load(), joined.Load(), errors.Load())
				log.Printf("Total Sent: %d packets (%0.2f MB)", totalPacketsSent.Load(), float64(totalBytesSent.Load())/(1024*1024))
				log.Printf("Total Received: %d packets (%0.2f MB)", totalPacketsRecv.Load(), float64(totalBytesRecv.Load())/(1024*1024))
				avgRecvRateKB := (float64(totalBytesRecv.Load()) / elapsed.Seconds()) / 1024.0
				log.Printf("Aggregate Download Throughput: %0.2f KB/s (%0.2f Mbps)", avgRecvRateKB, (avgRecvRateKB*8)/1024)
				log.Printf("Per-Player Download Rate: %0.2f KB/s (%0.2f Mbps)", avgRecvRateKB/float64(*playerCount), ((avgRecvRateKB*8)/1024)/float64(*playerCount))
				samplesMu.Lock()
				report := map[string]any{"host": *serverHost, "room": *roomID, "requested_peers": *playerCount, "peak_peers": peak.Load(), "joined": joined.Load(), "connection_errors": errors.Load(), "snapshot_gap_ms_p50": reportPercentile(gaps, .5), "snapshot_gap_ms_p95": reportPercentile(gaps, .95), "snapshot_gap_ms_p99": reportPercentile(gaps, .99), "snapshot_gap_ms_max": reportPercentile(gaps, 1), "ping_ms_p50": reportPercentile(pings, .5), "ping_ms_p95": reportPercentile(pings, .95), "ping_ms_max": reportPercentile(pings, 1), "confirmed_seat_entries": seats.Load(), "confirmed_seat_exits": exits.Load(), "driven_cars": len(drivenCars), "car_distance_m": carDistance, "max_car_speed_mps": maxSpeed, "replicated_fire_deliveries": fireDeliveries.Load(), "replicated_explosion_deliveries": explosions.Load(), "replicated_damage_deliveries": damage.Load(), "received_bytes": totalBytesRecv.Load(), "sent_bytes": totalBytesSent.Load(), "hold_seconds": elapsed.Seconds()}
				samplesMu.Unlock()
				data, _ := json.MarshalIndent(report, "", "  ")
				fmt.Println(string(data))
				if *output != "" {
					os.WriteFile(*output, append(data, '\n'), 0644)
				}
				return
			}

			curSent := totalBytesSent.Load()
			curRecv := totalBytesRecv.Load()
			curPktSent := totalPacketsSent.Load()
			curPktRecv := totalPacketsRecv.Load()

			sentDeltaKB := float64(curSent-lastSent) / 1024.0
			recvDeltaKB := float64(curRecv-lastRecv) / 1024.0
			pktSentDelta := curPktSent - lastPktSent
			pktRecvDelta := curPktRecv - lastPktRecv

			lastSent = curSent
			lastRecv = curRecv
			lastPktSent = curPktSent
			lastPktRecv = curPktRecv

			log.Printf("[T+%02ds] Active: %d | Up: %0.1f KB/s (%d pkts) | Down: %0.1f KB/s (%0.2f Mbps, %d pkts) | Per-Player Down: %0.1f KB/s",
				int(elapsed.Seconds()),
				connectedPlayers.Load(),
				sentDeltaKB,
				pktSentDelta,
				recvDeltaKB,
				(recvDeltaKB*8)/1024,
				pktRecvDelta,
				recvDeltaKB/float64(max(1, connectedPlayers.Load())),
			)
		}
	}
}
