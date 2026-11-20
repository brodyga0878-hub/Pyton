extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Rig := preload("res://scripts/mining_rig.gd")
const ASTEROID := Flight.ASTEROID_TARGET
const STEP := 1.0 / 60.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_manual_landing()
	_test_reversal()
	_test_automatic_landing()
	_test_station_docking()
	_test_jump_stowage()
	print("Landing gear integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_manual_landing() -> void:
	var flight := _pad_approach()
	var status := flight.surface_status()
	if not _expect(status.pad and status.speed_ok and status.height_ok and status.slope_ok and status.aim_ok
		and not status.gear_ok and not status.ok, "A geometrically valid approach cannot land with the gear stowed"):
		return
	_expect(not flight.dock_action() and flight.gear_deployed and flight.status_event == "gear_deploy",
		"The normal landing action requests deployment without touching down")
	_tick(flight, 0.59)
	_expect(flight.gear_extension > 0.0 and flight.gear_extension < 1.0 and not flight.surface_status().ok
		and not flight.dock_action() and not flight.landed,
		"Touchdown is still blocked while the struts are moving")
	var checkpoint: Dictionary = JSON.parse_string(JSON.stringify(flight.snapshot()))
	var reopened := Flight.new()
	if not _expect(reopened.restore(checkpoint) and reopened.gear_deployed
		and is_equal_approx(reopened.gear_extension, flight.gear_extension) and not reopened.gear_status().locked,
		"A cold restart restores the requested direction and partial travel"):
		return
	var malformed := checkpoint.duplicate(true)
	malformed.gear_extension = 1.01
	_expect(not reopened.restore(malformed) and is_equal_approx(reopened.gear_extension, flight.gear_extension),
		"Save loading rejects impossible travel without changing the live gear")
	malformed = checkpoint.duplicate(true)
	malformed.erase("gear_deployed")
	_expect(not reopened.restore(malformed), "A current save must include the gear command")
	var migrated_airborne := Flight.new()
	_expect(migrated_airborne.restore(_legacy(checkpoint)) and migrated_airborne.gear_extension == 0.0
		and not migrated_airborne.gear_deployed, "A 0.58 airborne save starts with the gear stowed")
	_tick(reopened, Flight.GEAR_TRAVEL_SECONDS - 0.59 - STEP * 2.0)
	_expect(not reopened.gear_status().locked and not reopened.surface_status().gear_ok,
		"The remaining deployment time is preserved after loading")
	_tick(reopened, STEP * 3.0)
	_expect(reopened.gear_status().locked and reopened.status_event == "gear_ready",
		"The mechanism reports completed deployment after the remaining time")
	_align_with_pad(reopened)
	if not _expect(reopened.surface_status().ok and reopened.dock_action() and reopened.landed_site == ASTEROID
		and reopened.gear_status().locked and not reopened.gear_action(),
		"Extended gear enables touchdown and cannot be retracted on the ground"):
		return
	reopened.ship.fuel = 0.0
	var landed := reopened.snapshot()
	malformed = landed.duplicate(true)
	malformed.gear_extension = 0.5
	_expect(not reopened.restore(malformed) and reopened.gear_status().locked,
		"A grounded save cannot include an incomplete deployment")
	var earlier := Flight.new()
	if not _expect(earlier.restore(_legacy(landed)) and earlier.landed and earlier.gear_status().locked
		and earlier.ship.fuel == 0.0, "A 0.58 grounded save restores with locked gear and preserves the empty fuel tank"):
		return
	_expect(earlier.mine_action() and earlier.mining.phase == Rig.DEPLOYING and not earlier.dock_action()
		and earlier.landed and earlier.gear_status().locked,
		"The mining interlock still holds the landed ship and its gear")
	_expect(reopened.dock_action() and not reopened.landed and not reopened.gear_deployed
		and reopened.gear_extension == 1.0 and reopened.ship.fuel == 0.0,
		"Reserve takeoff works with extended gear and requests its retraction")
	_tick(reopened, Flight.GEAR_TRAVEL_SECONDS + STEP)
	_expect(reopened.gear_extension == 0.0 and not reopened.gear_deployed and not reopened.landed,
		"The landing gear stows after takeoff with an empty tank")


func _test_reversal() -> void:
	var flight := _pad_approach()
	_expect(flight.gear_action(), "The airborne gear control requests extension")
	_tick(flight, 0.56)
	var extension := flight.gear_extension
	_expect(extension > 0.0 and extension < 1.0 and flight.gear_action()
		and is_equal_approx(flight.gear_extension, extension) and not flight.gear_deployed,
		"Reversing the actuator does not snap the struts to an endpoint")
	_tick(flight, 0.2)
	_expect(flight.gear_extension > 0.0 and flight.gear_extension < extension and not flight.surface_status().gear_ok,
		"The gear reverses through its physical travel without enabling touchdown")
	_tick(flight, 0.38)
	_expect(flight.gear_extension == 0.0 and flight.status_event == "gear_stowed",
		"The reversed deployment reaches the stowed stop")


func _test_automatic_landing() -> void:
	var flight := Flight.new()
	Fixture.launch(flight)
	flight.select_target(ASTEROID)
	flight.set_autopilot(true)
	var moving_before_touchdown := false
	for _frame in range(ceili(110.0 / STEP)):
		if flight.landed or not flight.autopilot:
			break
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
		moving_before_touchdown = moving_before_touchdown or (
			not flight.landed and flight.gear_extension > 0.0 and flight.gear_extension < 1.0)
	_expect(moving_before_touchdown and flight.landed_site == ASTEROID and flight.gear_status().locked
		and is_equal_approx(flight.ship.hull, 100.0), "Autopilot extends its gear in flight and lands on a marked pad")


func _test_station_docking() -> void:
	var flight := Flight.new()
	_expect(not flight.gear_action() and flight.gear_extension == 0.0,
		"Gear is stowed and its command is unavailable at an orbital berth")
	Fixture.launch(flight)
	flight.select_target(1)
	flight.position = flight.docking_position(1) + flight.station_axis(1) * 12.0
	flight.velocity = flight.target_velocity(1)
	if not _expect(flight.dock_clearance_action(), "Station access does not depend on the landing gear"):
		return
	_tick(flight, float(flight.dock_access_status(1).wait) + STEP)
	_expect(flight.dock_access_status(1).ready, "Orbital clearance is granted with the gear stowed")
	flight.position = flight.docking_position(1) + flight.station_axis(1) * 1.0
	flight.velocity = flight.target_velocity(1)
	flight.yaw = 0.0
	flight.pitch = 0.0
	flight.roll = flight.station_angle(1)
	_expect(flight.docking_guidance().ok and flight.dock_action() and flight.docked == 1
		and not flight.gear_deployed and flight.gear_extension == 0.0,
		"An orbital approach remains independent of touchdown gear")
	var docked := flight.snapshot()
	docked.gear_extension = 1.0
	docked.gear_deployed = true
	_expect(not flight.restore(docked) and flight.docked == 1 and flight.gear_extension == 0.0,
		"Loading rejects fully extended gear at an orbital berth")


func _test_jump_stowage() -> void:
	var flight := Flight.new()
	Fixture.launch(flight)
	flight.position = Vector3(-7000.0, 4200.0, 4500.0)
	flight.velocity = Vector3.ZERO
	_expect(flight.cycle_time_scale() and flight.time_scale > 1 and flight.gear_action()
		and flight.time_scale == 1 and not flight.time_status().allowed,
		"Starting gear motion safely ends time acceleration until the actuator settles")
	_tick(flight, Flight.GEAR_TRAVEL_SECONDS + STEP)
	if not _expect(flight.gear_status().locked and flight.plan_jump(Catalog.VELAR_SYSTEM) and flight.start_jump()
		and not flight.gear_deployed and not flight.gear_action(),
		"Jump charging requests retraction and blocks a conflicting gear command"):
		return
	_tick(flight, Flight.JUMP_CHARGE + STEP)
	_expect(flight.system_id == Catalog.VELAR_SYSTEM and flight.status_event == "jump_complete"
		and flight.gear_extension == 0.0 and not flight.gear_deployed,
		"Hyperspace arrival leaves the gear fully stowed")


func _pad_approach() -> Flight:
	var flight := Flight.new()
	Fixture.launch(flight)
	flight.select_target(ASTEROID)
	_align_with_pad(flight)
	return flight


func _align_with_pad(flight: Flight) -> void:
	flight.position = flight.target_contact(ASTEROID) + Vector3.BACK * 4.0
	flight.velocity = flight.target_velocity(ASTEROID)
	flight.yaw = 0.0
	flight.pitch = 0.0
	flight.roll = 0.0


func _legacy(snapshot: Dictionary) -> Dictionary:
	var older := snapshot.duplicate(true)
	older.schema = 18
	older.ship.erase("mining_laser")
	older.ship.erase("fragment_collector")
	older.ship.erase("hull_id")
	older.ship.erase("jump_fuel")
	older.mining.cargo.erase("hydrogen")
	older.mining.reserves.resize(Catalog.PRE_GAS_DESTINATION_COUNT)
	for stocks: Dictionary in older.market.values():
		stocks.erase("hydrogen")
	older.erase("gear_extension")
	older.erase("gear_deployed")
	return older


func _tick(flight: Flight, seconds: float) -> void:
	flight.update(seconds, Vector2.ZERO, 0.0, false, false)


func _expect(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
	return condition
