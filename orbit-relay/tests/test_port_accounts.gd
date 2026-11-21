extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Session := preload("res://scripts/session_io.gd")
const Services := preload("res://scripts/port_services.gd")
const PortAccount := preload("res://scripts/port_account.gd")
const Civic := preload("res://scripts/civic_reputation.gd")
const Economy := preload("res://scripts/port_economy.gd")
const HANGAR := Catalog.GROUND_HANGAR
const CLEARING_PORT := Catalog.GROUND_PAD
const ROUTE_PORT := Catalog.FRINGE_SECOND_PORT
const ROUTE := "fringe_beacons"

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_charges_and_legacy()
	_test_arrears_clearance()
	_test_civic_access()
	await _test_port_touch()
	print("Port accounts and civic reputation: %d checks, %d failures" % [_checks, _failures])
	quit(int(_failures > 0))


func _test_charges_and_legacy() -> void:
	var flight := _at_port(HANGAR, 30)
	var account := flight.port_account_status()
	var entry := int(account.entry)
	var rate := int(account.per_day)
	_expect(entry > 0 and rate > 0 and flight.credits == 30 - entry and account.receipt.kind == "entry"
		and int(account.receipt.paid) == entry and account.debt == 0, "Physical arrival charges the port-specific fee and issues a receipt")
	_expect(Flight.new().port_account_status().entry == 0 and Flight.new().departure_status().can_request,
		"The initial berth and introductory departure remain free")
	_tick(flight, PortAccount.DAY - 0.5)
	var checkpoint := _from_disk(flight.snapshot())
	if not _expect(checkpoint != null and checkpoint.credits == flight.credits
		and checkpoint.port_account_status().next_bill == account.next_bill, "Reload retains the original visit anchor just before a parking bill"):
		return
	_expect(checkpoint.toggle_time_pause(), "Pause the flight before crossing the billing boundary")
	_tick(checkpoint, 1.0)
	_expect(checkpoint.credits == 30 - entry and checkpoint.toggle_time_pause(), "A paused flight never posts a real-time parking bill")
	_tick(checkpoint, 0.5)
	account = checkpoint.port_account_status()
	_expect(checkpoint.credits == 30 - entry - rate and account.receipt.kind == "parking"
		and account.receipt.total == rate and account.receipt.at == PortAccount.DAY,
		"A completed simulation day adds exactly one tariff at its due timestamp")
	var restarted := _from_disk(checkpoint.snapshot())
	if not _expect(restarted != null, "A posted parking receipt survives a second independent load"):
		return
	_tick(restarted, 0.75)
	_expect(restarted.credits == checkpoint.credits and restarted.port_account_status().receipt == account.receipt,
		"Restart does not charge a second time for the same completed day")
	var legacy := restarted.snapshot()
	legacy.schema = 48
	Fixture.remove_schema_51_from_legacy(legacy)
	Fixture.remove_extended_career_from_legacy(legacy)
	Fixture.remove_ordnance_from_legacy(legacy)
	legacy.erase("port_account")
	legacy.erase("civic")
	legacy.erase("market_contacts")
	for good: String in Economy.GOODS:
		if good in Economy.LEGACY_GOODS:
			continue
		legacy.mining.cargo.erase(good)
		for stock: Dictionary in legacy.market.values():
			stock.erase(good)
	var migrated := _from_disk(legacy)
	if not _expect(migrated != null and migrated.credits == restarted.credits and migrated.port_account_status().receipt.is_empty()
		and migrated.port_account_status().next_bill == migrated.orbit_time + PortAccount.DAY,
		"Loading 0.96 at a paid berth anchors a fresh day without a retroactive charge"):
		return
	_tick(migrated, PortAccount.DAY - 1.0)
	_expect(migrated.credits == restarted.credits and migrated.port_account_status().receipt.is_empty(),
		"A migrated flight accrues its first bill only after a full new day")


