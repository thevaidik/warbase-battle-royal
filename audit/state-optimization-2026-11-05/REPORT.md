# State processing and load-test follow-up — November 5–6, 2026

## Applied

The Godot adapter now accepts the SDK's already-created snapshot for the flat player and objective schemas. Previously it recursively copied every scalar into another dictionary. Nested schemas, dictionaries and vehicle arrays retain deep conversion. This changes no wire fields, physics calculations or hit handling; the official SDK remains unmodified.

A regression checks all 64 player snapshots against the old path, mutation isolation in both directions, objective parity, nested room/vehicle isolation and that the optimized schema definitions remain flat. The five-round batch benchmark measured 75,861 versus 31,041 microseconds median: about 59% less time for this conversion workload. This is not a whole-game FPS improvement claim.

The load harness now supports coordinated cohorts in one official room. A new runner distributes 63 SDK clients across three OS processes, waits for all cohorts plus the packaged native observer, then starts the measurement together. Signed admissions use the existing public issuer and quota; tokens are passed in temporary owner-only files, removed at cleanup. No server security exception or localhost capacity test is used.

Each helper records CPU relative to one core and event-loop timing. Qualification subtracts the union-bound estimate of unproven occupancy intervals, requires every cohort to verify the same live roster, and rejects active drops, incomplete cohorts, missing telemetry or suspected helper starvation. Raw event-loop histogram timing includes its sample period; the final runner separately records excess delay above that period. Per-shard latency percentiles are retained rather than averaged.

## Measured baseline

The three helper processes used at most 6.29% CPU each. Nevertheless, application ping p95 remained 3,560–3,666 ms and the observer's frame p95/p99 were 55.211/113.293 ms. Two helper sockets dropped and recovered. The conservative shared full-occupancy lower bound was only 58.15 seconds, below the 60-second qualification gate. **The run fails acceptance.**

Matched server telemetry measured approximately 34.89 fixed steps per wall-clock second across the sampled full-roster window, against an advertised 60 Hz; worst rolling tick p95 and sample counts are in `baseline.json`. This motivates active-room profiling. Low helper CPU alone does not establish the cause of network or scheduling delay. This sharded workload has different cohort vehicle contention from the earlier single-process run and is not its exact before/after comparison.

A late baseline CPU profile captured cleanup, so it is excluded from full-load diagnosis. The subsequent capture is deliberately triggered after all three cohorts are ready.

## Rejected experiment

Precomputing server triangle edges and normals preserved 1,440 sampled ray results and 1,440 movement results exactly across ten maps. However, the mixed movement benchmark was slightly slower: 160.368 → 164.135 ms median, with added memory cost. It was reverted completely. See `rejected-server-cache.json`.

## Verification

The 15-scene bounded Godot suite passes, including the new snapshot contract. The server suite passed 90 tests with one optional benchmark skipped during the cache experiment; production server geometry was restored byte-exact to the preceding release. Performance-tool tests include the existing gate tests, seven input/admission contracts and six multiprocess qualification contracts. Matched native/Web exports and Web compression round-trips pass.

The deployed release is `warbase-colyseus:state-pass-20261105`; native/Web source fingerprint is `dc955da473cb2954de80658f34f9be9db0af5659116abd036ff4f83173d1d1d3`. Staged health, signed admission, cache policy and private dashboard isolation checks passed. Public verification is recorded separately.

## Remaining work and framework boundaries

Repeated-session retained-object growth remains open; this allocation reduction is not a fix for ownership retention. No quantization, distance-based StateView culling, lower simulation/patch rate, custom reconnect mechanism or physics-engine migration is shipped. Those change accuracy, relevance or integration behavior and require matched measurements and compatibility tests before rollout.

The current 20 Hz schema patches, owner-only inventory StateViews, SDK prediction/reconciliation and 60 Hz declared fixed timestep remain in use. Server scheduling under load, prediction/frame tails and a memory plateau remain acceptance gates.

## Primary guidance

- [Colyseus load testing](https://docs.colyseus.io/tools/loadtest): separate helper processes/machines and watch helper saturation.
- [Colyseus state optimization](https://docs.colyseus.io/state/optimization): benchmark schema types, patch frequency and view encoding costs before changing them.
- [Godot CPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html): profile bottlenecks, reduce redundant work and measure changes.
- [Godot RefCounted](https://docs.godotengine.org/en/4.4/classes/class_refcounted.html): reference cycles need ownership fixes, not an allocation-rate workaround.

Reproduce the load with `node warbase-colyseus/scripts/official-load-multiprocess.mjs --shards 3 --seconds 95 --output-dir /tmp/warbase-sharded-example --native-executable /absolute/path/to/the/packaged/game`. It deliberately generates 64-player traffic on the official deployment. Run it on a different machine from Umbrel, with no concurrent builds, and collect private server metrics separately. Raw captures stay under `/tmp/warbase-sharded-*`; compact credential-free evidence is versioned here.

## Deployed candidate result

The subsequent candidate run failed during population: the native observer disconnected at 41.493 seconds, after seeing at most 44 remotes. All 63 helpers did not finish joining; logs show abnormal socket closures and seat-reservation-expired errors. The ready barrier was never reached. The runner correctly rejected the capture, and now also terminates cohorts immediately if the owned observer exits prematurely. Missing helper resource samples during failed population cannot qualify as zero resource use.

This is not evidence of a full-room FPS improvement or a proven cause in either Colyseus or the public ingress. The adapter's partial-load frame p95 was 17.688 ms, which cannot be compared directly with the baseline's completed 64-player interval. The server had no schema exception in its recent logs. Both full-load profiling attempts remain unqualified: the first was late, and the next barrier-triggered capture could not begin. A fallback profile was after cleanup and is also excluded.

Further work must first isolate public connection resets and the large input backlog with synchronized client, server and ingress timing. Then obtain a successful sustained-room capture before changing tick frequency, precision, relevance filtering or the physics engine. The allocation improvement and test tooling are verified; these reliability and capacity gates remain open. Repeated-session retained-object growth also remains unresolved.
