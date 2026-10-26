# Movement shimmer / stadium z-fighting repair

## Confirmed cause
The supplied stadium had 867 coincident triangle overlaps. Of those, 803 had the same winding (767 overlaps used differing UVs). The material sanitizer also forced both sides to render. Competing surfaces at identical depth can flicker as the viewing angle moves. This is z-fighting, rather than the sun moving.

## Changes
- Removed 803 identically oriented coincident triangles, retaining 27,831 unique oriented triangles. Opposite-winding faces remain and use the source's intended back-face culling.
- Verified the position, normal and UV buffer views and embedded 8K atlas are byte-identical to the user-supplied source. Only index selection and metadata changed. See `preservation.json`.
- Disabled generated stadium LODs and vertex compression so fine original geometry remains consistent during motion.
- Enabled 2× MSAA, including alpha-to-coverage for the stadium's masked edges.
- Increased directional shadow resolution from 1024 to 2048.
- Tightened infantry camera clipping from 0.05–2500 m to 0.08–650 m to improve depth precision. All current map bounds fit this range.
- Kept player movement/interpolation behavior intact. The camera inherits interpolation from its player hierarchy; an initial inspection of the camera's local OFF flag alone was insufficient to diagnose movement timing.
- Regenerated matching server collision data and the optional stadium web pack. Its new content hash invalidates cached older geometry while keeping the full-resolution texture.

## Validation
- `godot-tests.log`: zero oriented mesh duplicates, all unique surfaces retained, all stadium spawn/geometry/material checks, grenade, Industrial collision, weapons and gameplay checks pass.
- `movement-tests.log`: walked 8.68 metres through the concourse; stadium and sun transforms stayed fixed. Native view captured in `moving-view.png`.
- `server-tests.log`: full Go race suite passes with regenerated geometry and navigation.
- `web-tests.log`: byte-identical gzip/Brotli, content hashes and mounting the actual optional map pack all pass.
- `mesh-cleanup.json`, `preservation.json`: exact cleanup counts and source-data preservation proof.

This addresses a confirmed stadium asset defect and reduces edge/shadow shimmer. It does not establish that every possible visual artifact on every map has the same cause. Source-rights provenance caveat remains documented in `../football-map/README.md`.
