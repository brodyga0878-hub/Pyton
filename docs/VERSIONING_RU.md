# Версии проекта и Android-сборок

После каждого завершённого и опубликованного блока разработки меняется версия исходного проекта. Новый крупный блок повышает minor-номер; исправление повышает patch-номер. Неизменные имена API-профилей проверенных математических модулей не заменяют версию игры.

Текущая версия исходного проекта: **0.32.0-statements-alpha1**, Android versionCode **57**. Последняя опубликованная техническая APK — **0.32.0-statements-alpha1**, code57; фактическая сборка и независимое соответствие исходникам подтверждены отдельными отчётами.

`scripts/build_info.gd` задаёт номер для меню и диагностических архивов. Android export preset обязан содержать те же versionName/versionCode. Каждый выпускаемый APK получает code больше предыдущего; публикация включает проверку фактического Android-манифеста, подписи и контрольной суммы.

Отчёт каждого блока отдельно указывает, собран ли новый APK, какие модули подключены к основному циклу и что пока проверяется отдельно. Повышение версии само по себе не означает завершение полного переноса оригинала. Если блок опубликован только как исходники, это должно быть явно указано без ссылки на несуществующий APK.

Для 0.29 собран отдельный APK с code54. Проверка `tools/verify_events_android.py` читает фактические константы экспортированного BuildInfo и сравнивает все 187 скриптов APK с независимым Android export-pack из проверенной пары исходных ZIP. Прежний `tools/verify_rebuilt_android.py` сохраняет контракт исторической версии 0.28/code53. Итоговая APK и оба исходных ZIP доступны в текущем разделе README.

Для 0.30 `tools/verify_mission_android.py` подтвердил code55, настоящие константы BuildInfo, прежнюю TEST-подпись, выравнивание и точные 36 JSON-ресурсов. Все 192 скрипта совпали с независимым Android export-pack из замороженной проверенной пары исходников. Исторические проверки 0.28/0.29 не переписаны. APK и оба ZIP скачаны по обычным HTTPS-ссылкам и проверены по размеру, SHA и CRC.

<!-- MISSION_TASKS_FINAL_EVIDENCE_BEGIN -->
Для 0.31 `tools/verify_task_android.py` подтвердил фактические code56/BuildInfo, ARM64, прежнюю TEST-подпись, CRC и выравнивание. Все **197** экспортированных скриптов совпали с независимой Android-компиляцией проверенной замороженной пары исходников; **37** JSON-ресурсов совпали побайтно. Source-коммит `1e9528ffa6f39d39d632e702aaf14f53bce6fc93`, artifact-коммит `3c93bfe2cff19994169f2a0df560a7bfafe2c791`. APK имеет SHA256 `4cfb8665c99b284261bba3937b7d967e8e9b6e8e2896d03eb70b3c9c69e35079` и размер 51 066 103 байт.

[APK0.31](https://raw.githubusercontent.com/brodyga0878-hub/Pyton/3c93bfe2cff19994169f2a0df560a7bfafe2c791/deliverables/mission-tasks-core-0.31.0-2026-11-19/StarFrontier-0.31.0-tasks-arm64.apk), [доказательство APK](https://raw.githubusercontent.com/brodyga0878-hub/Pyton/3c93bfe2cff19994169f2a0df560a7bfafe2c791/deliverables/mission-tasks-core-0.31.0-2026-11-19/android-verification.json) и [проверка 9 полных опубликованных загрузок](../validation/mission-tasks-publication-2026-11-19/verification.json). Исторические проверки 0.28/0.29/0.30 сохранены; новые ядра остаются вне Main. Физический S23 Ultra и FPS не проверялись.
<!-- MISSION_TASKS_FINAL_EVIDENCE_END -->

<!-- MISSION_STATEMENTS_FINAL_EVIDENCE_BEGIN -->
Для 0.32 `tools/verify_statements_android.py` подтвердил фактические code57/BuildInfo, ARM64, прежнюю TEST-подпись, CRC и выравнивание. Все **201** экспортированных скриптов совпали с независимой Android-компиляцией проверенной замороженной пары исходников; **37** JSON-ресурсов совпали побайтно. Source-коммит `54d394c5ce103a467def9cd7c554db1ba6372497`, artifact-коммит `de718cfbbfa74745b333d366e2cd4f1a9c75dc0e`. APK имеет SHA256 `6f5f795048c90ba4c7f60a755da250ad7d35183235763a67ba0caf6850fa5cf6` и размер 51 111 869 байт.

[APK0.32](https://raw.githubusercontent.com/brodyga0878-hub/Pyton/de718cfbbfa74745b333d366e2cd4f1a9c75dc0e/deliverables/mission-statements-core-0.32.0-2026-11-19/StarFrontier-0.32.0-statements-arm64.apk), [доказательство APK](https://raw.githubusercontent.com/brodyga0878-hub/Pyton/de718cfbbfa74745b333d366e2cd4f1a9c75dc0e/deliverables/mission-statements-core-0.32.0-2026-11-19/android-verification.json) и [проверка 9 полных опубликованных загрузок](../validation/mission-statements-publication-2026-11-19/verification.json). Исторические проверки 0.28/0.29/0.30/0.31 сохранены; новые ядра остаются вне Main. Физический S23 Ultra и FPS не проверялись.
<!-- MISSION_STATEMENTS_FINAL_EVIDENCE_END -->
