"""Strict source byte grammar and reproducibility of the original asset graph."""
import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import extract_world_models as extractor


class WorldModelAssets(unittest.TestCase):
    def test_reachable_commands_preserve_boundaries(self):
        # An end command terminates its path even when unrelated allocated
        # bytes follow it; a conditional branch explores both real targets.
        self.assertEqual([r["offset"] for r in extractor.decode(b"\0\0\x10\0")], [0])
        blob = struct.pack("<4H", (1 << 5) | 20, 0, 0, 0)
        rows = extractor.decode(blob)
        self.assertEqual([r["offset"] for r in rows], [0, 4, 6])
        self.assertEqual(rows[0]["jump_target"], 6)

    def test_malformed_and_unknown_commands_stop(self):
        for blob in [b"\x10\0", b"\x03\0\0\0", struct.pack("<3H", 5, 0, 3 << 8),
                     struct.pack("<2H", (1023 << 5) | 20, 0)]:
            with self.subTest(blob=blob.hex()), self.assertRaises(ValueError):
                extractor.decode(blob)

    def test_embedded_graph_is_bounded_and_hashed(self):
        data = json.loads((ROOT / "data/ffe_world_models.json").read_text())
        self.assertEqual(data["source_sha256"], "d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72")
        self.assertEqual(data["roots"], list(range(72, 91)))
        self.assertEqual(len(data["models"]), 150)
        for key, model in data["models"].items():
            with self.subTest(model=key):
                mesh = bytes.fromhex(model["mesh_hex"])
                self.assertEqual(hashlib.sha256(mesh).hexdigest(), model["mesh_sha256"])
                self.assertEqual(extractor.decode(mesh), model["commands"])
                self.assertEqual(len(bytes.fromhex(model["vertex_hex"])), model["vertex_count"] * 3)
                offsets = {r["offset"] for r in model["commands"]}
                for command in model["commands"]:
                    if "jump_target" in command:
                        self.assertIn(command["jump_target"], offsets)
                for child in model["submodels"]:
                    self.assertIn(str(child), data["models"])

    def test_original_archive_rebuild(self):
        executable = ROOT.parent / "scratch/ffe-analysis/files/FIRSTENC/FIRSTENC.EXE"
        if not executable.exists():
            self.skipTest("Uploaded original archive is not present in this checkout")
        expected = json.loads((ROOT / "data/ffe_world_models.json").read_text())
        # JSON object keys (opcode counters) are strings after serialization.
        actual = json.loads(json.dumps(extractor.extract(executable)))
        self.assertEqual(actual, expected)


if __name__ == "__main__":
    unittest.main()
