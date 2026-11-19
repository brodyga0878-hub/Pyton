"""Replace mission-task publication markers after all verified downloads.

Counts and immutable commit identities come from the sealed checkpoint and
its fresh verification. This never changes the ZIP, manifest or Git history.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

CHECKPOINT = 'mission-tasks-core-0.31.0-2026-11-19'
UPDATE_NAME = 'StarFrontier-0.31.0-mission-tasks-source-update.zip'
PAYLOADS = {'README_RU.md', UPDATE_NAME, 'functional-summary.json', 'source-pair-verification.json', 'source-update-policy.json'}
REQUIRED_NEW_SUITES = {'source_mission_models','source_mission_store','source_mission_task','source_mission_runtime'}

def require(ok, reason):
    if not ok:
        raise ValueError(reason)

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def number(value):
    require(type(value) is int and value >= 0, 'Nonnegative integer count required')
    return f'{value:,}'.replace(',', ' ')

def replace_marker(raw, marker, text):
    start = '<!-- ' + marker + '_BEGIN -->'
    end = '<!-- ' + marker + '_END -->'
    require(raw.count(start) == 1 and raw.count(end) == 1, 'Unique publication marker required: ' + marker)
    result, count = re.subn(re.escape(start) + '.*?' + re.escape(end), lambda _: start + '\n' + text + '\n' + end, raw, flags=re.S)
    require(count == 1, 'Publication marker order differs: ' + marker)
    return result

def declared_payloads(manifest):
    files=manifest.get('files');require(isinstance(files,dict),'Missing payload inventory')
    apk=manifest.get('apk')
    expected=set(PAYLOADS)
    if apk is not None:
        require(isinstance(apk,dict)and re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*\.apk',str(apk.get('file','')))is not None and apk.get('verification_file')=='android-verification.json','Unsafe APK declaration')
        require(apk.get('version')=='0.31.0-tasks-alpha1'and apk.get('version_code')==56 and apk.get('package')=='org.starfrontier.rebuild'and apk.get('abi')=='arm64-v8a'and apk.get('certificate_sha256')=='16f47f20a2d2aca3de1fe893ddfa01e90acf2d6b98b32ca772bb914c9ee21e25'and apk.get('signature_aapt_zipalign_rechecked_at_packaging')is True,'Declared APK identity differs')
        expected.update([apk['file'],apk['verification_file']])
    require(set(files)==expected and manifest.get('new_APK_produced')is(apk is not None),'Source/optional APK payload inventory differs')
    if apk is not None:require(files[apk['file']]=={'bytes':apk.get('bytes'),'sha256':apk.get('sha256')}and apk.get('source_commit')==manifest.get('source_commit'),'APK declaration and payload/source identity differ')
    require(manifest.get('game_version')=='0.31.0-tasks-alpha1'and manifest.get('Android_version_code')==56 and manifest.get('new_kernels_connected_to_Main')is False and manifest.get('version_metadata_changes_only')is True,'Source version/Main binding differs')
    return expected,apk


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=Path('/workspace/Pyton'))
    parser.add_argument('--publication-proof', type=Path)
    parser.add_argument('--download-verifier', type=Path, default=Path('/workspace/recovery/verify-mission-tasks-downloads.py'))
    args = parser.parse_args()
    root = args.repo.resolve()
    release = root / 'deliverables' / CHECKPOINT
    proof_path = args.publication_proof.resolve() if args.publication_proof else root / 'validation/mission-tasks-publication-2026-11-19/verification.json'
    proof_rel = proof_path.relative_to(root).as_posix()
    manifest_path = release / 'manifest.json'
    manifest_raw = manifest_path.read_bytes()
    manifest = json.loads(manifest_raw)
    require(manifest.get('schema') == 'starfrontier-mission-tasks-core-0.31.0-source-checkpoint-v1' and manifest.get('checkpoint') == CHECKPOINT, 'Sealed mission checkpoint required')
    payloads,apk_info=declared_payloads(manifest);expected_count=len(payloads)+2
    require(manifest.get('required_archive_count') == 2 and manifest.get('previous_update_archive_required') is False, 'Cumulative two-archive inventory differs')
    sealed = {manifest_path: sha(manifest_raw)}
    for name, expected in manifest['files'].items():
        raw = (release / name).read_bytes()
        require(len(raw) == expected.get('bytes') and sha(raw) == expected.get('sha256'), 'Sealed payload differs: ' + name)
        sealed[release / name] = sha(raw)
    fresh = json.loads((release / 'source-pair-verification.json').read_text())
    summary = json.loads((release / 'functional-summary.json').read_text())
    proof = json.loads(proof_path.read_text())
    source_commit = manifest.get('source_commit', '')
    artifact_commit = proof.get('artifact_commit', '')
    require(re.fullmatch('[0-9a-f]{40}', source_commit) is not None and re.fullmatch('[0-9a-f]{40}', artifact_commit) is not None, 'Full immutable commit identities required')
    require(fresh.get('ok') is True and fresh.get('status') == 'verified' and fresh.get('source_commit') == source_commit, 'Fresh source verification differs')
    require(proof.get('schema') == 'starfrontier-mission-tasks-core-0.31.0-source-publication-v1' and proof.get('status') == 'verified' and proof.get('checkpoint') == CHECKPOINT and proof.get('source_commit') == source_commit and proof.get('actual_complete_HTTPS_downloads') == expected_count, 'All declared verified publication downloads required')
    public_base = 'https://raw.githubusercontent.com/brodyga0878-hub/Pyton/' + artifact_commit + '/deliverables/' + CHECKPOINT + '/'
    base = manifest['base_archive']
    expected_downloads = {'manifest.json': {'url': public_base + 'manifest.json', 'bytes': len(manifest_raw), 'sha256': sha(manifest_raw)}}
    expected_downloads.update({name: {'url': public_base + name, **expected} for name, expected in manifest['files'].items()})
    base_name = Path(base['url']).name
    expected_downloads[base_name] = {'url': base['url'], 'bytes': base['bytes'], 'sha256': base['sha256']}
    records = proof.get('files', [])
    require(len(records) == expected_count and {row.get('file') for row in records} == set(expected_downloads), 'Publication payload inventory differs')
    for row in records:
        expected = expected_downloads[row['file']]
        require(row.get('http_status') == 200 and all(row.get(key) == value for key, value in expected.items()), 'Publication SHA/length/URL differs: ' + row['file'])
        if row['file'].endswith('.zip'):
            commit = base['source_commit'] if row['file'] == base_name else source_commit
            require(row.get('zip_CRC_verified') is True and row.get('source_commit_in_ZIP_comment') == commit, 'Publication ZIP CRC/source identity differs')
        if row['file'].endswith('.apk'):require(row.get('APK_CRC_verified')is True,'Publication APK CRC proof missing')
    require(proof.get('new_APK_produced')is(apk_info is not None)and proof.get('apk')==apk_info,'Publication optional APK binding differs')
    require(summary.get('status') == 'passed' and summary.get('failures') == 0 and fresh.get('startup_failures') == 0 and fresh.get('feature_failures') == 0, 'Functional and startup checks must pass')
    suites = summary['suites']
    require(len(suites) == len({row['name'] for row in suites}) and all(row['status'] == 'passed' and row['failures'] == 0 for row in suites), 'Unique passing suites required')
    previous = json.loads((root / 'validation/mission-expressions-2026-11-18/final-regression/summary.json').read_text())
    prior_names = {row['name'] for row in previous['suites']}
    require(previous.get('status') == 'passed' and previous.get('checks') == 268281 and len(prior_names) == 53, 'Pinned previous regression summary differs')
    require(prior_names <= {row['name'] for row in suites}, 'A previous regression suite was omitted')
    require('build_version' in {row['name'] for row in suites}, 'Current version suite required')
    added = [row for row in suites if row['name'] not in prior_names]
    require(REQUIRED_NEW_SUITES <= {row['name'] for row in added}, 'Required new model/store/task/runtime suites are missing')
    checks = sum(row['checks'] for row in suites)
    new_checks = sum(row['checks'] for row in added)
    require(checks == summary['checks'] == manifest['current_functional_checks'] == fresh['unique_feature_checks_separate'] and len(suites) == manifest['unique_suites'] == fresh['unique_feature_scripts_separate'], 'Functional counts differ')
    require(new_checks == manifest['new_core_checks'] and len(added) == manifest['new_core_suites'], 'New core counts differ')
    for manifest_key, fresh_key in {
        'runtime_inputs': 'runtime_inputs_verified',
        'merged_source_files': 'source_actual_files',
        'previous_backend_runtime_inputs': 'previous_backend_runtime_inputs',
        'unchanged_previous_backend_runtime_inputs': 'unchanged_previous_backend_runtime_inputs',
        'unchanged_published_game_runtime_inputs': 'unchanged_published0_28_runtime_inputs',
        'native_generator_count': 'native_generator_count',
        'native_main_generator_count': 'main_native_generator_count',
        'native_DOS_control_cases_separate': 'native_DOS_control_cases_separate',
        'native_JJFFE_diagnostics_separate': 'native_JJFFE_copy_diagnostics_separate',
        'supplemental_native_compositions_separate': 'supplemental_native_composition_cases_separate',
        'resource_replay_count': 'resource_replay_count',
    }.items():
        require(manifest[manifest_key] == fresh[fresh_key], 'Manifest/fresh count differs: ' + manifest_key)
    require(fresh.get('all_source_files_unchanged') is True and fresh.get('all_native_fixtures_byte_exact') is True and fresh.get('all_resource_replays_byte_exact') is True, 'Portable source/native/resource proof required')
    require(manifest.get('new_kernels_connected_to_Main') is False and manifest.get('physical_device_tested') is False and manifest.get('Android_version_code') == 56, 'Source-only publication scope differs')
    changed = fresh['changed_previous_backend_runtime_inputs']
    runtime = fresh['runtime_inputs_verified']
    old_runtime = fresh['previous_backend_runtime_inputs']
    unchanged = fresh['unchanged_previous_backend_runtime_inputs']
    published_runtime = fresh['unchanged_published0_28_runtime_inputs']
    startup = fresh['startup_checks']
    source_files = fresh['source_actual_files']
    native = fresh['native_generator_count']
    primary = fresh['main_native_generator_count']
    supplemental = fresh['supplemental_native_generator_count']
    dos = fresh['native_DOS_control_cases_separate']
    jjffe = fresh['native_JJFFE_copy_diagnostics_separate']
    compositions = fresh['supplemental_native_composition_cases_separate']
    update = manifest['files'][UPDATE_NAME]
    zip_url = public_base + UPDATE_NAME
    fresh_url = public_base + 'source-pair-verification.json'
    block = f'''**19 ноября 2026: опубликовано исходное ядро записи параметров и задач миссий.**
Процедуры замены моделей, записи параметров и задач миссий проверены
как отдельные исходные модули. [Контракт и границы](docs/SOURCE_MISSION_TASKS_RU.md).
Полный мировой цикл и подключение новых ядер к Main остаются следующими
блоками. Исходная версия — **0.31.0-tasks-alpha1 / code 56**.

Для полного проекта: [основа 0.28]({base['url']}) +
[кумулятивное обновление, {number(update['bytes'])} байт]({zip_url}).
Сначала распакуйте основу, затем обновление в ту же папку
`StarFrontier-0.28.0-source/`. Прежние малые обновления не требуются.

**{number(checks)} проверок / {len(suites)} наборов / 0 ошибок**;
новых наборов — **{len(added)}**, проверок в них — **{number(new_checks)}**.
Чистая пара ZIP: запуск **{startup}/0**, все **{len(suites)} наборов /
{number(checks)}/0**, все **{source_files}** исходных файлов неизменны
и **{runtime}** runtime-входов совпадают с freeze. Все **{unchanged}**
входов прежнего ядра и **{published_runtime}** входа опубликованной
игры сохранены побайтно. **{native} native-команд** ({primary} основных /
{supplemental} дополнительных) повторили **{number(dos)} DOS-контролей**,
**{jjffe}** отдельных диагностик JJFFE и **{compositions}** композиционных
сценариев без приватного EXE. Три ресурсных экстрактора восстановили
точные JSON столкновений, миссий и моделей из исходных диапазонов байтов; эти повторы не прибавлены
к функциональной сумме. **{expected_count}** полных HTTPS-загрузок, SHA/размеры, CRC
и Git-комментарии обоих ZIP проверены. [Подтверждение]({proof_rel}).'''
    publication = f'''Для полного проекта нужны **два ZIP**: [полная основа 0.28]({base['url']})
и [кумулятивное обновление]({zip_url}). Сначала распакуйте основу,
затем обновление в ту же папку `StarFrontier-0.28.0-source/`.
Предыдущие малые обновления не требуются. Оба ZIP меньше 32 МиБ;
обновление отдельно неполно. Включены исходники, тесты, ресурсы,
текстовые доказательства и переносимые генераторы с зависимостями.

Source-коммит: `{source_commit}`.
Artifact-коммит: `{artifact_commit}`.
Обновление: **{number(update['bytes'])} байт**, SHA256
`{update['sha256']}`.
Из чистой пары проверены запуск **{startup}/0**, все **{len(suites)} наборов /
{number(checks)}/0**, **{source_files}** неизменных файлов и **{runtime}**
runtime-входов. Все **{unchanged}** входов прежнего ядра
и **{published_runtime}** входа игры совпадают побайтно.
Только две строки версии в каждом из BuildInfo/export обновлены до0.31/code56; Main прежний.
**{native} native-команды** ({primary} основных / {supplemental} дополнительных)
воспроизвели **{number(dos)} DOS-контролей**, **{jjffe}** диагностик JJFFE
и **{compositions}** отдельных композиционных сценариев без приватного EXE.
Три экстрактора восстановили точные ресурсные JSON; эти категории
не прибавлены к функциональной сумме. **{expected_count}** полных HTTPS-загрузок,
размеры/SHA/CRC и Git-комментарии обоих ZIP совпали.
[Подтверждение](../{proof_rel}) и
[отчёт чистой проверки]({fresh_url}).

Архив и манифест запечатаны перед проверкой опубликованных загрузок и
остаются неизменными. PREPUB-записи внутри ZIP относятся к исходному
коммиту до публикации; окончательное подтверждение сохранено отдельно.
Новые ядра ещё не подключены к Main; исходная версия — **0.31.0-tasks-alpha1 / code 56**.
Физический S23 Ultra, графика и FPS этим исходным блоком не проверялись.'''
    if apk_info is not None:
        apk_url=public_base+apk_info['file']
        apk_text='\n\n[Техническая APK0.31 / code56]('+apk_url+'): ARM64, прежняя TEST-подпись, версия/пакет/CRC проверены. Новые ядра ещё не подключены к Main; физический S23 Ultra не проверялся.'
        block+=apk_text;publication+=apk_text
    edits = {}
    for name in ['README.md', 'SOURCE_ARCHIVE_RU.md', 'docs/RECOVERY_AND_ROADMAP_RU.md']:
        path = root / name
        text = block
        if name.startswith('docs/'):
            text = text.replace('(docs/SOURCE_MISSION_TASKS_RU.md)', '(SOURCE_MISSION_TASKS_RU.md)').replace('(' + proof_rel + ')', '(../' + proof_rel + ')')
        edits[path] = replace_marker(path.read_text(), 'MISSION_TASKS_CORE_CURRENT', text)
    detail = root / 'docs/SOURCE_MISSION_TASKS_RU.md'
    edits[detail] = replace_marker(detail.read_text(), 'MISSION_TASKS_PUBLICATION', publication)
    verifier = args.download_verifier.resolve()
    require(verifier.is_file(), 'Portable download verifier missing')
    destination = proof_path.parent / 'verify_downloads.py'
    verifier_raw = verifier.read_bytes()
    require(not destination.exists() or destination.read_bytes() == verifier_raw, 'Refuse to replace a different archived download verifier')
    # All identities and all four marker edits are validated before publication.
    for path, raw in edits.items():
        path.write_text(raw)
    if verifier != destination:
        shutil.copyfile(verifier, destination)
    require(all(sha(path.read_bytes()) == digest for path, digest in sealed.items()), 'Sealed ZIP/manifest/payload bytes changed during documentation publication')
    print(json.dumps({'status': 'documentation_updated', 'source_commit': source_commit, 'artifact_commit': artifact_commit, 'functional_checks': checks, 'runtime_inputs': runtime, 'updated_files': [str(path.relative_to(root)) for path in edits], 'sealed_payloads_unchanged': True}, ensure_ascii=False))

if __name__ == '__main__':
    main()
