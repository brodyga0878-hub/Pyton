extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Session := preload("res://scripts/session_io.gd")
const OrbitRelay := preload("res://main.tscn")
const MAIN_SAVE := Session.SAVE_PATH
const BACKUP := MAIN_SAVE + ".previous"

var _checks := 0
var _failures: Array[String] = []
var _archive: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_archive = "user://backup-probe-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_test_selection()
	var original := _original_files()
	if _expect(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(MAIN_SAVE))
		and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(BACKUP)),
		"The default save paths can be isolated for actual scene boot tests"):
		await _test_main_recovery()
		await _test_invalid_recovery()
		_remove(MAIN_SAVE)
		_remove(BACKUP)
		await _test_pause_notification()
		await _test_autopilot_background()
		await _test_scoop_background()
		await _test_jump_notifications()
		await _test_paid_jump_background()
		_restore_original_files(original)
	for path: String in [_archive, _archive + ".previous"]:
		_remove(path)
	print("Flight backup integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(int(not _failures.is_empty()))


func _test_selection() -> void:
	var destination := Flight.new()
	_expect(Session.load_valid_state(_archive, destination.restore) == Session.LoadResult.NO_SAVE,
		"Missing copies are distinct from bad data")
	var flight := Flight.new()
	flight.credits = 115
	_expect(Session.save_state(flight.snapshot(), _archive) == OK, "Write the first valid save")
	flight.credits = 390
	_expect(Session.save_state(flight.snapshot(), _archive) == OK, "Write a newer valid save and rotate the original")
	_expect(Session.load_valid_state(_archive, destination.restore) == Session.LoadResult.PRIMARY
		and destination.credits == 390, "Prefer a valid newer primary over an older valid backup")
	var old_bytes := FileAccess.get_file_as_bytes(_archive + ".previous")
	_expect(_write(_archive, "{\"truncated\":".to_utf8_buffer()), "Create an interrupted write as the primary")
	_expect(Session.load_valid_state(_archive, destination.restore) == Session.LoadResult.BACKUP
		and destination.credits == 115 and FileAccess.get_file_as_bytes(_archive + ".previous") == old_bytes,
		"Structural corruption falls back without touching the old bytes")


func _test_main_recovery() -> void:
	var pilot := Flight.new()
	pilot.credits = 246
	if not _expect(Fixture.depart(pilot), "Leave the station through the actual departure sequence before saving"):
		return
	pilot.set_autopilot(true)
	pilot.toggle_time_pause()
	var good := pilot.snapshot()
	var bad := good.duplicate(true)
	bad.ship.fuel = -2.0
	bad.credits = 900
	if not _expect(_write(BACKUP, JSON.stringify(good, "", true, true).to_utf8_buffer())
		and _write(MAIN_SAVE, JSON.stringify(bad).to_utf8_buffer()),
		"Create a structurally valid but physically impossible primary alongside an active valid backup"):
		return
	var original_backup := FileAccess.get_file_as_bytes(BACKUP)
	var game := _boot()
	var notice: String = game._hud._notice.text
	_expect(game.flight.credits == 246 and game.flight.time_paused and not game.flight.autopilot
		and game.flight.position.distance_to(pilot.position) < 0.001 and game.flight.orbit_time == pilot.orbit_time,
		"Actual startup chooses the last valid flight and safely stops the restored autopilot")
	_expect(game._hud._notice_panel.visible and "резервной копии" in notice and "автопилот" in notice,
		"Startup displays both the backup result and the interrupted flight mode")
	_expect(FileAccess.get_file_as_bytes(BACKUP) == original_backup,
		"Reading the backup leaves the stored copy byte-identical")
	var main_path := ProjectSettings.globalize_path(MAIN_SAVE)
	if _expect(DirAccess.remove_absolute(main_path) == OK and DirAccess.make_dir_absolute(main_path) == OK,
		"Force the first repaired write to encounter an occupied destination"):
		game._save()
		_expect(game._save_error_shown and game._preserve_backup_on_next_save
			and FileAccess.get_file_as_bytes(BACKUP) == original_backup,
			"A failed repaired write retains both the valid backup and the retry guard")
		DirAccess.remove_absolute(main_path)
	# Recreate the bad but parseable primary before the first successful repaired save.
	_expect(_write(MAIN_SAVE, JSON.stringify(bad).to_utf8_buffer()),
		"Restore the corrupt primary for the first successful recovery write")
	game.flight.credits = 277
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var first := Flight.new()
	_expect(not game._preserve_backup_on_next_save and Session.load_valid_state(MAIN_SAVE, first.restore) == Session.LoadResult.PRIMARY
		and first.credits == 277 and FileAccess.get_file_as_bytes(BACKUP) == original_backup,
		"Saving recovered progress first repairs the primary without copying corruption over the good backup")
	game.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	game.flight.credits = 301
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var rotated := Flight.new()
	_expect(rotated.restore(Session.load_state(BACKUP)) and rotated.credits == 277,
		"The following save returns to normal rotation and backs up the repaired primary")
	game.queue_free()
	await process_frame


func _test_invalid_recovery() -> void:
	var bad := Flight.new().snapshot()
	bad.throttle = -0.1
	var broken_primary := JSON.stringify(bad).to_utf8_buffer()
	var broken_backup := "{\"schema\":".to_utf8_buffer()
	if not _expect(_write(MAIN_SAVE, broken_primary) and _write(BACKUP, broken_backup),
		"Prepare two unusable copies before booting the actual scene"):
		return
	var game := _boot()
	_expect(game.flight.credits == 0 and game.flight.docked >= 0 and "Начат новый рейс" in game._hud._notice.text
		and not game._preserve_backup_on_next_save,
		"When neither copy validates, startup announces the fresh flight")
	_expect(FileAccess.get_file_as_bytes(MAIN_SAVE) == broken_primary and FileAccess.get_file_as_bytes(BACKUP) == broken_backup,
		"A failed read does not rewrite either source file")
	game.queue_free()
	await process_frame


func _test_pause_notification() -> void:
	var game := _boot()
	var pilot: Flight = game.flight
	if _expect(pilot.cycle_time_scale() and pilot.cycle_time_scale() and pilot.time_scale == 16,
		"Select x16 through the real calendar controls"):
		var epoch := pilot.orbit_time
		game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		var stored := Session.load_state()
		_expect(pilot.time_scale == 1 and stored.get("resume", {}).get("interrupted") == ["time_scale"],
			"Application pause resets warm acceleration and records the interruption for a cold start")
		var checkpoint := FileAccess.get_file_as_bytes(MAIN_SAVE)
		var previous := FileAccess.get_file_as_bytes(BACKUP) if FileAccess.file_exists(BACKUP) else PackedByteArray()
		game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		game._physics_process(0.25)
		game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		_expect(pilot.orbit_time == epoch and FileAccess.get_file_as_bytes(MAIN_SAVE) == checkpoint
			and (FileAccess.get_file_as_bytes(BACKUP) if FileAccess.file_exists(BACKUP) else PackedByteArray()) == previous,
			"Focus gain before resume and a duplicate pause neither advance the world nor rotate the checkpoint")
		game.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		game._physics_process(0.25)
		_expect(is_equal_approx(pilot.orbit_time, epoch + 0.25) and pilot.time_scale == 1,
			"An actual resume continues warm time at normal speed without catching up the interval in the background")
		game.queue_free()
		await process_frame
		var cold := _boot()
		_expect(cold.flight.time_scale == 1 and cold.flight.orbit_time == epoch
			and cold._hud._notice_panel.visible and "ускорение времени" in cold._hud._notice.text,
			"A later scene boot restores the same epoch and displays why acceleration stopped")
		cold.queue_free()
	else:
		game.queue_free()
	await process_frame


func _test_autopilot_background() -> void:
	var game := _boot()
	var pilot := Flight.new()
	game.flight = pilot
	if not _expect(Fixture.depart(pilot) and pilot.select_target(1), "Prepare an airborne ship and a real port for autopilot"):
		game.queue_free()
		await process_frame
		return
	pilot.set_autopilot(true)
	pilot.throttle = 0.54
	pilot.boost = true
	game._update_display(0.0)
	await process_frame
	var viewport := game.get_viewport()
	var point: Vector2 = game._hud._steer.get_global_rect().get_center() + Vector2(23.0, 4.0)
	_touch(viewport, point, true)
	_expect(pilot.autopilot and not game._hud.move_input().is_zero_approx(), "A real held steering gesture exists before the app loses focus")
	var epoch := pilot.orbit_time
	var position := pilot.position
	game.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	game._physics_process(0.25)
	var stored := Session.load_single_state(MAIN_SAVE)
	var cold := Flight.new()
	_expect(cold.restore(stored) and stored.resume.interrupted == ["autopilot"] and not cold.autopilot
		and cold.throttle == 0.0 and cold.position.is_equal_approx(position) and cold.orbit_time == epoch,
		"The background checkpoint contains the cold-start autopilot receipt and no continuing burn")
	_expect(not pilot.autopilot and not pilot.boost and pilot.throttle == 0.0 and pilot.position == position and pilot.orbit_time == epoch
		and game._hud.move_input().is_zero_approx(),
		"The warm flight clears its powered assist and held steering without moving in the background")
	_touch(viewport, point, true)
	game.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_touch(viewport, point, false)
	_expect(game._hud.move_input().is_zero_approx() and "автопилот" in game._hud._notice.text,
		"Return drops stale touches and explains the stopped autopilot")
	_touch(viewport, point, true)
	_expect(not game._hud.move_input().is_zero_approx(), "Fresh steering presses are accepted after resume")
	_touch(viewport, point, false)
	game.queue_free()
	await process_frame


func _test_scoop_background() -> void:
	var game := _boot()
	var pilot := Flight.new()
	game.flight = pilot
	if not _expect(Fixture.depart(pilot) and pilot.select_target(Catalog.STAR_ID), "Prepare a real hydrogen collection flight"):
		game.queue_free()
		await process_frame
		return
	pilot.position = pilot.target_position(Catalog.STAR_ID) + Vector3.BACK * 310.0
	pilot.velocity = pilot.target_velocity(Catalog.STAR_ID)
	pilot.yaw = PI
	pilot.pitch = 0.0
	if _expect(pilot.scoop_action() and pilot.scooping, "Open the scoop using its normal band and speed checks"):
		var cargo := pilot.mining.cargo_amount("hydrogen")
		var heat := pilot.star_heat
		game.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		game._physics_process(0.5)
		var stored := Session.load_single_state(MAIN_SAVE)
		_expect(not pilot.scooping and pilot.mining.cargo_amount("hydrogen") == cargo and pilot.star_heat == heat
			and "scoop" in stored.get("resume", {}).get("interrupted", []),
			"Backgrounding closes intake and stops heat and hydrogen generation while retaining the cold resume receipt")
	game.queue_free()
	await process_frame


func _test_jump_notifications() -> void:
	var game := _boot()
	var pilot := Flight.new()
	game.flight = pilot
	var destination := Catalog.VELAR_SYSTEM
	if not _expect(_start_charge(pilot, destination), "Start a real unpaid charge after departing and clearing the station"):
		game.queue_free()
		await process_frame
		return
	var fuel := pilot.ship.jump_fuel
	var seconds := pilot.jump_seconds_left
	var backup := FileAccess.get_file_as_bytes(BACKUP)
	game._open_voyages()
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	game._physics_process(0.25)
	_expect(game._voyages.is_open() and pilot.jump_seconds_left == seconds
		and FileAccess.get_file_as_bytes(BACKUP) == backup,
		"A suspend while the voyages screen awaits a choice keeps the warm charge and previous backup")
	game.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	game._close_voyages()
	game._open_report()
	# Simulate only the platform boundary after Android opens the native chooser.
	game._report_sharing = true
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var sharing_save := Session.load_state()
	_expect(game._report.visible and game._report_sharing and pilot.jump_seconds_left == seconds
		and pilot.ship.jump_fuel == fuel and sharing_save.get("resume", {}).get("interrupted") == ["unpaid_jump_charge"]
		and FileAccess.get_file_as_bytes(BACKUP) == backup,
		"Pausing for the report chooser preserves the running charge and still saves its cold state")
	game.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_expect(not game._report_sharing and pilot.jump_seconds_left == seconds,
		"Closing the system chooser clears the share guard without canceling the warm charge")
	game._close_report()
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var closed_save := Session.load_state()
	_expect(pilot.jump_seconds_left == 0.0 and pilot.ship.jump_fuel == fuel
		and closed_save.get("resume", {}).get("interrupted") == ["unpaid_jump_charge"],
		"An ordinary suspend cancels the unpaid warm charge after saving the interruption")
	var saved_bytes := FileAccess.get_file_as_bytes(MAIN_SAVE)
	var backup_bytes := FileAccess.get_file_as_bytes(BACKUP)
	game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_expect(FileAccess.get_file_as_bytes(MAIN_SAVE) == saved_bytes and FileAccess.get_file_as_bytes(BACKUP) == backup_bytes,
		"Closing while suspended keeps the earlier interruption receipt and backup")
	game.queue_free()
	await process_frame
	var cold := _boot()
	_expect(cold.flight.jump_target == destination and cold.flight.jump_seconds_left == 0.0 and cold.flight.ship.jump_fuel == fuel
		and cold._hud._notice_panel.visible and "зарядка прыжкового привода" in cold._hud._notice.text,
		"A cold boot retains the planned destination and full fare reserve and explains the cleared charge")
	cold.queue_free()
	await process_frame


func _test_paid_jump_background() -> void:
	var game := _boot()
	var pilot := Flight.new()
	game.flight = pilot
	var destination := Catalog.VELAR_SYSTEM
	var initial_fuel := pilot.ship.jump_fuel
	if not _expect(_start_charge(pilot, destination), "Prepare the next real jump for a paid-transit suspend test"):
		game.queue_free()
		await process_frame
		return
	for _frame: int in range(ceili(Flight.JUMP_CHARGE / Fixture.STEP)):
		pilot.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
		if pilot.jump_progress_status().phase == "transit":
			break
	if _expect(pilot.jump_progress_status().phase == "transit" and pilot.ship.jump_fuel < initial_fuel and pilot.toggle_time_pause(),
		"Commit the fare once and deliberately pause the calendar during real transit"):
		var ticket := pilot.snapshot()
		game.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		game._physics_process(1.0)
		game.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		game._physics_process(1.0)
		_expect(pilot.snapshot() == ticket and pilot.time_paused,
			"Application resumption preserves manual calendar pause and the paid ticket")
		var cold := Flight.new()
		var checkpoint := Session.load_single_state(MAIN_SAVE)
		_expect(cold.restore(checkpoint) and cold.time_paused and cold.jump_progress_status().phase == "transit"
			and cold.jump_seconds_left == pilot.jump_seconds_left and cold.ship.jump_fuel == pilot.ship.jump_fuel,
			"A cold scene can read the same paid ticket and pause after an OS interruption")
		var paid_fuel := pilot.ship.jump_fuel
		pilot.toggle_time_pause()
		for _frame: int in range(ceili(Flight.JUMP_TRANSIT_WALL / Fixture.STEP) + 1):
			game._physics_process(Fixture.STEP)
			if pilot.system_id == destination:
				break
		_expect(pilot.system_id == destination and pilot.ship.jump_fuel == paid_fuel and pilot.jump_seconds_left == 0.0,
			"Manual unpause completes the warm transit once without charging a second fare")
	game.queue_free()
	await process_frame


func _touch(viewport: Viewport, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 5
	event.position = point
	event.pressed = pressed
	viewport.push_input(event, true)


func _start_charge(pilot: Flight, destination: int) -> bool:
	if not Fixture.depart(pilot) or not pilot.plan_jump(destination):
		return false
	pilot.change_throttle(0.18)
	for _frame in range(ceili(15.0 / Fixture.STEP)):
		if pilot.jump_status(destination).ok:
			return pilot.start_jump() and pilot.jump_progress_status().phase == "charge"
		pilot.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
	return false


func _boot() -> Node:
	var game := OrbitRelay.instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	return game


func _original_files() -> Dictionary:
	var original := {}
	for path: String in [MAIN_SAVE, BACKUP]:
		if FileAccess.file_exists(path):
			original[path] = FileAccess.get_file_as_bytes(path)
	return original


func _restore_original_files(original: Dictionary) -> void:
	for path: String in [MAIN_SAVE, BACKUP]:
		if original.has(path):
			_write(path, original[path])
		else:
			_remove(path)


func _write(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	var error := file.get_error()
	file.close()
	return error == OK


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append("FAIL: " + description)
	return condition
