#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
IMAGE=${COLYSEUS_CANDIDATE_IMAGE:-warbase-colyseus:candidate}
PACKAGE="$ROOT/warbase-godot/client/candidate-static/candidate-manifest.json"

if [ ! -s "$PACKAGE" ]; then
  echo "Missing packaged candidate assets: $PACKAGE" >&2
  echo "Build them on the Godot export host with scripts/package_colyseus_web_candidate.py first." >&2
  exit 2
fi

python3 - "$PACKAGE" <<'PY'
import json, pathlib, sys
manifest_path = pathlib.Path(sys.argv[1])
manifest = json.loads(manifest_path.read_text())
if manifest.get("product") != "warbase-colyseus-web-candidate":
    raise SystemExit("Unexpected candidate manifest product")
if manifest.get("routePrefix") != "/colyseus/":
    raise SystemExit("Unexpected candidate route prefix")
for filename, record in manifest.get("files", {}).items():
    asset = manifest_path.parent / filename
    if not asset.is_file() or asset.stat().st_size != record.get("bytes"):
        raise SystemExit(f"Candidate asset missing or size changed: {filename}")
PY

docker build \
  --file "$ROOT/warbase-colyseus/Dockerfile.candidate" \
  --tag "$IMAGE" \
  "$ROOT"
docker image inspect "$IMAGE" --format 'CANDIDATE_IMAGE_OK id={{.Id}} size={{.Size}}'
