extends RefCounted

const SAVE_PATH = "user://flight.json"
const REPORT_DIR = "user://reports"
const DOWNLOAD_SUBDIR = "OrbitalRelay"
const MAX_STATE_BYTES = 32768
const MAX_EVENT_BYTES = 768
const MAX_EVENTS = 48
const MAX_DEPTH = 12
const MAX_NODES = 4096
const MAX_SAFE_INTEGER = 9007199254740991

var _started_msec := Time.get_ticks_msec()
var _events: Array[String] = []


static func save_state(state: Dictionary, path: String = SAVE_PATH) -> Error:
	var bytes := _state_bytes(state)
	if bytes.is_empty():
		return ERR_INVALID_DATA

	var destination := ProjectSettings.globalize_path(path)
	var previous := _read_save(destination)
	if not _parse_save(previous).is_empty():
		# Only rotate in a valid copy. Preserve the last good backup if the
		# current file was damaged before this save.
		var backup_error := _replace_bytes(destination + ".previous", previous)
		if backup_error != OK:
			return backup_error
	return _replace_bytes(destination, bytes)


static func load_state(path: String = SAVE_PATH) -> Dictionary:
	var destination := ProjectSettings.globalize_path(path)
	var primary := _parse_save(_read_save(destination))
	if primary.is_empty():
		return _parse_save(_read_save(destination + ".previous"))
	return primary


func trace(event: String, fields: Dictionary = {}) -> void:
	var entry := {
		"elapsed_ms": Time.get_ticks_msec() - _started_msec,
		"event": event.left(80),
	}
	if _is_plain_json(fields, 0, [64]):
		entry["fields"] = fields
	var line := JSON.stringify(entry, "", true, true)
	if line.to_utf8_buffer().size() > MAX_EVENT_BYTES:
		entry.erase("fields")
		line = JSON.stringify(entry)
	_events.append(line)
	if _events.size() > MAX_EVENTS:
		_events.pop_front()


func export_report(state: Dictionary, path: String = "") -> Dictionary:
	var state_bytes := _state_bytes(state)
	var fallback_path := ""
	if path.is_empty():
		var stamp := Time.get_datetime_string_from_system(true).replace(":", "-")
		fallback_path = REPORT_DIR.path_join("orbital-relay-%s-%d.zip" % [stamp, Time.get_ticks_usec()])
		path = _desktop_download_path(fallback_path)

	var destination := ProjectSettings.globalize_path(path)
	var result := _write_report_archive(destination, state_bytes)
	if result != OK and not fallback_path.is_empty() and fallback_path != path:
		destination = ProjectSettings.globalize_path(fallback_path)
		result = _write_report_archive(destination, state_bytes)
	if result != OK:
		return _report_error(result)

	var response := {
		"ok": true,
		"path": destination,
		"file": destination.get_file(),
		"public_downloads": false,
		"clipboard_copied": false,
	}
	if OS.has_feature("android"):
		var published := _android_publish_zip(destination)
		if published:
			response["path"] = "Download/%s/%s" % [DOWNLOAD_SUBDIR, destination.get_file()]
			response["public_downloads"] = true
			DirAccess.remove_absolute(destination)
		else:
			response["clipboard_copied"] = copy_report_text(state)
	return response


func _write_report_archive(destination: String, state_bytes: PackedByteArray) -> Error:
	var directory_error := DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	if directory_error != OK:
		return directory_error

	var temporary := _temporary_path(destination)
	var zip := ZIPPacker.new()
	var result := zip.open(temporary)
	if result != OK:
		DirAccess.remove_absolute(temporary)
		return result
	var summary := _report_summary(not state_bytes.is_empty())
	result = _pack(zip, "report.json", JSON.stringify(summary, "\t", true, true).to_utf8_buffer())
	if result == OK:
		var log := "\n".join(_events)
		if not log.is_empty():
			log += "\n"
		result = _pack(zip, "events.jsonl", log.to_utf8_buffer())
	if result == OK and not state_bytes.is_empty():
		result = _pack(zip, "flight.json", state_bytes)
	var close_error := zip.close()
	if result == OK:
		result = close_error
	if result == OK:
		result = DirAccess.rename_absolute(temporary, destination)
	if result != OK:
		DirAccess.remove_absolute(temporary)
	return result


func copy_report_text(state: Dictionary) -> bool:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		return false
	var state_bytes := _state_bytes(state)
	var text := JSON.stringify(_report_summary(not state_bytes.is_empty()))
	if not state_bytes.is_empty():
		text += "\n" + JSON.stringify(state, "", true, true)
	# Short enough to paste into a message when the public Downloads export
	# is unavailable. The full journal is in the local ZIP.
	for index in range(maxi(0, _events.size() - 16), _events.size()):
		text += "\n" + _events[index]
	DisplayServer.clipboard_set(text)
	return true


func _report_summary(includes_state: bool) -> Dictionary:
	return {
		"game": "Орбитальный рейс",
		"version": str(ProjectSettings.get_setting("application/config/version", "")),
		"godot_version": Engine.get_version_info().get("string", ""),
		"platform": OS.get_name(),
		"exported_utc": Time.get_datetime_string_from_system(true),
		"event_count": _events.size(),
		"includes_flight_state": includes_state,
	}


static func _is_plain_json(value: Variant, depth: int, remaining: Array) -> bool:
	remaining[0] -= 1
	if depth > MAX_DEPTH or remaining[0] < 0:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL:
			return true
		TYPE_INT:
			return value >= -MAX_SAFE_INTEGER and value <= MAX_SAFE_INTEGER
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_STRING:
			return value.length() <= 2048
		TYPE_ARRAY:
			for child: Variant in value:
				if not _is_plain_json(child, depth + 1, remaining):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if not key is String or key.length() > 96:
					return false
				if not _is_plain_json(value[key], depth + 1, remaining):
					return false
			return true
		_:
			return false


