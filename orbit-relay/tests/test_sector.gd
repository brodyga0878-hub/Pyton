extends SceneTree

const Fixture = preload("res://tests/flight_fixture.gd")

const Flight = preload("res://scripts/flight_sim.gd")
const Rig = preload("res://scripts/mining_rig.gd")
const Catalog = preload("res://scripts/sector_catalog.gd")
const OrbitRelay = preload("res://main.tscn")
const STEP := 1.0 / 60.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_navigation_routes()
	_test_delivery_contracts()
	_test_trade_and_depletion()
	_test_legacy_recovery()
	_test_schema_three_migration()
	await _test_touch_map()
	print("Sector integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		printerr(failure)
	# Let the mixer retire stopped playback before the SceneTree shuts down.
	await create_timer(0.15).timeout
	quit(0 if _failures.is_empty() else 1)


func _test_navigation_routes() -> void:
	_expect(Catalog.PORT_IDS == [0, 1, 3] and Catalog.MINING_IDS == [2, 4, 5, 6, 7, 8],
		"The catalog retains the published stable site IDs")
	for origin in range(Catalog.SITE_COUNT):
		for destination in range(Catalog.SITE_COUNT):
			if origin == destination:
				continue
			var flight := _at_site(origin)
			_fly_to(flight, destination, "Site %d to site %d" % [origin, destination])


func _test_delivery_contracts() -> void:
	var rewards := {
		Vector2i(0, 1): 240, Vector2i(0, 3): 340,
		Vector2i(1, 0): 180, Vector2i(1, 3): 280,
		Vector2i(3, 0): 320, Vector2i(3, 1): 260,
	}
	for route: Vector2i in rewards:
		var flight := _at_site(route.x)
		_expect(flight.select_target(route.y) and flight.offer_destination() == route.y
			and flight.contract_reward() == rewards[route] and not flight.contract_cargo().is_empty(),
			"Planning port route %s selects its named freight offer and reward" % route)
		_expect(flight.contract_action() and flight.contract_destination == route.y
			and not flight.contract_action(),
			"Port route %s accepts freight without paying it at the origin" % route)
		if _fly_to(flight, route.y, "Freight route %s" % route):
			_expect(flight.contract_action() and flight.credits == rewards[route] and flight.deliveries == 1,
				"Receiving port pays the reward for route %s" % route)


func _test_trade_and_depletion() -> void:
	var flight := _at_site(0)
	if not _fly_to(flight, 2, "Ore route"):
		return
	var initial_ore: int = flight.mining.reserve_at(2)
	var initial_crystal: int = flight.mining.reserve_at(4)
	_recover_batch(flight, 2)
	_expect(flight.mining.cargo_amount("ore") == 12 and flight.mining.reserve_at(2) == initial_ore - 12,
		"An ore recovery credits the ore bay and debits its own deposit")
	if not _fly_to(flight, 4, "Crystal route"):
		return
	_recover_batch(flight, 4)
	_expect(flight.mining.ore_hold == 24 and flight.mining.cargo_amount("ore") == 12
		and flight.mining.cargo_amount("crystal") == 12,
		"The two grades share a 24-unit hold while retaining separate quantities")
	_expect(flight.mining.reserve_at(4) == initial_crystal - 12 and flight.mining.reserve_at(2) == initial_ore - 12,
		"Recovery cannot debit a neighboring deposit")
	_expect(not flight.mine_action() and not flight.sell_ore_action(),
		"A full hold blocks deployment and a landed ship cannot sell")
	_expect(flight.mining.sale_quote(0) == 696 and flight.mining.sale_quote(1) == 600
		and flight.mining.sale_quote(3) == 948,
		"The two grades earn distinct fixed quotes at the three ports")

	var saved := _round_trip(flight.snapshot())
	var resumed := Flight.new()
	_expect(resumed.restore(saved) and resumed.snapshot() == flight.snapshot(),
		"Mixed cargo and both reserve debits survive a JSON save")
	if not _fly_to(resumed, 3, "Mixed cargo to Перевал"):
		return
	var quoted_payment: int = resumed.market_quote("ore", "sell", 12).cost + resumed.market_quote("crystal", "sell", 12).cost
	_expect(resumed.sell_ore_action() and resumed.credits == quoted_payment and resumed.mining.ore_hold == 0,
		"Перевал pays its own quote and empties the hold")
	_expect(not resumed.sell_ore_action() and resumed.credits == quoted_payment,
		"Sale cannot pay the same cargo twice")

	var last_deposit: Dictionary = flight.snapshot()
	for good: String in last_deposit.mining.cargo:
		last_deposit.mining.cargo[good] = 0
	last_deposit.mining.reserves[4] = 12
	_expect(resumed.restore(last_deposit), "A saved site with one batch left loads")
	_recover_batch(resumed, 4)
	_expect(resumed.mining.reserve_at(4) == 0 and resumed.mining.cargo_amount("crystal") == 12
		and not resumed.mine_action(),
		"An empty deposit blocks redeployment even with room in the hold")

	if not _fly_to(resumed, 8, "Ice route"):
		return
	_recover_batch(resumed, 8)
	_expect(resumed.mining.cargo_amount("ice") == 12 and resumed.mining.cargo_amount("crystal") == 12,
		"Comet ice fills only the ice compartment")


func _test_legacy_recovery() -> void:
	# Literal 0.34 save captured mid-recovery, with one prior batch aboard.
	var legacy := {
		"schema": 2, "position": [-215.0, -70.0, -372.0], "velocity": [0.0, 0.0, 0.0],
		"yaw": 0.0, "pitch": 0.0, "roll": 0.0, "elapsed": 26.0, "throttle": 0.0,
		"docked": -1, "landed": true, "target": 2, "credits": 240, "deliveries": 1,
		"contract_stage": 1, "contract_origin": 0, "contract_destination": 1,
		"mining": {"phase": 4, "phase_seconds": 1.25, "ore_hold": 12, "reserve": 108, "pending_ore": 12},
	}
	var flight := Flight.new()
	_expect(flight.restore(_round_trip(legacy)), "A 0.34 save restores a rig returning to Осколок")
	_expect(flight.landed and flight.landed_site == 2 and flight.mining.site_id == 2
		and flight.mining.phase == Rig.RETURNING and flight.mining.phase_seconds == 1.25
		and flight.mining.cargo_amount("ore") == 12 and flight.mining.pending_ore == 12,
		"Migration retains the recovery timer, held ore and uncredited batch")
	_expect(flight.mining.reserve_at(2) == 108 and flight.mining.reserve_at(4) == 96,
		"Migration preserves the old reserve and initializes untouched sites")
	_expect(flight.credits == 240 and flight.contract_destination == 1,
		"Migration retains balance and the active freight route")

	var before: Dictionary = flight.snapshot()
	_expect(before.schema == Flight.SAVE_SCHEMA, "Migration emits the current save schema")
	var malformed := before.duplicate(true)
	malformed.mining.site_id = 4
	_expect(not flight.restore(malformed) and flight.snapshot() == before,
		"Reject a returning rig aliased to a different deposit atomically")
	malformed = before.duplicate(true)
	malformed.landed_site = 1
	_expect(not flight.restore(malformed) and flight.snapshot() == before,
		"Reject a port ID used as the landed site atomically")
	malformed = legacy.duplicate(true)
	malformed.mining.reserve = 120
	_expect(not flight.restore(malformed) and flight.snapshot() == before,
		"Reject a legacy resource balance without any recorded extraction atomically")
	malformed = before.duplicate(true)
	malformed.planned_target = Catalog.TARGET_COUNT
	_expect(not flight.restore(malformed) and flight.snapshot() == before,
		"Reject an invalid planned destination atomically")
	flight.update(0.5, Vector2.ZERO, 0.0, false, false)
	_expect(flight.mining.cargo_amount("ore") == 12 and flight.mining.phase == Rig.RETURNING,
		"The migrated batch stays aboard the module until the recovery timer ends")
	flight.update(0.5, Vector2.ZERO, 0.0, false, false)
	flight.update(1.0, Vector2.ZERO, 0.0, false, false)
	_expect(flight.mining.cargo_amount("ore") == 24 and flight.mining.reserve_at(2) == 96
		and flight.mining.phase == Rig.STOWED and flight.mining.pending_ore == 0,
		"Completing the migrated recovery deposits one batch exactly once")


func _test_schema_three_migration() -> void:
	# The 0.35 format still had nine targets and did not store fuel or equipment.
	var legacy := {
		"schema": 3, "position": [450.0, 170.0, -2022.0], "velocity": [0.0, 0.0, 0.0],
		"yaw": 0.0, "pitch": 0.0, "roll": 0.0, "elapsed": 64.0, "throttle": 0.0,
		"docked": -1, "landed_site": 8, "target": 8, "planned_target": 3,
		"credits": 700, "deliveries": 2, "contract_stage": 1, "contract_origin": 3,
		"contract_destination": 1,
		"mining": {
			"site_id": 8, "phase": 4, "phase_seconds": 1.5, "pending_ore": 12,
			"cargo": {"ore": 12, "crystal": 0, "ice": 0},
			"reserves": [0, 0, 108, 0, 96, 180, 156, 132, 216],
		},
	}
	var flight := Flight.new()
	if not _expect(flight.restore(_round_trip(legacy)), "A 0.35 save restores a rig returning on Дымка"):
		return
	_expect(flight.landed_site == 8 and flight.planned_target == 3 and flight.contract_origin == 3
		and flight.contract_destination == 1 and flight.credits == 700 and flight.deliveries == 2,
		"Migration retains the planned course, freight contract, balance and deliveries")
	_expect(flight.mining.phase == Rig.RETURNING and flight.mining.phase_seconds == 1.5
		and flight.mining.pending_ore == 12 and flight.mining.cargo_amount("ore") == 12
		and flight.mining.reserve_at(2) == 108,
		"Migration retains the recovery timer, cargo and reserves")
	_expect(flight.ship.fuel == 100.0 and flight.ship.capacity() == 100.0
		and not flight.ship.tank_upgraded and not flight.ship.eco_upgraded,
		"Migration starts the ship with a full standard tank")
	var before := flight.snapshot()
	var invalid := legacy.duplicate(true)
	invalid.planned_target = Catalog.STAR_ID
	_expect(not flight.restore(invalid) and flight.snapshot() == before,
		"A schema-three save cannot encode destinations added in schema four")
	flight.update(0.75, Vector2.ZERO, 0.0, false, false)
	_expect(flight.mining.phase == Rig.STOWED and flight.mining.cargo_amount("ice") == 12
		and flight.mining.reserve_at(8) == 204 and flight.ship.fuel == 100.0,
		"The restored rig deposits ice once while the landed ship spends no fuel")

	var old_space := legacy.duplicate(true)
	var center: Vector3 = Catalog.site(Catalog.STAR_ID).center
	old_space.position = [center.x, center.y, center.z]
	old_space.velocity = [5.0, 0.0, 0.0]
	old_space.landed_site = -1
	old_space.planned_target = -1
	old_space.mining.phase = Rig.STOWED
	old_space.mining.phase_seconds = 0.0
	old_space.mining.pending_ore = 0
	_expect(flight.restore(_round_trip(old_space)) and flight.position.is_equal_approx(flight.target_gate(Catalog.STAR_ID))
		and flight.speed() == 0.0 and flight.target == 8 and flight.credits == 700,
		"A 0.35 ship inside the new stellar hull moves to safety with its course and progress retained")


func _test_touch_map() -> void:
	var game := _open_scene()
	game.flight = Flight.new()
	game._update_display(0.0)
	await process_frame
	_tap(game._hud._actions.get("contract"), "Accept freight on the ground")
	await process_frame
	_tap(game._hud._actions.get("map"), "Open the sector map")
	await process_frame
	var map: Node = game._map
	if not _expect(map.is_open() and game.flight.docked == 0, "The map opens without leaving the port"):
		game.queue_free()
		return
	var paused: float = game.flight.elapsed
	game._physics_process(0.5)
	_expect(game.flight.elapsed == paused, "The map suspends the flight clock")
	var launch_button: Button = game._hud._actions.get("dock")
	_expect(launch_button.disabled, "The map disables the underlying flight controls")
	_push_tap(launch_button.get_global_rect().get_center())
	_expect(game.flight.docked == 0, "A touch through the modal cannot launch the ship")
	_tap(map._site_buttons.get(3), "Preview a different port")
	await process_frame
	_tap(map._close_button, "Cancel the preview")
	await process_frame
	_expect(not map.is_open() and game.flight.planned_target == -1,
		"Closing the map discards the unconfirmed destination")
	_tap(game._hud._actions.get("map"), "Reopen the sector map")
	await process_frame
	var chart: Control = map._chart
	var point: Vector2 = chart._project(game.flight.target_position(8), chart._plot_bounds(), chart._bounds_xz())
	_push_tap(chart.get_global_transform_with_canvas() * point)
	await process_frame
	_tap(map._select_button, "Apply the planned route")
	await process_frame
	_expect(not map.is_open() and game.flight.planned_target == 8 and game.flight.contract_destination == 1,
		"A map course can be planned without discarding the freight contract")
	game.queue_free()
	await process_frame
	game = _open_scene()
	await process_frame
	_expect(game.flight.docked == 0 and game.flight.planned_target == 8,
		"The map course survives a regular scene restart before departure")
	_tap(game._hud._actions.get("dock"), "Request departure on the selected course")
	_expect(Fixture.await_departure(game.flight, 15.0, game._physics_process) and game.flight.target == 8,
		"Launch honors the destination selected while docked")
	game.queue_free()
	await process_frame


func _at_site(site: int) -> RefCounted:
	var flight := Flight.new()
	var state := flight.snapshot()
	var contact := flight.target_contact(site)
	state.position = [contact.x, contact.y, contact.z]
	state.target = site
	if Catalog.is_port(site):
		state.docked = site
	else:
		state.docked = -1
		state.landed_site = site
		state.landing_direction = [0.0, 0.0, 1.0]
		state.mining.site_id = site
		state.gear_extension = 1.0
		state.gear_deployed = true
	_expect(flight.restore(state), "Restore the parked starting state at site %d" % site)
	return flight


func _fly_to(flight: RefCounted, site: int, route: String) -> bool:
	if flight.docked >= 0 or flight.landed:
		var launched: bool = Fixture.launch(flight) if flight.docked >= 0 else flight.dock_action()
		if not _expect(launched, "%s: launch" % route):
			return false
	if not _expect(flight.select_target(site), "%s: select target" % route):
		return false
	flight.set_autopilot(true)
	for _step in range(int(140.0 / STEP)):
		if flight.docked >= 0 or flight.landed or not flight.autopilot:
			break
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	var arrived: bool = flight.docked == site if Catalog.is_port(site) else flight.landed_site == site
	return _expect(arrived and flight.position.is_equal_approx(flight.target_contact(site))
		and flight.speed() < 0.01,
		"%s: arrive at the contact pose, got %s at %s" % [route, flight.status_message, flight.position])


func _recover_batch(flight: RefCounted, site: int) -> void:
	var old_quantity: int = flight.mining.ore_hold
	var old_reserve: int = flight.mining.reserve_at(site)
	_expect(flight.mine_action(), "Deploy a rig at site %d" % site)
	for _step in range(int(20.0 / STEP)):
		if flight.mining.phase == Rig.READY:
			break
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	_expect(flight.mining.phase == Rig.READY and flight.mining.ore_hold == old_quantity
		and flight.mining.reserve_at(site) == old_reserve and not flight.dock_action(),
		"An extracted batch stays in the separate module and blocks lift")
	_expect(flight.mine_action(), "Recall rig from site %d" % site)
	for _step in range(int(4.0 / STEP)):
		if flight.mining.phase == Rig.STOWED:
			break
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	_expect(flight.mining.phase == Rig.STOWED and flight.mining.ore_hold == old_quantity + 12
		and flight.mining.reserve_at(site) == old_reserve - 12 and flight.mining.pending_ore == 0,
		"Recovery transfers the batch once and clears the lift interlock")


func _open_scene() -> Node:
	var game := OrbitRelay.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	return game


func _tap(button: Button, label: String) -> void:
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, label):
		return
	_push_tap(button.get_global_rect().get_center())


func _push_tap(position_2d: Vector2) -> void:
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 4
		touch.position = position_2d
		touch.pressed = pressed
		root.push_input(touch, true)


func _round_trip(state: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(state, "", true, true)) as Dictionary


func _expect(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
	return condition
