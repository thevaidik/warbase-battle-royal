"""Fingerprint the client inputs that determine a Colyseus client export."""

from __future__ import annotations

import hashlib
import json
import pathlib
import struct


GENERATED_DIRS = {".godot", "candidate-static", "candidate-web-dist", "candidate-native", "candidate-dist", "dist", "build"}
WEB_EXPORT_ASSETS = (
    "index.js", "index.wasm", "index.side.wasm", "index.pck",
    "index.audio.worklet.js", "index.audio.position.worklet.js",
    "libcolyseus_godot.web.wasm32.release.wasm",
    "index.png", "index.icon.png", "index.apple-touch-icon.png",
)


def client_fingerprint(client: pathlib.Path) -> str:
    digest = hashlib.sha256()
    files = sorted(
        path for path in client.rglob("*")
        if path.is_file() and not any(part in GENERATED_DIRS for part in path.relative_to(client).parts)
    )
    for path in files:
        relative = path.relative_to(client).as_posix()
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        digest.update(b"\0")
    return digest.hexdigest()


def make_provenance(client: pathlib.Path, godot_version: str, sdk_version: str) -> dict[str, str]:
    value = {
        "sourceFingerprint": client_fingerprint(client),
        "godotVersion": godot_version,
        "colyseusSdkVersion": sdk_version,
    }
    patch_path = client / "addons/colyseus/LOCAL_PATCH.json"
    if patch_path.exists():
        patch = json.loads(patch_path.read_text())
        actual = hashlib.sha256((patch_path.parent / "colyseus.gd").read_bytes()).hexdigest()
        if patch.get("sdkVersion") != sdk_version or patch.get("sourceSha256") != actual:
            raise RuntimeError("SDK source patch manifest does not match the pinned SDK/script")
        value["colyseusSdkSourcePatch"] = patch["patchId"] + ":" + actual
    return value


def artifact_records(directory: pathlib.Path, names: list[str]) -> dict[str, dict[str, int | str]]:
    records: dict[str, dict[str, int | str]] = {}
    for name in sorted(set(names)):
        path = directory / name
        if not path.is_file():
            raise RuntimeError(f"Export artifact is missing required file: {name}")
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        records[name] = {"sha256": digest.hexdigest(), "bytes": path.stat().st_size}
    return records


def verify_artifacts(provenance: dict, directory: pathlib.Path, names: list[str]) -> None:
    records = provenance.get("artifacts")
    if not isinstance(records, dict):
        raise RuntimeError("Client export provenance has no artifact hash records; re-export the client")
    for name in sorted(set(names)):
        expected = records.get(name)
        if not isinstance(expected, dict) or not isinstance(expected.get("sha256"), str) or not isinstance(expected.get("bytes"), int):
            raise RuntimeError(f"Client export provenance has no valid hash record for {name}")
        path = directory / name
        if not path.is_file():
            raise RuntimeError(f"Client export artifact is missing: {name}")
        actual = artifact_records(directory, [name])[name]
        if actual != expected:
            raise RuntimeError(f"Client export artifact does not match its provenance: {name}")


def read_provenance(path: pathlib.Path) -> dict[str, str]:
    try:
        value = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeError(f"Client export provenance is missing or invalid: {path}") from error
    required = ("sourceFingerprint", "godotVersion", "colyseusSdkVersion")
    if not isinstance(value, dict) or any(not isinstance(value.get(key), str) or not value[key] for key in required):
        raise RuntimeError("Client export provenance must include sourceFingerprint, godotVersion, and colyseusSdkVersion")
    if not isinstance(value.get("artifacts"), dict):
        raise RuntimeError("Client export provenance must include artifact hashes; re-export the client")
    return {**{key: value[key] for key in required}, **({"colyseusSdkSourcePatch": value["colyseusSdkSourcePatch"]} if isinstance(value.get("colyseusSdkSourcePatch"), str) else {}), "artifacts": value["artifacts"]}


def verify_current_export(provenance: dict[str, str], client: pathlib.Path) -> None:
    current = client_fingerprint(client)
    if provenance["sourceFingerprint"] != current:
        raise RuntimeError(
            "Stale client export: client source changed after export "
            f"(export={provenance['sourceFingerprint']}, current={current}); re-export before full-client packaging"
        )


def parse_pack_paths_bytes(pack: bytes) -> set[str]:
    if pack[:4] != b"GDPC" or len(pack) < 44:
        raise RuntimeError("Godot PCK has an invalid header")
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
        offset += length + 16 + 16 + 4
    return names


def parse_pack_paths(path: pathlib.Path) -> set[str]:
    return parse_pack_paths_bytes(path.read_bytes())
