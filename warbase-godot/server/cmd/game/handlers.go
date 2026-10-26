package main

import (
	"fmt"
	"math/rand"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
	"warbase-server/internal/engine"

	"github.com/gorilla/websocket"
)

var allowedOrigins = map[string]bool{
	"war.vaidik.blog":    true,
	"war.nxtlap.com":     true,
	"warbase.nxtlap.com": true,
	"localhost:8081":     true,
	"127.0.0.1:8081":     true,
}

var upgrader = websocket.Upgrader{
	ReadBufferSize:  8192,
	WriteBufferSize: 0,
	CheckOrigin: func(r *http.Request) bool {
		origin := r.Header.Get("Origin")
		if origin == "" {
			return true
		} // Native clients do not send browser origins.
		parsed, err := url.Parse(origin)
		if err != nil || (parsed.Scheme != "https" && parsed.Scheme != "http") {
			return false
		}
		return parsed.Host == r.Host || allowedOrigins[parsed.Host]
	},
}

func (app *application) healthcheckHandler(w http.ResponseWriter, r *http.Request) {
	if !app.match.Healthy() {
		app.writeJSON(w, http.StatusServiceUnavailable, envelope{"status": "unavailable"}, nil)
		return
	}
	data := envelope{
		"status": "available",
		"system_info": envelope{
			"environment": app.config.env,
			"version":     "1.0.0",
		},
	}

	err := app.writeJSON(w, http.StatusOK, data, nil)
	if err != nil {
		app.serverErrorResponse(w, r, err)
		return
	}
}

func isValidUsername(s string) bool {
	if len(s) < 3 || len(s) > 16 {
		return false
	}
	for _, c := range s {
		if !((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '-') {
			return false
		}
	}
	return true
}

func isValidRoom(s string) bool {
	if len(s) == 0 || len(s) > 64 {
		return false
	}
	for _, c := range s {
		if !((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '-' || c == '.') {
			return false
		}
	}
	return true
}

func (app *application) connectToServerHandler(w http.ResponseWriter, r *http.Request) {
	username := r.URL.Query().Get("user")
	if !isValidUsername(username) {
		username = "Guest_" + strconv.Itoa(rand.Intn(10000))
	}
	room := r.URL.Query().Get("room")
	if !isValidRoom(room) {
		room = "industrial"
	}

	if app.match.IsUsernameTaken(room, username) {
		app.badRequestResponse(w, r, fmt.Errorf("username already taken in this room"))
		return
	}

	// 1. Upgrade the http connection to websocket
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		app.logger.PrintError(err, nil)
		return
	}

	cid := r.URL.Query().Get("cid")
	if cid != "" {
		app.presenceMu.Lock()
		delete(app.presenceMap, cid)
		app.presenceMu.Unlock()
	}

	// Disable Nagle's algorithm so small packets (protobuf ~35 bytes) are sent
	// immediately without waiting for TCP buffer to fill up.
	if tcpConn, ok := conn.NetConn().(*net.TCPConn); ok {
		tcpConn.SetNoDelay(true)
	}

	// 3. Create the session:
	session := engine.NewGameSession(app.match, conn, username, room)

	// 4. Register the session with the central game Match
	if err := app.match.Register(session); err != nil {
		conn.WriteControl(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.ClosePolicyViolation, err.Error()), time.Now().Add(time.Second))
		conn.Close()
		return
	}

	// 5. Start the network loops in background goroutines
	go session.StreamUpdatesToPlayer()
	go session.ListenForPlayerInputs()
}

func (app *application) listRoomsHandler(w http.ResponseWriter, r *http.Request) {
	cid := r.URL.Query().Get("cid")
	now := time.Now()

	app.presenceMu.Lock()
	if cid != "" && len(cid) <= 64 && len(app.presenceMap) < 4096 {
		app.presenceMap[cid] = now
	}
	// Evict entries older than 15 seconds
	onlineCount := 0
	for id, lastSeen := range app.presenceMap {
		if now.Sub(lastSeen) > 20*time.Second {
			delete(app.presenceMap, id)
		} else {
			onlineCount++
		}
	}
	app.presenceMu.Unlock()

	// Add players currently in-game (WebSockets active in the Match engine)
	onlineCount += app.match.GetTotalActivePlayers()

	rooms := app.match.ListActiveRooms()

	err := app.writeJSON(w, http.StatusOK, envelope{
		"rooms":          rooms,
		"online_players": onlineCount,
	}, nil)
	if err != nil {
		app.serverErrorResponse(w, r, err)
	}
}

func (app *application) createRoomHandler(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Name      string `json:"name"`
		Map       string `json:"map"`
		Mode      string `json:"mode"`
		TimeOfDay string `json:"timeOfDay"`
	}

	err := app.readJSON(w, r, &input)
	if err != nil {
		app.badRequestResponse(w, r, err)
		return
	}

	input.Name = strings.TrimSpace(input.Name)
	validMaps := map[string]bool{"football": true, "resoforge": true, "industrial": true, "village": true, "arena": true, "shipment": true, "dust2": true, "canyon": true, "desert_oasis": true, "nuketown": true}
	if input.Mode == "" {
		input.Mode = "FFA"
	}
	validTimes := map[string]bool{"": true, "dawn": true, "noon": true, "dusk": true, "overcast": true, "night": true}
	if !validTimes[input.TimeOfDay] {
		app.badRequestResponse(w, r, fmt.Errorf("choose dawn, noon, dusk, or overcast"))
		return
	}
	if len(input.Name) < 1 || len(input.Name) > 48 || !validMaps[input.Map] || (input.Mode != "FFA" && input.Mode != "TDM") {
		app.badRequestResponse(w, r, fmt.Errorf("choose a valid map, FFA/TDM mode, and room name of 1–48 bytes"))
		return
	}

	if len(app.match.ListActiveRooms()) >= 256 {
		app.writeJSON(w, http.StatusTooManyRequests, envelope{"error": "room limit reached"}, nil)
		return
	}
	room := app.match.CreateRoom(input.Name, input.Map, input.Mode, input.TimeOfDay)
	if room == nil {
		app.writeJSON(w, http.StatusTooManyRequests, envelope{"error": "room limit reached"}, nil)
		return
	}

	err = app.writeJSON(w, http.StatusCreated, envelope{"room_id": room.ID}, nil)
	if err != nil {
		app.serverErrorResponse(w, r, err)
	}
}
