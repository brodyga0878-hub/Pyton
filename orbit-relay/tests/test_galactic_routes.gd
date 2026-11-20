extends SceneTree

const Fixture = preload("res://tests/flight_fixture.gd")

const Flight := preload("res://scripts/flight_sim.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Route := preload("res://scripts/galactic_route.gd")
const Expedition := preload("res://scripts/expedition.gd")
const FactionFronts := preload("res://scripts/faction_fronts.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const OrbitRelay := preload("res://main.tscn")
const HOME := Catalog.HOME_SYSTEM
const VELAR := Catalog.VELAR_SYSTEM
const FRINGE := Catalog.FRINGE_SYSTEM
const HEATHER := Catalog.HEATHER_SYSTEM
const LIMIT := Catalog.LIMIT_SYSTEM
const STEP := 1.0 / 60.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_planner()
	_test_fuel_preview_and_overrides()
	_test_hops_and_refuel()
	_test_save_guards()
	await _test_chart()
	print("Galactic routes integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_planner() -> void:
	var woven_known: Array[int] = [LIMIT, FRINGE, HOME, HEATHER, VELAR]
	var full := Route.plan(HOME, LIMIT, woven_known, 66.0)
	_expect(full.available and full.path == [HOME, LIMIT] and full.fuel == 66 and full.legs.size() == 1,
		"When the direct and relay paths both cost 66, fewer jumps choose the direct route")
	var intermediate := Route.plan(HOME, LIMIT, woven_known, 50.0)
	_expect(intermediate.available and intermediate.path == [HOME, HEATHER, LIMIT] and intermediate.fuel == 66
		and intermediate.next == HEATHER and intermediate.goal == LIMIT,
		"The same goal uses the lowest-fuel relay when the tank cannot fit the direct tariff")
	var small := Route.plan(HOME, LIMIT, woven_known, 26.0)
	var expected_distance := Catalog.jump_distance(HOME, VELAR) + Catalog.jump_distance(VELAR, HEATHER) \
		+ Catalog.jump_distance(HEATHER, LIMIT)
	if _expect(small.available and small.path == [HOME, VELAR, HEATHER, LIMIT] and small.fuel == 69
		and small.legs.size() == 3 and is_equal_approx(small.distance, expected_distance),
		"A small tank uses three real legs, summing their distances and fares"):
		_expect(small.legs[0].origin == HOME and small.legs[0].destination == VELAR and small.legs[0].fuel == 26
			and small.legs[1].fuel == 25 and small.legs[2].fuel == 18,
			"The itinerary gives the cost and both ends of each real leg")
	_expect(not Route.plan(HOME, LIMIT, woven_known, 25.99).available
		and not Route.plan(HOME, HOME, woven_known, 150.0).available,
		"No initial leg below its exact cost and no self-route can be accepted")
	var frontier_unknown: Array[int] = [HOME, VELAR, FRINGE]
	var missing_relay: Array[int] = [HOME, LIMIT]
	_expect(not Route.plan(HOME, LIMIT, frontier_unknown, 150.0).available
		and not Route.plan(HOME, LIMIT, missing_relay, 50.0).available,
		"An undiscovered destination or intermediate relay cannot provide a route")
	var fuel_limited := Route.plan(HOME, LIMIT, woven_known, 100.0, 34.0)
	_expect(fuel_limited.available and fuel_limited.path == [HOME, VELAR, LIMIT] and fuel_limited.fuel == 68
		and not Route.plan(HOME, LIMIT, woven_known, 100.0, 25.99).available,
		"Current fuel constrains the first departure while each later leg can use a full tank")
	var low_id: Array[int] = [HOME, VELAR, LIMIT]
	var high_id: Array[int] = [HOME, HEATHER, LIMIT]
	_expect(Route._better({"path": low_id, "fuel": 66}, {"path": high_id, "fuel": 66})
		and not Route._better({"path": high_id, "fuel": 66}, {"path": low_id, "fuel": 66}),
		"Equal-cost equal-length labels resolve deterministically by their system ID sequence")
	var reversed_known: Array[int] = [HOME, VELAR, HEATHER, FRINGE, LIMIT]
	_expect(Route.plan(HOME, LIMIT, reversed_known, 50.0) == intermediate,
		"Discovery order does not reorder the same planned itinerary")
	var repeated: Array[int] = [HOME, VELAR, HOME, LIMIT]
	_expect(not Route.valid_path(repeated, woven_known, 100.0) and not Route.describe(repeated).available
		and not Route.valid_path(low_id, missing_relay, 100.0) and not Route.valid_path(low_id, woven_known, 41.99),
		"Restorable itineraries must be simple, known and within capacity on every leg")


func _test_fuel_preview_and_overrides() -> void:
	var flight := _known_flight()
	var fuel := flight.ship.jump_fuel
	var unplanned := flight.snapshot()
	var preview := flight.route_preview(LIMIT)
	_expect(preview.available and preview.path == [HOME, VELAR, LIMIT] and flight.snapshot() == unplanned,
		"The newly reachable relay preview neither arms a jump nor mutates the save")
	if not _expect(flight.plan_route(LIMIT) and flight.jump_target == VELAR
		and flight.planned_route().path == preview.path and flight.ship.jump_fuel == fuel and not flight.start_jump(),
		"Planning commits the next target while the ship remains docked and its fuel is unchanged"):
		return
	var active := flight.snapshot()
	_expect(not flight.plan_route(HOME) and not flight.plan_route(Catalog.SYSTEM_COUNT) and flight.snapshot() == active,
		"Invalid goals leave the existing valid route and fuel intact")
	_expect(flight.service_action("jump_refuel") and flight.ship.jump_fuel == flight.ship.jump_capacity()
		and flight.planned_route().path == [HOME, VELAR, LIMIT] and flight.route_preview(LIMIT).path == [HOME, LIMIT],
		"Topping up allows a new direct preview but does not silently replace the activated route")
	_expect(flight.plan_jump(FRINGE) and flight.planned_route().path == [HOME, FRINGE]
		and flight.snapshot().jump_route.is_empty(),
		"Explicit direct planning used by mission workflows replaces the stored chain")
	_expect(flight.cancel_route() and not flight.cancel_route() and flight.jump_target == -1
		and not flight.planned_route().available and flight.ship.jump_fuel == flight.ship.jump_capacity(),
		"Cancel removes the route idempotently and has no fuel cost")
	flight.ship.jump_fuel = 5.0
	_expect(flight.route_preview(LIMIT).path == [HOME, LIMIT] and flight.plan_route(LIMIT)
		and flight.jump_target == LIMIT and not flight.jump_status(LIMIT).ok,
		"If no departure is affordable, the map still plans the capacity-valid route for after refuelling")


func _test_hops_and_refuel() -> void:
	var flight := _known_flight()
	if not _expect(flight.plan_route(LIMIT) and _depart(flight), "Launch and clear the source dock with the real relay selected"):
		return
	var cost := Catalog.jump_cost(HOME, VELAR)
	var earliest := flight.ship.jump_fuel
	if not _expect(flight.start_jump() and not flight.cancel_route() and not flight.plan_jump(FRINGE)
		and not flight.plan_route(HEATHER), "An active charge cannot silently change goals or cancel its itinerary"):
		return
	_tick(flight, 1.0)
	_expect(flight.system_id == HOME and flight.ship.jump_fuel == earliest and flight.planned_route().path == [HOME, VELAR, LIMIT],
		"Charging the first leg does not debit fuel or consume any destination before commit")
	var saved := _json(flight.snapshot())
	var resumed := Flight.new()
	if not _expect(resumed.restore(saved) and resumed.jump_seconds_left == 0.0 and resumed.ship.jump_fuel == earliest
		and resumed.planned_route().path == [HOME, VELAR, LIMIT] and saved.jump_route == [float(VELAR), float(LIMIT)],
		"A cold restore during charging keeps both frozen legs and clears only the transient countdown"):
		return
	flight.cancel_jump()
	_expect(flight.ship.jump_fuel == earliest and flight.planned_route().path == [HOME, VELAR, LIMIT],
		"Aborting a jump leaves both its fare and the route intact")
	if not _expect(resumed.start_jump(), "A restored route can be confirmed explicitly again"):
		return
	_tick(resumed, 3.0)
	if not _expect(resumed.system_id == VELAR and is_equal_approx(resumed.ship.jump_fuel, earliest - cost)
		and resumed.jump_target == LIMIT and resumed.jump_seconds_left == 0.0 and resumed.planned_route().path == [VELAR, LIMIT],
		"Arrival charges only the first fare and selects the next hop without starting it"):
		return
	var before_delay := resumed.ship.jump_fuel
	_tick(resumed, 5.0)
	_expect(resumed.system_id == VELAR and resumed.ship.jump_fuel == before_delay and not resumed.start_jump(),
		"The second leg waits for both a deliberate command and sufficient new fuel")
	var arrival_port: int = Catalog.system(VELAR).arrival_port
	if not _expect(_dock_at(resumed, arrival_port) and resumed.planned_route().path == [VELAR, LIMIT],
		"The explicit route survives actual automatic docking at its relay port"):
		return
	var fee: int = resumed.service_offer("jump_refuel").cost
	var prior_balance := resumed.credits
	if not _expect(fee > 0 and resumed.service_action("jump_refuel") and resumed.credits == prior_balance - fee
		and resumed.ship.jump_fuel == resumed.ship.jump_capacity() and not resumed.start_jump(),
		"The relay's normal services refill the tank and enforce takeoff before continuing"):
		return
	var parked_copy := Flight.new()
	if not _expect(parked_copy.restore(_json(resumed.snapshot())) and parked_copy.docked == arrival_port
		and parked_copy.planned_route().path == [VELAR, LIMIT] and _depart(parked_copy),
		"A refuel stop saves and restores the remaining route with no replayed first jump"):
		return
	var next_fuel := parked_copy.ship.jump_fuel
	if not _expect(parked_copy.start_jump(), "Confirm the second jump after taking off and clearing the relay"):
		return
	_tick(parked_copy, 3.0)
	_expect(parked_copy.system_id == LIMIT and parked_copy.jump_target == -1 and not parked_copy.planned_route().available
		and is_equal_approx(parked_copy.ship.jump_fuel, next_fuel - Catalog.jump_cost(VELAR, LIMIT)),
		"The last jump debits its own tariff once and clears the completed route")


func _test_save_guards() -> void:
	var flight := _known_flight()
	if not _expect(flight.plan_route(LIMIT), "Prepare a valid saved route for corruption checks"):
		return
	var live := flight.snapshot()
	var encoded := _json(live)
	for path: Variant in [[FRINGE, LIMIT], [VELAR, VELAR, LIMIT], [VELAR, HOME, LIMIT], [VELAR, 999],
		[VELAR, "4"], {"next": VELAR}, null]:
		var malformed := encoded.duplicate(true)
		malformed.jump_route = path
		_expect(not flight.restore(malformed) and flight.snapshot() == live,
			"Malformed, duplicate, cyclic or misaligned routes leave a running flight untouched")
	var missing_next := encoded.duplicate(true)
	missing_next.jump_target = -1
	_expect(not flight.restore(missing_next) and flight.snapshot() == live,
		"A remaining route cannot load without its matching next jump")
	var undiscovered := Flight.new().snapshot()
	undiscovered.jump_target = VELAR
	undiscovered.jump_route = [VELAR, LIMIT]
	_expect(not flight.restore(undiscovered) and flight.snapshot() == live,
		"A saved route cannot reveal or use an undiscovered frontier")
	var older := encoded.duplicate(true)
	older.schema = 16
	Fixture.remove_ground_ports_from_legacy(older)
	older.ship.erase("mining_laser")
	older.ship.erase("fragment_collector")
	older.ship.erase("hydrogen_scoop")
	older.ship.erase("fuel_pump")
	older.ship.erase("pump_mode")
	older.ship.erase("range_drive")
	older.ship.erase("drive_kind")
	older.ship.erase("hull_id")
	older.ship.fuel = older.ship.jump_fuel
	older.ship.erase("jump_fuel")
	older.mining.cargo.erase("hydrogen")
	older.mining.reserves.resize(Catalog.PRE_GAS_DESTINATION_COUNT)
	for stocks: Dictionary in older.market.values():
		stocks.erase("hydrogen")
	older.jump_target = LIMIT
	older.erase("jump_route")
	older.freight.erase("frontier_epochs")
	older.freight.ships = older.freight.ships.slice(0, 6)
	_expect(flight.restore(older) and flight.jump_target == LIMIT and flight.planned_route().path == [HOME, LIMIT]
		and flight.snapshot().jump_route.is_empty() and flight.route_preview(LIMIT).path == [HOME, VELAR, LIMIT],
		"A schema-16 direct destination survives even when a fresh preview would prefer a relay")


func _test_chart() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := OrbitRelay.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = _known_flight()
	game._update_display(0.0)
	await process_frame
	var chart: Node = game._galaxy
	var flight: Flight = game.flight
	_tap(viewport, game._hud._actions["galaxy"], "Open the playable galactic chart by touch")
	await process_frame
	_tap(viewport, chart._system_buttons[LIMIT], "Preview the distant destination by touch")
	await process_frame
	_expect(flight.jump_target == -1 and Catalog.system(VELAR).name in chart._itinerary.text,
		"The chart shows the affordable relay before the player commits the plan")
	_tap(viewport, chart._plan_button, "Plan the relay route through the actual chart")
	await process_frame
	_expect(flight.planned_route().path == [HOME, VELAR, LIMIT] and chart._jump_button.disabled
		and SessionIO.load_state().get("jump_route") == [float(VELAR), float(LIMIT)],
		"The committed multi-stage route is saved immediately and charging is still locked in port")
	_tap(viewport, chart._close_button, "Return to piloting before attempting the first jump")
	await process_frame
	if _expect(_depart(flight), "Clear the port while retaining the chosen itinerary"):
		game._update_display(0.0)
		await process_frame
		_tap(viewport, game._hud._actions["galaxy"], "Reopen the chart to confirm the next leg")
		await process_frame
		_tap(viewport, chart._jump_button, "Start just the upcoming jump from the real chart")
		await process_frame
		_expect(not chart.is_open() and flight.jump_seconds_left > 0.0,
			"Touch starts a real countdown and closes the chart")
		_tick(flight, 3.0)
		game._update_display(0.0)
		await process_frame
		_tap(viewport, game._hud._actions["galaxy"], "Show the remaining itinerary after arrival")
		await process_frame
		_expect(flight.system_id == VELAR and flight.jump_target == LIMIT and chart._jump_button.disabled,
			"The new next hop is shown but cannot start until the player obtains enough fuel")
		_tap(viewport, chart._cancel_route_button, "Cancel the remaining route by touch")
		await process_frame
		_expect(chart.is_open() and flight.jump_target == -1 and not flight.planned_route().available,
			"The cancellation button clears the itinerary without leaving the map")
	viewport.queue_free()
	await process_frame


func _known_flight() -> Flight:
	var flight := Flight.new()
	var saved := flight.snapshot()
	for index in range(2):
		saved.expedition.projects[index] = {"phase": Expedition.COMPLETE, "sponsor_port": 0, "sponsor": 0,
			"scan_index": Expedition.SURVEY_TOTAL, "build_index": Expedition.BUILD_TOTAL}
	var politics := FactionFronts.new()
	politics.commission(HEATHER, 0, 0.0)
	politics.commission(LIMIT, 0, 0.0)
	saved.factions = politics.snapshot()
	flight.freight.activate_frontier(HEATHER, 0.0)
	flight.freight.activate_frontier(LIMIT, 0.0)
	saved.freight = flight.freight.snapshot()
	saved.ship.jump_fuel = 34.0
	saved.credits = 1000
	_expect(flight.restore(saved), "Prepare an existing game with both frontier systems discovered and a partly filled tank")
	return flight


func _depart(flight: Flight) -> bool:
	if flight.docked < 0 or not Fixture.depart(flight):
		return false
	flight.change_throttle(0.18)
	for _frame in range(roundi(9.0 / STEP)):
		if flight.jump_status(flight.jump_target).ok:
			return true
		_tick(flight)
	return flight.jump_status(flight.jump_target).ok


func _dock_at(flight: Flight, port: int) -> bool:
	if not flight.select_target(port):
		return false
	flight.set_autopilot(true)
	for _frame in range(roundi(120.0 / STEP)):
		if not flight.autopilot:
			break
		_tick(flight)
	return flight.docked == port


func _tick(flight: Flight, delta := STEP) -> void:
	flight.update(delta, Vector2.ZERO, 0.0, false, false)


func _json(value: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value, "", true, true)) as Dictionary


func _tap(viewport: SubViewport, button: Button, description: String) -> void:
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, description):
		return
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 9
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		viewport.push_input(event, true)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
