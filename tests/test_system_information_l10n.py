"""Russian system-information templates checked against original byte strings.

This validates the bounded resource graph, variable/layout codes, dates and
original blank descriptions. It does not validate the whole FFE translation.
"""
from pathlib import Path
import json
import re
import unittest

PROJECT = Path(__file__).resolve().parents[1]
TOKEN = re.compile(r'\{(?:FF[0-9A-F]{4}|FD[0-9A-F]{2}|FE[0-9A-F]{4}|CTRL[0-9A-F]{2})\}|\r')


def source_tokens(raw):
    """Read FF operands before checking ordinary C-string control characters."""
    result = []
    at = 0
    while at < len(raw) - 1:
        value = raw[at]
        if value in (255, 254):
            assert at + 2 < len(raw), 'Truncated FF/FE code'
            result.append('{%s%02X%02X}' % ('FF' if value == 255 else 'FE', raw[at + 1], raw[at + 2]))
            at += 3
        elif value == 253:
            assert at + 1 < len(raw), 'Truncated FD code'
            result.append('{FD%02X}' % raw[at + 1])
            at += 2
        else:
            if value == 13:
                result.append('\r')
            elif value < 32:
                result.append('{CTRL%02X}' % value)
            at += 1
    return result


class SystemInformationLocalization(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = json.loads((PROJECT / 'data/ffe_system_information.json').read_text())
        cls.ru = json.loads((PROJECT / 'data/system_information_ru.json').read_text())

    def test_every_original_resource_string_has_exactly_one_translation(self):
        self.assertEqual(self.ru['schema'], 1)
        self.assertEqual(self.ru['language'], 'ru')
        self.assertEqual(self.ru['source_sha256'], self.source['source_sha256'])
        self.assertEqual(set(self.ru['strings']), set(self.source['strings']))
        self.assertEqual(len(self.ru['strings']), 358)
        self.assertEqual(self.ru['coverage']['total_strings'], 358)
        self.assertFalse(self.ru['coverage']['complete_game_localization'])
        for label, row in self.ru['strings'].items():
            with self.subTest(label=label):
                self.assertEqual(row['source_hex'], self.source['strings'][label]['hex'])
                self.assertIsInstance(row['text'], str)
                self.assertNotIn('\x00', row['text'])

    def test_all_source_variables_layout_codes_and_line_breaks_are_preserved(self):
        for label, row in self.ru['strings'].items():
            with self.subTest(label=label):
                raw = bytes.fromhex(row['source_hex'])
                self.assertEqual(TOKEN.findall(row['text']), source_tokens(raw))
                english = raw[:-1].decode('latin1')
                self.assertEqual(re.findall(r'%[si]', row['text']), re.findall(r'%[si]', english))

    def test_long_description_c_string_boundaries_preserve_nineteen_blanks(self):
        blanks = []
        narratives = []
        for label in range(7139, 7183):
            row = self.ru['strings'][str(label)]
            raw = bytes.fromhex(row['source_hex'])
            if raw == b' \0':
                blanks.append(label)
                self.assertEqual(row['text'], ' ')
                self.assertEqual(row['translation_policy'], 'original_blank')
            else:
                narratives.append(label)
                self.assertRegex(row['text'], '[А-Яа-яЁё]')
        self.assertEqual(len(blanks), 19)
        self.assertEqual(len(narratives), 25)
        self.assertEqual(self.ru['strings']['7182']['source_hex'], '2000')
        self.assertEqual(self.ru['strings']['7182']['text'], ' ')
        self.assertEqual(self.ru['coverage']['long_nonblank_descriptions'], 25)
        self.assertEqual(self.ru['coverage']['long_original_blank_descriptions'], 19)

    def test_narrative_years_and_planet_designators_remain_source_values(self):
        for label in range(7139, 7183):
            row = self.ru['strings'][str(label)]
            english = bytes.fromhex(row['source_hex'])[:-1].decode('latin1')
            with self.subTest(label=label):
                # Russian grammar may move a date before its place name.
                self.assertCountEqual(re.findall(r'\d+[a-d]?', row['text']), re.findall(r'\d+[a-d]?', english))

    def test_all_categories_commodities_and_types_have_russian_text(self):
        labels = [*range(6216, 6254), *range(6947, 7097), 7653, 7654]
        for label in labels:
            with self.subTest(label=label):
                text = self.ru['strings'][str(label)]['text']
                if label in (7050, 7051):
                    # These two population ranges contain only numbers in FFE.
                    self.assertRegex(text, r'^\d[\d ]*–\d[\d ]*$')
                else:
                    self.assertRegex(text, '[А-Яа-яЁё]')
        for key in ['general', 'demography', 'trade', 'body', 'major_imports', 'minor_imports',
                    'major_exports', 'minor_exports', 'illegal_goods', 'unsupported', 'unknown']:
            self.assertRegex(self.ru['ui'][key], '[А-Яа-яЁё]')

    def test_demographic_and_body_templates_keep_exact_source_operand_ids(self):
        self.assertEqual(TOKEN.findall(self.ru['strings']['7010']['text']),
                         ['{FD41}', '{FF3018}', '\r', '{FD41}', '{FF3019}', '\r',
                          '{FD41}', '{FF301A}', '\r', '{FD41}', '{FF301B}'])
        self.assertEqual(TOKEN.findall(self.ru['strings']['6990']['text']),
                         ['{FD29}', '{FF3008}', '\r', '{FF3001}', '\r'])
        self.assertEqual(self.ru['strings']['6252']['text'], 'Предмет задания 2')
        self.assertEqual(self.ru['strings']['6253']['text'], 'Предмет задания 3')

    def test_runtime_information_ui_consumers_have_russian_labels(self):
        source = (PROJECT / 'scripts/source_system_information.gd').read_text()
        keys = set(re.findall(r'Text\.ui\("([^\"]+)"', source))
        self.assertTrue({'ground_port', 'parent', 'no_entries'}.issubset(keys))
        for key in keys:
            with self.subTest(key=key):
                self.assertIn(key, self.ru['ui'])
                self.assertRegex(self.ru['ui'][key], '[А-Яа-яЁё]')


if __name__ == '__main__':
    unittest.main()
