extends RefCounted

const AndroidReportShare = preload("res://scripts/android_report_share.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const SAVE_PATH = "user://flight.json"
const BACKUP_PATH = SAVE_PATH + ".previous"
const REPORT_DIR = "user://reports"
const EVENTS_PATH = "user://report-events.jsonl"
const DOWNLOAD_SUBDIR = "OrbitalRelay"
const MAX_STATE_BYTES = 4 * 1024 * 1024
const MAX_EVENT_BYTES = 768
const MAX_EVENTS = 48
const MAX_JOURNAL_BYTES = MAX_EVENTS * (MAX_EVENT_BYTES + 1)
const EVENT_WRITE_INTERVAL_MS = 2000
const MAX_DEPTH = 12
const MAX_EVENT_NODES = 64
const MAX_SAFE_INTEGER = 9007199254740991

enum LoadResult { NO_SAVE, PRIMARY, BACKUP, INVALID }

var _started_msec := Time.get_ticks_msec()
var _events: Array[String] = []
var _persist_events: bool
var _events_dirty := false
var _last_event_write_msec := -EVENT_WRITE_INTERVAL_MS


func _init(persist_events: bool = false) -> void:
	_persist_events = persist_events
	if not _persist_events:
		return
	var bytes := _read_bounded(ProjectSettings.globalize_path(EVENTS_PATH), MAX_JOURNAL_BYTES)
	if bytes.is_empty() or not _valid_utf8(bytes):
		return
	for line: String in bytes.get_string_from_utf8().split("\n", false):
		var encoded := line.to_utf8_buffer()
		if encoded.size() <= MAX_EVENT_BYTES and _parse_save(encoded).get("event") is String:
			_events.append(line)
	_events = _events.slice(maxi(0, _events.size() - MAX_EVENTS))


static func save_state(state: Dictionary, path: String = SAVE_PATH, preserve_backup: bool = false) -> Error:
	var bytes := _state_bytes(state)
	if bytes.is_empty():
		return ERR_INVALID_DATA

	var destination := ProjectSettings.globalize_path(path)
	if not preserve_backup:
		var previous := _read_bounded(destination)
		if not _parse_save(previous).is_empty():
			var backup_error := _replace_bytes(destination + ".previous", previous)
			if backup_error != OK:
				return backup_error
	return _replace_bytes(destination, bytes)


static func load_state(path: String = SAVE_PATH) -> Dictionary:
	var primary := load_single_state(path)
	if primary.is_empty():
		return load_single_state(path + ".previous")
	return primary


static func load_single_state(path: String) -> Dictionary:
	return _parse_save(_read_bounded(ProjectSettings.globalize_path(path)))


static func load_valid_state(path: String, validator: Callable) -> LoadResult:
	var destination := ProjectSettings.globalize_path(path)
	var primary := _parse_save(_read_bounded(destination))
	if not primary.is_empty() and validator.call(primary):
		return LoadResult.PRIMARY
	var backup_path := destination + ".previous"
	var backup := _parse_save(_read_bounded(backup_path))
	if not backup.is_empty() and validator.call(backup):
		return LoadResult.BACKUP
	if FileAccess.file_exists(destination) or FileAccess.file_exists(backup_path):
		return LoadResult.INVALID
	return LoadResult.NO_SAVE


func trace(event: String, fields: Dictionary = {}) -> void:
	var recorded_msec := Time.get_ticks_msec()
	var entry := {
		"elapsed_ms": recorded_msec - _started_msec,
		"event": event.left(80),
		"recorded_utc": Time.get_datetime_string_from_system(true),
	}
	if _is_plain_json(fields, 0, [MAX_EVENT_NODES]):
		entry["fields"] = fields
	var line := JSON.stringify(entry, "", true, true)
	if line.to_utf8_buffer().size() > MAX_EVENT_BYTES:
		entry.erase("fields")
		line = JSON.stringify(entry)
	_events.append(line)
	if _events.size() > MAX_EVENTS:
		_events.pop_front()
	if _persist_events:
		_events_dirty = true
		if recorded_msec - _last_event_write_msec >= EVENT_WRITE_INTERVAL_MS:
			flush_events()


func flush_events() -> void:
	if not _events_dirty:
		return
	_last_event_write_msec = Time.get_ticks_msec()
	var data := ("\n".join(_events) + "\n").to_utf8_buffer()
	_events_dirty = _replace_bytes(ProjectSettings.globalize_path(EVENTS_PATH), data) != OK


static func report_flight_source(state: Dictionary) -> String:
	return _report_flight(state).source


func export_report(state: Dictionary, path: String = "") -> Dictionary:
	var android_download := path.is_empty() and OS.has_feature("android")
	var fallback_path := ""
	if path.is_empty():
		fallback_path = _next_report_path()
		path = _desktop_download_path(fallback_path)

	var destination := ProjectSettings.globalize_path(path)
	var capture := _report_flight(state)
	var result := _write_report_archive(destination, capture)
	if result != OK and not fallback_path.is_empty() and fallback_path != path:
		destination = ProjectSettings.globalize_path(fallback_path)
		result = _write_report_archive(destination, capture)
	if result != OK:
		return _report_error(result)

	var response := {
		"ok": true,
		"path": destination,
		"file": destination.get_file(),
		"public_downloads": false,
		"clipboard_copied": false,
		"includes_flight_state": capture.source != "none",
		"flight_state_source": capture.source,
	}
	if android_download:
		var published := AndroidReportShare.publish(destination)
		if published.ok:
			response["path"] = published.path
			response["file"] = published.file
			response["public_downloads"] = true
			DirAccess.remove_absolute(destination)
		else:
			response["clipboard_copied"] = _copy_report_to_clipboard(capture)
	return response


func share_report(state: Dictionary) -> Dictionary:
	if not OS.has_feature("android"):
		return {
			"ok": false, "shared": false, "path": "", "file": "", "public_downloads": false,
			"reason": "Системное меню «Поделиться» доступно на Android.",
		}
	var destination := ProjectSettings.globalize_path(_next_report_path())
	var capture := _report_flight(state)
	var result := _write_report_archive(destination, capture)
	if result != OK:
		return _report_error(result)
	var handoff := AndroidReportShare.share(destination)
	var available_path := str(handoff.get("path", ""))
	return {
		"ok": true,
		"shared": handoff.ok,
		"path": destination if available_path.is_empty() else available_path,
		"file": handoff.get("file", destination.get_file()),
		"public_downloads": handoff.get("public_downloads", false),
		"reason": handoff.get("reason", ""),
		"includes_flight_state": capture.source != "none",
		"flight_state_source": capture.source,
	}


static func _next_report_path() -> String:
	var stamp := Time.get_datetime_string_from_system(true).replace(":", "-")
	return REPORT_DIR.path_join("orbital-relay-%s-%d.zip" % [stamp, Time.get_ticks_usec()])


func _write_report_archive(destination: String, capture: Dictionary) -> Error:
	var directory_error := DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	if directory_error != OK:
		return directory_error

	var temporary := _temporary_path(destination)
	var zip := ZIPPacker.new()
	var result := zip.open(temporary)
	if result != OK:
		DirAccess.remove_absolute(temporary)
		return result
	var state_bytes: PackedByteArray = capture.bytes
	var summary := _report_summary(capture.source)
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
	return _copy_report_to_clipboard(_report_flight(state))


func _copy_report_to_clipboard(capture: Dictionary) -> bool:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		return false
	var state_bytes: PackedByteArray = capture.bytes
	var text := JSON.stringify(_report_summary(capture.source))
	if not state_bytes.is_empty():
		text += "\n" + state_bytes.get_string_from_utf8()
	# Keep the recent journal tail for the clipboard fallback.
	for index in range(maxi(0, _events.size() - 16), _events.size()):
		text += "\n" + _events[index]
	DisplayServer.clipboard_set(text)
	return true


func _report_summary(flight_state_source: String) -> Dictionary:
	return {
		"game": AndroidReportShare.REPORT_GAME_ID,
		"title": str(ProjectSettings.get_setting("application/config/name", "")),
		"version": str(ProjectSettings.get_setting("application/config/version", "")),
		"godot_version": Engine.get_version_info().get("string", ""),
		"platform": OS.get_name(),
		"exported_utc": Time.get_datetime_string_from_system(true),
		"event_count": _events.size(),
		"includes_flight_state": flight_state_source != "none",
		"flight_state_source": flight_state_source,
	}


static func _report_flight(state: Dictionary) -> Dictionary:
	var candidate := Flight.new()
	var current := _state_bytes(state)
	if _restorable_flight(current, candidate):
		return {"bytes": current, "source": "live"}
	for source: String in ["autosave", "backup"]:
		var path := SAVE_PATH if source == "autosave" else BACKUP_PATH
		var saved := _read_bounded(ProjectSettings.globalize_path(path))
		if _restorable_flight(saved, candidate):
			return {"bytes": saved, "source": source}
	return {"bytes": PackedByteArray(), "source": "none"}


static func _restorable_flight(bytes: PackedByteArray, candidate: Flight) -> bool:
	var parsed := _parse_save(bytes)
	return not parsed.is_empty() and candidate.restore(parsed)


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
	# Each JSON value takes at least one byte. Use the file-size limit
	# to bound traversal without rejecting small but wide catalogues.
	if state.is_empty() or not _is_plain_json(state, 0, [MAX_STATE_BYTES]):
		return PackedByteArray()
	var bytes := JSON.stringify(state, "", true, true).to_utf8_buffer()
	return bytes if bytes.size() <= MAX_STATE_BYTES else PackedByteArray()


static func _read_bounded(path: String, limit: int = MAX_STATE_BYTES) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var length := file.get_length()
	if length < 2 or length > limit:
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
	if not state is Dictionary or not _is_plain_json(state, 0, [bytes.size()]):
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
	return {
		"ok": false, "shared": false, "path": "", "file": "", "public_downloads": false,
		"error": error, "reason": error_string(error),
	}


static func _desktop_download_path(private_path: String) -> String:
	if OS.has_feature("android") or OS.has_feature("web"):
		return private_path
	var downloads := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if downloads.is_empty() or not DirAccess.dir_exists_absolute(downloads):
		return private_path
	return downloads.path_join(DOWNLOAD_SUBDIR).path_join(private_path.get_file())
