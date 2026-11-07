"""Information APK verifier rejection controls with an explicit mock archive.

These are neither a signed APK nor original-code semantic controls. Actual
export/signature and independent native fixtures are checked separately.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

PROJECT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('information_android_verifier',PROJECT/'tools/verify_rebuilt_android.py')
verifier=importlib.util.module_from_spec(spec);spec.loader.exec_module(verifier)


class MockInformationArchive:
    def __init__(self):
        self.entries={f'assets/scripts/{name}.gdc':b'GDSC'+b'explicit-unit-mock-not-an-APK'*5
                      for name in ('galactic_map_view',*verifier.SYSTEM_INFORMATION_MODULES)}
        self.entries.update({f'assets/data/{name}.json':(PROJECT/'data'/f'{name}.json').read_bytes()
                             for name in verifier.SYSTEM_INFORMATION_TABLES})
    def namelist(self):return list(self.entries)
    def read(self,name):return self.entries[name]


class InformationPackaging(unittest.TestCase):
    def setUp(self):self.archive=MockInformationArchive()

    def project_copy(self,directory):
        project=Path(directory)
        files=set(verifier.MAP_VISUAL_PROTECTED_SOURCE_SHA256)
        files.update(['scripts/main.gd','scripts/celestial_renderer.gd','scripts/galactic_map_view.gd','scripts/system_map_view.gd'])
        files.update(f'scripts/{name}.gd' for name in verifier.SYSTEM_INFORMATION_MODULES)
        files.update(f'data/{name}.json' for name in verifier.SYSTEM_INFORMATION_TABLES)
        for name in files:
            target=project/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((PROJECT/name).read_bytes())
        return project

    def mutate_resource(self,project,name,callback):
        path=project/'data'/f'{name}.json';value=json.loads(path.read_text());callback(value)
        raw=json.dumps(value,ensure_ascii=False).encode();path.write_bytes(raw)
        self.archive.entries[f'assets/data/{name}.json']=raw

    def test_current_information_scope_and_original_boundaries(self):
        result=verifier.verify_system_information_runtime(self.archive,PROJECT)
        self.assertEqual(result['baseline_source_commit'],'606775527498662697ae9eedba152898adabfe40')
        self.assertEqual(result['compiled_module_count'],3)
        self.assertEqual(result['protected_main_function_count'],28)
        self.assertEqual((result['source_strings'],result['ff_lookups']),(358,349))
        self.assertEqual((result['long_nonblank_descriptions'],result['long_blank_descriptions']),(25,19))
        self.assertFalse(result['complete_original_text_interpreter'])
        self.assertFalse(result['complete_game_localization'])
        self.assertFalse(result['original_instruction_oracle_executed_by_this_check'])

    def test_each_information_runtime_module_is_required(self):
        for name in verifier.SYSTEM_INFORMATION_MODULES:
            with self.subTest(name=name):
                archive=MockInformationArchive();del archive.entries[f'assets/scripts/{name}.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing system information runtime'):
                    verifier.verify_system_information_runtime(archive,PROJECT)

    def test_invalid_compiled_information_is_rejected(self):
        self.archive.entries['assets/scripts/source_information_text.gdc']=b'NOTGDSC'+b'x'*100
        with self.assertRaisesRegex(AssertionError,'Invalid compiled system information runtime'):
            verifier.verify_system_information_runtime(self.archive,PROJECT)

    def test_each_raw_and_translated_resource_is_required(self):
        for name in verifier.SYSTEM_INFORMATION_TABLES:
            with self.subTest(name=name):
                archive=MockInformationArchive();del archive.entries[f'assets/data/{name}.json']
                with self.assertRaisesRegex(AssertionError,'Missing system information resource'):
                    verifier.verify_system_information_runtime(archive,PROJECT)

    def test_runtime_resource_must_equal_source(self):
        self.archive.entries['assets/data/ffe_system_information.json']+=b' '
        with self.assertRaisesRegex(AssertionError,'resource differs from source'):
            verifier.verify_system_information_runtime(self.archive,PROJECT)

    def test_source_provenance_must_be_original(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_resource(project,'ffe_system_information',lambda data:data.update(source_sha256='0'*64))
            with self.assertRaisesRegex(AssertionError,'Wrong system information source provenance'):
                verifier.verify_system_information_runtime(self.archive,project)

    def test_constructor_tail_cannot_become_a_long_description(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_resource(project,'ffe_system_information',lambda data:data['strings']['7182'].update(hex='2000536f6c00'))
            with self.assertRaisesRegex(AssertionError,'crosses its original C boundary'):
                verifier.verify_system_information_runtime(self.archive,project)

    def test_translation_cannot_lose_source_variable_codes(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_resource(project,'system_information_ru',lambda data:data['strings']['7010'].update(text='Потеряны исходные параметры'))
            with self.assertRaisesRegex(AssertionError,'variable/layout tokens differ'):
                verifier.verify_system_information_runtime(self.archive,project)

    def test_information_cannot_change_simulation_or_save_functions(self):
        for name in ['_tick','_payload','_choose_body','_choose_site','_source_motion_step','_time_context']:
            with self.subTest(name=name),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/'scripts/main.gd';raw=path.read_text()
                function=verifier.source_function(raw,name)
                changed=function.replace('\n','\n\tpass # mutation of protected behavior\n',1)
                path.write_text(raw.replace(function,changed,1))
                with self.assertRaisesRegex(AssertionError,'Information update changed protected Main function'):
                    verifier.verify_system_information_runtime(self.archive,project)

    def test_information_cannot_undo_mercury_stellar_fix(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'scripts/celestial_renderer.gd';path.write_bytes(path.read_bytes()+b'\n')
            with self.assertRaisesRegex(AssertionError,'Mercury stellar-visibility fix'):
                verifier.verify_system_information_runtime(self.archive,project)

    def test_projection_cannot_write_ship_position(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'scripts/main.gd';raw=path.read_text()
            function=verifier.source_function(raw,'_update_flight_projection')
            changed=function.replace('\n','\n\tship.position=Vector3.ZERO\n',1)
            path.write_text(raw.replace(function,changed,1))
            with self.assertRaisesRegex(AssertionError,'protected projection/lifecycle function _update_flight_projection'):
                verifier.verify_system_information_runtime(self.archive,project)

    def test_information_helper_cannot_advance_simulation(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'scripts/main.gd';raw=path.read_text()
            function=verifier.source_function(raw,'_show_information')
            changed=function.replace('\n','\n\t_tick(0.1,Vector2.ZERO,0)\n',1)
            path.write_text(raw.replace(function,changed,1))
            with self.assertRaisesRegex(AssertionError,'audited read-only Main helper _show_information'):
                verifier.verify_system_information_runtime(self.archive,project)

    def test_system_map_cannot_redirect_travel(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'scripts/system_map_view.gd';raw=path.read_text()
            function=verifier.source_function(raw,'_request_travel')
            changed=function.replace('str(target.body_id)', '"star"',1)
            self.assertNotEqual(changed,function)
            path.write_text(raw.replace(function,changed,1))
            with self.assertRaisesRegex(AssertionError,'audited map view scripts/system_map_view.gd'):
                verifier.verify_system_information_runtime(self.archive,project)

    def test_historical_v38_fixture_is_exactly_pinned(self):
        data=json.loads((PROJECT/'tests/fixtures/celestial_visual_v38_sources.json').read_text())
        self.assertEqual(data['source_commit'],verifier.SYSTEM_INFORMATION_BASELINE_SOURCE_COMMIT)
        for value in data['files'].values():self.assertEqual(hashlib.sha256(value['source'].encode()).hexdigest(),value['sha256'])


if __name__=='__main__':unittest.main()
