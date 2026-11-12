# Legacy combat backend retirement — 2026-10-30

The public game now uses Colyseus exclusively. The Go combat service is stopped.

## Active Umbrel deployment

The game Docker engine is nested inside `portainer_docker_1`, using socket `unix:///data/docker.sock`.

- `warbase-server` now runs `warbase-gateway:colyseus-only-20261030` (Nginx), forwarding public port 8081 to Colyseus. The existing container name preserves ingress compatibility; it no longer runs Go.
- `warbase-colyseus-candidate` remains the authoritative combat server, with the existing image `warbase-colyseus:tailscale-monitor-20261030`. It was not restarted during the switch.
- `warbase-go-retired-20261030` is stopped with restart policy `no`. Its image and stopped container remain available for recovery only.

## Routing

- `https://war.vaidik.blog/` redirects to `/colyseus/`, selecting Colyseus in the existing Web build.
- `/colyseus/` paths are forwarded with the prefix stripped. Root matchmaking and SDK WebSocket paths also reach Colyseus.
- `/connect`, the retired Go combat endpoint, returns HTTP 410.
- Both public `/monitor/` and `/colyseus/monitor/` are blocked. All forwarded requests carry the public prefix header so the Colyseus monitor guard also applies.
- The dashboard remains at `http://100.107.118.10:8082/monitor/`, bound to Umbrel's Tailscale IP.

The gateway source is `gateway.conf`, `Dockerfile.gateway`, and `compose.gateway.yml` in this directory. Build from this directory with Dockerfile.gateway. Run Compose against the nested engine, not Umbrel's outer Docker engine. The old Go container was manually deployed without Compose labels; it cannot automatically replace the new gateway through a Compose restart.

## Native client

`Main.gd` now selects Colyseus by default. The existing default-backend regression assertion was updated accordingly. The macOS candidate ZIP was rebuilt using `scripts/export_colyseus_native_candidate.py` and extracted into `client/candidate-native/production-20261030/`. Opening this app requires no backend flags.

Older installed Mac exports still need replacement; their Go connection route now returns 410. The old source remains in the repository for history, but no active game service uses it.

## Verified after cutover

- Gateway and Colyseus containers healthy.
- Retired Go container reports `Running=false`, restart policy `no`.
- Public root follows redirects to HTTPS `/colyseus/` and returns 200.
- Public Colyseus health returns 200 and identifies `warbase-colyseus`.
- Legacy `/connect` returns 410; public prefixed monitor returns 404.
- Rebuilt native app launched without backend flags and joined Industrial TDM.
- Live private monitor reported one `battle` room (`industrial-public`) and one connection.

No Git push was performed.
