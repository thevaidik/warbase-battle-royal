# WarBase

Godot 4.7.2 FPS client and Go multiplayer service. The game supports FFA/TDM rooms, seven selectable weapons, custom primary/secondary/throwable slots, variable optics, online AI squads, and offline practice with bots and vehicles.

## Play locally

Install Godot 4.7.2 and Go 1.23 or later. Web release packaging also requires Node.js for built-in Brotli compression. On macOS, the Makefile defaults to `/Applications/Godot.app/Contents/MacOS/Godot`; override `GODOT` for another installation.

- Start the service with `make run-server`.
- Start the native client with `make run-godot`. Set **Settings → Server Host** to `localhost:8081` for local online play. The existing remote host remains the native default.
- Use **Join server** for online matches with AI and human players. The optional **Offline** switch starts a local sandbox. Home, Loadout, Operator, and Settings remain in the top bar.
- For the browser, install the matching Godot export templates, run `make export-godot-web`, start the service, and open `http://localhost:8081`.

The Web client connects to the same host and port that serves it. Online play uses protocol version 4; update the client and service together. Old exported clients are incompatible with the custom inventory, vehicle, and room-lighting protocol.

## Controls

| Action | Input |
| --- | --- |
| Move / jump / crouch | WASD / Space / C |
| Fire / aim | Left / right mouse button |
| Reload | R |
| Optic magnification | V on weapons with variable optics |
| Steady scoped aim | Hold Shift while stationary and aimed |
| Primary / secondary | 1 / 2; mouse wheel swaps between them |
| Equipped throwable | G; two per life |
| Inspect | I |
| Scoreboard / pause | Tab / Esc |
| Vehicle enter / exit | E near an unoccupied car; online and offline |
| Drive / brake / camera | WASD / Space / mouse; C changes chase view |

Click **Loadout** on the home screen to open the full equipment picker. Any two different guns can occupy the primary and secondary slots; choose an M67 frag or impact grenade. Choices are saved automatically and applied when you deploy.

Automatic weapons require roughly 0.32–0.40 seconds of perfect close-range body hits to eliminate a full-health target. Damage falls with distance except for the one-shot M2010 sniper. Spawn protection lasts 2.5 seconds and ends when firing or throwing. Health recovers at 15 HP/second after five seconds without damage.

Switching preserves each magazine and cancels an unfinished reload. Firing is blocked while drawing, reloading, cycling the sniper bolt, or throwing. The scope’s angular markings are for aiming references; the game uses hitscan rather than ballistic bullet drop. Exhausted breath must recover after releasing Shift.

## Validate

- `make test-server`: Go tests under the race detector, then `go vet`.
- `make test-web`: validates versioned web asset URLs, unused-asset removal, and lossless gzip/Brotli round trips after export.
- `make test-godot`: bounded handling and gameplay regressions; fails on script/physics errors or missing completion markers.
- With a local service on port 18091, run Godot with `--headless --path warbase-godot/client --script res://scripts/tests/test_online_sync.gd` to check two-client roster and grenade consistency.
- `make stress-test`: 60 protocol clients for ten seconds against localhost:8081. The bounded `cmd/stress` tool also accepts `-host=war.vaidik.blog`, `-room=<existing room ID>`, `-players=1..64`, `-duration=<up to 30m>`, `-combat=false`, `-drivers=0`, and `-output=<report.json>`. Drivers seek authored cars and send real seat/input events. It reports round-trip latency, snapshot gaps, confirmed seats, and observed car travel. Socket count alone does not prove a healthy match: verify `/api/rooms` occupancy and use rendered native/web observers.

Confirmed infantry hits produce small pooled blood effects and hit reactions. Tactical bots avoid visible grenades, search last-known locations, maintain squad spacing, and recover from blocked routes without changing aim accuracy.

The security suite covers firing cadence, shot replay, server-derived damage, reloads, respawn restrictions, teleport attempts, map occlusion, grenade authority, atomic admission, concurrent joins/leaves, and AOI snapshot coalescing.

## Build and deploy

1. Run `make test` and `make export-godot-web`.
2. Run `docker compose -f warbase-godot/docker-compose.yml build`.
3. Start the container with `docker compose -f warbase-godot/docker-compose.yml up -d`.

The Docker build expects the matching Web export in `warbase-godot/client/dist/`. It intentionally fails when that export is absent. It builds Go from the actual source directory and runs with a non-root user, a read-only filesystem, bounded resources, and a health check. Configure TLS at your reverse proxy; forward `/connect` WebSocket upgrades. `/healthcheck` returns unavailable if the match loop stops progressing.

For a standalone service, `--static-dir=/absolute/path/to/dist` or `DIST_DIR` chooses the Web directory. Profiling routes are disabled in production. Web assets have lossless Brotli and gzip companions. The service negotiates the encoding, including q=0 exclusions. Content-hashed engine/game URLs use immutable caching; unchanged engine files are reused across game releases, and one preceding release remains available.

Native macOS export: `make export-godot-mac`. Distribution signing/notarization still requires your release credentials.

## Map and protocol sources

- `warbase-godot/client/scripts/maps/MapBuilder.gd` constructs client maps.
- `make export-map-data` regenerates server collision triangles and authored spawn points from those same shapes, then compresses the result for embedding. Re-run this whenever collision geometry or spawns change.
- `shared/proto/fps/packets.proto` is the FPS schema. Install `protoc` and a matching `protoc-gen-go`, then run `make proto` after schema changes. `shared/proto/packets.proto` is a legacy strategy schema and is not used by this game.

Rooms use Dawn (06:00), Noon (12:00), Dusk (18:00), or Night (00:00). Public servers choose randomly and may change on a new round; custom servers retain the time selected at creation. The server list and HUD show the preset. Loft 17 is no longer playable or advertised.

The service simulates at 60 Hz and sends interpolated world snapshots at 30 Hz, with distance tiers for remote entities. Incoming transforms are coalesced, and unsent partial snapshots preserve rare AOI entities when replaced.

## Release status

See [the implementation notes](audit/implementation/CHANGES.md) and [the original audit](audit/PRODUCTION_READINESS_AUDIT.md).

This update improves handling, stability, combat validation, authoritative grenade damage, and release tooling. It does not certify a production release. Online cars now use server-owned seats, input-driven kinematic movement, terrain and chassis collision checks, health, destruction, roadkills, and respawning. Offline cars retain local four-wheel physics. Online transport does not implement mounted turret combat; infantry fire is blocked while driving. Movement still uses validated client transforms with map collision checks rather than a complete server input simulation with rewind. Long-duration soak tests, full network-impairment testing, cross-device browser QA, asset licensing, and release signing remain launch gates.

Football Stadium is included in native builds. For web releases, use `make export-godot-web` to generate the initial game and its optional stadium pack together, and serve all generated files in `warbase-godot/client/dist`. The stadium downloads on first join and retains its full-resolution atlas. `make test-web` validates compression and optional-pack mounting. See `audit/football-map/README.md` for validation and the source-rights caveat.

Current official release, measured capacity and remaining distribution checks: [28 October follow-up](audit/production-followup-2026-10-28/REPORT.md).

Audio is disabled throughout the game. Gunfire, footsteps, UI and vehicle audio methods are silent, and Settings shows **AUDIO DISABLED**.
