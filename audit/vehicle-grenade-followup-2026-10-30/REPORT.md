# Vehicle lifecycle and grenade prediction — 30 October 2026

## Changes

Vehicles now force-release both sides of a seat on driver death, vehicle destruction, dropped connections and final leave. Forced cleanup repairs missing/mismatched vehicle references without releasing another player's seat. Ordinary voluntary exits still require a valid exit location. Every actual seat release advances its generation so delayed driving frames cannot regain control; unoccupied cars do not churn their generation each tick. Reconnection returns the player on foot, with a fresh input epoch; re-entering creates a new seat generation.

The official Godot SDK is updated from 0.18.7 to 0.18.9, which includes upstream room-drop/leave/reconnect lifecycle fixes. No native SDK source was patched. The installer pins the published release checksum. Because full-asset downloads were extremely slow, this installation fetched the required entries by HTTPS Range and verified every ZIP member CRC; the whole archive SHA was not verified. `sdk-selected-sha256.json` records the installed files.

Grenade prediction is enabled for native and Web through official `Predict.define_event` / `EventChannel`. Channel creation now waits until the first decoded state and composite controller exist, rather than binding during the earlier joined signal. Cosmetic projectiles appear immediately and adopt the server's accepted launch without resetting elapsed flight. Rejection/expiry removes the pending cosmetic. Damage, inventory and explosions remain authoritative. No custom expiry timer, replay queue or reconciliation replacement was introduced.

## Evidence and interpretation of the earlier SDK blocker

The earlier recorded expiry failure is real evidence, but its exact crash cause was not established. Official 0.18.9 retains the same event-expiry C implementation, callback bridge and uthash revision as 0.18.7; it must not be described as a documented upstream grenade-expiry fix. During this follow-up, an event created before the game controller was ready failed to expire. Waiting for initial state/controller made the tested paths pass on 0.18.9.

The first isolated Web probe released one test channel before creating the next and hit a WebAssembly memory error. Retaining channels for their predictor lifetime, as the live game does, passed. The game owns one channel for the initialized prediction epoch and clears it during connection cleanup. Native reconnection with a pending event and subsequent expiry of the replacement channel also passed. Arbitrary channel disposal/reentrancy should not be considered proven safe by this release.

Sources: [official 0.18.9 release](https://github.com/colyseus/native-sdk/releases/tag/godot-v0.18.9), [event implementation](https://github.com/colyseus/native-sdk/blob/godot-v0.18.9/src/predict/events.c), [Godot event tests](https://github.com/colyseus/native-sdk/blob/godot-v0.18.9/platforms/godot/tests/test/test_predict_events.gd).

## Focused checks

- Server suite: 71 passed, zero failed, one optional benchmark skipped; TypeScript build passed. Includes actual JS SDK transport loss/reconnect, stale-seat input rejection, successful re-entry/ACK/motion, death, destroyed seats, stale references, stable parked generations and two-driver head-on blocking at 60 Hz.
- Actual Main vehicle probe at 180 ms injected delay plus jitter: ACKs advanced, SDK/display poses matched, exited car drift 0.0013m, resumed walking, maximum pending inputs 24. This run preceded the SDK update.
- Actual Main on SDK 0.18.9 at 400 ms injected delay plus jitter: 7.19m driving, ACK 2→141 during drive, SDK/display pose error 0.0000m, parked drift 0.0000m, resumed walking, maximum pending inputs 37. SDK aggregate correction includes non-position fields and is not a distance; it is labeled accordingly in logs. These injected settings are not a claim of measured WAN RTT or a frame-rate certificate.
- Actual native adapter on SDK 0.18.9: driving → real `room.drop()` → reconnect → released seat/fresh generation → re-entry and ACK advancement → death → empty seat. An event pending before drop was cleared, and an unresolved event in the replacement channel expired normally.
- Native full grenade settlement: continuous adoption, duplicate confirmation suppression, explicit SDK rejection, disconnect/respawn cosmetic cleanup, one-time explosion, authoritative inventory and actual production five-second TTL all passed.
- Native isolated/full-adapter expiry: short 150ms and default TTL passed after initialized state/controller.
- Focused Web SDK probe with the real schema, buffered input and composite controller passed 150ms/default/5000ms expiry, confirm, duplicate confirm, reject and clear. Verified through the in-app browser console at 08:05:37 UTC. This was an SDK probe, not a deferred browser gameplay/FPS test.
- Godot import/parse, native export, Web export and package passed. Full-room/native-Web performance gates and interactive browser gameplay were intentionally deferred by the user.

Existing vehicle collision rules remain approximate discrete chassis sampling. The two-driver test passed; this is not a continuous rigid-body collision rewrite or exhaustive multi-map soak coverage.

## Release

Image: `warbase-colyseus:vehicle-grenade-20261030`.

Paired source fingerprint: `4a3642f756746b1fb30d1bf85df54ca53b127fb959c46fded8aeda03e3857734`.

Native ZIP SHA256: `ec3183e0517a1c3baae50fa2274ba65c5983f57a272a4abb398870f81ff31270`.

All ten public maps remain Conquest. The deployment preserves admin storage/secrets and keeps the previous combat container stopped as a rollback snapshot. No Git push was performed.

Deployment completed. Both preflight and active-container checks passed for seat release/stable generations, all-map Conquest defaults, matched SDK/fingerprint, ground repair and persistent admin storage. The official-domain Web manifest matches the paired fingerprint and SDK 0.18.9. The full native grenade settlement scene also passed against `war.vaidik.blog/colyseus`, including server acceptance, inventory and the production TTL. Temporary native probes, local fixture/probe servers, download workers and browser probe tab were stopped/closed after verification. The updated macOS app is extracted under `warbase-godot/client/candidate-native/vehicle-grenade-20261030/`.

## Reproduce the Web SDK probe

Use a temporary Godot project with the installed `addons/colyseus`, a copy of `scripts/net/ColyseusSchema.gd` named `Schema.gd`, and the saved `web-probe.gd` named `probe.gd`. A Node scene attaches that script. Copy `web-probe-export.cfg` as `export_presets.cfg`, set the main scene, import, and export its Web preset with the matching dlink non-threaded template. Serve the export on loopback with COOP/COEP headers and start `warbase-colyseus/repro/composite/main_vehicle_server.ts` on 18195. The expected browser console line is `SDK_EVENT_EXPIRY_WEB_OK short/default/production TTL; confirm; duplicate; reject; clear; composite active`. Retain the probe channels until the predictor stops.
