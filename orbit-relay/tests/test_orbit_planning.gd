extends SceneTree

const Fixture = preload("res://tests/flight_fixture.gd")

const Flight := preload("res://scripts/flight_sim.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Ephemeris := preload("res://scripts/orbit_ephemeris.gd")
const Terrain := preload("res://scripts/surface_terrain.gd")
const OrbitRelay := preload("res://main.tscn")
const STEP := 1.0 / 60.0
const STAR := Catalog.FRINGE_STAR_ID
const RADIUS := 620.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_advisory_forecast()
	_test_moving_impact()
	_test_maneuver()
	_test_maneuver_guards()
	_test_cancellation()
	_test_transient_reload()
	await _test_chart()
	print("Orbit planning integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_advisory_forecast() -> void:
	var flight := _angled_approach()
	flight.set_flight_assist(false)
	var begin := flight.position
	var center := flight.target_position(STAR)
	var circular := sqrt(flight.gravity_at(begin).length() * RADIUS)
	flight.velocity = Vector3(0.67, 0.74, 0.0).normalized() * circular
	var status := flight.orbit_status()
	_expect(status.classification == "bound" and is_equal_approx(status.radius, RADIUS)
		and absf(status.radial_speed) < 0.001 and absf(status.circular_speed - circular) < 0.001
		and absf(status.periapsis - RADIUS) < 1.0 and absf(status.apoapsis - RADIUS) < 1.0
		and status.eccentricity < 0.002 and absf(status.period - TAU * RADIUS / circular) < 1.0,
		"The ship panel reports the osculating elements of a known circular orbit")
	var original := flight.snapshot()
	var predicted := flight.orbit_forecast()
	var points: PackedVector3Array = predicted.points
	if not _expect(predicted.impact == -1 and is_equal_approx(predicted.seconds, 180.0)
		and points.size() > 10 and points.size() <= 128 and points[0].is_equal_approx(begin),
		"The orbital chart includes the starting position and a bounded 180-second forecast"):
		return
	_expect(flight.snapshot() == original and flight.orbit_forecast() == predicted and not flight.orbit_maneuver,
		"Repeated forecasts are deterministic and leave all flight and control state unchanged")
	var linear := begin + flight.velocity * float(predicted.seconds)
	_expect(linear.distance_to(points[-1]) > 100.0 and absf(points[-1].distance_to(center) - RADIUS) < 3.0,
		"The forecast arcs under gravity instead of drawing a straight projected velocity")
	flight.update(predicted.seconds, Vector2.ZERO, 0.0, false, false)
	_expect(flight.position.distance_to(points[-1]) < 3.0 and flight.ship.hull == 100.0,
		"Free flight for the forecast duration reaches its indicated endpoint")
	flight.velocity = Vector3.UP * (circular * 1.8)
	var escaping := flight.orbit_status()
	_expect(escaping.classification == "escape" and escaping.period < 0.0 and escaping.apoapsis < 0.0,
		"An unbound trajectory has no imaginary apoapsis or period")
	var parked := Flight.new()
	_expect(parked.orbit_forecast().points.is_empty() and parked.orbit_status().classification == "unavailable",
		"Flight forecasting and orbital elements are unavailable while docked")


func _test_moving_impact() -> void:
	var flight := Flight.new()
	Fixture.launch(flight)
	flight.set_flight_assist(false)
	const ASTEROID := 2
	const LEAD_TIME := 55.0
	var old_center := flight.target_position(ASTEROID)
	var center_at_intercept: Vector3 = Ephemeris.sample(ASTEROID, flight.orbit_time + LEAD_TIME).position
	flight.position = center_at_intercept + Vector3.UP * 990.0
	flight.velocity = Vector3.DOWN * (990.0 / LEAD_TIME)
	var forecast := flight.orbit_forecast()
	var points: PackedVector3Array = forecast.points
	if not _expect(forecast.impact == ASTEROID and forecast.seconds > 48.0 and forecast.seconds < LEAD_TIME
		and points.size() > 1, "A forecast aimed ahead of a moving asteroid identifies that asteroid as the first obstacle"):
		return
	var future_center: Vector3 = Ephemeris.sample(ASTEROID, flight.orbit_time + forecast.seconds).position
	var envelope := float(Catalog.site(ASTEROID).radius) * Terrain.MAX_RADIUS_FACTOR + Terrain.CONTACT_CLEARANCE
	_expect(points[-1].distance_to(future_center) <= envelope + 2.0
		and points[-1].distance_to(old_center) > envelope + 14.0,
		"The predicted impact uses the asteroid's future position, away from its present collision envelope")
	var epoch := flight.orbit_time
	for _frame in range(roundi((LEAD_TIME + 2.0) / STEP)):
		if flight.ship.hull < 100.0:
			break
		_tick(flight)
	_expect(flight.ship.hull < 100.0 and absf(flight.orbit_time - epoch - forecast.seconds) < 2.1
		and flight.position.distance_to(points[-1]) < 30.0,
		"The actual ballistic approach hits near the forecast's conservative impact time and location")


func _test_maneuver() -> void:
	var flight := _angled_approach()
	var start := flight.position
	var velocity := flight.velocity
	var fuel := flight.ship.fuel
	var center := flight.target_position(STAR)
	var normal := (start - center).cross(velocity).normalized()
	var proposal := flight.orbit_status()
	if not _expect(flight.target != STAR and proposal.allowed and proposal.delta_v > 0.8
		and flight.start_orbit_maneuver() and flight.orbit_maneuver and not flight.flight_assist
		and flight.position == start and flight.velocity == velocity and flight.ship.fuel == fuel,
		"The planner can start without changing the selected target, and starting neither teleports nor burns fuel"):
		return
	var largest_velocity_change := 0.0
	var turn := false
	var burn := false
	for _frame in range(roundi(20.0 / STEP)):
		if not flight.orbit_maneuver:
			break
		var guidance := flight.orbit_status()
		turn = turn or guidance.maneuver_phase == "turn"
		burn = burn or guidance.maneuver_phase == "burn"
		var previous := flight.velocity
		_tick(flight)
		largest_velocity_change = maxf(largest_velocity_change, flight.velocity.distance_to(previous))
	var circularized := flight.orbit_status()
	if not _expect(not flight.orbit_maneuver and not flight.flight_assist and turn and burn
		and flight.ship.fuel < fuel and largest_velocity_change < 0.8 and largest_velocity_change > 0.01
		and circularized.classification == "bound" and circularized.eccentricity < 0.09
		and absf(circularized.radial_speed) < 0.16 and circularized.period > 0.0,
		"The ship turns and applies bounded thrust, spending fuel to produce a nearly circular trajectory (%s)" % flight.status_message):
		return
	var at_cutoff := flight.position
	var speed_at_cutoff := flight.velocity
	var coast_fuel := flight.ship.fuel
	var max_plane_error := 0.0
	var highest := 0.0
	var lowest := 0.0
	for _sector in range(8):
		flight.update(circularized.period / 8.0, Vector2.ZERO, 0.0, false, false)
		var relative := flight.position - center
		max_plane_error = maxf(max_plane_error, absf(normal.dot(relative)))
		highest = maxf(highest, relative.y)
		lowest = minf(lowest, relative.y)
	_expect(highest > 290.0 and lowest < -290.0 and max_plane_error < 20.0,
		"The maneuver preserves the initial orbital plane above and below the star")
	_expect(flight.position.distance_to(at_cutoff) < 12.0 and flight.velocity.distance_to(speed_at_cutoff) < 0.12
		and flight.ship.fuel == coast_fuel and flight.ship.hull == 100.0,
		"The resulting inclined trajectory completes a full free orbit without hidden thrust or hull damage")


func _test_maneuver_guards() -> void:
	var parked := Flight.new()
	_expect(not parked.orbit_status().allowed and not parked.start_orbit_maneuver(),
		"A ship cannot start an orbital maneuver while parked")
	var flight := _angled_approach()
	var center := flight.target_position(STAR)
	flight.position = center + Vector3.BACK * 500.0
	_expect(not flight.orbit_status().allowed and not flight.start_orbit_maneuver(),
		"The maneuver is guarded inside the minimum stellar clearance")
	flight.position = center + Vector3.BACK * 1801.0
	_expect(not flight.orbit_status().allowed and not flight.start_orbit_maneuver(),
		"The maneuver cannot start beyond its maximum operating radius")
	flight.position = center + Vector3.BACK * RADIUS
	flight.velocity = Vector3.UP * 31.0
	_expect(not flight.orbit_status().allowed and not flight.start_orbit_maneuver(),
		"A high-speed flyby is too fast for circularization assistance")
	flight.velocity = Vector3.UP * 2.4
	flight.ship.fuel = 0.0
	_expect(not flight.orbit_status().allowed and not flight.start_orbit_maneuver(),
		"Orbital assistance requires usable fuel")
	flight.ship.fuel = 50.0
	flight.ship.hull = 1.0
	_expect(not flight.orbit_status().allowed and not flight.start_orbit_maneuver(),
		"A critically damaged vessel must repair before starting the burn")


func _test_cancellation() -> void:
	for action: String in ["explicit cancellation", "steering", "brake", "translation", "autopilot", "jump"]:
		var flight := _angled_approach()
		if not _expect(flight.start_orbit_maneuver(), "Prepare an ongoing orbit maneuver before %s" % action):
			continue
		var handled := true
		match action:
			"explicit cancellation":
				handled = flight.cancel_orbit_maneuver()
			"steering":
				flight.update(STEP, Vector2.RIGHT, 0.0, false, false)
			"brake":
				flight.update(STEP, Vector2.ZERO, 0.0, false, true)
			"translation":
				flight.update(STEP, Vector2.ZERO, 0.0, false, false, Vector3.UP)
			"autopilot":
				flight.set_autopilot(true)
				handled = flight.autopilot
			"jump":
				handled = flight.plan_jump(Catalog.HOME_SYSTEM) and flight.start_jump()
		_expect(handled and not flight.orbit_maneuver and not flight.orbit_status().maneuver,
			"%s takes control and replaces the active planner" % action)
		if action != "jump" and action != "autopilot":
			_expect(not flight.cancel_orbit_maneuver(), "Cancellation is idempotent after %s" % action)


func _test_transient_reload() -> void:
	var flight := _angled_approach()
	if not _expect(flight.start_orbit_maneuver(), "Begin a maneuver before serializing the session"):
		return
	_tick(flight, 0.1)
	var saved := JSON.parse_string(JSON.stringify(flight.snapshot(), "", true, true)) as Dictionary
	var loaded := Flight.new()
	_expect(loaded.restore(saved) and not loaded.flight_assist and not loaded.orbit_maneuver
		and loaded.position.distance_to(flight.position) < 0.001 and loaded.velocity.distance_to(flight.velocity) < 0.001,
		"A cold start preserves ship momentum and inertial mode without restarting the automated burn")
	var fuel := loaded.ship.fuel
	_tick(loaded, 1.0)
	_expect(loaded.ship.fuel == fuel, "The restored coasting vessel does not spend fuel on the previous maneuver")


func _test_chart() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := OrbitRelay.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = _angled_approach()
	game._update_display(0.0)
	await process_frame
	var original_target: int = game.flight.target
	_tap(viewport, game._hud._actions["map"], "Open the actual sector chart through touch")
	await process_frame
	_tap(viewport, game._map._trajectory_button, "Open the trajectory forecast through touch")
	await process_frame
	_expect(game._map._trajectory_panel.is_visible_in_tree() and game._map._chart.forecast_visible
		and game._map._chart.forecast.size() > 2 and game.flight.target == original_target,
		"The trajectory overlay draws flight data without selecting a new destination")
	_tap(viewport, game._map._orbit_button, "Start circular orbit assistance from the actual chart")
	await process_frame
	_expect(game.flight.orbit_maneuver and not game._map.is_open() and game.flight.target == original_target,
		"Starting the maneuver returns the pilot to the flight HUD on the existing target")
	game._update_display(0.0)
	await process_frame
	_tap(viewport, game._hud._actions["orbit_cancel"], "Cancel the maneuver through the flight HUD")
	await process_frame
	_expect(not game.flight.orbit_maneuver and not game.flight.flight_assist,
		"Touch cancellation drops motor control while leaving the vessel in inertial flight")
	viewport.queue_free()
	await process_frame


func _angled_approach() -> Flight:
	var flight := Flight.new()
	var port := Catalog.FRINGE_ARRIVAL_PORT
	var saved := flight.snapshot()
	var docking := flight.docking_position(port)
	saved.merge({"system_id": Catalog.FRINGE_SYSTEM, "docked": port, "target": port,
		"position": [docking.x, docking.y, docking.z]}, true)
	_expect(flight.restore(saved) and Fixture.launch(flight), "Launch a test ship in the Kromka system")
	flight.position = flight.target_position(STAR) + Vector3.BACK * RADIUS
	flight.velocity = Vector3(0.67, 0.74, 0.0).normalized() * 2.4 + Vector3.BACK * 0.85
	flight.yaw = 0.0
	flight.pitch = 0.0
	flight.roll = 0.0
	return flight


func _tick(flight: Flight, delta: float = STEP) -> void:
	flight.update(delta, Vector2.ZERO, 0.0, false, false)


func _tap(viewport: SubViewport, button: Button, description: String) -> void:
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, description):
		return
	for pressed: bool in [true, false]:
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
