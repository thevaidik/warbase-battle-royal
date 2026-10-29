#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
IMAGE=${COLYSEUS_CANDIDATE_IMAGE:-warbase-colyseus:candidate}

python3 "$ROOT/scripts/export_colyseus_web_candidate.py"
python3 "$ROOT/scripts/package_colyseus_web_candidate.py"
docker build \
  --file "$ROOT/warbase-colyseus/Dockerfile.candidate" \
  --tag "$IMAGE" \
  "$ROOT"
docker image inspect "$IMAGE" --format 'CANDIDATE_IMAGE_OK id={{.Id}} size={{.Size}}'
