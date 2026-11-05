"""Fingerprint assets and generate lossless gzip/Brotli companions.

Engine URLs stay stable across game-only updates. Retain the preceding release
for clients already opening its HTML; immutable URLs are never overwritten.
"""
import gzip
import hashlib
import json
import pathlib
import re
import shutil
import subprocess

folder = pathlib.Path(__file__).resolve().parents[1] / "warbase-godot/client/dist"
html_path = folder / "index.html"
html = html_path.read_text()
match = re.search(r"const GODOT_CONFIG = (\{.*?\});", html)
if not match:
    raise RuntimeError("Godot export configuration not found")
config = json.loads(match[1])
engine_files = sorted(p for p in folder.glob("index.*") if p.suffix in {".js", ".wasm"})
if not (folder / "index.wasm").exists() or not (folder / "index.pck").exists():
    raise RuntimeError("Run Godot's Web export before packaging")
digest = hashlib.sha256()
for path in engine_files:
    digest.update(path.name.encode())
    digest.update(path.read_bytes())
engine = "engine-" + digest.hexdigest()[:16]
pack = "game-" + hashlib.sha256((folder / "index.pck").read_bytes()).hexdigest()[:16] + ".pck"
renames = {p.name: engine + p.name.removeprefix("index") for p in engine_files}
renames["index.pck"] = pack
for original, versioned in renames.items():
    shutil.copyfile(folder / original, folder / versioned)
config["executable"] = engine
config["mainPack"] = pack
config["fileSizes"] = {renames.get(name, name): size for name, size in config["fileSizes"].items()}
html = html[:match.start(1)] + json.dumps(config, separators=(",", ":")) + html[match.end(1):]
# Explicit QA URLs exercise the exported Web client with the same input probe
# used by the native binary. Ordinary URLs keep the original configuration.
qa_bootstrap = """
const qaParams=new URLSearchParams(window.location.search);
if(window.location.hostname==='war.vaidik.blog' && qaParams.get('qa_official')==='1' && /^[0-9a-f-]{36}$/.test(qaParams.get('qa_room')||'')) {
 const qaMaps=['industrial','football','desert_oasis'];
 const qaMap=qaMaps.includes(qaParams.get('qa_map'))?qaParams.get('qa_map'):'industrial';
 const qaSeconds=Math.max(1,Math.min(1800,Number(qaParams.get('qa_seconds'))||180));
 GODOT_CONFIG.args=['--','qa_official','qa_room='+qaParams.get('qa_room'),'qa_map='+qaMap,'qa_seconds='+qaSeconds];
}
"""
html=html.replace('const engine = new Engine(GODOT_CONFIG);',qa_bootstrap+'\nconst engine = new Engine(GODOT_CONFIG);')
html_path.write_text(html.replace('src="index.js"', f'src="{engine}.js"'))
optional_path = folder / "optional-maps.json"
optional = json.loads(optional_path.read_text()) if optional_path.exists() else {}
optional_names = [entry["file"] for entry in optional.values()]
current = ["index.html", *renames.values(), *(["optional-maps.json"] if optional else [])]
compressed_names = current + optional_names
manifest_path = folder / "web-manifest.json"
previous = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
keep = set(current + previous.get("assets", []) + optional_names + [entry["file"] for entry in previous.get("optional", {}).values()])
for path in folder.iterdir():
    base = path.name.removesuffix(".gz").removesuffix(".br")
    if (base.startswith(("engine-", "game-", "map-football-")) and base not in keep) or base in renames:
        path.unlink()
for name in compressed_names:
    path = folder / name
    with path.open("rb") as reader, pathlib.Path(str(path) + ".gz").open("wb") as writer:
        with gzip.GzipFile(fileobj=writer, mode="wb", mtime=0, compresslevel=9) as compressed:
            shutil.copyfileobj(reader, compressed)
node = shutil.which("node")
if not node:
    raise RuntimeError("Node.js is required for built-in lossless Brotli compression")
subprocess.run([node, "-e", """
const fs=require('node:fs'),z=require('node:zlib');
for(const name of JSON.parse(process.argv[1])) {
 const bytes=fs.readFileSync(name);
 fs.writeFileSync(name+'.br',z.brotliCompressSync(bytes,{params:{
  [z.constants.BROTLI_PARAM_QUALITY]:9,
  [z.constants.BROTLI_PARAM_SIZE_HINT]:bytes.length
 }}));
}
""", json.dumps([str(folder / name) for name in compressed_names])], check=True)
manifest = {"assets": current, "optional": optional, "engine": engine, "pack": pack, "bytes": {}}
for encoding, suffix in {"identity": "", "gzip": ".gz", "br": ".br"}.items():
    manifest["bytes"][encoding] = sum((folder / (name + suffix)).stat().st_size for name in current)
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps({"release": pack, "download_bytes": manifest["bytes"]}, indent=2))
