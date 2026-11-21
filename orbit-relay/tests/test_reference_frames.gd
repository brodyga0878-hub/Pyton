extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Terrain := preload("res://scripts/surface_terrain.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const Main := preload("res://main.tscn")
const AUTO := -2
const SYSTEM := -1
const HOME := Catalog.HOME_SYSTEM
const BINARY := Catalog.BINARY_SYSTEM
const PRIMARY := Catalog.BINARY_PRIMARY
const COMPANION := Catalog.BINARY_SECONDARY
const PLANET := Catalog.BINARY_PLANET
const MOON := Catalog.BINARY_MOON
const STEP := Fixture.STEP
const SAVE_PATH := "user://reference-frame-test.json"

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_body_fixed_frame()
	var arrived := _binary_arrival()
	if arrived != null:
		_test_coasting_handoff(arrived)
		_test_entry_exit_and_restart(arrived)
		_test_explicit_frames(arrived)
		_test_jump_policy(arrived)
		await _test_touch(arrived)
	print("Reference frame integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _binary_arrival() -> Flight:
	var flight := Flight.new()
	var frame := flight.frame_status()
	_expect(frame.mode == "auto" and frame.choice == AUTO and frame.reference == 0
		and frame.relative_speed == 0.0, "Startup reports the dock's automatic local frame while the ship is parked")
	_expect(not flight.set_reference_frame(Catalog.HEATHER_PORT)
		and not flight.set_reference_frame(9999) and flight.frame_status().choice == AUTO,
		"An undiscovered, remote or invalid target cannot become a frame")
	_expect(flight.set_reference_frame(SYSTEM) and flight.frame_status().reference == 0
		and flight.frame_status().relative_speed == 0.0 and flight.set_reference_frame(AUTO),
		"A configured frame preference does not replace the real berth reference while docked")
	if not _expect(flight.scan_galaxy() and flight.plan_jump(BINARY) and Fixture.depart(flight) and _jump(flight, BINARY, 0),
		"Reach the binary system by guided station departure and a real star drive jump"):
		return null
	return flight


func _test_body_fixed_frame() -> void:
	var flight := Flight.new()
	Fixture.launch(flight)
	const PORT := 0
	flight.position = flight.target_position(PORT) + Vector3(180.0, -25.0, 130.0)
	flight.velocity = Vector3(9.0, -3.0, 16.0)
	var position := flight.position
	var velocity := flight.velocity
	var attitude := flight.attitude()
	if not _expect(flight.can_rotate_reference(PORT) and not flight.set_reference_frame(Catalog.STAR_ID, true)
		and flight.set_reference_frame(PORT, true) and flight.position == position and flight.velocity == velocity
		and flight.attitude().is_equal_approx(attitude), "Selecting a rotating berth frame preserves the instantaneous world pose"):
		return
	var initial := flight.frame_status()
	var spin := float(Catalog.site(PORT).spin)
	var coupling := flight.station_axis(PORT).cross(position - flight.target_position(PORT)) * spin
	_expect(initial.rotating and Vector3(initial.velocity).is_equal_approx(flight.target_velocity(PORT) + coupling)
		and (Vector3(initial.origin) + initial.basis * initial.local_position).is_equal_approx(position)
		and (Vector3(initial.velocity) + initial.basis * initial.local_velocity).is_equal_approx(velocity)
		and (initial.basis * initial.local_attitude).is_equal_approx(attitude),
		"Berth axes, position, attitude and relative velocity reconstruct the same inertial ship state")
	for _index in range(18):
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	var updated := flight.frame_status()
	_expect(not flight.attitude().is_equal_approx(attitude) and updated.local_attitude.is_equal_approx(initial.local_attitude),
		"Assisted flight holds the selected station's local attitude as the berth rotates")
	flight.set_flight_assist(false)
	attitude = flight.attitude()
	for _index in range(18):
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	_expect(flight.attitude().is_equal_approx(attitude) and not flight.frame_status().local_attitude.is_equal_approx(updated.local_attitude),
		"Unaided inertial flight keeps its absolute attitude regardless of the instrument frame")
	var save := flight.snapshot()
	var cold := Flight.new()
	_expect(cold.restore(save) and cold.frame_status().rotating and cold.frame_status().basis.is_equal_approx(flight.frame_status().basis),
		"Cold restore recovers the chosen rotation and its physical epoch")
	save.frame.erase("rotating")
	_expect(Flight.new().restore(save), "Old two-field frame saves still open with an ordinary body frame")


func _test_coasting_handoff(arrived: Flight) -> void:
	var ship := _copy(arrived)
	var direction := ship.target_position(PLANET).direction_to(ship.target_position(MOON))
	ship.position = ship.target_position(PLANET) + direction * 230.0
	ship.velocity = ship.target_velocity(PLANET) + direction * 12.0
	ship.set_flight_assist(false)
	ship.yaw = 0.81
	ship.pitch = -0.23
	ship.roll = 0.54
	var frame := ship.frame_status()
	if not _expect(frame.mode == "auto" and frame.reference == PLANET and ship.target == PRIMARY,
		"Automatic capture picks the nearby planet independently of the selected flight target"):
		return
	var inertial := _copy(ship)
	var orientation := ship.attitude()
	if not _expect(inertial.set_reference_frame(SYSTEM), "A control ship can coast from the same state in the system frame"):
		return
	_tick_both(ship, inertial, func() -> bool: return ship.position.distance_to(ship.target_position(PLANET)) >= 255.0, 4.0)
	_expect(ship.position.distance_to(ship.target_position(MOON)) < float(Catalog.site(MOON).radius) + 75.0
		and ship.reference_site() == PLANET, "Entering the small overlapping region does not immediately flip between nearby bodies")
	_tick_both(ship, inertial, func() -> bool: return ship.reference_site() == MOON, 3.0)
	_expect(ship.reference_site() == MOON and ship.frame_status().mode == "auto" and ship.target == PRIMARY
		and ship.position.distance_to(ship.target_position(PLANET)) > 256.0,
		"Continuing physically into the nearer moon's region hands off the automatic reference")
	_expect(ship.position.distance_to(inertial.position) < 0.003 and ship.velocity.distance_to(inertial.velocity) < 0.001
		and ship.attitude().is_equal_approx(orientation) and ship.attitude().is_equal_approx(inertial.attitude())
		and is_equal_approx(ship.ship.fuel, inertial.ship.fuel),
		"Automatic handoff in an unassisted coast leaves the same inertial path, attitude and fuel as the system frame")


func _test_entry_exit_and_restart(arrived: Flight) -> void:
	var flight := _copy(arrived)
	var moon := flight.target_position(MOON)
	var outward := (moon - flight.target_position(PLANET)).cross(Vector3.UP).normalized()
	var radius := float(Catalog.site(MOON).radius)
	flight.position = moon + outward * (radius + 60.0)
	flight.velocity = flight.target_velocity(MOON) + outward * 13.0
	flight.set_flight_assist(false)
	if not _expect(flight.frame_status().reference == MOON
		and _advance(flight, func() -> bool: return flight.position.distance_to(flight.target_position(MOON)) > radius + 90.0, 4.0)
		and flight.frame_status().reference == MOON, "The moon reference remains active outside its entry radius while coasting outward"):
		return
	var checkpoint := flight.snapshot()
	if not _expect(SessionIO.save_state(checkpoint, SAVE_PATH) == OK, "Write the retained automatic reference to disk"):
		return
	var cold := Flight.new()
	if not _expect(cold.restore(SessionIO.load_state(SAVE_PATH)) and cold.frame_status().reference == MOON
		and cold.frame_status().mode == "auto" and cold.position.distance_to(flight.position) < 0.002
		and cold.velocity.distance_to(flight.velocity) < 0.002, "Cold restart preserves automatic hysteresis and inertial state"):
		return
	_expect(_advance(cold, func() -> bool: return cold.position.distance_to(cold.target_position(MOON)) > radius + 142.0, 7.0)
		and cold.frame_status().reference == SYSTEM and cold.frame_status().choice == AUTO
		and cold.frame_status().velocity == Vector3.ZERO, "Once truly clear of the body, automatic mode returns to the system frame")
	var after := Flight.new()
	_expect(after.restore(cold.snapshot()) and after.frame_status().reference == SYSTEM,
		"A body already exited does not reappear when loading the later automatic state")


func _test_explicit_frames(arrived: Flight) -> void:
	var flight := _copy(arrived)
	flight.position = flight.target_contact(PLANET)
	flight.velocity = Vector3(4.0, -2.0, -7.0)
	flight.yaw = 0.51
	flight.pitch = -0.32
	flight.roll = 0.73
	var position := flight.position
	var inertial_velocity := flight.velocity
	var orientation := flight.attitude()
	var selected := flight.target
	if not _expect(flight.set_reference_frame(PLANET), "Explicitly select the visible local rotating planet"):
		return
	var frame := flight.frame_status()
	var near_velocity := flight.surface_velocity(PLANET, position)
	_expect(frame.mode == "body" and frame.choice == PLANET and frame.reference == PLANET and frame.surface
		and frame.velocity.distance_to(near_velocity) < 0.35
		and frame.velocity.distance_to(flight.target_velocity(PLANET)) > 0.5
		and frame.relative_velocity.distance_to(inertial_velocity - frame.velocity) < 0.001
		and is_equal_approx(frame.relative_speed, frame.relative_velocity.length()),
		"The selected body uses both changing orbital velocity and local surface rotation near contact")
	_expect(flight.set_reference_frame(SYSTEM) and flight.position == position and flight.velocity == inertial_velocity
		and flight.attitude().is_equal_approx(orientation) and flight.target == selected
		and flight.frame_status().mode == "system" and flight.frame_status().velocity == Vector3.ZERO,
		"Changing the frame for instruments does not teleport, steer, accelerate, or retarget the ship")
	flight.position = flight.target_position(PLANET) + Vector3.UP * 720.0
	_expect(flight.set_reference_frame(PLANET) and not flight.frame_status().surface
		and flight.frame_status().velocity.distance_to(flight.target_velocity(PLANET)) < 0.001,
		"A distant rotating planet's frame does not give the ship an extrapolated surface velocity")
	flight.position = flight.target_position(COMPANION) + Vector3.UP * 720.0
	if not _expect(flight.set_reference_frame(COMPANION), "A visible moving star can be selected from beyond its automatic capture range"):
		return
	frame = flight.frame_status()
	var stellar_velocity := flight.target_velocity(COMPANION)
	_expect(frame.reference == COMPANION and not frame.surface
		and frame.velocity.distance_to(stellar_velocity) < 0.001 and frame.velocity.length() > 0.8,
		"A distant locked frame uses actual ephemeris velocity without any surface component")
	var selected_save := flight.snapshot()
	var cold := Flight.new()
	_expect(cold.restore(selected_save) and cold.frame_status().choice == COMPANION
		and cold.position == flight.position and cold.attitude().is_equal_approx(flight.attitude()),
		"Explicit body selection is persistent while ship state stays in the world frame")
	_expect(not cold.set_reference_frame(0) and cold.frame_status().choice == COMPANION,
		"Rejecting a remote port does not alter the previous valid body choice")
	var corrupt := selected_save.duplicate(true)
	corrupt.frame.choice = 0
	_expect(not Flight.new().restore(corrupt), "A save cannot resurrect an explicit reference to a foreign system")
	corrupt = selected_save.duplicate(true)
	corrupt.frame.auto_site = MOON
	_expect(not Flight.new().restore(corrupt), "A saved explicit frame cannot also include stale automatic hysteresis")
	_test_braking(flight)


func _test_braking(flight: Flight) -> void:
	flight.velocity = flight.target_velocity(COMPANION) + Vector3(8.0, -4.0, 3.0)
	var controls := _copy(flight)
	if not _expect(controls.set_reference_frame(SYSTEM), "Prepare the same manual braking maneuver against the system frame"):
		return
	var orientation := flight.attitude()
	for _frame in range(90):
		flight.update(STEP, Vector2.ZERO, 0.0, false, true)
		controls.update(STEP, Vector2.ZERO, 0.0, false, true)
	_expect(flight.velocity.distance_to(flight.target_velocity(COMPANION)) < 0.08 and controls.velocity.length() < 0.08
		and flight.velocity.distance_to(controls.velocity) > 0.8 and flight.attitude().is_equal_approx(orientation)
		and controls.attitude().is_equal_approx(orientation),
		"Braking physically matches the chosen inertial velocity without rotating the controls")
	var start_angle := flight.attitude()
	var start_speed := flight.velocity
	flight.update(0.25, Vector2(0.48, -0.31), 0.4, false, false, Vector3.RIGHT)
	_expect(not flight.attitude().is_equal_approx(start_angle) and flight.velocity.distance_to(start_speed) > 0.06
		and flight.frame_status().choice == COMPANION
		and absf(flight.attitude().determinant() - 1.0) < 0.001,
		"Steering, banking and lateral thrust still operate in the ship's own orientation while the frame stays locked")


func _test_jump_policy(arrived: Flight) -> void:
	for choice: int in [COMPANION, SYSTEM]:
		var flight := _copy(arrived)
		if not _expect(flight.set_reference_frame(choice) and flight.plan_jump(HOME) and _jump(flight, HOME, PRIMARY),
			"Return through a real jump with starting reference selection %d" % choice):
			continue
		var expected := AUTO if choice == COMPANION else SYSTEM
		_expect(flight.frame_status().choice == expected and flight.frame_status().reference != COMPANION,
			"Jumping clears a foreign body lock and preserves an explicit system frame (%d)" % choice)


func _test_touch(arrived: Flight) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := Main.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = _copy(arrived)
	game._update_display(0.0)
	await process_frame
	var flight: Flight = game.flight
	var position := flight.position
	var velocity := flight.velocity
	var attitude := flight.attitude()
	var selected := flight.target
	_tap(viewport, game._hud._actions["frame"], "Pilot taps the actual frame control on the cockpit")
	await process_frame
	_expect(flight.frame_status().mode == "system" and flight.position == position and flight.velocity == velocity
		and flight.attitude().is_equal_approx(attitude), "The cockpit cycles to system and leaves the flight state intact")
	_tap(viewport, game._hud._actions["map"], "Open the original sector chart with touch")
	await process_frame
	var map: Node = game._map
	_tap(viewport, map._trajectory_button, "Open trajectory actions on the sector map")
	await process_frame
	_tap(viewport, map._focus_buttons[MOON], "Preview the binary moon as the map reference")
	await process_frame
	_tap(viewport, map._frame_button, "Apply the moon reference through the map control")
	await process_frame
	var saved := SessionIO.load_state()
	_expect(map.is_open() and flight.frame_status().choice == MOON and flight.target == selected
		and saved.get("frame", {}).get("choice") == MOON and flight.position == position
		and flight.velocity == velocity and flight.attitude().is_equal_approx(attitude),
		"The real chart applies the explicit moon frame while preserving the current course and flight state")
	_tap(viewport, map._frame_rotation_button, "Switch to the rotating moon frame by touch")
	await process_frame
	_expect(flight.frame_status().rotating and SessionIO.load_state().get("frame", {}).get("rotating", false)
		and flight.position == position and flight.attitude().is_equal_approx(attitude),
		"The chart applies and saves the rotating frame without moving or turning the ship")
	viewport.queue_free()
	await process_frame


func _copy(source: Flight) -> Flight:
	var copy := Flight.new()
	_expect(copy.restore(source.snapshot()), "Clone the actual physical checkpoint for an independent scenario")
	return copy


func _jump(flight: Flight, destination: int, nearest_site: int) -> bool:
	var outward := (flight.position - flight.target_position(nearest_site)).normalized()
	flight.yaw = atan2(-outward.x, -outward.z)
	flight.pitch = asin(clampf(outward.y, -1.0, 1.0))
	flight.change_throttle(0.18)
	return _advance(flight, func() -> bool: return flight.jump_status(destination).ok, 25.0) \
		and flight.start_jump() \
		and _advance(flight, func() -> bool: return flight.system_id == destination, 4.0)


func _tick_both(flight: Flight, control: Flight, reached: Callable, seconds: float) -> void:
	for _frame in range(ceili(seconds / STEP)):
		if reached.call():
			return
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
		control.update(STEP, Vector2.ZERO, 0.0, false, false)


func _advance(flight: Flight, reached: Callable, seconds: float) -> bool:
	for _frame in range(ceili(seconds / STEP)):
		if reached.call():
			return true
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	return reached.call()


func _tap(viewport: SubViewport, button: Button, description: String) -> void:
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled
		and button.get_global_rect().size.y >= 39.0, description):
		return
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 27
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		viewport.push_input(event, true)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
