extends SceneTree

const Startup := preload("res://voyage_start.tscn")
const Flight := preload("res://scripts/flight_sim.gd")
const Session := preload("res://scripts/session_io.gd")
const Library := preload("res://scripts/voyage_library.gd")

class ReportDestination extends Session:
	var path: String

	func _init(destination: String) -> void:
		path = destination

	func export_report(state: Dictionary, destination: String = "") -> Dictionary:
		return super.export_report(state, path if destination.is_empty() else destination)

var _checks := 0
var _failures: Array[String] = []
var _viewport: SubViewport


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _expect(not FileAccess.file_exists(Session.SAVE_PATH) and not FileAccess.file_exists(Session.BACKUP_PATH)
		and Library.list_slots().is_empty(), "Run the startup flow under an isolated, empty user data directory"):
		_finish()
		return
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.own_world_3d = true
	root.add_child(_viewport)
	await _test_start_and_slots()
	await _test_continue_and_restore()
	await _test_report_restore()
	_viewport.queue_free()
	await process_frame
	_finish()


func _game() -> Node:
	var game := Startup.instantiate()
	_viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	return game


func _test_start_and_slots() -> void:
	var game := _game()
	var menu: CanvasLayer = game._voyages
	await process_frame
	game._physics_process(90.0)
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_expect(menu.is_open() and menu._heading.text == "Elite" and menu._actions["continue"].disabled and menu._actions["recover"].disabled
		and not game._flight_active and not FileAccess.file_exists(Session.SAVE_PATH),
		"A clean launch displays Elite and freezes the scene until the player starts a voyage")
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _tap(menu._actions["new"])
	_expect(game._flight_active and not menu.is_open() and FileAccess.file_exists(Session.SAVE_PATH)
		and game._hud._input_enabled, "A new flight writes its own starting state and activates the real cockpit")

	game.flight.credits = 731
	game._handle_action("settings")
	await process_frame
	var settings_button: Button
	for button: Button in game._settings._buttons:
		if button.text == "Рейсы":
			settings_button = button
			break
	await _tap(settings_button)
	_expect(menu.is_open() and not game._settings.is_open() and not game._hud._input_enabled,
		"The touch settings menu opens the voyage manager and stops cockpit input")
	await _tap(menu._actions["create"])
	menu._name_field.text = "Северный рейс"
	menu._name_field.text_changed.emit(menu._name_field.text)
	await _tap(menu._accept)
	var slots := Library.list_slots()
	if not _expect(slots.size() == 1 and slots[0].name == "Северный рейс"
		and menu._slot_buttons.has(slots[0].id), "The manager creates and lists a named copy of the active flight"):
		game.queue_free()
		await process_frame
		return
	var slot_id: String = slots[0].id
	await _tap(menu._slot_buttons[slot_id])
	await _tap(menu._actions["rename"])
	menu._name_field.text = "Северный рубеж"
	menu._name_field.text_changed.emit(menu._name_field.text)
	await _tap(menu._accept)
	_expect(Library.list_slots()[0].name == "Северный рубеж" and Library.list_slots()[0].id == slot_id,
		"Renaming changes the visible label while preserving the same archive identifier")

	await _tap(menu._actions["new"])
	await _tap(menu._cancel)
	_expect(game.flight.credits == 731 and menu.is_open(), "Cancelling a new flight keeps the current flight unchanged")
	await _tap(menu._actions["new"])
	await _tap(menu._accept)
	var prior := Flight.new()
	_expect(game.flight.credits == Flight.new().credits and prior.restore(Session.load_single_state(Session.BACKUP_PATH))
		and prior.credits == 731, "Confirming a new flight rotates the preceding active progress to the backup")
	game._handle_action("voyages")
	await process_frame
	await _tap(menu._slot_buttons[slot_id])
	await _tap(menu._actions["load"])
	await _tap(menu._accept)
	_expect(game.flight.credits == 731 and not menu.is_open(), "Loading a named copy restores exactly the named progress")
	game._handle_action("voyages")
	await process_frame
	await _tap(menu._slot_buttons[slot_id])
	await _tap(menu._actions["delete"])
	await _tap(menu._cancel)
	_expect(Library.list_slots().size() == 1, "Cancelling deletion keeps the named copy")
	await _tap(menu._actions["delete"])
	await _tap(menu._accept)
	_expect(Library.list_slots().is_empty() and game.flight.credits == 731,
		"Confirmed deletion removes only the selected copy, while the active flight remains")
	await _tap(menu._actions["continue"])
	_expect(game._flight_active and not menu.is_open() and game._hud._input_enabled,
		"Continuing an active flight closes the menu and releases controls")
	game.queue_free()
	await process_frame


func _test_continue_and_restore() -> void:
	var previous := Flight.new()
	previous.credits = 617
	var primary := Flight.new()
	primary.credits = 822
	_expect(Session.save_state(previous.snapshot()) == OK and Session.save_state(primary.snapshot()) == OK,
		"Prepare independent latest and reserve snapshots in the default game location")
	var game := _game()
	var menu: CanvasLayer = game._voyages
	await process_frame
	_expect(menu.is_open() and not game._flight_active and not menu._actions["continue"].disabled
		and not menu._actions["recover"].disabled, "A valid prior flight exposes Continue and Restore at cold start")
	await _tap(menu._actions["continue"])
	_expect(game._flight_active and game.flight.credits == 822 and not menu.is_open(),
		"Continue resumes the exact primary save on an ordinary cold start")
	game.queue_free()
	await process_frame

	var original_backup := FileAccess.get_file_as_bytes(Session.BACKUP_PATH)
	var file := FileAccess.open(Session.SAVE_PATH, FileAccess.WRITE)
	if not _expect(file != null, "Open the isolated primary to simulate damage"):
		return
	file.store_string("{damaged")
	file.close()
	game = _game()
	menu = game._voyages
	await process_frame
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_expect(menu._actions["continue"].disabled and not menu._actions["recover"].disabled
		and FileAccess.get_file_as_string(Session.SAVE_PATH) == "{damaged",
		"A damaged primary remains untouched on the start screen and only valid reserve recovery is offered")
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _tap(menu._actions["recover"])
	var recovered := Flight.new()
	_expect(game.flight.credits == 617 and not menu.is_open()
		and recovered.restore(Session.load_single_state(Session.SAVE_PATH)) and recovered.credits == 617
		and FileAccess.get_file_as_bytes(Session.BACKUP_PATH) == original_backup,
		"Explicit recovery repairs primary and preserves the valid reserve byte for byte")
	game.queue_free()
	await process_frame


