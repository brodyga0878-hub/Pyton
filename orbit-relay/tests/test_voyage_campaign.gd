extends SceneTree

const Startup := preload("res://voyage_start.tscn")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Session := preload("res://scripts/session_io.gd")
const Fixture := preload("res://tests/flight_fixture.gd")

var _viewport: SubViewport
var _game: Node
var _checks := 0
var _failures: Array[String] = []
var _mirror := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_mirror = "--mirror" in OS.get_cmdline_user_args()
	if _expect(not FileAccess.file_exists(Session.SAVE_PATH) and not FileAccess.file_exists(Session.BACKUP_PATH),
			"Campaign acceptance starts with no player files"):
		_viewport = SubViewport.new()
		_viewport.size = Vector2i(1544, 720)
		_viewport.own_world_3d = true
		root.add_child(_viewport)
		await _campaign()
		_viewport.queue_free()
		await process_frame
		await create_timer(0.15).timeout
	for failure: String in _failures:
		printerr(failure)
	print("Fresh voyage campaign: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _spawn() -> void:
	_game = Startup.instantiate()
	_viewport.add_child(_game)
	_game.set_process(false)
	_game.set_physics_process(false)


func _campaign() -> void:
	_spawn()
	if not _expect(_game._voyages.is_open() and not _game._flight_active and _game._voyages._actions["continue"].disabled,
			"Offline startup shows the choice before activating any voyage"):
		return
	if not await _tap(_game._voyages._actions["new"], "Start a new voyage"):
		return
	if not _expect(_game._flight_active and _game.flight.station_services_available()
			and _game.flight.story_status().stage == "locked", "The new pilot starts berthed and the story requires a delivery"):
		return
	if not await _first_delivery() or not await _first_report():
		return
	await _finale()


func _first_delivery() -> bool:
	var starter_balance := int(_game.flight.credits)
	if not await _tap(_game._hud._actions["contract"], "Accept a real first contract from the flight HUD"):
		return false
	var port := int(_game.flight.contract_destination)
	var reward := int(_game.flight.contract_reward())
	if not _expect(_game.flight.contract_stage == 1 and port >= 0 and reward > 0
			and _game.flight.story_status().stage == "locked", "Accepting a contract does not open the story"):
		return false
	if not await _tap(_game._hud._actions["journal"], "Open the delivery journal") \
			or not await _tap(_game._journal._follow_buttons["delivery"], "Follow the contract to its destination"):
		return false
	if not await _fly_to(port):
		return false
	if not await _tap(_game._hud._actions["contract"], "Turn in the first delivery"):
		return false
	return _expect(_game.flight.deliveries == 1 and _game.flight.credits == starter_balance + reward
		and _game.flight.story_status().stage == "offer", "One genuine delivery pays exactly once and opens the story")


func _first_report() -> bool:
	if not await _story_open() or not await _fly_story_objective():
		return false
	if not await _story_action("brief") or not _expect(_game.flight.story_status().entry == "freight",
			"The dispatcher knows this pilot entered through freight"):
		return false
	var branch := "mirror" if _mirror else "registry"
	var first_stage := "key" if _mirror else "observe"
	if not await _story_action(branch) or not _expect(_game.flight.story_status().stage == first_stage,
			"The chosen branch opens its physical objective"):
		return false
	if not await _fly_story_objective():
		return false
	if _mirror:
		if not await _story_action("collect_key"):
			return false
	elif not await _scan_story_site():
		return false
	var next_stage := "publish" if _mirror else "report"
	if not _expect(_game.flight.story_status().stage == next_stage, "The objective opens its submission berth"):
		return false
	if not await _story_open() or not await _fly_story_objective():
		return false
	var balance := int(_game.flight.credits)
	var payment := 820 if _mirror else 640
	return await _story_action("submit") and _expect(_game.flight.credits == balance + payment,
		"The delivered chapter pays its own settlement amount")


func _finale() -> void:
	if not _expect(_game.flight.story_status().stage == "verify",
			"The initial report leads to a verification leg in the campaign"):
		return
	if not await _fly_story_objective() or not await _scan_story_site() or not await _story_action("verify"):
		return
	var verified: Dictionary = _game.flight.story_status()
	var checkpoint := Session.load_single_state(Session.SAVE_PATH)
	if not _expect(verified.stage == "finale" and verified.verified_at >= verified.settled_at
			and _same_story(checkpoint.get("story", {}), _game.flight.story.snapshot()),
			"Accepting the observation automatically saves the final route"):
		return
	if not await _cold_continue() or not _expect(_same_story(_game.flight.story_status(), verified),
			"Continue restores the exact objective after the physical measurement"):
		return
	if not await _story_open() or not await _fly_story_objective():
		return
	var balance := int(_game.flight.credits)
	var trust: Array = _game.flight.career_status().factions.map(func(faction: Dictionary) -> int: return int(faction.trust))
	if not await _story_action("finale"):
		return
	var ending: Dictionary = _game.flight.story_status()
	var final_balance := int(_game.flight.credits)
	var final_trust: Array = _game.flight.career_status().factions.map(func(faction: Dictionary) -> int: return int(faction.trust))
	var branch := "mirror" if _mirror else "registry"
	var payment := 720 if _mirror else 580
	var expected_trust := [trust[0] + 1, trust[1] + 3] if _mirror else [trust[0] + 2, trust[1] + 2]
	if not _expect(ending.stage == "complete" and ending.branch == branch and ending.actions.is_empty()
			and ending.finished_at >= ending.verified_at and not ending.can_follow and final_balance == balance + payment
			and final_trust == expected_trust,
			"The real ending settles pay and faction standing and closes its available actions"):
		return
	if not await _cold_continue() or not await _story_open():
		return
	_expect(_same_story(_game.flight.story_status(), ending) and _game.flight.credits == final_balance
		and _game.flight.career_status().factions.map(func(faction: Dictionary) -> int: return int(faction.trust)) == final_trust
		and _game._journal._story_objective.text == ending.objective and not _game._journal._story_choices.visible
		and not _game._journal._follow_buttons["story"].visible
		and not _game.flight.story_action("finale") and _game.flight.credits == final_balance,
		"Cold startup preserves the visible conclusion and refuses a duplicate payment")


func _cold_continue() -> bool:
	_game.queue_free()
	await process_frame
	_spawn()
	return await _tap(_game._voyages._actions["continue"], "Continue the autosaved voyage from startup") \
		and _expect(_game._flight_active and not _game._voyages.is_open(),
			"An ordinary cold Continue returns control to the cockpit")


func _same_story(actual: Dictionary, expected: Dictionary) -> bool:
	if actual.size() != expected.size():
		return false
	for key: String in expected:
		if not actual.has(key):
			return false
		if key.ends_with("_at"):
			if absf(float(actual[key]) - float(expected[key])) > 0.000001:
				return false
		elif actual[key] != expected[key]:
			return false
	return true


func _story_open() -> bool:
	if not _game._journal.is_open() and not await _tap(_game._hud._actions["journal"], "Open the mission journal"):
		return false
	if _game._journal._story_page.visible:
		return true
	return await _tap(_game._journal._story_tab, "Open the story page")


func _story_action(action: String) -> bool:
	if not await _story_open():
		return false
	for option: Dictionary in _game._journal._story_options:
		var button: Button = option.button
		if str(button.get_meta("story_action", "")) == action:
			return await _tap(button, "Story command «%s»" % action)
	return _expect(false, "Story command «%s» exposed at %s" % [action, _game.flight.story_status().stage])


func _fly_story_objective() -> bool:
	var target := int(_game.flight.story_status().target)
	var system := Catalog.system_of_site(target)
	if not _expect(system >= 0, "Story names a real destination"):
		return false
	if _game.flight.docked == target or _game.flight.landed_site == target:
		return true
	if not await _tap(_game._journal._follow_buttons["story"], "Select the story route from the journal"):
		return false
	if _game.flight.system_id != system:
		if not await _jump_to(system) or not await _story_open() \
				or not await _tap(_game._journal._follow_buttons["story"], "Select the local leg after arrival"):
			return false
	return await _fly_to(target)


func _scan_story_site() -> bool:
	var site := int(_game.flight.story_status().target)
	if not _expect(_game.flight.landed_site == site, "Reach the survey body by physical touchdown"):
		return false
	if not await _story_open() or not await _tap(_game._journal._follow_buttons["story"], "Open the atlas from the landed objective"):
		return false
	if not _expect(_game._map.is_open(), "The landed objective leads into the atlas through the journal") \
			or not await _tap(_game._map._scan_button, "Record the objective in the atlas"):
		return false
	if not _expect(_game.flight.body_dossier(site).known, "Atlas scan is written to persistent cartography"):
		return false
	return await _tap(_game._map._close_button, "Close the atlas")


func _fly_to(site: int) -> bool:
	if not await _depart_if_parked():
		return false
	if not _expect(_game.flight.target == site, "The selected destination survives departure") \
			or not await _tap(_game._hud._actions["autopilot"], "Engage the onboard autopilot"):
		return false
	return _advance_until(func() -> bool: return _game.flight.docked == site or _game.flight.landed_site == site,
		190.0, "Fly to and arrive at «%s»" % _game.flight.target_name(site))


func _depart_if_parked() -> bool:
	if _game.flight.docked < 0 and not _game.flight.landed:
		return true
	if not await _tap(_game._hud._actions["dock"], "Request exit or lift off from the cockpit"):
		return false
	return _advance_until(func() -> bool: return _game.flight.docked < 0 and not _game.flight.landed,
		15.0, "Complete departure through the berth or surface sequence")


func _jump_to(system: int) -> bool:
	if not _expect(_game.flight.jump_target == system, "Story plots the real interstellar course") \
			or not await _depart_if_parked():
		return false
	if not await _tap(_game._hud._actions["throttle_up"], "Apply thrust to leave port clearance") \
			or not await _tap(_game._hud._actions["throttle_up"], "Increase clearing thrust"):
		return false
	if not _advance_until(func() -> bool: return _game.flight.jump_status(system).ok,
			23.0, "Reach valid jump clearance"):
		return false
	var fuel := float(_game.flight.ship.active_jump_fuel())
	if not await _tap(_game._hud._actions["galaxy"], "Open the galaxy chart") \
			or not await _tap(_game._galaxy._jump_button, "Charge the planned jump"):
		return false
	return _advance_until(func() -> bool: return _game.flight.system_id == system,
		6.0, "Complete the real interstellar transit") \
		and _expect(_game.flight.ship.active_jump_fuel() < fuel, "The journey consumes jump fuel")


func _advance_until(reached: Callable, seconds: float, description: String) -> bool:
	for _frame in range(ceili(seconds / Fixture.STEP)):
		if reached.call():
			break
		_game._physics_process(Fixture.STEP)
	_game._update_display(0.0)
	if reached.call():
		return _expect(true, description)
	var flight: RefCounted = _game.flight
	return _expect(false, "%s [dock %d, surface %d, target %d, fuel %.1f, %s]" %
		[description, flight.docked, flight.landed_site, flight.target, flight.ship.fuel, flight.status_message])


func _tap(button: Button, description: String) -> bool:
	await process_frame
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, description):
		return false
	var at := button.get_global_rect().get_center()
	if not _expect(_viewport.get_visible_rect().has_point(at), "%s is on screen" % description):
		return false
	for held: bool in [true, false]:
		var press := InputEventScreenTouch.new()
		press.index = 3
		press.position = at
		press.pressed = held
		_viewport.push_input(press, true)
	await process_frame
	return true


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append("FAIL: " + description)
	return condition
