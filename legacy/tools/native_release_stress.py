#!/usr/bin/env python3
"""Run the exported macOS game alongside 63 peers on the official server."""
import argparse
import json
import pathlib
import subprocess
import tempfile
import time
import uuid
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument("--name", required=True)
parser.add_argument("--map", default="industrial", choices=["industrial", "football", "desert_oasis"])
parser.add_argument("--seconds", type=int, default=180)
args = parser.parse_args()
if not args.name.replace("-", "").isalnum() or not 1 <= args.seconds <= 1800:
    parser.error("invalid bounded test parameters")
root = pathlib.Path(__file__).resolve().parents[1]
folder = root / "audit/production-followup-2026-10-28"
room_file = folder / (args.name + "-room.json")
if room_file.exists():
    parser.error("choose a new test name to preserve previous evidence")
with tempfile.TemporaryDirectory(prefix="warbase-native-qa-") as temporary:
    with zipfile.ZipFile(root / "build/WarBase-macOS.zip") as archive:
        archive.extractall(temporary)
    binary = pathlib.Path(temporary) / "WarBase Battle Royale.app/Contents/MacOS/WarBase Battle Royale"
    binary.chmod(0o755)
    cohort = subprocess.Popen(["python3", "-u", str(root / "scripts/official_stress.py"), "--name", args.name, "--map", args.map, "--clients", "63", "--drivers", "1", "--seconds", str(min(args.seconds + 45, 1800))], stdout=(folder / (args.name + "-runner.log")).open("w"), stderr=subprocess.STDOUT)
    for _ in range(150):
        if room_file.exists():
            break
        if cohort.poll() is not None:
            raise SystemExit("Cohort could not start; inspect its runner log")
        time.sleep(.2)
    room = str(uuid.UUID(json.loads(room_file.read_text())["room_id"]))
    command = [str(binary), "--resolution", "1280x800", "--max-fps", "120", "--log-file", str(folder / (args.name + "-engine.log")), "--", "qa_official", "qa_room=" + room, "qa_map=" + args.map, "qa_seconds=" + str(args.seconds), "qa_output=" + str(folder / (args.name + "-native.json"))]
    with (folder / (args.name + "-console.log")).open("w") as console:
        native = subprocess.Popen(command, stdout=console, stderr=subprocess.STDOUT)
        print("EXPORTED NATIVE TEST STARTED room=" + room, flush=True)
        try:
            native.wait(timeout=args.seconds + 90)
        except subprocess.TimeoutExpired:
            native.terminate()
            try:
                native.wait(timeout=5)
            except subprocess.TimeoutExpired:
                native.kill()
                native.wait()
    cohort.wait(timeout=args.seconds + 105)
    if native.returncode or cohort.returncode:
        raise SystemExit("Native/cohort failed; inspect saved evidence")
    report = json.loads((folder / (args.name + "-native.json")).read_text())
    print(json.dumps(report, indent=2), flush=True)
    if not report["release_export"] or report["disconnects"]:
        raise SystemExit("Native release validation failed")
