extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Operations := preload("res://scripts/operation_programs.gd")
const Game := preload("res://main.tscn")
const Session := preload("res://scripts/session_io.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_signal()
	_courier()
	_relay()
	await _touch()
	print("Special operations and mission programs: %d checks, %d failures" % [_checks, _failures])
	await create_timer(0.15).timeout
	quit(0 if _failures == 0 else 1)


func _signal() -> void:
	var flight := Flight.new()
	_expect(not flight.operation_action("signal", "accept") and not flight.operation_action("signal", "report"),
		"Mission program denies commands whose port or proof conditions are unmet")
	flight.deliveries = 1
	if not _expect(flight.operation_action("signal", "accept") and not flight.operation_action("signal", "survey")
		and Fixture.launch(flight), "An eligible pilot takes the order in the normal port"):
		return
	flight.position = flight.target_position(Operations.SLATE) + Vector3.BACK * 170.0
	flight.velocity = flight.target_velocity(Operations.SLATE)
	_expect(flight.operation_action("signal", "survey") and flight.body_dossier(Operations.SLATE).known,
		"Survey requires real proximity and records actual atlas evidence")
	_expect(flight.operation_action("signal", "research") and flight.operation_action("signal", "follow")
		and flight.jump_target == Catalog.VELAR_SYSTEM and not flight.operation_action("signal", "safety"),
		"The branch chooses an actual report port and blocks alternate completion")
	_expect(not flight.operation_action("signal", "report"), "Research cannot be reported from space")
	var saved := flight.snapshot()
	var resumed := Flight.new()
	_expect(saved.operations.records.signal.stage == "research" and resumed.restore(saved),
		"A started program survives a validated save")
	_expect(_jump_and_dock(flight, Operations.VELAR_PORT), "The destination accepts the science report after a normal jump")
	var balance := flight.credits
	_expect(flight.operation_action("signal", "report") and flight.credits == balance + 510
		and not flight.operation_action("signal", "report") and flight.operation_status("signal").stage == "done_research",
		"Report pays once and retains the chosen ending")


func _courier() -> void:
	var flight := Flight.new()
	_expect(flight.operation_action("courier", "accept") and flight.operation_contact().is_empty()
		and flight.operation_action("courier", "follow") and flight.jump_target == Catalog.VELAR_SYSTEM,
		"A courier order opens the route and initially has no target")
	if not _expect(_move_dock(flight, Operations.VELAR_PORT) and Fixture.launch(flight), "Set up in Velar after port departure"):
		return
	flight._advance_background_clock(35.0)
	var contact := flight.operation_contact()
	if not _expect(contact.get("id", "") == Operations.COURIER_ID,
		"The named ship appears in the correct system after the scheduled arrival"):
		return
	var prior_hull := flight.ship.hull
	flight._advance_background_clock(5.0)
	contact = flight.operation_contact()
	flight.position = Vector3(contact.position) + Vector3.BACK * 50.0
	flight.velocity = contact.velocity
	flight.yaw = 0.0
	flight.pitch = 0.0
	_expect(not flight._operations.counterfire(flight, 5.0).is_empty() and prior_hull == flight.ship.hull,
		"The courier has a scheduled counterattack in weapon range")
	_expect(flight.select_combat_contact(Operations.COURIER_ID) and flight.fire_action()
		and is_equal_approx(float(flight.operation_contact().hull), 48.0),
		"Ordinary laser processing hits the selected named ship and only its actual hull")
	for _index in range(2):
		flight._advance_background_clock(2.0)
		contact = flight.operation_contact()
		flight.position = Vector3(contact.position) + Vector3.BACK * 50.0
		_expect(flight.fire_action(), "The next legal laser shot hits the moving courier")
	_expect(flight.combat_lock_id().is_empty() and flight.operation_status("courier").stage == "report",
		"Destruction releases the combat lock and creates verified mission proof")
	_expect(_jump_and_dock(flight, Operations.HOME), "Return physically to the original issuer")
	var balance := flight.credits
	_expect(flight.operation_action("courier", "report") and not flight.operation_action("courier", "report")
		and flight.credits == balance + 740, "Award is credited once after return")
	var missed := Flight.new()
	missed.operation_action("courier", "accept")
	missed._advance_background_clock(360.0)
	missed._advance_mission_deadlines()
	_expect(missed.operation_status("courier").stage == "expired" and missed.operation_contact().is_empty()
		and missed.operation_action("courier", "renew") and missed.operation_action("courier", "accept"),
		"Deadline causes departure and permits a new order only via the issuer")


func _relay() -> void:
	var flight := Flight.new()
	flight.credits = 500
	if not _expect(_move_dock(flight, Operations.VELAR_PORT), "Set up at the League installation board"):
		return
	_expect(not flight.operation_action("relay", "accept") and flight.operation_action("relay", "buy")
		and flight.credits == 380 and flight.operation_action("relay", "accept"),
		"Station operation requires purchased equipment and the real commissioning authority")
	if not _expect(flight.operation_action("relay", "follow") and Fixture.launch(flight), "Plot and fly toward the installation"):
		return
	var contact: Dictionary = flight.operation_status("relay").contact
	_expect(not contact.is_empty() and contact.role == "relay" and not flight.operation_action("relay", "disable"),
		"The installation exists as a persistent local contact and cannot be hit at arbitrary distance")
	flight.position = Vector3(contact.position) + Vector3.BACK * 90.0
	flight.yaw = PI
	flight.pitch = 0.0
	_expect(not flight.operation_action("relay", "disable"), "Shooting away from the installation is rejected")
	flight.yaw = 0.0
	_expect(flight.operation_action("relay", "disable") and flight.operation_status("relay").stage == "report"
		and flight.operation_status("relay").contact.is_empty(), "A clear shot records the station proof and changes the operation")
	var old := flight.snapshot()
	var cold := Flight.new()
	_expect(cold.restore(old), "A disabled installation survives cold load")
	var loaded := cold.snapshot()
	var invalid := loaded.duplicate(true)
	invalid.operations.disruptor = false
	_expect(not cold.restore(invalid) and cold.snapshot() == loaded, "A manufactured equipped receipt is denied atomically")
	_expect(_move_dock(flight, Operations.VELAR_PORT), "Return to the authorized issuer")
	var balance := flight.credits
	_expect(flight.operation_action("relay", "report") and not flight.operation_action("relay", "report")
		and flight.credits == balance + 860, "Installation proof pays after legal reporting exactly once")


func _touch() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := Game.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = Flight.new()
	game._update_display(0.0)
	await process_frame
	_tap(viewport, game._hud._actions.journal)
	await process_frame
	_tap(viewport, game._journal._story_tab)
	await process_frame
	_tap(viewport, game._journal._operations_button)
	await process_frame
	_expect(game._operations_panel.is_open() and not game._journal.is_open(),
		"The operations board opens from the normal touch journal")
	_tap(viewport, game._operations_panel._buttons.tab_courier)
	await process_frame
	_tap(viewport, game._operations_panel._buttons.accept)
	var saved: Dictionary = Session.load_state().get("operations", {}).get("records", {}).get("courier", {})
	_expect(game.flight.operation_status("courier").stage == "intercept" and saved.get("stage") == "intercept",
		"Touch acceptance updates both runtime and the game autosave")
	game._audio.set_level(0)
	viewport.queue_free()
	await process_frame


func _jump_and_dock(flight: Flight, port: int) -> bool:
	var system := Catalog.system_of_site(port)
	flight.position = Vector3(350.0, 500.0, 570.0)
	flight.velocity = Vector3.ZERO
	if not flight.plan_jump(system) or not flight.start_jump():
		return false
	for _frame in range(240):
		if flight.system_id == system:
			break
		flight.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
	if flight.system_id != system or not flight.select_target(port):
		return false
	flight.set_autopilot(true)
	for _frame in range(85 * 60):
		if flight.docked == port:
			return true
		if not flight.autopilot:
			return false
		flight.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
	return false


func _move_dock(flight: Flight, port: int) -> bool:
	var state := flight.snapshot()
	state.system_id = Catalog.system_of_site(port)
	state.target = port
	state.docked = port
	state.planned_target = -1
	state.jump_target = -1
	state.jump_route = []
	state.dock_access = Flight.new().dock_access.snapshot()
	state.velocity = [0.0, 0.0, 0.0]
	var point := flight.docking_position(port)
	state.position = [point.x, point.y, point.z]
	return flight.restore(state)


func _tap(viewport: SubViewport, button: Button) -> void:
	if not _expect(button.is_visible_in_tree() and not button.disabled, "Touch button %s is available" % button.text):
		return
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 13
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		viewport.push_input(event, true)


func _expect(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures += 1
		printerr(message)
	return condition
