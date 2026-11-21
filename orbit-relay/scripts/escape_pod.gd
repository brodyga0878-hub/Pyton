extends RefCounted
## The pre-existing flight retires while the pilot drifts in an emergency capsule.

const Catalog := preload("res://scripts/sector_catalog.gd")

const PICKUP_DELAY := 12.0
const EJECT_HULL_LIMIT := 25.0
const EJECTION_SPEED := 12.0
const MAX_DRIFT_SPEED := 42.0
const RESCUE_FEE := 120
const WORLD_LIMIT := 10000000.0
const MAX_EPOCH := 3155760000.0
const FIELDS := ["system", "wreck", "ejected_at", "port", "pickup_at"]

var active := false
var wreck_position := Vector3.ZERO
var ejected_at := 0.0
var port := -1
var pickup_at := 0.0


func eject(wreck: Vector3, epoch: float) -> void:
	active = true
	wreck_position = wreck
	ejected_at = epoch
	port = -1
	pickup_at = 0.0


func request(site: int, epoch: float) -> bool:
	if not active or port >= 0 or site < 0:
		return false
	port = site
	pickup_at = minf(epoch + PICKUP_DELAY, MAX_EPOCH)
	return true


func snapshot(system: int) -> Dictionary:
	if not active:
		return {}
	return {"system": system, "wreck": [wreck_position.x, wreck_position.y, wreck_position.z],
		"ejected_at": ejected_at, "port": port, "pickup_at": pickup_at}


func restore(raw: Variant, epoch: float, system: int, operational: Callable) -> bool:
	if not raw is Dictionary:
		return false
	if raw.is_empty():
		return true
	if raw.size() != FIELDS.size() or not raw.has_all(FIELDS) or not _integer(raw.system, system, system):
		return false
	if not _number(raw.ejected_at, 0.0, epoch) or not _integer(raw.port, -1, Catalog.DESTINATION_COUNT - 1):
		return false
	var wreck := _decode_position(raw.wreck)
	if not wreck.is_finite():
		return false
	var site := int(raw.port)
	if site < 0:
		if not _number(raw.pickup_at, 0.0, 0.0):
			return false
	elif not operational.call(site) or not _number(raw.pickup_at, epoch, minf(MAX_EPOCH, epoch + PICKUP_DELAY)) \
			or float(raw.pickup_at) <= epoch:
		return false
	eject(wreck, float(raw.ejected_at))
	port = site
	pickup_at = float(raw.pickup_at)
	return true


static func _decode_position(raw: Variant) -> Vector3:
	if not raw is Array or raw.size() != 3:
		return Vector3.INF
	for value: Variant in raw:
		if not _number(value, -WORLD_LIMIT, WORLD_LIMIT):
			return Vector3.INF
	return Vector3(raw[0], raw[1], raw[2])


static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value, low, high) and floorf(float(value)) == float(value)


static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high
