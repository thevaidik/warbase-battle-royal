"""Restore authoring inputs from the local source archive before baking original maps."""
from pathlib import Path
import shutil
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'asset_backups/unused_map_sources'
TARGET=ROOT/'warbase-godot/client/assets/maps'
PREFIXES=('dust2','nuketown','military_base','devils_canyon','bld_ghost_city')
if not SOURCE.is_dir():raise SystemExit('Original map source archive is unavailable; baked runtime scenes remain usable.')
count=0
for path in SOURCE.iterdir():
    if path.is_file() and path.name.lower().startswith(PREFIXES) and not any(s in path.name for s in ('.obj','.mtl')):
        shutil.copy2(path,TARGET/path.name);count+=1
print(f'Restored {count} original map authoring inputs. Import with Godot before baking.')
