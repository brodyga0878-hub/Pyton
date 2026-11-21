extends SceneTree

const Calendar := preload("res://scripts/mission_calendar.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Crew := preload("res://scripts/crew.gd")
const Expedition := preload("res://scripts/expedition.gd")
const Fronts := preload("res://scripts/faction_fronts.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Session := preload("res://scripts/session_io.gd")
const ShipSystems := preload("res://scripts/ship_systems.gd")
const HOME := Catalog.HOME_SYSTEM
const STEP := Fixture.STEP
const STANDARD_DRIVE := "standard"
const RANGE_DRIVE := "range"
const TICKET_PATH := "user://hyperspace-paid.json"

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_quotes()
	var flight := _outfit_real_ship()
	if flight != null:
		_test_paid_transit(flight)
	_test_convoy_during_transit()
	print("Hyperspace integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_quotes() -> void:
	var flight := Flight.new()
	var destination := Catalog.VELAR_SYSTEM
	var distance := Catalog.jump_distance(HOME, destination)
	var base_cost := Catalog.jump_cost(HOME, destination)
	var unloaded := flight.jump_travel_seconds(HOME, destination)
	_expect(flight.jump_tariff(HOME, destination) == base_cost and unloaded == ceili(12.0 + 4.0 * distance),
		"The standard drive keeps the existing tariff and charges the unloaded leg's simulated duration")
	_expect(not flight.select_jump_drive(RANGE_DRIVE) and not flight.select_jump_drive("unknown")
		and not flight.service_action("range_drive"),
		"A fresh pilot cannot select an unfitted drive or buy equipment without credits")
	if _expect(flight.mining.insert_cargo("ore", flight.ship.cargo_capacity()), "Prepare a full commodity hold for the duration formula"):
		var loaded := flight.jump_travel_seconds(HOME, destination)
		_expect(flight.jump_tariff(HOME, destination) > base_cost and loaded == ceili((12.0 + 4.0 * distance) * 1.6)
			and loaded > unloaded, "A fully loaded standard drive spends more fuel and game time")
	_expect(flight.jump_tariff(HOME, HOME) == 0 and flight.jump_travel_seconds(HOME, HOME) == 0,
		"A same-system leg has neither a fuel tariff nor a travel duration")


func _outfit_real_ship() -> Flight:
	var flight := Flight.new()
	for delivery in range(4):
		if not _expect(flight.contract_action(), "Accept local freight to earn equipment and pilot fees"):
			return null
		var port := flight.contract_destination
		if not _expect(Fixture.depart(flight) and flight.select_target(port),
			"Depart physically for the contracted port"):
			return null
		flight.set_autopilot(true)
		if not _expect(_advance(flight, func() -> bool: return flight.docked == port, 125.0) and flight.contract_action(),
			"Complete the local cargo delivery at its actual berth"):
			return null
	_expect(flight.deliveries == 4 and flight.credits >= 600, "Four earned courier payouts fund the long-range outfitting")
	var balance := flight.credits
	if not _expect(flight.service_offer("range_drive").cost == 450 and flight.service_action("range_drive")
		and flight.credits == balance - 450 and not flight.service_action("range_drive")
		and flight.credits == balance - 450, "Buy the long-range drive at the real berth and pay only once"):
		return null
	if not _expect(flight.scan_galaxy() and _farthest_known(flight) >= Catalog.AUTHORED_SYSTEM_COUNT,
		"The actual scanner charts distant procedural systems through the existing policy"):
		return null
	if not _expect(flight.market_trade("ore", "buy", 3), "The run takes real purchased cargo into the jump"):
		return null
	return flight


func _test_paid_transit(flight: Flight) -> void:
	var destination := _farthest_known(flight)
	var base := Catalog.jump_cost(HOME, destination)
	var distance := Catalog.jump_distance(HOME, destination)
	var mass_ratio := flight.ship.flight_mass(flight.mining.ore_hold) / ShipSystems.REFERENCE_MASS
	var standard_seconds := ceili((12.0 + 4.0 * distance) *
		(1.0 + 0.6 * float(flight.mining.ore_hold) / float(flight.ship.cargo_capacity())))
	flight.select_jump_drive(STANDARD_DRIVE)
	var standard := flight.route_preview(destination)
	var standard_fare := ceili(base * mass_ratio)
	_expect(flight.jump_tariff(HOME, destination) == standard_fare and flight.jump_travel_seconds(HOME, destination) == standard_seconds
		and standard.available, "The equipped ship can still select the standard drive and quote the cargo-weighted leg")
	flight.select_jump_drive(RANGE_DRIVE)
	var fare := ceili(float(base) * 0.75 * (1.0 + (mass_ratio - 1.0) * 0.82))
	var travel := ceili((7.0 + 2.5 * distance) *
		(1.0 + 0.6 * float(flight.mining.ore_hold) / float(flight.ship.cargo_capacity())))
	if not _expect(flight.jump_tariff(HOME, destination) == fare and flight.jump_travel_seconds(HOME, destination) == travel
		and fare < standard_fare and travel < standard_seconds, "The selected long-range drive quotes independently shorter travel and a smaller fare"):
		return
	var route := flight.route_preview(destination)
	if not _expect(route.available and route.path == [HOME, destination] and int(route.legs[0].fuel) == fare
		and int(route.legs[0].seconds) == travel and int(route.seconds) == travel
		and flight.plan_route(destination) and flight.planned_route().next == destination,
		"The real planned direct leg, preview and fitted drive agree on the distant generated destination"):
		return
	if not _prepare_deadlines(flight):
		return
	var control := Flight.new()
	if not _expect(control.restore(flight.snapshot()), "Duplicate the last real berth for a world-ledger reference run"):
		return
	if not _expect(Fixture.depart(flight) and _fly_clear(flight, destination),
		"The fitted ship physically leaves the port and clears the jump gate"):
		return
	var start_time := flight.orbit_time
	var start_fuel := flight.ship.jump_fuel
	var reaction := flight.ship.fuel
	var fare_deadline := float(flight.passenger_status().deadline)
	var wage_due := float(flight.crew_status().next_due)
	var wage := int(flight.crew_status().members[0].wage)
	var credits := flight.credits
	if not _expect(start_time + Flight.JUMP_CHARGE < fare_deadline and wage_due > start_time + Flight.JUMP_CHARGE
		and wage_due < start_time + Flight.JUMP_CHARGE + travel,
		"Both real passenger and crew deadlines fall inside the upcoming simulated transit"):
		return
	var saved_drive := flight.ship.drive_kind
	_expect(not flight.select_jump_drive(STANDARD_DRIVE) and flight.ship.drive_kind == saved_drive,
		"The selected drive cannot be changed after leaving the berth")
	if not _expect(flight.start_jump() and flight.jump_progress_status().phase == "charge",
		"Starting a payable jump first shows a cancellable charging phase"):
		return
	_tick(flight, 0.5)
	_expect(flight.jump_progress_status().phase == "charge" and flight.ship.jump_fuel == start_fuel
		and flight.system_id == HOME, "No fare or relocation happens during the initial charge")
	if not _expect(flight.cancel_jump() and flight.jump_target == destination and flight.ship.jump_fuel == start_fuel
		and flight.jump_seconds_left <= 0.0, "Cancellation during charge keeps the full fare and selected destination"):
		return
	start_time = flight.orbit_time
	if not _expect(flight.start_jump() and _advance(flight,
		func() -> bool: return flight.jump_progress_status().phase == "transit", Flight.JUMP_CHARGE),
		"Recharging enters a distinct paid transit before visible arrival"):
		return
	_expect(flight.system_id == HOME and flight.ship.jump_fuel == start_fuel - fare
		and flight.ship.fuel == reaction and flight.jump_target == destination
		and not flight.start_jump() and not flight.cancel_jump() and not flight.cancel_route(),
		"Paid transit spends the fare once, locks the route and cannot be cancelled")
	_expect(not flight.passenger_status().overdue and flight.credits == credits,
		"The date and service deadlines have not yet advanced to the distant arrival")
	flight.toggle_time_pause()
	var before := flight.snapshot()
	var committed_time := flight.orbit_time
	var charge_time := Flight.JUMP_CHARGE - Flight.JUMP_TRANSIT_WALL
	_expect(absf(committed_time - start_time - charge_time) <= STEP + 0.00001,
		"The visible transit begins at the end of the ordinary charge segment")
	_expect(float(before.jump_transit.remaining) <= Flight.JUMP_TRANSIT_WALL
		and float(before.jump_transit.duration) == float(travel) and int(before.jump_transit.fare) == fare,
		"The saved payment record binds the charged fare, calendar duration and short animation remainder")
	flight.update(60.0, Vector2.ONE, 1.0, true, true)
	_expect(flight.snapshot() == before and flight.jump_progress_status().phase == "transit",
		"Pause freezes the paid transit and all services despite held manual controls")
	var resumed := Flight.new()
	if not _expect(Session.save_state(flight.snapshot(), TICKET_PATH) == OK and resumed.restore(Session.load_state(TICKET_PATH)),
		"Write and cold-load the already-paid, paused jump"):
		return
	var read := resumed.jump_progress_status()
	_expect(resumed.time_paused and read.phase == "transit" and resumed.jump_target == destination
		and resumed.ship.jump_fuel == start_fuel - fare and not resumed.cancel_jump(),
		"A reloaded transit is still paused, already paid and cannot charge or cancel a second time")
	var paused_save := resumed.snapshot()
	for invalid in [["remaining", -1.0], ["duration", travel + 1], ["fare", fare + 1]]:
		var damaged := paused_save.duplicate(true)
		damaged.jump_transit[invalid[0]] = invalid[1]
		_expect(not resumed.restore(damaged) and resumed.snapshot() == paused_save,
			"Reject a mismatched %s in the paid record without changing the live flight" % invalid[0])
	_tick(resumed, 60.0)
	_expect(resumed.snapshot() == paused_save, "An explicit pause survives loading the escrow record")
	if not _expect(resumed.toggle_time_pause() and _advance(resumed,
		func() -> bool: return resumed.system_id == destination, 1.0, true),
		"Resuming paid transit physically arrives even if the pilot holds manual controls"):
		return
	var transit_elapsed := resumed.orbit_time - committed_time
	var arrival := int(Catalog.system(destination).arrival_target)
	_expect(resumed.ship.jump_fuel == start_fuel - fare and resumed.ship.fuel == reaction
		and resumed.jump_seconds_left == 0.0 and resumed.jump_target == -1,
		"Arriving after a cold restart performs no second fuel debit and clears the completed leg")
	_expect(absf(transit_elapsed - float(travel)) < 0.00001
		and resumed.clock_status().stamp == Calendar.stamp(resumed.orbit_time)
		and absf(resumed.elapsed - resumed.orbit_time) < 0.00001,
		"The short real transition advances the full quoted calendar time and the station simulation clock")
	_expect(resumed.target == arrival and resumed.position.is_equal_approx(resumed.target_gate(arrival) + Vector3.BACK * Flight.ARRIVAL_OFFSET)
		and resumed.velocity.is_zero_approx() and resumed._obstacle_at(resumed.position) < 0,
		"The paid jump appears at the actual destination ephemeris with no residual collision or source drift")
	_tick_until(control, resumed.orbit_time)
	var arrived_crew: Array = resumed.crew.snapshot().members
	var control_crew: Array = control.crew.snapshot().members
	_expect(resumed.credits == credits - wage and resumed.passenger_status().overdue
		and resumed.credits == control.credits and arrived_crew.size() == 1 and control_crew.size() == 1
		and _same_schedule(arrived_crew[0], control_crew[0], ["hired_at"])
		and _same_schedule(resumed.passengers.snapshot(), control.passengers.snapshot(), ["accepted_at", "deadline"]),
		"Crossed passenger expiry and payroll are applied once and match an ordinary world clock")
	_expect(resumed.freight.snapshot() == control.freight.snapshot() and resumed.market.snapshot() == control.market.snapshot(),
		"All due NPC freight and market stock agree with the independently stepped clock")
	var arrived := Flight.new()
	var arrival_path := "user://hyperspace-arrived.json"
	if _expect(Session.save_state(resumed.snapshot(), arrival_path) == OK and arrived.restore(Session.load_state(arrival_path)),
		"The completed generated arrival can itself be saved and loaded"):
		var snapshot := arrived.snapshot()
		_tick(arrived, 0.25)
		_expect(arrived.ship.jump_fuel == float(snapshot.ship.jump_fuel) and arrived.credits == int(snapshot.credits)
			and arrived.passenger_status().overdue and arrived.system_id == destination,
			"A later cold load does not replay any jump, passenger or payroll completion")


func _test_convoy_during_transit() -> void:
	var flight := Flight.new()
	var station := Catalog.HEATHER_SYSTEM
	var funded_foundation := flight.snapshot()
	funded_foundation.credits = 1000
	funded_foundation.expedition.projects[0] = {
		"phase": Expedition.COMPLETE, "sponsor_port": 0, "sponsor": 0,
		"scan_index": Expedition.SURVEY_TOTAL, "build_index": Expedition.BUILD_TOTAL,
	}
	var fronts := Fronts.new()
	if not _expect(fronts.commission(station, 0, 0.0) and flight.freight.activate_frontier(station, 0.0),
		"Prepare a commissioned frontier system through the campaign fixture"):
		return
	funded_foundation.factions = fronts.snapshot()
	funded_foundation.freight = flight.freight.snapshot()
	if not _expect(flight.restore(funded_foundation) and flight.service_action("tank") and flight.service_action("jump_refuel"),
		"The sponsored pilot fits and fuels the return-capable tank at the real port"):
		return
	_tick(flight, Fronts.FOUNDING_GRACE)
	var escort: Dictionary = {}
	for offer: Dictionary in flight.convoy_offers():
		if offer.kind == "escort":
			escort = offer
			break
	if not _expect(not escort.is_empty() and flight.convoy_action(station, escort.id)
		and Fixture.depart(flight) and _fly_clear(flight, station) and flight.start_jump()
		and _advance(flight, func() -> bool: return flight.system_id == station, 4.0),
		"Accept the real escort order and physically jump into the war zone"):
		return
	var balance := flight.credits
	if not _expect(flight.convoy_action() and _advance(flight,
		func() -> bool: return flight.convoy_status().phase == "escorted", 55.0)
		and flight.factions.convoy(station, escort.id).assistance == "escort" and flight.credits == balance,
		"Fly actual formation until the convoy is protected, while the reward still awaits delivery"):
		return
	var due := float(escort.deadline)
	var travel := flight.jump_travel_seconds(station, HOME)
	var nearest := int(flight.local_targets()[0])
	for site: int in flight.local_targets():
		if flight.position.distance_squared_to(flight.target_position(site)) < flight.position.distance_squared_to(flight.target_position(nearest)):
			nearest = site
	var outward := (flight.position - flight.target_position(nearest)).normalized()
	flight.yaw = atan2(-outward.x, -outward.z)
	flight.pitch = asin(clampf(outward.y, -1.0, 1.0))
	if not _expect(flight.plan_route(HOME) and _fly_clear(flight, HOME),
		"Clear the source system and plot a real return jump from the escorted convoy"):
		return
	flight.change_throttle(-flight.throttle)
	_tick_until(flight, due - minf(12.0, travel * 0.5))
	if not _expect(flight.orbit_time < due - Flight.JUMP_CHARGE and flight.orbit_time + travel > due
		and flight.convoy_status().phase == "escorted" and flight.start_jump(),
		"The scheduled delivery falls within paid transit, after the visible charge ends"):
		return
	if not _expect(_advance(flight, func() -> bool: return flight.jump_progress_status().phase == "transit", Flight.JUMP_CHARGE)
		and flight.credits == balance and flight.orbit_time < due,
		"Entering paid transit neither delivers the convoy early nor pays its escort"):
		return
	var paid_path := "user://hyperspace-convoy-paid.json"
	var resumed := Flight.new()
	if not _expect(Session.save_state(flight.snapshot(), paid_path) == OK and resumed.restore(Session.load_state(paid_path))
		and resumed.jump_progress_status().phase == "transit" and resumed.convoy_status().phase == "escorted",
		"Cold-load the committed jump while the escorted convoy is still en route"):
		return
	if not _expect(_advance(resumed, func() -> bool: return resumed.system_id == HOME, 1.0)
		and resumed.orbit_time > due and resumed.factions.convoy(station, escort.id).stage == "delivered"
		and resumed.convoy_status().phase == "succeeded" and resumed.credits == balance + int(escort.reward),
		"The convoy delivery and escort reward are already reconciled on the exact arrival frame"):
		return
	var arrived_path := "user://hyperspace-convoy-arrived.json"
	var arrived := Flight.new()
	if not _expect(Session.save_state(resumed.snapshot(), arrived_path) == OK and arrived.restore(Session.load_state(arrived_path)),
		"The arrival frame contains a complete and loadable paid escort result"):
		return
	_tick(arrived, 0.25)
	_expect(arrived.convoy_status().phase == "succeeded" and arrived.credits == balance + int(escort.reward),
		"Loading after arrival and stepping normally cannot pay the delivered escort again")


func _prepare_deadlines(flight: Flight) -> bool:
	var ticket: Dictionary = {}
	for offer: Dictionary in flight.passenger_board():
		if (Catalog.system_of_site(int(offer.destination)) == HOME
			and (ticket.is_empty() or float(offer.duration) > float(ticket.duration))):
			ticket = offer
	if not _expect(not ticket.is_empty() and flight.passenger_accept(int(ticket.destination)),
		"Board real local passengers from the normal port board"):
		return false
	var deadline := float(flight.passenger_status().deadline)
	_tick_until(flight, deadline - Crew.WAGE_PERIOD + 2.0)
	var engineer := int(flight.crew_candidates()[0].id)
	if not _expect(flight.crew_hire(engineer) and flight.crew_status().engineer
		and absf(float(flight.crew_status().next_due) - deadline - 2.0) < 0.00001,
		"Hire a paid engineer whose first wage falls two game seconds after the passenger cutoff"):
		return false
	_tick_until(flight, deadline - 27.0)
	return flight.ship.jump_fuel >= flight.jump_tariff(HOME, flight.jump_target)


func _farthest_known(flight: Flight) -> int:
	var destination := -1
	var best := 0.0
	for system in range(Catalog.AUTHORED_SYSTEM_COUNT, Catalog.SYSTEM_COUNT):
		var distance := Catalog.jump_distance(HOME, system)
		if flight.system_known(system) and distance > best:
			best = distance
			destination = system
	return destination


func _fly_clear(flight: Flight, destination: int) -> bool:
	flight.change_throttle(0.16)
	return _advance(flight, func() -> bool: return flight.jump_status(destination).ok, 9.0)


func _advance(flight: Flight, reached: Callable, seconds: float, manual := false) -> bool:
	for _frame in range(ceili(seconds / STEP)):
		if reached.call():
			return true
		flight.update(STEP, Vector2(0.5, 0.0) if manual else Vector2.ZERO, 0.0, false, manual)
	return reached.call()


func _tick(flight: Flight, seconds: float) -> void:
	flight.update(seconds, Vector2.ZERO, 0.0, false, false)


func _tick_until(flight: Flight, epoch: float) -> void:
	while flight.orbit_time < epoch - 0.000000001:
		_tick(flight, minf(7.0, epoch - flight.orbit_time))


func _same_schedule(arrived: Dictionary, reference: Dictionary, clock_fields: Array[String]) -> bool:
	for field in clock_fields:
		if absf(float(arrived[field]) - float(reference[field])) >= 0.000000001:
			return false
		arrived.erase(field)
		reference.erase(field)
	return arrived == reference


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
