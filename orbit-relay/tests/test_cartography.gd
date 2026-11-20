extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Survey := preload("res://scripts/cartography.gd")
const Orbit := preload("res://scripts/orbit_ephemeris.gd")
const Dynamics := preload("res://scripts/orbital_dynamics.gd")
const Atmosphere := preload("res://scripts/atmosphere.gd")
const Expedition := preload("res://scripts/expedition.gd")
const Economy := preload("res://scripts/port_economy.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const Main := preload("res://main.tscn")
const HOME := Catalog.HOME_SYSTEM
const VELAR := Catalog.VELAR_SYSTEM
const HEATHER := Catalog.HEATHER_SYSTEM
const GIANT := Catalog.GAS_GIANT_ID
const TERRACE := Catalog.TERRACE_ID
const STAR := Catalog.STAR_ID
const ASTEROID := 2
const STEP := Fixture.STEP

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_scan_interlocks()
	_test_real_observations()
	_test_systems_and_trade()
	_test_previous_schema()
	await _test_scan_touch()
	print("Cartography integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_scan_interlocks() -> void:
	var flight := Flight.new()
	var nearby := flight.body_dossier(0)
	var unseen := flight.body_dossier(GIANT)
	_expect(not nearby.known and nearby.can_scan and nearby.data.is_empty(),
		"Even a known berth does not expose quantitative data before its first observation")
	_expect(unseen.in_system and not unseen.known and not unseen.can_scan and unseen.data.is_empty()
		and is_equal_approx(float(unseen.scan_limit), float(Catalog.site(GIANT).radius) + Survey.SCAN_CLEARANCE),
		"A charted gas body can be located without giving away its data or authorizing a scan from a distant berth")
	_expect(not flight.survey_action(-1) and not flight.survey_action(TERRACE) and not flight.survey_action(ASTEROID)
		and flight.snapshot().cartography.scans.is_empty(),
		"Invalid targets, a remote body and a different site while docked cannot create observations")
	_expect(flight.dock_action() and not flight.body_dossier(0).can_scan and not flight.survey_action(0),
		"An exit reservation locks the scanner while the ship is moving out of berth")
	if not _expect(flight.dock_action() and Fixture.launch(flight), "Cancel the reservation and seed an independent airborne interlock trial"):
		return
	var radius := float(Catalog.site(GIANT).radius)
	flight.position = flight.target_position(GIANT) + Vector3.BACK * (radius + 125.0)
	flight.velocity = flight.target_velocity(GIANT)
	_expect(flight.body_dossier(GIANT).can_scan and flight.plan_jump(VELAR) and flight.start_jump()
		and not flight.body_dossier(GIANT).can_scan and not flight.survey_action(GIANT),
		"The same physically observable gas body refuses a scan while the jump drive is charging")
	flight.cancel_jump()
	_expect(flight.body_dossier(GIANT).can_scan and not flight.body_dossier(GIANT).known,
		"Canceling the jump restores scan availability without recording anything")

	flight.position = flight.target_position(STAR) + Vector3.BACK * 310.0
	flight.velocity = flight.target_velocity(STAR)
	_expect(flight.survey_action(STAR) and _matches_physics(flight, STAR)
		and flight.body_dossier(STAR).data.period == 0.0 and float(flight.body_dossier(STAR).data.gravity) > 0.0,
		"A safe co-moving stellar observation reports stellar gravity and no orbit around itself")


func _test_real_observations() -> void:
	var flight := Flight.new()
	if not _expect(flight.select_target(GIANT) and Fixture.depart(flight) and _approach(flight, GIANT),
		"The ordinary route reaches the physical moving gas giant"):
		return
	var readiness := flight.body_dossier(GIANT)
	if not _expect(readiness.can_scan and not readiness.known and readiness.data.is_empty()
		and float(readiness.range) <= float(readiness.scan_limit), "A true approach gives permission and still hides unrecorded metrics"):
		return
	var co_moving := flight.velocity
	flight.velocity = flight.target_velocity(GIANT) + Vector3.UP * (Survey.SCAN_SPEED_LIMIT + 0.5)
	var unrecorded: Dictionary = flight.snapshot().cartography
	_expect(not flight.body_dossier(GIANT).can_scan and not flight.survey_action(GIANT)
		and flight.snapshot().cartography == unrecorded,
		"Excessive body-relative motion blocks a co-located scan and changes no records")
	flight.velocity = co_moving
	if not _expect(flight.survey_action(GIANT) and _matches_physics(flight, GIANT),
		"A stable gas approach records the actual radius, orbit, gravity and atmosphere"):
		return
	var record := flight.body_dossier(GIANT)
	var saved_at := flight.orbit_time
	_expect(record.known and not record.can_scan and float(record.recorded_at) == saved_at
		and float(record.data.atmosphere_height) > 0.0 and str(record.data.resource).is_empty(),
		"The gas observation stores its first game clock and carries no fictitious surface resource")
	_expect(not flight.survey_action(GIANT) and flight.body_dossier(GIANT).recorded_at == saved_at,
		"A repeated scan cannot duplicate or move the observation timestamp")
	if not _expect(_jump_from_body(flight, GIANT), "The scanned ship physically leaves the atmosphere and jumps to Velar"):
		return
	var remote := flight.body_dossier(GIANT)
	_expect(remote.known and not remote.in_system and not remote.can_scan
		and remote.range == -1.0 and remote.data == record.data and not flight.survey_action(GIANT),
		"Stored measurements remain available remotely without showing a fictitious live distance or scan option")
	if not _expect(_approach(flight, TERRACE) and flight.landed_site == TERRACE and flight.survey_action(TERRACE),
		"The native landing program reaches a solid world and records it from stable contact"):
		return
	var planet := flight.body_dossier(TERRACE)
	_expect(_matches_physics(flight, TERRACE) and planet.data.resource == Catalog.site(TERRACE).resource
		and int(planet.data.reserve) == flight.mining.reserve_at(TERRACE),
		"The observed rocky world reveals the actual atmosphere and available mineral reserve")
	_expect(flight.system_dossier(HOME).observations == [GIANT]
		and flight.system_dossier(VELAR).observations == [TERRACE]
		and int(flight.system_dossier(VELAR).scan_count) == 1,
		"Both system reports group just the observations in their own sector")
	var state := flight.snapshot()
	var sites: Array = state.cartography.scans.map(func(entry: Dictionary) -> int: return int(entry.site))
	_expect(sites == [TERRACE, GIANT], "Observations are serialized in a unique canonical site order")
	var path := "user://cartography-voyage.json"
	var cold := Flight.new()
	if not _expect(SessionIO.save_state(state, path) == OK and cold.restore(SessionIO.load_state(path))
		and cold.body_dossier(TERRACE).known and cold.body_dossier(GIANT).known
		and is_equal_approx(float(cold.body_dossier(GIANT).recorded_at), saved_at),
		"A real JSON restart retains observations on both sides of the jump"):
		return
	var retained := cold.snapshot()
	var invalid := retained.duplicate(true)
	invalid.cartography.scans.append(invalid.cartography.scans[0].duplicate())
	_expect(not cold.restore(invalid) and cold.snapshot() == retained,
		"Duplicating a survey record is rejected atomically")
	invalid = retained.duplicate(true)
	invalid.cartography.scans[0].epoch = cold.orbit_time + 1.0
	_expect(not cold.restore(invalid) and cold.snapshot() == retained,
		"A future observation cannot modify the loaded atlas")


func _test_systems_and_trade() -> void:
	var flight := Flight.new()
	var home := flight.system_dossier(HOME)
	_expect(home.known and home.ports == Catalog.ports_for(HOME)
		and home.faction == flight.system_faction_name(HOME) and int(home.target_count) == Catalog.targets_for(HOME).size(),
		"The home dossier uses real public ports, local objects and current faction")
	flight.credits = 500
	var before := int(home.goods["ice"])
	_expect(flight.market_trade("ice", "buy", 2) and int(flight.system_dossier(HOME).goods["ice"]) == before - 2,
		"A played market purchase changes the aggregate storage immediately")
	var hidden := flight.system_dossier(HEATHER)
	_expect(not hidden.known and hidden.ports.is_empty() and hidden.goods.is_empty() and hidden.observations.is_empty(),
		"A concealed frontier system does not reveal warehouses or surveys")
	if not _expect(flight.project_action() and flight.system_dossier(HEATHER).known,
		"Accepting a real expedition reveals the frontier system through the ordinary command"):
		return
	if not _expect(_seed_final_construction(flight), "Place the expedition in its legal final delivery phase"):
		return
	var pending := flight.system_dossier(HEATHER)
	_expect(pending.known and pending.ports.is_empty() and pending.goods.is_empty()
		and int(pending.target_count) == Catalog.targets_for(HEATHER).size() - 1,
		"A revealed frontier shows local targets but does not pretend the unfinished station is operational")
	if not _expect(flight.project_action() and flight.station_operational(Catalog.HEATHER_PORT),
		"The delivered construction shipment actually commissions the port"):
		return
	var commissioned := flight.system_dossier(HEATHER)
	_expect(commissioned.ports == [Catalog.HEATHER_PORT]
		and commissioned.faction == flight.system_faction_name(HEATHER)
		and commissioned.goods.size() == Economy.GOODS.size()
		and int(commissioned.goods["ore"]) == flight.market.stock(Catalog.HEATHER_PORT, "ore"),
		"Commissioning changes the visible facilities, governing faction and totals from the actual warehouse")
	var traffic := flight.freight_status(Catalog.HEATHER_PORT)
	if not _expect(not traffic.is_empty(), "Commissioning schedules a real frontier shipment"):
		return
	_tick(flight, float(traffic[0].departure_eta) + 0.25)
	var underway := flight.freight_status(Catalog.HEATHER_PORT)[0]
	if not _expect(underway.in_transit and int(underway.amount) > 0, "The scheduled service transports actual goods"):
		return
	var source_system := Catalog.system_of_site(int(underway.origin))
	var destination_system := Catalog.system_of_site(int(underway.destination))
	var exports: Array = flight.system_dossier(source_system).exports
	var imports: Array = flight.system_dossier(destination_system).imports
	var outgoing := _shipment(exports, underway.id)
	var incoming := _shipment(imports, underway.id)
	_expect(not outgoing.is_empty() and outgoing == incoming and int(incoming.amount) == int(underway.amount)
		and incoming.good == underway.good and incoming.origin == underway.origin and incoming.destination == underway.destination,
		"The exact interstellar cargo appears as an export and an import in the correct dossiers")
	var stored := flight.market.stock(int(underway.destination), str(underway.good))
	_tick(flight, float(underway.arrival_eta) + 0.25)
	_expect(_shipment(flight.system_dossier(destination_system).imports, underway.id).is_empty()
		and flight.market.stock(int(underway.destination), str(underway.good)) == stored + int(underway.amount),
		"Arrival removes the in-transit row and transfers the cargo to destination storage once")


func _test_previous_schema() -> void:
	var flight := Flight.new()
	flight.credits = 190
	if not _expect(flight.survey_action(0) and flight.contract_action(), "Prepare a new snapshot independent of the historic shape"):
		return
	var historic := flight.snapshot()
	historic.schema = 25
	historic.ship.erase("mining_laser")
	historic.ship.erase("fragment_collector")
	historic.mining.reserves.resize(Catalog.AUTHORED_DESTINATION_COUNT)
	historic.erase("cartography")
	var cold := Flight.new()
	_expect(cold.restore(historic) and cold.snapshot().cartography.scans.is_empty() and not cold.body_dossier(0).known
		and cold.credits == 190 and cold.contract_stage == 1 and cold.system_dossier(HOME).known,
		"The older schema keeps the ship and active cargo contract and starts with empty observations")


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
	var flight: Flight = game.flight
	Fixture.launch(flight)
	flight.select_target(ASTEROID)
	flight.position = flight.target_position(ASTEROID) + Vector3.BACK * (float(Catalog.site(ASTEROID).radius) + 50.0)
	flight.velocity = flight.target_velocity(ASTEROID)
	game._update_display(0.0)
	await process_frame
	_tap(viewport, game._hud._actions.get("map"), "Open the playable sector map with ordinary touch")
	await process_frame
	var map_ui: Node = game._map
	_tap(viewport, map_ui._site_buttons.get(ASTEROID), "Select the co-moving rocky body", 39.0)
	await process_frame
	_tap(viewport, map_ui._survey_button, "Open the selected object's data card")
	await process_frame
	_expect(map_ui.is_open() and not flight.body_dossier(ASTEROID).known
		and map_ui._scan_button.is_visible_in_tree(), "The actual card offers observation rather than showing invented measurements")
	_tap(viewport, map_ui._scan_button, "Record the observation using the actual map button")
	await process_frame
	var stored := SessionIO.load_state()
	_expect(map_ui.is_open() and stored.get("cartography", {}).get("scans", []).size() == 1
		and flight.body_dossier(ASTEROID).known and not map_ui._scan_button.is_visible_in_tree(),
		"The Main-bound scan saves immediately, refreshes the card and cannot be requested twice")
	viewport.queue_free()
	await process_frame


func _matches_physics(flight: Flight, site: int) -> bool:
	var packet := flight.body_dossier(site)
	if not packet.known or packet.data.is_empty():
		return false
	var data: Dictionary = packet.data
	var radius := float(Catalog.site(site).radius)
	var atmosphere := Atmosphere.profile(site)
	return is_equal_approx(float(data.radius), radius) and is_equal_approx(float(data.period), Orbit.period(site)) \
		and is_equal_approx(float(data.gravity), Dynamics.gravity_parameter(site) / (radius * radius)) \
		and is_equal_approx(float(data.atmosphere_height), float(atmosphere.get("height", 0.0))) \
		and is_equal_approx(float(data.atmosphere_density), float(atmosphere.get("density", 0.0)))


func _seed_final_construction(flight: Flight) -> bool:
	var state := flight.snapshot()
	state.expedition.projects[0] = {
		"phase": Expedition.BUILD, "sponsor_port": 0, "sponsor": 0,
		"scan_index": Expedition.SURVEY_TOTAL, "build_index": Expedition.BUILD_TOTAL - 1,
	}
	var approach := flight.target_gate(Catalog.HEATHER_PORT) + Vector3.BACK * Expedition.BUILD_APPROACH_OFFSET
	var motion := flight.target_velocity(Catalog.HEATHER_PORT)
	state.merge({"system_id": HEATHER, "docked": -1, "target": Catalog.HEATHER_PLANET,
		"position": [approach.x, approach.y, approach.z], "velocity": [motion.x, motion.y, motion.z],
		"jump_target": -1, "jump_route": [], "planned_target": -1}, true)
	for good: String in Expedition.SUPPLIES[0][Expedition.BUILD_TOTAL - 1]:
		state.mining.cargo[good] = Expedition.SUPPLIES[0][Expedition.BUILD_TOTAL - 1][good]
	return flight.restore(state)


func _shipment(rows: Array, id: Variant) -> Dictionary:
	for row: Dictionary in rows:
		if row.id == id:
			return row
	return {}


func _approach(flight: Flight, site: int) -> bool:
	if not flight.select_target(site):
		return false
	flight.set_autopilot(true)
	for _frame in range(120 * 60):
		if not flight.autopilot:
			return flight.target == site
		_tick(flight)
	return false


func _jump_from_body(flight: Flight, site: int) -> bool:
	var outward := (flight.position - flight.target_position(site)).normalized()
	flight.yaw = atan2(-outward.x, -outward.z)
	flight.pitch = asin(clampf(outward.y, -1.0, 1.0))
	if not flight.plan_jump(VELAR):
		return false
	flight.change_throttle(0.18)
	for _frame in range(18 * 60):
		if flight.jump_status(VELAR).ok:
			break
		_tick(flight)
	if not flight.start_jump():
		return false
	for _frame in range(4 * 60):
		if flight.system_id == VELAR:
			return true
		_tick(flight)
	return false


func _tap(viewport: SubViewport, button: Button, description: String, minimum_height := 44.0) -> void:
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree()
		and not button.disabled and button.get_global_rect().size.y >= minimum_height, description):
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
