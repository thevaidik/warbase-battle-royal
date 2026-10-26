# Grenade handling and ResoForge Yard

## Grenade behavior
- Hold G to see the first-flight arc and first contact; release G to throw. Inventory is spent on release. Pause, death, scoreboard, vehicles and returning home cancel aiming.
- Camera aim controls launch direction. Level overhand launch is 20 m/s forward plus 6 m/s loft, with 45% of movement velocity inherited and total launch speed limited to 29 m/s.
- Release point is swept against nearby cover, preventing hand offsets from spawning the grenade through a wall. The authority rejects release positions obscured from the player.
- Client and server use matching gravity (9.81), air drag (0.035), 0.06 m body-radius sweeps, 120 Hz substeps, restitution (0.35), tangential retention (0.70), and resting friction (10 m/s²). The compact body sweep samples seven rays; this is an approximation, rather than a general rigid-body solver.
- Preview shows first contact, not explosion position after subsequent bounces. Fuse starts on release; holding aim does not cook the grenade.
- Removed excessive airborne damping and velocity cuts on every contact. Contact-gap support prevents endless rolling. Cosmetic spoon debris cannot block projectile traces. Removed visible burning-wick/light/smoke behavior from the fragmentation grenade.

## New map
ResoForge Yard uses the user-provided GLB from `/Users/vaidik/Developer/lowpoly__fps__tdm__game__map_by_resoforge.glb`. Scaled 3× to gameplay metres (25.5 × 49.2 m footprint). Exact mesh collision retains authored cover openings. Twelve ground-level spawns were measured and capsule checked. Navigation has 274 nodes, all 12 spawns are reachable, and a route connects both ends. Added map arrows, preview art, custom-room support, and a public TDM room. This compact infantry map has no drivable vehicles.

Creator attribution and CC BY 4.0 source/licence links are in the exported `assets/maps/ResoForge-LICENSE.txt`; the menu description also credits the creator.

## Validation
- `grenade-tests.log`: ballistic range (~28.08 m to first landing), bounce momentum, settling (~39.68 m final position on the flat fixture), thin-wall sweeps and impact contact.
- `aim-tests.log`: native game hold/release behavior, preview visibility, single inventory decrement, no repeated-release throw, cleanup.
- `server-grenade-tests.log`: matching authority trajectory and new-map navigation.
- `server-tests.log` and `server-vet.log`: full Go race tests and vet passed.
- `godot-tests.log`: grenade, Industrial collision, weapons and gameplay regression checks passed.
- `online-tests.log`: real WebSocket impact grenade replication/detonation, inventory, AI and gameplay integration passed.
- `packed-maps.log`: all 9 maps, grenade scene and attribution loaded from the actual exported pack.
- `web-tests.log`: gzip/Brotli byte identity and hashed release URLs passed.

Final web transfer using Brotli: 34,320,220 bytes (~32.73 MiB), including engine and game; approximately 1.03 MiB above the prior build with the new map and preview included.
