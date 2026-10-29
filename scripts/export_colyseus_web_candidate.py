#!/usr/bin/env python3
"""Export and verify the isolated Colyseus-enabled Godot Web candidate."""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import platform
import re
import shutil
import struct
import subprocess
import sys
import tempfile


ROOT = pathlib.Path(__file__).resolve().parents[1]
CLIENT = ROOT / "warbase-godot/client"
PRESET = "Web (Colyseus Candidate)"
SDK_WASM = CLIENT / "addons/colyseus/bin/libcolyseus_godot.web.wasm32.release.wasm"
SDK_EXTENSION = CLIENT / "addons/colyseus/colyseus.gdextension"


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
        offset += length + 16 + 16 + 4
    return names


def template_path(godot: pathlib.Path, version: str) -> pathlib.Path:
    override = os.environ.get("GODOT_TEMPLATE_DIR")
    if override:
        base = pathlib.Path(override)
    elif platform.system() == "Darwin":
        base = pathlib.Path.home() / "Library/Application Support/Godot/export_templates" / f"{version}.stable"
    elif platform.system() == "Windows":
        base = pathlib.Path(os.environ.get("APPDATA", pathlib.Path.home())) / "Godot/export_templates" / f"{version}.stable"
    else:
        base = pathlib.Path.home() / ".local/share/godot/export_templates" / f"{version}.stable"
    return base / "web_dlink_nothreads_release.zip"


