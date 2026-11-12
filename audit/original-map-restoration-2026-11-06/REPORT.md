# Original map restoration — 2026-11-06

## Shipped selection

The selectable set is 11 complete original maps: Football Stadium, ResoForge Yard, Industrial Zone, Village Outpost, Combat Arena, Shipment, Dust II, Nuketown, Devil’s Canyon, Military Base and Ghost City. Public presets remain Conquest.

Industrial Recon and Industrial Outpost previously used the same Industrial model with altered styling. Their existing internal IDs (`dust2`, `nuketown`) now load the actual archived Dust II and Nuketown models and use their original names. Canyon now uses the original Devil’s Canyon layout. The handcrafted Canyon/Desert Oasis substitutes and unused recolouring helpers were removed. Original map colours, textures and PBR material values are retained; anisotropic filtering and two-sided wall rendering remain visibility fixes.

Inspecting the archived assets revealed that Military Outpost and Desert Oasis are prop sheets, and Desert Road is a small diorama. The user explicitly chose to keep those out of matches. Their original source assets remain archived; they are not advertised as completed levels. This corrects the earlier assumption that every GLB file was a ready-to-play map.

## Integration

Five restored static scenes use Godot SurfaceTool batching with their original materials, normals and UVs. It reduces Devil’s Canyon from 2,206 mesh nodes to 589 static batches without replacing its layout. Units and origin are normalized for a 1.8m player capsule. Original source hashes, transforms, bounds, batching counts and fixed spawn positions are recorded in `assets/data/restored-map-authoring.json` and the accompanying verification record.

Spawn authoring uses offline Godot raycasts, capsule overlap/sweep checks and connected ground samples. Each map has 12 fixed spawn positions. Nuketown’s playable/tactical bounds follow the fenced level, rather than its exported distant surrounding ground plane. Runtime map creation reads these authored values; it does not search for spawns every frame. Server collision and client prediction use the same extracted, indexed triangles.

The restored maps and Stadium are Web downloads on demand. The packer follows resource dependencies and records source UID mappings, root scene, content hash and size. Packaging rejects missing/corrupt packs, incorrect roots and omitted UID resources. Manifests revalidate; content-addressed packs are immutable. Native embeds every enabled scene. Authoring GLBs and duplicate source images are excluded from runtime exports.

To reproduce authoring with the local original-source archive: run `scripts/prepare_original_map_sources.py`, import the Godot project, run `scripts/tools/bake_restored_maps.gd` followed by `scripts/tools/author_restored_spawns.gd`, regenerate map geometry/fixtures and previews, then export through the gated release scripts. The baked scenes and required original textures are versioned runtime inputs.

## Loft 17 removal

154 Loft-named source, texture, preview/import and cached-import files were removed from the local project/archive. No Loft files remain under the runtime assets, local source archive or imported cache. Loft is absent from map catalogs. The release asset gate explicitly rejects Loft-named PCK resources. Historical Git commits and audit descriptions were not rewritten.

## Verification

- 25 Python checks pass, including a release guard against Loft content.
- Server: 103 tests, 102 pass, one skip; no failures. Old tests asserting that Dust II/Nuketown shared Industrial scenery were replaced with checks for distinct original maps and authored ground.
- All-map Godot gate passes: 11 maps, 132 spawn capsules, escape clearance, visible collider backing, preview availability and exact scene/prediction triangle parity.
- Full bounded Godot regression suite passes, including input focus, reconnection/respawn, collision, grenade, hitbox and weapon tests.
- Every optional pack loads from an isolated project where its root scene was initially absent; UID mapping, scene instantiation and texture dependencies succeed for all six packs.
- Native and Web builds share client fingerprint `e44272190317c635649ba4e843012c4bbb0e9074686c2726697f599a19835ccf`. Map compatibility is protocol 11; deploy clients/server together.

This is a map identity, content and integration release. It does not certify 64-player capacity or resolve the previously documented server-timing/Web input-backlog limits.

The packaged Web initial runtime/game assets total 87,585,669 identity bytes; all six optional map packs are separate from that initial payload. Compression is negotiated per asset. This is a transfer-size inventory, not a new download-speed benchmark.

Umbrel staging passed ordinary SDK joins and movement on all 11 maps. Neutral-input stop drift stayed below 3cm in every check, protocol-10 clients were rejected, and all six optional pack endpoints returned successfully with immutable cache headers. Health, signed admission, clean HTML revalidation and private dashboard isolation also passed. See `staged-sdk.json`.

## Deployment and public verification

Promoted `warbase-colyseus:originals-20261106` on Umbrel, retaining `warbase-gateway:controls-20261106` and all private dashboard mounts. Public health reports protocol 11; public map and room directories contain 11 original maps and omit Loft/the three excluded sources. Every optional download endpoint is available. The public candidate fingerprint matches both exports.

The actual exported native and Web clients each joined original Dust II against `war.vaidik.blog/colyseus`, moved successfully and completed an eight-second run with no disconnect. Native travelled 20.71m (ACK 463); Web travelled 11.23m (ACK 470). These are integration smoke tests, not matched FPS benchmarks. Compact results are in `native-live.json` and `web-live.json`.

The rendered QA observer must run with a real renderer: an initial headless invocation reached gameplay but its final screenshot step hit Godot's dummy texture backend. It was rerun in its supported rendered mode and exited cleanly. No native gameplay crash was observed in the rendered run.
