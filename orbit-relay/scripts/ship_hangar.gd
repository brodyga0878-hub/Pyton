extends RefCounted
## A parked hull keeps its integrity and berth. The pilot transfers equipment and crew.

const ShipSystems := preload("res://scripts/ship_systems.gd")
const LIMIT := 5
const LAST_ID := 1000000000
const FIELDS := ["slot", "port", "hull", "condition"]

var _rows: Array[Dictionary] = []
var _next_id := 1


func rows() -> Array[Dictionary]:
	return _rows.duplicate(true)


func can_park() -> bool:
	return _rows.size() < LIMIT and _next_id < LAST_ID


func can_replace() -> bool:
	return _next_id < LAST_ID


func find(id: String) -> Dictionary:
	for record: Dictionary in _rows:
		if key(record.slot) == id:
			return record.duplicate()
	return {}


func park(ship_id: String, condition: float, port: int) -> void:
	_rows.append({"slot": _next_id, "port": port, "hull": ship_id, "condition": condition})
	_next_id += 1


func release(id: String) -> void:
	for index in range(_rows.size()):
		if key(_rows[index].slot) == id:
			_rows.remove_at(index)
			return


func snapshot() -> Dictionary:
	return {"next_id": _next_id, "rows": rows()}


func restore(raw: Variant, yard_exists: Callable) -> bool:
	if not raw is Dictionary or raw.size() != 2 or not _integer(raw.get("next_id"), 1, LAST_ID):
		return false
	var staged: Variant = raw.get("rows")
	if not staged is Array or staged.size() > LIMIT:
		return false
	var records: Array[Dictionary] = []
	var latest := 0
	var next := int(raw.next_id)
	for entry: Variant in staged:
		if not entry is Dictionary or entry.size() != FIELDS.size() or not entry.has_all(FIELDS):
			return false
		if not _integer(entry.slot, latest + 1, next - 1) or not _integer(entry.port, 0, 1000000000):
			return false
		if not yard_exists.call(int(entry.port)) or not entry.hull is String or ShipSystems.profile(entry.hull).is_empty():
			return false
		if not _number(entry.condition, ShipSystems.MIN_HULL, ShipSystems.MAX_HULL):
			return false
		latest = int(entry.slot)
		records.append({"slot": latest, "port": int(entry.port), "hull": entry.hull, "condition": float(entry.condition)})
	_rows = records
	_next_id = next
	return true


static func key(slot: int) -> String:
	return "hangar-%d" % slot


static func appraisal(record: Dictionary) -> int:
	var price := int(ShipSystems.profile(record.hull).price)
	return floori(price * float(record.condition) * ShipSystems.TRADE_IN_PERCENT / 10000.0)


static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high


static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value, low, high) and floorf(float(value)) == value
