extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Fixture = preload("res://tests/flight_fixture.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const DockAccess := preload("res://scripts/dock_access.gd")
const OrbitRelay := preload("res://main.tscn")
const PORT := 1
const VELAR_PORT := 11
const STEP := 1.0 / 60.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_moving_frame()
	_test_manual_thresholds()
	_test_sync_guard()
	_test_spin_tracking(PORT)
	_test_spin_tracking(VELAR_PORT)
	_test_handoffs_and_save()
	_test_autodock(PORT)
	_test_autodock(VELAR_PORT)
	await _test_touch_controls()
	print("Docking guidance integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_moving_frame() -> void:
	var flight := _at_approach(PORT, Vector3(-4.0, 3.0, 75.0), Vector3(2.0, -1.0, -3.0))
	flight.yaw = deg_to_rad(7.0)
	flight.roll = wrapf(flight.station_angle(PORT) + deg_to_rad(19.0), -PI, PI)
	var guide := flight.docking_guidance()
	_expect(guide.port == PORT and guide.near and guide.in_front and is_equal_approx(guide.axis_distance, 75.0)
		and absf(guide.range - sqrt(5650.0)) < 0.01,
		"The moving station measures both forward-axis separation and true range from its docking contact")
	_expect(guide.off_axis.distance_to(Vector2(-4.0, 3.0)) < 0.01 and absf(guide.lateral_error - 5.0) < 0.01,
		"World offsets become signed horizontal and vertical displacements in the rotating docking frame")
	_expect(absf(guide.closing_speed - 3.0) < 0.01 and absf(guide.relative_speed - sqrt(14.0)) < 0.01,
		"Closing speed uses the positive inward component while relative speed includes lateral motion")
	_expect(absf(guide.aim_error_deg - 7.0) < 0.02 and absf(guide.roll_error_deg + 19.0) < 0.02
		and absf(guide.spin_deg_sec - rad_to_deg(Catalog.site(PORT).spin)) < 0.01,
		"Guidance reports unsigned pointing error and signed roll correction and station spin")
	flight.velocity = flight.target_velocity(PORT) + flight.station_axis(PORT) * 2.3
	_expect(absf(flight.docking_guidance().closing_speed + 2.3) < 0.01,
		"Backing away from the moving docking contact produces negative closing speed")


func _test_manual_thresholds() -> void:
	var flight := _at_approach(PORT, Vector3(3.0, 0.0, 6.1), Vector3(2.4, 0.0, -4.0))
	flight.yaw = 0.14
	flight.roll = wrapf(flight.station_angle(PORT) + 0.15, -PI, PI)
	var near := flight.docking_guidance()
	_expect(not near.ok and not near.cleared and near.position_ok and near.speed_ok and near.roll_ok and near.aim_ok,
		"An otherwise valid approach cannot dock without authorization")
	_set_offset(flight, PORT, Vector3.BACK * 12.0)
	flight.velocity = flight.target_velocity(PORT)
	if not _expect(flight.dock_clearance_action() and _await_open(flight, PORT),
		"The geometrical tolerances are measured in a genuinely open approach"):
		return
	_set_offset(flight, PORT, Vector3(0.0, 0.0, 7.2))
	_expect(not flight.docking_guidance().position_ok and not flight.dock_action(),
		"The manual docking contact still requires at most seven metres of true range")
	_set_offset(flight, PORT, Vector3(3.2, 0.0, 4.0))
	_expect(not flight.docking_guidance().position_ok and not flight.dock_action(),
		"An approach inside seven metres is rejected laterally outside the 3.1-metre corridor")
	_set_offset(flight, PORT, Vector3(0.0, 0.0, 4.5))
	flight.velocity = flight.target_velocity(PORT) + Vector3.FORWARD * 5.1
	_expect(not flight.docking_guidance().speed_ok and not flight.dock_action(),
		"Closing above five metres per second relative to the port blocks attachment")
	flight.velocity = flight.target_velocity(PORT)
	flight.yaw = 0.16
	_expect(not flight.docking_guidance().aim_ok and not flight.dock_action(),
		"The measured nose angle still limits manual docking")
	flight.yaw = 0.0
	flight.roll = wrapf(flight.station_angle(PORT) + 0.17, -PI, PI)
	_expect(not flight.docking_guidance().roll_ok and not flight.dock_action(),
		"Merely matching speed and heading does not bypass the roll tolerance")
	flight.roll = flight.station_angle(PORT)
	_expect(flight.docking_guidance().ok and flight.dock_action() and flight.docked == PORT
		and not flight.docking_guidance().near and flight.dock_roll_sync == -1,
		"Correcting the last tolerance docks and clears the approach instruments")


func _test_sync_guard() -> void:
	var flight := _at_approach(PORT, Vector3.BACK * 180.5, Vector3.ZERO)
	_expect(not flight.docking_guidance().sync_available and not flight.toggle_dock_sync(),
		"The roll helper will not arm outside the 180-metre capture zone")
	_set_offset(flight, PORT, Vector3.FORWARD * 80.0)
	_expect(not flight.docking_guidance().in_front and not flight.toggle_dock_sync(),
		"The rear side of a station cannot arm its manual dock helper")
	_set_offset(flight, PORT, Vector3.BACK * 88.0)
	flight.yaw = deg_to_rad(33.0)
	_expect(not flight.docking_guidance().sync_available and not flight.toggle_dock_sync(),
		"A facing error above 32 degrees keeps the helper off until the pilot aims at the station")
	flight.yaw = deg_to_rad(30.0)
	flight.velocity = flight.target_velocity(PORT) + Vector3.BACK * 12.0
	_expect(flight.docking_guidance().sync_available and flight.toggle_dock_sync()
		and flight.dock_roll_sync == PORT and not flight.docking_guidance().speed_ok,
		"The helper can align roll without declaring an overspeed approach ready")
	_expect(flight.toggle_dock_sync() and flight.dock_roll_sync == -1,
		"The same explicit control disengages the helper")
	if _expect(flight.toggle_dock_sync(), "Rearm the helper while the station remains eligible"):
		_set_offset(flight, PORT, Vector3.BACK * 181.0)
		_tick(flight)
		_expect(flight.dock_roll_sync == -1 and not flight.docking_guidance().sync_available,
			"Leaving the instrument capture zone drops an already active lock")
	flight.select_target(2)
	_expect(not flight.docking_guidance().sync_available and not flight.toggle_dock_sync(),
		"Solid surface targets use their normal landing controls instead of docking roll")
	var parked := Flight.new()
	_expect(not parked.toggle_dock_sync() and parked.dock_roll_sync == -1,
		"Synching a manual approach is unavailable while already docked")


func _test_spin_tracking(port: int) -> void:
	var flight := _at_approach(port, Vector3.BACK * 86.0, Vector3(1.0, -0.3, 0.0))
	flight.yaw = deg_to_rad(12.0)
	flight.pitch = deg_to_rad(-7.0)
	flight.roll = wrapf(flight.station_angle(port) + deg_to_rad(73.0), -PI, PI)
	var direction := flight.forward()
	var world := Flight.new()
	var before := _json(flight.snapshot())
	if not _expect(world.restore(before) and flight.toggle_dock_sync() and flight.dock_roll_sync == port,
		"Start an actual station roll synchronization alongside an identical no-assist flight"):
		return
	var warm_fuel := flight.ship.fuel
	_tick(flight, 4.0)
	_tick(world, 4.0)
	var tracked := flight.docking_guidance()
	if not _expect(tracked.sync_active and absf(tracked.roll_error_deg) < 1.4 and tracked.roll_ok
		and direction.dot(flight.forward()) > 0.99998,
		"The helper aligns roll to the selected station without changing the ship nose"):
		return
	var roll := flight.roll
	var previous_station := flight.station_angle(port)
	var previous_position := flight.target_position(port)
	_tick(flight, 2.0)
	_tick(world, 2.0)
	var ship_turn := angle_difference(roll, flight.roll)
	var station_turn := angle_difference(previous_station, flight.station_angle(port))
	_expect(absf(station_turn) > 0.35 and signf(ship_turn) == signf(float(Catalog.site(port).spin))
		and absf(ship_turn - station_turn) < 0.035 and flight.target_position(port).distance_to(previous_position) > 2.0,
		"The helper keeps up with the actual signed rotation and translating motion of station %d" % port)
	_expect(flight.position.distance_to(world.position) < 0.012 and flight.velocity.distance_to(world.velocity) < 0.012
		and flight.ship.fuel == world.ship.fuel and flight.ship.fuel == warm_fuel,
		"Identical piloting yields the same trajectory, relative speed and fuel with or without roll assistance")
	flight.change_throttle(0.15)
	flight.update(STEP, Vector2(0.38, 0.1), 0.0, false, false, Vector3.RIGHT)
	_expect(flight.dock_roll_sync == port,
		"Thrust, translation and ordinary steering stay in the pilot's hands while synchronization remains eligible")
	flight.update(STEP, Vector2.ZERO, 0.72, false, false)
	_expect(flight.dock_roll_sync == -1 and not flight.docking_guidance().sync_active,
		"Manual bank input disengages the roll helper immediately")


func _test_handoffs_and_save() -> void:
	var flight := _at_approach(PORT, Vector3.BACK * 100.0, Vector3.ZERO)
	if not _expect(flight.toggle_dock_sync(), "Set up synchronization before changing navigation modes"):
		return
	flight.select_target(0)
	_expect(flight.dock_roll_sync == -1, "Retargeting a different station drops the old port's roll lock")
	flight.select_target(PORT)
	flight.toggle_dock_sync()
	flight.set_autopilot(true)
	_expect(flight.autopilot and flight.dock_roll_sync == -1, "Enabling autopilot takes over and disengages manual roll synchronization")
	flight.set_autopilot(false)
	flight.toggle_dock_sync()
	if _expect(flight.dock_roll_sync == PORT and flight.plan_jump(Catalog.VELAR_SYSTEM) and flight.start_jump()
		and flight.dock_roll_sync == -1, "Starting a clear hyperspace jump disengages the active port lock"):
		_tick(flight, 3.0)
		_expect(flight.system_id == Catalog.VELAR_SYSTEM and flight.dock_roll_sync == -1,
			"Completing the jump never resumes an old station's alignment")
	flight = _at_approach(PORT, Vector3.BACK * 88.0, Vector3(0.0, 0.0, -0.2))
	flight.roll = wrapf(flight.station_angle(PORT) - 0.47, -PI, PI)
	flight.toggle_dock_sync()
	_tick(flight, 0.2)
	var saved := _json(flight.snapshot())
	var where := flight.position
	var movement := flight.velocity
	var facing := flight.attitude()
	_expect(flight.dock_roll_sync == PORT and not saved.has("dock_roll_sync") and flight.restore(saved)
		and flight.dock_roll_sync == -1 and flight.position.distance_to(where) < 0.001
		and flight.velocity.distance_to(movement) < 0.001 and flight.attitude().is_equal_approx(facing),
		"Reloading an active approach preserves the real pose and momentum but clears automatic bank commands")
	var earlier := saved.duplicate(true)
	earlier.schema = 15
	earlier.ship.erase("mining_laser")
	earlier.ship.erase("fragment_collector")
	earlier.ship.erase("hydrogen_scoop")
	earlier.ship.erase("fuel_pump")
	earlier.ship.erase("pump_mode")
	earlier.ship.erase("hull_id")
	earlier.ship.erase("jump_fuel")
	earlier.mining.cargo.erase("hydrogen")
	earlier.mining.reserves.resize(Catalog.PRE_GAS_DESTINATION_COUNT)
	for stocks: Dictionary in earlier.market.values():
		stocks.erase("hydrogen")
	earlier.erase("freight")
	_expect(flight.restore(earlier) and flight.dock_roll_sync == -1 and flight.target == PORT,
		"An older flight save restores the normal approach with synchronization off")
	if _expect(flight.toggle_dock_sync() and flight.select_target(2) and flight.dock_roll_sync == -1,
		"Changing a synchronized station approach to a surface target releases the lock"):
		flight.position = flight.target_contact(2) + Vector3.BACK * 3.0
		flight.velocity = flight.target_velocity(2)
		flight.yaw = 0.0
		flight.pitch = 0.0
		flight.roll = 0.0
		flight.gear_extension = 1.0
		flight.gear_deployed = true
		_expect(flight.dock_action() and flight.landed_site == 2 and flight.dock_roll_sync == -1,
			"A normal surface landing does not inherit a station's bank correction")


func _test_autodock(port: int) -> void:
	var flight := _station_departure(port)
	if not _expect(flight.select_target(port), "Select a real destination for automatic docking"):
		return
	flight.set_autopilot(true)
	var last := {}
	var queued := false
	var opened := false
	for _frame in range(roundi(120.0 / STEP)):
		if not flight.autopilot:
			break
		var state := flight.docking_guidance()
		var access := flight.dock_access_status(port)
		queued = queued or access.phase == "queued"
		opened = opened or bool(access.ready)
		_tick(flight)
		if flight.docked == port:
			last = state
	_expect(flight.docked == port and not flight.autopilot and flight.dock_roll_sync == -1
		and flight.ship.hull == 100.0 and not last.is_empty()
		and last.range < 2.95 and last.relative_speed < 3.3 and absf(flight.roll_error(port)) < 0.02
		and queued and opened and last.cleared,
		"Autopilot queues, gains clearance and reaches final-capture range at moving port %d (%s)" % [
			port, flight.status_message,
		])


func _test_touch_controls() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := OrbitRelay.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var flight := _at_approach(PORT, Vector3.BACK * 12.0, Vector3.ZERO)
	flight.roll = wrapf(flight.station_angle(PORT) + 0.9, -PI, PI)
	game.flight = flight
	game._update_display(0.0)
	await process_frame
	_expect(game._hud._docking_panel.is_visible_in_tree() and game._hud._docking_motion.is_visible_in_tree(),
		"The real flight HUD shows the moving-station approach instruments")
	_tap(viewport, game._hud._actions["dock_clearance"], "Request clearance from the touch HUD")
	await process_frame
	_expect(flight.dock_access_status(PORT).phase == "queued" and flight.docked < 0
		and "Ожидание допуска" in game._hud._docking_access.text,
		"Request input queues the actual station and displays the wait without attaching the ship")
	_tap(viewport, game._hud._actions["dock_sync"], "Engage station roll synchronization from the touch HUD")
	await process_frame
	_expect(flight.dock_roll_sync == PORT and flight.docked < 0, "Touch arms rotation only and does not dock the ship")
	if not _expect(_await_open(flight, PORT), "The requested hatch physically reaches the fully open position"):
		viewport.queue_free()
		await process_frame
		return
	_set_offset(flight, PORT, Vector3.BACK * minf(5.0, DockAccess.HATCH_AXIS_OFFSET - 1.0))
	flight.velocity = flight.target_velocity(PORT)
	game._update_display(0.0)
	await process_frame
	_expect(flight.docking_guidance().ok and game._hud._docking_roll.is_visible_in_tree()
		and "Проход открыт" in game._hud._docking_access.text,
		"The pilot can see the resulting readiness before choosing to dock")
	_tap(viewport, game._hud._actions["dock"], "Complete manual docking through the regular touch action")
	await process_frame
	_expect(flight.docked == PORT and flight.dock_roll_sync == -1
		and not game._hud._docking_panel.is_visible_in_tree() and not game._hud._actions["dock_sync"].is_visible_in_tree(),
		"The touch dock completes normally and clears the contextual helper and guidance")
	viewport.queue_free()
	await process_frame


func _station_departure(port: int) -> Flight:
	var flight := Flight.new()
	var system := Catalog.system_of_site(port)
	var home_port: int = Catalog.system(system).arrival_port
	var saved := flight.snapshot()
	var berth := flight.docking_position(home_port)
	saved.merge({"system_id": system, "docked": home_port, "target": home_port,
		"position": [berth.x, berth.y, berth.z]}, true)
	_expect(flight.restore(saved), "Load a docked state in the destination's system")
	_tick(flight, 137.0)
	_expect(Fixture.launch(flight), "Seed an airborne ship at the nearby port")
	return flight


func _at_approach(port: int, local_offset: Vector3, relative_velocity: Vector3) -> Flight:
	var flight := _station_departure(port)
	flight.select_target(port)
	_set_offset(flight, port, local_offset)
	flight.velocity = flight.target_velocity(port) + relative_velocity
	flight.yaw = 0.0
	flight.pitch = 0.0
	flight.roll = flight.station_angle(port)
	return flight


func _set_offset(flight: Flight, port: int, offset: Vector3) -> void:
	flight.position = flight.docking_position(port) + Basis(flight.station_axis(port), flight.station_angle(port)) * offset


func _tick(flight: Flight, delta := STEP) -> void:
	flight.update(delta, Vector2.ZERO, 0.0, false, false)


func _await_open(flight: Flight, port: int) -> bool:
	for _frame in range(ceili((DockAccess.MAX_QUEUE_SECONDS + DockAccess.OPENING_SECONDS + STEP) / STEP)):
		if flight.dock_access_status(port).ready:
			return true
		_tick(flight)
	return bool(flight.dock_access_status(port).ready)


func _json(value: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value, "", true, true)) as Dictionary


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
