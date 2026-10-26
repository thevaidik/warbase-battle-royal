# Web delivery, tactical AI, and confirmed-hit feedback

## Lossless web optimization

The measured first-transfer total fell from 40,870,312 bytes (38.98 MiB, previous gzip release) to 33,246,418 bytes (31.71 MiB, Brotli release): 18.65% smaller. Gzip fallback is 35,458,788 bytes (33.82 MiB). Totals include engine, game data, loader, audio worklets, and HTML; disk storage includes multiple encodings and is not the browser download.

Removed unused legacy soldier/vehicle-gun assets, the unused HDR sky, and the removed Loft preview from export. Active texture resolutions, meshes, animations, import compression, renderer, and effects quality were not reduced. Brotli/gzip decoding is checked byte-for-byte. All eight playable maps load from the actual exported pack.

Content hashes separate the stable engine bundle from changing game data. Immutable one-year caching and stable weak ETags avoid downloading the engine again when only game content changes. HTML stays fresh. Encoding negotiation respects client quality weights and explicit q=0 exclusions, with Vary on all representations. One preceding release is retained for clients already starting it.

The browser build was launched successfully at the desktop reference viewport, with no browser errors or warnings. optimized-web.jpg captures that running build. Further large initial-load savings would require on-demand map packs or a custom reduced engine template; those are not implemented here.

## Bot tactics

Added visible-grenade avoidance, target stickiness, searching around last-known positions, squad spacing around approach points, retreat fallback, and stuck-path recovery. Grenades behind walls do not trigger evasion. Reaction time and aim accuracy remain forgiving; these changes improve tactical decisions rather than perfect tracking. The bots are scripted agents, not learning models. More advanced future work could include objective roles and telemetry-driven difficulty tuning.

## Blood and sniper

Confirmed online infantry damage broadcasts a small cosmetic event to nearby observers and the participants. Clients show pooled short-lived blood droplets, a small remote hit reaction, and directional local feedback. Practice hits have equivalent blood feedback. Cosmetic events never apply damage, spawn-protected hits do not emit them, and vehicle hits do not show blood.

M2010 damage is lethal on unprotected infantry at all supported ranges, including practice body/limb hits. Spawn protection and vehicle armour remain applicable. Sniper tests cover torso, lower body, and head hits at 5, 100, 250, and 300 metres.

## Verification

Server race tests and go vet; weapon/gameplay tests; grenade-evasion/target/occlusion tests; actual exported-pack map loads; lossless compression and hash checks; browser launch; native sniper-hit/blood-pool expiry; and online confirmed-damage feedback checks passed. The update is run locally, with no public deployment.
