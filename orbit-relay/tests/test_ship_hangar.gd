extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Shell := preload("res://scripts/ship_systems.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_purchase_and_sale()
	_test_hangar_capacity()
	_test_locality()
	print("Ship hangar ownership: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_purchase_and_sale() -> void:
	var flight := Flight.new()
	var poor := flight.shipyard_offer(Shell.FREIGHTER_HULL)
	_check(poor.purchase_cost == 2200 and not poor.purchase_ok and not flight.shipyard_action("purchase", Shell.FREIGHTER_HULL)
		and flight.shipyard_storage().is_empty(), "A full purchase quotes the complete price and prevents overdrafts")

	flight.credits = 10000
	flight.ship.hull = 74.5
	flight.ship.fuel = 42.0
	if not _check(flight.crew_hire(0) and flight.service_action("combat_ecm")
		and flight.mining.insert_cargo("ore", 2), "Equip and crew the ship through ordinary port services"):
		return
	var credits := flight.credits
	var gear := flight.combat.snapshot()
	var crew := flight.crew.snapshot()
	if not _check(flight.shipyard_action("purchase", Shell.FREIGHTER_HULL)
		and flight.credits == credits - 2200 and flight.ship.hull_id == Shell.FREIGHTER_HULL,
		"Full purchase activates the new hull and charges exactly its full price"):
		return
	_check(flight.ship.hull == 100.0 and flight.ship.fuel == 42.0 and flight.mining.ore_hold == 2
		and flight.ship.cargo_capacity() == 44 and flight.combat.snapshot() == gear and flight.crew.snapshot() == crew,
		"Shipborne fittings, crew, fuel and payload transfer once without either loss or duplication")
	var stored := flight.shipyard_storage()
	if not _check(stored.size() == 1 and stored[0].hull == Shell.STARTER_HULL and stored[0].port == 0
		and is_equal_approx(float(stored[0].condition), 74.5) and stored[0].sell_price == 506,
		"The vacated hull stays at the yard with its initial wear and depreciated value"):
		return
	var old_id: String = stored[0].id
	_check(not flight.shipyard_action("purchase", Shell.FREIGHTER_HULL)
		and not flight.shipyard_action("sell", Shell.FREIGHTER_HULL) and flight.shipyard_storage().size() == 1,
		"Neither a duplicate purchase nor a sale of the active hull is allowed")

	var saved := flight.snapshot()
	var cold := Flight.new()
	if not _check(SessionIO.save_state(saved, "user://yard-purchases.json") == OK
		and cold.restore(SessionIO.load_state("user://yard-purchases.json"))
		and cold.shipyard_storage() == stored, "The berth, hull condition and receipt identifier survive a cold restart"):
		return
	var invalid := cold.snapshot()
	invalid.ship_hangar.rows[0].port = 1
	var valid := cold.snapshot()
	_check(not cold.restore(invalid) and cold.snapshot() == valid, "An invalid storage berth is rejected transactionally")
	var duplicate := valid.duplicate(true)
	duplicate.ship_hangar.rows.append(duplicate.ship_hangar.rows[0].duplicate())
	_check(not cold.restore(duplicate) and cold.snapshot() == valid, "Duplicate hangar receipts are rejected")
	var older := valid.duplicate(true)
	older.schema = 51
	older.erase("ship_hangar")
	var migrated := Flight.new()
	_check(migrated.restore(older) and migrated.shipyard_storage().is_empty()
		and migrated.ship.hull_id == cold.ship.hull_id and migrated.crew.snapshot() == cold.crew.snapshot(),
		"Schema 51 loads with an empty owned hangar without any change to active ship or roster")

	_check(cold.mining.insert_cargo("ore", 25)
		and not cold.shipyard_action("switch", old_id) and cold.shipyard_storage()[0].can_sell,
		"The smaller parked ship cannot be activated while the transferred hold would overflow")
	_check(cold.mining.remove_cargo("ore", 25) and cold.shipyard_action("switch", old_id)
		and cold.ship.hull_id == Shell.STARTER_HULL and is_equal_approx(cold.ship.hull, 74.5)
		and not cold.shipyard_action("switch", old_id),
		"Switching uses the parked integrity, keeps the old active hull, and invalidates stale input")
	var new_id: String = cold.shipyard_storage()[0].id
	credits = cold.credits
	var net := int(cold.shipyard_storage()[0].sell_price)
	_check(cold.shipyard_action("sell", new_id) and cold.credits == credits + net
		and cold.shipyard_storage().is_empty() and not cold.shipyard_action("sell", new_id)
		and cold.ship.hull_id == Shell.STARTER_HULL, "A local stored hull sale pays once and leaves a pilot with an operational ship")


func _test_hangar_capacity() -> void:
	var flight := Flight.new()
	flight.credits = 100000
	for _slot in range(flight.shipyard_storage_limit()):
		var id := Shell.FREIGHTER_HULL if flight.ship.hull_id == Shell.STARTER_HULL else Shell.STARTER_HULL
		_check(flight.shipyard_action("purchase", id), "Fill a real hangar slot with a distinct owned hull")
	var current := flight.ship.hull_id
	var id := Shell.FREIGHTER_HULL if current == Shell.STARTER_HULL else Shell.STARTER_HULL
	var saved := flight.snapshot()
	var quote := flight.shipyard_offer(id)
	_check(not quote.purchase_ok and quote.available and not flight.shipyard_action("purchase", id)
		and flight.snapshot() == saved, "Full hangars prevent a full-priced purchase and leave trade-in available")
	var receipt: String = flight.shipyard_storage()[0].id
	_check(flight.shipyard_action("switch", receipt) and flight.shipyard_storage().size() == 5,
		"An existing slot can be exchanged in a full hangar")
	flight.credits = 1000000000
	receipt = flight.shipyard_storage()[0].id
	_check(not flight.shipyard_action("sell", receipt) and flight.credits == 1000000000 and flight.shipyard_storage().size() == 5,
		"Selling does not produce a balance outside the save limits")


func _test_locality() -> void:
	var flight := Flight.new()
	flight.credits = 12000
	if not _check(flight.crew_hire(0) and flight.shipyard_action("purchase", Shell.FREIGHTER_HULL),
		"Hire the specialist and buy a freighter at the home port"):
		return
	var id: String = flight.shipyard_storage()[0].id
	if not _check(Fixture.depart(flight) and _jump_to_yard(flight) and flight.shipyard_available(),
		"Travel in the purchased freighter from the home yard to the Velar yard"):
		return
	var row: Dictionary = flight.shipyard_storage()[0]
	var preserved := flight.snapshot()
	_check(row.port == 0 and not row.can_sell and not row.can_switch
		and not flight.shipyard_action("sell", id) and not flight.shipyard_action("switch", id)
		and flight.snapshot() == preserved,
		"A licensed remote yard reports the parked hull's location and cannot sell or activate it")


func _jump_to_yard(flight: Flight) -> bool:
	var sector := Catalog.VELAR_SYSTEM
	flight.position = Vector3(-1200.0, 1800.0, 2400.0)
	flight.velocity = Vector3.ZERO
	if not flight.plan_jump(sector) or not flight.start_jump():
		return false
	for _step in range(5 * 60):
		if flight.system_id == sector:
			break
		flight.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
	if flight.system_id != sector or not flight.select_target(10):
		return false
	flight.set_autopilot(true)
	for _step in range(90 * 60):
		if flight.docked == 10:
			return true
		if not flight.autopilot:
			return false
		flight.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
	return false


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
	return condition
