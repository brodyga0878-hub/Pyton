#!/usr/bin/env python3
"""Finalize local evidence docs only after verified source/APK/HTTPS publication.

This never builds, uploads, republishes, or changes the sealed payloads. Run the
separate marker publisher first. Archived PREPUB text remains the source-time
record. This script is intentionally inert until main() is invoked explicitly.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import zipfile

CHECKPOINT = 'mission-statements-core-0.32.0-2026-11-19'
V = 'validation/mission-statements-2026-11-19'
PUBLICATION = 'validation/mission-statements-publication-2026-11-19'
UPDATE = 'StarFrontier-0.32.0-mission-statements-source-update.zip'
VERSION = '0.32.0-statements-alpha1'
CODE = 57
CERT = '16f47f20a2d2aca3de1fe893ddfa01e90acf2d6b98b32ca772bb914c9ee21e25'
FINAL_MARKER = 'MISSION_STATEMENTS_FINAL_EVIDENCE'
HELPERS = {
    'prepare-mission-statements-bundle.py': 'prepare_bundle.py',
    'verify-mission-statements-downloads.py': 'verify_downloads.py',
    'publish-mission-statements-docs.py': 'publish_docs.py',
    'record-mission-statements-android-provenance.py': 'record_android_provenance.py',
    'seal-mission-statements-validation.py': 'seal_validation.py',
    'archive-mission-statements-fresh-logs.py': 'archive_source_pair_logs.py',
}


def require(ok, reason):
    if not ok:
        raise ValueError(reason)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def load(path):
    raw = path.read_bytes()
    return json.loads(raw), sha(raw)


def number(value):
    require(type(value) is int and value >= 0, 'A measured nonnegative integer is required')
    return f'{value:,}'.replace(',', ' ')


def unique_replace(text, old, new):
    if new in text and old not in text:
        return text
    require(text.count(old) == 1, 'Expected source-phase wording is absent or ambiguous: ' + old[:100])
    return text.replace(old, new)


def append_marker(text, body):
    begin = '<!-- ' + FINAL_MARKER + '_BEGIN -->'
    end = '<!-- ' + FINAL_MARKER + '_END -->'
    replacement = begin + '\n' + body + '\n' + end
    if begin not in text:
        require(end not in text, 'Unpaired final evidence marker')
        return text.rstrip() + '\n\n' + replacement + '\n'
    require(text.count(begin) == text.count(end) == 1, 'Final evidence marker must be unique')
    return re.sub(re.escape(begin) + '.*?' + re.escape(end), lambda _: replacement, text, flags=re.S)


def replace_source_phase(text, body):
    begin = '<!-- MISSION_STATEMENTS_SOURCE_PHASE_BEGIN -->'
    end = '<!-- MISSION_STATEMENTS_SOURCE_PHASE_END -->'
    require(text.count(begin) == text.count(end) == 1, 'Unique source-phase paragraph required')
    return re.sub(re.escape(begin) + '.*?' + re.escape(end), lambda _: begin + '\n' + body + '\n' + end, text, flags=re.S)


def publication_marker(text):
    begin = '<!-- MISSION_STATEMENTS_PUBLICATION_BEGIN -->'
    end = '<!-- MISSION_STATEMENTS_PUBLICATION_END -->'
    require(text.count(begin) == text.count(end) == 1, 'Contract publication marker is required')
    return text[text.index(begin):text.index(end) + len(end)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=Path('/workspace/Pyton'))
    parser.add_argument('--publication-proof', type=Path)
    parser.add_argument('--helpers-dir', type=Path, default=Path('/workspace/recovery'))
    args = parser.parse_args()
    root = args.repo.resolve()
    release = root / 'deliverables' / CHECKPOINT
    pub = root / PUBLICATION
    proof_path = args.publication_proof.resolve() if args.publication_proof else pub / 'verification.json'
    require(proof_path.parent == pub, 'Publication evidence must be in the current publication directory')
    helpers_dir = args.helpers_dir.resolve()
    def helper_file(name):
        original = helpers_dir / name
        archived = helpers_dir / HELPERS[name]
        return original if original.is_file() else archived
    publisher_path = helper_file('publish-mission-statements-docs.py')
    spec = importlib.util.spec_from_file_location('mission_tasks_marker_publisher', publisher_path)
    require(spec is not None and spec.loader is not None, 'Marker publisher helper is unavailable')
    publisher = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(publisher)  # definitions only; never invokes its main()

    manifest_path = release / 'manifest.json'
    manifest, manifest_sha = load(manifest_path)
    require(manifest.get('schema') == 'starfrontier-mission-statements-core-0.32.0-source-checkpoint-v1' and manifest.get('checkpoint') == CHECKPOINT, 'Actual sealed checkpoint manifest required')
    payloads, apk_info = publisher.declared_payloads(manifest)
    require(apk_info is not None and manifest.get('fresh_pair_verified') is True, 'Actual APK and source-pair proof are mandatory for finalization')
    source = manifest.get('source_commit', '')
    require(re.fullmatch('[0-9a-f]{40}', source) is not None, 'Immutable full source commit required')
    sealed = {manifest_path: manifest_sha}
    for name, expected in manifest['files'].items():
        path = release / name
        raw = path.read_bytes()
        require(len(raw) == expected.get('bytes') and sha(raw) == expected.get('sha256'), 'Sealed payload differs: ' + name)
        sealed[path] = sha(raw)

    freeze_path = root / V / 'runtime-freeze.json'
    freeze, freeze_sha = load(freeze_path)
    sealed[freeze_path] = freeze_sha
    fresh_path = release / 'source-pair-verification.json'
    fresh, fresh_sha = load(fresh_path)
    summary, _ = load(release / 'functional-summary.json')
    android_path = release / apk_info['verification_file']
    android, android_sha = load(android_path)
    proof, proof_sha = load(proof_path)
    provenance_path = root / V / 'android-build-provenance.json'
    provenance, provenance_sha = load(provenance_path)
    sealed[provenance_path] = provenance_sha
    require(freeze.get('source_game_version') == VERSION and freeze.get('source_android_code') == CODE, 'Frozen source version differs')
    require(fresh.get('ok') is True and fresh.get('status') == 'verified' and fresh.get('source_commit') == source and fresh.get('runtime_freeze_sha256') == freeze_sha, 'Verified fresh source identity differs')
    require(fresh.get('all_source_files_unchanged') is True and fresh.get('all_native_fixtures_byte_exact') is True and fresh.get('all_resource_replays_byte_exact') is True and fresh.get('all_runtime_inputs_match_frozen_source') is True, 'Source/native/resource ownership proofs are incomplete')
    require(fresh.get('startup_failures') == fresh.get('feature_failures') == 0, 'Fresh startup and feature checks must pass')
    require(summary.get('status') == 'passed' and summary.get('failures') == 0, 'Final functional summary must pass')
    suites = summary.get('suites', [])
    require(isinstance(suites, list) and suites and len(suites) == len({row['name'] for row in suites}) and all(row.get('status') == 'passed' and row.get('failures') == 0 for row in suites), 'Unique passing functional suites required')
    checks = sum(row['checks'] for row in suites)
    require(checks == summary['checks'] == manifest['current_functional_checks'] == fresh['unique_feature_checks_separate'] and len(suites) == manifest['unique_suites'] == fresh['unique_feature_scripts_separate'], 'Final functional totals disagree')
    require(len(freeze['files_sha256']) == freeze['runtime_input_count'] == fresh['runtime_inputs_verified'] == manifest['runtime_inputs'], 'Frozen runtime counts disagree')
    for name, digest in freeze['files_sha256'].items():
        require(sha((root / name).read_bytes()) == digest, 'Current frozen runtime input differs: ' + name)
    require(manifest['unchanged_previous_backend_runtime_inputs'] == fresh['unchanged_previous_backend_runtime_inputs'] and manifest['unchanged_published_game_runtime_inputs'] == fresh['unchanged_published0_28_runtime_inputs'], 'Unchanged prior/published counts disagree')
    for manifest_key, fresh_key in {
        'merged_source_files': 'source_actual_files', 'native_generator_count': 'native_generator_count',
        'native_main_generator_count': 'main_native_generator_count',
        'native_DOS_control_cases_separate': 'native_DOS_control_cases_separate',
        'native_JJFFE_diagnostics_separate': 'native_JJFFE_copy_diagnostics_separate',
        'supplemental_native_compositions_separate': 'supplemental_native_composition_cases_separate',
        'resource_replay_count': 'resource_replay_count',
    }.items():
        require(manifest[manifest_key] == fresh[fresh_key], 'Sealed source count differs: ' + manifest_key)

    require(android.get('schema') == 'starfrontier-mission-statements-android-verification-v1' and android.get('status') == 'verified', 'Independent actual APK verification required')
    require(android.get('source_commit') == source and android.get('runtime_freeze_sha256') == freeze_sha and android.get('runtime_inputs_verified') == len(freeze['files_sha256']), 'APK frozen-source identity differs')
    require(android.get('version') == VERSION and android.get('version_code') == CODE and android.get('package') == 'org.starfrontier.rebuild' and android.get('certificate_sha256') == CERT and android.get('abi') == 'arm64-v8a', 'Actual APK identity differs')
    require(android.get('signature_verified') is True and android.get('test_key_only') is True and android.get('zipalign_16k') is True and android.get('runtime_inputs_match_frozen_source') is True and android.get('source_pair_verified') is True and android.get('compiled_source_correspondence_rebuilt_by_verifier') is True, 'APK ownership, signature or independent compilation proof is incomplete')
    compiled = android.get('compiled_modules', {})
    resources = android.get('data_assets_sha256', {})
    rebuilt = android.get('independent_android_recompilation', {})
    require(isinstance(compiled, dict) and compiled and isinstance(resources, dict) and resources and rebuilt.get('all_compiled_script_bytes_match') is True and rebuilt.get('actual_engine_pack_mounted') is True and rebuilt.get('compiled_script_count') == len(compiled), 'Every actual APK script must match independent frozen-source compilation')
    require(android.get('bytes') == apk_info['bytes'] and android.get('sha256') == apk_info['sha256'], 'Actual APK hash/size differs')
    with zipfile.ZipFile(release / apk_info['file']) as archive:
        require(archive.testzip() is None, 'Local actual APK CRC failure')
    require(provenance.get('schema') == 'starfrontier-mission-statements-android-build-provenance-v1' and provenance.get('status') == 'verified' and provenance.get('source_commit') == source, 'Completed Android build provenance required')
    require(provenance.get('runtime_freeze_sha256') == freeze_sha and provenance.get('source_pair_verification_sha256') == fresh_sha and provenance.get('android_verification_sha256') == android_sha and provenance.get('apk_sha256') == apk_info['sha256'] and provenance.get('apk_bytes') == apk_info['bytes'] and provenance.get('fresh_export_exit_code') == 0, 'Android build provenance is not bound to these exact artifacts')
    require(provenance.get('compiled_scripts') == len(compiled) and provenance.get('exact_JSON_resources') == len(resources) and provenance.get('all_runtime_inputs_unchanged_through_compilation') is True and provenance.get('compiled_source_correspondence_independently_verified') is True, 'Android provenance totals/compilation proof differ')
    build_log = root / V / provenance['build_log']
    require(build_log.parent == root / V and sha(build_log.read_bytes()) == provenance['build_log_sha256'], 'Archived Android build log differs')
    for document in [manifest, android, proof]:
        require(document.get('new_kernels_connected_to_Main') is False and document.get('physical_device_tested') is False, 'Unexpected Main/device claims')

    artifact = proof.get('artifact_commit', '')
    require(re.fullmatch('[0-9a-f]{40}', artifact) is not None, 'Immutable artifact commit required')
    require(proof.get('schema') == 'starfrontier-mission-statements-core-0.32.0-source-publication-v1' and proof.get('status') == 'verified' and proof.get('checkpoint') == CHECKPOINT and proof.get('source_commit') == source and proof.get('runtime_freeze_sha256') == freeze_sha and proof.get('all_current_runtime_inputs_match_frozen_source') is True, 'Verified final HTTPS publication/freeze binding required')
    require(proof.get('new_APK_produced') is True and proof.get('apk') == apk_info and proof.get('all_manifest_payloads_downloaded') is True and proof.get('required_source_archives_downloaded') == 2, 'Actual published APK and both source archives must be verified')
    public_base = 'https://raw.githubusercontent.com/brodyga0878-hub/Pyton/' + artifact + '/deliverables/' + CHECKPOINT + '/'
    expected = {'manifest.json': {'url': public_base + 'manifest.json', 'bytes': manifest_path.stat().st_size, 'sha256': manifest_sha}}
    expected.update({name: {'url': public_base + name, **row} for name, row in manifest['files'].items()})
    base = manifest['base_archive']
    base_name = Path(base['url']).name
    expected[base_name] = {'url': base['url'], 'bytes': base['bytes'], 'sha256': base['sha256']}
    records = proof.get('files', [])
    require(len(records) == len(expected) == proof.get('actual_complete_HTTPS_downloads') == len(payloads) + 2 and len({row.get('file') for row in records}) == len(records) and {row.get('file') for row in records} == set(expected), 'Every complete immutable HTTPS download must be verified')
    for row in records:
        require(row.get('http_status') == 200 and all(row.get(key) == value for key, value in expected[row['file']].items()), 'Published payload URL/hash/size differs: ' + row['file'])
        if row['file'].endswith('.zip'):
            require(row.get('zip_CRC_verified') is True and row.get('source_commit_in_ZIP_comment') == (base['source_commit'] if row['file'] == base_name else source), 'Published ZIP CRC/source identity differs')
        if row['file'].endswith('.apk'):
            require(row.get('APK_CRC_verified') is True, 'Published APK CRC proof required')

    contract = root / 'docs/SOURCE_MISSION_STATEMENTS_RU.md'
    contract_text = contract.read_text()
    untouched_contract_marker = publication_marker(contract_text)
    require(source in untouched_contract_marker and artifact in untouched_contract_marker and public_base + apk_info['file'] in untouched_contract_marker, 'Run the separate marker publisher after verified HTTPS proof, before this finalizer')
    contract_text = replace_source_phase(contract_text, f'Блок **{VERSION} / code {CODE}** исполняет отдельно проверенные F39/F40, команды F41 и составление VM. Замороженный прогон: **{len(suites)} наборов / {number(checks)} проверок / 0 ошибок**. Техническая APK, чистое восстановление пары ZIP и опубликованные загрузки подтверждены отдельными отчётами. PREPUB внутри замороженного ZIP отражает момент исходного коммита; окончательные подтверждения сохранены отдельно.')
    require(publication_marker(contract_text) == untouched_contract_marker, 'Finalizer must not modify the separate contract publication marker')
    facts = f'''Публикация версии **{VERSION} / code {CODE}** подтверждена отдельными отчётами. Source-коммит `{source}`; artifact-коммит `{artifact}`.

Чистая пара ZIP: запуск {fresh['startup_checks']}/0, **{len(suites)} наборов / {number(checks)} проверок / 0 ошибок**, {fresh['source_actual_files']} неизменных исходных файлов и {fresh['runtime_inputs_verified']} runtime-входов. Все {fresh['unchanged_previous_backend_runtime_inputs']} прочих прежних и {fresh['unchanged_published0_28_runtime_inputs']} прочих опубликованных игровых входов совпали побайтно; Main сохранён. Повторены {fresh['native_generator_count']} native-команд ({fresh['main_native_generator_count']} основных / {fresh['supplemental_native_generator_count']} дополнительных), {number(fresh['native_DOS_control_cases_separate'])} основных DOS-контролей, отдельно {fresh['native_JJFFE_copy_diagnostics_separate']} диагностик JJFFE, {fresh['supplemental_native_composition_cases_separate']} композиционных сценариев и {fresh['resource_replay_count']} ресурсных извлечения. Повторы не прибавлены к функциональной сумме.

Кумулятивный ZIP: **{number(manifest['files'][UPDATE]['bytes'])} байт**, SHA256 `{manifest['files'][UPDATE]['sha256']}`. Он дополняет полную основу 0.28 в папке `StarFrontier-0.28.0-source/`; одно обновление неполно.

Техническая APK: **{number(apk_info['bytes'])} байт**, SHA256 `{apk_info['sha256']}`, ARM64, прежняя TEST-подпись. Фактические manifest/BuildInfo, CRC и выравнивание проверены; все **{len(compiled)}** экспортированных скриптов совпали с независимой Android-компиляцией замороженных исходников, все **{len(resources)}** JSON-ресурсов совпали с исходными байтами. Проверены **{len(records)}** полных HTTPS-загрузок, размеры/SHA256, CRC и source-комментарии ZIP.

Замороженные ZIP, manifest, payload и runtime-freeze не изменены. PREPUB внутри архивов относится к исходному моменту до этих последующих проверок. Новые ядра ещё не подключены к Main; оставшиеся мировые службы, физический S23 Ultra, графика и FPS этим подтверждением не заявлены.'''
    edits = {contract: contract_text}
    for relative in [V + '/AUDIT_RU.md', V + '/WORK_LOG_RU.md']:
        path = root / relative
        text = path.read_text()
        text = replace_source_phase(text, f'Версия **{VERSION} / code {CODE}**. Замороженный прогон: **{len(suites)} наборов / {number(checks)} проверок / 0 ошибок**. После исходного freeze подтверждены фактическая APK, чистая пара ZIP и полные HTTPS-загрузки; итоговые факты сохранены ниже. PREPUB внутри архивов остаётся записью исходного момента. Новые ядра остаются вне Main; необслуженные мировые/форматирующие службы имеют самостоятельные границы.')
        text = text.replace('## Упаковка и необходимые проверки — PREPUB', '## Упаковка и подтверждённый комплект')
        # Both documents are directly under validation/<checkpoint>/.
        link = '../mission-statements-publication-2026-11-19/verification.json'
        body = facts + '\n\n[Проверка опубликованных загрузок](' + link + '); [воспроизводимые помощники](' + link.replace('verification.json', 'README.md') + ').'
        edits[path] = append_marker(text, body)

    versioning = root / 'docs/VERSIONING_RU.md'
    text = versioning.read_text()
    latest_pattern = r'Последняя опубликованная(?: техническая)? APK — \*\*[^*]+\*\*, code\d+; [^\n]+'
    require(len(re.findall(latest_pattern, text)) == 1, 'Unique current published APK wording is required')
    latest_text = 'Последняя опубликованная техническая APK — **0.32.0-statements-alpha1**, code57; фактическая сборка и независимое соответствие исходникам подтверждены отдельными отчётами.'
    text = re.sub(latest_pattern, lambda _: latest_text, text)
    version_body = f'''Для 0.32 `tools/verify_statements_android.py` подтвердил фактические code57/BuildInfo, ARM64, прежнюю TEST-подпись, CRC и выравнивание. Все **{len(compiled)}** экспортированных скриптов совпали с независимой Android-компиляцией проверенной замороженной пары исходников; **{len(resources)}** JSON-ресурсов совпали побайтно. Source-коммит `{source}`, artifact-коммит `{artifact}`. APK имеет SHA256 `{apk_info['sha256']}` и размер {number(apk_info['bytes'])} байт.

[APK0.32]({public_base + apk_info['file']}), [доказательство APK]({public_base + apk_info['verification_file']}) и [проверка {len(records)} полных опубликованных загрузок](../{PUBLICATION}/verification.json). Исторические проверки 0.28/0.29/0.30/0.31 сохранены; новые ядра остаются вне Main. Физический S23 Ultra и FPS не проверялись.'''
    edits[versioning] = append_marker(text, version_body)

    copies = {}
    for name, archived in HELPERS.items():
        path = helper_file(name)
        require(path.is_file(), 'Required executed helper is missing: ' + name)
        copies[pub / archived] = path.read_bytes()
    copies[pub / 'finalize_evidence.py'] = Path(__file__).read_bytes()
    for path, raw in copies.items():
        require(not path.exists() or path.read_bytes() == raw, 'Refuse to overwrite different archived helper: ' + path.name)
    readme = f'''# Проверка публикации версии 0.32

`verification.json` подтверждает {len(records)} полных HTTPS-загрузок неизменяемого artifact-коммита `{artifact}`: APK, оба исходных ZIP, manifest и объявленные подтверждения. Source-коммит — `{source}`. Размеры/SHA256, CRC и source-комментарии ZIP совпали. Исходные ZIP, manifest и payload после публикации не менялись; PREPUB внутри них относится к моменту исходного коммита.

`verify_downloads.py`, `prepare_bundle.py`, `publish_docs.py` — точные копии помощников проверки загрузок, запечатывания комплекта и обновления четырёх marker-разделов. `record_android_provenance.py` фиксирует завершённую фактическую сборку и независимое соответствие APK исходникам. `seal_validation.py` сохраняет полный локальный regression/freeze. `archive_source_pair_logs.py` архивирует уже выполненные логи чистого восстановления. Эти исторические скрипты сохраняют исходные пути рабочего окружения; перед воспроизведением их входы и путь репозитория должны соответствовать указанному source-коммиту. Запечатывание и архивирование не повторяют поверх существующего результата.

Сначала повторяют исходные генераторы/проверку пары из `validation/mission-statements-2026-11-19/tools`, затем реальную сборку Android и `tools/verify_statements_android.py`. После успешной сборки выполняют запись provenance с фактически наблюдавшимся exit code, подготовку manifest и проверку полных HTTPS-загрузок точного artifact-коммита. `publish_docs.py` меняет только текущие marker-разделы после этих подтверждений.

`finalize_evidence.py` обновляет последующую локальную документацию только после всех подтверждений и marker-публикации:

```sh
python finalize_evidence.py --repo /workspace/Pyton --helpers-dir .
```

Он проверяет точные SHA payload, source/freeze/APK/provenance/publication-связи, независимое совпадение всех {len(compiled)} скриптов и {len(resources)} JSON, затем дополняет AUDIT/WORK_LOG/VERSIONING и вводное описание контракта. Четыре marker-раздела принадлежат отдельному publisher и здесь не переписываются. Manifest, ZIP/APK, freeze, тесты и native-доказательства не меняются. `final-documentation.json` фиксирует входные хеши и изменённые документы.

Новые ядра ещё не подключены к Main; Неперенесённые службы мира остаются явными границами. Физический S23 Ultra, графика и FPS не заявлены.
'''
    require(publication_marker(edits[contract]) == untouched_contract_marker, 'Contract publication marker unexpectedly changed')
    for path, text in edits.items():
        if path == contract:
            outside = text.replace(untouched_contract_marker, '')
        else:
            outside = text
        require('ещё не опубликован' not in outside and 'пока имеют статус **PREPUB**' not in outside, 'Stale unpublished current facts remain: ' + str(path))
    require(all(sha(path.read_bytes()) == digest for path, digest in sealed.items()), 'Sealed input changed before documentation update')
    # All input/identity/text/archive validations finish before the first write.
    for path, text in edits.items():
        path.write_text(text)
    pub.mkdir(parents=True, exist_ok=True)
    for path, raw in copies.items():
        if not path.exists():
            path.write_bytes(raw)
    (pub / 'README.md').write_text(readme)
    require(all(sha(path.read_bytes()) == digest for path, digest in sealed.items()), 'Sealed payload/freeze bytes changed during final documentation update')
    result = {
        'schema': 'starfrontier-mission-statements-final-documentation-v1', 'status': 'verified',
        'source_commit': source, 'artifact_commit': artifact,
        'manifest_sha256': manifest_sha, 'publication_proof_sha256': proof_sha,
        'source_pair_verification_sha256': fresh_sha, 'android_verification_sha256': android_sha,
        'android_provenance_sha256': provenance_sha, 'runtime_freeze_sha256': freeze_sha,
        'functional_suites': len(suites), 'functional_checks': checks,
        'runtime_inputs': len(freeze['files_sha256']), 'actual_complete_HTTPS_downloads': len(records),
        'compiled_scripts': len(compiled), 'exact_JSON_resources': len(resources),
        'updated_documents_sha256': {str(path.relative_to(root)): sha(path.read_bytes()) for path in edits},
        'archived_helpers_sha256': {path.name: sha(raw) for path, raw in copies.items()},
        'sealed_payloads_and_freeze_unchanged': True,
        'publication_markers_changed_by_this_script': False,
        'Main_integrated': False, 'physical_device_tested': False,
    }
    (pub / 'final-documentation.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'status': 'final_documentation_updated', 'source_commit': source, 'artifact_commit': artifact, 'checks': checks, 'updated_documents': list(result['updated_documents_sha256']), 'sealed_inputs_unchanged': True}, ensure_ascii=False))


if __name__ == '__main__':
    main()
