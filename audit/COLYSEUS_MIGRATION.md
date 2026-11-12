# Colyseus migration work log

## Target

Replace the Go combat service with Colyseus while preserving WarBase's Godot native and web clients. Use the framework's state synchronization, input buffering/acknowledgement, clock synchronization, prediction/reconciliation and rewind rather than recreating our previous custom transport under a new name. Game rules and simulation still require game-specific code.

## Initial implementation boundaries

- New `warbase-colyseus/` service: authoritative Colyseus room and schema, framework fixed-step input processing, player lifecycle, movement and initial combat.
- Godot SDK installation: pinned official native and web artifacts with a reproducible download script and recorded hashes.
- Godot adapter: explicit opt-in backend selection and a real SDK connection/state path. The existing Go path remains the default until the replacement has passed acceptance checks.
- Live deployment changes follow validated native/web builds and feature parity; an incomplete prototype is not a production replacement.

## Acceptance order

1. Verify the downloaded SDK actually loads on the current Godot version and exposes the documented prediction APIs; verify the web artifact and export requirements.
2. Demonstrate two actual Godot clients joining, moving, leaving and reconnecting with framework state sync and prediction. Demonstrate server-approved damage and respawn. Include hostile/replayed/invalid input checks.
3. Port and test remaining maps, collision, bots, grenades and vehicles with equivalent security and gameplay behavior. No feature may silently fall back to client authority.
4. Export actual Mac and web builds, deploy an isolated candidate to official infrastructure, and compare under the same 64-player workload. Record position corrections, confirmed hits, disconnects, frame times, RTT, snapshot gaps, bandwidth and server resources.
5. Complete endurance and impairment checks and roll out only the tested matching server/client release, keeping rollback available.

## Process constraints

Implementation and scoped checks are delegated to Luna agents. Parent handles coordination and review. Test subprocesses must have timeouts and cleanup; do not leave headless Godot, Node or load clients running. Local smoke/unit tests are not official-server capacity evidence. All live capacity claims require the official endpoint.

## Status

Implementation is on branch `codex/colyseus-migration`. The official Godot SDK v0.18.7 archive was verified against its published SHA-256, and a bounded Godot 4.7.2 smoke check loaded and instantiated its native client class without making a network connection. The retained source includes `Predict.reconciler`, `Predict.sim`, buffered inputs and synchronized clocks. Mac arm64 and Web binaries are retained; the installer omits other platforms. The current Godot installation contains the required web dynamic-link export templates.

The TypeScript server uses Colyseus 0.18.10 and the actual framework fixed-step input, prediction and rewind APIs. The server simulation is 60 Hz and state patches are 20 Hz. All 280 existing damage fixtures pass, including the sniper minimum of 100 damage. Animated capsule hitboxes use the existing pose data; framework animation transitions and aim-direction checks pass.

Bounded loopback checks passed for two Godot SDK clients (input acknowledgement, reconnect and peer removal), and for the actual Main/Player scene (22.32 metres of movement and a remote peer). These are integration checks, not exported-client or official-server capacity evidence. Shared collision fixtures passed across all ten maps; the candidate uses the same sampled collision solver for client prediction and server authority, which is an approximation of Godot's physics solver.

Bots, grenades and vehicles have tested simulation modules and candidate Room/client integration. A previous candidate Web export omitted runtime map datasets; candidate export assertions now require all ten datasets before accepting a build. Audio remains muted by the existing runtime audio manager.

An isolated candidate is deployed at `https://war.vaidik.blog/colyseus/` on Umbrel. The current Go game still serves the main URL. Its updated image adds optional candidate-only matchmaking and WebSocket routing, and the previous Go container is retained as `warbase-server-before-colyseus-route` for rollback. The active candidate image is `warbase-colyseus:perf-candidate-20261029` (image ID `sha256:6b9187f51d3280b94be7a9ef0b4d7d223e176bb4a8d69d25527940a1712ab07d`). Public health, manifest identity and a matchmaking reservation were verified. The root service remains based on official combat release commit `98663dd`.

The full server suite passed 39/39; Godot regression passed all eight named suites before the subsequent targeted performance changes, which passed focused client tests. A two-client Godot test passed through the actual Go proxy, including reconnect, acknowledgement and animation timing. A separate Mac candidate was exported and checked for the SDK and map resources. Candidate web transfer is 44,497,884 bytes Brotli.

Two bounded tests used the official domain and reached 64 human actors at peak. The native headless observer had to be stopped early in both: after initially holding 30 FPS, it dropped to 1–6 FPS and consumed about one CPU core. On the second run, the fall coincided with a vehicle exit and other events; causation is not established. The SDK peers continued, and the server's p95 state gap was approximately 1,054 ms in the second run with CPU averaging about 94.5% of one core. These are diagnostic results, not a capacity pass or graphical FPS benchmark. See `colyseus-migration-2026-10-28/official-load-summary.md`. Real browser gameplay, endurance, network impairment and resolution of the observed stalls remain acceptance gates. Avoid replacing the main game until those gates and feature parity are verified.

An isolated eight-client CPU profile on Umbrel identified map capsule collision queries as the dominant sampled server cost, particularly `collisionRaycast`, `resolveMove`, and `moveAxis`. Startup navigation preparation also appeared in the profile but is performed before the server accepts players. Further collision optimization needs its own parity tests and another official load comparison. The attempted headless Edge browser check crashed before DevTools started, so real browser matchmaking and gameplay remain unverified.

On October 29 a live profile of the user's graphical Mac candidate showed 335 of 336 main-thread samples in the SDK's synchronous input-send reconciliation callback, which runs the GDScript map collision solver. This identifies a client integration bottleneck, independently of the earlier loaded-server bottleneck. A focused fix skips exactly stationary capsule sweeps and the grounded idle fixed point; all-map fixture and fractional height/velocity comparisons passed. On one local benchmark, idle prediction fell to approximately 0.086 ms per step, while moving prediction still took approximately 7 ms per step and a near-wall fixture approximately 34 ms. These measurements are not a full-match FPS result; further optimization and a graphical retest are needed.
