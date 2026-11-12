# All-map integrity audit — 6 November 2026

## Findings and repairs

All ten shipped maps were inspected using actual Godot scene physics. The initial static-geometry audit found 23 authored spawn capsules overlapping geometry: Village 1, Combat Arena 5, Shipment 4, Industrial Recon 1 and Industrial Outpost 12. Some floor-height cases were previously raised by server initialization; the authored/native markers still disagreed. A further check included parked vehicles and moved Industrial Recon’s first spawn away from its jeep.

Twelve synthetic invisible perimeter walls remained across Village, Arena and Shipment. The imported maps already include visible enclosing geometry; these extra square blockers and their helper were removed. Shipment’s imported collision was deduplicated before deriving its themed collision from visible meshes.

Village’s 55 manually positioned prop colliders were replaced by the imported scene’s exact visible geometry. This favors correct placement over hand-entered coordinates. Collision triangle/data cost increases on Village; see geometry-cost.json. No FPS improvement is claimed from that change.

Spawn corrections were baked offline using Godot floor rays, capsule overlap and motion checks, with separation between markers. Runtime movement was not replaced with a new custom escape solver. Both client and server datasets were regenerated from the final authoring scenes.

Authority now handles actors falling below the safety floor through the existing death and scheduled-respawn lifecycle. Tests cover normal and deep Canyon fall limits. Unsupported/missing map assets fail loading rather than silently substituting Industrial.

## Permanent release checks

Both native and Web export commands call the new map-integrity gate. It verifies server/client geometry byte parity, actual scene-versus-prediction triangle parity, geometry identity, visible backing for static colliders, all spawn capsules against scenery and vehicles, and at least two clear walking exits. All 120 authored spawns across ten maps pass.

The gate uses built-in Godot physics and caches success only for identical client inputs, server geometry, engine version and checker source. Input changes invalidate that result. Exported packs are separately inspected for every map’s collision data, preview, model import and actual imported scene. Native must include Stadium; Web retains the existing optional Stadium pack. Unit checks reject missing scene content and missing previews.

Named Industrial variants remain intentional and explicitly labelled Industrial Recon / Industrial Outpost. Canyon is a separate scene. Every preview was regenerated from the actual final scene. Geometry-changing releases advance compatibility to protocol 9; prior clients receive the update-required response.

## Verification and scope

Godot: the new ten-map gate plus 17 bounded existing gameplay scenes passed. Server suite: 102 tests, 101 passed, one optional benchmark skipped; the additional 120-spawn authoritative exit test also passed. Python export/tool checks: 18 passed. These checks cover map correctness and the reproduced bug classes; full-room FPS and long-duration network acceptance remain separate, previously documented work.

Release image: `warbase-colyseus:all-map-guard-20261106`. Native/Web source fingerprint: `ef3c8a29beeb2a6a2e2b9e406adef81a70c51088ec5db0269c97d1c22bf365af`. Both actual exported packs passed the scene/model/preview checks; native includes Stadium, and Web uses the existing verified optional Stadium pack.

Staging passed health, signed admission, forged-forwarded-header rejection, HTML cache checks and private dashboard isolation. The default gameplay services and persistent admin/secret volumes use the existing deployment topology.

The staged Umbrel Village match passed real SDK join, protocol enforcement and authoritative movement: 2.07m travelled, input ACK 20, feet at ground height. This checks the map with the largest corrected collision dataset before promotion.

All ten official-domain SDK map checks passed after deployment: successful admission, matching map/protocol, advanced input ACKs, grounded feet and 1.55–2.07m of authoritative movement. Canonical directory labels and previous-client rejection also passed. Public health and the exact matched native/Web fingerprint were verified. The matching native client is open against the official server.

Retired release containers/image tag and remote temporary build context were removed after health verification. Persistent dashboard/secret volumes were preserved, the staging tunnel was closed, and all SDK probe processes completed.
