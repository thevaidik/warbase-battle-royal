package main

import (
	"net/http"
	"net/http/pprof"
	"os"
	"strings"
)

func (app *application) routes() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("/healthcheck", app.healthcheckHandler)
	mux.HandleFunc("/connect", app.connectToServerHandler)
	
	mux.HandleFunc("/api/rooms", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodGet {
			app.listRoomsHandler(w, r)
		} else if r.Method == http.MethodPost {
			app.createRoomHandler(w, r)
		} else {
			app.methodNotAllowedResponse(w, r)
		}
	})

	// Serve the compiled frontend game
	distPath := "../client/dist"
	if os.Getenv("ENV") == "production" {
		distPath = "/app/dist"
	}
	fileServer := http.FileServer(http.Dir(distPath))
	mux.Handle("/", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Referrer-Policy", "no-referrer")
		if r.URL.Path == "/" || strings.HasSuffix(r.URL.Path, ".html") {
			w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
			w.Header().Set("Pragma", "no-cache")
			w.Header().Set("Expires", "0")
		}
		fileServer.ServeHTTP(w, r)
	}))

	// Profiling only when not production
	if os.Getenv("ENV") != "production" {
		mux.HandleFunc("/debug/pprof/", pprof.Index)
		mux.HandleFunc("/debug/pprof/cmdline", pprof.Cmdline)
		mux.HandleFunc("/debug/pprof/profile", pprof.Profile)
		mux.HandleFunc("/debug/pprof/symbol", pprof.Symbol)
		mux.HandleFunc("/debug/pprof/trace", pprof.Trace)
	}


	return mux
}
