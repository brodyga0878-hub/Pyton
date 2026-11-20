extends SceneTree

const Flight = preload("res://scripts/flight_sim.gd")
const Catalog = preload("res://scripts/sector_catalog.gd")
const OrbitRelay = preload("res://main.tscn")
const STEP := 1.0 / 60.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_manual_depletion()
	_test_scoop_safety()
	_test_stellar_heat()
	_test_heat_and_time_acceleration()
	_test_rear_stellar_departure()
	_test_service_rules()
	await _test_touch_route()
	print("Fuel integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_manual_depletion() -> void:
	var flight := Flight.new()
	_step_flight(flight, 5.0, true)
	_expect(flight.ship.fuel == 100.0 and flight.speed() == 0.0,
		"A docked ship neither moves nor spends fuel under held boost")
	_expect(flight.dock_action(), "Manual test launches from Маяк-7")
	flight.change_throttle(1.0)
	_step_flight(flight, 2.0)
	_expect(flight.ship.fuel > 96.0 and flight.ship.fuel < 99.0 and flight.speed() > 50.0,
		"Manual thrust spends fuel while accelerating a real flight")
	var normal_fuel := flight.ship.fuel
	_step_flight(flight, 2.0, true)
	_expect(flight.ship.fuel < normal_fuel - 4.0 and flight.boost and flight.speed() > Flight.MAX_SPEED * 0.8,
		"Boost consumes fuel faster than normal thrust")
	_step_flight(flight, 45.0, true)
	_expect(flight.ship.fuel == 0.0 and not flight.boost and flight.speed() > 10.0 and flight.speed() <= 42.05,
		"An empty tank blocks boost and leaves bounded reserve propulsion")
	var resumed := Flight.new()
	_expect(resumed.restore(_round_trip(flight.snapshot())) and resumed.ship.fuel == 0.0,
		"An empty airborne tank survives a JSON save")
	_step_flight(resumed, 2.0, false, true)
	_expect(resumed.speed() < 0.01 and resumed.ship.fuel == 0.0,
		"Brake can stop an empty ship and the tank never becomes negative")


func _test_scoop_safety() -> void:
	var flight := Flight.new()
	flight.ship.fuel = 50.0
	var star := Catalog.site(Catalog.STAR_ID)
	var center: Vector3 = star.center
	_expect(not flight.scoop_status().ok and not flight.scoop_action(), "The scoop stays closed in port")
	flight.dock_action()
	flight.select_target(Catalog.STAR_ID)
	_expect(not flight.scoop_status().ok and not flight.scoop_action(), "Selecting a distant star grants no fuel")
	flight.position = center + Vector3.BACK * 395.0
	flight.velocity = Vector3.ZERO
	_expect(not flight.scoop_status().ok and not flight.scoop_action(), "The scoop rejects the outside of the band")
	flight.position = center + Vector3.BACK * 260.0
	_expect(not flight.scoop_status().ok and not flight.scoop_action(), "The scoop rejects the inside of the band")
	flight.position = center + Vector3.BACK * 310.0
	flight.velocity = Vector3.BACK * 40.0
	_expect(not flight.scoop_status().ok and not flight.scoop_action(), "The scoop rejects excessive speed")
	flight.velocity = Vector3.ZERO
	_expect(flight.scoop_status().ok and flight.scoop_action() and flight.scooping,
		"The scoop opens at safe speed inside the stellar band")
	_step_flight(flight, 1.0)
	_expect(flight.ship.fuel > 50.0 and flight.ship.fuel < flight.ship.capacity() and flight.scooping,
		"An open scoop adds fuel gradually")
	var gathered := flight.ship.fuel
	flight.position = center + Vector3.BACK * 395.0
	_step_flight(flight, STEP)
	_expect(not flight.scooping and flight.ship.fuel == gathered,
		"Leaving the band closes the scoop before awarding fuel")
	flight.position = center + Vector3.BACK * 255.0
	flight.velocity = Vector3.FORWARD * 35.0
	flight.yaw = 0.0
	flight.change_throttle(1.0)
	_step_flight(flight, 1.0)
	_expect(flight.position.distance_to(center) >= 249.98 and flight.speed() < 0.01,
		"The star's exclusion radius protects a manual approach")
	_expect(not flight.dock_action() and not flight.mine_action() and flight.mining.ore_hold == 0,
		"The star supports neither touchdown nor mining")
	flight.position = center + Vector3.BACK * 310.0
	flight.ship.fuel = flight.ship.capacity() - 0.0005
	_expect(flight.scoop_action(), "The scoop can finish filling a nearly full tank")
	_step_flight(flight, STEP)
	_expect(not flight.scooping and flight.ship.fuel == flight.ship.capacity(),
		"Stellar collection clamps the last fraction of fuel and closes")


func _test_stellar_heat() -> void:
	var flight := Flight.new()
	flight.dock_action()
	flight.select_target(Catalog.STAR_ID)
	var center := flight.target_position(Catalog.STAR_ID)
	flight.position = center + Vector3.BACK * (Catalog.SCOOP_INNER + 1.0)
	flight.velocity = Vector3.ZERO
	flight.ship.fuel = 10.0
	if not _expect(flight.scoop_action(), "A cool ship can initially collect at the inner edge of the band"):
		return
	_step_flight(flight, 6.0)
	_expect(flight.star_heat > 0.0 and flight.ship.fuel > 10.0
		and flight.ship.fuel < 10.0 + 6.0 * Flight.SCOOP_RATE,
		"Heating at the inner edge reduces collection below the safe stellar rate")
	_step_flight(flight, 9.0)
	var hot := flight.thermal_status()
	_expect(hot.blocked and not flight.scooping and not flight.scoop_action() and flight.ship.fuel < 100.0,
		"Sustained inner-band heat closes the scoop before the tank is full and blocks immediate reopening")
	var resumed := Flight.new()
	var saved := _round_trip(flight.snapshot())
	_expect(resumed.restore(saved) and is_equal_approx(resumed.star_heat, flight.star_heat)
		and resumed.thermal_status().blocked and not resumed.scooping,
		"Reloading a hot ship preserves its temperature and continues to block collection")
	var intact := resumed.snapshot()
	for invalid: Variant in [-1, 101, "50", INF]:
		var malformed := saved.duplicate(true)
		malformed.star_heat = invalid
		_expect(not resumed.restore(malformed) and resumed.snapshot() == intact,
			"An invalid saved temperature is rejected atomically: %s" % invalid)
	flight.position = center + Vector3.BACK * (Catalog.STAR_CLEARANCE + 0.3)
	var hull_before := flight.ship.hull
	_step_flight(flight, 22.0)
	_expect(flight.thermal_status().danger and flight.thermal_status().level == "critical"
		and flight.ship.hull < hull_before and flight.ship.hull > 0.0,
		"Sustained exposure just above the stellar exclusion radius damages the hull")
	flight.yaw = PI
	flight.change_throttle(0.45)
	_step_flight(flight, 7.0)
	flight.change_throttle(-1.0)
	_step_flight(flight, 1.5, false, true)
	var hull_after_retreat := flight.ship.hull
	_expect(flight.position.distance_to(center) > Catalog.SCOOP_OUTER and flight.thermal_status().cooling,
		"Moving beyond the collection band begins cooling the ship")
	_step_flight(flight, 45.0)
	_expect(flight.star_heat < 1.0 and is_equal_approx(flight.ship.hull, hull_after_retreat)
		and not flight.thermal_status().blocked,
		"Cooling clears the hazardous state without further hull damage or implicit repairs")
	flight.position = center + Vector3.BACK * 310.0
	_expect(flight.scoop_action(), "A cooled ship can collect fuel again at the safe stellar radius")


func _test_heat_and_time_acceleration() -> void:
	var flight := Flight.new()
	flight.dock_action()
	var center := flight.target_position(Catalog.STAR_ID)
	flight.position = center + Vector3.BACK * (Catalog.SCOOP_OUTER + Flight.STAR_WARP_MARGIN + 18.0)
	flight.velocity = Vector3.FORWARD * 27.0
	flight.yaw = 0.0
	flight.change_throttle(0.20)
	if not _expect(flight.cycle_time_scale() and flight.cycle_time_scale() and flight.time_scale == 16,
		"Time acceleration is available outside the stellar approach margin"):
		return
	var clock_before := flight.orbit_time
	flight.update(2.0, Vector2.ZERO, 0.0, false, false)
	_expect(flight.time_scale == 1 and flight.orbit_time - clock_before < 6.0
		and flight.position.distance_to(center) > Catalog.SCOOP_OUTER and not flight.cycle_time_scale(),
		"Crossing the stellar margin cancels x16 before the ship reaches the dangerous band")


func _test_rear_stellar_departure() -> void:
	var flight := Flight.new()
	flight.dock_action()
	var center: Vector3 = Catalog.site(Catalog.STAR_ID).center
	flight.position = center + Vector3.FORWARD * 310.0
	flight.velocity = Vector3.ZERO
	flight.ship.fuel = 0.0
	flight.select_target(1)
	flight.set_autopilot(true)
	var nearest := flight.position.distance_to(center)
	var fastest := 0.0
	for _step in range(roundi(145.0 / STEP)):
		if not flight.autopilot:
			break
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
		nearest = minf(nearest, flight.position.distance_to(center))
		fastest = maxf(fastest, flight.speed())
	_expect(flight.docked == 1 and nearest >= Catalog.STAR_CLEARANCE,
		"Autopilot clears the stellar hull when returning from the rear of the band")
	_expect(fastest > 10.0 and fastest <= 42.05 and flight.ship.fuel == 0.0,
		"The entire return and docking can run on the speed-limited reserve drive")


func _test_service_rules() -> void:
	var flight := Flight.new()
	flight.ship.fuel = 75.5
	var cost := ceili(100.0 - 75.5) * flight.refuel_unit_price()
	flight.credits = cost - 1
	_expect(cost > 0 and flight.service_offer("refuel").cost == cost
		and not flight.service_offer("refuel").allowed and not flight.service_action("refuel")
		and flight.credits == cost - 1 and flight.ship.fuel == 75.5,
		"A port quotes whole units and an unaffordable refill changes nothing")
	flight.credits = cost
	_expect(flight.service_offer("refuel").allowed and flight.service_action("refuel")
		and flight.credits == 0 and flight.ship.fuel == 100.0,
		"The port accepts exact payment and fills the missing fuel")
	_expect(not flight.service_action("refuel") and flight.credits == 0, "A full tank cannot be charged twice")
	flight.credits = 1000
	flight.dock_action()
	_step_flight(flight, 2.0, true)
	_expect(not flight.service_offer("refuel").allowed and not flight.service_action("refuel")
		and not flight.service_action("tank") and not flight.service_action("eco") and flight.credits == 1000,
		"Station purchases are blocked in flight even with missing fuel and enough credits")
	var efficient := Flight.new()
	var offered_eco: int = efficient.service_offer("eco").cost
	efficient.credits = offered_eco
	_expect(efficient.service_action("eco") and efficient.credits == 0, "The economy upgrade consumes its quoted fee")
	var standard := Flight.new()
	for ship in [standard, efficient]:
		ship.dock_action()
		ship.change_throttle(0.6)
		_step_flight(ship, 10.0)
	_expect(efficient.ship.fuel > standard.ship.fuel and is_equal_approx(efficient.speed(), standard.speed()),
		"The economy upgrade lowers real flight consumption at equal speed and throttle")


func _test_touch_route() -> void:
	var game := _open_scene()
	var flight: RefCounted = game.flight
	flight.credits = 1000
	var initial_mining: Dictionary = flight.mining.snapshot()
	game._update_display(0.0)
	await process_frame
	_tap(game._hud._actions.get("map"), "Touch opens the sector map")
	await process_frame
	_tap(game._map._site_buttons.get(Catalog.STAR_ID), "Touch previews the star as a map destination")
	await process_frame
	_tap(game._map._select_button, "Touch confirms the star course")
	await process_frame
	_expect(flight.planned_target == Catalog.STAR_ID and not game._map.is_open(),
		"The chart stores the star course until launch")
	_tap(game._hud._actions.get("dock"), "Touch launches on the planned course")
	await process_frame
	_tap(game._hud._actions.get("autopilot"), "Touch starts the star approach")
	_advance(game, func() -> bool: return not flight.autopilot, 115.0)
	var star_center: Vector3 = Catalog.site(Catalog.STAR_ID).center
	var radius: float = flight.position.distance_to(star_center)
	if not _expect(flight.target == Catalog.STAR_ID and not flight.autopilot and flight.docked < 0
		and not flight.landed and radius >= 268.0 and radius <= 382.0 and flight.speed() <= 38.0,
		"Autopilot reaches a stellar holding point in the scoop band, radius %.1f m" % radius):
		await _close_scene(game)
		return
	_expect(not flight.scooping and flight.ship.fuel < 100.0 and flight.ship.fuel > 0.0,
		"The approach uses fuel and leaves collection under manual control")
	game._update_display(0.0)
	await process_frame
	_expect(game._hud._thermal_panel.is_visible_in_tree()
		and is_equal_approx(game._hud._thermal_level.value, flight.star_heat),
		"The flight HUD displays the live heat reading inside the collection band")
	_tap(game._hud._actions.get("scoop"), "Touch opens the scoop in the band")
	_expect(flight.scooping, "The HUD action opens the scoop")
	game._physics_process(0.25)
	var active_save: Dictionary = flight.snapshot()
	game = await _restart_scene(game)
	flight = game.flight
	_expect(flight.snapshot() == active_save and not flight.scooping and flight.scoop_status().ok,
		"Restart restores the partial fuel safely with the scoop closed")
	_tap(game._hud._actions.get("scoop"), "Touch reopens the scoop after a restart")
	_advance(game, func() -> bool: return not flight.scooping, 20.0)
	_expect(flight.ship.fuel == flight.ship.capacity() and not flight.scooping
		and not flight.scoop_action() and flight.mining.snapshot() == initial_mining
		and flight.ship.hull == 100.0 and not flight.thermal_status().danger,
		"A safe autopilot approach fills the tank with no heat damage or change to mining cargo or reserves")
	_expect(flight.select_target(1), "A port can be selected after collecting fuel")
	flight.set_autopilot(true)
	_advance(game, func() -> bool: return flight.docked >= 0 or not flight.autopilot, 115.0)
	if not _expect(flight.docked == 1 and flight.ship.fuel < 100.0 and flight.ship.fuel > 0.0,
		"The ship uses collected fuel to return to Тихий порт"):
		await _close_scene(game)
		return
	game._update_display(0.0)
	await process_frame
	_expect(not game._hud._thermal_panel.is_visible_in_tree(), "The stellar heat indicator clears when docked")
	_tap(game._hud._actions.get("services"), "Touch opens the port services panel")
	await process_frame
	var services: Node = game._services
	_expect(services.is_open(), "The services panel opens only after docking")
	var elapsed: float = flight.elapsed
	game._physics_process(0.5)
	game._handle_action("dock")
	_expect(flight.elapsed == elapsed and flight.docked == 1 and game._hud._actions.get("dock").disabled,
		"A services transaction pauses the clock and the underlying launch controls")
	var refill_cost: int = flight.service_offer("refuel").cost
	_tap(services._action_buttons.get("refuel"), "Touch pays the port tariff and refills")
	_expect(refill_cost > 0 and flight.credits == 1000 - refill_cost and flight.ship.fuel == 100.0
		and services._action_buttons.get("refuel").disabled,
		"Refill is charged exactly once and its control closes over a full tank")
	var tank_cost: int = flight.service_offer("tank").cost
	_tap(services._action_buttons.get("tank"), "Touch buys the larger tank")
	_expect(flight.ship.tank_upgraded and flight.ship.capacity() == 150.0 and flight.ship.fuel == 100.0
		and flight.credits == 1000 - refill_cost - tank_cost and services._action_buttons.get("tank").disabled,
		"Tank installation increases capacity without crediting free fuel or allowing duplicates")
	var eco_cost: int = flight.service_offer("eco").cost
	_tap(services._action_buttons.get("eco"), "Touch buys the economy module")
	_expect(flight.ship.eco_upgraded and flight.credits == 1000 - refill_cost - tank_cost - eco_cost
		and services._action_buttons.get("eco").disabled,
		"The economy module is installed and charged only once")
	var port_save: Dictionary = flight.snapshot()
	_tap(services._close_button, "Touch dismisses services")
	_expect(not services.is_open(), "The services panel closes and releases the modal")
	await _close_scene(game)
	game = _open_scene()
	await process_frame
	flight = game.flight
	_expect(flight.snapshot() == port_save and flight.docked == 1 and flight.ship.capacity() == 150.0,
		"Port purchases save immediately and survive a cold restart")
	var malformed := port_save.duplicate(true)
	malformed.ship.fuel = 150.01
	_expect(not flight.restore(malformed) and flight.snapshot() == port_save,
		"Rejected over-capacity fuel does not change the restored session")
	malformed = port_save.duplicate(true)
	malformed.ship.eco_upgraded = 1
	_expect(not flight.restore(malformed) and flight.snapshot() == port_save,
		"Rejected malformed equipment does not change the restored session")
	await _close_scene(game)


func _step_flight(flight: RefCounted, seconds: float, boost := false, brake := false) -> void:
	for _step in range(roundi(seconds / STEP)):
		flight.update(STEP, Vector2.ZERO, 0.0, boost, brake)


func _advance(game: Node, stop: Callable, limit: float) -> void:
	for _step in range(roundi(limit / STEP)):
		if stop.call():
			return
		game._physics_process(STEP)


func _open_scene() -> Node:
	var game := OrbitRelay.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	return game


func _restart_scene(game: Node) -> Node:
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await _close_scene(game)
	var resumed := _open_scene()
	await process_frame
	return resumed


func _close_scene(game: Node) -> void:
	game.queue_free()
	await process_frame


func _tap(button: Button, label: String) -> void:
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, label):
		return
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 6
		touch.position = button.get_global_rect().get_center()
		touch.pressed = pressed
		root.push_input(touch, true)


func _round_trip(state: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(state, "", true, true)) as Dictionary


func _expect(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
	return condition
