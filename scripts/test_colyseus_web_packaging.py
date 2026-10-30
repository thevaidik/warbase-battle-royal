import json
import pathlib
import re
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from package_colyseus_web_candidate import (
    SDK_WASM_ASSET,
    SDK_WASM_RUNTIME_PATH,
    configure_gdextension_runtime,
    copy_renamed_assets,
    render_packaged_html,
)


class ColyseusWebPackagingTests(unittest.TestCase):
    def test_loader_preserves_the_original_sdk_basename(self):
        config = {"executable": "index", "mainPack": "index.pck", "gdextensionLibs": [SDK_WASM_ASSET]}
        renames = {"index.js": "engine-aabbccdd.js", "index.pck": "game-aabbccdd.pck", SDK_WASM_ASSET: SDK_WASM_ASSET}
        configure_gdextension_runtime(config, renames)

        self.assertEqual(config["gdextensionLibs"], [SDK_WASM_RUNTIME_PATH])
        self.assertEqual(renames[SDK_WASM_ASSET], SDK_WASM_RUNTIME_PATH)
        self.assertEqual(SDK_WASM_RUNTIME_PATH, SDK_WASM_ASSET)

    def test_html_uses_sdk_basename_once_and_preserves_other_hashed_names(self):
        html = '<script src="index.js"></script><script>const GODOT_CONFIG = {"executable":"index","mainPack":"index.pck","fileSizes":{"index.pck":10},"gdextensionLibs":["libcolyseus_godot.web.wasm32.release.wasm"]};</script>'
        match = re.search(r"const GODOT_CONFIG = (\{.*?\});", html, re.S)
        config = json.loads(match.group(1))
        renames = {"index.js": "engine-aabbccdd.js", "index.pck": "game-aabbccdd.pck", SDK_WASM_ASSET: SDK_WASM_ASSET}
        configure_gdextension_runtime(config, renames)
        rendered = render_packaged_html(html, config, match, renames)
        new_config = json.loads(re.search(r"const GODOT_CONFIG = (\{.*?\});", rendered, re.S).group(1))

        self.assertEqual(new_config["gdextensionLibs"], [SDK_WASM_RUNTIME_PATH])
        self.assertEqual(rendered.count(SDK_WASM_RUNTIME_PATH), 1)
        self.assertIn('src="engine-aabbccdd.js"', rendered)
        self.assertEqual(new_config["mainPack"], "game-aabbccdd.pck")

    def test_packager_copies_sdk_to_preload_basename(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            source, output = root / "source", root / "output"
            source.mkdir()
            (source / SDK_WASM_ASSET).write_bytes(b"external sdk wasm")
            copy_renamed_assets(source, output, {SDK_WASM_ASSET: SDK_WASM_RUNTIME_PATH})

            self.assertEqual((output / SDK_WASM_RUNTIME_PATH).read_bytes(), b"external sdk wasm")


if __name__ == "__main__":
    unittest.main()
