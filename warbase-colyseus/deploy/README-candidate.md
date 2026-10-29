# Colyseus sidecar candidate

This is an isolated candidate for `https://war.vaidik.blog/colyseus/`. It serves the hashed Godot Web build and Colyseus API/WebSocket on one sidecar listener. The existing game route and service are left untouched by these commands. The deployment command is intentionally separate from the build command.

## Reproducible build

From the repository root, with the pinned Colyseus Godot SDK installed and Godot export templates available:

```sh
python3 scripts/export_colyseus_web_candidate.py
python3 scripts/package_colyseus_web_candidate.py
docker build -f warbase-colyseus/Dockerfile.candidate -t warbase-colyseus:candidate .
```

Or run `scripts/build_colyseus_candidate.sh` on the Mac export host to perform all three steps. For the Umbrel build, transfer the source snapshot plus `warbase-godot/client/candidate-static/` and run `scripts/build_colyseus_candidate_image.sh`; this verifies the manifest and builds without requiring Godot or the SDK on Umbrel. The package step rejects a PCK that omits any of the ten playable maps' compressed collision data, the Industrial compatibility fallback, or the GDExtension descriptor. It records hashes and sizes in `warbase-godot/client/candidate-static/candidate-manifest.json`, then produces deterministic gzip and Brotli sidecars for the HTML and every referenced asset. Asset names are content-hashed and HTML is marked `no-cache`; hashed assets are safe for long immutable caching. The package step verifies gzip and Brotli decompression against each source asset.

The Godot runtime already mutes its Master bus and starts with SFX at zero. Its audio worklet files remain in the export because the Web template includes them regardless of the runtime mute state.

## Isolated sidecar deployment

On the Umbrel host, after confirming Docker Compose can see the existing external `warbase_server_default` network and port 8082 is unused:

```sh
docker compose -f warbase-colyseus/deploy/compose.candidate.yml build
docker compose -f warbase-colyseus/deploy/compose.candidate.yml up -d
docker compose -f warbase-colyseus/deploy/compose.candidate.yml ps
```

The source snapshot needs `warbase-colyseus/{package.json,package-lock.json,tsconfig.json,scripts/,src/}` plus the packaged `warbase-godot/client/candidate-static/`. Run `scripts/archive_colyseus_candidate_snapshot.sh /tmp/warbase-colyseus-candidate.tar.gz` to create a compact transfer archive. It omits `node_modules/`, all `dist/` folders, `warbase-godot/client/candidate-dist/`, `candidate-web-dist/`, `.godot/`, and audit logs; `.dockerignore` also excludes these generated and local-only files from the Docker build context. Transfer and extract the archive, then run `scripts/build_colyseus_candidate_image.sh` from its root.

The candidate binds host port `8082` to container port `8081`; it joins the external `warbase_server_default` network and uses `STATIC_DIR=/app/static`. To use a different advertised address, set `COLYSEUS_PUBLIC_ADDRESS` before starting it. The default is `war.vaidik.blog/colyseus` (host and prefix only; the SDK adds the secure WebSocket scheme).

Add the contents of `colyseus-location.nginx.conf` to the HTTPS gateway only after reviewing the candidate. Its trailing slash on `proxy_pass` strips `/colyseus/`, so `GET /colyseus/engine-<hash>.wasm`, `GET /colyseus/api/maps`, Colyseus matchmaking calls, and upgraded WebSocket requests arrive at the sidecar as root-relative paths. Keep the existing `/` route unchanged. Use `?backend=colyseus` to select the candidate client; the unqualified URL keeps the existing backend selection.

The static server must negotiate the generated `.br` or `.gz` sidecar only when the request's `Accept-Encoding` allows it, return the original asset MIME type plus `Content-Encoding`, and add `Vary: Accept-Encoding`. `index.html` uses `Cache-Control: no-cache`; hashed files use `public, max-age=31536000, immutable`. The Web export also requires `application/wasm` for `.wasm` and the isolation headers `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`. Verify these response headers through the gateway before exposing the route.

