# Colyseus combat-server evaluation

**Scope:** evaluate replacing the Go combat server while retaining the Godot game, native and web clients, and the existing gameplay. This is a feasibility assessment, not a completed migration or proof of production readiness.

## Candidate

[Colyseus 0.18](https://docs.colyseus.io/) is an open-source Node.js/TypeScript authoritative multiplayer framework. It provides rooms, matchmaking, state synchronization, fixed-step simulation and [server-side rewind primitives](https://docs.colyseus.io/netcode/lag-compensation). It is a candidate for replacing our match transport and lifecycle as well as hosting adapted combat code. It does not ship WarBase's complete FPS combat, vehicle, bot or map rules.

The [Godot SDK](https://docs.colyseus.io/getting-started/godot) lists native and web support, but its GDExtension is explicitly beta. Older porting notes caused ambiguity about native prediction support. Inspection of the pinned v0.18.7 Godot SDK now confirms actual `Predict.reconciler` and `Predict.sim` APIs, buffered inputs and clocks. A bounded native smoke check loaded its client class; integration and exported web/native gameplay checks remain pending. See the [migration work log](COLYSEUS_MIGRATION.md).

## Work required to replace the Go service

1. Build a Godot-to-Colyseus connection and room joining flow for both Mac and web, including disconnect, reconnect and server list. The current client speaks our own protobuf/WebSocket protocol; Colyseus state messages are not wire-compatible by default.
2. Port and verify match rules, input validation, health, respawn, weapons, damage, animated hitboxes and lag compensation. Port map collision, server bots, grenades and vehicles, including seat and driving authority. Reuse existing gameplay data where possible, but a TypeScript implementation still needs equivalent behavior and tests.
3. Recreate or explicitly replace existing area-of-interest filtering, compression, bounded queues, acknowledgement handling, snapshot recovery, abuse checks and monitoring. Confirm which Colyseus features meet the requirements through testing rather than assuming equivalence.
4. Package and operate the new server for the Umbrel/Portainer deployment. Preserve public web asset serving, room APIs and WebSocket routing or deliberately update clients and reverse-proxy configuration. Keep a matching previous image for rollback.

## Acceptance gates

- Deterministic parity tests for weapon damage, fire cadence, spawn protection, shot replay, cover, friendly blocking and animated hit regions; verify rewind under jitter and reject spoofed or unavailable historical poses.
- Reconnection, room admission, bots, grenades, vehicle entry/driving/exit, respawns and collision checks on each supported map.
- Actual native and web builds against an isolated official-server test deployment, including desktop browser pointer lock and fullscreen. Do not treat Node-only mock clients or localhost measurements as proof of game performance.
- A matching 64-player official-server test and 30-minute endurance run with CPU, memory, bandwidth, disconnects, frame time, RTT, snapshot gaps and player corrections recorded. Include impairment tests and multiple geographic routes before claiming low latency.
- Compare against the documented [current combat release](combat-balance-2026-10-28/REPORT.md) and [earlier endurance results](production-followup-2026-10-28/REPORT.md), accounting for build, workload and network differences. No single benchmark proves reliability.

## Decision and risks

Colyseus is a reasonable candidate for an isolated proof of concept; it is not yet established as a more reliable replacement for this game. The Godot beta SDK, the availability of client prediction on that SDK, browser packaging, and full-room performance are release blockers to investigate. Existing public-route latency (456 ms median in the combat test) and client frame time may persist independently of the server framework. Do not replace the live service until the port and these gates pass.
