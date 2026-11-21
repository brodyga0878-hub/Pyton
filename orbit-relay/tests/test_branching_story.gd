extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Session := preload("res://scripts/session_io.gd")

const STEP := Fixture.STEP
const AUDIT_PORT := 3
const AUDIT_BODY := 7
const ENTRY_COMET := 8
const KEY_PORT := 10
const MIRROR_PORT := 11
const REGISTRY_SAVE := "user://story-registry-choice.json"
const MIRROR_SAVE := "user://story-mirror-key.json"
const ENDING_SAVE := "user://story-ending.json"

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_registry()
	_test_mirror()
	print("Branching story integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_registry() -> void:
	var flight := Flight.new()
	var initial := flight.story_status()
	_expect(initial.stage == "locked" and initial.target == -1 and initial.actions.is_empty()
		and not flight.story_action("brief") and not flight.story_follow(),
		"A fresh pilot cannot force a story briefing before any evidence")
	if not _expect(flight.contract_action() and _visit(flight, 1) and flight.contract_action()
		and flight.deliveries == 1 and flight.credits == 240,
		"Earn the freight entry through a standard physically flown courier assignment"):
		return
	var opening := flight.story_status()
	if not _expect(opening.stage == "offer" and opening.target == AUDIT_PORT and opening.actions.is_empty()
		and opening.can_follow and not flight.story_action("brief") and flight.story_follow()
		and flight.planned_target == AUDIT_PORT and _visit(flight, AUDIT_PORT),
		"Use the story navigation to reach the real briefing port instead of acting remotely"):
		return
	if not _expect(flight.story_action("brief") and flight.story_status().entry == "freight"
		and flight.story_status().stage == "choice" and flight.story_status().actions.size() == 2
		and not flight.story_action("brief"), "The freight pilot can receive one briefing with two mutually exclusive choices"):
		return
	var before := flight.credits
	var trust := _trust(flight)
	if not _expect(flight.story_action("registry") and not flight.story_action("mirror") and not flight.story_action("submit")
		and flight.story_status().stage == "observe" and flight.story_status().target == AUDIT_BODY
		and flight.credits == before and _trust(flight) == trust
		and Session.save_state(flight.snapshot(), REGISTRY_SAVE) == OK,
		"An official choice earns no payment and waits for a real astronomical observation"):
		return
	flight = _load(REGISTRY_SAVE)
	if flight == null:
		return
	var pending := flight.story_status()
	if not _expect(pending.branch == "registry" and pending.entry == "freight" and pending.chosen_at >= pending.briefed_at
		and pending.settled_at < 0.0 and not flight.story_action("mirror") and not flight.story_action("submit")
		and flight.story_follow() and flight.planned_target == AUDIT_BODY and _visit(flight, AUDIT_BODY)
		and flight.landed_site == AUDIT_BODY and flight.story_status().stage == "observe",
		"Cold restore preserves the selected branch and requires an atlas measurement even after physical touchdown"):
		return
	if not _expect(flight.survey_action(AUDIT_BODY) and flight.body_dossier(AUDIT_BODY).known
		and flight.story_status().stage == "report" and flight.story_status().target == AUDIT_PORT
		and not flight.story_action("submit") and flight.story_follow() and flight.planned_target == AUDIT_PORT
		and _visit(flight, AUDIT_PORT), "The real atlas observation triggers the official report at its actual berth"):
		return
	_expect(_action_ids(flight) == ["submit"] and flight.story_action("submit")
		and flight.story_status().stage == "complete" and flight.story_status().branch == "registry"
		and flight.credits == before + 640 and _trust(flight) == [trust[0] + 4, trust[1] - 1],
		"The registry ending pays 640 and changes actual faction career trust in opposing directions")
	_test_no_repeat(flight, "registry")


func _test_mirror() -> void:
	var flight := Flight.new()
	if not _expect(_visit(flight, ENTRY_COMET) and flight.landed_site == ENTRY_COMET
		and flight.story_status().stage == "locked" and flight.survey_action(ENTRY_COMET)
		and flight.deliveries == 0 and flight.story_status().stage == "offer"
		and flight.story_follow() and flight.planned_target == AUDIT_PORT and _visit(flight, AUDIT_PORT),
		"Actual comet observation can open an independent story with no prior cargo delivery"):
		return
	if not _expect(flight.story_action("brief") and flight.story_status().entry == "survey"
		and flight.story_action("mirror") and flight.story_status().branch == "mirror"
		and flight.story_status().stage == "key" and flight.story_status().target == KEY_PORT
		and not flight.story_action("collect_key") and not flight.story_action("submit"),
		"The independent choice requires a physical visit to retrieve its key"):
		return
	var before := flight.credits
	var trust := _trust(flight)
	if not _expect(flight.story_follow() and flight.jump_target == Catalog.VELAR_SYSTEM and _jump_on_course(flight)
		and _visit(flight, KEY_PORT) and _action_ids(flight) == ["collect_key"],
		"Follow the independent objective into a paid interstellar jump and dock at the key station"):
		return
	if not _expect(flight.story_action("collect_key") and flight.story_status().stage == "publish"
		and flight.story_status().key_at >= flight.story_status().chosen_at and flight.story_status().target == MIRROR_PORT
		and not flight.story_action("collect_key") and not flight.story_action("submit")
		and flight.credits == before and _trust(flight) == trust and Session.save_state(flight.snapshot(), MIRROR_SAVE) == OK,
		"Retain the one collected key without paying, altering trust or allowing premature publication"):
		return
	flight = _load(MIRROR_SAVE)
	if flight == null:
		return
	var pending := flight.story_status()
	if not _expect(pending.stage == "publish" and pending.entry == "survey" and pending.branch == "mirror"
		and pending.target == MIRROR_PORT and pending.key_at >= 0.0 and not flight.story_action("registry")
		and flight.story_follow() and flight.planned_target == MIRROR_PORT and _visit(flight, MIRROR_PORT),
		"Cold continuation keeps the key and the chosen publication destination"):
		return
	_expect(_action_ids(flight) == ["submit"] and flight.story_action("submit")
		and flight.story_status().stage == "complete" and flight.story_status().branch == "mirror"
		and flight.credits == before + 820 and _trust(flight) == [trust[0] - 2, trust[1] + 4],
		"The mirror ending pays 820 and changes actual faction career trust differently")
	_test_no_repeat(flight, "mirror")


func _test_no_repeat(flight: Flight, branch: String) -> void:
	var ending := flight.story_status()
	var balance := flight.credits
	var trust := _trust(flight)
	if not _expect(ending.settled_at >= ending.chosen_at and not ending.can_follow and ending.actions.is_empty()
		and not flight.story_action("submit") and not flight.story_action("brief")
		and Session.save_state(flight.snapshot(), ENDING_SAVE) == OK,
		"Completion hides settled actions and preserves the one award at the real station"):
		return
	var resumed := _load(ENDING_SAVE)
	if resumed == null:
		return
	var final := resumed.story_status()
	_expect(final.branch == branch and final.stage == "complete" and absf(final.settled_at - ending.settled_at) < 0.00000001
		and final.objective == ending.objective and resumed.credits == balance and _trust(resumed) == trust
		and not resumed.story_action("submit") and not resumed.story_action("collect_key") and not resumed.story_follow(),
		"Cold completion preserves its ending, final faction changes and single payment")
	var malformed := resumed.snapshot()
	malformed.story.settled_at = resumed.orbit_time + 1.0
	var unaffected := resumed.snapshot()
	_expect(not resumed.restore(malformed) and resumed.snapshot() == unaffected,
		"Impossible future story timestamps cannot modify the valid completed flight")
	var absent_scan := resumed.snapshot()
	var required_site := AUDIT_BODY if branch == "registry" else ENTRY_COMET
	absent_scan.cartography.scans = absent_scan.cartography.scans.filter(func(observation: Dictionary) -> bool:
		return int(observation.site) != required_site)
	_expect(not resumed.restore(absent_scan) and resumed.snapshot() == unaffected,
		"A completed path cannot be restored after removing its required measurement")


func _action_ids(flight: Flight) -> Array:
	return flight.story_status().actions.map(func(entry: Dictionary) -> String: return entry.id)


func _trust(flight: Flight) -> Array[int]:
	var standing: Array = flight.career_status().factions
	return [int(standing[0].trust), int(standing[1].trust)]


func _load(path: String) -> Flight:
	var flight := Flight.new()
	return flight if _expect(flight.restore(Session.load_state(path)), "Cold restore the actual story checkpoint from %s" % path) else null


func _jump_on_course(flight: Flight) -> bool:
	if not Fixture.depart(flight):
		return false
	flight.change_throttle(0.18)
	return _until(flight, func() -> bool: return flight.jump_status(Catalog.VELAR_SYSTEM).ok, 16.0) and flight.start_jump() \
		and _until(flight, func() -> bool: return flight.system_id == Catalog.VELAR_SYSTEM, 5.0)


func _visit(flight: Flight, site: int) -> bool:
	if not flight.select_target(site) or (flight.docked >= 0 and not Fixture.depart(flight)) or (flight.landed and not flight.dock_action()):
		return false
	flight.set_autopilot(true)
	return _until(flight, func() -> bool: return flight.docked == site or flight.landed_site == site, 155.0)


func _until(flight: Flight, reached: Callable, seconds: float) -> bool:
	for _frame in range(ceili(seconds / STEP)):
		if reached.call():
			return true
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	return reached.call()


func _expect(value: bool, description: String) -> bool:
	_checks += 1
	if not value:
		_failures.append("FAIL: " + description)
	return value
