extends RefCounted
## Reads a diagnostic ZIP into a caller-supplied flight validator.
## The caller owns the candidate flight and any decision to save it.

const ReportShare := preload("res://scripts/android_report_share.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const ENTRY_LIMITS := {
	"report.json": 4096,
	"events.jsonl": SessionIO.MAX_EVENTS * (SessionIO.MAX_EVENT_BYTES + 1),
	"flight.json": SessionIO.MAX_STATE_BYTES,
}


static func load_report(path: String, validator: Callable) -> Error:
	if path.is_empty() or not validator.is_valid():
		return ERR_INVALID_PARAMETER
	var source := FileAccess.open(path, FileAccess.READ)
	if source == null:
		return FileAccess.get_open_error()
	var length := source.get_length()
	if length < 22 or length > ReportShare.MAX_ZIP_BYTES:
		return ERR_FILE_CORRUPT
	var bytes := source.get_buffer(length)
	source.close()
	if bytes.size() != length or not ReportShare._zip_policy(bytes):
		return ERR_FILE_CORRUPT
	var sizes := _entry_sizes(bytes)
	if sizes.is_empty():
		return ERR_FILE_CORRUPT
	for name: String in sizes:
		if sizes[name] > ENTRY_LIMITS[name]:
			return ERR_INVALID_DATA

	# ZIPReader takes a path. Give it a private copy of exactly the bytes that passed
	# the size and entry checks, even if the selected file changes or is a content URI.
	var staged := FileAccess.create_temp(FileAccess.WRITE, "orbital-relay-import", "zip")
	if staged == null:
		return FileAccess.get_open_error()
	var written := staged.store_buffer(bytes)
	staged.flush()
	var error := staged.get_error()
	var staged_path := staged.get_path_absolute()
	staged.close()
	if not written or error != OK:
		return error if error != OK else ERR_FILE_CANT_WRITE
	var result := _read_report(staged_path, sizes, validator)
	staged = null
	return result


static func _entry_sizes(bytes: PackedByteArray) -> Dictionary:
	# The shared ZIP policy has already checked record bounds and entry count.
	var end := -1
	for cursor in range(bytes.size() - 22, maxi(-1, bytes.size() - 65558), -1):
		if bytes.decode_u32(cursor) == 0x06054b50 and cursor + 22 + bytes.decode_u16(cursor + 20) == bytes.size():
			end = cursor
			break
	if end < 0:
		return {}
	var central := int(bytes.decode_u32(end + 16))
	var sizes := {}
	for entry in range(bytes.decode_u16(end + 10)):
		var name_length := bytes.decode_u16(central + 28)
		var name_bytes := bytes.slice(central + 46, central + 46 + name_length)
		var name := name_bytes.get_string_from_ascii()
		var local := int(bytes.decode_u32(central + 42))
		var local_length := bytes.decode_u16(local + 26)
		var size := int(bytes.decode_u32(central + 24))
		if not ENTRY_LIMITS.has(name) or name.to_ascii_buffer() != name_bytes:
			return {}
		if bytes.slice(local + 30, local + 30 + local_length) != name_bytes:
			return {}
		if size == 0 and bytes.decode_u32(central + 16) != 0:
			return {}
		sizes[name] = size
		central += 46 + name_length + bytes.decode_u16(central + 30) + bytes.decode_u16(central + 32)
	return sizes


static func _read_report(path: String, sizes: Dictionary, validator: Callable) -> Error:
	var zip := ZIPReader.new()
	if zip.open(path) != OK:
		return ERR_FILE_CORRUPT
	var names := zip.get_files()
	var has_state := names.has("flight.json")
	if names.size() != sizes.size() or not names.has("report.json") or not names.has("events.jsonl"):
		return ERR_FILE_CORRUPT
	var metadata_bytes := zip.read_file("report.json", true)
	var journal_bytes := zip.read_file("events.jsonl", true)
	if metadata_bytes.size() != sizes["report.json"] or journal_bytes.size() != sizes["events.jsonl"]:
		return ERR_FILE_CORRUPT
	var metadata := SessionIO._parse_save(metadata_bytes)
	var includes_state: Variant = metadata.get("includes_flight_state")
	if metadata.get("game") != "Орбитальный рейс" or not includes_state is bool or includes_state != has_state:
		return ERR_INVALID_DATA
	if not _valid_journal(journal_bytes, metadata.get("event_count")):
		return ERR_INVALID_DATA
	if not has_state:
		return ERR_UNAVAILABLE
	var state_bytes := zip.read_file("flight.json", true)
	zip.close()
	if state_bytes.size() != sizes.get("flight.json", -1):
		return ERR_FILE_CORRUPT
	var state := SessionIO._parse_save(state_bytes)
	if state.is_empty():
		return ERR_INVALID_DATA
	var accepted: Variant = validator.call(state)
	return OK if accepted is bool and accepted else ERR_INVALID_DATA


static func _valid_journal(bytes: PackedByteArray, event_count: Variant) -> bool:
	if not event_count is float or not SessionIO._valid_utf8(bytes):
		return false
	var lines := bytes.get_string_from_utf8().split("\n", false)
	if lines.size() != event_count or lines.size() > SessionIO.MAX_EVENTS:
		return false
	for line: String in lines:
		var encoded := line.to_utf8_buffer()
		if encoded.size() > SessionIO.MAX_EVENT_BYTES or SessionIO._parse_save(encoded).is_empty():
			return false
	return true
