"""Validate the on-demand Stadium artifact before export or deployment."""
from __future__ import annotations
import hashlib
import json
import pathlib
import re
from client_provenance import parse_pack_paths


def optional_map_assets(directory: pathlib.Path) -> list[str]:
    manifest = json.loads((directory / 'optional-maps.json').read_text())
    entry = manifest.get('football', {})
    filename = entry.get('file', '')
    if not isinstance(filename, str) or not re.fullmatch(r'map-football-[0-9a-f]{16}\.pck', filename):
        raise RuntimeError('Stadium manifest contains an invalid pack filename')
    path = directory / filename
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != entry.get('sha256') or filename != f'map-football-{digest[:16]}.pck' or path.stat().st_size != entry.get('bytes'):
        raise RuntimeError('Stadium download hash or size does not match its manifest')
    paths = parse_pack_paths(path)
    required = {'assets/maps/football.glb.import', 'assets/maps/football_0.png.import',
                'assets/maps/football_backfaces.res', 'assets/maps/Football-LICENSE.txt'}
    if not required.issubset(paths) or not any(p.startswith('.godot/imported/football.glb-') and p.endswith('.scn') for p in paths) or not any(p.startswith('.godot/imported/football_0.png-') and p.endswith('.ctex') for p in paths):
        raise RuntimeError('Stadium pack is missing its scene, texture, collision surface or license')
    uids = entry.get('uids', {})
    if not isinstance(uids, dict) or set(uids.values()) != {'res://assets/maps/football.glb', 'res://assets/maps/football_0.png'}:
        raise RuntimeError('Stadium manifest is missing resource UID mappings')
    return ['optional-maps.json', filename]
