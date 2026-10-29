#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUTER_DOCKER=${COLYSEUS_OUTER_DOCKER:-docker}
NESTED_CONTAINER=${COLYSEUS_NESTED_DOCKER_CONTAINER:-portainer_docker_1}
NESTED_SOCKET=${COLYSEUS_NESTED_DOCKER_SOCKET:-unix:///data/docker.sock}
NESTED_NETWORK=${COLYSEUS_LOAD_NETWORK:-warbase_server_default}
SERVER_CONTAINER=${COLYSEUS_SERVER_CONTAINER:-warbase-colyseus-candidate}
IMAGE=${COLYSEUS_LOAD_IMAGE:-warbase-colyseus-load:temporary}
if [ -n "${COLYSEUS_LOAD_BUILD_CACHE_FROM:-}" ]; then
  BUILD_CACHE_FROM=$COLYSEUS_LOAD_BUILD_CACHE_FROM
else
  BUILD_CACHE_FROM=$("$OUTER_DOCKER" exec -i "$NESTED_CONTAINER" docker -H "$NESTED_SOCKET" inspect "$SERVER_CONTAINER" --format '{{.Config.Image}}')
fi
HOST_SHARED_ROOT=${COLYSEUS_LOAD_SHARED_ROOT:-/home/umbrel/umbrel/app-data/portainer/data/docker/colyseus-load-output}
NESTED_SHARED_ROOT=${COLYSEUS_LOAD_NESTED_SHARED_ROOT:-/data/colyseus-load-output}
STAMP=$(date -u +%Y%m%dT%H%M%SZ)-$$
HOST_OUTDIR=$HOST_SHARED_ROOT/$STAMP
NESTED_OUTDIR=$NESTED_SHARED_ROOT/$STAMP
DOCKER_WRAPPER=$(mktemp /tmp/colyseus-nested-docker.XXXXXX)
IMAGE_BUILT=0

cleanup() {
  status=$?
  trap - EXIT INT TERM HUP
  if [ "$IMAGE_BUILT" = 1 ]; then
    "$OUTER_DOCKER" exec -i "$NESTED_CONTAINER" docker -H "$NESTED_SOCKET" image rm "$IMAGE" >/dev/null 2>&1 || true
  fi
  rm -f "$DOCKER_WRAPPER"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

for arg in "$@"; do
  case "$arg" in
    --url|--url=*|--url*) echo "The official endpoint is fixed; URL overrides are rejected." >&2; exit 2 ;;
  esac
done

mkdir -p "$HOST_OUTDIR"
cat >"$DOCKER_WRAPPER" <<EOF
#!/bin/sh
exec "$OUTER_DOCKER" exec -i "$NESTED_CONTAINER" docker -H "$NESTED_SOCKET" "\$@"
EOF
chmod +x "$DOCKER_WRAPPER"

(
  cd "$ROOT"
  tar -cf - .dockerignore \
    warbase-colyseus/Dockerfile.load-harness \
    warbase-colyseus/package.json \
    warbase-colyseus/package-lock.json \
    warbase-colyseus/scripts/official-load-harness.mjs
) | "$OUTER_DOCKER" exec -i "$NESTED_CONTAINER" docker -H "$NESTED_SOCKET" build \
  --cache-from "$BUILD_CACHE_FROM" \
  --file warbase-colyseus/Dockerfile.load-harness \
  --tag "$IMAGE" -
IMAGE_BUILT=1

set +e
COLYSEUS_LOAD_BUILD_IMAGE=0 \
COLYSEUS_LOAD_DOCKER_BIN="$DOCKER_WRAPPER" \
COLYSEUS_LOAD_OUTDIR="$HOST_OUTDIR" \
COLYSEUS_LOAD_DOCKER_OUTDIR="$NESTED_OUTDIR" \
COLYSEUS_LOAD_NETWORK="$NESTED_NETWORK" \
  "$ROOT/scripts/run_colyseus_official_load.sh" "$@"
status=$?
set -e

printf 'NESTED_LOAD_ARTIFACTS directory=%s\n' "$HOST_OUTDIR"
exit "$status"
