# WarBase handling and stability update

Implemented against the current Godot/Go working copy on 26 October 2026. The original audit is historical; this file records the resulting behavior and the limits of validation.

## Weapons and optics

- Correct perspective-based 2×/4× rifle and 4×/8× sniper magnification, with mouse sensitivity following the actual optical zoom.
- Clean circular scope apertures, resolution-aware angular reference marks, an unobstructed center, and visible health/ammunition while scoped. Removed decorative bullet-drop distances: the game uses hitscan.
- Corrected rifle eye relief and rebuilt the pistol rear sight with an open center notch. Reduced excessive viewmodel lighting and sight glow. Removed unsupported decorative emoji from UI text for Web font compatibility.
- Tighter settled ADS accuracy with movement, crouch, airborne, and sustained-fire penalties. The first round uses settled spread; firing builds bloom for subsequent rounds.
- Stable damped recoil and a small real camera aiming drift. Sniper steady aim reduces that drift, consumes stamina, and requires release/recovery after exhaustion.
- Each weapon retains its magazine through switching. Switching cancels reload without refilling ammunition. Draw, reload, sniper cycling, and throw states gate firing.
- Muzzle-to-target obstruction checks prevent the camera from shooting a barrel through cover.
- Per-shot IDs and server acknowledgments reconcile predicted ammunition without simply replenishing the local magazine from old snapshots.
- The Infiltrator now starts with its advertised pistol; loadout descriptions match weapon data more closely.
- Static procedural weapon parts are batched by material while magazine, bolt, and slide pivots remain separate. This also reduces repeated weapon draw calls on bots and remote characters.

## Stability and match correctness

- Parked vehicles use static freezing. The original bot/parked-vehicle non-finite physics failure no longer reproduced in the deterministic handling test; earlier isolation also exercised eight seeds.
- Offline practice has an explicit lobby action. Its bots, health, grenades, and vehicles are isolated from online player state.
- Online grenade inventory, cooldown, flight/bounce against exported map collision, explosion positions, damage, and kill attribution run on the server. Both clients in the integration test observed the same resulting health.
- Shared map collision and authored spawn points are exported from Godot and embedded in the service. Initial spawn and respawn selection use map data and prefer distance from existing opponents.
- Living players cannot request free healing/ammunition, and dead players must wait for the server respawn delay. Client transform packets cannot resurrect players.
- Fire cadence, shot IDs, a single damage resolution per accepted shot, finite origins/ranges, target intersection, and static-map occlusion are checked by the server. Damage is derived from weapon configuration rather than client claims.
- Movement has a cumulative time budget, map bounds, and torso collision samples. Repeating an invalid teleport never makes it valid. The client corrects persistent positional disagreement.
- Scoring stops during intermission. Local score resets follow the next round, and the winner feed is shown once.
- Physics pause applies to the practice world while the network loop remains active. Input is blocked until online state is synchronized, with reconnect/rejection feedback.

## Networking and release setup

- Atomic room admission, username reservation, and consistent synchronization remove the reproduced player-map race. Room/player limits and room input validation are enforced.
- Incoming transform updates replace older pending transforms instead of filling a large queue under load. This fixed the delayed disconnect cleanup observed in an intermediate 60-player run.
- Server simulation remains 60 Hz; world snapshots run at 30 Hz with distance tiers. Critical events are separate. Replacing an unsent partial AOI snapshot preserves its rare entities.
- Visual distance LOD no longer disables limb hitboxes. Very close nameplates are hidden, and nameplates respect scene depth.
- Browser connections use the actual serving host and port. The FPS schema now lives at `shared/proto/fps/packets.proto`; protocol version 2 prevents silently using an incompatible export.
- Audio is audible by default; volume and mouse sensitivity persist. The master bus is no longer permanently muted.
- Corrected Docker paths and removed the obsolete npm client build. Docker consumes an explicit matching Godot Web export and runs as a non-root user with health/resource settings.
- Corrected Make targets, bounded test execution, Web export paths, deterministic compression, configurable static asset directory, production profiling restrictions, and shutdown of WebSocket/match loops.

## Verified results

