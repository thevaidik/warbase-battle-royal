# Football Stadium integration

Source: user-supplied `/Users/vaidik/Developer/new_football_map.glb`.

## Playable content
- Dedicated Football Stadium map in map previews, offline practice, online public TDM, and custom room creation.
- Supplied geometry retained at its original metre scale: approximately 172 × 199 metres, 28,634 triangles.
- Twelve measured spawns on the pitch and surrounding concourse; each has solid ground and standing-capsule clearance. Authored geometry supplies the boundary, without extra invisible walls.
- Navigation uses a 1 metre grid for this stadium. The default 2 metre grid could not connect its entrances/stairs. All 12 spawns now connect to the pitch, with 15,795 navigation nodes; other maps retain their previous grid spacing.
- Preserved the material atlas's alpha cut-outs, and enabled lighting response for room time-of-day presets. Full 8192 × 8192 atlas is retained with lossless import. Original mesh and texture resolution are unchanged.
- Lobby preview and native first-person play were rendered and inspected.

## Web download
The original map contains about 50 MB of PNG texture data. Its lossless imported resource is deliberately outside the initial web pack. Joining the stadium fetches a separate hashed pack, verifies SHA-256, saves it to browser game storage, mounts it and restores resource UID mappings. Failed downloads return to the lobby with retry feedback. Rejoining reuses mounted content; saved content is hash-checked before reuse. The browser test caught an HTTPRequest file-output issue; the final downloader explicitly writes and closes the completed response before validation.

`make export-godot-web` exports both packs and compression companions. `make test-web` checks gzip/Brotli byte identity, content hashes, and mounts the actual optional pack against the initial release. The server marks hashed map packs immutable.

Final initial transfer: 34,619,443 bytes Brotli (~33.02 MiB). Stadium-specific transfer: 48,053,017 bytes Brotli (~45.83 MiB), fetched only when joining this map. No texture downscaling or lossy texture recompression was used.

## Validation
- `godot-tests.log`: stadium spawn/collision/material checks, grenade, Industrial collision, weapons and gameplay checks pass.
- `navigation-tests.log`: all twelve spawn locations connect to the pitch.
- `server-tests.log`, `server-vet.log`: Go race tests and vet pass.
- `play-tests.log`: native match, aiming preview, grenade release, inventory and cleanup pass.
- `optional-pack-tests.log`: actual initial release excludes the stadium; mounting the optional pack loads all 12 spawns and the full 8K atlas.
- `web-tests.log`: release and optional-pack hashes/compression checked.
- `web-play.png`: actual browser online TDM stadium play; server bots produced team scores, and return/rejoin reused loaded assets.

## Provenance caveat
Embedded metadata identifies kyrox, a Sketchfab source URL, and CC BY 4.0. The current creator listing labels it as a Garena Free Fire map and also adds a redistribution restriction. These conflicting claims do not establish cleared public/commercial rights. Integration and testing were local; no remote/public deployment was performed. Source details are included in `assets/maps/Football-LICENSE.txt` and the optional map pack.
