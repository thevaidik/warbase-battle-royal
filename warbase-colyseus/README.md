# WarBase Colyseus server

WarBase's production multiplayer service is a Node.js 22+ server built on Colyseus 0.18.10. The former Go production service is retired. The public URL `https://war.vaidik.blog/` redirects to `/colyseus/`; the `warbase-server` container is now an Nginx gateway on port 8081 routing game traffic to `warbase-colyseus-candidate`.

## Run locally

```sh
npm ci
npm run build
npm start
```

The default listener is `0.0.0.0:8081`, configurable with `HOST` and `PORT`. `GET /health` and `/healthcheck` report readiness; `GET /api/maps` lists supported maps; `GET /api/rooms` returns the room directory used by the client; `POST /api/rooms` creates a room. Clients join room type `battle` with `{ username, room }`. In production, the reverse proxy strips `/colyseus` before forwarding and `PUBLIC_ADDRESS` is set to `war.vaidik.blog/colyseus`, preserving the public prefix in matchmaking and seat URLs. `STATIC_DIR` selects the packaged Godot web client directory, including gzip/Brotli sidecars and required MIME, cache, COOP, and COEP headers.

The Godot native client defaults to Colyseus. For local play, start this server and set **Settings → Server Host** to `localhost:8081`. The repository's `make run-godot` target starts the native client.

## Operations dashboard and playground

