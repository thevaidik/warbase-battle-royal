import hashlib
import json
import pathlib
import tempfile
import unittest
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from client_provenance import artifact_records, client_fingerprint, make_provenance, read_provenance, verify_artifacts, verify_current_export


class ClientProvenanceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.client = pathlib.Path(self.temp.name) / "client"
        self.client.mkdir()
        (self.client / "Main.gd").write_text("initial")

    def tearDown(self):
        self.temp.cleanup()

    def test_relevant_source_change_makes_export_stale(self):
        provenance = make_provenance(self.client, "4.7.1", "0.18.7")
        (self.client / "Main.gd").write_text("changed")
        with self.assertRaisesRegex(RuntimeError, "Stale client export"):
            verify_current_export(provenance, self.client)

    def test_generated_exports_do_not_change_source_fingerprint(self):
        before = client_fingerprint(self.client)
        generated = self.client / "candidate-web-dist"
        generated.mkdir()
        (generated / "index.pck").write_bytes(b"export")
        self.assertEqual(before, client_fingerprint(self.client))

    def test_provenance_round_trips_versions_and_fingerprint(self):
        provenance = make_provenance(self.client, "4.7.1", "0.18.7")
        (self.client / "index.pck").write_bytes(b"pck bytes")
        provenance["artifacts"] = artifact_records(self.client, ["index.pck"])
        path = self.client / "client-provenance.json"
        path.write_text(json.dumps(provenance))
        self.assertEqual(provenance, read_provenance(path))

    def test_swapped_export_artifact_fails_provenance_check(self):
        pck = self.client / "index.pck"
        pck.write_bytes(b"expected export")
        provenance = make_provenance(self.client, "4.7.1", "0.18.7")
        provenance["artifacts"] = artifact_records(self.client, ["index.pck"])
        pck.write_bytes(b"swapped older export")
        with self.assertRaisesRegex(RuntimeError, "does not match its provenance: index.pck"):
            verify_artifacts(provenance, self.client, ["index.pck"])

    def test_source_patch_identity_is_preserved_in_export_provenance(self):
        sdk = self.client / "addons/colyseus"
        sdk.mkdir(parents=True)
        script = b"verified wrapper patch"
        (sdk / "colyseus.gd").write_bytes(script)
        (sdk / "LOCAL_PATCH.json").write_text(json.dumps({"sdkVersion":"0.18.9", "patchId":"room-lifetime-v1", "sourceSha256":hashlib.sha256(script).hexdigest()}))
        provenance = make_provenance(self.client, "4.7.2", "0.18.9")
        self.assertTrue(provenance["colyseusSdkSourcePatch"].startswith("room-lifetime-v1:"))
        provenance["artifacts"] = {}
        path = self.client / "provenance.json"
        path.write_text(json.dumps(provenance))
        self.assertEqual(provenance, read_provenance(path))
        (sdk / "colyseus.gd").write_bytes(b"unexpected wrapper change")
        with self.assertRaisesRegex(RuntimeError, "patch manifest does not match"):
            make_provenance(self.client, "4.7.2", "0.18.9")


if __name__ == "__main__":
    unittest.main()
