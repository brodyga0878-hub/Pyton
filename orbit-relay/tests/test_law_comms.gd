extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Law := preload("res://scripts/law_network.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const VELAR_IN := 10
const VELAR_OUT := 11
const VELAR_AUTHORITY := 1

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_pursuit_and_arrest()
	_test_radio_negotiation()
	_test_contact_and_distress()
	print("Law and flight communications: %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_pursuit_and_arrest() -> void:
	var pilot := _wanted_pilot()
	if not _expect(pilot != null, "A real prohibited shipment builds a criminal record in the controlling faction"):
		return
	var before := pilot.law_status()
	_expect(before.counts.contraband == 1 and before.wanted == Law.ALERT and before.debt == 0
		and pilot.customs_status().debt == 415 and not before.detained and pilot.mining.ore_hold == 0,
		"The confiscation tracks a criminal offence without issuing the cargo fine a second time")
	if not _expect(pilot.select_target(VELAR_IN) and Fixture.depart(pilot), "Leave the port with the unresolved warrant"):
		return
	pilot.update(0.04, Vector2.ZERO, 0.0, false, false)
	var first := _patrol_contact(pilot)
	_expect(not first.is_empty() and pilot.law_status().phase == "challenge" and not pilot.time_status().allowed,
		"The local patrol is a real moving contact and opens a timed radio challenge")
	var cold := Flight.new()
	if not _expect(cold.restore(_json(pilot.snapshot())) and cold.law_status().phase == "challenge"
		and _patrol_contact(cold).position.is_equal_approx(first.position), "The active challenge and patrol position survive cold load"):
		return
	for _step in range(1250):
		if cold.law_status().phase == "interdicted":
			break
		cold.update(0.03, Vector2.ZERO, 0.0, false, false)
	var chased := _patrol_contact(cold)
	if not _expect(cold.law_status().phase == "interdicted" and cold.law_status().counts.evasion == 1
		and chased.position.distance_to(cold.position) <= Law.PATROL_RANGE + 1.0,
		"Ignoring the challenge adds one evasion offence and the moving patrol catches the ship"):
		return
	cold.velocity = Vector3.RIGHT * 120.0
	cold.update(0.03, Vector2.ZERO, 0.0, false, false)
	_expect(cold.velocity.length() <= 34.1 and "дозору" in str(cold.jump_status(Catalog.HOME_SYSTEM).reason),
		"Interdiction caps movement and prevents escaping through a normal jump")
	if not _expect(_fly(cold, VELAR_IN) and cold.law_status().detained and not cold.dock_action(),
		"Returning to an actual local berth arrests the ship and denies departure"):
		return
	var sentence := cold.law_status()
	var separate := Flight.new()
	if not _expect(separate.restore(_json(cold.snapshot())) and separate.law_status().detained
		and not separate.comms_action("release"), "A cold port arrest cannot be released prematurely"):
		return
	separate.update(float(sentence.release_at) - separate.orbit_time, Vector2.ZERO, 0.0, false, false)
	_expect(separate.comms_action("release") and not separate.law_status().detained and separate.law_status().wanted == 0
		and separate.customs_status().debt == 415 and separate.law_status().debt == 80 and separate.dock_action(),
		"Serving the sentence unlocks departure while preserving unpaid criminal and customs obligations")
	var stored := separate.snapshot()
	stored.law.records[VELAR_AUTHORITY].wanted = Law.MAX_WANTED + 1
	_expect(not Flight.new().restore(_json(stored)), "Impossible criminal scores are rejected during save restore")


func _test_radio_negotiation() -> void:
	var pilot := _wanted_pilot()
	if not _expect(pilot != null and Fixture.depart(pilot), "Start a second pursuit for remote negotiation"):
		return
	pilot.update(0.04, Vector2.ZERO, 0.0, false, false)
	pilot.credits = 1000
	_expect(not pilot.comms_action("pay", Law.PATROL_ID) and pilot.comms_action("answer", Law.PATROL_ID)
		and not pilot.comms_action("answer", Law.PATROL_ID) and pilot.law_status().phase == "negotiation",
		"A selected patrol permits one direct reply before it accepts remote payments")
	_expect(pilot.comms_action("contest", Law.PATROL_ID) and pilot.law_status().debt == 45
		and not pilot.comms_action("contest", Law.PATROL_ID) and pilot.credits == 1000,
		"An unsupported appeal is decided once and can increase the debt without crediting the wallet")
	_expect(pilot.comms_action("bribe", Law.PATROL_ID) and pilot.law_status().counts.bribery == 1
		and pilot.law_status().debt == 110 and pilot.credits == 880 and not pilot.comms_action("bribe", Law.PATROL_ID),
		"A rejected offer spends real credits, creates a new offence and cannot be repeated")
	var cold := Flight.new()
	if not _expect(cold.restore(_json(pilot.snapshot())) and not cold.comms_action("contest", Law.PATROL_ID)
		and not cold.comms_action("bribe", Law.PATROL_ID), "Remote answer and one-use decisions persist in an active negotiation"):
		return
	_expect(cold.comms_action("pay", Law.PATROL_ID) and cold.credits == 770 and cold.law_status().debt == 0
		and cold.comms_action("pay", Law.PATROL_ID) and cold.credits == 355 and cold.customs_status().debt == 0
		and not cold.comms_action("pay", Law.PATROL_ID) and cold.comms_action("release", Law.PATROL_ID)
		and _patrol_contact(cold).is_empty(), "Remote settlement pays each ledger once and withdraws the real pursuit")


func _test_contact_and_distress() -> void:
	var pilot := Flight.new()
	if not _expect(Fixture.depart(pilot), "Depart to test the regular traffic channel"):
		return
	var chosen := {}
	for contact: Dictionary in pilot.traffic_contacts():
		if contact.role == "trader" and not contact.get("hostile", false):
			chosen = contact
			break
	if not _expect(not chosen.is_empty(), "Locate an actual responsive ship in the local traffic"):
		return
	var relay := str(chosen.id)
	pilot.position = (chosen.position as Vector3) + Vector3.UP * 80.0
	pilot.velocity = Vector3.ZERO
	pilot.ship.fuel = 1.0
	_expect(not pilot.comms_action("report", "unknown") and pilot.comms_action("report", relay)
		and str(chosen.name) in str(pilot.comms_status(relay).receipt), "A radio response identifies the selected real ship")
	_expect(pilot.comms_action("route", relay) and Catalog.is_port(pilot.target)
		and Catalog.system_of_site(pilot.target) == pilot.system_id, "Requesting directions sets an actual local approach target")
	_expect(pilot.comms_action("distress") and pilot.ship.fuel == 6.0 and pilot.credits == 0 and pilot.mining.ore_hold == 0,
		"A nearby friendly ship provides only a small reserve of usable reaction fuel")
	pilot.ship.fuel = 2.0
	var cold := Flight.new()
	_expect(cold.restore(_json(pilot.snapshot())) and not pilot.comms_action("distress") and not cold.comms_action("distress")
		and cold.ship.fuel == 2.0, "Repeated calls and reloads cannot bypass the cooldown")
	var legacy := pilot.snapshot()
	legacy.schema = 50
	Fixture.remove_schema_51_from_legacy(legacy)
	var older := Flight.new()
	_expect(older.restore(_json(legacy)) and older.law_status().wanted == 0 and older.ship.fuel == 2.0,
		"Schema 50 starts a blank criminal and radio history without changing the ship's existing fuel")


func _wanted_pilot() -> Flight:
	var pilot := Flight.new()
	var state := pilot.snapshot()
	var at := pilot.target_contact(VELAR_IN)
	state.merge({"docked": VELAR_IN, "target": VELAR_IN, "system_id": Catalog.VELAR_SYSTEM,
		"position": [at.x, at.y, at.z]}, true)
	if not pilot.restore(state) or not pilot.mining.insert_cargo("weapon_parts", 7) or not _fly(pilot, VELAR_OUT):
		return null
	return pilot


func _fly(pilot: Flight, destination: int) -> bool:
	if not pilot.select_target(destination) or (pilot.docked >= 0 and not Fixture.depart(pilot)):
		return false
	pilot.set_autopilot(true)
	for _step in range(3600):
		if pilot.docked == destination:
			return true
		pilot.update(0.05, Vector2.ZERO, 0.0, false, false)
	return false


func _patrol_contact(pilot: Flight) -> Dictionary:
	for contact: Dictionary in pilot.traffic_contacts():
		if contact.id == Law.PATROL_ID:
			return contact
	return {}


func _json(state: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(state))


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
