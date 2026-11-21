extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const Game := preload("res://main.tscn")
const HOME := 0
const STVOR := 10

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_contract()
	_test_deadline()
	await _test_touch()
	print("Reconnaissance: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	await create_timer(0.15).timeout
	quit(0 if _failures.is_empty() else 1)


func _test_contract() -> void:
	var flight := Flight.new()
	flight.credits = 1000
	_check(not flight.recon_action("accept") and not flight.recon_action("photo"), "Equipment is required")
	_check(flight.recon_action("buy") and flight.recon_action("accept") and flight.recon_action("follow")
		and flight.credits == 915 and flight.jump_target == Catalog.VELAR_SYSTEM,
		"Camera purchase and accepting the port offer plan an actual interstellar route")
	_check(not flight.recon_action("report") and not flight.recon_action("buy"), "Premature reports and repeat purchase are rejected")
	if not _check(Fixture.launch(flight) and _make_jump(flight, Catalog.VELAR_SYSTEM), "Ordinary departure and flight to Velar"):
		return

	var center := flight.target_position(STVOR)
	var offset := Vector3.BACK * 132.0
	flight.position = center + offset
	flight.velocity = flight.target_velocity(STVOR)
	flight.yaw = PI
	flight.pitch = 0.0
	_check(not flight.recon_action("photo") and int(flight.recon_status().score) == 0, "A target behind the ship cannot be photographed")
	flight.yaw = 0.0
	flight.velocity += Vector3.RIGHT * 42.0
	_check(not flight.recon_action("photo"), "Excessive relative speed prevents a photo")
	flight.velocity = flight.target_velocity(STVOR)
	flight.position = center + offset * 4.0
	_check(not flight.recon_action("photo"), "Out-of-range photos cannot be used")
	flight.position = center + offset
	_check(flight.recon_action("photo") and int(flight.recon_status().score) == 93, "Valid geometry yields a measured quality score")
	flight.velocity += Vector3.RIGHT * 12.0
	_check(flight.recon_action("photo") and int(flight.recon_status().score) == 93, "A worse image does not replace the accepted best image")
	flight.velocity = flight.target_velocity(STVOR)
	var with_photo := flight.snapshot()
	var good := Flight.new()
	_check(SessionIO.save_state(with_photo, "user://recon-photo.json") == OK
		and good.restore(SessionIO.load_state("user://recon-photo.json"))
		and int(good.recon_status().score) == 93 and int(good.recon_status().reward) == 306,
		"The measured proof and payment survive a serialized reload")
	var forged := with_photo.duplicate(true)
	forged.reconnaissance.photo.score = 100
	var loaded := good.snapshot()
	_check(not good.restore(forged) and good.snapshot() == loaded, "Forged score is rejected transactionally")
	if not _check(_dock_at(flight, STVOR) and not flight.recon_action("report")
			and flight.recon_action("follow") and int(flight.jump_target) == Catalog.HOME_SYSTEM,
		"A wrong berth cannot credit the mission. Completed proofs route back to the issuer"):
		return
	if not _check(Fixture.launch(flight) and _make_jump(flight, Catalog.HOME_SYSTEM) and _dock_at(flight, HOME),
		"The evidence can be returned within the allotted mission time"):
		return
	var before := flight.credits
	_check(flight.recon_action("report") and flight.credits == before + 306 and not flight.recon_action("report")
		and not flight.recon_action("accept"), "Return pays out once and completes the issuing port's assignment")
	_check(good.restore(flight.snapshot()) and bool(good.recon_status().completed), "Completed contract ledger survives a fresh load")


func _test_deadline() -> void:
	var flight := Flight.new()
	flight.credits = 100
	flight.recon_action("buy")
	flight.recon_action("accept")
	var older := flight.snapshot()
	older.schema = 49
	Fixture.remove_schema_51_from_legacy(older)
	older.erase("reconnaissance")
	Fixture.remove_extended_career_from_legacy(older)
	Fixture.remove_ordnance_from_legacy(older)
	var migrated := Flight.new()
	_check(migrated.restore(older) and not migrated.recon_status().fitted and migrated.credits == 15,
		"Schema 49 loads with an empty camera record and preserves the balance")
	_check(is_equal_approx(flight._fast_wait_stop_epoch(), 705.0), "The camera order participates in safe time compression")
	flight.orbit_time = 720.0
	flight._advance_mission_deadlines()
	_check(flight.status_event == "recon_expired" and not flight.recon_status().active and flight.recon_status().can_accept,
		"An expired order does not pay and its offer can be accepted again")


func _test_touch() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := Game.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = Flight.new()
	game.flight.credits = 1000
	game._update_display(0.0)
	await process_frame
	_check(_tap(viewport, game._hud._actions["recon"]) and game._recon.is_open(), "The cockpit shortcut opens the camera by touch")
	await process_frame
	_check(_tap(viewport, game._recon._buttons.buy) and game.flight.recon_status().fitted, "Camera can be bought by touch")
	await process_frame
	_check(_tap(viewport, game._recon._buttons.accept) and game.flight.recon_status().active, "A touch accepts the offer")
	await process_frame
	_check(_tap(viewport, game._recon._buttons.follow) and not game._recon.is_open() and game.flight.jump_target == Catalog.VELAR_SYSTEM,
		"The route button returns to flight")
	_check(SessionIO.load_state().get("reconnaissance", {}).get("issuer", -1) == HOME, "Main persists the offer on interaction")

	_check(_tap(viewport, game._hud._actions["services"]) and game._services.is_open(), "Open port services")
	await process_frame
	var services: Node = game._services
	_check(_tap(viewport, services._mining_toggle), "Open outfitting by touch")
	await process_frame
	_check(_tap(viewport, services._equipment_tabs[3]), "Open weapon stores by touch")
	await process_frame
	_check(_tap(viewport, services._action_buttons.combat_launcher), "Fit a launcher in port")
	await process_frame
	_check(_tap(viewport, services._action_buttons.combat_missile_dart)
		and _tap(viewport, services._action_buttons.combat_missile_lance), "Load both types from the weapon stores")
	await process_frame
	_check(_tap(viewport, services._missile_buttons[1]) and game.flight.combat_equipment_status().missile_slot == 1,
		"Change the armed ordnance in the stock display")

	game._audio.set_level(0)
	await create_timer(AudioServer.get_time_to_next_mix() + 0.025).timeout
	viewport.queue_free()
	await process_frame


func _tap(viewport: SubViewport, button: Button) -> bool:
	if button == null or button.disabled or not button.is_visible_in_tree():
		return false
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 13
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		viewport.push_input(event, true)
	return true


func _make_jump(flight: Flight, system: int) -> bool:
	flight.change_throttle(0.18)
	for _frame in range(12 * 60):
		if flight.jump_status(system).ok:
			break
		flight.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
	if not flight.start_jump():
		return false
	for _frame in range(4 * 60):
		if flight.system_id == system:
			return true
		flight.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
	return false


func _dock_at(flight: Flight, port: int) -> bool:
	if not flight.select_target(port):
		return false
	flight.set_autopilot(true)
	for _frame in range(85 * 60):
		if flight.docked == port:
			return true
		if not flight.autopilot:
			return false
		flight.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
	return false


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
	return condition
