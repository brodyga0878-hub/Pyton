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

HISTORICAL_SOURCE_COMMIT='860951235548fc58c859d7337b9a6909fd78ca62'
HISTORICAL_SOURCE_SHA256={
    'scripts/main.gd':'c83a666e1de2c6ce23b29247ad3c8fab007a0f325ecf2288523bfc8abad3a9de',
    'scripts/navigation.gd':'aee7aeffccd200290c435cabf708c0e4ec5dc852fbae30f85b2bedce1c2a6b80',
    'scripts/galactic_map_model.gd':'bb2f52814aae33d1d7fa000931e369f8c4d1cb0de1364939f9b363e496399b02',
    'scripts/galactic_map_view.gd':'2b725d1ecfda0f66e2d56872dd20c737dc73f904eee1a4fe490a2d93bbd9a33f',
}


def information_project_files():
    files=set(verifier.MAP_VISUAL_PROTECTED_SOURCE_SHA256)
    files.update(['scripts/main.gd','scripts/celestial_renderer.gd','scripts/galactic_map_view.gd','scripts/system_map_view.gd'])
    files.update(f'scripts/{name}.gd' for name in verifier.SYSTEM_INFORMATION_MODULES)
    files.update(f'data/{name}.json' for name in verifier.SYSTEM_INFORMATION_TABLES)
    return files


class MockInformationArchive:
    def __init__(self,project):
        self.entries={f'assets/scripts/{name}.gdc':b'GDSC'+b'explicit-unit-mock-not-an-APK'*5
                      for name in ('galactic_map_view',*verifier.SYSTEM_INFORMATION_MODULES)}
        self.entries.update({f'assets/data/{name}.json':(project/'data'/f'{name}.json').read_bytes()
                             for name in verifier.SYSTEM_INFORMATION_TABLES})
    def namelist(self):return list(self.entries)
    def read(self,name):return self.entries[name]


class InformationPackaging(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        # Code39 keeps its audited Main/navigation/map contracts after code40
        # changes their live consumers. Information resources and other inputs
        # remain the frozen project files; only these four sources are overlaid.
        directory=tempfile.TemporaryDirectory(prefix='information-packaging-v39-')
        cls.addClassCleanup(directory.cleanup)
        cls.project=Path(directory.name)
        for name in information_project_files():
            target=cls.project/name;target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes((PROJECT/name).read_bytes())
        baseline=json.loads((PROJECT/'tests/fixtures/hyperdrive_v39_sources.json').read_text())
        if baseline['source_commit']!=HISTORICAL_SOURCE_COMMIT or set(baseline['files'])!=set(HISTORICAL_SOURCE_SHA256):
            raise AssertionError('Historical information packaging source fixture changed')
        for name,expected in HISTORICAL_SOURCE_SHA256.items():
            entry=baseline['files'][name];raw=entry['source'].encode()
            if entry['sha256']!=expected or hashlib.sha256(raw).hexdigest()!=expected:
                raise AssertionError('Historical information packaging source differs: '+name)
            (cls.project/name).write_bytes(raw)

    def setUp(self):self.archive=MockInformationArchive(self.project)

    def project_copy(self,directory):
        project=Path(directory)
        for name in information_project_files():
            target=project/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((self.project/name).read_bytes())
        return project

    def mutate_resource(self,project,name,callback):
        path=project/'data'/f'{name}.json';value=json.loads(path.read_text());callback(value)
        raw=json.dumps(value,ensure_ascii=False).encode();path.write_bytes(raw)
        self.archive.entries[f'assets/data/{name}.json']=raw

    def test_current_information_scope_and_original_boundaries(self):
        result=verifier.verify_system_information_runtime(self.archive,self.project)
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
                archive=MockInformationArchive(self.project);del archive.entries[f'assets/scripts/{name}.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing system information runtime'):
                    verifier.verify_system_information_runtime(archive,self.project)

    def test_invalid_compiled_information_is_rejected(self):
        self.archive.entries['assets/scripts/source_information_text.gdc']=b'NOTGDSC'+b'x'*100
        with self.assertRaisesRegex(AssertionError,'Invalid compiled system information runtime'):
            verifier.verify_system_information_runtime(self.archive,self.project)

    def test_each_raw_and_translated_resource_is_required(self):
        for name in verifier.SYSTEM_INFORMATION_TABLES:
            with self.subTest(name=name):
                archive=MockInformationArchive(self.project);del archive.entries[f'assets/data/{name}.json']
                with self.assertRaisesRegex(AssertionError,'Missing system information resource'):
                    verifier.verify_system_information_runtime(archive,self.project)

    def test_runtime_resource_must_equal_source(self):
        self.archive.entries['assets/data/ffe_system_information.json']+=b' '
        with self.assertRaisesRegex(AssertionError,'resource differs from source'):
            verifier.verify_system_information_runtime(self.archive,self.project)

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

    def test_historical_v39_fixture_is_exactly_pinned(self):
        data=json.loads((PROJECT/'tests/fixtures/hyperdrive_v39_sources.json').read_text())
        self.assertEqual(data['source_commit'],HISTORICAL_SOURCE_COMMIT)
        self.assertEqual(set(data['files']),set(HISTORICAL_SOURCE_SHA256))
        for name,expected in HISTORICAL_SOURCE_SHA256.items():
            with self.subTest(source=name):
                entry=data['files'][name]
                self.assertEqual(entry['sha256'],expected)
                self.assertEqual(hashlib.sha256(entry['source'].encode()).hexdigest(),expected)
                self.assertEqual(hashlib.sha256((self.project/name).read_bytes()).hexdigest(),expected)

    def test_historical_navigation_and_map_logic_cannot_drift(self):
        for name in ['scripts/navigation.gd','scripts/galactic_map_model.gd']:
            with self.subTest(source=name),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/name
                path.write_bytes(path.read_bytes()+b'\n# changed protected historical logic\n')
                with self.assertRaisesRegex(AssertionError,'Visual-only map update changed protected source/data '+name):
                    verifier.verify_system_information_runtime(self.archive,project)


if __name__=='__main__':unittest.main()
