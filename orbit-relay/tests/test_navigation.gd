extends SceneTree

const Fixture = preload("res://tests/flight_fixture.gd")

const Flight := preload("res://scripts/flight_sim.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const OrbitRelay := preload("res://main.tscn")
const OPEN_SPACE := Vector3(6500.0, 7500.0, 8500.0)
const STEP := 1.0 / 60.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_full_attitude()
	_test_translation()
	_test_inertial_driving()
	_test_inclined_orbit()
	_test_saves()
	_test_docking_and_landing()
	await _test_touch()
	print("Navigation integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_full_attitude() -> void:
	var flight := _free_flight()
	var initial := flight.attitude()
	var pitch_rate := Flight.MAX_STEER
	flight.update(PI * 0.47 / pitch_rate, Vector2.DOWN, 0.0, false, false)
	_expect(absf(flight.forward().y) > 0.98,
		"Using the normal steering input pitches nearly upright")
	flight.update(PI * 0.09 / pitch_rate, Vector2.DOWN, 0.0, false, false)
	_expect(flight.forward().dot(-initial.z) < -0.12 and _orthonormal(flight.attitude()),
		"Pitch smoothly crosses the vertical pole with a valid 3D attitude")
	flight.update(PI * 1.44 / pitch_rate, Vector2.DOWN, 0.0, false, false)
	_expect(_same_attitude(flight.attitude(), initial),
		"A full pitch loop returns the forward, right and up axes to their start")
	flight.update(PI / 2.0 / Flight.MAX_ROLL, Vector2.ZERO, 1.0, false, false)
	var banked := flight.attitude()
	_expect(banked.z.dot(initial.z) > 0.9999 and absf(banked.y.dot(initial.x)) > 0.9999,
		"Rolling the ship preserves forward and banks the local up axis")
	flight.update(PI / 2.0 / Flight.MAX_STEER, Vector2.RIGHT, 0.0, false, false)
	_expect(absf(flight.forward().dot(initial.y)) > 0.9999 and _orthonormal(flight.attitude()),
		"Yaw on a banked ship turns about its own up axis through the vertical plane")
	var tilted := flight.attitude()
	flight.update(TAU / Flight.MAX_ROLL, Vector2.ZERO, 1.0, false, false)
	_expect(_same_attitude(flight.attitude(), tilted), "Full roll also preserves a tilted heading")


func _test_translation() -> void:
	for command: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var flight := _free_flight()
		flight.yaw = 0.41
		flight.pitch = -0.32
		flight.roll = 0.77
		var attitude := flight.attitude()
		var expected := attitude * Vector3(command.x, command.y, -command.z)
		var start := flight.position
		flight.update(0.8, Vector2.ZERO, 0.0, false, false, command)
		_expect(flight.velocity.dot(expected) > 2.0 and flight.velocity.normalized().dot(expected) > 0.995
			and (flight.position - start).dot(expected) > 0.6 and _same_attitude(flight.attitude(), attitude),
			"Translation %s changes velocity and position along the corresponding ship axis without steering" % command)
		_expect(flight.ship.fuel < flight.ship.capacity(), "Powered translation %s uses fuel" % command)
	var flight := _free_flight()
	flight.set_autopilot(true)
	flight.update(STEP, Vector2.ZERO, 0.0, false, false, Vector3.LEFT)
	_expect(not flight.autopilot, "A lateral thrust input immediately overrides autopilot")


func _test_inertial_driving() -> void:
	var flight := _free_flight()
	var start := flight.position
	var inherited := Vector3(34.0, -11.0, -22.0)
	flight.velocity = inherited
	flight.change_throttle(0.8)
	if not _expect(flight.flight_assist and flight.set_flight_assist(false) and not flight.flight_assist
		and flight.velocity == inherited and flight.throttle == 0.0,
		"Switching to manual inertia starts with the existing velocity and neutral thrust"):
		return
	var duration := 4.0
	var fuel := flight.ship.fuel
	flight.update(duration, Vector2.ZERO, 0.0, false, false)
	_expect(flight.velocity.distance_to(inherited) < 0.04
		and flight.position.distance_to(start + inherited * duration) < 0.25 and flight.ship.fuel == fuel,
		"An unpowered coasting ship does not slow itself or expend fuel")
	flight.update(0.7, Vector2.ZERO, 0.0, false, false, Vector3.RIGHT)
	_expect(flight.velocity.x > inherited.x + 2.0 and absf(flight.velocity.z - inherited.z) < 0.04,
		"Manual lateral thrust adds to inertial velocity and preserves its orthogonal component")
	_expect(flight.set_flight_assist(true), "Stabilization can be restored during flight")
	flight.update(2.0, Vector2.ZERO, 0.0, false, false)
	_expect(flight.velocity.length() < 0.05, "Assisted idle brakes against the active reference frame")
	var moving_port := 1
	flight.select_target(moving_port)
	flight.position = flight.target_gate(moving_port)
	flight.velocity = flight.target_velocity(moving_port) + Vector3.RIGHT * 19.0
	flight.set_flight_assist(false)
	flight.update(1.0, Vector2.ZERO, 0.0, false, true)
	_expect(flight.reference_site() == moving_port and flight.speed_relative_to(moving_port) < 0.03,
		"The brake in inertial mode matches the velocity of a moving nearby station")


func _test_inclined_orbit() -> void:
	var flight := _free_flight(Catalog.FRINGE_ARRIVAL_PORT)
	var star := Catalog.FRINGE_STAR_ID
	flight.select_target(star)
	var center := flight.target_position(star)
	var radius := 320.0
	var outward := Vector3.BACK
	var tangent := Vector3(0.67, 0.74, 0.0).normalized()
	var normal := outward.cross(tangent)
	var start := center + outward * radius
	flight.position = start
	var gravity := flight.gravity_at(start)
	var distant := flight.gravity_at(center + outward * radius * 2.0)
	if not _expect(gravity.length() > 0.01 and gravity.normalized().dot(-outward) > 0.9999
		and is_equal_approx(gravity.length(), distant.length() * 4.0),
		"A lone star pulls toward its centre with inverse-square acceleration"):
		return
	flight.update(0.6, Vector2.ZERO, 0.0, false, false)
	_expect(flight.velocity.length() < 0.001, "Stabilization holds a stationary ship near the star")
	var orbital_speed := sqrt(gravity.length() * radius)
	flight.position = start
	flight.velocity = tangent * orbital_speed
	flight.set_flight_assist(false)
	var period := TAU * radius / orbital_speed
	var largest_radial_error := 0.0
	var largest_plane_error := 0.0
	var max_height := 0.0
	var min_height := 0.0
	for _segment in range(8):
		flight.update(period / 8.0, Vector2.ZERO, 0.0, false, false)
		var radial := flight.position - center
		largest_radial_error = maxf(largest_radial_error, absf(radial.length() - radius))
		largest_plane_error = maxf(largest_plane_error, absf(normal.dot(radial)))
		max_height = maxf(max_height, radial.y)
		min_height = minf(min_height, radial.y)
	_expect(max_height > 190.0 and min_height < -190.0 and largest_plane_error < 2.0,
		"Gravity bends the free ship through a complete inclined plane above and below the star")
	_expect(largest_radial_error < 3.0 and flight.position.distance_to(start) < 5.0
		and flight.velocity.distance_to(tangent * orbital_speed) < 0.09,
		"A free circular orbit returns close to its starting radius and velocity after the calculated period")
	_expect(flight.ship.fuel == flight.ship.capacity() and flight.ship.hull == 100.0,
		"The coast along an unobstructed orbit needs neither thrust nor thermal damage")


func _test_saves() -> void:
	var flight := _free_flight()
	flight.set_flight_assist(false)
	flight.velocity = Vector3(-11.0, 8.0, 23.0)
	flight.update(PI * 0.73 / Flight.MAX_STEER, Vector2.DOWN, 0.0, false, false)
	flight.update(0.3, Vector2.RIGHT, 0.43, false, false)
	var expected := flight.attitude()
	var saved := _json(flight.snapshot())
	var resumed := Flight.new()
	if not _expect(saved.schema == Flight.SAVE_SCHEMA and saved.orientation.size() == 4 and resumed.restore(saved)
		and not resumed.flight_assist and _same_attitude(resumed.attitude(), expected)
		and resumed.velocity.distance_to(flight.velocity) < 0.001,
		"A new safe load preserves position, momentum and full 3D attitude across the pitch pole"):
		return
	_expect(resumed.position.distance_to(flight.position) < 0.001, "The restarted inertial ship keeps its position")
	var preserved := resumed.snapshot()
	for wrong in [[0, 0, 0, 0], [0, 0, 1], [0, INF, 0, 1], [0, 0, 0, 0.4]]:
		var damaged := saved.duplicate(true)
		damaged.orientation = wrong
		_expect(not resumed.restore(damaged) and resumed.snapshot() == preserved,
			"Non-unit, malformed or non-finite saved attitude is rejected atomically")
	var damaged := saved.duplicate(true)
	damaged.flight_assist = "false"
	_expect(not resumed.restore(damaged) and resumed.snapshot() == preserved,
		"Assist mode cannot be restored from arbitrary text")
	var legacy := _free_flight()
	legacy.yaw = -0.63
	legacy.pitch = 0.51
	legacy.roll = 1.07
	legacy.velocity = Vector3(2.0, -4.0, -12.0)
	var previous := _json(legacy.snapshot())
	previous.schema = 12
	previous.ship.erase("mining_laser")
	previous.ship.erase("fragment_collector")
	previous.ship.erase("hydrogen_scoop")
	previous.ship.erase("fuel_pump")
	previous.ship.erase("pump_mode")
	previous.ship.erase("hull_id")
	previous.ship.erase("jump_fuel")
	previous.mining.cargo.erase("hydrogen")
	previous.mining.reserves.resize(Catalog.PRE_GAS_DESTINATION_COUNT)
	for stocks: Dictionary in previous.market.values():
		stocks.erase("hydrogen")
	previous.ship.erase("heat_shield")
	previous.erase("orientation")
	previous.erase("flight_assist")
	_expect(resumed.restore(previous) and resumed.flight_assist and _same_attitude(resumed.attitude(), legacy.attitude())
		and resumed.velocity.distance_to(legacy.velocity) < 0.001 and resumed.snapshot().schema == Flight.SAVE_SCHEMA,
		"A version 0.45 save migrates its old Euler attitude and momentum with flight assistance enabled")


func _test_docking_and_landing() -> void:
	var flight := Flight.new()
	if not _expect(flight.set_flight_assist(false) and _travel(flight, 1) and flight.docked == 1
		and not flight.flight_assist and absf(flight.roll_error(1)) < 0.02,
		"Autopilot still docks and synchronizes with a rotating station from manual-inertia mode"):
		return
	_expect(_travel(flight, 2) and flight.landed_site == 2 and not flight.flight_assist,
		"The next launch and automatic landing on a rocky body preserve the pilot's assist preference")
	_expect(flight.dock_action() and not flight.landed,
		"The ship can lift off again after the automatic landing")


func _test_touch() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := OrbitRelay.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = _free_flight()
	game._update_display(0.0)
	await process_frame
	_tap(viewport, game._hud._actions["flight_assist"], "Toggle inertial piloting through the real flight HUD")
	await process_frame
	_expect(not game.flight.flight_assist, "The touch action reaches the flight-assist model")
	_tap(viewport, game._hud._actions["translation_mode"], "Switch the pad to translation")
	await process_frame
	var pad: Rect2 = game._hud._steer.get_global_rect()
	var sideways := pad.get_center() + Vector2(pad.size.x * 0.3, 0.0)
	var reverse: Button = game._hud._actions["translation_reverse"]
	var reverse_point := reverse.get_global_rect().get_center()
	if _expect(reverse.is_visible_in_tree() and not reverse.disabled,
		"The reverse-thrust control is available in the touch translation layout"):
		var frame: Basis = game.flight.attitude()
		_touch(viewport, 7, sideways, true)
		_touch(viewport, 8, reverse_point, true)
		var input: Vector3 = game._hud.translation_input()
		_expect(input.x > 0.2 and input.z < -0.2 and game._hud.move_input() == Vector2.ZERO,
			"The real pad and reverse button can command two thrust axes without producing rotation")
		game._physics_process(0.4)
		_expect(game.flight.velocity.dot(frame.x) > 1.0 and game.flight.velocity.dot(frame.z) > 1.0
			and _same_attitude(game.flight.attitude(), frame),
			"The Android controls drive both directions in the real physics entry point")
		_touch(viewport, 8, reverse_point, false)
		_touch(viewport, 7, sideways, false)
		_expect(game._hud.translation_input() == Vector3.ZERO,
			"Releasing both fingers clears their applied thrust")
	viewport.queue_free()
	await process_frame


func _travel(flight: Flight, destination: int) -> bool:
	if not flight.select_target(destination) or not Fixture.depart(flight):
		return false
	flight.set_autopilot(true)
	for _frame in range(roundi(150.0 / STEP)):
		if not flight.autopilot:
			return true
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	return false


func _free_flight(port: int = 0) -> Flight:
	var flight := Flight.new()
	if port != 0:
		var saved := flight.snapshot()
		saved.system_id = Catalog.system_of_site(port)
		saved.docked = port
		saved.target = port
		_expect(flight.restore(saved), "Load a real port in an isolated star system")
	Fixture.launch(flight)
	flight.position = OPEN_SPACE
	flight.velocity = Vector3.ZERO
	flight.yaw = 0.0
	flight.pitch = 0.0
	flight.roll = 0.0
	return flight


func _orthonormal(basis: Basis) -> bool:
	return basis.is_finite() and absf(basis.determinant() - 1.0) < 0.0001 \
		and absf(basis.x.dot(basis.y)) < 0.0001 and absf(basis.y.dot(basis.z)) < 0.0001


func _same_attitude(actual: Basis, expected: Basis) -> bool:
	return _orthonormal(actual) and actual.x.dot(expected.x) > 0.9999 \
		and actual.y.dot(expected.y) > 0.9999 and actual.z.dot(expected.z) > 0.9999


func _json(state: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(state, "", true, true)) as Dictionary


func _tap(viewport: SubViewport, button: Button, description: String) -> void:
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, description):
		return
	var position := button.get_global_rect().get_center()
	_touch(viewport, 6, position, true)
	_touch(viewport, 6, position, false)


func _touch(viewport: SubViewport, index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	viewport.push_input(event, true)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
