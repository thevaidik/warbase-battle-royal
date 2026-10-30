#!/usr/bin/env python3
"""Verify and package the isolated Colyseus Web export for static deployment."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import pathlib
import re
import shutil
import struct
import subprocess
import tempfile

from client_provenance import WEB_EXPORT_ASSETS, read_provenance, verify_artifacts, verify_current_export


ROOT = pathlib.Path(__file__).resolve().parents[1]
CLIENT = ROOT / "warbase-godot/client"
PLAYABLE_MAPS = (
    "football", "resoforge", "industrial", "village", "arena",
    "shipment", "dust2", "nuketown", "canyon", "desert_oasis",
)
ASSETS = WEB_EXPORT_ASSETS
SDK_WASM_ASSET = "libcolyseus_godot.web.wasm32.release.wasm"
SDK_WASM_RUNTIME_PATH = SDK_WASM_ASSET


def configure_gdextension_runtime(config: dict, renames: dict[str, str]) -> None:
    """Keep the SDK's original preload name, which the Web runtime requests."""
    if SDK_WASM_ASSET not in config.get("gdextensionLibs", []):
        raise RuntimeError("Candidate HTML is missing the Colyseus Web library registration")
    renames[SDK_WASM_ASSET] = SDK_WASM_RUNTIME_PATH
    config["gdextensionLibs"] = [
        SDK_WASM_RUNTIME_PATH if name == SDK_WASM_ASSET else renames.get(name, name)
        for name in config["gdextensionLibs"]
    ]


def copy_renamed_assets(source: pathlib.Path, output: pathlib.Path, renames: dict[str, str]) -> None:
    for original, renamed in renames.items():
        destination = output / renamed
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source / original, destination)


def render_packaged_html(html: str, config: dict, config_match: re.Match[str], renames: dict[str, str]) -> str:
    config["executable"] = renames["index.js"].removesuffix(".js")
    config["mainPack"] = renames["index.pck"]
    config["fileSizes"] = {renames.get(name, name): size for name, size in config.get("fileSizes", {}).items()}
    config["gdextensionLibs"] = [renames.get(name, name) for name in config.get("gdextensionLibs", [])]
    packaged_html = html[:config_match.start(1)] + json.dumps(config, separators=(",", ":")) + html[config_match.end(1):]
    for original, renamed in renames.items():
        # The SDK preload name must match the basename used by the runtime.
        if original != SDK_WASM_ASSET:
            packaged_html = packaged_html.replace(original, renamed)
    packaged_html = packaged_html.replace('src="index.js"', f'src="{renames["index.js"]}"')
    return packaged_html


def parse_pack_paths(path: pathlib.Path) -> set[str]:
    pack = path.read_bytes()
    if pack[:4] != b"GDPC" or len(pack) < 44:
        raise RuntimeError("Godot Web PCK has an invalid header")
    version = struct.unpack_from("<I", pack, 4)[0]
    if version != 4:
        raise RuntimeError(f"Unsupported PCK version {version}")
    offset = struct.unpack_from("<Q", pack, 32)[0]
    if offset + 4 > len(pack):
        raise RuntimeError("PCK directory offset is invalid")
    count = struct.unpack_from("<I", pack, offset)[0]
    offset += 4
    names: set[str] = set()
    for _ in range(count):
        if offset + 4 > len(pack):
            raise RuntimeError("PCK directory is truncated")
        length = struct.unpack_from("<I", pack, offset)[0]
        offset += 4
        if length > len(pack) - offset:
            raise RuntimeError("PCK path record is truncated")
        names.add(pack[offset : offset + length].rstrip(b"\0").decode("utf-8"))
        offset += length + 36
    return names


