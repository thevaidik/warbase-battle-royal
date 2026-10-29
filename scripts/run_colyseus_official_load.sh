#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
IMAGE=${COLYSEUS_LOAD_IMAGE:-warbase-colyseus-load:temporary}
DOCKER_BIN=${COLYSEUS_LOAD_DOCKER_BIN:-docker}
BUILD_IMAGE=${COLYSEUS_LOAD_BUILD_IMAGE:-1}
SERVER_CONTAINER=${COLYSEUS_SERVER_CONTAINER:-warbase-colyseus-candidate}
NETWORK=${COLYSEUS_LOAD_NETWORK:-warbase_server_default}
OUTDIR=${COLYSEUS_LOAD_OUTDIR:-/tmp/colyseus-official-load-$(date -u +%Y%m%dT%H%M%SZ)}
DOCKER_OUTDIR=${COLYSEUS_LOAD_DOCKER_OUTDIR:-$OUTDIR}
URL=https://war.vaidik.blog/colyseus
NAME=colyseus-official-load-$(date +%s)-$$
LOG=$OUTDIR/helper.log
LOAD_PID=
TAIL_PID=
STATS_PID=

for arg in "$@"; do
  case "$arg" in
    --url|--url=*|--url*) echo "The official endpoint is fixed; URL overrides are rejected." >&2; exit 2 ;;
  esac
done

mkdir -p "$OUTDIR"
if [ "$BUILD_IMAGE" = 1 ]; then
  "$DOCKER_BIN" build --file "$ROOT/warbase-colyseus/Dockerfile.load-harness" --tag "$IMAGE" "$ROOT"
else
  "$DOCKER_BIN" image inspect "$IMAGE" >/dev/null
fi

cleanup() {
  trap - EXIT INT TERM HUP
  if [ -n "$TAIL_PID" ]; then kill "$TAIL_PID" 2>/dev/null || true; fi
  if [ -n "$STATS_PID" ]; then kill "$STATS_PID" 2>/dev/null || true; fi
  if "$DOCKER_BIN" container inspect "$NAME" >/dev/null 2>&1; then "$DOCKER_BIN" stop --time 10 "$NAME" >/dev/null 2>&1 || true; fi
  if [ -n "$LOAD_PID" ]; then wait "$LOAD_PID" 2>/dev/null || true; fi
  if [ -n "$TAIL_PID" ]; then wait "$TAIL_PID" 2>/dev/null || true; fi
  if [ -n "$STATS_PID" ]; then wait "$STATS_PID" 2>/dev/null || true; fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

"$DOCKER_BIN" run --rm \
  --name "$NAME" \
  --network "$NETWORK" \
  --cpus=2.0 \
  --memory=1536m \
  --memory-swap=1536m \
  --pids-limit=128 \
  --init \
  --stop-timeout=15 \
  --cap-drop=ALL \
  --security-opt=no-new-privileges \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  --user "$(id -u):$(id -g)" \
  --volume "$DOCKER_OUTDIR:/results:rw" \
  "$IMAGE" \
  --url "$URL" "$@" --output /results/official-load.json >"$LOG" 2>&1 &
LOAD_PID=$!

tail -n +1 -f "$LOG" &
TAIL_PID=$!
(
  printf 'timestamp_utc,container,cpu_percent,memory_usage,memory_percent\n'
  while kill -0 "$LOAD_PID" 2>/dev/null; do
    stamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    for container in "$SERVER_CONTAINER" "$NAME"; do
      stats=$("$DOCKER_BIN" stats --no-stream --format '{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}}' "$container" 2>/dev/null || true)
      if [ -n "$stats" ]; then printf '%s,%s\n' "$stamp" "$stats"; fi
    done
    sleep 5
  done
) >"$OUTDIR/container-resources.csv" 2>&1 &
STATS_PID=$!

set +e
wait "$LOAD_PID"
RESULT=$?
set -e
LOAD_PID=
if [ -n "$TAIL_PID" ]; then kill "$TAIL_PID" 2>/dev/null || true; wait "$TAIL_PID" 2>/dev/null || true; TAIL_PID=; fi
if [ -n "$STATS_PID" ]; then kill "$STATS_PID" 2>/dev/null || true; wait "$STATS_PID" 2>/dev/null || true; STATS_PID=; fi
cat "$LOG"
printf 'LOAD_ARTIFACTS directory=%s report=%s resources=%s\n' "$OUTDIR" "$OUTDIR/official-load.json" "$OUTDIR/container-resources.csv"
exit "$RESULT"
