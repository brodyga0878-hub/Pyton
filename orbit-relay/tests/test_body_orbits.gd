extends SceneTree

const Fixture = preload("res://tests/flight_fixture.gd")

const Flight := preload("res://scripts/flight_sim.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Ephemeris := preload("res://scripts/orbit_ephemeris.gd")
const Expedition := preload("res://scripts/expedition.gd")
const FactionFronts := preload("res://scripts/faction_fronts.gd")
const OrbitRelay := preload("res://main.tscn")
const PLANET := Catalog.HEATHER_PLANET
const MOON := 6
const STEP := 1.0 / 60.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var planet := _approach(PLANET, Catalog.HEATHER_PORT, 19.0)
	_test_translating_forecast(planet)
	_test_body_orbit(planet, PLANET)
	var moon := _approach(MOON, 0, 11.0)
	_test_body_orbit(moon, MOON)
	_test_selection_and_limits()
	await _test_chart()
	print("Moving body orbits integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_translating_forecast(flight: Flight) -> void:
	var original := flight.snapshot()
	var predicted := flight.orbit_forecast(PLANET)
	var absolute: PackedVector3Array = predicted.points
	var anchored: PackedVector3Array = predicted.relative_points
	if not _expect(predicted.focus_id == PLANET and predicted.impact == -1
		and is_equal_approx(predicted.seconds, 180.0) and absolute.size() == anchored.size()
		and absolute.size() > 20 and anchored[0].is_equal_approx(flight.position)
		and absolute[0].is_equal_approx(flight.position) and flight.snapshot() == original,
		"The selected planet adds a relative forecast to the absolute track without changing the ship"):
		return
	var current_planet := flight.target_position(PLANET)
	var end_epoch := flight.orbit_time + float(predicted.seconds)
	var future_planet: Vector3 = Ephemeris.sample(PLANET, end_epoch).position
	var planet_motion := future_planet - current_planet
	_expect(planet_motion.length() > 200.0 and (absolute[-1] - anchored[-1]).distance_to(planet_motion) < 0.015,
		"The relative endpoint subtracts the actual ephemeris displacement instead of using a fixed body")
	var direct_transfer := flight.target_velocity(PLANET) * float(predicted.seconds)
	_expect(planet_motion.distance_to(direct_transfer) > 15.0,
		"The ephemeris anchor follows the curved motion of the planet during the forecast")
	var resumed := Flight.new()
	if not _expect(resumed.restore(_json(original)) and resumed.set_flight_assist(false),
		"Prepare a real unassisted flight from the forecast coordinates"):
		return
	_tick(resumed, float(predicted.seconds))
	var actual_relative := resumed.position - resumed.target_position(PLANET) + current_planet
	_expect(resumed.position.distance_to(absolute[-1]) < 6.0 and actual_relative.distance_to(anchored[-1]) < 6.0,
		"Free flight agrees with the projected position in both absolute and planet-centred frames")


func _test_body_orbit(flight: Flight, focus: int) -> void:
	var name: String = Catalog.site(focus).name
	var proposal := flight.orbit_status(focus)
	var previous_velocity := flight.velocity
	var current_pos := flight.position
	var fuel := flight.ship.fuel
	var chosen_target := flight.target
	var radial_start := current_pos - flight.target_position(focus)
	var plane := radial_start.cross(previous_velocity - flight.target_velocity(focus)).normalized()
	if not _expect(proposal.allowed and proposal.focus == focus and proposal.focus_kind == Catalog.site(focus).kind
		and proposal.approach_min > proposal.collision_radius and proposal.radius > proposal.approach_min
		and proposal.radius < proposal.approach_max and proposal.delta_v > 0.15,
		"An approach to %s supplies a valid body, terrain clearance, safe band and relative impulse (%s)" % [name, proposal.reason]):
		return
	if not _expect(flight.start_orbit_maneuver(focus) and flight.orbit_maneuver_focus == focus
		and flight.orbit_status().focus == focus and flight.target == chosen_target and not flight.flight_assist
		and flight.position == current_pos and flight.velocity == previous_velocity and flight.ship.fuel == fuel,
		"The maneuver locks %s without teleporting or taking over the selected approach destination" % name):
		return
	_expect(flight.orbit_forecast().focus_id == focus
		and not flight.start_orbit_maneuver(Catalog.star_for(flight.system_id)),
		"An ongoing maneuver keeps its chosen body in the default forecast and cannot be retargeted")
	for _frame in range(roundi(15.0 / STEP)):
		if not flight.orbit_maneuver:
			break
		_tick(flight)
	var quality := flight.orbit_status(focus)
	var relative_velocity := flight.velocity - flight.target_velocity(focus)
	if not _expect(flight.status_event == "orbit_complete" and not flight.orbit_maneuver and flight.orbit_maneuver_focus == -1
		and flight.ship.fuel < fuel and quality.classification == "bound" and quality.period > 0.0
		and absf(quality.radial_speed) < 0.18 and absf(relative_velocity.length() - float(quality.circular_speed)) < 0.17
		and absf(relative_velocity.length() - flight.velocity.length()) > 0.5,
		"Thrust establishes a bound orbit about moving %s with local, not system-frame, circular velocity (%s)" % [name, flight.status_message]):
		return
	var first_center := flight.target_position(focus)
	var first_radial := flight.position - first_center
	var last_radial := first_radial
	var cutoff_fuel := flight.ship.fuel
	var angular_distance := 0.0
	var shortest_radius := first_radial.length()
	var widest_radius := shortest_radius
	var high := first_radial.y
	var low := first_radial.y
	var seconds := 0.0
	const SAMPLE := 4.0
	while angular_distance < TAU - 0.025 and seconds < float(quality.period) * 1.45:
		_tick(flight, SAMPLE)
		seconds += SAMPLE
		var radial := flight.position - flight.target_position(focus)
		angular_distance += atan2(plane.dot(last_radial.cross(radial)), last_radial.dot(radial))
		last_radial = radial
		shortest_radius = minf(shortest_radius, radial.length())
		widest_radius = maxf(widest_radius, radial.length())
		high = maxf(high, radial.y)
		low = minf(low, radial.y)
	_expect(angular_distance >= TAU - 0.025 and shortest_radius > float(proposal.collision_radius)
		and widest_radius < first_radial.length() * 1.3 and last_radial.distance_to(first_radial) < first_radial.length() * 0.4,
		"The ship makes a full circuit relative to %s while staying clear of terrain (%.2f rad, %.0f–%.0f m)" % [
			name, angular_distance, shortest_radius, widest_radius,
		])
	_expect(high > first_radial.length() * 0.65 and low < -first_radial.length() * 0.65
		and flight.target_position(focus).distance_to(first_center) > 300.0
		and flight.ship.fuel == cutoff_fuel and flight.ship.hull == 100.0,
		"The inclined circuit follows the translating body above and below its equator with no hidden thrust or collision")


func _test_selection_and_limits() -> void:
	var flight := _approach(MOON, 0, 15.0)
	var initial := flight.snapshot()
	for invalid: int in [0, 2, PLANET, 200]:
		_expect(flight.orbit_status(invalid).classification == "unavailable" and not flight.start_orbit_maneuver(invalid)
			and flight.snapshot() == initial,
			"A port, asteroid, undiscovered system target or invalid catalog ID cannot become an orbital focus (%d)" % invalid)
	var reference_velocity := flight.target_velocity(MOON)
	var along := reference_velocity.normalized()
	flight.velocity = reference_velocity + along * (Flight.ORBIT_MAX_SPEED - 0.5)
	_expect(flight.speed() > Flight.ORBIT_MAX_SPEED and flight.orbit_status(MOON).allowed,
		"A fast system-frame ship still qualifies when its speed relative to the moon is within the limit")
	flight.velocity = reference_velocity - along * (Flight.ORBIT_MAX_SPEED + 0.5)
	_expect(flight.speed() < Flight.ORBIT_MAX_SPEED and not flight.orbit_status(MOON).allowed
		and not flight.start_orbit_maneuver(MOON),
		"A slower system-frame ship is rejected if its motion relative to the moon exceeds the limit")
	flight.velocity = reference_velocity
	var band := flight.orbit_status(MOON)
	var center := flight.target_position(MOON)
	flight.position = center + (flight.position - center).normalized() * (float(band.approach_min) - 1.0)
	_expect(not flight.start_orbit_maneuver(MOON), "The terrain-clearance buffer blocks a low attempt")
	flight.position = center + (flight.position - center).normalized() * (float(band.approach_max) + 1.0)
	_expect(not flight.start_orbit_maneuver(MOON), "The upper limit of the moon's sphere of influence blocks a distant attempt")
	flight = _approach(MOON, 0, 15.0)
	flight.ship.fuel = 0.0
	_expect(not flight.start_orbit_maneuver(MOON), "A valid orbit band still requires fuel to start")
	var narrow := _approach(PLANET, Catalog.HEATHER_PORT, 19.0)
	var blocked := narrow.orbit_status(Catalog.HEATHER_MOON)
	_expect(blocked.focus_kind == "moon" and blocked.approach_min > blocked.approach_max
		and blocked.classification != "unavailable" and not narrow.start_orbit_maneuver(Catalog.HEATHER_MOON),
		"A nearby moon with no safe interval retains its measurable orbit data and rejects a burn")
	if not _expect(narrow.start_orbit_maneuver(PLANET), "Start a planet-centred maneuver for cancellation tests"):
		return
	_tick(narrow, 0.25)
	var saved := _json(narrow.snapshot())
	var restored := Flight.new()
	_expect(restored.restore(saved) and restored.orbit_maneuver_focus == -1 and not restored.orbit_maneuver
		and restored.orbit_status().focus == Catalog.HEATHER_STAR and not restored.flight_assist
		and restored.velocity.distance_to(narrow.velocity) < 0.001,
		"Cold restart saves flight state but releases the selected body lock and pending burn")
	narrow.update(STEP, Vector2.ZERO, 0.0, false, true)
	_expect(narrow.orbit_maneuver_focus == -1 and not narrow.orbit_maneuver,
		"Manual braking releases the active planet focus")


func _test_chart() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := OrbitRelay.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = _approach(PLANET, Catalog.HEATHER_PORT, 19.0)
	game._update_display(0.0)
	await process_frame
	var original_target: int = game.flight.target
	_tap(viewport, game._hud._actions["map"], "Open the sector chart using touch")
	await process_frame
	_tap(viewport, game._map._trajectory_button, "Show the orbit planning panel")
	await process_frame
	_tap(viewport, game._map._focus_buttons[PLANET], "Set the planet as the orbit reference through touch")
	await process_frame
	_expect(game._map._orbit_focus == PLANET and game._map._chart.orbit_focus == PLANET
		and game._map._chart.forecast.size() > 2 and game._map._chart.system_forecast.size() > 2
		and game._map._chart.forecast != game._map._chart.system_forecast and game.flight.target == original_target,
		"The focused chart displays separate inertial and translating tracks while retaining the navigation target")
	_tap(viewport, game._map._orbit_button, "Command the focused planet maneuver from the map")
	await process_frame
	_expect(game.flight.orbit_maneuver and game.flight.orbit_maneuver_focus == PLANET
		and game.flight.target == original_target and not game._map.is_open(),
		"The chart forwards the exact selected planet ID to the flight simulation")
	viewport.queue_free()
	await process_frame


func _approach(focus: int, port: int, extra_clearance: float) -> Flight:
	var flight := Flight.new()
	var system := Catalog.system_of_site(focus)
	var saved := flight.snapshot()
	if system == Catalog.HEATHER_SYSTEM:
		saved.expedition.projects[0] = {"phase": Expedition.COMPLETE, "sponsor_port": 0, "sponsor": 0,
			"scan_index": Expedition.SURVEY_TOTAL, "build_index": Expedition.BUILD_TOTAL}
		var fronts := FactionFronts.new()
		fronts.commission(system, 0, 0.0)
		saved.factions = fronts.snapshot()
		flight.freight.activate_frontier(system, 0.0)
		saved.freight = flight.freight.snapshot()
	var dock := flight.docking_position(port)
	saved.merge({"system_id": system, "docked": port, "target": port, "position": [dock.x, dock.y, dock.z]}, true)
	_expect(flight.restore(saved) and Fixture.launch(flight), "Launch a ship in the system with orbital focus %d" % focus)
	var center := flight.target_position(focus)
	var primary := flight.target_position(Catalog.star_for(system))
	var normal := center.direction_to(primary)
	var outward := normal.cross(Vector3.UP).normalized()
	var tangent := normal.cross(outward).normalized()
	var band := flight.orbit_status(focus)
	flight.position = center + outward * (float(band.approach_min) + extra_clearance)
	var circular: float = flight.orbit_status(focus).circular_speed
	flight.velocity = flight.target_velocity(focus) + tangent * circular * 0.84 + outward * 0.32
	flight.yaw = 0.0
	flight.pitch = 0.0
	flight.roll = 0.0
	return flight


func _tick(flight: Flight, delta: float = STEP) -> void:
	flight.update(delta, Vector2.ZERO, 0.0, false, false)


func _json(state: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(state, "", true, true)) as Dictionary


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
