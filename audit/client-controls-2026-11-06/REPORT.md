# Client controls, lobby and Stadium download repair — 2026-11-06

## Changes

- Home no longer displays the large map preview. A persistent Multiplayer navigation entry now contains the match directory and create/deploy actions. Loadout and Operator retain their own pages.
- Settings exposes the measured online-service/lobby status as a read-only label. It no longer lets players accidentally change the backend address.
- The public root redirects to `/colyseus/` without `release=admission-v1`. That query was an old cache-refresh marker, not a separate game or mode. Clients remove only that obsolete `release` parameter and preserve other query options.
- Gameplay loses held keys and queued jump input when window focus is lost or gameplay overlays disable controls. Unfocused SDK input frames are neutral; regaining focus does not unpause the game.
- Vehicle steering uses matching bicycle steering and lateral-acceleration limits on both server and SDK prediction. Previous full-speed steering could reach approximately 252 degrees/second; the new limit at 22m/s is approximately 20 degrees/second. Reverse steering remains directional.
- The car camera runs after SDK render reconciliation, no longer reads stale server speed/reverse values while locally predicted, and preserves camera yaw while reversing. SDK interpolation/reconciliation remains in use.
- This changes deterministic vehicle physics: server and clients now require protocol 10. Previous clients must refresh/update.

## Stadium root cause and release prevention

Web exports intentionally excluded the Stadium asset, but the current export/package pipeline omitted its on-demand resource pack and `optional-maps.json`. Clicking Stadium could therefore report downloading and then fail. The pipeline now exports that pack into the current candidate output, validates its scene/texture/license/UID content and SHA-256/size, records it in export provenance, and packages the manifest, pack and gzip/Brotli sidecars. The manifest revalidates; the content-hashed pack is immutable. Missing or modified downloads block packaging.

The Stadium pack is 49,150,948 uncompressed bytes and remains optional rather than increasing the initial game pack. Its content hash is `997a092552696fd98ad1e26acb0402334f584f220c275c484e692227ab13ce21`.

## Verification

- 24 Python tests pass, including absent manifest/pack, corruption, unsafe paths, missing scene and valid packaging.
- Server: 104 tests, 103 pass, 1 skipped, zero failures. TypeScript checks pass.
- Godot regression checks pass, including all ten map scenes and 120 spawn checks, focus loss, reconnect/respawn, vehicle wheels, weapons, grenade and hitbox tests.
- Updated server-generated vehicle fixtures match Godot prediction across all ten map definitions and four ray-cache configurations: 1,320 samples per configuration, zero parity failures.
- Dedicated reverse-camera and process-order checks pass.
- Automated rendered UI checks pass at 1440×900 and 960×640, including an assertion that service settings contain no editable address.
- Isolated pack-only test starts without Stadium installed, mounts the exported download, resolves UID mappings, instantiates the scene and loads its texture successfully.
- Umbrel staging: ResoForge, Industrial and Stadium protocol-10 SDK joins/movement pass. Protocol-9 client rejection and canonical map listing pass.
- Staged HTTP: Stadium pack downloaded in full and its checksum/size verified. Manifest no-cache, pack immutable, clean root redirect verified. Admission checks and private-dashboard isolation pass.

## Performance scope

ResoForge contains 529 glTF nodes and 295 meshes (58,758 indexed triangles), versus Industrial's 12 nodes and 8 meshes (79,091 triangles). This is a possible draw-call cost, not proof of the reported FPS cause. A headless 600-step ResoForge prediction sample measured p50 1,207us, p95 1,886us, maximum 61,836us on this Mac with other work running. It is not an isolated benchmark and does not establish a smooth-gameplay guarantee. Rendered official-server results are recorded below when available. Earlier full-room FPS/tick capacity limitations remain open.

## Deployment

Promoted `warbase-colyseus:controls-20261106` and `warbase-gateway:controls-20261106` on Umbrel through Portainer's nested Docker engine. Private admin mounts and rollback containers were preserved. Native and Web source fingerprint: `4516a3191c09d981b38c2dd7ad720bd5ee6c5bab481852fb3761fda5b6e7aff2`.

## Rendered ResoForge finding and follow-up

The first deployed native release reproduced wall-contact stalls in a 35-second real match with seven server bots: walking frame p95 25.006ms, p99 103.697ms; overall frame p50 6.896ms and p95 22.7ms. There were no disconnects, SDK ACK advanced to 2016, and the prediction callback ran 5,775 times with a 1,637us mean. This identified collision replay cost rather than a broken connection; low FPS remains a measured concern, not a resolved assertion.

A follow-up removes per-triangle temporary hit dictionaries in hot ray paths, caches the exact capsule sample offsets by full-precision radius/height, and skips only settlement floor queries whose results are mathematically unread. It preserves collision triangles, ray order, tolerances, nearest-hit behavior and SDK reconciliation. A 1,440-case direct old-versus-new movement comparison across all ten maps and three capsule radii matches exactly. Triangle parity, full Godot regression checks and vehicle fixture parity pass. A comparable 600-step headless ResoForge sample improved from p50/p95 1,207/1,886us to 930/1,345us (about 23%/29%); these samples are not a general FPS guarantee.

## Runtime verification limits and remaining work

Stadium downloaded, mounted and ran in the real exported Web client on the public domain: 12 seconds, seven server bots, 44.99m travelled and no unplanned disconnect. Frame p95 was 11.475ms, but snapshot-gap p95 was 434ms and final SDK pending inputs reached 112. Thus the download failure is fixed; Web input/update latency remains an open issue.

Private server metrics captured during a one-client/seven-bot match showed recent tick p95 20.810ms and maximum 30.953ms, exceeding the 16.67ms target on some ticks. Event-loop delay p95 was 23.413ms. Server timing and input backlog require a separate controlled performance pass; these are not solved by reducing client collision allocation.

The follow-up native run reported frame p95 7.32ms and p99 43.769ms with no disconnect. It travelled only 4.64m versus 37.37m in the initial run, so this is not a valid matched walking FPS comparison. See `verification.json` for compact, sanitized results. Do not interpret it as a general FPS improvement claim.

The collision follow-up ships as `warbase-colyseus:controls-opt-20261106`, with unchanged `warbase-gateway:controls-20261106`, protocol 10. Follow-up native/Web fingerprint: `5988f22a020cbe8603b7bda7eed83317f21d9416db8e31bacfac51be6902875d`.
