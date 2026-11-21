extends RefCounted

const SessionIO := preload("res://scripts/session_io.gd")
const DIRECTORY := "user://voyages"
const MAX_SLOTS := 12
const MAX_NAME_LENGTH := 48
const HEADER_LIMIT := 512
const VERSION := 1
const EXTENSION := ".voyage"

static var _access := Mutex.new()


static func list_slots() -> Array[Dictionary]:
	_access.lock()
	var slots: Array[Dictionary] = []
	for id: String in _slot_ids():
		var record := _read_slot(id)
		slots.append({
			"id": id,
			"name": record.get("name", "Повреждённый рейс"),
			"modified": int(record["modified"]) if not record.is_empty() else FileAccess.get_modified_time(_path(id)),
		})
	_access.unlock()
	slots.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return first["id"] < second["id"] if first["modified"] == second["modified"] else first["modified"] > second["modified"])
	return slots


static func create_slot(name: String, state: Dictionary) -> Dictionary:
	var label := _clean_name(name)
	if label.is_empty():
		return _failure(ERR_INVALID_PARAMETER)
	var payload := SessionIO._state_bytes(state)
	if payload.is_empty():
		return _failure(ERR_INVALID_DATA)
	_access.lock()
	var result := _create_slot(label, payload)
	_access.unlock()
	return result


static func load_slot(id: String, validator: Callable) -> bool:
	if not _valid_id(id) or not validator.is_valid():
		return false
	_access.lock()
	var record := _read_slot(id, true)
	_access.unlock()
	if record.is_empty():
		return false
	var state := SessionIO._parse_save(record["payload"])
	return not state.is_empty() and validator.call(state) == true


static func rename_slot(id: String, name: String) -> Error:
	var label := _clean_name(name)
	if not _valid_id(id) or label.is_empty():
		return ERR_INVALID_PARAMETER
	_access.lock()
	var error := _rename_slot(id, label)
	_access.unlock()
	return error


static func delete_slot(id: String) -> Error:
	if not _valid_id(id):
		return ERR_INVALID_PARAMETER
	_access.lock()
	var path := _path(id)
	var error := DirAccess.remove_absolute(path) if FileAccess.file_exists(path) else ERR_FILE_NOT_FOUND
	_access.unlock()
	return error


static func error_message(error: Error) -> String:
	match error:
		ERR_INVALID_PARAMETER:
			return "Введите имя рейса длиной от 1 до %d символов в одну строку." % MAX_NAME_LENGTH
		ERR_ALREADY_EXISTS:
			return "Рейс с таким именем уже есть."
		ERR_UNAVAILABLE:
			return "Все %d мест заняты. Удалите один из рейсов." % MAX_SLOTS
		ERR_INVALID_DATA:
			return "Это состояние рейса не удалось записать."
		ERR_FILE_NOT_FOUND:
			return "Рейс с таким идентификатором не найден."
		ERR_FILE_CORRUPT:
			return "Файл рейса повреждён."
		_:
			return "Не удалось изменить список рейсов."


static func _create_slot(name: String, payload: PackedByteArray) -> Dictionary:
	var folder := ProjectSettings.globalize_path(DIRECTORY)
	if not DirAccess.dir_exists_absolute(folder):
		var directory_error := DirAccess.make_dir_recursive_absolute(folder)
		if directory_error != OK:
			return _failure(directory_error)
	var ids := _slot_ids()
	if _name_exists(name, ids):
		return _failure(ERR_ALREADY_EXISTS)
	if ids.size() >= MAX_SLOTS:
		return _failure(ERR_UNAVAILABLE)
	for _attempt in range(4):
		var id := Crypto.new().generate_random_bytes(16).hex_encode()
		if not _valid_id(id) or id in ids or DirAccess.dir_exists_absolute(_path(id)):
			continue
		var error := _write_slot(id, name, payload)
		return {"ok": true, "id": id} if error == OK else _failure(error)
	return _failure(ERR_CANT_CREATE)