def sha(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def compress_assets(directory: pathlib.Path, names: list[str]) -> None:
    for name in names:
        source = directory / name
        with source.open("rb") as reader, (directory / (name + ".gz")).open("wb") as writer:
            with gzip.GzipFile(fileobj=writer, mode="wb", mtime=0, compresslevel=9) as zipped:
                shutil.copyfileobj(reader, zipped)
    node = shutil.which("node")
    if not node:
        raise RuntimeError("Node.js is required for precompressed Brotli assets")
    paths = [str(directory / name) for name in names]
    subprocess.run(
        [node, "-e", """
const fs=require('node:fs'),z=require('node:zlib');
for(const path of JSON.parse(process.argv[1])) {
 const bytes=fs.readFileSync(path);
 fs.writeFileSync(path+'.br',z.brotliCompressSync(bytes,{params:{
  [z.constants.BROTLI_PARAM_QUALITY]:9,
  [z.constants.BROTLI_PARAM_SIZE_HINT]:bytes.length
 }}));
}
""", json.dumps(paths)],
        check=True,
        timeout=120,
    )


def choose_output(value: str | None) -> pathlib.Path:
    if value is None:
        return (CLIENT / "candidate-static").resolve()
    output = pathlib.Path(value).expanduser().resolve()
    temp = pathlib.Path(tempfile.gettempdir()).resolve()
    allowed = output == (CLIENT / "candidate-static").resolve()
    try:
        output.relative_to(temp)
        allowed = True
    except ValueError:
        pass
    if not allowed:
        raise RuntimeError("--output must be client/candidate-static or a path under the system temp directory")
    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default=str(CLIENT / "candidate-web-dist"))
    parser.add_argument("--output", help="defaults to client/candidate-static")
    parser.add_argument("--server-only", action="store_true", help="package the existing client artifact unchanged for a server-only release")
    args = parser.parse_args()
    source = pathlib.Path(args.source).expanduser().resolve()
    output = choose_output(args.output)
    if output == source or output in {(CLIENT / "dist").resolve(), (CLIENT / "build").resolve()}:
        raise RuntimeError("Candidate packaging cannot overwrite its source or production exports")

    html_path = source / "index.html"
    for name in ASSETS:
        if not (source / name).is_file():
            raise RuntimeError(f"Candidate export is missing {name}")
    html = html_path.read_text()
    config_match = re.search(r"const GODOT_CONFIG = (\{.*?\});", html, re.S)
    if not config_match:
        raise RuntimeError("Candidate HTML has no Godot export configuration")
    config = json.loads(config_match.group(1))
    if config.get("executable") != "index" or "libcolyseus_godot.web.wasm32.release.wasm" not in config.get("gdextensionLibs", []):
        raise RuntimeError("Candidate HTML does not reference the expected SDK-enabled Godot Web export")

    provenance = read_provenance(source / "client-provenance.json")
    verify_artifacts(provenance, source, ["index.html", *ASSETS])
    if not args.server_only:
        verify_current_export(provenance, CLIENT)

    pck_paths = parse_pack_paths(source / "index.pck")
    required_pck = {
        "addons/colyseus/colyseus.gdextension",
        "assets/data/industrial.json.gz",
        "scripts/core/AudioManager.gdc",
        "scripts/core/AudioManager.gd.remap",
    }
    required_pck.update(f"assets/data/maps/{map_name}.json.gz" for map_name in PLAYABLE_MAPS)
    missing = required_pck - pck_paths
    if missing:
        raise RuntimeError("Candidate PCK is missing runtime resources: " + ", ".join(sorted(missing)))
    engine_hash = hashlib.sha256()
    for name in ASSETS:
        if name.startswith("index.") and name != "index.pck":
            engine_hash.update(name.encode())
            engine_hash.update((source / name).read_bytes())
    engine_stem = "engine-" + engine_hash.hexdigest()[:16]
    pack_name = "game-" + sha(source / "index.pck")[:16] + ".pck"
    renames = {
        "index.js": engine_stem + ".js",
        "index.wasm": engine_stem + ".wasm",
        "index.side.wasm": engine_stem + ".side.wasm",
        "index.audio.worklet.js": engine_stem + ".audio.worklet.js",
        "index.audio.position.worklet.js": engine_stem + ".audio.position.worklet.js",
        "index.pck": pack_name,
        "libcolyseus_godot.web.wasm32.release.wasm": SDK_WASM_ASSET,
        "index.png": "icon-" + sha(source / "index.png")[:16] + ".png",
        "index.icon.png": "icon-app-" + sha(source / "index.icon.png")[:16] + ".png",
        "index.apple-touch-icon.png": "icon-touch-" + sha(source / "index.apple-touch-icon.png")[:16] + ".png",
    }
    configure_gdextension_runtime(config, renames)

    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)
    copy_renamed_assets(source, output, renames)
    packaged_html = render_packaged_html(html, config, config_match, renames)
    (output / "index.html").write_text(packaged_html)

    names = ["index.html", *renames.values()]
    compress_assets(output, names)
    node = shutil.which("node")
    assert node
    for name in names:
        original = (output / name).read_bytes()
        if gzip.decompress((output / (name + ".gz")).read_bytes()) != original:
            raise RuntimeError(f"Gzip verification failed for {name}")
    subprocess.run([node, "-e", "const fs=require('node:fs'),z=require('node:zlib');for(const p of JSON.parse(process.argv[1]))if(!z.brotliDecompressSync(fs.readFileSync(p+'.br')).equals(fs.readFileSync(p)))process.exit(1);", json.dumps([str(output / name) for name in names])], check=True, timeout=120)

    manifest = {
        "product": "warbase-colyseus-web-candidate",
        "releaseScope": "server-only" if args.server_only else "full-client",
        "client": {
            **provenance,
            "artifact": "index.pck and Godot Web runtime files from the supplied export",
            "sourceMatchAtPackaging": not args.server_only,
        },
        "routePrefix": "/colyseus/",
        "entrypoint": "index.html",
        "engine": engine_stem,
        "pack": pack_name,
        "sdkWasm": SDK_WASM_RUNTIME_PATH,
        "pckResourceCount": len(pck_paths),
        "playableMapData": [f"assets/data/maps/{name}.json.gz" for name in PLAYABLE_MAPS],
        "compression": {"contentNegotiated": ["br", "gzip"], "sidecarSuffixes": [".br", ".gz"]},
        "cachePolicy": {
            "index.html": "no-cache",
            "hashedAssetPattern": r"^(engine|game|colyseus|icon|icon-app|icon-touch)-[0-9a-f]{16}\.",
            "hashedAssets": "public, max-age=31536000, immutable",
            "noCacheAssets": [SDK_WASM_RUNTIME_PATH],
        },
        "headers": {
            "index.html": {"Cache-Control": "no-cache"},
            "hashed assets": {"Cache-Control": "public, max-age=31536000, immutable"},
            "compressed sidecars": {"Content-Encoding": "selected from Accept-Encoding", "Vary": "Accept-Encoding"},
            "wasm": {"Content-Type": "application/wasm"},
            "crossOriginIsolation": {"Cross-Origin-Opener-Policy": "same-origin", "Cross-Origin-Embedder-Policy": "require-corp"},
        },
        "files": {},
    }
    for name in names:
        manifest["files"][name] = {"sha256": sha(output / name), "bytes": (output / name).stat().st_size}
    (output / "candidate-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"output": str(output), "release_scope": manifest["releaseScope"], "client_source_fingerprint": provenance["sourceFingerprint"], "godot_version": provenance["godotVersion"], "colyseus_sdk_version": provenance["colyseusSdkVersion"], "pck_resources": len(pck_paths), "maps": len(PLAYABLE_MAPS), "files": len(names), "bytes": {encoding: sum((output / (name + suffix)).stat().st_size for name in names) for encoding, suffix in (("identity", ""), ("gzip", ".gz"), ("br", ".br"))}}, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        raise SystemExit(str(error))
