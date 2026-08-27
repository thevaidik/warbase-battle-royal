.PHONY: build run run-release dev-client build-server docker swift dev

# Build the Web Client (Vite/TypeScript)
build:
	@echo "Building Frontend Client..."
	@cd client && npm run build

# Build and start the Swift Game Server locally (Development mode)
run: build
	@echo "Starting Unified Game Server (Swift Hummingbird, Port 8081)..."
	@cd server-swift && PORT=8081 ENV=development swift run App

# Compile optimized Swift release binary
build-server:
	@echo "Compiling Optimized Swift Server Binary (-c release)..."
	@cd server-swift && swift build -c release

# Run the compiled Swift release binary (Production mode)
run-release: build build-server
	@echo "Starting Optimized Swift Server (Release Binary, Port 8081)..."
	@cd server-swift && PORT=8081 ENV=production ./.build/release/App

# Run Vite dev server for rapid frontend development
dev-client:
	@echo "Starting Vite Dev Server..."
	@cd client && npm run dev

# Build and start the Docker production stack
docker:
	@echo "Starting Swift Server in Docker Container..."
	@docker compose up --build

# Aliases
swift: run
dev: run


