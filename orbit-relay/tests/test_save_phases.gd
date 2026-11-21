extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Expedition := preload("res://scripts/expedition.gd")
const Factions := preload("res://scripts/faction_fronts.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const OrbitRelay := preload("res://main.tscn")
const Patrol := preload("res://scripts/patrol_encounter.gd")
const Session := preload("res://scripts/session_io.gd")
const STEP := Fixture.STEP
const AIRBORNE_SAVE := "user://save-phases.json"
const HEATHER := Catalog.HEATHER_SYSTEM

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_manual_and_local_guidance()
	await _test_paused_autopilot_boot()
	_test_unpowered_modes()
	_test_science_and_drill_guidance()
	_test_patrol_timing()
	_test_convoy_timing()
	print("Flight phase persistence: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_manual_and_local_guidance() -> void:
	var manual := Flight.new()
	if _expect(Fixture.depart(manual), "Depart by the ordinary launch sequence before saving manually controlled flight"):
		manual.change_throttle(0.28)
		_step(manual, 1.0)
		var restored := _round_trip(manual, [], false)
		if restored != null:
			_expect(restored.throttle == 0.28 and restored.status_event.is_empty() and not restored.autopilot,
				"Manual throttle persists exactly without a spurious assistant notice")

	var rendezvous := Flight.new()
	if _expect(Fixture.depart(rendezvous) and rendezvous.start_rendezvous(1), "Start the actual rendezvous controller"):
		_step(rendezvous, 0.5)
		var restored := _round_trip(rendezvous, ["rendezvous"], true)
		if restored != null:
			_expect(not restored.rendezvous_active and restored.target == rendezvous.target,
				"The helper clears at restart while retaining the chosen target")

	var orbit := _at_port(Flight.new(), Catalog.FRINGE_ARRIVAL_PORT)
	if orbit == null or not _expect(Fixture.depart(orbit), "Leave the Kromka berth for the same physical orbital setup"):
		return
	var star := Catalog.FRINGE_STAR_ID
	orbit.position = orbit.target_position(star) + Vector3.BACK * 620.0
	orbit.velocity = Vector3(0.67, 0.74, 0.0).normalized() * 2.4 + Vector3.BACK * 0.85
	orbit.yaw = 0.0
	orbit.pitch = 0.0
	orbit.roll = 0.0
	if _expect(orbit.start_orbit_maneuver(star), "Engage a real inclined circularization maneuver"):
		_step(orbit, 0.25)
		var restored := _round_trip(orbit, ["orbit_maneuver"], true)
		if restored != null:
			_expect(not restored.orbit_maneuver and not restored.flight_assist,
				"The interrupted orbital maneuver retains the proper inertial flight mode")


func _test_paused_autopilot_boot() -> void:
	var flight := Flight.new()
	if not _expect(flight.select_target(1) and Fixture.depart(flight), "Fly a genuine route before saving the automatic pilot"):
		return
	flight.set_autopilot(true)
	if not _expect(_until(flight, func() -> bool: return flight.autopilot and flight.throttle > 0.05, 12.0)
		and flight.toggle_time_pause(), "Pause while the independent automatic controller is applying actual thrust"):
		return
	var former_throttle := flight.throttle
	var saved := flight.snapshot()
	if not _expect(saved.throttle == 0.0 and saved.resume.interrupted == ["autopilot"]
		and flight.throttle == former_throttle and flight.autopilot and Session.save_state(saved) == OK,
		"Saved automation neutralizes only the serialized throttle and records the reason without changing the live controller"):
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := OrbitRelay.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	var cold: Flight = game.flight
	_expect(cold.time_paused and not cold.autopilot and cold.throttle == 0.0 and cold.target == flight.target
		and game._hud._notice_panel.is_visible_in_tree() and game._hud._notice.text.to_lower().contains("автопилот"),
		"The real boot displays the interrupted autopilot notice immediately even with calendar pause retained")
	var clean := cold.snapshot()
	game._physics_process(2.0)
	_expect(cold.snapshot() == clean and clean.resume.interrupted.is_empty() and cold.status_event.is_empty(),
		"The startup notice is consumed once and pause prevents any further flight update")
	var damaged := saved.duplicate(true)
	damaged.resume.interrupted.append("unknown_automation")
	_expect(not cold.restore(damaged) and cold.snapshot() == clean,
		"An unknown saved interruption cannot partially overwrite the valid paused flight")
	damaged.resume.interrupted = ["autopilot", "autopilot"]
	_expect(not cold.restore(damaged) and cold.snapshot() == clean,
		"Duplicating a valid interruption cannot duplicate the notice or mutate the existing flight")
	viewport.queue_free()
	await process_frame


func _test_unpowered_modes() -> void:
	var accelerated := Flight.new()
	if _expect(accelerated.cycle_time_scale() and accelerated.cycle_time_scale() and accelerated.time_scale == 16,
		"Use the actual time controls to create a resumable previous acceleration"):
		var restored := _round_trip(accelerated, ["time_scale"], false)
		if restored != null:
			_expect(restored.time_scale == 1 and restored.docked == 0, "Time acceleration is reported but does not silently resume")

	var sync := Flight.new()
	if _expect(Fixture.depart(sync) and sync.select_target(0), "Approach the real rotating berth for synchronization"):
		sync.position = sync.docking_position(0) + Vector3.BACK * 24.0
		sync.velocity = sync.target_velocity(0)
		sync.yaw = 0.0
		sync.pitch = 0.0
		if _expect(sync.toggle_dock_sync(), "Activate actual roll-only docking assistance"):
			sync.change_throttle(0.17)
			var restored := _round_trip(sync, ["dock_roll_sync"], false)
			if restored != null:
				_expect(restored.dock_roll_sync == -1 and restored.throttle == 0.17,
					"The saved roll synchronization clears without changing genuine manual thrust")

	var charger := Flight.new()
	if _expect(Fixture.depart(charger) and charger.plan_jump(Catalog.VELAR_SYSTEM), "Set a real planned jump from the home berth"):
		charger.change_throttle(0.18)
		if _expect(_until(charger, func() -> bool: return charger.jump_status(Catalog.VELAR_SYSTEM).ok, 15.0)
			and charger.start_jump(), "Start an actual uncommitted jump charge"):
			var restored := _round_trip(charger, ["unpaid_jump_charge"], false)
			if restored != null:
				_expect(restored.jump_target == Catalog.VELAR_SYSTEM and restored.jump_seconds_left == 0.0
					and restored.ship.jump_fuel == charger.ship.jump_fuel,
					"The unpaid charge safely clears with destination and full fare reserve retained")
			if _expect(_until(charger, func() -> bool: return charger.jump_progress_status().is_transit, 4.0),
				"Let the otherwise unchanged warm charge commit the actual fare"):
				var paid := _round_trip(charger, [], false)
				if paid != null:
					_expect(paid.jump_progress_status().is_transit and paid.ship.jump_fuel == charger.ship.jump_fuel
						and _until(paid, func() -> bool: return paid.system_id == Catalog.VELAR_SYSTEM, 3.0),
						"Paid transit still resumes instead of being treated as a temporary charge")

	var scooper := Flight.new()
	if _expect(Fixture.depart(scooper) and scooper.select_target(Catalog.STAR_ID), "Approach the normal stellar collection zone"):
		var star := Catalog.STAR_ID
		scooper.position = scooper.target_position(star) + Vector3.BACK * 315.0
		scooper.velocity = scooper.target_velocity(star)
		if _expect(scooper.scoop_status().ok and scooper.scoop_action(), "Activate the existing installed stellar scoop"):
			var restored := _round_trip(scooper, ["scoop"], false)
			if restored != null:
				_expect(not restored.scooping and restored.target == star,
					"Cold restart closes the temporary scoop without deleting its actual flight target")


func _test_science_and_drill_guidance() -> void:
	var science := Flight.new()
	if _expect(science.project_action() and _jump(science, HEATHER) and science.project_action() and science.project_course,
		"Follow a real expedition's physical first survey after a paid away-system jump"):
		_step(science, 0.25)
		var restored := _round_trip(science, ["project_course"], true)
		if restored != null:
			_expect(not restored.project_course and restored.frontier_status().phase == Expedition.SURVEY
				and restored.frontier_status().site == science.frontier_status().site,
				"Clearing the automatic survey course preserves expedition and target progress")

	var drill := Flight.new()
	if not _expect(drill.select_target(2) and Fixture.depart(drill), "Depart for the physical asteroid and its detachable drill"):
		return
	drill.set_autopilot(true)
	if _expect(_until(drill, func() -> bool: return drill.landed_site == 2, 125.0) and drill.leave_remote_rig()
		and drill.dock_action() and drill.track_remote_rig() and drill.autopilot and drill.remote_rig_status().navigating,
		"Travel, land, leave the drill and activate the specific returned drill approach"):
		var restored := _round_trip(drill, ["rig_approach"], true)
		if restored != null:
			_expect(restored.remote_rig_status().active and not restored.remote_rig_status().navigating and not restored.autopilot,
				"Cold reload drops both route controls but does not remove the actual working drill")


func _test_patrol_timing() -> void:
	var patrol := Flight.new()
	if not _expect(patrol.patrol_action() and Fixture.depart(patrol) and patrol.patrol_action()
		and patrol.patrol_course, "Begin the real outward pursuit before testing combat phase clocks"):
		return
	_step(patrol, 1.0)
	var paused_route := _round_trip(patrol, ["patrol_course"], true)
	if paused_route != null:
		_expect(not paused_route.patrol_course and paused_route.patrol.phase == Patrol.OUTBOUND
			and paused_route.patrol.origin == patrol.patrol.origin,
			"The temporary patrol course resets without abandoning the actual accepted contract")
	if not _expect(_until(patrol, func() -> bool: return patrol.patrol.phase == Patrol.ENGAGED, 50.0),
		"Continue the unmodified warm chase into an actual combat phase"):
		return
	_step(patrol, 2.70)
	_aim_at(patrol, "raider-%d" % patrol.patrol.origin)
	if not _expect(patrol.fire_action(), "Fire an actual shot shortly before the raider's first damaging salvo"):
		return
	var saved := patrol.snapshot()
	var cold := _round_trip(patrol, [], false)
	if cold == null:
		return
	var attack := float(saved.resume.patrol_clock.attack)
	var shot := float(saved.resume.patrol_clock.shot)
	_expect(attack > 0.10 and attack < 0.45 and shot > 0.30 and shot <= 0.45
		and _same_clock(cold.patrol.combat_clock(), saved.resume.patrol_clock)
		and cold.ship.hull == patrol.ship.hull and not cold.fire_status().ok,
		"Both countdowns are measured from a real live shot and preserved at cold load")
	var original_hull := patrol.ship.hull
	var warm_frame := _next_damage_frame(patrol, 60)
	var cold_frame := _next_damage_frame(cold, 60)
	_expect(warm_frame > 0 and cold_frame == warm_frame and patrol.ship.hull == original_hull - 6.0
		and cold.ship.hull == patrol.ship.hull,
		"Reloading cannot postpone or duplicate the next actual enemy hit")
	var malformed := saved.duplicate(true)
	malformed.resume.patrol_clock.attack = -1.0
	var retained := cold.snapshot()
	_expect(not cold.restore(malformed) and cold.snapshot() == retained,
		"An invalid partial combat timer is rejected without altering the good continuation")


func _test_convoy_timing() -> void:
	var sponsor := Flight.new()
	var state := sponsor.snapshot()
	state.expedition.projects[0] = {"phase": Expedition.COMPLETE, "sponsor_port": 0, "sponsor": 0,
		"scan_index": Expedition.SURVEY_TOTAL, "build_index": Expedition.BUILD_TOTAL}
	var front := Factions.new()
	front.commission(HEATHER, 0, 0.0)
	state.factions = front.snapshot()
	sponsor.freight.activate_frontier(HEATHER, 0.0)
	state.freight = sponsor.freight.snapshot()
	if not _expect(sponsor.restore(state), "Seed the same valid commissioned-scene fixture as the strategic convoy tests"):
		return
	_tick(sponsor, Factions.FOUNDING_GRACE + STEP)
	var flight := _at_port(sponsor, 10)
	if flight == null:
		return
	var offer := {}
	for order: Dictionary in flight.convoy_offers():
		if order.kind == "intercept" and order.system == HEATHER:
			offer = order
			break
	if not _expect(not offer.is_empty() and flight.convoy_action(HEATHER, offer.id) and _jump(flight, HEATHER)
		and flight.convoy_action() and flight.convoy_course, "Take an actual hostile convoy assignment and follow it in its remote sector"):
		return
	if not _expect(_until(flight, func() -> bool: return flight.fire_status().ok, 50.0) and flight.fire_action(),
		"Fly to actual firing range and hit the convoy with its defence timer running"):
		return
	var saved := flight.snapshot()
	var cold := _round_trip(flight, ["convoy_course"], true)
	if cold == null:
		return
	_expect(not cold.convoy_course and cold.convoy_status().active and cold.convoy_status().enemy_hull == flight.convoy_status().enemy_hull
		and _same_clock(cold.convoy_order.combat_clock(), saved.resume.convoy_clock)
		and float(saved.resume.convoy_clock.shot) > 0.0 and not cold.fire_status().ok,
		"Cold convoy gives up automatic guidance but retains its actual target, hull and both cooldowns")
	var malformed := saved.duplicate(true)
	malformed.resume.convoy_clock.shot = 2.0
	var retained := cold.snapshot()
	_expect(not cold.restore(malformed) and cold.snapshot() == retained,
		"Convoy restore rejects a fabricated overlong shot cooldown without changing the good flight")


func _round_trip(flight: Flight, expected: Array[String], powered: bool) -> Flight:
	var saved := flight.snapshot()
	var rows: Array = saved.resume.interrupted
	var cold := Flight.new()
	if not _expect(rows.size() == expected.size() and expected.all(func(mode: String) -> bool: return mode in rows)
		and saved.throttle == (0.0 if powered else flight.throttle)
		and Session.save_state(saved, AIRBORNE_SAVE) == OK and cold.restore(Session.load_state(AIRBORNE_SAVE)),
		"Persist and restore the real state for %s" % [expected]):
		return null
	_expect(cold.position.is_equal_approx(flight.position) and cold.velocity.is_equal_approx(flight.velocity)
		and cold.throttle == saved.throttle and absf(cold.orbit_time - flight.orbit_time) < 0.00000001
		and (cold.status_event == "flight_restore_interruptions" if not rows.is_empty() else cold.status_event.is_empty()),
		"Saved intent leaves measured flight and emits only its required interruption notice")
	return cold


func _same_clock(actual: Dictionary, expected: Dictionary) -> bool:
	return absf(float(actual.shot) - float(expected.shot)) < 0.00000001 \
		and absf(float(actual.attack) - float(expected.attack)) < 0.00000001


func _at_port(prior: Flight, port: int) -> Flight:
	var saved := prior.snapshot()
	var docked := Flight.new()
	docked.orbit_time = prior.orbit_time
	var position := docked.target_contact(port)
	saved.merge({"system_id": Catalog.system_of_site(port), "docked": port, "target": port,
		"position": [position.x, position.y, position.z]}, true)
	return docked if _expect(docked.restore(saved), "Place the scoped fixture at the actual moving berth %d" % port) else null


func _jump(flight: Flight, destination: int) -> bool:
	if (flight.docked >= 0 and not Fixture.depart(flight)) or not flight.plan_jump(destination):
		return false
	flight.change_throttle(0.18)
	return _until(flight, func() -> bool: return flight.jump_status(destination).ok, 28.0) and flight.start_jump() \
		and _until(flight, func() -> bool: return flight.system_id == destination, 5.0)


func _aim_at(flight: Flight, id: String) -> void:
	for contact: Dictionary in flight.traffic_contacts():
		if contact.id == id:
			var aim := flight.position.direction_to(contact.position)
			flight.yaw = atan2(-aim.x, -aim.z)
			flight.pitch = clampf(asin(aim.y), -Flight.MAX_PITCH, Flight.MAX_PITCH)
			return


func _next_damage_frame(flight: Flight, maximum: int) -> int:
	var hull := flight.ship.hull
	for frame in range(1, maximum + 1):
		_tick(flight)
		if flight.ship.hull < hull:
			return frame
	return -1


func _until(flight: Flight, reached: Callable, seconds: float) -> bool:
	for _frame in range(ceili(seconds / STEP)):
		if reached.call():
			return true
		_tick(flight)
	return reached.call()


func _step(flight: Flight, seconds: float) -> void:
	for _frame in range(roundi(seconds / STEP)):
		_tick(flight)


func _tick(flight: Flight, delta := STEP) -> void:
	flight.update(delta, Vector2.ZERO, 0.0, false, false)


func _expect(value: bool, description: String) -> bool:
	_checks += 1
	if not value:
		_failures.append("FAIL: " + description)
	return value
