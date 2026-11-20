extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const Main := preload("res://main.tscn")
const HOME_PORT := 0
const VELAR_PORT := 10
const WAGE_INTERVAL := 240.0
const STEP := Fixture.STEP

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_hiring_and_repair()
	_test_payroll_and_repayment()
	_test_passenger_voyage()
	_test_previous_schema()
	await _test_crew_touch()
	print("Crew integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_hiring_and_repair() -> void:
	var flight := Flight.new()
	var empty := flight.crew_status()
	_expect(int(empty.count) == 0 and int(empty.capacity) == 2 and int(empty.arrears) == 0
		and not empty.engineer and not empty.navigator,
		"The starter can fly solo with an empty roster and no crew debt")
	var engineer := _role(flight.crew_candidates(), "engineer")
	var navigator := _role(flight.crew_candidates(), "navigator")
	if not _expect(not engineer.is_empty() and not navigator.is_empty() and engineer.id != navigator.id
		and int(engineer.origin) == HOME_PORT and int(navigator.origin) == HOME_PORT,
		"The operational station has distinct local engineer and navigator offers"):
		return
	var before := flight.snapshot()
	_expect(not engineer.available and not navigator.available and not flight.crew_hire(int(engineer.id))
		and not flight.crew_hire(-1) and flight.snapshot() == before,
		"Unfunded or invalid hiring never changes money or the roster")
	flight.ship.apply_damage(10.0)
	flight.credits = int(engineer.fee) + 100
	var base_repair := flight.repair_unit_price()
	var regular_invoice := flight.service_offer("repair")
	if not _expect(flight.crew_hire(int(engineer.id)) and flight.credits == 100
			and flight.crew_status().engineer, "A funded hire debits the quoted fee and enables the engineer"):
		return
	var discounted_invoice := flight.service_offer("repair")
	_expect(flight.repair_unit_price() == maxi(1, base_repair - 1)
		and int(discounted_invoice.cost) == flight.repair_unit_price() * 10
		and int(discounted_invoice.cost) < int(regular_invoice.cost),
		"The paid engineer reduces the real station repair tariff but never below one credit per unit")
	_expect(not flight.crew_hire(int(engineer.id)) and int(flight.crew_status().count) == 1 and flight.credits == 100,
		"The same candidate cannot be hired or paid an entry fee twice")
	_expect(flight.service_action("repair") and flight.ship.hull == 100.0
		and flight.credits == 100 - int(discounted_invoice.cost),
		"The actual service purchase uses the displayed engineer discount")
	if not _expect(flight.dock_action() and flight.crew_candidates().is_empty()
		and not flight.crew_hire(int(navigator.id)) and not flight.crew_dismiss(int(engineer.id)),
		"A sortie in the station's exit corridor cannot hire or dismiss crew"):
		return
	_expect(flight.dock_action() and flight.crew_dismiss(int(engineer.id)) and int(flight.crew_status().count) == 0
		and flight.repair_unit_price() == base_repair,
		"Canceling departure resumes port services and a fully paid engineer can leave")


func _test_payroll_and_repayment() -> void:
	var flight := Flight.new()
	flight.orbit_time = 80.0
	flight.credits = 1000
	var navigator := _role(flight.crew_candidates(), "navigator")
	var engineer := _role(flight.crew_candidates(), "engineer")
	if not _expect(not navigator.is_empty() and not engineer.is_empty()
		and flight.crew_hire(int(navigator.id)) and flight.crew_hire(int(engineer.id)),
		"Both jobs can be filled in reverse order at the same game time"):
		return
	var initial := flight.crew_status()
	var full_wages := int(engineer.wage) + int(navigator.wage)
	var due := float(initial.next_due)
	if not _expect(int(initial.count) == 2 and initial.engineer and initial.navigator
		and due == flight.orbit_time + WAGE_INTERVAL,
		"Both paid crew members are active until the same first wage due time"):
		return
	var balance := flight.credits
	_tick(flight, due - flight.orbit_time - 0.25)
	_expect(flight.credits == balance and float(flight.crew_status().next_due) == due,
		"Approaching the due time by a quarter second never charges either wage early")
	var path := "user://crew-payroll.json"
	var cold := Flight.new()
	if not _expect(SessionIO.save_state(flight.snapshot(), path) == OK and cold.restore(SessionIO.load_state(path))
		and not cold.crew_status().members.is_empty() and is_equal_approx(cold.orbit_time, due - 0.25),
		"A disk checkpoint just before payroll preserves both scheduled wages"):
		return
	_tick(cold, 0.25)
	var paid := cold.crew_status()
	if not _expect(cold.orbit_time == due and cold.credits == balance - full_wages
		and int(paid.arrears) == 0 and float(paid.next_due) == due + WAGE_INTERVAL,
		"The exact due instant debits both wages once and moves both schedules forward"):
		return
	flight = Flight.new()
	if not _expect(SessionIO.save_state(cold.snapshot(), path) == OK and flight.restore(SessionIO.load_state(path)),
		"A cold save at the cutoff retains the completed payroll"):
		return
	_tick(flight, 0.25)
	_expect(flight.credits == cold.credits and float(flight.crew_status().next_due) == float(paid.next_due),
		"The completed wage tick does not run again after a restart")

	# Spend the previously available balance before the next automatic wage deduction.
	flight.credits = int(engineer.wage) + 1
	_tick(flight, float(paid.next_due) - flight.orbit_time)
	var shortfall := flight.crew_status()
	var unpaid := _role(shortfall.members, "navigator")
	var paid_crew := _role(shortfall.members, "engineer")
	if not _expect(not unpaid.is_empty() and not paid_crew.is_empty() and flight.credits == 0
		and int(paid_crew.arrears) == 0 and int(unpaid.arrears) == int(navigator.wage) - 1
		and int(shortfall.arrears) == int(unpaid.arrears) and shortfall.engineer and not shortfall.navigator,
		"With both wages due together, the lower candidate ID receives payment first rather than the first hire"):
		return
	_expect(not unpaid.can_dismiss and not unpaid.can_pay and not flight.crew_dismiss(int(navigator.id))
		and not flight.crew_pay(int(navigator.id)), "The unpaid crew member stays aboard and cannot be paid with zero credits")
	var arrears := int(shortfall.arrears)
	flight.credits = 1
	_expect(flight.crew_pay(int(navigator.id)) and flight.credits == 0
		and int(flight.crew_status().arrears) == arrears - 1
		and not flight.crew_status().navigator and not flight.crew_dismiss(int(navigator.id)),
		"A berth can make a partial repayment while the remaining debt still blocks dismissal and the job benefit")
	var debt_snapshot := flight.snapshot()
	cold = Flight.new()
	if not _expect(SessionIO.save_state(debt_snapshot, path) == OK and cold.restore(SessionIO.load_state(path))
		and int(cold.crew_status().arrears) == arrears - 1 and not cold.crew_status().navigator,
		"A cold reload keeps the partially repaid debt separated from the paid engineer"):
		return
	cold.credits = arrears + 4
	_expect(cold.crew_pay(int(navigator.id)) and int(cold.crew_status().arrears) == 0
		and cold.crew_status().navigator and cold.credits == 5,
		"Paying the outstanding amount reactivates the navigator and consumes only his debt")
	_expect(cold.crew_dismiss(int(navigator.id)) and not cold.crew_dismiss(int(navigator.id))
		and int(cold.crew_status().count) == 1 and cold.crew_status().engineer,
		"The repaid navigator can now leave once without affecting the other job")


func _test_passenger_voyage() -> void:
	var flight := Flight.new()
	flight.credits = 1000
	var engineer := _role(flight.crew_candidates(), "engineer")
	var navigator := _role(flight.crew_candidates(), "navigator")
	if not _expect(not engineer.is_empty() and not navigator.is_empty()
		and flight.crew_hire(int(engineer.id)) and flight.crew_hire(int(navigator.id))
		and flight.contract_action() and flight.mining.insert_cargo("ore", flight.ship.cargo_capacity()),
		"A crew can staff a fully loaded freight and passenger ship without using commodity capacity"):
		return
	_tick(flight, float(flight.crew_status().next_due) - flight.orbit_time - 2.0)
	if not _expect(flight.passenger_accept(VELAR_PORT) and flight.passenger_follow(),
		"The cabin and the specialist jobs coexist with an active interstellar ticket"):
		return
	var cargo := flight.mining.snapshot()
	var advance_balance := flight.credits
	var expected_wages := int(engineer.wage) + int(navigator.wage)
	var ticket := flight.passenger_status()
	if not _expect(Fixture.depart(flight) and flight.credits == advance_balance - expected_wages
		and flight.passenger_status().active and float(flight.passenger_status().deadline) == float(ticket.deadline),
		"Guided departure reaches payroll while the passenger and freight remain aboard"):
		return
	flight.change_throttle(0.18)
	for _frame in range(12 * 60):
		if flight.jump_status(Catalog.VELAR_SYSTEM).ok:
			break
		_tick(flight)
	if not _expect(flight.start_jump() and is_equal_approx(flight.jump_seconds_left, 2.2)
		and flight.jump_seconds_left < Flight.JUMP_CHARGE,
		"A paid navigator shortens actual jump charging from 2.5 to 2.2 seconds"):
		return
	for _frame in range(4 * 60):
		if flight.system_id == Catalog.VELAR_SYSTEM:
			break
		_tick(flight)
	if not _expect(flight.system_id == Catalog.VELAR_SYSTEM and not flight.crew_dismiss(int(engineer.id))
		and flight.passenger_follow(), "Crew dismissal is unavailable in space and passenger guidance survives the jump"):
		return
	flight.set_autopilot(true)
	for _frame in range(85 * 60):
		if flight.docked == VELAR_PORT or not flight.autopilot:
			break
		_tick(flight)
	if not _expect(flight.docked == VELAR_PORT and flight.passenger_discharge()
		and not flight.passenger_status().active and int(flight.passenger_status().completed) == 1,
		"The paid crew and passengers complete a real Velar itinerary"):
		return
	_expect(flight.credits == advance_balance - expected_wages + int(ticket.fare) - int(ticket.advance)
		and flight.contract_stage == 1 and flight.mining.snapshot() == cargo
		and int(flight.crew_status().count) == 2,
		"Payroll and passenger settlement balance exactly while the original freight contract and ore stay intact")


func _test_previous_schema() -> void:
	var flight := Flight.new()
	flight.credits = 640
	if not _expect(flight.contract_action() and flight.passenger_accept(1), "Prepare a previous commander with both mission types"):
		return
	var previous := flight.snapshot()
	previous.schema = 23
	previous.ship.erase("hull_id")
	previous.erase("crew")
	var cold := Flight.new()
	if not _expect(cold.restore(previous) and int(cold.crew_status().count) == 0
		and int(cold.crew_status().arrears) == 0 and cold.passenger_status().active
		and cold.credits == flight.credits and cold.contract_stage == 1,
		"The pre-crew schema loads as a solo commander with passenger and freight obligations intact"):
		return
	var engineer := _role(cold.crew_candidates(), "engineer")
	if not _expect(not engineer.is_empty() and cold.crew_hire(int(engineer.id)),
		"A migrated commander can use the new hiring service immediately"):
		return
	var valid := cold.snapshot()
	var invalid := valid.duplicate(true)
	invalid.crew = {}
	_expect(not cold.restore(invalid) and cold.snapshot() == valid,
		"A malformed roster is rejected without affecting the loaded ship and its missions")


func _test_crew_touch() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := Main.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = Flight.new()
	var flight: Flight = game.flight
	var engineer := _role(flight.crew_candidates(), "engineer")
	if engineer.is_empty():
		_expect(false, "The berth has a real engineer for the crew touch path")
		viewport.queue_free()
		await process_frame
		return
	flight.credits = int(engineer.fee)
	var candidate_id := int(engineer.id)
	game._update_display(0.0)
	await process_frame
	_tap(viewport, game._hud._actions.get("services"), "Open port services by ordinary touch")
	await process_frame
	var services: Node = game._services
	_tap(viewport, services._crew_toggle, "Open the crew panel by ordinary touch")
	await process_frame
	_tap(viewport, _crew_button(services._crew_candidate_rows, candidate_id, "hire"), "Hire the named engineer by touch")
	await process_frame
	if _expect(flight.crew_status().engineer and flight.credits == 0
		and SessionIO.load_state().has("crew"), "Touch hiring charges the exact fee and saves the roster"):
		_tap(viewport, services._close_button, "Close the berth panel so the simulation can run")
		await process_frame
		game._physics_process(float(flight.crew_status().next_due) - flight.orbit_time)
		_expect(not flight.crew_status().engineer and int(flight.crew_status().arrears) == int(engineer.wage),
			"The actual scene applies unpaid wages while the crew panel is closed")
		flight.credits = int(engineer.wage)
		game._update_display(0.0)
		await process_frame
		_tap(viewport, game._hud._actions.get("services"), "Return to the real berth services")
		await process_frame
		_tap(viewport, services._crew_toggle, "Reopen the crew panel after payroll")
		await process_frame
		_tap(viewport, _crew_button(services._crew_member_rows, candidate_id, "pay"), "Pay the selected engineer through the crew panel")
		await process_frame
		_expect(flight.crew_status().engineer and int(flight.crew_status().arrears) == 0 and flight.credits == 0,
			"The actual payment button clears the engineer's debt and reactivates the job")
		_tap(viewport, _crew_button(services._crew_member_rows, candidate_id, "dismiss"), "Dismiss a fully paid engineer from the crew panel")
		await process_frame
		var reopened := Flight.new()
		_expect(int(flight.crew_status().count) == 0 and reopened.restore(SessionIO.load_state())
			and int(reopened.crew_status().count) == 0, "Touch dismissal empties and saves the crew berth")
	viewport.queue_free()
	await process_frame


func _role(rows: Array, name: String) -> Dictionary:
	for row: Dictionary in rows:
		if row.role == name:
			return row
	return {}


func _crew_button(rows: Array, id: int, action: String) -> Button:
	for row: Dictionary in rows:
		if int(row.id) == id:
			return row.get(action)
	return null


func _tap(viewport: SubViewport, button: Button, description: String) -> void:
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree()
		and not button.disabled and button.get_global_rect().size.y >= 44.0, description):
		return
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 13
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		viewport.push_input(event, true)


func _tick(flight: Flight, delta := STEP) -> void:
	flight.update(delta, Vector2.ZERO, 0.0, false, false)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
