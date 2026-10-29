#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT="$ROOT/warbase-godot/client"
VERSION="0.18.7"
URL="https://github.com/colyseus/native-sdk/releases/download/godot-v${VERSION}/colyseus-godot-${VERSION}.zip"
SHA256="e7a0ecab03084c98033de55dfd03abb8336e02d0284af32025e53e6946f9510d"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

curl --fail --location --retry 3 --output "$TMP/sdk.zip" "$URL"
printf '%s  %s\n' "$SHA256" "$TMP/sdk.zip" | shasum -a 256 --check

python3 - "$TMP/sdk.zip" "$CLIENT/addons/colyseus" <<'PY'
import pathlib
import sys
import zipfile

archive = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
prefix = "addons/colyseus/"
keep = {
    "plugin.cfg",
    "plugin.gd",
    "version.json",
    "colyseus.gd",
    "colyseus.gdextension",
    "bin/libcolyseus_godot.macos.debug.dylib",
    "bin/libcolyseus_godot.macos.release.dylib",
    "bin/libcolyseus_godot.web.wasm32.debug.wasm",
    "bin/libcolyseus_godot.web.wasm32.release.wasm",
}

with zipfile.ZipFile(archive) as sdk:
    files = {item.filename: item for item in sdk.infolist() if not item.is_dir()}
    missing = [prefix + name for name in keep if prefix + name not in files]
    if missing:
        raise SystemExit("SDK archive is missing required files: " + ", ".join(missing))
    if target.exists():
        import shutil
        shutil.rmtree(target)
    target.mkdir(parents=True, exist_ok=True)
    for name in keep:
        relative = pathlib.PurePosixPath(name)
        destination = target.joinpath(*relative.parts)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(sdk.read(files[prefix + name]))
PY

cat > "$CLIENT/addons/colyseus/LICENSE" <<'LICENSE'
Copyright (c) 2025 Bharat Sharma, Endel Dreyer

MIT License:

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
LICENSE
cat > "$CLIENT/addons/colyseus/UPSTREAM.txt" <<MANIFEST
Colyseus Godot SDK ${VERSION}
Source: https://github.com/colyseus/native-sdk/releases/tag/godot-v${VERSION}
Asset: ${URL}
SHA-256: ${SHA256}
Extracted runtime targets: macOS arm64, Web wasm32
License: MIT (LICENSE; upstream LICENSE at the tag above)
MANIFEST

echo "Installed Colyseus Godot SDK ${VERSION} (macOS arm64 + Web wasm32)."