The beta [Admin Panel](http://100.107.118.10:8082/admin/) is hosted on Tailscale. Its initial setup form creates the first administrator; use an email and password of at least 12 characters. Operator accounts, roles and audit history persist in dedicated Docker volumes. Gameplay remains anonymous. See [admin configuration](deploy/ADMIN.md) for secrets, storage and access controls.

The [monitor](http://100.107.118.10:8082/monitor/) uses the same admin session. It shows match name/map/mode/time, connected human SDK clients, CPU, memory and room state, with administrative actions. Its connection count excludes bots and clients that have not joined a room. Admin and monitor routes are blocked on the public domain. Colyseus Cloud's hosted dashboard is a separate product.

To enable local development pages, start with `NODE_ENV=development HOST=127.0.0.1 ENABLE_LOCAL_MONITOR=1 npm start`. The monitor is served at `http://127.0.0.1:8081/monitor/`; the same flag enables `/playground/` for connection, message, and reconnect debugging. Existing `npm run dev` also enables the local monitor. These pages are development tooling; the playground is not claimed as deployed.

## Runtime model

Room state is synchronized with Colyseus Schema. `players` is keyed by username for client compatibility. Each `PlayerState` includes server-owned transforms and velocities, orientation, animation clip and phase, weapon, health, score, team, ammo, death, reconciliation sequence and seat index/generation. The root state carries protocol version 6, map, time of day, mode, scores, winner, and a `vehicles` map. Update clients and server together.

Movement consumes numeric buffered `defineInput()` frames in the fixed 60 Hz simulation. These include infantry controls and vehicle throttle, steer, brake, gear and seat index/generation. The former `vehicle_input` message handler is disabled. Official Godot `Predict.sim` binds the driver and vehicle numeric mirrors into one framework-owned rollback/replay controller; our callback supplies deterministic driving/collision rules. Entry/exit use authoritative seat messages, with stale seat generations rejected. Schema patches remain 20 Hz. Fire uses framework rewind state, animated hit capsules, map geometry and vehicles. Legacy client `hit` notices do not apply damage.

Grenade prediction now uses the official Godot SDK 0.18.9 `EventChannel` after the initial state/controller is ready. Immediate cosmetics adopt server confirmation without restarting flight; rejection, expiry and connection cleanup retire pending cosmetics. Native production-TTL settlement and focused Web SDK short/default/production-TTL checks pass. Server inventory/damage remain authoritative; no custom timeout/replay queue was added. Vehicle death, destruction and disconnects force seat cleanup and advance the seat epoch, fencing old inputs. [Current prediction evidence](../audit/vehicle-grenade-followup-2026-10-30/REPORT.md).

The current slice supports ten authored maps (`arena`, `canyon`, `desert_oasis`, `dust2`, `football`, `industrial`, `nuketown`, `resoforge`, `shipment`, and `village`), Conquest/TDM/FFA, collision-aware movement, weapon cadence/ammo/reload and shared damage falloff, timed respawn and spawn protection, seven filling bots in rooms with humans, grenades, and authored vehicles. Time presets are Dawn (06:00), Noon (12:00), Dusk (18:00), and Overcast (14:00); there is no Night preset. Map geometry and hit-pose assets are shared with the Godot client. Bot navigation, visibility, combat, and respawn are implemented, while grenade evasion, squad radio, cover, and repositioning do not yet match the retired Go service. See the [feature usage report](../audit/COLYSEUS_FEATURE_USAGE_REPORT.md) for the migration inventory and known gaps.

The 64-player room cap is a configured maximum, not a measured capacity result. The existing native performance gate missed its 60 FPS and disconnect criteria, and the full web gate remains incomplete. Comprehensive live multiplayer testing, production anti-cheat coverage, and remaining legacy gameplay migration are still outstanding.

## Conquest and ground contact

`CONQUEST` is accepted by matchmaking and room creation. The room owns four objective Schema entries (A–D), team ownership, contested status, capture progress/radius, tickets and finished/winner state. Objectives use separated map spawns and bounded, non-overlapping capture radii. Capture requires living on-foot team members; bots seek objectives outside active combat. A neutral capture takes 12 seconds; hostile ownership first takes a neutralization stage. Teams start at 500 tickets, majority advantage bleeds enemy tickets and kills cost one ticket. Colyseus Schema/fixed-step state carries these rules; there is no custom conquest transport.

`industrial-conquest-public` is advertised alongside the existing public rooms. Native/Web M-map displays objective state and a one-time orthographic map render; closing it disables that viewport. The normal input handle sends neutral controls while open.

Authored spawn markers below nearby walkable road surfaces are now raised to the actual floor before admission/respawn. Infantry vertical velocity stops on actual capsule contacts, including edge and ceiling contacts, rather than relying exclusively on a ray beneath the capsule centre. The matching Godot prediction callback uses the same rule. A reported Industrial-scenery variant spawn was reproduced below the road; its corrected camera height was checked against the actual Godot collider.

## Admission security and scaling architecture

### Anonymous ticket admission and proxy attribution
Online matchmaking requires a short-lived cryptographic admission ticket (`src/admission.ts`, `AdmissionSession.gd`). Clients obtain anonymous tickets before matchmaking or room creation:
- **Cryptographic tickets**: Tickets carry a server-signed HMAC-SHA256 signature, expiration timestamp (TTL), and canonical player ID.
- **Trusted proxy attribution**: Gateway forwarding preserves genuine caller IP via `CF-Connecting-IP` verified with the internal secret `X-Warbase-Gateway-Token`. Untrusted direct clients attempting to forge forwarded headers are rejected.
- **Per-caller rate limits**: Fixed-window limits throttle ticket issuance and room creation per genuine caller address, shielding the matchmaker and server resources from flood attempts.

### Single-process Redis-optional architecture
The Umbrel deployment runs a single Node 22+ process dependency-free with `REDIS_URL` omitted:
- **Physics is single-threaded**: The primary server performance bottleneck during full matches is CPU-bound swept/BVH collision and vehicle simulation inside the 60 Hz room tick callback. Colyseus Redis presence distributes separate rooms across worker processes, but *one individual room's simulation and collision step cannot be divided across CPU cores by Redis*.
- **Zero-overhead single node**: On Umbrel's single-node host, running in-memory eliminates Redis daemon overhead, network hops, and inter-process serialization latency.
- **Horizontal extensibility**: The infrastructure layer (`src/room-infrastructure.ts`) is fully validated. Setting `REDIS_URL` activates `@colyseus/redis-presence` and `@colyseus/redis-driver` without code changes if multi-server horizontal scaling is needed in the future.

## Build and deployment references

Use the current Colyseus Node/npm build and deployment workflow. The native candidate exporter is `scripts/export_colyseus_native_candidate.py`; web export and packaging scripts in the repository prepare the client assets served through `STATIC_DIR`. The former Go `make` test and stress targets do not validate the current production runtime. For retired service details and routing changes, see [the legacy retirement record](deploy/LEGACY_RETIREMENT.md). For broader behavior and audit references, see [the feature usage report](../audit/COLYSEUS_FEATURE_USAGE_REPORT.md).

## Latest local follow-up — 5 November 2026

See [verification and deployment status](../audit/colyseus-features-2026-11-05/REPORT.md). The signed-admission, realtime lobby and StateView/incremental release is deployed on Umbrel with matching native/Web builds. Both containers are healthy, admin storage is preserved, and the HTML cache policy is corrected. Use the [paired admission/gateway runbook](deploy/ADMISSION.md) and [optional Redis activation prerequisites](deploy/SCALING.md). Development entrypoint tickets use an ephemeral signing key; production requires persisted secret files.
