# Colyseus gameplay and networking feature audit

## Latest follow-up — Web recovery and performance diagnostics

The current deployed release is `warbase-colyseus:web-recovery-20261105`. The browser Connecting crash is fixed and public match entry is verified. A diagnostic reached 64 humans but failed frame-time budgets; it used a development executable with concurrent build activity and does not certify packaged-release capacity. Qualified full-room native/Web acceptance remains open. See [the follow-up report](performance-next-2026-11-05/REPORT.md).

## Current outcome — cleanup and deployment removal, 5 November 2026

The cleanup release `warbase-colyseus:cleanup-20261105` is deployed and verified on Umbrel with matched native/Web builds. See [cleanup evidence](cleanup-2026-11-05/REPORT.md). Retired WarBase deployment containers and obsolete tagged images have been removed at the owner's request; persistent volumes and the current gateway/combat services are preserved.

**The main planned integrations are complete; every optional Colyseus feature is not enabled.**

| Capability | Current status |
| --- | --- |
| Authoritative rooms, lifecycle, matchmaking and capacity | In use |
| Fixed-step inputs, prediction/reconciliation, remote interpolation and rewind hit checks | In use; full-load acceptance remains open |
| Vehicle composite prediction and grenade event prediction | In use; collision, handling and damage remain game logic |
| StateView privacy and incremental schema callbacks | Implemented and verified with matched SDK probes |
| Realtime lobby and signed anonymous admission, quotas and duplicate sessions | Deployed and verified |
| Private beta admin and monitor | Deployed; persistent login and public-route blocking verified |
| Playground | Local development only, intentionally disabled in production |
| Smaller numeric encodings and further schema payload reduction | Partial; measure precision/bandwidth before further changes |
| Predicted spawn API | Unused; grenade EventChannel is the current integration |
| Redis multi-worker presence/driver | Configuration exists, disabled; live routing and distributed admission limits unfinished |
| Alternate transports and streaming collections | Unused; no measured need or established cross-platform fit |

Remaining acceptance work: full-room native/Web frame-time and disconnect gates, interactive current Web gameplay, movement-feel comparison, and native shutdown ObjectDB ownership/long-duration memory checks. Automatic browser reconnect is unsupported by the pinned SDK; focused Node/native reconnection checks do not establish that capability on Web. More optional APIs do not replace these acceptance checks.

Historical sections below describe older releases and are superseded by this table and the linked dated evidence.

## Latest implementation status — 5 November 2026

The StateView/incremental decoding, realtime lobby and signed anonymous admission follow-up is **deployed on Umbrel** with matching native/Web artifacts. Staged and official-domain SDK/native checks pass, both containers are healthy, existing admin accounts are preserved, and all ten public presets remain Conquest. The final release also repairs HTML cache revalidation while preserving Brotli and immutable hashed assets. See [the current verification and remaining work](colyseus-features-2026-11-05/REPORT.md). No Git push was performed.

Redis configuration support is implemented but disabled. Its live two-worker test, worker routing and shared admission counters remain unfinished prerequisites to activation; it is not production cluster readiness. Full-room/FPS and interactive Web gameplay gates remain deferred per user instruction.

## Previous production status and next work — 30 October 2026

Vehicle lifecycle and grenade follow-up: forced cleanup now handles death, destruction and dropped connections with stale-seat fencing. Native actual reconnect/driving/death, injected latency and two-driver checks passed. Godot SDK 0.18.9 and deferred event-channel initialization passed native settlement and focused native/Web expiry checks; grenade prediction is enabled in the paired release. See [current evidence and limitations](vehicle-grenade-followup-2026-10-30/REPORT.md). The previously disabled grenade status below is historical.

The latest paired release adds Conquest (four A–D capture points, tickets, objective-seeking bots and M tactical map) and repairs buried spawns/vertical contact settlement in server and prediction. It is deployed on Umbrel with matching native/Web exports. See [Conquest and ground-contact evidence](conquest-ground-2026-10-30/REPORT.md) for verification and remaining limits.

The follow-up adds floating objective badges and off-screen navigation arrows during gameplay. See [objective marker evidence](objective-markers-2026-10-30/REPORT.md).

All ten default public maps now enforce Conquest, with one preset per map and fresh volatile match state after deployment. Custom modes remain available. See [public defaults and reset](public-conquest-2026-10-30/REPORT.md).

