#!/usr/bin/env python3
"""Publish checkout documentation after nine verified immutable HTTPS downloads.

This helper has no network, Git, build, artifact or proof writes. It validates
the sealed release and prepares four documentation replacements; the optional
roadmap update adds a dated current section without rewriting previous history.
Frozen source ZIP documents retain the source commit's PREPUB state.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import struct
import zipfile

VERSION = '0.28.0-native-station-alpha1'
VERSION_CODE = 53
MARKER = 'NATIVE_STATION_CURRENT'
PUBLICATION = 'validation/native-station-publication-2026-11-16/verification.json'
PORTABILITY = 'validation/native-station-source-portability-2026-11-16/verification.json'
FEATURES = {
    'tests/test_native_station_main.gd': ('Main', 114),
    'tests/test_native_station_frame.gd': ('pure Frame', 157),
    'tests/test_native_station_trial.gd': ('pure Trial', 219),
}


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def number(value):
    return format(value, ',').replace(',', ' ')


def safe_relative(value):
    require(isinstance(value, str) and bool(value), 'Missing relative payload path')
    path = PurePosixPath(value)
    require(not path.is_absolute() and '..' not in path.parts and '.' not in path.parts
            and '\\' not in value and '\x00' not in value and path.as_posix() == value,
            'Unsafe payload path: ' + repr(value))
    return path


def section(text, body, marker=MARKER):
    begin, end = '<!-- ' + marker + '_BEGIN -->', '<!-- ' + marker + '_END -->'
    require(text.count(begin) == text.count(end) == 1,
            'Expected exactly one current documentation section: ' + marker)
    head, rest = text.split(begin, 1)
    _, tail = rest.split(end, 1)
    return head + begin + '\n' + body.strip() + '\n' + end + tail


def zero_failures(value):
    return value == 0 or value == []


def inspect_release(root):
    release = root / 'deliverables' / VERSION
    manifest_path, proof_path = release / 'manifest.json', root / PUBLICATION
    manifest_raw, proof_raw = manifest_path.read_bytes(), proof_path.read_bytes()
    manifest, proof = json.loads(manifest_raw), json.loads(proof_raw)
    require(proof.get('status') == 'verified',
            'Actual nine-download immutable HTTPS proof has not succeeded')
    artifact_commit, source_commit = proof.get('artifact_commit', ''), proof.get('source_commit', '')
    require(re.fullmatch(r'[0-9a-f]{40}', artifact_commit) is not None,
            'Missing immutable artifact Git SHA')
    require(re.fullmatch(r'[0-9a-f]{40}', source_commit) is not None
            and source_commit == manifest.get('source_commit'), 'Wrong frozen source commit')
    require(manifest.get('version') == proof.get('version') == VERSION
            and manifest.get('version_code') == VERSION_CODE, 'Wrong version/code')
    payloads = manifest.get('files')
    require(isinstance(payloads, dict) and bool(payloads), 'Missing sealed payload manifest')
    local_raw = {}
    for name, expected in payloads.items():
        safe_relative(name)
        path = release / name
        require(path.resolve().is_relative_to(release.resolve()), 'Payload escapes release directory')
        require(isinstance(expected, dict) and type(expected.get('bytes')) is int
                and expected['bytes'] > 0 and isinstance(expected.get('sha256'), str)
                and re.fullmatch(r'[0-9a-f]{64}', expected['sha256']),
                'Invalid sealed hash/length: ' + name)
        raw = path.read_bytes()
        require(len(raw) == expected['bytes'] and digest(raw) == expected['sha256'],
                'Local sealed payload changed: ' + name)
        local_raw[name] = raw
    apk_name = 'StarFrontier-0.28.0-native-station-arm64.apk'
    source_name = 'StarFrontier-0.28.0-native-station-source.zip'
    require(apk_name in payloads and source_name in payloads, 'Missing exact APK/source payloads')
    pngs = sorted(name for name in payloads if name.endswith('.png'))
    captures = [name for name in payloads if name.endswith('capture-manifest.json')]
    diagnostic_name = manifest.get('actual_collector_report_ZIP')
    require(len(pngs) == 4 and len(captures) == 1, 'Expected four PNGs and one capture manifest')
    require(isinstance(diagnostic_name, str) and diagnostic_name in payloads
            and diagnostic_name.endswith('.zip') and diagnostic_name != source_name,
            'Missing actual include-save diagnostic ZIP')
    base = ('https://raw.githubusercontent.com/brodyga0878-hub/Pyton/'
            + artifact_commit + '/deliverables/' + VERSION + '/')
    records = proof.get('files')
    require(isinstance(records, list) and len(records) == 9,
            'Exactly nine complete actual HTTPS downloads are required')
    expected_downloads = {'manifest.json', apk_name, source_name, captures[0], diagnostic_name, *pngs}
    downloaded = set()
    for record in records:
        require(isinstance(record, dict), 'Invalid download record')
        name = record.get('file')
        require(isinstance(name, str) and name in expected_downloads and name not in downloaded,
                'Duplicate or unexpected HTTP download')
        downloaded.add(name)
        expected = ({'bytes': len(manifest_raw), 'sha256': digest(manifest_raw)}
                    if name == 'manifest.json' else payloads[name])
        require(record.get('http_status') == 200 and record.get('url') == base + name,
                'Missing HTTP200 or immutable raw GitHub URL: ' + name)
        require(record.get('bytes') == expected['bytes'] and record.get('sha256') == expected['sha256'],
                'Actual HTTP length/SHA differs from sealed bytes: ' + name)
        if name.endswith(('.zip', '.apk')):
            require(record.get('zip_crc_verified') is True, 'Downloaded archive CRC missing: ' + name)
        if name == source_name:
            require(record.get('source_commit_in_zip_comment') == source_commit,
                    'Downloaded source ZIP Git comment differs')
    require(downloaded == expected_downloads, 'The exact nine publication files were not all downloaded')
    for name in (apk_name, source_name, diagnostic_name):
        with zipfile.ZipFile(release / name) as archive:
            require(archive.testzip() is None, 'Local archive CRC failed: ' + name)
            if name == source_name:
                require(archive.comment.decode('ascii') == source_commit, 'Local source ZIP Git comment differs')
                infos = archive.infolist()
                actual_files = len([entry for entry in infos if not entry.is_dir()])
                zip_entries = len(infos)
                require(actual_files == manifest.get('source_archive_actual_files')
                        and zip_entries == manifest.get('source_archive_files'), 'Source ZIP inventory count differs')
                require(len(local_raw[name]) == manifest.get('source_archive_bytes')
                        and len(local_raw[name]) < 32 * 1024 * 1024, 'Source ZIP length/32MiB policy differs')
    for name in pngs:
        raw = local_raw[name]
        require(raw[:16] == b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR'
                and len(raw) > 32 and all(struct.unpack('>II', raw[16:24])), 'Invalid PNG IHDR: ' + name)
    summary_name = manifest.get('functional_report')
    require(summary_name in local_raw, 'Sealed functional summary is missing')
    summary = json.loads(local_raw[summary_name])
    suites = summary.get('suites')
    require(summary.get('status') == 'passed' and summary.get('failures') == 0
            and isinstance(suites, list) and len(suites) == 47, 'Expected current passing 47-suite summary')
    require(len({entry.get('test') for entry in suites}) == len(suites), 'Repeated functional test script')
    require(all(type(entry.get('checks')) is int and entry['checks'] > 0
                and entry.get('failures') == 0 for entry in suites), 'Invalid functional suite result')
    total = sum(entry['checks'] for entry in suites)
    require(summary.get('checks') == manifest.get('functional_checks') == total
            and summary.get('passed_suites') == manifest.get('functional_groups') == len(suites)
            and manifest.get('functional_failures') == 0, 'Functional manifest/summary sums differ')
    current_features = {entry['test']: entry for entry in suites if entry.get('test') in FEATURES}
    require(set(current_features) == set(FEATURES), 'Missing current station feature suites')
    for script, (_, expected) in FEATURES.items():
        require(current_features[script]['checks'] == expected, 'Unexpected current feature result: ' + script)
    packaging = json.loads(local_raw['packaging.json'])
    require(packaging.get('unit_test_count') == packaging.get('unique_test_id_count')
            == manifest.get('python_packaging_tests_separate') == 431
            and packaging.get('unit_test_failures') == packaging.get('unit_test_errors') == 0
            and len(packaging.get('unit_test_modules', {})) == manifest.get('python_packaging_modules') == 16,
            'Python packaging count or module coverage differs')
    capture = json.loads(local_raw[captures[0]])
    require(zero_failures(capture.get('failures')) and capture.get('checks') == manifest.get('capture_checks_separate')
            and type(capture.get('checks')) is int and capture['checks'] > 0
            and len(capture.get('frames', [])) == manifest.get('desktop_frames_visually_inspected') == 4,
            'Capture checks/frame count differs')
    require(manifest.get('runtime_frozen_files') == 475 and manifest.get('unchanged_previous_runtime_files') == 468
            and len(manifest.get('changed_previous_runtime_files', [])) == 3
            and len(manifest.get('added_runtime_files', [])) == 4, 'Runtime continuity count differs')
    require(manifest.get('compiled_integration_modules') == 58 and manifest.get('compiled_new_modules') == 2,
            'Compiled module count differs')
    assets = manifest.get('native_station_assets')
    require(isinstance(assets, dict) and assets.get('unchanged_code52_runtime_source_count') == 55,
            'Protected 55 non-Main core modules are not verified')
    require(manifest.get('reused_native_control_cases') == 402
            and manifest.get('native_reproduction_validator_checks_separate') == 6208
            and manifest.get('new_native_control_cases') == 0
            and manifest.get('new_original_native_oracle_claimed') is False, 'Old native bank accounting differs')
    require(manifest.get('physical_device_tested') is False and manifest.get('production_release_ready') is False
            and manifest.get('full_original_port_complete') is False, 'Release scope flags differ')
    require(manifest.get('actual_collector_report_included_save') is True,
            'Diagnostic report must include the complete save')
    portability_name = 'source-portability/verification.json'
    require(portability_name in local_raw, 'Fresh-source portability proof missing')
    portability = json.loads(local_raw[portability_name])
    require(portability.get('ok') is True and portability.get('archive_sha256') == payloads[source_name]['sha256']
            and portability.get('source_commit') == source_commit
            and portability.get('archive_file_count') == actual_files
            and portability.get('startup_failures') == 0
            and portability.get('extracted_archive_files_unchanged') is True,
            'Fresh-source startup/inventory proof differs')
    fresh = {}
    for name, raw in local_raw.items():
        if not name.startswith('source-portability/') or not name.endswith('.json'):
            continue
        obj = json.loads(raw)
        script = obj.get('test', obj.get('primary_feature_script'))
        if script not in FEATURES or 'features' in obj:
            continue
        require(script not in fresh, 'Duplicate clean-source feature proof: ' + script)
        require(obj.get('ok') is True and obj.get('failures') == 0
                and obj.get('source_commit') == source_commit
                and obj.get('archive_sha256') == payloads[source_name]['sha256']
                and obj.get('checks') == FEATURES[script][1]
                and obj.get('all_source_files_unchanged') is True,
                'Clean-source feature proof differs: ' + name)
        fresh[script] = obj
    require(set(fresh) == set(FEATURES), 'Expected fresh one-Main plus two-pure station reports')
    fresh_total = sum(entry['checks'] for entry in fresh.values())
    require(fresh_total == 490, 'Fresh station feature sum differs')
    require(manifest.get('source_archive_all_actual_files_unchanged') == actual_files,
            'Source archive invariance count differs')
    require(manifest.get('source_archive_pinned_runtime_inputs_verified') == 475,
            'Portable runtime freeze is not verified')
    return dict(root=root, release=release, manifest_path=manifest_path, proof_path=proof_path,
                manifest_raw=manifest_raw, proof_raw=proof_raw, manifest=manifest, proof=proof,
                payloads=payloads, source_name=source_name, apk_name=apk_name, base=base,
                source_commit=source_commit, artifact_commit=artifact_commit, pngs=pngs,
                actual_files=actual_files, zip_entries=zip_entries, total=total, groups=len(suites),
                capture_checks=capture['checks'], startup_checks=portability['startup_checks'],
                fresh_total=fresh_total, payload_count=len(payloads), auxiliary=len(payloads)-8)


def prepare_documents(facts, update_roadmap=False):
    f = facts
    root, m = f['root'], f['manifest']
    apk, source = f['payloads'][f['apk_name']], f['payloads'][f['source_name']]
    apk_url, source_url = f['base'] + f['apk_name'], f['base'] + f['source_name']
    frames = ' · '.join('[Кадр ' + str(i+1) + '](' + f['base'] + name + ')'
                        for i, name in enumerate(f['pngs']))
    downloads = f'''- [Скачать ARM64 APK]({apk_url}) — {number(apk['bytes'])} байт.
- [Скачать исходники ZIP]({source_url}) — {number(source['bytes'])} байт, меньше 32 МиБ.
- Настоящие desktop-кадры игры: {frames}.'''
    features = '''1. **Переход к станции.** В космической фазе испытания можно выбрать
   реальную орбитальную станцию текущего тела. В пределах **100 км**, вне
   атмосферы и при допустимом просвете переносится текущая Float64-позиция.
   Signed64-начала вычитаются до перевода в метры; поправка скорости
   учитывает движение станции по исходным эфемеридам. Выбор не выполняет
   дальний перелёт и не сбрасывает достигнутую позу, время или топливо.
2. **Док и службы в одном сеансе.** Прежний автоподход проходит настоящие
   вращение, дверь и геометрию захвата. После стыковки доступны оплачиваемые
   ремонт, заправка и оборудование. Проверены реальная покупка водорода,
   снятие и повторная установка защиты за деньги. Бесплатная выдача
   оборудования не используется; смена корабля в испытании отклоняется.
3. **Вылет, возврат и сохранение.** После физического выхода из дока можно
   перейти обратно к планетному кадру с текущими координатами, скоростью,
   корпусом, топливом, оборудованием и часами. Холодная загрузка сохраняет
   точные биты движения, состояние автоподхода и историю вращения/CCD,
   включая движение двери и стоянку. Отрисовка использует частный мир
   и не изменяет физическое source-состояние. Основной прогресс отделён.'''
    usage = '''На исходной поверхности вне города: **Меню → «Испытание исходной
посадки»**, затем вылет и **Меню → «Орбитальные станции»**. Подлетите к
выбранной станции вручную. В станционной фазе **«Авто»** включает заход;
после стыковки та же кнопка открывает службы. **«Вылететь»** запускает
физический выход, **«К планете»** возвращает планетный кадр. Дальнейший
полёт до поверхности продолжается самостоятельно. Основной прогресс
возвращается отдельной командой меню. **«Отчёт об ошибке / логи»** с
включённым сохранением выгружает полный текущий станционный сеанс.'''
    checks = f'''Текущая функциональная сводка: **{number(f['total'])} условий /
{f['groups']} уникальных групп / 0 ошибок**. Новый блок содержит один сценарий
настоящего Main — **114/0**, два pure-набора Frame/Trial — **157/0 и 219/0**.
Отдельно: **431 Python-тест в 16 модулях**, **четыре осмотренных desktop-кадра /
{number(f['capture_checks'])} проверок захвата**, прежний native-банк **402 случая /
6208 условий**. Повторы, захват, Python и прежний native-банк не прибавлены
к функциональной сумме; нового исходного native-эталона нет.

Проверен ARM64 TEST APK **code 53**, SDK {m['min_sdk']}/{m['target_sdk']},
16-КиБ выравнивание. Закреплены **475 runtime-входов**: из прежних 471
неизменны 468, изменены три, добавлены четыре. Проверены **58 основных
скомпилированных модулей**, включая два новых; **55 прежних модулей,
кроме Main, побайтно сохранены**.'''
    portable = f'''Точный ZIP из исходного коммита `{f['source_commit']}`:
**{number(source['bytes'])} байт / {number(f['actual_files'])} файлов /
{number(f['zip_entries'])} ZIP-записей**, меньше 32 МиБ. Свежие импорт и
запуск — **{f['startup_checks']}/0**. Повтор в чистом ZIP: **490/0 — один Main
(114) и два pure-набора (157 + 219)**; это не три сценария Main. Все
**{number(f['actual_files'])} файлов** после проверок неизменны. Повторные
проверки переносимости остаются отдельно от функциональной суммы.'''
    publication = f'''Проверены **девять полных HTTPS-скачиваний**: манифест, APK,
исходники, протокол захвата, четыре PNG и настоящий ZIP-отчёт с сохранением.
Для всех получены HTTP 200 и совпадение размеров/SHA; CRC архивов и
Git-комментарий исходного ZIP совпали. Локально проверены все
**{f['payload_count']} payload**; остальные **{f['auxiliary']} вспомогательных файлов
отдельно через HTTP не скачивались**. [Подтверждение публикации]({PUBLICATION}).
Artifact-коммит: `{f['artifact_commit']}`. Запечатанные манифест и исходный ZIP
не изменяются; документы внутри ZIP сохраняют PREPUB-состояние исходного
коммита. Итог публикации записан в текущем checkout.'''
    limits = '''Земные станции находятся примерно в **35 млн м** от поверхности.
Этот дальний перелёт не выдаётся за пройденный: после настоящего вылета
до 20 км проверка честно задаёт начальную точку **на 100 м снаружи
действительного внешнего waypoint**, затем выполняет реальный заход.
Ограничение 600 м/с относится к заданной скорости стабилизации; инерциальный
режим допускает больший разгон с расходом топлива и последующим торможением.

Продолжение у станции использует существующий мобильный закон. Полные
исходные F570/F606 и F597/AI, универсальная поверхность, полный клон,
полная русификация и магазинный релиз не завершены. Круговая орбита
автоматически не создаётся. Физический S23 Ultra и FPS не проверены.'''
    archive_policy = '''В ZIP сохранены все текущие runtime, изображения, игровые данные,
тесты, инструменты, документация и `recovered-history/`. Добавлены
`native_station_frame.gd`, `native_station_trial.gd`, их UID и проверки.
Для ограничения 32 МиБ не дублируются прежние QA 0.27, кроме обязательного
`runtime-freeze.json`, и её прежняя проверка переносимости. Они остаются
в GitHub и точном архиве 0.27. Необходимые старые `native-proof/`, включая
зависимости прежних 0.26/0.25, сохранены. Технический APK-отчёт
`android-verification.json` поставляется отдельно с APK и не требуется
для сборки исходников. Четыре кадра и их capture-manifest/visual-review,
`capture-runtime-inputs.json`, `capture.log` и полный
`packaging-unit-tests.log` доступны отдельно в том же наборе сборки.
Сводка Python и все текущие функциональные отчёты включены в ZIP.
Файлы репозитория и история исходников этой политикой не удаляются.'''
    readme_body = '\n\n'.join([
        'Опубликована TEST-сборка **' + VERSION + ' / code 53**.', downloads,
        'Завершены три последовательные задачи: **переход к станции → док и\nслужбы в том же испытании → вылет и обратный переход**.',
        features, usage, checks, portable, publication, limits,
        '[Изменения](docs/RELEASE_0_28_0_RU.md) · [Контракт](docs/SOURCE_NATIVE_STATION_RU.md).\nПредыдущие опубликованные сборки и их неизменяемые файлы сохранены ниже.'
    ])
    source_body = '\n\n'.join([
        'Опубликован **' + VERSION + ' / code 53**.\n[Скачать точный ZIP](' + source_url + ').',
        portable, 'SHA256 исходного ZIP: `' + source['sha256'] + '`.',
        archive_policy, checks, publication,
        '[Контракт и границы](docs/SOURCE_NATIVE_STATION_RU.md).'
    ])
    release_text = '\n\n'.join([
        '# Связанный станционный полёт — 0.28.0',
        'Опубликована TEST-сборка **' + VERSION + ' / Android code 53**.',
        downloads, features, usage, checks, portable,
        publication.replace('](' + PUBLICATION + ')', '](../' + PUBLICATION + ')'), limits,
        '[Подробный контракт](SOURCE_NATIVE_STATION_RU.md) ·\n[Предыдущая сборка 0.27](RELEASE_0_27_0_RU.md).'
    ]) + '\n'
    contract_path = root / 'docs/SOURCE_NATIVE_STATION_RU.md'
    contract_old = contract_path.read_text()
    technical_marker = '## Переход между кадрами'
    require(contract_old.count(technical_marker) == 1, 'Unexpected station contract structure')
    technical = contract_old[contract_old.index(technical_marker):]
    header = '\n\n'.join([
        '# Связанный полёт у орбитальной станции',
        'Опубликована TEST-сборка **' + VERSION + ' / code 53**.\n'
        '[ARM64 APK](' + apk_url + ') · [исходники ZIP](' + source_url + ').',
        'Три действия соединены в одном отдельном испытательном сеансе:\n'
        'ограниченный переход к станции, прежняя стыковка и платные службы,\n'
        'физический вылет и обратный переход к планетному кадру.',
        portable, checks,
        publication.replace('](' + PUBLICATION + ')', '](../' + PUBLICATION + ')'),
        '[Описание сборки](RELEASE_0_28_0_RU.md).'
    ]) + '\n\n'
    paths = {
        root / 'README.md': section((root / 'README.md').read_text(), readme_body),
        root / 'SOURCE_ARCHIVE_RU.md': section((root / 'SOURCE_ARCHIVE_RU.md').read_text(), source_body),
        root / 'docs/RELEASE_0_28_0_RU.md': release_text,
        contract_path: header + technical,
    }
    if update_roadmap:
        path = root / 'docs/RECOVERY_AND_ROADMAP_RU.md'
        text = path.read_text()
        body = f'''Обновлено **16 ноября 2026 года**. Текущее продолжение — опубликованная
TEST-сборка **{VERSION} / code 53**: [описание](RELEASE_0_28_0_RU.md).
Завершены ограниченный переход к станции текущего тела в пределах 100 км
вне атмосферы, настоящий автоподход/док с платными службами в том же
испытании, физический вылет и обратный переход к планетному кадру.
Холодное продолжение сохраняет движение и вращение; основной прогресс отделён.

Сводка **{number(f['total'])} / {f['groups']} групп / 0 ошибок**. Отдельно —
431 Python-тест, четыре desktop-кадра / {number(f['capture_checks'])} проверки,
чистый ZIP490/0 (один Main114 + два pure157/219) и прежний native-банк402/6208.
Девять полных HTTPS-скачиваний проверены: [подтверждение](../{PUBLICATION}).
Дальний35-Мм перелёт не заявляется пройденным: у внешнего waypoint
использована явная тестовая начальная точка. Полные F570/F606 и F597/AI,
полный клон/русификация, универсальная поверхность и магазинный релиз
не завершены; физический S23 Ultra/FPS не проверены.

Следующий крупный блок — непрерывные дальние перелёты, три задачи:

1. Единое исходное состояние корабля и небесных кадров: выбор родителя,
   raw-координаты, скорость родителя и переходы F585/F570/F595/F604–606.
2. Исходная цепочка времени F208/F1418 и больших шагов с согласованными
   движением, топливом, нагревом, столкновениями и событиями мира.
3. Дальний автопилот F597: перехват движущейся цели и торможение,
   затем реально пройденный маршрут поверхность → станция → службы →
   вылет → поверхность и холодное продолжение в пути.

Сначала нужны независимые контрольные траектории исходного DOS EXE и
разбор отличий JJFFE; существующие режимы сохраняются до подтверждения
новой цепочки. Полный object/AI bank, добыча MB4, посадка на все твёрдые
тела, экономика, кампания, локализация и проверка устройства остаются
отдельными незавершёнными областями. Дата готовности полного клона не задана.

Ниже сохранена датированная история, а не текущий остаток работ.'''
        if '<!-- ' + MARKER + '_BEGIN -->' in text:
            text = section(text, body)
        else:
            first, separator, tail = text.partition('\n\n')
            require(bool(separator), 'Unexpected recovery roadmap heading')
            text = first + '\n\n<!-- ' + MARKER + '_BEGIN -->\n' + body + '\n<!-- ' + MARKER + '_END -->\n\n' + tail
        paths[path] = text
    for path, text in paths.items():
        require(re.search(r'\]\((?:/workspace(?:/|\))|file://)', text) is None,
                'Invalid local download URL: ' + str(path))
        if path.name in ('README.md', 'SOURCE_ARCHIVE_RU.md'):
            current = text.split('<!-- ' + MARKER + '_BEGIN -->', 1)[1].split('<!-- ' + MARKER + '_END -->', 1)[0]
            require('PREPUB.' not in current, 'Current section remains a prepublication candidate')
    return paths


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path('/workspace/Pyton'))
    parser.add_argument('--update-roadmap', action='store_true',
                        help='Add a dated current marker without rewriting roadmap history.')
    parser.add_argument('--check-only', action='store_true',
                        help='Validate actual publication proof and prepare documents without writes.')
    args = parser.parse_args()
    facts = inspect_release(args.root.resolve())
    documents = prepare_documents(facts, args.update_roadmap)
    if not args.check_only:
        for path, text in documents.items():
            path.write_text(text, encoding='utf-8')
    require(facts['manifest_path'].read_bytes() == facts['manifest_raw'], 'Sealed manifest changed')
    require(facts['proof_path'].read_bytes() == facts['proof_raw'], 'Actual publication proof changed')
    for name, expected in facts['payloads'].items():
        raw = (facts['release'] / name).read_bytes()
        require(len(raw) == expected['bytes'] and digest(raw) == expected['sha256'],
                'Sealed payload changed while preparing docs: ' + name)
    print(json.dumps({'status': 'documentation_validated' if args.check_only else 'published_documentation_written',
                      'source_commit': facts['source_commit'], 'artifact_commit': facts['artifact_commit'],
                      'actual_complete_HTTPS_downloads': 9, 'functional_checks': facts['total'],
                      'functional_groups': facts['groups'], 'fresh_features_separate': '1 Main + 2 pure, 490/0',
                      'local_manifest_payloads_verified': facts['payload_count'],
                      'auxiliary_payloads_not_individually_downloaded': facts['auxiliary'],
                      'written_files': [] if args.check_only else [str(p.relative_to(facts['root'])) for p in documents],
                      'prepared_files': [str(p.relative_to(facts['root'])) for p in documents],
                      'sealed_artifacts_manifest_and_actual_proof_unchanged': True}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
