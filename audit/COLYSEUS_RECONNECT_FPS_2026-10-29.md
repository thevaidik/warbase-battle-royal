# Reconnect and frame-rate follow-up

Historical 29 October snapshot; its “no client export or deployment” note was true then and is superseded by the 30 October [candidate follow-up](colyseus-followup-2026-10-29/REPORT.md).

The client reconnect lifecycle now invalidates callbacks from abandoned rooms, stops retries and leaves on timeout or explicit disconnect, and waits for fresh decoded player state after reconnect. A deterministic lifecycle check passed. Two native two-client checks against the official candidate were inconclusive overall: one did not recover before the smoke-test deadline; one recovered with a fresh state and a newer input epoch, but the separate yaw interpolation check failed. Web reconnect remains unverified.

Two 45-second rendered source-client observations used the official Colyseus candidate, Industrial, a 1280×800 window, an Apple M4, a 120 FPS cap, one observer and seven server bots. Both included walking and driving. These are small observations, not release builds or 64-player tests. They do not establish a causal comparison because the gameplay and network conditions varied.

| Measurement | Before map-cache fix | After map-cache fix |
| --- | ---: | ---: |
| Median frame time | 8.33 ms | 8.33 ms |
| 95th percentile frame time | 11.95 ms | 11.73 ms |
| 99th percentile frame time | 75.01 ms | 57.45 ms |
| Worst frame | 141.66 ms | 141.66 ms |
| 95th percentile snapshot gap | 84 ms | 65 ms |
| Disconnects | 0 | 0 |

The source fix prevents repeated server updates for the same map from invalidating its collision data, avoiding repeated decompression and parsing on subsequent movement prediction. Severe stalls still occurred on foot; car driving was mostly smoother. Do not claim the FPS problem is solved. Profile walking prediction, collision sweeps and replay, state processing, entity updates and asset loading in the same phase and workload. Measure release native and Web separately, including a full-room workload and server tick tails. Investigate the intermittent reconnect and yaw test before releasing these client changes. No client export or deployment was performed.
