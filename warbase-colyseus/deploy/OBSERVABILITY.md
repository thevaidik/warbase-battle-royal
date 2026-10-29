# Colyseus room listing and operations visibility

## Current integration

The client-facing room browser uses `GET /api/maps` and `GET /api/rooms`. The latter deliberately includes one stable public entry for each of the ten playable maps, even when no room is active, then adds live custom rooms. That contract supports the current game menu and its map-first join flow. It is not the same as a list of currently instantiated Colyseus rooms.

The candidate also exposes `/health` for the container health check and an optional `GET /internal/metrics` route. When enabled, it requires `Authorization: Bearer <OPS_METRICS_TOKEN>`; without the token configured, it returns 404. Keep the token in the deployment secret store or process environment, never in source control, a URL, or shell command arguments. The response is aggregate process and room data and does not contain player identities, IP addresses, or room IDs.

The metrics response includes active rooms/clients/bots; simulation tick count, average/max tick time, callback scheduling gaps and over-budget ticks; consumed and empty movement-input steps; joins/leaves, rejected admissions/payloads and rate limits; and process RSS/heap. Counters are process-local and reset when the service restarts. Per-room counters are discarded when a room is disposed, so this endpoint is for current operations and diagnosis, not long-term analytics.

Run the read-only API contract check from the repository root:

```sh
node warbase-colyseus/scripts/check_public_observability.mjs --base-url https://war.vaidik.blog/colyseus/
```

If `OPS_METRICS_TOKEN` is present in the environment, the checker also verifies that an unauthenticated request is denied and a bearer-authenticated request succeeds. It only performs bounded GET requests, has a 5-second per-request timeout by default, rejects responses over 256 KiB, and never prints the token. Override the timeout with `--timeout-ms`; use `--no-metrics` to skip the protected endpoint. Run its offline tests with:

```sh
node --test warbase-colyseus/scripts/check_public_observability.test.mjs
```

## Official Colyseus tools

Colyseus 0.18 provides two relevant built-in tools:

- The [Monitoring Panel](https://docs.colyseus.io/tools/monitoring) lists rooms and connected clients, inspects room state, and can dispose rooms, disconnect clients, or broadcast messages. It is an administrative control surface. The official docs explicitly warn against exposing it without password protection. Do not mount it on the public `/colyseus/` route; if operators need it, keep it on a private network or behind authenticated access and a separately controlled route.
- The [Lobby Room and realtime listing](https://docs.colyseus.io/matchmaker) can drive a live client room browser when room definitions opt into realtime listing and the frontend subscribes through LobbyRoom. That is not a drop-in replacement for WarBase's existing `/api/rooms`: the game menu displays stable, joinable map entries even before a room exists and currently expects this REST shape. Preserve that contract until a client migration is designed and verified.

The official matchmaker also exposes local room/CCU statistics and multi-process stats APIs. A single candidate sidecar can use process-local counts; a multi-process deployment must use the documented matchmaker/presence setup before treating counts as global. Current aggregate metrics should remain bounded and read-only, and must not expose state snapshots or admin actions publicly.

## Safe deployment sequence

1. Build and review the candidate image without changing the live gateway route.
2. Configure `OPS_METRICS_TOKEN` through the deployment secret mechanism. Do not put it in the Compose file or a tracked `.env`.
3. Keep `/internal/metrics` inaccessible through the public gateway. If remote collection is needed, allow it only from a trusted monitoring network or use a private authenticated tunnel.
4. Run the read-only checker against the candidate prefix; verify the ordinary room-list response and token-gated metrics before routing more users.
5. Treat `/health` as a liveness check, not proof that the room list, matchmaking, WebSocket, or metrics paths are healthy.

The checker does not deploy, create rooms, join players, or alter the currently running service.
