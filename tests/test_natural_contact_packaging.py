"""Code46 rejection controls with explicit mock GDSC, not an APK or device."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import test_spherical_contact_packaging as retained

verifier = retained.verifier
PROJECT = retained.PROJECT


class MockNaturalArchive(retained.MockSphericalArchive):
    def __init__(self):
        super().__init__()
        for name in verifier.NATURAL_CONTACT_MODULES:
            self.entries['assets/scripts/' + name + '.gdc'] = b'GDSC' + b'explicit-unit-mock-not-an-APK' * 5
        for name in ('ffe_natural_contact', 'ffe_ground_collision'):
            self.entries['assets/data/' + name + '.json'] = (PROJECT / 'data' / (name + '.json')).read_bytes()


class NaturalContactPackaging(unittest.TestCase):
    def setUp(self):
        self.archive = MockNaturalArchive()

    @staticmethod
    def project_files():
        files = retained.SphericalContactPackaging.project_files()
        files.update('scripts/' + name + '.gd' for name in verifier.NATURAL_CONTACT_MODULES)
        files.update(['data/ffe_natural_contact.json', 'data/ffe_ground_collision.json',
                      'tests/fixtures/source_natural_contact_native.json'])
        return files

    def project_copy(self, directory):
        project = Path(directory)
        for relative in self.project_files():
            target = project / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((PROJECT / relative).read_bytes())
        return project

    def mutate_resource(self, project, callback):
        path = project / 'data/ffe_natural_contact.json'
        data = json.loads(path.read_text())
        callback(data)
        raw = json.dumps(data, ensure_ascii=False).encode()
        path.write_bytes(raw)
        self.archive.entries['assets/data/ffe_natural_contact.json'] = raw

    def test_frozen_runtime_scope_preserves_exact_code45_and_real_three_ship_lists(self):
        result = verifier.verify_natural_contact_runtime(self.archive, PROJECT)
        self.assertEqual(result['baseline_source_commit'], 'e3b9369230085ef7c15ab974d8e8de84eda1a991')
        self.assertEqual((result['compiled_module_count'], result['integration_compiled_module_count']), (3, 29))
        self.assertEqual(result['unchanged_code45_source_count'], 25)
        self.assertEqual(result['ship_model_count'], 3)
        self.assertEqual(result['natural_parent_model_count'], 32)
        self.assertEqual(result['source_player_child_counts'], {'24': 0, '38': 2, '15': 1})
        self.assertTrue(result['new_json_runtime_lookup_required'])
        self.assertTrue(result['actual_Main_probe_readonly'])
        self.assertEqual(result['retained_spherical_contact_assets']['integration_compiled_module_count'], 26)
        for key in ('physical_response_changed_by_probe', 'full_F569_F570_engine',
                    'full_original_world_object_bank', 'complete_original_physics',
                    'independent_native_natural_F575_pipeline_executed',
                    'compiled_source_correspondence_rebuilt_by_verifier', 'physical_device_tested'):
            self.assertFalse(result[key], key)
        native = result['native_reference']
        self.assertFalse(native['oracle_executed_by_apk_verifier'])
        self.assertEqual(native['case_count'], verifier.NATURAL_CONTACT_NATIVE_CASE_COUNT)
        self.assertEqual(native['separate_unsupported_VM_abort_interception_count'], 2)

    def test_each_of29_compiled_modules_required(self):
        for relative in verifier.NATURAL_CONTACT_AUDITED_SOURCE_SHA256:
            with self.subTest(relative=relative):
                archive = MockNaturalArchive()
                del archive.entries['assets/scripts/' + Path(relative).stem + '.gdc']
                with self.assertRaisesRegex(AssertionError, 'Missing natural-contact integration runtime'):
                    verifier.verify_natural_contact_runtime(archive, PROJECT)

    def test_each_new_module_rejects_wrong_header_or64byte_truncation(self):
        for name in verifier.NATURAL_CONTACT_MODULES:
            for value in (b'BAD!' + b'x' * 100, b'GDSC' + b'x' * 60):
                with self.subTest(name=name, size=len(value)):
                    archive = MockNaturalArchive()
                    archive.entries['assets/scripts/' + name + '.gdc'] = value
                    with self.assertRaisesRegex(AssertionError, 'Invalid compiled natural-contact integration runtime'):
                        verifier.verify_natural_contact_runtime(archive, PROJECT)

    def test_missing_new_metadata_rejects(self):
        del self.archive.entries['assets/data/ffe_natural_contact.json']
        with self.assertRaisesRegex(AssertionError, 'Missing natural-contact metadata resource'):
            verifier.verify_natural_contact_runtime(self.archive, PROJECT)

    def test_export_must_match_local_metadata_bytes(self):
        self.archive.entries['assets/data/ffe_natural_contact.json'] += b' '
        with self.assertRaisesRegex(AssertionError, 'Natural-contact resource differs from local source'):
            verifier.verify_natural_contact_runtime(self.archive, PROJECT)

    def test_original_source_provenance_cannot_be_replaced(self):
        with tempfile.TemporaryDirectory() as directory:
            project = self.project_copy(directory)
            self.mutate_resource(project, lambda d: d.update(source_sha256='0' * 64))
            with self.assertRaisesRegex(AssertionError, 'Wrong natural-contact source provenance'):
                verifier.verify_natural_contact_runtime(self.archive, project)

    def test_previous_resource_digest_contract_cannot_change(self):
        with tempfile.TemporaryDirectory() as directory:
            project = self.project_copy(directory)
            self.mutate_resource(project, lambda d: d['immutable_resources'].update(ffe_ground_collision_sha256='0' * 64))
            with self.assertRaisesRegex(AssertionError, 'changed retained resource digests'):
                verifier.verify_natural_contact_runtime(self.archive, project)

    def test_all_old_raw_resources_remain_checked(self):
        for name in ('ffe_ground_collision', 'ffe_spherical_contact', 'ffe_surface_contact',
                     'ffe_runtime_model_descriptors', 'ffe_hyperdrive', 'ffe_fuel',
                     'ffe_atmosphere', 'ffe_landing_gear', *verifier.SYSTEM_INFORMATION_TABLES):
            with self.subTest(name=name):
                archive = MockNaturalArchive()
                archive.entries['assets/data/' + name + '.json'] += b' '
                with self.assertRaises(AssertionError):
                    verifier.verify_natural_contact_runtime(archive, PROJECT)

    def test_all_three_original_ship_models_are_required(self):
        with tempfile.TemporaryDirectory() as directory:
            project = self.project_copy(directory)
            self.mutate_resource(project, lambda d: d['ship_models'].pop('15'))
            with self.assertRaisesRegex(AssertionError, 'Incomplete three-ship'):
                verifier.verify_natural_contact_runtime(self.archive, project)

    def test_ship_descriptor_cannot_be_fabricated(self):
        with tempfile.TemporaryDirectory() as directory:
            project = self.project_copy(directory)
            self.mutate_resource(project, lambda d: d['ship_models']['24'].update(descriptor_hex='00' * 68))
            with self.assertRaisesRegex(AssertionError, 'Natural ship descriptor mismatch'):
                verifier.verify_natural_contact_runtime(self.archive, project)

    def test_ship_physical_spec_cannot_be_replaced(self):
        with tempfile.TemporaryDirectory() as directory:
            project = self.project_copy(directory)
            self.mutate_resource(project, lambda d: d['ship_models']['24'].update(physical_spec_hex='00' * 24))
            with self.assertRaisesRegex(AssertionError, 'Natural ship physical specification mismatch'):
                verifier.verify_natural_contact_runtime(self.archive, project)

    def test_player_inner_radius_must_remain_actual_positive_f1533_value(self):
        with tempfile.TemporaryDirectory() as directory:
            project = self.project_copy(directory)
            self.mutate_resource(project, lambda d: d['ship_models']['24']['f1533_radii'].update(inner_s64=0))
            with self.assertRaisesRegex(AssertionError, 'positive F1533 radii mismatch'):
                verifier.verify_natural_contact_runtime(self.archive, project)

    def test_child_pointer_uses_actual_va_to_file_mapping(self):
        with tempfile.TemporaryDirectory() as directory:
            project = self.project_copy(directory)
            self.mutate_resource(project, lambda d: d['ship_models']['38'].update(collision_file_offset=0))
            with self.assertRaisesRegex(AssertionError, 'original collision pointer/prefix mismatch'):
                verifier.verify_natural_contact_runtime(self.archive, project)

    def test_cobra_real_children_cannot_be_replaced_by_fake_zero_terminator(self):
        with tempfile.TemporaryDirectory() as directory:
            project = self.project_copy(directory)
            self.mutate_resource(project, lambda d: d['ship_models']['38']['preceding_children'].update(hex='0000', records=[]))
            with self.assertRaisesRegex(AssertionError, 'backwards child bytes mismatch'):
                verifier.verify_natural_contact_runtime(self.archive, project)

    def test_child_record_count_cannot_drop_shuttle_offset(self):
        with tempfile.TemporaryDirectory() as directory:
            project = self.project_copy(directory)
            self.mutate_resource(project, lambda d: d['ship_models']['15']['preceding_children'].update(records=[]))
            with self.assertRaisesRegex(AssertionError, 'actual child count mismatch'):
                verifier.verify_natural_contact_runtime(self.archive, project)

    def test_child_displacement_axis_sign_and_radius_cannot_be_reinterpreted(self):
        for field, value in [('axis_negative', False), ('axis_index', 2),
                             ('radius_word_u16', 13200), ('displacement_s16', 0)]:
            with self.subTest(field=field), tempfile.TemporaryDirectory() as directory:
                project = self.project_copy(directory)
                self.mutate_resource(project, lambda d: d['ship_models']['38']['preceding_children']['records'][0].update({field: value}))
                with self.assertRaisesRegex(AssertionError, 'child axis/radius/offset mismatch'):
                    verifier.verify_natural_contact_runtime(self.archive, project)

    def test_all32_natural_parent_indices_required(self):
        with tempfile.TemporaryDirectory() as directory:
            project = self.project_copy(directory)
            self.mutate_resource(project, lambda d: d['natural_parent_programs'].pop('148'))
            with self.assertRaisesRegex(AssertionError, 'Incomplete32-natural'):
                verifier.verify_natural_contact_runtime(self.archive, project)

    def test_model117_must_retain_nonspherical_source_flag(self):
        with tempfile.TemporaryDirectory() as directory:
            project = self.project_copy(directory)
            self.mutate_resource(project, lambda d: d['natural_parent_programs']['117'].update(non_spherical_source_model=False))
            with self.assertRaisesRegex(AssertionError, 'nonspherical provenance mismatch'):
                verifier.verify_natural_contact_runtime(self.archive, project)

    def test_natural_terrain_stream_digest_cannot_be_self_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            project = self.project_copy(directory)
            self.mutate_resource(project, lambda d: d['natural_parent_programs']['134']['program'].update(sha256='0' * 64))
            with self.assertRaisesRegex(AssertionError, 'complete terrain program mismatch'):
                verifier.verify_natural_contact_runtime(self.archive, project)

    def test_source_feature_terminator_and_opcode_provenance_stay_exact(self):
        for field, value in [('feature_count', 999), ('primitive_selector_u8', 0)]:
            with self.subTest(field=field), tempfile.TemporaryDirectory() as directory:
                project = self.project_copy(directory)
                self.mutate_resource(project, lambda d: d['natural_parent_programs']['118']['program'].update({field: value}))
                with self.assertRaisesRegex(AssertionError, 'Natural (feature list|opcode/payload)'):
                    verifier.verify_natural_contact_runtime(self.archive, project)

    def test_unreviewed_metadata_addition_rejects_frozen_hash(self):
        with tempfile.TemporaryDirectory() as directory:
            project = self.project_copy(directory)
            self.mutate_resource(project, lambda d: d.update(full_original_engine=True))
            with self.assertRaisesRegex(AssertionError, 'differs from frozen DOS extraction'):
                verifier.verify_natural_contact_runtime(self.archive, project)

    def test_every_new_local_runtime_source_is_frozen(self):
        for name in verifier.NATURAL_CONTACT_MODULES:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                project = self.project_copy(directory)
                path = project / 'scripts' / (name + '.gd')
                path.write_bytes(path.read_bytes() + b'\n# unreviewed change\n')
                with self.assertRaisesRegex(AssertionError, 'Natural contact differs from audited integration source'):
                    verifier.verify_natural_contact_runtime(self.archive, project)

    def test_all_old25_nonmain_sources_remain_unchanged(self):
        for relative in verifier.SPHERICAL_CONTACT_AUDITED_SOURCE_SHA256:
            if relative == 'scripts/main.gd':
                continue
            with self.subTest(relative=relative), tempfile.TemporaryDirectory() as directory:
                project = self.project_copy(directory)
                path = project / relative
                path.write_bytes(path.read_bytes() + b'\n# changed old owner\n')
                with self.assertRaisesRegex(AssertionError, 'Natural contact differs from audited integration source'):
                    verifier.verify_natural_contact_runtime(self.archive, project)

    def test_main_physical_tick_and_save_cannot_change(self):
        for function in ('_tick', '_payload'):
            with self.subTest(function=function), tempfile.TemporaryDirectory() as directory:
                project = self.project_copy(directory)
                path = project / 'scripts/main.gd'
                raw = path.read_text()
                old = verifier.source_function(raw, function)
                path.write_text(raw.replace(old, old.replace('\n', '\n\tship.hull=100\n', 1), 1))
                with self.assertRaisesRegex(AssertionError, 'changed physical/save/Main outside exact diagnostic normalization'):
                    verifier.verify_natural_contact_runtime(self.archive, project)

    def test_natural_diagnostic_preload_cannot_be_removed_or_duplicated(self):
        preload = 'const NaturalContactProbe=preload("res://scripts/source_natural_contact_probe.gd")\n'
        for value in ('', preload * 2):
            with self.subTest(value=value), tempfile.TemporaryDirectory() as directory:
                project = self.project_copy(directory)
                path = project / 'scripts/main.gd'
                path.write_text(path.read_text().replace(preload, value, 1))
                with self.assertRaisesRegex(AssertionError, 'Missing exact natural diagnostic-only Main additions'):
                    verifier.verify_natural_contact_runtime(self.archive, project)

    def test_new_native_reference_bytes_cannot_change(self):
        with tempfile.TemporaryDirectory() as directory:
            project = self.project_copy(directory)
            path = project / 'tests/fixtures/source_natural_contact_native.json'
            path.write_bytes(path.read_bytes() + b' ')
            with self.assertRaisesRegex(AssertionError, 'Changed natural native reference'):
                verifier.verify_natural_contact_runtime(self.archive, project)

    def test_retained_native_domains_stay_pinned(self):
        for name in ('source_spherical_contact_native', 'source_spherical_contact_pipeline_native',
                     'source_surface_contact_native'):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                project = self.project_copy(directory)
                path = project / 'tests/fixtures' / (name + '.json')
                path.write_bytes(path.read_bytes() + b' ')
                with self.assertRaises(AssertionError):
                    verifier.verify_natural_contact_runtime(self.archive, project)

    def test_old45_public_gate_remains_strict_against_actual46_main(self):
        with self.assertRaisesRegex(AssertionError, 'Missing exact spherical diagnostic-only Main additions|Spherical update changed physical/save/Main'):
            verifier.verify_spherical_contact_runtime(self.archive, PROJECT)

    def test_old44_public_gate_remains_strict_against_actual46_main(self):
        with self.assertRaisesRegex(AssertionError, 'Contact differs from audited integration source scripts/main.gd'):
            verifier.verify_surface_contact_runtime(self.archive, PROJECT)


if __name__ == '__main__':
    unittest.main()