## Rollback

Remove only the candidate prefix route from the gateway, then run:

```sh
docker compose -f warbase-colyseus/deploy/compose.candidate.yml down
```

This does not stop or rebuild the legacy service. Do not use `docker compose down` against the legacy stack.

## Official bounded SDK load run

Run this only after the candidate is deployed at `/colyseus/` and the gateway passes the static asset/header checks. `scripts/run_colyseus_official_load.sh` hard-codes and validates `https://war.vaidik.blog/colyseus`; it rejects endpoint overrides and never falls back to localhost. The helper uses the official `@colyseus/sdk`, creates an isolated Industrial FFA room through `/api/rooms`, and prints `PREPARED_ROOM` before waiting for the real native observer.

On Umbrel, use the nested-engine wrapper. It streams the minimal helper build context directly to the Portainer game engine, uses the active candidate image as a build cache source, runs the cohort on `warbase_server_default`, writes reports to the Portainer `/data` bind, and removes the temporary helper image afterward:

```sh
scripts/run_colyseus_official_load_nested.sh --map industrial --peers 63 --seconds 180 --observer QA_NATIVE
```

The wrapper defaults to Umbrel's `portainer_docker_1` nested engine, discovers the active candidate container's image tag for `--cache-from`, and writes under the host's `/home/umbrel/umbrel/app-data/portainer/data/docker` shared bind. Set `COLYSEUS_NESTED_DOCKER_CONTAINER`, `COLYSEUS_NESTED_DOCKER_SOCKET`, `COLYSEUS_SERVER_CONTAINER`, `COLYSEUS_LOAD_BUILD_CACHE_FROM`, `COLYSEUS_LOAD_SHARED_ROOT`, or `COLYSEUS_LOAD_NESTED_SHARED_ROOT` only when those names or paths differ. `scripts/run_colyseus_official_load.sh` remains available when invoked directly inside the engine that owns `warbase_server_default`.

When the log prints the room ID, launch exactly one native observer on the Mac at 30 FPS, using that ID. Give it enough time to cover the 90-second observer gate, peer ramp-up, and the 180-second sample:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --max-fps 30 --path warbase-godot/client --script res://scripts/tests/test_official_stress_observer.gd -- qa_colyseus qa_room=<room-id> qa_map=industrial qa_seconds=300 qa_output=audit/colyseus-migration-2026-10-29/native-observer.json
```

The SDK cohort is limited to 63 peers; the observer must join as the distinct human `QA_NATIVE`, for exactly 64 target humans. The helper waits for that human before joining the cohort and verifies the decoded room state has the expected number of humans. It sends a reflected SDK input through the reliable buffered channel at the server-advertised 60 Hz rate, measures SDK ACKs/RTT/state gaps and authoritative player positions, walks selected peers toward nearby authored vehicle spawns using normal movement input, and attempts normal fire/grenade/vehicle messages. It triggers one SDK transport reconnect, then leaves cohort peers and checks that the room state reports removals. Bots are counted separately from humans. There are no transform writes or test-only server mutations.

The temporary Node helper runs on `warbase_server_default` with a 2 CPU, 1536 MiB memory, and 128 PID limit. It exits automatically after the bounded run; the runner traps interruption and stops the helper container. `official-load.json` records helper CPU/RSS, movement and gameplay event coverage, ACK progress, join/removal/reconnect outcomes, and RTT. It includes `coverageStatus` and a `missingEvidence` list; completing the duration does not by itself prove every action worked. `container-resources.csv` separately samples the candidate server and helper with Docker stats. Since the cohort runs on the Umbrel host/network, its route and RTT differ from the Mac observer; report both measurements without treating the cohort's RTT as Mac-user latency. Zero confirmed hits, accepted grenades, vehicle entry/motion, or observed cleanup are reported as missing evidence, not silently treated as a pass.
