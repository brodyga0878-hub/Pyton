extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Session := preload("res://scripts/session_io.gd")
const Main := preload("res://main.tscn")
const FAST_RATES := [4, 16, 64, 256]
const STEP := 1.0 / 60.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_settled_rates()
	_test_deadline_stop()
	_test_takeoff_and_cold_load()
	await _test_time_button()
	for failure: String in _failures:
		printerr(failure)
	print("Fast waiting integration: %d checks, %d failures" % [_checks, _failures.size()])
	quit(int(not _failures.is_empty()))


func _test_settled_rates() -> void:
	var fast := Flight.new()
	var normal := Flight.new()
	if not _expect(int(fast.time_status().max_rate) == 256 and _select_fast(fast),
		"The pilot can select four increasing rates while stationary"):
		return
	_tick(fast, 0.75)
	for _interval in range(48):
		_tick(normal, 4.0)
	_expect(fast.orbit_time == 192.0 and fast.orbit_time == normal.orbit_time
		and fast.freight.snapshot() == normal.freight.snapshot() and fast.market.snapshot() == normal.market.snapshot()
		and fast.credits == normal.credits and fast.position.is_equal_approx(normal.position),
		"A 256× wait matches ordinary motion, credits and freight at the same world epoch")
	_expect(fast.cycle_time_scale() and fast.time_scale == 1, "The next touch-based rate returns the docked ship to 1×")


func _test_deadline_stop() -> void:
	var flight := Flight.new()
	if not _expect(flight.passenger_accept(1) and _select_fast(flight), "Enter fast wait with a real timed passenger trip"):
		return
	var deadline: float = flight.passenger_status().deadline
	_tick(flight, 2.0)
	_expect(is_equal_approx(flight.orbit_time, deadline - Flight.FAST_WAIT_DEADLINE_MARGIN)
		and flight.time_scale == 1 and flight.status_event == "time_normal"
		and flight.passenger_status().active and not flight.passenger_status().overdue,
		"Fast wait stops precisely before the fare deadline and preserves the on-time voyage")
	_expect(int(flight.time_status().max_rate) == 16 and flight.cycle_time_scale()
		and flight.cycle_time_scale() and flight.cycle_time_scale() and flight.time_scale == 1,
		"Risky fast rates are excluded during the reaction window; normal rates remain usable")
	_tick(flight, Flight.FAST_WAIT_DEADLINE_MARGIN)
	_expect(flight.passenger_status().overdue and flight.status_event == "passenger_overdue",
		"A deliberate wait in ordinary time still expires the fare exactly once")


func _test_takeoff_and_cold_load() -> void:
	var flight := Flight.new()
	if not _expect(_select_fast(flight), "Prepare a high-rate parked state"):
		return
	_tick(flight, STEP)
	var active := flight.snapshot()
	var path := "user://fast-wait.pilot"
	var cold := Flight.new()
	_expect(Session.save_state(active, path) == OK and cold.restore(Session.load_state(path))
		and cold.time_scale == 1 and cold.orbit_time == flight.orbit_time,
		"Loading keeps the time and resumes the pilot at 1×")
	_expect(flight.dock_action() and flight.time_scale == 1 and not flight.cycle_time_scale(),
		"Requesting undock immediately cancels high-rate wait and blocks it during departure")
	var air := Flight.new()
	air._launch()
	air.position = Vector3(310.0, 4000.0, 8500.0)
	air.velocity = Vector3.ZERO
	_expect(air.time_status().allowed and air.time_status().max_rate == 64
		and air.cycle_time_scale() and air.cycle_time_scale() and air.cycle_time_scale() and air.time_scale == 64,
		"An unobstructed coast can accelerate to 64× while 256× stays reserved for stops")
	var coast_start := air.orbit_time
	air.update(0.25, Vector2.ZERO, 0.0, false, false)
	_expect(is_equal_approx(air.orbit_time, coast_start + 16.0), "Fast coasting advances the physical and mission clock")
	air.position = air.target_position(1) + Vector3.BACK * 220.0
	air.update(STEP, Vector2.ZERO, 0.0, false, false)
	_expect(air.time_scale == 1 and air.time_status().max_rate <= 16,
		"Entering the approach safety envelope stops high-rate coasting before collision")


func _test_time_button() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := Main.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	var button: Button = game._hud._actions["time"]
	if _expect(button.is_visible_in_tree() and not button.disabled, "The live docked HUD exposes the rate button"):
		for expected: int in [4, 16, 64, 256, 1]:
			var point := button.get_global_rect().get_center()
			for pressed in [true, false]:
				var touch := InputEventScreenTouch.new()
				touch.index = 4
				touch.pressed = pressed
				touch.position = point
				viewport.push_input(touch, true)
			await process_frame
			_expect(game.flight.time_scale == expected and button.text == "%d×" % expected,
				"A real finger selects and displays the %d× rate" % expected)
	viewport.queue_free()
	await process_frame


func _select_fast(pilot: Flight) -> bool:
	for rate: int in FAST_RATES:
		if not pilot.cycle_time_scale() or pilot.time_scale != rate:
			return false
	return true


func _tick(pilot: Flight, dt: float) -> void:
	pilot.update(dt, Vector2.ZERO, 0.0, false, false)


func _expect(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
	return condition
