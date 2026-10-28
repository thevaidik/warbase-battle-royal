# Combat balance and hitbox verification — 28 October 2026

## Result and scope

Close-range automatic-primary damage is tuned for an ideal 200–240 ms chest time to kill against 100 HP. This is inspired by EA’s published [200–300 ms automatic-primary benchmark](https://www.ea.com/games/battlefield/battlefield-6/news/bf-combat-gunplay); it is not a copy of Battlefield 6 weapon statistics. These times measure first bullet to lethal bullet at the configured fire rate and exclude reaction, aim-down-sight time, misses, rendering quantization and network delay.

| Weapon | Old base damage | New base damage | Close chest hits | Ideal chest TTK |
| --- | --- | --- | --- | --- |
| AK-47 | 22 | 34 | 3 | 200 ms |
| M4 | 20 | 25 | 4 | 240 ms |
| MP5 | 17 | 25 | 4 | 212 ms |
| WB-46 LMG | 26 | 34 | 3 | 231 ms |
| Pistol .50 | 24 | 34 | 3 | 300 ms |
| DMR-52 | 40 | 50 | 2 | 250 ms |
| M2010 | 100 | 100 | 1 | First hit |

Rifle/LMG full damage lasts through 20 m and declines smoothly to 60% at 90 m. MP5, pistol and DMR retain distinct range curves. Lower torso/limb damage is 0.84x (DMR 0.91x); head multipliers remain weapon-specific. Server and practice client use identical rounding, checked with 280 Go-generated weapon/range/zone fixtures. The sniper keeps the requested one-hit damage on all anatomical regions, including legs, at all supported ranges. This deliberately differs from Battlefield 6 sniper sweet spots. Health stays 100, regeneration begins after five seconds, and spawn protection stays 2.5 seconds and ends when attacking. No infantry armour-plate system was added.

## Hit registration fixes

- Fixed the offline bot’s broad movement collider intercepting rays before its anatomical head/limb areas. Hitscan now queries world/vehicles and anatomical areas; player movement collision is unchanged.
- Replaced static upright hit areas with 14 bone-following capsules: head, neck/chest, lower torso, upper/lower arms, thighs, shins and feet. Rig inspection proved the running head moves about 0.3–0.4 m forward and downward from the old head capsule; jump and limb poses also exceeded it.
- Baked the actual soldier’s five idle/run/fire/walk/jump clips at 30 Hz into shared pose data. Server tests intersect that animated skeleton, and remote visual playback uses the same authoritative animation phase. The permanent pose exporter regenerates matching client/server data.
- Player snapshots include server pose timestamps; hit claims include the timestamp of the pose actually rendered. The server validates that exact interpolated historical pose, rather than searching for any past pose that happens to intersect the ray.
- Rewind is bounded by server-measured frame-ACK RTT, render buffering and a small jitter allowance, with a hard 750 ms maximum. Client-reported ping cannot grant rewind. No timestamp means current-pose validation. Old, future or unavailable poses fail; history is fixed-size and cleared across respawn, vehicle entry and discontinuities.
- Intervening players are checked at the same historical time. Friendly hits consume their shot and cannot be reused against another target; walls, vehicles, spawn protection and authoritative ammunition/damage still apply.
- A shot through a limb into the same actor’s chest/head uses the reached central region. Both camera/muzzle queries preserve cover and intervening actors, and a pure limb shot still does limb damage. Online hitmarkers now wait for server confirmation.
- Removed a client name-prefix filter that omitted hit claims for online players named `BOT_*`; target validity is decided by the server.
- Bounded server firing grace handles normal arrival jitter without increasing sustained RPM; tests cover all seven weapons, immediate repeat rejection and a faster-than-allowed input stream.

## Verification

Complete Go race suite and static analysis passed. Complete bounded Godot suite passed, including animated head/limb physics, 280 cross-runtime damage comparisons, LOD/driver/death transitions, timestamp interpolation and integer precision, cover/friendly blocking, and predicted-versus-confirmed markers. Native/Web exports were rebuilt and checked for ZIP integrity, versioned assets and lossless compression. The native pack contains the new skeletal helper. The final real-weapon packet regression also confirms that a `BOT_STRESS_00` peer receives a hit claim with its exact rendered pose timestamp. Evidence is retained with this audit.

The multiplayer protocol is now 5 because animation phase and pose timestamps must agree between the client and server. Refresh the Web game or use the rebuilt Mac release. Audio remains disabled.

## Limits

This verifies the implemented standing, run, fire and jump animation geometry; it does not add a dedicated third-person crouch/prone animation or a new armour/ballistic simulation. Existing crouch stance replication/visual work, Stadium movement corrections, normal desktop-browser pointer-lock checks, public-route latency, asset rights and Mac notarization remain separate work. No claim is made that all Battlefield mechanics or overall production readiness are complete. At 750 ms the server rejects older views; lag compensation cannot remove physical network delay.

## Official release and full-room check

Deployed image `warbase_server-warbase-server:combat-final-20261028`, server SHA-256 `33519d5c20dad42cf1d5f269097e66e8728d648e8e4697feca1e1fa782ead64d`, Web pack `game-ae08372d77d11dd3.pck`. Public health, manifest/pack availability and disabled public profiler were verified. The previous image/container is retained for rollback. The native ZIP and Web pack were rebuilt after the peer-name filter fix; Web gzip/Brotli remain byte-identical to the original assets.

An exported native client joined 63 normal protocol peers on `war.vaidik.blog` for 120 seconds. The room API independently recorded 64 players; all 63 load peers joined with zero reported errors. This was automated; no manual play was used as evidence. The client recorded 9 server-confirmed hits, 3 server-confirmed kills, 184 local shots, 3 respawns, two grenades, one seat entry/exit, 118.7 m of driving and 330.9 m of walking, with zero disconnects. These confirm successful firing and kills in the full live room; they are not an accuracy percentage or proof that every attempted shot should land.

Frame times were 18.0 ms median, 34.2 ms at p95 and 41.8 ms at p99. Public-route ping was 456 ms median / 716 ms p95, with a 695 ms worst snapshot gap. No position corrections were applied, but the reported prediction discrepancy reached 5.58 m. Full-room frame consistency, public-route latency and movement disagreement remain work; this run does not close those earlier production issues. Web export/compression and shared-client logic were tested automatically; this combat update did not repeat interactive desktop-browser play.

Validated animated intersection benchmarks measured approximately 0.76 µs for a current pose and 0.90 µs for an exact historical pose, with zero allocations. These are isolated geometry benchmarks, not total frame costs.
