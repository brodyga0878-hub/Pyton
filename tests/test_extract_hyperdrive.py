"""Exact DOS byte controls for tables, model pointers and explicit adapters.

These are extraction controls; independent native F902/F903 arithmetic is a
separate fixture. No claim of whole-game or outfitting-economy parity.
"""
import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / "tools"))
import extract_hyperdrive as extractor

EXE = Path("/workspace/ffe-original/FIRSTENC.EXE")
SOURCE = Path("/workspace/ffe-upstream/jjffe")
PINNED_TABLES = {
    "drive_records": (884260, 240, "82659f368ab7b4298735b16b4f76276207a19d1b529526c4452c2c78569fe654"),
    "installed_drive_masses": (886300, 60, "46acd9e04a1ddee59a46da2a5b51cf6f7db9e2c4b1caf40027ed61275914965d"),
    "npc_drive_masses": (822064, 56, "5fb0927aed0329629fdaba6b0b8c4d5b76a640928b7abf359ccacabaed7180d4"),
    "npc_hyperfuel": (822120, 60, "2f1f1292c9a0abcd45beccffbf72cdc94267ced52c980576fa0b9e5c06176bc0"),
    "npc_jetfuel": (822396, 60, "6fd21579d4bf35590dee289b2a1cbe12f1bc4e0d10a9ee71d56efea80cac21cb"),
    "equipment_records": (792180, 1452, "e92bfe6a60c5bd4c98d7c58969d776e836815b655654882155b22b85fe30cbb6"),
}


