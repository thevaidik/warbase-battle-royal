package main

import (
	"flag"
	"fmt"
	"log"
	"math/rand"
	"net/url"
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
	duration    = flag.Duration("duration", 10*time.Second, "Test duration")
)

func main() {
	flag.Parse()

	log.Printf("=== WARBASE 60-PLAYER + 30-VEHICLE NETCODE STRESS TEST ===")
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
		isDriver := i < 30 // First 30 players are driving vehicles

		go func(id string, driving bool) {
			defer wg.Done()

			u := url.URL{
				Scheme:   "ws",
				Host:     *serverHost,
				Path:     "/connect",
				RawQuery: fmt.Sprintf("user=%s&room=%s&cid=stress_%s", id, *roomID, id),
			}

			conn, _, err := websocket.DefaultDialer.Dial(u.String(), nil)
			if err != nil {
				log.Printf("[%s] Connection failed: %v", id, err)
				return
			}
			defer conn.Close()

			connectedPlayers.Add(1)
			defer connectedPlayers.Add(-1)

			var positionMu sync.Mutex
			var posX, posZ float32
			// Reader loop
			go func() {
				for {
					_, msg, err := conn.ReadMessage()
					if err != nil {
						return
					}
					serverMessage := &engine.ServerMessage{}
					if proto.Unmarshal(msg, serverMessage) == nil {
						positionMu.Lock()
						if respawn := serverMessage.GetServerEvent().GetRespawn(); respawn != nil {
							posX = respawn.X
							posZ = respawn.Z
						}
						if state := serverMessage.GetGameState().GetPlayers()[id]; state != nil {
							dx, dz := state.X-posX, state.Z-posZ
							if dx*dx+dz*dz > 4 {
								posX = state.X
								posZ = state.Z
							}
						}
						positionMu.Unlock()
					}
					totalBytesRecv.Add(int64(len(msg)))
					totalPacketsRecv.Add(1)
				}
			}()

			// Writer loop at 60Hz
			ticker := time.NewTicker(time.Second / 60)
			defer ticker.Stop()

			// Initial position scattered over a 500m map

			speed := float32(18.0) // 65 km/h for vehicles, 6.2 m/s for infantry
			if !driving {
				speed = 6.2
			}

			anim := "run"
			weapon := "ak47"
			if driving {
				anim = "drive"
				weapon = "vehicle"
			}

			for {
				select {
				case <-stopChan:
					return
				case <-ticker.C:
					// Move around
					positionMu.Lock()
					posX += (rand.Float32() - 0.5) * (speed / 60.0)
					posZ += (rand.Float32() - 0.5) * (speed / 60.0)

					event := &engine.ClientEvent{
						Event: &engine.ClientEvent_StateUpdate{
							StateUpdate: &engine.PlayerStateUpdate{
								X:          posX,
								Y:          0.5,
								Z:          posZ,
								Rx:         0,
								Ry:         0,
								Rz:         0,
								Rw:         1.0,
								Animation:  anim,
								PlatformId: "stress_bot",
								Ping:       12,
								WeaponId:   weapon,
							},
						},
					}

					positionMu.Unlock()
					data, err := proto.Marshal(event)
					if err != nil {
						continue
					}

					if err := conn.WriteMessage(websocket.BinaryMessage, data); err != nil {
						return
					}

					totalBytesSent.Add(int64(len(data)))
					totalPacketsSent.Add(1)
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
				log.Printf("Connected Players: %d", connectedPlayers.Load())
				log.Printf("Total Sent: %d packets (%0.2f MB)", totalPacketsSent.Load(), float64(totalBytesSent.Load())/(1024*1024))
				log.Printf("Total Received: %d packets (%0.2f MB)", totalPacketsRecv.Load(), float64(totalBytesRecv.Load())/(1024*1024))
				avgRecvRateKB := (float64(totalBytesRecv.Load()) / elapsed.Seconds()) / 1024.0
				log.Printf("Aggregate Download Throughput: %0.2f KB/s (%0.2f Mbps)", avgRecvRateKB, (avgRecvRateKB*8)/1024)
				log.Printf("Per-Player Download Rate: %0.2f KB/s (%0.2f Mbps)", avgRecvRateKB/float64(*playerCount), ((avgRecvRateKB*8)/1024)/float64(*playerCount))
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
