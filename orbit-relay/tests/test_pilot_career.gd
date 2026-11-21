extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Patrol := preload("res://scripts/patrol_encounter.gd")
const Session := preload("res://scripts/session_io.gd")

const STEP := Fixture.STEP
const HOME_PORT := 0
const VELAR_PORT := 10
const DISPATCH_SAVE := "user://career-dispatch.json"
const VICTORY_SAVE := "user://career-victory.json"

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var pilot := Flight.new()
	_test_new_standings(pilot)
	if _earn_freight(pilot, 0) and _expect(_fly(pilot, HOME_PORT), "Return to the original port for its faction patrol"):
		if _test_victory_and_report(pilot, 0):
			_test_dispatch(pilot)
	_test_velar_standings()
	print("Pilot career integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_new_standings(flight: Flight) -> void:
	var status := flight.career_status()
	_expect(status.combat_points == 0 and status.combat_rank == 0 and status.factions.size() == 2
		and _standing(flight, 0).trust == 0 and _standing(flight, 1).trust == 0
		and _standing(flight, 0).service_points == 0 and _standing(flight, 1).service_points == 0
		and not status.offer.allowed and not status.dispatch.active and not flight.career_dispatch_action(),
		"A new pilot has independent zero standings and no access to faction service dispatch")


func _earn_freight(flight: Flight, issuer: int) -> bool:
	var own := _standing(flight, issuer)
	var other := _standing(flight, 1 - issuer)
	var combat := int(flight.career_status().combat_points)
	var completed := flight.deliveries
	if not _expect(flight.contract_action() and flight.contract_stage == 1, "Take a real local cargo assignment"):
		return false
	var destination := flight.contract_destination
	if not _expect(_fly(flight, destination) and flight.contract_action() and flight.deliveries == completed + 1,
		"Fly to the contracting port and file the actual freight receipt"):
		return false
	var posted := _standing(flight, issuer)
	return _expect(posted.trust == own.trust + 1 and posted.service_points == own.service_points
		and flight.career_status().combat_points == combat and _standing(flight, 1 - issuer) == other,
		"An ordinary paid cargo receipt improves only its faction's trust")


func _test_victory_and_report(flight: Flight, issuer: int) -> bool:
	var own := _standing(flight, issuer)
	var other := _standing(flight, 1 - issuer)
	var balance := flight.credits
	var port := flight.docked
	var combat := int(flight.career_status().combat_points)
	if not _expect(flight.patrol_action() and flight.career_status().patrol_issuer == issuer
		and Fixture.depart(flight) and flight.patrol_action()
		and _until(flight, func() -> bool: return flight.patrol.phase == Patrol.ENGAGED, 60.0),
		"Accept an actual faction patrol and follow its independent signal"):
		return false
	for _frame in range(ceili(12.0 / STEP)):
		if flight.patrol.phase != Patrol.ENGAGED:
			break
		_aim_at_mission(flight)
		if flight.fire_status().ok:
			flight.fire_action()
		_tick(flight)
	if not _expect(flight.patrol.phase == Patrol.RETURN and flight.career_status().combat_points == combat + 1
		and flight.career_status().combat_rank >= 1 and flight.credits == balance
		and _standing(flight, issuer) == own and _standing(flight, 1 - issuer) == other,
		"Winning combat raises the combat rank immediately while service and money await a report"):
		return false
	var saved := flight.snapshot()
	var cold := Flight.new()
	if not _expect(Session.save_state(saved, VICTORY_SAVE) == OK and cold.restore(Session.load_state(VICTORY_SAVE))
		and cold.patrol.phase == Patrol.RETURN and cold.career_status().patrol_issuer == issuer
		and cold.career_status().combat_points == combat + 1 and _standing(cold, issuer) == own
		and flight.restore(Session.load_state(VICTORY_SAVE)),
		"Cold victory retains the combat mark, exact issuer, and unfiled service credit"):
		return false
	if not _expect(flight.patrol_action() and _until(flight, func() -> bool: return flight.docked == port, 125.0)
		and flight.patrol_action(), "Use real return autopilot and submit the patrol report only at its originating berth"):
		return false
	var record := flight.career_status()
	var promoted: Dictionary = record.factions[issuer]
	return _expect(flight.patrol.phase == Patrol.COMPLETE and record.patrol_issuer == -1
		and promoted.trust == own.trust + 1 and promoted.service_points == own.service_points + 1
		and promoted.service_rank == 1 and promoted.dispatch_role and _standing(flight, 1 - issuer) == other
		and record.combat_points == combat + 1 and flight.credits == balance + 450 + flight.system_id * 75,
		"The report pays and promotes the correct faction exactly once without a duplicate combat award")


func _test_dispatch(flight: Flight) -> void:
	var issuer := 0
	var standing := _standing(flight, issuer)
	var offer: Dictionary = flight.career_status().offer
	if not _expect(offer.allowed and offer.issuer == issuer and offer.origin == flight.docked and offer.destination == 1
		and offer.reward == 300 and offer.duration == 180.0 and flight.career_dispatch_action(),
		"The newly earned service role unlocks a real timed dispatch at the correct station"):
		return
	var original: Dictionary = flight.career_status().dispatch
	var old_balance := flight.credits
	if not _expect(original.active and original.issuer == issuer and original.destination == 1
		and _near(original.deadline - original.accepted_at, 180.0)
		and flight.career_status().can_follow and not flight.career_status().can_submit
		and not flight.career_dispatch_action() and flight.credits == old_balance
		and Session.save_state(flight.snapshot(), DISPATCH_SAVE) == OK,
		"Taking a dispatch locks its destination and 180-second deadline without issuing money"):
		return
	var paused := _load(DISPATCH_SAVE)
	if paused != null:
		_test_dispatch_expiration(paused)
	var continued := _load(DISPATCH_SAVE)
	if continued == null:
		return
	if not _expect(continued.career_status().dispatch.active and _near(continued.career_status().dispatch.deadline, original.deadline)
		and continued.career_follow() and continued.planned_target == 1 and Fixture.depart(continued)
		and continued.career_follow() and continued.target == 1, "Cold dispatch follow plots the correct berth before and after departure"):
		return
	continued.set_autopilot(true)
	if not _expect(_until(continued, func() -> bool: return continued.docked == 1, 125.0)
		and continued.career_status().can_submit and continued.career_dispatch_action(), "Submit the active dispatch at its destination before expiry"):
		return
	var obtained := _standing(continued, issuer)
	_expect(continued.credits == old_balance + 300 and obtained.trust == standing.trust + 1
		and obtained.service_points == standing.service_points + 1 and continued.career_status().combat_points == 1
		and not continued.career_status().dispatch.active and not continued.career_status().can_submit,
		"The submitted dispatch pays and updates only the commissioning faction without raising combat rank")
	var file := "user://career-dispatch-complete.json"
	if not _expect(Session.save_state(continued.snapshot(), file) == OK, "Save the completed role assignment"):
		return
	var after := _load(file)
	if after != null:
		_expect(after.credits == old_balance + 300 and _standing(after, issuer) == obtained
			and not after.career_status().dispatch.active and not after.career_status().can_submit,
			"Cold completion cannot replay the payment or service progression")


func _test_dispatch_expiration(flight: Flight) -> void:
	var balance := flight.credits
	var previous := _standing(flight, 0)
	var deadline := float(flight.career_status().dispatch.deadline)
	flight.cycle_time_scale()
	flight.cycle_time_scale()
	if not _expect(flight.time_scale == 16 and flight.career_status().dispatch.active, "Fast-forward dispatch time while physically docked"):
		return
	flight.update((deadline - flight.orbit_time - 0.25) / 16.0, Vector2.ZERO, 0.0, false, false)
	if not _expect(flight.career_status().dispatch.active and flight.toggle_time_pause(), "Pause the actual dispatch clock just before its deadline"):
		return
	var checkpoint := flight.snapshot()
	flight.update(5.0, Vector2.ZERO, 0.0, false, false)
	_expect(flight.snapshot() == checkpoint and flight.toggle_time_pause(), "Wall time cannot expire a paused active dispatch")
	flight.update(0.25 / float(flight.time_scale), Vector2.ZERO, 0.0, false, false)
	var missed := _standing(flight, 0)
	_expect(_near(flight.orbit_time, deadline) and not flight.career_status().dispatch.active
		and missed.trust == previous.trust - 2 and missed.service_points == previous.service_points
		and not missed.dispatch_role and not flight.career_dispatch_action() and flight.credits == balance,
		"At the exact deadline a missed dispatch loses only commissioning trust and qualification")
	_tick(flight)
	_expect(_standing(flight, 0) == missed, "Another game frame cannot charge the expiry again")
	if _earn_freight(flight, 0) and _earn_freight(flight, 0):
		_expect(_standing(flight, 0).dispatch_role and _standing(flight, 0).trust == previous.trust
			and _standing(flight, 0).service_points == previous.service_points
			and flight.career_status().offer.allowed, "Actual new freight receipts rebuild the lost service qualification")


func _test_velar_standings() -> void:
	var flight := Flight.new()
	if not _expect(Fixture.depart(flight) and flight.plan_jump(Catalog.VELAR_SYSTEM), "Leave Home for actual service in another faction"):
		return
	flight.change_throttle(0.18)
	if not _expect(_until(flight, func() -> bool: return flight.jump_status(Catalog.VELAR_SYSTEM).ok, 15.0)
		and flight.start_jump() and _until(flight, func() -> bool: return flight.system_id == Catalog.VELAR_SYSTEM, 5.0)
		and _fly(flight, VELAR_PORT), "Undergo the paid jump and dock with the main Velar faction port"):
		return
	if not _earn_freight(flight, 1) or not _test_victory_and_report(flight, 1):
		return
	var status := flight.career_status()
	if not _expect(status.offer.allowed and status.offer.issuer == 1 and status.offer.origin == flight.docked
		and status.offer.destination == VELAR_PORT and _standing(flight, 1).dispatch_role
		and not _standing(flight, 0).dispatch_role and _standing(flight, 0).trust == 0,
		"Independent service in Velar unlocks a Velar dispatch without giving the Home faction credit"):
		return
	var balance := flight.credits
	_expect(flight.career_dispatch_action() and _fly(flight, VELAR_PORT)
		and flight.career_status().can_submit and flight.career_dispatch_action()
		and flight.credits == balance + 300 and _standing(flight, 1).service_points == 2 and _standing(flight, 0).service_points == 0,
		"Complete and pay the independent Velar dispatch through the same Journal submission path")


func _standing(flight: Flight, issuer: int) -> Dictionary:
	return flight.career_status().factions[issuer]


func _fly(flight: Flight, port: int) -> bool:
	if not flight.select_target(port) or (flight.docked >= 0 and not Fixture.depart(flight)):
		return false
	flight.set_autopilot(true)
	return _until(flight, func() -> bool: return flight.docked == port, 140.0)


func _aim_at_mission(flight: Flight) -> void:
	for contact: Dictionary in flight.traffic_contacts():
		if contact.role == "raider" and not contact.get("ambient", false):
			var direction := flight.position.direction_to(contact.position)
			flight.yaw = atan2(-direction.x, -direction.z)
			flight.pitch = clampf(asin(direction.y), -Flight.MAX_PITCH, Flight.MAX_PITCH)
			return


func _load(path: String) -> Flight:
	var flight := Flight.new()
	return flight if _expect(flight.restore(Session.load_state(path)), "Cold restore the actual career state from %s" % path) else null


func _until(flight: Flight, reached: Callable, seconds: float) -> bool:
	for _frame in range(ceili(seconds / STEP)):
		if reached.call():
			return true
		_tick(flight)
	return reached.call()


func _tick(flight: Flight) -> void:
	flight.update(STEP, Vector2.ZERO, 0.0, false, false)


func _near(actual: float, wanted: float) -> bool:
	return absf(actual - wanted) < 0.00001


func _expect(value: bool, description: String) -> bool:
	_checks += 1
	if not value:
		_failures.append("FAIL: " + description)
	return value
