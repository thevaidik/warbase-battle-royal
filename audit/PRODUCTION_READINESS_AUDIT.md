# WarBase production readiness audit

> Historical audit of the original snapshot. See [implementation notes](implementation/CHANGES.md) for fixes and remaining launch gates.

Date: 26 October 2026. Scope: the current working copy of the Godot client and Go server, including gameplay authority, networking, runtime stability, lobby experience, testing, exports, and deployment.

**Verdict: not ready for a public production release.** The project has a substantial playable prototype: an FPS controller, four weapons, bots, vehicles, maps, a lobby, and binary multiplayer replication. The main obstacles are correctness and stability, rather than adding more content. Fix those before expanding the game.

No gameplay or deployment code was changed by this audit. Temporary server probes were removed from the application package and preserved as a complete text file in `evidence/`. Existing working-copy changes were preserved. This review concerns source and local runs, not the currently deployed public website.

## What was actually verified

| Check | Result | Limits |
| --- | --- | --- |
| Go build, `go vet ./...`, baseline `go test -race ./...` | Build/vet passed; every package reports no test files | A passing command currently provides no gameplay regression coverage |
| Godot headless editor load | Project loaded without reported GDScript parse errors | Sandbox caused certificate/editor-settings access messages; this does not establish gameplay correctness |
| Existing nine-map audit | Printed completion and clear-spawn results for all nine requested map names | Queries run immediately after constructing maps; no capsule sweep, physics settling, or assertions. Some names silently load another map |
| Temporary security invariant tests | All four tests failed, exposing vulnerabilities | Full probe source and output are retained; intentionally failing probes are outside the normal test suite |
| 60 simulated clients, five-second localhost workload, race-instrumented server | All 60 clients active; steady samples approximately 48–49 KB/s download per client; reported aggregate average 51.69 KB/s per client | Short synthetic run, not a production capacity certification; startup traffic affects average; shares host with graphical client |
| Race-instrumented server under those joins | **Data race detected** between username lookup and player registration | Actual runtime evidence, not merely a theoretical lock concern |
| Headless gameplay smoke run | Invalid transform/vector error flood; did not complete before interruption | Offline endpoint intentionally used; connection errors expected |
| Native rendered run on Apple M4, Godot 4.7.2 Compatibility renderer | Lobby rendered; deployment reached roughly 974–978 draw calls and early 19–25 FPS samples, followed by repeated physics warnings | Not a steady-state performance benchmark; process terminated at 18-second deadline; gameplay screenshot could not complete |

The stress harness marks 30 players as drivers. It does **not** create 30 independent authoritative server vehicle physics objects. It does not measure packet loss, input-to-display latency, tick percentiles, or long-match memory stability. Its final “Connected Players: 0” is printed after shutting down simulated clients; that is not evidence that all clients unexpectedly disconnected.

## Release blockers

### 1. Concurrent player map access — critical, reproduced

Locations: `warbase-godot/server/internal/engine/match.go:174`, `:335`, and `cmd/game/handlers.go:80`.

`IsUsernameTaken` reads `room.PlayerIndices` under `roomsMutex`, while the match loop writes the same map without that mutex. The local 60-player run produced a Go race-detector warning identifying those exact operations. This can lead to corrupt behavior or a concurrent-map process crash.

**Required change:** give player/session membership one concurrency owner. Route admission through the match loop and acknowledge acceptance, or consistently synchronize all access. Reserve names atomically with admission; checking before asynchronous registration also permits duplicate identities during simultaneous joins. Verify join/leave/reconnect bursts under the race detector.

### 2. Hit claims can kill arbitrary distant players — critical, reproduced

Locations: `server/internal/engine/match.go:407`, `player.go:112`.

A temporary test registered a shooter and victim 10 km apart, sent one Fire event followed by three Hit claims of 34 damage, and the server killed the victim. There is no shot identifier consumption, geometry intersection, line-of-sight, range, or aim validation. The 800 ms recent-fire window does not prevent replaying hit claims from one shot. A client-controlled `drive` animation or `vehicle` weapon label bypasses even that recent-fire window and allows higher damage.

