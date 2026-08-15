package main

import (
	"flag"
	"os"
	"sync"
	"time"

	"warbase-server/internal/engine"
	"warbase-server/internal/jsonlog"
)

type config struct {
	port int
	env  string
}

type application struct {
	config        config
	logger        *jsonlog.Logger
	match         *engine.Match
	wg            sync.WaitGroup
	presenceMu    sync.Mutex
	presenceMap   map[string]time.Time
}

func main() {
	var cfg config

	flag.IntVar(&cfg.port, "port", 8081, "Game server port")
	flag.StringVar(&cfg.env, "env", "development", "Environment (Development | Production)")

	flag.Parse()

	logger := jsonlog.New(os.Stdout, jsonlog.LevelInfo)

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
