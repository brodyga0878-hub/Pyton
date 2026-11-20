extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Combat := preload("res://scripts/combat_systems.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Patrol := preload("res://scripts/patrol_encounter.gd")
const Session := preload("res://scripts/session_io.gd")

const STEP := Fixture.STEP
const HOME_PORT := 0
const INCOMING_SAVE := "user://combat-incoming.json"
const REPAIRED_SAVE := "user://combat-repaired.json"

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var pilot := _earn_outfitting()
	if pilot != null and _buy_modules(pilot):
		var pulse := _copy(pilot)
		if pulse != null:
			_expect(pulse.select_weapon("pulse") and pulse.combat_status().weapon == "pulse",
				"The fitted ship can still choose the standard laser at its berth")
			if _engage(pulse):
				_test_ecm_damage(pulse)
		if _engage(pilot):
			_test_focus_heat(pilot)
			_test_active_projectile(pilot)
	_test_projectile_boundaries()
	_test_parking(HOME_PORT)
	_test_parking(2)
	print("Combat outfitting: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _earn_outfitting() -> Flight:
	var flight := Flight.new()
	var installed := flight.combat_equipment_status()
	_expect(installed.station and installed.weapon == "pulse" and not installed.focus_owned
		and not installed.shield_fitted and not installed.ecm_fitted and installed.damaged.is_empty(),
		"The original starter has its pulse laser and none of the new modules")
	_expect(not flight.select_weapon("focus") and not flight.select_weapon("unknown")
		and not flight.service_action("combat_shield") and not flight.service_action("combat_ecm")
		and not flight.service_action("combat_focus") and not flight.service_action("combat_repair")
		and not flight.use_ecm() and flight.credits == 0, "Unaffordable or inapplicable commands cannot mutate a new ship")
	if not _engage(flight):
		return null
	var hull := flight.ship.hull
	_expect(_until(flight, func() -> bool: return flight.ship.hull < hull, 5.0)
		and flight.ship.hull == hull - 6.0 and flight.combat_status().shield_max == 0.0,
		"An unshielded ship still receives the original six-point patrol beam")
	_aim_at_raider(flight)
	var shot_epoch := flight.orbit_time
	if not _expect(flight.fire_action() and flight.patrol.enemy_hull == 76.0 and flight.combat_status().heat == 17.0
		and absf(float(flight.snapshot().combat.fire_ready_at) - shot_epoch - 0.38) < 0.0000001
		and not flight.fire_action(), "The firing starter retains 24 damage and a 0.38-second cooldown with 17 heat"):
		return null
	for _frame in range(ceili(20.0 / STEP)):
		if flight.patrol.phase != Patrol.ENGAGED:
			break
		_aim_at_raider(flight)
		if flight.fire_status().ok:
			flight.fire_action()
		_tick(flight)
	if not _expect(flight.patrol.phase == Patrol.RETURN and flight.credits == 0 and flight.patrol_action(),
		"Defeating a live raider puts the pilot on course for a paid report"):
		return null
	if not _expect(_until(flight, func() -> bool: return flight.docked == HOME_PORT, 100.0)
		and flight.patrol_action() and flight.patrol.phase == Patrol.COMPLETE and flight.credits == 450,
		"Actual docking and filing the report pays 450 credits to fund outfitting"):
		return null
	return flight


func _buy_modules(flight: Flight) -> bool:
	var hull := flight.ship.hull
	for offer: Dictionary in [{"id": "combat_shield", "price": 120}, {"id": "combat_ecm", "price": 90},
			{"id": "combat_focus", "price": 170}]:
		var balance := flight.credits
		if not _expect(flight.service_offer(offer.id).cost == offer.price and flight.service_action(offer.id)
			and flight.credits == balance - offer.price and not flight.service_action(offer.id)
			and flight.credits == balance - offer.price, "Buy %s at the real station and charge exactly once" % offer.id):
			return false
	var installed := flight.combat_equipment_status()
	return _expect(flight.credits == 70 and installed.focus_owned and installed.shield_fitted and installed.ecm_fitted
		and flight.combat_status().shield == 36.0 and flight.combat_status().shield_max == 36.0
		and installed.weapon == "focus" and flight.ship.hull == hull and not flight.service_offer("combat_repair").allowed,
		"All three purchases apply without healing or repair charges and select the acquired laser")


func _engage(flight: Flight) -> bool:
	if not _expect(flight.patrol_action() and flight.patrol.phase == Patrol.OUTBOUND
		and Fixture.depart(flight) and flight.patrol_action(), "Take the optional patrol and depart using normal guidance"):
		return false
	return _expect(_until(flight, func() -> bool: return flight.patrol.phase == Patrol.ENGAGED, 50.0)
		and not _raider(flight).is_empty(), "Follow the actual patrol signal to a hostile contact")


func _test_focus_heat(engaged: Flight) -> void:
	var focus := _copy(engaged)
	if focus == null:
		return
	_aim_at_raider(focus)
	var start := focus.orbit_time
	if not _expect(focus.fire_action() and focus.combat_status().heat == 40.0
		and absf(float(focus.snapshot().combat.fire_ready_at) - start - 0.60) < 0.0000001
		and not focus.fire_action(), "A successful focus shot costs 40 heat and begins its longer 0.60-second cooldown"):
		return
	_step(focus, 0.40)
	_aim_at_raider(focus)
	_expect(absf(float(focus.combat_status().heat) - (40.0 - 16.0 * 0.40)) < 0.000001
		and not focus.fire_action(), "Cooling uses 16 units per game second and standard-laser cadence is too soon")
	_step(focus, 0.20)
	_aim_at_raider(focus)
	if not _expect(focus.fire_action() and focus.combat_status().heat > 70.0, "The second shot can fire at the focus cadence"):
		return
	_step(focus, 0.60)
	_aim_at_raider(focus)
	var enemy_hull := focus.patrol.enemy_hull
	_expect(focus.combat_status().fire_blocked.begins_with("Перегрев") and not focus.fire_action()
		and focus.patrol.enemy_hull == enemy_hull, "A third shot at the resumed cadence overheats without consuming target hull")
	_step(focus, 0.30)
	_aim_at_raider(focus)
	_expect(focus.fire_action() and focus.patrol.enemy_hull < enemy_hull,
		"The ship can fire again after the heat falls enough")

	var standard := Combat.new()
	var extended := Combat.new()
	_expect(standard.profile().range_bonus == 0.0 and extended.buy("combat_focus", 170) == 170
		and extended.profile().range_bonus == 80.0, "Focus adds 80 metres to the standard firing profile")
	var long_range := _copy(engaged)
	if long_range == null:
		return
	var enemy := _raider(long_range)
	var path := long_range.position.direction_to(enemy.position)
	long_range.position = enemy.position - path * 340.0
	_aim_at_raider(long_range)
	_expect(not long_range.patrol.fire_status(long_range).ok and long_range.fire_status().ok,
		"At 340 metres the real line-of-sight gate denies the old range and allows the fitted focus")


func _test_ecm_damage(flight: Flight) -> void:
	var hull := flight.ship.hull
	if not _expect(_until(flight, func() -> bool: return flight.combat_status().projectile, 7.5)
		and flight.combat_status().shield == 24.0 and flight.ship.hull == hull,
		"With the standard laser selected, two real beams reach the fitted shield before the projectile"):
		return
	if not _expect(_until(flight, func() -> bool: return flight.combat_status().damaged == "ecm", 6.0),
		"The unobstructed, unopposed projectile can damage the ECM while the pulse laser is selected"):
		return
	_expect(not flight.use_ecm() and flight.combat_status().ecm_reason.contains("повреждён")
		and flight.combat_equipment_status().ecm_fitted and flight.ship.hull < hull,
		"An ECM hit disables the installed module without removing it")


func _test_active_projectile(flight: Flight) -> void:
	var initial_hull := flight.ship.hull
	if not _expect(_until(flight, func() -> bool: return flight.combat_status().shield < 36.0, 5.0)
		and flight.combat_status().shield == 30.0 and flight.ship.hull == initial_hull
		and not flight.combat_status().projectile and not flight.use_ecm(),
		"The first actual beam spends six shield without hitting hull or launching a projectile"):
		return
	if not _expect(_until(flight, func() -> bool: return flight.combat_status().projectile, 4.0),
		"The second hostile beam launches a physical projectile"):
		return
	var incoming := flight.combat_status()
	_expect(flight.status_event == "combat_missile" and incoming.shield == 24.0
		and flight.ship.hull == initial_hull and incoming.visible
		and incoming.projectile_distance > 0.0 and is_equal_approx(incoming.velocity.length(), 64.0)
		and not flight.time_status().allowed,
		"Missile launch preserves the second shield hit, missile velocity and the time-acceleration restriction")
	_aim_at_raider(flight)
	if not _expect(flight.fire_action() and flight.combat_status().heat == 40.0 and flight.toggle_time_pause(),
		"Fire an actual shot and pause while both heat and inbound trajectory are active"):
		return
	var snapshot := flight.snapshot()
	if not _expect(Session.save_state(snapshot, INCOMING_SAVE) == OK, "Persist the actual airborne, paused combat frame"):
		return
	var defended := _load(INCOMING_SAVE)
	var impacted := _load(INCOMING_SAVE)
	if defended == null or impacted == null:
		return
	var status := defended.combat_status()
	_expect(defended.clock_status().paused and defended.patrol.enemy_hull == flight.patrol.enemy_hull
		and defended.ship.hull == flight.ship.hull and status.weapon == "focus" and status.heat == 40.0
		and status.shield == 24.0 and status.projectile and status.position.is_equal_approx(incoming.position)
		and status.velocity.is_equal_approx(incoming.velocity) and status.fire_blocked == flight.combat_status().fire_blocked
		and absf(float(defended.snapshot().combat.projectile.expires) - float(snapshot.combat.projectile.expires)) < 0.00000001,
		"A cold paused restore retains hulls, equipped laser, heat, shield, cooldown, projectile and exact expiry")
	var cold_pause := defended.snapshot()
	defended.update(2.0, Vector2.ZERO, 0.0, false, false)
	_expect(defended.snapshot() == cold_pause,
		"A paused combat state freezes the complete projectile and energy model after cold restore")
	_test_invalid_states(snapshot)
	_test_intercept(defended, initial_hull)
	_test_hit_and_repair(impacted, initial_hull)


func _test_intercept(flight: Flight, initial_hull: float) -> void:
	if not _expect(flight.toggle_time_pause() and _until(flight, func() -> bool: return flight.combat_status().ecm_ok, 6.0)
		and flight.combat_status().projectile_distance <= 140.0,
		"The real incoming trajectory enters the ECM distance window after resuming"):
		return
	var shield: float = flight.combat_status().shield
	_expect(flight.use_ecm() and flight.status_event == "combat_ecm" and not flight.combat_status().projectile
		and not flight.use_ecm() and flight.combat_status().shield == shield and flight.ship.hull == initial_hull,
		"A single interception clears the projectile without collateral damage or a duplicate action")
	var intercepted := _copy(flight)
	if intercepted == null:
		return
	_step(intercepted, 2.0)
	_expect(not intercepted.combat_status().projectile and intercepted.ship.hull == initial_hull
		and intercepted.combat_equipment_status().damaged.is_empty(),
		"Resuming an intercepted state cannot recreate or apply the resolved missile")


func _test_hit_and_repair(flight: Flight, initial_hull: float) -> void:
	if not _expect(flight.toggle_time_pause()
		and _until(flight, func() -> bool: return flight.combat_status().damaged == "focus", 6.0),
		"The same unopposed cold trajectory physically hits and damages the selected laser"):
		return
	var hit := flight.combat_status()
	_aim_at_raider(flight)
	_expect(flight.status_event == "combat_missile_hit" and not hit.projectile
		and hit.shield == 0.0 and flight.ship.hull == initial_hull - 4.0
		and hit.fire_blocked.contains("повреждено") and not flight.fire_action(),
		"One 28-point projectile drains 24 shield and applies exactly four hull damage and a module fault")
	var damaged := _copy(flight)
	if damaged != null:
		_tick(damaged)
		_expect(damaged.ship.hull == flight.ship.hull and not damaged.combat_status().projectile
			and damaged.combat_equipment_status().damaged == "focus",
			"A post-impact restore does not insert extra damage and retains the module fault")
	_expect(not flight.service_action("combat_repair") and flight.credits == 70,
		"Repair in flight, even with enough funds, cannot charge or restore a module")
	flight.select_target(HOME_PORT)
	flight.set_autopilot(true)
	if not _expect(_until(flight, func() -> bool: return flight.docked == HOME_PORT, 100.0),
		"Escape the damaged encounter and dock normally for repairs"):
		return
	var hull := flight.ship.hull
	_expect(flight.service_offer("combat_repair").cost == 60 and flight.service_action("combat_repair")
		and flight.credits == 10 and flight.combat_status().weapon == "focus"
		and flight.combat_equipment_status().damaged.is_empty() and flight.combat_status().fire_blocked.is_empty()
		and flight.ship.hull == hull and not flight.service_action("combat_repair") and flight.credits == 10,
		"A station restores the fitted module for 60 once, preserving equipment selection and hull")
	if _expect(Session.save_state(flight.snapshot(), REPAIRED_SAVE) == OK, "Save the returned and repaired ship"):
		var clean := _load(REPAIRED_SAVE)
		if clean != null:
			_expect(clean.docked == HOME_PORT and clean.credits == 10 and clean.combat_equipment_status().damaged.is_empty(),
				"Cold docked restore preserves the repair and final balance")


func _test_invalid_states(active: Dictionary) -> void:
	var wrong_system := active.duplicate(true)
	wrong_system.combat.projectile.system = Catalog.VELAR_SYSTEM
	_expect(not Flight.new().restore(wrong_system), "A saved foreign-system trajectory is rejected")
	var zero_velocity := active.duplicate(true)
	zero_velocity.combat.projectile.velocity = [0.0, 0.0, 0.0]
	_expect(not Flight.new().restore(zero_velocity), "A saved projectile with invalid velocity is rejected")
	var missing_interceptor := active.duplicate(true)
	missing_interceptor.combat.ecm_fitted = false
	missing_interceptor.combat.damaged = "ecm"
	_expect(not Flight.new().restore(missing_interceptor), "A fault on a module the ship does not own is rejected")
	var unmatched_clock := active.duplicate(true)
	unmatched_clock.combat.projectile.expires = float(active.orbit_time) - 1.0
	_expect(not Flight.new().restore(unmatched_clock), "An already expired projectile cannot be restored")
	var parked := Flight.new()
	parked.update(float(active.orbit_time), Vector2.ZERO, 0.0, false, false)
	var valid_parked := parked.snapshot()
	_expect(Flight.new().restore(valid_parked), "An undamaged docked checkpoint is otherwise valid at the same epoch")
	valid_parked.combat = active.combat.duplicate(true)
	_expect(not Flight.new().restore(valid_parked), "A parked ship cannot restore an active hostile projectile")


func _test_projectile_boundaries() -> void:
	var combat := Combat.new()
	var start := Vector3(140.0, 0.0, 0.0)
	_expect(combat.buy("combat_ecm", 90) == 90 and not combat.incoming_shot(start, Vector3.ZERO, 0, 3.0)
		and combat.incoming_shot(start, Vector3.ZERO, 0, 4.0), "Exactly two hostile salvos arm a projectile through the model")
	_expect(not combat.use_ecm(Vector3(-0.001, 0.0, 0.0), 4.0) and combat.use_ecm(Vector3.ZERO, 4.0)
		and not combat.use_ecm(Vector3.ZERO, 4.0), "140 metres is included, any greater range is denied, and the same missile is consumed")
	_expect(not combat.incoming_shot(start, Vector3.ZERO, 0, 5.0)
		and not combat.incoming_shot(start, Vector3.ZERO, 0, 5.05)
		and combat.incoming_shot(start, Vector3.ZERO, 0, 10.0), "The salvo cooldown prevents spawning another projectile immediately")
	var segment := combat.advance_projectile(16.5, 6.5)
	_expect(not segment.is_empty() and segment.from == start and segment.to == Vector3(-244.0, 0.0, 0.0)
		and combat.projectile_status().is_empty() and not combat.use_ecm(Vector3.ZERO, 16.5),
		"An evaded projectile sweeps only its six seconds of travel and expires without a second sweep")
	_expect(combat.advance_projectile(17.0, 0.5).is_empty(), "An expired projectile cannot collide in a later frame")


func _test_parking(site: int) -> void:
	var flight := Flight.new()
	var station := Catalog.is_port(site)
	if not _expect(Fixture.depart(flight) and flight.select_target(site), "Depart normally toward parking site %d" % site):
		return
	flight.set_autopilot(true)
	var finish_approach := func() -> bool:
		if station:
			return flight.autopilot_phase == "Стыковка" and flight.docking_guidance().range <= 5.0
		var surface := flight.surface_status()
		return flight.autopilot_phase == "Посадка" and surface.near and surface.gear_ok and surface.altitude <= 14.0
	if not _expect(_until(flight, finish_approach, 100.0), "Reach the normal final approach to site %d" % site):
		return
	# Place a pending projectile beyond immediate collision range to isolate the capture transition.
	var source := flight.position + Vector3.UP * 260.0
	flight.combat.incoming_shot(source, flight.position, flight.system_id, flight.orbit_time)
	if not _expect(flight.combat.incoming_shot(source, flight.position, flight.system_id, flight.orbit_time)
		and flight.combat_status().projectile, "Prepare a hazardous but unexpired final approach at site %d" % site):
		return
	var active_on_entry := false
	for _frame in range(ceili(5.0 / STEP)):
		active_on_entry = flight.combat_status().projectile
		_tick(flight)
		if flight.docked >= 0 or flight.landed:
			break
	var parked := flight.docked if station else flight.landed_site
	_expect(parked == site and active_on_entry and not flight.combat_status().projectile,
		"Actual parking at site %d clears a missile active in the preceding frame" % site)
	var resumed := _copy(flight)
	if resumed != null:
		_expect((resumed.docked if station else resumed.landed_site) == site and not resumed.combat_status().projectile,
			"Parking at site %d remains valid after restore" % site)


func _load(path: String) -> Flight:
	var flight := Flight.new()
	return flight if _expect(flight.restore(Session.load_state(path)), "Load an independent flight instance from %s" % path) else null


func _copy(source: Flight) -> Flight:
	var flight := Flight.new()
	return flight if _expect(flight.restore(source.snapshot()), "Copy an actual flight checkpoint independently") else null


func _until(flight: Flight, reached: Callable, seconds: float) -> bool:
	for _frame in range(ceili(seconds / STEP)):
		if reached.call():
			return true
		_tick(flight)
	return reached.call()


func _step(flight: Flight, seconds: float) -> void:
	for _frame in range(roundi(seconds / STEP)):
		_tick(flight)


func _tick(flight: Flight) -> void:
	flight.update(STEP, Vector2.ZERO, 0.0, false, false)


func _raider(flight: Flight) -> Dictionary:
	for contact: Dictionary in flight.traffic_contacts():
		if contact.role == "raider":
			return contact
	return {}


func _aim_at_raider(flight: Flight) -> void:
	var contact := _raider(flight)
	if contact.is_empty():
		return
	var aim := flight.position.direction_to(contact.position)
	flight.yaw = atan2(-aim.x, -aim.z)
	flight.pitch = clampf(asin(aim.y), -Flight.MAX_PITCH, Flight.MAX_PITCH)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append("FAIL: " + description)
	return condition
