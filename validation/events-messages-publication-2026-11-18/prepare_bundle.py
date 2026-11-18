"""Seal five reviewed source payloads after fresh source-pair verification.

The source ZIP and source-pair report must already exist. This does not build
an APK, run tests, push Git or claim that HTTP publication has been verified.
"""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import shutil
import os
import subprocess
import zipfile

CHECKPOINT = 'events-messages-core-0.29.0-2026-11-18'
VALIDATION = 'validation/events-messages-2026-11-18'
UPDATE_NAME = 'StarFrontier-0.29.0-events-messages-source-update.zip'
REQUIRED_NEW_SUITES = {'source_events', 'source_events_state', 'source_messages', 'source_player_events', 'source_event_services', 'build_version'}
ALLOWED_CHANGED = {'scripts/build_info.gd','export_presets.cfg'}
BASE = {
    'url': 'https://raw.githubusercontent.com/brodyga0878-hub/Pyton/f6d802e5f34f735eef91fdc2670bc8850443511a/deliverables/0.28.0-native-station-alpha1/StarFrontier-0.28.0-native-station-source.zip',
    'bytes': 33543341,
    'sha256': '830e7219879f694a24e41f579417986f936902f6592926ff8e84dc99217b6c2d',
    'source_commit': 'de8eb18a687d007781321436910187dff3785775',
}

def require(ok, reason):
    if not ok:
        raise ValueError(reason)

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def number(value):
    return f'{value:,}'.replace(',', ' ')

EXPECTED_VERSION='0.29.0-events-alpha1'
EXPECTED_CODE=54
EXPECTED_PACKAGE='org.starfrontier.rebuild'
EXPECTED_CERT='16f47f20a2d2aca3de1fe893ddfa01e90acf2d6b98b32ca772bb914c9ee21e25'

