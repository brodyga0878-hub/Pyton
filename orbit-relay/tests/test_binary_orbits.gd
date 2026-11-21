extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Orbit := preload("res://scripts/orbit_ephemeris.gd")
const Dynamics := preload("res://scripts/orbital_dynamics.gd")
const Economy := preload("res://scripts/port_economy.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const HOME := Catalog.HOME_SYSTEM
const BINARY := Catalog.BINARY_SYSTEM
const PRIMARY := Catalog.BINARY_PRIMARY
const COMPANION := Catalog.BINARY_SECONDARY
const PLANET := Catalog.BINARY_PLANET
const MOON := Catalog.BINARY_MOON
const STEP := Fixture.STEP
const SAVE_PATH := "user://binary-orbits-test.json"

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_ephemerides()
	_test_binary_flight()
	_test_schema27()
	print("Binary system integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_ephemerides() -> void:
	var system := Catalog.system(BINARY)
	var barycenter: Vector3 = system.barycenter
	var first_mu := Dynamics.gravity_parameter(PRIMARY)
	var second_mu := Dynamics.gravity_parameter(COMPANION)
	var planet_mu := Dynamics.gravity_parameter(PLANET)
	var separation: float = system.binary_separation
	_expect(BINARY == Catalog.PRE_BINARY_SYSTEM_COUNT and PRIMARY == Catalog.PRE_BINARY_DESTINATION_COUNT
		and Catalog.SYSTEM_COUNT == BINARY + 1 and Catalog.PRE_GROUND_DESTINATION_COUNT == MOON + 1
		and Catalog.stars_for(BINARY) == [PRIMARY, COMPANION]
		and Catalog.star_for(BINARY) == PRIMARY and Catalog.ports_for(BINARY).is_empty()
		and Catalog.targets_for(BINARY) == [PRIMARY, COMPANION, PLANET, MOON],
		"The binary appends a separate system containing two stars and two solid targets with stable IDs")
	_expect(first_mu > second_mu and second_mu > 0.0 and planet_mu > 0.0
		and Orbit.orbit_parent(PRIMARY) == -1 and Orbit.orbit_parent(COMPANION) == -1
		and Orbit.orbit_parent(PLANET) == -1 and Orbit.orbit_parent(MOON) == PLANET,
		"Stellar masses differ, and the moon has the moving planet as its explicit parent")
	var mass := first_mu + second_mu
	var period := TAU * sqrt(separation * separation * separation / mass)
	_expect(absf(Orbit.period(PRIMARY) - period) < 0.002 and absf(Orbit.period(COMPANION) - period) < 0.002,
		"The two stars share the period determined by total mass and separation")
	var lunar_origin: Vector3 = Orbit.sample(MOON, 0.0).position - Orbit.sample(PLANET, 0.0).position
	var planet_origin: Vector3 = Orbit.sample(PLANET, 0.0).position - barycenter
	for epoch: float in [0.0, 37.0, period * 0.25, period * 0.5, 12345.0, 92000000.0]:
		var first := Orbit.sample(PRIMARY, epoch)
		var second := Orbit.sample(COMPANION, epoch)
		var weighted_position: Vector3 = (first.position * first_mu + second.position * second_mu) / mass
		var weighted_velocity: Vector3 = (first.velocity * first_mu + second.velocity * second_mu) / mass
		_expect(weighted_position.distance_to(barycenter) < 0.003 and weighted_velocity.length() < 0.0001
			and absf(first.position.distance_to(second.position) - separation) < 0.003,
			"Epoch %.1f keeps the center of mass, opposition and separation" % epoch)
		var planet := Orbit.sample(PLANET, epoch)
		var moon := Orbit.sample(MOON, epoch)
		_expect(absf(planet.position.distance_to(barycenter) - planet_origin.length()) < 0.008
			and absf(moon.position.distance_to(planet.position) - lunar_origin.length()) < 0.008,
			"Epoch %.1f preserves the two nested orbit radii in their own frames" % epoch)
	for site: int in [PRIMARY, COMPANION, PLANET, MOON]:
		var original := Orbit.sample(site, 0.0)
		var moving := Orbit.sample(site, 480.0)
		var previous: Vector3 = Orbit.sample(site, 479.75).position
		var following: Vector3 = Orbit.sample(site, 480.25).position
		var derivative := (following - previous) / 0.5
		_expect(original.position == Catalog.site(site).center and moving.position.distance_to(original.position) > 30.0
			and derivative.distance_to(moving.velocity) < 0.01,
			"Site %d retains the epoch anchor and its analytic velocity matches movement" % site)
		var path := Orbit.orbit_points(site, 480.0)
		_expect(path.size() >= 48 and path[0].distance_to(path[-1]) < 0.005,
			"Site %d supplies a closed path at the chart epoch" % site)
	var path_at_epoch := Orbit.orbit_points(MOON, 0.0)
	var shifted_path := Orbit.orbit_points(MOON, 480.0)
	var migration: Vector3 = Orbit.sample(PLANET, 480.0).position - Orbit.sample(PLANET, 0.0).position
	_expect(migration.length() > 100.0 and path_at_epoch.size() == shifted_path.size()
		and (shifted_path[0] - path_at_epoch[0]).distance_to(migration) < 0.01
		and (shifted_path[24] - path_at_epoch[24]).distance_to(migration) < 0.01,
		"The lunar chart path is translated by the moving parent, retaining its local shape")
	var lunar_period := Orbit.period(MOON)
	var end_moon: Vector3 = Orbit.sample(MOON, lunar_period).position
	var end_planet: Vector3 = Orbit.sample(PLANET, lunar_period).position
	_expect((end_moon - end_planet).distance_to(lunar_origin) < 0.005
		and end_moon.distance_to(Orbit.sample(MOON, 0.0).position) > 100.0,
		"A complete lunar orbit closes in the planet frame while the entire system continues to move")
	var probe: Vector3 = Orbit.sample(COMPANION, 480.0).position + Vector3.UP * 450.0
	var unweighted := Vector3.ZERO
	for site: int in Catalog.targets_for(BINARY):
		var center: Vector3 = Orbit.sample(site, 480.0).position
		unweighted += Dynamics.point_acceleration(probe, center, Dynamics.gravity_parameter(site), 1.0)
	var modeled := Dynamics.acceleration_at_epoch(BINARY, probe, 480.0)
	_expect(modeled.distance_to(unweighted) < 0.000005 and modeled.dot(Vector3.DOWN) > 0.015,
		"The ship gravity field includes both moving stars and the other local masses")


func _test_binary_flight() -> void:
	var flight := Flight.new()
	var tariff := Catalog.jump_cost(HOME, BINARY)
	_expect(tariff > 0 and not flight.system_known(BINARY) and not flight.plan_jump(BINARY),
		"An undiscovered system cannot become a jump target")
	flight.ship.jump_fuel = float(tariff)
	if not _expect(flight.scan_galaxy() and flight.system_known(BINARY) and flight.plan_route(BINARY)
		and Fixture.depart(flight) and _jump(flight, BINARY, 0),
		"The scanner unlocks a real route through normal home station departure"):
		return
	_expect(flight.system_id == BINARY and flight.local_targets() == [PRIMARY, COMPANION, PLANET, MOON]
		and flight.target == PRIMARY and flight.local_ports().is_empty()
		and flight.ship.jump_fuel == 0.0 and not flight.station_services_available(),
		"Arrival reaches the primary's current gate and creates no fictitious station")
	if not _expect(_approach(flight, COMPANION) and flight.scoop_status().ok
		and flight.scoop_status().body == COMPANION and flight.thermal_status().body == COMPANION,
		"Autopilot intercepts the moving companion and reports its own heat and collection shell"):
		return
	_expect(flight.speed_relative_to(COMPANION) < 3.0 and flight.target_velocity(COMPANION).length() > 0.5
		and flight.body_dossier(COMPANION).can_scan and flight.survey_action(COMPANION),
		"An independent companion survey requires a close, co-moving ship")
	_check_secondary_limits(flight)
	var companion_data: Dictionary = flight.body_dossier(COMPANION).data
	_expect(is_equal_approx(float(companion_data.period), Orbit.period(COMPANION))
		and is_equal_approx(float(companion_data.gravity), Dynamics.gravity_parameter(COMPANION)
			/ pow(float(Catalog.site(COMPANION).radius), 2.0)),
		"The stored companion dossier uses its actual orbital period and surface gravity")
	if not _expect(flight.scoop_action() and flight.scoop_active_at(COMPANION)
		and _advance(flight, func() -> bool: return flight.mining.cargo_amount(Economy.HYDROGEN) >= 2, 10.0)
		and flight.scoop_action(),
		"The companion yields real hydrogen canisters during physical flight"):
		return
	for site: int in [PLANET, MOON]:
		if not _expect(_approach(flight, site) and flight.landed_site == site and flight.survey_action(site),
			"Autopilot lands at the moving body %d and records a new survey (%s)" % [site, flight.status_message]):
			return
		var first := flight.position
		_advance(flight, func() -> bool: return false, 8.0)
		_expect(flight.landed_site == site and flight.position.distance_to(first) > 2.0
			and flight.position.distance_to(flight.target_contact(site)) < 0.02 and flight.dock_action() and not flight.landed,
			"At site %d the parked ship follows its body and lifts without losing control" % site)
	if not _expect(_approach(flight, PRIMARY) and flight.thermal_status().body == PRIMARY
		and flight.scoop_status().body == PRIMARY and flight.scoop_status().ok and flight.survey_action(PRIMARY),
		"Primary remains independently approachable, surveyable and scoopable"):
		return
	var earlier_canisters := flight.mining.cargo_amount(Economy.HYDROGEN)
	var needed := ceili(float(tariff) / 10.0)
	if not _expect(flight.scoop_action() and flight.scoop_active_at(PRIMARY)
		and _advance(flight, func() -> bool: return flight.mining.cargo_amount(Economy.HYDROGEN) >= needed, 15.0)
		and flight.mining.cargo_amount(Economy.HYDROGEN) > earlier_canisters and flight.scoop_action()
		and flight.fuel_transfer("jump") and flight.ship.jump_fuel >= tariff,
		"Collection from both stars finances a return trip with an initially empty jump tank"):
		return
	var checkpoint := flight.snapshot()
	if not _expect(SessionIO.save_state(checkpoint, SAVE_PATH) == OK, "Save the ship while moving near a binary star"):
		return
	var cold := Flight.new()
	if not _expect(cold.restore(SessionIO.load_state(SAVE_PATH)) and cold.system_id == BINARY and cold.target == PRIMARY
		and cold.position.distance_to(flight.position) < 0.002 and cold.velocity.distance_to(flight.velocity) < 0.002
		and cold.system_dossier(BINARY).observations == [PRIMARY, COMPANION, PLANET, MOON],
		"Cold restart preserves the binary location, both stellar and both surface records"):
		return
	var return_fuel := cold.ship.jump_fuel
	for site: int in [PRIMARY, COMPANION, PLANET, MOON]:
		_expect(cold.target_position(site).distance_to(flight.target_position(site)) < 0.002
			and cold.target_velocity(site).distance_to(flight.target_velocity(site)) < 0.002,
			"The restored clock produces the same position and velocity for site %d" % site)
	_expect(cold.plan_route(HOME) and _jump(cold, HOME, PRIMARY)
		and is_equal_approx(cold.ship.jump_fuel, return_fuel - tariff)
		and _approach(cold, 0) and cold.docked == 0 and cold.body_dossier(COMPANION).known,
		"The recovered ship exits the binary safely, returns to the home dock and retains its observations")


func _check_secondary_limits(flight: Flight) -> void:
	var probe := Flight.new()
	if not _expect(probe.restore(flight.snapshot()), "Clone the physical co-moving companion approach for envelope checks"):
		return
	probe.ship.jump_fuel = probe.ship.jump_capacity()
	_expect(probe.plan_jump(HOME) and not probe.jump_status(HOME).ok and not probe.start_jump()
		and not probe.time_status().allowed, "The companion blocks jump charge and accelerated time within its shell")
	var star := probe.target_position(COMPANION)
	var approaching := probe.target_velocity(COMPANION).normalized()
	probe.position = star + approaching * (Catalog.SCOOP_OUTER + 0.5)
	probe.velocity = Vector3.ZERO
	var fuel := probe.ship.jump_fuel
	_expect(probe.position.distance_to(star) > Catalog.SCOOP_OUTER
		and not probe.jump_status(HOME).ok and not probe.start_jump() and probe.ship.jump_fuel == fuel,
		"Charge is blocked before ignition if the moving companion would overtake the ship during the countdown")
	probe.position += approaching * 12.0
	_expect(probe.jump_status(HOME).ok, "A safe interval beyond the companion permits charging again")
	probe.position = probe.target_position(COMPANION) + Vector3.BACK * (Catalog.SCOOP_INNER - 28.0)
	probe.velocity = probe.target_velocity(COMPANION)
	_expect(not probe.scoop_status().ok and probe.thermal_status().danger
		and _advance(probe, func() -> bool: return probe.star_heat >= Flight.HEAT_DAMAGE_LIMIT, 20.0),
		"Flying inside the companion's safe band heats the hull and cuts off collection")
	_advance(probe, func() -> bool: return false, 1.0)
	_expect(probe.ship.hull < 100.0, "Prolonged excessive heat from the companion damages the hull")


func _test_schema27() -> void:
	var previous := Flight.new()
	if not _expect(previous.survey_action(0), "Prepare a schema27-shaped state with an authored survey"):
		return
	var state := previous.snapshot()
	state.schema = 27
	Fixture.remove_ground_ports_from_legacy(state)
	state.ship.erase("mining_laser")
	state.ship.erase("fragment_collector")
	state.ship.erase("hydrogen_scoop")
	state.ship.erase("fuel_pump")
	state.ship.erase("pump_mode")
	state.ship.erase("range_drive")
	state.ship.erase("drive_kind")
	state.ship.erase("autopilot_fitted")
	state.mining.reserves.resize(Catalog.PRE_BINARY_DESTINATION_COUNT)
	var cold := Flight.new()
	_expect(cold.restore(state) and cold.docked == 0 and cold.body_dossier(0).known and not cold.system_known(BINARY)
		and cold.snapshot().mining.reserves.size() == Catalog.DESTINATION_COUNT
		and cold.mining.reserve_at(PLANET) > 0 and cold.mining.reserve_at(MOON) > 0,
		"Schema 27 keeps its measurements and initializes the previously unavailable system without discovering it")
	state.cartography.systems.append({"system": BINARY, "epoch": previous.orbit_time})
	_expect(not Flight.new().restore(state), "A schema27 file cannot contain a future catalog system")


func _approach(flight: Flight, site: int) -> bool:
	var before := flight.position
	if not flight.select_target(site):
		return false
	flight.set_autopilot(true)
	return flight.position == before and flight.autopilot \
		and _advance(flight, func() -> bool: return not flight.autopilot, 220.0) and flight.target == site


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
