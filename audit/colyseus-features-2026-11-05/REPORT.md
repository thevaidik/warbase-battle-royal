# Colyseus follow-up — 5 November 2026

## Release status

**Deployed to Umbrel on 5 November 2026.** Both final containers are healthy: `warbase-colyseus:features-cache-20261105` and `warbase-gateway:features-cache-20261105`. The official domain serves the matching Web build; the matching Mac app is extracted at `warbase-godot/client/candidate-native/features-20261105/WarBase Battle Royale.app`. Admin accounts, keys, database and metrics mounts are preserved. No Git push was performed.

The `router` SSH alias did not resolve; deployment used the established `ssh umbrel` path after Docker group access was restored. Public traffic uses the verified tunnel pin `10.21.0.11/32`; host-network gateway traffic reaches combat from the verified peer `100.107.118.10/32`. Staging caught the former bridge-source assumption before promotion. Final public gateway logs confirm successful admission requests retain a global caller address without exposing addresses in this report.

The old feature pair and the intermediate pre-cache pair are retained stopped with restart disabled. The Go combat backend remains stopped with restart disabled.

## Implemented

- Owner-only `StateView` fields: ammo, grenades, throwable and input acknowledgement. Other players' public pose/combat state remains visible. Matching native and Web two-peer SDK probes pass the unfiltered baseline and filtered owner/peer checks, removal and fresh rejoin. Native automatic reconnect passes; automatic Web reconnect is unsupported in the pinned SDK.
- Incremental client state caching: map add/remove callbacks and per-entity dirty sets convert changed entities once per publication. Vehicle `pos` arrays are watched through the parent schema field callback. Root-only patches do not reconvert every entity; the authoritative raw cache stays separate from SDK-interpolated rendering. Native fixture passes add/change/remove, in-place array mutation and reconnect cleanup.
- Official realtime lobby listing replaces routine menu polling while connected. The ten public presets remain available when no room exists; live/custom rooms merge into the menu. Connection loss schedules bounded subscription retries with HTTP fallback.
- Signed anonymous admission tickets, shared endpoint-scoped client acquisition/cache, expiry margin, official SDK bearer transport, identity join/create quotas and official duplicate-session plugin. Unauthenticated matchmaking is rejected before battle allocation. The real development entrypoint issues ephemeral signed tickets, so local development uses the same client flow; production requires persistent signing/gateway secrets.
- Gateway configuration overwrites forwarded headers and authenticates the trust path with a private shared token plus pinned immediate peer. Gateway host networking and a pinned outer tunnel address preserve public caller attribution. This topology is deployed and verified through staged forged-header rejection and official-domain caller attribution checks. Public admin/monitor blocking is retained.
- Optional official Redis presence/driver factory and driver-backed HTTP room directory. Redis remains disabled. Configuration/default-mode tests pass; a live two-worker exercise and shared admission limits remain required before production activation. See `warbase-colyseus/deploy/SCALING.md`.
- Deployment archive includes the new gateway entrypoint and admission secret preparation/runbook. The official load harness acquires one signed identity per simulated human and paces ticket issuance below production caller limits; a full load run was not performed.

## Verification

- TypeScript production build passes.
- Server suite: 87 tests, 86 passed, 1 optional benchmark skipped, zero failed. Includes actual SDK signed matchmaking/lobby creation/update/removal, duplicate-session rejection and pre-allocation unsigned rejection.
- Standalone Node StateView suite: 3 passed.
- Native incremental state fixture and native signed lobby/battle fixture pass.
- Paired native StateView baseline/filtered probes pass, including automatic reconnect and removal/rejoin.
- Paired Web SDK-only baseline/filtered probes pass. Browser console results are in `web-sdk-result.json`.
- Actual `dist/index.js` development entrypoint: signed ticket issuance, lobby/battle join and HTTP creation protection pass (`ACTUAL_ENTRYPOINT_SIGNED_FLOW_OK`).
- Native and Web exports pass SDK/provenance validation with matching source fingerprint `f2555b7ba73ae602c10c0a4915404db5d58e6950a6fb04af6b9d305ff8729d0c`. Native ZIP SHA256 `0255c9ac6fdab00c6a3734c58044b21d84b1951fea095fd1664fc3ff3b72e58b`, 148,436,186 bytes. Packaged Web totals: 89,437,529 bytes original assets, 45,115,077 bytes Brotli sidecars. This is package size, not a measured initial gameplay download.

## Deployment verification and cache correction

The staged and official-domain SDK checks pass signed joins, realtime lobby updates, owner-only state, Conquest, reconnect and peer removal. The actual native adapter passes signed lobby/battle connection against both staging and the official domain. The final API lists all ten public Conquest presets with zero connected test players. Both live containers are healthy; private admin remains bootstrapped and the monitor rejects unauthenticated requests. Public admin/debug routes remain blocked.

Final Web delivery checks found an older directory-index caching bug: including `index.html` in the release manifest incorrectly overrode HTML revalidation. The shared static cache policy now prioritizes HTML and explicitly mutable SDK paths. Three new regression tests pass. Real staged and official GET/HEAD checks pass for directory and explicit HTML URLs; hashed engine assets retain Brotli compression and immutable caching, with isolation headers retained. The public root redirects to `/colyseus/?release=admission-v1` so browsers that cached the old immutable page fetch a fresh entry URL. This fix changes only server/gateway delivery; the native/Web source fingerprint remains the same.

A Python urllib public probe received an edge 403. Official SDK, native client and Node fetch requests passed; final Web checks used the same Node path. This does not establish unrestricted access for every external HTTP client.

Temporary staged containers and the local SSH forwarding process are removed/stopped. The user's existing local port-8081 dashboard was left running. No full gameplay/FPS test was added.

## Remaining and limits

1. Full-room FPS/stress testing and interactive full Web gameplay remain deferred at the user's request. Focused SDK checks do not establish a 64-player smoothness pass or a bandwidth/CPU improvement percentage.
2. Live two-worker Redis, worker routing and distributed admission counters are not production-complete and are unnecessary for the current single-worker deployment decision.
3. Native SDK probes print ObjectDB/resource cleanup warnings at process exit. These are recorded in the logs; these short probes do not establish long-duration client memory behavior.

Colyseus supplies the room, lobby, state view, callbacks, bearer transport and plugin machinery. Token issuance policy, visibility choices, menus, collision and game rules remain application responsibilities. This work does not mean every optional framework feature is enabled.
