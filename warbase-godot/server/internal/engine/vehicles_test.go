package engine

import (
	"github.com/gorilla/websocket"
	"google.golang.org/protobuf/proto"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func vehicleFixture() (*Match, *Room, *Player) {
	m := NewMatch()
	r := NewRoom("test", "test", "industrial", "FFA")
	floor := []triangle{{vector{-40, 0, -40}, vector{40, 0, -40}, vector{40, 0, 40}}, {vector{-40, 0, -40}, vector{40, 0, 40}, vector{-40, 0, 40}}}
	r.Geometry = &mapGeometry{spawns: []vector{{-3, 0, 0}}, root: buildCollision(floor), vehicleSpawns: [][4]float32{{0, 0, 0, 0}}}
	r.initVehicles()
	m.rooms[r.ID] = r
	i := m.addHuman(r, "driver")
	return m, r, &r.PlayerEntities[i]
}

func TestVehiclePacketsAcrossWebSocket(t *testing.T) {
	m, r, _ := vehicleFixture()
	// Keep population management out of this focused transport protocol fixture.
	for i := 0; i < 7; i++ {
		r.Sessions[NewGameSession(m, nil, string(rune('a'+i)), r.ID)] = true
	}
	go m.Run()
	defer m.Stop()
	upgrader := websocket.Upgrader{}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, request *http.Request) {
		conn, err := upgrader.Upgrade(w, request, nil)
		if err != nil {
			return
		}
		session := NewGameSession(m, conn, "driver", r.ID)
		if m.Register(session) != nil {
			conn.Close()
			return
		}
		go session.StreamUpdatesToPlayer()
		session.ListenForPlayerInputs()
	}))
	defer server.Close()
	client, _, err := websocket.DefaultDialer.Dial("ws"+strings.TrimPrefix(server.URL, "http"), nil)
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()
	send := func(event *ClientEvent) {
		data, _ := proto.Marshal(event)
		if err := client.WriteMessage(websocket.BinaryMessage, data); err != nil {
			t.Fatal(err)
		}
	}
	wait := func(predicate func(*GameState) bool) {
		client.SetReadDeadline(time.Now().Add(3 * time.Second))
		for {
			_, data, err := client.ReadMessage()
			if err != nil {
				t.Fatal(err)
			}
			message := &ServerMessage{}
			if proto.Unmarshal(data, message) != nil {
				continue
			}
			if state := message.GetGameState(); state != nil && predicate(state) {
				return
			}
		}
	}
	send(&ClientEvent{Event: &ClientEvent_VehicleSeat{VehicleSeat: &VehicleSeatEvent{VehicleId: "CAR_0", Enter: true}}})
	wait(func(state *GameState) bool {
		return state.Players["driver"] != nil && state.Players["driver"].DrivingVehicleId == "CAR_0" && state.Vehicles["CAR_0"].Driver == "driver"
	})
	wait(func(state *GameState) bool {
		send(&ClientEvent{Event: &ClientEvent_VehicleInput{VehicleInput: &VehicleInputEvent{Throttle: 1, Gear: 1}}})
		return state.Vehicles["CAR_0"].Z < -1 && state.Players["driver"].Z < -1
	})
	send(&ClientEvent{Event: &ClientEvent_VehicleSeat{VehicleSeat: &VehicleSeatEvent{Enter: false}}})
	wait(func(state *GameState) bool {
		return state.Players["driver"].DrivingVehicleId == "" && state.Vehicles["CAR_0"].Driver == ""
	})
}

