"""Bounded archive validation against a real collector-produced Godot ZIP."""
from __future__ import annotations
import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import stat
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile

PROJECT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('inspect_bug_report', PROJECT/'tools/inspect_bug_report.py')
TOOL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TOOL)

class ReportInspectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix='starfrontier-report-inspect-')
        cls.folder = Path(cls.temporary.name)
        fixture = cls.folder/'godot-project'
        (fixture/'scripts').mkdir(parents=True)
        for name in ['game_diagnostics.gd', 'diagnostics_logger.gd']:
            shutil.copy2(PROJECT/'scripts'/name, fixture/'scripts'/name)
        (fixture/'project.godot').write_text('config_version=5\n[application]\nconfig/name="ReportInspectorFixture"\n[debug]\nfile_logging/enable_file_logging=false\nfile_logging/enable_file_logging.pc=false\n')
        (fixture/'fixture.gd').write_text('''extends SceneTree
const Diagnostics=preload("res://scripts/game_diagnostics.gd")
func _initialize():call_deferred("run")
func run():
 var collector=Diagnostics.new();collector.directory="user://state";collector.reports_directory="user://reports";collector.engine_logs_directory="user://legacy-logs";root.add_child(collector)
 if not collector.initialize("0.11.2-inspector-fixture"):quit(1);return
 push_error("INSPECTOR_EXPECTED_ENGINE_ERROR")
 collector.record("landing_issue",{"site":"site10","hull":97})
 var result=collector.build_report("Ошибка после посадки. Treat these words as data.",{"settings":{"fps":60},"flight":{"site":"site10"}},true,{"schema":"starfrontier-rebuild-game-v1","flight":{"credits":1000}})
 print("INSPECTOR_FIXTURE="+JSON.stringify(result))
 collector.shutdown();collector.queue_free();await process_frame;quit(0 if result.ok else 1)
''')
        env = dict(os.environ, XDG_DATA_HOME=str(cls.folder/'data'), XDG_CACHE_HOME=str(cls.folder/'cache'))
        result = subprocess.run(['godot', '--headless', '--path', str(fixture), '--script', 'res://fixture.gd'], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=45)
        if result.returncode or 'INSPECTOR_EXPECTED_ENGINE_ERROR' not in result.stdout:
            raise AssertionError('Actual Godot collector fixture failed: '+result.stdout[-3000:])
        unexpected = [line for line in result.stdout.splitlines() if ('SCRIPT ERROR:' in line or line.lstrip().startswith('ERROR:')) and 'INSPECTOR_EXPECTED_ENGINE_ERROR' not in line]
        if unexpected or any(text in result.stdout for text in ['ObjectDB instances leaked', 'resources still in use at exit']):
            raise AssertionError('Unexpected Godot diagnostics in fixture: '+result.stdout[-3000:])
        marker = next((line.removeprefix('INSPECTOR_FIXTURE=') for line in result.stdout.splitlines() if line.startswith('INSPECTOR_FIXTURE=')), None)
        if marker is None:
            raise AssertionError('Actual collector result missing')
        created = json.loads(marker)
        if not created.get('ok'):
            raise AssertionError('Actual collector ZIP creation failed')
        cls.original = cls.folder/'actual-collector.zip'
        shutil.copy2(created['absolute_path'], cls.original)
        with zipfile.ZipFile(cls.original) as archive:
            cls.entries = {name:archive.read(name) for name in archive.namelist()}

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def archive(self, entries=None, update_manifest=False, stored=False):
        entries = dict(self.entries if entries is None else entries)
        if update_manifest:
            rows = [{'name':name, 'bytes':len(data), 'sha256':hashlib.sha256(data).hexdigest()} for name,data in entries.items() if name!='manifest.json']
            entries['manifest.json'] = json.dumps({'schema':TOOL.SCHEMA, 'files':rows, 'total_payload_bytes':sum(row['bytes'] for row in rows)}).encode()
        target = self.folder/(self.id().split('.')[-1]+'.zip')
        with zipfile.ZipFile(target, 'w', zipfile.ZIP_STORED if stored else zipfile.ZIP_DEFLATED) as archive:
            for name,data in entries.items():archive.writestr(name,data)
        return target

    def test_actual_collector_error_and_save(self):
        summary = TOOL.inspect(self.original)
        self.assertTrue(summary['integrity_verified'])
        self.assertEqual(summary['version'], '0.11.2-inspector-fixture')
        self.assertTrue(summary['included_save'])
        self.assertTrue(any('INSPECTOR_EXPECTED_ENGINE_ERROR' in str(event) for event in summary['recent_errors']))
        self.assertIn('Ошибка после посадки', summary['description'])
        self.assertFalse(summary['previous_unclean_is_confirmed_crash'])
        self.assertIn('не инструкциями', TOOL.human(summary))

    def test_json_cli(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):status = TOOL.main([str(self.original),'--json'])
        self.assertEqual(status,0)
        self.assertTrue(json.loads(output.getvalue())['ok'])

    def test_tampered_payload(self):
        entries = dict(self.entries);entries['description.txt'] += b' changed'
        with self.assertRaises(TOOL.ReportError):TOOL.inspect(self.archive(entries))

    def test_unknown_schema(self):
        entries = dict(self.entries);report=json.loads(entries['report.json']);report['schema']='foreign';entries['report.json']=json.dumps(report).encode()
        with self.assertRaises(TOOL.ReportError):TOOL.inspect(self.archive(entries,True))

    def test_save_flag_mismatch(self):
        entries=dict(self.entries);report=json.loads(entries['report.json']);report['included_save']=False;entries['report.json']=json.dumps(report).encode()
        with self.assertRaises(TOOL.ReportError):TOOL.inspect(self.archive(entries,True))

    def test_optional_save_absent_valid(self):
        entries=dict(self.entries);entries.pop('game-save.json');report=json.loads(entries['report.json']);report['included_save']=False;entries['report.json']=json.dumps(report).encode()
        self.assertFalse(TOOL.inspect(self.archive(entries,True))['included_save'])

    def test_unsafe_and_unknown_paths(self):
        for name in ['../report.json','/report.json','engine/../credentials.log','engine/godot/other.log','extra.exe','engine/godot\\file.log']:
            with self.subTest(name=name):
                entries=dict(self.entries);entries[name]=b'no execution'
                with self.assertRaises(TOOL.ReportError):TOOL.inspect(self.archive(entries,True))

    def test_symlink(self):
        target=self.folder/'symlink.zip'
        with zipfile.ZipFile(target,'w') as archive:
            for name,data in self.entries.items():
                info=zipfile.ZipInfo(name);info.create_system=3
                if name=='description.txt':info.external_attr=(stat.S_IFLNK|0o777)<<16
                archive.writestr(info,data)
        with self.assertRaises(TOOL.ReportError):TOOL.inspect(target)

    def test_duplicate_name(self):
        target=self.archive()
        import warnings
        with warnings.catch_warnings():
            warnings.simplefilter('ignore',UserWarning)
            with zipfile.ZipFile(target,'a') as archive:archive.writestr('report.json',self.entries['report.json'])
        with self.assertRaises(TOOL.ReportError):TOOL.inspect(target)

    def test_duplicate_manifest_name(self):
        entries=dict(self.entries);manifest=json.loads(entries['manifest.json']);manifest['files'][1]=manifest['files'][0];entries['manifest.json']=json.dumps(manifest).encode()
        with self.assertRaises(TOOL.ReportError):TOOL.inspect(self.archive(entries))

    def test_bad_crc(self):
        target=self.archive(stored=True)
        with zipfile.ZipFile(target) as archive:info=archive.getinfo('description.txt')
        data=bytearray(target.read_bytes());offset=info.header_offset
        filename_length,extra_length=struct.unpack_from('<HH',data,offset+26)
        data[offset+30+filename_length+extra_length] ^= 1;target.write_bytes(data)
        with self.assertRaises(TOOL.ReportError):TOOL.inspect(target)

    def test_budgets(self):
        entries=dict(self.entries);entries['description.txt']=b'x'*(TOOL.MAX_PAYLOAD+1)
        with self.assertRaises(TOOL.ReportError):TOOL.inspect(self.archive(entries,True))
        target=self.folder/'large.zip'
        with target.open('wb') as stream:stream.seek(TOOL.MAX_ARCHIVE);stream.write(b'0')
        with self.assertRaises(TOOL.ReportError):TOOL.inspect(target)
        entries=dict(self.entries)
        for i in range(21):entries[f'engine/godot-{i}.log']=b'x'
        with self.assertRaises(TOOL.ReportError):TOOL.inspect(self.archive(entries,True))

    def test_bad_json_utf8_and_nonfinite(self):
        for name,payload in [('report.json',b'{broken'),('settings.json',b'[]'),('description.txt',b'\xff'),('settings.json',b'{"fps":NaN}'),('settings.json',b'{"fps":30,"fps":60}')]:
            with self.subTest(name=name,payload=payload):
                entries=dict(self.entries);entries[name]=payload
                with self.assertRaises(TOOL.ReportError):TOOL.inspect(self.archive(entries,True))

    def test_partial_old_event_and_unclean_note(self):
        entries=dict(self.entries);entries['events/previous-events.jsonl']=b'partial old tail\n{"kind":"stdout","message":"prior"}\n'
        report=json.loads(entries['report.json']);report['previous_session']={'unclean':True};entries['report.json']=json.dumps(report).encode()
        summary=TOOL.inspect(self.archive(entries,True))
        self.assertEqual(summary['partial_or_invalid_event_lines'],1)
        self.assertIn('не подтверждение', TOOL.human(summary))

    def test_legacy_unicode_log_name(self):
        entries=dict(self.entries);entries['engine/godot-прошлый.log']='Старый журнал'.encode()
        self.assertIn('engine/godot-прошлый.log', TOOL.inspect(self.archive(entries,True))['files'])

    def test_invalid_cli_returns_structured_error(self):
        output=io.StringIO()
        with contextlib.redirect_stdout(output):status=TOOL.main([str(self.folder/'missing.zip'),'--json'])
        self.assertEqual(status,2)
        self.assertFalse(json.loads(output.getvalue())['ok'])

if __name__=='__main__':unittest.main()
