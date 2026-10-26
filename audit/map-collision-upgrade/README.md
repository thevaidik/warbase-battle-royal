# Industrial Zone collision repair

## Reproduction and cause
The industrial source model extends to x=91.2 and includes a visible perimeter fence. Extra invisible square barriers at x/z ±70 cut across the eastern road (contact at x=69). Industrial Outpost used an even smaller square at ±35. Before-fix probes and an overhead image with the invisible colliders highlighted are included here.

## Repair
Removed the extra square barriers from Industrial Zone, Industrial Recon, Industrial Outpost, and Canyon, which share the same industrial GLB. Retained imported fence, building, terrain and prop collision. Regenerated the authoritative server collision data from the client geometry and rebuilt the web release.

## Validation
`test_industrial_collision.gd` sweeps a standing player capsule across three affected road segments on every industrial variant, verifies clear rays, and checks that the visible perimeter fence and warehouse wall still collide. `industrial_collision_test.go` verifies the corresponding paths against the embedded authoritative server geometry. The client regression is included in `scripts/check_godot.py`.

## Requested new map
Source: https://sketchfab.com/3d-models/lowpoly-fps-tdm-game-map-by-resoforge-d41a19f699ea421a9aa32b407cb7537b
Creator: ResoForge (old profile), @aslbekburonbey.
Licence verified using the official Sketchfab API: CC BY 4.0, commercial use allowed with attribution. The user supplied the downloaded GLB from their Developer folder. Imported as ResoForge Yard with collision, validated spawns, bot navigation, an online public room, custom-room selection, lobby preview, and CC BY attribution. See ../grenade-map-upgrade for validation.
