# Five optimization tracks — 6 November 2026

## Implementation

All five requested tracks have code and focused verification. This is not a certification that every map, device, or 64-player scenario holds 60 FPS. The final measured acceptance below is separate from implementation status.

| Track | Implementation and evidence |
| --- | --- |
| Correct distributed load rig | 63 official JS SDK peers across three OS processes plus a packaged native observer. Signed admission, public domain, shared start barrier, independent live-roster checks, helper resource measurements and conservative occupancy intersection. Saturated helpers or an early observer exit invalidate the result. |
| Smaller network state | Matched protocol 7 uses float32 transforms, scalar vehicle position, and full-state-only quaternion fields. Authoritative server quaternion values retain precision for rewind. Timestamps, health, counts and ACK sequences are not forced into float32. Old protocols receive an upgrade error before room lookup. |
| Relevance filtering | Official StateView tags separate private inventory/ACK fields from presentation fields. Animation and weapon presentation uses 240m entry / 280m exit hysteresis at 4Hz. Positions, health, teams and objectives remain public. Every weapon range is inside the presentation entry radius. |
| Collision and prediction CPU | Official entity reconciler while on foot; official composite simulation while driving. Unchanged metadata no longer transmits every frame. Exact grounded idle shortcut avoids unnecessary candidate collection. Server BVH candidate reuse limit raised from 32 to 128 after comparative measurements and collision parity verification; duplicate floor queries and provably unread floor lookups are skipped. No new transport or physics engine. |
| Memory ownership | Shared immutable schema definitions; weak signal forwarding; a pinned Godot SDK wrapper ownership patch balances the native matchmaking return reference and preserves async request lifetime. Native dylibs and WASM remain official unmodified binaries. |

## Measured tradeoffs

- In the reproducible 64-actor moving-state microbenchmark, steady patches decreased from **3059.2 to 2189.56 bytes** (28.4%). Initial state increased from **5361 to 7471 bytes**. These are fixture measurements, not total network bandwidth guarantees. See [wire benchmark](wire-benchmark.json).
- StateView filtering costs CPU when nearly everyone is relevant: the 64-recipient microbenchmark increased from roughly 2.5ms to 10–11ms total across 30 patches. It reduces distant presentation traffic and protects inventory; it is not free serialization. See [multiview measurement](multiview-benchmark.json).
- The stationary-only server benchmark decreased from 40.48ms to 31.84ms for 6000 moves. This is not a whole-server speedup. See [idle measurement](idle-benchmark.json).
- Raising the server candidate limit from 32 to 128 reduced the ten-map movement microbenchmark median from **247.11ms to 120.75ms** for 4320 moves. All 1440 comparison inputs matched exactly. 256/512 provided little additional benefit, so 128 bounds scratch storage. See [candidate benchmark](collision-candidate-benchmark.json). Reproduce with `node warbase-colyseus/scripts/benchmark-collision-candidates.mjs`; a second run independently measured 251.88ms → 119.71ms.
- Ten real typed-state join/leave cycles stabilized at **1624 Godot objects**, with neither wrapper nor native room nor decoded root retained. Rejected joins and cancellation before initial state also release both room handles. This fixes the reproduced room ownership leak; it does not prove all game assets or driver memory remain flat indefinitely. See [lifecycle results](lifecycle-fixed.json) and [pinned patch](../../patches/README.md).

## Verification

- Server: full suite 97 tests, 96 passed, one optional benchmark skipped, zero failures. The added settlement-floor regression subsequently passed in the 12-test geometry suite (11 passed, one optional benchmark skipped).
- Godot: 16 bounded scenes covering schema isolation, SDK ownership, movement/collision, reconnect, wheels, grenades, weapons and hitboxes.
- Python tooling: 14 tests passed; load harness/coordinator contracts: 14 passed.
- Native typed-state fixture verifies scalar vehicles, metadata and walking → driving → walking prediction handoff. Remote staged native smoke verifies ACKs, reconnect and peer removal.
- Public Web reconnect completed a 40-second game session with the exact SDK WASM, one intentional connection drop and successful recovery in 466ms. This small-load check does not certify full-room Web FPS. See [Web result](web-reconnect.json).
- Staging verifies gateway admission, forged-header rejection, no-cache HTML, and public admin/monitor blocking. Persistent administrator and secret volumes are preserved.

## Full-room baseline and diagnosis

