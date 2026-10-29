# WarBase Colyseus server

Node.js 22+ authoritative multiplayer server using Colyseus 0.18.10.

```sh
npm ci
npm run build
npm start
```

The default listener is `0.0.0.0:8081`. Configure it with `HOST` and `PORT`. `GET /health` and `/healthcheck` report readiness; `GET /api/maps` lists supported maps; `GET /api/rooms` returns the room-directory shape used by the existing client; `POST /api/rooms` creates a room. A room is joined as type `battle` with `{ username, room }`. The production reverse proxy can strip `/colyseus` before forwarding to this listener; set `PUBLIC_ADDRESS` to `war.vaidik.blog/colyseus` so Colyseus matchmaking and seat URLs retain the public prefix. Set `STATIC_DIR` to the packaged client directory to serve the Godot web build, including the packaged gzip/Brotli sidecars and MIME, cache, COOP, and COEP headers.

Room state is synchronized with Colyseus Schema. `players` is keyed by username for existing client compatibility; each `PlayerState` includes server-owned transforms and velocities, orientation, animation clip/phase, weapon, health, score, team, ammo, death and reconciliation sequence. The root includes protocol version 5, map, time of day, mode, scores, winner, and a `vehicles` map. Player capacity is capped at 64; this is a configured ceiling, not a measured capacity claim.

Movement consumes numeric, buffered `defineInput()` frames (`move_x`, `move_z`, `yaw`, `pitch`, `jump`, `sprint`, and `crouch`) in the Colyseus fixed simulation at 60 Hz. Schema patches are sent at 20 Hz. Clients should use the framework input handle and prediction/reconciliation rather than sending transforms. `state_meta` carries animation and weapon presentation metadata; equipment, respawn, grenade, and vehicle actions use dedicated room messages. Fire aim is validated from the shot-time camera yaw/pitch, and the server immediately resolves the ray against framework rewind state, animated hit capsules, map geometry, and vehicles. Legacy client `hit` notices do not apply damage.

The current slice supports the ten authored playable maps (`arena`, `canyon`, `desert_oasis`, `dust2`, `football`, `industrial`, `nuketown`, `resoforge`, `shipment`, and `village`), TDM/FFA room selection, four time-of-day values, collision-aware movement, weapon cadence/ammo/reload and shared damage falloff, timed respawn and spawn protection, seven filling bots in rooms with humans, grenades, and authored vehicles. Map geometry and hit-pose assets are shared with the Godot client. Bots provide navigation, visibility, combat and respawn, but do not yet match the Go server's grenade evasion, squad radio, cover, and reposition behavior. The migration is not complete feature parity: full production anti-cheat, the remaining Go gameplay systems and comprehensive live multiplayer playtesting are still required. The current 64-player cap has not been capacity-tested.
