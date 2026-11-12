# Godot and Colyseus optimization plan

## Evidence and target

The graphical Mac client profile placed 335/336 main-thread samples in synchronous Colyseus input prediction, which calls the GDScript collision solver. A moving input costs approximately 7 ms and a near-wall case approximately 34 ms, before replay/rendering. Server profiling independently identified the same collision algorithm as its main active cost. Two official-domain load diagnostics reached 64 humans at peak but failed sustained client performance; server state gaps remained around one second at p95. These are the baseline, not a capacity pass.

## Research

- [Godot general optimization](https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization.html): measure the bottleneck, improve algorithms/data locality, precompute expensive work, and retain changes only when benchmarks improve.
- [Godot CPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html): expensive calculations may need compiled code; built-in engine operations are already native. Lowering real-time physics frequency has responsiveness costs.
- [Godot profiler](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html): separate script, idle, physics and full-frame costs; profiling itself adds measurement overhead.
- [Godot servers](https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html): lower-level APIs can avoid scene-tree overhead, but synchronous data queries may stall the server. Moving this exact solver to PhysicsServer3D requires measurement and an exact-parity check first.
- [Godot 3D optimization](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html): animation/skinning cost can be reduced for distant actors, but this is secondary to the measured prediction hotspot.
- [Colyseus prediction](https://docs.colyseus.io/netcode/client-prediction): use the same deterministic step and advertised timestep on both sides, tick once per rendered frame, and send one input per returned step. Replay can execute the step repeatedly, so the step must be cheap and free of presentation side effects.
- [Colyseus state synchronization](https://docs.colyseus.io/state): schema patches track changed properties; simulation and state publication are separate cadences.

## Implementation order

1. Optimize the shared collision workload first. Reuse candidate geometry within one movement query, reduce allocations/repeated traversals, and preserve exact wall/floor/jump results. Keep immutable per-map caches and room isolation. Do not hide overload by dropping input steps or changing tick rate.
2. Benchmark moving, idle, jumping, wall sliding and blocked cases before/after. Compare optimized solver output with the existing solver and shared ten-map fixtures. Include fractional heights, vertical velocities and invalid inputs.
3. Verify the actual SDK/Main path with bounded client tests. Measure prediction callback time separately from render frame time, replay count and state gaps. Keep the user's open game untouched until a tested replacement is ready.
4. Apply matching server optimizations and run the full server suite. Preserve authoritative hits, grenades, bots and vehicle behavior.
5. Export isolated native/Web candidates with all map data and SDK binaries. Test the actual graphical client against the official candidate. Headless benchmark timings do not establish graphical FPS.
6. Deploy only the isolated candidate and compare official-domain load results. Record sustained human count, frame distribution/tail stalls, simulation timing, pending inputs, RTT, patch gaps and CPU. Stop a hot/unresponsive observer early and remove helpers.

## Acceptance and fallback

Aim for prediction comfortably below the 16.67 ms simulation budget, including replays; a single-step average alone cannot prove this. No new false wall passage, changed hit damage, precision reduction or input loss is acceptable. A/B changes that regress timing are removed. If exact collision remains too expensive in GDScript after algorithmic improvements, move the shared solver to compiled native/Web code as a separate reproducible build task, rather than adding more expensive script-level patches.

The main Go release remains available until graphical/native and browser gameplay, realistic load, and recovery checks pass. Candidate deployment is not completion of the migration.

## Candidate deployment and short official-server check

The matching server and Web package were deployed to the isolated official candidate on October 29 as `warbase-colyseus:collision-optimized-20261029` (image SHA-256 `0249c19ddf618d662ae0925a49f9ed3993e742fbc015b7be0fe15a30d3202d90`). Public manifest SHA-256 `e3a00acb86f9bc1f3a26b4c5eca7d20e6942148b2e1302723f75b81f9d1e399e` was verified; main-game health remained available.

A bounded 30-second graphical native observer connected to the official candidate, saw seven remotes, sent 1,823 inputs and acknowledged 1,731, with zero disconnects. At a 30 FPS cap, frame p50/p95/p99 were 33.34/54.54/57.13 ms and maximum 138.94 ms. This short check does not cover the earlier ~45-second slowdown or sustained 64-player performance. It reported aggregate position error up to 45.23 m in a run including a respawn and vehicle entry; the report does not attribute maxima to a specific transition, so this requires phase-specific investigation before declaring prediction correct. Snapshot gaps were 101 ms p95 / 1,200 ms maximum. Raw report is `colyseus-migration-2026-10-28/official-single-observer.json`. The observer exited; the updated interactive Mac build was then opened for the user.

## Godot client implementation and results

The existing exact-ground idle fixed-point shortcut remains in place. It only skips the collision step when the player has no horizontal input or jump, has zero vertical velocity, and is within 1 micrometer of the sampled floor. Fractional heights and nonzero vertical velocities still take the full server-matched path. The capsule solver also skips an exactly zero-length sweep; the ray/triangle determinant makes that sweep an exact no-hit.

Two additional client improvements are applied:

- `ColyseusNetwork._predict_server_step()` now samples the starting floor only for a jump or the exact-idle case. The server already queries that floor only for jump input; all normal movement and falling still run the same resolver and post-step floor query. A paired 60-step Industrial run preserved state every step and measured 0.469 ms with the old redundant query versus 0.383 ms with the query gated.
- `ColyseusWorldGeometry.resolve_move()` gathers a conservative swept-capsule candidate triangle list once per move, then reuses it across the capsule sample rays. It follows the shared BVH traversal and leaf order. Bounds are X/Z min/max endpoints ± radius and Y from `min(from.y,to.y)+0.08−1e-4` through `max(from.y,to.y)+0.45+min(height,1.72)+1e-4`. Up to 12 triangles use the candidate list; on the 13th, the list is discarded and all samples use the original ray/BVH path. The candidate loop uses the same triangle intersection, nearest-fraction rule and hit normal. The project data format and movement precision are unchanged.

The candidate collector reuses static traversal arrays, matching the server's reusable collision scratch approach. The reference option `resolve_move(..., use_candidate_cache=false)` exists for focused A/B parity checks; gameplay uses the default cached path. The Godot harness compares analog movement and jump against the uncached step on all ten maps, varies idle height and vertical velocity, and compares 80 fixture moves across all maps. It reports no position difference above `1e-7`.

Bounded headless results on the local Mac: the 80 fixture moves averaged 19.27 ms with per-ray BVH traversal and 4.675 ms with the candidate cache (~4.12× faster). Industrial open movement averaged 0.383 ms per prediction callback; the near-wall case averaged 1.364 ms per move. The separate redundant-floor-query A/B measured 0.469 ms versus 0.383 ms over the same 60-step path. These are single-client simulation measurements without replay, rendering or cohort load; they do not establish graphical FPS or multiplayer capacity. The existing `GEOMETRY_PARITY_OK` fixtures passed across 10 maps, 13 rays and 13 moves. Test script: `warbase-godot/client/scenes/tests/ColyseusIdlePrediction.tscn`.

The bounded real-scene integration test also passed against a loopback Colyseus server and one peer: `COLYSEUS_MAIN_SMOKE_OK moved=18.19 m reconciled remote=PEER_531 coarse_hit_hint=true`, with protocol 5 and Industrial state. The default-backend regression passed and still selects `res://scripts/net/NetworkManager.gd`. Both test processes were cleaned up after completion. The currently open native app remains the earlier candidate build; it was not closed or overwritten during this work.

The implementation follows [Godot's profiling and optimization guidance](https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization.html): measure the hot path and keep only changes that improve it. [Colyseus fixed-timestep input guidance](https://docs.colyseus.io/netcode/server-input) and [client prediction guidance](https://docs.colyseus.io/netcode/client-prediction) require the same deterministic step and one input for every returned fixed step. No input steps are dropped, no movement fields are quantized, and no render or animation work was changed. The framework's SDK `Predict.tick()` wrapper does not expose a safe catch-up cap; overload should be addressed by reducing the deterministic step's cost or through a coordinated server/client tick-rate change, not by skipping buffered commands.

## Server collision implementation and local results

The server movement solver now gathers a bounded set of triangles once for each swept capsule move and reuses that set across its sample rays. It computes the swept capsule sample bounds from the start/end feet positions, radius, height, and step height; traverses the existing BVH in its existing order; and retains the existing triangle ray test, epsilon rules, and strict nearest-hit selection. At most 12 triangle indices are retained. If the query encounters a 13th triangle, it drops the candidate set and uses the original BVH ray path for the entire move. This keeps dense geometry on the known-correct path and avoids a mutable global cache. The public map and geometry formats are unchanged.

The movement test compares the new solver against a test-only copy of the previous solver using the same geometry trace. It covers shared fixtures, authored wall/fence movement, and seeded moves from authored spawns on all ten maps; resulting positions must agree within 1e-7 m. A bounded local microbenchmark ran 168 moves on Industrial and Football geometry: 43.55 ms for the reference solver and 4.72 ms for candidate reuse (9.23x in that run). This is a local algorithm benchmark, not an official-domain capacity or client frame-rate result.

Verification: `npm run build` passed; the bounded server suite passed 40 tests with one opt-in benchmark skipped. The geometry benchmark command is `npm run benchmark:geometry`. The suite's actual Colyseus room test binds loopback and therefore needed the approved elevated local test run.

This follows Colyseus' guidance to keep state synchronization lean and profile room logic, while retaining the advertised fixed-step prediction and patch cadence ([Colyseus optimization](https://docs.colyseus.io/state/optimization), [Colyseus FAQ](https://docs.colyseus.io/faq)). Node's built-in CPU profiler remains the recommended way to identify remaining server hotspots ([Node.js profiler](https://nodejs.org/api/cli.html#--cpu-prof)). The client-side floor-query gate is owned by the Godot client work; no Godot source was changed in this server section.
