extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Expedition := preload("res://scripts/expedition.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const SectorNews := preload("res://scripts/sector_news.gd")
const Session := preload("res://scripts/session_io.gd")
const LAST_PREVIOUSLY_WRITABLE := 223
const PREVIOUS_BYTE_LIMIT := 256 * 1024

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var directory := "user://extended-session-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var absolute := ProjectSettings.globalize_path(directory)
	if _expect(DirAccess.make_dir_absolute(absolute) == OK, "Create an isolated directory for this test"):
		_test_previous_boundary(directory.path_join("boundary.json"))
		_test_full_session(directory)
		for file: String in DirAccess.get_files_at(absolute):
			DirAccess.remove_absolute(absolute.path_join(file))
		DirAccess.remove_absolute(absolute)
	for failure: String in _failures:
		printerr(failure)
	print("Extended session integration: %d checks, %d failures" % [_checks, _failures.size()])
	quit(int(not _failures.is_empty()))


func _test_previous_boundary(path: String) -> void:
	var flight := Flight.new()
	if not _expect(_discover_catalog(flight) and flight.known_systems().size() == Catalog.SYSTEM_COUNT - 2,
		"Reproduce the original boundary with all generated systems and the three starting systems known"):
		return
	var observations := 0
	for site in range(Catalog.DESTINATION_COUNT):
		if not Catalog.is_mine_site(site) or not flight.system_known(Catalog.system_of_site(site)):
			continue
		if not flight.cartography.record(site, flight.orbit_time):
			break
		observations += 1
		if observations == LAST_PREVIOUSLY_WRITABLE or observations == LAST_PREVIOUSLY_WRITABLE + 1:
			var snapshot := flight.snapshot()
			var restored := Flight.new()
			_expect(restored.restore(snapshot), "The flight model accepts %d observations" % observations)
			_expect(Session.save_state(snapshot, path) == OK, "Write the real snapshot with %d observations" % observations)
			_expect(Session.load_valid_state(path, restored.restore) == Session.LoadResult.PRIMARY
				and restored.cartography.surveyed_sites().size() == observations,
				"Read the current primary with exactly %d observations" % observations)
		if observations > LAST_PREVIOUSLY_WRITABLE:
			break
	_expect(observations == LAST_PREVIOUSLY_WRITABLE + 1, "Exercise both sides of the old 223-observation boundary")


func _test_full_session(directory: String) -> void:
	var flight := Flight.new()
	var charter := flight.expedition.snapshot()
	for index in range(Expedition.FRONTIER_SYSTEMS.size()):
		charter.projects[index] = {"phase": Expedition.COMPLETE, "sponsor_port": flight.docked, "sponsor": 0,
			"scan_index": Expedition.SURVEY_TOTAL, "build_index": Expedition.BUILD_TOTAL}
	if not _expect(flight.expedition.restore(charter) and _discover_catalog(flight),
		"Restore both completed construction projects and discover the generated catalog"):
		return
	for system: int in Expedition.FRONTIER_SYSTEMS:
		if not _expect(flight.factions.commission(system, 0, flight.orbit_time)
			and flight.freight.activate_frontier(system, flight.orbit_time),
			"Schedule ownership and freight for the commissioned system %d" % system):
			return
	if not _expect(flight.known_systems().size() == Catalog.SYSTEM_COUNT, "All catalog systems are known"):
		return
	for site in range(Catalog.DESTINATION_COUNT):
		if not flight.cartography.record(site, flight.orbit_time):
			break
	if not _expect(flight.cartography.surveyed_sites().size() == Catalog.DESTINATION_COUNT,
		"Record observations for every catalog site, including both commissioned ports"):
		return

	var news_text := "Я" + "🚀".repeat(SectorNews.MAX_TEXT - 1)
	var id_prefix := "x".repeat(SectorNews.MAX_KEY - 4)
	var related := "y".repeat(SectorNews.MAX_KEY)
	var action := "z".repeat(SectorNews.MAX_KEY)
	for index in range(SectorNews.MAX_REPORTS):
		var id := "%s%04d" % [id_prefix, index]
		if not flight.news.record(id, "war_round", Catalog.HEATHER_SYSTEM, flight.orbit_time, news_text, related, action):
			break
	flight.credits = 600
	if not _expect(flight.news.snapshot().reports.size() == SectorNews.MAX_REPORTS
		and flight.market_trade("ore", "buy", 1) and flight.contract_action()
		and flight.plan_route(Catalog.SYSTEM_COUNT - 1),
		"Fill the news archive with long Unicode text and prepare an actual trade, contract and galactic route"):
		return

	var path := directory.path_join("flight.json")
	var snapshot := flight.snapshot()
	var restored := Flight.new()
	if not _expect(restored.restore(snapshot), "The flight model accepts the combined large session"):
		return
	var serialized := JSON.stringify(snapshot, "", true, true)
	var serialized_size := serialized.to_utf8_buffer().size()
	_expect(serialized_size > PREVIOUS_BYTE_LIMIT, "A valid wide Unicode session exceeds the previous byte limit")
	print("Full session fixture: %d bytes" % serialized_size)
	var first_written := Session.save_state(snapshot, path) == OK
	_expect(first_written, "Write the complete chart, news archive and active flight state")
	if first_written:
		var original_bytes := FileAccess.get_file_as_bytes(path)
		var cold := Flight.new()
		_expect(Session.load_valid_state(path, cold.restore) == Session.LoadResult.PRIMARY
			and cold.cartography.surveyed_sites().size() == Catalog.DESTINATION_COUNT
			and cold.news.snapshot().reports.size() == SectorNews.MAX_REPORTS
			and Session.load_state(path) == JSON.parse_string(serialized),
			"A fresh load restores all chart, economy, route and Unicode news data")
		_test_large_backup(flight, path, original_bytes)
	_test_diagnostic_archive(snapshot, directory.path_join("diagnostics.zip"))


func _test_large_backup(flight: Flight, path: String, original_bytes: PackedByteArray) -> void:
	var previous_credits := flight.credits
	flight.credits += 1
	if not _expect(Session.save_state(flight.snapshot(), path) == OK, "Write a newer complete save and rotate its predecessor"):
		return
	var backup_path := path + ".previous"
	var current := Flight.new()
	_expect(FileAccess.get_file_as_bytes(backup_path) == original_bytes
		and Session.load_valid_state(path, current.restore) == Session.LoadResult.PRIMARY
		and current.credits == flight.credits,
		"The backup keeps the exact older bytes and the valid primary wins")

	var corrupted := FileAccess.get_file_as_bytes(path)
	var first_unicode := 0
	while first_unicode < corrupted.size() and corrupted[first_unicode] < 0x80:
		first_unicode += 1
	if not _expect(first_unicode < corrupted.size(), "The full save contains UTF-8 text to corrupt"):
		return
	corrupted[first_unicode] = 0xc0
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not _expect(file != null, "Open the isolated primary to simulate corruption"):
		return
	file.store_buffer(corrupted)
	file.close()
	var recovered := Flight.new()
	if not _expect(Session.load_valid_state(path, recovered.restore) == Session.LoadResult.BACKUP
		and recovered.credits == previous_credits and recovered.known_systems().size() == Catalog.SYSTEM_COUNT
		and recovered.cartography.surveyed_sites().size() == Catalog.DESTINATION_COUNT
		and FileAccess.get_file_as_bytes(backup_path) == original_bytes,
		"Reject malformed UTF-8 and restore the complete older chart without rewriting the backup"):
		return
	recovered.credits += 2
	var repaired := Flight.new()
	_expect(Session.save_state(recovered.snapshot(), path, true) == OK
		and Session.load_valid_state(path, repaired.restore) == Session.LoadResult.PRIMARY
		and repaired.credits == recovered.credits and FileAccess.get_file_as_bytes(backup_path) == original_bytes,
		"The first save after recovery repairs the primary and preserves the original backup bytes")


func _test_diagnostic_archive(snapshot: Dictionary, path: String) -> void:
	var log := Session.new()
	log.trace("large_session", {"text": "Проверка"})
	var result := log.export_report(snapshot, path)
	var archive := ZIPReader.new()
	if not _expect(result.ok and archive.open(result.path) == OK, "Open the large session diagnostic ZIP"):
		return
	var report: Variant = JSON.parse_string(archive.read_file("report.json").get_string_from_utf8())
	var event: Variant = JSON.parse_string(archive.read_file("events.jsonl").get_string_from_utf8())
	var has_flight := archive.file_exists("flight.json")
	var archived := archive.read_file("flight.json") if has_flight else PackedByteArray()
	archive.close()
	var expected := JSON.stringify(snapshot, "", true, true).to_utf8_buffer()
	var restored := Flight.new()
	_expect(report is Dictionary and report.get("includes_flight_state", false)
		and archived == expected and restored.restore(JSON.parse_string(archived.get_string_from_utf8()))
		and event is Dictionary and event.get("fields", {}).get("text") == "Проверка",
		"The ZIP includes the exact resumable flight JSON alongside metadata and the localized event journal")


func _discover_catalog(flight: Flight) -> bool:
	var chart := flight.cartography.snapshot()
	for system in range(Catalog.AUTHORED_SYSTEM_COUNT, Catalog.SYSTEM_COUNT):
		chart.systems.append({"system": system, "epoch": flight.orbit_time})
	return flight.cartography.restore(chart, flight.orbit_time)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
