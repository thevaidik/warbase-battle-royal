# Colyseus follow-up review and Luna implementation handoff

Reviewed 29 October 2026 against commits 8958d27 and f65c2f0. This is a source review and assessment of existing verification evidence. No new gameplay benchmark was run for this review, and live deployment state was not rechecked.

## Verdict

Keep the recent safeguards and diagnostics, but do not call the game production ready or claim this batch fixed synchronization lag. Most additions improve diagnosis and basic message hygiene. The passing room tests and health/API smoke are useful regression evidence; they do not establish smooth, correct 64-player gameplay on native and Web.

Useful work to retain: authoritative combat checks and prototype-safe weapon lookup, bounded message counters, normalized display names, optional bearer-protected aggregate metrics, bounded phase-specific QA samples, and a separate candidate deployment with a rollback image.

## Implement in this order

### 1. Make reconnect failure final and guard old connection callbacks

Evidence: `warbase-godot/client/scripts/net/ColyseusNetwork.gd:365` emits a timeout and clears the connection intent, but does not stop the room's reconnect machinery. The same room's reconnected callback invokes `_on_joined`, which unconditionally sets connection intent true at line 113. A delayed success can therefore undo the adapter's reported failure. Also audit callbacks from a replaced room: handlers currently reference the adapter's mutable room field.

Implement a single explicit connection lifecycle. On terminal timeout, cancel/leave the appropriate room and release prediction/input resources. Guard callbacks using the originating room or a connection generation so an old room cannot change a new session. Emit the terminal error once. Use the agreed server reconnection window with an intentional timeout policy; a timer value alone does not align lifecycle behavior.

Reset initial-state readiness on reconnect and verify a newly decoded state before reporting gameplay ready. The existing `_has_initial_state` flag survives drops, so asserting that flag alone does not prove fresh state arrived.

Acceptance: successful short reconnect, expired reconnect, success arriving after timeout, leave during reconnect, and switching rooms during reconnect. No late callback revives an abandoned connection, no duplicate input driver or player, and fresh state/input epoch are proven after recovery. Exercise supported Web behavior separately from native behavior.

### 2. Finish client delivery and make stale exports detectable

Evidence: the deployment record explicitly says the server image reused the older bundled Web assets. The updated Godot adapter and QA scripts have not reached exported clients. Asset hashes prove the identity of packaged bytes, not that those bytes came from current source.

After task 1, export native and Web clients. Record client source revision or a relevant source fingerprint, engine/SDK versions and artifact hashes. Check that the fingerprint still matches when packaging; reject stale exports. Support explicitly server-only releases while preserving accurate client version metadata. Package checks should inspect the artifact rather than infer its behavior from current source files outside that artifact.

Acceptance: changing relevant client source after export causes full-client packaging to reject that stale export. Native and Web identify the expected client build and connect to the candidate. Preserve the running user app; create a separate native artifact unless replacing it is requested.

### 3. Make operational measurements useful during actual matches

Evidence: `/internal/metrics` is implemented but the documented deployment leaves it disabled. Room counters are deleted on disposal and the route aggregates only currently retained rooms. Average/max tick duration cannot show p95/p99 stalls or distinguish event-loop delays from simulation cost.

Add bounded tick-duration distributions or histograms, event-loop delay and clearly labeled active-room versus process-lifetime counters. Retain process totals without retaining player identities. Add sampling of patch bytes/serialization cost only through supported framework hooks or measured transport instrumentation. Configure private collection with a deployment secret; do not print tokens or expose the admin panel publicly.

Acceptance: an active test match produces useful samples; closing it does not erase process-lifetime rejection/join counts. No player names, payloads or tokens enter metrics. Verify disabled, unauthorized and authorized endpoint behavior against the real HTTP handler, not only the checker's mocked fetch responses.

### 4. Correct the fairness limits of anonymous admission protection

Evidence: `battle-room.ts:83` consumes a shared process creation allowance before validating map/mode/time, so invalid create requests can spend it. `battle-room.ts:198` shares one join allowance among everybody entering a room. One source can exhaust either shared allowance and delay legitimate players. Display-name checks establish no verified identity.

Validate cheap request fields before consuming expensive-operation allowances. Separate overload ceilings from caller limits. Choose caller identity only after documenting the actual proxy chain; do not blindly trust forwarding headers or use spoofable names as identities. Keep global resource ceilings as explicitly shared overload controls. Preserve access for ordinary joins to existing rooms while room creation is throttled. Signed admission needs a trusted issuer; an anonymous public ticket endpoint alone does not solve identity or abuse.

Acceptance: invalid map/mode requests cannot spend the valid-create allowance; normal supported actions stay within their limits; one abusive test caller does not consume another caller's allocated admission budget where reliable caller attribution exists. Document the remaining limitations when attribution is unavailable.

### 5. Establish a release gameplay gate on the official candidate

