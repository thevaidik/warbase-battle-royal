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


ROOT = pathlib.Path(__file__).resolve().parents[1]
CLIENT = ROOT / "warbase-godot/client"
PLAYABLE_MAPS = (
    "football", "resoforge", "industrial", "village", "arena",
    "shipment", "dust2", "nuketown", "canyon", "desert_oasis",
)
ASSETS = (
    "index.js", "index.wasm", "index.side.wasm", "index.pck",
    "index.audio.worklet.js", "index.audio.position.worklet.js",
    "libcolyseus_godot.web.wasm32.release.wasm",
    "index.png", "index.icon.png", "index.apple-touch-icon.png",
)


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

    main_source = (CLIENT / "scripts/core/Main.gd").read_text()
    network_source = (CLIENT / "scripts/net/ColyseusNetwork.gd").read_text()
    route_contract = (
        'web_backend.to_lower() == "colyseus"' in main_source
        and 'web_path == "/colyseus" or web_path.begins_with("/colyseus/")' in main_source
        and 'if _use_colyseus else NetScript.new()' in main_source
        and 'String(web_path).begins_with("/colyseus") or web_backend in ["colyseus", "qa_colyseus"]' in network_source
        and 'endpoint = "%s://%s%s"' in network_source
    )
    if not route_contract:
        raise RuntimeError("Web backend-selection contract changed; verify bare-root fallback and /colyseus prefix before packaging")

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
    audio_source = (CLIENT / "scripts/core/AudioManager.gd").read_text()
    for audio_guard in ("const AUDIO_ENABLED := false", "var muted := true", "var master_volume := 0.0", 'AudioServer.set_bus_mute(master, true)'):
        if audio_guard not in audio_source:
            raise RuntimeError("Candidate audio mute contract changed; review before packaging")

    engine_hash = hashlib.sha256()
    for name in ASSETS:
        if name.startswith("index.") and name != "index.pck":
            engine_hash.update(name.encode())
            engine_hash.update((source / name).read_bytes())
    engine_stem = "engine-" + engine_hash.hexdigest()[:16]
    pack_name = "game-" + sha(source / "index.pck")[:16] + ".pck"
    sdk_name = "colyseus-" + sha(source / "libcolyseus_godot.web.wasm32.release.wasm")[:16] + ".wasm"
    renames = {
        "index.js": engine_stem + ".js",
        "index.wasm": engine_stem + ".wasm",
        "index.side.wasm": engine_stem + ".side.wasm",
        "index.audio.worklet.js": engine_stem + ".audio.worklet.js",
        "index.audio.position.worklet.js": engine_stem + ".audio.position.worklet.js",
        "index.pck": pack_name,
        "libcolyseus_godot.web.wasm32.release.wasm": sdk_name,
        "index.png": "icon-" + sha(source / "index.png")[:16] + ".png",
        "index.icon.png": "icon-app-" + sha(source / "index.icon.png")[:16] + ".png",
        "index.apple-touch-icon.png": "icon-touch-" + sha(source / "index.apple-touch-icon.png")[:16] + ".png",
    }

    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)
    for original, renamed in renames.items():
        shutil.copyfile(source / original, output / renamed)
    config["executable"] = engine_stem
    config["mainPack"] = pack_name
    config["fileSizes"] = {renames.get(name, name): size for name, size in config.get("fileSizes", {}).items()}
    config["gdextensionLibs"] = [renames.get(name, name) for name in config.get("gdextensionLibs", [])]
    packaged_html = html[:config_match.start(1)] + json.dumps(config, separators=(",", ":")) + html[config_match.end(1):]
    for original, renamed in renames.items():
        packaged_html = packaged_html.replace(original, renamed)
    packaged_html = packaged_html.replace('src="index.js"', f'src="{renames["index.js"]}"')
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
        "routePrefix": "/colyseus/",
        "entrypoint": "index.html",
        "engine": engine_stem,
        "pack": pack_name,
        "sdkWasm": sdk_name,
        "pckResourceCount": len(pck_paths),
        "playableMapData": [f"assets/data/maps/{name}.json.gz" for name in PLAYABLE_MAPS],
        "compression": {"contentNegotiated": ["br", "gzip"], "sidecarSuffixes": [".br", ".gz"]},
        "cachePolicy": {
            "index.html": "no-cache",
            "hashedAssetPattern": r"^(engine|game|colyseus|icon|icon-app|icon-touch)-[0-9a-f]{16}\.",
            "hashedAssets": "public, max-age=31536000, immutable",
        },
        "headers": {
            "index.html": {"Cache-Control": "no-cache"},
            "hashed assets": {"Cache-Control": "public, max-age=31536000, immutable"},
            "compressed sidecars": {"Content-Encoding": "selected from Accept-Encoding", "Vary": "Accept-Encoding"},
            "wasm": {"Content-Type": "application/wasm"},
            "crossOriginIsolation": {"Cross-Origin-Opener-Policy": "same-origin", "Cross-Origin-Embedder-Policy": "require-corp"},
        },
        "audio": {
            "runtimeMuted": True,
            "contract": "AUDIO_ENABLED=false; Master bus muted in WarAudioManager._ready().",
            "worklets": "Web template worklet files remain bundled but produce no game audio while runtime is muted.",
        },
        "files": {},
    }
    for name in names:
        manifest["files"][name] = {"sha256": sha(output / name), "bytes": (output / name).stat().st_size}
    (output / "candidate-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"output": str(output), "pck_resources": len(pck_paths), "maps": len(PLAYABLE_MAPS), "web_route_contract": "bare root defaults to legacy; /colyseus/ selects Colyseus; backend=colyseus preserves prefix", "files": len(names), "bytes": {encoding: sum((output / (name + suffix)).stat().st_size for name in names) for encoding, suffix in (("identity", ""), ("gzip", ".gz"), ("br", ".br"))}}, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        raise SystemExit(str(error))
