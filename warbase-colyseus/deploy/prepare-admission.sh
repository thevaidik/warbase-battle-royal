#!/bin/sh
set -eu
# Use the same Docker engine as the game. This preserves existing secrets.
DOCKER_BIN=${COLYSEUS_DOCKER_BIN:-docker}
"$DOCKER_BIN" volume create warbase-admission-secrets >/dev/null
"$DOCKER_BIN" volume create warbase-gateway-secrets >/dev/null
"$DOCKER_BIN" run --rm --user 0 --entrypoint node \
  -v warbase-admission-secrets:/admission \
  -v warbase-gateway-secrets:/gateway node:22-alpine -e '
const fs = require("node:fs");
const crypto = require("node:crypto");
for (const [directory, name, uid] of [["/admission", "jwt", 1000], ["/gateway", "token", 1000]]) {
  fs.chownSync(directory, uid, uid);
  fs.chmodSync(directory, 0o700);
  const file = directory + "/" + name;
  if (!fs.existsSync(file)) fs.writeFileSync(file, crypto.randomBytes(32).toString("base64url"), { mode: 0o400 });
  fs.chownSync(file, uid, uid);
  fs.chmodSync(file, 0o400);
}
'
echo 'Admission and gateway secrets prepared without printing values.'
