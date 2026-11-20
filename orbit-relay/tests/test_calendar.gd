extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Calendar := preload("res://scripts/mission_calendar.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Economy := preload("res://scripts/port_economy.gd")
const Crew := preload("res://scripts/crew.gd")
const Freight := preload("res://scripts/npc_freight.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Session := preload("res://scripts/session_io.gd")
const Main := preload("res://main.tscn")
const HOME_PORT := 0
const NEXT_PORT := 1
const MIDNIGHT := 78.0
const STEP := Fixture.STEP

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_midnight_and_freight()
	var booked := _book_real_services()
	if booked != null:
		_test_service_deadlines(booked)
		await _test_touch(booked)
	_test_departure_pause()
	_test_migration()
	print("Mission calendar integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_midnight_and_freight() -> void:
	var flight := Flight.new()
	var initial := flight.clock_status()
	_expect(initial.stamp == "01.01.2478 · 23:58:42" and initial.date == "01.01.2478"
		and initial.clock == "23:58:42" and initial.epoch == 0.0 and initial.scale == 1 and not initial.paused,
		"A fresh earned flight uses the fixed in-game calendar without consulting the device clock")
	_expect(Calendar.stamp(MIDNIGHT - 0.000001) == "01.01.2478 · 23:59:59"
		and Calendar.stamp(MIDNIGHT) == "02.01.2478 · 00:00:00"
		and Calendar.stamp(MIDNIGHT + 86400.0) == "03.01.2478 · 00:00:00",
		"Whole-second conversion changes the civil date at the exact midnight boundary")
	var supplies := _supplies(flight)
	var destination_stock := flight.market.stock(NEXT_PORT, "circuits")
	if not _expect(_warp(flight), "The parked pilot can cycle from 1× to 4× and 16×"):
		return
	_tick_until(flight, MIDNIGHT - 0.25)
	var underway := flight.freight_status(NEXT_PORT)[0]
	if not _expect(underway.in_transit and underway.amount == Freight.CAPACITY and underway.arrival_eta == 0.25
		and flight.market.stock(NEXT_PORT, "circuits") == destination_stock
		and flight.clock_status().stamp == "01.01.2478 · 23:59:59",
		"A quarter second before midnight the scheduled shipment is still aboard"):
		return
	_expect(flight.toggle_time_pause() and flight.status_event == "time_paused" and flight.clock_status().paused,
		"The explicit pause activates at 16× without moving the world clock")
	var paused := flight.snapshot()
	flight.update(24.0, Vector2(0.7, 0.7), 0.8, true, true)
	_expect(flight.snapshot() == paused and flight.time_scale == 16 and not flight.cycle_time_scale(),
		"Pause keeps time, position, stock, other world state and the selected speed fixed even with held controls")
	var cold := _roundtrip(flight, "user://calendar-before-freight.json")
	if cold == null:
		return
	_expect(cold.clock_status().paused and cold.orbit_time == MIDNIGHT - 0.25
		and cold.freight.snapshot() == flight.freight.snapshot() and cold.market.snapshot() == flight.market.snapshot(),
		"A paused disk load preserves the pending delivery and its warehouse balances")
	_tick(cold, 86400.0)
	_expect(cold.orbit_time == MIDNIGHT - 0.25 and cold.snapshot() == paused,
		"The paused cold state ignores a full day's worth of update calls")
	if not _expect(cold.toggle_time_pause() and cold.status_event == "time_resumed" and _warp(cold),
		"A cold paused pilot resumes and can select acceleration again"):
		return
	_tick(cold, 0.25 / cold.time_scale)
	var delivered := cold.freight_status(NEXT_PORT)[0]
	if not _expect(cold.orbit_time == MIDNIGHT and cold.clock_status().stamp == "02.01.2478 · 00:00:00"
		and not delivered.in_transit and delivered.last_delivered == Freight.CAPACITY
		and cold.market.stock(NEXT_PORT, "circuits") == destination_stock + Freight.CAPACITY,
		"The exact accelerated midnight adds the first eight circuits once"):
		return
	var resumed := _roundtrip(cold, "user://calendar-after-freight.json")
	if resumed == null:
		return
	_tick(resumed, 0.25)
	_expect(resumed.market.snapshot() == cold.market.snapshot() and resumed.freight.snapshot() == cold.freight.snapshot(),
		"Reloading at the arrival boundary does not replay the unloaded shipment")
	if not _expect(_warp(resumed), "The reloaded ship can restore the pilot's selected 16× rate through normal controls"):
		return
	var reference := Flight.new()
	for through: float in [160.25, 360.25, 720.25, 86478.25]:
		_tick_until(resumed, through)
		_tick_until(reference, through, 7.0)
		_expect(resumed.orbit_time == reference.orbit_time and resumed.clock_status().stamp == reference.clock_status().stamp
			and resumed.market.snapshot() == reference.market.snapshot() and resumed.freight.snapshot() == reference.freight.snapshot()
			and _supplies(resumed) == supplies,
			"The accelerated clock and normal clock agree across every due shipment at t=%.2f" % through)
	_expect(resumed.clock_status().stamp == "03.01.2478 · 00:00:00",
		"A full accelerated civil day reaches the following midnight with conserved cargo")


func _book_real_services() -> Flight:
	var flight := Flight.new()
	if not _expect(flight.contract_action() and Fixture.depart(flight) and flight.select_target(NEXT_PORT),
		"A zero-credit pilot accepts real freight and departs to earn the hiring fee"):
		return null
	flight.set_autopilot(true)
	for _frame in range(100 * 60):
		if flight.docked == NEXT_PORT:
			break
		_tick(flight, STEP)
	if not _expect(flight.docked == NEXT_PORT and flight.contract_action() and flight.credits == 240
		and flight.orbit_time < MIDNIGHT - 0.25, "The physically delivered cargo is paid before the first midnight"):
		return null
	var candidate := int(flight.crew_candidates()[0].id)
	if not _expect(flight.crew_hire(candidate) and flight.crew_status().engineer and flight.passenger_accept(HOME_PORT),
		"A paid engineer and a real passenger have independent scheduled deadlines"):
		return null
	_tick_until(flight, MIDNIGHT - 0.25)
	return flight


func _test_service_deadlines(booked: Flight) -> void:
	var flight := Flight.new()
	if not _expect(flight.restore(booked.snapshot()) and _warp(flight), "The booked parked flight can advance at 16×"):
		return
	var due := float(flight.crew_status().next_due)
	var deadline := float(flight.passenger_status().deadline)
	var wage := int(flight.crew_status().members[0].wage)
	var credits := flight.credits
	if not _expect(due > MIDNIGHT and deadline > due and deadline < due + Crew.WAGE_PERIOD,
		"The first wage and ticket deadline fall separately after midnight"):
		return
	_tick_until(flight, due - 0.25)
	_expect(flight.credits == credits and not flight.passenger_status().overdue,
		"The first payroll is untouched immediately before its due instant")
	flight.toggle_time_pause()
	_tick(flight, 200.0)
	_expect(flight.orbit_time == due - 0.25 and flight.credits == credits and not flight.passenger_status().overdue,
		"A pause across both apparent wall-clock deadlines issues neither payroll nor expiry")
	flight.toggle_time_pause()
	_tick(flight, 0.25 / flight.time_scale)
	_expect(flight.orbit_time == due and flight.credits == credits - wage
		and float(flight.crew_status().next_due) == due + Crew.WAGE_PERIOD and not flight.passenger_status().overdue,
		"The exact wage boundary charges once while the separate ticket remains timely")
	_tick_until(flight, deadline - 0.25)
	flight.toggle_time_pause()
	var cold := _roundtrip(flight, "user://calendar-before-passenger.json")
	if cold == null:
		return
	_tick(cold, 200.0)
	_expect(cold.clock_status().paused and cold.orbit_time == deadline - 0.25
		and cold.credits == credits - wage and not cold.passenger_status().overdue,
		"Reloading paused just before expiry neither repeats wages nor expires the ticket early")
	if not _expect(cold.toggle_time_pause() and _warp(cold), "The restored ticket can continue at 16×"):
		return
	_tick(cold, 0.25 / cold.time_scale)
	_expect(cold.orbit_time == deadline and cold.passenger_status().active and cold.passenger_status().overdue
		and cold.credits == credits - wage and cold.status_event == "passenger_overdue",
		"Ticket expiry triggers one notice at its own exact date while the passenger remains aboard")
	cold.status_event = ""
	_tick(cold, 0.25 / cold.time_scale)
	_expect(cold.status_event != "passenger_overdue" and cold.credits == credits - wage,
		"The following clock tick does not repeat the completed expiry or wage")
	var resumed := _roundtrip(cold, "user://calendar-after-passenger.json")
	if resumed == null:
		return
	_tick(resumed, 0.25)
	_expect(resumed.passenger_status().overdue and resumed.credits == credits - wage
		and resumed.status_event != "passenger_overdue",
		"A later cold load keeps recorded expiry without triggering it again")
	_tick_until(resumed, due + 2.0 * Crew.WAGE_PERIOD)
	_expect(resumed.credits == credits - 3 * wage
		and float(resumed.crew_status().next_due) == due + 3.0 * Crew.WAGE_PERIOD,
		"Crossing two more payroll periods debits the correct number of wages")


func _test_touch(booked: Flight) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := Main.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = booked
	game._update_display(0.0)
	await process_frame
	var flight: Flight = game.flight
	var before := flight.snapshot()
	var hud: Node = game._hud
	_expect(hud._clock.text == "01.01.2478\n23:59:59", "The real cockpit shows the current calendar date and time")
	_tap(viewport, hud._actions["time_pause"], "Tap the real cockpit pause button")
	await process_frame
	game._physics_process(24.0)
	var stored := Session.load_state()
	_expect(flight.time_paused and hud._actions["time_pause"].text == "Продолжить" and hud._actions["time"].disabled
		and flight.orbit_time == float(before.orbit_time) and flight.market.snapshot() == before.market
		and stored.get("time_paused") == true and float(stored.orbit_time) == flight.orbit_time,
		"Touch pause changes the controls, saves pause immediately and stops scene physics")
	_tap(viewport, hud._actions["journal"], "Open the paused passenger journal from the real cockpit")
	await process_frame
	var journal: Node = game._journal
	_tap(viewport, journal._passenger_tab, "Switch the actual journal to passenger deadlines")
	await process_frame
	_expect(journal.is_open() and journal._clock_readout.text == flight.clock_status().stamp + " · Пауза"
		and journal._passenger_deadline.is_visible_in_tree()
		and Calendar.stamp(float(flight.passenger_status().deadline)) in journal._passenger_deadline.text,
		"The journal shares the paused clock and displays the absolute passenger deadline")
	_tap(viewport, journal._close_button, "Close the passenger journal through its original button")
	await process_frame
	_tap(viewport, hud._actions["time_pause"], "Resume through the real cockpit button")
	await process_frame
	game._physics_process(0.25)
	game._update_display(0.0)
	await process_frame
	_expect(not flight.time_paused and hud._clock.text == "02.01.2478\n00:00:00"
		and flight.freight_status(NEXT_PORT)[0].last_delivered == Freight.CAPACITY,
		"Resuming via touch crosses the first midnight and unloads freight through scene physics")
	viewport.queue_free()
	await process_frame


func _test_departure_pause() -> void:
	var flight := Flight.new()
	if not _expect(flight.dock_action(), "The dock accepts a real departure before testing motion on pause"):
		return
	for _frame in range(14 * 60):
		if flight.departure_status().phase == "transit":
			break
		_tick(flight, STEP)
	_tick(flight, 0.5)
	var progress := float(flight.departure_status().progress)
	if not _expect(flight.departure_status().phase == "transit" and progress > 0.0 and progress < 1.0,
		"The ship is physically moving through the departure corridor"):
		return
	flight.toggle_time_pause()
	var held := flight.snapshot()
	_tick(flight, 12.0)
	_expect(flight.snapshot() == held and float(flight.departure_status().progress) == progress,
		"Pause keeps the moving departure corridor, ship and clock fixed")
	var cold := _roundtrip(flight, "user://calendar-departure.json")
	if cold == null:
		return
	_expect(cold.time_paused and is_equal_approx(float(cold.departure_status().progress), progress)
		and cold.position.is_equal_approx(flight.position) and cold.velocity.is_equal_approx(flight.velocity),
		"Cold load preserves both pause and its in-progress departure")
	_expect(cold.toggle_time_pause() and Fixture.await_departure(cold) and cold.docked < 0,
		"Resuming completes the same real departure")


func _test_migration() -> void:
	var previous := Flight.new()
	_tick_until(previous, MIDNIGHT - 0.25)
	var historical := previous.snapshot()
	historical.schema = 34
	Fixture.remove_ground_ports_from_legacy(historical)
	historical.erase("time_paused")
	historical.ship.erase("range_drive")
	historical.ship.erase("drive_kind")
	var restored := Flight.new()
	if not _expect(restored.restore(historical) and not restored.time_paused
		and restored.clock_status().stamp == "01.01.2478 · 23:59:59",
		"A pre-calendar save acquires the calendar and defaults to running"):
		return
	_tick(restored, 0.25)
	_expect(restored.freight_status(NEXT_PORT)[0].last_delivered == Freight.CAPACITY,
		"Adding a clock to an older save leaves its next delivery intact")
	var malformed := restored.snapshot()
	malformed.time_paused = 0
	var unchanged := restored.snapshot()
	_expect(not restored.restore(malformed) and restored.snapshot() == unchanged,
		"A malformed pause field is rejected without partially loading the flight")


func _roundtrip(flight: Flight, path: String) -> Flight:
	var cold := Flight.new()
	if not _expect(Session.save_state(flight.snapshot(), path) == OK and cold.restore(Session.load_state(path)),
		"The live state writes and reloads through the production save path"):
		return null
	return cold


func _warp(flight: Flight) -> bool:
	return (flight.time_scale == 1 and flight.cycle_time_scale() and flight.time_scale == 4
		and flight.cycle_time_scale() and flight.time_scale == 16)


func _tick(flight: Flight, seconds: float) -> void:
	flight.update(seconds, Vector2.ZERO, 0.0, false, false)


func _tick_until(flight: Flight, epoch: float, max_delta := 4.0) -> void:
	while flight.orbit_time < epoch - 0.000000001:
		_tick(flight, minf(max_delta, (epoch - flight.orbit_time) / flight.time_scale))


func _supplies(flight: Flight) -> Dictionary:
	var totals := {}
	for good in Economy.GOODS:
		totals[good] = 0
	for system in range(Catalog.CORE_SYSTEM_COUNT):
		for port in Catalog.ports_for(system):
			for good in Economy.GOODS:
				totals[good] += flight.market.stock(port, good)
		for service in flight.freight.services(system, flight.orbit_time):
			if service.in_transit:
				totals[service.good] += int(service.amount)
	return totals


func _tap(viewport: SubViewport, button: Button, description: String) -> void:
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled
		and button.get_global_rect().size.y >= 42.0, description):
		return
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 15
		touch.pressed = pressed
		touch.position = button.get_global_rect().get_center()
		viewport.push_input(touch, true)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
