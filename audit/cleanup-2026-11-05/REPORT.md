# Cleanup and optimization — 2026-11-05

Deployed to Umbrel as `warbase-colyseus:cleanup-20261105`. The existing gateway and persistent admin/admission volumes are preserved. Follow-up: at the owner's request, retired WarBase deployment containers and obsolete tagged images were removed. Current healthy services and all persistent volumes are preserved. Source release commit `d9e66cc` was pushed to `thevaidik/warbase-battle-royal`, branch `codex/colyseus-migration`.

## Changes

- Removed 5,012,654,780 logical bytes of generated development exports, binaries and temporary artifacts. This is development disk cleanup, not a 5 GB player download saving. See `generated-quarantine.json`.
- Archived retired Go/protobuf code and tools under `legacy/`, outside active game exports and the Docker context. Removed obsolete active transport, configuration and no-op code; updated Make commands for Colyseus.
- Archived unused original assets under `asset_backups/cleanup-unused-assets-20261105`; unique source assets remain recoverable. All 10 current maps remain available. Asset hashes are recorded in `unused-asset-archive.json`.
- Reduced per-frame remote pose preparation from 60 copied fields to the 12 needed for rendering and animation. Synthetic benchmark with 63 remotes: median 200.825 → 84.86 microseconds, about 58% less time for this operation. Render-field parity passed. This is not a full-game FPS measurement.
- Removed unnecessary bot-map array allocation and the ignored instance authentication hook; static signed admission remains enforced.
- Production TypeScript builds exclude test modules and clear stale output. Removed duplicate geometry copying and set non-root runtime ownership. A staging ownership failure was corrected before promotion.

## Packages

| Measurement | Previous | Cleanup |
| --- | ---: | ---: |
| Web pack resources | 269 | 210 |
| Native ZIP bytes | 148,436,186 | 146,071,775 |
| Web Brotli package bytes | 45,115,077 | 44,790,940 |
| Server image bytes | 707,250,929 | 691,527,378 |

Current Web identity package: 86,852,185 bytes; gzip: 48,233,886 bytes. The native and Web exports share source fingerprint `ebc1ef164c1d1457548c094d841edafcf2227d101eb2678c963d1407c202bcbd`, Godot 4.7.2 and Colyseus SDK 0.18.9. Audio remains disabled.

Native artifact: `warbase-godot/client/candidate-native/WarBase-Colyseus-macOS.zip`; extracted app: `warbase-godot/client/candidate-native/cleanup-20261105/WarBase Battle Royale.app`.

## Verification

- Strict TypeScript checks and 90 server tests: 89 passed, one optional benchmark skipped, zero failures.
- Bounded 10-scene Godot suite, remote pose timing/ownership checks, and default-backend checks passed.
- Web packaging/provenance checks passed; exported pack excludes retired codec, Loft resources and QA scenes.
- Staging and official public server SDK probes passed signed joining, lobby updates, owner-only state, Conquest, reconnection and player removal.
- Actual headless native client passed signed lobby joining, battle-state reception and realtime occupancy against staging and production.
- Live Web source fingerprint matches the native build. HTML cache and isolation headers passed; public private-tool routes remain blocked. Both production containers are healthy and the private admin setup persists.
- Release archive SHA-256 matches locally and on Umbrel: `c31800dee1edc3774c5fc316035b5a4251f731976771f76c62bb29d309376c39`.
- Temporary remote build context removed; old Go deployment has been removed. Local user-owned dashboard was left running.

## Remaining limits

Full-room FPS/load certification and interactive browser gameplay remain deferred. Headless native shutdown reports 351 ObjectDB instances remaining at exit; connection tests pass, but this is not a memory-cleanliness certification. Investigate SDK/client shutdown ownership separately. Historical performance reports remain historical; these focused checks do not supersede their full-load limitations.

Adjacent logs and manifests contain the verification evidence.
