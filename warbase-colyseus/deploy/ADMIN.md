# Beta Colyseus Admin Panel

This uses the official `@colyseus/admin` 0.18.6, `@colyseus/database` 0.18.5 and `@colyseus/auth` 0.18.4 packages. The database package's Drizzle 1.0.0-rc.2 dependency is pinned directly to keep a single copy. Gameplay stays anonymous; this separate SQLite database contains operator accounts, sessions/roles metadata and the framework audit log, not game progression.

## Private deployment

Run `sh warbase-colyseus/deploy/prepare-admin.sh` against the Docker engine that owns the game. On Umbrel that is the nested engine inside `portainer_docker_1`, socket `unix:///data/docker.sock`; use a wrapper as `COLYSEUS_DOCKER_BIN`. This creates persistent named volumes `warbase-admin-data` and `warbase-admin-secrets`, assigns them to the image's node user (1000), and generates signing secrets without printing them. Re-running it preserves existing secrets and accounts.

The game container needs:

- `ENABLE_PRIVATE_MONITOR=1`, `ENABLE_PRIVATE_ADMIN=1`
- `ADMIN_DATABASE_PATH=/app/admin-data/operations.sqlite`
- `ADMIN_JWT_SECRET_FILE=/run/secrets/admin/jwt`
- `ADMIN_SESSION_SECRET_FILE=/run/secrets/admin/session`
- Data volume mounted read/write at `/app/admin-data`, secrets volume read-only at `/run/secrets/admin`.
- Host port 8082 bound only to Umbrel's Tailscale IP, as in the existing private monitor deployment.

For the existing HTTP URL inside the encrypted Tailscale network, set `ADMIN_TAILNET_HTTP=1`. This permits its host-only HttpOnly session cookie over tailnet HTTP. When serving through HTTPS, leave it unset so cookies require HTTPS. Cookies use SameSite Strict and expire after eight hours. Never publish this listener on the public interface.

The Nginx gateway denies both root and `/colyseus/` forms of `/admin`, `/admin-api`, `/monitor` and `/playground`; the application independently rejects public forwarded-prefix requests to admin routes. `enforceRbac` is enabled and development-header identities are disabled.

## Open and set up

Open `http://100.107.118.10:8082/admin/` while connected to Tailscale. The framework presents its one-time setup form when no administrator exists. Choose your administrator email and a password of at least 12 characters. Once created, a second bootstrap is refused; subsequent visits show the login form. No default password is shipped.

The dashboard provides live rooms, room inspection/actions, database health, roles and audit history. The existing `/monitor/` panel uses the same admin session. Bots are room entities; connection counts count joined SDK clients. The admin account total is not the number of anonymous people playing the game.

Password-reset email delivery is not configured. Reset links/tokens are not logged. Preserve both volumes when updating or recreating the container. Back up the admin database together with the signing secrets; the game image contains neither. Destroying these volumes loses accounts/audit history, and rotating signing secrets signs operators out.

Playground remains development-only because it installs room/debug/profiling hooks. Enabling the beta admin panel does not enable Playground on the live combat server.

Official references: [Admin Panel](https://docs.colyseus.io/admin), [Authentication and RBAC](https://docs.colyseus.io/admin/authentication), [Database](https://docs.colyseus.io/database).
