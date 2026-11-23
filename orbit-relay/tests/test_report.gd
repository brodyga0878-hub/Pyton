extends SceneTree

const Fixture = preload("res://tests/flight_fixture.gd")

const Flight := preload("res://scripts/flight_sim.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const OrbitRelay := preload("res://main.tscn")
const Startup := preload("res://voyage_start.tscn")
const VoyageImport := preload("res://scripts/voyage_import.gd")

class TestSessionIO extends SessionIO:
	var destination: String

	func _init(path: String) -> void:
		destination = path

	func export_report(state: Dictionary, path: String = "") -> Dictionary:
		return super.export_report(state, destination if path.is_empty() else path)

class InvalidSnapshotFlight extends Flight:
	func snapshot() -> Dictionary:
		var state := super.snapshot()
		state["invalid"] = Vector3.BACK
		return state

var _checks := 0
var _failures: Array[String] = []
var _workspace: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _expect(not FileAccess.file_exists(SessionIO.SAVE_PATH) and not FileAccess.file_exists(SessionIO.BACKUP_PATH)
		and not FileAccess.file_exists(SessionIO.EVENTS_PATH),
		"Run report recovery tests under an isolated, empty user data directory"):
		printerr(_failures[0])
		quit(1)
		return
	_workspace = "user://report-integration-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_test_archive()
	_test_invalid_state_and_destination()
	_test_cold_journal()
	_test_desktop_guard()
	await _test_startup_report()
	await _test_overlay()
	_test_restorable_fallback()
	var absolute := ProjectSettings.globalize_path(_workspace)
	for file: String in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute(absolute.path_join(file))
	DirAccess.remove_absolute(absolute)
	print("Report integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_archive() -> void:
	var flight := Flight.new()
	flight.credits = 714
	flight.ship.fuel = 69.3
	var snapshot := flight.snapshot()
	var log := SessionIO.new()
	const EXTRA := 7
	for index in range(SessionIO.MAX_EVENTS + EXTRA):
		log.trace("step_%d" % index, {"target": flight.target, "index": index, "text": "Проверка"})
	log.trace("bounded_".repeat(20), {"payload": "x".repeat(SessionIO.MAX_EVENT_BYTES * 2)})
	log.trace("invalid_fields", {"position": Vector3.RIGHT})
	var explicit_path := _workspace.path_join("diagnostics.zip")
	var result := log.export_report(snapshot, explicit_path)
	if not _expect(result.ok and result.path == ProjectSettings.globalize_path(explicit_path)
		and result.file == "diagnostics.zip" and not result.public_downloads,
		"An explicit ZIP export returns its exact local file path"):
		return
	_expect(result.get("includes_flight_state", false) == true and result.get("flight_state_source") == "live",
		"A full ZIP export identifies the included active flight")
	var contents := _read_zip(result.path)
	var files := contents.keys()
	files.sort()
	_expect(files == ["events.jsonl", "flight.json", "report.json"], "The export contains exactly the three documented report entries")
	var report := _dictionary(contents.get("report.json", ""))
	_expect(report.get("game") == str(ProjectSettings.get_setting("application/config/name"))
		and report.get("version") == str(ProjectSettings.get_setting("application/config/version"))
		and report.get("platform") == OS.get_name()
		and not str(report.get("godot_version", "")).is_empty() and not str(report.get("exported_utc", "")).is_empty()
		and report.get("event_count") == SessionIO.MAX_EVENTS and report.get("includes_flight_state", false)
		and report.get("flight_state_source") == "live",
		"Metadata reports the actual game version, engine, platform and bounded event count")
	var archived_state := _dictionary(contents.get("flight.json", ""))
	var restored := Flight.new()
	_expect(archived_state == _json(snapshot) and restored.restore(archived_state) and restored.credits == 714,
		"The archived flight is the current resumable game state")
	var lines: PackedStringArray = str(contents.get("events.jsonl", "")).split("\n", false)
	if not _expect(lines.size() == SessionIO.MAX_EVENTS and str(contents["events.jsonl"]).ends_with("\n"),
		"The journal is valid bounded JSON Lines ending after the newest event"):
		return
	var oldest := _dictionary(lines[0])
	var latest := _dictionary(lines[-1])
	var oversized := _dictionary(lines[-2])
	_expect(oldest.get("event") == "step_%d" % (EXTRA + 2) and oldest.get("fields", {}).get("index") == EXTRA + 2
		and oldest.get("fields", {}).get("text") == "Проверка",
		"The journal keeps the newest entries in order and preserves valid localized fields")
	_expect(str(oversized.get("event", "")).length() == 80 and not oversized.has("fields")
		and latest.get("event") == "invalid_fields" and not latest.has("fields")
		and lines[-2].to_utf8_buffer().size() <= SessionIO.MAX_EVENT_BYTES,
		"Unsafe or oversized diagnostic fields are omitted without losing their event names")


func _test_invalid_state_and_destination() -> void:
	var log := SessionIO.new()
	log.trace("recovery_hint", {"probe": 38})
	var unsafe_state := {"schema": 15, "invalid": Vector3.BACK}
	var archive := _workspace.path_join("partial.zip")
	var partial := log.export_report(unsafe_state, archive)
	if _expect(partial.ok, "A malformed flight still allows a journal-only archive"):
		_expect(partial.get("includes_flight_state", true) == false,
			"A journal-only ZIP export reports that it omits the flight state")
		var contents := _read_zip(partial.path)
		var report := _dictionary(contents.get("report.json", ""))
		_expect(not report.get("includes_flight_state", true) and not contents.has("flight.json")
			and _dictionary(str(contents.get("events.jsonl", "")).strip_edges()).get("event") == "recovery_hint",
			"Invalid data never enters the ZIP as a resumable flight, while metadata and the safe journal remain readable")
	var blocker_path := _workspace.path_join("not-a-directory")
	var blocker := FileAccess.open(blocker_path, FileAccess.WRITE)
	if not _expect(blocker != null, "Create a plain file in place of a destination directory"):
		return
	blocker.store_string("original")
	blocker.close()
	var failed := log.export_report(Flight.new().snapshot(), blocker_path.path_join("refused.zip"))
	_expect(not failed.ok and str(failed.get("path", "")).is_empty() and str(failed.get("file", "")).is_empty()
		and not str(failed.get("reason", "")).is_empty() and FileAccess.get_file_as_string(blocker_path) == "original",
		"An impossible archive destination returns an error without replacing the original data")
	var occupied := ProjectSettings.globalize_path(_workspace.path_join("occupied.zip"))
	if _expect(DirAccess.make_dir_absolute(occupied) == OK, "Leave a directory occupying the requested ZIP filename"):
		var blocked_rename := log.export_report(Flight.new().snapshot(), occupied)
		var files := Array(DirAccess.get_files_at(ProjectSettings.globalize_path(_workspace)))
		_expect(not blocked_rename.ok and DirAccess.dir_exists_absolute(occupied)
			and not files.any(func(file: String) -> bool: return file.ends_with(".tmp")),
			"A failed final rename preserves the destination directory and removes its temporary ZIP")
		DirAccess.remove_absolute(occupied)
	var clipboard := DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)
	_expect(log.copy_report_text(unsafe_state) == clipboard,
		"The text fallback reports native clipboard availability accurately")
	if clipboard:
		var lines := DisplayServer.clipboard_get().split("\n", false)
		_expect(lines.size() == 2 and not _dictionary(lines[0]).get("includes_flight_state", true)
			and _dictionary(lines[1]).get("event") == "recovery_hint",
			"The copy fallback carries the metadata and safe recent events even without a valid saved flight")


func _test_restorable_fallback() -> void:
	var log := SessionIO.new()
	var flight := Flight.new()
	flight.credits = 218
	var previous := flight.snapshot()
	flight.credits = 506
	var primary := flight.snapshot()
	flight.credits = 733
	var live := flight.snapshot()
	var invalid := live.duplicate(true)
	invalid["credits"] = -1
	if _expect(SessionIO.save_state(previous) == OK and SessionIO.save_state(primary) == OK,
		"Start report recovery with valid primary and reserve flights"):
		_check_report_source(log, live, "live", 733)
		_check_report_source(log, invalid, "autosave", 506)
		if _expect(SessionIO.save_state(invalid, SessionIO.SAVE_PATH, true) == OK,
			"The old primary can still be parseable JSON when it is unfit for flight restore"):
			_check_report_source(log, invalid, "backup", 218)
			_expect(SessionIO.load_single_state(SessionIO.SAVE_PATH) == _json(invalid)
				and SessionIO.load_single_state(SessionIO.BACKUP_PATH) == _json(previous),
				"Export leaves both autosave files intact")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SessionIO.SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SessionIO.BACKUP_PATH))


