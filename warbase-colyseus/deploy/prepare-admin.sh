#!/bin/sh
set -eu
# Run against the Docker engine that owns the game (Portainer's nested engine
# on Umbrel). COLYSEUS_DOCKER_BIN may be a wrapper for that engine.
DOCKER_BIN=${COLYSEUS_DOCKER_BIN:-docker}
"$DOCKER_BIN" volume create warbase-admin-data >/dev/null
"$DOCKER_BIN" volume create warbase-admin-secrets >/dev/null
"$DOCKER_BIN" run --rm --user 0 --entrypoint node \
  -v warbase-admin-data:/admin-data \
  -v warbase-admin-secrets:/admin-secrets \
  node:22-alpine -e '
const fs = require("node:fs");
const crypto = require("node:crypto");
for (const folder of ["/admin-data", "/admin-secrets"]) {
  fs.chownSync(folder, 1000, 1000);
  fs.chmodSync(folder, 0o700);
}
for (const name of ["jwt", "session"]) {
  const file = "/admin-secrets/" + name;
  if (!fs.existsSync(file)) fs.writeFileSync(file, crypto.randomBytes(48).toString("base64"), { mode: 0o400 });
  fs.chownSync(file, 1000, 1000);
  fs.chmodSync(file, 0o400);
}
'
echo 'Private admin storage and signing secrets ready; secret values were not printed.'