The protocol-7 run held a conservatively verified **92.03 seconds with 64 live humans**, zero active disconnects, and unsaturated helpers (maximum 7.27% of one CPU core). Native observer frame times across its complete session (including warm-up/cleanup): p50 12.912ms, p95 61.860ms, p99 117.046ms. Effective server simulation was 49.48Hz; worst rolling tick p95 was 29.675ms. **The strict 60 FPS / 60Hz gate failed.** See [baseline](full-room-wire7.json).

The three SDK cohorts entered vehicles 24 times, sent 1056 driving inputs, observed vehicle motion, accepted eight grenades and observed nine distinct explosions. Two confirmed hits were recorded; no kills were recorded. The packaged observer stayed on foot, so this does not certify native driving performance.

A CPU profile captured during verified full occupancy attributed most server samples to collision ray traversal and triangle intersection. That justified the candidate-limit change. A zero-length guard was briefly duplicated during follow-up, caught in review and removed: it already existed and is not counted as a new improvement.

## Release and final acceptance

Final candidate: `warbase-colyseus:wire7c-20261106`. Native/Web source fingerprint: `cd341407d751bbe8c8f0ae152c2460325467a211b47c99f28cdd06a726fd81aa`. Godot 4.7.2; SDK 0.18.9; wrapper compatibility patch `room-lifetime-v1`. Paired native archive is generated at `warbase-godot/client/candidate-native/WarBase-Colyseus-macOS.zip`; generated binaries are not committed.

The intermediate `wire7b` run improved effective server simulation to **53.98Hz** and worst rolling tick p95 to **22.04ms**, but native p95 was **78.28ms** (p50 13.212ms, p99 115.059ms). Two SDK peers had unplanned 1006 disconnects and recovered in 425/471ms. The harness correctly marked this run **invalid for stable capacity certification**, despite 88.45 conservatively observed full-occupancy seconds and unsaturated helpers. This is not a native smoothness improvement claim. See [intermediate result](full-room-wire7b.json).

The subsequent server-only follow-up removes an identical repeated floor query and avoids computing a floor value that the vertical settlement helper cannot read. Existing ten-map reference collision tests pass; a 672-case boundary matrix verifies floor omission preserves falling/ceiling-contact results. A triangle-bounds cache experiment was discarded: its small microbenchmark gain did not justify the added geometry memory. No bounds cache ships.

## Framework boundary

Colyseus supplies room lifecycle, admission hooks, StateView, schema deltas, fixed-step input and reconciliation primitives. Movement rules, collision queries, handling, combat, bots and capture rules remain game logic. The targeted [SDK ownership patch](../../patches/README.md) must be revalidated before SDK updates.

Optional Redis distribution, alternative transports and experimental datagrams are not enabled merely to claim full feature coverage. Redis can distribute separate rooms, not split one CPU-bound room across cores. Full-room Web acceptance, longer memory endurance and multi-map full-capacity coverage remain separate release gates.

### Final deployed measurement

`wire7c` held a conservative 69.12 seconds of observed 64-human occupancy during the 75-second cohort interval, but one SDK peer dropped unexpectedly (1006) and recovered in 455ms. The harness therefore reports **invalid for stable-capacity certification**. Helpers remained unsaturated (maximum 7.33% of one core). The packaged native observer had zero disconnects and 63 remotes; whole-session frame times were p50 **8.455ms**, p95 **51.564ms**, p99 **124.505ms**.

Effective server simulation measured **47.77Hz**, with worst rolling tick p95 **29.41ms**. The strict **60 FPS / 60Hz gate still fails**. The run is not evidence of a consistent whole-server improvement over `wire7b`; spawned positions, collisions and driving paths vary across these gameplay runs. The deterministic microbenchmarks and exact-output regressions support the individual optimizations, while real workload acceptance remains open. See [final measurements](full-room-final.json).

The combat container transmitted **26.396Mbps** and received **3.221Mbps** over a 30-second full-room window. WAN link capacity was not measured, so this does not establish uplink saturation. Remaining diagnosis should separate simulation CPU, public-route transport/egress, and client replay cost before further tuning. The unexpected SDK connection drops remain unresolved; automatic recovery is not a zero-disconnect pass.

All five implementation tracks are delivered. Remaining production acceptance: sustained native and Web frame-time budgets, clean full-cohort public-route connections, longer memory endurance and full-load coverage across maps. No claim that every Colyseus optional feature is enabled or that this game is fully production-certified is made.

After final public health verification, six retired stopped release containers and their obsolete combat image tags were removed. Current gateway/combat services and all persistent administrator/secret volumes were preserved. Temporary remote build contexts and the owned staging SSH tunnel were removed; test admission caches were deleted.
