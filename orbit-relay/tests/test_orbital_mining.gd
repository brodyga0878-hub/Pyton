extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Rig := preload("res://scripts/mining_rig.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const ASTEROID := 2
const MOON := 6
const PORT := 1
const HOME := Catalog.HOME_SYSTEM
const VELAR := Catalog.VELAR_SYSTEM
const STEP := Fixture.STEP
const SAVE_PATH := "user://orbital-mining-test.json"

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_player_cycle()
	print("Orbital mining integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_player_cycle() -> void:
	var flight := Flight.new()
	_expect(not flight.ship.mining_laser and not flight.ship.fragment_collector
		and not flight.service_action("mining_laser") and not flight.service_action("fragment_collector")
		and not flight.fire_mining_pulse() and not flight.collect_fragment(),
		"An unmodified starter has neither equipment nor an orbital mining action in port")
	if not _expect(flight.contract_action() and Fixture.depart(flight) and _dock_at(flight, PORT)
		and flight.contract_action() and flight.credits == 240,
		"Earn the two equipment purchases through an actual short freight delivery"):
		return
	if not _expect(flight.service_offer("mining_laser").cost == 140
		and flight.service_offer("fragment_collector").cost == 90
		and flight.service_action("mining_laser") and flight.credits == 100
		and flight.ship.mining_laser and not flight.ship.fragment_collector
		and not flight.service_action("mining_laser") and flight.credits == 100
		and flight.service_action("fragment_collector") and flight.credits == 10
		and flight.ship.fragment_collector and not flight.service_action("fragment_collector"),
		"Two separate certified modules install and charge once at their displayed prices"):
		return
	_expect(not flight.fire_mining_pulse() and not flight.collect_fragment(), "Installed tools remain inert in port")
	if not _expect(Fixture.depart(flight) and flight.select_target(ASTEROID), "Leave port and select the authored asteroid"):
		return
	var reserve := flight.mining.reserve_at(ASTEROID)
	var fuel := flight.ship.fuel
	_expect(not flight.service_action("fragment_collector") and not flight.fire_mining_pulse()
		and flight.mining.reserve_at(ASTEROID) == reserve and flight.ship.fuel == fuel,
		"An out-of-range pulse and airborne service command cannot change fuel or reserves")
	if not _expect(flight.start_rendezvous(ASTEROID, 150)
		and _advance(flight, func() -> bool: return flight.rendezvous_status().can_finish, 110.0)
		and not flight.landed and flight.orbital_mining_status().fire_ok,
		"Follow the moving asteroid to a real stand-off match with the mining pulse enabled"):
		return
	var aimed_yaw := flight.yaw
	flight.yaw = wrapf(aimed_yaw + PI, -PI, PI)
	fuel = flight.ship.fuel
	_expect(not flight.fire_mining_pulse() and flight.mining.reserve_at(ASTEROID) == reserve and flight.ship.fuel == fuel,
		"Pointing away from the rock cannot debit the deposit or emit a fragment")
	flight.yaw = aimed_yaw
	if not _expect(flight.fire_mining_pulse() and flight.local_fragments().size() == 1
		and flight.mining.reserve_at(ASTEROID) == reserve - 1 and flight.mining.ore_hold == 0
		and flight.ship.fuel < fuel and float(flight.orbital_mining_status().ready_in) > 0.0,
		"A held-space hit spends reaction fuel and detaches exactly one unit without filling the hold"):
		return
	var beam := flight.orbital_mining_beam()
	var fresh := flight.local_fragments().front() as Dictionary
	_expect(not beam.is_empty() and float(beam.get("remaining", 0.0)) > 0.0
		and (beam.start as Vector3).distance_to(flight.position) < 5.0
		and fresh.site == ASTEROID and fresh.resource == Catalog.site(ASTEROID).resource,
		"The hit emits a beam at the actual craft and a fragment with the actual resource identity")
	var original_radius: float = (fresh.position as Vector3).distance_to(flight.target_position(ASTEROID))
	_tick(flight, 0.65)
	var drifted := flight.local_fragments().front() as Dictionary
	_expect((drifted.position as Vector3).distance_to(fresh.position) > 0.1
		and (drifted.position as Vector3).distance_to(flight.target_position(ASTEROID)) > original_radius + 0.1
		and (drifted.velocity as Vector3).distance_to(flight.target_velocity(ASTEROID)) > 0.05
		and flight.orbital_mining_beam().is_empty(),
		"The loose piece moves outward with its moving parent and the pulse visual is only transient")
	_expect(not flight.fire_mining_pulse() and flight.local_fragments().size() == 1
		and flight.mining.reserve_at(ASTEROID) == reserve - 1,
		"Another pulse before cooldown cannot emit a second fragment or debit a second unit")
	var checkpoint := flight.snapshot()
	var resumed := Flight.new()
	if not _expect(SessionIO.save_state(checkpoint, SAVE_PATH) == OK and resumed.restore(SessionIO.load_state(SAVE_PATH)),
		"Write and cold-load a genuine mid-flight state with one loose fragment"):
		return
	var reloaded := resumed.local_fragments().front() as Dictionary
	_expect(resumed.ship.mining_laser and resumed.ship.fragment_collector and reloaded.site == ASTEROID
		and (reloaded.position as Vector3).distance_to(drifted.position) < 0.002
		and (reloaded.velocity as Vector3).distance_to(drifted.velocity) < 0.002
		and absf(float(resumed.orbital_mining_status().ready_in) - float(flight.orbital_mining_status().ready_in)) < 0.000001
		and resumed.mining.reserve_at(ASTEROID) == reserve - 1 and resumed.mining.ore_hold == 0,
		"Both installed modules, cooldown, fragment kinematics and the debited stock survive a cold start")
	_test_full_hold(checkpoint)
	_test_save_integrity(checkpoint)
	_test_interstellar(checkpoint)
	_test_shared_deposit(checkpoint)
	var good := str(Catalog.site(ASTEROID).resource)
	if not _expect(resumed.orbital_mining_status().collect_ok and resumed.collect_fragment()
		and resumed.mining.cargo_amount(good) == 1 and resumed.local_fragments().is_empty(),
		"The collector recovers exactly one loose unit after a cold restart"):
		return
	_expect(not resumed.collect_fragment() and not resumed.fire_mining_pulse()
		and resumed.mining.cargo_amount(good) == 1 and resumed.mining.reserve_at(ASTEROID) == reserve - 1,
		"Collection is single-use and does not reset the pulse cooldown or debit the deposit again")
	_tick(resumed, 2.2)
	_expect(resumed.orbital_mining_status().fire_ok and resumed.fire_mining_pulse()
		and resumed.mining.reserve_at(ASTEROID) == reserve - 2 and resumed.mining.cargo_amount(good) == 1,
		"Once the cooldown ends a fresh hit deducts a new unit without copying the previously collected one")
	_tick(resumed, 2.2)
	_expect(not resumed.fire_mining_pulse() and resumed.local_fragments().size() == 1
		and resumed.mining.reserve_at(ASTEROID) == reserve - 2,
		"A still-loose unit blocks another hit even after the cooldown expires")


func _test_full_hold(checkpoint: Dictionary) -> void:
	var flight := Flight.new()
	if not _expect(flight.restore(checkpoint) and flight.mining.insert_cargo("circuits", flight.mining.free_capacity()),
		"Prepare a full shared hold beside the existing loose fragment"):
		return
	var inventory := flight.mining.snapshot()
	var position: Vector3 = flight.local_fragments().front().position
	_expect(not flight.orbital_mining_status().collect_ok and not flight.collect_fragment()
		and flight.mining.snapshot() == inventory and flight.local_fragments().size() == 1
		and flight.local_fragments().front().position == position,
		"A full hold cannot collect and leaves the fragment in exactly the same place")
	if not _expect(flight.select_target(MOON) and not flight.fire_mining_pulse() and not flight.collect_fragment()
		and flight.local_fragments().size() == 1 and flight.select_target(ASTEROID),
		"Changing to a non-asteroid neither acts on nor removes the existing fragment"):
		return
	var good := str(Catalog.site(ASTEROID).resource)
	_expect(flight.jettison_cargo("circuits") and flight.mining.free_capacity() == 1
		and flight.collect_fragment() and not flight.collect_fragment() and flight.mining.free_capacity() == 0
		and flight.mining.cargo_amount(good) == 1 and flight.local_fragments().is_empty(),
		"Freeing one true cargo slot permits one pickup despite the remaining manufactured goods")


func _test_save_integrity(checkpoint: Dictionary) -> void:
	var flight := Flight.new()
	if not _expect(flight.restore(checkpoint), "Initialize an intact save used by the corruption checks"):
		return
	var intact := flight.snapshot()
	var invalid := checkpoint.duplicate(true)
	invalid.orbital_mining.fragments.append(invalid.orbital_mining.fragments.front().duplicate(true))
	_expect(not flight.restore(invalid) and flight.snapshot() == intact, "Reject duplicate escrow entries without changing the live flight")
	invalid = checkpoint.duplicate(true)
	invalid.orbital_mining.fragments[0].created = float(invalid.orbit_time) + 1.0
	_expect(not flight.restore(invalid) and flight.snapshot() == intact, "Reject loose ore created in the future")
	invalid = checkpoint.duplicate(true)
	invalid.mining.reserves[ASTEROID] = int(Catalog.site(ASTEROID).reserve)
	_expect(not flight.restore(invalid) and flight.snapshot() == intact, "Reject a loose fragment with no corresponding reserve debit")


func _test_interstellar(checkpoint: Dictionary) -> void:
	var flight := Flight.new()
	if not _expect(flight.restore(checkpoint) and _jump(flight, VELAR, ASTEROID)
		and flight.local_fragments().is_empty() and not flight.collect_fragment(),
		"Travel through a real jump to Velar without rendering or collecting the Helion fragment there"):
		return
	var distant := flight.snapshot()
	var resumed := Flight.new()
	if not _expect(resumed.restore(distant) and resumed.local_fragments().is_empty()
		and _jump(resumed, HOME, Catalog.system(VELAR).arrival_port),
		"Cold-load in the foreign system and jump physically back"):
		return
	var found := resumed.local_fragments()
	_expect(found.size() == 1 and found.front().site == ASTEROID and resumed.mining.ore_hold == 0
		and resumed.mining.reserve_at(ASTEROID) == int(checkpoint.mining.reserves[ASTEROID]),
		"The single conserved fragment remains at its original asteroid after the interstellar round trip")


func _test_shared_deposit(checkpoint: Dictionary) -> void:
	var flight := Flight.new()
	if not _expect(flight.restore(checkpoint), "Initialize the asteroid with a loose fragment before landing"):
		return
	flight.set_autopilot(true)
	if not _expect(_advance(flight, func() -> bool: return flight.landed_site == ASTEROID, 100.0)
		and flight.leave_remote_rig() and flight.local_fragments().size() == 1,
		"A physical landing and unattended drill deployment leave the loose fragment in orbit"):
		return
	var reserve := flight.mining.reserve_at(ASTEROID)
	_tick(flight, float(flight.remote_rig_status().remaining) + 0.05)
	if not _expect(flight.remote_rig_status().stored == Rig.BATCH and flight.local_fragments().size() == 1
		and flight.mining.reserve_at(ASTEROID) == reserve - Rig.BATCH,
		"The ground installation and the loose fragment have distinct claims on one reserve"):
		return
	var combined := flight.snapshot()
	var resumed := Flight.new()
	_expect(resumed.restore(combined) and resumed.remote_rig_status().stored == Rig.BATCH
		and resumed.local_fragments().size() == 1, "The save preserves both physical stores without adding either to the hold")
	combined.mining.reserves[ASTEROID] += 1
	_expect(not resumed.restore(combined), "One unit of the deposit cannot account for both a stored and loose unit")


func _dock_at(flight: Flight, port: int) -> bool:
	if not flight.select_target(port):
		return false
	flight.set_autopilot(true)
	return _advance(flight, func() -> bool: return flight.docked == port, 120.0)


func _jump(flight: Flight, destination: int, nearby: int) -> bool:
	if not flight.plan_jump(destination):
		return false
	if not flight.jump_status(destination).ok:
		var direction := (flight.position - flight.target_position(nearby)).normalized()
		flight.yaw = atan2(-direction.x, -direction.z)
		flight.pitch = asin(clampf(direction.y, -1.0, 1.0))
		flight.change_throttle(0.18)
		if not _advance(flight, func() -> bool: return flight.jump_status(destination).ok, 30.0):
			return false
	return flight.start_jump() and _advance(flight, func() -> bool: return flight.system_id == destination, 4.0)


func _advance(flight: Flight, reached: Callable, seconds: float) -> bool:
	for _frame in range(ceili(seconds / STEP)):
		if reached.call():
			return true
		_tick(flight, STEP)
	return reached.call()


func _tick(flight: Flight, seconds: float) -> void:
	flight.update(seconds, Vector2.ZERO, 0.0, false, false)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
