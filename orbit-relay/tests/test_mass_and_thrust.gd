extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Economy := preload("res://scripts/port_economy.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Ship := preload("res://scripts/ship_systems.gd")
const Session := preload("res://scripts/session_io.gd")
const STEP := Fixture.STEP
const START := Catalog.HOME_SYSTEM
const DESTINATION := Catalog.VELAR_SYSTEM
const ROOM := Vector3(6700.0, 7500.0, 8600.0)
const TICKET := "user://mass-thrust-ticket.json"
const DIRECTIONS := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_test_axes()
	_test_mass_effects()
	_test_route_budget()
	_test_paid_receipts()
	print("Mass and thrust integration: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _test_axes() -> void:
	for id: String in Ship.hull_ids():
		var limits: Array[float] = []
		for axis: Vector3 in DIRECTIONS:
			var flight := _free_flight(id)
			flight.yaw = 0.35
			flight.pitch = -0.21
			flight.roll = 0.62
			var direction := flight.attitude() * axis
			var components := flight.ship.thrust_acceleration(axis, 0)
			var expected := components[axis.abs().max_axis_index()]
			_step_axis(flight, axis)
			var actual := flight.velocity.dot(direction) / STEP
			limits.append(actual)
			_expect(is_equal_approx(actual, expected) and flight.velocity.normalized().dot(direction) > 0.99999
				and flight.ship.fuel < flight.ship.capacity(),
				"Hull %s uses its signed local axis %s in actual motion and spends reaction fuel" % [id, axis])
		_expect(limits[0] > limits[1] and limits[2] > limits[3] and limits[5] > limits[4],
			"Right/left, rise/fall and ahead/astern have distinct bench-measured limits")
	var courier := _free_flight()
	var freighter := _free_flight(Ship.FREIGHTER_HULL)
	courier.update(0.25, Vector2.ZERO, 1.0, false, false)
	freighter.update(0.25, Vector2.ZERO, 1.0, false, false)
	_expect(absf(courier.roll) > absf(freighter.roll) and absf(courier.roll) > 0.4 and absf(freighter.roll) > 0.3,
		"The two hulls respond differently to the same roll command")


func _test_mass_effects() -> void:
	var light := _free_flight()
	var loaded := _free_flight()
	var tank := _free_flight()
	var reserve := _free_flight()
	loaded.mining.insert_cargo("ore", 24)
	tank.ship.tank_upgraded = true
	tank.ship.fuel = tank.ship.capacity()
	tank.ship.jump_fuel = tank.ship.capacity()
	reserve.ship.fuel = 0.0
	var base := Catalog.jump_cost(START, DESTINATION)
	_expect(light.jump_tariff(START, DESTINATION) == base
		and is_equal_approx(float(light.jump_drive_status().mass_t), Ship.REFERENCE_MASS),
		"The new original hull keeps its existing nominal beginner fare")
	_expect(is_equal_approx(float(loaded.jump_drive_status().mass_t), Ship.REFERENCE_MASS + 24.0 * Ship.CARGO_UNIT_MASS)
		and float(tank.jump_drive_status().mass_t) > float(light.jump_drive_status().mass_t),
		"Cargo, tank hardware and both actual fuel reserves contribute to flying mass")
	for ship: Flight in [light, loaded, tank, reserve]:
		_step_axis(ship, Vector3.FORWARD)
	_expect(light.speed() > loaded.speed() and light.speed() > tank.speed()
		and reserve.speed() > 0.0 and reserve.speed() < light.speed() * 0.62,
		"A heavy hold and enlarged filled tank reduce acceleration; the empty tank falls back to reserve thrust")
	var standard_fare := loaded.jump_tariff(START, DESTINATION)
	var standard_range := float(loaded.jump_drive_status().max_range_ly)
	loaded.ship.range_drive = true
	loaded.ship.select_drive(Ship.DRIVE_RANGE)
	_expect(standard_fare > base and loaded.jump_tariff(START, DESTINATION) < standard_fare
		and float(loaded.jump_drive_status().max_range_ly) > standard_range,
		"Mass increases the tariff and a lighter propulsion coefficient increases useful jump range")


func _test_route_budget() -> void:
	var current := _free_flight()
	for reserve: float in [9.0, 42.7, 100.0]:
		for drive: String in [Ship.DRIVE_STANDARD, Ship.DRIVE_RANGE]:
			current.ship.range_drive = true
			current.ship.select_drive(drive)
			var limit := current.ship.base_jump_budget(reserve, 19, reserve)
			_expect(current.ship.jump_tariff(limit, 19, reserve) <= floorf(reserve)
				and current.ship.jump_tariff(limit + 1, 19, reserve) > floorf(reserve),
				"The indexed candidate budget exactly inverts the loaded fare, including integer fuel rounding")
	var flight := _free_flight()
	var goal := -1
	for candidate in range(Catalog.AUTHORED_SYSTEM_COUNT, Catalog.SYSTEM_COUNT):
		var fare := Catalog.jump_cost(START, candidate)
		if fare >= 93 and fare <= 100:
			goal = candidate
			break
	if not _expect(goal >= 0 and flight.cartography.restore({"systems": [{"system": goal, "epoch": 0.0}], "scans": []}, 0.0)
		and flight.plan_route(goal) and flight.jump_target == goal,
		"A known edge of normal empty cargo range can be planned as a direct hop"):
		return
	var light_range := float(flight.jump_drive_status().max_range_ly)
	flight.mining.insert_cargo("ore", flight.mining.free_capacity())
	var planned := flight.planned_route()
	var price := flight.jump_tariff(START, goal)
	var resumed := Flight.new()
	_expect(price > flight.ship.jump_capacity() and float(flight.jump_drive_status().max_range_ly) < light_range
		and not flight.jump_status(goal).ok and not flight.start_jump() and int(planned.legs[0].fuel) == price
		and resumed.restore(flight.snapshot()) and resumed.jump_target == goal and not resumed.jump_status(goal).ok,
		"Overweight cargo lowers range and blocks departure while the previously selected itinerary survives a reload")
	_expect(resumed.mining.remove_cargo("ore", 24) and resumed.jump_status(goal).ok,
		"Unloading makes that selected direct hop usable again")


func _test_paid_receipts() -> void:
	var flight := _free_flight()
	flight.mining.insert_cargo("ore", 18)
	var initial_fuel := flight.ship.jump_fuel
	if not _expect(flight.plan_route(DESTINATION), "Prepare a real loaded route"):
		return
	var fare: int = flight.planned_route().legs[0].fuel
	_expect(fare == flight.jump_status(DESTINATION).cost and fare > Catalog.jump_cost(START, DESTINATION)
		and flight.start_jump(), "Live route preview and flight agree on the mass-adjusted fare")
	for _step in range(180):
		if flight.jump_progress_status().is_transit:
			break
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	var ticket := flight.snapshot()
	if not _expect(ticket.jump_transit.get("fare") == fare and ticket.jump_transit.get("pricing") == Flight.MASS_JUMP_PRICING
		and flight.jump_tariff(START, DESTINATION) == fare and flight.ship.jump_fuel == initial_fuel - fare,
		"A committed jump keeps the original quote in the route after spending the fare"):
		return
	_finish_from_json(ticket, fare, initial_fuel)
	var legacy := ticket.duplicate(true)
	legacy.schema = 48
	legacy.jump_transit.erase("pricing")
	legacy.jump_transit.fare = Catalog.jump_cost(START, DESTINATION)
	legacy.ship.jump_fuel = initial_fuel - int(legacy.jump_transit.fare)
	for good: String in Economy.NEW_GOODS:
		legacy.mining.cargo.erase(good)
		for stock: Dictionary in legacy.market.values():
			stock.erase(good)
	legacy.erase("market_contacts")
	legacy.erase("port_account")
	legacy.erase("civic")
	var restored := Flight.new()
	if not _expect(restored.restore(legacy) and restored.jump_progress_status().fare == int(legacy.jump_transit.fare)
		and int(restored.snapshot().jump_transit.pricing) == Flight.LEGACY_JUMP_PRICING,
		"A loaded schema-48 ticket preserves its original, smaller fare when migrated"):
		return
	_finish_from_json(restored.snapshot(), int(legacy.jump_transit.fare), initial_fuel)


func _finish_from_json(ticket: Dictionary, fare: int, initial_fuel: float) -> void:
	var ship := Flight.new()
	if not _expect(Session.save_state(ticket, TICKET) == OK and ship.restore(Session.load_state(TICKET))
		and ship.jump_progress_status().fare == fare,
		"The paid receipt validates through the actual JSON storage path"):
		return
	var duration: float = ship.jump_progress_status().duration
	var start_epoch := ship.orbit_time
	ship.update(0.6, Vector2.ZERO, 0.0, false, false)
	_expect(ship.system_id == DESTINATION and ship.ship.jump_fuel == initial_fuel - fare
		and absf(ship.orbit_time - start_epoch - duration) < 0.2 and ship.snapshot().jump_transit.is_empty(),
		"Cold arrival settles once and does not spend the new rate or replay old fare")


func _step_axis(flight: Flight, axis: Vector3) -> void:
	flight.update(STEP, Vector2.ZERO, 0.0, false, false, Vector3(axis.x, axis.y, -axis.z))


func _free_flight(id := Ship.STARTER_HULL) -> Flight:
	var flight := Flight.new()
	if id != Ship.STARTER_HULL:
		flight.ship.swap_hull(id)
		flight.mining.cargo_capacity = flight.ship.cargo_capacity()
	Fixture.launch(flight)
	flight.position = ROOM
	flight.velocity = Vector3.ZERO
	flight.roll = 0.0
	return flight


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures += 1
		printerr(description)
	return condition