**Required change:** accept firing intent and derive damage from server-owned weapon state. Validate each shot once against authoritative targets and collision geometry, with a bounded lag-compensation history. Vehicle impact damage must require server-owned vehicle occupancy and collision evidence.

### 3. Fire-rate validation is effectively disabled for three weapons — high, reproduced

Location: `server/internal/engine/player.go:68`.

The server subtracts 200 ms from the weapon interval, then clamps negative values to zero. AK-47, pistol, and HMG intervals are all below 200 ms. Immediate consecutive shots are accepted; all three cases were reproduced.

**Required change:** enforce a server-owned firing schedule with bounded jitter/burst handling. Add deterministic clock-driven tests for legal cadence, rapid fire, reload completion, weapon switches, and delayed packets.

### 4. Living players can request free healing and ammunition — critical, reproduced

Location: `server/internal/engine/match.go:565`.

The respawn eligibility expression explicitly permits a player who is alive. A probe confirmed a living player receives a respawn event. That branch restores health and the current magazine and clears spawn validation state.

**Required change:** respawn only after a server-recorded death and the applicable delay, or a separate server-owned round reset. Do not use ordinary respawn as the recovery path for locally simulated damage. Rate-limit requests and prevent duplicate responses.

### 5. Movement protection permits arbitrary teleports — critical, reproduced

Location: `server/internal/engine/match.go:357`.

Movement permits 25 m per packet on foot and 60 m when the client claims to be driving. After three rejected large movements, the fourth is accepted. A probe moved a player to x=10,000 with four state updates. This is independent of elapsed time or collision geometry. Sending a `death` animation can also clear the spawn gate.

**Required change:** simulate movement from bounded inputs, or at minimum validate against elapsed server time, map bounds, server-owned movement mode, and collision constraints. Repeated invalid positions must never become valid solely because they were repeated. Add sequence acknowledgments and client reconciliation; the local client currently sends transforms but does not reconcile its position to the server state.

### 6. Runtime develops invalid physics/transforms — high, reproduced

Observed in headless and native rendered runs. Output includes non-finite transform errors and repeated warnings with `scripts/bots/Bot.gd:706` in the backtrace, at the bot `move_and_slide()` call. The existing smoke test did not finish; the native screenshot timer also did not complete before termination. These are symptoms, not a proven root cause in that line.

**Required change:** instrument the first non-finite position, velocity, basis, and collision response; record the responsible entity and preceding state. Investigate bot/vehicle/map collision interactions, invalid scaling, and simulation inputs. Prevent an invalid entity from flooding every subsequent frame. Run bounded tests with deterministic seeds on all maps and record first failure. Do not treat suppressing warnings as fixing the simulation.

### 7. Multiplayer combat has conflicting sources of truth — high, source-confirmed

Locations: `client/scripts/core/Main.gd:134`, `:414`; `bots/BotManager.gd:18`; `weapons/Grenade.gd:205`; `net/RemotePlayer.gd:331`.

Every client spawns its own seven bots, which damage its local player. Grenades simulate and apply explosion damage locally; the server relays a throw but has no authoritative explosion damage resolution. Remote explosion damage only changes the local replica. The local player keeps the lower of local damage and server health. The practice damage toggle also controls local explosion damage. Players therefore need not share bots, health, deaths, or grenade outcomes.

**Required change:** explicitly separate offline practice from online play. In online rooms, let the server own bots, grenades, health, kill attribution, and score. Client prediction should render feedback while awaiting authoritative outcomes.

### 8. Vehicles have no authoritative identity/ownership lifecycle — high, source-confirmed

Locations: `client/scripts/net/RemotePlayer.gd:153`, `:460`; `vehicles/CombatJeep.gd`; server state update and hit handlers.