func _test_cold_journal() -> void:
	var first := SessionIO.new(true)
	first.trace("initial_event")
	_expect("initial_event" in FileAccess.get_file_as_string(SessionIO.EVENTS_PATH),
		"The first runtime event reaches disk before the first autosave")
	for index in range(SessionIO.MAX_EVENTS + 5):
		first.trace("previous_session_%d" % index)
	first.flush_events()
	var persisted := FileAccess.get_file_as_bytes(SessionIO.EVENTS_PATH)
	_expect(persisted.size() <= SessionIO.MAX_JOURNAL_BYTES, "The persisted journal observes the same size limit as a ZIP entry")
	first = null
	var cold := SessionIO.new(true)
	var cold_report := cold.export_report({}, _workspace.path_join("cold.zip"))
	if _expect(cold_report.ok and not cold_report.includes_flight_state, "A cold process can report before creating a new flight"):
		var contents := _read_zip(cold_report.path)
		var lines := str(contents.get("events.jsonl", "")).split("\n", false)
		if _expect(lines.size() == SessionIO.MAX_EVENTS, "The cold report retains the most recent bounded journal"):
			_expect(_dictionary(lines[0]).get("event") == "previous_session_5"
				and _dictionary(lines[-1]).get("event") == "previous_session_%d" % (SessionIO.MAX_EVENTS + 4)
				and not str(_dictionary(lines[-1]).get("recorded_utc", "")).is_empty(),
				"The cold journal preserves event order and wall-clock time")
	var damaged := FileAccess.open(SessionIO.EVENTS_PATH, FileAccess.WRITE)
	if _expect(damaged != null, "Open the journal fixture to simulate an interrupted write"):
		damaged.store_string("{torn line\n{\"event\":\"recovered_line\"}\n")
		damaged.close()
		var repaired := SessionIO.new(true).export_report({}, _workspace.path_join("partial-journal.zip"))
		if _expect(repaired.ok, "A malformed journal line does not prevent ZIP export"):
			var contents := _read_zip(repaired.path)
			_expect(_dictionary(str(contents.get("events.jsonl", "")).strip_edges()).get("event") == "recovered_line",
				"Journal recovery keeps the valid record and discards the corrupt line")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SessionIO.EVENTS_PATH))


