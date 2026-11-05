# WarBase

WarBase is a Godot 4.7.2 FPS with native and browser clients and a Node.js/Colyseus multiplayer service. Default public rooms use Conquest with four capture points; custom rooms also support free-for-all and team deathmatch with human players and filling AI bots; offline practice remains available.

The Web recovery and performance follow-up is deployed on Umbrel with matching native/Web builds; see [current results and limits](audit/performance-next-2026-11-05/REPORT.md). For the preceding cleanup, see [cleanup results and remaining limits](audit/cleanup-2026-11-05/REPORT.md). The networking follow-up is documented separately; see [current verification and release status](audit/colyseus-features-2026-11-05/REPORT.md). Signed admission deployment is documented in [the paired release runbook](warbase-colyseus/deploy/ADMISSION.md), and optional Redis requirements in [scaling notes](warbase-colyseus/deploy/SCALING.md).

## Build and verification commands

`make run-server` and `make test-server` use Colyseus. `make test` runs server, bounded Godot and Web packaging/provenance checks. `make export-godot-mac` and `make export-godot-web` use only the SDK-enabled presets. `make export-map-data` writes temporary authoring data under `build/map-authoring` and generates the matching Godot/Colyseus collision assets. Retired code and export/load tools are documented in [legacy/README.md](legacy/README.md).

## Play locally

Install Godot 4.7.2 and Node.js 22+. Start the current multiplayer service from `warbase-colyseus`:

```sh
cd warbase-colyseus
npm ci
npm run build
npm start
```

The service listens on port 8081 by default. Development uses temporary signed gameplay tickets; a server restart invalidates those tickets. Production requires persisted admission/gateway keys as documented in the runbook. Run `make run-godot` from the repository root for the native client; the default server is the public service, or set **Settings → Server Host** to `localhost:8081` for local online play. Use **Join server** to enter an online match or **Offline** for a local sandbox. To package and serve the browser client locally, use the current Colyseus web export and packaging scripts described in [the server README](warbase-colyseus/README.md).

## Dashboard and debugging

The beta Colyseus Admin Panel is at [http://100.107.118.10:8082/admin/](http://100.107.118.10:8082/admin/) on Tailscale. On first visit, use its one-time setup form to choose the administrator email and a password of at least 12 characters. It provides live room inspection/actions, roles, audit history and database health. Operator accounts use a dedicated persistent database; gameplay remains anonymous.

The [monitor](http://100.107.118.10:8082/monitor/) now requires the same admin login. It reports rooms, connected SDK clients, CPU, memory and room state. Battle-room connections count joined human SDK clients; bots are excluded. The new local realtime lobby implementation also creates a separate lobby-room connection while the menu is open. Both panels are blocked on the public domain. See [admin setup and storage](warbase-colyseus/deploy/ADMIN.md).

For local development, run the server with `NODE_ENV=development HOST=127.0.0.1 ENABLE_LOCAL_MONITOR=1 npm start`; the monitor is then available at `http://127.0.0.1:8081/monitor/`. The same development-only flag also enables the private `/playground/` page for connection, message, and reconnect debugging. The playground is local development tooling and is not claimed as deployed.

The public game URL [https://war.vaidik.blog/](https://war.vaidik.blog/) redirects to `/colyseus/`. The former Go production deployment has been removed. Its source and old tooling are preserved under `legacy/`, outside the active Godot project and Docker build context. The `warbase-server` container now runs the Nginx gateway on port 8081 and routes game traffic to `warbase-colyseus-candidate`. See [the Colyseus README](warbase-colyseus/README.md), [feature usage report](audit/COLYSEUS_FEATURE_USAGE_REPORT.md), and [legacy retirement record](warbase-colyseus/deploy/LEGACY_RETIREMENT.md) for architecture and operational details. The separate Colyseus Cloud paid hosted dashboard is not the dashboard used for this Umbrel deployment.

## Controls and gameplay

| Action | Input |
| --- | --- |
| Move / jump / crouch | WASD / Space / C |
| Fire / aim | Left / right mouse button |
| Reload | R |
| Optic magnification | V on weapons with variable optics |
| Steady scoped aim | Hold Shift while stationary and aimed |
| Primary / secondary | 1 / 2; mouse wheel swaps between them |
| Equipped throwable | G |
| Inspect | I |
| Scoreboard / pause | Tab / Esc |
| Conquest tactical map | M; M or Esc closes it |
| Vehicle enter / exit | E near an unoccupied car |
| Drive / brake / camera | WASD / Space / mouse; C changes chase view |

Choose equipment from **Loadout** on the home screen. The game includes selectable weapons, optics, grenades, vehicles, and offline bots. Current online feature coverage and known gaps are documented in the [Colyseus feature usage report](audit/COLYSEUS_FEATURE_USAGE_REPORT.md); do not assume every legacy Go feature has migrated.

## Conquest

While playing, floating A–D badges show objective locations, distance, ownership and capture progress. Off-screen objectives have directional arrows; amber marks contested points. M opens the full tactical map; M or Esc closes it.

Every map's default public server uses **Conquest**. Public mode/map settings are enforced by the server, including when an older client requests FFA or TDM. Public entries are joinable presets; rooms start when someone joins. Custom matches can still select other modes. Teams capture four objectives, A–D. An uncontested on-foot presence captures a neutral point in 12 seconds; an enemy point must first be neutralized. Both teams present makes it contested and freezes progress. Dead players and vehicle occupants cannot capture. Each team starts with 500 tickets; objective advantage drains enemy tickets, and kills cost the defeated team one ticket. Zero tickets ends the match. Filling bots pursue capture objectives when not fighting.

Press **M** for a top-down view of the loaded map, ownership/capture markers and your position. M or Esc closes it. The map blocks your movement, fire and throwing while open; the online match keeps running. The 3D overview is rendered once per opening and disabled while closed.

## Current architecture and status

Colyseus is the production multiplayer runtime. It simulates movement at 60 Hz from buffered numeric input frames and sends synchronized schema state at 20 Hz. The server is authoritative for movement, combat, room state, and gameplay actions. Read [warbase-colyseus/README.md](warbase-colyseus/README.md) for the current implementation details and commands.

Protocol 6 uses the official `Predict.sim` for the driver and all vehicle mirrors together. Buffered controls include seat-generation guards; entry/exit and damage remain authoritative. Death, destruction and dropped connections release seats immediately and invalidate old driving inputs. Matched native/Web clients use Godot SDK 0.18.9 and immediate grenade visuals through its official `EventChannel`; confirmation adopts the same cosmetic, and rejection/expiry removes it. The channel is initialized after the first decoded state/controller and cleared across connection changes. Inventory, explosions and damage remain server-owned. See [vehicle/grenade follow-up evidence](audit/vehicle-grenade-followup-2026-10-30/REPORT.md).

The room's configured ceiling is 64 players; this is not a capacity certification. The existing native performance gate did not meet its 60 FPS and disconnect criteria, and the web full gate remains incomplete. See [the performance notes](GAME_PERFORMANCE_AND_IMPROVEMENTS.md) for measured results and limitations.

Native candidate exports use `scripts/export_colyseus_native_candidate.py`. Web export and pack scripts are also maintained in this repository; use the current Colyseus workflow rather than the retired Go `make run-server`, Go test, or Go stress-test targets for production validation. See [the legacy retirement record](warbase-colyseus/deploy/LEGACY_RETIREMENT.md).

Audio is currently disabled throughout the game.