A remote driver claims a nearby locally instantiated jeep by distance. Replication carries a player transform and vehicle label, rather than a vehicle entity ID, occupancy, authoritative damage, or ownership transition. `_sync_claimed_jeep_transform` is empty. Two clients can disagree about the vehicle selected or its state.

**Required change:** stable vehicle entity IDs; server-controlled enter/exit arbitration, seats, health, destruction, transforms, and collision damage. Reconnect and late join must reconstruct the same vehicles. This is required before claiming reliable multiplayer vehicle combat.

### 9. Docker release path cannot build the current game — high, source-confirmed

Locations: `warbase-godot/docker-compose.yml`, `server/Dockerfile`, root `Makefile`, root `README.md`.

Compose uses the repository root as context, but Dockerfile copies `client/package*.json` and `server/go.mod`; those paths do not match the current tree. The client stage expects npm even though the active client is Godot. Existing root documentation describes removed Babylon/Swift applications and nonexistent make targets. I did not execute a Docker build; the missing COPY inputs are visible in source.

**Required change:** export the Godot Web preset in a pinned build environment, build the Go service from its real directory, and package both into one consistent artifact. Make the static root and output paths agree. Prove the documented clean-checkout build and cold container startup work. Add health checks, resource limits, non-root execution, version metadata, and rollback instructions.

## Other changes required before public launch

| Priority | Finding and evidence | Required outcome |
| --- | --- | --- |
| High | **Audio cannot be enabled through the current settings.** `AudioManager.gd:10–21` starts muted, sets both volumes to zero, and mutes the Master bus. The settings slider only changes SFX volume. No unmute path was found. | Working mute/master/SFX controls, sensible defaults, persistent preferences, and audible spatial combat cues. |
| High | **Server spawn selection ignores maps.** `match.go:577` and `:702` choose random x/z within ±12, y=1 for every map. `Main.gd:448` only substitutes the first spawn's height. Loft includes multiple floors. | Server-owned, map-specific safe spawns with capsule clearance, enemy-distance selection, and spawn protection. Client and server use the same map/spawn data. |
| High | **Round completion/reset is incomplete.** Fire/hit handling is not gated on PLAYING; kills during FINISHED can modify results and extend the reset timer. `MultiplayerManager.gd` uses maximum lifetime local/server kills and deaths, so server resets do not lower local stats. `Main.gd:432` adds the winner feed on every snapshot. | A real round state machine with round IDs, immutable final results, disabled scoring during intermission, and one-time UI transitions. Reset local stats on authoritative new round. |
| High | **Unbounded admission and abuse paths.** No player/room cap or per-peer input/event rate limiter was found. Room creation accepts arbitrary map/mode/name values. Presence accepts arbitrary client IDs. `CheckOrigin` always returns true. Grenade throttle at `match.go:617` has an empty body and updates no cooldown. | Enforce total/room/session budgets, bounded strings and enums, per-message rate limits and separate grenade inventory/cooldown. Restrict browser origins and provide an identity/session model appropriate to anonymous or account-based play. |
| High | **Server failure can leave health falsely green.** `Match.Run` recovers a panic and then returns; healthcheck always reports available. No match-loop watchdog exists. HTTP Shutdown does not explicitly close active WebSocket sessions or stop/drain the match loop. | Health depends on live tick progress; fail visibly on engine death. Drain admissions, notify/close sockets, stop loops, and bound shutdown time. |
| Medium | **Profiling production flag mismatch.** `routes.go:119` only checks `ENV`, while static serving also checks `--env`. `--env=production` alone leaves profiling routes registered. | One authoritative environment configuration; profiling disabled or privately bound in production. |
| High | **Lobby can misrepresent reality.** `Main.gd:445` ignores connection changes; gameplay starts before admission. Room creation callbacks ignore HTTP status and invent a room ID on failure (`MainMenu.gd:865`). Server auto-creation defaults to industrial/FFA except name heuristics for arena/village. | Show connecting, rejected, reconnecting, and disconnected states. Deploy after accepted room metadata. Show real creation errors and never invent online success. |
| Medium | **Lobby capacity display is false.** A captured server card showed 56/16 PLAYERS. `MainMenu.gd:1067` hardcodes /16, and the server has no matching cap. | Server reports/enforces capacity; UI displays it and disables full rooms consistently. |
| Medium | **Loadout descriptions do not match behavior.** Infiltrator advertises a pistol and faster sprint, but setup only special-cases SCOUT; other classes start with AK. Advertised pistol magazine/RPM also differ from live weapon config. | Drive descriptions and behavior from shared data; implement class differences or remove the promises. |
| Medium | **Distance optimization changes hit registration.** `RemotePlayer.gd:481` disables limb hitboxes beyond 45 m while local weapon raycasts determine hit claims. | Keep gameplay collision independent of visual LOD; test limb shots across distance boundaries. |
| Medium | **AOI packets are partial, but latest-state queue replaces whole packets.** `session.go:60` evicts queued state, while `replication.go` includes distant entities only on selected ticks. A slow client can repeatedly miss rare updates and eventually despawn a still-connected entity after the client's 3 s timeout. | Explicit full/delta snapshot semantics, sequence/baseline IDs, guaranteed lifecycle events, and acknowledged/merged state for low-frequency entities. Test slow readers. |
| Medium | **Web payload and load behavior need work.** Existing `build/index.pck` is about 197 MiB and WASM about 38 MiB uncompressed. Map loading and collision generation happen synchronously in `MapBuilder.build`. Native deployment sampled nearly 1,000 draw calls before error flooding. | Measure real compressed transfer, first-play latency, memory, and frame-time percentiles. Audit exported dependencies, prebuild collisions, and use a visible loading state with measured asset budgets. Existing build files may be stale; re-export before final sizing. |
| Medium | **No trustworthy shared protocol source.** `shared/proto/packets.proto` describes an incompatible strategy simulation; the active Godot codec says it was recovered from the old FPS schema. Two generated Go schema packages exist. No version handshake is present. | One canonical FPS schema, reproducible generation, protocol version negotiation, client/server compatibility fixtures, and malformed-packet tests. |
| Medium | **Map identity falls back silently.** `MapBuilder.gd:378` loads industrial for unknown names, including city; multiple named maps reuse the same industrial GLB. The existing map audit can report success for the fallback geometry. | Make map IDs explicit and validated across server, lobby, assets, and tests; intentional variants should be named accurately. |
| Medium | **Settings/accessibility are incomplete.** Sensitivity and volume are runtime variables, with no persistence found. Key actions use keycode bindings; no remapping UI was found. Lobby secondary text is extremely small at 1280×720. | Persist settings; provide remapping, scalable UI, readable text, color-independent team cues, and reduced camera shake/motion options. |

