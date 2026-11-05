# Controlled packaged-client performance follow-up — 2026-11-05

The controlled release improves existing collision-query costs while retaining the official Colyseus SDK. **Production performance acceptance remains open.** No renderer quality downgrade or replacement networking stack was introduced. Audio remains disabled.

## Changes and correctness

- Vehicle prediction memoizes exact static ray queries, bounded to 8,192 entries and invalidated per map. Dynamic vehicle collisions remain evaluated. All 1,320 populated fixture samples match uncached results exactly. Fixture replay fell from 2,546,482 to 1,360,918 microseconds; this is a microbenchmark, not a whole-game FPS claim.
- Static triangle origins, edges and normals are computed once per loaded map. The BVH, intersection boundaries and collision semantics are preserved. 7,680 sampled cases across ten maps plus degenerate cases pass parity. Direct triangle benchmark: 8,283 versus 3,373 microseconds. Maximum additional active-map storage is approximately 5.14 MiB.
- Game-owned room signal subscriptions now disconnect on teardown/error; a WeakRef regression checks callback cleanup. The official SDK itself is unchanged.
- Separate prediction/state/vehicle timings and per-phase frame percentiles identify spikes. SDK composite numeric correction is explicitly labelled numeric, not metres.
- Load tooling uses supported SDK buffered inputs and Node ws. It checks actual open sockets and live server clients, freshness and sustained occupancy, counts transient recovery, and excludes outage intervals. Seven behavioral contract tests cover the harness. Admission caches are protected, endpoint-bound and expiring.

## Packaged native evidence

The `native-external` run used the public domain, a packaged native observer and 63 official SDK helpers. It maintained **64 live players for 94.2 seconds**, minimum 64 during the measured full-room interval, with zero helper/observer disconnects. The observer drove 127.7 m, registered five hits and threw two grenades.

| Measurement | Result |
| --- | ---: |
| Native frame p50 | 6.896 ms |
| Native frame p95 | 20.572 ms |
| Native frame p99 | 93.395 ms |
| Worst sampled server rolling tick p95 | 35.244 ms |
| Helper application RTT p95 | 4,122 ms |

**The strict 60 FPS / tick budget fails.** The 125-second observer capture includes startup and cleanup around the 94.2-second full-room interval. A separate smaller/mixed-load native run had p95 13.744 ms; it cannot certify 64-player performance.

Early baseline runs using an unregistered vehicle message or frozen schema occupancy were invalid. `baseline-ws` sustained occupancy but used an older client and a different mode/workload, so it is not a controlled before/after speedup. All compact summaries are retained with these limits.

## Web evidence

The production packaged Web observer reached 63 remote players and drove 127.1 m, then dropped at 34.815 seconds. Frame p50/p95/p99 were 16.666 / 33.332 / 133.317 ms. It did not complete the planned 125 seconds. **Web full-room acceptance fails.** Browser RSS and normal-browser mouse-look acceptance were not measured in this run.

## Session memory and reliability

The public-server lifecycle reproduction completed four joins. Cleanup object counts grew 1,880 → 2,205 → 2,530 → 2,855; static memory grew about 0.43 MiB per subsequent join. Resource count stayed 12. The fifth join hit Cloudflare origin TLS error 525. **Memory plateau and long-duration stability are not passed.**

A temporary SDK wrapper experiment did not resolve the retained-object growth and was reverted. There is no maintained vendor fork. The saved lifecycle runner and compact rows support a focused Godot/SDK ownership investigation. The TLS failure also requires separate investigation; transport/security timeouts were not weakened.

## Framework policy and remaining work

Use Colyseus room lifecycle, buffered inputs, authoritative state and built-in reconnection. Avoid introducing another custom transport, retry loop or collision engine. A shared Rapier/Jolt physics prototype would require pinned native/WASM versions and recorded parity tests before adoption; neither is installed or claimed to be a drop-in replacement.

Remaining gates: frame-time tails under sustained full-room load, server tick/RTT tails, repeated-session memory plateau, and a longer quiet-machine soak. These are measured gaps, not completed production certifications.

## Release provenance

The measured full-room release was `warbase-colyseus:controlled-20261105`, with paired native/Web source fingerprint `ec765eb0e5e785f158e69274c5f8698e31729cabeebfc8d3751b01477cfca54b`. The isolated reconnect probe passed. The final deployed release is `warbase-colyseus:controlled-reconnect-20261105`, paired native/Web fingerprint `95e17f95ac5406ea3a28b3514fd8669988dcafae2416c9e9c019ef1f459da735`. Public manifest, health and ten-map/ten-room listing checks pass after promotion. An early public check during restart returned 502; the post-promotion check passed. Raw large captures remain under `/tmp/warbase-controlled-*`; compact summaries here contain no admission credentials.

## SDK Web recovery verification

An isolated packaged Web probe intentionally called the official SDK `room.drop()` at ten seconds. The SDK reconnected in 1,084 ms; the adapter resumed fresh authoritative state, advanced input epoch 0 → 1 and received ACK 1,342. It completed all 35 seconds connected. The adapter previously terminated Web drops before allowing this SDK path; that guard is removed. No custom retry loop or SDK modification is included. This one-client/seven-bot check verifies recovery only; it does not overturn the failed full-room frame-time result.

To reproduce the lifecycle trace, copy `memory-lifecycle-node.gd` here to `/tmp/warbase-memory-lifecycle-node.gd`, then run Godot headless with the WarBase client project and `--script` pointing at the absolute path of `memory-lifecycle-runner.gd`. It connects to the public deployment and performs up to eight sequential test joins; do not run concurrently with performance acceptance captures.
