"""Run with: STELLAR_SOURCE_CSV=/path/to/hygdata_v41.csv python3 -m unittest discover -s tools -p test_import_stellar_catalog.py"""
import csv
import hashlib
import json
import math
import os
from pathlib import Path
import unittest

import import_stellar_catalog as importer

ROOT = Path(__file__).resolve().parents[1]


class StellarImportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data_bytes = (ROOT / "scripts/stellar_catalog_data.gd").read_bytes()
        cls.rows = [json.loads(line.strip().removesuffix(",")) for line in cls.data_bytes.decode().splitlines() if line.startswith("\t[")]
        cls.by_id = {row[0]: row for row in cls.rows}
        cls.provenance = json.loads((ROOT / "data/stellar_catalog/hyg-v41-provenance.json").read_text())
        source_path = os.environ.get("STELLAR_SOURCE_CSV")
        cls.source = Path(source_path).read_bytes() if source_path else None

    def test_frozen_ids_selection_and_attribution(self):
        self.assertEqual(len(self.rows), 4380)
        self.assertEqual(len(self.by_id), 4380)
        self.assertNotIn(0, self.by_id)
        self.assertEqual([row[0] for row in self.rows], sorted(self.by_id))
        self.assertEqual(self.provenance["nearby_records_le_100_ly"], 4059)
        self.assertEqual(self.provenance["additional_farther_proper_named_records"], 321)
        self.assertEqual(self.provenance["generated_gd_sha256"], hashlib.sha256(self.data_bytes).hexdigest())
        self.assertEqual(self.provenance["license"], "CC-BY-SA-4.0")
        self.assertIn("David Nash", self.provenance["author"])
        self.assertIn("Attribution-ShareAlike 4.0", (ROOT / "data/stellar_catalog/HYG-LICENSE.txt").read_text())

    def test_complete_pinned_source_selection(self):
        if self.source is None:
            self.skipTest("Set STELLAR_SOURCE_CSV for independent whole-source inclusion verification")
        self.assertEqual(hashlib.sha256(self.source).hexdigest(), importer.SOURCE_SHA256)
        original = list(csv.DictReader(self.source.decode().splitlines()))
        wanted = {
            int(row["id"]) for row in original
            if int(row["id"]) != 0 and 0 < float(row["dist"]) < 100000
            and (float(row["dist"]) * importer.PARSEC_TO_LY <= 100 or row["proper"].strip())
        }
        self.assertEqual(set(self.by_id), wanted)
        for row in original:
            ident = int(row["id"])
            if ident in self.by_id:
                self.assertEqual(self.by_id[ident][11], float(row["dist"]))
                self.assertEqual(self.by_id[ident][12], [float(row[c]) for c in ("x", "y", "z")])

    def test_reproducible_output_and_rejected_source_mutation(self):
        if self.source is None:
            self.skipTest("Set STELLAR_SOURCE_CSV to regenerate both outputs")
        outputs = importer.generate(self.source)
        self.assertEqual(outputs["scripts/stellar_catalog_data.gd"], self.data_bytes)
        for path, content in outputs.items():
            self.assertEqual((ROOT / path).read_bytes(), content)
        with self.assertRaisesRegex(ValueError, "pinned HYG"):
            importer.generate(self.source + b"\n")

    def test_independent_star_reference_positions(self):
        # Values independently obtained from pinned HYG xyz and ERFA convention.
        expected = {
            70666: (2.930908150678701, -3.041428224712877, -0.142121980862639),
            71456: (3.093484113973798, -3.015204744003430, -0.051242748661806),
            71453: (3.093241287733961, -3.015449712920790, -0.051449591615050),
            32263: (-5.770230991547391, -6.237896681332887, -1.329189701503214),
        }
        for ident, point in expected.items():
            for actual, reference in zip(self.by_id[ident][13], point):
                self.assertAlmostEqual(actual, reference, delta=2e-8)
        self.assertGreater(self.by_id[70666][13][0], 0)
        self.assertLess(self.by_id[32263][13][0], 0)

    def test_frame_is_right_handed_and_distance_column_is_not_forced(self):
        matrix = importer.ROTATION
        for a in range(3):
            for b in range(3):
                self.assertAlmostEqual(sum(matrix[a][i] * matrix[b][i] for i in range(3)), float(a == b), places=13)
        a, b, c = matrix
        determinant = a[0]*(b[1]*c[2]-b[2]*c[1])-a[1]*(b[0]*c[2]-b[2]*c[0])+a[2]*(b[0]*c[1]-b[1]*c[0])
        self.assertAlmostEqual(determinant, 1.0, places=13)
        row = self.by_id[119395]
        original_norm = math.sqrt(sum(value*value for value in row[12]))
        self.assertGreater(abs(original_norm - row[11]), .01)
        self.assertAlmostEqual(math.sqrt(sum(value*value for value in row[13])), original_norm * importer.PARSEC_TO_LY, places=10)

    def test_record_labels_and_only_source_cross_identified_multiples(self):
        self.assertEqual(len({row[1] for row in self.rows}), len(self.rows))
        self.assertEqual(self.by_id[70666][1], "Проксима Центавра")
        self.assertEqual(self.by_id[32263][1], "Сириус A")
        self.assertEqual(self.by_id[118441][1], "Сириус B")
        self.assertEqual(self.by_id[70666][22], [])
        self.assertIn(71453, self.by_id[71456][22])
        self.assertIn(71456, self.by_id[71453][22])
        for row in self.rows:
            for related in row[22]:
                self.assertEqual(self.by_id[related][21], row[21])
                self.assertEqual(self.by_id[related][20], row[20])
            self.assertTrue(row[1])
            self.assertTrue(0 < row[11] < 100000)
            self.assertTrue(row[11] * importer.PARSEC_TO_LY <= 100 or row[3])
            self.assertTrue(all(math.isfinite(x) for x in row[12] + row[13]))


if __name__ == "__main__":
    unittest.main()