Use the finished client builds and private telemetry. Run bounded, separately recorded native and Web workloads with the same map, render settings, player count and actions. Include walking/collision, deaths/respawns, firing, grenade events, car enter/drive/exit, disconnect/reconnect and leave cleanup. Count human SDK clients and bots separately. Keep helpers on Umbrel and cap local observers to avoid heating the Mac with many clients.

Acceptance: record target hardware and frame budget before judging results. Capture frame p50/p95/p99, server tick tails, ACK/pending-input progression, snapshot gaps, and phase-specific reconciliation corrections. Distinguish normal prediction/interpolation offset from actual correction or teleport errors. Missing hits, vehicle transitions, browser coverage or reconnect evidence must remain explicit gaps. Cleanup all owned helpers. Health 200 and a configured 64-player capacity are not substitutes for this gate.

### 6. Optimize client state conversion only if the measurements justify it

Evidence: `_on_state_changed` recursively converts the whole decoded state at `ColyseusNetwork.gd:136`, then scans/normalizes players again. `get_sdk_remote_poses` duplicates each remote dictionary each render update. These are concrete allocation candidates, but this review does not establish their share of frame time.

Measure conversion, remote-pose preparation and downstream entity/animation updates separately. If significant, use verified SDK change callbacks or a stable cache to update affected entries. Preserve reconnect rebinding, removals, alias fields and snapshot ownership; avoid silently mutating data retained by consumers. Compare CPU/allocation figures before and after using the same workload. Do not change interpolation or prediction simultaneously.

### 7. Reproduce optional-feature failures before expanding integration

StateView: keep it off. The recorded experiment failed, but that does not establish an upstream Godot SDK defect. Retain a small runnable reproducer with exact versions, an unfiltered baseline, correct view tags, two peers, owner/non-owner field assertions, reconnect and removal. Compare Node SDK, native Godot and Web outcomes to isolate server setup, adapter and decoder causes. The exploratory files were removed, so the current report alone is insufficient for an upstream bug report.

Vehicles: first design how seat transitions and driver inputs share a replay-safe authoritative timeline. Current vehicle messages do not use the buffered movement input/ACK path. Only then evaluate composite prediction against the existing authoritative simulation with collision and transition parity checks.

Predicted events/spawns: add only for an observed presentation problem, with confirmation/rejection and duplicate-effect checks. Lobby/Redis/transport changes remain later work unless measurements or room-distribution needs justify them.

## Instructions for Luna

Implement one numbered task per reviewable change. Start with task 1; task 2 depends on it. Keep source-review findings distinct from reproduced failures and measured bottlenecks. Read repository instructions, preserve unrelated local files and active user applications, and use the current candidate rather than changing the main gateway route. Do not enable StateView or replace vehicle prediction as incidental cleanup. Report changed files, focused verification, artifact/deployment versions and unresolved evidence after each task.

## Implementation outcome — 30 October 2026

| Work item | Status | Evidence / remaining gap |
|---|---|---|
| 1. Reconnect lifecycle | Complete for native | Old-room callbacks and late timeout success are guarded; recovery waits for fresh state and a new input epoch. Native reconnect and removal smoke tests passed. Web reconnect is not supported by this pinned SDK path and remains unverified. |
| 2. Client delivery | Complete for packaging and basic Web play | Native and Web exports carry source and artifact fingerprints; stale Web exports are rejected. The cache-enabled build is on the isolated candidate and passed a seven-bot Web match. |
| 3. Private operational metrics | Complete | Bounded tick distributions, event-loop delay and process totals are available behind a loopback-only bearer route. The live checker passed; token remains out of public responses and logs. |
| 4. Admission fairness | Partial | Cheap map/mode/time validation now happens before allowance use. Global overload controls remain shared because the trusted proxy identity chain is not established; no per-player fairness or verified identity is claimed. |
| 5. Official gameplay gate | Not passed | Seven-bot native/Web checks work. Full-room native still misses the 60 FPS target and had three observer disconnects in the cache run. The latest 64-player Web attempt did not get its observer into the room, so it is explicitly incomplete. See the current [test report](colyseus-followup-2026-10-29/REPORT.md). |
| 6. Client performance investigation | Partial | Remote-pose preparation/application measurements do not justify rewriting state conversion. An exact-input/map collision replay cache passed ten-map parity and 150 movement samples. The 64-player cache run improved frame tails versus an uncontrolled earlier run, but still missed budget; do not claim causality or smooth 64-player play. |
| 7. Optional Colyseus features | Partial by design | Node StateView baseline/filter/reconnect/removal pass; native Godot sees only its own player even unfiltered, so compatibility remains inconclusive and StateView stays off. Vehicle prediction, predicted events and spawns were not enabled without a replay-safe design and matching tests. |

The server candidate and the legacy game server were healthy after the latest incomplete Web test. Its temporary load container exited and was absent from the final container check. This work improves lifecycle handling, observability and measured client cost, but the game is **not yet validated for smooth 64-player production matches**. The next meaningful gate is a full-room run with the observer connected before the SDK clients start, then a controlled native/Web comparison.
