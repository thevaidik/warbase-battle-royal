import unittest
from map_integrity_gate import MAPS, verify_map_pack

class MapPackTests(unittest.TestCase):
    def setUp(self):
        self.paths={f'assets/data/maps/{name}.json.gz' for name in MAPS}
        self.paths.update(f'assets/ui/maps/{name}.png.import' for name in MAPS)
        self.paths.update(f'.godot/imported/{name}.png-hash.ctex' for name in MAPS)
        for drone in ['vanguard.glb', 'raider.glb']:
            self.paths.add('assets/drones/' + drone + '.import')
            self.paths.add('.godot/imported/' + drone + '-hash.scn')
        for name in ['low_poly_industrial_zone.glb','village_lowres.glb',
                     'fps_shooter_game_arena_map_v3.glb']:
            self.paths.add('assets/maps/'+name+'.import')
            self.paths.add('.godot/imported/'+name+'-hash.scn')
    def test_removed_loft_assets_cannot_ship(self):
        self.paths.add('assets/maps/loft_17.glb.import')
        with self.assertRaisesRegex(RuntimeError, 'Loft 17'):
            verify_map_pack(self.paths, include_football=False)
    def test_missing_scene_cannot_ship_with_its_collision(self):
        self.paths.remove('.godot/imported/village_lowres.glb-hash.scn')
        with self.assertRaisesRegex(RuntimeError,'imported scene for village'):
            verify_map_pack(self.paths,include_football=False)
    def test_native_requires_stadium_but_web_uses_optional_pack(self):
        verify_map_pack(self.paths,include_football=False)
        with self.assertRaisesRegex(RuntimeError,'football.glb'):
            verify_map_pack(self.paths,include_football=True)
    def test_preview_import_without_texture_is_rejected(self):
        self.paths.remove('.godot/imported/canyon.png-hash.ctex')
        with self.assertRaisesRegex(RuntimeError,'preview texture for canyon'):
            verify_map_pack(self.paths,include_football=False)
    def test_missing_preview_is_rejected(self):
        self.paths.remove('assets/ui/maps/canyon.png.import')
        with self.assertRaisesRegex(RuntimeError,'canyon.png.import'):
            verify_map_pack(self.paths,include_football=False)

if __name__=='__main__':unittest.main()
