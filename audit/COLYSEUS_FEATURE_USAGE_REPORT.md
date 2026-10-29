# Colyseus gameplay and networking feature audit

Audit date: 29 October 2026. Scope: current `warbase-colyseus` candidate and Godot adapter, compared with Colyseus 0.18 documentation. Accounts, profiles, saved progression and databases are excluded. Session admission/security is included because it protects live matches without requiring saved accounts.

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
| Reconnection | Used | Framework reconnection window is 15 seconds; Godot uses SDK reconnect events/options. A local 10-second error-reporting gate also exists and should be reconciled with the server policy. | `onDrop`; Godot reconnect handlers and `_process` |
| Transient action messages | Used | Fire, damage, confirmed hit/kill, grenades and explosions use room messages alongside schema state. | `onMessage`, `broadcast`, `client.send` |
| Framework timers | Used | Reload completion uses the room clock; several game deadlines still use application timestamps. | `this.clock.setTimeout`; runtime deadlines |
| Graceful shutdown | Used | SIGTERM/SIGINT trigger framework graceful shutdown with a bounded fallback. This does not migrate an active room to another process. | `src/index.ts`: `shutdown` |
| Framework test support | Used in development | Actual room tests use `@colyseus/testing`; SDK and real Main scene checks supplement simulation fixtures. | `package.json`; room/client tests |

These capabilities follow the official [netcode model](https://docs.colyseus.io/netcode), [room lifecycle](https://docs.colyseus.io/room/lifecycle), and [state synchronization](https://docs.colyseus.io/state). The framework supplies networking machinery; our code still supplies the simulation and game rules.

## Useful features absent or only partly integrated

| Capability | Current situation | Benefit and tradeoff for this game | Priority |
|---|---|---|---|
| Composite/physics prediction: `Predict.sim` | Unused. Local player uses scalar reconciler; cars use server state plus custom Godot smoothing. | Evaluate a shared vehicle+driver prediction model, including entering/exiting seats. Requires replay-safe vehicle state and parity tests; it is not a switch that fixes car physics. | High: investigate |
| Predicted event settlement: `define_event` | Unused, although the pinned Godot wrapper exposes it. | Could settle/deduplicate speculative effects when authority confirms/rejects them. Keep damage server-authoritative and prevent replayed sounds/particles. | Medium |
| Predicted spawns: `spawns` | Unused; grenade messages and local effects are custom. | Could improve immediate grenade/projectile presentation and reconcile optimistic objects with authoritative ones. Does not supply grenade physics. | Medium |
| Prediction diagnostics | Implemented for QA, not always-on gameplay: adapter exposes sent/ack/pending/epoch, correction/drift and reconnect data; observer samples walking, respawn and vehicle phases and marks seat, reconnect and frame-stall events. | Use bounded observer reports to attribute position errors and frame stalls before changing prediction behavior. | Highest; continue measuring |
| Per-client `StateView` | Not enabled. A bounded two-client Godot 4.7.2 probe against the production schema delivered decoded state to only one client; the other client's typed `get_state()` stayed null. | Keep shared state until the pinned Godot 0.18.7 client passes initial sync, updates, reconnect and removal for both peers. Do not infer support from the Node SDK alone. | Blocked by client compatibility |
| Fine-grained schema callbacks | Partial: room state-change signal is used, but the adapter converts the decoded state to dictionaries and scans players. | Incremental field/add/remove handling could reduce conversion work and allocations, if supported reliably by the pinned Godot binding. | High: measure |
| Schema encoding optimization | Partial: correct delta sync, but broad `number`/string fields, overlapping yaw/quaternion data and public per-player fields remain. | Measure encoded bytes/patch cost before choosing smaller numeric encodings or restructuring. Precision changes must preserve aim and movement. | Medium |
| Built-in lobby / queue rooms | Unused; custom HTTP room browser, simple room filter. | Lobby could replace polling for room updates. Queue matchmaking could group players by region/mode/skill if needed. Neither fixes a slow movement callback. | Medium / later |
| Framework admission hook | `onAuth` now bounds and normalizes anonymous display names and rejects reserved bot names; duplicates are rejected in `onJoin`. There is still no verified identity or signed match ticket. | Add short-lived admission tickets if the game gets a trusted identity issuer. Name validation is input hygiene, not authentication. | High for public rollout |
| Abuse controls / room plugins | Per-session action limits, bounded room-creation/join rates and payload checks were added. No IP-based identity, idle-kick policy or unique-account/session plugin is in use. | These limits reduce accidental floods but are not anti-cheat or identity controls; anonymous clients can reconnect and acquire a new session. | High for public rollout |
| Built-in monitoring / persistent operational telemetry | Optional token-protected `/internal/metrics` now reports aggregate room counts, tick timing, late ticks, inputs, validation counts and memory. It is disabled unless `OPS_METRICS_TOKEN` is configured. The admin monitoring panel is not mounted. | Configure a secret only after keeping the metrics route private. Health alone does not prove a playable match. | High |
| Multi-process presence/driver | Defaults only; no Redis-backed shared services. `activeRooms` is a process-local application map. | Distribute different rooms across processes/cores; replace/aggregate the custom local listing. It does not divide one room's physics across cores. | Later, after single-room performance |
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

Verification completed for the implementation: server TypeScript build and its 42-test suite passed (one opt-in benchmark skipped); the public API checker passed its three offline tests; Godot observer diagnostics and a bounded two-client reconnect smoke passed. A separate bounded native StateView probe against the production schema failed: both clients joined, but only one had decoded room state. StateView therefore remains disabled. These latest edits have not been deployed; the legacy service and current candidate routing were left untouched.

Still open: native-client StateView compatibility, `Predict.sim` vehicle prediction, predicted event/spawn settlement, fine-grained incremental schema decoding, verified admission tickets, and deployment of these follow-up changes. Each needs a specific compatibility or safety test before activation.
