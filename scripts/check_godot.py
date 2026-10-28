#!/usr/bin/env python3
"""Run bounded Godot tests; fail even when a script error incorrectly exits with code 0."""
import os
import pathlib
import selectors
import subprocess
import sys
import tempfile
import time

root = pathlib.Path(__file__).resolve().parents[1]
godot = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
commands = [
    (["--script", "res://scripts/tests/test_vehicle_wheels.gd", "--fixed-fps", "60"], "VEHICLE WHEEL TEST: 0 failures"),
    (["--script", "res://scripts/tests/test_network_recovery.gd", "--fixed-fps", "60"], "NETWORK RECOVERY TEST: 0 failures"),
    (["--script", "res://scripts/tests/test_traversal_safety.gd", "--fixed-fps", "60"], "TRAVERSAL SAFETY TEST: 0 failures"),
    (["--script", "res://scripts/tests/test_football_map.gd", "--fixed-fps", "60"], "FOOTBALL MAP TEST: 0 failures"),
    (["--script", "res://scripts/tests/test_grenade_ballistics.gd", "--fixed-fps", "60"], "GRENADE BALLISTICS TEST: 0 failures"),
    (["--script", "res://scripts/tests/test_industrial_collision.gd", "--fixed-fps", "60"], "INDUSTRIAL COLLISION TEST: 0 failures"),
    (["--script", "res://scripts/tests/test_weapon_handling.gd", "--fixed-fps", "60"], "WEAPON TEST: 0 failures"),
    (["--script", "res://scripts/tests/test_hitboxes.gd", "--fixed-fps", "60"], "HITBOX TEST: 0 failures"),
    (["res://scenes/Main.tscn", "--fixed-fps", "60", "--", "autotest", "host=localhost:18091"], "AUTOTEST: DONE"),
]
for arguments, marker in commands:
    with tempfile.TemporaryDirectory(prefix="warbase-test-") as directory:
        command = [godot, "--headless", "--path", str(root / "warbase-godot/client"), "--log-file", str(pathlib.Path(directory) / "engine.log")] + arguments
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        output_bytes = bytearray()
        deadline = time.monotonic() + 40
        exceeded = False
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            while True:
                if time.monotonic() >= deadline or len(output_bytes) > 2_000_000:
                    exceeded = True
                    process.kill()
                    break
                for key, _ in selector.select(0.1):
                    chunk = key.fileobj.read1(65536)
                    if chunk:
                        output_bytes.extend(chunk)
                if process.poll() is not None:
                    output_bytes.extend(process.stdout.read(2_000_001 - min(len(output_bytes), 2_000_001)))
                    break
        process.wait()
        output = output_bytes.decode(errors="replace")
        print(output)
        if exceeded:
            sys.exit("Godot exceeded the time or output limit")
        bad = any(token in output for token in ["SCRIPT ERROR", "CHECK FAIL", "!v.is_finite()", "cannot be normalized", "Parse Error"])
        if process.returncode or marker not in output or bad:
            sys.exit(1)
