extends RefCounted
## A single-use energy cell for the fictional short-range ship pulse.

const COST := 240
const RADIUS := 220.0
const DAMAGE := 76.0
const VISUAL_SECONDS := 0.82
const WORLD_LIMIT := 10000000.0
const MAX_EPOCH := 3155760000.0
const FIELDS := ["system", "origin", "until"]

var count := 0
var wave: Dictionary = {}


func emit_at(origin: Vector3, system: int, epoch: float) -> bool:
	if count != 1 or not wave.is_empty() or not _number(epoch, 0.0, MAX_EPOCH - VISUAL_SECONDS):
		return false
	if not origin.is_finite():
		return false
	count = 0
	wave = {"origin": origin, "system": system, "until": epoch + VISUAL_SECONDS}
	return true


func advance(epoch: float) -> void:
	if not wave.is_empty() and epoch >= float(wave.until):
		wave.clear()


func status(epoch: float) -> Dictionary:
	var active := not wave.is_empty()
	var left := maxf(0.0, float(wave.until) - epoch) if active else 0.0
	return {"count": count, "active": active, "position": wave.get("origin", Vector3.ZERO),
		"radius": RADIUS, "progress": clampf(1.0 - left / VISUAL_SECONDS, 0.0, 1.0) if active else 0.0}


func snapshot() -> Dictionary:
	var state := wave.duplicate()
	if not state.is_empty():
		var origin: Vector3 = state.origin
		state.origin = [origin.x, origin.y, origin.z]
	return {"count": count, "wave": state}


func restore(raw: Variant, epoch: float, system: int) -> bool:
	if not raw is Dictionary or raw.size() != 2 or not _integer(raw.get("count"), 0, 1) or not raw.get("wave") is Dictionary:
		return false
	var state: Dictionary = raw.wave
	var restored_wave := {}
	if not state.is_empty():
		if raw.count != 0 or state.size() != FIELDS.size() or not state.has_all(FIELDS) or not _integer(state.system, system, system):
			return false
		if not _number(state.until, epoch, minf(MAX_EPOCH, epoch + VISUAL_SECONDS + 0.000002)) or float(state.until) <= epoch:
			return false
		var origin := _decode_position(state.origin)
		if not origin.is_finite():
			return false
		restored_wave = {"origin": origin, "system": system, "until": float(state.until)}
	count = int(raw.count)
	wave = restored_wave
	return true


static func _decode_position(raw: Variant) -> Vector3:
	if not raw is Array or raw.size() != 3:
		return Vector3.INF
	for item: Variant in raw:
		if not _number(item, -WORLD_LIMIT, WORLD_LIMIT):
			return Vector3.INF
	return Vector3(raw[0], raw[1], raw[2])


static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value, low, high) and floorf(float(value)) == float(value)


static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high
