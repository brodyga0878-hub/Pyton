extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Economy := preload("res://scripts/port_economy.gd")
const Expedition := preload("res://scripts/expedition.gd")
const NpcFreight := preload("res://scripts/npc_freight.gd")
const OrbitRelay := preload("res://main.tscn")
const HOME := Catalog.HOME_SYSTEM
const VELAR := Catalog.VELAR_SYSTEM
const FIRST_DEPARTURE := 28.0
const FIRST_ARRIVAL := 78.0
const FIRST_RETURN := 144.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_remote_shipments()
	_test_capacity_guards()
	_test_mid_leg_restart()
	_test_rounded_arrival_restart()
	_test_interval_and_migration()
	_test_stock_sensitive_prices()
	_test_quick_sale()
	await _test_market_touch()
	print("NPC freight and market integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_remote_shipments() -> void:
	var flight := Flight.new()
	var totals := _supplies(flight)
	var source := flight.market.stock(0, "circuits")
	var destination := flight.market.stock(1, "circuits")
	var remote_source := flight.market.stock(10, "ice")
	var remote_destination := flight.market.stock(11, "ice")
	var initial := _service(flight, HOME, 0)
	if not _expect(not initial.is_empty() and not initial.in_transit and initial.origin == 0 and initial.destination == 1
		and is_equal_approx(initial.departure_eta, FIRST_DEPARTURE) and initial.arrival_eta >= FIRST_DEPARTURE,
		"A scheduled local trader exposes its real endpoints and time to first departure"):
		return
	_expect(flight.freight_status(Catalog.HEATHER_PORT).is_empty() and flight.freight_status(999).is_empty(),
		"Undiscovered and nonexistent ports expose no scheduled cargo traffic")
	_tick(flight, FIRST_DEPARTURE - 0.25)
	_expect(flight.market.stock(0, "circuits") == source and flight.market.stock(10, "ice") == remote_source,
		"Warehouses retain cargo until the actual scheduled departure")
	_tick(flight, 0.5)
	var loaded := _service(flight, HOME, 0)
	var remote := _service(flight, VELAR, 0)
	if not _expect(loaded.in_transit and loaded.good == "circuits" and loaded.amount == NpcFreight.CAPACITY
		and remote.in_transit and remote.good == "ice" and remote.amount == NpcFreight.CAPACITY
		and flight.market.stock(0, "circuits") == source - loaded.amount and flight.market.stock(1, "circuits") == destination
		and flight.market.stock(10, "ice") == remote_source - remote.amount and flight.market.stock(11, "ice") == remote_destination,
		"Departures transfer real stock into the haulers in both the current and remote sectors"):
		return
	_expect(flight.market_quote("circuits", "buy", 1).unit == Economy.price(0, "circuits", "buy") + 1,
		"The same live port quote reflects the shortage created by the departing trader")
	_tick(flight, 25.0)
	var moving := _service(flight, HOME, 0)
	_expect(moving.progress > loaded.progress and moving.progress > 0.25 and moving.progress < 0.75
		and moving.arrival_eta < loaded.arrival_eta and not flight.freight_status(1).is_empty(),
		"Trader service rows report progress and a decreasing arrival estimate during flight")
	_tick(flight, 25.0)
	var unloaded := _service(flight, HOME, 0)
	_expect(flight.docked == 0 and flight.system_id == HOME and not unloaded.in_transit
		and unloaded.last_port == 1 and unloaded.last_delivered == loaded.amount and unloaded.last_good == "circuits"
		and flight.market.stock(1, "circuits") == destination + loaded.amount
		and flight.market.stock(11, "ice") == remote_destination + remote.amount,
		"Both shipments arrive at their real warehouses even though the player stayed docked in the original system")
	_expect(_supplies(flight) == totals, "No commodity is created or lost while the scheduled ships move cargo")


func _test_capacity_guards() -> void:
	var scarce := Flight.new()
	_set_stock(scarce, 0, "circuits", NpcFreight.STOCK_FLOOR + 3)
	_set_stock(scarce, 1, "circuits", Economy.MAX_STOCK - 1)
	_tick(scarce, FIRST_DEPARTURE + 0.25)
	_expect(_service(scarce, HOME, 0).amount == 1 and scarce.market.stock(0, "circuits") == NpcFreight.STOCK_FLOOR + 2,
		"A departing trader loads only the known free capacity at its destination")
	_tick(scarce, FIRST_ARRIVAL - FIRST_DEPARTURE)
	_expect(scarce.market.stock(1, "circuits") == Economy.MAX_STOCK and _service(scarce, HOME, 0).amount == 0,
		"The one-unit shipment fits exactly without overflowing the warehouse")
	var flight := Flight.new()
	_set_stock(flight, 0, "circuits", NpcFreight.STOCK_FLOOR + 3)
	_tick(flight, FIRST_DEPARTURE + 0.25)
	_expect(_service(flight, HOME, 0).amount == 3 and flight.market.stock(0, "circuits") == NpcFreight.STOCK_FLOOR,
		"A trader draws only the surplus above the origin's commodity reserve")
	_set_stock(flight, 1, "circuits", Economy.MAX_STOCK)
	var after_injection := _supplies(flight)
	_tick(flight, FIRST_ARRIVAL - FIRST_DEPARTURE)
	var waiting := _service(flight, HOME, 0)
	_expect(not waiting.in_transit and waiting.amount == 3 and waiting.last_delivered == 0
		and flight.market.stock(1, "circuits") == Economy.MAX_STOCK and _supplies(flight) == after_injection,
		"If the destination fills during travel, the ship retains all undelivered cargo")
	_tick(flight, FIRST_RETURN - FIRST_ARRIVAL)
	var returning := _service(flight, HOME, 0)
	_expect(not returning.in_transit and returning.last_port == 0 and returning.last_delivered == 3 and returning.last_good == "circuits"
		and returning.amount == 0 and flight.market.stock(0, "circuits") == NpcFreight.STOCK_FLOOR + 3
		and _supplies(flight) == after_injection,
		"Retained cargo returns to the open warehouse without duplication or a new incompatible load")


func _test_mid_leg_restart() -> void:
	var flight := Flight.new()
	_tick(flight, FIRST_DEPARTURE + 15.0)
	var persisted := _json(flight.snapshot())
	var resumed := Flight.new()
	if not _expect(persisted.schema == Flight.SAVE_SCHEMA and resumed.restore(persisted)
		and _service(resumed, HOME, 0) == _service(flight, HOME, 0)
		and _service(resumed, HOME, 0).amount > 0 and resumed.market.snapshot() == flight.market.snapshot(),
		"A cold mid-flight restore keeps the actual cargo, phase, timings and market debit"):
		return
	var invalid := persisted.duplicate(true)
	invalid.freight.ships[0].amount = NpcFreight.CAPACITY + 1
	var unchanged := resumed.snapshot()
	_expect(not resumed.restore(invalid) and resumed.snapshot() == unchanged,
		"A persisted hauler above its capacity cannot partially replace a live market or route")
	_tick(flight, 46.0)
	_tick(resumed, 46.0)
	_expect(resumed.market.snapshot() == flight.market.snapshot() and resumed.freight.snapshot() == flight.freight.snapshot()
		and _service(resumed, HOME, 0).last_delivered == NpcFreight.CAPACITY,
		"Once resumed, the same leg unloads only once and the next dock schedule remains deterministic")


func _test_rounded_arrival_restart() -> void:
	var flight := Flight.new()
	_tick(flight, 34.0)
	var frontier := flight.expedition.snapshot()
	frontier.projects[0] = {"phase": Expedition.COMPLETE, "sponsor_port": 0, "sponsor": 0,
		"scan_index": Expedition.SURVEY_TOTAL, "build_index": Expedition.BUILD_TOTAL}
	if not _expect(flight.expedition.restore(frontier) and flight.factions.commission(Catalog.HEATHER_SYSTEM, 0, flight.orbit_time)
		and flight.freight.activate_frontier(Catalog.HEATHER_SYSTEM, flight.orbit_time), "Prepare two simultaneous scheduled arrivals"):
		return
	_tick(flight, 78.0 - 1e-14)
	var saved := _json(flight.snapshot())
	# Round to the boundary if the JSON writer happened to retain the final digit.
	saved.orbit_time = 112.0
	var resumed := Flight.new()
	var core_stock := flight.market.stock(3, "medical")
	var frontier_stock := flight.market.stock(Catalog.HEATHER_PORT, "medical")
	if not _expect(flight.orbit_time < 112.0 and saved.freight.ships[1].amount == NpcFreight.CAPACITY
		and saved.freight.ships[6].amount == NpcFreight.CAPACITY and resumed.restore(saved)
		and resumed.freight.snapshot() == flight.freight.snapshot(), "A rounded arrival epoch preserves both pending ledgers on restart"):
		return
	var stale := saved.duplicate(true)
	stale.orbit_time = 112.01
	var before := resumed.snapshot()
	_expect(not resumed.restore(stale) and resumed.snapshot() == before, "A stale arrival step away from the boundary is still rejected atomically")
	_tick(resumed, 0.5)
	var delivered := _json(resumed.snapshot())
	delivered.orbit_time = 112.0 - 1e-12
	_expect(resumed.market.stock(3, "medical") == core_stock + NpcFreight.CAPACITY
		and resumed.market.stock(Catalog.HEATHER_PORT, "medical") == frontier_stock + NpcFreight.CAPACITY
		and resumed.restore(delivered), "Pending arrivals unload, and a backward-rounded clock accepts both completed steps")
	_tick(resumed, 0.5)
	_expect(resumed.market.stock(3, "medical") == core_stock + NpcFreight.CAPACITY
		and resumed.market.stock(Catalog.HEATHER_PORT, "medical") == frontier_stock + NpcFreight.CAPACITY,
		"Neither cargo is delivered twice after reopening the completed boundary")


func _test_interval_and_migration() -> void:
	var bulk := Flight.new()
	var fragmented := Flight.new()
	var warp := Flight.new()
	var initial := _supplies(bulk)
	_tick(bulk, 600.0)
	for _step in range(60):
		_tick(fragmented, 10.0)
	warp.cycle_time_scale()
	warp.cycle_time_scale()
	_tick(warp, 37.5)
	_expect(bulk.market.snapshot() == fragmented.market.snapshot() and bulk.freight.snapshot() == fragmented.freight.snapshot()
		and bulk.market.snapshot() == warp.market.snapshot() and bulk.freight.snapshot() == warp.freight.snapshot()
		and bulk.orbit_time == warp.orbit_time and _supplies(bulk) == initial,
		"One 600-second interval, sixty intervals and 16× time produce the same cargo and inventories")
	var historical := Flight.new()
	_set_stock(historical, 0, "circuits", 37)
	var old := _json(historical.snapshot())
	old.schema = 15
	old.ship.erase("mining_laser")
	old.ship.erase("fragment_collector")
	old.ship.erase("hull_id")
	old.ship.erase("jump_fuel")
	old.mining.cargo.erase("hydrogen")
	old.mining.reserves.resize(Catalog.PRE_GAS_DESTINATION_COUNT)
	for stocks: Dictionary in old.market.values():
		stocks.erase("hydrogen")
	old.orbit_time = 1234.25
	old.elapsed = 1234.25
	old.erase("freight")
	if not _expect(historical.restore(old) and _market_without_hydrogen(historical) == old.market
		and historical.orbit_time == 1234.25 and is_equal_approx(_service(historical, HOME, 0).departure_eta, FIRST_DEPARTURE),
		"Migrating an older save preserves its market and schedules new deliveries from the saved epoch"):
		return
	_tick(historical, FIRST_DEPARTURE - 0.25)
	_expect(_market_without_hydrogen(historical) == old.market and not _service(historical, HOME, 0).in_transit,
		"Migrated time does not retroactively replay old transactions")
	_tick(historical, 0.5)
	_expect(historical.market.stock(0, "circuits") == 37 - NpcFreight.CAPACITY and _service(historical, HOME, 0).in_transit,
		"The first shipment after migration uses the saved inventory at its new departure time")


func _test_stock_sensitive_prices() -> void:
	var flight := Flight.new()
	var stock := flight.market.stock(0, "ore")
	var base_buy := Economy.price(0, "ore", "buy")
	var base_sell := Economy.price(0, "ore", "sell")
	var quote := flight.market_quote("ore", "buy", 18)
	var expected_buy := 18 * base_buy + 18
	_expect(quote.cost == expected_buy and quote.unit == base_buy and quote.stock == stock,
		"Taking 18 units prices each set of six against the progressively lower inventory")
	flight.credits = expected_buy - 1
	_expect(flight.market_limit("ore", "buy") == 17 and not flight.market_quote("ore", "buy", 18).ok,
		"Maximum affordable quantity uses the sum of changing unit prices")
	var denied := flight.snapshot()
	_expect(not flight.market_trade("ore", "buy", 18) and flight.snapshot() == denied,
		"An order one credit beyond the quote leaves the market and hold untouched")
	flight.credits = expected_buy
	if not _expect(flight.market_trade("ore", "buy", 18) and flight.market.stock(0, "ore") == stock - 18
		and flight.credits == 0 and flight.mining.cargo_amount("ore") == 18,
		"Paying the exact marginal quote transfers all 18 units"):
		return
	var return_quote := flight.market_quote("ore", "sell", 18)
	var expected_sale := 18 * base_sell + 18
	_expect(return_quote.ok and return_quote.cost == expected_sale and expected_buy > expected_sale,
		"Selling the bulk back prices the same stock levels at the lower sell tariff")
	_expect(flight.market_trade("ore", "sell", 18) and flight.credits == expected_sale
		and flight.market.stock(0, "ore") == stock and flight.mining.cargo_amount("ore") == 0,
		"A buy and sell at the same dock cannot create money or stock")
	_set_stock(flight, 0, "ice", 1)
	_set_stock(flight, 0, "ore", Economy.MAX_STOCK)
	_expect(flight.market_quote("ice", "buy", 1).unit == Economy.price(0, "ice", "buy") + 8
		and flight.market_quote("ore", "buy", 1).unit == base_buy - 8,
		"Scarcity premiums and surplus discounts stop at eight credits")


func _test_quick_sale() -> void:
	var flight := Flight.new()
	flight.credits = 1500
	if not _expect(flight.market_trade("ore", "buy", 10) and flight.market_trade("ice", "buy", 4)
		and flight.market_trade("crystal", "buy", 3), "Prepare a mixed hold through actual market transactions"):
		return
	_set_stock(flight, 0, "ore", Economy.MAX_STOCK - 2)
	_set_stock(flight, 0, "crystal", Economy.MAX_STOCK)
	var expected := int(flight.market_quote("ore", "sell", 2).cost) + int(flight.market_quote("ice", "sell", 4).cost)
	var balance := flight.credits
	var unchanged := flight.snapshot()
	_expect(flight.raw_sale_quote() == expected, "The HUD's raw-material quote includes only units that can actually be sold")
	_expect(flight.market_limit("ore", "sell") == 2 and flight.market_limit("crystal", "sell") == 0
		and not flight.market_trade("ore", "sell", 3) and flight.snapshot() == unchanged,
		"The normal sell route rejects units beyond free warehouse space without removing cargo")
	_expect(flight.sell_ore_action() and flight.credits == balance + expected and flight.market.stock(0, "ore") == Economy.MAX_STOCK
		and flight.mining.cargo_amount("ore") == 8 and flight.mining.cargo_amount("ice") == 0
		and flight.mining.cargo_amount("crystal") == 3,
		"Quick sale uses the same prices and keeps goods that the port cannot store")


func _test_market_touch() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := OrbitRelay.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var flight := Flight.new()
	game.flight = flight
	flight.credits = int(flight.market_quote("ore", "buy", 18).cost) - 1
	var balance := flight.credits
	var payment: int = flight.market_quote("ore", "buy", 17).cost
	game._update_display(0.0)
	await process_frame
	_tap(viewport, game._hud._actions["market"], "Open the actual exchange by touch")
	await process_frame
	_tap(viewport, game._market._buy_max_button, "Use the maximum-purchase touch control")
	await process_frame
	_expect(game._market._quantity == 17, "The maximum purchase button selects the largest affordable marginal quote")
	_tap(viewport, game._market._buy_button, "Complete the quantity chosen by the maximum button")
	await process_frame
	_expect(flight.mining.cargo_amount("ore") == 17 and flight.credits == balance - payment,
		"The touch transaction debits the sum shown for the affordable lot")
	_set_stock(flight, 0, "ore", Economy.MAX_STOCK - 1)
	game._market.refresh()
	await process_frame
	_tap(viewport, game._market._sell_max_button, "Select the maximum sale with only one free warehouse slot")
	await process_frame
	_expect(game._market._quantity == 1, "The maximum sale control limits the quantity to existing warehouse space")
	_tap(viewport, game._market._sell_button, "Sell the single unit that fits")
	await process_frame
	_expect(flight.mining.cargo_amount("ore") == 16 and flight.market.stock(0, "ore") == Economy.MAX_STOCK
		and game._market._sell_max_button.disabled, "The touch sale keeps all remaining cargo as the warehouse fills")
	_tick(flight, FIRST_DEPARTURE + 17.0)
	_tap(viewport, game._market._freight_tab, "Open the actual NPC supply page by touch")
	await process_frame
	var route := _service(flight, HOME, 0)
	if _expect(game._market._freight_page.is_visible_in_tree() and not game._market._freight_rows.is_empty(),
		"The current dock's supply page renders its progressing service"):
		var row: Dictionary = game._market._freight_rows[0]
		_expect(Economy.good_name("circuits") in row.cargo.text and str(route.amount) in row.cargo.text
			and row.progress.visible and absf(row.progress.value - float(route.progress)) <= maxf(row.progress.step * 0.51, 0.001)
			and "Прибытие" in row.eta.text,
			"The freight card reads real cargo, progress and arrival time from the simulation")
	viewport.queue_free()
	await process_frame


func _set_stock(flight: Flight, port: int, good: String, amount: int) -> void:
	flight.market.change_stock(port, good, amount - flight.market.stock(port, good))


func _service(flight: Flight, system: int, slot: int) -> Dictionary:
	for route: Dictionary in flight.freight.services(system, flight.orbit_time):
		if route.slot == slot:
			return route
	return {}


func _supplies(flight: Flight) -> Dictionary:
	var totals := {}
	for good: String in Economy.GOODS:
		totals[good] = 0
	for inventory: Dictionary in flight.market.snapshot().values():
		for good: String in inventory:
			totals[good] += inventory[good]
	for system in range(Catalog.CORE_SYSTEM_COUNT):
		for route: Dictionary in flight.freight.services(system, flight.orbit_time):
			if route.amount > 0:
				totals[route.good] += route.amount
	return totals


func _json(value: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value, "", true, true)) as Dictionary


func _tick(flight: Flight, seconds: float) -> void:
	flight.update(seconds, Vector2.ZERO, 0.0, false, false)


func _tap(viewport: SubViewport, button: Button, description: String) -> void:
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, description):
		return
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 9
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		viewport.push_input(event, true)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition


func _market_without_hydrogen(flight: Flight) -> Dictionary:
	var stocks := _json(flight.market.snapshot())
	for inventory: Dictionary in stocks.values():
		inventory.erase("hydrogen")
	return stocks