func _test_arrears_clearance() -> void:
	var flight := _at_port(HANGAR, 2)
	var bill := flight.port_account_status()
	var arrival_debt := int(bill.entry) - 2
	_expect(flight.credits == 0 and bill.debt == arrival_debt and bill.due == PortAccount.DAY
		and not bill.overdue and flight.departure_status().can_request,
		"An entry shortfall has a visiting-port creditor and an actual one-day grace period")
	_tick(flight, PortAccount.DAY)
	bill = flight.port_account_status()
	var first_debt := arrival_debt + int(bill.per_day)
	_expect(bill.overdue and bill.debt == first_debt and not flight.departure_status().can_request
		and not flight.dock_action() and flight.status_event == "departure_charge_denied",
		"Unsettled overdue debt blocks ordinary clearance at that port")
	_expect(flight.service_action("berth_defer") and not flight.service_action("berth_defer")
		and flight.departure_status().can_request and flight.port_account_status().debt == first_debt,
		"A pilot short of funds can get this visit's permission without extinguishing the debt")
	var cleared := _from_disk(flight.snapshot())
	if not _expect(cleared != null and cleared.departure_status().can_request and Fixture.depart(cleared),
		"A permitted departure survives reload and leaves through the normal hangar sequence"):
		return
	_dock(cleared, CLEARING_PORT)
	cleared.credits = 1
	_expect(cleared.port_account_status().debt == 0 and cleared.port_account_status().other_debts[0].port == HANGAR
		and not cleared.service_action("berth_pay") and not cleared.service_action("berth_defer") and cleared.credits == 1,
		"A different port, even under the same authority, cannot settle or clear another port's bill")
	cleared.credits = 0
	_dock(cleared, HANGAR)
	var total := int(cleared.port_account_status().debt)
	cleared.credits = 4
	_expect(total > first_debt and not cleared.departure_status().can_request
		and cleared.service_action("berth_pay") and cleared.credits == 0 and cleared.port_account_status().debt == total - 4,
		"A second visit needs a new clearance; a partial payment reduces the local debt only")
	cleared.credits = total
	_expect(cleared.service_action("berth_pay") and cleared.credits == 4 and cleared.port_account_status().debt == 0
		and cleared.departure_status().can_request, "Full settlement removes the overdue hold and records the payment")


func _test_civic_access() -> void:
	var flight := _at_port(ROUTE_PORT, Civic.COST - 1)
	_expect(flight.courier_offer().id == ROUTE and not flight.courier_offer().allowed and not flight.accept_courier(ROUTE)
		and not flight.service_action("civic_donate") and flight.credits == Civic.COST - 1,
		"The named optional contract is visible and denied, and an unaffordable donation has no effect")
	var career := flight.career.snapshot()
	flight.credits += 1
	_expect(flight.service_action("civic_donate") and flight.credits == 0 and flight.civic_status().score == Civic.DONATION_REPUTATION
		and flight.career.snapshot() == career and flight.courier_offer().allowed,
		"A real donation debits credits, raises shared civilian standing and leaves military career untouched")
	var reopened := _from_disk(flight.snapshot())
	if not _expect(reopened != null and reopened.civic_status().receipt.port == ROUTE_PORT
		and reopened.accept_courier(ROUTE) and reopened.contract_stage == 1,
		"The receipt and standing survive reload and permit the real multi-stop cargo contract"):
		return
	var veteran := _at_port(ROUTE_PORT, 0)
	veteran.deliveries = Civic.CONTRACT_REQUIREMENTS[ROUTE]
	_expect(veteran.civic_status().score == veteran.deliveries and veteran.accept_courier(ROUTE),
		"Completed ordinary deliveries also count towards the same civic access")
	var malformed := reopened.snapshot()
	malformed.civic.receipt.at = reopened.orbit_time + 1.0
	_expect(not reopened.restore(malformed), "A future donation receipt cannot be restored")


func _test_port_touch() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var services := Services.new()
	viewport.add_child(services)
	var flight := _at_port(HANGAR, 0)
	_tick(flight, PortAccount.DAY)
	flight.credits = Civic.COST + 12
	services.service_requested.connect(func(action: String) -> void:
		flight.service_action(action)
		services.refresh())
	services.open(flight)
	await process_frame
	_tap(viewport, services._berth_toggle)
	await process_frame
	_expect(services._berth_rates.is_visible_in_tree() and "кр. за сутки" in services._berth_rates.text
		and "Выход закрыт" in services._berth_due.text, "The berth tab shows the daily rate and overdue status")
	_tap(viewport, services._berth_pay)
	await process_frame
	_expect(flight.port_account_status().debt == 0 and "Погашение счёта" in services._berth_receipt.text,
		"The touchscreen payment actually clears the local ledger and displays the receipt")
	_tap(viewport, services._civic_donate)
	await process_frame
	_expect(flight.civic_status().donated == Civic.COST and services._civic_receipt.is_visible_in_tree(),
		"The touchscreen donation records a visible receipt after the debit")
	viewport.queue_free()
	await process_frame


func _at_port(port: int, credits: int) -> Flight:
	var flight := Flight.new()
	flight.credits = credits
	_dock(flight, port)
	return flight


func _dock(flight: Flight, port: int) -> void:
	if flight.docked >= 0:
		Fixture.launch(flight)
	flight.system_id = Catalog.system_of_site(port)
	flight.target = port
	flight._dock()


func _from_disk(state: Dictionary) -> Flight:
	var path := "user://port-accounts-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var result := Flight.new()
	if Session.save_state(state, path) != OK or Session.load_valid_state(path, result.restore) != Session.LoadResult.PRIMARY:
		result = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return result


func _tick(flight: Flight, seconds: float) -> void:
	flight.update(seconds, Vector2.ZERO, 0.0, false, false)


func _tap(viewport: SubViewport, button: Button) -> void:
	if not _expect(button.is_visible_in_tree() and not button.disabled, "The visible port action is available by touch"):
		return
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 4
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		viewport.push_input(event, true)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		printerr(description)
		_failures += 1
	return condition
