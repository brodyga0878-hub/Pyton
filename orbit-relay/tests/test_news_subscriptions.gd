extends SceneTree

const Calendar := preload("res://scripts/mission_calendar.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Main := preload("res://main.tscn")
const Session := preload("res://scripts/session_io.gd")
const NAV := "navigation"
const FRONTIER := "frontier"
const DISPATCH := "dispatch"

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_publication()
	_test_calendar_wait()
	await _test_touch()
	for failure: String in _failures:
		printerr(failure)
	print("News subscriptions: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _test_publication() -> void:
	var flight := Flight.new()
	_expect(not flight.subscribe_news(NAV) and flight.credits == 0, "An empty credit account cannot buy a subscription")
	flight.credits = 180
	var offers := flight.news_publications()
	var budget := flight.credits
	_expect(offers.size() == 3 and offers[0].days == 1 and offers[1].days == 2 and offers[2].days == 7
		and offers[0].next < offers[1].next and offers[1].next < offers[2].next,
		"Each editor has a distinct recurring date and price")
	_expect(flight.news_publication_archive(NAV).is_empty() and flight.news_publication_issue(NAV, 0.0).is_empty(),
		"An unsubscribed publication keeps both archive and direct issues locked")
	if not _expect(flight.subscribe_news(NAV) and flight.credits == budget - int(offers[0].price),
		"Buying an original publication charges the real flight account"):
		return
	var remaining := flight.credits
	_expect(not flight.subscribe_news(NAV) and not flight.subscribe_news("unknown") and flight.credits == remaining,
		"Neither a duplicate purchase nor an unknown publication incurs a debit")
	_expect(flight.news_publication_archive(FRONTIER).is_empty() and flight.news_publication_archive(DISPATCH).is_empty()
		and flight.news_publication_issue(NAV, 0.0).articles[0].title == "Скорость в кадре цели",
		"One subscription opens its original first edition and leaves the other publications locked")
	_expect(flight.news.record("feed-known", "story_brief", Catalog.HOME_SYSTEM, 0.0, "Проверка маяка")
		and flight.news.record("feed-hidden", "story_brief", Catalog.SYSTEM_COUNT - 1, 0.0, "Невидимый журнал")
		and flight.news.record("feed-other", "war_declared", Catalog.HOME_SYSTEM, 0.0, "Чужая редакция")
		and not flight.system_known(Catalog.SYSTEM_COUNT - 1), "Prepare event notes from different desks and visibility scopes")
	var released := float(offers[0].next)
	_expect(flight.news_publication_issue(NAV, released).is_empty(), "The next issue stays inaccessible until its calendar time")
	if not _expect(flight.wait_on_calendar(released), "Request the next publication time from a safe berth"):
		return
	_tick(flight, 1.0)
	var edition := flight.news_publication_issue(NAV, released)
	_expect(not edition.is_empty() and edition.articles.size() == 2 and edition.articles[1].id == "feed-known"
		and float(flight.news_publication_archive(NAV)[1].published_at) == 0.0,
		"Exactly the known, matching event appears in the new issue and the initial issue remains readable")
	var before := flight.snapshot()
	var cold := Flight.new()
	_expect(Session.save_state(before, "user://periodicals.json") == OK
		and Session.load_valid_state("user://periodicals.json", cold.restore) == Session.LoadResult.PRIMARY
		and cold.news_publication_issue(NAV, released) == edition,
		"A full save round trip retains the paid dates and rebuilds the same dated issue")
	var malformed := before.duplicate(true)
	malformed.periodicals[NAV] = Calendar.MAX_EPOCH
	_expect(not flight.restore(malformed) and flight.snapshot() == before,
		"Reject a fabricated future entitlement without altering the current flight")
	var expiry := float(flight.news_publications()[0].until)
	flight.orbit_time = expiry
	_expect(not flight.news_publications()[0].active and flight.news_publication_issue(NAV, released).is_empty()
		and flight.subscribe_news(NAV) and flight.credits == remaining - int(offers[0].price),
		"Expiry unlocks a new purchase and temporarily closes each archived issue")


func _test_calendar_wait() -> void:
	var flight := Flight.new()
	var first := Calendar.next_midnight(flight.orbit_time)
	_expect(first == 78.0 and Calendar.stamp(first) == "02.01.2478 · 00:00:00"
		and Calendar.next_midnight(Calendar.MAX_EPOCH) == -1.0, "The existing calendar epoch and day boundary are exact")
	var midnight := Time.get_unix_time_from_datetime_string("2480-02-29T00:00:00") - Calendar.START_UNIX
	_expect(Calendar.next_midnight(midnight - 1.0) == midnight and Calendar.date(midnight) == "29.02.2480",
		"UTC civil calendar includes its own actual leap day")
	_expect(not flight.wait_on_calendar(flight.orbit_time) and flight.wait_on_calendar(first)
		and flight.time_scale == 256 and float(flight.clock_status().wait_until) == first,
		"A future date arms the bounded fast advance")
	_tick(flight, 1.0)
	_expect(flight.orbit_time == first and flight.time_scale == 1 and flight.status_event == "calendar_wait_finished"
		and float(flight.clock_status().wait_until) < 0.0, "Fast advance stops at the requested second and restores ordinary time")
	_expect(flight.wait_on_calendar(first + 1200.0) and flight.reset_time_scale()
		and float(flight.clock_status().wait_until) < 0.0, "Manually resetting the time rate clears the target date")
	_expect(Fixture.launch(flight) and not flight.wait_on_calendar(first + 1200.0) and flight.time_scale == 1,
		"Scheduled waiting is gated to a stationary berth or a landing")
	var timed := Flight.new()
	if not _expect(timed.passenger_accept(1), "Book a real passenger deadline before attempting a long calendar wait"):
		return
	var deadline: float = timed.passenger_status().deadline
	_expect(timed.wait_on_calendar(deadline + 1200.0), "A date can be selected beyond a current mission deadline")
	_tick(timed, 2.0)
	_expect(timed.orbit_time == deadline - Flight.FAST_WAIT_DEADLINE_MARGIN and timed.time_scale == 1
		and float(timed.clock_status().wait_until) < 0.0 and not timed.passenger_status().overdue,
		"Mission protection safely supersedes a planned calendar wait")


func _test_touch() -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(854, 480)
	root.add_child(viewport)
	var game := Main.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = Flight.new()
	game.flight.credits = 180
	game._handle_action("journal")
	await process_frame
	var page: Node = game._journal._news_page
	_tap(viewport, game._journal._news_tab)
	await process_frame
	_tap(viewport, page._feed_buttons[NAV])
	await process_frame
	_expect(page._subscription.visible and not page._subscription.disabled
		and page._archive_title.text == "Вахтенный журнал" and page._archive.is_empty(),
		"The journal displays a locked paid feed with its subscription button")
	_tap(viewport, page._subscription)
	await process_frame
	_expect(not page._subscription.visible and page._article_title.text == "Скорость в кадре цели"
		and Session.load_state().periodicals.has(NAV), "A real touch buys the feed, displays an issue and saves its expiry")
	var model := viewport.get_visible_rect().grow(0.5)
	_expect(model.encloses(page._wait.get_global_rect()) and model.encloses(page._issue_buttons[0].get_global_rect()),
		"Issue and wait controls fit a short landscape viewport")
	_tap(viewport, page._wait)
	await process_frame
	_expect(not game._journal.is_open() and game.flight.time_scale == 256,
		"Waiting for a scheduled edition closes the journal and resumes the simulation")
	viewport.queue_free()
	await create_timer(0.15).timeout


func _tap(viewport: SubViewport, button: Button) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 8
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		viewport.push_input(event, true)


func _tick(flight: Flight, delta: float) -> void:
	flight.update(delta, Vector2.ZERO, 0.0, false, false)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
