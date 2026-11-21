extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Session := preload("res://scripts/session_io.gd")
const Missing := preload("res://scripts/missing_person.gd")
const MainScript := preload("res://scripts/main.gd")
const STEP := Fixture.STEP

var _checks := 0
var _failures := 0


class BoardGame extends MainScript:
	var isolated_save := "user://missing-board-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]

	func _save(_keep_backup: bool = false) -> void:
		SessionIO.save_state(flight.snapshot(), isolated_save)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var waiting := _earn_notice()
	if waiting != null:
		await _test_actual_board(waiting)
		_test_fast_wait(waiting.snapshot())
		var clue := _obtain_clue(waiting)
		if clue != null:
			_test_information_only(clue.snapshot())
			var occupied := _obtain_rescue(clue)
			if not occupied.is_empty():
				_test_rescue_payment(occupied)
				_test_expired_evacuation(occupied)
	print("Missing person integration: %d checks, %d failures" % [_checks, _failures])
	quit(int(_failures > 0))


func _earn_notice() -> Flight:
	var pilot := Flight.new()
	if not _expect(pilot.search_status().stage == "locked" and not pilot.search_action("accept")
		and not pilot.search_action("follow"), "A new pilot cannot reveal or claim the notice before an ordinary delivery"):
		return null
	if not _expect(pilot.contract_action() and _visit(pilot, 1) and pilot.contract_action() and pilot.deliveries == 1,
		"Complete the real first freight delivery to earn access"):
		return null
	if not _expect(pilot.search_status().stage == "offer" and not pilot.search_action("accept")
		and pilot.search_action("follow") and pilot.planned_target == Missing.ISSUER and _visit(pilot, Missing.ISSUER),
		"Only the actual issuer accepts the search, and the notice can plot the route back"):
		return null
	return pilot


func _obtain_clue(pilot: Flight) -> Flight:
	if not _expect(pilot.search_action("accept") and not pilot.search_action("accept")
		and pilot.search_status().route_site == Missing.REGISTRY and not pilot.search_action("clue")
		and not pilot.search_action("inspect") and pilot.search_action("follow"),
		"Acceptance reveals the registry clue, but inspection and clue actions require their physical locations"):
		return null
	var cold := _round_trip(pilot.snapshot())
	if not _expect(cold != null and cold.search_status().stage == "clue"
		and cold.planned_route().goal == Catalog.VELAR_SYSTEM and _jump(cold, Catalog.VELAR_SYSTEM)
		and _visit(cold, Missing.REGISTRY) and cold.search_action("clue"),
		"Recover the accepted case and use normal departure, jump and docking to read the actual registry"):
		return null
	if not _expect(cold.search_status().stage == "inspect" and cold.search_status().route_site == Missing.SEARCH_SITE
		and not cold.search_action("inspect") and cold.service_action("jump_refuel"),
		"The registry reveals Terrace without letting a docked pilot pretend to inspect its surface"):
		return null
	return cold


func _test_fast_wait(state: Dictionary) -> void:
	var pilot := _round_trip(state)
	if not _expect(pilot != null and pilot.search_action("accept"), "Prepare a live search deadline while berthed"):
		return
	for _attempt in range(4):
		if pilot.time_scale > Flight.TIME_SCALES[-1] or not pilot.cycle_time_scale():
			break
	if not _expect(pilot.time_scale > Flight.TIME_SCALES[-1], "The ordinary berth control can enter accelerated waiting"):
		return
	var deadline := float(pilot.search_status().deadline)
	_tick(pilot, (deadline - pilot.orbit_time + 60.0) / pilot.time_scale)
	_expect(pilot.time_scale == 1 and pilot.orbit_time < deadline and pilot.search_status().stage == "clue",
		"High-speed waiting pauses at normal speed just before the search deadline")
	_tick(pilot, deadline - pilot.orbit_time)
	_expect(pilot.search_status().stage == "expired" and pilot.status_event == "missing_expired"
		and not pilot.search_action("submit"), "Ordinary passage across the deadline can still close the case without payment")


