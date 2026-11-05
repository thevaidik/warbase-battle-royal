> Historical handoff. See the [28 October follow-up](../production-followup-2026-10-28/REPORT.md) for subsequent fixes, full-suite results and official retesting.

# Network repair handoff — 27 October 2026

## Fixed

- Reconcile against acknowledged historical input, preventing latency alone from snapping the player backwards. Keep real collision corrections and clear old history on respawn.
- Bounded acknowledged server delivery, latest-state/vehicle-input coalescing, reliable-event priority, cosmetic overflow dropping, compressed batches, 20 Hz replication with 60 Hz simulation. Encode each player once per tick and prune BVH rays beyond an existing nearest hit.
- Spread occupied spawns, throttle repeated rejection logs, preserve network processing while paused, display persistent synchronization status and return to lobby after terminal connection errors.
- Fix expired blood/decal references causing combat script errors. Refresh web asset write deadlines as downloads make progress; official tunnel logs confirmed old large-pack truncation.
- Final refinements: eight outstanding client movement/driving inputs, vehicle input acknowledgements, five-second stall watchdog, shared remote weapon meshes and one remote actor built per frame. Moving actors update at 20 Hz within 35 m, 10 Hz through 120 m, 4 Hz beyond, with distance-adjusted interpolation. Dormant actors use lower keepalive rates.
- Preserve every nearby cosmetic shot/passing bullet; alternate distant tracers within hearing range. Authoritative damage, ammunition and local weapon effects remain unchanged.

## Validation caveat

Final Godot regressions, targeted network race tests, Web compression checks and native ZIP integrity passed. The full server race suite failed `TestBotsUseAuthorityAndRespectTeams` with `bot bypassed RPM limit`. This test calls the wall clock for two successive shots and ran slowly; investigate or replace it with a deterministic clock and rerun before claiming a fully green suite. Bot combat code was not changed in this final refinement. Do not treat the targeted pass as a full-suite pass. See `server-tests-final.log` and `network-tests-final.log`.

## Last completed full-room test and limits

`final-load.json`: 62 normal clients on Umbrel through public WSS plus native/web observers reached API-confirmed 64/64 occupancy. Over 120 s, load clients had zero connection errors, median RTT 2168 ms and p95 3851 ms. The native observer had eight reconnects; car movement was insufficient to certify driving. These measurements PRECEDE the final input-window/AOI/cache refinements. This is NOT a production-capacity pass.

Earlier load binaries used Go race instrumentation, distorting timing; do not use those runs as clean before/after comparisons. Corrected normal-client tests still showed full-room latency. A private Tailnet control had better median latency but jitter remained; hosting/uplink/tunnel causation is unproven.

Native observations used Godot loading the exported release pack with an external observer, not the standalone signed executable. The in-app browser rendered the game but rejected pointer lock; normal-browser aiming/driving remains unverified. See `release-status.md` for final packaging/deployment status.

## Later work, in priority order

1. Repeat the final release at 64 players on official public WSS with native and normal-browser observers. Require stable latency, no unexpected reconnects and actual enter/drive/reverse/exit on several vehicles. Follow with 30-minute endurance testing; verify API occupancy throughout. Use a normal non-race generator.
2. Measure uplink use, public versus private route latency, input age, snapshot age, tick budgets and tunnel behavior separately. Consider compact pose deltas, adaptive bandwidth budgets or different hosting based on evidence. Increasing timeouts alone is not a backlog fix.
3. Full-load Football Stadium, Desert Oasis and Industrial Zone; collisions, vehicle impacts, respawns, grenades, blood/death, late joins, interruption/reconnect and map changes. Latest completed public cohort covered Industrial Zone only.
4. Check standalone native plus normal Chrome/Safari/Firefox fullscreen/pointer lock and cold-join/combat frame times. Profile additional cosmetic effects before changing budgets.
5. Complete native signing/notarization and verify imported-map licensing/attribution before public distribution.

## Deployment and rollback

SSH: `ssh umbrel`. Game Docker engine is nested in `portainer_docker_1`, socket `unix:///data/docker.sock`. Do not modify the unrelated Arcane engine. Preserve network `warbase_server_default`, alias `warbase-server`, published port 8081.

Original stopped rollback container: `warbase-server-before-network-20261027`; original image tag: `warbase_server-warbase-server:before-network-20261027`. To roll back, stop/rename the active game container, rename the original to `warbase-server`, and start it, preserving matching web assets. Optional profiler binds loopback only inside the container; public `/debug/pprof` must remain 404.
