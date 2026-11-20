extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Atmosphere := preload("res://scripts/atmosphere.gd")
const Navigation := preload("res://scripts/orbital_navigation.gd")
const Terrain := preload("res://scripts/surface_terrain.gd")
const OrbitRelay := preload("res://main.tscn")
const PLANET := Catalog.TERRACE_ID
const STEP := 1.0 / 60.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_profiles_and_vacuum()
	_test_grazing_entry()
	_test_forecast()
	_test_time_and_landing()
	_test_offpad_landing()
	_test_hot_saves()
	await _test_hud()
	print("Atmospheric entry integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_profiles_and_vacuum() -> void:
	for profile: Vector2i in [Vector2i(PLANET, 46), Vector2i(Catalog.HEATHER_PLANET, 38), Vector2i(Catalog.LIMIT_PLANET, 41)]:
		var air := Atmosphere.profile(profile.x)
		_expect(not air.is_empty() and is_equal_approx(float(air.height), float(profile.y)) and air.density > 0.0,
			"The planet has its expected atmospheric profile (%d)" % profile.x)
	_expect(Atmosphere.profile(Catalog.STAR_ID).is_empty() and Atmosphere.profile(2).is_empty()
		and Atmosphere.profile(12).is_empty(), "Stars, asteroids and airless moons do not become atmosphere sources")
	var flight := _launch()
	var nominal := float(Catalog.site(PLANET).radius)
	flight.position = flight.target_position(PLANET) + Vector3.BACK * (nominal + 180.0)
	flight.velocity = flight.target_velocity(PLANET) + Vector3.UP * 50.0
	var origin := flight.position
	var velocity := flight.velocity
	var fuel := flight.ship.fuel
	_tick(flight, 2.0)
	var outside := flight.atmosphere_status()
	_expect(not outside.inside and not outside.near and outside.density == 0.0 and flight.entry_heat == 0.0
		and flight.velocity.distance_to(velocity) < 0.16 and flight.position.distance_to(origin + velocity * 2.0) < 0.4
		and flight.ship.fuel == fuel,
		"Outside the shell the unpowered ship keeps its ballistic coast without drag or entry heating")


func _test_grazing_entry() -> void:
	var flight := _grazing(175.0)
	var initialized := flight.atmosphere_status()
	var fuel := flight.ship.fuel
	var altitude := flight.position.distance_to(flight.target_position(PLANET)) - Terrain.radius_at(PLANET, Vector3.RIGHT)
	if not _expect(initialized.site == PLANET and initialized.inside and initialized.near and initialized.visible
		and initialized.density > 0.0 and is_equal_approx(initialized.safe_speed, 38.0)
		and absf(initialized.altitude - altitude) < 0.02 and absf(initialized.vertical_speed) < 0.02,
		"Entry instruments show the actual terrain altitude and speed relative to the moving planet"):
		return
	var peak := 0.0
	for _frame in range(roundi(2.0 / STEP)):
		_tick(flight)
		peak = maxf(peak, flight.entry_heat)
	_expect(peak > 24.0 and not flight.atmosphere_status().inside and flight.speed_relative_to(PLANET) < 172.0
		and flight.speed_relative_to(PLANET) > 38.0 and flight.ship.fuel == fuel and flight.star_heat == 0.0,
		"A genuine high-speed pass warms and slows in the moving gas without fuel use or stellar heat")
	var warm := _grazing(196.0, 72.0)
	var minimum_altitude := INF
	var thermal_burst := false
	for _frame in range(roundi(1.3 / STEP)):
		_tick(warm)
		minimum_altitude = minf(minimum_altitude, float(warm.atmosphere_status().altitude))
		thermal_burst = thermal_burst or warm.entry_heat >= 85.0
	_expect(thermal_burst and minimum_altitude > Terrain.CONTACT_CLEARANCE + 2.0 and warm.ship.hull < 100.0
		and warm.ship.hull > 80.0 and not warm.atmosphere_status().inside,
		"A second pass with a warm hull causes thermal damage while remaining well clear of terrain")
	var retreat_heat := warm.entry_heat
	var retreat_speed := warm.velocity.length()
	_tick(warm, 16.0)
	_expect(warm.entry_heat < 1.0 and warm.entry_heat < retreat_heat and warm.velocity.length() > retreat_speed - 1.2,
		"After leaving the air the ship cools, and its surviving momentum is no longer aerodynamically braked")


func _test_forecast() -> void:
	var flight := _grazing(145.0)
	var position := flight.position
	var velocity := flight.velocity
	var state := flight.snapshot()
	const DURATION := 2.0
	var predicted := Navigation.forecast(flight, DURATION, PLANET)
	var points: PackedVector3Array = predicted.points
	if not _expect(predicted.impact == -1 and is_equal_approx(predicted.seconds, DURATION)
		and points.size() > 4 and flight.snapshot() == state,
		"The short sector forecast can model a high-speed atmosphere crossing without mutating the ship"):
		return
	_tick(flight, DURATION)
	var vacuum_end := position + velocity * DURATION
	var simulated_loss := flight.position.distance_to(vacuum_end)
	_expect(simulated_loss > 2.4 and points[-1].distance_to(flight.position) < simulated_loss * 0.45,
		"The forecast follows real atmospheric drag more closely than a straight vacuum extrapolation")


func _test_time_and_landing() -> void:
	var flight := _launch()
	var r := float(Catalog.site(PLANET).radius)
	var height: float = Atmosphere.profile(PLANET).height
	flight.position = flight.target_position(PLANET) + Vector3.BACK * (r + height + Atmosphere.NEAR_MARGIN + 5.0)
	flight.velocity = flight.target_velocity(PLANET) + Vector3.FORWARD * 25.0
	if _expect(not flight.atmosphere_status().near and flight.cycle_time_scale() and flight.cycle_time_scale() and flight.time_scale == 16,
		"Time acceleration is allowed before the atmosphere approach margin"):
		var epoch := flight.orbit_time
		_tick(flight, 1.0)
		_expect(flight.time_scale == 1 and flight.orbit_time - epoch < 3.0 and flight.atmosphere_status().near
			and not flight.atmosphere_status().inside and not flight.cycle_time_scale(),
			"The flight clock drops to real time on entry to the approach margin, before air is encountered")
	flight = _launch()
	flight.position = flight.target_position(PLANET) + Vector3(155.0, -90.0, 580.0)
	flight.velocity = Vector3.ZERO
	flight.set_autopilot(true)
	var inside := false
	var maximum := 0.0
	var peak_heat := 0.0
	for _frame in range(roundi(140.0 / STEP)):
		if not flight.autopilot:
			break
		_tick(flight)
		var entry := flight.atmosphere_status()
		if entry.inside and not flight.landed:
			inside = true
			maximum = maxf(maximum, float(entry.relative_speed))
			peak_heat = maxf(peak_heat, flight.entry_heat)
	if not _expect(inside and maximum <= 41.0 and flight.landed_site == PLANET and not flight.landed_offpad()
		and flight.ship.hull == 100.0 and peak_heat < 12.0,
		"The actual autopilot decelerates before entering the atmosphere and lands safely (%s, %.1f m/s)" % [
			flight.status_message, maximum,
		]):
		return
	_expect(not flight.atmosphere_status().visible and flight.cycle_time_scale() and flight.cycle_time_scale() and flight.time_scale == 16,
		"Landing suppresses the entry warning and restores access to accelerated time")
	var epoch := flight.orbit_time
	_tick(flight, 0.5)
	_expect(is_equal_approx(flight.orbit_time - epoch, 8.0) and flight.landed_site == PLANET,
		"A parked ship advances ground time normally while inside the atmosphere")
	if _expect(flight.dock_action() and not flight.landed and flight.time_scale == 1,
		"The normal takeoff button remains available inside the atmosphere"):
		_tick(flight)
		_expect(flight.atmosphere_status().inside and flight.atmosphere_status().vertical_speed > 4.0
			and flight.ship.hull == 100.0, "Takeoff retains an outward vertical speed and no excessive heat")


func _test_offpad_landing() -> void:
	var direction := Vector3.RIGHT
	for candidate: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3(0.8, 0.1, 0.6).normalized()]:
		if Terrain.landable(PLANET, candidate) and absf(Terrain.normal(PLANET, candidate).y) < 0.85:
			direction = candidate
			break
	var flight := _launch()
	var inward := -Terrain.normal(PLANET, direction)
	flight.position = flight.target_position(PLANET) + Terrain.point(PLANET, direction) + direction * 15.0
	flight.velocity = flight.target_velocity(PLANET) - direction * 2.1
	flight.yaw = atan2(-inward.x, -inward.z)
	flight.pitch = asin(inward.y)
	flight.gear_action()
	if not _expect(flight.atmosphere_status().inside and flight.atmosphere_status().vertical_speed < -1.8,
		"A manual off-pad approach senses its actual low-speed descent in the atmosphere"):
		return
	for _frame in range(roundi(8.0 / STEP)):
		if flight.surface_status().ok:
			break
		_tick(flight)
	if not _expect(flight.dock_action() and flight.landed_offpad() and flight.landed_site == PLANET
		and flight.landing_direction.dot(direction) > 0.99 and flight.ship.hull == 100.0 and flight.entry_heat < 2.0,
		"A controlled slow descent lands safely on the chosen terrain patch"):
		return
	if _expect(flight.dock_action() and not flight.landed, "The ship can lift off again from the off-pad ground"):
		_tick(flight)
		_expect(flight.atmosphere_status().inside and flight.atmosphere_status().vertical_speed > 3.0,
			"The craft climbs through the atmosphere after the off-pad lift")