func _check_report_source(log: SessionIO, state: Dictionary, source: String, credits: int) -> void:
	_expect(SessionIO.report_flight_source(state) == source, "Report preview identifies the %s flight" % source)
	var result := log.export_report(state, _workspace.path_join(source + ".zip"))
	if not _expect(result.ok and result.includes_flight_state and result.flight_state_source == source,
		"Report export identifies the %s flight" % source):
		return
	var contents := _read_zip(result.path)
	var metadata := _dictionary(str(contents.get("report.json", "")))
	var restored := Flight.new()
	_expect(metadata.get("flight_state_source") == source
		and VoyageImport.load_report(result.path, restored.restore) == OK and restored.credits == credits,
		"The in-game ZIP importer restores the selected %s flight" % source)


func _test_desktop_guard() -> void:
	if OS.has_feature("android"):
		return
	var log := SessionIO.new()
	var directory := ProjectSettings.globalize_path(SessionIO.REPORT_DIR)
	var existing := DirAccess.dir_exists_absolute(directory)
	var old_files := DirAccess.get_files_at(directory) if existing else PackedStringArray()
	var answer := log.share_report(Flight.new().snapshot())
	_expect(not answer.ok and not answer.get("shared", true) and not answer.get("public_downloads", false)
		and str(answer.get("path", "")).is_empty() and not str(answer.get("reason", "")).is_empty()
		and DirAccess.dir_exists_absolute(directory) == existing
		and (not existing or DirAccess.get_files_at(directory) == old_files),
		"The mobile share action on desktop neither reports sharing nor creates an orphaned archive")


