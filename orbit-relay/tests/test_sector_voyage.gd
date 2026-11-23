extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Session := preload("res://scripts/session_io.gd")

const SAVE_PATH := "user://streamed-sector-voyage.json"
const HOME := Catalog.HOME_SYSTEM
const STEP := Fixture.STEP

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_voyage()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + ".previous"))
	for failure: String in _failures:
		printerr(failure)
	print("Streamed sector voyage: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _test_voyage() -> void:
	var flight := Flight.new()
	var candidates := Catalog.generated_systems_near(HOME, Catalog.GENERATED_SCAN_RANGE, true)
	var stop := -1
	var next := -1
	for candidate: int in candidates:
		if not Catalog.is_extended_system(candidate):
			continue
		var fare := flight.jump_tariff(HOME, candidate)
		if 2 * fare <= flight.ship.active_jump_fuel() + 5.0 or fare > flight.ship.active_jump_fuel():
			continue
		for successor: int in Catalog.generated_systems_near(candidate, Catalog.GENERATED_SCAN_RANGE, true):
			if Catalog.is_extended_system(successor) and successor not in candidates:
				stop = candidate
				next = successor
				break
		if stop >= 0:
			break
	if not _expect(stop >= 0 and next >= 0 and not flight.plan_jump(stop) and not flight.system_dossier(stop).known,
		"An uncharted streamed stop is hidden until the pilot scans its neighborhood"):
		return
	if not _expect(flight.scan_galaxy() and flight.system_known(stop) and not flight.system_known(next)
		and not flight.scan_galaxy() and flight.route_preview(stop).available and flight.plan_jump(stop),
		"Ordinary radio discovery reveals a streamed stop and allows a standard in-range route"):
		return
	if not _expect(Fixture.depart(flight) and _charge_jump(flight, stop, 0),
		"Depart from the starting station and pay for a real jump to the next sector"):
		return
	var spent := flight.ship.jump_fuel
	var transit := _save_and_restart(flight)
	if not _expect(transit != null and transit.jump_progress_status().is_transit and transit.jump_target == stop,
		"Cold restart keeps the paid phase and the streamed destination in a planned route"):
		return
	if not _expect(_advance(transit, func() -> bool: return transit.system_id == stop, 4.0)
		and transit.ship.jump_fuel == spent and transit.local_ports().is_empty() and transit.system_dossier(stop).known,
		"Arrival enters the generated system with the same fuel balance and no synthetic berth"):
		return
	if not _expect(transit.scan_galaxy() and transit.system_known(next) and transit.route_preview(next).available,
		"Radio discovery from this sector opens an adjacent unknown system without a global search"):
		return
	var before := transit.snapshot()
	var cold := _save_and_restart(transit)
	if not _expect(cold != null and cold.system_id == stop and cold.system_known(next)
		and cold.snapshot().cartography == before.cartography,
		"Cold restart preserves both scan epochs and every recorded neighboring address"):
		return
	var forged := before.duplicate(true)
	forged.schema = 55
	_expect(not Flight.new().restore(forged), "A legacy schema cannot forge a discovery in a streamed sector")
	forged = before.duplicate(true)
	var group: Array = forged.cartography.sector_systems[0][1]
	group.insert(1, group[0])
	_expect(not Flight.new().restore(forged), "A duplicate streamed address is rejected during restore")

	var star := Catalog.star_for(stop)
	var return_fare := cold.ship.jump_tariff(Catalog.jump_cost(stop, HOME), cold.mining.ore_hold, cold.ship.jump_capacity())
	var needed := ceili((return_fare - cold.ship.jump_fuel) / 10.0)
	if not _expect(needed > 0 and _approach(cold, star) and cold.scoop_action()
		and _advance(cold, func() -> bool: return cold.mining.cargo_amount("hydrogen") >= needed, 38.0),
		"Collect enough hydrogen for a return leg in the uninhabited sector"):
		return
	if cold.scooping:
		cold.scoop_action()
	_expect(cold.fuel_transfer("jump") and cold.plan_jump(HOME) and _charge_jump(cold, HOME, star)
		and _advance(cold, func() -> bool: return cold.system_id == HOME, 4.0)
		and cold.system_known(next),
		"Return to the original galaxy with the refueled drive and streamed discoveries")


func _save_and_restart(flight: Flight) -> Flight:
	if Session.save_state(flight.snapshot(), SAVE_PATH) != OK:
		return null
	var cold := Flight.new()
	return cold if cold.restore(Session.load_state(SAVE_PATH)) else null


func _charge_jump(flight: Flight, destination: int, nearest_site: int) -> bool:
	var outward := (flight.position - flight.target_position(nearest_site)).normalized()
	flight.yaw = atan2(-outward.x, -outward.z)
	flight.pitch = asin(clampf(outward.y, -1.0, 1.0))
	flight.change_throttle(0.18)
	return _advance(flight, func() -> bool: return flight.jump_status(destination).ok, 25.0) \
		and flight.start_jump() \
		and _advance(flight, func() -> bool: return flight.jump_progress_status().is_transit, 4.0)


func _approach(flight: Flight, site: int) -> bool:
	if not flight.select_target(site):
		return false
	flight.set_autopilot(true)
	return _advance(flight, func() -> bool: return not flight.autopilot, 170.0)


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
