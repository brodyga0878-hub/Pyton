extends SceneTree

const Flight = preload("res://scripts/flight_sim.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_test_route_and_recovery()
	_test_flight_controls()
	print("Flight integration: %d failures" % failures.size())
	for message in failures:
		printerr(message)
	quit(0 if failures.is_empty() else 1)


func _test_route_and_recovery() -> void:
	var flight := Flight.new()
	_check(flight.contract_action() and flight.contract_destination == 1, "First cargo can be accepted at its origin")
	_check(not flight.contract_action(), "Contract cannot be paid at its origin")
	_check(flight.dock_action() and flight.docked == -1, "Launch is available from station services")
	_check(not flight.dock_action(), "Remote docking is rejected")
	_fly_to_station(flight, 1)
	_check(flight.contract_action() and flight.credits == 240 and flight.deliveries == 1, "Receiving station pays for delivered cargo")
	var recovered := Flight.new()
	var cold := JSON.parse_string(JSON.stringify(flight.snapshot())) as Dictionary
	_check(recovered.restore(cold) and recovered.docked == 1 and recovered.credits == 240, "A cold load retains station, cargo progress and credits")
	_check(recovered.contract_action() and recovered.credits == 240 and recovered.contract_destination == 0, "Repeated action starts a new return cargo without repaying the previous one")
	recovered.dock_action()
	_fly_to_station(recovered, 0)
	_check(recovered.contract_action() and recovered.credits == 420 and recovered.deliveries == 2, "Return leg completes from the back of the target station")
	var good := recovered.snapshot()
	var invalid := good.duplicate(true)
	invalid.contract_destination = invalid.contract_origin
	_check(not recovered.restore(invalid) and recovered.snapshot() == good, "Invalid payload does not change a running flight")


func _fly_to_station(flight: RefCounted, destination: int) -> void:
	flight.set_autopilot(true)
	for _step in range(60 * 110):
		flight.update(1.0 / 60.0, Vector2.ZERO, 0.0, false, false)
		if flight.docked >= 0 or not flight.autopilot:
			break
	_check(flight.docked == destination, "Autopilot reaches port %d, got dock=%d, pos=%s, message=%s" % [destination, flight.docked, flight.position, flight.status_message])
	_check(is_equal_approx(flight.roll, flight.station_angle(destination)), "Docked attitude follows the rotating port")


func _test_flight_controls() -> void:
	var flight := Flight.new()
	flight.dock_action()
	flight.set_autopilot(true)
	flight.update(1.0 / 60.0, Vector2.RIGHT, 0.0, false, false)
	_check(not flight.autopilot, "Steering overrides autopilot")
	flight.position = flight.docking_position(1) + Vector3(0, 0, 3)
	flight.target = 1
	flight.velocity = flight.target_velocity(1)
	flight.yaw = 0.0
	flight.roll = flight.station_angle(1) + 0.8
	_check(not flight.dock_action(), "Manual docking rejects roll misalignment")
	flight.roll = flight.station_angle(1)
	flight.velocity = flight.target_velocity(1) + Vector3(0, 0, -6)
	_check(not flight.dock_action(), "Manual docking rejects excessive speed")
	flight.velocity = flight.target_velocity(1)
	_check(flight.dock_action() and flight.docked == 1, "Manual docking accepts a slow aligned approach")
	flight.dock_action()
	flight.change_throttle(0.4)
	for _step in range(80):
		flight.update(1.0 / 60.0, Vector2.ZERO, 0.0, false, true)
	_check(flight.relative_speed() < 0.01 and flight.throttle == 0.0, "Emergency braking brings the ship to a stop in its active reference frame")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
