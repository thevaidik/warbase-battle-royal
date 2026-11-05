#!/bin/sh
set -eu
umask 077

fail() {
  printf '%s\n' "warbase gateway configuration error: $1" >&2
  exit 1
}

listen="${WARBASE_GATEWAY_LISTEN:-0.0.0.0:8081}"
case "$listen" in
  0.0.0.0:*|127.0.0.1:*) ;;
  *) fail 'WARBASE_GATEWAY_LISTEN must use 0.0.0.0 or 127.0.0.1 with a port.' ;;
esac
listen_port=${listen##*:}
case "$listen_port" in
  ''|*[!0-9]*) fail 'WARBASE_GATEWAY_LISTEN has an invalid port.' ;;
esac
[ "${#listen_port}" -le 5 ] || fail 'WARBASE_GATEWAY_LISTEN has an invalid port.'
listen_port_num=$(printf '%s' "$listen_port" | sed 's/^0*//')
[ -n "$listen_port_num" ] || fail 'WARBASE_GATEWAY_LISTEN has an invalid port.'
[ "$listen_port_num" -ge 1 ] && [ "$listen_port_num" -le 65535 ] || fail 'WARBASE_GATEWAY_LISTEN has an invalid port.'
health_port="${WARBASE_GATEWAY_HEALTH_PORT:-$listen_port_num}"
case "$health_port" in
  ''|*[!0-9]*) fail 'WARBASE_GATEWAY_HEALTH_PORT has an invalid port.' ;;
esac
[ "${#health_port}" -le 5 ] || fail 'WARBASE_GATEWAY_HEALTH_PORT has an invalid port.'
health_port_num=$(printf '%s' "$health_port" | sed 's/^0*//')
[ -n "$health_port_num" ] || fail 'WARBASE_GATEWAY_HEALTH_PORT has an invalid port.'
[ "$health_port_num" -ge 1 ] && [ "$health_port_num" -le 65535 ] || fail 'WARBASE_GATEWAY_HEALTH_PORT has an invalid port.'
[ "$health_port_num" = "$listen_port_num" ] || fail 'WARBASE_GATEWAY_HEALTH_PORT must match WARBASE_GATEWAY_LISTEN.'

upstream="${WARBASE_COMBAT_UPSTREAM:-100.107.118.10:8082}"
case "$upstream" in
  ''|*[!A-Za-z0-9.:-]*|*:*:*) fail 'WARBASE_COMBAT_UPSTREAM must be a host or IPv4 address and port.' ;;
esac
upstream_host=${upstream%%:*}
upstream_port=${upstream##*:}
[ "$upstream_host" != "$upstream" ] || fail 'WARBASE_COMBAT_UPSTREAM must include a port.'
case "$upstream_port" in
  ''|*[!0-9]*) fail 'WARBASE_COMBAT_UPSTREAM has an invalid port.' ;;
esac
[ "${#upstream_port}" -le 5 ] || fail 'WARBASE_COMBAT_UPSTREAM has an invalid port.'
upstream_port_num=$(printf '%s' "$upstream_port" | sed 's/^0*//')
[ -n "$upstream_port_num" ] || fail 'WARBASE_COMBAT_UPSTREAM has an invalid port.'
[ "$upstream_port_num" -ge 1 ] && [ "$upstream_port_num" -le 65535 ] || fail 'WARBASE_COMBAT_UPSTREAM has an invalid port.'

secret_file="${WARBASE_GATEWAY_TOKEN_FILE:-/run/secrets/gateway/token}"
[ -r "$secret_file" ] || fail 'gateway token secret file is unavailable.'
gateway_token=$(cat "$secret_file") || fail 'gateway token secret file could not be read.'
case "$gateway_token" in
  ''|*[!A-Za-z0-9_-]*) fail 'gateway token secret must be a 32-byte base64url value.' ;;
esac
[ "${#gateway_token}" -eq 43 ] || fail 'gateway token secret must be a 32-byte base64url value.'

template=/etc/nginx/templates/gateway.conf.template
trusted_tunnel="${WARBASE_TUNNEL_TRUST_CIDR:-}"
case "$trusted_tunnel" in
  */32) ;;
  *) fail 'WARBASE_TUNNEL_TRUST_CIDR must pin the verified tunnel IPv4 address with /32.' ;;
esac
case "$trusted_tunnel" in
  *[!0-9./]*) fail 'WARBASE_TUNNEL_TRUST_CIDR has invalid characters.' ;;
esac
printf '%s\n' "${trusted_tunnel%/32}" | awk -F. 'NF != 4 { exit 1 } { for (i=1;i<=4;i++) if ($i !~ /^[0-9]+$/ || $i > 255) exit 1 }' || fail 'WARBASE_TUNNEL_TRUST_CIDR is not an IPv4 address.'
destination=/etc/nginx/conf.d/default.conf
[ -r "$template" ] || fail 'gateway configuration template is unavailable.'
WARBASE_GATEWAY_LISTEN="$listen" \
WARBASE_COMBAT_UPSTREAM="$upstream" \
WARBASE_GATEWAY_TOKEN="$gateway_token" \
WARBASE_TUNNEL_TRUST_CIDR="$trusted_tunnel" \
  envsubst '${WARBASE_GATEWAY_LISTEN} ${WARBASE_COMBAT_UPSTREAM} ${WARBASE_GATEWAY_TOKEN} ${WARBASE_TUNNEL_TRUST_CIDR}' < "$template" > "$destination"
chmod 600 "$destination"
unset gateway_token

nginx -t
exec "$@"
