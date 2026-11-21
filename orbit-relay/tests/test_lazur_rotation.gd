extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Ground := preload("res://scripts/ground_port.gd")
const Orbit := preload("res://scripts/orbit_ephemeris.gd")
const Terrain := preload("res://scripts/surface_terrain.gd")

const BODY := Catalog.GROUND_BODY
const PAD := Catalog.GROUND_PAD
const HANGAR := Catalog.GROUND_HANGAR
const ORBITAL := 10
const PHASES := 12
const CHECK_INTERVAL := 0.125
const STEP := Fixture.STEP

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var spin := Terrain.spin_rate(BODY)
	if _expect(is_equal_approx(spin, 0.025), "Lazur has the authored angular speed"):
		var period := TAU / spin
		_test_sampled_motion(period)
		var orbiting := _reach_velar()
		if _expect(orbiting != null, "Enter Velar and dock at the original orbital port using ordinary controls"):
			_test_synchronized_routes(orbiting, period)
	print("Lazur rotation integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(int(not _failures.is_empty()))


func _test_sampled_motion(period: float) -> void:
	_expect(Terrain.spin_basis(BODY, 0.0) == Basis.IDENTITY
		and Terrain.spin_basis(BODY, period).is_equal_approx(Basis.IDENTITY),
		"A full axial turn returns to the authored zero-epoch orientation")
	for phase in range(PHASES):
		var epoch := 43.0 + period * phase / PHASES
		var host := Orbit.sample(BODY, epoch)
		var frame := Terrain.spin_basis(BODY, epoch)
		for port: int in [PAD, HANGAR]:
			var anchor := Orbit.sample(port, epoch)
			var local: Vector3 = anchor.position - host.position
			var before: Vector3 = Orbit.sample(port, epoch - CHECK_INTERVAL).position
			var after: Vector3 = Orbit.sample(port, epoch + CHECK_INTERVAL).position
			var numeric_velocity := (after - before) / (2.0 * CHECK_INTERVAL)
			var analytic: Vector3 = host.velocity + Terrain.spin_velocity(BODY, local)
			_expect(local.distance_to(frame * Ground.anchor_offset(port, 0.0)) < 0.0002
				and Ground.basis(port, epoch).z.dot(local.normalized()) > 0.9,
				"Berth %d stays attached to its rock and terrain normal at phase %d" % [port, phase])
			_expect(analytic.distance_to(anchor.velocity) < 0.0001 and numeric_velocity.distance_to(analytic) < 0.0025,
				"Berth %d position derivative includes both orbit and axial motion at phase %d" % [port, phase])


func _reach_velar() -> Flight:
	var ship := Flight.new()
	if not Fixture.depart(ship) or not ship.plan_jump(Catalog.VELAR_SYSTEM):
		return null
	ship.change_throttle(0.18)
	if not _until(ship, func() -> bool: return ship.jump_status(Catalog.VELAR_SYSTEM).ok, 15.0) or not ship.start_jump():
		return null
	if not _until(ship, func() -> bool: return ship.system_id == Catalog.VELAR_SYSTEM, 5.0) or not ship.select_target(ORBITAL):
		return null
	ship.set_autopilot(true)
	return ship if _until(ship, func() -> bool: return ship.docked == ORBITAL, 125.0) else null


func _test_synchronized_routes(orbiting: Flight, period: float) -> void:
	for phase in range(PHASES):
		if phase > 0:
			for _step in range(roundi(period / PHASES / STEP)):
				_tick(orbiting)
		var ship := Flight.new()
		if not _expect(ship.restore(orbiting.snapshot()), "Reload the orbital berth before route %d" % phase):
			continue
		var first := PAD if phase % 2 == 0 else HANGAR
		var second := HANGAR if first == PAD else PAD
		for port: int in [first, second, ORBITAL]:
			var previous := ship.docked
			if not _expect(ship.select_target(port) and Fixture.depart(ship),
				"Release from %d towards %d at phase %d" % [previous, port, phase]):
				break
			if Ground.is_port(previous):
				var expected := _surface_drift(ship, ship.position) + ship.station_axis(previous) * Flight.DEPARTURE_SPEED
				_expect(ship.velocity.distance_to(expected) < 0.001,
					"Release from %d inherits the local rotational tangent at phase %d" % [previous, phase])
			ship.set_autopilot(true)
			if not _expect(_until(ship, func() -> bool: return ship.docked >= 0, 140.0) and ship.docked == port,
				"Complete the actual approach from %d to %d at phase %d" % [previous, port, phase]):
				break
			var expected_gear := 1.0 if Ground.is_port(port) else 0.0
			_expect(ship.ship.hull == 100.0 and ship.gear_extension == expected_gear and ship.station_services_available(),
				"Dock at %d with intact hull, correct gear and active services at phase %d" % [port, phase])
			if Ground.is_port(port):
				_expect(ship.position.distance_to(ship.docking_position(port)) < 0.001
					and ship.velocity.distance_to(_surface_drift(ship, ship.position)) < 0.001,
					"Parked ship at %d remains in the same physical surface frame at phase %d" % [port, phase])
				if port == second:
					_test_departure_to_moon(ship, phase)


func _test_departure_to_moon(docked: Flight, phase: int) -> void:
	var ship := Flight.new()
	if not _expect(ship.restore(docked.snapshot()) and ship.select_target(BODY) and Fixture.depart(ship),
		"Leave berth %d physically for bare terrain on the same moon at phase %d" % [docked.docked, phase]):
		return
	ship.set_autopilot(true)
	_expect(_until(ship, func() -> bool: return ship.landed or not ship.autopilot, 140.0)
		and ship.landed_site == BODY and not ship.landed_offpad() and ship.ship.hull == 100.0,
		"Approach the natural landing pad after clearing its host moon's berth at phase %d" % phase)


func _surface_drift(ship: Flight, point: Vector3) -> Vector3:
	return ship.target_velocity(BODY) + Terrain.spin_velocity(BODY, point - ship.target_position(BODY))


func _until(ship: Flight, reached: Callable, seconds: float) -> bool:
	for _frame in range(ceili(seconds / STEP)):
		if reached.call():
			return true
		_tick(ship)
	return reached.call()


func _tick(ship: Flight) -> void:
	ship.update(STEP, Vector2.ZERO, 0.0, false, false)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append("FAIL: " + description)
	return condition