static func _state_bytes(state: Dictionary) -> PackedByteArray:
	if state.is_empty() or not _is_plain_json(state, 0, [MAX_NODES]):
		return PackedByteArray()
	var bytes := JSON.stringify(state, "", true, true).to_utf8_buffer()
	return bytes if bytes.size() <= MAX_STATE_BYTES else PackedByteArray()


static func _read_save(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var length := file.get_length()
	if length < 2 or length > MAX_STATE_BYTES:
		return PackedByteArray()
	var bytes := file.get_buffer(length)
	if bytes.size() != length:
		return PackedByteArray()
	return bytes


static func _parse_save(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty() or not _valid_utf8(bytes):
		return {}
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK:
		return {}
	var state: Variant = json.data
	if not state is Dictionary or not _is_plain_json(state, 0, [MAX_NODES]):
		return {}
	return state


static func _valid_utf8(bytes: PackedByteArray) -> bool:
	var offset := 0
	while offset < bytes.size():
		var lead := bytes[offset]
		offset += 1
		if lead == 0:
			return false  # Embedded raw NUL would truncate the decoded text.
		if lead < 0x80:
			continue

		var count: int
		var codepoint: int
		var minimum: int
		if lead >= 0xc2 and lead <= 0xdf:
			count = 1
			codepoint = lead & 0x1f
			minimum = 0x80
		elif lead >= 0xe0 and lead <= 0xef:
			count = 2
			codepoint = lead & 0x0f
			minimum = 0x800
		elif lead >= 0xf0 and lead <= 0xf4:
			count = 3
			codepoint = lead & 0x07
			minimum = 0x10000
		else:
			return false
		if offset + count > bytes.size():
			return false
		for index in range(count):
			var continuation := bytes[offset + index]
			if (continuation & 0xc0) != 0x80:
				return false
			codepoint = (codepoint << 6) | (continuation & 0x3f)
		if codepoint < minimum or codepoint > 0x10ffff:
			return false
		if codepoint >= 0xd800 and codepoint <= 0xdfff:
			return false
		offset += count
	return true


static func _temporary_path(destination: String) -> String:
	return "%s.%d-%d.tmp" % [destination, OS.get_process_id(), Time.get_ticks_usec()]


static func _replace_bytes(destination: String, bytes: PackedByteArray) -> Error:
	var temporary := _temporary_path(destination)
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var written := file.store_buffer(bytes)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if not written and write_error == OK:
		write_error = ERR_FILE_CANT_WRITE
	if write_error == OK:
		write_error = DirAccess.rename_absolute(temporary, destination)
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
	return write_error


static func _pack(zip: ZIPPacker, filename: String, bytes: PackedByteArray) -> Error:
	var result := zip.start_file(filename)
	if result != OK:
		return result
	result = zip.write_file(bytes)
	var close_error := zip.close_file()
	return close_error if result == OK else result


static func _report_error(error: Error) -> Dictionary:
	return {"ok": false, "path": "", "file": "", "error": error, "reason": error_string(error)}


static func _desktop_download_path(private_path: String) -> String:
	if OS.has_feature("android") or OS.has_feature("web"):
		return private_path
	var downloads := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if downloads.is_empty() or not DirAccess.dir_exists_absolute(downloads):
		return private_path
	return downloads.path_join(DOWNLOAD_SUBDIR).path_join(private_path.get_file())


static func _android_publish_zip(local_path: String) -> bool:
	# AndroidRuntime and JavaClassWrapper are shipped with the Android export
	# template. MediaStore allows creating our own ZIP in Downloads without
	# granting general access to shared storage.
	if not Engine.has_singleton("AndroidRuntime") or not Engine.has_singleton("JavaClassWrapper"):
		return false
	var archive_bytes := FileAccess.get_file_as_bytes(local_path)
	if archive_bytes.size() < 22:
		return false
	var runtime: Variant = Engine.get_singleton("AndroidRuntime")
	var bridge: Variant = Engine.get_singleton("JavaClassWrapper")
	var version: Variant = bridge.wrap("android.os.Build$VERSION")
	if version == null or int(version.SDK_INT) < 29:
		return false

	var context: Variant = runtime.getApplicationContext()
	if context == null:
		return false
	var resolver: Variant = context.getContentResolver()
	var downloads: Variant = bridge.wrap("android.provider.MediaStore$Downloads")
	var values_class: Variant = bridge.wrap("android.content.ContentValues")
	if resolver == null or downloads == null or values_class == null:
		return false
	var collection: Variant = downloads.getContentUri("external_primary")
	if collection == null:
		return false
	var values: Variant = values_class.new()
	if values == null:
		return false
	values.put("_display_name", local_path.get_file())
	values.put("mime_type", "application/zip")
	values.put("relative_path", "Download/" + DOWNLOAD_SUBDIR + "/")
	values.put("is_pending", "1")
	var uri: Variant = resolver.insert(collection, values)
	if uri == null:
		return false

	var stream: Variant = resolver.openOutputStream(uri, "w")
	if stream == null:
		resolver.delete(uri, "", PackedStringArray())
		return false
	stream.write(archive_bytes)
	var written: bool = bridge.get_exception() == null
	stream.close()
	var closed: bool = bridge.get_exception() == null
	if written and closed:
		var ready: Variant = values_class.new()
		ready.put("is_pending", "0")
		var updated: Variant = resolver.update(uri, ready, "", PackedStringArray())
		if updated != null and int(updated) == 1:
			return true
	resolver.delete(uri, "", PackedStringArray())
	return false
