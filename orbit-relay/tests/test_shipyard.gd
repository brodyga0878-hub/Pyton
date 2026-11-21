extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Customs := preload("res://scripts/customs.gd")
const ShipSystems := preload("res://scripts/ship_systems.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const Main := preload("res://main.tscn")
const COURIER := ShipSystems.STARTER_HULL
const FREIGHTER := ShipSystems.FREIGHTER_HULL
const VELAR_PORT := 10
const OPEN_SPACE := Vector3(-7500.0, 3200.0, 4200.0)
const STEP := Fixture.STEP

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_licenses_and_quotes()
	_test_rotating_stock()
	_test_featured_hulls()
	_test_upgrade_and_travel()
	_test_flight_characteristics()
	_test_previous_schema()
	await _test_yard_touch()
	print("Shipyard integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_licenses_and_quotes() -> void:
	for port: int in [0, 10, 16, 1, 3, 11, 17]:
		var dock := _at_port(port)
		if not _expect(dock != null, "Prepare a physically docked flight for port %d" % port):
			continue
		dock.credits = 5000
		var licensed := port in [0, 10, 16]
		_expect(dock.shipyard_available() == licensed and dock.shipyard_offers().size() == (2 if licensed else 0)
			and dock.shipyard_offer(FREIGHTER).available == licensed,
			"Only licensed dock %d can offer a payable hull exchange" % port)
		if not licensed:
			var saved := dock.snapshot()
			_expect(not dock.shipyard_swap(FREIGHTER) and dock.snapshot() == saved,
				"An unlicensed berth cannot debit money or install a hull")
	var flight := Flight.new()
	_expect(flight.ship.hull_id == COURIER and flight.ship.crew_required() == 0
		and flight.ship.cargo_capacity() == 24 and flight.ship.cargo_capacity_for(FREIGHTER) == 44,
		"New commanders keep the light starter and see the heavy hull's larger base cargo capacity")
	var quote := flight.shipyard_offer(FREIGHTER)
	if not _expect(not quote.is_empty() and int(quote.net_cost) > 0 and not quote.available
		and int(quote.net_cost) == int(quote.price) - int(quote.trade_in)
		and not flight.shipyard_swap(FREIGHTER) and not flight.shipyard_swap("invalid"),
		"Trading in the existing hull produces one net quote and cannot accept insufficient funds"):
		return
	flight.ship.apply_damage(31.0)
	_expect(int(flight.shipyard_offer(FREIGHTER).trade_in) < int(quote.trade_in)
		and int(flight.shipyard_offer(FREIGHTER).net_cost) > int(quote.net_cost),
		"A damaged hull depreciates instead of funding a cost-free repair together with the purchase")

	flight = Flight.new()
	flight.credits = 5000
	var original := flight.credits
	for _iteration in range(2):
		var outgoing_quote := flight.shipyard_offer(FREIGHTER)
		if not _expect(flight.shipyard_swap(FREIGHTER) and int(outgoing_quote.net_cost) > 0,
			"Buying the freighter consumes the full positive net price"):
			return
		var return_quote := flight.shipyard_offer(COURIER)
		var before_return := flight.credits
		if not _expect(int(return_quote.net_cost) < 0 and flight.shipyard_swap(COURIER)
			and flight.credits == before_return - int(return_quote.net_cost),
			"A trade down credits exactly the negative net quote"):
			return
	_expect(flight.credits < original and flight.ship.hull_id == COURIER,
		"Repeated round trips impose a loss rather than minting credits")


func _test_rotating_stock() -> void:
	var flight := Flight.new()
	flight.credits = 7000
	var survey := ShipSystems.SURVEY_HULL
	var tug := ShipSystems.UTILITY_HULL
	_expect(ShipSystems.hull_ids().size() == 6 and not flight.shipyard_swap(survey)
		and not flight.shipyard_swap(tug) and flight.credits == 7000,
		"The wider hull catalogue does not let a pilot buy what this shift has not listed")
	flight.update(Flight.SHIPYARD_STOCK_SECONDS * 2.0, Vector2.ZERO, 0.0, false, false)
	var quote := flight.shipyard_offer(survey)
	_expect(quote.available and flight.shipyard_offers()[1].id == survey
		and flight.shipyard_restock_time() == Flight.SHIPYARD_STOCK_SECONDS * 3.0,
		"The next shipyard shift changes the actual purchase offer and announces the next refresh")
	_expect(flight.mining.insert_cargo("ore", 19) and not flight.shipyard_swap(survey) and flight.credits == 7000,
		"The smaller reconnaissance hull respects the actual fit of the original hold")
	_expect(flight.mining.remove_cargo("ore", 2) and flight.shipyard_swap(survey)
		and flight.mining.cargo_capacity == 18 and flight.mining.cargo_amount("ore") == 17
		and flight.credits == 7000 - int(quote.net_cost), "Exchange installs the offered smaller hull and preserves the cargo")
	var scout_roll := flight.ship.roll_rate(0)
	var scout_side := flight.ship.thrust_acceleration(Vector3.RIGHT, 0).x
	var restored := Flight.new()
	_expect(restored.restore(JSON.parse_string(JSON.stringify(flight.snapshot()))) and restored.ship.hull_id == survey
		and restored.shipyard_offers()[1].id == survey, "The purchased hull and shift remain exact after cold load")
	restored.update(Flight.SHIPYARD_STOCK_SECONDS * 2.0, Vector2.ZERO, 0.0, false, false)
	_expect(restored.shipyard_offers()[1].id == tug and restored.shipyard_swap(tug) and restored.ship.crew_required() == 1
		and restored.mining.cargo_capacity == 34 and restored.ship.roll_rate(0) < scout_roll
		and restored.ship.thrust_acceleration(Vector3.RIGHT, 0).x > scout_side,
		"The working tug trades turn speed for stronger side thrust and a wider hold with a crew requirement")
	_expect(not restored.dock_action() and restored.docked == 0, "A tug without its required crew cannot depart")


func _test_featured_hulls() -> void:
	var survey := ShipSystems.SURVEY_HULL
	var tug := ShipSystems.UTILITY_HULL
	var interceptor := ShipSystems.INTERCEPTOR_HULL
	var hauler := ShipSystems.HAULER_HULL
	var shift := Flight.SHIPYARD_STOCK_SECONDS
	var initial := {0: [FREIGHTER, FREIGHTER, survey, survey, tug],
		10: [FREIGHTER, survey, tug, FREIGHTER, survey],
		16: [FREIGHTER, survey, FREIGHTER, tug, tug]}
	for port: int in initial:
		var yard := _at_port(port)
		for expected: String in initial[port]:
			var offers := yard.shipyard_offers()
			_expect(offers.size() == 2 and offers[0].id == COURIER and offers[1].id == expected,
				"The first five shifts at yard %d retain the previous selection" % port)
			yard.update(shift, Vector2.ZERO, 0.0, false, false)
		_expect(yard.shipyard_offers()[1].id == (hauler if port == 16 else interceptor),
			"Advanced stock follows this port's role while keeping two active cards")
	var pilot := Flight.new()
	pilot.credits = 16000
	pilot.update(5.0 * shift, Vector2.ZERO, 0.0, false, false)
	var listed := pilot.shipyard_offer(interceptor)
	_expect(listed.available and int(listed.crew_required) == 0 and not pilot.shipyard_offer(hauler).available,
		"The interceptor is physically stocked while the early hauler request is refused")
	var opening_balance := pilot.credits
	if not _expect(pilot.shipyard_swap(interceptor) and pilot.ship.hull_id == interceptor
		and pilot.mining.cargo_capacity == 12 and pilot.credits == opening_balance - int(listed.net_cost),
		"Install the listed interceptor through the real yard quote"):
		return
	var solo := Flight.new()
	var checkpoint := pilot.snapshot()
	_expect(solo.restore(JSON.parse_string(JSON.stringify(checkpoint))) and Fixture.depart(solo)
		and solo.ship.hull_id == interceptor and solo.ship.crew_required() == 0,
		"The new interceptor survives cold load and actually departs with its pilot alone")
	checkpoint.schema = 51
	_expect(not Flight.new().restore(checkpoint), "A 0.99 format cannot claim an interceptor that did not exist yet")
	var fast_roll := pilot.ship.roll_rate(0)
	var fast_forward := pilot.ship.thrust_acceleration(Vector3.FORWARD, 0).z
	pilot.update(3.0 * shift, Vector2.ZERO, 0.0, false, false)
	_expect(pilot.shipyard_swap(hauler) and pilot.ship.hull_id == hauler and pilot.mining.cargo_capacity == 58
		and pilot.ship.crew_required() == 2 and pilot.ship.roll_rate(0) < fast_roll and pilot.ship.thrust_acceleration(Vector3.FORWARD, 0).z < fast_forward,
		"The rotating yard delivers a heavier profile with different acceleration and expanded crew rules")
	_expect(not pilot.dock_action(), "Departing the long-haul ship requires actual onboard specialists")
	var crew := pilot.crew_candidates()
	_expect(pilot.crew_hire(int(crew[0].id)) and not pilot.dock_action() and pilot.crew_hire(int(crew[1].id))
		and pilot.service_action("cargo") and pilot.mining.insert_cargo("ore", 80) and Fixture.depart(pilot),
		"The working hauler departs with two paid specialists and all 80 expanded cargo units")
	var customs := Customs.new()
	var seized := customs.record(1, 10, "weapon_parts", 80, 25.0)
	_expect(seized.ok and Customs.new().restore(customs.snapshot(), 25.0)
		and not Customs.new().restore(customs.snapshot(), 25.0, false, true),
		"The larger single seizure is supported by current holds and rejected in the earlier save shape")


func _test_upgrade_and_travel() -> void:
	var flight := Flight.new()
	flight.credits = 6500
	if not _expect(flight.service_action("tank") and flight.service_action("eco")
		and flight.service_action("cargo") and flight.service_action("heat_shield")
		and flight.contract_action() and flight.passenger_accept(VELAR_PORT) and flight.mining.insert_cargo("ore", 34),
		"The current ship has bought upgrades, a loaded hold and two independent contracts before exchange"):
		return
	flight.ship.fuel = 83.0
	flight.ship.jump_fuel = 61.0
	flight.ship.apply_damage(24.0)
	var before_swap := flight.snapshot()
	var passenger := flight.passenger_status()
	var quote := flight.shipyard_offer(FREIGHTER)
	var before_credits := flight.credits
	if not _expect(quote.available and int(quote.cargo_capacity) == 60 and flight.shipyard_swap(FREIGHTER)
		and flight.credits == before_credits - int(quote.net_cost) and flight.ship.hull_id == FREIGHTER,
		"The upgraded freighter slot is installed at exactly the quoted post-trade cost"):
		return
	_expect(flight.ship.hull == 100.0 and flight.ship.fuel == 83.0 and flight.ship.jump_fuel == 61.0
		and flight.ship.tank_upgraded and flight.ship.eco_upgraded and flight.ship.cargo_upgraded and flight.ship.heat_shield
		and flight.ship.cargo_capacity() == 60 and flight.mining.cargo_capacity == 60,
		"The exchange refreshes body condition while keeping installed upgrades and both fuel stores")
	_expect(flight.mining.snapshot() == before_swap.mining and flight.passenger_status().seats == passenger.seats
		and flight.contract_stage == 1 and flight.contract_destination == int(before_swap.contract_destination),
		"Cargo and both passenger and freight obligations survive the hull exchange")
	_expect(flight.ship.crew_required() == 1 and not flight.departure_status().can_request
		and not flight.dock_action() and not flight.departure_status().active and flight.docked == 0,
		"A pilot alone cannot open a departure slot for the freighter")
	var hire := _role(flight.crew_candidates(), "engineer")
	if not _expect(not hire.is_empty() and flight.crew_hire(int(hire.id)) and flight.departure_status().can_request
		and flight.mining.insert_cargo("ore", 19) and flight.passenger_follow(),
		"A staffed freighter accepts 53 units of ore and can follow the interstellar passenger route"):
		return
	var path := "user://shipyard-voyage.json"
	var cold := Flight.new()
	if not _expect(SessionIO.save_state(flight.snapshot(), path) == OK and cold.restore(SessionIO.load_state(path))
		and cold.ship.hull_id == FREIGHTER and cold.mining.cargo_amount("ore") == 53 and cold.crew_status().engineer,
		"The actual save reader initializes freighter hold capacity before restoring a load too large for the courier"):
		return
	flight = cold
	if not _expect(Fixture.depart(flight) and not flight.shipyard_available() and _jump_to_velar(flight),
		"The saved staffed freighter exits through the station and makes the chosen Velar jump"):
		return
	if not _expect(flight.passenger_follow() and _dock_at(flight, VELAR_PORT) and flight.shipyard_available()
		and flight.ship.hull == 100.0 and flight.passenger_status().can_discharge,
		"The actual licensed Velar berth receives the passenger freighter safely"):
		return
	var crowded := flight.snapshot()
	var blocked := flight.shipyard_offer(COURIER)
	_expect(not blocked.available and int(blocked.cargo_capacity) == 40 and not flight.shipyard_swap(COURIER)
		and flight.snapshot() == crowded, "A smaller hull is rejected atomically until the loaded ore fits")
	if not _expect(flight.market_trade("ore", "sell", 13) and flight.mining.cargo_amount("ore") == 40,
		"The remote market can sell the cargo just above the courier payload limit"):
		return
	var back := flight.shipyard_offer(COURIER)
	var old_cash := flight.credits
	var stores := [flight.ship.fuel, flight.ship.jump_fuel]
	if not _expect(back.available and flight.shipyard_swap(COURIER) and flight.credits == old_cash - int(back.net_cost)
		and flight.ship.hull_id == COURIER and flight.mining.cargo_capacity == 40 and flight.mining.cargo_amount("ore") == 40,
		"Exactly forty units transfer to the upgraded courier with no truncation"):
		return
	_expect(flight.ship.fuel == stores[0] and flight.ship.jump_fuel == stores[1] and flight.crew_status().engineer
		and flight.passenger_status().can_discharge and flight.passenger_discharge() and int(flight.passenger_status().completed) == 1,
		"Both fuel reserves, the employed engineer and the payable terminal fare survive the downgrade")
	_expect(flight.contract_stage == 1 and flight.contract_destination == int(before_swap.contract_destination)
		and flight.ship.crew_required() == 0, "The original freight contract remains live and the starter needs no extra staff")


func _test_flight_characteristics() -> void:
	var courier := _flight_trials(COURIER)
	var freighter := _flight_trials(FREIGHTER)
	if not _expect(not courier.is_empty() and not freighter.is_empty(), "Prepare independent flight measurements in clear space"):
		return
	_expect(is_equal_approx(float(freighter.first_speed) / float(courier.first_speed), 0.76)
		and is_equal_approx(float(freighter.top_speed) / float(courier.top_speed), 0.8),
		"With the same thrust command the actual heavy craft accelerates more slowly and reaches a lower speed")
	_expect(is_equal_approx(float(freighter.fuel_spent) / float(courier.fuel_spent), 1.18),
		"Fuel burn at equal throttle follows the installed hull's consumption, not its camera or label")
	_expect(is_equal_approx(float(freighter.reserve_speed), Flight.RESERVE_SPEED)
		and is_equal_approx(float(courier.reserve_speed), Flight.RESERVE_SPEED),
		"Running out of reaction fuel leaves the common emergency speed available for both hulls")


func _test_previous_schema() -> void:
	var flight := Flight.new()
	flight.credits = 3000
	if not _expect(flight.service_action("cargo") and flight.mining.insert_cargo("hydrogen", 25)
		and flight.passenger_accept(1), "Prepare an expanded old hold with passenger and jump cargo"):
		return
	flight.ship.apply_damage(17.0)
	flight.ship.fuel = 31.0
	var previous := flight.snapshot()
	previous.schema = 24
	Fixture.remove_ground_ports_from_legacy(previous)
	previous.ship.erase("mining_laser")
	previous.ship.erase("fragment_collector")
	previous.ship.erase("hydrogen_scoop")
	previous.ship.erase("fuel_pump")
	previous.ship.erase("pump_mode")
	previous.ship.erase("range_drive")
	previous.ship.erase("drive_kind")
	previous.ship.erase("autopilot_fitted")
	previous.mining.reserves.resize(Catalog.AUTHORED_DESTINATION_COUNT)
	previous.ship.erase("hull_id")
	var cold := Flight.new()
	if not _expect(cold.restore(previous) and cold.ship.hull_id == COURIER and cold.ship.hull == 83.0
		and cold.ship.fuel == 31.0 and cold.mining.cargo_amount("hydrogen") == 25 and cold.passenger_status().active,
		"The previously published shape keeps all data and defaults to the original courier"):
		return
	var valid := cold.snapshot()
	var tampered := valid.duplicate(true)
	tampered.ship.hull_id = "unknown"
	_expect(not cold.restore(tampered) and cold.snapshot() == valid,
		"An unsupported hull ID cannot silently shrink the loaded hold or reset the commander")


func _test_yard_touch() -> void:
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
	flight.credits = 5500
	var price := int(flight.shipyard_offer(FREIGHTER).net_cost)
	game._update_display(0.0)
	await process_frame
	_tap(viewport, game._hud._actions.get("services"), "Open the ordinary station services through touch")
	await process_frame
	var services: Node = game._services
	_tap(viewport, services._yard_toggle, "Open the licensed shipyard through touch")
	await process_frame
	var exchange: Button
	for row: Dictionary in services._yard_rows:
		if row.id == FREIGHTER:
			exchange = row.exchange
			break
	_tap(viewport, exchange, "Choose the priced freighter exchange through its actual button")
	await process_frame
	var reopened := Flight.new()
	_expect(flight.ship.hull_id == FREIGHTER and flight.credits == 5500 - price
		and reopened.restore(SessionIO.load_state()) and reopened.ship.hull_id == FREIGHTER
		and reopened.credits == flight.credits, "The Main-bound purchase transfers credits and writes a resumable hull")
	_expect(is_instance_valid(exchange) and exchange.disabled,
		"The current hull's touch control cannot charge for a repeated installation")
	flight.update(Flight.SHIPYARD_STOCK_SECONDS * 5.0, Vector2.ZERO, 0.0, false, false)
	services.refresh()
	await process_frame
	var featured: Array[String] = []
	var fits := true
	for row: Dictionary in services._yard_rows:
		if row.panel.is_visible_in_tree():
			featured.append(row.id)
			fits = fits and viewport.get_visible_rect().grow(0.5).encloses(row.exchange.get_global_rect())
	_expect(featured == [COURIER, ShipSystems.INTERCEPTOR_HULL] and fits,
		"The expanded catalogue uses only the two current yard cards and both stay in the landscape viewport")
	viewport.queue_free()
	await process_frame


func _flight_trials(id: String) -> Dictionary:
	var flight := Flight.new()
	flight.credits = 5000
	if id != COURIER and not flight.shipyard_swap(id):
		return {}
	if not Fixture.launch(flight):
		return {}
	flight.position = OPEN_SPACE
	flight.velocity = Vector3.ZERO
	flight.yaw = 0.0
	var initial_fuel := flight.ship.fuel
	flight.change_throttle(1.0)
	_tick(flight, 0.5)
	var first_speed := flight.speed()
	_tick(flight, 8.0)
	var top_speed := flight.speed()
	var fuel_spent := initial_fuel - flight.ship.fuel
	flight.ship.fuel = 0.0
	flight.velocity = Vector3.ZERO
	_tick(flight, 4.0)
	return {"first_speed": first_speed, "top_speed": top_speed, "fuel_spent": fuel_spent, "reserve_speed": flight.speed()}


func _at_port(port: int) -> Flight:
	var flight := Flight.new()
	var state := flight.snapshot()
	var contact := flight.docking_position(port)
	state.position = [contact.x, contact.y, contact.z]
	state.system_id = Catalog.system_of_site(port)
	state.target = port
	state.docked = port
	return flight if flight.restore(state) else null


func _role(rows: Array, name: String) -> Dictionary:
	for row: Dictionary in rows:
		if row.role == name:
			return row
	return {}


func _jump_to_velar(flight: Flight) -> bool:
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


func _dock_at(flight: Flight, port: int) -> bool:
	if not flight.select_target(port):
		return false
	flight.set_autopilot(true)
	for _frame in range(85 * 60):
		if flight.docked == port:
			return true
		if not flight.autopilot:
			return false
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
