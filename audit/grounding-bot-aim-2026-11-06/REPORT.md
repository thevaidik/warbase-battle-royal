# Grounding, bot aiming and original map scale — 6 November 2026

## Causes and changes

The online capsule was approximated by rings of rays at seven heights. These could miss thin platform edges or stop the capsule on a middle ring while a single ray beneath the feet said it was airborne. That combination caused hovering, buried feet, lost walking feedback and rejected jumps. Raising the visual body would leave the physics disagreement intact.

Client and server now use the same vertical capsule/triangle closest-feature contacts, BVH candidates, bounded movement substeps, 8 mm contact skin, contact-normal ground support and 0.45 m grounded stepping. Jumping, gravity settlement and camera walking feedback consume capsule support. Ceiling contact does not count as floor support. Supported standing stops gravity from creating sideways slope drift. Recovery cannot commit an unresolved overlap or a large correction; opposing narrow walls preserve the previous clear position instead of pushing the player between faces. The BVH movement envelope includes recovery and stepping space. Wall-blocked movement preserves unblocked vertical/tangential motion. Step selection measures progress along the requested direction, so a sideways recovery cannot produce a false upward step. Positions use a shared 1 mm grid; submillimetre rounding cannot cancel free flight.

This is shared game physics code, **not a physics feature supplied by Colyseus**. Colyseus still supplies authoritative room state, buffered inputs, prediction/interpolation, rewind, admission and presence. A controller simulation change requires paired protocol **12**; old clients must refresh.

The bot simulation wrote run/idle every tick, overriding the room's firing hold. The room now owns its presentation clip and timer independently. It holds attack poses for 320 ms after the latest shot, uses the moving-fire clip while travelling, and does not restart the whole body for every bullet. Gun-only recoil responds to individual shot events.

Bots now turn at bounded yaw/pitch rates and fire only inside an aim tolerance. Each shot checks current line of sight. Burst lengths/pauses depend on weapon and range, and stopped movement clears stale velocity. Pitch uses the same positive-down convention as human aiming. Existing reaction delays, visibility memory, replanning, cover/retreat decisions and Conquest objectives remain.

The rig's firing rifle barrel was 13–15 degrees off the animated support direction. A standard Godot `SkeletonModifier3D` rotates Spine1 and descendants to the replicated aim after animation evaluation; feet/root remain unchanged. Baked animation rifle axes drive the equivalent server rewind correction, including pitch, so hitboxes follow the visible upper body. Pose sampling now uses the bake FPS directly, avoiding a duplicate endpoint stretching the short firing clip. Aim pitch is interpolated by the existing Colyseus SDK.

Nuketown's arbitrary 0.8 scale was removed: the original asset now uses 1.0, 25% larger, with freshly authored spawns, bounds and collision. Its fenced area is about 63 × 43 m. Canyon remains 3.0 (about 109 × 123 m); repeated wall modules support that scale. Whole scene bounds include distant scenery and are not sufficient to calibrate human dimensions. The soldier's head-top bone is about 1.74 m above its feet; its capsule is 1.8 m and eye height 1.65 m. Animated mesh AABBs are not a reliable body-height measurement. Canyon's compact arena and rooftop viewpoints remain properties of the original source, not a new map variant.

## Verification and limits

- New synthetic contacts: floor, wall sliding, thin ledge support, true air, ramp, low ceiling, low step, invalid coordinates.
- All-map release gate now simulates walking, jumping and landing from every authored spawn, checking against **Godot's independent native capsule overlap queries** throughout movement (5 mm shape tolerance for numerical grazing contacts). It originally caught Dust II's opposing-wall defect and blocks export if it recurs.
- Server/client movement parity: 792 checkpoints across 132 spawns/11 maps, 120 fixed 60 Hz steps each, without authoritative reseeding. Maximum position difference 0.006001 m; vertical velocity difference zero. The strict gate retains 0.03 m position / 0.001 m/s vertical-velocity tolerances.
- Native aim test covers both firing clips, two phases/yaws and positive/negative pitch: 98 checks, zero failures; barrel alignment within 0.25°, feet/root preserved, disabled modifier restores animation.
- Server regression covers a burst across multiple simulation ticks, locomotion overwrites, clip phase continuity, turn-before-fire and DMR cadence.
- Focused movement benchmark compared 168 Industrial/Football queries: old ray reference 44.16 ms, new contact controller 4.13 ms (local sample, **not an overall FPS or 64-player capacity claim**).
- Validation and deployment evidence accompanies this report. A finite route test does not prove every possible route is bug-free. Full reload/magazine animation assets, coordinated squad tactics and large-match FPS/tick capacity remain separate work; no neural or HTN system is claimed here.

## Research used

- [Godot CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html): grounded movement, collision margin, slopes and jump-aware floor snap. Online prediction bypasses `move_and_slide`, so changing only native floor margin would not repair the authoritative simulation.
- [Godot SkeletonModifier3D](https://docs.godotengine.org/en/stable/classes/class_skeletonmodifier3d.html): established post-animation skeleton modification hook used for rifle alignment.
- [Valve Source multiplayer animation state](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/shared/Multiplayer/multiplayer_animstate.cpp): separates movement/aim state from attack gestures. Our persistent attack timeline applies that principle; it does not import Valve code.
- [Guerrilla: Killzone 2 multiplayer bots](https://www.guerrilla-games.com/read/killzone-2-multiplayer-bots): hierarchy, terrain analysis and team coordination are stronger future directions than simply increasing accuracy.
- [Human-like Bots for Tactical Shooters Using Compute-Efficient Sensors](https://arxiv.org/abs/2501.00078): supports bounded perception as a useful design direction. This update uses explicit perception and aiming rules, not that paper's trained agent.

## Release validation

Independent native traversal: 1,956 overlap checks, 134 jump/landing cycles across 132 spawns, zero overlaps.

Server: 116 tests, 115 passed, one benchmark skipped, zero failures. The benchmark was then run explicitly and passed (10.69× faster than the retired ray reference for that workload). Python release tooling: 25 tests passed. Native regression runner passed, including the independent all-map collision gate, movement and rifle-pose parity, SDK lifetime/reconnect checks, input focus, nameplates, weapons, vehicles, grenades and hitboxes.

Both exported clients use fingerprint `cb3809d9003cab6ad899d8b68c948b8e7b3f67e8a5748ac7211468697cc07fce`, protocol 12. Native archive size: 187,081,133 bytes. Detailed numeric evidence: [validation.json](validation.json), [map-integrity.json](map-integrity.json).

## Umbrel release

Image `warbase-colyseus:grounding-20261106` promoted through the existing Portainer Docker environment. Gateway image/configuration and persistent dashboard/admin mounts are preserved; the previous paired containers remain stopped for rollback. Public entry remains `https://war.vaidik.blog/`.

All 11 staged Umbrel matches passed signed SDK admission, movement, jump/landing and neutral-stop checks. Jump rise ranged from 0.637 to 0.998 m depending on headroom; stopped horizontal drift was zero. Six optional packs passed availability checks. Protocol-11 clients were rejected, private admin routes remained blocked publicly, and HTML cache headers passed. See [umbrel-stage.json](umbrel-stage.json). Native client reopened from `candidate-native/grounding-20261106`.

Public production verification passed after promotion: signed SDK clients moved, jumped, landed and stopped on Dust II, Nuketown and Industrial Zone at the real public domain. Health reports protocol 12; the served client fingerprint matches both exports; all six optional packs are available. See [public-production.json](public-production.json). QA clients and the temporary SSH tunnel were closed; only the intentionally launched new native client remains.
