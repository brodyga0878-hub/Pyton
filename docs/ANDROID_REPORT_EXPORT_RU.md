# Сохранение ZIP-отчёта на Android

`scripts/report_export.gd` сохраняет готовый ZIP через **системный диалог Android Storage Access Framework**. Пользователь выбирает, например, «Загрузки», после чего может прикрепить файл в ChatGPT. Показ внутреннего `user://reports/…` пути не используется как способ передачи архива.

Ни Android-плагин, ни Gradle, ни широкие файловые разрешения, ни доступ в Интернет не требуются. Это штатная возможность закреплённого Godot4.6.3. Приложение не отправляет отчёт автоматически.

## API

```gdscript
var exporter = preload("res://scripts/report_export.gd").new()
add_child(exporter)
exporter.completed.connect(on_report_export_finished)
var started = exporter.export_report(zip_path, filename)
if not started.ok:
    show_error(started.error)
```

Метод принимает путь `user://…` или абсолютный путь готового ZIP. При успешном открытии диалога возвращает `{ok:true,pending:true}`. Непосредственный отказ возвращает `{ok:false,error:…}` и не требует ожидания сигнала. Два одновременных диалога запрещены.

После выбора результата сигнал `completed(result:Dictionary)` содержит:

- `ok=true`, `verified=true`, `bytes`, `sha256` и `path` при подтверждённой записи;
- `cancelled=true` при отмене;
- `ok=false`, `error` и `message` при отказе.

На Android `path` является `content://` URI выбранного документа; нельзя интерпретировать его как обычный путь `/sdcard`. Предлагаемое имя ZIP передаётся в native picker. MIME — `application/zip`.

Архив копируется блоками64КиБ. После закрытия записи файл читается повторно и сравнивается SHA-256/длина. При сбое, недоступном чтении у выбранного провайдера или отмене исходный архив остаётся в приложении; пользователь может повторить сохранение в локальные «Загрузки». Экспорт ограничен32МиБ. На desktop используется встроенный `FileDialog`; внешний desktop portal не требуется.

## Проверенная платформа

Официальный исходник **Godot4.6.3-stable**:

- [`DisplayServer.file_dialog_show`](https://github.com/godotengine/godot/blob/4.6.3-stable/doc/classes/DisplayServer.xml) документирует Android SAF, `FILE_DIALOG_MODE_SAVE_FILE`, callback `(bool,PackedStringArray,int)` и прямой read/write выбранного URI через `FileAccess`.
- [`DisplayServerAndroid`](https://github.com/godotengine/godot/blob/4.6.3-stable/platform/android/display_server_android.cpp) передаёт запрос native picker и возвращает callback отложенно в Godot.
- [`FilePicker.kt`](https://github.com/godotengine/godot/blob/4.6.3-stable/platform/android/java/lib/src/main/java/org/godotengine/godot/io/FilePicker.kt) прямо сопоставляет режим4 с `Intent.ACTION_CREATE_DOCUMENT`, передаёт предложенное имя через `EXTRA_TITLE`, MIME через `MimeTypeMap`, выбирает открываемый локальный документ и возвращает выбранный URI. Отмена возвращает `false` и пустой список.

Метод сохранения не использует `FileProvider` и `Intent.ACTION_SEND`. Отдельная кнопка отправки через Java bridge не добавлена: сохранённого в доступную папку ZIP достаточно для прикрепления сюда, а закрытие стороннего Android chooser не доказывало бы доставку отчёта.

## Что реально проверено

`tests/test_report_export.gd`: **27 проверок,0 ошибок** на Godot4.6.3, без ошибок движка и утечек. Проверены настоящий ZIP с метаданными и журналом170123байта, побайтовое копирование/чтение архиватора, сохранение исходника, ошибочные назначения, защита от самокопирования, одновременные запросы, native callback отмены/ошибки/успеха и повторный поздний callback. Журнал содержит детерминированные псевдослучайные байты; отдельное утверждение проверяет, что сам ZIP больше128КиБ и копирование действительно проходит несколько блоков.

```sh
godot --headless --path . --script tests/test_report_export.gd
```

Эти проверки не исполняют Android picker. Реальный выбор папки, URI выбранного Samsung-провайдера и прикрепление файла в ChatGPT должны быть проверены на физическом S23 Ultra. Источники подтверждают API, но не заменяют аппаратную проверку.
