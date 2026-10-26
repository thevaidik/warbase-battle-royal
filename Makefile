GODOT ?= /Applications/Godot.app/Contents/MacOS/Godot
.PHONY: test-web run-server build-server test test-server test-godot stress-test docker run-godot export-godot-mac export-godot-web export-map-data proto
run-server:
	cd warbase-godot/server && go run ./cmd/game
build-server:
	cd warbase-godot/server && go build -o warbase-server ./cmd/game
test: test-server test-godot
test-server:
	cd warbase-godot/server && go test -race ./... && go vet ./...
test-godot:
	GODOT="$(GODOT)" python3 scripts/check_godot.py
stress-test:
	cd warbase-godot/server && go run ./cmd/stress -players=60 -duration=10s
docker:
	docker compose -f warbase-godot/docker-compose.yml up --build
run-godot:
	"$(GODOT)" --path warbase-godot/client res://scenes/Main.tscn
export-godot-mac:
	mkdir -p build
	"$(GODOT)" --headless --path warbase-godot/client --export-release macOS ../../build/WarBase-macOS.zip
export-godot-web:
	mkdir -p warbase-godot/client/dist
	"$(GODOT)" --headless --path warbase-godot/client --export-release Web dist/index.html
	"$(GODOT)" --headless --path warbase-godot/client --script res://scripts/tools/export_optional_maps.gd
	python3 scripts/compress_web.py
export-map-data:
	"$(GODOT)" --headless --path warbase-godot/client --script res://scripts/tools/export_server_maps.gd
	python3 scripts/compress_maps.py
proto:
	protoc -I shared/proto/fps --go_out=warbase-godot/server --go_opt=module=warbase-server shared/proto/fps/packets.proto

test-web:
	python3 scripts/check_web_export.py
	GODOT="$(GODOT)" python3 scripts/check_optional_maps.py
