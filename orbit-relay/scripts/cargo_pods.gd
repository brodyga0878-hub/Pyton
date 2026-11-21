extends RefCounted
## A loose container holds one unit removed from the ship's shared cargo hold.

const Economy := preload("res://scripts/port_economy.gd")

const CAPACITY := 16
const LIFETIME := 3600.0
const EJECT_CLEARANCE := 8.0
const EJECT_SPEED := 3.0
const MAX_POSITION := 10000000.0 + EJECT_CLEARANCE
const MAX_EPOCH := 3155760000.0
const MAX_ID := 2147483647
const ITEM_FIELDS := ["id", "system", "good", "position", "velocity", "created"]

var tracked := -1
var _next_id := 1
var _items: Dictionary[int, Dictionary] = {}


func can_eject() -> bool:
	return _items.size() < CAPACITY and _next_id < MAX_ID


func eject(rig: RefCounted, system: int, good: String, position: Vector3, velocity: Vector3, epoch: float, max_speed: float) -> bool:
	if not can_eject() or not _valid_vectors(position, velocity, max_speed) or not _number(epoch, 0.0, MAX_EPOCH):
		return false
	if not rig.remove_cargo(good, 1):
		return false
	_items[_next_id] = {"system": system, "good": good, "position": position, "velocity": velocity, "created": epoch}
	_next_id += 1
	return true


func collect(rig: RefCounted, id: int) -> bool:
	if not _items.has(id) or not rig.insert_cargo(_items[id].good, 1):
		return false
	_remove(id)
	return true


func advance(epoch: float) -> void:
	if _items.is_empty():
		return
	for id: int in _items.keys():
		if epoch - float(_items[id].created) >= LIFETIME:
			_remove(id)


func _remove(id: int) -> void:
	_items.erase(id)
	if tracked == id:
		tracked = -1


func local(system: int, epoch: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: int in _items:
		var item := _items[id]
		var age := epoch - float(item.created)
		if int(item.system) == system and age >= 0.0 and age < LIFETIME:
			var origin: Vector3 = item.position
			var velocity: Vector3 = item.velocity
			result.append({"id": id, "system": system, "good": item.good,
				"position": origin + velocity * age, "velocity": velocity, "remaining": LIFETIME - age})
	return result


func snapshot() -> Dictionary:
	var items: Array[Dictionary] = []
	for id: int in _items:
		var item := _items[id]
		var position: Vector3 = item.position
		var velocity: Vector3 = item.velocity
		items.append({"id": id, "system": item.system, "good": item.good, "created": item.created,
			"position": [position.x, position.y, position.z], "velocity": [velocity.x, velocity.y, velocity.z]})
	return {"next_id": _next_id, "tracked": tracked, "items": items}


func restore(raw: Variant, epoch: float, current_system: int, known: Array[int], max_speed: float) -> bool:
	if not raw is Dictionary or raw.size() != 3 or not _integer(raw.get("next_id"), 1, MAX_ID):
		return false
	var limit := int(raw.next_id) - 1
	if not _integer(raw.get("tracked"), -1, limit) or not raw.get("items") is Array or raw.items.size() > CAPACITY:
		return false
	var restored: Dictionary[int, Dictionary] = {}
	var previous_id := 0
	for item: Variant in raw.items:
		if not item is Dictionary or item.size() != ITEM_FIELDS.size() or not item.has_all(ITEM_FIELDS):
			return false
		if not _integer(item.id, previous_id + 1, limit) or not _integer(item.system, 0, MAX_ID) or int(item.system) not in known:
			return false
		if not item.good is String or not Economy.GOODS.has(item.good) or not _number(item.created, 0.0, epoch):
			return false
		if epoch - float(item.created) >= LIFETIME:
			return false
		var position := _decode_vector(item.position, MAX_POSITION)
		var velocity := _decode_vector(item.velocity, max_speed)
		if not _valid_vectors(position, velocity, max_speed):
			return false
		previous_id = int(item.id)
		restored[previous_id] = {"system": int(item.system), "good": item.good, "created": float(item.created),
			"position": position, "velocity": velocity}
	var restored_tracked := int(raw.tracked)
	if restored_tracked != -1 and (not restored.has(restored_tracked) or int(restored[restored_tracked].system) != current_system):
		return false
	_items = restored
	_next_id = int(raw.next_id)
	tracked = restored_tracked
	return true


static func _valid_vectors(position: Vector3, velocity: Vector3, max_speed: float) -> bool:
	var magnitude := position.abs()
	return position.is_finite() and maxf(magnitude.x, maxf(magnitude.y, magnitude.z)) <= MAX_POSITION \
		and velocity.is_finite() and velocity.length() <= max_speed


static func _decode_vector(raw: Variant, limit: float) -> Vector3:
	if not raw is Array or raw.size() != 3:
		return Vector3.INF
	for value: Variant in raw:
		if not _number(value, -limit, limit):
			return Vector3.INF
	return Vector3(raw[0], raw[1], raw[2])


static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high


static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value, low, high) and value == floorf(float(value))