This section supersedes deployment descriptions below. The Go combat backend is now stopped with restart policy `no`. The public root redirects to `/colyseus/`; `warbase-server` now runs the Nginx gateway, and `warbase-colyseus-candidate` runs live combat. See [retirement and routing](../warbase-colyseus/deploy/LEGACY_RETIREMENT.md).

Native and Web now use the paired protocol-6 release with official vehicle `Predict.sim`, buffered seat-generation controls, and grounded walking/weapon bob, sprint/crouch camera state and jump/landing feedback. The ten-map infantry regression, 660 vehicle callback parity samples and actual Main driving/exit probe passed. Full legacy movement parity and 64-player performance remain unproven. See the [current release evidence](colyseus-prediction-2026-10-30/REPORT.md).

### Tooling now released

- Private monitor room columns include the match name, map, mode and time of day, alongside room ID, human connections/capacity, lock status and elapsed time.
- Official `@colyseus/playground` 0.18.6 is pinned directly. `ENABLE_LOCAL_MONITOR=1` also mounts `/playground/` for a non-production loopback listener. Playground is deliberately not mounted by the production private-monitor flag: its room introspection and debug/profiling hooks are development tools.
- Both tools reject requests carrying a public forwarded prefix. The gateway source also denies root/prefixed monitor and Playground paths. Tool defaults, listener restrictions, real HTTP pages and forwarding rejection pass focused tests; TypeScript build passes.
- The READMEs document private dashboard access, human-versus-bot connection counts, current Colyseus deployment and the retired Go backend.

