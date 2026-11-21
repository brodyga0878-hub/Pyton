extends RefCounted
## A detachable medical processor consumes its supplies at the start of each batch.

const Catalog := preload("res://scripts/sector_catalog.gd")
const Rig := preload("res://scripts/mining_rig.gd")
const Terrain := preload("res://scripts/surface_terrain.gd")

const PRICE := 280
const ICE := 2
const GRAIN := 1
const OUTPUT := 2
const SECONDS := 25.0
const ACCESS_DISTANCE := 20.0
const MAX_EPOCH := 3155760000.0
const TICKS_PER_SECOND := 1048576.0
const FIELDS := ["installed", "site", "direction", "ready", "due"]

var installed := false
var site := -1
var direction := Vector3.ZERO
var ready := 0
var due := -1


func active() -> bool:
	return site >= 0


func can_feed(cargo: RefCounted) -> bool:
	return installed and due < 0 and ready == 0 and cargo.phase == Rig.STOWED \
		and cargo.cargo_amount("ice") >= ICE and cargo.cargo_amount("grain") >= GRAIN


func deploy(cargo: RefCounted, body: int, patch: Vector3, epoch: float) -> bool:
	if active() or not _valid_patch(body, patch) or not feed(cargo, epoch):
		return false
	site = body
	direction = patch
	return true


func feed(cargo: RefCounted, epoch: float) -> bool:
	if not can_feed(cargo) or epoch < 0.0 or epoch + SECONDS > MAX_EPOCH:
		return false
	if not cargo.remove_cargo("ice", ICE):
		return false
	if not cargo.remove_cargo("grain", GRAIN):
		cargo.insert_cargo("ice", ICE)
		return false
	due = roundi((epoch + SECONDS) * TICKS_PER_SECOND)
	return true


func advance(epoch: float) -> bool:
	if due < 0 or floori(epoch * TICKS_PER_SECOND) < due:
		return false
	due = -1
	ready = OUTPUT
	return true


func unload(cargo: RefCounted) -> int:
	var units: int = mini(ready, cargo.free_capacity())
	if units <= 0 or not cargo.insert_cargo("medical", units):
		return 0
	ready -= units
	return units


func retrieve() -> bool:
	if not active() or ready > 0 or due >= 0:
		return false
	site = -1
	direction = Vector3.ZERO
	return true


func remaining(epoch: float) -> float:
	return maxf(0.0, float(due) / TICKS_PER_SECOND - epoch)


func snapshot() -> Dictionary:
	return {"installed": installed, "site": site, "direction": [direction.x, direction.y, direction.z], "ready": ready, "due": due}


func restore(raw: Variant, epoch: float, site_limit: int) -> bool:
	if not raw is Dictionary or raw.size() != FIELDS.size() or not raw.has_all(FIELDS) or not raw.installed is bool:
		return false
	if not _integer(raw.site, -1, site_limit - 1) or not _integer(raw.ready, 0, OUTPUT):
		return false
	if not raw.direction is Array or raw.direction.size() != 3:
		return false
	for value: Variant in raw.direction:
		if not _number(value, -1.0, 1.0):
			return false
	var point := Vector3(raw.direction[0], raw.direction[1], raw.direction[2])
	var clock := floori(epoch * TICKS_PER_SECOND)
	if not _integer(raw.due, -1, roundi(minf(MAX_EPOCH, epoch + SECONDS) * TICKS_PER_SECOND) + 1):
		return false
	if raw.site < 0:
		if not point.is_zero_approx() or raw.due != -1 or raw.ready != 0:
			return false
	elif not raw.installed or not _valid_patch(int(raw.site), point):
		return false
	if raw.due != -1 and (int(raw.due) <= clock or raw.ready != 0):
		return false
	installed = raw.installed
	site = int(raw.site)
	direction = point
	ready = int(raw.ready)
	due = int(raw.due)
	return true


static func _valid_patch(body: int, point: Vector3) -> bool:
	return Catalog.is_mine_site(body) and point.is_normalized() and Terrain.landable(body, point)


static func _number(value: Variant, lower: float, upper: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= lower and value <= upper


static func _integer(value: Variant, lower: int, upper: int) -> bool:
	return _number(value, lower, upper) and float(value) == floorf(float(value))
