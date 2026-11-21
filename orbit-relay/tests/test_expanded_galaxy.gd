extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Orbit := preload("res://scripts/orbit_ephemeris.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Session := preload("res://scripts/session_io.gd")
const Rig := preload("res://scripts/mining_rig.gd")
const HOME := Catalog.HOME_SYSTEM
const STEP := Fixture.STEP

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog()
	_test_schema_45()
	_test_round_trip()
	for failure: String in _failures:
		printerr(failure)
	print("Expanded galaxy integration: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _test_catalog() -> void:
	_expect(Catalog.PRE_EXPANDED_SYSTEM_COUNT == 24 and Catalog.PRE_ATLAS_SYSTEM_COUNT == 96
		and Catalog.PRE_EXPANDED_DESTINATION_COUNT == 89 and Catalog.PRE_ATLAS_DESTINATION_COUNT == 305,
		"The previous expansion still occupies its original system and target IDs")
	_expect(Catalog.SYSTEM_COUNT == 512 and Catalog.PRE_RICH_SYSTEMS_DESTINATION_COUNT == 1553
		and Catalog.DESTINATION_COUNT == 1585,
		"The atlas preserves its 1553 base sites and appends 32 new moons and gas giants")
	var names := {}
	var targets := {}
	var sectors := {}
	for system in range(Catalog.SYSTEM_COUNT):
		var known: Array[int] = []
		for candidate in range(Catalog.AUTHORED_SYSTEM_COUNT, Catalog.SYSTEM_COUNT):
			if candidate != system and Catalog.jump_distance(system, candidate) <= Catalog.GENERATED_SCAN_RANGE:
				known.append(candidate)
		_expect(Catalog.generated_systems_near(system, Catalog.GENERATED_SCAN_RANGE) == known,
			"Indexed 3D radio lookup matches an exhaustive scan for system %d" % system)
		var row := Catalog.system(system)
		_expect(not names.has(row.name) and not Catalog.targets_for(system).is_empty(),
			"Every system has a distinct name and local objects")
		names[row.name] = true
		for target: int in Catalog.targets_for(system):
			_expect(not targets.has(target) and Catalog.system_of_site(target) == system and not Catalog.site(target).is_empty(),
				"Every local target has one stable owner and valid data")
			targets[target] = true
		if system >= Catalog.PRE_EXPANDED_SYSTEM_COUNT:
			var sector := Catalog.sector_coordinates(system)
			if system < Catalog.PRE_ATLAS_SYSTEM_COUNT:
				sectors[sector] = true
			var planet: int = row.mines[0]
			var ephemeris := Orbit.sample(planet, 123.0)
			_expect(row.sector == sector and row.targets.size() in [3, 4] and row.ports.is_empty()
				and row.arrival_target == row.star and Orbit.period(planet) > 0.0
				and ephemeris.position.is_finite() and not Vector3(ephemeris.velocity).is_zero_approx(),
				"The generated system has a navigable primary and orbiting survey targets")
	_expect(targets.size() == Catalog.DESTINATION_COUNT and sectors.size() == 72,
		"All destinations are uniquely indexed and new systems occupy distinct sectors")
	var reachable: Array[int] = [HOME, Catalog.VELAR_SYSTEM, Catalog.FRINGE_SYSTEM]
	var queue := 0
	var capacity := Flight.new().ship.jump_capacity()
	while queue < reachable.size():
		var origin := reachable[queue]
		queue += 1
		for neighbor: int in Catalog.generated_systems_near(origin, Catalog.GENERATED_SCAN_RANGE):
			if neighbor not in reachable and Catalog.jump_cost(origin, neighbor) <= capacity:
				reachable.append(neighbor)
	_expect(reachable.size() == Catalog.SYSTEM_COUNT - 2
		and Catalog.HEATHER_SYSTEM not in reachable and Catalog.LIMIT_SYSTEM not in reachable,
		"Every exploration sector is connected by radio and ordinary jump range while authored expeditions keep their own unlocks")


func _test_schema_45() -> void:
	var old := Flight.new().snapshot()
	old.schema = 45
	old.mining.reserves.resize(Catalog.PRE_EXPANDED_DESTINATION_COUNT)
	var first := Catalog.AUTHORED_SYSTEM_COUNT
	old.cartography.systems = [{"system": first, "epoch": 0.0}]
	old.mining.reserves[2] -= 12
	var restored := Flight.new()
	if not _expect(restored.restore(old), "A release 0.91 payload migrates with its original deposit and discovered systems"):
		return
	var fresh := Catalog.PRE_EXPANDED_SYSTEM_COUNT
	var new_planet: int = Catalog.mines_for(fresh)[0]
	_expect(restored.known_systems() == [HOME, Catalog.VELAR_SYSTEM, Catalog.FRINGE_SYSTEM, first]
		and restored.mining.reserve_at(2) == old.mining.reserves[2]
		and restored.mining.reserve_at(new_planet) == int(Catalog.site(new_planet).reserve)
		and restored.snapshot().schema == Flight.SAVE_SCHEMA and not restored.system_known(fresh),
		"Legacy chart visibility is retained and newly introduced reserves start untouched")
	var before := restored.snapshot()
	var forged := old.duplicate(true)
	forged.cartography.systems.append({"system": fresh, "epoch": 0.0})
	_expect(not restored.restore(forged) and restored.snapshot() == before,
		"A legacy payload cannot introduce a discovered system beyond its original catalog range")
	forged = old.duplicate(true)
	forged.mining.reserves.append(0)
	_expect(not restored.restore(forged) and restored.snapshot() == before,
		"Appending reserve slots to an older schema cannot partially change the active flight")


func _test_round_trip() -> void:
	var flight := Flight.new()
	var outbound: Array[int] = [Catalog.AUTHORED_SYSTEM_COUNT]
	for x in [-2, -3, -4]:
		for system in range(Catalog.PRE_EXPANDED_SYSTEM_COUNT, Catalog.SYSTEM_COUNT):
			if Catalog.sector_coordinates(system) == Vector2i(x, 0):
				outbound.append(system)
				break
	if not _expect(outbound.size() == 4 and Fixture.depart(flight), "Begin a physical voyage west from the starter berth"):
		return
	var previous := HOME
	for system in outbound:
		if not _expect(flight.scan_galaxy() and flight.system_known(system) and flight.plan_jump(system)
			and _travel(flight, system, 0 if previous == HOME else Catalog.star_for(previous)),
			"Radio discover, refuel and physically jump from sector system %d to %d" % [previous, system]):
			return
		previous = system
	var frontier: int = outbound.back()
	var planet: int = Catalog.mines_for(frontier)[0]
	var resource: String = Catalog.site(planet).resource
	var reserve := flight.mining.reserve_at(planet)
	if not _expect(_approach(flight, planet) and flight.landed_site == planet and flight.survey_action(planet)
		and flight.mine_action() and _advance(flight, func() -> bool: return flight.mining.phase == Rig.READY, 25.0)
		and flight.mine_action() and _advance(flight, func() -> bool: return flight.mining.phase == Rig.STOWED, 6.0)
		and flight.mining.cargo_amount(resource) == Rig.BATCH and flight.mining.reserve_at(planet) == reserve - Rig.BATCH,
		"Land, survey and mine a body at the western edge of the expanded region"):
		return
	var save_path := "user://expanded-galaxy-route.json"
	var cold := Flight.new()
	if not _expect(Session.save_state(flight.snapshot(), save_path) == OK and cold.restore(Session.load_state(save_path))
		and cold.landed_site == planet and cold.body_dossier(planet).known
		and cold.mining.reserve_at(planet) == reserve - Rig.BATCH and cold.plan_route(HOME) and cold.dock_action(),
		"Cold restart on a new world preserves the survey and cargo, and accepts a return route"):
		return
	var return_legs := 0
	while cold.system_id != HOME and return_legs < 12:
		var next := cold.jump_target
		if not _expect(next >= 0 and _travel(cold, next, Catalog.star_for(cold.system_id)),
			"Refuel as needed and physically fly the next persisted return leg"):
			return
		return_legs += 1
	_expect(cold.system_id == HOME and return_legs >= 3 and _approach(cold, 0) and cold.docked == 0
		and cold.mining.cargo_amount(resource) == Rig.BATCH and cold.ship.hull == 100.0,
		"Return from the new frontier to the original dock with surveyed minerals and full hull")


func _travel(flight: Flight, destination: int, nearest_site: int) -> bool:
	var fare := flight.jump_tariff(flight.system_id, destination)
	if flight.ship.jump_fuel < fare:
		var star := Catalog.star_for(flight.system_id)
		var needed := ceili((fare - flight.ship.jump_fuel) / 10.0)
		if not _approach(flight, star) or not flight.scoop_action():
			return false
		if not _advance(flight, func() -> bool: return flight.mining.cargo_amount("hydrogen") >= needed, 38.0):
			return false
		if flight.scooping:
			flight.scoop_action()
		if not flight.fuel_transfer("jump"):
			return false
		nearest_site = star
	var outgoing := (flight.position - flight.target_position(nearest_site)).normalized()
	flight.yaw = atan2(-outgoing.x, -outgoing.z)
	flight.pitch = asin(clampf(outgoing.y, -1.0, 1.0))
	flight.change_throttle(0.18)
	return _advance(flight, func() -> bool: return flight.jump_status(destination).ok, 25.0) \
		and flight.start_jump() and _advance(flight, func() -> bool: return flight.system_id == destination, 4.0)


func _approach(flight: Flight, site: int) -> bool:
	if not flight.select_target(site):
		return false
	flight.set_autopilot(true)
	return _advance(flight, func() -> bool: return not flight.autopilot, 160.0)


func _advance(flight: Flight, reached: Callable, maximum: float) -> bool:
	for _frame in range(ceili(maximum / STEP)):
		if reached.call():
			return true
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	return reached.call()


func _expect(value: bool, description: String) -> bool:
	_checks += 1
	if not value:
		_failures.append(description)
	return value
