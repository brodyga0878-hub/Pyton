extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const Main := preload("res://main.tscn")
const HOME_PORT := 0
const LOCAL_PORT := 1
const WRONG_PORT := 3
const VELAR_PORT := 10
const STEP := Fixture.STEP

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_on_time()
	_test_deadline_and_debt()
	_test_berth_cancellation()
	_test_previous_schema()
	await _test_touch_board()
	print("Passenger integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_on_time() -> void:
	var flight := Flight.new()
	flight.credits = 180
	if not _expect(flight.docked == HOME_PORT and flight.station_services_available()
		and not flight.passenger_board().is_empty() and not flight.passenger_accept(-1),
		"The operational home port offers actual passenger routes and rejects an invalid berth"):
		return
	_expect(not flight.passenger_accept(Catalog.HEATHER_PORT),
		"An uncommissioned frontier dock cannot be the passenger destination")
	if not _expect(flight.contract_action() and flight.mining.insert_cargo("ore", flight.ship.cargo_capacity()),
		"An existing freight assignment can coexist with a completely full commodity hold"):
		return
	var cargo := flight.mining.snapshot()
	var contract_destination := flight.contract_destination
	var original_balance := flight.credits
	if not _expect(flight.passenger_accept(VELAR_PORT), "A two-seat Velar service can board with no free freight capacity"):
		return
	var boarding := flight.passenger_status()
	_expect(boarding.active and not boarding.overdue and int(boarding.origin) == HOME_PORT
		and int(boarding.destination) == VELAR_PORT and int(boarding.seats) == 2
		and int(boarding.seats) == int(boarding.capacity), "The interstellar party occupies its own cabin seats")
	_expect(flight.credits == original_balance + int(boarding.advance) and int(boarding.advance) > 0
		and int(boarding.fare) > int(boarding.advance) and flight.mining.snapshot() == cargo,
		"Boarding pays an advance once and does not change the freight hold")
	var booked := flight.snapshot()
	_expect(not flight.passenger_accept(LOCAL_PORT) and flight.snapshot() == booked,
		"A competing passenger booking cannot claim occupied seats or pay another advance")
	var wrong_berth := _parked_copy(flight, WRONG_PORT)
	if _expect(wrong_berth != null and wrong_berth.docked == WRONG_PORT, "The booking persists at a wrong local berth"):
		_expect(not wrong_berth.passenger_status().can_discharge and not wrong_berth.passenger_discharge()
			and wrong_berth.credits == flight.credits, "A wrong timely port cannot settle or cancel the fare")

	if not _expect(flight.plan_route(Catalog.FRINGE_SYSTEM) and flight.passenger_follow()
		and flight.jump_target == Catalog.VELAR_SYSTEM and flight.contract_destination == contract_destination,
		"Passenger guidance replaces the old jump route without changing the freight assignment"):
		return
	var path := "user://passengers-booked.json"
	var cold := Flight.new()
	if not _expect(SessionIO.save_state(flight.snapshot(), path) == OK and cold.restore(SessionIO.load_state(path))
		and cold.passenger_status().active and cold.passenger_status().deadline == boarding.deadline
		and cold.credits == flight.credits and cold.jump_target == Catalog.VELAR_SYSTEM,
		"A disk reload preserves the paid advance, deadline and selected jump"):
		return
	flight = cold
	if not _expect(flight.dock_action() and flight.passenger_board().is_empty()
		and not flight.passenger_accept(LOCAL_PORT) and not flight.passenger_discharge(),
		"The departing ship has no passenger services even while held by the station"):
		return
	if not _expect(Fixture.await_departure(flight) and _jump_outbound(flight),
		"The booked ship physically departs, clears the station and jumps to Velar"):
		return
	_expect(flight.passenger_status().active and flight.passenger_status().destination == VELAR_PORT
		and not flight.passenger_status().can_discharge and flight.credits == original_balance + int(boarding.advance),
		"The passenger remains aboard during interstellar approach without early payment")
	if not _expect(flight.passenger_follow() and _dock_at(flight, VELAR_PORT),
		"The passenger route guides the ship all the way to its actual destination dock"):
		return
	var arrived := flight.passenger_status()
	var on_time_balance := flight.credits
	_expect(arrived.can_discharge and not arrived.overdue and flight.passenger_discharge(),
		"A timely arrival at the correct dock can settle the passage")
	var paid := flight.passenger_status()
	_expect(not paid.active and int(paid.seats) == 0 and int(paid.completed) == 1
		and int(paid.reputation) > int(boarding.reputation)
		and flight.credits == on_time_balance + int(boarding.fare) - int(boarding.advance),
		"Timely settlement releases the cabin, records the success and pays precisely the remaining fare")
	_expect(flight.contract_stage == 1 and flight.contract_destination == contract_destination
		and flight.mining.snapshot() == cargo, "The complete passage leaves the freight contract and hold untouched")
	var reopened := Flight.new()
	_expect(SessionIO.save_state(flight.snapshot(), path) == OK and reopened.restore(SessionIO.load_state(path))
		and not reopened.passenger_discharge() and reopened.credits == flight.credits
		and int(reopened.passenger_status().completed) == 1,
		"Settled passenger tickets cannot pay twice after a cold restart")


func _test_deadline_and_debt() -> void:
	var flight := Flight.new()
	flight.orbit_time = 120.0
	if not _expect(flight.passenger_accept(LOCAL_PORT), "The home board accepts a one-seat local service"):
		return
	var booked := flight.passenger_status()
	_expect(int(booked.seats) == 1 and int(booked.capacity) == 2 and int(booked.advance) > 1,
		"The local party occupies one cabin seat and advances a partial fare")
	# Represent a passenger advance already spent before reaching the deadline.
	flight.credits = 1
	_tick(flight, float(booked.remaining) - 1.0)
	_expect(is_equal_approx(flight.orbit_time, float(booked.deadline) - 1.0)
		and not flight.passenger_status().overdue and flight.cycle_time_scale(),
		"The booked service stays timely on the last second and the parked ship can accelerate time")
	_tick(flight, 1.0 / flight.time_scale)
	var late := flight.passenger_status()
	if not _expect(flight.orbit_time == float(booked.deadline) and late.active and late.overdue
			and int(late.seats) == 1 and late.remaining == 0.0 and flight.credits == 1,
		"The exact deadline becomes overdue at accelerated time without deleting the passenger or charging twice"):
		return
	var path := "user://passengers-overdue.json"
	var cold := Flight.new()
	if not _expect(SessionIO.save_state(flight.snapshot(), path) == OK and cold.restore(SessionIO.load_state(path))
		and cold.passenger_status().overdue and cold.passenger_status().active,
		"A cold reload at the exact deadline keeps the overdue party aboard"):
		return
	var wrong_berth := _parked_copy(cold, WRONG_PORT)
	if not _expect(wrong_berth != null and wrong_berth.passenger_status().can_discharge,
			"A late passenger may disembark at an operational berth other than the destination"):
		return
	var debt := int(booked.advance) - 1
	if not _expect(wrong_berth.passenger_discharge() and not wrong_berth.passenger_status().active
		and wrong_berth.credits == 0 and int(wrong_berth.passenger_status().debt) == debt,
		"An overdue disembarkation refunds the attainable amount and records the remaining debt"):
		return
	var discharged := wrong_berth.passenger_status()
	_expect(int(discharged.seats) == 0 and int(discharged.late) == 1 and int(discharged.completed) == 0
		and int(discharged.reputation) < int(booked.reputation)
		and not wrong_berth.passenger_discharge() and not wrong_berth.passenger_repay(),
		"Late discharge frees the seat and applies one unfavourable outcome without paying the balance")
	var debt_state := wrong_berth.snapshot()
	wrong_berth = Flight.new()
	if not _expect(SessionIO.save_state(debt_state, path) == OK and wrong_berth.restore(SessionIO.load_state(path))
		and int(wrong_berth.passenger_status().debt) == debt and int(wrong_berth.passenger_status().late) == 1,
		"Outstanding passenger debt and its single recorded late outcome survive a disk reload"):
		return
	var board := wrong_berth.passenger_board()
	if not _expect(not board.is_empty() and not wrong_berth.passenger_accept(int(board[0].destination)),
		"Passenger debt blocks boarding and prevents another advance"):
		return
	wrong_berth.credits = 1
	_expect(wrong_berth.passenger_repay() and wrong_berth.credits == 0
		and int(wrong_berth.passenger_status().debt) == debt - 1,
		"A funded partial repayment uses no more than the available credits")
	wrong_berth.credits = debt + 90
	if debt > 1:
		_expect(wrong_berth.passenger_repay(), "The remaining debt can be paid at an operational berth")
	_expect(int(wrong_berth.passenger_status().debt) == 0 and not wrong_berth.passenger_repay()
		and wrong_berth.passenger_accept(int(board[0].destination)),
		"Full repayment reopens boarding without a duplicate charge")


func _test_berth_cancellation() -> void:
	var flight := Flight.new()
	var balance := 130
	flight.credits = balance
	if not _expect(flight.passenger_accept(LOCAL_PORT) and flight.passenger_status().can_discharge
		and flight.passenger_status().canceling, "Only the departure berth offers early, timely cancellation"):
		return
	var before := flight.passenger_status()
	_expect(flight.passenger_discharge() and flight.credits == balance and not flight.passenger_status().active
		and int(flight.passenger_status().seats) == 0 and int(flight.passenger_status().debt) == 0
		and int(flight.passenger_status().reputation) < int(before.reputation)
		and int(flight.passenger_status().completed) == 0,
		"Timely cancellation at the origin refunds the advance and does not award the fare")
	_expect(not flight.passenger_discharge() and flight.credits == balance,
		"A cancelled passage cannot refund the advance again")


func _test_previous_schema() -> void:
	var flight := Flight.new()
	flight.credits = 245
	flight.ship.fuel = 71.0
	flight.ship.jump_fuel = 52.0
	var previous := flight.snapshot()
	previous.schema = 22
	previous.ship.erase("mining_laser")
	previous.ship.erase("fragment_collector")
	previous.ship.erase("hydrogen_scoop")
	previous.ship.erase("fuel_pump")
	previous.ship.erase("pump_mode")
	previous.ship.erase("range_drive")
	previous.ship.erase("drive_kind")
	previous.mining.reserves.resize(Catalog.AUTHORED_DESTINATION_COUNT)
	previous.ship.erase("hull_id")
	previous.erase("passengers")
	if not _expect(flight.restore(previous) and not flight.passenger_status().active
		and int(flight.passenger_status().capacity) == 2 and int(flight.passenger_status().debt) == 0
		and flight.credits == 245 and flight.ship.fuel == 71.0 and flight.ship.jump_fuel == 52.0,
		"An older commander starts with an empty cabin and keeps the berth and balances"):
		return
	if not _expect(flight.passenger_accept(LOCAL_PORT), "A migrated save can enter the new passenger lifecycle"):
		return
	var valid := flight.snapshot()
	var invalid := valid.duplicate(true)
	invalid.passengers.debt = -1
	_expect(not flight.restore(invalid) and flight.snapshot() == valid,
		"Invalid passenger state is rejected without altering a live booking")


func _test_touch_board() -> void:
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
	game._update_display(0.0)
	await process_frame
	_tap(viewport, game._hud._actions.get("market"), "Open the ordinary port market by touch")
	await process_frame
	var market: Node = game._market
	_tap(viewport, market._passenger_tab, "Open the passenger board by touch")
	await process_frame
	var accept: Button
	for row: Dictionary in market._passenger_offer_rows:
		if int(row.destination) == LOCAL_PORT:
			accept = row.accept
			break
	_tap(viewport, accept, "Accept the local passage through the actual offer row")
	await process_frame
	var boarding := flight.passenger_status()
	if _expect(boarding.active and int(boarding.destination) == LOCAL_PORT
		and SessionIO.load_state().get("passengers", {}).get("destination", -1) == LOCAL_PORT,
		"Boarding through the market emits the contract and saves it"):
		_tap(viewport, market._close_button, "Close the port board")
		await process_frame
		_expect(flight.passenger_follow(), "Set the local passenger route")
		_tap(viewport, game._hud._actions.get("dock"), "Request ordinary port departure by touch")
		if _expect(Fixture.await_departure(flight, 15.0, game._physics_process)
			and _dock_at(flight, LOCAL_PORT, game._physics_process),
			"The local ticket remains on the normal exit and approach path"):
			game._update_display(0.0)
			await process_frame
			_tap(viewport, game._hud._actions.get("market"), "Open the destination port market by touch")
			await process_frame
			_tap(viewport, market._passenger_tab, "Open the passenger destination board")
			await process_frame
			_tap(viewport, market._passenger_discharge_button, "Settle the timely passenger through the destination button")
			_expect(not flight.passenger_status().active and flight.credits == int(boarding.fare)
				and int(flight.passenger_status().completed) == 1,
				"The real discharge button settles the ticket and credits its remaining balance")
	viewport.queue_free()
	await process_frame


func _parked_copy(source: Flight, port: int) -> Flight:
	var flight := Flight.new()
	var state := source.snapshot()
	state.system_id = Catalog.system_of_site(port)
	state.target = port
	state.docked = port
	state.planned_target = -1
	var contact := flight.docking_position(port)
	state.position = [contact.x, contact.y, contact.z]
	state.velocity = [0.0, 0.0, 0.0]
	state.dock_access = flight.dock_access.snapshot()
	return flight if flight.restore(state) else null


func _jump_outbound(flight: Flight) -> bool:
	flight.change_throttle(0.18)
	for _frame in range(12 * 60):
		if flight.jump_status(Catalog.VELAR_SYSTEM).ok:
			break
		_tick(flight)
	if not flight.start_jump():
		return false
	for _frame in range(4 * 60):
		if flight.system_id == Catalog.VELAR_SYSTEM:
			return true
		_tick(flight)
	return false


func _dock_at(flight: Flight, port: int, tick := Callable()) -> bool:
	if not flight.select_target(port):
		return false
	flight.set_autopilot(true)
	for _frame in range(85 * 60):
		if flight.docked == port:
			return true
		if not flight.autopilot:
			return false
		if tick.is_valid():
			tick.call(STEP)
		else:
			_tick(flight)
	return false


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