func _test_information_only(state: Dictionary) -> void:
	var pilot := _round_trip(state)
	var group_port := _two_seat_destination(pilot)
	if not _expect(group_port >= 0 and pilot.passenger_accept(group_port) and pilot.passenger_status().free_seats == 0,
		"An actual interstellar passenger booking can fill both seats during a search"):
		return
	if not _expect(_land_and_inspect(pilot) and pilot.search_status().show_pickup
		and not pilot.search_status().can_pickup and not pilot.search_action("pickup"),
		"The physical inspection records actionable coordinates even when both cabins are occupied"):
		return
	var earlier := pilot.credits
	_expect(_return_to_issuer(pilot) and pilot.search_action("submit") and pilot.credits == earlier + Missing.REWARD
		and pilot.search_status().paid == Missing.REWARD and pilot.passenger_status().rescue_seats == 0,
		"Evidence alone closes the search with the base reward and does not disturb the regular passenger manifest")


func _obtain_rescue(pilot: Flight) -> Dictionary:
	if not _expect(_land_and_inspect(pilot) and pilot.search_status().can_pickup and pilot.search_action("pickup")
		and not pilot.search_action("pickup") and pilot.passenger_status().rescue_seats == 1,
		"The actual landed inspection can rescue once and occupies exactly one seat"):
		return {}
	var saved := pilot.snapshot()
	var forged := saved.duplicate(true)
	forged.missing_person.clue_at = -1.0
	_expect(not Flight.new().restore(forged), "A cold restore rejects evidence preceding its clue")
	return saved


func _test_rescue_payment(state: Dictionary) -> void:
	var pilot := _round_trip(state)
	if not _expect(pilot != null and pilot.search_status().aboard and pilot.passenger_status().free_seats == 1
		and pilot.landed_site == Missing.SEARCH_SITE and not pilot.search_action("submit"),
		"Rescue and cabin occupancy survive cold restore and cannot pay while away from the issuer"):
		return
	var before := pilot.credits
	if not _expect(_return_to_issuer(pilot), "Route, jump and physically dock at the issuing station"):
		return
	var group_port := _two_seat_destination(pilot)
	_expect(group_port >= 0 and not pilot.passenger_accept(group_port), "The rescued person's seat blocks a new two-seat booking")
	if not _expect(pilot.search_action("submit")
		and pilot.credits == before + Missing.REWARD + Missing.RESCUE_BONUS and pilot.passenger_status().free_seats == 2,
		"Returning the person to the original issuer credits the bonus and frees the cabin"):
		return
	var completed := _round_trip(pilot.snapshot())
	_expect(completed != null and completed.search_status().stage == "complete"
		and not completed.search_action("submit") and not completed.search_action("accept") and completed.credits == pilot.credits,
		"Neither closing a finished case nor claiming it again can pay the reward twice after reload")


func _test_expired_evacuation(state: Dictionary) -> void:
	var pilot := _round_trip(state)
	if not _expect(pilot != null, "Load the same rescue for the expiry branch"):
		return
	_tick(pilot, float(pilot.search_status().deadline) - pilot.orbit_time)
	if not _expect(pilot.status_event == "missing_expired" and pilot.search_status().stage == "evacuate"
		and not pilot.search_action("submit") and not pilot.search_action("disembark"),
		"The deadline closes the reward but keeps the rescued person on board until a real berth"):
		return
	var expired := _round_trip(pilot.snapshot())
	if not _expect(expired != null and expired.search_status().aboard and expired.passenger_status().free_seats == 1
		and expired.search_action("follow") and Catalog.is_port(expired.planned_target) and expired.planned_target != Missing.ISSUER,
		"After expiry and restart, the actual nearest port can be routed for safe disembarkation"):
		return
	var port := expired.planned_target
	if not _expect(_visit(expired, port), "Reach the actual nearest operating berth"):
		return
	var before := expired.credits
	_expect(expired.search_action("disembark") and expired.credits == before
		and expired.passenger_status().rescue_seats == 0 and expired.search_status().stage == "expired"
		and not expired.search_action("disembark"), "Late disembarkation at a different real port releases the seat exactly once with no reward")


