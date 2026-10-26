# Online AI, weapons, and Desert Oasis

The local game now supports server-controlled AI in online rooms. The authority fills occupied rooms to eight combatants, removes AI as humans join, and stops AI in empty rooms. The lobby labels AI population separately from human players. Bot names are visibly marked [BOT].

## AI behaviour

- Collision-derived navigation with A* routes, separate walkable floors, obstacle clearance, and ledge checks. Navigation data is shared per map.
- Field of view and occlusion checks, finite reaction time, imperfect aim, and short bursts. Bots do not shoot hidden targets.
- Recent gunfire supplies a last-known location. Team radio shares locations without granting wall vision.
- Different approach angles and weapon engagement ranges, plus cover seeking while injured or reloading.
- The same authoritative magazines, cadence, reloads, damage, team protection, scoring, round rules, and three-second respawns as human combatants.

These are scripted tactical bots, not learning agents. They do not currently use grenades, vehicles, or advanced coordinated objectives. More playtesting is needed to tune difficulty across maps; this is not a claim of tournament-level AI.

## Added weapons

| Slot | Weapon | Damage | RPM | Magazine | Optic |
| --- | --- | --- | --- | --- | --- |
| 5 | M4 Carbine | 29 | 750 | 30 | 1× / 2× |
| 6 | MP5 SMG | 22 | 850 | 30 | 1× reflex |
| 7 | DMR-52 | 52 | 240 | 20 | 4× / 6× |

Each has its own model, firing sound, recoil, spread, reload timing, and loadout option. Mouse wheel cycles all seven weapons; keys 5–7 select the additions directly. V changes available magnification. DMR is semi-automatic and supports steady aim while scoped.

## Desert Oasis

The previous scene loaded Industrial Zone at 2% scale, based on a comment referring to an unavailable oasis asset. Replaced it with a full-size arena authored in metres: sand floor, ruins, cover, sandstone outcrops, and palms. Regenerated the server collision data and map preview from the new scene. Online geometry and client visuals now agree.

## Verification

- Server tests with the race detector and go vet.
- Bot population, obstacle routing, map navigation, occlusion, reaction delay, ammo/cadence, team rules, respawn, and scoring tests.
- Live local client/server integration: seven replicated AI, seven moving AI, bot fire, authoritative damage, and an eight-combatant scoreboard.
- Weapon/gameplay regressions, including the three new weapons, DMR trigger gating, and scope HUD integration.
- Native visual inspection of the new weapons and ADS, plus a Web release export.

Run the online integration test against a server on localhost:18092 with Godot's --script res://scripts/tests/test_online_bots.gd. The local server and native game are run for review; the public site has not been deployed by this change.