## Lobby visual assessment

The captured lobby has a consistent dark tactical palette and an obvious deploy action. It also has substantial empty space, very small descriptions, tightly packed class labels, and several competing accent colors. Simplify it around player identity, selected room, connection state, and one join action. Keep map choice, room choice, and game mode synchronized. Fix incorrect capacity and loadout promises before cosmetic polish.

Screenshot: [captured lobby](evidence/lobby.png). A complete visual assessment of aiming, animation, weapon feel, readability in combat, and effects remains outstanding because the rendered gameplay run entered the warning loop. This report does not claim those aspects passed.

## Test infrastructure corrections

The current baseline Go suite has no test files. The Makefile smoke command pipes output through a text filter; pipeline exit status can be misleading, no timeout is imposed, and engine errors without “SCRIPT ERROR” can be missed. The autotest contains some assertions but many checks only print values. The map audit prints warnings instead of returning a failure, queries newly constructed worlds without a simulation settling step, and can validate fallback maps under the wrong name.

Replace this with bounded tests that return nonzero on failed invariants. Preserve full logs as artifacts and summarize failures. Cover two real clients sharing the same room, health and kill attribution, rejected shots, round resets, safe spawns, reconnects, stale clients, and vehicle ownership conflicts. The existing stress harness is useful for traffic generation; add server tick timing, queue/drop counters, validated sequence counts, active connection high-water marks, CPU/heap observations, and latency distributions. Do not describe TCP message counts as “zero packet loss.”

