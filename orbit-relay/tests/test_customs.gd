extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Expedition := preload("res://scripts/expedition.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const HOME := Catalog.HOME_SYSTEM
const VELAR := Catalog.VELAR_SYSTEM
const HEATHER := Catalog.HEATHER_SYSTEM
const COLONY := Catalog.HEATHER_PORT
const LEAGUE := 1
const HOME_PORT := 0
const OTHER_HOME_PORT := 1
const VELAR_PORT := 10
const OTHER_VELAR_PORT := 11
const MEDICINE := "medical"
const STEP := Fixture.STEP
const SAVE_PATH := "user://customs-test.json"

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_jurisdiction_trip()
	_test_change_of_authority()
	_test_previous_schema()
	print("Customs integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_jurisdiction_trip() -> void:
	var flight := Flight.new()
	var personal := flight.customs_status()
	_expect(personal.authority == 0 and personal.medical_allowance == -1 and personal.total_debt == 0
		and personal.violations == 0 and personal.notice.is_empty(), "Home begins under the Commonwealth's unrestricted medical import rule")
	flight.credits = int(flight.market_quote(MEDICINE, "buy", 8).cost) + int(flight.market_quote("ore", "buy", 2).cost) + 90
	if not _expect(flight.market_trade(MEDICINE, "buy", 8) and flight.market_trade("ore", "buy", 2) and flight.credits == 90,
		"Load eight units of medicine and unrelated ore through the real Home market"):
		return
	if not _expect(Fixture.depart(flight) and _dock_at(flight, OTHER_HOME_PORT)
		and flight.mining.cargo_amount(MEDICINE) == 8 and flight.mining.cargo_amount("ore") == 2
		and flight.customs_status().violations == 0 and flight.credits == 90,
		"A physical Commonwealth arrival leaves the cargo and wallet untouched"):
		return
	if not _expect(_jump_from_port(flight, VELAR), "Cross the real interstellar corridor into Velar"):
		return
	var entry := flight.customs_status()
	_expect(flight.docked == -1 and entry.authority == LEAGUE and entry.medical_allowance == 4
		and entry.medical_aboard == 8 and entry.debt == 0 and not entry.can_pay and not flight.customs_pay(),
		"The League's rule is visible in flight, but a jump alone does not inspect cargo")
	if not _expect(_dock_at(flight, VELAR_PORT), "Complete a real docking at the League station"):
		return
	var fined := flight.customs_status()
	var notice: Dictionary = fined.notice
	var fine := 100 + 45 * 4
	_expect(fined.authority == LEAGUE and fined.authority_name == flight.system_faction_name(VELAR)
		and fined.medical_aboard == 4 and flight.mining.cargo_amount("ore") == 2 and flight.credits == 90,
		"Customs leaves the permitted four units, preserves unrelated cargo and does not automatically debit credits")
	_expect(fined.violations == 1 and fined.debt == fine and fined.total_debt == fine
		and notice.get("authority") == LEAGUE and notice.get("port") == VELAR_PORT
		and notice.get("good") == MEDICINE and notice.get("quantity") == 4 and notice.get("fine") == fine
		and fined.debts.size() == 1 and fined.debts[0].authority == LEAGUE and fined.debts[0].amount == fine,
		"Exactly the excess generates a dated, faction-specific fine and notice")
	_expect(flight.market_limit(MEDICINE, "buy") == 0 and not flight.market_trade(MEDICINE, "buy", 1)
		and flight.market_quote(MEDICINE, "sell", 1).ok and flight.credits == 90,
		"An already full League allowance prevents buying more while leaving sale available")
	if not _expect(fined.can_pay and flight.customs_pay() and flight.credits == 0 and flight.customs_status().debt == fine - 90
		and not flight.customs_pay(), "Payment applies only available credits and keeps the unpaid League balance"):
		return
	var checkpoint := flight.snapshot()
	if not _expect(SessionIO.save_state(checkpoint, SAVE_PATH) == OK, "Persist the real inspection and partial payment"):
		return
	var cold := Flight.new()
	if not _expect(cold.restore(SessionIO.load_state(SAVE_PATH)) and cold.docked == VELAR_PORT
		and cold.credits == 0 and cold.mining.cargo_amount(MEDICINE) == 4,
		"Cold restart keeps cargo that survived the customs inspection"):
		return
	var remaining := fine - 90
	var history := cold.customs_status()
	_expect(history.debt == remaining and history.violations == 1 and history.notice.get("fine") == fine
		and absf(float(history.notice.epoch) - float(notice.epoch)) < 0.000000001,
		"Cold restart keeps the ledger, count and original notice timestamp")
	_test_invalid_ledger(checkpoint)
	if not _expect(_jump_from_port(cold, HOME) and _dock_at(cold, HOME_PORT), "Return to the Commonwealth while owing the League"):
		return
	cold.credits = remaining + 65
	var other := cold.customs_status()
	_expect(other.authority == 0 and other.debt == 0 and other.total_debt == remaining and not other.can_pay
		and not cold.customs_pay() and cold.credits == remaining + 65,
		"Another authority cannot settle the League's fine even with enough credits in the wallet")
	if not _expect(_jump_from_port(cold, VELAR) and _dock_at(cold, OTHER_VELAR_PORT),
		"Arrive at the second port of the same League authority"):
		return
	var before_closing := cold.customs_status()
	_expect(before_closing.violations == 1 and before_closing.debt == remaining and before_closing.medical_aboard == 4
		and before_closing.notice.get("port") == VELAR_PORT,
		"A later inspection leaves the already permitted cargo and first notice unchanged")
	_expect(before_closing.can_pay and cold.customs_pay() and cold.credits == 65 and cold.customs_status().total_debt == 0
		and cold.customs_status().debts.is_empty() and not cold.customs_pay() and cold.customs_status().violations == 1,
		"Any port of the creditor can close the balance, and a repeated payment cannot debit it again")


func _test_change_of_authority() -> void:
	var flight := Flight.new()
	var before := flight.customs_status(HEATHER)
	_expect(before.authority == -1 and not before.available and not before.can_pay
		and not flight.station_operational(COLONY),
		"The uncommissioned frontier port has no local customs authority")
	if not _expect(_stage_commissioning(flight), "Prepare a legal final frontier delivery with a medical cargo"):
		return
	_expect(flight.customs_status().authority == -1 and not flight.customs_status().available
		and not flight.customs_pay() and flight.mining.cargo_amount(MEDICINE) == 7,
		"A revealed but unfinished station still does not run customs")
	if not _expect(flight.project_action() and flight.station_operational(COLONY) and _dock_at(flight, COLONY)
		and flight.factions.owner(HEATHER) == 0 and flight.customs_status().medical_aboard == 7,
		"Foundation establishes the unrestricted Commonwealth customs office (%s)" % flight.status_message):
		return
	for _step in range(360):
		if flight.factions.owner(HEATHER) == LEAGUE:
			break
		flight.update(30.0, Vector2.ZERO, 0.0, false, false)
	var transfer := flight.customs_status()
	if not _expect(flight.factions.owner(HEATHER) == LEAGUE and flight.station_operational(COLONY)
		and transfer.authority == LEAGUE and transfer.medical_allowance == 4 and transfer.medical_aboard == 7
		and transfer.violations == 0, "A real faction takeover changes the rule but leaves currently berthed goods alone"):
		return
	var balance := flight.credits
	if not _expect(Fixture.depart(flight) and _dock_at(flight, COLONY),
		"Leave and dock again through the same operational station after the takeover"):
		return
	var imposed := flight.customs_status()
	_expect(imposed.authority == LEAGUE and imposed.violations == 1 and imposed.medical_aboard == 4
		and imposed.debt == 100 + 45 * 3 and imposed.notice.get("port") == COLONY and flight.credits == balance,
		"The next physical inspection uses the live authority and records its own new debt")


func _test_previous_schema() -> void:
	var old := Flight.new().snapshot()
	old.schema = 30
	old.ship.erase("mining_laser")
	old.ship.erase("fragment_collector")
	old.ship.erase("hydrogen_scoop")
	old.ship.erase("fuel_pump")
	old.ship.erase("pump_mode")
	old.erase("customs")
	old.mining.cargo.medical = 7
	var migrated := Flight.new()
	_expect(migrated.restore(old) and migrated.docked == HOME_PORT and migrated.customs_status().medical_aboard == 7
		and migrated.customs_status().violations == 0 and migrated.customs_status().total_debt == 0,
		"Schema 30 begins with an empty customs history and retains its original legal cargo")


func _test_invalid_ledger(checkpoint: Dictionary) -> void:
	var bad := checkpoint.duplicate(true)
	bad.customs.debts[LEAGUE] = -1
	_expect(not Flight.new().restore(bad), "A negative customs balance cannot enter the save")
	bad = checkpoint.duplicate(true)
	bad.customs.notice.port = Catalog.STAR_ID
	_expect(not Flight.new().restore(bad), "A customs notice must have been issued by an actual port")


func _stage_commissioning(flight: Flight) -> bool:
	var state := flight.snapshot()
	state.expedition.projects[0] = {
		"phase": Expedition.BUILD, "sponsor_port": HOME_PORT, "sponsor": 0,
		"scan_index": Expedition.SURVEY_TOTAL, "build_index": Expedition.BUILD_TOTAL - 1,
	}
	var point := flight.target_gate(COLONY) + Vector3.BACK * Expedition.BUILD_APPROACH_OFFSET
	var drift := flight.target_velocity(COLONY)
	state.merge({"system_id": HEATHER, "docked": -1, "target": Catalog.HEATHER_PLANET,
		"position": [point.x, point.y, point.z], "velocity": [drift.x, drift.y, drift.z]}, true)
	state.mining.cargo.medical = 7
	state.mining.cargo.ore = 4
	state.mining.cargo.crystal = 3
	return flight.restore(state) and flight.frontier_status().can_act


func _dock_at(flight: Flight, port: int) -> bool:
	if not flight.select_target(port):
		return false
	flight.set_autopilot(true)
	return _advance(flight, func() -> bool: return flight.docked == port, 140.0)


func _jump_from_port(flight: Flight, destination: int) -> bool:
	if not flight.plan_jump(destination) or not Fixture.depart(flight):
		return false
	flight.change_throttle(0.18)
	return _advance(flight, func() -> bool: return flight.jump_status(destination).ok, 25.0) \
		and flight.start_jump() and _advance(flight, func() -> bool: return flight.system_id == destination, 4.0)


func _advance(flight: Flight, reached: Callable, seconds: float) -> bool:
	for _frame in range(ceili(seconds / STEP)):
		if reached.call():
			return true
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	return reached.call()


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
