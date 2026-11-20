extends SceneTree

const Flight = preload("res://scripts/flight_sim.gd")
const Catalog = preload("res://scripts/sector_catalog.gd")
const Economy = preload("res://scripts/port_economy.gd")
const Rig = preload("res://scripts/mining_rig.gd")
const OrbitRelay = preload("res://main.tscn")
const STEP := 1.0 / 60.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_local_tariffs()
	_test_trade_guards()
	_test_hull_and_hold()
	_test_legacy_save()
	_test_interstellar_courier()
	await _test_touch_services()
	await _test_touch_trade_and_courier()
	print("Economy integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_local_tariffs() -> void:
	for system in range(Catalog.CORE_SYSTEM_COUNT):
		for port: int in Catalog.ports_for(system):
			var flight := _at_port(port)
			flight.credits = 2000
			for good: String in Economy.GOODS:
				var buying := flight.market_quote(good, "buy", 1)
				var selling := flight.market_quote(good, "sell", 1)
				_expect(buying.ok and buying.cost == buying.unit and buying.stock > 0 and buying.owned == 0
					and buying.unit > selling.unit and not selling.ok,
					"Port %d quotes distinct local prices and available stock for %s" % [port, good])
			var route := flight.courier_offer()
			_expect(route.origin == port and route.stops.size() >= 2 and route.reward > 0,
				"Port %d offers a courier itinerary with multiple stops" % port)
	_expect(Economy.price(3, "circuits", "sell") > Economy.price(0, "circuits", "buy"),
		"The industrial route has a profitable spread between distinct ports")


func _test_trade_guards() -> void:
	var flight := Flight.new()
	var price: int = Economy.price(0, "circuits", "buy")
	flight.credits = 2 * price - 1
	var original := flight.snapshot()
	_expect(not flight.market_quote("circuits", "buy", 2).ok
		and not flight.market_trade("circuits", "buy", 2) and flight.snapshot() == original,
		"An unaffordable purchase leaves all state unchanged")
	for invalid in [["circuits", "buy", 0], ["circuits", "sell", -1], ["circuits", "buy", 25],
			["circuits", "sell", 1], ["unknown", "buy", 1], ["ore", "barter", 1]]:
		_expect(not flight.market_trade(invalid[0], invalid[1], invalid[2]) and flight.snapshot() == original,
			"An invalid or unavailable trade is atomic: %s" % [invalid])
	flight.credits += 1
	var old_stock: int = flight.market_quote("circuits", "buy", 2).stock
	_expect(flight.market_trade("circuits", "buy", 2) and flight.credits == 0
		and flight.mining.cargo_amount("circuits") == 2
		and flight.market_quote("circuits", "buy", 1).stock == old_stock - 2,
		"An exact-price purchase debits the port's stock and fills the shared hold")
	var paid := flight.snapshot()
	_expect(not flight.market_trade("circuits", "buy", 2) and not flight.market_trade("circuits", "sell", 3)
		and not flight.sell_ore_action() and flight.snapshot() == paid,
		"Repeated unaffordable purchases, overselling and raw quick sale cannot duplicate trade cargo")
	flight.dock_action()
	var launched := flight.snapshot()
	_expect(not flight.market_quote("circuits", "sell", 1).ok and not flight.market_trade("circuits", "sell", 1)
		and not flight.market_trade("ore", "buy", 1) and flight.snapshot() == launched,
		"The market cannot change inventory away from a dock")
	var scarce := _at_port(3)
	scarce.credits = 2000
	var stock: int = scarce.market_quote("medical", "buy", 1).stock
	var before := scarce.snapshot()
	_expect(stock > 0 and stock < scarce.mining.cargo_capacity
		and not scarce.market_trade("medical", "buy", stock + 1) and scarce.snapshot() == before,
		"A fully funded order that exceeds local stock leaves the market and hold unchanged")
	_expect(scarce.market_trade("medical", "buy", stock) and scarce.mining.cargo_amount("medical") == stock
		and scarce.market_quote("medical", "buy", 1).stock == 0 and not scarce.market_trade("medical", "buy", 1),
		"Buying a full supply empties just its local inventory and disables another purchase")


func _test_hull_and_hold() -> void:
	var flight := Flight.new()
	flight.dock_action()
	flight.select_target(Catalog.STAR_ID)
	var star_center := flight.target_position(Catalog.STAR_ID)
	flight.position = star_center + Vector3.BACK * (Catalog.STAR_CLEARANCE + 0.02)
	flight.yaw = 0.0
	flight.velocity = Vector3.FORWARD * 8.0
	flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	_expect(flight.ship.hull == 100.0 and flight.speed() < 0.01,
		"Gentle protective braking does not damage the hull")
	flight.velocity = Vector3.FORWARD * 65.0
	flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	_expect(flight.ship.hull < 100.0 and flight.ship.hull >= 1.0 and flight.speed() < 0.01,
		"High-speed contact records hull damage and still stops the ship at the protection boundary")
	var resumed := Flight.new()
	_expect(resumed.restore(_round_trip(flight.snapshot())) and is_equal_approx(resumed.ship.hull, flight.ship.hull),
		"Hull damage survives a cold load in flight")
	_expect(not resumed.service_action("repair") and not resumed.service_action("cargo"),
		"Repair and cargo equipment require docking")
	if not _expect(_fly_to(resumed, 0), "The damaged ship can still return to port"):
		return
	var repair_cost: int = ceili(100.0 - resumed.ship.hull) * Economy.repair_price(0)
	resumed.credits = maxi(0, repair_cost - 1)
	_expect(repair_cost > 0 and resumed.service_offer("repair").cost == repair_cost
		and not resumed.service_action("repair"), "Repair quotes the port tariff and rejects insufficient payment")
	resumed.credits = repair_cost
	_expect(resumed.service_action("repair") and resumed.ship.hull == 100.0 and resumed.credits == 0
		and not resumed.service_action("repair"), "Exact-price repair restores the hull and cannot charge twice")
	resumed.credits = 2400
	_expect(resumed.mining.cargo_capacity == Rig.CAPACITY and resumed.service_offer("cargo").cost == 300
		and resumed.service_action("cargo") and resumed.ship.cargo_upgraded and resumed.mining.cargo_capacity == 40
		and resumed.credits == 2100 and not resumed.service_action("cargo"),
		"Cargo equipment raises the shared hold from 24 to 40 exactly once")
	_expect(resumed.market_trade("circuits", "buy", 37) and resumed.mining.free_capacity() == 3,
		"Purchased components leave exactly their remaining space for mined cargo")
	if not _expect(_fly_to(resumed, 2), "The upgraded ship reaches the ore deposit with its purchased freight"):
		return
	var reserve: int = resumed.mining.reserve_at(2)
	_expect(resumed.mine_action(), "The rig starts a partial batch with only three slots remaining")
	_step(resumed, 13.0)
	_expect(resumed.mining.phase == Rig.READY and resumed.mining.pending_ore == 3 and resumed.mine_action(),
		"The ready rig reserves only enough ore to fill the remaining shared hold space")
	_step(resumed, 3.0)
	_expect(resumed.mining.ore_hold == 40 and resumed.mining.cargo_amount("ore") == 3
		and resumed.mining.reserve_at(2) == reserve - 3 and not resumed.mine_action(),
		"Recovery debits only the partial yield and the full upgraded hold blocks another rig deployment")
	var upgraded := Flight.new()
	_expect(upgraded.restore(_round_trip(resumed.snapshot())) and upgraded.mining.cargo_capacity == 40
		and upgraded.mining.cargo_amount("circuits") == 37 and upgraded.mining.cargo_amount("ore") == 3,
		"A cold save reloads purchased goods and extracted ore above the original limit")
	var before := upgraded.snapshot()
	var invalid := before.duplicate(true)
	invalid.ship.cargo_upgraded = false
	_expect(not upgraded.restore(invalid) and upgraded.snapshot() == before,
		"Removing the equipment flag cannot restore an overfilled hold")
	if not _expect(_fly_to(upgraded, 3), "The mixed hold can reach a market at a different port"):
		return
	var previous_credits: int = upgraded.credits
	var raw_stock: int = upgraded.market_quote("ore", "sell", 3).stock
	_expect(upgraded.sell_ore_action() and upgraded.mining.cargo_amount("ore") == 0
		and upgraded.mining.cargo_amount("circuits") == 37
		and upgraded.credits == previous_credits + 3 * Economy.price(3, "ore", "sell")
		and upgraded.market_quote("ore", "sell", 1).stock == raw_stock + 3,
		"The raw-resource shortcut sells the ore and replenishes stock while retaining manufactured goods")


func _test_legacy_save() -> void:
	# Published 0.39 state has a three-resource hold and no independent market stock.
	var legacy := {
		"schema": 7, "position": [0.0, 0.0, -152.0], "velocity": [0.0, 0.0, 0.0],
		"yaw": 0.0, "pitch": 0.0, "roll": 0.0, "elapsed": 0.0, "orbit_time": 0.0, "throttle": 0.0,
		"docked": 0, "target": 1, "landed_site": -1, "planned_target": -1, "landing_direction": [0.0, 0.0, 0.0],
		"system_id": 0, "jump_target": 1, "credits": 188, "deliveries": 2,
		"contract_stage": 1, "contract_origin": 0, "contract_destination": 1,
		"ship": {"fuel": 84.25, "tank_upgraded": true, "eco_upgraded": true},
		"mining": {"site_id": 2, "phase": Rig.STOWED, "phase_seconds": 0.0, "pending_ore": 0,
			"cargo": {"ore": 12, "crystal": 0, "ice": 0},
			"reserves": [0, 0, 108, 0, 96, 180, 156, 132, 216, 0, 0, 0, 192, 144, 0, 240]},
	}
	var flight := Flight.new()
	if not _expect(flight.restore(_round_trip(legacy)), "A literal 0.39 save migrates into the economy version"):
		return
	_expect(flight.ship.fuel == 84.25 and flight.ship.tank_upgraded and flight.ship.eco_upgraded
		and flight.ship.hull == 100.0 and flight.mining.cargo_capacity == 24
		and flight.credits == 188 and flight.deliveries == 2 and flight.contract_destination == 1,
		"Migration initializes hull and the standard hold while keeping the established upgrades and freight")
	_expect(flight.mining.cargo_amount("ore") == 12 and flight.mining.cargo_amount("circuits") == 0
		and flight.mining.cargo_amount("medical") == 0 and flight.mining.reserve_at(2) == 108
		and flight.market_quote("circuits", "buy", 1).stock == Flight.new().market_quote("circuits", "buy", 1).stock,
		"Old mined resources, untouched market slots and starting station inventories migrate together")
	var modern := flight.snapshot()
	var invalid := modern.duplicate(true)
	invalid.ship.hull = 101.0
	_expect(not flight.restore(invalid) and flight.snapshot() == modern,
		"Invalid hull integrity is rejected atomically")
	invalid = modern.duplicate(true)
	invalid.market["0"].ore = -1
	_expect(not flight.restore(invalid) and flight.snapshot() == modern,
		"An impossible persisted market inventory cannot alter the live state")
	if _expect(_fly_to(flight, 1), "Pre-economy single-stop freight remains deliverable on normal autopilot"):
		_expect(flight.contract_action() and flight.credits == 188 + 240 and flight.deliveries == 3,
			"An already accepted legacy contract still pays the same award exactly once")


func _test_interstellar_courier() -> void:
	var flight := _at_port(3)
	var route := flight.courier_offer()
	if not _expect(route.stops == [0, 10, 11] and not flight.accept_courier("relay_calibration")
		and flight.accept_courier(route.id) and not flight.accept_courier(route.id)
		and not flight.contract_action(), "The interstellar courier accepts once and must begin at its source port"):
		return
	if not _expect(_fly_to(flight, 0) and flight.contract_action() and flight.contract_destination == 10
		and flight.contract_itinerary().leg == 1 and flight.credits == 0 and flight.deliveries == 0,
		"The first local stop marks progress without paying and selects the foreign stop"):
		return
	var resumed := Flight.new()
	if not _expect(resumed.restore(_round_trip(flight.snapshot())) and resumed.contract_itinerary().leg == 1
		and resumed.contract_destination == 10 and not resumed.contract_action(),
		"The active remote stop survives a save and cannot be repeatedly cleared from port 0"):
		return
	var active := resumed.snapshot()
	var invalid := active.duplicate(true)
	invalid.contract_leg = 2
	_expect(not resumed.restore(invalid) and resumed.snapshot() == active,
		"A recorded next port must match its persisted courier leg")
	_expect(_jump_to(resumed, Catalog.VELAR_SYSTEM), "Courier freight crosses systems on the actual jump drive")
	if not _expect(_fly_to(resumed, 10) and resumed.contract_action() and resumed.contract_destination == 11
		and resumed.contract_itinerary().leg == 2 and resumed.credits == 0 and resumed.deliveries == 0,
		"The first remote port marks the second leg and selects the final delivery"):
		return
	if _expect(_fly_to(resumed, 11), "The final remote stop is reachable on the local autopilot"):
		_expect(resumed.contract_action() and resumed.contract_itinerary().completed and resumed.credits == route.reward
			and resumed.deliveries == 1, "Completing the courier route pays its whole reward once")
		var completed := Flight.new()
		_expect(completed.restore(_round_trip(resumed.snapshot())) and completed.credits == route.reward
			and completed.contract_itinerary().completed,
			"A completed itinerary survives a cold reload without awarding a new payment")


func _test_touch_services() -> void:
	var game := _open_scene()
	game.flight = Flight.new()
	var flight: Flight = game.flight
	flight.credits = 800
	flight.ship.apply_damage(7.5)
	var quote: int = flight.service_offer("repair").cost
	game._update_display(0.0)
	await process_frame
	_tap(game._hud._actions.get("services"), "Open the equipment and repair workshop by touch")
	await process_frame
	var services: Node = game._services
	_tap(services._action_buttons.get("repair"), "Pay the quoted repair tariff by touch")
	_expect(flight.ship.hull == 100.0 and flight.credits == 800 - quote
		and services._action_buttons.get("repair").disabled,
		"The repaired ship cannot buy a second repair while its hull is intact")
	await process_frame
	_tap(services._action_buttons.get("cargo"), "Install the expanded hold by touch")
	_expect(flight.ship.cargo_upgraded and flight.mining.cargo_capacity == 40 and flight.credits == 800 - quote - 300
		and services._action_buttons.get("cargo").disabled,
		"The workshop displays the installed upgrade and charges only once")
	game.queue_free()
	await process_frame
	game = _open_scene()
	flight = game.flight
	_expect(flight.ship.hull == 100.0 and flight.ship.cargo_upgraded and flight.mining.cargo_capacity == 40
		and flight.credits == 800 - quote - 300, "Touch repairs and equipment survive a cold reload")
	game.queue_free()
	await process_frame


func _test_touch_trade_and_courier() -> void:
	var game := _open_scene()
	game.flight = Flight.new()
	var flight: Flight = game.flight
	flight.credits = 1000
	game._update_display(0.0)
	await process_frame
	_tap(game._hud._actions.get("market"), "Open the exchange from the actual HUD")
	await process_frame
	var exchange: Node = game._market
	var paused: float = flight.elapsed
	game._physics_process(0.5)
	_expect(exchange.is_open() and flight.elapsed == paused and game._hud._actions.get("dock").disabled,
		"The exchange overlay pauses time and protects underlying ship controls")
	_tap(exchange._goods_buttons.get("circuits"), "Select the industrial commodity by touch")
	await process_frame
	_tap(exchange._plus_button, "Increase trade quantity by touch")
	await process_frame
	var buying := flight.market_quote("circuits", "buy", 2)
	_tap(exchange._buy_button, "Buy two units through the exchange")
	_expect(flight.credits == 1000 - buying.cost and flight.mining.cargo_amount("circuits") == 2
		and flight.market_quote("circuits", "buy", 1).stock == buying.stock - 2,
		"The quoted quantity, price and market subtraction match the touch transaction")
	game.queue_free()
	await process_frame
	game = _open_scene()
	flight = game.flight
	await process_frame
	_expect(flight.credits == 1000 - buying.cost and flight.mining.cargo_amount("circuits") == 2
		and flight.market_quote("circuits", "buy", 1).stock == buying.stock - 2,
		"The touch purchase saves station inventory and hold for a cold scene")
	_tap(game._hud._actions.get("market"), "Open the exchange on the restored ship")
	await process_frame
	exchange = game._market
	_tap(exchange._courier_tab, "Open the courier offers tab")
	await process_frame
	_tap(exchange._courier_button, "Accept the two-stop courier contract with touch")
	_expect(flight.contract_itinerary().get("leg", -1) == 0 and flight.contract_destination == 1,
		"The exchange accepts the first courier stop in its display order")
	if exchange.is_open():
		_tap(exchange._close_button, "Close the exchange and return to the flight HUD")
	await process_frame
	if not (await _touch_fly(game, 1)):
		game.queue_free()
		await process_frame
		return
	_tap(game._hud._actions.get("contract"), "Confirm the intermediate courier stop with the flight HUD")
	_expect(flight.contract_destination == 3 and flight.credits == 1000 - buying.cost and flight.deliveries == 0,
		"The intermediate touch advances the itinerary without issuing a payment")
	game.queue_free()
	await process_frame
	game = _open_scene()
	flight = game.flight
	await process_frame
	_expect(flight.contract_itinerary().get("leg", -1) == 1 and flight.contract_destination == 3 and flight.docked == 1,
		"The intermediate stop saves as soon as it is confirmed")
	if not (await _touch_fly(game, 3)):
		game.queue_free()
		await process_frame
		return
	_tap(game._hud._actions.get("contract"), "Complete the two-stop courier delivery by touch")
	_expect(flight.credits == 1000 - buying.cost + 570 and flight.deliveries == 1,
		"The courier touch pays only at the last port")
	_tap(game._hud._actions.get("market"), "Open the destination port's exchange")
	await process_frame
	exchange = game._market
	_tap(exchange._goods_buttons.get("circuits"), "Select the components held for resale")
	await process_frame
	_tap(exchange._plus_button, "Select both units for resale")
	await process_frame
	var selling := flight.market_quote("circuits", "sell", 2)
	_tap(exchange._sell_button, "Resell both units at the destination tariff")
	_expect(selling.cost > buying.cost and flight.credits == 1000 - buying.cost + 570 + selling.cost
		and flight.mining.ore_hold == 0 and flight.market_quote("circuits", "buy", 1).stock == selling.stock + 2,
		"Trading between two real ports earns the quoted difference and fills the destination stock")
	game.queue_free()
	await process_frame
	game = _open_scene()
	flight = game.flight
	_expect(flight.credits == 1000 - buying.cost + 570 + selling.cost and flight.mining.ore_hold == 0
		and not flight.market_trade("circuits", "sell", 1), "A cold reload cannot pay the resold goods again")
	game.queue_free()
	await process_frame


func _touch_fly(game: Node, destination: int) -> bool:
	_tap(game._hud._actions.get("dock"), "Launch to courier stop %d" % destination)
	await process_frame
	_tap(game._hud._actions.get("autopilot"), "Engage autopilot for courier stop %d" % destination)
	for _frame in range(roundi(125.0 / STEP)):
		if not game.flight.autopilot:
			break
		game._physics_process(STEP)
	game._update_display(0.0)
	await process_frame
	return _expect(game.flight.docked == destination,
		"The actual flight scene arrives at courier stop %d (%s)" % [destination, game.flight.status_message])


func _at_port(port: int) -> Flight:
	var flight := Flight.new()
	var state := flight.snapshot()
	var contact := flight.target_contact(port)
	state.position = [contact.x, contact.y, contact.z]
	state.system_id = Catalog.system_of_site(port)
	state.docked = port
	state.target = port
	_expect(flight.restore(state), "Initialize a physically docked ship at port %d" % port)
	return flight


func _fly_to(flight: Flight, destination: int) -> bool:
	if not flight.select_target(destination):
		return false
	if (flight.docked >= 0 or flight.landed) and not flight.dock_action():
		return false
	flight.set_autopilot(true)
	for _frame in range(roundi(125.0 / STEP)):
		if not flight.autopilot:
			break
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	return flight.docked == destination or flight.landed_site == destination


func _jump_to(flight: Flight, system: int) -> bool:
	if (flight.docked >= 0 and not flight.dock_action()) or not flight.plan_jump(system):
		return false
	flight.change_throttle(0.18)
	for _frame in range(roundi(12.0 / STEP)):
		if flight.jump_status(system).ok:
			break
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	if not flight.start_jump():
		return false
	_step(flight, 3.0)
	return flight.system_id == system


func _step(flight: Flight, seconds: float) -> void:
	for _frame in range(roundi(seconds / STEP)):
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)


func _open_scene() -> Node:
	var game := OrbitRelay.instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game._update_display(0.0)
	return game


func _tap(button: Button, description: String) -> bool:
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, description):
		return false
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 7
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event, true)
	return true


func _round_trip(value: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value, "", true, true))


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
