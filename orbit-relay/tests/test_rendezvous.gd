extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Ephemeris := preload("res://scripts/orbit_ephemeris.gd")
const Terrain := preload("res://scripts/surface_terrain.gd")
const OrbitRelay := preload("res://main.tscn")
const PORT := 1
const MOON := 6
const STEP := 1.0 / 60.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_stern_approach()
	_test_surface_after_star_detour()
	_test_reserve_speed_and_jump()
	_test_denial_and_save()
	await _test_chart_to_hud()
	print("Rendezvous integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_stern_approach() -> void:
	var flight := _approach_station()
	var before := flight.snapshot()
	var preview := flight.rendezvous_status(PORT, 150)
	var offset: Vector3 = preview.point - flight.target_position(PORT)
	var expected: Vector3 = Ephemeris.sample(PORT, flight.orbit_time + float(preview.eta)).position + offset
	_expect(preview.site == PORT and preview.allowed and preview.has_point and preview.eta > 5.0
		and absf(offset.length() - float(Catalog.site(PORT).radius) - 150.0) < 0.02
		and expected.distance_to(preview.predicted) < 0.02 and offset.z > 150.0
		and preview.point.distance_to(preview.predicted) > 5.0 and flight.snapshot() == before,
		"Station preview uses the future ephemeris and a 150-metre gap outside the hull without modifying flight")
	var begin := flight.position
	var begin_velocity := flight.velocity
	if not _expect(flight.start_rendezvous(PORT, 150) and flight.rendezvous_active
		and not flight.autopilot and flight.position == begin and flight.velocity == begin_velocity
		and flight.target == PORT and not flight.finish_rendezvous(),
		"Starting selects the moving station without immediately changing motion or allowing docking handoff"):
		return
	var radius := INF
	var starting_height := flight.position.y - flight.target_position(PORT).y
	for _frame in range(roundi(130.0 / STEP)):
		if not flight.rendezvous_active or flight.rendezvous_status().phase == "hold":
			break
		_tick(flight)
		radius = minf(radius, flight.position.distance_to(flight.target_position(PORT)))
	var hold := flight.rendezvous_status()
	if not _expect(hold.phase == "hold" and hold.can_finish and hold.eta == 0.0
		and flight.docked < 0 and not flight.landed and not flight.autopilot
		and flight.ship.hull == 100.0 and radius > 31.5 and starting_height < -65.0
		and absf(flight.position.y - flight.target_position(PORT).y) < 5.0
		and (flight.position - flight.target_position(PORT)).z > 175.0,
		"The stern approach crosses height and station sides clear of the hull, then holds outside docking range (%s, %.1f m)" % [flight.status_message, radius]):
		return
	var old_center := flight.target_position(PORT)
	_tick(flight, 25.0)
	var aligned := flight.rendezvous_status()
	_expect(flight.rendezvous_active and aligned.phase == "hold" and aligned.can_finish
		and flight.target_position(PORT).distance_to(old_center) > 30.0
		and flight.position.distance_to(aligned.point) < 2.5 and flight.speed_relative_to(PORT) < 0.8
		and flight.docked < 0,
		"Stand-off mode follows the station's translating ephemeris for 25 seconds without docking")
	if not _expect(flight.finish_rendezvous() and not flight.rendezvous_active
		and flight.target == PORT and flight.autopilot,
		"A separate command hands the matching flight over to the normal docking autopilot"):
		return
	_expect(_wait_for_autopilot(flight) and flight.docked == PORT and absf(flight.roll_error(PORT)) < 0.02,
		"The standard docking program matches the station's rotation and completes the approach")


func _test_surface_after_star_detour() -> void:
	var flight := Flight.new()
	flight.dock_action()
	flight.orbit_time = 80.0
	var star := flight.target_position(Catalog.STAR_ID)
	var moon := flight.target_position(MOON)
	var plane := star.direction_to(moon)
	flight.position = star - plane * 850.0
	flight.velocity = Vector3.ZERO
	var preview := flight.rendezvous_status(MOON, 300)
	var radius := float(Catalog.site(MOON).radius) * Terrain.MAX_RADIUS_FACTOR + Terrain.CONTACT_CLEARANCE
	_expect(preview.allowed and absf(preview.point.distance_to(moon) - radius - 300.0) < 0.02,
		"A landable body preview uses its conservative terrain envelope plus the selected 300 metres")
	if not _expect(flight.start_rendezvous(MOON, 300), "Start a long moving-moon rendezvous on the far side of the star"):
		return
	var minimum_star_distance := INF
	for _frame in range(roundi(165.0 / STEP)):
		if not flight.rendezvous_active or flight.rendezvous_status().phase == "hold":
			break
		_tick(flight)
		minimum_star_distance = minf(minimum_star_distance, flight.position.distance_to(star))
	if not _expect(flight.rendezvous_status().can_finish and minimum_star_distance >= Catalog.SCOOP_INNER - 1.0
		and flight.ship.hull == 100.0 and not flight.landed and flight.position.distance_to(flight.target_position(MOON)) > radius + 294.0,
		"The long approach detours around the stellar exclusion and settles outside the moon's terrain shell (%s, %.1f m)" % [
			flight.status_message, minimum_star_distance,
		]):
		return
	if not _expect(flight.finish_rendezvous() and flight.autopilot and flight.target == MOON,
		"The surface rendezvous hands off explicitly to the existing landing program"):
		return
	_expect(_wait_for_autopilot(flight) and flight.landed_site == MOON and flight.ship.hull == 100.0 and flight.dock_action(),
		"The moon landing and subsequent takeoff remain fully playable")


func _test_reserve_speed_and_jump() -> void:
	var flight := _approach_station()
	var normal_eta: float = flight.rendezvous_status(PORT, 600).eta
	flight.ship.fuel = 0.0
	var reserve_eta: float = flight.rendezvous_status(PORT, 600).eta
	if not _expect(reserve_eta > normal_eta * 1.8 and flight.start_rendezvous(PORT, 600),
		"An empty tank uses the reserve-drive interception estimate and can still start"):
		return
	var peak := 0.0
	for _frame in range(roundi(150.0 / STEP)):
		if not flight.rendezvous_active or flight.rendezvous_status().phase == "hold":
			break
		_tick(flight)
		peak = maxf(peak, flight.speed_relative_to(PORT))
	_expect(flight.rendezvous_status().can_finish and flight.ship.fuel == 0.0 and peak <= Flight.RESERVE_SPEED + 4.0
		and peak > 12.0 and flight.position.distance_to(flight.target_position(PORT)) >= 625.0,
		"Reserve propulsion reaches the moving station's 600-metre hold with bounded speed and zero fuel")
	flight = _approach_station()
	var fuel := flight.ship.fuel
	var destination := Catalog.VELAR_SYSTEM
	var fare := Catalog.jump_cost(flight.system_id, destination)
	if not _expect(flight.start_rendezvous(PORT, 600) and flight.plan_jump(destination) and flight.start_jump()
		and not flight.rendezvous_active and flight.jump_seconds_left > 0.0,
		"A valid interstellar departure interrupts an active rendezvous before charging"):
		return
	_tick(flight, 3.0)
	_expect(flight.system_id == destination and is_equal_approx(flight.ship.fuel, fuel - fare)
		and not flight.rendezvous_active,
		"The jump completes normally with its own fuel charge and no lingering pursuit")


func _test_denial_and_save() -> void:
	var parked := Flight.new()
	_expect(not parked.start_rendezvous(PORT, 150), "Rendezvous cannot start while parked")
	var flight := _approach_station()
	for invalid: int in [Catalog.STAR_ID, 10, 999]:
		_expect(not flight.rendezvous_status(invalid, 150).allowed and not flight.start_rendezvous(invalid, 150),
			"A star, remote port or nonexistent site is not a local rendezvous target (%d)" % invalid)
	var frontier := Flight.new()
	var jumped := frontier.project_action() and frontier.dock_action()
	frontier.change_throttle(0.25)
	for _frame in range(roundi(8.0 / STEP)):
		if frontier.jump_status(Catalog.HEATHER_SYSTEM).ok:
			break
		_tick(frontier)
	jumped = jumped and frontier.start_jump()
	_tick(frontier, 3.0)
	_expect(jumped and frontier.system_id == Catalog.HEATHER_SYSTEM and frontier.system_known(Catalog.HEATHER_SYSTEM)
		and not frontier.station_operational(Catalog.HEATHER_PORT)
		and not frontier.start_rendezvous(Catalog.HEATHER_PORT, 300),
		"Even after jumping into the discovered system, an uncommissioned station cannot be used to rendezvous")
	if not _expect(flight.start_rendezvous(PORT, 150), "Prepare a real rendezvous that can be saved and manually cancelled"):
		return
	_tick(flight, 2.0)
	var state := JSON.parse_string(JSON.stringify(flight.snapshot(), "", true, true)) as Dictionary
	var clone := Flight.new()
	if _expect(clone.restore(state) and not clone.rendezvous_active and clone.rendezvous_status().phase == "idle"
		and clone.position.distance_to(flight.position) < 0.001 and clone.velocity.distance_to(flight.velocity) < 0.001,
		"Cold reload keeps the in-flight position and momentum and clears the helper"):
		var saved_fuel := clone.ship.fuel
		_tick(clone, 1.0)
		_expect(clone.ship.fuel == saved_fuel, "Reloaded flight does not resume automated thrust")
	flight.update(STEP, Vector2.ZERO, 0.0, false, false, Vector3.UP)
	_expect(not flight.rendezvous_active and not flight.finish_rendezvous(),
		"Manual translation cancels rendezvous immediately and removes the handoff")
	if not _expect(flight.start_rendezvous(PORT, 150), "Prepare a second approach for explicit cancellation"):
		return
	_expect(flight.cancel_rendezvous() and not flight.rendezvous_active and not flight.cancel_rendezvous(),
		"The cancel command is safe to repeat")


func _test_chart_to_hud() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := OrbitRelay.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = _approach_station()
	game._update_display(0.0)
	await process_frame
	_tap(viewport, game._hud._actions["map"], "Open the actual sector chart through touch")
	await process_frame
	_tap(viewport, game._map._site_buttons[PORT], "Preview a moving station through touch")
	await process_frame
	_tap(viewport, game._map._rendezvous_button, "Open the rendezvous panel")
	await process_frame
	_tap(viewport, game._map._rendezvous_gap_buttons[300], "Choose the 300-metre gap in the chart")
	await process_frame
	_expect(game.flight.target == 2, "Chart preview preserves the existing navigation destination until confirmation")
	_tap(viewport, game._map._rendezvous_action, "Start the approach from touch")
	await process_frame
	if _expect(game.flight.rendezvous_active and not game._map.is_open() and game.flight.rendezvous_status().site == PORT
		and game.flight.rendezvous_status().gap == 300 and game.flight.target == PORT,
		"Confirming the chart action selects the station and starts a rendezvous at the chosen gap"):
		var flight: Flight = game.flight
		for _frame in range(roundi(130.0 / STEP)):
			if not flight.rendezvous_active or flight.rendezvous_status().phase == "hold":
				break
			_tick(flight)
		game._update_display(0.0)
		await process_frame
		var finish: Button = game._hud._actions["rendezvous_finish"]
		_tap(viewport, finish, "Request the normal docking approach through the hold HUD")
		await process_frame
		_expect(game.flight.autopilot and game.flight.target == PORT and not game.flight.rendezvous_active,
			"The hold-specific touch action switches to the regular docking program")
	viewport.queue_free()
	await process_frame


func _approach_station() -> Flight:
	var flight := Flight.new()
	flight.dock_action()
	flight.orbit_time = 340.0
	flight.select_target(2)
	flight.position = flight.target_position(PORT) + Vector3(4.0, -96.0, -540.0)
	flight.velocity = flight.target_velocity(PORT) + Vector3.BACK * 18.0
	return flight


func _wait_for_autopilot(flight: Flight) -> bool:
	for _frame in range(roundi(160.0 / STEP)):
		if not flight.autopilot:
			return true
		_tick(flight)
	return false


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