func _test_hot_saves() -> void:
	var hot := _grazing(145.0, 51.7)
	hot.star_heat = 12.4
	hot.credits = 318
	var state := JSON.parse_string(JSON.stringify(hot.snapshot(), "", true, true)) as Dictionary
	var resumed := Flight.new()
	if not _expect(state.schema == Flight.SAVE_SCHEMA and resumed.restore(state) and is_equal_approx(resumed.entry_heat, hot.entry_heat)
		and is_equal_approx(resumed.star_heat, hot.star_heat) and resumed.velocity.distance_to(hot.velocity) < 0.001,
		"Cold restarts preserve atmospheric and stellar heat independently with existing momentum"):
		return
	var live := resumed.snapshot()
	for bad: Variant in [-1, 101, "51.7", INF]:
		var corrupt := state.duplicate(true)
		corrupt.entry_heat = bad
		_expect(not resumed.restore(corrupt) and resumed.snapshot() == live,
			"Malformed atmospheric heat is rejected without affecting the loaded state")
	var previous := state.duplicate(true)
	previous.schema = 13
	previous.erase("entry_heat")
	previous.ship.erase("heat_shield")
	_expect(resumed.restore(previous) and resumed.entry_heat == 0.0 and is_equal_approx(resumed.star_heat, 12.4)
		and resumed.credits == 318 and resumed.system_id == Catalog.VELAR_SYSTEM,
		"Schema-13 saves migrate with a cool shield while retaining existing stellar heat and ship progress")


