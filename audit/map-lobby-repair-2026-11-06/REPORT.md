# Map collision and lobby correction — 6 November 2026

## Root causes

Desert Oasis called `_add_perimeter_barriers` with extent 32m while its visible terrain extended to 40m. Those four 14m-high colliders had no visible mesh. They were present in commit `fe44dc3`, dated 26 October; the cyberpunk UI update did not introduce them. Several authored spawn capsules also overlapped ruin walls.

Canyon was an alias for `low_poly_industrial_zone.glb`, with Industrial spawn locations and a misleading name/preview. It now has an independent authored low-poly rock layout, natural arch, visible ridge boundaries, clear spawn locations and a regenerated scene preview. This is a new procedural layout, not a downloaded third-party Canyon asset.

## Repairs

- Desert Oasis uses visible outer rock walls at the terrain edge; the former hidden ±32m square is gone. Ruin-embedded spawns moved into clear approaches. Sandstone outcrops use faceted rock meshes.
- Rendered static geometry produces the collision data for both server and Godot prediction. Only Canyon and Desert Oasis datasets were rebuilt; shared fixtures were refreshed.
- Collision regression checks assert every non-safety static collider belongs to a visible mesh, all spawn capsules are unobstructed, former hidden Desert boundaries are traversable, and visible rock boundaries remain solid.
- Match names and official map names are separate listing fields. Default match name is Public Conquest; custom names remain intact. Canonical map names are checked across server/client.
- Home, Loadout, Operator and Settings are in a persistent left rail. Home uses the full remaining width for map selection and matches. The redundant equipment sidebar and offline toggle were removed. Deploy always joins the official online service.
- Rows show match name, official map name and numeric human occupancy/capacity. AI-fill-ready messaging and exact clock times were removed. Lighting selection retains named daylight presets.
- Dedicated loadout layout collapses to one equipment column at smaller widths.

## Compatibility and verification

Protocol 8 forces matched map-data clients; protocol 7 receives the existing update-required error before room lookup. Schema field layouts are otherwise unchanged.

Server suite: 101 tests, 100 passed, one optional benchmark skipped. Seventeen bounded Godot scenes include the new visible-geometry and spawn-capsule checks. Native visual captures cover 1440×900 and 960×640, including dedicated loadout and persistent navigation. Screenshots use isolated fixture rows, not live population telemetry.

Matched native/Web source fingerprint: `b9444043abbdb293ae82836df4409eea41b3f5808f3ed8a8cdafafef03d1f461`. Release image: `warbase-colyseus:map-lobby-fix-20261106`. Native archive size is 145,056,200 bytes. Older protocol-7 matchmaking rejection also passed as a focused integration check.

Staged Umbrel checks passed signed admission, spoofed-header rejection, HTML cache policy, dashboard isolation and SDK joins on both repaired maps. Movement advanced 4.55m / 4.34m, ACKs advanced to 44 / 42 and feet settled at floor height. Protocol-7 admission was rejected. These are focused low-load map checks, not 64-player performance certification.

Public-domain verification also passed on both repaired maps: movement advanced 4.13m / 3.82m, ACKs advanced to 40 / 37, feet settled at floor height, canonical room labels matched, and old clients received the update-required error. Public protocol 8 and the exact native/Web source fingerprint were verified. The matching packaged native client replaced the earlier client and was launched against the official domain.

Retired deployment containers/image tag and remote temporary build context were removed after health verification. Persistent dashboard/secret volumes were preserved; the staging SSH tunnel was closed.
