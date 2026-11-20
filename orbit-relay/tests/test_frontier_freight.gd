extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Economy := preload("res://scripts/port_economy.gd")
const Expedition := preload("res://scripts/expedition.gd")
const NpcFreight := preload("res://scripts/npc_freight.gd")
const HOME := Catalog.HOME_SYSTEM
const FRINGE := Catalog.FRINGE_SYSTEM
const HEATHER := Catalog.HEATHER_SYSTEM
const LIMIT := Catalog.LIMIT_SYSTEM
const SVOD := Catalog.FRINGE_SECOND_PORT
const HEATHER_PORT := Catalog.HEATHER_PORT
const LIMIT_PORT := Catalog.LIMIT_PORT
const HEATHER_SHIP := "freighter-frontier-3"
const LIMIT_SHIP := "freighter-frontier-4"
const FIRST_LOAD := 28.0
const FIRST_UNLOAD := 78.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var flight := _test_commission_heather()
	if flight != null:
		_test_partial_unload(flight)
		flight = _test_first_service(flight)
	if flight != null and _test_limit_service(flight):
		_test_legacy_migration(flight)
		_test_change_of_control(flight)
	print("Frontier freight integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_commission_heather() -> Flight:
	var flight := Flight.new()
	var source := flight.market.stock(SVOD, "medical")
	var destination := flight.market.stock(HEATHER_PORT, "medical")
	_tick(flight, 310.0)
	_expect(not flight.freight.frontier_active(HEATHER) and not flight.freight.frontier_active(LIMIT)
		and flight.freight_status(HEATHER_PORT).is_empty() and _route(flight, HEATHER_SHIP, SVOD).is_empty()
		and flight.market.stock(SVOD, "medical") == source and flight.market.stock(HEATHER_PORT, "medical") == destination,
		"No frontier ship launches or moves goods while its target colony is unbuilt")
	if not _expect(_stage_final_lot(flight, HEATHER) and flight.system_known(HEATHER)
		and not flight.station_operational(HEATHER_PORT) and not flight.freight.frontier_active(HEATHER)
		and flight.freight_status(HEATHER_PORT).is_empty(),
		"Discovery and the first station construction lot do not enable commerce"):
		return null
	var dormant := flight.snapshot()
	var invalid := dormant.duplicate(true)
	invalid.freight.frontier_epochs[0] = flight.orbit_time
	_expect(not flight.restore(invalid) and flight.snapshot() == dormant,
		"A current-schema save cannot enable a freight route before commissioning the linked station")
	var commissioning := flight.orbit_time
	if not _expect(flight.project_action() and flight.status_event == "expedition_complete"
		and flight.station_operational(HEATHER_PORT) and flight.freight.frontier_active(HEATHER)
		and not flight.freight.frontier_active(LIMIT) and flight.freight.snapshot().frontier_epochs[0] == commissioning,
		"The normal final delivery commissions the station and starts only its own route at the current epoch"):
		return null
	var service := _route(flight, HEATHER_SHIP, SVOD)
	if not _expect(not service.is_empty() and service.interstellar and service.origin == SVOD and service.destination == HEATHER_PORT
		and service.good == "medical" and service.amount == 0 and service.visual_phase == "waiting"
		and is_equal_approx(service.departure_eta, FIRST_LOAD) and is_equal_approx(service.arrival_eta, FIRST_UNLOAD),
		"The new service starts at Свод with a fresh departure and arrival estimate"):
		return null
	_expect(not _route(flight, HEATHER_SHIP, HEATHER_PORT).is_empty() and flight.freight_status(LIMIT_PORT).is_empty(),
		"Both real endpoints list the first service while Предел remains unserved")
	return flight


func _test_first_service(flight: Flight) -> Flight:
	var source := flight.market.stock(SVOD, "medical")
	var receiver := flight.market.stock(HEATHER_PORT, "medical")
	var inventory := _total_goods(flight)
	_tick(flight, FIRST_LOAD + 0.25)
	var departure := _route(flight, HEATHER_SHIP, SVOD)
	var outbound := _contact_at(flight, FRINGE, HEATHER_SHIP)
	if not _expect(departure.visual_phase == "departure" and departure.local_port == SVOD
		and departure.amount == NpcFreight.CAPACITY and departure.in_transit
		and flight.market.stock(SVOD, "medical") == source - departure.amount
		and flight.market.stock(HEATHER_PORT, "medical") == receiver and _total_goods(flight) == inventory,
		"The interstellar trader removes real medicine from its origin and carries it before unloading"):
		return null
	_expect(not outbound.is_empty() and outbound.role == "trader" and outbound.freight.visual_phase == "departure"
		and outbound.position.is_finite() and outbound.velocity.is_finite() and _contact_at(flight, HEATHER, HEATHER_SHIP).is_empty(),
		"The physical ship departing Свод is visible only in its current system")
	_tick(flight, 7.0)
	var moving := _contact_at(flight, FRINGE, HEATHER_SHIP)
	_expect(not outbound.is_empty() and not moving.is_empty() and moving.position.distance_to(outbound.position) > 50.0,
		"The departure contact actually moves away from the berth along its local phase")
	_tick(flight, 7.0)
	var between := _route(flight, HEATHER_SHIP, HEATHER_PORT)
	if not _expect(between.visual_phase == "hyperspace" and between.amount == departure.amount
		and _contact_at(flight, FRINGE, HEATHER_SHIP).is_empty() and _contact_at(flight, HEATHER, HEATHER_SHIP).is_empty()
		and _total_goods(flight) == inventory,
		"The market still tracks conserved cargo in hyperspace while both local spaces omit the contact"):
		return null
	var cold := Flight.new()
	var saved := _json(flight.snapshot())
	if not _expect(saved.schema == Flight.SAVE_SCHEMA and cold.restore(saved) and cold.freight.snapshot() == flight.freight.snapshot()
		and cold.market.snapshot() == flight.market.snapshot()
		and _route(cold, HEATHER_SHIP, HEATHER_PORT) == between,
		"Cold restart in hyperspace keeps the cargo, both markets, ETA and visual phase"):
		return null
	_tick(flight, 26.0)
	_tick(cold, 26.0)
	var arriving := _contact_at(cold, HEATHER, HEATHER_SHIP)
	var arrival := _route(cold, HEATHER_SHIP, HEATHER_PORT)
	_expect(arrival.visual_phase == "arrival" and arrival.local_port == HEATHER_PORT and arrival.amount == departure.amount
		and not arriving.is_empty() and arriving.freight.visual_phase == "arrival"
		and _contact_at(cold, FRINGE, HEATHER_SHIP).is_empty() and _total_goods(cold) == inventory,
		"After the jump the same physical contact appears only near its destination with undelivered cargo")
	_tick(flight, 10.0)
	_tick(cold, 10.0)
	var unloaded := _route(cold, HEATHER_SHIP, HEATHER_PORT)
	_expect(cold.market.stock(HEATHER_PORT, "medical") == receiver + departure.amount
		and unloaded.last_port == HEATHER_PORT and unloaded.last_good == "medical" and unloaded.last_delivered == departure.amount
		and unloaded.amount == 0 and _total_goods(cold) == inventory,
		"Arrival moves the shipment into the remote warehouse exactly once")
	_expect(cold.market.snapshot() == flight.market.snapshot() and cold.freight.snapshot() == flight.freight.snapshot(),
		"The saved and uninterrupted fleet reach the same stock and schedule after delivery")
	return cold


func _test_partial_unload(flight: Flight) -> void:
	var world := _local_view(flight, HOME)
	if not _expect(world != null, "Prepare the newly commissioned service while docked elsewhere"):
		return
	var origin := world.market.stock(SVOD, "medical")
	_tick(world, FIRST_LOAD + 0.25)
	var loaded: int = _route(world, HEATHER_SHIP, HEATHER_PORT).amount
	world.market.change_stock(HEATHER_PORT, "medical", Economy.MAX_STOCK - 3 - world.market.stock(HEATHER_PORT, "medical"))
	var conserved := _total_goods(world)
	_tick(world, FIRST_UNLOAD - FIRST_LOAD)
	var remaining := _route(world, HEATHER_SHIP, HEATHER_PORT)
	_expect(loaded == NpcFreight.CAPACITY and world.market.stock(HEATHER_PORT, "medical") == Economy.MAX_STOCK
		and remaining.last_delivered == 3 and remaining.amount == loaded - 3 and _total_goods(world) == conserved,
		"A frontier warehouse that fills in mid-flight takes only the three units it can store")
	_tick(world, 16.0)
	var inbound := _route(world, HEATHER_SHIP, SVOD)
	_expect(inbound.origin == HEATHER_PORT and inbound.good == "medical" and inbound.amount == loaded - 3,
		"The reverse crossing keeps the undelivered medicine aboard instead of loading a new commodity")
	_tick(world, 50.0)
	var returned := _route(world, HEATHER_SHIP, SVOD)
	_expect(returned.last_delivered == loaded - 3 and world.market.stock(SVOD, "medical") == origin - 3
		and returned.amount == 0 and _total_goods(world) == conserved,
		"The surplus returns to the original warehouse with no loss or duplicate transfer")


func _test_limit_service(flight: Flight) -> bool:
	var first_epoch: float = flight.freight.snapshot().frontier_epochs[0]
	if not _expect(_stage_final_lot(flight, LIMIT) and flight.freight.frontier_active(HEATHER)
		and not flight.freight.frontier_active(LIMIT) and _route(flight, LIMIT_SHIP, HEATHER_PORT).is_empty(),
		"The second service is dormant while the first remains available throughout construction"):
		return false
	var opening := flight.orbit_time
	if not _expect(flight.project_action() and flight.status_event == "expedition_complete"
		and flight.station_operational(LIMIT_PORT) and flight.freight.frontier_active(LIMIT)
		and flight.freight.snapshot().frontier_epochs == [first_epoch, opening],
		"Completing Предел adds its trade route without reseeding the existing schedule"):
		return false
	var launch := _route(flight, LIMIT_SHIP, LIMIT_PORT)
	_expect(launch.origin == HEATHER_PORT and launch.destination == LIMIT_PORT and launch.good == "circuits"
		and flight.freight_status(HEATHER_PORT).size() == 2 and flight.freight_status(LIMIT_PORT).size() == 1,
		"Вереск becomes the exchange point for two distinct scheduled routes")
	var source := flight.market.stock(HEATHER_PORT, "circuits")
	var destination := flight.market.stock(LIMIT_PORT, "circuits")
	var total := _total_goods(flight)
	_tick(flight, FIRST_LOAD + 0.25)
	var cargo := _route(flight, LIMIT_SHIP, LIMIT_PORT)
	_expect(cargo.amount == NpcFreight.CAPACITY and cargo.good == "circuits"
		and flight.market.stock(HEATHER_PORT, "circuits") == source - cargo.amount,
		"The second service loads circuits out of the commissioned intermediate warehouse")
	_tick(flight, FIRST_UNLOAD - FIRST_LOAD)
	var reception := _route(flight, LIMIT_SHIP, LIMIT_PORT)
	_expect(reception.last_good == "circuits" and reception.last_delivered == cargo.amount
		and flight.market.stock(LIMIT_PORT, "circuits") == destination + cargo.amount,
		"Предел receives the actual inbound goods after its own travel time")
	var crystals := flight.market.stock(HEATHER_PORT, "crystal")
	_tick(flight, 66.0)
	var returning := _route(flight, LIMIT_SHIP, HEATHER_PORT)
	_expect(returning.last_port == HEATHER_PORT and returning.last_good == "crystal" and returning.last_delivered == NpcFreight.CAPACITY
		and flight.market.stock(HEATHER_PORT, "crystal") == crystals + returning.last_delivered
		and _total_goods(flight) == total,
		"The reverse leg returns crystals, preserving totals through both directions and the existing service")
	return true


func _test_legacy_migration(flight: Flight) -> void:
	for version in [16, 17]:
		var legacy := _json(flight.snapshot())
		legacy.schema = version
		legacy.ship.erase("jump_fuel")
		legacy.mining.cargo.erase("hydrogen")
		legacy.mining.reserves.resize(Catalog.PRE_GAS_DESTINATION_COUNT)
		for stocks: Dictionary in legacy.market.values():
			stocks.erase("hydrogen")
		legacy.freight.ships = legacy.freight.ships.slice(0, 6)
		legacy.freight.erase("frontier_epochs")
		if version < 17:
			legacy.erase("jump_route")
		legacy.market[str(SVOD)].medical = 25.0
		legacy.market[str(HEATHER_PORT)].medical = 10.0
		var resumed := Flight.new()
		if not _expect(resumed.restore(legacy) and resumed.freight.frontier_active(HEATHER) and resumed.freight.frontier_active(LIMIT)
			and _market_without_hydrogen(resumed) == legacy.market and resumed.freight.snapshot().frontier_epochs == [flight.orbit_time, flight.orbit_time]
			and is_equal_approx(_route(resumed, HEATHER_SHIP, SVOD).departure_eta, FIRST_LOAD),
			"Schema %d upgrades its old six ships and adds both new services at the save epoch without transfers" % version):
			continue
		_tick(resumed, FIRST_LOAD - 0.25)
		_expect(resumed.market.stock(HEATHER_PORT, "medical") == 10 and resumed.market.stock(SVOD, "medical") == 25,
			"A legacy load leaves frontier stock untouched until the first new departure")
		_tick(resumed, 0.5)
		_expect(resumed.market.stock(SVOD, "medical") == 25 - NpcFreight.CAPACITY
			and resumed.market.stock(HEATHER_PORT, "medical") == 10,
			"The newly scheduled ship loads stock only after the proper launch delay")


func _test_change_of_control(flight: Flight) -> void:
	var after_war := _local_view(flight, HOME)
	if not _expect(after_war != null, "Load the commissioned trade ledger while the player is in another sector"):
		return
	var old_owner := after_war.factions.owner(HEATHER)
	var timetable: Array = after_war.freight.snapshot().frontier_epochs
	for _step in range(360):
		if after_war.factions.owner(HEATHER) != old_owner:
			break
		_tick(after_war, 30.0)
	if not _expect(after_war.factions.owner(HEATHER) != old_owner and after_war.freight.frontier_active(HEATHER)
		and after_war.station_operational(HEATHER_PORT) and after_war.freight.snapshot().frontier_epochs == timetable,
		"An autonomous faction takeover leaves the established freight timetable active and unchanged"):
		return
	for port in [SVOD, HEATHER_PORT]:
		for good in ["medical", "ice"]:
			after_war.market.change_stock(port, good, 25 - after_war.market.stock(port, good))
	var state_before := _ship_step(after_war, HEATHER_SHIP)
	var totals := _total_goods(after_war)
	_tick(after_war, 110.0)
	var later := _route(after_war, HEATHER_SHIP, SVOD)
	_expect(_ship_step(after_war, HEATHER_SHIP) >= state_before + 2 and later.last_delivered > 0
		and _total_goods(after_war) == totals and after_war.freight.snapshot().frontier_epochs == timetable,
		"Real deliveries and conservation continue after a change of local faction control")


func _stage_final_lot(flight: Flight, system: int) -> bool:
	var first := system == HEATHER
	var saved := flight.snapshot()
	var project := 0 if first else 1
	saved.expedition.projects[project] = {"phase": Expedition.BUILD, "sponsor_port": 0, "sponsor": 0,
		"scan_index": Expedition.SURVEY_TOTAL, "build_index": Expedition.BUILD_TOTAL - 1}
	var port := HEATHER_PORT if first else LIMIT_PORT
	var position := flight.target_gate(port) + Vector3.BACK * Expedition.BUILD_APPROACH_OFFSET
	var motion := flight.target_velocity(port)
	saved.merge({"system_id": system, "docked": -1, "target": Catalog.system(system).survey_sites[0],
		"position": _vector(position), "velocity": _vector(motion), "jump_target": -1, "jump_route": [],
		"planned_target": -1}, true)
	var cargo: Dictionary = saved.mining.cargo
	cargo.crystal = 3 if first else 4
	cargo.ore = 4 if first else 0
	cargo.circuits = 0 if first else 3
	return flight.restore(saved) and flight.frontier_status().can_act


func _local_view(flight: Flight, system: int) -> Flight:
	var other := Flight.new()
	var saved := flight.snapshot()
	var port: int = Catalog.system(system).arrival_port
	saved.merge({"system_id": system, "docked": port, "target": port,
		"position": _vector(flight.docking_position(port)), "velocity": [0.0, 0.0, 0.0],
		"jump_target": -1, "jump_route": [], "planned_target": -1}, true)
	return other if other.restore(saved) else null


func _contact_at(flight: Flight, system: int, id: String) -> Dictionary:
	var local := flight if flight.system_id == system else _local_view(flight, system)
	if local != null:
		for contact: Dictionary in local.traffic_contacts():
			if contact.id == id:
				return contact
	return {}


func _route(flight: Flight, id: String, port: int) -> Dictionary:
	for service: Dictionary in flight.freight_status(port):
		if service.id == id:
			return service
	return {}


func _ship_step(flight: Flight, id: String) -> int:
	for record: Dictionary in flight.freight.snapshot().ships:
		if record.id == id:
			return record.step
	return -1


func _total_goods(flight: Flight) -> Dictionary:
	var totals := {}
	for good: String in Economy.GOODS:
		totals[good] = 0
	for inventory: Dictionary in flight.market.snapshot().values():
		for good: String in inventory:
			totals[good] += inventory[good]
	for record: Dictionary in flight.freight.snapshot().ships:
		if record.amount > 0:
			totals[record.good] += record.amount
	return totals


func _tick(flight: Flight, delta: float) -> void:
	flight.update(delta, Vector2.ZERO, 0.0, false, false)


func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _json(value: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value, "", true, true)) as Dictionary


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
