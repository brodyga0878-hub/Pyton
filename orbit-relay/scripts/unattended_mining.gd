extends RefCounted
## A single owned rig can remain installed while its ship is away.

const Catalog = preload("res://scripts/sector_catalog.gd")
const MiningRig = preload("res://scripts/mining_rig.gd")
const Terrain = preload("res://scripts/surface_terrain.gd")

const CAPACITY := 48
const MAX_EPOCH := 3155760000.0
# Binary subdivisions stay exact over the save's supported century of time.
const TICKS_PER_SECOND := 1048576.0
const SAVE_FIELDS := ["site_id", "direction", "stored", "next_epoch"]

var site_id := -1
var direction := Vector3.ZERO
var stored := 0
var next_epoch := -1.0


func active() -> bool:
	return site_id >= 0


func deploy(rig: RefCounted, site: int, local_direction: Vector3, epoch: float) -> bool:
	if active() or rig.phase != MiningRig.STOWED or not _valid_epoch(epoch) or not _valid_patch(site, local_direction):
		return false
	if rig.reserve_at(site) <= 0:
		return false
	site_id = site
	direction = local_direction
	var first_wait := MiningRig.DEPLOY_SECONDS + float(Catalog.site(site).drill_seconds)
	next_epoch = _ticks(epoch + first_wait) / TICKS_PER_SECOND
	return true


func advance(rig: RefCounted, epoch: float) -> int:
	if not active() or next_epoch < 0.0 or rig.phase != MiningRig.STOWED or not _valid_epoch(epoch) or epoch < next_epoch:
		return 0
	var clock := floori(epoch * TICKS_PER_SECOND)
	var deadline := _ticks(next_epoch)
	var interval := _drill_ticks(site_id)
	@warning_ignore("integer_division")
	var batches := 1 + (clock - deadline) / interval
	var extracted: int = rig.extract_remote(site_id, mini(CAPACITY - stored, batches * MiningRig.BATCH))
	stored += extracted
	if stored >= CAPACITY or rig.reserve_at(site_id) == 0:
		next_epoch = -1.0
	else:
		next_epoch = (deadline + batches * interval) / TICKS_PER_SECOND
	return extracted


func unload(rig: RefCounted, epoch: float) -> int:
	if not active() or not _valid_epoch(epoch):
		return 0
	var units := mini(stored, rig.free_capacity())
	if units <= 0 or not rig.insert_cargo(Catalog.site(site_id).resource, units):
		return 0
	stored -= units
	if next_epoch < 0.0 and rig.reserve_at(site_id) > 0:
		next_epoch = (_ticks(epoch) + _drill_ticks(site_id)) / TICKS_PER_SECOND
	return units


func retrieve() -> bool:
	if not active() or stored != 0:
		return false
	_clear()
	return true


func snapshot() -> Dictionary:
	if not active():
		return {}
	return {"site_id": site_id, "direction": [direction.x, direction.y, direction.z],
		"stored": stored, "next_epoch": next_epoch}


func restore(raw: Variant, epoch: float, rig: RefCounted) -> bool:
	if not raw is Dictionary or not _valid_epoch(epoch):
		return false
	if raw.is_empty():
		_clear()
		return true
	if raw.size() != SAVE_FIELDS.size() or not raw.has_all(SAVE_FIELDS) or rig.phase != MiningRig.STOWED:
		return false
	if not _integer(raw.site_id, 0, Catalog.SITE_ID_LIMIT - 1):
		return false
	var restored_site := int(raw.site_id)
	var encoded: Variant = raw.direction
	if not encoded is Array or encoded.size() != 3:
		return false
	for coordinate: Variant in encoded:
		if not _number(coordinate, -1.0, 1.0):
			return false
	var restored_direction := Vector3(encoded[0], encoded[1], encoded[2])
	if not _valid_patch(restored_site, restored_direction):
		return false
	var reserve: int = rig.reserve_at(restored_site)
	var max_stored := mini(CAPACITY, int(Catalog.site(restored_site).reserve) - reserve)
	if not _integer(raw.stored, 0, max_stored):
		return false
	var restored_stock := int(raw.stored)
	var latest := epoch + float(Catalog.site(restored_site).drill_seconds)
	if restored_stock == 0:
		latest += MiningRig.DEPLOY_SECONDS
	if not _number(raw.next_epoch, -1.0, latest + 1.0 / TICKS_PER_SECOND):
		return false
	var restored_due := float(raw.next_epoch)
	if restored_stock == CAPACITY or reserve == 0:
		if restored_due != -1.0:
			return false
	else:
		if restored_due <= epoch or _ticks(restored_due) <= floori(epoch * TICKS_PER_SECOND):
			return false
		restored_due = _ticks(restored_due) / TICKS_PER_SECOND
	site_id = restored_site
	direction = restored_direction
	stored = restored_stock
	next_epoch = restored_due
	return true


func _clear() -> void:
	site_id = -1
	direction = Vector3.ZERO
	stored = 0
	next_epoch = -1.0


static func _valid_patch(site: int, local_direction: Vector3) -> bool:
	return Catalog.is_mine_site(site) and local_direction.is_normalized() and Terrain.landable(site, local_direction)


static func _valid_epoch(epoch: float) -> bool:
	return is_finite(epoch) and epoch >= 0.0 and epoch <= MAX_EPOCH


static func _drill_ticks(site: int) -> int:
	return _ticks(float(Catalog.site(site).drill_seconds))


static func _ticks(seconds: float) -> int:
	return roundi(seconds * TICKS_PER_SECOND)


static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, minimum, maximum) and value == floorf(float(value))
