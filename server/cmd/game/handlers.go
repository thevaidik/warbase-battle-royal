package main

import (
	"fmt"
	"math/rand"
	"net"
	"net/http"
	"strconv"
	"time"
	"warbase-server/internal/engine"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  8192,
	WriteBufferSize: 0, // Disable gorilla's write buffer — flush packets immediately
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all for prototype
	},
}

func (app *application) healthcheckHandler(w http.ResponseWriter, r *http.Request) {
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

func (app *application) connectToServerHandler(w http.ResponseWriter, r *http.Request) {
	username := r.URL.Query().Get("user")
	if username == "" {
		username = "Guest_" + strconv.Itoa(rand.Intn(10000))
	}
	room := r.URL.Query().Get("room")
	if room == "" {
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
	app.match.Register(session)

	// 5. Start the network loops in background goroutines
	go session.StreamUpdatesToPlayer()
	go session.ListenForPlayerInputs()
}

func (app *application) listRoomsHandler(w http.ResponseWriter, r *http.Request) {
	cid := r.URL.Query().Get("cid")
	now := time.Now()

	app.presenceMu.Lock()
	if cid != "" {
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
		Name string `json:"name"`
		Map  string `json:"map"`
		Mode string `json:"mode"`
	}

	err := app.readJSON(w, r, &input)
	if err != nil {
		app.badRequestResponse(w, r, err)
		return
	}

	if input.Name == "" || input.Map == "" {
		app.badRequestResponse(w, r, fmt.Errorf("name and map are required"))
		return
	}

	room := app.match.CreateRoom(input.Name, input.Map, input.Mode)

	err = app.writeJSON(w, http.StatusCreated, envelope{"room_id": room.ID}, nil)
	if err != nil {
		app.serverErrorResponse(w, r, err)
	}
}
