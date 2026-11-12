# Colyseus room listing and operations visibility

## Current integration

For local development, `npm run dev` binds the server to `127.0.0.1` and mounts Colyseus's room/client Monitoring Panel at `http://127.0.0.1:8081/monitor`. It can inspect and modify live room state and disconnect clients, so keep this local-only. Startup rejects the local monitor flag in production or when the bind host is not loopback.

The panel can also be enabled on Umbrel with `ENABLE_PRIVATE_MONITOR=1`, but only on the production candidate. Publish candidate port 8082 to the Umbrel Tailscale IPv4 address by setting `COLYSEUS_HOST_BIND_IP` to that address; do not bind it to `0.0.0.0`. The candidate rejects requests carrying the public gateway's `/colyseus` forwarding prefix, and the Go gateway source has an additional 404 guard for its next rebuild. Open `http://<umbrel-tailscale-ip>:8082/monitor/` from a device on the tailnet. This grants dashboard access to tailnet devices permitted to reach Umbrel, including its room-inspection and control actions. The ordinary Compose default binds the host port to loopback, and the production service does not enable the panel unless explicitly configured.

The client-facing room browser uses `GET /api/maps` and `GET /api/rooms`. The latter deliberately includes one stable public entry for each of the ten playable maps, even when no room is active, then adds live custom rooms. That contract supports the current game menu and its map-first join flow. It is not the same as a list of currently instantiated Colyseus rooms.

The candidate also exposes `/health` for the container health check and an optional `GET /internal/metrics` route. When enabled, it requires `Authorization: Bearer <OPS_METRICS_TOKEN>` and a loopback socket peer; without a token it returns 404 and non-loopback peers receive 403. It ignores forwarded-address headers. Keep the token in the deployment secret store or process environment, never in source control, a URL, or shell command arguments. The response is aggregate process and room data and does not contain player identities, IP addresses, or room IDs.

The metrics response labels active-room aggregates separately from process-lifetime admission/message counters. Tick duration and callback scheduling-gap percentiles (p50/p95/p99 and max) use a bounded 2,048-sample recent window; Node event-loop delay is measured separately. It also includes an active-room tick count/average/over-budget view, process-lifetime tick count, consumed and empty movement-input steps, process RSS/heap, and room-creation totals. Disposing a room removes its active-room samples but does not erase process-lifetime counts or recent timing samples. All values reset when the process restarts, so this endpoint is for current diagnosis, not long-term analytics. No player identity or payload data is stored in the process metrics.

Run the read-only API contract check from inside the candidate container:

```sh
docker exec warbase-colyseus-candidate node scripts/check_public_observability.mjs --base-url http://127.0.0.1:8081/
```

When the token file is mounted, the checker reads `OPS_METRICS_TOKEN_FILE` in the container, verifies an unauthenticated request is denied and a bearer-authenticated request succeeds. It uses bounded GET requests, a 5-second per-request timeout by default, rejects responses over 256 KiB, and never prints the token. Override the timeout with `--timeout-ms`; use `--no-metrics` to skip the protected endpoint. Run its offline and real-handler regression tests from the repository root with:

```sh
node --import tsx --test warbase-colyseus/scripts/check_public_observability.test.mjs
```

## Official Colyseus tools

Colyseus 0.18 provides two relevant built-in tools:

- The [Monitoring Panel](https://docs.colyseus.io/tools/monitoring) lists rooms and connected clients, inspects room state, and can dispose rooms, disconnect clients, or broadcast messages. It is an administrative control surface. The official docs explicitly warn against exposing it without password protection. Do not mount it on the public `/colyseus/` route; if operators need it, keep it on a private network or behind authenticated access and a separately controlled route.
- The [Lobby Room and realtime listing](https://docs.colyseus.io/matchmaker) can drive a live client room browser when room definitions opt into realtime listing and the frontend subscribes through LobbyRoom. That is not a drop-in replacement for WarBase's existing `/api/rooms`: the game menu displays stable, joinable map entries even before a room exists and currently expects this REST shape. Preserve that contract until a client migration is designed and verified.

The official matchmaker also exposes local room/CCU statistics and multi-process stats APIs. A single candidate sidecar can use process-local counts; a multi-process deployment must use the documented matchmaker/presence setup before treating counts as global. Current aggregate metrics should remain bounded and read-only, and must not expose state snapshots or admin actions publicly.

## Safe deployment sequence

1. Build and review the candidate image without changing the live gateway route.
2. Configure `OPS_METRICS_TOKEN_FILE` to a read-only secret file on the host (mode `0400`, readable by the container's `node` user); Compose mounts it read-only at `/run/secrets/ops_metrics_token`. The process also supports `OPS_METRICS_TOKEN` as an environment secret. Do not put the value in the Compose file, a tracked `.env`, or command arguments. With neither source set, metrics remain disabled.
3. The route accepts only loopback socket peers, regardless of forwarded headers; the supplied Nginx candidate snippet also returns 404 for `/colyseus/internal/metrics`. Collect from the candidate container with `docker exec` against `http://127.0.0.1:8081/`; the host-published port and reverse proxy are intentionally denied.
4. Run the checker through `docker exec` against container loopback; it reads the mounted secret file and verifies ordinary room-list and token-gated metrics before routing more users. The host-published port 8082 is not suitable because its connection is non-loopback inside the container and is intentionally denied.
5. Treat `/health` as a liveness check, not proof that the room list, matchmaking, WebSocket, or metrics paths are healthy.

The checker does not deploy, create rooms, join players, or alter the currently running service.
