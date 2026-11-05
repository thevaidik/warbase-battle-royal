#!/usr/bin/env python3
"""Exercise a dedicated room on the official WSS host and record occupancy."""
import argparse
import json
import pathlib
import subprocess
import time
import uuid

parser = argparse.ArgumentParser()
parser.add_argument("--name", required=True)
parser.add_argument("--map", default="industrial")
parser.add_argument("--clients", type=int, default=64)
parser.add_argument("--seconds", type=int, default=90)
parser.add_argument("--drivers", type=int, default=6)
args = parser.parse_args()
if not args.name.replace("-", "").isalnum() or not 1 <= args.clients <= 64 or not 1 <= args.seconds <= 1800 or not 0 <= args.drivers <= args.clients:
    parser.error("invalid bounded test parameters")
if args.map not in {"industrial", "football", "desert_oasis"}:
    parser.error("unsupported test map")
folder = pathlib.Path(__file__).resolve().parents[1] / "audit/production-followup-2026-10-28"
folder.mkdir(exist_ok=True)

def request(path, body=None):
    command = ["curl", "-fsS", "--max-time", "20", "https://war.vaidik.blog" + path]
    if body is not None:
        command += ["-X", "POST", "-H", "Content-Type: application/json", "--data-binary", json.dumps(body)]
    return json.loads(subprocess.check_output(command))

room = request("/api/rooms", {"name": "QA " + args.name, "map": args.map, "mode": "TDM", "timeOfDay": "noon"})
rid = str(uuid.UUID(room["room_id"]))
(folder / (args.name + "-room.json")).write_text(json.dumps(room))
remote_output = "/tmp/warbase-" + args.name + ".json"
command = f"/tmp/warbase-stress-followup -host=war.vaidik.blog -room={rid} -players={args.clients} -drivers={args.drivers} -duration={args.seconds}s -output={remote_output}"
print("OFFICIAL TEST STARTED room=" + rid, flush=True)
started = time.monotonic()
samples = []
with (folder / (args.name + "-load.log")).open("w") as log:
    process = subprocess.Popen(["ssh", "-o", "BatchMode=yes", "umbrel", command], stdout=log, stderr=subprocess.STDOUT)
    while process.poll() is None:
        try:
            rooms = request("/api/rooms")
            current = next((r for r in rooms["rooms"] if r["id"] == rid), {})
            samples.append({"elapsed": round(time.monotonic() - started, 1), "room": current})
            (folder / (args.name + "-occupancy.json")).write_text(json.dumps(samples, indent=2))
        except (ValueError, subprocess.SubprocessError) as error:
            print("Occupancy sample failed: " + type(error).__name__, flush=True)
        time.sleep(10)
destination = folder / (args.name + "-load.json")
subprocess.run(["scp", "-q", "-o", "BatchMode=yes", "umbrel:" + remote_output, str(destination)], check=True)
report = json.loads(destination.read_text())
print(json.dumps(report, indent=2), flush=True)
if report["joined"] != args.clients or report["connection_errors"]:
    raise SystemExit("Cohort failed: inspect its saved report")