func _test_report_restore() -> void:
	var report_path := "user://voyage-test-report.zip"
	var game := _game()
	var menu: CanvasLayer = game._voyages
	await process_frame
	await _tap(menu._actions["continue"])
	game.flight.credits = 912
	_expect(game.flight.contract_action(), "Accept a tracked delivery before taking the diagnostic snapshot")
	game._io = ReportDestination.new(report_path)
	game._io.trace("voyage_test_report")
	game._update_display(0.0)
	await _tap(game._hud._actions["report"])
	var saved_flight: Dictionary = game.flight.snapshot()
	await _tap(game._report_buttons[0])
	var report_bytes := FileAccess.get_file_as_bytes(report_path)
	_expect(not report_bytes.is_empty() and report_path.get_file() in game._report_text.text,
		"The HUD creates a diagnostic ZIP with the active contract and accessible filename")
	await _tap(game._report_buttons.back())
	game.flight.credits = 678
	var outgoing: Dictionary = game.flight.snapshot()
	var primary_before := FileAccess.get_file_as_bytes(Session.SAVE_PATH)
	var backup_before := FileAccess.get_file_as_bytes(Session.BACKUP_PATH)
	game._handle_action("voyages")
	await process_frame

	var journal_path := "user://voyage-test-no-flight.zip"
	_expect(_write_journal_only_report(journal_path), "Create a received journal-only ZIP alongside the active voyage")
	await _choose_report(game, journal_path)
	_expect(menu.is_open() and "только журнал" in menu._status.text and game.flight.snapshot() == outgoing,
		"The chooser explains how to recover from a journal-only ZIP without switching flights")
	var broken_path := "user://voyage-test-broken.zip"
	var broken := FileAccess.open(broken_path, FileAccess.WRITE)
	if _expect(broken != null, "Create a truncated copy of the actual report"):
		broken.store_buffer(report_bytes.slice(0, report_bytes.size() / 2))
		broken.close()
		await _choose_report(game, broken_path)
		_expect(menu.is_open() and "Не удалось прочитать" in menu._status.text and game.flight.snapshot() == outgoing,
			"Selecting a damaged archive leaves the live voyage available")
	_expect(FileAccess.get_file_as_bytes(Session.SAVE_PATH) == primary_before
		and FileAccess.get_file_as_bytes(Session.BACKUP_PATH) == backup_before,
		"Failed imports keep the primary and backup identical on disk")

	await _choose_report(game, report_path, true)
	var preserved := Flight.new()
	_expect(game._flight_active and game.flight.snapshot() == saved_flight and not menu.is_open()
		and preserved.restore(Session.load_single_state(Session.BACKUP_PATH)) and preserved.snapshot() == outgoing
		and FileAccess.get_file_as_bytes(report_path) == report_bytes,
		"Import restores the diagnostic snapshot and backs up the outgoing live voyage")
	game.queue_free()
	await process_frame
	game = _game()
	await _tap(game._voyages._actions["continue"])
	_expect(game._flight_active and game.flight.snapshot() == saved_flight and game._hud._input_enabled,
		"Continue from a cold start resumes the last restored flight and its active delivery")
	game.queue_free()
	await process_frame
	for path: String in [report_path, journal_path, broken_path]:
		DirAccess.remove_absolute(path)


func _write_journal_only_report(path: String) -> bool:
	var zip := ZIPPacker.new()
	if zip.open(path) != OK:
		return false
	var metadata := {"game": "Орбитальный рейс", "event_count": 0, "includes_flight_state": false}
	var success := zip.start_file("report.json") == OK and zip.write_file(JSON.stringify(metadata).to_utf8_buffer()) == OK \
		and zip.close_file() == OK and zip.start_file("events.jsonl") == OK and zip.close_file() == OK
	return zip.close() == OK and success


func _choose_report(game: Node, path: String, app_paused := false) -> void:
	await _tap(game._voyages._actions["import"])
	await _tap(game._voyages._accept)
	if _expect(game._voyage_picker != null, "The menu opens the configured file chooser after confirmation"):
		game._voyage_picker.hide()
		if app_paused:
			game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		game._voyage_picker.file_selected.emit(ProjectSettings.globalize_path(path))
		if app_paused:
			game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)


func _tap(button: Button) -> void:
	await process_frame
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled,
		"Interactive button available: %s" % (button.text if is_instance_valid(button) else "unknown")):
		return
	var position := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 5
		event.position = position
		event.pressed = pressed
		_viewport.push_input(event, true)
	await process_frame


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition


func _finish() -> void:
	for failure: String in _failures:
		printerr(failure)
	print("Voyage startup integration: %d checks, %d failures" % [_checks, _failures.size()])
	quit(int(not _failures.is_empty()))
