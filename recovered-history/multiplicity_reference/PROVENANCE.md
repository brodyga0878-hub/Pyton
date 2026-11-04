# Восстановление из истории multiplicity_reference

Дата: 2026-11-04. Агент: `/root/worlds_completion_audit/multiplicity_reference`.
Рабочий репозиторий `/workspace/Pyton` не изменялся.

## Что действительно сохранилось

В доступном контексте остались последние дословные выводы чтения файлов во время read-only аудита Source3. Предыдущие turns создания Python-генераторов уже заменены краткой сводкой. Их полных tool inputs или файлов в текущем контексте нет. Доступного инструмента чтения более ранних turns не обнаружено; старых файлов на новом диске также не найдено.

Единственный полностью восстановленный файл:

- `scripts/source_city_view.gd`: полный дословный вывод `sed -n '1,240p' scripts/source_city_view.gd` из предыдущей среды. Он независимо совпал байт в байт с копией, восстановленной агентом `worlds_completion_audit`. Это снимок на момент последнего чтения; последующие изменения старого диска неизвестны.

Частичные файлы в `partial/` — это фрагменты с исходными номерами строк в именах, а не готовые полные скрипты:

- `scripts/near_surface_view.gd.lines24-69.txt`: две полные функции `update` и `enter_descent`, из последнего `nl -ba` чтения.
- `scripts/main.gd.lines2582-2632.txt`: начало `_sync_planet_visuals`, конец функции не сохранился.
- `scripts/surface_visual.gd.lines77-93.txt`: ветка отдельного source-city renderer и начало legacy pad.
- `tests/test_source_city_view.gd.lines31-92.txt`: хвост теста, склеенный из двух перекрывающихся дословных чтений. Совпадает с соответствующими строками независимо восстановленного полного теста. Исходная опечатка `sphere-source-city-v3` сохранена; исправлений при восстановлении нет.

Эти файлы не создавались заново по описанию алгоритма. Частичные фрагменты не следует автоматически заменять ими полные исходники. Новые SHA-256 в `RECOVERED_SHA256SUMS` идентифицируют нынешние восстановленные файлы и не являются независимо сохранившимися хешами старого диска.

## Что восстановить из этой истории НЕ удалось

Следующие имена и характеристики сохранились в сообщениях/сводке, но полного текста нет. Не созданы ни поддельные исходники, ни JSON с выдуманными результатами.

| Артефакт | Сохранившиеся сведения, не новый запуск |
| --- | --- |
| `tools/build_multiplicity_reference.py`, `tests/fixtures/multiplicity_reference.json` | Родной reference для исходных multiplicity 4/5; исторически 436 cases, 11574 records; 55 фактических входов каталога. Использовал существующий `build_inhabited_system_reference.py --cases-input`. |
| `tools/build_terrain_primitives_reference.py`, `tests/fixtures/terrain_primitives_reference.json` | Оригинальные F1824 hash, F1846 displacement, F1521 signed Q31 multiply; исторически 2016 cases /10080 outputs. |
| `tools/build_terrain_query_reference.py`, `tests/fixtures/terrain_query_reference.json` | Оригинальный F1876, 336 raw cases: 4 seeds ×14 styles ×2 radii ×3 orientations. Feature list пуст. |
| `tools/build_terrain_model_query_reference.py`, `tests/fixtures/terrain_model_query_reference.json` | Реальные model feature streams для 119/125/129/133; исторически 608 cases /1216 queries, 87 отличий от пустых feature lists. |
| `tools/extract_terrain_query.py`, `data/ffe_terrain_query.json` | Ревизия dataset v2: DATA7835..7894, 60 таблиц, две bitmap DATA7637/7638 по 16 KiB, модели 117..133. Точные исходные байты/хеши отсутствуют. |
| `tests/test_terrain_model_query.py`, `tests/test_terrain_resources.py` | Исторически 6 тестов, включая native reproduction. Полного текста нет. |
| `tools/build_terrain_additional_query_reference.py` | Исторически 390 native controls для 13 дополнительных моделей (117..133 без прежних четырёх). Имя соответствующего fixture целиком не сохранилось в прямом чтении. |
| `docs/TERRAIN_MODEL_RESOURCES_RU.md` | Была создана точная таблица 17 моделей; полного текста нет. |
| `/workspace/ffe-review/terrain-provider-stress/summary.json` | Внешний stress result, не project fixture: исторически 8864 samples для 16 uniform моделей, обратный порядок/свежий процесс совпадали; данных файла нет. |