func _test_overlay() -> void:
	if OS.has_feature("android"):
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := OrbitRelay.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = Flight.new()
	game.flight.credits = 318
	Fixture.launch(game.flight)
	var assigned_path := _workspace.path_join("touch.zip")
	game._io = TestSessionIO.new(assigned_path)
	game._io.trace("overlay_probe", {"target": game.flight.target})
	game._update_display(0.0)
	await process_frame
	_tap(viewport, game._hud._actions["report"], "Open the report overlay through the actual HUD touch action")
	await process_frame
	var elapsed: float = game.flight.elapsed
	game._physics_process(0.75)
	_expect(game._report.visible and not game._hud._input_enabled and game.flight.elapsed == elapsed,
		"The overlay freezes flight motion and consumes input while open")
	_expect("состояние рейса" in game._report_text.text.to_lower()
		and "только журнал" not in game._report_text.text.to_lower(),
		"The report overlay advertises the full flight state when the snapshot is valid")
	if not _expect(game._report_buttons.size() == 3, "Desktop exposes local save, text copy and close controls"):
		viewport.queue_free()
		await process_frame
		return
	var save: Button = game._report_buttons[0]
	var at := save.get_global_rect().get_center()
	_touch(viewport, at, true)
	_touch(viewport, at, false, true)
	_expect(not FileAccess.file_exists(assigned_path) and game._report_touches.is_empty(),
		"Cancelling a touch before release writes no archive")
	_tap(viewport, save, "Write the report ZIP by touch")
	await process_frame
	var contents := _read_zip(assigned_path)
	_expect(_dictionary(contents.get("flight.json", "")) == _json(game.flight.snapshot())
		and "overlay_probe" in str(contents.get("events.jsonl", ""))
		and "touch.zip" in game._report_text.text and "только журнал" not in game._report_text.text.to_lower()
		and game._report.visible,
		"Saving from the real overlay writes the shown flight, journal and accessible ZIP filename")
	var copy: Button = game._report_buttons[1]
	_tap(viewport, copy, "Request the text copy fallback by touch")
	await process_frame
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		_expect("недоступен" in game._report_text.text and FileAccess.file_exists(assigned_path),
			"The headless clipboard error leaves the diagnostic ZIP intact")
	_tap(viewport, game._report_buttons.back(), "Close the report via touch")
	await process_frame
	game._physics_process(0.25)
	_expect(not game._report.visible and game._report_touches.is_empty() and game._hud._input_enabled
		and game.flight.elapsed > elapsed, "Closing releases the captured fingers and resumes real flight")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SessionIO.SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SessionIO.BACKUP_PATH))
	await _test_journal_only_overlay(viewport, game)
	await _test_report_during_manoeuvres(viewport, game)
	viewport.queue_free()
	await process_frame


func _test_journal_only_overlay(viewport: SubViewport, game: Node) -> void:
	game.flight = InvalidSnapshotFlight.new()
	Fixture.launch(game.flight)
	var assigned_path := _workspace.path_join("journal-only.zip")
	var absolute_path := ProjectSettings.globalize_path(assigned_path)
	game._io = TestSessionIO.new(assigned_path)
	game._io.trace("journal_only_probe")
	game._update_display(0.0)
	await process_frame
	_tap(viewport, game._hud._actions["report"], "Open the report overlay with an invalid flight snapshot")
	await process_frame
	var preview: String = game._report_text.text.to_lower()
	_expect(game._report.visible and "только журнал" in preview and "состояни" in preview
		and "рейса" in preview and not FileAccess.file_exists(assigned_path),
		"The overlay tells the player before exporting that the ZIP will omit the flight state")
	_tap(viewport, game._report_buttons[0], "Write the journal-only report ZIP by touch")
	await process_frame
	_expect(game._report.visible and "только журнал" in game._report_text.text.to_lower()
		and absolute_path in game._report_text.text,
		"The overlay confirms journal-only export and still gives the archive path")
	var contents := _read_zip(assigned_path)
	_expect(contents.size() == 2 and not contents.has("flight.json")
		and _dictionary(contents.get("report.json", "")).get("includes_flight_state", true) == false
		and "journal_only_probe" in str(contents.get("events.jsonl", "")),
		"The ZIP from the overlay contains the journal and metadata without the flight state")
	game._close_report()


func _test_startup_report() -> void:
	if OS.has_feature("android"):
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1560, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := Startup.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var menu: CanvasLayer = game._voyages
	var report: Button = menu._actions["report"]
	var journal_path := _workspace.path_join("startup-journal.zip")
	game._io = TestSessionIO.new(journal_path)
	await process_frame
	_tap(viewport, report, "Open the diagnostic report from the real startup menu")
	await process_frame
	_expect(game._report.visible and not menu.is_open() and not game._flight_active
		and "только журнал" in game._report_text.text.to_lower(),
		"A clean startup reports its journal without packaging an untouched new flight")
	_tap(viewport, game._report_buttons[0], "Save the startup report")
	var journal := _read_zip(journal_path)
	_expect(not journal.has("flight.json") and not FileAccess.file_exists(SessionIO.SAVE_PATH),
		"Sending a startup journal does not create a flight or an autosave")
	_tap(viewport, game._report_buttons.back(), "Close the report from startup")
	await process_frame
	_expect(menu.is_open() and not game._report.visible and not game._hud._input_enabled,
		"Closing the report restores the startup menu with the flight still inactive")

	var backup := Flight.new()
	backup.credits = 576
	if _expect(SessionIO.save_state(backup.snapshot(), SessionIO.BACKUP_PATH) == OK,
		"Prepare a restorable backup without a primary autosave"):
		var backup_path := _workspace.path_join("startup-backup.zip")
		game._io = TestSessionIO.new(backup_path)
		_tap(viewport, report, "Open the report again when only a backup is available")
		await process_frame
		_expect("резервной копии" in game._report_text.text, "The report preview names the backup it will include")
		_tap(viewport, game._report_buttons[0], "Save the diagnostic archive with backup data")
		var archive := _read_zip(backup_path)
		_expect(_dictionary(str(archive.get("flight.json", ""))).get("credits") == 576
			and "резервной копии" in game._report_text.text and "startup-backup.zip" in game._report_text.text
			and not FileAccess.file_exists(SessionIO.SAVE_PATH),
			"The archive contains the backup and the confirmation identifies it and the ZIP file")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SessionIO.BACKUP_PATH))
	viewport.queue_free()
	await process_frame


