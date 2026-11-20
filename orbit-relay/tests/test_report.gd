extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const OrbitRelay := preload("res://main.tscn")

class TestSessionIO extends SessionIO:
	var destination: String

	func _init(path: String) -> void:
		destination = path

	func export_report(state: Dictionary, path: String = "") -> Dictionary:
		return super.export_report(state, destination if path.is_empty() else path)

var _checks := 0
var _failures: Array[String] = []
var _workspace: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_workspace = "user://report-integration-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_test_archive()
	_test_invalid_state_and_destination()
	_test_desktop_guard()
	await _test_overlay()
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
	var contents := _read_zip(result.path)
	var files := contents.keys()
	files.sort()
	_expect(files == ["events.jsonl", "flight.json", "report.json"], "The export contains exactly the three documented report entries")
	var report := _dictionary(contents.get("report.json", ""))
	_expect(report.get("game") == str(ProjectSettings.get_setting("application/config/name"))
		and report.get("version") == str(ProjectSettings.get_setting("application/config/version"))
		and report.get("platform") == OS.get_name()
		and not str(report.get("godot_version", "")).is_empty() and not str(report.get("exported_utc", "")).is_empty()
		and report.get("event_count") == SessionIO.MAX_EVENTS and report.get("includes_flight_state", false),
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
	game.flight.dock_action()
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
		and "touch.zip" in game._report_text.text and game._report.visible,
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
	viewport.queue_free()
	await process_frame


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