func _test_hud() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := OrbitRelay.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = _grazing(173.0, 89.0)
	game._update_display(0.0)
	await process_frame
	_expect(game._hud._entry_readout.is_visible_in_tree() and Catalog.site(PLANET).name in game._hud._entry_readout.text
		and game._hud._thermal_label.text.begins_with("Критический нагрев")
		and is_equal_approx(game._hud._thermal_level.value, 89.0) and "38" in game._hud._guidance.text,
		"Actual flight HUD shows body, atmospheric heat and entry braking guidance")
	game.flight = _launch()
	game.flight.position = Vector3(4300.0, 5100.0, 5300.0)
	game._update_display(0.0)
	await process_frame
	_expect(not game._hud._entry_readout.is_visible_in_tree() and not game._hud._thermal_panel.is_visible_in_tree(),
		"Entry readouts clear on transition to a cool, distant flight")
	viewport.queue_free()
	await process_frame


func _launch() -> Flight:
	var flight := Flight.new()
	var state := flight.snapshot()
	var dock := flight.docking_position(10)
	state.merge({"system_id": Catalog.VELAR_SYSTEM, "docked": 10, "target": 10,
		"position": [dock.x, dock.y, dock.z]}, true)
	_expect(flight.restore(state) and flight.dock_action() and flight.select_target(PLANET) and flight.set_flight_assist(false),
		"Launch a normal ship in the atmosphere test system")
	return flight


func _grazing(speed: float, retained_heat := 0.0) -> Flight:
	var flight := _launch()
	var safe_periapsis := float(Catalog.site(PLANET).radius) * Terrain.MAX_RADIUS_FACTOR + Terrain.CONTACT_CLEARANCE + 4.0
	flight.position = flight.target_position(PLANET) + Vector3.RIGHT * safe_periapsis
	flight.velocity = flight.target_velocity(PLANET) + Vector3.UP * speed
	flight.entry_heat = retained_heat
	return flight


func _tick(flight: Flight, delta: float = STEP) -> void:
	flight.update(delta, Vector2.ZERO, 0.0, false, false)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
