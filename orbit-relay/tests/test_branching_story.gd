extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Story := preload("res://scripts/branching_story.gd")
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
const FINAL_LEG_SAVE := "user://story-final-leg.json"

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
	if _expect(_action_ids(flight) == ["submit"] and flight.story_action("submit")
		and flight.story_status().stage == "verify" and flight.story_status().branch == "registry"
		and flight.credits == before + 640 and _trust(flight) == [trust[0] + 4, trust[1] - 1],
		"The registry chapter pays 640 and opens the field verification"):
		_test_finale(flight, "registry")


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
	if _expect(_action_ids(flight) == ["submit"] and flight.story_action("submit")
		and flight.story_status().stage == "verify" and flight.story_status().branch == "mirror"
		and flight.credits == before + 820 and _trust(flight) == [trust[0] - 2, trust[1] + 4],
		"The mirror chapter pays 820 and opens a different field verification"):
		_test_finale(flight, "mirror")


func _test_finale(flight: Flight, branch: String) -> void:
	var route: Dictionary = Story.BRANCHES[branch]
	var site := int(route.verification_site)
	var port := int(route.final_port)
	var local_system := Catalog.system_of_site(site)
	var former := flight.snapshot()
	former.schema = 54
	former.erase("story_finale")
	var migrated := Flight.new()
	if not _expect(migrated.restore(former) and migrated.story_status().stage == "verify"
		and migrated.story_status().target == site and migrated.story_status().verified_at < 0.0
		and migrated.credits == flight.credits and _trust(migrated) == _trust(flight)
		and not migrated.story_action("submit") and not migrated.story_action("verify") and not migrated.story_action("finale"),
		"A settled schema 54 chapter resumes the finale with original pay and standing intact"):
		return
	flight = migrated
	if flight.service_offer("refuel").allowed:
		flight.service_action("refuel")
	if not _expect(flight.story_follow() and flight.jump_target == local_system and _jump_on_course(flight)
		and _visit(flight, site) and flight.landed_site == site and flight.story_status().can_follow
		and not flight.story_action("verify"),
		"Follow the advertised route, pay for a real interstellar jump and land without bypassing the atlas"):
		return
	var balance := flight.credits
	var trust := _trust(flight)
	if not _expect(flight.survey_action(site) and _action_ids(flight) == ["verify"] and flight.story_action("verify")
		and flight.story_status().stage == "finale" and flight.story_status().target == port
		and flight.story_status().verified_at >= flight.story_status().settled_at and flight.story_status().finished_at < 0.0
		and flight.credits == balance and _trust(flight) == trust
		and not flight.story_action("verify") and not flight.story_action("finale")
		and Session.save_state(flight.snapshot(), FINAL_LEG_SAVE) == OK,
		"Record the field comparison once at the actual site, with no early payment or remote handover"):
		return
	flight = _load(FINAL_LEG_SAVE)
	if flight == null or not _expect(flight.story_status().stage == "finale" and flight.story_follow() and _visit(flight, port),
		"Cold continuation remembers evidence and flies to the branch's final berth"):
		return
	balance = flight.credits
	trust = _trust(flight)
	var reward := int(route.final_credits)
	flight.credits = 1000000000 - reward + 1
	var pre_overflow := flight.snapshot()
	_expect(not bool(flight.story_status().actions[0].available) and not flight.story_action("finale")
		and flight.snapshot() == pre_overflow, "An overflowing award changes no state and makes room for a later handover")
	flight.credits = balance
	if _expect(_action_ids(flight) == ["finale"] and flight.story_action("finale") and flight.story_status().stage == "complete"
		and flight.story_status().finished_at >= flight.story_status().verified_at
		and flight.credits == balance + reward and _trust(flight) == [trust[0] + route.final_trust[0], trust[1] + route.final_trust[1]],
		"The branch's conclusion pays and records its distinct faction response once"):
		_test_no_repeat(flight, branch, site, local_system)


func _test_no_repeat(flight: Flight, branch: String, site: int, system: int) -> void:
	var ending := flight.story_status()
	var balance := flight.credits
	var trust := _trust(flight)
	var reports: Array = flight.snapshot().news.reports.filter(func(report: Dictionary) -> bool: return report.id == "story-finale")
	if not _expect(ending.finished_at >= ending.verified_at and not ending.can_follow and ending.actions.is_empty()
		and reports.size() == 1 and reports[0].kind == "story_" + branch + "_finale" and reports[0].system == system
		and reports[0].related == "story-result"
		and not flight.story_action("finale") and not flight.story_action("submit") and not flight.story_action("brief")
		and Session.save_state(flight.snapshot(), ENDING_SAVE) == OK,
		"Completion hides settled actions and preserves the one award at the real station"):
		return
	var resumed := _load(ENDING_SAVE)
	if resumed == null:
		return
	var final := resumed.story_status()
	_expect(final.branch == branch and final.stage == "complete" and absf(final.finished_at - ending.finished_at) < 0.00000001
		and final.objective == ending.objective and resumed.credits == balance and _trust(resumed) == trust
		and not resumed.story_action("finale") and not resumed.story_action("verify")
		and not resumed.story_action("submit") and not resumed.story_action("collect_key") and not resumed.story_follow(),
		"Cold completion preserves its ending, final faction changes and single payment")
	var malformed := resumed.snapshot()
	malformed.story_finale.finished_at = resumed.orbit_time + 1.0
	var unaffected := resumed.snapshot()
	_expect(not resumed.restore(malformed) and resumed.snapshot() == unaffected,
		"Impossible future story timestamps cannot modify the valid completed flight")
	var absent_scan := resumed.snapshot()
	var required_site := AUDIT_BODY if branch == "registry" else ENTRY_COMET
	absent_scan.cartography.scans = absent_scan.cartography.scans.filter(func(observation: Dictionary) -> bool:
		return int(observation.site) != required_site)
	_expect(not resumed.restore(absent_scan) and resumed.snapshot() == unaffected,
		"A completed path cannot be restored after removing its required measurement")
	var absent_final_scan := resumed.snapshot()
	absent_final_scan.cartography.scans = absent_final_scan.cartography.scans.filter(func(observation: Dictionary) -> bool:
		return int(observation.site) != site)
	_expect(not resumed.restore(absent_final_scan) and resumed.snapshot() == unaffected,
		"The final handover cannot be restored without evidence from the designated field site")


func _action_ids(flight: Flight) -> Array:
	return flight.story_status().actions.map(func(entry: Dictionary) -> String: return entry.id)


func _trust(flight: Flight) -> Array[int]:
	var standing: Array = flight.career_status().factions
	return [int(standing[0].trust), int(standing[1].trust)]


func _load(path: String) -> Flight:
	var flight := Flight.new()
	return flight if _expect(flight.restore(Session.load_state(path)), "Cold restore the actual story checkpoint from %s" % path) else null


func _jump_on_course(flight: Flight) -> bool:
	var destination := flight.jump_target
	if not Fixture.depart(flight):
		return false
	flight.change_throttle(0.18)
	return _until(flight, func() -> bool: return flight.jump_status(destination).ok, 16.0) and flight.start_jump() \
		and _until(flight, func() -> bool: return flight.system_id == destination, 5.0)


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