func _test_actual_board(pilot: Flight) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := BoardGame.new()
	game.show_voyage_menu_on_launch = true
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game._audio.set_level(0)
	game._voyages.close()
	game._flight_active = true
	game.flight = _round_trip(pilot.snapshot())
	game._hud.set_input_enabled(true)
	game._update_display(0.0)
	await process_frame
	_tap(viewport, game._hud._actions["frontier"])
	await process_frame
	var board: Node = game._frontier
	_tap(viewport, board._search_tab)
	await process_frame
	_expect(board.is_open() and board._search_action.is_visible_in_tree() and "Взять поиск" in board._search_action.text,
		"The normal flight shortcut opens Освоение → Поиск with a real touchable notice")
	_tap(viewport, board._search_action)
	await process_frame
	_expect(game.flight.search_status().stage == "clue" and board._search_deadline.is_visible_in_tree()
		and "Створ" in board._search_target.text and board._search_action.disabled
		and float(Session.load_state(game.isolated_save).get("missing_person", {}).get("accepted_at", -1.0)) >= 0.0,
		"Touching the notice acts through Main and visibly reveals the registry target and due time")
	_tap(viewport, board._search_route)
	await process_frame
	_expect(not board.is_open() and game.flight.planned_route().goal == Catalog.VELAR_SYSTEM,
		"The board requests a real route and returns control to the flight view")
	for path: String in [game.isolated_save, game.isolated_save + ".previous"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	viewport.queue_free()
	await process_frame


func _land_and_inspect(pilot: Flight) -> bool:
	return pilot.search_action("follow") and pilot.planned_target == Missing.SEARCH_SITE \
		and _visit(pilot, Missing.SEARCH_SITE) and pilot.landed_site == Missing.SEARCH_SITE and pilot.search_action("inspect")


func _two_seat_destination(pilot: Flight) -> int:
	if pilot != null:
		for offer: Dictionary in pilot.passenger_board():
			if int(offer.seats) == 2:
				return int(offer.destination)
	return -1


func _return_to_issuer(pilot: Flight) -> bool:
	return pilot.search_action("follow") and _jump(pilot, Catalog.HOME_SYSTEM) and _visit(pilot, Missing.ISSUER)


func _visit(pilot: Flight, site: int) -> bool:
	if not pilot.select_target(site):
		return false
	if pilot.docked >= 0 and not Fixture.depart(pilot):
		return false
	if pilot.landed and not pilot.dock_action():
		return false
	if pilot.target != site and not pilot.select_target(site):
		return false
	pilot.set_autopilot(true)
	return _wait(pilot, func() -> bool: return pilot.docked == site or pilot.landed_site == site, 170.0)


func _jump(pilot: Flight, system: int) -> bool:
	if pilot.docked >= 0 and not Fixture.depart(pilot):
		return false
	if pilot.landed and not pilot.dock_action():
		return false
	pilot.change_throttle(0.18)
	return _wait(pilot, func() -> bool: return pilot.jump_status(system).ok, 35.0) and pilot.start_jump() \
		and _wait(pilot, func() -> bool: return pilot.system_id == system, 5.0)


func _wait(pilot: Flight, condition: Callable, limit: float) -> bool:
	for _step in range(ceili(limit / STEP)):
		if condition.call():
			return true
		_tick(pilot, STEP)
	return condition.call()


func _tick(pilot: Flight, seconds: float) -> void:
	pilot.update(seconds, Vector2.ZERO, 0.0, false, false)


func _round_trip(state: Dictionary) -> Flight:
	var path := "user://missing-person-probe-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var pilot := Flight.new()
	if Session.save_state(state, path) != OK or Session.load_valid_state(path, pilot.restore) != Session.LoadResult.PRIMARY:
		pilot = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return pilot


func _tap(viewport: SubViewport, button: Button) -> void:
	if not _expect(button.is_visible_in_tree() and not button.disabled, "The requested search UI button is usable by touch"):
		return
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 14
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		viewport.push_input(event, true)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		printerr(description)
		_failures += 1
	return condition