| Check | Result |
| --- | --- |
| Go suite under `-race` and `go vet` | Passed, including combat, movement, admission, AOI, grenades, and HTTP configuration tests |
| Godot handling regression | 12 checks passed, including retained ammo, draw gating, reload cancellation, optical zoom, recoil settling, finite bot/vehicle physics, pause, and respawn state |
| Existing full gameplay autotest | Reached its completion marker, including vehicle transmission/view checks; bounded runner found no script or non-finite physics errors |
| Two real Godot WebSocket clients, alongside the 60-client workload | Shared roster and protocol confirmed; both observed **14 HP** after the same authoritative grenade explosion |
| 60 simulated clients, latest five-second local run with race-instrumented service | Completed; all simulated connections admitted; no race report; **zero remaining connections** after cleanup |
| Native rendered optics preview | Completed rifle 2×/4×, sniper 4×/8×, pistol ADS, and lobby screenshots without the original warning loop |
| Web build | Exported successfully; loaded in the in-app browser and joined the local service |
| Compose configuration | Validated |
| Full Docker image/container run | Not executed: local Docker daemon is unavailable |

The load run's steady per-player download samples were approximately **107–108 KiB/s** with players concentrated near authored spawns. This is not directly comparable with the old audit's geographically scattered client positions. It is not a production bandwidth/capacity certification. The test does not simulate 30 authoritative vehicles or measure packet loss.

The native screenshot run ended at approximately 59 FPS with the process capped at 60. Individual startup/aim-transition samples were lower; this is not a sustained 60 FPS claim or a cross-device benchmark.

The newly generated Web pack is approximately **45 MiB**, compared with the existing old pack of roughly 197 MiB. WebAssembly is approximately 38 MiB raw / 9.6 MiB gzip; the pack's gzip companion is approximately 43 MiB. Both gzip variants are served transparently. Further download-budget work remains useful.

Headless test output includes host certificate-access errors, expected requests to an absent lobby endpoint, and engine cleanup ObjectDB warnings. The native rendered preview completed without those cleanup warnings. Long-running memory behavior has not been certified.

## Deliberate scope limits and remaining launch gates

1. **Online vehicle driving is unavailable.** Vehicles remain in offline practice. A production online version requires authoritative vehicle IDs, occupancy, transforms, collisions, destruction, and reconnect behavior. Client-provided driving labels no longer grant faster movement or roadkill damage.
2. Movement is still validated client transforms with static collision samples, not a complete server input/physics simulation or lag compensation/rewind. Combat checks use current server target positions and static map geometry; dynamic vehicle physics is outside online scope.
3. Online grenades wait for server admission and detonation events; sophisticated projectile prediction/reconciliation is not implemented.
4. Long-duration load/memory tests, impaired-network testing, supported-device/browser QA, detailed map balance/playtesting, asset-license verification, and signed/notarized distribution remain required before a production launch.
5. Room capacities are enforced at 64, but the local smoke/load run is not proof that every map/device is suitable for 64 rendered players.
6. The Docker configuration and Web export are ready for image testing once the daemon is available. The actual image build, cold start, reverse proxy, TLS, and rollback still need environment validation.

## Try and review

Run `make run-godot` and choose **Offline Practice** to inspect the changes immediately. Right mouse aims; V changes supported magnification; Shift steadies the sniper; R reloads; 1–4 or the wheel switches weapons. For online play, deploy the matching client and server together because protocol version 2 is required.

Full source remains in the project. `source-changes.patch` contains the before/after diff for existing source files; new source includes server geometry/grenade logic, tests, export utilities, and the canonical FPS schema. No commits or public deployments were performed.

Evidence: [full verification](verification.log), [server tests](server-tests.log), [client tests](client-tests.log), [two-client integration](online-sync.log), [load generator](60-player-load.log), [load server](load-server.log), and [Web export](web-export.log).

Screenshots: [rifle 2×](rifle-2x.png), [rifle 4×](rifle-4x.png), [sniper 4×](sniper-4x.png), [sniper 8×](sniper-8x.png), [pistol ADS](pistol-ads.png), and [Web online play](web-online.png). The Web screenshot was captured during an intermediate load run; subsequent input coalescing and disconnect cleanup corrections were verified by the final integration test.
