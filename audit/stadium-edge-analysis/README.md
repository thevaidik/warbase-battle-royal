# Football-only desktop flicker: partial coplanar overlap repair

User confirmed the problem affects the fullscreen desktop game and only Football Stadium. Rendering settings for other maps were not changed in this pass.

## Finding
The previous repair removed identical triangles. A deeper same-facing plane/intersection scan found another 2,942 partially overlapping triangle pairs, with total pairwise projected overlap area of about 5,170.48 m². These are different triangulations and partial polygons sharing depth; identical-triangle removal cannot fix them.

## Repair
`repair_coplanar_map.py` subtracts already covered portions from later same-facing coplanar triangles, using a 0.5 mm plane tolerance to accommodate source precision. It retains the original source order in overlapping areas and interpolates original texture coordinates and normals onto cut vertices. Opposite-facing surfaces remain separate. This changes triangulation from 27,831 to 34,422 triangles while preserving the union of visible geometry; it does not simplify away unique surfaces.

After repair, the same audit reports only 18 floating-point edge slivers, totaling 0.000268 m², with largest pair overlap 0.000026 m². Substantial coplanar overlap is removed. This is over 99.99999% reduction in the measured pairwise projected overlap area.

The original 8K atlas is byte-identical (`atlas-check.json`). Full-resolution rendering, 4× MSAA, V-sync, and disabled real-time map shadows remain as previously configured. No further global rendering changes were made.

## Validation
- `surface-tests.log`: 10,000 deterministic ground, wall and roof rays compare against the previous mesh and preserve hit coverage/positions within 2 mm. All 12 spawns retain connected bot routes.
- `godot-tests.log`: stadium geometry/spawn/material checks, grenade, Industrial collision, weapons and gameplay checks pass.
- `play-tests.log`: fullscreen movement check at 3024×1898, 4× MSAA and full render scale; no geometry/light transform movement. Native view in `repaired-view.png` inspected for missing surfaces.
- `web-tests.log`: actual exported initial/optional packs and compression hashes pass. Repaired stadium content has a new hash, invalidating the prior cached mesh.
- `server-tests.log`, `server-vet.log`: final server race suite and vet.

Source-rights caveat is unchanged from `../football-map/README.md`. This provides a concrete asset repair; the user's exact subjective flicker still needs their visual confirmation in the reopened game.
