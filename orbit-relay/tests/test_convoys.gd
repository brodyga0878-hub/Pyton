extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Expedition := preload("res://scripts/expedition.gd")
const FactionFronts := preload("res://scripts/faction_fronts.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const OrbitRelay := preload("res://main.tscn")
const HOME := Catalog.HOME_SYSTEM
const HEATHER := Catalog.HEATHER_SYSTEM
const STEP := 1.0 / 30.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var campaign := _campaign()
	if not campaign.is_empty():
		_test_offers_and_migration(campaign)
		_test_escort(campaign)
		_test_interception(campaign)
		_test_expiry(campaign)
		await _test_board(campaign)
	print("Convoy orders integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _campaign() -> Dictionary:
	# Prepare a completed founding project and let the normal flight clock start the war.
	var flight := Flight.new()
	var snapshot := flight.snapshot()
	snapshot.expedition.projects[0] = {"phase": Expedition.COMPLETE, "sponsor_port": 0, "sponsor": 0,
		"scan_index": Expedition.SURVEY_TOTAL, "build_index": Expedition.BUILD_TOTAL}
	var fronts := FactionFronts.new()
	if not _expect(fronts.commission(HEATHER, 0, 0.0), "Prepare the sponsor's commissioned station"):
		return {}
	snapshot.factions = fronts.snapshot()
	if not _expect(flight.restore(snapshot), "Load a valid completed expedition through the flight save path"):
		return {}
	_tick(flight, FactionFronts.FOUNDING_GRACE + STEP)
	if not _expect(flight.factions.active_convoys(HEATHER).size() == 2 and flight.station_operational(Catalog.HEATHER_PORT),
		"The war sends two real convoys after time passes at the sponsor's dock"):
		return {}
	return flight.snapshot()


func _test_offers_and_migration(campaign: Dictionary) -> void:
	var flight := _restore(campaign, "Start at a faction port with a war underway")
	var escort := _offer(flight, "escort")
	var intercept := _offer(flight, "intercept")
	if not _expect(flight.convoy_offers().size() == 2 and not escort.is_empty() and not intercept.is_empty(),
		"The port offers escort for its faction and interception for its opponent"):
		return
	_expect(escort.faction == 0 and intercept.faction == 0 and escort.target_faction == 0
		and intercept.target_faction == 1 and escort.system == HEATHER and intercept.system == HEATHER
		and escort.id != intercept.id and escort.reward > 0 and intercept.reward > 0,
		"Offers identify the actual sponsor, convoy, allegiance and payout")
	var before := flight.snapshot()
	_expect(not flight.convoy_action(HEATHER, "missing-convoy")
		and not flight.convoy_action(Catalog.LIMIT_SYSTEM, escort.id) and flight.snapshot() == before,
		"Orders cannot be taken for a fabricated convoy or a concealed sector")
	_expect(not flight.factions.escort_convoy(HEATHER, intercept.id, 0)
		and flight.factions.intercept_convoy(HEATHER, escort.id, 0).is_empty() and flight.snapshot() == before,
		"An enemy convoy cannot be escorted for this faction and an ally cannot be claimed as an interception")
	_expect(flight.dock_action() and flight.convoy_offers().is_empty()
		and not flight.convoy_action(HEATHER, escort.id),
		"An order must be booked at an operational dock")
	var old := _json(campaign)
	old.schema = 11
	old.erase("convoy_order")
	for record: Dictionary in old.factions.frontiers:
		for convoy: Dictionary in record.convoys:
			convoy.erase("assistance")
	var migrated := Flight.new()
	_expect(migrated.restore(old) and migrated.snapshot().schema == Flight.SAVE_SCHEMA
		and migrated.convoy_status().phase == "idle" and migrated.convoy_offers().size() == 2
		and migrated.factions.convoy(HEATHER, escort.id).assistance == "none"
		and is_equal_approx(migrated.factions.convoy(HEATHER, escort.id).due_at, escort.deadline),
		"Version 11 keeps its active war, convoy schedules and newfound ports without inventing player orders")


func _test_escort(campaign: Dictionary) -> void:
	var flight := _restore(campaign, "Prepare an escort departure from the sponsor's core system")
	var offer := _offer(flight, "escort")
	if not _expect(not offer.is_empty() and flight.convoy_action(HEATHER, offer.id)
		and not flight.convoy_status().local and flight.jump_target == HEATHER,
		"Taking the escort order at a real dock plots an interstellar approach"):
		return
	var credit_before := flight.credits
	_expect(not flight.convoy_action(HEATHER, offer.id)
		and flight.convoy_status().id == offer.id and flight.credits == credit_before,
		"The same convoy order cannot be accepted twice")
	if not _expect(_jump_to_heather(flight) and flight.convoy_action() and flight.convoy_course,
		"The full jump arrives in the war zone and enables flight assistance"):
		return
	var original := _contact(flight, offer.id)
	if not _expect(not original.is_empty() and _wait_for(flight, 55.0,
		func() -> bool: return float(flight.convoy_status().formation_time) >= 2.0),
		"The assist reaches a real moving convoy and holds formation (%s)" % flight.status_message):
		return
	var moving := _contact(flight, offer.id)
	_expect(not moving.is_empty() and moving.position.distance_to(original.position) > 25.0
		and flight.position.distance_to(moving.position) < 96.1 and flight.velocity.distance_to(moving.velocity) < 25.1,
		"Formation follows the convoy's moving trajectory and matches its speed")
	_expect(not flight.fire_action() and flight.combat_beams().is_empty(),
		"A formation order cannot fire at the convoy it protects")
	var saved := _json(flight.snapshot())
	var resumed := _restore(saved, "Restore an airborne ship midway through escort formation")
	if not _expect(resumed.convoy_status().phase == "active"
		and is_equal_approx(resumed.convoy_status().formation_time, flight.convoy_status().formation_time)
		and resumed.convoy_action() and resumed.convoy_course,
		"Flight save keeps elapsed formation and allows assistance to restart"):
		return
	var malformed := saved.duplicate(true)
	malformed.convoy_order.target_faction = 1
	var intact := resumed.snapshot()
	_expect(not resumed.restore(malformed) and resumed.snapshot() == intact,
		"A saved escort cannot switch to protecting the opposing faction")
	if not _expect(_wait_for(resumed, 18.0, func() -> bool: return resumed.convoy_status().phase == "escorted")
		and resumed.credits == credit_before and resumed.factions.convoy(HEATHER, offer.id).assistance == "escort",
		"Completing formation secures the convoy while payout waits for delivery (%s)" % resumed.status_message):
		return
	if not _expect(_wait_for(resumed, float(offer.deadline) - resumed.orbit_time + 1.0,
		func() -> bool: return resumed.convoy_status().phase == "succeeded")
		and resumed.factions.convoy(HEATHER, offer.id).stage == "delivered"
		and resumed.credits == credit_before + int(offer.reward),
		"An assisted delivery pays the agreed reward and brings the cargo to the station"):
		return
	var paid := _restore(_json(resumed.snapshot()), "Cold restart after a successful escort")
	_tick(paid, 1.0)
	_expect(paid.convoy_status().phase == "succeeded" and paid.credits == resumed.credits
		and not paid.convoy_action(HEATHER, offer.id),
		"Restarting after delivery and replaying its order cannot pay again")


func _test_interception(campaign: Dictionary) -> void:
	var flight := _at_port(campaign, Catalog.VELAR_SYSTEM, 10)
	var offer := _offer(flight, "intercept")
	if not _expect(not offer.is_empty() and offer.faction == 1 and offer.target_faction == 0
		and flight.convoy_action(HEATHER, offer.id) and _jump_to_heather(flight) and flight.convoy_action(),
		"A different faction can commission interception of its rival's convoy"):
		return
	if not _expect(_wait_for(flight, 45.0, func() -> bool: return flight.fire_status().ok),
		"Flight assistance brings a moving target into the normal fire control (%s)" % flight.fire_status().reason):
		return
	var contact := _contact(flight, offer.id)
	if not _expect(not contact.is_empty(), "Identify the actual tactical convoy before firing"):
		return
	var direction: Vector3 = contact.position - flight.position
	_aim(flight, -direction)
	_expect(not flight.fire_status().ok and not flight.fire_action() and flight.combat_beams().is_empty(),
		"The common weapon action rejects firing while facing away")
	_aim(flight, direction)
	var old_hull: float = flight.convoy_status().enemy_hull
	if not _expect(flight.fire_status().ok and flight.fire_action()
		and flight.convoy_status().enemy_hull < old_hull and flight.convoy_status().enemy_hull > 0.0,
		"Aimed fire damages the hostile convoy through the same weapon action as patrols"):
		return
	var beams := flight.combat_beams()
	_expect(beams.size() == 1 and not beams[0].hostile and beams[0].to.distance_to(contact.position) < 0.1
		and not flight.fire_action(),
		"The shot uses the visible beam at the target and immediate repeat is blocked by cooldown")
	var partial_hull: float = flight.convoy_status().enemy_hull
	var credit_before := flight.credits
	var resumed := _restore(_json(flight.snapshot()), "Restore an interception after its first hit")
	_expect(is_equal_approx(resumed.convoy_status().enemy_hull, partial_hull)
		and resumed.credits == credit_before and resumed.convoy_action(),
		"Saved hull damage resumes before any interception payout")
	for _shot in range(8):
		if resumed.convoy_status().phase != "active":
			break
		if not _wait_for(resumed, 5.0, func() -> bool: return resumed.fire_status().ok):
			break
		resumed.fire_action()
	var result := resumed.factions.convoy(HEATHER, offer.id)
	if not _expect(resumed.convoy_status().phase == "succeeded" and not result.is_empty()
		and result.stage == "intercepted" and result.assistance == "intercept"
		and resumed.credits == credit_before + int(offer.reward) and _contact(resumed, offer.id).is_empty(),
		"Disabling the moving convoy changes the strategic outcome, removes it from traffic and pays once (%s)" % resumed.status_message):
		return
	var paid := _restore(_json(resumed.snapshot()), "Cold restart after an interception payout")
	_tick(paid, 1.0)
	_expect(paid.credits == resumed.credits and paid.convoy_status().phase == "succeeded"
		and not paid.fire_action() and not paid.convoy_action(HEATHER, offer.id),
		"Another shot or duplicate order after a cold restart cannot repeat interception pay")


func _test_expiry(campaign: Dictionary) -> void:
	var flight := _restore(campaign, "Prepare an unattended order at a remote dock")
	var offer := _offer(flight, "escort")
	if not _expect(not offer.is_empty() and flight.convoy_action(HEATHER, offer.id)
		and flight.cycle_time_scale() and flight.cycle_time_scale(),
		"A player can leave an assigned order unattended while time passes"):
		return
	var credits := flight.credits
	var remaining := float(offer.deadline) - flight.orbit_time
	_tick(flight, (remaining - 0.25) / flight.time_scale)
	_expect(flight.convoy_status().phase == "active" and flight.credits == credits,
		"The pending order stays valid just before its deadline")
	_tick(flight, 0.5 / flight.time_scale)
	_expect(flight.convoy_status().phase == "failed" and flight.credits == credits
		and not flight.convoy_action(HEATHER, offer.id)
		and flight.factions.convoy(HEATHER, offer.id).stage != "en_route",
		"A missed deadline expires the order while the NPC convoy resolves autonomously")


func _test_board(campaign: Dictionary) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := OrbitRelay.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = _restore(campaign, "Load a campaign into the playable scene")
	game._update_display(0.0)
	await process_frame
	_tap(viewport, game._hud._actions["frontier"], "Open the frontier board through a real touch")
	await process_frame
	_tap(viewport, game._frontier._convoy_tab, "Open the convoy-order tab through a real touch")
	await process_frame
	if _expect(not game._frontier._offer_rows.is_empty(), "The order tab lists available contracts"):
		_tap(viewport, game._frontier._offer_rows[0].button, "Take one of the convoy orders by touch")
		await process_frame
		_expect(game.flight.convoy_status().phase == "active" and game.flight.jump_target == HEATHER
			and game.flight.docked == 0 and SessionIO.load_state().get("convoy_order") == _json(game.flight.snapshot()).convoy_order,
			"The board plots an accepted order and commits it to the real session save before launch")
	viewport.queue_free()
	await process_frame


func _offer(flight: Flight, kind: String) -> Dictionary:
	for offer: Dictionary in flight.convoy_offers():
		if offer.kind == kind:
			return offer
	return {}


func _contact(flight: Flight, id: String) -> Dictionary:
	for contact: Dictionary in flight.traffic_contacts():
		if contact.id == id:
			return contact
	return {}


func _restore(state: Dictionary, description: String) -> Flight:
	var flight := Flight.new()
	_expect(flight.restore(state), description)
	return flight


func _at_port(state: Dictionary, system: int, port: int) -> Flight:
	var replacement := state.duplicate(true)
	var probe := Flight.new()
	probe.orbit_time = float(replacement.orbit_time)
	var position := probe.docking_position(port)
	replacement.merge({"system_id": system, "docked": port, "target": port,
		"position": [position.x, position.y, position.z]}, true)
	return _restore(replacement, "Start docked at the other faction's station")


func _jump_to_heather(flight: Flight) -> bool:
	if flight.jump_target != HEATHER or not flight.dock_action():
		return false
	flight.change_throttle(0.18)
	if not _wait_for(flight, 15.0, func() -> bool: return flight.jump_status(HEATHER).ok) or not flight.start_jump():
		return false
	return _wait_for(flight, 3.0, func() -> bool: return flight.system_id == HEATHER)


func _wait_for(flight: Flight, seconds: float, predicate: Callable) -> bool:
	for _frame in range(maxi(0, ceili(seconds / STEP))):
		if predicate.call():
			return true
		_tick(flight)
	return predicate.call()


func _tick(flight: Flight, delta: float = STEP) -> void:
	flight.update(delta, Vector2.ZERO, 0.0, false, false)


func _aim(flight: Flight, direction: Vector3) -> void:
	var aim := direction.normalized()
	flight.yaw = atan2(-aim.x, -aim.z)
	flight.pitch = clampf(asin(aim.y), -Flight.MAX_PITCH, Flight.MAX_PITCH)


func _tap(viewport: SubViewport, button: Button, description: String) -> void:
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, description):
		return
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 7
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		viewport.push_input(event, true)


func _json(state: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(state, "", true, true)) as Dictionary


func _expect(passed: bool, description: String) -> bool:
	_checks += 1
	if not passed:
		_failures.append(description)
	return passed
