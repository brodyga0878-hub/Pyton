extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Orbit := preload("res://scripts/orbit_ephemeris.gd")
const Atmosphere := preload("res://scripts/atmosphere.gd")
const Terrain := preload("res://scripts/surface_terrain.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Economy := preload("res://scripts/port_economy.gd")
const Rig := preload("res://scripts/mining_rig.gd")
const FirstMoon := Catalog.PRE_RICH_SYSTEMS_DESTINATION_COUNT
const FirstGiant := FirstMoon + 1

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_test_appended_geometry()
	_test_lunar_flight()
	_test_giant_flight()
	_test_legacy_restore()
	print("Generated companions integration: %d checks, %d failures" % [_checks, _failures])
	quit(int(_failures > 0))


func _test_appended_geometry() -> void:
	var moons := 0
	var giants := 0
	var visited := {}
	for id in range(FirstMoon, Catalog.DESTINATION_COUNT):
		var system := Catalog.system_of_site(id)
		var body := Catalog.site(id)
		var parent := Orbit.orbit_parent(id)
		var range_to_parent := Orbit.extrema(id)
		var min_clearance := float(body.radius) * Terrain.MAX_RADIUS_FACTOR + Terrain.CONTACT_CLEARANCE
		_expect(Catalog.targets_for(system).size() == 4 and Catalog.targets_for(system).back() == id
			and parent < FirstMoon and Catalog.system_of_site(parent) == system and not visited.has(system)
			and Orbit.sample(id, 0.0).position == body.center and range_to_parent.x > 0.0 and Orbit.period(id) > 0.0,
			"Appended site %d has one owner and a valid orbit without renumbering its parent" % id)
		visited[system] = true
		var base_mines := Catalog.mines_for(system)
		var old_planet: int = base_mines[0]
		var asteroid: int = base_mines[1]
		if body.kind == "moon":
			moons += 1
			_expect(parent == old_planet and Catalog.is_mine_site(id) and Terrain.spin_rate(id) > 0.0
				and range_to_parent.x - min_clearance > float(Catalog.site(parent).gate_offset)
				and Orbit.extrema(parent).x - range_to_parent.y - min_clearance > Catalog.SCOOP_OUTER
				and Orbit.extrema(asteroid).x - float(Catalog.site(asteroid).gate_offset) > Orbit.extrema(parent).y + range_to_parent.y + min_clearance,
				"The orbit of new moon %d clears its parent's approach, stellar scoop path and old asteroid's approach" % id)
		else:
			giants += 1
			var layer := Atmosphere.profile(id)
			_expect(parent == Catalog.star_for(system) and Catalog.gas_giant_for(system) == id
				and Catalog.is_gas_giant(id) and not Catalog.is_mine_site(id) and not Catalog.is_port(id)
				and float(layer.height) > Flight.GAS_SCOOP_MAX_ALTITUDE and float(layer.density) > 0.0
				and range_to_parent.x - float(body.radius) - float(layer.height) > Orbit.extrema(asteroid).y + float(Catalog.site(asteroid).gate_offset),
				"The non-landable giant %d adds a real atmosphere beyond the older approaches" % id)
	_expect(moons == 16 and giants == 16 and Catalog.SYSTEM_COUNT == 512 and FirstMoon == 1553,
		"Sixteen moons and sixteen gas giants append to the 1,553 historical bodies")


func _test_lunar_flight() -> void:
	var moon := FirstMoon
	var parent := Orbit.orbit_parent(moon)
	var epoch := 180.0
	var actual := Orbit.sample(moon, epoch)
	var world_delta: Vector3 = Orbit.sample(moon, epoch + 0.25).position - Orbit.sample(moon, epoch - 0.25).position
	var relative_radius: Vector3 = actual.position - Orbit.sample(parent, epoch).position
	var later_relative: Vector3 = Orbit.sample(moon, epoch + Orbit.period(moon)).position - Orbit.sample(parent, epoch + Orbit.period(moon)).position
	_expect(Vector3(actual.velocity).distance_to(world_delta / 0.5) < 0.005
		and relative_radius.distance_to(later_relative) < 0.003,
		"The moving moon inherits its planet's velocity and returns to its relative place after a lunar period")
	var hidden := Flight.new().body_dossier(moon)
	_expect(not hidden.known and hidden.name.is_empty() and hidden.data.is_empty(), "An undiscovered system conceals its new moon")
	var flight := _near_body(moon, 85.0, epoch)
	if not _expect(flight != null and flight.select_target(moon) and flight.survey_action(moon)
		and flight.body_dossier(moon).data.orbit_parent == parent, "Select and survey the actual moon after revealing its system"):
		return
	flight.set_autopilot(true)
	for _step in range(60 * 100):
		if not flight.autopilot:
			break
		flight.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
	if not _expect(flight.landed_site == moon and flight.ship.hull > 99.0,
		"The normal autopilot reaches and lands on the moving terrain (%s)" % flight.status_message):
		return
	var reserves := flight.mining.reserve_at(moon)
	if not _expect(flight.mine_action(), "Deploy the mining equipment on the lunar surface"):
		return
	flight.update(Rig.DEPLOY_SECONDS + float(Catalog.site(moon).drill_seconds) + 0.2, Vector2.ZERO, 0.0, false, false)
	if not _expect(flight.mining.phase == Rig.READY and flight.mine_action(), "Recover the equipment with the first batch of lunar ice"):
		return
	flight.update(Rig.RETURN_SECONDS + 0.1, Vector2.ZERO, 0.0, false, false)
	_expect(flight.mining.cargo_amount("ice") == Rig.BATCH and flight.mining.reserve_at(moon) == reserves - Rig.BATCH
		and flight.dock_action() and not flight.landed, "The game depletes actual ice and permits takeoff after the rig returns")
	var resumed := Flight.new()
	_expect(resumed.restore(flight.snapshot()) and resumed.body_dossier(moon).known
		and resumed.mining.reserve_at(moon) == reserves - Rig.BATCH, "The new survey and depleted deposit persist through a cold restore")


func _test_giant_flight() -> void:
	var giant := FirstGiant
	var flight := _near_body(giant, 45.0, 140.0)
	if not _expect(flight != null, "Seed a discovered gas-giant system"):
		return
	flight.jump_target = Catalog.system_of_site(giant)
	flight._finish_jump_arrival()
	if not _expect(flight.select_target(giant), "Select the generated gas giant from the normal system arrival"):
		return
	flight.set_autopilot(true)
	for _step in range(60 * 180):
		if not flight.autopilot:
			break
		flight.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
	if not _expect(not flight.autopilot and flight.status_event == "gas_arrival" and flight.ship.hull == 100.0,
		"The normal autopilot intercepts the moving giant and approaches its atmosphere without damage"):
		return
	var air := flight.atmosphere_status()
	var collector := flight.scoop_status()
	_expect(air.site == giant and air.inside and air.density > 0.0 and absf(float(air.altitude) - 45.0) < 2.1
		and collector.kind == "gas" and collector.ok and not flight.cycle_time_scale(),
		"The flight uses the giant's atmosphere for pressure, time safety and co-moving scoop rules")
	_expect(flight.survey_action(giant) and not flight.dock_action() and not flight.mine_action() and not flight.landed,
		"A survey can observe the giant while landing, docking and drilling remain unavailable")
	if not _expect(flight.scoop_action() and flight.scoop_active_at(giant), "Start hydrogen skimming near the generated giant"):
		return
	flight.update(3.0, Vector2.ZERO, 0.0, false, false)
	_expect(flight.mining.cargo_amount(Economy.HYDROGEN) > 0 and flight.ship.hull == 100.0,
		"The usual skimming cycle fills real hydrogen canisters")
	var resumed := Flight.new()
	_expect(resumed.restore(flight.snapshot()) and not resumed.scooping and resumed.body_dossier(giant).known
		and resumed.mining.cargo_amount(Economy.HYDROGEN) == flight.mining.cargo_amount(Economy.HYDROGEN),
		"Finished canisters and the new target survive a cold restore while the active scoop stops safely")


func _test_legacy_restore() -> void:
	var body := FirstGiant
	var system := Catalog.system_of_site(body)
	var flight := _near_body(body, 10.0, 150.0)
	if not _expect(flight != null, "Set a valid ordinary approach in the old catalog's system"):
		return
	var old := flight.snapshot()
	old.schema = 47
	old.erase("cargo_pods")
	old.mining.reserves.resize(FirstMoon)
	old.frame.auto_site = -1
	var prior_site: int = Catalog.mines_for(system)[0]
	old.mining.reserves[prior_site] -= Rig.BATCH
	var clear := Flight.new()
	_expect(clear.restore(old) and clear.position == flight.position and clear.velocity == flight.velocity
		and clear.mining.reserve_at(prior_site) == old.mining.reserves[prior_site]
		and clear.mining.reserve_at(FirstMoon) == int(Catalog.site(FirstMoon).reserve),
		"The legacy flight keeps its safe coordinates and old depletion and adds untouched lunar reserves")
	var occupied: Vector3 = flight.target_position(body)
	old.position = [occupied.x, occupied.y, occupied.z]
	var cleared := Flight.new()
	_expect(cleared.restore(old) and cleared.position.distance_to(occupied) > float(Catalog.site(body).radius)
		and cleared.velocity == flight.target_velocity(body), "Only a pre-existing save inside a new giant is moved to safe clearance")
	old.cartography.scans = [{"site": body, "epoch": flight.orbit_time}]
	_expect(not Flight.new().restore(old), "A legacy save cannot claim observations of newly introduced sites")


func _near_body(site: int, altitude: float, epoch: float) -> Flight:
	var flight := Flight.new()
	flight.update(epoch, Vector2.ZERO, 0.0, false, false)
	if not Fixture.launch(flight):
		return null
	var system := Catalog.system_of_site(site)
	if not flight.cartography.restore({"systems": [{"system": system, "epoch": 0.0}], "scans": []}, epoch):
		return null
	flight.system_id = system
	flight.target = Catalog.star_for(system)
	var direction := Terrain.spin_basis(site, epoch) * Vector3.BACK
	flight.position = flight.target_position(site) + direction * (float(Catalog.site(site).radius) + altitude)
	flight.velocity = flight.target_velocity(site)
	return flight


func _expect(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		printerr(message)
		_failures += 1
	return condition
