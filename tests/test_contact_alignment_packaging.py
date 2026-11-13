"""Code47 package rejection controls; mock GDSC is never an exported APK."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import test_natural_contact_packaging as retained

verifier=retained.verifier
PROJECT=retained.PROJECT


class MockAlignmentArchive(retained.MockNaturalArchive):
    def __init__(self):
        super().__init__()
        modules={Path(path).stem for path in verifier.CONTACT_ALIGNMENT_AUDITED_SOURCE_SHA256}
        modules.update(Path(path).stem for path in verifier.CONTACT_ALIGNMENT_PROTECTED_KERNEL_DATA_SHA256 if path.endswith('.gd'))
        for name in modules:
            self.entries['assets/scripts/'+name+'.gdc']=b'GDSC'+('actual47-unit-mock-'+name).encode()*5
        for relative in verifier.FUEL_CONTACT_DEPENDENCY_SHA256:
            if relative.startswith('data/'):
                self.entries['assets/'+relative]=(PROJECT/relative).read_bytes()


class ContactAlignmentPackaging(unittest.TestCase):
    def setUp(self):self.archive=MockAlignmentArchive()

    @staticmethod
    def project_files():
        files=retained.NaturalContactPackaging.project_files()
        files.update(verifier.CONTACT_ALIGNMENT_AUDITED_SOURCE_SHA256)
        files.update(verifier.FUEL_CONTACT_DEPENDENCY_SHA256)
        files.update(verifier.CONTACT_ALIGNMENT_PROTECTED_KERNEL_DATA_SHA256)
        files.update(['tests/fixtures/alignment_v46_sources.json','tests/fixtures/source_contact_field_native.json',
                      'tests/test_source_contact_surface_render.gd',
                      'validation/alignment-2026-11-13/source-contact-surface-render.json'])
        return files

    def project_copy(self,directory):
        project=Path(directory)
        for relative in self.project_files():
            target=project/relative;target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes((PROJECT/relative).read_bytes())
        return project

    def mutate_json(self,project,relative,callback):
        path=project/relative;data=json.loads(path.read_text());callback(data)
        path.write_text(json.dumps(data,ensure_ascii=False))

    def test_actual47_scope_retains_v4_defaults_without_compiled_asset_substitution(self):
        result=verifier.verify_contact_alignment_runtime(self.archive,PROJECT)
        self.assertEqual(result['baseline_source_commit'],'2637168f2371937758504a54b9e17c11d279c82e')
        self.assertEqual((result['compiled_module_count'],result['integration_compiled_module_count']),(4,40))
        self.assertEqual(result['unchanged_code46_runtime_source_count'],27)
        self.assertEqual(result['preserved_physical_default_material_function_count'],11)
        self.assertEqual(result['baseline_fixture_source_count'],36)
        self.assertEqual(result['retained_code46_source_audit']['source_override_count'],9)
        self.assertFalse(result['retained_code46_source_audit']['compiled_assets_substituted'])
        self.assertFalse(result['actual_runtime_is_unchanged_code46'])
        self.assertTrue(result['v4_is_default_physical_terrain'])
        self.assertEqual(result['native_field_reference']['case_count'],459)
        self.assertEqual(result['native_field_reference']['canonical_positive_player_classifier_case_count'],306)
        self.assertEqual(result['v4_renderer_regression']['v4_patch_checksum'],verifier.CONTACT_ALIGNMENT_V4_PATCH_CHECKSUM)
        for key in ('Main_new_natural_response_branch','new_alignment_data_persisted_in_game_save',
                    'whole_interpolated_triangle_certified','complete_original_physics',
                    'physical_device_tested','compiled_source_correspondence_rebuilt_by_verifier'):
            self.assertFalse(result[key],key)

    def test_all40_actual_compiled_sources_are_required(self):
        for relative in verifier.CONTACT_ALIGNMENT_AUDITED_SOURCE_SHA256:
            with self.subTest(relative=relative):
                archive=MockAlignmentArchive();del archive.entries['assets/scripts/'+Path(relative).stem+'.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing contact-alignment integration runtime'):
                    verifier.verify_contact_alignment_runtime(archive,PROJECT)

    def test_new_compiled_headers_and_truncation_reject(self):
        for name in verifier.CONTACT_ALIGNMENT_MODULES:
            for raw in (b'BAD!'+b'x'*100,b'GDSC'+b'x'*60):
                with self.subTest(name=name,size=len(raw)):
                    archive=MockAlignmentArchive();archive.entries['assets/scripts/'+name+'.gdc']=raw
                    with self.assertRaisesRegex(AssertionError,'Invalid compiled contact-alignment integration runtime'):
                        verifier.verify_contact_alignment_runtime(archive,PROJECT)

    def test_current_compiled_provider_bytes_remain_actual_in_retained_audit(self):
        path='assets/scripts/source_surface_render_state.gdc';raw=b'GDSC'+b'current47-only-exported-provider'*5
        self.archive.entries[path]=raw
        result=verifier.verify_contact_alignment_runtime(self.archive,PROJECT)
        digest=hashlib.sha256(raw).hexdigest()
        self.assertEqual(result['integration_compiled_modules']['source_surface_render_state'],digest)
        old=result['retained_code46_source_audit']['assets']['retained_spherical_contact_assets']['retained_surface_contact_assets']
        self.assertEqual(old['published_provider_compiled_modules']['source_surface_render_state'],digest)
        self.assertFalse(result['retained_code46_source_audit']['compiled_assets_substituted'])

    def test_old46_public_gate_still_rejects_actual47_runtime(self):
        with self.assertRaises(AssertionError):verifier.verify_natural_contact_runtime(self.archive,PROJECT)

    def test_baseline_comes_from_fixed_git_commit_and_exact36_sources(self):
        data=verifier._load_contact_alignment_baseline(PROJECT)
        self.assertEqual(len(data['files']),36)
        self.assertEqual(data['source_commit'],'2637168f2371937758504a54b9e17c11d279c82e')
        self.assertEqual(data['audited_runtime_source_sha256'],verifier.NATURAL_CONTACT_AUDITED_SOURCE_SHA256)
        self.assertEqual(len(data['provider_source_sha256']),6)

    def test_portable_baseline_cannot_change_even_with_its_own_rehashed_entries(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            def corrupt(data):
                row=data['files']['scripts/main.gd'];row['source']+='\n# fabricated history\n'
                row['sha256']=hashlib.sha256(row['source'].encode()).hexdigest()
            self.mutate_json(project,'tests/fixtures/alignment_v46_sources.json',corrupt)
            with self.assertRaisesRegex(AssertionError,'Changed portable code46 alignment source baseline'):
                verifier.verify_contact_alignment_runtime(self.archive,project)

    def test_all_four_new_local_runtime_sources_are_frozen(self):
        for name in verifier.CONTACT_ALIGNMENT_MODULES:
            with self.subTest(name=name),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/'scripts'/f'{name}.gd'
                path.write_bytes(path.read_bytes()+b'\n# unaudited change\n')
                with self.assertRaisesRegex(AssertionError,'Contact alignment differs from audited integration source'):
                    verifier.verify_contact_alignment_runtime(self.archive,project)

    def test_six_renderer_sources_and_root_compatibility_consumers_are_frozen(self):
        for relative in [*verifier.CONTACT_ALIGNMENT_PROVIDER_SOURCE_SHA256,'scripts/main.gd','scripts/surface_model.gd','scripts/surface_orbit_link.gd']:
            with self.subTest(relative=relative),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/relative
                path.write_bytes(path.read_bytes()+b'\n# changed policy owner\n')
                with self.assertRaisesRegex(AssertionError,'Contact alignment differs from audited integration source'):
                    verifier.verify_contact_alignment_runtime(self.archive,project)

    def test_old27_unchanged_runtime_sources_cannot_be_hidden_by_source_history_view(self):
        for relative in verifier.NATURAL_CONTACT_AUDITED_SOURCE_SHA256:
            if relative in ('scripts/main.gd','scripts/surface_model.gd'):continue
            with self.subTest(relative=relative),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/relative
                path.write_bytes(path.read_bytes()+b'\n# changed old kernel\n')
                with self.assertRaisesRegex(AssertionError,'Contact alignment differs from audited integration source'):
                    verifier.verify_contact_alignment_runtime(self.archive,project)

    def test_base_terrain_and_source_math_remain_exact(self):
        for relative in ['scripts/source_surface_terrain.gd','scripts/source_ground_surface.gd','scripts/source_terrain_query.gd','scripts/source_terrain_point.gd','scripts/source_terrain_math.gd','scripts/source_units.gd']:
            with self.subTest(relative=relative),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/relative
                path.write_bytes(path.read_bytes()+b'\n# changed source math\n')
                with self.assertRaisesRegex(AssertionError,'Contact alignment changed protected original kernel/data'):
                    verifier.verify_contact_alignment_runtime(self.archive,project)

    def test_actual_tick_save_and_v4_preference_are_checked_before_legacy_source_audit(self):
        baseline=verifier._load_contact_alignment_baseline(PROJECT)
        for relative,name in [('scripts/main.gd','_tick'),('scripts/main.gd','_payload'),('scripts/surface_orbit_link.gd','preferred_terrain_revision')]:
            with self.subTest(function=name),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/relative;raw=path.read_text()
                original=verifier.source_function(raw,name)
                path.write_text(raw.replace(original,original.replace('\n','\n\t# changed physical function\n',1),1))
                with self.assertRaisesRegex(AssertionError,'protected physical/default/material function'):
                    verifier._verify_contact_alignment_preserved_functions(project,baseline)

    def test_immutable_original_resources_are_exported_exactly(self):
        for name in ('ffe_natural_contact','ffe_spherical_contact','ffe_ground_collision','ffe_surface_contact','ffe_terrain_query','ffe_fuel','ffe_hyperdrive'):
            with self.subTest(name=name):
                archive=MockAlignmentArchive()
                if 'assets/data/'+name+'.json' not in archive.entries:
                    archive.entries['assets/data/'+name+'.json']=(PROJECT/'data'/f'{name}.json').read_bytes()
                archive.entries['assets/data/'+name+'.json']+=b' '
                with self.assertRaises(AssertionError):verifier.verify_contact_alignment_runtime(archive,PROJECT)

    def test_new_native_field_reference_cannot_change(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'tests/fixtures/source_contact_field_native.json'
            path.write_bytes(path.read_bytes()+b' ')
            with self.assertRaisesRegex(AssertionError,'Changed independent signed-field native reference'):
                verifier.verify_contact_alignment_runtime(self.archive,project)

    def test_native_geometry_cases_are_separate_from_actual_positive_player_classification(self):
        result=verifier._verify_contact_field_native_reference(PROJECT)
        self.assertEqual((result['geometry_case_count'],result['canonical_positive_player_classifier_case_count']),(153,306))
        self.assertEqual((result['exact_zero_count'],result['adjacent_integer_boundary_count']),(39,12))
        self.assertEqual(result['geometry_only_coarse_bound_exclusions'],['model117_axis_x','model117_axis_z'])
        for key in ('canonical_F576_bounds_expanded','oracle_executed_by_apk_verifier','root_algorithm_is_original_FFE','global_root_uniqueness_proved','interpolated_triangle_certification_proved'):
            self.assertFalse(result[key])

    def test_old993_classifier_and_original_response_native_proofs_stay_pinned(self):
        for name in ('source_natural_contact_native','source_surface_contact_native','source_spherical_contact_native'):
            with self.subTest(name=name),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/'tests/fixtures'/f'{name}.json'
                path.write_bytes(path.read_bytes()+b' ')
                with self.assertRaises(AssertionError):verifier.verify_contact_alignment_runtime(self.archive,project)

    def test_v4_renderer_evidence_must_match_current_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            def corrupt(data):data['sources']['scripts/source_surface_render_packet.gd']='0'*64
            self.mutate_json(project,'validation/alignment-2026-11-13/source-contact-surface-render.json',corrupt)
            with self.assertRaisesRegex(AssertionError,'Stale renderer regression evidence source'):
                verifier.verify_contact_alignment_runtime(self.archive,project)

    def test_v4_fixed_patch_checksum_and_global_key_cannot_change(self):
        for field in ('patch_checksum','global_key'):
            with self.subTest(field=field),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory)
                def corrupt(data):
                    row=next(row for row in data['evidence']if row['case']=='immutable_v4_compatibility');row[field]='0'*64
                self.mutate_json(project,'validation/alignment-2026-11-13/source-contact-surface-render.json',corrupt)
                with self.assertRaisesRegex(AssertionError,'old v4 checksum/cache defaults'):
                    verifier.verify_contact_alignment_runtime(self.archive,project)

    def test_interpolated_triangle_evidence_may_not_claim_arbitrary_point_native_equality(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            def corrupt(data):
                row=next(row for row in data['evidence']if row['case']=='actual_source_v5_saved_triangle');row['interpolated_triangle_is_native_arbitrary_point_zero']=True
            self.mutate_json(project,'validation/alignment-2026-11-13/source-contact-surface-render.json',corrupt)
            with self.assertRaisesRegex(AssertionError,'cannot claim arbitrary-point/native/global/GPU equivalence'):
                verifier.verify_contact_alignment_runtime(self.archive,project)

    def test_failed_renderer_evidence_cannot_be_accepted(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_json(project,'validation/alignment-2026-11-13/source-contact-surface-render.json',lambda d:d.update(failures=1))
            with self.assertRaisesRegex(AssertionError,'Missing successful current v4/v5 renderer regression evidence'):
                verifier.verify_contact_alignment_runtime(self.archive,project)


if __name__=='__main__':unittest.main()
