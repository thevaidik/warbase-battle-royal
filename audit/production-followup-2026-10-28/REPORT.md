# Official release follow-up — 28 October 2026

All online measurements below use **war.vaidik.blog through public WSS**, with normal, non-race Linux load clients on Umbrel. No localhost or private game endpoint is used for capacity evidence. The Mac and Umbrel share a Tailnet, so these are not geographically diverse Internet clients.

## Implemented

- Disable synthesized gunfire, footsteps, UI and vehicle audio. Master is muted, sound calls are silent, vehicle sound players are not created, and Settings displays AUDIO DISABLED.
- Retain acknowledged historical movement reconciliation, eight outstanding input limits, bounded world delivery, 60 Hz simulation / 20 Hz snapshots, distance-based actor updates, shared immutable wire entries and remote weapon geometry.
- Send changed vehicles after an initial full vehicle baseline. Preserve queued vehicle changes through backpressure and send a complete baseline to late joins.
- Negotiate a continuous per-connection GZIP stream, with exact bounded decoded sizes and fresh decoder history on reconnect. Existing clients retain independent GZIP frames. Go-to-Godot fixtures validate interoperability; a representative 30-frame fixture used 14,473 bytes versus 20,626 with independent compression (about 30% less, not a universal bandwidth guarantee).
- Explicitly replicate player departures, including server bots removed as humans join. Remove pending actor creation and scoreboard entries immediately rather than displaying three-second ghost bots.
- Build the first bot navigation graph asynchronously so a cold map graph cannot block every live match. Give newly created, unused custom rooms five minutes for first download; used empty rooms still expire after one minute.
- Use the same explicit clock for bot firing validation and cadence. The full race suite now passes; the historical RPM-test failure is resolved.
- Increase bounded critical-event capacity to 256 and verify a 128-event burst is preserved. Log one precise delivery failure reason per connection: critical queue full, acknowledgement timeout or failed write. Cosmetic effects keep their separate bounded queue.
- Fix missing online tyres. An automated pre-fix diagnostic proved frozen VehicleWheel3D nodes remained at world origin / their previous location while the server-controlled chassis moved. Render tyre assemblies on separate chassis mounts; offline mounts follow actual suspension and online mounts animate travel/steering. Preserve imported rubber, rims, hubs and their orientation. Regression checks translation, turning, parked rotation and offline suspension; see `tyres-fixed.png`.
- Recover a latched death screen from an authoritative living snapshot once respawn has been requested; retry a still-pending respawn at most once per second. A dead authoritative snapshot still cannot revive the client. Regression checks both cases.

## Measured results

| Evidence | Occupancy / duration | Result |
| --- | --- | --- |
| `baseline-load.json` | 64 protocol peers, 60 s | 0 connection errors; RTT median 979 ms / p95 1,457 ms |
| `idle-route-load.json` | 1 protocol peer plus online AI, 30 s | RTT median 373 ms / p95 478 ms; the public route itself remains high latency |
| `native-verified-native.json` | API-confirmed 64/64, 63 peers + exported native executable, 180 s | 0 native disconnects; median frame 8.33 ms, p95 10.66 ms; RTT median 375 ms / p95 536 ms; enter/drive/exit, 79.25 m travel |
| `web-full-client.json` | API-confirmed 64/64, 63 peers + exported Web WASM, 180 s | 0 Web disconnects; median frame 33.33 ms, p95 34.04 ms; RTT median 369 ms / p95 533 ms; enter/drive/exit, 40.43 m; 362 local shots, 1,173 ADS frames, 3 grenades; audio muted |
| `football-final-*` | Reached 64/64; native observed 90 s | **Not a clean pass:** native stayed connected, but 1 protocol peer disconnected; native made 53 actual position corrections and did not reach a vehicle |
| `desert-final-*` | API-confirmed 64/64, 63 peers + exported native, native 90 s / cohort 135 s | 0 native or cohort disconnects; enter/drive/exit, 60.01 m native travel; 113 local shots, 1,757 ADS frames, 1 grenade; RTT median 430 ms / p95 830 ms; 2 corrections |

The native executable is extracted from the exported ZIP, not the editor or an external script loading a pack. Earlier native/Web observations predate the final tyre and respawn refinements. Their automated regressions and rebuilt exports are recorded separately. The Web observation above ran in the in-app browser at 473×853, approximately 30 FPS; it is not a normal desktop Chrome/Safari/Firefox fullscreen pass. A later 1280×800 attempt did not yield a new report / confirmed 64th client and is not counted as a Web pass.

The first Stadium cohort ended before the native observer; its last seconds therefore were not full capacity. The runner now adds 45 seconds of cohort grace (bounded by 30 minutes). Desert and some Stadium measurements overlap the separate endurance room; do not compare their latency as isolated single-room baselines. Raw `max_position_error_m` also includes latency and respawns; `applied_corrections` is the actual correction count.

## Validation and release identity

- `server-tests-release.log`: full `go test -race ./...` passed; `go vet ./...` passed before the Linux release build.
- `godot-tests-release.log`: complete bounded Godot suite, including tyres, authoritative respawn recovery, network, traversal, Stadium, grenades, Industrial collision and weapon handling.
- `export-release.log`, `web-check-release.log`: native/Web release rebuild, lossless compression round trips, versioned assets and ZIP integrity.
- `release-identity.json`: final image, pack fingerprint and binary SHA-256. Public `/healthcheck` must report production and `/debug/pprof/` must return 404.
- `endurance-*.json` / logs: long-run occupancy, traffic and resource evidence. Results are appended below only after the test completes.

