GODOT ?= /Applications/Godot.app/Contents/MacOS/Godot
.PHONY: run-server build-server test test-server test-godot test-web run-godot export-godot-mac export-godot-web export-map-data docker

run-server:
	cd warbase-colyseus && npm run build && npm start

build-server:
	cd warbase-colyseus && npm run build

test: test-server test-godot test-web

test-server:
	cd warbase-colyseus && npm test

test-godot:
	GODOT="$(GODOT)" python3 scripts/check_godot.py

test-web:
	python3 scripts/test_colyseus_web_packaging.py
	python3 scripts/test_client_provenance.py

run-godot:
	"$(GODOT)" --path warbase-godot/client res://scenes/Main.tscn

export-godot-mac:
	GODOT="$(GODOT)" python3 scripts/export_colyseus_native_candidate.py

export-godot-web:
	GODOT="$(GODOT)" python3 scripts/export_colyseus_web_candidate.py
	python3 scripts/package_colyseus_web_candidate.py

export-map-data:
	"$(GODOT)" --headless --path warbase-godot/client --script res://scripts/tools/export_server_maps.gd
	python3 scripts/compress_maps.py
	python3 warbase-colyseus/scripts/extract_industrial_geometry.py --all-maps

# Build only. Production replacement follows the staged paired-release runbook.
docker:
	scripts/build_colyseus_candidate_image.sh
