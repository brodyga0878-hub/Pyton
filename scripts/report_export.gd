extends Node
# Godot 4.6 Android native file dialog uses SAF ACTION_CREATE_DOCUMENT.
# Its content:// result is writable through FileAccess; no storage permission,
# FileProvider, Java plugin, network upload, or private-path handoff is required.
signal completed(result:Dictionary)
const MAX_REPORT_BYTES:=32*1024*1024
const BLOCK_BYTES:=64*1024
var _busy:=false
var _source_path:=""
var _filename:=""
var _desktop_dialog:FileDialog

func is_busy()->bool:return _busy

static func _error(message:String)->Dictionary:
	return {"ok":false,"pending":false,"cancelled":false,"verified":false,"error":message,"message":message}

static func _inspect_source(path:String)->Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):return _error("ZIP-отчёт не найден. Создайте отчёт ещё раз.")
	var source:=FileAccess.open(path,FileAccess.READ)
	if source==null:return _error("Не удалось прочитать ZIP-отчёт.")
	var length:=source.get_length()
	var header:=source.get_buffer(4);source.close()
	if length<=22 or length>MAX_REPORT_BYTES:return _error("Размер ZIP-отчёта недопустим для экспорта.")
	if header!=PackedByteArray([80,75,3,4]):return _error("Файл отчёта не является ZIP-архивом.")
	return {"ok":true,"bytes":length}

static func _hash_file(path:String)->Dictionary:
	var stream:=FileAccess.open(path,FileAccess.READ)
	if stream==null:return _error("Не удалось прочитать записанный файл для проверки.")
	var hash:=HashingContext.new()
	if hash.start(HashingContext.HASH_SHA256)!=OK:stream.close();return _error("Не удалось начать проверку ZIP-отчёта.")
	var total:=0
	var length:=stream.get_length()
	while total<length:
		var chunk:=stream.get_buffer(mini(BLOCK_BYTES,length-total))
		if chunk.is_empty():stream.close();return _error("Файл прочитан не полностью.")
		total+=chunk.size();hash.update(chunk)
	stream.close()
	return {"ok":true,"bytes":total,"sha256":hash.finish().hex_encode()}

static func copy_file_verified(source_path:String,destination:String)->Dictionary:
	# Public to permit deterministic testing without opening a native picker.
	# Runtime destinations originate exclusively from the user's save dialog.
	var inspected:=_inspect_source(source_path)
	if not inspected.ok:return inspected
	if destination.is_empty():return _error("Не выбрано место для ZIP-отчёта.")
	if source_path==destination or ProjectSettings.globalize_path(source_path)==ProjectSettings.globalize_path(destination):
		return _error("Выберите другое место: исходный отчёт уже находится здесь.")
	var source:=FileAccess.open(source_path,FileAccess.READ)
	if source==null:return _error("Не удалось открыть исходный ZIP-отчёт.")
	var target:=FileAccess.open(destination,FileAccess.WRITE)
	if target==null:source.close();return _error("Не удалось записать ZIP-отчёт в выбранное место.")
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	var written:=0
	while written<int(inspected.bytes):
		var chunk:=source.get_buffer(mini(BLOCK_BYTES,int(inspected.bytes)-written))
		if chunk.is_empty():source.close();target.close();return _error("Исходный ZIP-отчёт прочитан не полностью.")
		target.store_buffer(chunk)
		if target.get_error()!=OK:source.close();target.close();return _error("Запись ZIP-отчёта прервана. Повторите сохранение.")
		hash.update(chunk);written+=chunk.size()
	target.flush();var write_error:=target.get_error();target.close();source.close()
	if write_error!=OK:return _error("Не удалось завершить запись ZIP-отчёта.")
	var expected:=hash.finish().hex_encode()
	var actual:=_hash_file(destination)
	if not actual.ok:return _error("Файл записан, но проверить его чтением не удалось. Исходный ZIP сохранён; выберите другое место.")
	if int(actual.bytes)!=written or actual.sha256!=expected:return _error("Проверка записанного ZIP не пройдена. Повторите сохранение.")
	return {"ok":true,"pending":false,"cancelled":false,"verified":true,"path":destination,"bytes":written,"sha256":expected,"error":"","message":"ZIP-отчёт сохранён. Прикрепите этот файл к сообщению в ChatGPT."}

func export_report(source_path:String,filename:String)->Dictionary:
	if _busy:return _error("Диалог сохранения отчёта уже открыт.")
	var inspected:=_inspect_source(source_path)
	if not inspected.ok:return inspected
	var safe_name:=filename.get_file().replace("\\","_")
	if safe_name.is_empty():safe_name="StarFrontier-report.zip"
	if safe_name.length()>120:safe_name="StarFrontier-report.zip"
	if not safe_name.to_lower().ends_with(".zip"):safe_name+=".zip"
	_source_path=source_path;_filename=safe_name;_busy=true
	if OS.has_feature("android") and DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		var error:=DisplayServer.file_dialog_show("Сохранить ZIP-отчёт","",safe_name,false,DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,PackedStringArray(["*.zip;ZIP-архив;application/zip"]),_on_native_selected)
		if error==OK:return {"ok":true,"pending":true,"filename":safe_name,"error":""}
		_reset();return _error("Android не открыл системный диалог сохранения. Попробуйте ещё раз.")
	if OS.has_feature("android"):
		_reset();return _error("Системный диалог файлов недоступен в этой сборке Android.")
	if DisplayServer.get_name()=="headless":
		_reset();return _error("Для выбора места сохранения нужен графический интерфейс.")
	_show_desktop_dialog()
	return {"ok":true,"pending":true,"filename":safe_name,"error":""}

func _show_desktop_dialog()->void:
	if _desktop_dialog==null:
		_desktop_dialog=FileDialog.new();_desktop_dialog.title="Сохранить ZIP-отчёт";_desktop_dialog.access=FileDialog.ACCESS_FILESYSTEM;_desktop_dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE
		_desktop_dialog.filters=PackedStringArray(["*.zip;ZIP-архив"]);_desktop_dialog.use_native_dialog=false
		_desktop_dialog.file_selected.connect(_on_desktop_selected);_desktop_dialog.canceled.connect(_on_cancelled)
		add_child(_desktop_dialog)
	_desktop_dialog.current_file=_filename;_desktop_dialog.popup_centered_ratio(0.8)

func _on_native_selected(status:bool,paths:PackedStringArray,_filter_index:int)->void:
	if not _busy:return
	if not status:_on_cancelled();return
	if paths.size()!=1 or paths[0].is_empty():
		_finish(_error("Android не вернул выбранный файл. Повторите сохранение."));return
	_on_desktop_selected(paths[0])

func _on_desktop_selected(path:String)->void:
	if not _busy:return
	var result:=copy_file_verified(_source_path,path)
	result.filename=_filename;_finish(result)

func _on_cancelled()->void:
	if not _busy:return
	_finish({"ok":false,"pending":false,"cancelled":true,"verified":false,"error":"","message":"Сохранение ZIP-отчёта отменено."})

func _reset()->void:
	_busy=false;_source_path="";_filename=""

func _finish(result:Dictionary)->void:
	_reset();completed.emit(result)
