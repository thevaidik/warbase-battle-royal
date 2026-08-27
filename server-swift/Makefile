.PHONY: build run docker test health

build:
	@echo "Building Swift Server..."
	swift build -c release

run: build
	@echo "Starting Swift Game Server (Port 8081)..."
	PORT=8081 ENV=development swift run App

docker:
	docker compose up --build -d
	@echo "Swift server at http://localhost:8081 (or https://warbase.nxtlap.com via cloudflared)"

health:
	@curl -s http://localhost:8081/healthcheck | head -20
	@echo ""
	@curl -s http://localhost:8081/api/rooms | head -40

test: health
	@echo "Testing WebSocket (requires wscat)..."
	@echo "Mac client: open WarBaseClient in Xcode, Run (DEBUG uses localhost:8081, Release uses warbase.nxtlap.com)"
