extends SceneTree

const Calendar := preload("res://scripts/mission_calendar.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Session := preload("res://scripts/session_io.gd")
const STEP := Fixture.STEP
const FRONTIER := Catalog.HEATHER_SYSTEM
const WAITING_NEWS := "user://pending-sector-edition.json"
const WAR_SNAPSHOT := "user://sector-war-news.json"

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_calendar()
	_test_live_story_news()
	_test_faction_news()
	print("Sector news integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_calendar() -> void:
	var pilot := Flight.new()
	var archive := pilot.news_archive(Catalog.HOME_SYSTEM)
	_expect(archive.size() == 1 and archive[0].published_at == 0.0
		and pilot.news_edition(Catalog.HOME_SYSTEM, 78.0).is_empty()
		and pilot.news_edition(Catalog.HOME_SYSTEM, 0.0).articles.size() == 1
		and pilot.news_archive(FRONTIER).is_empty(),
		"The starter sees one opening issue and cannot inspect a future daily edition")
	_tick(pilot, 77.75)
	_expect(pilot.news_archive(Catalog.HOME_SYSTEM).size() == 1, "The daily bulletin waits until the exact game midnight")
	_tick(pilot, 0.25)
	var after := pilot.news_archive(Catalog.HOME_SYSTEM, 1)
	_expect(after.size() == 1 and after[0].published_at == 78.0 and after[0].date == "02.01.2478"
		and pilot.news_archive(Catalog.HOME_SYSTEM).size() == 2,
		"Midnight produces a dated daily issue and the archive limit remains exact")


func _test_live_story_news() -> void:
	var pilot := Flight.new()
	if not _expect(pilot.contract_action() and _dock_at(pilot, 1) and pilot.contract_action()
		and _dock_at(pilot, 3) and pilot.story_action("brief") and pilot.story_action("registry"),
		"Real freight and actual brief and choice activate the narrative reporting chain"):
		return
	var briefing := _report(pilot, "story_brief")
	var choice := _report(pilot, "story_choice")
	if not _expect(not briefing.is_empty() and not choice.is_empty() and choice.related == briefing.id
		and choice.published_at > briefing.published_at and pilot.news_article(briefing.id).is_empty()
		and pilot.news_article(choice.id).is_empty(), "Linked reports wait for distinct issues and are unavailable before publication"):
		return
	_tick(pilot, float(briefing.published_at) - pilot.orbit_time - 0.25)
	if not _expect(pilot.news_article(briefing.id).is_empty() and pilot.toggle_time_pause()
		and Session.save_state(pilot.snapshot(), WAITING_NEWS) == OK,
		"A queued story report can be cold-saved just before its real publication boundary"):
		return
	var reloaded := Flight.new()
	if not _expect(reloaded.restore(Session.load_state(WAITING_NEWS)) and reloaded.clock_status().paused,
		"The queued issue survives a real paused disk save and reload"):
		return
	pilot = reloaded
	_tick(pilot, 1.0)
	_expect(pilot.news_article(briefing.id).is_empty() and pilot.toggle_time_pause(),
		"Wall time cannot publish the archived issue while the game calendar is paused")
	_tick(pilot, 0.25)
	var issued := pilot.news_article(briefing.id)
	_expect(issued.kind == "story_brief" and issued.published_at == briefing.published_at
		and issued.stamp == Calendar.stamp(issued.published_at)
		and pilot.news_article(choice.id).is_empty(),
		"Resuming at the exact second releases the correct briefing without exposing its future follow-up")
	_tick(pilot, float(choice.published_at) - pilot.orbit_time)
	var decision := pilot.news_article(choice.id)
	_expect(decision.related_available and decision.related_at == briefing.published_at
		and _edition_has(pilot, Catalog.HOME_SYSTEM, decision.published_at, choice.id),
		"A later official choice issue links to the distinct earlier briefing and appears in the archive")
	if not _expect(_land_at(pilot, 7) and pilot.survey_action(7) and pilot.dock_action()
		and _dock_at(pilot, 3) and pilot.story_action("submit"), "Fly an actual survey and submit the official ending"):
		return
	var ending := _report(pilot, "story_registry")
	if not _expect(not ending.is_empty() and ending.related == choice.id
		and pilot.news_article(ending.id).is_empty(), "The actual story outcome creates a third queued consequence linked to its choice"):
		return
	_tick(pilot, float(ending.published_at) - pilot.orbit_time)
	var final := pilot.news_article(ending.id)
	_expect(final.kind == "story_registry" and final.related_available and final.related_at == choice.published_at
		and _edition_has(pilot, Catalog.HOME_SYSTEM, final.published_at, final.id)
		and not pilot.story_action("submit") and _count_reports(pilot, "story_registry") == 1,
		"The final issue publishes the real branch exactly once and keeps access to the earlier edition")


func _test_faction_news() -> void:
	var pilot := _colonize()
	if pilot == null:
		return
	var peace := pilot.factions.system_state(FRONTIER)
	if not _expect(pilot.docked == 0 and peace.stage == "peace" and peace.next_at > pilot.orbit_time
		and not _report(pilot, "expedition_complete", FRONTIER).is_empty(),
		"The player returns Home while their actual frontier station is commissioned and still at peace"):
		return
	_tick(pilot, float(peace.next_at) - pilot.orbit_time + 0.02)
	var declared := _report(pilot, "war_declared", FRONTIER)
	var war := pilot.factions.system_state(FRONTIER)
	if not _expect(war.stage == "war" and not declared.is_empty() and pilot.news_article(declared.id).is_empty(),
		"The independent conflict makes a dated statement without premature publication"):
		return
	pilot.cycle_time_scale()
	pilot.cycle_time_scale()
	if not _expect(pilot.time_scale == 16 and _until(pilot, func() -> bool:
		return int(pilot.factions.system_state(FRONTIER).round) > 0, 13.0),
		"Normal accelerated dock updates finish both convoy arrivals and the full fighting round"):
		return
	pilot.reset_time_scale()
	var latest := _report(pilot, "war_round", FRONTIER)
	if not _expect(pilot.factions.system_state(FRONTIER).round > 0 and pilot.docked == 0
		and not latest.is_empty() and latest.related == declared.id and latest.published_at > declared.published_at
		and pilot.news_article(latest.id).is_empty(),
		"A genuine remote fighting round creates its own issue and references the original war declaration"):
		return
	_tick(pilot, float(latest.published_at) - pilot.orbit_time)
	var report := pilot.news_article(latest.id)
	_expect(report.related_available and report.related_system == FRONTIER and report.related_at == declared.published_at
		and _edition_has(pilot, FRONTIER, report.published_at, report.id)
		and _edition_has(pilot, FRONTIER, declared.published_at, declared.id) and pilot.docked == 0,
		"Both independent wartime issues and their actionable link are readable while the player remains at Home")
	var cold := Flight.new()
	if _expect(Session.save_state(pilot.snapshot(), WAR_SNAPSHOT) == OK and cold.restore(Session.load_state(WAR_SNAPSHOT)),
		"Actual expedition, war state and published archive can be cold-saved together"):
		_expect(cold.news_archive(FRONTIER) == pilot.news_archive(FRONTIER) and cold.news_article(report.id) == report,
			"Reload retains archive identity, publication dates and published cross-issue links")
	var exported := Session.new().export_report(pilot.snapshot(), "user://news-support.zip")
	var archive := ZIPReader.new()
	if not _expect(exported.ok and archive.open(exported.path) == OK, "An actual current support ZIP can include the frontier archive"):
		return
	var included: Variant = JSON.parse_string(archive.read_file("flight.json").get_string_from_utf8())
	archive.close()
	var diagnostic := Flight.new()
	_expect(diagnostic.restore(included) and diagnostic.news_article(report.id) == report,
		"The standard diagnostics contain a genuinely resumable save with its published wartime story")


func _edition_has(flight: Flight, system: int, released: float, identifier: String) -> bool:
	var edition := flight.news_edition(system, released)
	return not edition.is_empty() and edition.articles.any(func(article: Dictionary) -> bool: return article.id == identifier)


func _report(flight: Flight, kind: String, system := -2) -> Dictionary:
	for report: Dictionary in flight.snapshot().news.reports:
		if report.kind == kind and (system == -2 or int(report.system) == system):
			return report
	return {}


func _count_reports(flight: Flight, kind: String) -> int:
	var reports: Array = flight.snapshot().news.reports
	return reports.filter(func(report: Dictionary) -> bool: return report.kind == kind).size()


func _land_at(flight: Flight, site: int) -> bool:
	if not flight.select_target(site) or (flight.docked >= 0 and not Fixture.depart(flight)):
		return false
	flight.set_autopilot(true)
	return _until(flight, func() -> bool: return flight.landed_site == site, 155.0)


func _colonize() -> Flight:
	var flight := Flight.new()
	if not _expect(flight.contract_action() and _dock_at(flight, 1) and flight.contract_action() and _dock_at(flight, 0)
		and flight.project_action(), "Real courier earnings and genuine survey acceptance from Home"):
		return null
	if not _expect(_jump(flight, FRONTIER) and _guide(flight) and flight.project_action()
		and _guide(flight) and flight.project_action(), "Follow and record both frontier observations"):
		return null
	if not _expect(_jump(flight, Catalog.HOME_SYSTEM) and _dock_at(flight, 0) and flight.project_action()
		and flight.service_action("jump_refuel") and flight.service_action("refuel"),
		"File actual survey report at Home and replenish both fuel reserves"):
		return null
	for material: Dictionary in [{"id": "ore", "count": 10}, {"id": "circuits", "count": 2}, {"id": "crystal", "count": 3}]:
		if not _expect(flight.market_trade(material.id, "buy", material.count), "Purchase physical construction freight"):
			return null
	if not _expect(_jump(flight, FRONTIER) and _guide(flight) and flight.project_action() and flight.project_action()
		and flight.station_operational(Catalog.HEATHER_PORT), "Make both real deliveries and commission the contested station"):
		return null
	if not _expect(_jump(flight, Catalog.HOME_SYSTEM) and _dock_at(flight, 0), "Return by paid jump to watch the remote conflict"):
		return null
	return flight


func _jump(flight: Flight, system: int) -> bool:
	if (flight.docked >= 0 and not Fixture.depart(flight)) or not flight.plan_jump(system):
		return false
	flight.change_throttle(0.18)
	return _until(flight, func() -> bool: return flight.jump_status(system).ok, 30.0) and flight.start_jump() \
		and _until(flight, func() -> bool: return flight.system_id == system, 5.0)


func _guide(flight: Flight) -> bool:
	if not flight.frontier_status().ready and not flight.project_action():
		return false
	return _until(flight, func() -> bool: return flight.frontier_status().ready, 150.0)


func _dock_at(flight: Flight, port: int) -> bool:
	if not flight.select_target(port) or (flight.docked >= 0 and not Fixture.depart(flight)):
		return false
	flight.set_autopilot(true)
	return _until(flight, func() -> bool: return flight.docked == port, 135.0)


func _until(flight: Flight, reached: Callable, seconds: float) -> bool:
	for _frame in range(ceili(seconds / STEP)):
		if reached.call():
			return true
		_tick(flight)
	return reached.call()


func _tick(flight: Flight, delta := STEP) -> void:
	flight.update(delta, Vector2.ZERO, 0.0, false, false)


func _expect(value: bool, description: String) -> bool:
	_checks += 1
	if not value:
		_failures.append("FAIL: " + description)
	return value
