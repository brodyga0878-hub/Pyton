extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Economy := preload("res://scripts/port_economy.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Main := preload("res://main.tscn")
const Session := preload("res://scripts/session_io.gd")
const FARM := 1
const MINE := 3
const DEALER := 11
const CARGO := "rations"
const REGULATED := "weapon_parts"

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_industry()
	_test_routes_and_disposal()
	_test_contact_transactions()
	_test_save_upgrade()
	await _test_market_interface()
	print("Industrial and hidden markets: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_industry() -> void:
	var flight := _at_port(FARM)
	var unique := {}
	for group: int in range(Economy.GROUPS.size()):
		for good: String in Economy.goods_for_group(group):
			_expect(not unique.has(good) and Economy.good_name(good) != "", "Each catalogue item is reachable in exactly one group")
			unique[good] = true
	_expect(unique.size() == 33 and Economy.NEW_GOODS.size() == 27, "The catalogue has six retained and 27 new commodities")
	var farm := flight.market_profile(FARM)
	var mine := flight.market_profile(MINE)
	var local := flight.market_profile(DEALER)
	_expect(farm.specialty == "food" and mine.specialty == "mining" and farm.settlements == Catalog.ports_for(Catalog.HOME_SYSTEM).size()
		and local.owner == 1 and local.settlements == Catalog.ports_for(Catalog.VELAR_SYSTEM).size(),
		"Port profiles use actual operational settlements and system ownership")
	var first_stock := flight.market.stock(FARM, CARGO)
	var second_stock := flight.market.stock(MINE, CARGO)
	var inactive_stock := flight.market.stock(Catalog.HEATHER_PORT, CARGO)
	var prior_buy := flight.market_quote(CARGO, "buy", 1)
	var counterpart := _at_port(FARM)
	flight.update(Economy.SUPPLY_INTERVAL * 2.0, Vector2.ZERO, 0.0, false, false)
	for _step in range(2):
		counterpart.update(Economy.SUPPLY_INTERVAL, Vector2.ZERO, 0.0, false, false)
	_expect(flight.market.stock(FARM, CARGO) == first_stock + 2 * Economy.supply_flow(CARGO, farm)
		and flight.market.stock(MINE, CARGO) == second_stock + 2 * Economy.supply_flow(CARGO, mine)
		and flight.market.stock(Catalog.HEATHER_PORT, CARGO) == inactive_stock,
		"The producing port replenishes rations, the consuming port spends them, and an unbuilt port remains inactive")
	_expect(flight.market.snapshot() == counterpart.market.snapshot() and flight.market_quote(CARGO, "buy", 1).unit < prior_buy.unit,
		"Stock and quotes are deterministic independently of the size of elapsed simulation steps")
	var normal := Economy.profile(Catalog.HEATHER_PORT, 0, 1, 0, false)
	var under_attack := Economy.profile(Catalog.HEATHER_PORT, 0, 1, 80, true)
	var seized := Economy.profile(Catalog.HEATHER_PORT, 1, 1, 80, true)
	_expect(Economy.supply_flow("grain", under_attack) < Economy.supply_flow("grain", normal)
		and Economy.price(Catalog.HEATHER_PORT, "biosamples", "buy", under_attack) > Economy.price(Catalog.HEATHER_PORT, "biosamples", "buy", normal)
		and Economy.price(Catalog.HEATHER_PORT, "biosamples", "buy", seized) > Economy.price(Catalog.HEATHER_PORT, "biosamples", "buy", under_attack),
		"War pressure inhibits production and raises risk prices, and a change of authority applies a different tariff")


func _test_routes_and_disposal() -> void:
	var flight := _at_port(FARM)
	flight.credits = 320
	var buying := flight.market_quote(CARGO, "buy", 3)
	_expect(buying.ok and flight.market_trade(CARGO, "buy", 3) and flight.mining.cargo_amount(CARGO) == 3
		and flight.credits == 320 - buying.cost and flight.market.stock(FARM, CARGO) == buying.stock - 3,
		"A new product is purchased with real money, stock and shared hold accounting")
	var arrived := flight.select_target(MINE) and Fixture.depart(flight)
	if arrived:
		flight.set_autopilot(true)
		for _frame in range(180 * 20):
			if flight.docked == MINE:
				break
			flight.update(0.05, Vector2.ZERO, 0.0, false, false)
	_expect(arrived and flight.docked == MINE, "Move the traded cargo along the actual route from the producer to the consuming mine")
	var selling := flight.market_quote(CARGO, "sell", 3)
	_expect(selling.ok and selling.cost > buying.cost and flight.market_trade(CARGO, "sell", 3)
		and flight.mining.cargo_amount(CARGO) == 0 and flight.credits == 320 - buying.cost + selling.cost,
		"The shipment earns the visible price difference at the consuming port")
	var waste := _at_port(0)
	var offer := waste.market_quote("sludge", "buy", 2)
	_expect(offer.ok and offer.cost < 0 and waste.market_trade("sludge", "buy", 2) and waste.credits == -offer.cost,
		"A negative ask pays the pilot to take waste cargo")
	var disposal := waste.market_quote("sludge", "sell", 2)
	_expect(not disposal.ok and disposal.cost < offer.cost and waste.market_limit("sludge", "sell") < 2
		and not waste.market_trade("sludge", "sell", 2) and waste.mining.cargo_amount("sludge") == 2,
		"A same-port disposal costs more than the pickup pays and cannot overdraw the wallet")
	waste.credits += 100
	disposal = waste.market_quote("sludge", "sell", 2)
	var balance := waste.credits
	_expect(disposal.ok and waste.market_trade("sludge", "sell", 2) and waste.credits == balance + disposal.cost,
		"A negative sale charges the signed disposal tariff exactly once")


func _test_contact_transactions() -> void:
	var safe: Flight
	var caught: Flight
	for index in range(40):
		var flight := _at_port(DEALER)
		flight.update(index * 30.0, Vector2.ZERO, 0.0, false, false)
		flight.credits = 450
		var legal_stock := flight.market.stock(DEALER, REGULATED)
		var hidden := flight.market_quote(REGULATED, "buy", 1, true)
		if not hidden.ok or not flight.market_trade(REGULATED, "buy", 1, true):
			continue
		if flight.mining.cargo_amount(REGULATED) > 0 and safe == null:
			safe = flight
			_expect(not safe.market_quote(REGULATED, "buy", 1).listed and safe.customs_status().violations == 0
				and hidden.risk > 0 and safe.credits == 450 - hidden.cost,
				"A restricted item trades only through the contact and can beat a real exposure roll")
		elif flight.mining.cargo_amount(REGULATED) == 0 and caught == null:
			caught = flight
			_expect(caught.customs_status().notice.get("good") == REGULATED and caught.customs_status().debt == 145
				and caught.credits == 450 and caught.status_event == "market_contact_seized",
				"An intercepted deal issues a real customs fine and neither charges the price nor delivers cargo")
		if flight == safe or flight == caught:
			_expect(flight.market.stock(DEALER, REGULATED) == legal_stock
				and flight.market.stock(DEALER, REGULATED, true) == hidden.stock - 1,
				"A hidden sale or seizure updates the contact inventory independently of the legal warehouse")
		if safe != null and caught != null:
			break
	if not _expect(safe != null and caught != null, "Both successful and intercepted transactions were exercised"):
		return
	var return_to := Catalog.system_of_site(DEALER)
	_expect(safe.system_id == return_to and safe.select_target(10) and Fixture.depart(safe),
		"A successful black-market lot can travel aboard the normal ship")
	safe.set_autopilot(true)
	for _step in range(180 * 20):
		if safe.docked == 10:
			break
		safe.update(0.05, Vector2.ZERO, 0.0, false, false)
	_expect(safe.docked == 10 and safe.mining.cargo_amount(REGULATED) == 0
		and safe.customs_status().notice.get("good") == REGULATED and safe.customs_status().debt == 145,
		"The next physical docking can confiscate a previously successful shipment under the local law")
	var cold := Flight.new()
	_expect(cold.restore(_rounded(caught.snapshot())) and cold.market.hidden_snapshot() == caught.market.hidden_snapshot()
		and cold.customs_status().notice == caught.customs_status().notice,
		"A completed interception survives a cold load with the same stock and customs ledger")


func _test_save_upgrade() -> void:
	var latest := _at_port(FARM)
	latest.credits = 200
	_expect(latest.market_trade("ore", "buy", 2), "Always retain established raw trading")
	var prior := latest.snapshot()
	prior.schema = 48
	Fixture.remove_expanded_market_from_legacy(prior)
	prior.erase("port_account")
	prior.erase("civic_reputation")
	var migrated := Flight.new()
	_expect(migrated.restore(_rounded(prior)) and migrated.credits == latest.credits and migrated.mining.cargo_amount("ore") == 2
		and migrated.market.stock(FARM, "ore") == latest.market.stock(FARM, "ore")
		and migrated.market.stock(FARM, CARGO) > 0 and migrated.mining.cargo_amount(CARGO) == 0,
		"Schema 48 keeps established hold contents and warehouse counts and creates stock only for new merchandise")
	var invalid := migrated.snapshot()
	invalid.market_contacts[str(DEALER)][REGULATED] = Economy.MAX_HIDDEN_STOCK + 1
	var good_save := migrated.snapshot()
	_expect(not migrated.restore(invalid) and migrated.snapshot() == good_save, "An impossible contact inventory is rejected atomically")
	invalid = migrated.snapshot()
	invalid.mining.cargo.erase(CARGO)
	_expect(not migrated.restore(invalid) and migrated.snapshot() == good_save, "A current save must describe all cargo entries")


func _test_market_interface() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := Main.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = _at_port(DEALER)
	game.flight.credits = 600
	game._update_display(0.0)
	await process_frame
	_tap(viewport, game._hud._actions["market"], "Open the real exchange from the dock")
	await process_frame
	var menu: CanvasLayer = game._market
	_tap(viewport, menu._next_group, "Browse from basic goods to the provisions group")
	await process_frame
	_expect(menu._goods_buttons[CARGO].is_visible_in_tree() and not menu._goods_buttons["ore"].is_visible_in_tree(),
		"The extra assortment stays reachable without overfilling the list")
	_tap(viewport, menu._contact_tab, "Open the docks contact on the touch exchange")
	await process_frame
	_tap(viewport, menu._goods_buttons[REGULATED], "Select embargoed goods at the separate contact")
	await process_frame
	_expect("Риск срыва" in menu._customs_rule.text and menu._buy_button.is_visible_in_tree()
		and not menu._goods_buttons[CARGO].is_visible_in_tree(), "The contact displays its own goods, risk and legal information")
	var before: int = game.flight.market.stock(DEALER, REGULATED, true)
	_tap(viewport, menu._buy_button, "Commit the actual contact quote by touch")
	_expect(game.flight.market.stock(DEALER, REGULATED, true) == before - 1 and menu._trade_receipt.is_visible_in_tree()
		and not menu._trade_receipt.text.is_empty(), "The action updates hidden inventory and reports its result on the same exchange")
	var cold := Flight.new()
	_expect(cold.restore(Session.load_state()) and cold.market.stock(DEALER, REGULATED, true) == before - 1,
		"The real market action immediately saves the result of the secret deal")
	viewport.queue_free()
	await process_frame


func _at_port(port: int) -> Flight:
	var flight := Flight.new()
	var state := flight.snapshot()
	var contact := flight.target_contact(port)
	state.merge({"position": [contact.x, contact.y, contact.z], "system_id": Catalog.system_of_site(port),
		"docked": port, "target": port}, true)
	if port == 0:
		return flight
	assert(flight.restore(state))
	return flight


func _tap(viewport: SubViewport, button: Button, description: String) -> void:
	if not _expect(button.is_visible_in_tree() and not button.disabled, description):
		return
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 8
		event.pressed = pressed
		event.position = button.get_global_rect().get_center()
		viewport.push_input(event, true)


func _rounded(state: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(state))


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
