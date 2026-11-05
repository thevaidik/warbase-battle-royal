"""Load the actual release and mount optional assets using the runtime loader."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
folder = root / "warbase-godot/client/dist"
manifest = json.loads((folder / "web-manifest.json").read_text())
godot = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
with tempfile.TemporaryDirectory(prefix="warbase-pack-check-") as directory:
    command = [godot, "--headless", "--main-pack", str(folder / manifest["pack"]), "--log-file", str(Path(directory) / "engine.log"), "--script", str(root / "warbase-godot/client/scripts/tests/test_optional_map_pack.gd"), "--", "optional=" + str(folder / manifest["optional"]["football"]["file"]), "manifest=" + str(folder / "optional-maps.json")]
    result = subprocess.run(command, capture_output=True, text=True, timeout=30)
    output = result.stdout + result.stderr
    print(output)
    if result.returncode or "OPTIONAL PACK TEST: PASS" not in output or "SCRIPT ERROR" in output:
        raise SystemExit(1)