The beta [Admin Panel](http://100.107.118.10:8082/admin/) is now deployed with persistent operator-only storage and framework login/RBAC/audit logging. Its one-time setup form creates the first administrator. The [monitor](http://100.107.118.10:8082/monitor/) now requires that same admin session. All public admin/monitor routes are blocked. In the previous deployed release, being on the home menu created no room connection; the new local implementation adds a separate lobby connection. Joining an online match adds a battle connection. Bots do not count as connected clients.

### Remaining priorities

| Order | Work | Completion criterion |
| --- | --- | --- |
| 1 | Compare movement feel against the former controller and verify current Web gameplay | Paired exports now include grounded feedback; any remaining acceleration/ADS/backwards/strafe differences must change in both server and client prediction together. Interactive Web gameplay verification remains deferred per user instruction. |
| 2 | Full-room native and Web gameplay gate | Observer joins before helpers; record frame/tick tails, ACK/pending inputs, corrections, deaths, hits, grenades, driving and cleanup. Full-room 64-player gate remains deferred per user instruction. |
| 5 | Native/Web StateView compatibility and incremental decoding | Implemented & verified: Matched two-peer unit tests establish selective visibility (`StateView` preserves private fields `ammo`, `grenades`, `throwable`, `ack_input_sequence` for owner while keeping position/yaw/combat state public to peers across reconnects/removals). Incremental schema callbacks (`on_add`, `on_remove`, `on_change`, and nested `ArraySchema` item callbacks) verified with `IncrementalColyseusState.tscn` passing all checks (`callbacks=true root_scalars=true player_add_change_remove=true vehicle_array=true objective_change=true cleanup_reconnect=true`). |
| 6 | Lobby subscriptions and fair admission | Implemented & verified: `AuthenticatedLobbyRoom` with `enableRealtimeListing()` (`src/lobby.ts`) and client `LobbyAdapter.gd` real-time subscriptions replacing HTTP polling with exponential backoff and fallback. Signed anonymous JWT admission (`AdmissionSession.gd`, `src/admission.ts`) with expiration, per-caller rate limiting, trusted proxy attribution via gateway secret (`X-Warbase-Gateway-Token`) and `CF-Connecting-IP`, and forged forwarded header prevention. |
| Later | Redis-backed multi-process rooms, alternate transport, larger admin tooling | Assessed for Umbrel candidate: Multi-process Redis scaling is NOT needed and remains disabled (`REDIS_URL` omitted). Single-process Node 22+ architecture runs dependency-free with minimal memory/daemon overhead. Rationale: individual room 60 Hz swept-collision/physics tick is single-threaded and CPU-bound; Redis distributes rooms across processes but cannot divide a single room's simulation across cores, adding serialization latency and daemon overhead. Configuration and disabled-mode tests pass. Live two-worker testing, worker-specific routing and distributed admission limits remain required before activation; see `warbase-colyseus/deploy/SCALING.md`. |

### Other Colyseus administration tools

The [Monitoring Panel](https://docs.colyseus.io/tools/monitoring) is the lightweight live room/process inspector. [Playground](https://docs.colyseus.io/tools/playground) is an interactive connection/message/state debugger, enabled locally only. The beta [Admin Panel](https://docs.colyseus.io/admin) is now installed on Umbrel with official database/auth packages; it adds roles, audit logging, operator sessions, live room inspection and configurable widgets. The hosted Cloud dashboard belongs to a separate service; Umbrel does not provide its hosted deployment/billing views.

## Historical audit and implementation evidence

Audit date: 29 October 2026. Scope: current `warbase-colyseus` candidate and Godot adapter, compared with Colyseus 0.18 documentation. Accounts, profiles, saved progression and databases are excluded. Session admission/security is included because it protects live matches without requiring saved accounts.

**Status update, 30 October:** The historical audit below describes the earlier implementation. See [the current follow-up](colyseus-followup-2026-10-29/REPORT.md) for changes, deployed candidate versions, verified Web gameplay and the failed 64-player performance gate. Private loopback-only metrics are now enabled on the candidate.

## Answer in plain language

**No, we are not using every Colyseus feature. We are using its main shooter networking features, with several important gaps.** This is a real framework integration, not just our old protocol renamed: Colyseus buffers inputs, acknowledges them, runs the fixed-step driver, predicts/reconciles the local player, smooths remote players, and supplies the rewind view used for hit checks.

However, the most complete integration is on-foot movement. Vehicles, grenade presentation, room browsing and diagnostics still contain substantial custom paths. More features being enabled would not automatically make the game faster or reliable. Our measured collision bottleneck lives in the simulation callback that we supply to the framework.

“Used” below means present in code, not production acceptance. The earlier load tests and position-error findings remain relevant; enabling an API is not proof that its integration is correct under every condition. This is an audit, not an implementation change.

## Features in use

| Capability | Status | What our game actually does | Code evidence |
|---|---|---|---|
| Authoritative rooms | Used | `BattleRoom` owns players, damage, ammo, respawns, bots, grenades and vehicles. | `warbase-colyseus/src/battle-room.ts` |
| Room lifecycle | Used | Join, drop, reconnect, leave and disposal hooks manage live entities and cleanup. | `BattleRoom.onJoin/onDrop/onReconnect/onLeave/onDispose` |
| Capacity and seat reservation | Used | Room limit is 64 client connections; SDK joins through framework matchmaking/seat reservation. This is a configured limit, not a proven capacity. Bots are game entities, not SDK clients. | `BattleRoom.maxClients`; `ColyseusNetwork.connect_to` |
| Matchmaking/filtering | Used, basic | Framework `battle` room type filtered by logical room; custom HTTP endpoints expose the existing game menu. | `index.ts`: `define(...).filterBy(['room'])`, `createRoom` |
| Binary schema/delta state | Used | `MapSchema` players and vehicles are synchronized by Colyseus, rather than a custom full JSON network protocol. | `src/schema.ts`; Godot `ColyseusSchema.gd` |
| Separate simulation/publication rates | Used | Server simulation 60 Hz; schema patches 20 Hz. | `setFixedTimestep`, `patchRate=50` |
| Buffered typed inputs | Used | Declared movement/aim input schema, sanitization ranges, buffer and consumed sequence acknowledgements. | `defineInput`; `inputs.get(...).next()` |
| Local prediction and replay reconciliation | Used | Official Godot SDK reconciler runs our movement step and replays pending inputs after authoritative updates. | `ColyseusNetwork.gd`: `predictor.reconciler`, `_predict_server_step` |
| Remote interpolation | Used for players | SDK lerp for position and wrap-aware yaw. Existing legacy player interpolation is bypassed for this path. | `predictor.attach_all`, `get_sdk_remote_poses` |
| Clock/RTT | Used, with custom bridging | SDK clock drives prediction/render timing and ping; an epoch conversion bridges our pose timestamps to SDK time. This conversion deserves continued validation. | `room.clock`, `get_pose_clock_diagnostics` |
| Lag compensation/rewind | Used | Server retains 400 ms history and resolves shots through `lastSeenBy`; separate interpolation groups preserve discrete animation changes. | `allowRewindState`, `attachAll`, `fire` |
| Reconnection | Used on native | Server allows 15 seconds; client has a final 14-second deadline and waits for new state. The pinned SDK documents Web automatic reconnect as unsupported; Web interruption is handled as terminal. | `onDrop`; Godot reconnect handlers and `_process` |
| Transient action messages | Used | Fire, damage, confirmed hit/kill, grenades and explosions use room messages alongside schema state. | `onMessage`, `broadcast`, `client.send` |
| Framework timers | Used | Reload completion uses the room clock; several game deadlines still use application timestamps. | `this.clock.setTimeout`; runtime deadlines |
| Graceful shutdown | Used | SIGTERM/SIGINT trigger framework graceful shutdown with a bounded fallback. This does not migrate an active room to another process. | `src/index.ts`: `shutdown` |
| Framework test support | Used in development | Actual room tests use `@colyseus/testing`; SDK and real Main scene checks supplement simulation fixtures. | `package.json`; room/client tests |

These capabilities follow the official [netcode model](https://docs.colyseus.io/netcode), [room lifecycle](https://docs.colyseus.io/room/lifecycle), and [state synchronization](https://docs.colyseus.io/state). The framework supplies networking machinery; our code still supplies the simulation and game rules.

## Useful features absent or only partly integrated

| Capability | Current situation | Benefit and tradeoff for this game | Priority |
|---|---|---|---|
| Composite/physics prediction: `or Predict.sim` | Unused. Local player uses scalar reconciler; cars use server state plus custom Godot smoothing. | Evaluate a shared vehicle+driver prediction model, including entering/exiting seats. Requires replay-safe vehicle state and parity tests; it is not a switch that fixes car physics. | High: investigate |
| Predicted event settlement: `define_event` | Unused, although the pinned Godot wrapper exposes it. | Could settle/deduplicate speculative effects when authority confirms/rejects them. Keep damage server-authoritative and prevent replayed sounds/particles. | Medium |
| Predicted spawns: `spawns` | Unused; grenade messages and local effects are custom. | Could improve immediate grenade/projectile presentation and reconcile optimistic objects with authoritative ones. Does not supply grenade physics. | Medium |
| Prediction diagnostics | Implemented for QA, not always-on gameplay: adapter exposes sent/ack/pending/epoch, correction/drift and reconnect data; observer samples walking, respawn and vehicle phases and marks seat, reconnect and frame-stall events. | Use bounded observer reports to attribute position errors and frame stalls before changing prediction behavior. | Highest; continue measuring |
| Per-client `StateView` | Implemented and verified: `src/state-visibility.test.ts` verifies selective visibility (`ammo`, `grenades`, `throwable`, `ack_input_sequence` remain private to owner; positions, yaw and combat states remain public to peers). Peer view state survives disconnects and reconnects. | Shields sensitive inventory and input sequence acknowledgement from unprivileged peer broadcasts while preserving public combat observation. | Implemented |
| Fine-grained schema callbacks | Implemented and verified: `ColyseusNetwork.gd` implements cached incremental entity updates using GDExtension `on_add`, `on_remove`, `on_change`, and collection-level item callbacks for nested `ArraySchema` (`pos`). | Eliminates full-state dictionary conversions on every tick; verified through `IncrementalColyseusState.tscn` passing all incremental conversion checks. | Implemented |
| Schema encoding optimization | Partial: correct delta sync, but broad `number`/string fields, overlapping yaw/quaternion data and public per-player fields remain. | Measure encoded bytes/patch cost before choosing smaller numeric encodings or restructuring. Precision changes must preserve aim and movement. | Medium |
| Built-in lobby / queue rooms | Implemented: `AuthenticatedLobbyRoom` with `enableRealtimeListing()` (`src/lobby.ts`) and client `LobbyAdapter.gd` real-time subscriptions replacing HTTP polling. | Real-time push updates for room card listings with graceful backoff and reconnect handling. | Implemented |
| Framework admission hook | Implemented: server-signed anonymous JWT admission tickets (`src/admission.ts`, `AdmissionSession.gd`). | Tickets carry cryptographic signatures, expiry TTLs, and are required before room matchmaking. Verified in `src/admission.test.ts`. | Implemented |
| Abuse controls / room plugins | Implemented: trusted proxy attribution (`CF-Connecting-IP`, `X-Warbase-Gateway-Token`), preventing direct clients from forging forwarded headers; per-caller rate limiting for ticket issuance and room creation. | Enforces fair admission limits per genuine caller IP and denies unauthorized or forged requests. | Implemented |
| Built-in monitoring / persistent operational telemetry | Token-protected `/internal/metrics` reports bounded aggregate timing and process data. The Colyseus Monitoring Panel is now mounted on the Umbrel candidate and reachable only through the host's Tailscale IPv4 port binding; the candidate rejects its public gateway route. The panel can inspect and alter live room state, so tailnet access is administrator access. | Use the panel for current room/client inspection and actions; use metrics for performance samples. Neither provides long-term history. | In use, private |
| Multi-process presence/driver | Evaluated & architectural decision documented: Single-process Node 22+ architecture runs dependency-free with `REDIS_URL` omitted. Single-room 60 Hz physics/BVH swept collision is CPU-bound on a single thread; Redis presence distributes separate rooms across worker processes but cannot divide a single room's simulation across cores, adding latency and daemon overhead. Umbrel host profile is single-node. Extensible infrastructure is tested in `src/room-infrastructure.test.ts`. | Keep Redis disabled for Umbrel candidate; activate via `REDIS_URL` only if horizontal multi-server scaling is ever required. | Architectural decision: single-process |
| Alternative WebSocket transport | Default `@colyseus/ws-transport`; no uWebSockets/Bun integration. | Benchmark only if transport/serialization becomes the bottleneck. Current profiles point to collision CPU, so a transport swap is not the first fix. | Low now |
| WebTransport/datagrams | Unused. | Current official prediction docs describe unreliable input as experimental and JavaScript/TypeScript-SDK-only; it is not a drop-in option for our pinned Godot native client. | Not currently a cross-platform option |
| Streaming collections | No integration. | Potentially useful for very large datasets/worlds, but unnecessary to enable blindly for a 64-player match; verify SDK support and actual data size first. | Low now |

The official [prediction documentation](https://docs.colyseus.io/netcode/client-prediction) distinguishes scalar prediction, composite simulation, events and predicted spawns. The pinned Godot wrapper exposes `sim`, `define_event`, `spawns`, pending input counts and drift values; this audit found no game-adapter calls to those optional prediction primitives.

[StateView documentation](https://docs.colyseus.io/state/view) describes visibility filtering, its extra serialization work and its dataset limitations. It is not automatic interest management: we must decide what each player should receive. [Scaling documentation](https://docs.colyseus.io/scalability) distributes rooms across processes; one room remains owned by one process. [State optimization](https://docs.colyseus.io/state/optimization) is relevant to encoding costs, not a substitute for profiling the simulation.

## What Colyseus does not replace for us

We still implement collision geometry, movement rules, weapon damage/cadence, animated hitbox shapes, bot AI/navigation, car handling/seats, grenade physics, round/team rules, graphics, sounds and menus. Colyseus can schedule and synchronize those systems and reconcile a supplied deterministic simulation. It does not provide finished Battlefield-style combat or map physics automatically.

Therefore, enabling every optional feature is not the goal. Relay/WebRTC-style alternatives are not substitutes for our authoritative shooter design. Redis scaling cannot fix one room's slow collision step. More interpolation can disguise some network variation but cannot cure a frozen main thread.

## Recommended order

1. Finish correctness and performance of the core integration: match-state synchronization, prediction drift by phase, reconnect policy and frame-time tails. Repeat the official workload only with bounded diagnostics and cleanup.
2. Keep the optional metrics route disabled until deployment secrets and gateway privacy are configured; add signed admission only when a trusted issuer exists.
3. Keep shared schema state. Revisit StateView only after fixing and passing the native Godot decoder probe; then compare bandwidth and CPU before changing public fields.
4. Evaluate composite vehicle prediction and consistent event/spawn settlement; validate respawn and seat transitions explicitly. These are not safely interchangeable with the current scalar player reconciler.
5. Add lobby/queue/scaling/alternative transports only against a measured need and cross-platform SDK compatibility.

## Evidence and limits

Primary code: `warbase-colyseus/src/battle-room.ts`, `src/schema.ts`, `src/index.ts`, `package.json`; `warbase-godot/client/scripts/net/ColyseusNetwork.gd`, `ColyseusSchema.gd`, `MultiplayerManager.gd`; `scripts/vehicles/CombatJeep.gd`; `client/addons/colyseus/colyseus.gd` and its version manifest. These findings apply to the candidate, not the legacy main Go service. “Unused” means no production integration found in these application paths, not that the dependency lacks the feature. No percentage is assigned: feature counts differ by SDK and many alternatives are mutually exclusive.

## Implementation follow-up — 29 October 2026

The report's highest-priority diagnostics and basic admission/message safeguards are implemented in the working tree. The Godot adapter exposes read-only prediction/reconnect counters to QA, and the official observer records phase-specific position error plus bounded event markers. Its 10-second client-side reconnect error gate is now 14 seconds, leaving one second before the server's 15-second reconnection window expires.

The server records tick cost and scheduling gaps, late ticks, consumed/empty movement inputs, joins/leaves, rejected admissions/payloads and per-action rate limits. `/internal/metrics` is 404 by default and requires a bearer token when explicitly enabled. It reports aggregate counts only. Fixed-window limits are process-local and do not prove player identity or stop a determined anonymous attacker.

Verification completed for the implementation: server TypeScript build and its 42-test suite passed (one opt-in benchmark skipped); the public API checker passed its three offline tests; Godot observer diagnostics and a bounded two-client reconnect smoke passed. The earlier bounded production-schema StateView run lacked a matched unfiltered baseline. A minimal versioned repro now exists at `warbase-colyseus/repro/state-view/`; its Node SDK baseline, owner/non-owner filtering, reconnect, and removal checks pass. In native Godot 4.7.2 with the pinned 0.18.7 addon, both peers joined the same probe room and got patches, but each saw only its own `players` entry in both filtered and unfiltered modes. Since the unfiltered baseline also fails, this does not establish a StateView-specific cause. The external probe is at `warbase-godot/state-view-repro/`; the Web build and Godot reconnect/removal remain unverified. StateView remains disabled and no upstream defect is established.

The safeguards and metrics server were committed as `8958d27` and pushed to `thevaidik/codex/colyseus-migration`. On 29 October the isolated sidecar was rebuilt from that source and smoke-tested before replacement. The deployed candidate reports healthy, lists all ten maps, shows zero connected players, and returns 404 for metrics while no token is configured. The legacy server and root route were left untouched. The candidate's bundled Godot Web assets were not re-exported in this deployment, so the Godot adapter/QA changes in this commit still need a client build before users receive them.

Still open: native-client StateView compatibility, `Predict.sim` vehicle prediction, predicted event/spawn settlement, fine-grained incremental schema decoding, verified admission tickets, and deployment of these follow-up changes. Room creation retains a process-wide overload ceiling; caller-specific limits are unavailable because the deployed reverse-proxy chain has not been verified. Room joins use a shared room-level anonymous ceiling because the Colyseus auth callback has no verified caller identity. These limits do not establish identity or prevent distributed anonymous abuse. Each item needs a specific compatibility or safety test before activation.

## Current outcome — 30 October 2026

The reconnect, metrics, package-provenance, input-acknowledgement and collision-cache work is now implemented on the isolated candidate. The native reconnect checks and seven-bot Web match passed. The exact movement-cache parity checks passed, and the cache-enabled client showed lower frame tails in one full-room run, but that run still measured 28.88 ms p95 / 55.21 ms p99 at 60 FPS with three disconnects. It is not a smoothness pass. A later official Web 64-player attempt stopped at its observer gate and is recorded as incomplete; it did not test Web full-room gameplay. See the [dated results and remaining gaps](colyseus-followup-2026-10-29/REPORT.md) and [implementation outcome](COLYSEUS_FOLLOWUP_FOR_LUNA.md).

The candidate is deployed separately from the legacy game route. The latest full-room acceptance gate remains open; optional vehicle prediction, predicted events/spawns, native StateView compatibility, and caller-specific admission limits remain unimplemented or inconclusive by design.

The Colyseus Monitoring Panel is running on Umbrel at `http://100.107.118.10:8082/monitor/`, bound to its Tailscale address. At enablement there were no active rooms, so the panel initially showed an empty room list. `/colyseus/monitor/` through the public game gateway returned 404, while the public maps API remained available.
