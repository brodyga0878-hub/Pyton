"""Focused controls for original DOS system-information resource extraction."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools import extract_system_information as source


class SystemInformationExtractionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.resource = json.loads((ROOT / "data/ffe_system_information.json").read_text())
        cls.metadata = json.loads((ROOT / "data/ffe_system_metadata.json").read_text())
        cls.exe_path = Path("/workspace/ffe-original/FIRSTENC.EXE")
        cls.asm_path = Path("/workspace/ffe-upstream/jjffe/ffe.asm")
        cls.data_path = Path("/workspace/ffe-upstream/jjffe/ffedat.asm")

    def require_originals(self):
        if not all(p.is_file() for p in [self.exe_path, self.asm_path, self.data_path]):
            self.skipTest("Original pinned DOS/JJFFE files are required for byte-level re-extraction")

    def test_reextraction_is_deterministic_and_preserves_inputs(self):
        self.require_originals()
        old = json.dumps(self.metadata, sort_keys=True)
        extracted = source.extract(self.exe_path.read_bytes(), self.asm_path.read_bytes(), self.data_path.read_bytes(), self.metadata)
        self.assertEqual(extracted, self.resource)
        self.assertEqual(json.dumps(self.metadata, sort_keys=True), old)

    def test_modified_source_executable_is_rejected(self):
        self.require_originals()
        executable = bytearray(self.exe_path.read_bytes()); executable[0] ^= 1
        with self.assertRaisesRegex(ValueError, "SHA256 mismatch"):
            source.extract(bytes(executable), self.asm_path.read_bytes(), self.data_path.read_bytes(), self.metadata)

    def test_exact_text_graph_labels_and_ff_domains(self):
        expected = set(range(6830, 7104)) | set(range(7139, 7183)) | set(range(6216, 6254)) | {7653, 7654}
        self.assertEqual(set(map(int, self.resource["strings"])), expected)
        self.assertEqual(len(expected), 358)
        lookup = self.resource["ff_code_to_label"]
        for start, first, count in [(0x8401, 6830, 267), (0x8000, 7139, 44), (0x8E00, 6216, 38)]:
            for index in range(count):
                self.assertEqual(lookup[str(start + index)], str(first + index))
        self.assertEqual(len(lookup), 349)
        self.assertNotIn(str(0x85FF), lookup)  # Dynamic name expansion is not an invented literal.

    def test_every_string_is_exact_original_executable_bytes(self):
        self.require_originals()
        executable = self.exe_path.read_bytes()
        self.assertEqual(hashlib.sha256(executable).hexdigest(), source.EXE_SHA)
        for label, row in self.resource["strings"].items():
            with self.subTest(label=label):
                raw = bytes.fromhex(row["hex"])
                self.assertEqual(source.cstring(raw), raw)
                self.assertEqual(row["byte_length"], len(raw))
                self.assertEqual(row["sha256"], hashlib.sha256(raw).hexdigest())
                offset = row["executable_offset"]
                self.assertEqual(executable[offset:offset + len(raw)], raw)

    def test_long_descriptions_stop_before_constructor_names(self):
        rows = self.resource["strings"]
        raw = b"".join(bytes.fromhex(rows[str(label)]["hex"]) for label in range(7139, 7183))
        expected_blank = list(range(0x8000, 0x8008)) + [0x8009, 0x800B, 0x8011, 0x8017, 0x801F, 0x8020, 0x8022] + list(range(0x8028, 0x802C))
        blank = [0x8000 + label - 7139 for label in range(7139, 7183) if rows[str(label)]["hex"] == "2000"]
        self.assertEqual(blank, expected_blank)
        self.assertEqual((len(blank), 44 - len(blank)), (19, 25))
        self.assertEqual(len(raw), 6333)
        self.assertEqual(hashlib.sha256(raw).hexdigest(), "7a8eb24a707f5feabe1a99cc0cda5a96e934d33b6ba01e2dd6471bf64144b8c6")
        self.assertEqual(rows["7182"]["hex"], "2000")
        self.assertEqual(rows["7182"]["ignored_label_tail_bytes"], 1373)
        self.assertEqual(rows["7103"]["ignored_label_tail_bytes"], 3)

    def test_all_three_original_pointer_tables_are_preserved(self):
        self.require_originals()
        executable = self.exe_path.read_bytes()
        independent = {"system": (829684, 267, "6874228a62753e0ec76e3c4a478b5541e20a43092b42186cad5852c303b0b5b9"),
                       "long": (873780, 44, "aa3a86597dd4d2c6347b9312219ba17030fa89ec61193785cd0c4d495fa18206"),
                       "commodity": (817472, 38, "0b732869f8e04448fb016c5810768ee3275318242274ff74fe57038c8367ab85")}
        for name, (offset, count, expected_sha) in independent.items():
            table = self.resource["pointer_tables"][name]
            raw = executable[offset:offset + count * 4]
            self.assertEqual(hashlib.sha256(raw).hexdigest(), expected_sha)
            self.assertEqual(table["executable_offset"], offset)
            self.assertEqual(list(struct.unpack(f"<{count}I", raw)), table["dos_pointer_u32"])
            for pointer, label in zip(table["dos_pointer_u32"], table["labels"]):
                self.assertEqual(pointer - 0x416400, self.resource["strings"][str(label)]["executable_offset"])

    def test_dos_policy_rows_and_jjffe_insertion_remain_distinct(self):
        resource = self.resource
        dos = bytes.fromhex(resource["dos_metadata_hex"])
        jjffe = bytes.fromhex(resource["metadata_variants"]["jjffe_hex"])
        self.assertEqual(dos.hex(), self.metadata["dos_metadata_hex"])
        self.assertEqual(jjffe.hex(), self.metadata["metadata_hex"])
        self.assertEqual((len(dos), len(jjffe)), (18268, 18808))
        self.assertEqual(resource["dos_record_rows"], 338)
        self.assertEqual(resource["dos_handcoded_count"], 329)
        self.assertEqual(resource["dos_scan_rows"], 330)
        self.assertEqual(dos[18198:18252], bytes(54))
        ids = [struct.unpack_from("<I", dos, 432 + index * 54)[0] for index in range(330)]
        self.assertTrue(all(ids[:-1])); self.assertEqual(ids[-1], 0)
        self.assertEqual(list(struct.unpack("<4I", dos[18252:])), resource["source_exception_ids"])
        self.assertEqual(jjffe, dos[:18198] + bytes.fromhex(resource["metadata_variants"]["jjffe_inserted_bytes_hex"]) + dos[18198:])

    def test_market_uses_only_original_thirty_three_slots(self):
        categories = self.resource["categories"]
        self.assertEqual(categories["trade_commodities"]["ff_codes"], list(range(0x8E00, 0x8E21)))
        self.assertEqual(categories["extra_mission_items"]["ff_codes"], list(range(0x8E21, 0x8E26)))
        self.assertEqual(bytes.fromhex(self.resource["strings"]["6248"]["hex"]), b"Chaff\0")
        self.assertEqual(bytes.fromhex(self.resource["strings"]["6249"]["hex"]), b"Jjagged Bbanner Card\0")

    def test_original_control_and_unknown_glyph_bytes_are_not_guessed(self):
        graph = self.resource["dependency_graph"]
        self.assertEqual(graph["unresolved_ff_references"], [])
        self.assertEqual(graph["extended_glyphs"], [{"data_label": 7167, "offset": 94, "byte": 0x83}])
        self.assertEqual(bytes.fromhex(self.resource["strings"]["7167"]["hex"])[94], 0x83)
        self.assertEqual(graph["source_ff30_dispatch"][str(0x3003)], "FUNC_001374_FF30WriteIntV3")
        self.assertEqual(graph["source_ff30_dispatch"][str(0x301F)], "FUNC_001371_FF30WriteTonsV1")
        unknown = source.text_controls(b"A\xff\xde\xadB\0")
        self.assertEqual(unknown["ff_refs"], [0xDEAD])
        self.assertIn("report unsupported", graph["unsupported_policy"])

    def test_source_parser_preserves_quoted_comments_commas_and_zero_operands(self):
        block = source.Block(1, 1, "db 'x;y,z', 0x83, 0x0 ; outside comment\n")
        self.assertEqual(source.db_bytes(block), b"x;y,z\x83\0")
        raw = b"A\xfe\x00\x02B\xfd\x00C\xff\x84\x00D\0tail"
        self.assertEqual(source.cstring(raw), raw[:-4])
        self.assertEqual(source.text_controls(source.cstring(raw))["ff_refs"], [0x8400])
        with self.assertRaisesRegex(ValueError, "pure db"):
            source.db_bytes(source.Block(2, 2, "dd FUNC_000895\n"))
        with self.assertRaises(ValueError):
            source.cstring(b"unfinished\xff")

    def test_page_contracts_distinguish_demographics_from_world_population(self):
        pages = self.resource["page_contracts"]
        self.assertEqual(pages["F895"]["index_bias"], 0)
        self.assertEqual((pages["F843"]["demographics_action"], pages["F843"]["trade_action"], pages["F843"]["overview_action"]), (0xFA, 0xF9, 0xFF))
        self.assertIn("record+4", pages["F843"]["population"])
        self.assertIn("not F869 byte(record+5)", pages["F843"]["population"])
        self.assertEqual(pages["F842"]["unknown_ff"], 0x84B3)


if __name__ == "__main__":
    unittest.main()
