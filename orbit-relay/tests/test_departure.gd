extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Access := preload("res://scripts/dock_access.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const Main := preload("res://main.tscn")
const PORT := 0
const LOCAL_DESTINATION := 3
const STEP := Fixture.STEP

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_queue_and_cancel()
	_test_reload_in_transit()
	_test_previous_berth()
	await _test_departure_touch()
	print("Dock departure integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_queue_and_cancel() -> void:
	var flight := Flight.new()
	flight.credits = 1000
	flight.ship.fuel = 0.0
	var original_berth := flight.position
	_expect(flight.departure_status().phase == "idle" and flight.cycle_time_scale()
		and flight.time_scale > 1, "A ship can prepare its flight before requesting exit")
	_expect(flight.dock_action() and flight.departure_status().phase == "waiting"
		and flight.departure_status().can_cancel and flight.docked == PORT
		and flight.position == original_berth and flight.time_scale == 1,
		"Departure requests a slot without teleporting the ship and restores ordinary time")
	_expect(not flight.cycle_time_scale() and not flight.service_offer("refuel").allowed
		and not flight.market_quote("ice", "buy", 1).ok,
		"Time acceleration and port transactions stay unavailable while exit is pending")
	var old_schedule: Dictionary = flight.snapshot().dock_access
	_tick(flight, 0.25)
	var path := "user://departure-queue.json"
	var cold := Flight.new()
	_expect(SessionIO.save_state(flight.snapshot(), path) == OK and cold.restore(SessionIO.load_state(path))
		and cold.departure_status().phase == "waiting"
		and is_equal_approx(cold.departure_status().wait, flight.departure_status().wait)
		and cold.snapshot().dock_access == old_schedule,
		"A disk reload resumes the queued slot without resetting its wait")
	_expect(cold.dock_action() and not cold.departure_status().active and cold.docked == PORT
		and cold.dock_access_status(PORT).phase == "closed"
		and cold.service_offer("refuel").allowed and cold.market_quote("ice", "buy", 1).ok,
		"Cancelling the queued exit restores the berth and its transactions")
	_tick(cold, Access.MAX_QUEUE_SECONDS + Access.OPENING_SECONDS + Flight.DEPARTURE_SECONDS + 1.0)
	_expect(cold.docked == PORT and not cold.departure_status().active,
		"A cancelled slot never frees the ship when its old scheduled time passes")
	if not _expect(cold.dock_action(), "A fresh exit can be requested after cancelling the first slot"):
		return
	_tick(cold, float(cold.departure_status().wait) - Access.OPENING_SECONDS * 0.6)
	var opening := cold.dock_access_status(PORT)
	if not _expect(opening.phase == "opening" and cold.dock_action(), "The pilot can cancel while the hatch is visibly opening"):
		return
	var closing := cold.dock_access_status(PORT)
	_expect(closing.phase == "closing" and is_equal_approx(opening.open_fraction, closing.open_fraction)
		and cold.docked == PORT and not cold.departure_status().active,
		"Cancelling a half-open hatch reverses it smoothly at the current aperture")
	_expect(SessionIO.save_state(cold.snapshot(), path) == OK and flight.restore(SessionIO.load_state(path))
		and flight.dock_access_status(PORT).phase == "closing",
		"A cancelled partial closure survives an ordinary disk save")
	_tick(flight, float(closing.wait) + STEP)
	_expect(flight.docked == PORT and flight.dock_access_status(PORT).phase == "closed",
		"A partially reversed hatch closes without releasing the ship")


func _test_reload_in_transit() -> void:
	var flight := Flight.new()
	flight.ship.fuel = 0.0
	_expect(flight.select_target(LOCAL_DESTINATION) and flight.plan_route(Catalog.VELAR_SYSTEM)
		and flight.dock_action(), "Local and galactic routes can be planned before the exit request")
	var opening_wait: float = flight.departure_status().wait - Access.OPENING_SECONDS * 0.5
	_tick(flight, opening_wait)
	_expect(flight.departure_status().phase == "opening"
		and flight.departure_status().progress > 0.0 and flight.departure_status().progress < 1.0
		and _axial_distance(flight) < 0.001 and not flight.dock_access_status(PORT).ready,
		"The ship holds its moving berth while the hatch is only partially open")
	for _frame in range(ceili(5.0 / STEP)):
		if flight.departure_status().phase == "transit":
			break
		_tick(flight)
	_expect(flight.departure_status().phase == "transit" and flight.docked == PORT
		and flight.dock_access_status(PORT).ready and not flight.departure_status().can_cancel,
		"The guided traverse begins only at a fully open hatch")
	_tick(flight, Flight.DEPARTURE_SECONDS * 0.45)
	var progress: float = flight.departure_status().progress
	var position := flight.position
	var velocity := flight.velocity
	_expect(progress > 0.4 and progress < 0.5 and _axial_distance(flight) > 1.0
		and _axial_distance(flight) < Access.HATCH_AXIS_OFFSET and not flight.dock_action(),
		"Departure moves continuously toward the hatch and rejects cancellation in transit")
	var checkpoint := flight.snapshot()
	var bad := checkpoint.duplicate(true)
	bad.departure_seconds = Flight.DEPARTURE_SECONDS
	_expect(not flight.restore(bad) and flight.snapshot() == checkpoint,
		"A completed traverse cannot be restored as a departure in progress")
	bad = checkpoint.duplicate(true)
	bad.dock_access.port = -1
	for key in ["requested_at", "opening_at", "closing_at"]:
		bad.dock_access[key] = 0.0
	_expect(not flight.restore(bad) and flight.snapshot() == checkpoint,
		"A guided traverse cannot restore with a missing authorization")
	bad = checkpoint.duplicate(true)
	bad.dock_access.port = LOCAL_DESTINATION
	_expect(not flight.restore(bad) and flight.snapshot() == checkpoint,
		"An otherwise valid permission for a different port cannot release the docked ship")
	var path := "user://departure-transit.json"
	var cold := Flight.new()
	if not _expect(SessionIO.save_state(checkpoint, path) == OK and cold.restore(SessionIO.load_state(path)),
		"Save and restore a ship physically moving toward the hatch"):
		return
	_expect(cold.departure_status().phase == "transit" and is_equal_approx(cold.departure_status().progress, progress)
		and cold.position.distance_to(position) < 0.002 and cold.velocity.distance_to(velocity) < 0.002,
		"Cold restore preserves pose, velocity and progress inside the moving port")
	var launches := 0
	for _frame in range(ceili(5.0 / STEP)):
		flight.status_event = ""
		cold.status_event = ""
		_tick(flight)
		_tick(cold)
		if cold.status_event == "launch":
			launches += 1
			_expect(_axial_distance(cold) >= Flight.DEPARTURE_DISTANCE - 0.001
				and (cold.velocity - cold.target_velocity(PORT)).is_equal_approx(
					cold.station_axis(PORT) * Flight.DEPARTURE_SPEED)
				and cold.dock_access_status(PORT).phase == "closing",
				"Control returns at the outside release point with the port's drift and door safe to close")
		elif cold.docked >= 0:
			if not cold.dock_access_status(PORT).ready:
				_expect(false, "The door stays open for the entire guided traverse")
				break
	_expect(cold.docked == -1 and launches == 1 and cold.ship.fuel == 0.0 and cold.ship.hull == 100.0,
		"Resuming the route produces one release without using reaction fuel or damaging the hull")
	_expect(cold.target == LOCAL_DESTINATION and cold.jump_target == Catalog.VELAR_SYSTEM
		and not cold.departure_status().active and cold.position.distance_to(flight.position) < 0.005,
		"The uninterrupted and resumed flights keep the same planned route and trajectory")


func _test_previous_berth() -> void:
	var flight := Flight.new()
	var legacy := flight.snapshot()
	legacy.schema = 21
	Fixture.remove_ground_ports_from_legacy(legacy)
	legacy.ship.erase("mining_laser")
	legacy.ship.erase("fragment_collector")
	legacy.ship.erase("hydrogen_scoop")
	legacy.ship.erase("fuel_pump")
	legacy.ship.erase("pump_mode")
	legacy.ship.erase("range_drive")
	legacy.ship.erase("drive_kind")
	legacy.ship.erase("autopilot_fitted")
	legacy.mining.reserves.resize(Catalog.AUTHORED_DESTINATION_COUNT)
	legacy.ship.erase("hull_id")
	legacy.erase("departure_requested")
	legacy.erase("departure_seconds")
	_expect(flight.restore(legacy) and flight.departure_status().phase == "idle"
		and flight.dock_action() and Fixture.await_departure(flight),
		"A pre-departure save restores at its berth and can request and finish a normal exit")


func _test_departure_touch() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := Main.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = Flight.new()
	game._update_display(0.0)
	await process_frame
	var dock_button: Button = game._hud._actions["dock"]
	_tap(viewport, dock_button)
	await process_frame
	_expect(game.flight.departure_status().active and game.flight.docked == PORT
		and bool(SessionIO.load_state().get("departure_requested", false)),
		"Ordinary touch input requests exit and saves the waiting state")
	game._hud.action_requested.emit("services")
	_expect(not game._services.is_open(), "A departure in progress prevents reopening port service screens")
	_tap(viewport, dock_button)
	await process_frame
	_expect(not game.flight.departure_status().active and game.flight.docked == PORT
		and not bool(SessionIO.load_state().get("departure_requested", true)),
		"The same ordinary touch control cancels safely and saves the cancellation")
	_tap(viewport, dock_button)
	_expect(Fixture.await_departure(game.flight, 15.0, game._physics_process), "The touch-requested flight exits through open hatch")
	var saved := SessionIO.load_state()
	_expect(int(saved.get("docked", PORT)) < 0 and not bool(saved.get("departure_requested", true)),
		"The normal release event saves an airborne state that cannot repeat the departure")
	viewport.queue_free()
	await process_frame


func _tap(viewport: SubViewport, button: Button) -> void:
	if not _expect(button.is_visible_in_tree() and not button.disabled
		and button.get_global_rect().size.y >= 44.0, "The normal departure button stays accessible to touch"):
		return
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 13
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		viewport.push_input(event, true)


func _axial_distance(flight: Flight) -> float:
	return (flight.position - flight.docking_position(PORT)).dot(flight.station_axis(PORT))


func _tick(flight: Flight, delta := STEP) -> void:
	flight.update(delta, Vector2.ZERO, 0.0, false, false)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
