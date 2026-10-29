# WarBase performance and improvements

**Updated:** 28 October 2026. This describes the combat release deployed as image `warbase_server-warbase-server:combat-final-20261028`, protocol 5, web pack `game-ae08372d77d11dd3.pck`. Measurements are snapshots from specific tests, not guarantees for every device, map or network.

## Improvements made

- **Less network traffic:** the server simulates at 60 Hz and sends snapshots at up to 20 Hz. Moving players within 35 m can update at 20 Hz, from 35–120 m at 10 Hz, and farther away at 4 Hz. Stationary players receive less frequent updates; each player still receives their own latest state. This lowers repeated data while keeping nearby combat responsive.
- **Reuse and compress data:** player wire entries are encoded once per snapshot and shared among viewers. Negotiated continuous GZIP keeps compression history between messages; clients that do not negotiate streaming use independent GZIP frames; online clients still need protocol 5. One 30-frame test fixture used 14,473 bytes instead of 20,626 bytes, about 30% less. Actual savings vary with activity and compatibility.
- **Control congestion:** incoming movement is coalesced, state delivery is bounded, and critical events have priority over cosmetic effects. Unsent partial snapshots preserve pending actor and vehicle changes. Vehicles get an initial baseline followed by changes, including a baseline for late joiners. Client movement and driving inputs have bounded outstanding queues.
- **Reduce client overhead:** remote actors are created gradually, weapon geometry is shared, and distant visual details use level of detail. Bone-following hitboxes remain active across visual LOD levels so distant shots can still register correctly; presentation is simplified rather than removing limb hitboxes.
- **Keep server work bounded:** the initial bot navigation graph builds asynchronously. Hit validation uses a conservative broad-phase test before checking animated capsules; per-player pose history is fixed-size, and historical validation is bounded to at most 750 ms. Standalone benchmarks measured roughly 0.76 µs for a current-pose intersection and 0.90 µs for a historical-pose intersection, with zero allocations. These numbers are geometry benchmarks, not full server or frame costs.
- **Reduce web transfer without reducing texture quality:** the current initial web pack is 67,600,539 bytes uncompressed, 36,958,132 bytes with gzip, or 34,683,032 bytes with Brotli. Compression was checked to reproduce the original bytes. Football Stadium is a separate optional download; the web manifest and cache affect what a particular player actually transfers.
- **Improve correctness under load:** explicit player departures remove ghost actors, and authoritative snapshots can recover a stuck respawn screen. Hitboxes follow the animated head and limbs, and the server validates the pose the shooter saw within its trusted rewind window. Online hitmarkers wait for server confirmation. Audio is disabled.

## What was measured

All online tests below used the official `war.vaidik.blog` public WebSocket route. The test clients and server shared a Tailnet; these results do not represent geographically diverse players. They used automated load clients and the exported game, not 64 human players.

| Test | Result | Scope |
| --- | --- | --- |
| Earlier networking release, 30-minute endurance | 64 peers, zero unexpected connection errors; median RTT 375 ms, p95 665 ms. Two cars travelled about 7,171 m combined. | Protocol clients on the release before the later combat and hitbox changes. A near-end sample showed 198.7 MiB RAM and about 95% of one logical CPU. One sample does not establish peak use or prove the absence of leaks. |
| Current combat release, 120-second native observer | Room API confirmed 64 players; 63 load peers joined without errors. Native client had zero disconnects, 9 confirmed hits and 3 confirmed kills, and drove about 119 m. | Exported Mac client plus simulated peers on Industrial Zone. Median frame time 18.0 ms, p95 34.2 ms; median ping 456 ms, p95 716 ms. |
| Earlier Web observation, 180 seconds | 64-player room, zero Web-client disconnects, car entry/driving/exit; median frame 33.33 ms, p95 34.04 ms. | Earlier release in the in-app browser at 473 × 853, approximately 30 FPS. This was not a normal desktop fullscreen browser test and was not rerun for the latest combat release. |

Earlier and current runs have different builds and conditions; their frame times are not a controlled before/after benchmark. See the [production follow-up](audit/production-followup-2026-10-28/REPORT.md) and [combat audit](audit/combat-balance-2026-10-28/REPORT.md) for methodology, evidence and release identities.

## Remaining work

- **Latency and frame consistency:** the public route is still slow in these tests, with occasional long snapshot gaps. The latest full-room native test also showed a maximum 5.58 m prediction discrepancy, although no corrections were applied. Profile and test across networks and devices before claiming competitive latency or consistent frame rates.
- **Stadium movement:** a previous full-room Stadium test had 53 movement corrections and one load-peer disconnect; its cause needs further diagnosis and a clean repeated test.
- **Crouch pose:** dedicated third-person crouch/prone pose and stance replication still need work. Existing hitbox verification covers standing, running, firing and jumping.
- **Browser and distribution:** complete normal desktop Chrome, Safari and Firefox fullscreen/pointer-lock checks. Resolve Stadium redistribution rights and macOS signing/notarization before public distribution.
- **Capacity limits:** 64-player evidence does not prove 100-plus players, 30 simultaneous vehicles, zero packet loss, or production readiness for all conditions. The [October 12 netcode audit](NETCODE_AUDIT_AND_OPTIMIZATION.md) is historical; its 60 Hz near-player snapshots, culled limb hitboxes, blanket AAA verdict and old benchmark expectations no longer describe the current game.
