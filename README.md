# WarBase

WarBase is a high-octane 3D vehicle and drone combat multiplayer shooter built with **Godot 4.7.2** (native and Web export) and a high-performance **Colyseus 0.18 (Node.js 22+ / TypeScript)** server.

Players command versatile combat chassis—ranging from agile aerial drones to heavily armored ground tanks—competing in objective-based Conquest, Team Deathmatch, and Free-For-All with human players and intelligent AI bots.

---

## Highlights & Features

- **Authoritative Multiplayer Netcode**: 60 Hz server-authoritative fixed-tick simulation with client-side prediction, entity interpolation, and protocol 16 schema synchronization via WebSockets.
- **Drone & Ground Vehicle Combat**:
  - **Mobility Kits**: Rotors (Quad/Helo), Fixed-Wing, High-Traction Wheels, and Heavy Armored Tracks.
  - **Tanks & Triple Weapon Mounts**: Heavy track chassis mount up to 3 active weapon systems (Primary, Secondary, and Tertiary Heavy Cannon/Missile Rack).
  - **Directional Armor System**: Realistic angle-of-incidence damage calculation featuring front armor deflection (0.75x multiplier), catastrophic rear engine criticals (1.5x multiplier), and plunging top-attack bypass (>35°).
  - **Active Countermeasures**: Deployable thermal smoke screens (`[C]` / `[X]`) providing visual concealment and projectile disruption.
  - **Dynamic Hull States**: Critical hull warnings (<25% HP), billowing smoke effects, and violent ammo rack cook-offs upon vehicle destruction.
  - **Combat Audio & Acoustics**: Procedural engine dynamics, weapon report, explosive impacts, and supersonic bullet flyby snaps.
- **11 Battle-Tested Maps**: Complete with server-verified collision geometry and spawn integrity:
  - `arena`, `canyon`, `desert_oasis`, `dust2`, `football`, `ghost_city`, `industrial`, `military_base`, `nuketown`, `resoforge`, and `shipment`.
- **Game Modes**:
  - **Conquest**: Tactical 4-point (A–D) objective control with real-time ticket bleed and full-map tactical overview (`[M]`).
  - **Team Deathmatch (TDM)** & **Free-For-All (FFA)**: Fast-paced elimination matches with automatic bot backfill.
  - **Offline Practice**: Local sandbox for instant weapon testing and flight tuning without network requirements.
- **Zero-Downtime Infrastructure**: Reverse-proxied via Nginx gateway on Umbrel (`https://war.vaidik.blog/`), featuring cryptographic ticket admission, client rate-limiting, and web-ready compressed assets (Brotli/Gzip).

---

## Controls

| Action | Key / Input |
| --- | --- |
| **Movement** | `W` / `A` / `S` / `D` |
| **Ascend / Jump / Handbrake** | `Space` |
| **Descend / Reverse Assist** | `Ctrl` |
| **Boost / Sprint** | `Shift` |
| **Primary Fire / Aim** | `Left Mouse` / `Right Mouse` |
| **Weapon Selection** | `1` (Primary), `2` (Secondary), `3` (Heavy/Tertiary) or `Scroll Wheel` |
| **Reload** | `R` |
| **Deploy Smoke Screen** | `C` or `X` |
| **Throw Ordnance / Grenade** | `G` |
| **Optic Zoom / Magnification** | `V` |
| **Tactical Map (Conquest)** | `M` (toggle) |
| **Scoreboard / Menu** | `Tab` / `Esc` |

---

## Quick Start (Local Development)

### 1. Prerequisites
- **Node.js**: v22.x or later
- **Godot Engine**: 4.7.2 .NET / Standard with GDExtension support
- **Python**: 3.11+ (for map authoring and release test gates)

### 2. Start the Multiplayer Server
```bash
cd warbase-colyseus
npm ci
npm run build
npm start
```
The server binds to `0.0.0.0:8081` by default.
- Health Check: `http://localhost:8081/health`
- Local Dev Monitor (with `ENABLE_LOCAL_MONITOR=1`): `http://localhost:8081/monitor/`

### 3. Launch the Client
From the repository root:
```bash
# Launch Godot native client
make run-godot
```
In the main menu:
- Click **Join Server** (defaults to production or configured local server via **Settings → Server Host** `localhost:8081`).
- Or select **Offline** for instant local simulation.

---

## Build & Test Pipeline

```bash
# Run complete test suite (Server + Godot Headless + Web Packaging + Performance Gates)
make test

# Server-only tests (TypeScript type-check + Node test suites)
make test-server

# Godot client tests (Headless GDScript runner across 28 functional test suites)
make test-godot

# Export and package candidate distributions
make export-godot-mac   # Standalone macOS application
make export-godot-web   # Optimized HTML5/WASM client with Brotli sidecars
```

---

## Deployment & Production Topology

WarBase runs containerized on an Umbrel host behind an Nginx edge proxy with cryptographic ticket admission:
- **Public Entrypoint**: `https://war.vaidik.blog/` (redirects to `/colyseus/`)
- **Admin Dashboard**: Hosted on private Tailscale network at `http://100.107.118.10:8082/admin/`
- **Realtime Monitor**: Available to authenticated admins at `http://100.107.118.10:8082/monitor/`
- Operational documentation is maintained in [`warbase-colyseus/deploy/`](warbase-colyseus/deploy/):
  - [ADMIN.md](warbase-colyseus/deploy/ADMIN.md): Operator credentials, role-based access, and persistence.
  - [ADMISSION.md](warbase-colyseus/deploy/ADMISSION.md): Cryptographic ticket admission, rate-limiting, and gateway token validation.
  - [SCALING.md](warbase-colyseus/deploy/SCALING.md): Single-node in-memory architecture and optional Redis clustering.
  - [OBSERVABILITY.md](warbase-colyseus/deploy/OBSERVABILITY.md): Metrics, health checks, and room telemetry.
