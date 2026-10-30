#!/usr/bin/env python3
"""Export an isolated native macOS Colyseus candidate and record its provenance."""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import platform
import re
import shutil
import subprocess
import tempfile
import zipfile
import struct

from client_provenance import artifact_records, client_fingerprint, make_provenance


ROOT = pathlib.Path(__file__).resolve().parents[1]
CLIENT = ROOT / "warbase-godot/client"
PRESET = "macOS (Colyseus Candidate)"
PRESET_INDEX = "3"
DEFAULT_OUTPUT = CLIENT / "candidate-native" / "WarBase-Colyseus-macOS.zip"
LC_SEGMENT_64 = 0x19
LC_CODE_SIGNATURE = 0x1D
MH_MAGIC_64 = 0xFEEDFACF


def mach_o_segments(data: bytes) -> tuple[tuple[int, ...], list[tuple[str, int, int, int, int]], list[tuple[int, bytes]]]:
    if len(data) < 32:
        raise RuntimeError("Colyseus library is too short to be a Mach-O binary")
    magic, cpu, subtype, filetype, command_count, command_bytes, flags, reserved = struct.unpack_from("<IiiIIIII", data, 0)
    if magic != MH_MAGIC_64:
        raise RuntimeError("Colyseus library must be a 64-bit little-endian Mach-O binary")
    header = (magic, cpu, subtype, filetype, command_count, command_bytes, flags, reserved)
    offset = 32
    end_commands = offset + command_bytes
    if end_commands > len(data):
        raise RuntimeError("Mach-O load commands extend past the library")
    segments: list[tuple[str, int, int, int, int]] = []
    commands: list[tuple[int, bytes]] = []
    for _ in range(command_count):
        if offset + 8 > end_commands:
            raise RuntimeError("Mach-O load command header is truncated")
        command, size = struct.unpack_from("<II", data, offset)
        if size < 8 or offset + size > end_commands:
            raise RuntimeError("Mach-O load command has an invalid size")
        record = bytearray(data[offset:offset + size])
        if command == LC_SEGMENT_64:
            if size < 72:
                raise RuntimeError("Mach-O segment command is truncated")
            name = struct.unpack_from("<16s", record, 8)[0].split(b"\0", 1)[0].decode("ascii")
            vmaddr, vmsize, fileoff, filesize = struct.unpack_from("<QQQQ", record, 24)
            segments.append((name, vmaddr, vmsize, fileoff, filesize))
            if name == "__LINKEDIT":
                # Godot strips symbols and re-signs the dylib, changing only linkedit extent.
                record[32:40] = b"\0" * 8
                record[48:56] = b"\0" * 8
        elif command == LC_CODE_SIGNATURE:
            if size < 16:
                raise RuntimeError("Mach-O code-signature command is truncated")
            record[12:16] = b"\0" * 4
        commands.append((command, bytes(record)))
        offset += size
    if offset != end_commands:
        raise RuntimeError("Mach-O load-command byte count is inconsistent")
    return header, segments, commands


def verify_native_sdk_binary(installed: bytes, exported: bytes) -> None:
    installed_header, installed_segments, installed_commands = mach_o_segments(installed)
    exported_header, exported_segments, exported_commands = mach_o_segments(exported)
    if installed_header != exported_header or installed_commands != exported_commands:
        raise RuntimeError("Exported Colyseus library differs from the installed SDK outside Godot's linkedit/signature normalization")
    def normalized_segments(rows: list[tuple[str, int, int, int, int]]) -> list[tuple[str, int, int, int, int]]:
        return [
            (name, vmaddr, 0, fileoff, 0) if name == "__LINKEDIT" else row
            for row in rows
            for name, vmaddr, _vmsize, fileoff, _filesize in [row]
        ]
    if normalized_segments(installed_segments) != normalized_segments(exported_segments):
        raise RuntimeError("Exported Colyseus library has different Mach-O segment layout")
    for name, _vmaddr, _vmsize, fileoff, filesize in installed_segments:
        if name == "__LINKEDIT":
            continue
        if fileoff + filesize > len(installed) or fileoff + filesize > len(exported):
            raise RuntimeError(f"Mach-O segment {name} extends past a library file")
        start = fileoff
        if name == "__TEXT":
            start = max(start, 32 + sum(len(record) for _command, record in installed_commands))
        if installed[start:fileoff + filesize] != exported[start:fileoff + filesize]:
            raise RuntimeError(f"Exported Colyseus library changed executable/data segment {name}")


