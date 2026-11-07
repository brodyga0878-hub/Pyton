"""DOS byte/geometry/variant controls, separate from native runtime oracles."""
import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest

PROJECT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(PROJECT/'tools'))
import extract_fuel as extractor
EXE=Path('/workspace/ffe-original/FIRSTENC.EXE')
SOURCE=Path('/workspace/ffe-upstream/jjffe')


class FuelExtraction(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.data=json.loads((PROJECT/'data/ffe_fuel.json').read_text())

    def test_immutable_hyperdrive_resource_and_source_provenance(self):
        self.assertEqual(self.data['schema'],1)
        self.assertEqual(self.data['source_sha256'],extractor.EXE_SHA)
        self.assertEqual(self.data['source_assembly_sha256'],extractor.ASM_SHA)
        self.assertEqual(self.data['immutable_hyperdrive_resource_sha256'],extractor.HYPER_SHA)
        self.assertEqual(hashlib.sha256((PROJECT/'data/ffe_hyperdrive.json').read_bytes()).hexdigest(),extractor.HYPER_SHA)

    def test_manual_capacity_and_npc_initial_tables_are_distinct(self):
        tables=self.data['tables_hex']
        capacity=struct.unpack('<15I',bytes.fromhex(tables['5111']))
        npc=struct.unpack('<15I',bytes.fromhex(tables['6266']))
        self.assertEqual(capacity,(0,0x20000000,0x20000000,0x40000000,0x60000000,0x80000000,
                                   0xa0000000,0xc0000000,0xe0000000,0xffffffff,0x20000000,0x40000000,
                                   0x60000000,0x80000000,0x20000000))
        self.assertEqual(npc,(0,32,32,64,96,128,160,192,224,255,32,64,96,128,0))
        self.assertNotEqual(capacity[9],npc[9]<<24)
        self.assertNotEqual(capacity[14],npc[14]<<24)
        self.assertEqual(hashlib.sha256(bytes.fromhex(tables['5111'])).hexdigest(),
                         '094f80502f208b354b4e91d1dff6777d0d893d47c05c31fba8177d3e5b214a57')
        self.assertEqual(self.data['constants']['manual_refill_margin_raw_u32'],0x1999999)

    def test_source_equipment_mass_mask_and_scoop_hull_requirement(self):
        expected={'refueller':(14,1,2),'scoop':(29,6,0x100000),
                  'atmospheric_shielding':(15,1,0x40000000),
                  'laser_cooling_booster':(18,1,1),'energy_booster':(36,5,0x10000000),
                  'hull_auto_repair':(40,40,0x80000000),'shield_generator':(27,4,0)}
        for key,values in expected.items():
            item=self.data['equipment'][key]
            self.assertEqual(tuple(item[k]for k in ['equipment_index','mass_tonnes_u32','equipment_mask_u32']),values)
            raw=bytes.fromhex(item['record_hex'])
            self.assertEqual(len(raw),22)
            self.assertEqual(struct.unpack_from('<I',raw,8)[0],values[1])
            self.assertEqual(item['name_ff_code'],0x9875+values[0])
        self.assertEqual(self.data['equipment']['scoop']['required_spec_word_offset'],4)
        self.assertEqual(self.data['equipment']['scoop']['required_spec_mask_u16'],0x100)
        self.assertEqual(self.data['equipment']['cargo_scoop_conversion']['required_equipment_mask_u32'],0x100000)
        shield=self.data['equipment']['shield_generator']
        self.assertEqual(shield['type_u8'],4)
        self.assertFalse(shield['single_install'])
        self.assertEqual(shield['shield_capacity_increment_raw'],64)

    def test_original_starters_are_explicitly_separate_from_bare_shuttle(self):
        profiles=self.data['starter_profiles']
        self.assertEqual([profiles[k]['initial_jet_raw_u32']for k in ['cobra','eagle','shuttle']],
                         [0x40000000,0x20000000,0])
        self.assertEqual([profiles[k]['initial_equipment_bits_u32']for k in ['cobra','eagle','shuttle']],
                         [0x40000,0x40240000,0])
        self.assertTrue(profiles['cobra']['original_starter'])
        self.assertFalse(profiles['eagle']['original_starter'])
        self.assertFalse(profiles['shuttle']['original_starter'])
        self.assertTrue(profiles['cobra']['scoop_hull_eligible'])
        self.assertFalse(profiles['eagle']['scoop_hull_eligible'])
        self.assertFalse(profiles['shuttle']['scoop_hull_eligible'])
        self.assertTrue(all(not row['has_refueller'] and not row['has_scoop'] for row in profiles.values()))

    def test_dos_f929_variant_cannot_be_called_jjffe_six_axis_restore(self):
        variant=self.data['source_variants']['F929']
        self.assertIs(variant['DOS_automatic_restore'],False)
        self.assertEqual(variant['DOS_exhaustion_cleared_offsets'],[0xbc,0xc0,0xc4])
        raw=bytes.fromhex(self.data['dos_code_blocks']['929']['hex'])
        for offset in [0xbc,0xc0,0xc4]:self.assertIn(bytes.fromhex('66c783')+struct.pack('<I',offset)+b'\0\0',raw)
        for offset in [0xbe,0xc2,0xc6]:self.assertNotIn(bytes.fromhex('66c783')+struct.pack('<I',offset)+b'\0\0',raw)
        self.assertNotIn(bytes.fromhex('668b8614020000'),raw)
        manual=bytes.fromhex(self.data['dos_code_blocks']['289']['hex'])
        self.assertIn(bytes.fromhex('668b9814020000'),manual)

    def test_all_fifteen_models_keep_raw_geometry_and_separate_bounds(self):
        models=self.data['models']
        self.assertEqual(sorted(map(int,models)),list(range(134,149)))
        for key,row in models.items():
            descriptor=bytes.fromhex(row['descriptor_hex'])
            vertices=bytes.fromhex(row['vertices_hex'])
            payload=bytes.fromhex(row['collision_payload_hex'])
            self.assertEqual(len(descriptor),68)
            self.assertEqual(len(vertices),24)
            self.assertEqual(payload[:4],bytes.fromhex('06020400'))
            self.assertEqual(len(payload),8)
            self.assertEqual(struct.unpack_from('<H',payload,4)[0],{134:3,135:6,136:5}.get(int(key),9))
            self.assertEqual(row['mesh_zoom'],sum(struct.unpack_from('<II',descriptor,20)))
            self.assertEqual(bytes.fromhex(row['collision_stream_hex']),bytes.fromhex('1083ff')+payload+bytes.fromhex('5080000000'))
            for field in ['vertices','descriptor','collision_payload']:
                self.assertEqual(hashlib.sha256(bytes.fromhex(row[field+'_hex'])).hexdigest(),row[field+'_sha256'])
        self.assertEqual(models['134']['collision_stream_offset'],'0x9ddb0')
        self.assertEqual(models['137']['collision_stream_offset'],'0x9df8a')

    @unittest.skipUnless(EXE.is_file(),'Original uploaded DOS executable not present')
    def test_every_published_table_code_anchor_and_geometry_byte_is_original(self):
        raw=EXE.read_bytes()
        for row in self.data['tables'].values():
            at=row['dos_file_offset'];data=bytes.fromhex(row['hex'])
            self.assertEqual(raw[at:at+len(data)],data)
        for group in ['dos_instruction_anchors','dos_code_blocks']:
            for row in self.data[group].values():
                at=row['dos_file_offset'];data=bytes.fromhex(row['hex'])
                self.assertEqual(raw[at:at+len(data)],data)
        for row in self.data['equipment'].values():
            at=row['record_file_offset'];self.assertEqual(raw[at:at+22].hex(),row['record_hex'])
            at=row['dos_file_offset'];data=bytes.fromhex(row['hex']);self.assertEqual(raw[at:at+len(data)],data)
        for row in self.data['models'].values():
            at=int(row['descriptor_offset'],16);self.assertEqual(raw[at:at+68].hex(),row['descriptor_hex'])
            pointer=struct.unpack_from('<I',raw,row['descriptor_table_file_offset'])[0]
            self.assertEqual(pointer,at+0x416400)
            for key in ['vertices','collision_payload']:
                at=int(row[key+'_offset'],16);data=bytes.fromhex(row[key+'_hex']);self.assertEqual(raw[at:at+len(data)],data)

    @unittest.skipUnless(EXE.is_file() and (SOURCE/'ffe.asm').is_file(),'Pinned originals unavailable')
    def test_drive_removal_clears_jet_without_grant_on_installation(self):
        proof=extractor.extract_drive_service_proof(EXE.read_bytes(),(SOURCE/'ffe.asm').read_bytes())
        self.assertEqual(proof['functions']['410']['dos_file_offset'],0x14148)
        effects=proof['functions']['410']['statically_reviewed_effects']
        self.assertEqual(effects['object_write_offsets'],[0xd0,0x11e])
        self.assertEqual(effects['jet_value_on_success'],0)
        self.assertFalse(effects['thrust_limit_writes'])
        self.assertFalse(proof['functions']['408']['statically_reviewed_effects']['initial_fuel_granted'])
        self.assertFalse(proof['native_oracle_executed'])

    @unittest.skipUnless(EXE.is_file() and (SOURCE/'ffe.asm').is_file(),'Pinned originals unavailable')
    def test_reextraction_is_exact_and_wrong_old_hyperdrive_is_rejected(self):
        args=[EXE.read_bytes(),(SOURCE/'ffe.asm').read_bytes(),(SOURCE/'ffedat.asm').read_bytes(),
              (PROJECT/'data/ffe_hyperdrive.json').read_bytes()]
        self.assertEqual(extractor.extract(*args),self.data)
        with self.assertRaisesRegex(ValueError,'Immutable code40 hyperdrive'):
            extractor.extract(*args[:3],args[3]+b' ')


if __name__=='__main__':unittest.main()
