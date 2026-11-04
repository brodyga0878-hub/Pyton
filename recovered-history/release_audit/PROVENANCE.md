# Источник восстановления /root/release_audit

Дата восстановления: 2026-11-04. Цель: сохранить найденный код из доступного агенту контекста, не создавать отсутствующую игру заново. Пустой /workspace/Pyton не изменялся.

## Границы доступной истории

У меня сохранился унаследованный контекст родительского агента с полными cat/read outputs и tool inputs итераций 10.11–10.15 (версии 0.10.0–0.10.4-alpha1), а также собственная запись docs/RELEASE_ROADMAP_RU.md итерации 10.16/0.10.5-alpha1. Это НЕ финальные исходники позднейших итераций. Нет доступа к старой файловой системе или прежним ZIP/APK; сведения о них в истории не заменяют сами файлы.

Файлы scripts/* в корне этой папки — последний полностью восстановимый вариант в моей истории. Более новые варианты из других агентов могут иметь приоритет при сборке. Сохранять известные старые ошибки здесь намеренно: например, spherical_terrain.basis_at относится к эпохе orbit-link-v1, до исправления ориентации в итерации 10.16.

## Полные тексты

- project.godot: полный cat read в начале графической итерации 10.12, тогда 0.10.0-alpha1. В последующих видимых изменениях этот файл не менялся.
- scripts/device_settings.gd: полный cat output той же итерации.
- scripts/settings_panel.gd: полный head -90 output (файл короче 90 строк) плюс три точные замены подписей качества 0.10.1.
- versions/v0.10.0-read/scripts/celestial_renderer.gd и planet.gdshader: полные cat outputs. scripts/celestial_renderer.gd и planet.gdshader — применение видимых точных patches графической итерации 0.10.1, сохранённых также в history_patches/visuals_v0100_to_v0104.py.
- scripts/surface_model.gd: полный исторический read 0.10.1 (сохранён в versions/v0.10.1-read), затем детерминированное применение ВСЕХ видимых последовательных patches 0.10.2/0.10.3/0.10.4. Patches сохранены в history_patches, каждый промежуточный полный файл — в versions. Последний файл 440 строк. Номера известных строк совпали со старым rg-output: state.version=4 — строка 204, проверка layout — строка 346, сообщение begin_descent — строка 415. Независимо восстановленный preview_review SurfaceModel0.10.4 побайтно совпал с этим файлом (сообщение агента, diff пустой).
- versions/v0.10.2-read/scripts/surface_visual.gd: полный cat output 0.10.2. SHA256 **b2ebdbd0bf6e54fe491bee91ba4a292d381ee2975c547766ad10142705daa583** ТОЧНО совпал со значением reference_sha256 старого stage10-14-terrain-comparison.json, напечатанного в истории. Это независимая проверка точности транскрипции. Этот же файл сохранён как tests/surface_visual_reference_v0102.gd.
- scripts/surface_visual.gd: к указанному полному снимку применены видимые sample-optimization patches 0.10.3 и дальнее кольцо/цветовой fade 0.10.4. Промежуточный вариант сохранён в versions/v0.10.3-history-patches.
- scripts/spherical_terrain.gd: полный read старой sphere-v1 плюс полностью видимая добавленная функция sample (0.10.3). Этот старый адаптированный рельеф не подменяет более поздний исходный FFE-генератор.
- scripts/surface_orbit_link.gd: полностью видимый heredoc 0.10.3 с точными последующими patches layout/source_digest/get validation. Это orbit-link-v1, НЕ позднейший v2/v3.
- scripts/world_presentation.gd: полностью видимый heredoc 0.10.1 и точные patches update_height/reset/fog 0.10.4.
- scripts/terrain.gdshader, landing_pad.gdshader, building.gdshader, atmosphere.gdshader: полные heredoc inputs и точные последующие material-coordinate/filter patches вплоть до 0.10.4.
- tools/build_android.sh: полный head -45 output (файл короче 45 строк), неизменный в видимых следующих итерациях. Пути на старые toolchains не означают, что toolchains/ключ доступны в новой среде. Здесь только обычная тестовая настройка, не приватный ключ.
- tools/check.sh: восстановлен из перекрывающихся head/tail outputs полного исходного списка и точных последующих suite/smoke append patches до 0.10.4. Полный логический текст известен; независимого старого SHA для контроля пробельных строк нет.
- tests/test_vertical_flight.gd, test_surface_orbit_link.gd, test_world_presentation.gd: полные heredoc inputs и видимые последующие исправления. В старой среде выводились соответственно 2004, 176 и 96 проверок. Эти старые результаты не являются выполнением тестов на восстановленной неполной игре.
- docs/RELEASE_ROADMAP_RU.md: точный полный текст, написанный мной через apply_patch для родителя в отдельном задании 10.16, до потери старой среды.

## Только фрагменты

partial/scripts/* явно НЕ полные исходники. Там нет заглушек недостающих функций или придуманного JSON.

- flight_model.gd: только наблюдавшиеся полные forward/brake/can_dock/snapshot и prefix step. Полного класса, профилей, всех функций restore/dock/equipment у меня не было.
- planetary_system.gd: только наблюдавшиеся функции origin/local_meters/transfer/protect_surface и точная правка same-focus station route 0.10.3. Конструктор, исходный генератор и полный restore отсутствуют.
- main.gd: только полностью видимые методы вертикального перехода и команда поверхности. _physics_process, map/help и другие полные фрагменты отдельно восстанавливает preview_review; мы разделили работу.

Полных navigation.gd, galaxy.gd, flight_model.gd, planetary_system.gd, main.gd, main.tscn, export_presets.cfg и полного tools/verify_android.py у меня нет. Их нельзя объявлять восстановленными из моего контекста. Конкретные имена агентов этапов 1–9 в доступной истории отсутствуют; выдуманный список не создавался.

Файлы здесь не компилировались как самостоятельная игра: нужные оригинальные зависимости/JSON отсутствуют. Сверка SHA/номеров строк подтверждает историческую транскрипцию, а не готовность нового APK.