## Recommended delivery order

1. **Stability and release foundation:** reproduce/fix invalid physics, fix the data race, make the build/export/container reproducible, and add bounded smoke/security tests. Gate: the current failure probes become passing security tests; race runs and deterministic gameplay runs are clean.
2. **One authoritative online match:** separate practice; implement server-owned movement/combat/spawns, bots/grenades/vehicles, and a protocol handshake. Gate: two clients agree on health, kills, deaths, vehicles, and round results under latency and reconnects.
3. **Honest, usable player flow:** connection/admission states, real room errors and capacity, correct loadouts, functioning audio, persisted controls, and round-end presentation. Gate: a new player completes join → play → death → respawn → result → next round without ambiguous states.
4. **Performance and deployment validation:** re-export the release, establish target devices and budgets, measure real browser/native performance, then soak-test at the intended capacity with network impairment. Gate: meet agreed frame-time, memory, download, tick-time, latency, and reconnect targets; demonstrate restart and rollback.
5. **Content and polish:** tune weapon feel, map flow, animation, sound, effects, onboarding, and visual identity using human playtests after the simulation is dependable.

Start with a clearly scoped FFA/TDM release on one or two proven maps. Current source implements respawn-and-score matches, not a full battle-royale lifecycle with elimination, shrinking zone, and last-player victory. Decide which product is shipping and align the title, lobby copy, rules, and acceptance criteria with that choice.

## Suggested launch gates

These are proposed targets to agree on, not results achieved by this audit:

- Clean checkout builds the correct native/Web client and server; deployment serves the matching version and supports rollback.
- No race-detector reports, non-finite transforms, crashes, or unbounded error floods in reproducible tests and an extended target-capacity soak.
- All security invariants pass: cadence, one damage resolution per shot, range/geometry, valid occupancy, health, respawn delay, movement budget, room admission, and round state.
- Two-client tests pass with latency, jitter, brief disconnects, late joins, and slow receivers. UI accurately reports these states.
- Choose supported hardware/browser targets; for a 60 FPS target, demonstrate the agreed percentile frame-time budget around 16.7 ms in representative combat. A startup sample or headless FPS is not sufficient.
- Server tick duration has a documented percentile budget below the 16.7 ms period at 60 Hz, with queue/deadline telemetry and headroom.
- Download size, load time, memory growth, and reconnect recovery satisfy explicit product budgets.
- Audio, controls, readable UI, settings persistence, and map-safe respawns pass manual QA.
- Confirm asset redistribution licenses and ownership, release signing/notarization requirements, and any account/privacy obligations relevant to the chosen distribution. No asset license inventory was found; this is an unresolved release check, not a claim that assets are unlicensed.

## Evidence and reproducibility

- [Security test output](evidence/server-security-results.log)
- [Full temporary server probe source](evidence/server_security_probe_test.go.txt)
- [60-player workload output](evidence/60-player-stress.log)
- [Race detector server output](evidence/race-server.log)
- [Rendered client excerpt](evidence/rendered-runtime-excerpt.log)
- [Headless client excerpt](evidence/client-runtime-excerpt.log)
- [Existing map audit output](evidence/map-audit.log)
- [Baseline Go check output](evidence/go-baseline.log)

The complete temporary test source is intentionally retained outside the server package: it asserts required protections and therefore fails against the current implementation. To reproduce, copy it into `warbase-godot/server/internal/engine/audit_probe_test.go`, run `go test ./internal/engine -run TestAudit -v` from the server directory, then remove the temporary copy. Use a writable Go build cache in a restricted environment.

All generated evidence is local. Tests used a temporary localhost service, not the public production server. Large repetitive runtime logs were reduced to excerpts and their temporary originals removed. The temporary server and game processes were stopped. No fixes, commits, deployments, or public service changes were performed.
