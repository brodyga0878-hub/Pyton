extends SceneTree

const Flight = preload("res://scripts/flight_sim.gd")
const Orbit = preload("res://scripts/orbit_ephemeris.gd")
const Catalog = preload("res://scripts/sector_catalog.gd")
const Rig = preload("res://scripts/mining_rig.gd")
const OrbitRelay = preload("res://main.tscn")
const STEP := 1.0 / 60.0
const EPOCH := 480.0
const MOON := 12

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_ephemeris()
	_test_moving_contacts()
	_test_time_flow()
	_test_warp_interlocks()
	_test_save_and_migration()
	_test_shifted_routes()
	_test_moving_obstacle_detours()
	await _test_time_button()
	print("Orbital integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_ephemeris() -> void:
	for site in range(Catalog.DESTINATION_COUNT):
		var initial := Orbit.sample(site, 0.0)
		var future := Orbit.sample(site, EPOCH)
		var path := Orbit.orbit_points(site)
		_expect(initial.position == Catalog.site(site).center,
			"Site %d matches the exact catalog position at the epoch" % site)
		if site == Catalog.star_for(Catalog.system_of_site(site)):
			_expect(future.position == initial.position and future.velocity == Vector3.ZERO and path.is_empty(),
				"Star %d remains at the focus with no moving orbit" % site)
			continue
		var previous: Vector3 = Orbit.sample(site, EPOCH - 0.25).position
		var following: Vector3 = Orbit.sample(site, EPOCH + 0.25).position
		var derivative := (following - previous) / 0.5
		_expect(future.position.distance_to(initial.position) > 50.0 and future.velocity.length() > 0.2,
			"Moving site %d changes position and carries local orbital velocity" % site)
		_expect(derivative.distance_to(future.velocity) < 0.04,
			"Site %d analytic velocity agrees with the central position derivative" % site)
		_expect(path.size() >= 48 and path[0].is_equal_approx(path[-1]),
			"Site %d supplies a closed orbital path to the local chart" % site)
		var after_orbit := Orbit.sample(site, Orbit.period(site))
		_expect(initial.position.distance_to(after_orbit.position) < 0.005
			and initial.velocity.distance_to(after_orbit.velocity) < 0.001,
			"Site %d returns to its epoch state after a complete orbit" % site)


func _test_moving_contacts() -> void:
	var flight := _parked(0)
	flight.dock_action()
	flight.select_target(1)
	var gate := flight.target_gate(1)
	var eta := flight.intercept_time(1)
	_expect(eta > 0.0 and is_finite(eta)
		and gate.distance_to(Orbit.sample(1, flight.orbit_time + eta).position + Vector3.BACK * 70.0) > 0.5,
		"An intercept estimate advances the moving gate past its present position")
	flight.position = flight.target_contact(1) + Vector3.BACK * 3.0
	flight.yaw = 0.0
	flight.roll = flight.station_angle(1)
	flight.velocity = flight.target_velocity(1) + Vector3.FORWARD * 5.7
	_expect(flight.reference_site() == 1 and is_equal_approx(flight.relative_speed(), 5.7)
		and not flight.dock_action(), "Docking uses speed relative to the moving station")
	flight.velocity = flight.target_velocity(1)
	flight.roll += 0.4
	_expect(not flight.dock_action() and is_zero_approx(flight.relative_speed()),
		"Matching the station's translation still requires matching its roll")
	flight.roll = flight.station_angle(1)
	_expect(flight.dock_action() and flight.docked == 1, "Aligned contact with the moving station docks")
	var first := flight.position
	_step(flight, 4.0)
	_expect(flight.position.distance_to(first) > 0.7 and flight.position == flight.target_contact(1)
		and is_equal_approx(flight.roll, flight.station_angle(1)) and is_zero_approx(flight.relative_speed()),
		"A docked ship follows the orbit and rotation of its station")
	var reference_velocity := flight.target_velocity(1)
	_expect(flight.dock_action() and flight.velocity.distance_to(reference_velocity + Vector3.BACK * 6.0) < 0.02,
		"Launching from a station retains its inertial velocity")

	var surface := _parked(10)
	surface.dock_action()
	surface.select_target(MOON)
	surface.position = surface.target_contact(MOON) + Vector3.BACK * 3.0
	surface.yaw = 0.0
	surface.velocity = surface.target_velocity(MOON) + Vector3.FORWARD * 4.5
	_expect(not surface.dock_action(), "Touchdown rejects excessive speed relative to the moon")
	surface.velocity = surface.target_velocity(MOON) + Vector3.FORWARD * 2.0
	_expect(surface.dock_action() and surface.landed_site == MOON, "A slow relative approach lands on the moving moon")
	var before := surface.position
	_step(surface, 4.0)
	_expect(surface.position.distance_to(before) > 0.7 and surface.position == surface.target_contact(MOON)
		and surface.reference_site() == MOON and is_zero_approx(surface.relative_speed()),
		"The landed ship keeps contact on the translating surface")
	var lunar_velocity := surface.target_velocity(MOON)
	_expect(surface.dock_action() and surface.velocity.distance_to(lunar_velocity + Vector3.BACK * 9.0) < 0.02,
		"Takeoff inherits the moving surface's orbital velocity")


func _test_time_flow() -> void:
	var slow := _clear_flight()
	var fast := _clear_flight()
	for flight in [slow, fast]:
		flight.change_throttle(0.42)
	_expect(fast.cycle_time_scale() and fast.time_scale == 4 and fast.cycle_time_scale() and fast.time_scale == 16,
		"Open cruise can switch through 4× and 16×")
	_step(slow, 16.0)
	_step(fast, 1.0)
	_expect(is_equal_approx(slow.orbit_time, fast.orbit_time) and is_equal_approx(slow.elapsed, fast.elapsed)
		and slow.position.distance_to(fast.position) < 0.02 and slow.velocity.distance_to(fast.velocity) < 0.01
		and absf(slow.ship.fuel - fast.ship.fuel) < 0.0001 and fast.ship.fuel < 100.0,
		"One 16× real second is equivalent to sixteen 1× seconds for cruise and fuel")
	_expect(fast.cycle_time_scale() and fast.time_scale == 1, "The next tap returns 16× to normal time")

	var mining := _parked(MOON)
	var reserve := mining.mining.reserve_at(MOON)
	mining.mine_action()
	mining.cycle_time_scale()
	mining.cycle_time_scale()
	_step(mining, 1.0)
	_expect(mining.landed and mining.mining.phase == Rig.READY and mining.mining.pending_ore == 12
		and mining.mining.ore_hold == 0 and mining.position == mining.target_contact(MOON),
		"A 16× parked second completes drilling while the ship follows the moon")
	mining.mine_action()
	_step(mining, 1.0)
	_expect(mining.mining.phase == Rig.STOWED and mining.mining.reserve_at(MOON) == reserve - 12
		and mining.mining.ore_hold == 12 and mining.ship.fuel == 100.0,
		"Accelerated recovery transfers the batch once without consuming flight fuel")
	_step(mining, 1.0)
	_expect(mining.mining.ore_hold == 12 and mining.mining.reserve_at(MOON) == reserve - 12,
		"Subsequent accelerated ticks cannot recover the same cargo again")


func _test_warp_interlocks() -> void:
	var flight := _clear_flight()
	flight.cycle_time_scale()
	flight.cycle_time_scale()
	flight.change_throttle(0.1)
	_expect(flight.time_scale == 1, "A manual throttle change restores 1×")
	for input in [Vector2.RIGHT, Vector2.ZERO]:
		flight.cycle_time_scale()
		flight.cycle_time_scale()
		var before := flight.orbit_time
		flight.update(STEP, input, 0.0, false, input == Vector2.ZERO)
		_expect(flight.time_scale == 1 and is_equal_approx(flight.orbit_time - before, STEP),
			"Manual steering and emergency brake each restore 1× before stepping")
	var close := _parked(0)
	close.dock_action()
	_expect(not close.time_status().allowed and not close.cycle_time_scale() and close.time_scale == 1,
		"Accelerated time cannot be armed beside the launch station")
	close.select_target(1)
	close.position = close.target_position(1) + Vector3.BACK * (float(Catalog.site(1).radius) + 111.0)
	close.yaw = 0.0
	close.velocity = Vector3.FORWARD * 130.0
	close.change_throttle(1.0)
	close.cycle_time_scale()
	close.cycle_time_scale()
	var elapsed := close.orbit_time
	close.update(STEP, Vector2.ZERO, 0.0, false, false)
	_expect(close.time_scale == 1 and close.orbit_time - elapsed < 16.0 * STEP and not close.time_status().allowed,
		"An approach entering the safety zone cannot consume the remaining accelerated substeps")

	var jump := _clear_flight()
	jump.cycle_time_scale()
	jump.cycle_time_scale()
	jump.plan_jump(Catalog.VELAR_SYSTEM)
	var jump_started := jump.start_jump()
	jump.update(STEP, Vector2.ZERO, 0.0, false, false)
	_expect(jump_started and jump.time_scale == 1 and not jump.time_status().allowed
		and is_equal_approx(jump.jump_seconds_left, Flight.JUMP_CHARGE - STEP),
		"Jump charging runs in real time and disallows acceleration")
	var scoop := _clear_flight()
	scoop.cycle_time_scale()
	scoop.cycle_time_scale()
	scoop.ship.fuel = 50.0
	scoop.position = scoop.target_contact(Catalog.STAR_ID)
	var scoop_started := scoop.scoop_action()
	scoop.update(STEP, Vector2.ZERO, 0.0, false, false)
	_expect(scoop_started and scoop.time_scale == 1 and not scoop.time_status().allowed
		and is_equal_approx(scoop.ship.fuel, 50.0 + Flight.SCOOP_RATE * STEP),
		"Fuel collection cannot accelerate its intake rate")


func _test_save_and_migration() -> void:
	# Captured independently from the v5 format, before a separate orbital epoch existed.
	var previous := {
		"schema": 5, "position": [620.0, -95.0, -782.0], "velocity": [0.0, 0.0, 0.0],
		"yaw": 0.0, "pitch": 0.0, "roll": 0.0, "elapsed": 825.0, "throttle": 0.0,
		"docked": -1, "landed_site": MOON, "target": MOON, "planned_target": 11,
		"system_id": Catalog.VELAR_SYSTEM, "jump_target": Catalog.HOME_SYSTEM,
		"credits": 480, "deliveries": 2, "contract_stage": 0, "contract_origin": -1,
		"contract_destination": -1,
		"ship": {"fuel": 83.0, "tank_upgraded": false, "eco_upgraded": true},
		"mining": {
			"site_id": MOON, "phase": Rig.DRILLING, "phase_seconds": 8.0, "pending_ore": 0,
			"cargo": {"ore": 0, "crystal": 0, "ice": 0},
			"reserves": [0, 0, 120, 0, 96, 180, 156, 132, 216, 0, 0, 0, 192, 144, 0],
		},
	}
	var flight := Flight.new()
	_expect(flight.restore(_round_trip(previous)) and flight.orbit_time == 0.0 and flight.elapsed == 825.0
		and flight.landed_site == MOON and flight.position == Vector3(620.0, -95.0, -782.0)
		and flight.jump_target == Catalog.HOME_SYSTEM and flight.mining.phase_seconds == 8.0
		and flight.ship.fuel == 83.0 and flight.ship.eco_upgraded,
		"A v5 landing keeps its full progress and begins orbits at the legacy position")
	flight.cycle_time_scale()
	_step(flight, 1.0)
	var saved := flight.snapshot()
	var resumed := Flight.new()
	_expect(resumed.restore(_round_trip(saved)) and resumed.snapshot() == saved and resumed.time_scale == 1
		and resumed.orbit_time > 0.0 and resumed.position == resumed.target_contact(MOON)
		and resumed.mining.phase == Rig.READY,
		"A v6 landing restores orbital phase and mining without resuming acceleration")
	var invalid := saved.duplicate(true)
	invalid.orbit_time += EPOCH
	_expect(not resumed.restore(invalid) and resumed.snapshot() == saved,
		"Restore rejects a landing pose from another epoch without changing the live state")
	invalid = saved.duplicate(true)
	invalid.orbit_time = -1.0
	_expect(not resumed.restore(invalid) and resumed.snapshot() == saved,
		"A negative orbital epoch is rejected atomically")
	var airborne := _clear_flight()
	airborne.change_throttle(0.37)
	airborne.cycle_time_scale()
	_step(airborne, 2.0)
	var cruise := airborne.snapshot()
	_expect(resumed.restore(_round_trip(cruise)) and resumed.snapshot() == cruise and resumed.time_scale == 1,
		"Cold restore in free flight retains inertial velocity, throttle, fuel and orbital positions")
	_expect(resumed.target_position(1).distance_to(airborne.target_position(1)) < 0.001,
		"The saved epoch reproduces the moving position of targets after a cold restart")


func _test_shifted_routes() -> void:
	for system in range(Catalog.SYSTEM_COUNT):
		var destinations := Catalog.targets_for(system)
		for origin: int in destinations:
			for destination: int in destinations:
				if origin == destination:
					continue
				var flight := _parked(origin)
				var result := _fly_route(flight, destination)
				_expect(result.arrived, "Epoch %.0f, route %d → %d reaches its moving destination (%s at %s)"
					% [EPOCH, origin, destination, flight.status_message, flight.position])


func _test_moving_obstacle_detours() -> void:
	for scenario in [Vector2i(180, 3), Vector2i(1200, 6)]:
		var flight := _parked(0, scenario.x)
		var result := _fly_route(flight, scenario.y)
		_expect(result.arrived and result.avoided,
			"Epoch %d, route 0 → %d takes a detour around a moving obstacle and reaches its target (%s at %s)"
			% [scenario.x, scenario.y, flight.status_message, flight.position])


func _fly_route(flight: Flight, destination: int) -> Dictionary:
	if flight.docked >= 0 or flight.landed:
		flight.dock_action()
	flight.select_target(destination)
	flight.set_autopilot(true)
	var avoided := false
	for _frame in range(roundi(160.0 / STEP)):
		if not flight.autopilot:
			break
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
		avoided = avoided or flight.autopilot_phase == "Обход препятствия"
	var arrived := flight.docked == destination or flight.landed_site == destination
	if destination == Catalog.star_for(flight.system_id):
		var distance := flight.position.distance_to(flight.target_position(destination))
		arrived = not flight.autopilot and Catalog.SCOOP_INNER <= distance and distance <= Catalog.SCOOP_OUTER
	return {"arrived": arrived, "avoided": avoided}


func _test_time_button() -> void:
	var game := OrbitRelay.instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = _parked(0)
	game._update_display(0.0)
	await process_frame
	var time_button: Button = game._hud._actions.get("time")
	if _expect(is_instance_valid(time_button) and time_button.is_visible_in_tree() and not time_button.disabled,
		"Time acceleration is accessible from the touch HUD"):
		_tap(time_button)
		_expect(game.flight.time_scale == 4, "An indexed tap on the flight HUD sets 4×")
		await process_frame
		_tap(time_button)
		var before: float = game.flight.orbit_time
		game._physics_process(STEP)
		_expect(game.flight.time_scale == 16 and is_equal_approx(game.flight.orbit_time - before, STEP * 16.0)
			and game.flight.position == game.flight.target_contact(0), "Touch time control advances orbits while docked")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_O
		key.pressed = true
		root.push_input(key)
		_expect(game.flight.time_scale == 1, "The desktop O shortcut also cycles time acceleration")
	game.queue_free()
	await process_frame


func _parked(site: int, epoch := EPOCH) -> Flight:
	var flight := Flight.new()
	var state := flight.snapshot()
	var center: Vector3 = Orbit.sample(site, epoch).position
	var touch := center + Vector3.BACK * float(Catalog.site(site).pad_offset)
	state.orbit_time = epoch
	state.elapsed = epoch
	state.position = [touch.x, touch.y, touch.z]
	state.system_id = Catalog.system_of_site(site)
	state.target = site
	state.docked = site if Catalog.is_port(site) else -1
	if Catalog.is_mine_site(site):
		state.landed_site = site
		state.landing_direction = [0.0, 0.0, 1.0]
		state.mining.site_id = site
	if not flight.restore(state):
		_failures.append("Dynamic contact fixture at site %d could not be restored" % site)
	return flight


func _clear_flight() -> Flight:
	var flight := _parked(0)
	flight.dock_action()
	flight.position = Vector3(-7000.0, 4200.0, 4500.0)
	flight.velocity = Vector3.ZERO
	flight.yaw = 0.0
	return flight


func _step(flight: Flight, seconds: float) -> void:
	for _frame in range(roundi(seconds / STEP)):
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)


func _tap(button: Button) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 11
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event, true)


func _round_trip(state: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(state, "", true, true)) as Dictionary


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
