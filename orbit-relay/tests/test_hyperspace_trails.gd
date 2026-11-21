extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Freight := preload("res://scripts/npc_freight.gd")
const Trace := preload("res://scripts/hyperspace_trails.gd")
const Session := preload("res://scripts/session_io.gd")
const Main := preload("res://main.tscn")
const HOME := Catalog.HOME_SYSTEM
const CHOSEN := Catalog.VELAR_SYSTEM
const REFUGE := Catalog.FRINGE_SYSTEM
const STEP := Fixture.STEP
const SAVE := "user://hyperspace-trace-test.json"

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_shuttles()
	_verify_ordinary_jump()
	_verify_emergency_jump()
	await _verify_controls()
	print("Hyperspace trail and emergency integration: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _verify_shuttles() -> void:
	var flight := Flight.new()
	_expect(flight.freight.activate_frontier(Catalog.HEATHER_SYSTEM, 0.0), "Activate the actual frontier shuttle")
	var departure := Freight.FRONTIER_DEPARTURE + Freight.LOCAL_TRANSIT_SECONDS
	var arrival := Freight.FRONTIER_DEPARTURE + Freight.TRANSIT_SECONDS - Freight.LOCAL_TRANSIT_SECONDS
	flight._advance_background_clock(departure - 1.0)
	_expect(flight.freight.hyperspace_windows(REFUGE, flight.orbit_time).is_empty()
		and flight.freight.hyperspace_windows(Catalog.HEATHER_SYSTEM, flight.orbit_time).is_empty(),
		"No signal appears while the shuttle is still flying through its departure lane")
	flight._advance_background_clock(2.0)
	var left := flight.freight.hyperspace_windows(REFUGE, flight.orbit_time)
	var right := flight.freight.hyperspace_windows(Catalog.HEATHER_SYSTEM, flight.orbit_time)
	if _expect(left.size() == 1 and right.size() == 1, "The actual departure exposes two local trail windows"):
		_expect(left[0].kind == Trace.DEPARTURE and right[0].kind == Trace.INCOMING
			and float(right[0].eta) == arrival - flight.orbit_time and int(right[0].destination) == Catalog.HEATHER_SYSTEM
			and int(right[0].cargo) > 0 and float(left[0].eta) == float(right[0].eta),
			"The live windows identify opposite endpoints with actual arrival time and boarded payload")
	flight._advance_background_clock(arrival + 1.0 - flight.orbit_time)
	var residual := flight.freight.hyperspace_windows(Catalog.HEATHER_SYSTEM, flight.orbit_time)
	_expect(residual.size() == 1 and residual[0].kind == Trace.RESIDUAL and float(residual[0].eta) < 0.0,
		"The destination signal becomes an arrival remnant as the ship emerges from hyperspace")
	flight._advance_background_clock(Freight.TRACE_RESIDUAL_SECONDS)
	_expect(flight.freight.hyperspace_windows(Catalog.HEATHER_SYSTEM, flight.orbit_time).is_empty(),
		"Expired shuttle windows disappear while the vessel continues its timetable")


func _verify_ordinary_jump() -> void:
	var flight := _outfitted()
	if not _expect(flight.jump_drive_status().analyzer and not flight.jump_drive_status().fault
		and flight.credits == 500 - Trace.ANALYZER_COST and not flight.service_action("hyperspace_analyzer"),
		"Installing the analyzer pays once and enters the equipment state"):
		return
	_depart_open(flight)
	flight.ship.hull = 22.0
	var fuel := flight.ship.jump_fuel
	if not _expect(flight.plan_jump(CHOSEN) and flight.start_jump() and _until(flight,
		func() -> bool: return flight.jump_progress_status().is_transit, 3.0),
		"A damaged ship can still opt for a normal safe jump"):
		return
	var departure: Array = flight.snapshot().hyperspace.trails
	_expect(departure.size() == 1 and departure[0].kind == Trace.DEPARTURE and departure[0].origin == HOME
		and departure[0].destination == CHOSEN and departure[0].due > departure[0].created,
		"An actual paid departure creates one source record with planned arrival time")
	_expect(flight.local_hyperspace_trails().is_empty(),
		"In transit, the ship cannot analyze objects in either local system")
	var fare: int = flight.jump_progress_status().fare
	if not _expect(_until(flight, func() -> bool: return flight.system_id == CHOSEN, 1.0) and not flight.jump_drive_status().fault
		and flight.ship.jump_fuel == fuel - fare,
		"Normal arrival keeps the selected system and charges no emergency or extra fare"):
		return
	var echo := flight.hyperspace_trail_status()
	if not _expect(echo.readable and echo.kind == Trace.RESIDUAL and echo.origin == HOME and echo.destination == CHOSEN
		and echo.eta < 0.0 and absf(float(echo.mass) - 50.8) < 0.01,
		"At the physical exit point the installed analyzer reports original system, destination, residual and mass"):
		return
	var id: String = echo.id
	_expect(flight.target_hyperspace_trail(id) and flight.hyperspace_trail_status().tracking
		and flight.analyze_hyperspace_trail(id) and flight.status_event == "hyperspace_analyzed",
		"The player can mark and read the exact active trail")
	var cold := Flight.new()
	_expect(Session.save_state(flight.snapshot(), SAVE) == OK and cold.restore(Session.load_state(SAVE))
		and cold.hyperspace_trail_status(id).readable,
		"The analyzer and residual survive the actual JSON save and cold restore")
	cold.position += Vector3.RIGHT * (Trace.ANALYZER_RANGE + 40.0)
	_expect(cold.hyperspace_trail_status(id).active and not cold.hyperspace_trail_status(id).readable
		and cold.hyperspace_trail_status(id).origin == -1 and not cold.analyze_hyperspace_trail(id),
		"The raw echo can be tracked out of range but the analyzer withholds unreadable details")
	cold._advance_background_clock(Trace.LIFETIME + 1.0)
	_expect(not cold.hyperspace_trail_status(id).active and cold.snapshot().hyperspace.trails.is_empty(),
		"Player drive records fade on simulation time")


func _verify_emergency_jump() -> void:
	var flight := Flight.new()
	_depart_open(flight)
	flight.plan_jump(CHOSEN)
	_expect(not flight.emergency_jump_status().ok and not flight.start_jump(true),
		"A healthy ship does not arm the override")
	flight.ship.hull = 22.0
	var fuel := flight.ship.jump_fuel
	var status := flight.emergency_jump_status()
	if not _expect(status.ok and status.destination == REFUGE and status.requested == CHOSEN and status.fault_risk
		and flight.start_jump(true) and flight.jump_progress_status().emergency and flight.cancel_jump()
		and flight.ship.jump_fuel == fuel and flight.snapshot().hyperspace.trails.is_empty(),
		"A critically damaged pilot can explicitly cancel the unpaid diversion without producing a trace"):
		return
	if not _expect(flight.start_jump(true) and _until(flight, func() -> bool: return flight.jump_progress_status().is_transit, 3.0),
		"Explicit rearm commits the emergency's distinct destination and fare"):
		return
	var ticket := flight.snapshot()
	_expect(ticket.jump_transit.get("requested") == CHOSEN and ticket.jump_target == REFUGE
		and ticket.jump_transit.fare == status.cost and ticket.jump_transit.duration == status.duration,
		"The paid record preserves requested route, real destination and diverted calendar duration")
	var invalid := ticket.duplicate(true)
	invalid.jump_transit.requested = REFUGE
	var resumed := Flight.new()
	_expect(not resumed.restore(invalid), "Reject a corrupt emergency receipt with no genuine diversion")
	if not _expect(Session.save_state(ticket, SAVE) == OK and resumed.restore(Session.load_state(SAVE))
		and resumed.jump_progress_status().requested == CHOSEN and resumed.ship.jump_fuel == fuel - float(status.cost),
		"Cold load preserves the emergency receipt and already-debited fuel"):
		return
	if not _expect(_until(resumed, func() -> bool: return resumed.system_id == REFUGE, 1.0)
		and resumed.status_event == "emergency_jump_arrival" and resumed.jump_drive_status().fault
		and resumed.ship.jump_fuel == fuel - float(status.cost),
		"Emergency exits in the selected refuge, locks the damaged drive and charges exactly once"):
		return
	var unreadable := resumed.hyperspace_trail_status()
	_expect(unreadable.active and not unreadable.readable and unreadable.origin == -1
		and not resumed.analyze_hyperspace_trail(),
		"A detectable trace exposes no route or mass without the analyzer")
	_expect(resumed.plan_jump(HOME) and not resumed.jump_status(HOME).ok and not resumed.start_jump()
		and not resumed.service_action("jump_repair"), "Fault blocks a new jump and onboard software repair")
	var port := int(Catalog.system(REFUGE).arrival_port)
	resumed.select_target(port)
	resumed.set_autopilot(true)
	if not _expect(_until(resumed, func() -> bool: return resumed.docked == port, 120.0),
		"The refuge has a reachable dock even with a failed jump drive"):
		return
	var parked := Flight.new()
	if not _expect(parked.restore(resumed.snapshot()) and parked.jump_drive_status().fault
		and parked.service_offer("jump_repair").allowed, "Fault and service entitlement survive parking and restart"):
		return
	var credits := parked.credits
	_expect(parked.service_action("jump_repair") and parked.credits == credits and not parked.jump_drive_status().fault
		and not parked.service_action("jump_repair"),
		"A free port restart repairs the drive once and never requires a credit balance")
	var reserve := Flight.new()
	_depart_open(reserve)
	reserve.ship.hull = 38.0
	reserve.ship.jump_fuel = 27.0
	reserve.plan_jump(REFUGE)
	_expect(not reserve.start_jump() and reserve.ship.jump_fuel == 27.0 and reserve.emergency_jump_status().destination == CHOSEN
		and reserve.start_jump(true) and _until(reserve, func() -> bool: return reserve.system_id == CHOSEN, 4.0)
		and reserve.ship.jump_fuel == 1.0 and not reserve.jump_drive_status().fault,
		"A moderately damaged ship can divert to a cheaper real port while the intended hop is unaffordable")


func _verify_controls() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1544, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := Main.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game._audio.set_level(0)
	var flight := _outfitted()
	game.flight = flight
	_depart_open(flight)
	flight.ship.hull = 22.0
	flight.plan_jump(CHOSEN)
	game._galaxy.open(flight)
	await process_frame
	var chart: Node = game._galaxy
	_expect(chart._emergency_button.is_visible_in_tree() and not chart._emergency_button.disabled
		and chart._emergency_label.text.contains(Catalog.system(REFUGE).name),
		"The real galaxy console shows the actual refuge and enables a guarded emergency control")
	_tap(viewport, chart._emergency_button)
	_expect(chart._emergency_armed and flight.jump_seconds_left == 0.0,
		"The first touch confirms intent without starting the charge")
	_tap(viewport, chart._emergency_button)
	_expect(not chart.is_open() and flight.jump_progress_status().emergency and flight.jump_seconds_left > 0.0,
		"The second touch starts the emergency charge and dismisses the overlay")
	_until(flight, func() -> bool: return flight.system_id == REFUGE, 4.0)
	game._galaxy.open(flight)
	await process_frame
	_expect(chart._echo_analyze.is_visible_in_tree() and not chart._echo_analyze.disabled
		and chart._echo_label.text.contains(Catalog.system(HOME).name),
		"The real map displays an analyzed trail at the actual jump exit")
	_tap(viewport, chart._echo_analyze)
	_expect(chart.is_open(), "Analysis keeps the map open for reading")
	_tap(viewport, chart._echo_track)
	_expect(not chart.is_open() and flight.hyperspace_trail_status().tracking,
		"Tracking from the map returns to piloting with the selected contact")
	viewport.queue_free()
	await process_frame


func _outfitted() -> Flight:
	var flight := Flight.new()
	flight.credits = 500
	flight.service_action("hyperspace_analyzer")
	return flight


func _depart_open(flight: Flight) -> void:
	Fixture.launch(flight)
	flight.position = Vector3(2400.0, 8100.0, 8000.0)
	flight.velocity = Vector3.ZERO


func _until(flight: Flight, done: Callable, maximum: float) -> bool:
	for _step in range(ceili(maximum / STEP)):
		if done.call():
			return true
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	return done.call()


func _tap(viewport: SubViewport, button: Button) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 9
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		viewport.push_input(event, true)


func _expect(value: bool, description: String) -> bool:
	_checks += 1
	if not value:
		_failures += 1
		printerr(description)
	return value