func TestVehicleSeatsAndDriving(t *testing.T) {
	m, r, p := vehicleFixture()
	v := r.Vehicles["CAR_0"]
	p.State.X = 20
	if m.enterVehicle(r, p, "CAR_0") {
		t.Fatal("entered distant car")
	}
	p.State.X = -3
	if !m.enterVehicle(r, p, "CAR_0") {
		t.Fatal("could not enter nearby car")
	}
	other := NewPlayer("other")
	other.State.X = -3
	if m.enterVehicle(r, other, "CAR_0") {
		t.Fatal("double occupancy")
	}
	if p.ValidateAndApplyFire() == nil {
		t.Fatal("driver fired infantry weapon")
	}
	v.throttle = 1
	now := time.Now()
	for i := 0; i < 60; i++ {
		v.inputAt = now
		m.advanceVehicles(r, now, 1.0/60)
		now = now.Add(time.Second / 60)
	}
	if v.state.Z >= -1 || v.state.Speed <= 0 || p.State.Z != v.state.Z {
		t.Fatal("authority did not drive and carry player")
	}
	if !m.exitVehicle(r, p) || p.State.DrivingVehicleId != "" || v.state.Driver != "" {
		t.Fatal("safe exit failed")
	}
	if r.vehicleMovementBlocked(position(p), position(p)) {
		t.Fatal("exit placed player inside chassis")
	}
}

func TestVehicleWallCollisionAndInputExpiry(t *testing.T) {
	m, r, p := vehicleFixture()
	wall := []triangle{{vector{-10, 0, -6}, vector{10, 0, -6}, vector{10, 5, -6}}, {vector{-10, 0, -6}, vector{10, 5, -6}, vector{-10, 5, -6}}}
	floor := []triangle{{vector{-40, 0, -40}, vector{40, 0, -40}, vector{40, 0, 40}}, {vector{-40, 0, -40}, vector{40, 0, 40}, vector{-40, 0, 40}}}
	r.Geometry.root = buildCollision(append(floor, wall...))
	if !m.enterVehicle(r, p, "CAR_0") {
		t.Fatal("fixture enter failed")
	}
	v := r.Vehicles["CAR_0"]
	v.throttle = 1
	now := time.Now()
	for i := 0; i < 180; i++ {
		v.inputAt = now
		m.advanceVehicles(r, now, 1.0/60)
		now = now.Add(time.Second / 60)
	}
	if v.state.Z < -3.7 {
		t.Fatalf("chassis crossed wall: z=%v", v.state.Z)
	}
	v.throttle = 1
	v.inputAt = now.Add(-time.Second)
	m.advanceVehicles(r, now, 1.0/60)
	if v.throttle != 0 || !v.brake {
		t.Fatal("stale input retained throttle")
	}
}

func TestVehicleDamageAndRespawn(t *testing.T) {
	m, r, p := vehicleFixture()
	v := r.Vehicles["CAR_0"]
	shooter := NewPlayer("shooter")
	shooter.State.X = -5
	if err := shooter.ValidateFireRay(&FireEvent{ShotId: 1, OriginX: -5, OriginY: 1, HitX: -1.2, HitY: 1}); err != nil {
		t.Fatal(err)
	}
	m.hitVehicle(r, shooter, v, 1)
	if v.state.Health != 1178 {
		t.Fatalf("vehicle did not take authoritative damage: %d", v.state.Health)
	}
	m.hitVehicle(r, shooter, v, 1)
	if v.state.Health != 1178 {
		t.Fatal("reused shot on vehicle")
	}
	if !m.enterVehicle(r, p, "CAR_0") {
		t.Fatal("fixture enter failed")
	}
	m.damageVehicle(r, shooter, v, 2000)
	if v.state.Health != 0 || !p.State.IsDead || p.State.DrivingVehicleId != "" {
		t.Fatal("destroyed transport retained live driver")
	}
	m.advanceVehicles(r, time.Now().Add(21*time.Second), 1.0/60)
	if v.state.Health != 1200 || v.state.Driver != "" {
		t.Fatal("vehicle did not respawn")
	}
}

func TestRoomLightingAndRemovedMap(t *testing.T) {
	m := NewMatch()
	for _, info := range m.ListActiveRooms() {
		if info.MapName == "loft" {
			t.Fatal("removed map still advertised")
		}
		if info.TimeOfDay != "dawn" && info.TimeOfDay != "noon" && info.TimeOfDay != "dusk" && info.TimeOfDay != "overcast" {
			t.Fatal("invalid public time preset")
		}
	}
	r := m.CreateRoom("Night test", "arena", "FFA", "night")
	if r.TimeOfDay != "overcast" || r.RandomTime {
		t.Fatal("explicit lighting was not retained")
	}
}