class HyperdriveExtraction(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads((PROJECT / "data/ffe_hyperdrive.json").read_text())

    def test_exact_fifteen_drive_domain_and_table_digest(self):
        data = self.data
        self.assertEqual(data["schema"], 1)
        self.assertEqual(data["source_sha256"], extractor.EXE_SHA)
        self.assertEqual((data["drive_count"], data["drive_stride_bytes"]), (15, 16))
        self.assertEqual(data["valid_drive_indices"], list(range(15)))
        raw = bytes.fromhex(data["drive_table_hex"])
        self.assertEqual(len(raw), 240)
        self.assertEqual(hashlib.sha256(raw).hexdigest(), PINNED_TABLES["drive_records"][2])
        self.assertEqual(b"".join(bytes.fromhex(row["hex"]) for row in data["drives"]), raw)
        for index, row in enumerate(data["drives"]):
            with self.subTest(index=index):
                self.assertEqual(row["index"], index)
                self.assertEqual(struct.unpack("<4I", bytes.fromhex(row["hex"])),
                                 tuple(row[key] for key in ("coefficient_u32", "correction_u32",
                                                           "capacity_threshold_tonnes_u32", "name_ff_code")))

    def test_installation_mass_does_not_use_f902_capacity_threshold(self):
        drives = self.data["drives"]
        self.assertEqual([r["mass_tonnes_u32"] for r in drives],
                         [0, 4, 10, 25, 45, 80, 150, 250, 400, 600, 6, 12, 24, 36, 0])
        self.assertEqual([drives[i]["capacity_threshold_tonnes_u32"] for i in (2, 3, 4)], [6, 12, 24])
        self.assertEqual([drives[i]["mass_tonnes_u32"] for i in (2, 3, 4)], [10, 25, 45])
        self.assertEqual(drives[13]["correction_u32"], 64443)
        self.assertEqual([row["fuel_commodity_index"] for row in drives], [19] * 10 + [20] * 5)
        for row in drives:
            equipment = row["equipment"]
            if equipment is not None:
                self.assertEqual(struct.unpack_from("<I", bytes.fromhex(equipment["hex"]), 8)[0], row["mass_tonnes_u32"])
                self.assertEqual(bytes.fromhex(equipment["hex"])[18], row["index"])
        self.assertEqual(sum(row["equipment"] is not None for row in drives), 13)

    def test_original_dos_equipment_variant_is_explicit(self):
        table = self.data["tables"]["equipment_records"]
        self.assertFalse(table["dos_matches_jjffe_data"])
        self.assertEqual([(d["byte_offset"], d["dos_byte"], d["jjffe_byte"])
                          for d in table["variant_differences"]],
                         [(1185, 235, 215), (1207, 235, 215), (1229, 235, 215), (1251, 235, 215)])
        self.assertTrue(all(d["record_byte"] == 19 for d in table["variant_differences"]))

    def test_fifty_seven_specs_include_distinct_eagles(self):
        specs = self.data["ship_specs"]
        self.assertEqual(sorted(map(int, specs)), list(range(15, 72)))
        for key, spec in specs.items():
            raw = bytes.fromhex(spec["spec_hex"])
            self.assertEqual(len(raw), 24)
            self.assertEqual(hashlib.sha256(raw).hexdigest(), spec["spec_sha256"])
            self.assertEqual(struct.unpack_from("<hh", raw, 6),
                             (spec["hull_mass_tonnes_s16"], spec["internal_capacity_tonnes_s16"]))
        self.assertEqual((specs["23"]["hull_mass_tonnes_s16"], specs["23"]["internal_capacity_tonnes_s16"]), (25, 20))
        self.assertEqual((specs["24"]["hull_mass_tonnes_s16"], specs["24"]["internal_capacity_tonnes_s16"]), (28, 22))
        self.assertNotEqual(specs["23"]["spec_hex"], specs["24"]["spec_hex"])

    def test_starting_fuel_is_cargo_and_adapters_are_not_original_starters(self):
        profiles = self.data["new_session_profiles"]
        self.assertEqual(set(profiles), {"cobra", "eagle", "shuttle"})
        for ship, expected in {"cobra": (38, 3, 4, 6, True), "eagle": (24, 2, 1, 6, False),
                               "shuttle": (15, 1, 0, 0, False)}.items():
            profile = profiles[ship]
            self.assertEqual(tuple(profile[k] for k in ("source_model_index", "source_drive_index", "hydrogen", "fixed_equipment_space_t", "original_starter")), expected)
            self.assertEqual((profile["military"], profile["waste"]), (0, 0))
        # Source equipment capacity excludes fuel: Cobra free45, adapted Eagle5.
        for ship, free in (("cobra", 45), ("eagle", 5), ("shuttle", 0)):
            p = profiles[ship]
            capacity = self.data["ship_specs"][str(p["source_model_index"])]["internal_capacity_tonnes_s16"]
            self.assertEqual(capacity - self.data["drives"][p["source_drive_index"]]["mass_tonnes_u32"]
                             - p["fixed_equipment_space_t"] - p["hydrogen"], free)
        self.assertEqual(profiles["eagle"]["fitting_reference_model_index"], 23)
        self.assertIsNone(profiles["shuttle"]["source_start_selector"])
        self.assertEqual(self.data["ship_specs"]["15"]["stock_drive_word_u16"], 0x8001)
        self.assertIsNone(profiles["shuttle"]["source_jetfuel_raw_u32"])

    @unittest.skipUnless(EXE.is_file(), "Original uploaded DOS executable is not present")
    def test_all_data_and_instruction_bytes_are_at_the_stated_dos_offsets(self):
        exe = EXE.read_bytes()
        self.assertEqual(hashlib.sha256(exe).hexdigest(), extractor.EXE_SHA)
        for name, (at, count, digest) in PINNED_TABLES.items():
            table = self.data["tables"][name]
            self.assertEqual((table["dos_file_offset"], table["byte_count"], table["sha256"]), (at, count, digest))
            self.assertEqual(exe[at:at + count], bytes.fromhex(table["hex"]))
        for anchor in self.data["dos_instruction_anchors"].values():
            at = anchor["dos_file_offset"]
            self.assertEqual(exe[at:at + anchor["byte_count"]], bytes.fromhex(anchor["hex"]))
        for spec in self.data["ship_specs"].values():
            at = spec["spec_file_offset"]
            self.assertEqual(exe[at:at + 24].hex(), spec["spec_hex"])
            self.assertEqual(struct.unpack_from("<I", exe, spec["descriptor_file_offset"] + 0x38)[0],
                             at + 0x416400)

    @unittest.skipUnless(EXE.is_file() and (SOURCE / "ffedat.asm").is_file(), "Pinned original source is not present")
    def test_reextraction_is_reproducible_and_rejects_wrong_original(self):
        args = [EXE.read_bytes(), (SOURCE / "ffe.asm").read_bytes(),
                (SOURCE / "ffedat.asm").read_bytes(), json.loads((PROJECT / "data/ffe_ship_registry.json").read_text())]
        self.assertEqual(extractor.extract(*args), self.data)
        mutated = bytearray(args[0]); mutated[884260] ^= 1
        with self.assertRaisesRegex(ValueError, "SHA256 mismatch"):
            extractor.extract(bytes(mutated), *args[1:])


if __name__ == "__main__":
    unittest.main()
