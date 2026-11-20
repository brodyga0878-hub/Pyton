extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Orbit := preload("res://scripts/orbit_ephemeris.gd")
const Rig := preload("res://scripts/mining_rig.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const Economy := preload("res://scripts/port_economy.gd")
const Main := preload("res://main.tscn")
const HOME := Catalog.HOME_SYSTEM
const FIRST_GENERATED := Catalog.AUTHORED_SYSTEM_COUNT
const STEP := Fixture.STEP
const SAVE_PATH := "user://procedural-galaxy-test.json"

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog()
	_test_frontier_flight()
	_test_previous_save()
	await _test_scan_touch()
	print("Procedural galaxy integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_catalog() -> void:
	_expect(FIRST_GENERATED == 5 and Catalog.AUTHORED_DESTINATION_COUNT == 29
		and Catalog.PRE_BINARY_SYSTEM_COUNT == 23 and Catalog.PRE_BINARY_DESTINATION_COUNT == 83,
		"Procedural systems append stable IDs to the 5 authored systems and 29 sites")
	_expect(Catalog.star_for(HOME) == Catalog.STAR_ID and Catalog.gas_giant_for(HOME) == Catalog.GAS_GIANT_ID
		and Catalog.ports_for(Catalog.HEATHER_SYSTEM) == [Catalog.HEATHER_PORT]
		and Catalog.ports_for(Catalog.LIMIT_SYSTEM) == [Catalog.LIMIT_PORT],
		"Saved authored targets, established ports and construction sites retain their IDs")
	for origin in range(FIRST_GENERATED):
		for destination in range(FIRST_GENERATED):
			_expect(Catalog.jump_cost(origin, destination) == Catalog.JUMP_COSTS[origin][destination],
				"Existing route tariff %d → %d is stable" % [origin, destination])
	var positions: Array[Vector3] = []
	for system in range(FIRST_GENERATED, Catalog.PRE_BINARY_SYSTEM_COUNT):
		var row := Catalog.system(system)
		var position := Catalog.system_position3(system)
		var sector := Catalog.sector_coordinates(system)
		var star := Catalog.star_for(system)
		var mines := Catalog.mines_for(system)
		var expected_star := Catalog.AUTHORED_DESTINATION_COUNT + (system - FIRST_GENERATED) * 3
		_expect(Catalog.is_generated_system(system) and not row.is_empty()
			and position.is_finite() and not positions.has(position)
			and Catalog.system_position3(system) == position and Catalog.sector_coordinates(system) == sector,
			"Generated system %d has reproducible 3D coordinates in its sector" % system)
		positions.append(position)
		_expect(star == expected_star and mines == [star + 1, star + 2]
			and Catalog.targets_for(system).size() == 3 and Catalog.ports_for(system).is_empty()
			and Catalog.system_of_site(star) == system and Catalog.site(star).kind == "star",
			"Generated system %d owns one primary and two mineable sites, with no port" % system)
		for site: int in mines:
			var period := Orbit.period(site)
			var start := Orbit.sample(site, 0.0)
			var quarter := Orbit.sample(site, period * 0.25)
			_expect(Catalog.system_of_site(site) == system and Catalog.is_mine_site(site)
				and period > 0.0 and start.position == Catalog.site(site).center
				and quarter.position.distance_to(start.position) > 100.0
				and Orbit.sample(site, period).position.distance_to(start.position) < 0.02,
				"Generated body %d follows a continuous local orbit around its own primary" % site)
		var tariff := Catalog.jump_cost(HOME, system)
		_expect(tariff == Catalog.jump_cost(system, HOME)
			and is_equal_approx(Catalog.jump_distance(HOME, system), Catalog.jump_distance(system, HOME)),
			"Generated connection %d has symmetric distance and fuel" % system)


func _test_frontier_flight() -> void:
	var flight := Flight.new()
	var expected: Array[int] = []
	for system in range(FIRST_GENERATED, Catalog.SYSTEM_COUNT):
		if Catalog.jump_distance(HOME, system) <= Catalog.GENERATED_SCAN_RANGE:
			expected.append(system)
	_expect(not flight.system_known(FIRST_GENERATED) and not flight.system_dossier(FIRST_GENERATED).known
		and not flight.route_preview(FIRST_GENERATED).available and not flight.plan_jump(FIRST_GENERATED)
		and not flight.body_dossier(Catalog.star_for(FIRST_GENERATED)).known,
		"Unseen systems cannot reveal local data or be targeted by a jump")
	var scan := flight.galaxy_scan_status()
	if not _expect(not expected.is_empty() and expected.size() < Catalog.SYSTEM_COUNT - FIRST_GENERATED
		and scan.allowed and scan.unseen_count == expected.size() and scan.range == Catalog.GENERATED_SCAN_RANGE
		and flight.scan_galaxy() and flight.status_event == "galaxy_scan",
		"The normal scanner discovers exactly the hidden systems in the current scan radius"):
		return
	var discovered: Array[int] = []
	for system in range(FIRST_GENERATED, Catalog.SYSTEM_COUNT):
		if flight.system_known(system):
			discovered.append(system)
	_expect(discovered == expected and not flight.scan_galaxy()
		and flight.galaxy_scan_status().unseen_count == 0,
		"Repeated scans from the same origin produce no repeated discoveries or remote reveals")
	var destination := expected[0]
	var star := Catalog.star_for(destination)
	var solid: int = Catalog.mines_for(destination)[0]
	var outbound := Catalog.jump_cost(HOME, destination)
	flight.ship.jump_fuel = float(outbound)
	if not _expect(outbound > 0 and flight.route_preview(destination).path == [HOME, destination]
		and flight.plan_route(destination) and not flight.start_jump() and Fixture.depart(flight)
		and _jump(flight, destination, 0),
		"The first discovered route uses real station departure and a charged interstellar jump"):
		return
	var dossier := flight.system_dossier(destination)
	_expect(flight.system_id == destination and flight.target == int(Catalog.system(destination).arrival_target)
		and flight.docked == -1 and flight.ship.jump_fuel == 0.0 and flight.local_ports().is_empty()
		and flight.local_targets().size() == 3 and dossier.known and dossier.ports.is_empty() and dossier.goods.is_empty(),
		"Unsettled arrival uses a physical target and has no fictitious markets or stations")
	_expect(flight.cartography.discovered(destination) and not flight.station_services_available()
		and not flight.body_dossier(solid).known,
		"Discovering coordinates leaves surface measurements locked until a local survey")
	if not _expect(_approach(flight, solid) and flight.landed_site == solid and flight.survey_action(solid),
		"Autopilot lands on a generated solid world and permits a real survey"):
		return
	var data := flight.body_dossier(solid).data as Dictionary
	var resource: String = Catalog.site(solid).resource
	var old_reserve := flight.mining.reserve_at(solid)
	_expect(data.resource == resource and data.reserve == old_reserve and data.period > 0.0
		and not flight.survey_action(solid), "The survey records its actual orbital period and mineral deposit once")
	if not _expect(flight.mine_action()
		and _advance(flight, func() -> bool: return flight.mining.phase == Rig.READY, 25.0)
		and flight.mine_action()
		and _advance(flight, func() -> bool: return flight.mining.phase == Rig.STOWED, 4.0),
		"The detachable drill deploys, extracts and transfers minerals at a generated site"):
		return
	_expect(flight.mining.cargo_amount(resource) == Rig.BATCH and flight.mining.reserve_at(solid) == old_reserve - Rig.BATCH,
		"Only the exact generated deposit is depleted when the rig returns")
	if not _expect(flight.dock_action() and not flight.landed and _approach(flight, star)
		and flight.scoop_status().ok and flight.scoop_action(),
		"After lift-off, the local primary supports real safe-band hydrogen collection"):
		return
	var return_cost := Catalog.jump_cost(destination, HOME)
	var needed_canisters := ceili(float(return_cost) / 10.0)
	if not _expect(_advance(flight, func() -> bool: return flight.mining.cargo_amount(Economy.HYDROGEN) >= needed_canisters, 30.0)
		and flight.scoop_action() and flight.fuel_transfer("jump") and flight.ship.jump_fuel >= return_cost,
		"Stellar hydrogen in the hold can replenish the empty jump drive for the trip back"):
		return
	var before := flight.snapshot()
	if not _expect(SessionIO.save_state(before, SAVE_PATH) == OK, "A real save can be written in the unsettled system"):
		return
	var cold := Flight.new()
	if not _expect(cold.restore(SessionIO.load_state(SAVE_PATH)) and cold.system_id == destination
		and cold.target == star and cold.body_dossier(solid).known and cold.system_dossier(destination).observations == [solid]
		and cold.mining.cargo_amount(resource) == Rig.BATCH and cold.mining.reserve_at(solid) == old_reserve - Rig.BATCH
		and cold.snapshot().cartography == before.cartography and is_equal_approx(cold.ship.jump_fuel, flight.ship.jump_fuel),
		"Cold restart preserves all discoveries, depleted reserves, cargo, orbit and usable return fuel"):
		return
	var usable_return_fuel := cold.ship.jump_fuel
	_expect(cold.plan_route(HOME) and _jump(cold, HOME, star)
		and is_equal_approx(cold.ship.jump_fuel, usable_return_fuel - return_cost) and _approach(cold, 0) and cold.docked == 0
		and cold.mining.cargo_amount(resource) == Rig.BATCH and cold.body_dossier(solid).known,
		"Generated minerals and measurements survive the powered return jump and normal home docking")


func _test_previous_save() -> void:
	var previous := Flight.new()
	if not _expect(previous.survey_action(0), "Prepare an authored observation at the starting berth"):
		return
	var old := previous.snapshot()
	old.schema = 26
	old.mining.reserves.resize(Catalog.AUTHORED_DESTINATION_COUNT)
	old.cartography.erase("systems")
	var cold := Flight.new()
	_expect(cold.restore(old) and cold.docked == 0 and cold.body_dossier(0).known
		and cold.snapshot().cartography.scans == old.cartography.scans and cold.snapshot().cartography.systems.is_empty()
		and cold.snapshot().mining.reserves.size() == Catalog.DESTINATION_COUNT
		and cold.mining.reserve_at(Catalog.mines_for(FIRST_GENERATED)[0]) > 0
		and not cold.system_known(FIRST_GENERATED),
		"A 0.66 save keeps all prior observations and gets unseen generated reserves without retroactive discoveries")
	var hidden_site: int = Catalog.mines_for(FIRST_GENERATED)[0]
	var forged := cold.snapshot()
	forged.cartography.scans.append({"site": hidden_site, "epoch": cold.orbit_time})
	_expect(not Flight.new().restore(forged), "A saved generated measurement requires a matching system discovery")
	forged = cold.snapshot()
	forged.cartography.systems = [{"system": FIRST_GENERATED, "epoch": cold.orbit_time + 1.0}]
	_expect(not Flight.new().restore(forged), "A future discovery cannot be loaded")


func _test_scan_touch() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := Main.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = Flight.new()
	game._update_display(0.0)
	await process_frame
	var flight: Flight = game.flight
	var chart: Node = game._galaxy
	_tap(viewport, game._hud._actions["galaxy"], "Open the actual galactic chart with ordinary touch")
	await process_frame
	var uncharted_button: Button = chart._system_buttons[FIRST_GENERATED]
	_expect(chart.is_open() and not uncharted_button.is_visible_in_tree() and uncharted_button.text.is_empty(),
		"The chart does not list undiscovered systems")
	var count := int(flight.galaxy_scan_status().unseen_count)
	_tap(viewport, chart._scan_button, "Use the real galactic scanner button by touch")
	await process_frame
	var stored := SessionIO.load_state()
	_expect(chart.is_open() and chart._scan_button.disabled and count > 0 and uncharted_button.is_visible_in_tree()
		and flight.system_known(FIRST_GENERATED) and int(chart._last_scan_count) == count
		and stored.get("cartography", {}).get("systems", []).size() == count,
		"New galactic coordinates are saved immediately, and the player remains on the map with the result")
	viewport.queue_free()
	await process_frame


func _tap(viewport: SubViewport, button: Button, description: String) -> void:
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled
		and button.get_global_rect().size.y >= 44.0, description):
		return
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 19
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		viewport.push_input(event, true)


func _approach(flight: Flight, site: int) -> bool:
	if not flight.select_target(site):
		return false
	flight.set_autopilot(true)
	return _advance(flight, func() -> bool: return not flight.autopilot, 160.0) and flight.target == site


func _jump(flight: Flight, destination: int, nearest_site: int) -> bool:
	var outward := (flight.position - flight.target_position(nearest_site)).normalized()
	flight.yaw = atan2(-outward.x, -outward.z)
	flight.pitch = asin(clampf(outward.y, -1.0, 1.0))
	flight.change_throttle(0.18)
	return _advance(flight, func() -> bool: return flight.jump_status(destination).ok, 25.0) \
		and flight.start_jump() \
		and _advance(flight, func() -> bool: return flight.system_id == destination, 4.0)


func _advance(flight: Flight, reached: Callable, seconds: float) -> bool:
	for _frame in range(ceili(seconds / STEP)):
		if reached.call():
			return true
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	return reached.call()


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
