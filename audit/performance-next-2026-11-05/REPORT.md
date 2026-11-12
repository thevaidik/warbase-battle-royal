# Web recovery and performance work — 5 November 2026

Deployed `warbase-colyseus:web-recovery-20261105` on Umbrel with matching native/Web client sources. Public SDK admission, lobby, Conquest, StateView, reconnect and removal checks pass. The public browser menu now lists all ten maps and actual Conquest match entry is verified.

## Fixed and implemented

- Reproduced the frozen Connecting menu: the pinned Godot SDK generic HTTP callback traps in its Web side module after a successful admission response. Its async Web request path frees request context before the fetch callback completes. Ticket acquisition on Web now uses Godot HTTPRequest with an eight-second timeout and deferred scene-tree attachment. The official SDK still owns bearer transport, matchmaking, WebSockets, prediction and state. No authentication bypass or backend replacement.
- Fixed camera-plane objective projection: HUD arrows use camera-space direction for points behind/on the projection plane. A focused regression covers exact and near-zero depth; no projection-error spam appeared in the live match.
- Distant living server-authoritative player animations use the official AnimationMixer MANUAL callback mode and latest phase at 30 Hz beyond 45 m, 15 Hz beyond 120 m. Near playback remains continuous; transforms/hit timestamps remain current every update; offline animated hitboxes and death playback remain active. Eleven focused checks pass, including observing real process frames.
- Ten-second live server CPU profile identified geometry queries and bot distances as major active costs. Bot perception, nearest navigation-node and retreat comparisons now use squared distances, preserving ordering and A* distance costs. The reproducible nearest-node benchmark measured 1,111 ms versus 494 ms median with equal results. This is a focused benchmark, not a whole-game speedup. Perception boundary/tie equivalence and existing bot tests pass.
- Added an automated native/Web performance gate and integrated its six unit checks into `make test`. Missing metrics cannot pass. It separates game memory/server ticks from helper memory/client prediction work and requires sustained occupancy evidence. Raw correction values spanning respawn/seat transitions cannot certify gameplay correction accuracy.

## Verification and measured limits

The 90-test server suite passed 89 tests with one optional benchmark skipped. The additional perception-equivalence test passes. The existing bounded ten-scene Godot suite passes; objective projection and animation checks pass separately and are now included in the suite. Matching native and Web exports and package provenance pass.

An official-server diagnostic reached 64 humans, rendered 63 remote actors, drove 55.8 m with seat entry/exit, fired, registered a hit, threw a grenade and respawned. The native observer had zero disconnects. However, frame p95 was 72.732 ms and p99 133.057 ms: the performance gate FAILS. See `diagnostic-summary.json` and `native-gate.json`.

This used the development Godot executable and overlapped other build/test activity. It is neither a controlled optimization comparison nor a packaged-release capacity certification. Peak 64-player occupancy does not prove a sustained full-room interval. Matched full-room server timing, qualified correction magnitude, current interactive Web frame-time acceptance and long-duration memory checks remain open. The earlier private telemetry with seven bots had a tick p95 around 18.2 ms, motivating CPU profiling; it is not the full-room measurement.

The in-app browser verified menu loading, live state, combat and respawn, but reports a pointer-lock limitation. Mouse-look acceptance requires a normal browser. Native shutdown still reports remaining ObjectDB instances; no memory-cleanliness claim is made.

## Next work

1. Repeat a controlled packaged native/Web run with no concurrent builds and sustained roster, plus matched server telemetry.
2. Profile collision/prediction replay tails and rendering separately; optimize the measured bottleneck while checking geometry and hit parity.
3. Check shutdown ownership and long-duration memory; measure bandwidth before changing schema precision or adding interest filtering.

No global quality downgrade or renderer switch was applied. Audio remains disabled. Large raw diagnostic captures are retained locally; compact evidence, benchmark and acceptance result are versioned.
