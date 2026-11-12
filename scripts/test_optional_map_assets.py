import hashlib
import json
import pathlib
import tempfile
import unittest
from unittest.mock import patch
from optional_map_assets import optional_map_assets

class OptionalMapAssetsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        data = b'fake pack for manifest validation'
        digest = hashlib.sha256(data).hexdigest()
        self.filename = f'map-football-{digest[:16]}.pck'
        (self.root / self.filename).write_bytes(data)
        self.entry = {'file': self.filename, 'sha256': digest, 'bytes': len(data), 'uids': {
            'uid://scene': 'res://assets/maps/football.glb', 'uid://texture': 'res://assets/maps/football_0.png'}}
        self.paths = {'assets/maps/football.glb.import', 'assets/maps/football_0.png.import',
            'assets/maps/football_backfaces.res', 'assets/maps/Football-LICENSE.txt',
            '.godot/imported/football.glb-hash.scn', '.godot/imported/football_0.png-hash.ctex'}
    def write(self):
        (self.root / 'optional-maps.json').write_text(json.dumps({'football': self.entry}))
    def test_missing_manifest_blocks_packaging(self):
        with self.assertRaises(FileNotFoundError): optional_map_assets(self.root, ('football',))
    def test_missing_download_blocks_packaging(self):
        self.write()
        (self.root / self.filename).unlink()
        with self.assertRaises(FileNotFoundError): optional_map_assets(self.root, ('football',))
    def test_modified_pack_is_rejected(self):
        self.write()
        (self.root / self.filename).write_bytes(b'corrupt')
        with self.assertRaisesRegex(RuntimeError, 'hash or size'): optional_map_assets(self.root, ('football',))
    def test_unsafe_filename_is_rejected(self):
        self.entry['file'] = '../football.pck'
        self.write()
        with self.assertRaisesRegex(RuntimeError, 'filename'): optional_map_assets(self.root, ('football',))
    def test_missing_imported_scene_is_rejected(self):
        self.write()
        self.paths.remove('.godot/imported/football.glb-hash.scn')
        with patch('optional_map_assets.parse_pack_paths', return_value=self.paths):
            with self.assertRaisesRegex(RuntimeError, 'missing its scene'): optional_map_assets(self.root, ('football',))
    def test_valid_downloads_are_included_in_release(self):
        self.write()
        with patch('optional_map_assets.parse_pack_paths', return_value=self.paths):
            self.assertEqual(optional_map_assets(self.root, ('football',)), ['optional-maps.json', self.filename])

if __name__ == '__main__': unittest.main()
