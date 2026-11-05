# Colyseus vehicle prediction and beta administration — 30 October 2026

Historical release: the later [vehicle/grenade follow-up](../vehicle-grenade-followup-2026-10-30/REPORT.md) supersedes the disabled grenade gate and open focused vehicle checks below. It documents SDK 0.18.9, event initialization ordering, passing expiry/settlement/reconnect tests and remaining limits.

## Released

Umbrel combat image: `warbase-colyseus:vehicle-admin-20261030`, ID `010109369a1f22666e9aed11b2f75bc0b23e6f10594d465e80477b1b1dd335de`.
Gateway image: `warbase-gateway:admin-private-20261030`, ID `2c0c3bbd8cd0bc4e7e5cb2f5aef123fc3de2932fd1ebccf05b6b6185a59ebcca`.
Native/Web source fingerprint: `da6a4f029681aaf4f6c04e912a8b84d8f9001b6585d1f9a79e831016c405db27`; Godot 4.7.2, Godot SDK 0.18.7. The native ZIP SHA-256 is `90e6be3424e77328c0631df6fb91bd7d9cec8936c110a77e144fe4149f3d3491`.

Protocol 6 is a paired client/server release. Both exports also carry the earlier grounded movement feedback fix. The deployed Web loader still selects Colyseus under `/colyseus/`.

## Built-in framework use

Vehicles now use official `Predict.sim`, binding the local player and all decoded vehicle numeric instances once per room. Colyseus owns input history, ACK tracking, authoritative adoption, replay, correction smoothing and reconnect epochs. There is no parallel vehicle prediction queue or replacement network reconciler.

The callback supplies our existing driving acceleration, steering, braking, gear caps, terrain probes and chassis collision rules in GDScript, matching the authoritative TypeScript simulation. Colyseus does not supply finished car physics. `defineInput` now carries vehicle controls on the same 60 Hz timeline as infantry. The old action-message handler is removed. Seat index/generation fields fence old buffered controls across entering, switching or exiting. Native `CharacterBody` and `VehicleBody` movement remain disabled for network-controlled actors; the SDK pose drives rendering.

Expected benefit: the local car can respond on the next prediction tick instead of waiting for an authoritative pose to complete a network round trip. Server corrections still occur, especially when another moving car or an obstacle changes the result. This does not reduce internet RTT or certify a frame-rate improvement.

## Grenade prediction: disabled due to SDK failure

The implementation uses official `Predict.define_event` / `EventChannel` for UI-born prediction, confirmation and rejection, with request-to-cosmetic-node associations solely for rendering. The server validates launches and echoes accepted/rejected keys. Accepted cosmetics preserve elapsed flight when applying launch corrections. Duplicate confirmations and explosion visuals are suppressed. Damage and inventory remain authoritative.

However, real Godot SDK tests found unresolved events did not expire as expected at 150 ms or 5000 ms, and normal predictor ticking with a zero-TTL unresolved event crashed in the native addon (`_colyseus_event_channel_prune` → `_reject_entry`, null `UT_hash_table`). This is a reproduced pinned-runtime failure, not a proven root cause in upstream source. The latest official Godot release checked was still 0.18.7. No native SDK patch, custom timeout queue or custom replay implementation was added.

`GRENADE_EVENT_PREDICTION_ENABLED=false` keeps the channel unconstructed in ordinary gameplay. Production sends request ID zero and renders the reliable authoritative grenade broadcast. Explicit SDK rejection and cosmetic settlement paths are retained as gated work for rechecking an official SDK fix. Immediate optimistic grenade visuals are therefore **not enabled** in this release.

## Beta administration

Official packages: admin 0.18.6, database 0.18.5, auth 0.18.4, Drizzle 1.0.0-rc.2. Panel: `http://100.107.118.10:8082/admin/`, Tailscale only. It uses the framework's first-admin bootstrap, JWT cookie sessions, RBAC, live room inspector and persistent audit database. `X-User-Id` development bypass is disabled. The existing monitor uses the same session; Playground stays development-only.

Named volumes `warbase-admin-data` and `warbase-admin-secrets` persist the operator-only SQLite database and signing secrets. No default password exists; the operator completes the one-time setup form. The tailnet HTTP session setting relies on Tailscale transport encryption; HTTPS deployments keep Secure cookies enabled. See [admin configuration](../../warbase-colyseus/deploy/ADMIN.md).

## Verification

- Final server suite: 53 passed, zero failed, one opt-in benchmark skipped; TypeScript build passed.
- Cross-language vehicle callback: 660 server samples matched, including steering, braking, reversing, gear changes and the Industrial wall case. Maps without authored cars explicitly have no car trace.
- Actual pinned SDK composite probe: step callback and dynamic vehicle mirror access work under injected latency; schema strings are absent in mirrors, so runtime control uses numeric seat fields. Pending-input lead was compared with expected lead rather than incorrectly requiring the predicted pose to equal an older server patch.
- Real Main + actual BattleRoom vehicle fixture: 7.82 m driving, 150 sampled poses matching the SDK controller, ACK 1→149, network physics frozen, authoritative exit, 0.0003 m subsequent parked drift, and walking resumed. Fixture-only spawn positioning/protection does not ship in production.
- Real Main two-peer on-foot smoke passed: movement, SDK remote poses and coarse remote hit hints remained active.
- Grenade scene passed adoption continuity, duplicate confirmation, explicit SDK rejection, disconnect/respawn cosmetic cleanup, one-time explosions and the safe authoritative production path. Expiry remains failed as above.
- Beta admin HTTP test passed bootstrap, login, second-bootstrap refusal, persistence, unauthorized monitor rejection, disabled development-header identity and forwarded-public-route rejection.
- Deployed preflight passed before cutover; active combat/gateway containers healthy. Public admin UI/API returned 404; private UI returned 200; anonymous monitor API returned 401; first-run status reports `needsBootstrap=true`.
- Official public SDK smoke joined protocol 6, verified vehicle scalar mirrors and observed input ACK advancement before leaving. Its first short-wait attempt did not see an ACK in time; the bounded retry allowed remote RTT and passed. This is connectivity evidence, not a load/performance gate.

Temporary owned local servers/headless probes were stopped. The prior combat and gateway containers are stopped with restart disabled for recovery. The original Go combat backend remains stopped. No Git push was performed.

## Remaining

An official native SDK fix and native/Web expiry regression are required before enabling grenade prediction. Web was freshly exported and packaged but this batch did not perform an interactive browser vehicle test or 64-player performance run. High-latency vehicle correction tails, multi-driver collisions, death/seat transitions and longer reconnect/soak workloads still need broader acceptance coverage. The earlier full-room performance gate remains open.