func _test_report_during_manoeuvres(viewport: SubViewport, game: Node) -> void:
	var flight := Flight.new()
	game.flight = flight
	var report: Button = game._hud._actions["report"]
	if _expect(flight.dock_action() and flight.departure_status().active and flight.toggle_time_pause(),
		"Set up a paused departure from the starter port"):
		var departure_path := _workspace.path_join("departure.zip")
		game._io = TestSessionIO.new(departure_path)
		game._update_display(0.0)
		await process_frame
		var before := flight.snapshot()
		_tap(viewport, report, "Open the report by touch while departure is paused")
		game._physics_process(0.5)
		_expect(game._report.visible and flight.snapshot() == before,
			"The report opens during departure without advancing or cancelling it")
		_tap(viewport, game._report_buttons[0], "Save the report during a paused departure")
		var departure := _read_zip(departure_path)
		_expect(_dictionary(departure.get("report.json", "")).get("flight_state_source") == "live"
			and _dictionary(departure.get("flight.json", "")) == _json(before),
			"A departure report contains the live suspended flight")
		game._close_report()
		_expect(flight.time_paused, "Returning from the report leaves the player's pause in effect")
	flight = Flight.new()
	game.flight = flight
	Fixture.launch(flight)
	var destination := 1
	if not _expect(flight.plan_jump(destination), "Plot a nearby destination for the diagnostic test"):
		return
	flight.change_throttle(0.16)
	for _step in range(ceili(12.0 / Fixture.STEP)):
		if flight.jump_status(destination).ok:
			break
		flight.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
	if not _expect(flight.start_jump(), "Start a real payable jump outside the port clearance"):
		return
	for _step in range(ceili(Flight.JUMP_CHARGE / Fixture.STEP) + 1):
		if flight.jump_progress_status().is_transit:
			break
		flight.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
	if not _expect(flight.jump_progress_status().is_transit, "Enter the paid transit phase"):
		return
	var transit_path := _workspace.path_join("transit.zip")
	game._io = TestSessionIO.new(transit_path)
	game._update_display(0.0)
	await process_frame
	var before := flight.snapshot()
	_tap(viewport, report, "Open the report by touch during a paid jump")
	game._physics_process(0.5)
	_expect(game._report.visible and flight.snapshot() == before,
		"The report remains available during a jump and stops the live clock")
	_tap(viewport, game._report_buttons[0], "Save the report during a paid jump")
	var transit := _read_zip(transit_path)
	_expect(_dictionary(transit.get("report.json", "")).get("flight_state_source") == "live"
		and _dictionary(transit.get("flight.json", "")) == _json(before),
		"A transit report contains the live paid jump and its remaining progress")
	game._close_report()


func _read_zip(path: String) -> Dictionary:
	var archive := ZIPReader.new()
	var result := {}
	if not _expect(archive.open(path) == OK, "The generated diagnostic ZIP opens with the standard reader"):
		return result
	for file: String in archive.get_files():
		result[file] = archive.read_file(file).get_string_from_utf8()
	archive.close()
	return result


func _dictionary(text: String) -> Dictionary:
	var value: Variant = JSON.parse_string(text)
	return value if value is Dictionary else {}


func _json(value: Dictionary) -> Dictionary:
	return _dictionary(JSON.stringify(value, "", true, true))


func _tap(viewport: SubViewport, button: Button, description: String) -> void:
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, description):
		return
	var position := button.get_global_rect().get_center()
	_touch(viewport, position, true)
	_touch(viewport, position, false)


func _touch(viewport: SubViewport, position: Vector2, pressed: bool, cancelled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 17
	event.position = position
	event.pressed = pressed
	event.canceled = cancelled
	viewport.push_input(event, true)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