## Remaining production gates

1. **Stadium requires further collision/reconciliation work and a clean repeated full-room test.** Keep the failed evidence. Its disconnect cause cannot be established retrospectively from the old generic log; new bounded diagnostics identify future failures. A 53-correction run cannot be called glitch-free. Check corner/stair movement against server sweep validation and actual input paths before loosening anti-teleport checks.
2. Public-route latency is still roughly 370 ms even nearly empty. Separate hosting/uplink/tunnel and geographic tests before promising competitive low-latency play. These results do not establish a hosting cause.
3. Complete normal desktop Chrome/Safari/Firefox fullscreen, pointer-lock and interactive aiming checks. The in-app browser has a pointer-lock restriction; QA automation deliberately avoids pointer lock. It is not proof that every normal browser has this restriction.
4. Resolve Football Stadium redistribution rights. Local notes describe an embedded CC BY license alongside source-listing Garena/Free Fire restrictions. Attribution alone does not settle this conflict; owner permission is pending. ResoForge attribution is retained.
5. macOS public distribution still needs Developer ID signing and notarization. Only a development identity was found; no distribution identity or credentials have been supplied. ZIP integrity is not notarization.

## Repeatable official QA

`python3 scripts/native_release_stress.py --name unique-run --map industrial --seconds 180` creates a dedicated official room and runs the exported Mac app with 63 peers. Supported maps are industrial, football and desert_oasis.

`python3 scripts/official_stress.py --name unique-endurance --map industrial --clients 64 --seconds 1800 --drivers 6` runs normal protocol clients through public WSS and records API occupancy every ten seconds. It fails on admission shortfall or any unexpected connection error. Do not reuse evidence names. Explicit QA launch flags / URL parameters are inactive during ordinary play.

## Deployment / recovery

Only the game Docker daemon inside `portainer_docker_1`, socket `unix:///data/docker.sock`, is used. Preserve network `warbase_server_default`, alias `warbase-server` and port 8081. The unrelated Arcane engine is untouched. Original rollback remains `warbase-server-before-network-20261027`; latest matching rollback is `warbase-server-pre-final`. Stop/rename the active game container, rename the selected matching rollback to `warbase-server`, then start it. Do not mix a binary with another release's Web files. Private profiling is disabled in the final release.

## Completed endurance result

`endurance-final-load.json`: **64/64 peers, 1,800 seconds, zero unexpected connection errors**. Official API recorded 167 occupancy samples, including 166 at 64 players after initial admission. Six peers attempted driving; the two authored cars recorded 116 confirmed entries, 115 exits and 7,170.97 m combined travel. Ending a run with one seat occupied is not a lost exit. There were 1,532,496 replicated damage deliveries and 96,320 explosion deliveries (deliveries include fan-out, not unique hits/explosions).

RTT median 375 ms / p95 665 ms / max 3,457 ms; snapshot gap median 51.73 ms / p95 179.96 ms / p99 325.29 ms / max 3,053 ms. Connection continuity passed; occasional long stalls and baseline route latency remain. Early minutes also overlapped the other-map tests. Near the end, the server used 198.7 MiB RAM, approximately 95% of one logical CPU on an eight-CPU host, and had zero container restarts. A single memory sample does not prove absence of leaks.

This endurance run used the final networking/navigation build before the subsequent logging-only server change and client tyre/respawn refinements. The matching final native release is retested separately in `release-final-*`. The Web initial transfer is about 34.64 MB with lossless Brotli, with Stadium downloaded separately; no texture quality reduction was introduced by compression.

## Final release retest and cleanup

`release-final-*` uses the actual rebuilt native ZIP against the final deployed server. Official API confirmed 64/64. Native observed 90 seconds while 63 normal peers held for 135 seconds: zero native disconnects, zero cohort connection errors, peak 63 remote avatars, **zero actual movement corrections**, median frame 8.333 ms / p95 8.542 ms, RTT median 365 ms / p95 519 ms, 51.88 m driving, 20 local shots and two respawns. Master audio was muted. The report recorded one car entry but no seat exit, so this particular run does not independently certify exit; previous native and Web runs did. It recorded no local grenade throw; grenade regression and earlier rendered runs provide that coverage.

Final live fingerprint: `game-8f3a40c0ceb42bac.pck`; binary SHA-256 `3f37389ac882deb12ef57a3cc5fb1e726f93bc956e22e3b8ad03cc21d73a5194`; image `warbase_server-warbase-server:final-20261028`. Public health reports production; public profiler returns 404. Matching previous build is preserved as `warbase-server-pre-final`.

Cleanup verification found no remaining native Godot/WarBase or stress-generator processes locally or on Umbrel. Agent-created browser game tabs were closed, Edge fullscreen and the in-app viewport override were restored. The official game service remains running. Xcode’s pre-existing `lldb-rpc-server` (PID 5773, parent 5396) was left untouched. See `final-process-check.log` and `final-server-diagnostics.log`.
