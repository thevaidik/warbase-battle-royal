#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT=${1:-/tmp/warbase-colyseus-candidate.tar.gz}
OUT_DIR=$(dirname -- "$OUT")
mkdir -p "$OUT_DIR"
OUT=$(cd -- "$OUT_DIR" && pwd)/$(basename -- "$OUT")
case "$OUT" in
  "$ROOT"/*) echo "Archive output must be outside the repository" >&2; exit 2 ;;
esac

PACKAGE="$ROOT/warbase-godot/client/candidate-static/candidate-manifest.json"
if [ ! -s "$PACKAGE" ]; then
  echo "Missing packaged candidate assets: $PACKAGE" >&2
  exit 2
fi

tar -czf "$OUT" -C "$ROOT" \
  .dockerignore \
  warbase-colyseus/Dockerfile.candidate \
  warbase-colyseus/Dockerfile.load-harness \
  warbase-colyseus/package.json \
  warbase-colyseus/package-lock.json \
  warbase-colyseus/tsconfig.json \
  warbase-colyseus/scripts \
  warbase-colyseus/src \
  warbase-colyseus/deploy/compose.candidate.yml \
  warbase-colyseus/deploy/colyseus-location.nginx.conf \
  warbase-colyseus/deploy/README-candidate.md \
  warbase-godot/client/candidate-static \
  scripts/build_colyseus_candidate_image.sh \
  scripts/run_colyseus_official_load.sh \
  scripts/run_colyseus_official_load_nested.sh

printf 'CANDIDATE_SNAPSHOT_OK path=%s bytes=%s\n' "$OUT" "$(wc -c < "$OUT" | tr -d ' ')"
