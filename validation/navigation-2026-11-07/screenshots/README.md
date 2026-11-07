# Навигация 0.13.0: фактические кадры Main

10 PNG сняты из `scenes/main.tscn` через `tools/capture_navigation_block.gd`: полёт с часами и креном, секторная карта, обзор галактики, вся система Sol, Земля/Луна. Каждый вид снят при 1440×720 и 2316×1080. Все 10 финальных изображений отдельно просмотрены через `view_image`.

Последний проход: **2191 проверка, 0 ошибок**. Проверяются реальные кнопки, границы и пересечения отображаемых подписей, наличие измеренной телеметрии, отсутствие продвижения живых часов/корабля при просмотре карт и отключённые игровые сохранения. Версия, время начала, SHA256 исходников и состояния кадров записаны в `capture-manifest.json`; изображения привязаны к визуальному осмотру через `visual-review.json` и `SHA256SUMS.txt`.

Это реальный desktop OpenGL рендер Godot 4.6.3 через Mesa llvmpipe. Изображения не смонтированы. Набор не является съёмкой с физического Samsung S23 Ultra или измерением производительности его GPU.

Команда после запуска локального Xorg `:97`:

```sh
DISPLAY=:97 XDG_DATA_HOME=/workspace/recovery/navigation-capture/data XDG_CACHE_HOME=/workspace/recovery/navigation-capture/cache XDG_CONFIG_HOME=/workspace/recovery/navigation-capture/config godot --path /workspace/Pyton --rendering-method gl_compatibility --audio-driver Dummy --script res://tools/capture_navigation_block.gd -- --rebuild-capture
```

Прогресс игры не загружается и не сохраняется: capture mode создаёт отдельный полёт в памяти. Геометрия станции и положения объектов берутся из работающих игровых модулей.
