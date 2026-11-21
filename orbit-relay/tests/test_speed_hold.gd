extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Session := preload("res://scripts/session_io.gd")
const SpeedHold := preload("res://scripts/speed_hold.gd")

const STEP := Fixture.STEP
const SAVE := "user://speed-hold-flight.json"

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_signed_speed_model()
	var flight := _test_software_equipment()
	if flight != null:
		_test_flight_hold(flight)
	_test_course_and_jump_exclusion()
	_test_blocked_speed_hold()
	print("Speed hold integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_signed_speed_model() -> void:
	var model := SpeedHold.new()
	_expect(not model.enabled and model.setpoint == 0.0 and not model.set_enabled(false),
		"A new velocity aid is off with its neutral setpoint")
	_expect(model.set_speed(200.0) and model.setpoint == 60.0 and not model.adjust(0.25),
		"The positive setpoint cannot exceed 60 m/s")
	_expect(model.set_speed(-200.0) and model.setpoint == -60.0 and not model.adjust(-0.25)
		and not model.set_speed(INF) and not model.set_speed(NAN) and model.setpoint == -60.0,
		"The negative setpoint clamps to -60 m/s and invalid input cannot affect it")
	var drift := Vector3(-4.0, 6.0, 20.0)
	var forward := Vector3.FORWARD
	var velocity := drift + forward * 12.0 + Vector3.RIGHT * 5.0
	_expect(SpeedHold.projected_speed(velocity, drift, forward * 7.0) == 12.0
		and SpeedHold.projected_speed(drift - forward * 8.0, drift, forward) == -8.0
		and SpeedHold.projected_speed(velocity, drift, Vector3.ZERO) == 0.0,
		"Signed speed is the normalized longitudinal projection and omits frame drift and lateral motion")
	_expect(model.speed_delta(velocity, drift, forward, 4.0, 0.5) == 0.0
		and model.set_enabled(true) and not model.set_enabled(true)
		and model.speed_delta(velocity, drift, forward, 4.0, 0.5) == -2.0,
		"Disabled control exerts no correction and enabled reversal is acceleration limited")
	_expect(model.speed_delta(drift - forward * 39.5, drift, forward, 4.0, 0.5, 40.0) == -0.5
		and model.speed_delta(drift - forward * 44.0, drift, forward, 4.0, 1.0, 40.0) == 4.0,
		"Fuel or hull limits cap achievable reverse speed without overshooting or replacing the requested setpoint")
	_expect(model.speed_delta(velocity, drift, forward, -3.0, 0.5) == 0.0
		and model.speed_delta(velocity, drift, forward, 4.0, -0.5) == 0.0
		and model.speed_delta(velocity, drift, forward, 4.0, 0.5, -1.0) == 0.0,
		"Invalid acceleration, elapsed time and reachable range produce no correction")
	var encoded := model.snapshot()
	var restored := SpeedHold.new()
	_expect(restored.restore(JSON.parse_string(JSON.stringify(encoded))) and restored.snapshot() == encoded,
		"A JSON round trip preserves exact signed setpoint and armed state")
	for invalid: Dictionary in [{"enabled": true, "setpoint": -60.1}, {"enabled": false, "setpoint": 60.1},
			{"enabled": 0, "setpoint": 5.0}, {"enabled": true, "setpoint": INF},
			{"enabled": true, "setpoint": 5.0, "other": 0}]:
		_expect(not restored.restore(invalid) and restored.snapshot() == encoded, "Reject malformed speed settings atomically")


func _test_software_equipment() -> Flight:
	var flight := Flight.new()
	var setup := flight.autopilot_equipment_status()
	var old_balance := flight.credits
	var old_fuel := flight.ship.fuel
	_expect(setup.installed and setup.available and flight.ship.autopilot_fitted
		and not flight.speed_hold_status().available and not flight.toggle_speed_hold(),
		"The new docked pilot retains the usual computer but cannot engage longitudinal speed hold")
	if not _expect(flight.autopilot_equipment_action() and not flight.ship.autopilot_fitted
		and flight.credits == old_balance and flight.ship.fuel == old_fuel,
		"The standing pilot can uninstall the course computer without taking money or fuel"):
		return null
	var cold := Flight.new()
	if not _expect(Session.save_state(flight.snapshot(), SAVE) == OK and cold.restore(Session.load_state(SAVE))
		and not cold.ship.autopilot_fitted and not cold.autopilot_equipment_status().installed,
		"An actual cold reload preserves that the computer is absent"):
		return null
	_expect(cold.autopilot_equipment_action() and cold.autopilot_equipment_status().installed
		and cold.credits == old_balance and cold.ship.fuel == old_fuel,
		"Reinstalling the course computer at the same dock also preserves balance and fuel")
	if not _expect(flight.select_target(1) and Fixture.depart(flight) and flight.target == 1,
		"Manual open flight remains accessible without a course computer"):
		return null
	var position := flight.position
	flight.set_autopilot(true)
	_expect(not flight.autopilot and flight.position == position and not flight.autopilot_equipment_action()
		and not flight.autopilot_equipment_status().available and not flight.ship.autopilot_fitted
		and flight.speed_hold_status().available, "Course assistance stays off without its computer while the separate hold remains available")
	return flight


func _test_flight_hold(flight: Flight) -> void:
	if not _expect(flight.toggle_speed_hold() and flight.speed_hold_status().enabled
		and _setpoint(flight, 36.0), "Engage independent positive flight hold and set +36 m/s"):
		return
	var throttle := flight.throttle
	flight.change_speed_pilot_control(0.11, 4.0)
	if not _expect(_near(flight.speed_hold_status().setpoint, 40.0) and flight.throttle == throttle,
		"The shared pilot speed controls change the hold setpoint without adding throttle"):
		return
	var fuel := flight.ship.fuel
	var start := flight.position
	if not _expect(_until(flight, func() -> bool: return _near(flight.speed_hold_status().actual, 40.0, 0.22), 6.0)
		and flight.position.distance_to(start) > 12.0 and flight.ship.fuel < fuel,
		"Physical longitudinal thrust reaches the positive setpoint and consumes reaction fuel"):
		return
	_step(flight, 5.0)
	var heading := flight.forward()
	flight.update(0.5, Vector2(0.22, 0.36), 0.0, false, false, Vector3(0.15, 0.16, 0.0))
	_expect(flight.speed_hold_status().enabled and flight.forward().distance_to(heading) > 0.02
		and _near(flight.speed_hold_status().setpoint, 40.0),
		"Steering and sideways translation remain available without canceling the forward setpoint")
	_expect(flight.set_flight_assist(false) and flight.speed_hold_status().enabled,
		"A separate switch between stabilized and inertial flight retains the selected speed")
	_expect(flight.set_reference_frame(1) and flight.speed_hold_status().enabled,
		"Choosing a moving reference changes the measurement without canceling the hold")
	if not _expect(_setpoint(flight, -18.0)
		and _until(flight, func() -> bool: return _near(flight.speed_hold_status().actual, -18.0, 0.22), 10.0),
		"The ship physically stops and begins moving backward to the valid negative setpoint"):
		return
	var frame := flight.frame_status()
	var relative: Vector3 = flight.velocity - frame.velocity
	_expect(frame.choice == 1 and frame.velocity.length() > 0.01 and relative.dot(flight.forward()) < -17.7
		and _near(flight.speed_hold_status().actual, relative.dot(flight.forward())),
		"The real reverse reading subtracts selected frame velocity before projecting against the ship's nose")
	_test_hold_reloading(flight)
	_test_manual_overrides(flight)
	_test_reserve_limit(flight)


func _test_hold_reloading(flight: Flight) -> void:
	if not _expect(flight.toggle_time_pause(), "Pause a physically moving ship with reverse hold armed"):
		return
	var saved := flight.snapshot()
	var cold := Flight.new()
	if not _expect(Session.save_state(saved, SAVE) == OK and cold.restore(Session.load_state(SAVE))
		and cold.clock_status().paused and cold.speed_hold_status().enabled
		and cold.speed_hold_status().setpoint == -18.0 and not cold.ship.autopilot_fitted
		and cold.position.is_equal_approx(flight.position) and cold.velocity.is_equal_approx(flight.velocity),
		"Cold flight restores reverse speed, paused control state, equipment choice and kinematics"):
		flight.toggle_time_pause()
		return
	var unchanged := cold.snapshot()
	_step(cold, 1.0)
	_expect(cold.snapshot() == unchanged and cold.toggle_time_pause()
		and _until(cold, func() -> bool: return _near(cold.speed_hold_status().actual, -18.0, 0.14), 4.0),
		"A paused reload leaves the ship frozen and resumes the same signed hold when released")
	var malformed := saved.duplicate(true)
	malformed.speed_hold.setpoint = -61.0
	_expect(not Flight.new().restore(malformed), "An out-of-range persisted navigation setpoint is rejected")
	flight.toggle_time_pause()


func _test_manual_overrides(flight: Flight) -> void:
	var programmed := flight.snapshot()
	var requested := float(flight.speed_hold_status().setpoint)
	var controls := [
		{"name": "brake", "boost": false, "brake": true, "z": 0.0},
		{"name": "boost", "boost": true, "brake": false, "z": 0.0},
		{"name": "forward", "boost": false, "brake": false, "z": 0.44},
		{"name": "reverse", "boost": false, "brake": false, "z": -0.44},
	]
	for control: Dictionary in controls:
		var clone := Flight.new()
		if not _expect(clone.restore(programmed) and clone.speed_hold_status().enabled,
			"Initialize a live hold before using the %s control" % control.name):
			continue
		clone.update(STEP, Vector2.ZERO, 0.0, control.boost, control.brake, Vector3(0.0, 0.0, control.z))
		_expect(not clone.speed_hold_status().enabled and clone.speed_hold_status().setpoint == requested,
			"The %s override disengages speed hold and keeps the last programmed speed" % control.name)
	var manual := Flight.new()
	if _expect(manual.restore(programmed), "Initialize a live hold for direct manual throttle"):
		manual.change_throttle(0.18)
		_expect(not manual.speed_hold_status().enabled and manual.speed_hold_status().setpoint == requested
			and manual.throttle > 0.0, "Direct throttle input cleanly overrides longitudinal control")
		manual.change_speed_pilot_control(0.11, -4.0)
		_expect(not manual.speed_hold_status().enabled and manual.speed_hold_status().setpoint == requested
			and _near(manual.throttle, 0.29), "With hold off, shared controls operate the original manual throttle only")


func _test_reserve_limit(source: Flight) -> void:
	var limited := Flight.new()
	if not _expect(limited.restore(source.snapshot()) and _setpoint(limited, 60.0), "Set full positive speed before losing reaction fuel"):
		return
	limited.ship.fuel = 0.0
	if not limited.flight_assist:
		limited.set_flight_assist(true)
	_expect(_until(limited, func() -> bool: return _near(limited.speed_hold_status().actual, 42.0, 0.24), 9.0)
		and limited.speed_hold_status().enabled and limited.speed_hold_status().setpoint == 60.0
		and limited.ship.fuel == 0.0,
		"An empty tank limits actual speed to the reserve drive while keeping the explicit 60 m/s setpoint")


func _test_course_and_jump_exclusion() -> void:
	var flight := Flight.new()
	if not _expect(flight.select_target(1) and Fixture.depart(flight) and flight.toggle_speed_hold() and _setpoint(flight, 20.0),
		"An equipped pilot can select a local port and arm independent speed hold"):
		return
	flight.set_autopilot(true)
	if not _expect(flight.autopilot and not flight.speed_hold_status().enabled and flight.speed_hold_status().available
		and flight.speed_hold_status().setpoint == 20.0,
		"Engaging a working course computer disables speed hold and excludes simultaneous flight assistance"):
		return
	if not _expect(flight.toggle_speed_hold() and not flight.autopilot and flight.speed_hold_status().enabled
		and flight.plan_jump(Catalog.VELAR_SYSTEM) and _setpoint(flight, 45.0),
		"Switching back to manual hold cancels course control and allows normal jump approach"):
		return
	_expect(_until(flight, func() -> bool: return flight.speed() > 43.0, 5.0)
		and not flight.jump_status(Catalog.VELAR_SYSTEM).ok and not flight.start_jump() and flight.speed_hold_status().enabled,
		"The held speed still obeys the jump drive's normal speed gate")
	if not _expect(_setpoint(flight, 35.0)
		and _until(flight, func() -> bool: return flight.jump_status(Catalog.VELAR_SYSTEM).ok, 15.0)
		and flight.start_jump(), "Physically leave departure exclusion and start a normal jump"):
		return
	_expect(not flight.speed_hold_status().enabled and not flight.speed_hold_status().available and not flight.toggle_speed_hold()
		and flight.speed_hold_status().setpoint == 35.0,
		"Charging excludes velocity control without losing the saved signed setpoint")
	_expect(_until(flight, func() -> bool: return flight.system_id == Catalog.VELAR_SYSTEM, 4.0)
		and not flight.speed_hold_status().enabled and flight.speed_hold_status().available,
		"Arrival re-enables manual access without forcing a saved velocity")
	_expect(flight.toggle_speed_hold() and flight.start_rendezvous(10) and flight.rendezvous_active
		and not flight.speed_hold_status().enabled and flight.speed_hold_status().setpoint == 35.0,
		"Engaging real rendezvous assistance also releases the independent longitudinal controller")


func _test_blocked_speed_hold() -> void:
	var flight := Flight.new()
	if not _expect(Fixture.depart(flight) and flight.toggle_speed_hold() and _setpoint(flight, 12.0),
		"Arm velocity hold before a controlled inbound shutter approach"):
		return
	flight.position = flight.dock_hatch_position(0) + Vector3.BACK * 0.04
	flight.velocity = flight.target_velocity(0) + Vector3.FORWARD * 12.0
	flight.yaw = 0.0
	flight.pitch = 0.0
	_tick(flight)
	_expect(flight.status_event == "dock_denied" and not flight.speed_hold_status().enabled
		and flight.speed_hold_status().setpoint == 12.0 and flight.ship.hull == 100.0,
		"A real closed shutter releases speed hold without overriding the collision notice or programmed speed")


func _setpoint(flight: Flight, speed: float) -> bool:
	var previous := float(flight.speed_hold_status().setpoint)
	return _near(previous, speed) or flight.adjust_speed_hold(speed - previous) and _near(flight.speed_hold_status().setpoint, speed)


func _near(actual: float, wanted: float, tolerance := 0.00001) -> bool:
	return absf(actual - wanted) < tolerance


func _until(flight: Flight, reached: Callable, timeout_seconds: float) -> bool:
	for _frame in range(ceili(timeout_seconds / STEP)):
		if reached.call():
			return true
		_tick(flight)
	return reached.call()


func _step(flight: Flight, seconds: float) -> void:
	for _frame in range(roundi(seconds / STEP)):
		_tick(flight)


func _tick(flight: Flight) -> void:
	flight.update(STEP, Vector2.ZERO, 0.0, false, false)


func _expect(value: bool, description: String) -> bool:
	_checks += 1
	if not value:
		_failures.append("FAIL: " + description)
	return value
