.PHONY: build run run-swift run-swift-server swift build-swift run-swift-release docker-swift

build:
	@echo "Building Frontend Client..."
	@cd client && npm run build

run: build
	@echo "Starting Unified Game Server (Go, Port 8081)..."
	@cd server && go run ./cmd/game/

run-swift run-swift-server swift: build
	@echo "Starting Unified Game Server (Swift Hummingbird, Port 8081)..."
	@cd server-swift && PORT=8081 ENV=development swift run App

build-swift: build
	@echo "Compiling Optimized Swift Server Binary (-c release)..."
	@cd server-swift && swift build -c release

run-swift-release: build-swift
	@echo "Starting Optimized Swift Server (Release Binary, Port 8081)..."
	@cd server-swift && PORT=8081 ENV=production ./.build/release/App

docker-swift: build
	@echo "Starting Swift Server in Docker Container..."
	@cd server-swift && docker compose up --build

