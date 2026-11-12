"""Validate on-demand original map artifacts before export or deployment."""
from __future__ import annotations
import hashlib
import json
import pathlib
import re
from client_provenance import parse_pack_paths

RESTORED_MAPS = ('dust2','nuketown','canyon','military_base','ghost_city')
OPTIONAL_MAPS = ('football', *RESTORED_MAPS)


def optional_map_assets(directory: pathlib.Path, required_maps: tuple[str, ...] = OPTIONAL_MAPS) -> list[str]:
    manifest = json.loads((directory / 'optional-maps.json').read_text())
    names = ['optional-maps.json']
    for map_id in required_maps:
        entry = manifest.get(map_id, {})
        filename = entry.get('file', '')
        if not isinstance(filename, str) or not re.fullmatch(r'map-' + re.escape(map_id) + r'-[0-9a-f]{16}\.pck', filename):
            raise RuntimeError(f'{map_id} manifest contains an invalid pack filename')
        path = directory / filename
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != entry.get('sha256') or filename != f'map-{map_id}-{digest[:16]}.pck' or path.stat().st_size != entry.get('bytes'):
            raise RuntimeError(f'{map_id} download hash or size does not match its manifest')
        paths = parse_pack_paths(path)
        root = 'assets/maps/football.glb' if map_id == 'football' else f'assets/maps/restored/{map_id}.scn'
        if entry.get('root', 'res://' + root) != 'res://' + root:
            raise RuntimeError(f'{map_id} download points at the wrong scene')
        if map_id == 'football':
            required = {'assets/maps/football.glb.import','assets/maps/football_0.png.import','assets/maps/football_backfaces.res','assets/maps/Football-LICENSE.txt'}
            complete = required.issubset(paths) and any(p.startswith('.godot/imported/football.glb-') and p.endswith('.scn') for p in paths) and any(p.startswith('.godot/imported/football_0.png-') and p.endswith('.ctex') for p in paths)
        else:
            complete = root in paths
        if not complete:
            raise RuntimeError(f'{map_id} pack is missing its scene, texture, collision surface or license')
        uids = entry.get('uids', {})
        if not isinstance(uids, dict) or (map_id == 'football' and not {'res://assets/maps/football.glb','res://assets/maps/football_0.png'}.issubset(set(uids.values()))):
            raise RuntimeError(f'{map_id} manifest is missing resource UID mappings')
        for resource in uids.values():
            relative = str(resource).removeprefix('res://')
            if relative not in paths and relative + '.import' not in paths:
                raise RuntimeError(f'{map_id} pack omitted UID resource {relative}')
        names.append(filename)
    return names