`tools/build_terrain_game_query_reference.py` и `tools/build_terrain_provider_reference.py` упоминались как соседние/родительские инструменты. Их полные тексты в этом контексте тоже отсутствуют. Первый исторически имел fixture на 120 оригинальных F581 caller controls; старые raw336/model608/game120 fixture оставались неизменными при расширении моделей. Это сведения о прошлой работе, а не подтверждение наличия файлов сейчас.

## Сохранившийся контракт resources (описание, не оригинальный JSON)

- `tables[String(number)] = {bytes_hex, relocations: [{offset, symbol}]}`. Для pointer words в `bytes_hex` были нули, полные символы сохранялись в relocations. Таблицы numeric-order сохраняли смежность DATA7841/7842.
- DATA7637/7638 — реальные bitmap bytes; не подстановка или процедурное приближение.
- `models[String(id)]` содержал `feature_stream_hex`, `terrain_style_raw` и provenance; позднее добавлены `vertices_hex`, `collision_payload_hex`, `mesh_zoom`, `source_scale_raw`, `source_scale2_raw`, `interaction_radius_raw`, `collision_radius_raw`, `model_radius_raw`, указатели/offset/hash provenance.
- Для 117..133 добавлены `base_axis_vertex_raw`, `base_axis`, `axis_vertices_raw`, `base_axes`, `axes_uniform`, `uniform_base_radius_raw`, `spherical_provider_eligible`. Модель 117 неравномерная (исторически абсолютные оси 14/23/71), исключалась из spherical provider; 118..133 равномерные.
- `vector_scale` не объявлялся универсальным свойством модели; caller задавал его отдельно. Модель 118 не имела доказанного естественного UID в проверенном source-body корпусе.

Эти сведения могут помочь новой реализации после восстановления upstream, но не заменяют потерянные файлы и не доказывают точные массивы данных.

## Внешние входы и временные помощники

Точные прежние пути, явно оставшиеся в сообщениях:

- Оригинальный EXE: `/workspace/scratch/ffe-analysis/files/FIRSTENC/FIRSTENC.EXE`.
- JJFFE assembly: `/workspace/ffe-upstream/jjffe/ffe.asm`.
- Таблицы читались из `ffedat`/`FFEDAT.asm` upstream; полный абсолютный путь и регистр имени в доступном тексте не сохранились достаточно точно.
- Модуль `native_reference` и существующий `tools/build_inhabited_system_reference.py` использовались как native harness инфраструктура. Полных исходников и точного layout модуля здесь нет.
- Ранние прототипы: `/tmp/terrain_query_probe.py`, `/tmp/terrain_query_probe_mirror.py`.
- Внешняя рабочая папка: `/workspace/ffe-review/terrain-query-work`.
- Исходный пользовательский архив теперь доступен как `/workspace/recovery/Frontier_First_Encounters.rar`.

Native F1876 harness исторически требовал не только обычного helper: именованные FUNC boundaries, encoded negative frame offsets, расширение семи stack frames и двух POP RCX, адаптацию 32-bit callback table к `mov/call rax`, `OFFSET FLAT` для bare DATA/FUNC immediates, реальные размеры BSS, trap недостигнутых функций. Сведения сохранились в заданиях, но точных замен и полного wrapper assembly нет. Функции terrain математическими аппроксимациями не заменялись.

Ни один native/reference тест в новой среде в рамках этого восстановления не запускался: нужные исходники и harness отсутствуют. Проверены только полнота сохранённого текста и совпадение двух независимо восстановленных копий города/хвоста теста.