def choose_output(value: str | None) -> pathlib.Path:
    if value is None:
        return (CLIENT / "candidate-web-dist").resolve()
    output = pathlib.Path(value).expanduser().resolve()
    temp_root = pathlib.Path(tempfile.gettempdir()).resolve()
    allowed_project_path = (CLIENT / "candidate-web-dist").resolve()
    try:
        output.relative_to(temp_root)
        allowed = True
    except ValueError:
        allowed = output == allowed_project_path
    if not allowed:
        raise RuntimeError("--output must be the client's candidate-web-dist directory or a path under the system temp directory")
    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", help="candidate export directory (defaults to client/candidate-web-dist)")
    parser.add_argument("--timeout", type=int, default=180, help="Godot export timeout in seconds (1-300)")
    args = parser.parse_args()
    if not 1 <= args.timeout <= 300:
        raise SystemExit("--timeout must be between 1 and 300 seconds")

    godot_value = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
    godot_command = shutil.which(godot_value) if not pathlib.Path(godot_value).is_file() else godot_value
    if not godot_command:
        raise SystemExit(f"Godot executable not found: {godot_value}")
    godot = pathlib.Path(godot_command).resolve()

    presets = (CLIENT / "export_presets.cfg").read_text()
    candidate_block = re.search(r"\[preset\.2\](.*?)(?=\n\[preset\.)", presets, re.S)
    options_block = re.search(r"\[preset\.2\.options\](.*?)(?=\n\[preset\.|\Z)", presets, re.S)
    if not candidate_block or 'name="Web (Colyseus Candidate)"' not in candidate_block.group(1):
        raise SystemExit("Candidate Web preset is missing")
    if 'export_path="candidate-web-dist/index.html"' not in candidate_block.group(1):
        raise SystemExit("Candidate Web preset must export to candidate-web-dist/index.html")
    if not options_block or "variant/extensions_support=true" not in options_block.group(1):
        raise SystemExit("Candidate Web preset must enable extensions_support")
    if not SDK_WASM.is_file() or SDK_WASM.stat().st_size == 0:
        raise SystemExit("Colyseus Web release binary is missing; run scripts/install_colyseus_godot_sdk.sh first")
    extension_text = SDK_EXTENSION.read_text()
    if 'web.release.wasm32 = "bin/libcolyseus_godot.web.wasm32.release.wasm"' not in extension_text:
        raise SystemExit("Colyseus GDExtension does not map the Web release binary")

    version_result = subprocess.run([str(godot), "--headless", "--version"], capture_output=True, text=True, timeout=10, check=True)
    version_match = re.search(r"(\d+\.\d+\.\d+)", version_result.stdout + version_result.stderr)
    if not version_match:
        raise SystemExit("Could not read Godot version")
    template = template_path(godot, version_match.group(1))
    if not template.is_file():
        raise SystemExit(f"Required dlink Web release template is missing: {template}")

    output = choose_output(args.output)
    if output in {(CLIENT / "dist").resolve(), (CLIENT / "build").resolve()}:
        raise SystemExit("Candidate output may not use production dist or build")
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)
    log_file = tempfile.NamedTemporaryFile(prefix="godot-colyseus-web-export-", suffix=".log", delete=False)
    log_path = pathlib.Path(log_file.name)
    log_file.close()

    command = [
        str(godot), "--headless", "--path", str(CLIENT),
        "--export-release", PRESET, str(output / "index.html"),
        "--log-file", str(log_path),
    ]
    process: subprocess.Popen[str] | None = None
    try:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        try:
            captured, _ = process.communicate(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            process.kill()
            captured, _ = process.communicate()
            print(captured)
            raise SystemExit(f"Godot candidate export exceeded {args.timeout}s; process killed")
        if process.returncode != 0:
            print(captured)
            raise SystemExit(f"Godot candidate export failed with exit {process.returncode}")
        diagnostics = [line.strip() for line in captured.splitlines() if "ERROR:" in line]
        for line in diagnostics:
            print(f"Godot diagnostic: {line}")

        html_path, pack_path, wasm_path = output / "index.html", output / "index.pck", output / "index.wasm"
        side_wasm_path = output / "index.side.wasm"
        for required in (html_path, pack_path, wasm_path, side_wasm_path):
            if not required.is_file() or required.stat().st_size == 0:
                raise SystemExit(f"Candidate export is missing {required.name}")
        html = html_path.read_text()
        config_match = re.search(r"const GODOT_CONFIG = (\{.*?\});", html, re.S)
        if not config_match:
            raise SystemExit("Candidate HTML has no Godot export configuration")
        config = json.loads(config_match.group(1))
        if config.get("fileSizes", {}).get("index.pck", 0) <= 0 or config.get("executable") != "index":
            raise SystemExit(f"Unexpected candidate HTML configuration: {config}")
        if "libcolyseus_godot.web.wasm32.release.wasm" not in config.get("gdextensionLibs", []):
            raise SystemExit(f"Candidate HTML does not register the Colyseus GDExtension wasm: {config.get('gdextensionLibs')}")

        paths = parse_pack_paths(pack_path)
        required_paths = {
            "addons/colyseus/colyseus.gdextension",
            "assets/data/industrial.json.gz",
        }
        playable_maps = (
            "football", "resoforge", "industrial", "village", "arena",
            "shipment", "dust2", "nuketown", "canyon", "desert_oasis",
        )
        required_paths.update(f"assets/data/maps/{map_name}.json.gz" for map_name in playable_maps)
        missing = required_paths - paths
        if missing:
            raise SystemExit("Candidate PCK omitted Colyseus extension files: " + ", ".join(sorted(missing)))
        exported_library = output / "libcolyseus_godot.web.wasm32.release.wasm"
        if not exported_library.is_file() or not exported_library.stat().st_size:
            raise SystemExit("Candidate export omitted the external Colyseus Web extension library")
        if exported_library.read_bytes() != SDK_WASM.read_bytes():
            raise SystemExit("Candidate extension library does not match the pinned SDK wasm")
        print(f"COLYSEUS_WEB_CANDIDATE_OK: Godot {version_match.group(1)}, dlink template, {len(paths)} PCK resources; exact SDK wasm ({exported_library.stat().st_size} bytes), side module ({side_wasm_path.stat().st_size} bytes)")
        print(f"Candidate: {output}")
        return 0
    finally:
        if process is not None and process.poll() is None:
            process.kill()
            process.wait()
        log_path.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.TimeoutExpired as error:
        raise SystemExit(f"Bounded prerequisite command timed out: {error}")
