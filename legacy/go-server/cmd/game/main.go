package main

import (
	"flag"
	"fmt"
	"net"
	"net/http"
	"net/http/pprof"
	"os"
	"sync"
	"time"

	"warbase-server/internal/engine"
	"warbase-server/internal/jsonlog"
)

type config struct {
	port            int
	diagnosticsPort int
	staticDir       string
	env             string
	colyseusURL     string
}

type application struct {
	config      config
	logger      *jsonlog.Logger
	match       *engine.Match
	wg          sync.WaitGroup
	presenceMu  sync.Mutex
	presenceMap map[string]time.Time
}

func main() {
	var cfg config

	flag.IntVar(&cfg.port, "port", 8081, "Game server port")
	flag.StringVar(&cfg.env, "env", "development", "Environment (Development | Production)")

	flag.StringVar(&cfg.staticDir, "static-dir", os.Getenv("DIST_DIR"), "Directory containing the Godot Web export")
	flag.IntVar(&cfg.diagnosticsPort, "diagnostics-port", 0, "Optional container-loopback profiling port (0 disables)")
	flag.Parse()
	cfg.colyseusURL = os.Getenv("COLYSEUS_CANDIDATE_URL")

	logger := jsonlog.New(os.Stdout, jsonlog.LevelInfo)
	if cfg.colyseusURL != "" {
		if _, err := parseColyseusCandidateURL(cfg.colyseusURL); err != nil {
			logger.PrintFatal(err, map[string]string{"env": "COLYSEUS_CANDIDATE_URL"})
		}
	}

	if cfg.diagnosticsPort > 0 {
		listener, err := net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", cfg.diagnosticsPort))
		if err != nil {
			logger.PrintFatal(err, nil)
		}
		defer listener.Close()
		diagnostics := http.NewServeMux()
		diagnostics.HandleFunc("/debug/pprof/profile", pprof.Profile)
		diagnostics.HandleFunc("/debug/pprof/", pprof.Index)
		go http.Serve(listener, diagnostics)
	}

	match := engine.NewMatch()
	// The Match engine automatically creates permanent public rooms internally via seedDefaultRoomsLocked.
	go match.Run()

	app := &application{
		config:      cfg,
		logger:      logger,
		match:       match,
		presenceMap: make(map[string]time.Time),
	}

	err := app.serve()
	if err != nil {
		logger.PrintFatal(err, nil)
	}
}