static func _rename_slot(id: String, name: String) -> Error:
	if not FileAccess.file_exists(_path(id)):
		return ERR_FILE_NOT_FOUND
	var record := _read_slot(id, true)
	if record.is_empty():
		return ERR_FILE_CORRUPT
	if record["name"] == name:
		return OK
	if _name_exists(name, _slot_ids(), id):
		return ERR_ALREADY_EXISTS
	return _write_slot(id, name, record["payload"])


static func _slot_ids() -> Array[String]:
	var ids: Array[String] = []
	var folder := DirAccess.open(DIRECTORY)
	if folder == null:
		return ids
	for filename: String in folder.get_files():
		if not filename.ends_with(EXTENSION):
			continue
		var id := filename.trim_suffix(EXTENSION)
		if _valid_id(id) and not folder.is_link(filename):
			ids.append(id)
	return ids


static func _name_exists(name: String, ids: Array[String], exclude := "") -> bool:
	var key := name.to_lower()
	for id: String in ids:
		if id != exclude and String(_read_slot(id).get("name", "")).to_lower() == key:
			return true
	return false


static func _read_slot(id: String, include_payload := false) -> Dictionary:
	var file := FileAccess.open(_path(id), FileAccess.READ)
	if file == null:
		return {}
	var total := file.get_length()
	if total < 2 or total > HEADER_LIMIT + SessionIO.MAX_STATE_BYTES:
		return {}
	var prefix := file.get_buffer(mini(total, HEADER_LIMIT))
	var newline := prefix.find(10)
	if newline < 1:
		return {}
	var record := SessionIO._parse_save(prefix.slice(0, newline))
	var length := total - newline - 1
	if record.size() != 4 or record.get("version") != VERSION or record.get("length") != length \
		or length < 2 or length > SessionIO.MAX_STATE_BYTES or not record.get("name") is String:
		return {}
	var name: String = record["name"]
	var modified: Variant = record.get("modified")
	if name.is_empty() or _clean_name(name) != name or not (modified is int or modified is float) \
		or modified < 0 or modified > SessionIO.MAX_SAFE_INTEGER or floorf(modified) != modified:
		return {}
	if include_payload:
		file.seek(newline + 1)
		var payload := file.get_buffer(length)
		if payload.size() != length:
			return {}
		record["payload"] = payload
	return record


static func _write_slot(id: String, name: String, payload: PackedByteArray) -> Error:
	# Keep metadata and snapshot in one atomic replacement. The separate JSON
	# line keeps the snapshot within the autosave's own size and depth bounds.
	var header := {"version": VERSION, "name": name, "modified": int(Time.get_unix_time_from_system()), "length": payload.size()}
	var bytes := (JSON.stringify(header) + "\n").to_utf8_buffer()
	if bytes.size() > HEADER_LIMIT:
		return ERR_INVALID_DATA
	bytes.append_array(payload)
	return SessionIO._replace_bytes(_path(id), bytes)


static func _path(id: String) -> String:
	return ProjectSettings.globalize_path(DIRECTORY.path_join(id + EXTENSION))


static func _valid_id(id: String) -> bool:
	if id.length() != 32:
		return false
	for character: String in id:
		if not character in "0123456789abcdef":
			return false
	return true


static func _clean_name(name: String) -> String:
	var first := 0
	var end := name.length()
	while first < end and _is_spacing(name.unicode_at(first)):
		first += 1
	while end > first and _is_spacing(name.unicode_at(end - 1)):
		end -= 1
	if end - first > MAX_NAME_LENGTH:
		return ""
	for index in range(first, end):
		var point := name.unicode_at(index)
		if point < 32 or (point >= 127 and point <= 159) or point in [0x2028, 0x2029]:
			return ""
	return name.substr(first, end - first)


static func _is_spacing(point: int) -> bool:
	return point <= 32 or (point >= 0x2000 and point <= 0x200a) \
		or point in [0x85, 0xa0, 0x1680, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000]


static func _failure(error: Error) -> Dictionary:
	return {"ok": false, "id": "", "error": error, "reason": error_message(error)}
