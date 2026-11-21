extends SceneTree

const Fixture = preload("res://tests/flight_fixture.gd")

const Flight = preload("res://scripts/flight_sim.gd")
const Catalog = preload("res://scripts/sector_catalog.gd")
const Terrain = preload("res://scripts/surface_terrain.gd")
const OrbitRelay = preload("res://main.tscn")
const STEP := 1.0 / 60.0
const HOME := Catalog.HOME_SYSTEM
const VELAR := Catalog.VELAR_SYSTEM

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_jump_conditions()
	_test_cancellation_and_commit()
	_test_previous_save()
	_test_velar_routes()
	await _test_touch_route()
	print("Jump integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_jump_conditions() -> void:
	var flight := Flight.new()
	_expect(flight.system_id == HOME and not flight.start_jump() and not flight.plan_jump(HOME)
		and not flight.plan_jump(Catalog.SYSTEM_COUNT), "A current, unknown or unplanned destination cannot start a jump")
	_expect(flight.plan_jump(VELAR) and flight.jump_status(VELAR).cost == 26
		and not flight.jump_status(VELAR).ok and not flight.start_jump(), "Planning from the dock quotes the jump but keeps it locked")
	Fixture.launch(flight)
	_expect(not flight.jump_status(VELAR).ok, "The jump remains locked during departure close to the port")
	flight.position = _arrival(flight, HOME)
	flight.velocity = Vector3.BACK * 43.0
	_expect(not flight.jump_status(VELAR).ok, "Exceeding the departure speed limit prevents charging")
	flight.velocity = Vector3.ZERO
	flight.set_autopilot(true)
	_expect(not flight.jump_status(VELAR).ok, "The jump drive cannot engage with autopilot running")
	flight.set_autopilot(false)
	flight.ship.jump_fuel = 25.99
	_expect(not flight.jump_status(VELAR).ok and not flight.start_jump()
		and flight.ship.jump_fuel == 25.99 and flight.ship.fuel == 100.0,
		"A full reaction tank cannot make up an insufficient jump reserve")
	flight.ship.jump_fuel = 26.0
	var star: int = Catalog.star_for(HOME)
	flight.position = flight.target_contact(star)
	_expect(not flight.jump_status(VELAR).ok, "Jump charging is prohibited inside the stellar scoop band")
	flight.position = flight.target_gate(star)
	_expect(flight.jump_status(VELAR).ok, "Jump charging is allowed outside the stellar scoop band")
	var landed := _parked(12)
	landed.plan_jump(HOME)
	_expect(landed.landed and not landed.jump_status(HOME).ok and not landed.start_jump(),
		"A ship on a solid surface cannot start a jump")


func _test_cancellation_and_commit() -> void:
	var flight := Flight.new()
	Fixture.launch(flight)
	flight.position = _arrival(flight, HOME)
	flight.velocity = Vector3.ZERO
	flight.ship.jump_fuel = 26.0
	flight.plan_jump(VELAR)
	_expect(flight.start_jump() and is_equal_approx(flight.jump_seconds_left, 2.5) and not flight.start_jump(),
		"The countdown starts once without accepting a duplicate command")
	_step(flight, 1.0)
	_expect(flight.system_id == HOME and flight.ship.jump_fuel == 26.0 and flight.jump_seconds_left > 0.0,
		"Charging stays in the source system and makes no debit before commit")
	var during: Dictionary = flight.snapshot()
	var resumed := Flight.new()
	_expect(resumed.restore(_round_trip(during)) and resumed.jump_target == VELAR
		and resumed.jump_seconds_left == 0.0 and resumed.ship.jump_fuel == 26.0,
		"A save during charging retains the planned route and cancels the transient charge")
	resumed.position = resumed.target_position(0) + Vector3.BACK * 78.0
	resumed.velocity = Vector3.FORWARD * 42.0
	_expect(resumed.start_jump(), "A ship can start at the valid edge of the exclusion zone")
	_step(resumed, 0.25)
	_expect(resumed.jump_seconds_left == 0.0 and resumed.system_id == HOME and resumed.ship.jump_fuel == 26.0,
		"Coasting into an exclusion zone during charging cancels before any debit")
	flight.update(STEP, Vector2.ZERO, 0.0, false, true)
	_expect(flight.jump_seconds_left == 0.0 and flight.system_id == HOME and flight.ship.jump_fuel == 26.0,
		"The brake cancels charging without a fuel debit")
	flight.start_jump()
	flight.update(STEP, Vector2(0.5, 0.0), 0.0, false, false)
	_expect(flight.jump_seconds_left == 0.0 and flight.system_id == HOME and flight.ship.jump_fuel == 26.0,
		"The steering pad cancels charging without a fuel debit")
	flight.start_jump()
	flight.change_throttle(0.1)
	_expect(flight.jump_seconds_left == 0.0 and flight.system_id == HOME and flight.ship.jump_fuel == 26.0,
		"Changing throttle cancels charging immediately")
	flight.start_jump()
	flight.update(STEP, Vector2.ZERO, 0.0, true, false)
	_expect(flight.jump_seconds_left == 0.0 and flight.system_id == HOME and flight.ship.jump_fuel == 26.0,
		"Boost cancels charging and does not debit the jump fare")
	flight.velocity = Vector3.ZERO
	flight.ship.fuel = 0.0
	flight.ship.jump_fuel = 26.0
	flight.start_jump()
	_expect(flight.cancel_jump() and not flight.cancel_jump() and flight.ship.jump_fuel == 26.0,
		"Explicit cancellation is safe to repeat and leaves the planned route intact")
	flight.start_jump()
	_step(flight, Flight.JUMP_CHARGE)
	_expect(flight.system_id == VELAR and flight.jump_target == -1 and flight.jump_seconds_left == 0.0
		and flight.ship.jump_fuel == 0.0 and flight.ship.fuel == 0.0
		and flight.position.is_equal_approx(_arrival(flight, VELAR)),
		"The exact fare commits once and arrives safely at the other system")
	_expect(_fly_to(flight, int(Catalog.system(VELAR).arrival_port)) and flight.ship.fuel == 0.0,
		"An exact-fare arrival can still dock on the reserve drive")


func _test_previous_save() -> void:
	# Version 0.36 stores no system information and has exactly nine reserve slots.
	var previous := {
		"schema": 4, "position": [2000.0, 380.0, -1540.0], "velocity": [0.0, 0.0, 0.0],
		"yaw": 0.0, "pitch": 0.0, "roll": 0.0, "elapsed": 97.0, "throttle": 0.0,
		"docked": -1, "landed_site": -1, "target": 9, "planned_target": -1,
		"credits": 1010, "deliveries": 3, "contract_stage": 1, "contract_origin": 0,
		"contract_destination": 1, "ship": {"fuel": 77.25, "tank_upgraded": true, "eco_upgraded": true},
		"mining": {"site_id": 4, "phase": 0, "phase_seconds": 0.0, "pending_ore": 0,
			"cargo": {"ore": 12, "crystal": 12, "ice": 0},
			"reserves": [0, 0, 108, 0, 84, 180, 156, 132, 216]},
	}
	var flight := Flight.new()
	if not _expect(flight.restore(_round_trip(previous)), "A literal version 0.36 save migrates from the old schema"):
		return
	_expect(flight.system_id == HOME and flight.jump_target == -1 and flight.target == Catalog.STAR_ID
		and flight.position.is_equal_approx(flight.target_contact(Catalog.STAR_ID)),
		"Migrating retains the original flight position and local star target")
	_expect(flight.ship.fuel == 77.25 and flight.ship.jump_fuel == 77.25 and flight.ship.tank_upgraded and flight.ship.eco_upgraded
		and flight.credits == 1010 and flight.deliveries == 3 and flight.contract_destination == 1,
		"Migrating retains current fuel, equipment, balance and freight")
	var migrated := flight.snapshot()
	_expect(migrated.schema == Flight.SAVE_SCHEMA and migrated.mining.reserves.size() == Catalog.DESTINATION_COUNT
		and flight.mining.ore_hold == 24 and flight.mining.reserve_at(4) == 84
		and flight.mining.reserve_at(12) == int(Catalog.site(12).reserve)
		and flight.mining.reserve_at(13) == int(Catalog.site(13).reserve),
		"Old reserves and cargo survive with new deposits initialized")
	previous.target = 10
	_expect(not flight.restore(previous) and flight.snapshot() == migrated, "A version 0.36 save cannot refer to a new system")
	var malformed := migrated.duplicate(true)
	malformed.system_id = VELAR
	_expect(not flight.restore(malformed) and flight.snapshot() == migrated, "A system and local target mismatch is rejected atomically")
	malformed = migrated.duplicate(true)
	malformed.jump_target = HOME
	_expect(not flight.restore(malformed) and flight.snapshot() == migrated, "A planned jump to the current system is rejected atomically")


func _test_velar_routes() -> void:
	for fuel in [0.0, 100.0]:
		for origin: int in Catalog.targets_for(VELAR):
			for destination: int in Catalog.targets_for(VELAR):
				if origin != destination:
					var flight := _at_destination(origin)
					flight.ship.fuel = fuel
					_expect(_fly_to(flight, destination), "Second-system route %d → %d on %.0f fuel arrives at its target (%s)" % [origin, destination, fuel, flight.status_message])
	for port: int in Catalog.ports_for(VELAR):
		var flight := _parked(port)
		var destination: int = flight.offer_destination()
		var reward: int = flight.contract_reward()
		_expect(destination in Catalog.ports_for(VELAR) and destination != port and reward > 0
			and flight.contract_action() and _fly_to(flight, destination) and flight.contract_action()
			and flight.credits == reward and flight.deliveries == 1, "A new local contract can be accepted and delivered")
	var mining_flight := _parked(12)
	var reserve: int = mining_flight.mining.reserve_at(12)
	mining_flight.mine_action()
	_step(mining_flight, 16.0)
	mining_flight.mine_action()
	_step(mining_flight, 3.0)
	_expect(mining_flight.mining.cargo_amount("ice") == 12 and mining_flight.mining.reserve_at(12) == reserve - 12
		and _fly_to(mining_flight, 11), "Mining on the remote moon yields a batch and permits takeoff")
	var quoted_payment: int = mining_flight.market_quote("ice", "sell", 12).cost
	_expect(mining_flight.sell_ore_action() and mining_flight.credits == quoted_payment
		and mining_flight.service_action("refuel") and mining_flight.ship.fuel == 100.0,
		"The remote market buys its moon ice and provides a working refuel service")


func _test_touch_route() -> void:
	var game := _open_scene()
	game.flight = Flight.new()
	var flight: RefCounted = game.flight
	var saved_port: Dictionary = flight.snapshot()
	saved_port.credits = 1100
	saved_port.mining.reserves[2] -= 12
	saved_port.mining.cargo.ore = 12
	_expect(flight.restore(saved_port), "Load an existing ship with mined ore aboard")
	var mining_before: Dictionary = flight.mining.snapshot()
	flight.service_action("tank")
	flight.service_action("eco")
	game._update_display(0.0)
	await process_frame
	_tap(game._hud._actions.get("contract"), "A touch accepts local freight")
	_tap(game._hud._actions.get("galaxy"), "A touch opens the galaxy map from port")
	await process_frame
	var chart: Node = game._galaxy
	var stopped_time: float = flight.elapsed
	game._physics_process(0.5)
	_expect(chart.is_open() and flight.elapsed == stopped_time and game._hud._actions.get("dock").disabled,
		"The map holds underlying flight actions and time")
	_tap(chart._system_buttons.get(VELAR), "A touch previews Велар in the galaxy map")
	_expect(flight.jump_target == -1, "Previewing a system does not plan the jump")
	_tap(chart._plan_button, "A touch saves the jump plan")
	_expect(chart.is_open() and chart._jump_button.disabled and flight.jump_target == VELAR and flight.ship.jump_fuel == 100.0 and flight.ship.fuel == 100.0,
		"Planning from port keeps the jump guarded and leaves the tank untouched")
	_tap(chart._close_button, "A touch dismisses the galaxy map")
	await process_frame
	_tap(game._hud._actions.get("dock"), "A touch requests departure on the current system's local flight controls")
	_expect(Fixture.await_departure(flight, 15.0, game._physics_process), "The departure is completed before clearing for the jump")
	game._update_display(0.0)
	await process_frame
	_tap(game._hud._actions.get("throttle_up"), "A touch increases departure thrust")
	_tap(game._hud._actions.get("throttle_up"), "A second touch increases departure thrust")
	_advance(game, func() -> bool: return flight.jump_status(VELAR).ok, 10.0)
	_expect(flight.jump_status(VELAR).ok, "The ship flies clear before jumping, got thrust %.2f and speed %.2f (%s)" % [flight.throttle, flight.speed(), flight.jump_status(VELAR).reason])
	game._update_display(0.0)
	await process_frame
	_tap(game._hud._actions.get("galaxy"), "A touch reopens the galaxy map in flight")
	await process_frame
	_tap(chart._system_buttons.get(VELAR), "The destination is selected for departure")
	var first_fare_fuel: float = flight.ship.jump_fuel
	var first_reaction_fuel: float = flight.ship.fuel
	_tap(chart._jump_button, "A touch starts outbound charging")
	_expect(not chart.is_open() and flight.jump_seconds_left > 0.0, "Charging dismisses the map and allows the flight clock to advance")
	_advance(game, func() -> bool: return flight.system_id == VELAR, 4.0)
	if not _expect(flight.system_id == VELAR and flight.target == 10 and flight.ship.jump_fuel == first_fare_fuel - 26.0
		and flight.ship.fuel == first_reaction_fuel
		and flight.contract_stage == 1 and flight.contract_destination == 1 and flight.ship.capacity() == 150.0,
		"The first jump charges one fare, selects the remote arrival port and preserves the freight and tank"):
		game.queue_free()
		await process_frame
		return
	game._update_display(STEP)
	var view: Node = game._view
	var camera_position: Vector3 = view.camera.global_position
	_expect(view._system_id == VELAR and view._stations.keys() == Catalog.ports_for(VELAR)
		and camera_position.is_equal_approx(flight.position + Vector3(0.0, 3.4, 10.5)),
		"The rendered arrival activates only the second sector and snaps the camera at the jump")
	var upon_arrival: Dictionary = flight.snapshot()
	game.queue_free()
	await process_frame
	game = _open_scene()
	await process_frame
	flight = game.flight
	var restored: Dictionary = flight.snapshot()
	var fuel_matches := absf(float(restored.ship.fuel) - float(upon_arrival.ship.fuel)) < 0.000000001
	restored.ship.erase("fuel")
	upon_arrival.ship.erase("fuel")
	var clocks_match := true
	for key: String in ["elapsed", "orbit_time"]:
		clocks_match = clocks_match and absf(float(restored[key]) - float(upon_arrival[key])) < 0.000000001
		restored.erase(key)
		upon_arrival.erase(key)
	_expect(restored == upon_arrival and fuel_matches and clocks_match and flight.system_id == VELAR,
		"A cold scene loads the new system and preserves post-jump state through JSON")
	_tap(game._hud._actions.get("map"), "A touch opens the new system's local map")
	await process_frame
	var local_map: Node = game._map
	var home_button: Button = local_map._site_buttons.get(0)
	var velar_button: Button = local_map._site_buttons.get(11)
	_expect(local_map.is_open() and (home_button == null or not home_button.is_visible_in_tree())
		and velar_button != null and velar_button.is_visible_in_tree() and not flight.select_target(0),
		"Only locations in the new system appear in the local map and can be selected")
	_tap(local_map._close_button, "A touch closes the local map")
	_tap(game._hud._actions.get("galaxy"), "A touch opens the return chart")
	await process_frame
	chart = game._galaxy
	_tap(chart._system_buttons.get(HOME), "A touch selects Гелион for return")
	_tap(chart._plan_button, "A touch confirms the return plan")
	var last_fare_fuel: float = flight.ship.jump_fuel
	_tap(chart._jump_button, "A touch starts return charging")
	_advance(game, func() -> bool: return flight.system_id == HOME, 4.0)
	_expect(flight.system_id == HOME and flight.target == 0 and flight.ship.jump_fuel == last_fare_fuel - 26.0
		and flight.contract_stage == 1 and flight.contract_destination == 1 and flight.credits == 520,
		"The full touch round trip changes systems twice and charges only the jump fares")
	_expect(flight.mining.snapshot() == mining_before and flight.mining.cargo_amount("ore") == 12,
		"Mining cargo and the depleted deposit persist across both jumps")
	game._update_display(STEP)
	_expect(game._view._system_id == HOME and game._view._stations.keys() == Catalog.ports_for(HOME),
		"The return restores just the home-sector scene")
	game.queue_free()
	await process_frame


func _arrival(flight: RefCounted, system_id: int) -> Vector3:
	return flight.target_gate(int(Catalog.system(system_id).arrival_port)) + Vector3.BACK * 90.0


func _parked(id: int) -> RefCounted:
	var flight := Flight.new()
	var state := flight.snapshot()
	var contact := flight.target_contact(id)
	state.system_id = Catalog.system_of_site(id)
	state.position = [contact.x, contact.y, contact.z]
	state.target = id
	state.docked = id if Catalog.is_port(id) else -1
	if Catalog.is_mine_site(id):
		state.landed_site = id
		state.landing_direction = [0.0, 0.0, 1.0]
		state.mining.site_id = id
		if Terrain.spin_rate(id) > 0.0:
			var drift := flight.surface_velocity(id, contact)
			state.velocity = [drift.x, drift.y, drift.z]
	if Catalog.is_mine_site(id) or id in [Catalog.GROUND_PAD, Catalog.GROUND_HANGAR]:
		state.gear_extension = 1.0
		state.gear_deployed = true
	_expect(flight.restore(state), "Initialize a docked or landed flight at site %d" % id)
	return flight


func _at_destination(id: int) -> RefCounted:
	if id != Catalog.VELAR_STAR_ID:
		return _parked(id)
	var flight := _parked(int(Catalog.system(VELAR).arrival_port))
	Fixture.launch(flight)
	flight.target = id
	flight.position = flight.target_contact(id)
	flight.velocity = Vector3.ZERO
	return flight


func _fly_to(flight: RefCounted, id: int) -> bool:
	if (flight.docked >= 0 and not Fixture.launch(flight)) or (flight.landed and not flight.dock_action()):
		return false
	if not flight.select_target(id):
		return false
	flight.set_autopilot(true)
	for _frame in range(roundi(140.0 / STEP)):
		if not flight.autopilot:
			break
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	if id == Catalog.star_for(flight.system_id):
		var radius: float = flight.position.distance_to(flight.target_position(id))
		return not flight.autopilot and radius >= Catalog.SCOOP_INNER and radius <= Catalog.SCOOP_OUTER
	return flight.docked == id or flight.landed_site == id


func _open_scene() -> Node:
	var game := OrbitRelay.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	return game


func _tap(button: Button, description: String) -> void:
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, description):
		return
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 8
		touch.position = button.get_global_rect().get_center()
		touch.pressed = pressed
		root.push_input(touch, true)


func _advance(game: Node, stop: Callable, seconds: float) -> void:
	for _frame in range(roundi(seconds / STEP)):
		if stop.call():
			return
		game._physics_process(STEP)


func _step(flight: RefCounted, seconds: float) -> void:
	for _frame in range(roundi(seconds / STEP)):
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)


func _round_trip(state: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(state, "", true, true)) as Dictionary


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
