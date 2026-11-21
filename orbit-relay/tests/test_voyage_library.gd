extends SceneTree

const Library := preload("res://scripts/voyage_library.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Session := preload("res://scripts/session_io.gd")

var _checks := 0
var _failures: Array[String] = []
var _created: Array[String] = []
var _unique := "%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var autosave := FileAccess.get_file_as_bytes(Session.SAVE_PATH)
	var backup := FileAccess.get_file_as_bytes(Session.SAVE_PATH + ".previous")
	var initial := Library.list_slots()
	if _expect(initial.size() <= Library.MAX_SLOTS - 3, "Use a test data directory with at least three free slots"):
		_test_named_round_trip()
		_test_corruption()
		_test_capacity()
	for id: String in _created:
		Library.delete_slot(id)
	_expect(Library.list_slots() == initial, "Only test-owned records are removed")
	_expect(FileAccess.get_file_as_bytes(Session.SAVE_PATH) == autosave
		and FileAccess.get_file_as_bytes(Session.SAVE_PATH + ".previous") == backup,
		"Named flight management leaves autosave and backup untouched")
	print("Voyage library: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(int(not _failures.is_empty()))


func _test_named_round_trip() -> void:
	var pilot := Flight.new()
	pilot.credits = 325
	var name := "Рейс 🛰 " + _unique
	var id := _create("\u00a0" + name + "\u2007", pilot.snapshot())
	pilot.credits = 771
	var second_name := "Копия " + _unique
	var other := _create(second_name, pilot.snapshot())
	if id.is_empty() or other.is_empty():
		return
	_expect(id != other and id.length() == 32 and _entry(id).get("name") == name,
		"Unicode labels trim surrounding spacing and receive separate stable IDs")
	var duplicate := Library.create_slot("  " + name.to_upper() + "  ", pilot.snapshot())
	_expect(not duplicate.ok and duplicate.error == ERR_ALREADY_EXISTS,
		"Names that differ only in case or surrounding spacing cannot overwrite a slot")
	_expect(Library.rename_slot(id, second_name.to_upper()) == ERR_ALREADY_EXISTS and _entry(id).name == name,
		"Renaming to an occupied name leaves the original metadata untouched")
	_expect(Library.rename_slot(id, name + "\nСтрока") == ERR_INVALID_PARAMETER and _entry(id).name == name,
		"Line breaks cannot enter a display name")
	var new_name := "Маршрут " + _unique
	_expect(Library.rename_slot(id, new_name) == OK and _entry(id).get("name") == new_name,
		"Rename updates the stored label while retaining the assigned ID")
	var restored := Flight.new()
	_expect(Library.load_slot(id, restored.restore) and restored.credits == 325,
		"Renaming retains the original full flight contents")
	_expect(Library.load_slot(other, restored.restore) and restored.credits == 771,
		"An independently named flight restores its own state")
	_expect(not Library.load_slot("../flight.json", restored.restore)
		and Library.delete_slot("../flight.json") == ERR_INVALID_PARAMETER and restored.credits == 771,
		"Path-shaped identifiers cannot access a different save")
	_expect(Library.delete_slot(id) == OK and not Library.load_slot(id, restored.restore)
		and Library.delete_slot(id) == ERR_FILE_NOT_FOUND and not _entry(other).is_empty(),
		"Deleting a chosen flight does not delete its neighbour")
	_expect(Library.delete_slot(other) == OK, "Release the test's second slot")


func _test_corruption() -> void:
	var pilot := Flight.new()
	pilot.credits = 612
	var bad_state := pilot.snapshot()
	bad_state.ship.fuel = -1.0
	var id := _create("Проверка " + _unique, bad_state)
	if id.is_empty():
		return
	var live := Flight.new()
	var prior := live.snapshot()
	_expect(not Library.load_slot(id, live.restore) and live.snapshot() == prior,
		"Semantic validation rejects a nonphysical snapshot atomically")
	var path := Library.DIRECTORY.path_join(id + Library.EXTENSION)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not _expect(file != null, "Open the test-owned payload to emulate a truncated write"):
		return
	file.store_string("{\"partial\":")
	file.close()
	_expect(not Library.load_slot(id, live.restore) and _entry(id).get("name") == "Повреждённый рейс",
		"A damaged file remains listed for removal and never reaches the live flight")
	_expect(Library.rename_slot(id, "Целое имя " + _unique) == ERR_FILE_CORRUPT
		and Library.delete_slot(id) == OK,
		"Rename cannot disguise an unreadable record and deletion frees its space")


func _test_capacity() -> void:
	var state := Flight.new().snapshot()
	var count := Library.list_slots().size()
	for slot in range(count, Library.MAX_SLOTS):
		if _create("Запись %d %s" % [slot, _unique], state).is_empty():
			return
	var blocked := Library.create_slot("Запись сверх лимита " + _unique, state)
	_expect(not blocked.ok and blocked.error == ERR_UNAVAILABLE and Library.list_slots().size() == Library.MAX_SLOTS,
		"The library enforces its cap without removing existing flights")
	var overlong := Library.create_slot("Я".repeat(Library.MAX_NAME_LENGTH + 1), state)
	_expect(not overlong.ok and overlong.error == ERR_INVALID_PARAMETER, "Name limit counts Unicode codepoints")


func _entry(id: String) -> Dictionary:
	for entry in Library.list_slots():
		if entry.id == id:
			return entry
	return {}


func _create(name: String, state: Dictionary) -> String:
	var result := Library.create_slot(name, state)
	if not _expect(result.ok, "Create a named flight in the isolated library"):
		return ""
	_created.append(result.id)
	return result.id


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
