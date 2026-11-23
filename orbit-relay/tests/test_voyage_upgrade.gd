extends SceneTree
## The checkpoint modes allow the two halves to run in separate engine processes
## using the same test data directory, including across actual exported versions.

const Startup := preload("res://voyage_start.tscn")
const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Library := preload("res://scripts/voyage_library.gd")
const Session := preload("res://scripts/session_io.gd")
const Settings := preload("res://scripts/display_settings.gd")
const DESTINATION := Catalog.VELAR_SYSTEM
const SLOT_NAME := "Рейс до обновления"
const WAIT_SECONDS := 8.0 * 3600.0

var _viewport: SubViewport
var _game: Node
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := OS.get_cmdline_user_args()
	var write_checkpoint := "--write-checkpoint" in options
	var resume_checkpoint := "--resume-checkpoint" in options
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1544, 720)
	_viewport.own_world_3d = true
	root.add_child(_viewport)
	if _expect(not (write_checkpoint and resume_checkpoint), "Choose one checkpoint mode at a time"):
		if resume_checkpoint:
			await _complete_voyage()
		elif _expect(not FileAccess.file_exists(Session.SAVE_PATH) and not FileAccess.file_exists(Session.BACKUP_PATH)
				and not FileAccess.file_exists(Settings.PATH) and Library.list_slots().is_empty(),
				"Start with an isolated empty player directory"):
			_spawn()
			if _prepare_voyage() and not write_checkpoint:
				await _complete_voyage()
	_viewport.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("Voyage upgrade %s: %d checks, %d failures" % [
		ProjectSettings.get_setting("application/config/version"), _checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(int(not _failures.is_empty()))


func _prepare_voyage() -> bool:
	_game._voyage_action("new", "", "")
	_game._handle_action("settings")
	_game._change_preference("quality", 2)
	_game._change_preference("layout", 1)
	_game._change_preference("invert_pitch", 1)
	_game._close_settings()
	_game._handle_action("contract")
	var delivery := int(_game.flight.contract_destination)
	if not _expect(_game.flight.contract_stage == 1 and delivery >= 0, "Accept the ordinary starter delivery") \
			or not _dock_at(delivery):
		return false
	_game._handle_action("contract")
	_game._handle_action("market")
	_game._market_trade("ore", "buy", 2, false)
	_game._close_market()
	if not _expect(_game.flight.deliveries == 1 and _game.flight.story_status().stage == "offer"
			and _game.flight.mining.cargo_amount("ore") == 2, "Physical delivery opens the story and two ore units enter cargo"):
		return false

	_game._open_voyages()
	_game._voyage_action("create", "", SLOT_NAME)
	_game._close_voyages()
	var slots := Library.list_slots()
	if not _expect(slots.size() == 1 and slots[0].name == SLOT_NAME, "Create a named copy from the live berth"):
		return false
	var fare := int(_game.flight.jump_tariff(Catalog.HOME_SYSTEM, DESTINATION))
	var fuel := float(_game.flight.ship.active_jump_fuel())
	if not _expect(_game.flight.plan_route(DESTINATION), "Plot a normal course through the galactic navigator"):
		return false
	_game._deliver_notice()
	if not _depart():
		return false
	_game._handle_action("throttle_up")
	_game._handle_action("throttle_up")
	if not _advance_until(func() -> bool: return _game.flight.jump_status(DESTINATION).ok, 23.0, "Reach jump clearance"):
		return false
	_game._handle_action("galaxy")
	_game._start_jump()
	if not _advance_until(func() -> bool: return _game.flight.jump_progress_status().is_transit, 6.0,
			"Leave the voyage in a paid interstellar transit"):
		return false
	_game._handle_action("time_pause")
	var written := Flight.new()
	return _expect(Session.load_valid_state(Session.SAVE_PATH, written.restore) == Session.LoadResult.PRIMARY
		and written.time_paused and written.jump_progress_status().is_transit
		and is_equal_approx(written.ship.active_jump_fuel(), fuel - fare)
		and written.deliveries == 1 and written.mining.cargo_amount("ore") == 2,
		"The ordinary autosave contains the paid ticket, pause, prior payout and cargo")


func _complete_voyage() -> void:
	var paid := Flight.new()
	var slots := Library.list_slots()
	if not _expect(Session.load_valid_state(Session.SAVE_PATH, paid.restore) == Session.LoadResult.PRIMARY
			and paid.time_paused and paid.jump_progress_status().is_transit
			and slots.size() == 1 and slots[0].name == SLOT_NAME, "Read the staged paid ticket and named checkpoint"):
		return
	var slot_id: String = slots[0].id
	var slot_path := Library.DIRECTORY.path_join(slot_id + Library.EXTENSION)
	var checkpoint_bytes := FileAccess.get_file_as_bytes(slot_path)
	if not await _cold_continue():
		return
	var active: Flight = _game.flight
	if not _expect(active.snapshot() == paid.snapshot() and _game.presentation.quality == 2
			and _game.presentation.layout == 1 and _game.presentation.invert_pitch == 1,
			"Cold startup restores the exact paid transit and the independently saved preferences"):
		return
	var fuel := active.ship.active_jump_fuel()
	var arrival := float(active.jump_progress_status().arrival_epoch)
	_game._handle_action("time_pause")
	if not _advance_until(func() -> bool: return active.system_id == DESTINATION, 6.0, "Resume the paid transit to Velar"):
		return
	if not _expect(active.jump_seconds_left == 0.0 and is_equal_approx(active.ship.active_jump_fuel(), fuel)
			and is_equal_approx(active.orbit_time, arrival), "Arrival settles the original ticket without a second charge") \
			or not _dock_at(int(Catalog.system(DESTINATION).arrival_port)):
		return
	var start_time := active.orbit_time
	var freight := active.freight.snapshot()
	var end_time := start_time + WAIT_SECONDS
	_game._handle_action("journal")
	_game._calendar_wait(end_time)
	if not _advance_until(func() -> bool: return active.orbit_time >= end_time, 130.0, "Advance eight game hours at the real berth"):
		return
	if not _expect(is_equal_approx(active.orbit_time, end_time) and not active.time_paused
			and active.freight.snapshot() != freight and active.story_status().stage == "offer",
			"The ordinary calendar advances traffic and preserves the unclaimed story lead"):
		return
	# Advance through an ordinary autosave window past the end of time acceleration.
	if not _advance_until(func() -> bool: return active.orbit_time >= end_time + 9.0, 12.0, "Autosave after the berth wait"):
		return
	var saved := Flight.new()
	if not _expect(Session.load_valid_state(Session.SAVE_PATH, saved.restore) == Session.LoadResult.PRIMARY
			and saved.orbit_time >= end_time, "The disk checkpoint includes all eight hours"):
		return
	if not await _cold_continue():
		return
	_expect(_game.flight.snapshot() == saved.snapshot() and _game.flight.deliveries == 1
		and _game.flight.mining.cargo_amount("ore") == 2 and _game.flight.ship.active_jump_fuel() == fuel,
		"A second cold launch preserves the late market, freight, balance, cargo and fuel")
	var earlier := Flight.new()
	_expect(FileAccess.get_file_as_bytes(slot_path) == checkpoint_bytes and Library.load_slot(slot_id, earlier.restore)
		and earlier.system_id == Catalog.HOME_SYSTEM and earlier.docked >= 0 and earlier.orbit_time < start_time,
		"The saved starting berth remains separately loadable after update and continued play")


func _spawn() -> void:
	_game = Startup.instantiate()
	_viewport.add_child(_game)
	_game.set_process(false)
	_game.set_physics_process(false)


func _cold_continue() -> bool:
	if is_instance_valid(_game):
		_game.queue_free()
		await process_frame
	_spawn()
	if not _expect(_game._voyages.is_open() and not _game._voyages._actions["continue"].disabled,
			"Cold launch offers the normal Continue action"):
		return false
	_game._voyage_action("continue", "", "")
	return _expect(_game._flight_active and not _game._voyages.is_open(), "Continue activates the saved flight")


func _dock_at(port: int) -> bool:
	if _game.flight.docked == port:
		return true
	if not _expect(_game.flight.target == port or _game.flight.select_target(port), "Select port %d" % port):
		return false
	if _game.flight.docked >= 0 and not _depart():
		return false
	_game._handle_action("autopilot")
	return _advance_until(func() -> bool: return _game.flight.docked == port, 190.0, "Fly the actual approach to port %d" % port)


func _depart() -> bool:
	_game._handle_action("dock")
	return _advance_until(func() -> bool: return _game.flight.docked < 0, 15.0, "Clear the rotating berth through normal departure")


func _advance_until(reached: Callable, seconds: float, label: String) -> bool:
	for _frame in range(ceili(seconds / Fixture.STEP)):
		if reached.call():
			return _expect(true, label)
		_game._physics_process(Fixture.STEP)
	return _expect(bool(reached.call()), "%s. Last notice %s" % [label, _game.flight.status_message])


func _expect(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(label)
	return condition
