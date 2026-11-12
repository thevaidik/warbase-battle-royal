# Drone visual polish — 12 November 2026

This is an incremental visual improvement, not AAA certification. The original low-poly maps remain low-poly assets. No changes to hitboxes, map collision, or server gameplay in this pass.

## Changes
- Open rounded track belts, evenly spaced tread shoes, visible road wheels and a slimmer lower chassis. Existing rotating road wheels retained; belt shoes are static, not simulated tracks.
- Shared deterministic 256px mipmapped metal albedo and roughness maps; subdued variation avoids strong wavy reflections. Rubber is nonmetallic. The generated finish is cached once, and static hardware remains batched.
- Browser hangar now uses 4x MSAA with screen-scale-aware resolution, capped at 1440x1050. Hidden previews remain disabled.
- Industrial Zone uses sky-derived ambient fill plus modest built-in SSAO contact shading. Hangar also uses small-radius SSAO. Real-time shadow maps remain disabled, so this does not resolve the absence of cast sunlight shadows.
- Matching native and browser exports include the current integrated Hangar and manual edit/redeploy flow from the preceding work.

## Verification
- Drone visual regression: zero failures, including all mobility kits and centered hit-volume/ground-contact bounds.
- Export gate: all 11 maps, 132 spawns, 792 drone prediction comparisons passed.
- Native hangar, Apple M4, 1440x900, 180 frames after warmup: median 8.035ms, p95 12.596ms, 59 draw calls. This is a presentation-only microbenchmark, not full-match performance.
- Browser: actual exported build served by local Colyseus at 127.0.0.1:18306; integrated hangar loaded, tracked chassis selected, joined Industrial Conquest, observed death UI, redeployed and moved. At 1440x900 the HUD showed 115 FPS after moving and 120 FPS while stationary. An earlier snapshot during death/effect startup showed 32 FPS. These are spot observations, not measured p95/p99 or a 64-player gate. No sustained-performance claim.
- Native screenshot: hangar.png. The reference map was also visually inspected from above and during browser gameplay.
- Godot 4.7 Compatibility SSAO support checked against official documentation: https://docs.godotengine.org/en/latest/tutorials/3d/environment_and_post_processing.html

## Release status
Native archive and compressed browser package built successfully. Browser source fingerprint: `16c09857aaa274c134481fd53288a5e35235b70a1072970c33cc5792949067e3`.

**Not deployed.** Two SSH attempts to `umbrel` (100.107.118.10:22) timed out. Public war.vaidik.blog therefore remains on the earlier build. Existing deployment secrets/containers were not changed. Resume via PORTAINER_CONTAINER_ACCESS_GUIDE.md and the paired release runbook; preserve server/admin/admission volumes, validate the matched server/client release, then switch traffic with rollback available.

## Still needed for a substantially higher visual bar
Authored normal/detail textures and better silhouettes, animated track belts, baked/static map lighting and contact shadows, consistent environment art, plus sustained browser frame-time testing across hardware. More polygons or unbounded postprocessing alone will not achieve this.