def verify_apk(apk,proof,source_commit,freeze_sha,build_tools):
    raw=apk.read_bytes()
    require(re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*\.apk',apk.name)is not None,'Unsafe APK filename')
    require(proof.get('version')==EXPECTED_VERSION and proof.get('version_code')==EXPECTED_CODE and proof.get('package')==EXPECTED_PACKAGE,'APK proof version/package differs')
    require(proof.get('sha256')==sha(raw) and proof.get('bytes')==len(raw),'APK proof SHA/bytes differ')
    require(proof.get('source_commit')==source_commit and proof.get('runtime_freeze_sha256')==freeze_sha and proof.get('runtime_inputs_match_frozen_source')is True,'APK must bind the exact verified source/freeze')
    require(proof.get('abi')=='arm64-v8a' and proof.get('signature_verified')is True and proof.get('certificate_sha256')==EXPECTED_CERT and proof.get('test_key_only')is True,'APK ABI or TEST signature proof differs')
    require(proof.get('zipalign_16k')is True and bool(proof.get('elf_load_alignment')) and proof.get('forbidden_permissions_absent')is True and proof.get('physical_device_tested')is False and proof.get('new_kernels_connected_to_Main')is False,'APK technical or Main/device scope differs')
    require(proof.get('toolchain_smoke_only',False)is False,'Toolchain-only APK is not a game artifact')
    require(proof.get('compiled_source_correspondence_rebuilt_by_verifier')is True and proof.get('all_script_bytecode_headers_valid')is True,'Every APK script must match an independent frozen-source Android compilation')
    require(proof.get('embedded_build_info')=={'version':EXPECTED_VERSION,'version_code':EXPECTED_CODE,'channel':'rebuild-alpha-test','actual_exported_bytecode_loaded':True},'Actual exported diagnostic/menu version is not verified')
    recompiled=proof.get('independent_android_recompilation',{})
    require(recompiled.get('all_compiled_script_bytes_match')is True and recompiled.get('actual_engine_pack_mounted')is True and type(recompiled.get('compiled_script_count'))is int and recompiled['compiled_script_count']>0,'Independent Android bytecode correspondence proof missing')
    with zipfile.ZipFile(apk)as archive:require(archive.testzip()is None,'APK CRC failed')
    env=os.environ.copy();jdk=Path('/workspace/toolchains/jdk17')
    if (jdk/'bin/java').is_file():env['JAVA_HOME']=str(jdk);env['PATH']=str(jdk/'bin')+os.pathsep+env.get('PATH','')
    def run(args):
        done=subprocess.run(args,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=120)
        require(done.returncode==0,'APK read-only tool verification failed: '+Path(args[0]).name)
        return done.stdout
    badging=run([str(build_tools/'aapt'),'dump','badging',str(apk)])
    package=re.search(r"package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'",badging)
    require(package and package.groups()==(EXPECTED_PACKAGE,str(EXPECTED_CODE),EXPECTED_VERSION),'Actual APK aapt version/package differs')
    abi=re.search(r'^native-code:(.*)$',badging,re.M)
    require(abi and re.findall(r"'([^']+)'",abi[1])==['arm64-v8a'],'Actual APK is not ARM64-only')
    signed=run([str(build_tools/'apksigner'),'verify','--verbose','--print-certs',str(apk)])
    certificate=re.search(r'certificate SHA-256 digest: ([0-9a-fA-F]+)',signed)
    require(certificate and certificate[1].lower()==EXPECTED_CERT,'Actual APK signature differs from the prior TEST certificate')
    run([str(build_tools/'zipalign'),'-c','-P','16','-v','4',str(apk)])
    return {'file':apk.name,'verification_file':'android-verification.json','bytes':len(raw),'sha256':sha(raw),'version':EXPECTED_VERSION,'version_code':EXPECTED_CODE,'package':EXPECTED_PACKAGE,'abi':'arm64-v8a','certificate_sha256':EXPECTED_CERT,'source_commit':source_commit,'runtime_freeze_sha256':freeze_sha,'signature_aapt_zipalign_rechecked_at_packaging':True}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-commit', required=True)
    parser.add_argument('--apk', type=Path)
    parser.add_argument('--apk-proof', type=Path)
    parser.add_argument('--build-tools', type=Path, default=Path('/workspace/toolchains/android-sdk/build-tools/36.0.0'))
    parser.add_argument('--repo', type=Path, default=Path('/workspace/Pyton'))
    parser.add_argument('--policy', type=Path, default=Path('/workspace/recovery/events-messages-update-policy.json'))
    args = parser.parse_args()
    require(re.fullmatch('[0-9a-f]{40}', args.source_commit) is not None, 'Full immutable source commit required')
    root = args.repo.resolve()
    validation = root / VALIDATION
    output = root / 'deliverables' / CHECKPOINT
    require(not (output / 'manifest.json').exists(), 'Refuse to overwrite a sealed checkpoint manifest')
    source_zip = output / UPDATE_NAME
    require(source_zip.is_file(), 'Build the source update ZIP first')
    summary_path = validation / 'final-regression/summary.json'
    summary = json.loads(summary_path.read_text())
    require(summary.get('status') == 'passed' and summary.get('failures') == 0, 'Current functional summary must pass')
    suites = summary.get('suites')
    require(isinstance(suites, list) and len({row.get('name') for row in suites}) == len(suites), 'Unique suite inventory required')
    require(all(row.get('status') == 'passed' and row.get('failures') == 0 and type(row.get('checks')) is int and row['checks'] > 0 for row in suites), 'Every suite must pass')
    require(sum(row['checks'] for row in suites) == summary.get('checks'), 'Current functional totals differ')
    previous = json.loads((root / 'validation/equipment-effects-2026-11-18/final-regression/summary.json').read_text())
    prior_names = {row['name'] for row in previous['suites']}
    require(previous.get('status') == 'passed' and previous.get('checks') == 249807 and len(prior_names) == 43, 'Pinned previous regression summary differs')
    require(prior_names <= {row['name'] for row in suites}, 'A previous regression suite was omitted')
    added = [row for row in suites if row['name'] not in prior_names]
    require(REQUIRED_NEW_SUITES <= {row['name'] for row in added}, 'Required new events/messages/player/state suites are missing')
    fresh_path = output / 'source-pair-verification.json'
    fresh = json.loads(fresh_path.read_text())
    require(fresh.get('ok') is True and fresh.get('status') == 'verified' and fresh.get('source_commit') == args.source_commit, 'Fresh verification source commit differs')
    require(fresh.get('unique_feature_scripts_separate') == len(suites) and fresh.get('unique_feature_checks_separate') == summary['checks'], 'Fresh suite totals differ')
    require(fresh.get('startup_checks', 0) > 0 and fresh.get('startup_failures') == 0 and fresh.get('feature_failures') == 0, 'Fresh startup and suites must pass')
    require(type(fresh.get('runtime_inputs_verified')) is int and fresh['runtime_inputs_verified'] > 551 and fresh.get('previous_backend_runtime_inputs') == 551 and fresh.get('unchanged_published0_28_runtime_inputs') == 473, 'Pinned runtime inventories differ')
    changed = fresh.get('changed_previous_backend_runtime_inputs')
    require(isinstance(changed, list) and len(set(changed)) == len(changed) and set(changed) == ALLOWED_CHANGED, 'Unexpected prior runtime change')
    unchanged = 551 - len(changed)
    require(fresh.get('unchanged_previous_backend_runtime_inputs') == unchanged, 'Previous unchanged count differs')
    native = fresh.get('native_reproductions')
    require(isinstance(native, list) and {'events', 'messages', 'player_events', 'damage_effects'} <= {row.get('name') for row in native} and len(native) == fresh.get('native_generator_count'), 'Mandatory old damage contact and new equipment/effects native controls are missing')
    require(fresh['main_native_generator_count'] + fresh['supplemental_native_generator_count'] == len(native), 'Native primary/supplemental counts differ')
    require(fresh.get('all_native_fixtures_byte_exact') is True and fresh.get('resource_replay_count') == 1 and fresh.get('all_resource_replays_byte_exact') is True, 'Native/resource portability proof is incomplete')
    require(fresh.get('all_source_files_unchanged') is True and fresh.get('new_APK_produced') is False, 'Source-only verification scope differs')
    policy = json.loads(args.policy.read_text())
    archive_raw = source_zip.read_bytes()
    require(policy.get('status') == 'verified' and policy.get('source_commit') == args.source_commit and policy.get('update_archive_sha256') == sha(archive_raw) and policy.get('update_archive_bytes') == len(archive_raw), 'Source-update policy/ZIP identity differs')
    require(len(archive_raw) < 33554432 and policy.get('runtime_input_count') == fresh['runtime_inputs_verified'], 'Source update size/runtime policy differs')
    require(fresh.get('update_archive_sha256') == sha(archive_raw) and fresh.get('update_archive_bytes') == len(archive_raw), 'Fresh source ZIP identity differs')
    require(fresh.get('base_archive_sha256') == BASE['sha256'] and fresh.get('base_archive_bytes') == BASE['bytes'] and fresh.get('base_source_commit') == BASE['source_commit'], 'Required source base identity differs')
    require((args.apk is None)==(args.apk_proof is None),'APK and its verification proof must be supplied together')
    require(fresh.get('source_game_version')==EXPECTED_VERSION and fresh.get('source_android_code')==EXPECTED_CODE and fresh.get('version_metadata_changes_only')is True,'Fresh source version metadata differs')
    apk_info=None
    if args.apk is not None:
        apk_path=args.apk.resolve();proof_path=args.apk_proof.resolve();apk_proof=json.loads(proof_path.read_text())
        apk_info=verify_apk(apk_path,apk_proof,args.source_commit,fresh['runtime_freeze_sha256'],args.build_tools.resolve())
        target=output/apk_path.name
        require(apk_path.name not in {'README_RU.md',UPDATE_NAME,'manifest.json','functional-summary.json','source-pair-verification.json','source-update-policy.json','android-verification.json'},'APK basename collides with source payload')
        if apk_path!=target.resolve():
            require(not target.exists(),'Refuse to overwrite an existing APK payload');shutil.copyfile(apk_path,target)
        proof_target=output/'android-verification.json'
        if proof_path!=proof_target.resolve():
            require(not proof_target.exists(),'Refuse to overwrite APK verification payload');shutil.copyfile(proof_path,proof_target)
    shutil.copyfile(args.policy, output / 'source-update-policy.json')
    shutil.copyfile(summary_path, output / 'functional-summary.json')
    new_checks = sum(row['checks'] for row in added)
    readme = f'''# Исходное ядро событий и сообщений — 18 ноября 2026 года

В проект добавлены отдельно проверяемые процедуры событий, сообщений,
обработчиков игрока и переносимого состояния. Реальные границы
и внешние зависимости перечислены в `docs/SOURCE_EVENTS_MESSAGES_RU.md`
и текстовых native-доказательствах внутри проекта.

Это исходники отдельно проверяемого ядра. Новые модули ещё не подключены
к Main; исходная версия — **0.29.0-events-alpha1 / Android code 54**.
Создание груза F926/F927, уничтожение F942 и его исходная математика
выполняются. VM событий, тела модульных обработчиков, форматирование F1344
и внешние графические/звуковые обработчики остаются отдельными зависимостями.
Профиль целей F953 остаётся 0..148; повторное повреждение созданных
объектов моделей153/155 пока отклоняется явно.
Точные границы реально исполненного кода описаны в контракте проекта.
Полный мировой планировщик, эфемериды F866, дальний автопилот F597,
подключение общего цикла и окончательная проверка Android остаются
следующими блоками. S23 Ultra, графика и FPS этим checkpoint не проверялись.

Нужны **два ZIP**: [полная основа 0.28]({BASE['url']}) и
[{UPDATE_NAME}]({UPDATE_NAME}) рядом с этим README. Сначала распакуйте
основу, затем обновление в ту же папку `StarFrontier-0.28.0-source/`.
Прежние малые обновления не нужны: обновление кумулятивное. Оба ZIP
меньше 32 МиБ. Обновление отдельно от основы неполно.

Source commit: `{args.source_commit}`.
Текущий прогон: **{number(summary['checks'])} проверок / {len(suites)} наборов / 0 ошибок**.
Новых наборов: **{len(added)}**, проверок в них: **{number(new_checks)}**.
Чистая пара ZIP: запуск **{fresh['startup_checks']}/0** и повтор всех
**{fresh['unique_feature_scripts_separate']} наборов / {number(fresh['unique_feature_checks_separate'])}/0**.
Все **{fresh['source_actual_files']}** исходных файлов сохранены,
**{fresh['runtime_inputs_verified']}** runtime-входов совпадают с freeze.
Все **{unchanged}** прежних runtime-входов и **473** игровых
входа остаются побайтно прежними. Только имя/код версии в BuildInfo и
export-профиле обновлены до 0.29.0-events-alpha1 /54; Main остаётся прежним.

Переносимый повтор подтвердил **{fresh['native_generator_count']}** native-команд:
{fresh['main_native_generator_count']} основных банков и
{fresh['supplemental_native_generator_count']} отдельных композиционных генераторов.
Native-контроли: **{number(fresh['native_DOS_control_cases_separate'])}**,
отдельных диагностик JJFFE: **{fresh['native_JJFFE_copy_diagnostics_separate']}**,
композиционных сценариев: **{fresh['supplemental_native_composition_cases_separate']}**.
Числа берутся из фактических fixture/отчёта; повторы не добавлены
к функциональной сумме. Ресурсный экстрактор отдельно восстановил точный
JSON из сохранённых исходных диапазонов байтов. Это не native-расчёт.

Проверка исполняет сверенные DOS-инструкции через документированный ELF64
host ABI-адаптер, а не неизменённый IA32-файл. Приватный EXE и Git-метаданные
для переносимого повтора не нужны. Необслуженные внешние зависимости
не подменяются полным игровым движком.

Манифест и ZIP запечатаны перед проверкой опубликованных HTTPS-загрузок.
Подтверждение публикации сохраняется отдельно. PREPUB-записи внутри ZIP
относятся к исходному коммиту до публикации; итоговые подтверждения сохраняются отдельно.
'''
    if apk_info is not None:
        readme+='\nПроверенная техническая APK-сборка: ['+apk_info['file']+']('+apk_info['file']+'), **0.29.0-events-alpha1 / code54**, ARM64, прежняя TEST-подпись. Пакет, версия, подпись и выравнивание проверены повторно; физический телефон не проверялся. Новые ядра ещё не подключены к Main.\n'
    (output / 'README_RU.md').write_text(readme)
    files = {}
    for name in ['README_RU.md', UPDATE_NAME, 'functional-summary.json', 'source-pair-verification.json', 'source-update-policy.json']:
        raw = (output / name).read_bytes()
        files[name] = {'bytes': len(raw), 'sha256': sha(raw)}
    if apk_info is not None:
        for name in [apk_info['file'],apk_info['verification_file']]:
            raw=(output/name).read_bytes();files[name]={'bytes':len(raw),'sha256':sha(raw)}
    manifest = {
        'schema': 'starfrontier-events-messages-core-0.29.0-source-checkpoint-v1',
        'checkpoint': CHECKPOINT,
        'source_commit': args.source_commit,
        'created_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
        'required_archive_count': 2,
        'previous_update_archive_required': False,
        'base_archive': BASE,
        'files': files,
        'merged_source_files': fresh['source_actual_files'],
        'runtime_inputs': fresh['runtime_inputs_verified'],
        'published_game_runtime_inputs': 475,
        'unchanged_published_game_runtime_inputs': 473,
        'previous_backend_runtime_inputs': 551,
        'unchanged_previous_backend_runtime_inputs': unchanged,
        'changed_previous_backend_runtime_paths': changed,
        'current_functional_checks': summary['checks'],
        'unique_suites': len(suites),
        'new_core_checks': new_checks,
        'new_core_suites': len(added),
        'fresh_core_suites': fresh['unique_feature_scripts_separate'],
        'fresh_core_checks_separate': fresh['unique_feature_checks_separate'],
        'native_main_generator_count': fresh['main_native_generator_count'],
        'native_DOS_control_cases_separate': fresh['native_DOS_control_cases_separate'],
        'native_JJFFE_diagnostics_separate': fresh['native_JJFFE_copy_diagnostics_separate'],
        'supplemental_native_compositions_separate': fresh['supplemental_native_composition_cases_separate'],
        'native_generator_count': fresh['native_generator_count'],
        'resource_replay_count': fresh['resource_replay_count'],
        'fresh_pair_verified': True,
        'new_APK_produced': apk_info is not None,
        'apk': apk_info,
        'version_metadata_changes_only': True,
        'version_metadata_paths': sorted(ALLOWED_CHANGED),
        'new_kernels_connected_to_Main': False,
        'game_version': '0.29.0-events-alpha1',
        'Android_version_code': 54,
        'full_original_port_complete': False,
        'physical_device_tested': False,
        'immutable_HTTPS_verified_at_packaging': False,
    }
    (output / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'files': files, 'checks': summary['checks'], 'runtime_inputs': fresh['runtime_inputs_verified'], 'source_files': fresh['source_actual_files']}, indent=2))

if __name__ == '__main__':
    main()
