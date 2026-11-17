"""Require physics-verified map authoring before either client release export."""
from __future__ import annotations
import hashlib
import json
import pathlib
import subprocess
import tempfile
from client_provenance import client_fingerprint
from optional_map_assets import RESTORED_MAPS

MAPS = ('football','industrial','village','arena','dust2','nuketown','canyon','military_base', 'ghost_city', 'cosmodrome', 'dam', 'skyline')

def ensure_map_integrity(root: pathlib.Path, godot: pathlib.Path) -> dict:
    client = root / 'warbase-godot/client'
    digest = hashlib.sha256()
    for name in MAPS:
        server = root / 'warbase-colyseus/src/data/maps' / (name + '.json.gz')
        predicted = client / 'assets/data/maps' / (name + '.json.gz')
        if server.read_bytes() != predicted.read_bytes():
            raise RuntimeError(f'Map release blocked: server/client geometry differs for {name}')
        digest.update(name.encode())
        digest.update(server.read_bytes())
    for relative in ('src/world-geometry.ts','src/capsule-contact.ts','src/drone-flight.ts','src/drone-hitboxes.ts','src/presentation-animation.ts','src/battle-room.ts',
                     'scripts/export-drone-prediction-fixtures.ts'):
        digest.update((root / 'warbase-colyseus' / relative).read_bytes())
    version = subprocess.check_output([str(godot),'--headless','--version'], text=True, timeout=10).strip()
    inputs = {'client':client_fingerprint(client),'server':digest.hexdigest(),'engine':version,
              'gate':hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest()}
    cache = root / 'build/qa/map-integrity.json'
    if cache.exists():
        previous = json.loads(cache.read_text())
        if previous.get('inputs') == inputs and previous.get('verified') is True:
            print(f'MAP_INTEGRITY_GATE_OK cached=true maps={len(MAPS)}')
            return previous
    with tempfile.TemporaryDirectory(prefix='warbase-map-gate-') as directory:
        report = pathlib.Path(directory) / 'result.json'
        process = subprocess.run([str(godot),'--headless','--fixed-fps','60','--quit-after','600','--path',str(client),'--script',
          'res://scripts/tests/test_all_map_integrity.gd','--','report='+str(report)],
          capture_output=True,text=True,timeout=90)
        output = process.stdout + process.stderr
        if process.returncode or 'SCRIPT ERROR' in output or not report.exists():
            raise RuntimeError('Map release blocked: physics audit failed\n'+output[-4000:])
        for exporter, test, argument, marker in (
            ('export-drone-prediction-fixtures.ts','test_drone_prediction_parity.gd','fixtures=', f'DRONE_PREDICTION_PARITY comparisons={len(MAPS) * 72}'),
        ):
            fixture = pathlib.Path(directory) / (exporter + '.json')
            generated = subprocess.run(['node','--import','tsx','scripts/'+exporter,'--out',str(fixture)],
                cwd=root/'warbase-colyseus',capture_output=True,text=True,timeout=30)
            if generated.returncode:
                raise RuntimeError('Map release blocked: fixture generation failed\n'+generated.stdout+generated.stderr)
            parity = subprocess.run([str(godot),'--headless','--path',str(client),'--log-file',str(pathlib.Path(directory)/(test+'.log')),
                '--script','res://scripts/tests/'+test,'--',argument+str(fixture)],capture_output=True,text=True,timeout=90)
            parity_output = parity.stdout + parity.stderr
            if parity.returncode or 'SCRIPT ERROR' in parity_output or marker not in parity_output:
                raise RuntimeError('Map release blocked: client/server parity failed\n'+parity_output[-6000:])
            print(marker)
        result = json.loads(report.read_text())
        if result.get('failures') or len(result.get('maps',[])) != len(MAPS):
            raise RuntimeError('Map release blocked: '+json.dumps(result))
    if client_fingerprint(client) != inputs['client']:
        raise RuntimeError('Map inputs changed during verification; run the export again')
    value = {'inputs':inputs,'verified':True,'report':result}
    cache.parent.mkdir(parents=True,exist_ok=True)
    cache.write_text(json.dumps(value,indent=2)+'\n')
    print(f'MAP_INTEGRITY_GATE_OK cached=false maps={len(MAPS)} spawns='+str(result['spawn_count']))
    return value


def verify_map_pack(paths: set[str], *, include_football: bool) -> None:
    """Collision without its scene or thumbnail must never ship."""
    if any('AnimatedSoldier' in path or 'soldier_hit_poses' in path for path in paths):
        raise RuntimeError('Retired humanoid resources cannot ship in the drone client')
    if any('loft' in path.lower() for path in paths):
        raise RuntimeError('Removed Loft 17 content cannot ship')
    required = {'assets/drones/vanguard.glb.import','assets/drones/raider.glb.import'}
    required.update({f'assets/data/maps/{name}.json.gz' for name in MAPS})
    required.update(f'assets/ui/maps/{name}.png.import' for name in MAPS)
    assets = ['low_poly_industrial_zone.glb','village_lowres.glb',
              'fps_shooter_game_arena_map_v3.glb']
    if include_football:
        required.update(f'assets/maps/restored/{name}.scn' for name in RESTORED_MAPS)
        required.update(f'assets/maps/{name}.scn' for name in ('cosmodrome', 'dam', 'skyline'))
        assets.append('football.glb')
    required.update('assets/maps/'+name+'.import' for name in assets)
    missing = required - paths
    for name in MAPS:
        if not any(p.startswith('.godot/imported/'+name+'.png-') and p.endswith('.ctex') for p in paths):
            missing.add('imported preview texture for '+name)
    for name in ('vanguard.glb','raider.glb',*assets):
        if not any(p.startswith('.godot/imported/'+name+'-') and p.endswith('.scn') for p in paths):
            missing.add('imported scene for '+name)
    if missing:
        raise RuntimeError('Map release blocked: missing packaged map content: '+', '.join(sorted(missing)))
