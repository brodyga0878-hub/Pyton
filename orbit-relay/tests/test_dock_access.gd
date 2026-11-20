extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Access := preload("res://scripts/dock_access.gd")
const Freight := preload("res://scripts/npc_freight.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Fixture = preload("res://tests/flight_fixture.gd")
const PORT := 0
const ALTERNATE_PORT := 1
const STEP := 1.0 / 60.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_test_request_zone()
	_test_hatch_passage()
	_test_freight_wait()
	_test_expiry_and_retarget()
	_test_save_and_reload()
	print("Dock access integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_request_zone() -> void:
	var flight := Flight.new()
	_expect(not flight.dock_clearance_action(), "Inbound authorization is unavailable while already docked")
	flight = _approach(PORT)
	_set_axial_pose(flight, PORT, -30.0)
	_expect(not flight.dock_access_status(PORT).request_available and not flight.dock_clearance_action(),
		"A ship behind the station cannot request an inbound slot")
	_set_axial_pose(flight, PORT, Flight.DOCK_GUIDE_DISTANCE + 0.5)
	_expect(not flight.dock_access_status(PORT).request_available and not flight.dock_clearance_action(),
		"A ship outside the approach zone cannot reserve a slot")


func _test_hatch_passage() -> void:
	var flight := _approach(PORT)
	_set_axial_pose(flight, PORT, Access.HATCH_AXIS_OFFSET + 0.04, -8.0)
	var guide := flight.docking_guidance()
	_expect(guide.position_ok and not guide.cleared and not guide.ok,
		"Correct geometry by itself does not authorize docking")
	_tick(flight)
	_expect(_distance_along_axis(flight, PORT) >= Access.HATCH_AXIS_OFFSET - 0.03 and flight.docked == -1,
		"The physical closed hatch blocks a ship flying inward through its plane")
	_set_axial_pose(flight, PORT, 12.0)
	_expect(not flight.dock_action() and flight.dock_access_status(PORT).phase == "queued"
		and flight.docked == -1, "Ordinary dock input can request access without prematurely docking")
	var queue: Dictionary = flight.snapshot().dock_access
	_expect(not flight.dock_clearance_action() and flight.snapshot().dock_access == queue,
		"A duplicate request does not reset the reserved time slot")
	var to_open: float = flight.dock_access_status(PORT).wait
	_tick(flight, to_open - Access.OPENING_SECONDS * 0.5)
	var partial := flight.dock_access_status(PORT)
	_expect(partial.phase == "opening" and partial.open_fraction > 0.0
		and partial.open_fraction < 1.0 and not partial.ready,
		"The moving hatch has a partial aperture before authorization begins")
	_set_axial_pose(flight, PORT, Access.HATCH_AXIS_OFFSET + 0.04, -8.0)
	_tick(flight)
	_expect(_distance_along_axis(flight, PORT) >= Access.HATCH_AXIS_OFFSET - 0.03 and not flight.dock_action()
		and flight.docked == -1, "The partial aperture blocks both physical crossing and manual capture")
	_set_axial_pose(flight, PORT, 12.0)
	_tick(flight, float(partial.wait) + STEP)
	var open := flight.dock_access_status(PORT)
	_expect(open.phase == "open" and open.ready and open.open_fraction == 1.0 and open.remaining > 0.0,
		"Finishing the gate movement opens a timed access window")
	_set_axial_pose(flight, PORT, Access.HATCH_AXIS_OFFSET + 0.04, -8.0)
	_tick(flight)
	_expect(_distance_along_axis(flight, PORT) < Access.HATCH_AXIS_OFFSET - 0.02 and flight.docked == -1,
		"The open hatch permits actual inward flight without teleporting the ship")
	_set_axial_pose(flight, PORT, _distance_along_axis(flight, PORT))
	_expect(flight.docking_guidance().ok and flight.dock_action() and flight.docked == PORT
		and flight.dock_access_status(PORT).phase == "closing", "Manual capture consumes the booked access and closes the hatch")
	var docked_save := _json(flight.snapshot())
	_expect(flight.restore(docked_save) and flight.docked == PORT and flight.dock_access_status(PORT).phase == "closing",
		"Reloading a new berth retains the timed close without reviving its authorization")
	_expect(flight.dock_action() and flight.docked == PORT and flight.departure_status().active,
		"An ordinary launch waits for its own authorization after inbound capture")
	_expect(Fixture.await_departure(flight) and _distance_along_axis(flight, PORT) > Access.HATCH_AXIS_OFFSET,
		"The outbound passage finishes beyond the hatch")


func _test_freight_wait() -> void:
	var quiet := _approach(PORT)
	var busy := _approach(PORT, Freight.FIRST_DEPARTURES[0] - 5.0)
	var departures := busy.freight_status(PORT)
	_expect(departures.size() > 0 and not departures[0].in_transit
		and departures[0].origin == PORT and is_equal_approx(departures[0].departure_eta, 5.0),
		"The approach reaches the ordinary port five seconds before a real NPC departure")
	_expect(quiet.dock_clearance_action() and busy.dock_clearance_action(),
		"The station schedules an inbound slot both with and without imminent traffic")
	var normal: float = quiet.dock_access_status(PORT).wait
	var delayed: float = busy.dock_access_status(PORT).wait
	_expect(is_equal_approx(normal, Access.HEADING_SECONDS + Access.OPENING_SECONDS) and delayed > normal + 4.0
		and delayed <= Access.MAX_QUEUE_SECONDS + Access.OPENING_SECONDS + STEP,
		"The real departure delays the inbound slot by a bounded amount")
	_tick(busy, normal)
	_expect(busy.dock_access_status(PORT).phase == "queued" and not busy.dock_access_status(PORT).ready,
		"NPC traffic still occupies the slot after the ordinary quiet approach would open")
	_tick(busy, delayed - normal + STEP)
	_expect(busy.dock_access_status(PORT).ready,
		"The deferred slot opens after the NPC departure and never leaves the player waiting indefinitely")
	var arrival := _approach(ALTERNATE_PORT, Freight.FIRST_DEPARTURES[0] + Freight.TRANSIT_SECONDS - 4.0)
	var arrivals := arrival.freight_status(ALTERNATE_PORT)
	_expect(arrivals.size() > 0 and arrivals[0].in_transit and arrivals[0].destination == ALTERNATE_PORT
		and is_equal_approx(arrivals[0].arrival_eta, 4.0) and arrival.dock_clearance_action()
		and is_equal_approx(arrival.dock_access_status(ALTERNATE_PORT).wait, 4.0 + Access.TRAFFIC_BUFFER + Access.OPENING_SECONDS),
		"An actual arriving freighter also keeps the hatch reserved until its berth clears")


func _test_expiry_and_retarget() -> void:
	var flight := _approach(PORT)
	_expect(flight.dock_clearance_action(), "The first station accepts an inbound request")
	_tick(flight, float(flight.dock_access_status(PORT).wait) + STEP)
	var ready := flight.dock_access_status(PORT)
	_expect(ready.ready and not flight.dock_clearance_action()
		and is_equal_approx(ready.remaining, flight.dock_access_status(PORT).remaining),
		"Repeated calls cannot lengthen an open permit")
	_tick(flight, float(ready.remaining) + Access.CLOSING_SECONDS * 0.4)
	var closing := flight.dock_access_status(PORT)
	_expect(closing.phase == "closing" and closing.open_fraction > 0.0
		and not closing.ready and not flight.dock_clearance_action(),
		"An expired permit closes the hatch and rejects a request until movement finishes")
	_set_axial_pose(flight, PORT, Access.HATCH_AXIS_OFFSET + 0.04, -8.0)
	_tick(flight)
	_expect(_distance_along_axis(flight, PORT) >= Access.HATCH_AXIS_OFFSET - 0.03 and flight.docked == -1,
		"The closing hatch also blocks new inward passage")
	_set_axial_pose(flight, PORT, 12.0)
	_tick(flight, float(closing.wait) + STEP)
	_expect(flight.dock_access_status(PORT).phase == "closed" and flight.dock_clearance_action(),
		"After the old window has completely closed the port accepts a new request")
	_expect(flight.select_target(ALTERNATE_PORT) and not flight.dock_access_status(ALTERNATE_PORT).ready
		and flight.dock_access_status(PORT).phase == "closed",
		"Selecting a different rotating port does not inherit the old reservation")
	_set_axial_pose(flight, ALTERNATE_PORT, 12.0)
	_expect(flight.dock_clearance_action() and flight.dock_access_status(ALTERNATE_PORT).phase == "queued",
		"The new port grants a new slot independently")
	_tick(flight, float(flight.dock_access_status(ALTERNATE_PORT).wait) + STEP)
	_expect(flight.dock_access_status(ALTERNATE_PORT).ready and flight.select_target(PORT)
		and not flight.dock_access_status(ALTERNATE_PORT).ready and not flight.dock_access_status(PORT).ready,
		"Discarding an open permit cannot leave its previous hatch authorized")


func _test_save_and_reload() -> void:
	var flight := _approach(ALTERNATE_PORT)
	_expect(flight.dock_clearance_action(), "Create a queue through the live flight action")
	_tick(flight, 1.25)
	var checkpoint := _json(flight.snapshot())
	var remaining: float = flight.dock_access_status(ALTERNATE_PORT).wait
	var resumed := Flight.new()
	if not _expect(checkpoint.schema == Flight.SAVE_SCHEMA and resumed.restore(checkpoint)
		and resumed.dock_access_status(ALTERNATE_PORT).phase == "queued"
		and is_equal_approx(resumed.dock_access_status(ALTERNATE_PORT).wait, remaining),
		"A JSON cold reload restores the live queue with its exact remaining duration"):
		return
	var damaged := checkpoint.duplicate(true)
	damaged.dock_access.port = PORT
	_expect(not resumed.restore(damaged) and resumed.dock_access_status(ALTERNATE_PORT).phase == "queued",
		"A live queue cannot be reassigned to a different selected port by changing the save")
	damaged = checkpoint.duplicate(true)
	damaged.dock_access.opening_at = -1.0
	_expect(not resumed.restore(damaged) and is_equal_approx(resumed.dock_access_status(ALTERNATE_PORT).wait, remaining),
		"Invalid timing cannot mutate the current queue")
	_tick(resumed, remaining + STEP)
	_expect(resumed.dock_access_status(ALTERNATE_PORT).ready,
		"A resumed queue opens at the originally booked time")
	var open_checkpoint := _json(resumed.snapshot())
	var open_time: float = resumed.dock_access_status(ALTERNATE_PORT).remaining
	_expect(resumed.restore(open_checkpoint) and resumed.dock_access_status(ALTERNATE_PORT).ready
		and is_equal_approx(resumed.dock_access_status(ALTERNATE_PORT).remaining, open_time),
		"Reloading an already open hatch does not restart its remaining permit")
	_set_axial_pose(resumed, ALTERNATE_PORT, Access.HATCH_AXIS_OFFSET - 0.04, 8.0)
	var legacy := _json(resumed.snapshot())
	legacy.schema = 20
	legacy.ship.erase("mining_laser")
	legacy.ship.erase("fragment_collector")
	legacy.ship.erase("hydrogen_scoop")
	legacy.ship.erase("fuel_pump")
	legacy.ship.erase("pump_mode")
	legacy.mining.reserves.resize(Catalog.AUTHORED_DESTINATION_COUNT)
	legacy.ship.erase("hull_id")
	legacy.erase("dock_access")
	var earlier := Flight.new()
	if not _expect(earlier.restore(legacy) and earlier.dock_access_status(ALTERNATE_PORT).phase == "closed"
		and _distance_along_axis(earlier, ALTERNATE_PORT) < Access.HATCH_AXIS_OFFSET,
		"A 0.60 save inside the new collar loads without creating a permit"):
		return
	_tick(earlier)
	_expect(_distance_along_axis(earlier, ALTERNATE_PORT) > Access.HATCH_AXIS_OFFSET + 0.02
		and earlier.docked == -1, "A legacy ship already within the collar can leave outward through the closed plane")


func _approach(port: int, epoch := 0.0) -> Flight:
	var flight := Flight.new()
	if epoch > 0.0:
		_tick(flight, epoch)
	Fixture.launch(flight)
	flight.select_target(port)
	flight.set_flight_assist(false)
	_set_axial_pose(flight, port, 32.0)
	return flight


func _set_axial_pose(flight: Flight, port: int, distance: float, radial_speed := 0.0) -> void:
	var axis := flight.station_axis(port)
	flight.position = flight.docking_position(port) + axis * distance
	flight.velocity = flight.target_velocity(port) + axis * radial_speed
	flight.yaw = 0.0
	flight.pitch = 0.0
	flight.roll = flight.station_angle(port)


func _distance_along_axis(flight: Flight, port: int) -> float:
	return (flight.position - flight.docking_position(port)).dot(flight.station_axis(port))


func _tick(flight: Flight, duration := STEP) -> void:
	flight.update(duration, Vector2.ZERO, 0.0, false, false)


func _json(value: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value, "", true, true)) as Dictionary


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