def choose_output(value: str | None) -> pathlib.Path:
    output = pathlib.Path(value).expanduser().resolve() if value else DEFAULT_OUTPUT.resolve()
    allowed = output == DEFAULT_OUTPUT.resolve()
    try:
        output.relative_to(pathlib.Path(tempfile.gettempdir()).resolve())
        allowed = True
    except ValueError:
        pass
    if not allowed:
        raise RuntimeError("--output must be client/candidate-native/WarBase-Colyseus-macOS.zip or a path under the system temp directory")
    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", help="isolated candidate zip path (defaults to client/candidate-native/WarBase-Colyseus-macOS.zip)")
    parser.add_argument("--timeout", type=int, default=300, help="Godot export timeout in seconds (1-900)")
    args = parser.parse_args()
    if not 1 <= args.timeout <= 900:
        raise SystemExit("--timeout must be between 1 and 900 seconds")
    if platform.system() != "Darwin":
        raise SystemExit("Native Colyseus candidate export requires macOS")

    godot_value = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
    godot_command = shutil.which(godot_value) if not pathlib.Path(godot_value).is_file() else godot_value
    if not godot_command:
        raise SystemExit(f"Godot executable not found: {godot_value}")
    godot = pathlib.Path(godot_command).resolve()

    presets = (CLIENT / "export_presets.cfg").read_text()
    candidate_block = re.search(rf"\[preset\.{PRESET_INDEX}\](.*?)(?=\n\[preset\.)", presets, re.S)
    options_block = re.search(rf"\[preset\.{PRESET_INDEX}\.options\](.*?)(?=\n\[preset\.|\Z)", presets, re.S)
    if not candidate_block or f'name="{PRESET}"' not in candidate_block.group(1):
        raise SystemExit("Candidate macOS preset is missing")
    if 'export_path="build/colyseus-candidate/WarBase-Colyseus-macOS.zip"' not in candidate_block.group(1):
        raise SystemExit("Candidate macOS preset must retain its isolated candidate export path")
    if not options_block or "variant/extensions_support=true" not in options_block.group(1):
        raise SystemExit("Candidate macOS preset must enable GDExtension support")
    sdk_version = json.loads((CLIENT / "addons/colyseus/version.json").read_text())["version"]
    native_library = CLIENT / "addons/colyseus/bin/libcolyseus_godot.macos.release.dylib"
    if not native_library.is_file() or native_library.stat().st_size == 0:
        raise SystemExit("Colyseus macOS release library is missing")

    version_result = subprocess.run([str(godot), "--headless", "--version"], capture_output=True, text=True, timeout=10, check=True)
    version_match = re.search(r"(\d+\.\d+\.\d+)", version_result.stdout + version_result.stderr)
    if not version_match:
        raise SystemExit("Could not read Godot version")

    output = choose_output(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    provenance_path = output.with_name("client-provenance.json")
    export_fingerprint = client_fingerprint(CLIENT)
    command = [str(godot), "--headless", "--path", str(CLIENT), "--export-release", PRESET, str(output)]
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
        if not output.is_file() or output.stat().st_size == 0:
            raise SystemExit(f"Candidate export is missing or empty: {output}")
        with zipfile.ZipFile(output) as archive:
            sdk_members = [name for name in archive.namelist() if name.endswith("libcolyseus_godot.macos.release.dylib")]
            if not sdk_members:
                raise SystemExit("Candidate macOS archive omitted the Colyseus release library")
            sdk_bytes = native_library.read_bytes()
            matched_library: bytes | None = None
            for name in sdk_members:
                candidate_bytes = archive.read(name)
                try:
                    verify_native_sdk_binary(sdk_bytes, candidate_bytes)
                    matched_library = candidate_bytes
                    break
                except RuntimeError:
                    continue
            if matched_library is None:
                raise SystemExit("Candidate macOS release library does not match the installed SDK executable and data segments")
            with tempfile.NamedTemporaryFile(prefix="colyseus-native-export-check-", suffix=".dylib") as library_check:
                library_check.write(matched_library)
                library_check.flush()
                subprocess.run(["codesign", "--verify", "--strict", library_check.name], check=True, capture_output=True, text=True, timeout=30)
        if client_fingerprint(CLIENT) != export_fingerprint:
            raise SystemExit("Client source changed while the export was running; discard it and export again")

        provenance = make_provenance(CLIENT, version_match.group(1), str(sdk_version))
        provenance["target"] = "macOS"
        provenance["artifactName"] = output.name
        provenance["artifacts"] = artifact_records(output.parent, [output.name])
        provenance_path.write_text(json.dumps(provenance, indent=2) + "\n")
        print(json.dumps({
            "status": "COLYSEUS_NATIVE_CANDIDATE_OK",
            "artifact": str(output),
            "provenance": str(provenance_path),
            "sourceFingerprint": provenance["sourceFingerprint"],
            "godotVersion": provenance["godotVersion"],
            "colyseusSdkVersion": provenance["colyseusSdkVersion"],
            "artifactSha256": provenance["artifacts"][output.name]["sha256"],
            "artifactBytes": provenance["artifacts"][output.name]["bytes"],
            "launchBackendArgument": "backend=colyseus",
        }, indent=2))
        return 0
    finally:
        if process is not None and process.poll() is None:
            process.kill()
            process.wait()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        raise SystemExit(str(error))
