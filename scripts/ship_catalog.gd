class_name ShipCatalog
extends RefCounted
# Rebuilt loader for the preserved get_ship/all API. The three JSON loadouts
# are explicitly adapted reconstruction data, not the original 57-ship registry.
const DATA_PATH := "res://data/ships.json"
var data: Dictionary = {"ships": []}
var ships: Dictionary = {}
var valid := false
var last_error := ""

func _init(path: String = DATA_PATH) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "Не удалось открыть каталог кораблей."
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		last_error = "Каталог кораблей содержит неверный JSON."
		return
	restore_catalog(json.data)

static func _number_in(value: Variant, minimum: float, maximum: float, whole := false) -> bool:
	if not (value is int or value is float): return false
	var number := float(value)
	return is_finite(number) and number >= minimum and number <= maximum and (not whole or number == floorf(number))

func restore_catalog(source: Variant) -> bool:
	# Validate into local containers before replacing a previously valid catalogue.
	if not source is Dictionary or not source.get("ships") is Array:
		last_error = "В каталоге отсутствует список кораблей."
		return false
	if source.ships.is_empty() or source.ships.size() > 128:
		last_error = "Неверное число кораблей в каталоге."
		return false
	var candidate: Dictionary = {}
	var rows: Array = []
	var identifier := RegEx.new()
	identifier.compile("^[a-z][a-z0-9_]{0,31}$")
	for entry in source.ships:
		if not entry is Dictionary:
			last_error = "Неверная запись корабля."
			return false
		for key in ["id", "name", "name_ru", "name_en", "description", "color"]:
			if not entry.get(key) is String or str(entry[key]).is_empty() or str(entry[key]).length() > (1000 if key == "description" else 100):
				last_error = "В записи корабля отсутствуют обязательные сведения."
				return false
		if identifier.search(entry.id) == null or candidate.has(entry.id) or not Color.html_is_valid(entry.color):
			last_error = "Неверный идентификатор или цвет корабля."
			return false
		if not _number_in(entry.get("cargo_capacity"), 0, 1000000, true) or not _number_in(entry.get("acceleration"), 0.1, 1000) or not _number_in(entry.get("turn_rate"), 0.01, 20) or not _number_in(entry.get("jump_range"), 0.1, 10000) or not _number_in(entry.get("visual_span_m"), 1, 100000):
			last_error = "Характеристики корабля выходят за допустимые пределы."
			return false
		var row: Dictionary = entry.duplicate(true)
		row.cargo_capacity = int(row.cargo_capacity)
		for key in ["acceleration", "turn_rate", "jump_range", "visual_span_m"]: row[key] = float(row[key])
		candidate[row.id] = row
		rows.append(row)
	var candidate_data: Dictionary = source.duplicate(true)
	candidate_data.ships = rows
	ships = candidate
	data = candidate_data
	valid = true
	last_error = ""
	return true

func get_ship(id: String) -> Dictionary:
	# Callers receive their own metadata view; UI code cannot mutate live limits.
	return ships[id].duplicate(true) if ships.has(id) else {}

func all() -> Array:
	return data.ships.duplicate(true)
