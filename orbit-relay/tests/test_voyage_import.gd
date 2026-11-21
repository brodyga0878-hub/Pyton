extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const ReportShare := preload("res://scripts/android_report_share.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const VoyageImport := preload("res://scripts/voyage_import.gd")

var _directory: String
var _checks := 0
var _validator_calls := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_directory = ProjectSettings.globalize_path("user://voyage-import-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	if _expect(DirAccess.make_dir_absolute(_directory) == OK, "Create an isolated directory"):
		_test_report_roundtrip()
		_test_invalid_reports()
		for path: String in DirAccess.get_files_at(_directory):
			DirAccess.remove_absolute(_directory.path_join(path))
		DirAccess.remove_absolute(_directory)
	for failure: String in _failures:
		printerr(failure)
	print("Voyage ZIP import: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _test_report_roundtrip() -> void:
	var flight := Flight.new()
	flight.credits = 714
	flight.ship.fuel = 69.3
	_expect(flight.market_trade("ore", "buy", 1) and flight.contract_action(), "Create a real purchase and tracked contract")
	var log := SessionIO.new()
	log.trace("probe", {"text": "Проверка 🚀"})
	var archive := _directory.path_join("received by mail.zip")
	var result := log.export_report(flight.snapshot(), archive)
	if not _expect(result.ok and result.includes_flight_state, "Export a complete ZIP to a user-selected filename"):
		return
	var expected_zip := FileAccess.get_file_as_bytes(archive)
	var save_before := _saved_files()
	var restored := Flight.new()
	_expect(VoyageImport.load_report(archive, restored.restore) == OK and restored.credits == flight.credits
		and is_equal_approx(restored.ship.fuel, 69.3) and restored.contract_stage == flight.contract_stage,
		"Restore a real flight, including currency, fuel and the active contract")
	_expect(FileAccess.get_file_as_bytes(archive) == expected_zip and _saved_files() == save_before,
		"Import only reads the selected archive and leaves the active save and backup untouched")
	_expect(VoyageImport.load_report(archive, func(_state: Dictionary) -> int: return 1) == ERR_INVALID_DATA,
		"Acceptance must be an explicit bool from the validator")


func _test_invalid_reports() -> void:
	var snapshot := Flight.new().snapshot()
	var valid_state := JSON.stringify(snapshot, "", true, true).to_utf8_buffer()
	var metadata := {"game": "Орбитальный рейс", "includes_flight_state": true, "event_count": 0}
	_check_archive("extra entry", metadata, valid_state, "", {"../flight.json": valid_state}, ERR_FILE_CORRUPT)
	_check_archive("unknown entry case", metadata, null, "", {"Flight.json": valid_state}, ERR_FILE_CORRUPT)
	_check_archive("missing flight", metadata, null, "", {}, ERR_INVALID_DATA)
	var journal_only := metadata.duplicate()
	journal_only.includes_flight_state = false
	_check_archive("journal only", journal_only, null, "", {}, ERR_UNAVAILABLE)
	_check_archive("unexpected flight", journal_only, valid_state, "", {}, ERR_INVALID_DATA)
	var wrong_type := metadata.duplicate()
	wrong_type.includes_flight_state = 1
	_check_archive("non-boolean flight flag", wrong_type, valid_state, "", {}, ERR_INVALID_DATA)
	var foreign := metadata.duplicate()
	foreign.game = "Another game"
	_check_archive("different game", foreign, valid_state, "", {}, ERR_INVALID_DATA)
	var wrong_count := metadata.duplicate()
	wrong_count.event_count = 1
	_check_archive("inconsistent event count", wrong_count, valid_state, "", {}, ERR_INVALID_DATA)
	_check_archive("invalid journal line", wrong_count, valid_state, "broken\n", {}, ERR_INVALID_DATA)
	_check_archive("non-UTF8 state", metadata, PackedByteArray([0x7b, 0xc0, 0x7d]), "", {}, ERR_INVALID_DATA)
	_check_archive("malformed state", metadata, "[1, 2, 3]".to_utf8_buffer(), "", {}, ERR_INVALID_DATA)
	_check_archive("oversized expanded state", metadata, " ".repeat(SessionIO.MAX_STATE_BYTES + 1).to_utf8_buffer(),
		"", {}, ERR_INVALID_DATA)
	var bad_crc := _directory.path_join("altered crc.zip")
	if _expect(_create_zip(bad_crc, metadata, valid_state, "", {}) and _alter_crc(bad_crc, "flight.json"),
		"Create a ZIP with valid JSON bytes and bad CRC headers"):
		var print_errors := Engine.print_error_messages
		Engine.print_error_messages = false # ZIPReader logs the expected CRC failure.
		var result := VoyageImport.load_report(bad_crc, _validator)
		Engine.print_error_messages = print_errors
		_expect(result == ERR_FILE_CORRUPT, "Reject a CRC mismatch even when the underlying flight still parses")
	var empty_bad_crc := _directory.path_join("altered empty crc.zip")
	if _expect(_create_zip(empty_bad_crc, metadata, valid_state, "", {}) and _alter_crc(empty_bad_crc, "events.jsonl"),
		"Create a ZIP with a bad CRC for its empty journal"):
		_expect(VoyageImport.load_report(empty_bad_crc, _validator) == ERR_FILE_CORRUPT,
			"Distinguish a corrupt journal from valid empty contents")

	snapshot.credits = -1
	var invalid := _directory.path_join("invalid flight schema fields.zip")
	if _expect(_create_zip(invalid, metadata, JSON.stringify(snapshot).to_utf8_buffer(), "", {}), "Create a semantic rejection fixture"):
		var candidate := Flight.new()
		var credits := candidate.credits
		_expect(VoyageImport.load_report(invalid, candidate.restore) == ERR_INVALID_DATA and candidate.credits == credits,
			"The flight validator rejects a structurally valid ZIP with impossible state")
	var oversized := _directory.path_join("oversized.zip")
	var file := FileAccess.open(oversized, FileAccess.WRITE)
	if _expect(file != null, "Create an oversized raw archive fixture"):
		file.seek(ReportShare.MAX_ZIP_BYTES)
		file.store_8(0)
		file.close()
		_expect(VoyageImport.load_report(oversized, _validator) == ERR_FILE_CORRUPT, "Reject a ZIP above the raw file-size limit")
	_expect(VoyageImport.load_report(_directory.path_join("missing.zip"), _validator) != OK,
		"An unreadable input fails before involving the flight validator")
	_expect(_validator_calls == 0, "Invalid or journal-only input never reaches the validator")


func _check_archive(label: String, metadata: Dictionary, state: Variant, journal: String, extras: Dictionary, error: Error) -> void:
	var path := _directory.path_join(label + ".zip")
	if _expect(_create_zip(path, metadata, state, journal, extras), "Create archive: " + label):
		_expect(VoyageImport.load_report(path, _validator) == error, "Reject archive: " + label)


func _create_zip(path: String, metadata: Dictionary, state: Variant, journal: String, extras: Dictionary) -> bool:
	var zip := ZIPPacker.new()
	if zip.open(path) != OK:
		return false
	var entries := {"report.json": JSON.stringify(metadata).to_utf8_buffer(), "events.jsonl": journal.to_utf8_buffer()}
	if state != null:
		entries["flight.json"] = state
	entries.merge(extras)
	for name: String in entries:
		if zip.start_file(name) != OK or zip.write_file(entries[name]) != OK or zip.close_file() != OK:
			zip.close()
			return false
	return zip.close() == OK


func _alter_crc(path: String, entry: String) -> bool:
	var bytes := FileAccess.get_file_as_bytes(path)
	var end := bytes.size() - 22
	var central := int(bytes.decode_u32(end + 16))
	for index in range(bytes.decode_u16(end + 10)):
		var size := bytes.decode_u16(central + 28)
		if bytes.slice(central + 46, central + 46 + size).get_string_from_ascii() == entry:
			var local := int(bytes.decode_u32(central + 42))
			var crc := bytes.decode_u32(central + 16) ^ 1
			bytes.encode_u32(central + 16, crc)
			bytes.encode_u32(local + 14, crc)
			var file := FileAccess.open(path, FileAccess.WRITE)
			return file != null and file.store_buffer(bytes)
		central += 46 + size + bytes.decode_u16(central + 30) + bytes.decode_u16(central + 32)
	return false


func _saved_files() -> Array:
	var result := []
	for path in [SessionIO.SAVE_PATH, SessionIO.SAVE_PATH + ".previous"]:
		result.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null)
	return result


func _validator(_state: Dictionary) -> bool:
	_validator_calls += 1
	return true


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
