"""Check release URLs and prove compression reproduces every original byte."""
import gzip
import hashlib
import json
import pathlib
import re
import shutil
import struct
import subprocess

folder = pathlib.Path(__file__).resolve().parents[1] / "warbase-godot/client/dist"
manifest = json.loads((folder / "web-manifest.json").read_text())
html = (folder / "index.html").read_text()
config = json.loads(re.search(r"const GODOT_CONFIG = (\{.*?\});", html)[1])
assert config["mainPack"] == manifest["pack"]
assert config["executable"] == manifest["engine"]
assert f'src="{manifest["engine"]}.js"' in html
pack = (folder / manifest["pack"]).read_bytes()
assert hashlib.sha256(pack).hexdigest()[:16] in manifest["pack"]
all_assets = manifest["assets"] + [entry["file"] for entry in manifest.get("optional", {}).values()]
for name in all_assets:
    path = folder / name
    assert gzip.decompress(pathlib.Path(str(path) + ".gz").read_bytes()) == path.read_bytes(), name
subprocess.run([shutil.which("node"), "-e", """
const fs=require('node:fs'),z=require('node:zlib');
for(const path of JSON.parse(process.argv[1])) {
 if(!z.brotliDecompressSync(fs.readFileSync(path+'.br')).equals(fs.readFileSync(path))) throw Error(path);
}
""", json.dumps([str(folder / name) for name in all_assets])], check=True)
assert pack[:4] == b"GDPC" and struct.unpack_from("<I", pack, 4)[0] == 4
for entry in manifest.get("optional", {}).values():
    assert hashlib.sha256((folder / entry["file"]).read_bytes()).hexdigest() == entry["sha256"]
offset = struct.unpack_from("<Q", pack, 32)[0]
count = struct.unpack_from("<I", pack, offset)[0]
offset += 4
for _ in range(count):
    length = struct.unpack_from("<I", pack, offset)[0]
    offset += 4
    name = pack[offset:offset + length].rstrip(b"\0").decode()
    offset += length + 16 + 16 + 4
    assert not any(unused in name for unused in ["/combat_technical", "/Soldier", "venice_sunset", "/loft"]), name
print(f"WEB CHECK PASS: {count} packed files; gzip and Brotli are byte-identical; hashed URLs verified")
print(json.dumps(manifest["bytes"], indent=2))
