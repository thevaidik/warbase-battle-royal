# Signed anonymous gameplay admission and paired release

This implementation is deployed on Umbrel; verify the dated feature report for exact image identities and verification results. The server now requires admission and gateway secrets in production. Old clients cannot join this version without obtaining a ticket, so deploy matching native/Web clients and both server/gateway configurations together.

Run `prepare-admission.sh` against the engine owning the game. On Umbrel this is Portainer's nested Docker engine, not an unrelated outer Docker stack. The script preserves existing volume secrets and prints no values. Keep admin storage/secrets and metrics mounts when replacing containers.

The public root redirects to `/colyseus/?release=admission-v1` to refresh browsers that cached the previous HTML incorrectly. HTML revalidates; hashed engine assets remain immutable.

The client obtains a 15-minute anonymous signed ticket from `POST /api/admission`, caches it per endpoint with a refresh margin, and uses the official SDK bearer-token transport for lobby and battle matchmaking. HTTP room creation requires the same bearer token. This provides a signed session identity, not account ownership or protection against a distributed anonymous attacker. Defaults: 30 ticket issues/caller/minute, 300/process/minute, 30 matchmaking authorizations/identity/minute, 4 room creations/identity/minute. Fixed-window counters are process-local.

## Proxy trust is part of the deployment

The old inner bridge gateway hides source addresses behind NAT. The new gateway uses host networking and trusts `CF-Connecting-IP` only from the outer Cloudflare connector address explicitly supplied as `WARBASE_TUNNEL_TRUST_CIDR` (IPv4 `/32` required). The verified address on 5 November is `10.21.0.11/32`. Re-inspect that connector before deploying, and update that environment variable if its address changes. The gateway refuses startup without a valid explicit pin. Never trust the full bridge subnet or arbitrary forwarded headers.

Nginx overwrites forwarded caller headers and supplies a private gateway token. The battle server accepts that caller attribution only when both the immediate peer CIDR and shared gateway token match. With the host-network gateway connecting through the Tailnet-bound port, the verified immediate peer is `100.107.118.10/32`. This is the current `ADMISSION_TRUSTED_PROXY_CIDRS` default; confirm the real socket source whenever topology changes. The bridge gateway address alone is not evidence of the caller source. Missing/mismatched gateway identity fails closed. Direct private-port admission requests may therefore fail; private admin/monitor remain separately authenticated.

The gateway uses `WARBASE_COMBAT_UPSTREAM` (default `100.107.118.10:8082`) and listens on the existing game port 8081. Public root/prefixed admin, monitor and playground paths remain blocked. Do not publish 8082 on every interface; retain its Tailnet-only binding.

## Release procedure

1. Build/export native and Web clients; package Web assets and create the candidate archive. Build the candidate and gateway from that archive. The gateway build context is `warbase-colyseus/deploy`.
2. Prepare new secret volumes. Preserve current admin database, admin keys and metrics mounts. Inspect the live connector IP and inner network gateway before applying the pinned trust settings.
3. Stage the new candidate on a private alternate port and a loopback-only host-network gateway pointing at it. Use a corresponding test `PUBLIC_ADDRESS`. Verify ticket issuance, forged-header handling, signed native lobby/battle join, occupancy updates, state visibility, and blocked public admin paths.
4. Stop/rename the previous candidate and gateway as rollback containers with restart disabled. Replace both as a coordinated release. Use current private 8082 binding, official public address, persisted admin mounts and the new secret mounts. Deploy matching Web assets and distribute the matching native build.
5. Check health, official-domain ticket issuance, lobby/battle join and Web asset headers. Roll back both containers and client assets together if these fail. Do not restart the retired Go combat service.

The bounded official load harness now acquires a distinct ticket for each simulated human and paces issuance below the default caller limit (about two minutes for 63 peers before room preparation). It does not bypass production admission. Full-room execution remains a separate deferred gate.
