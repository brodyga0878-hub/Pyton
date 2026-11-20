extends RefCounted
## Loose asteroid fragments carry ore already deducted from the shared deposit.

const Catalog = preload("res://scripts/sector_catalog.gd")
const Orbit = preload("res://scripts/orbit_ephemeris.gd")
const Terrain = preload("res://scripts/surface_terrain.gd")

const PULSE_SECONDS := 2.0
const LAUNCH_CLEARANCE := 18.0
const DRIFT_DISTANCE := 18.0
const DRIFT_HALF_TIME := 15.0
const MAX_EPOCH := 3155760000.0
const CLOCK_TOLERANCE := 0.000002
const FRAGMENT_FIELDS := ["site", "direction", "created"]

var ready_at := 0.0

var _fragments: Dictionary[int, Dictionary] = {}


static func supports_site(site: int) -> bool:
	return Catalog.site(site).get("kind", "") == "asteroid"


func has_fragment(site: int) -> bool:
	return _fragments.has(site)


func fragment_sites() -> Array[int]:
	var sites := _fragments.keys()
	sites.sort()
	return sites


func fragment_state(site: int, epoch: float) -> Dictionary:
	if not has_fragment(site) or not _valid_epoch(epoch):
		return {}
	var fragment := _fragments[site]
	var age := epoch - float(fragment.created)
	if age < 0.0:
		return {}
	var direction: Vector3 = fragment.direction
	var orbit := Orbit.sample(site, epoch)
	var center: Vector3 = orbit.position
	var orbital_velocity: Vector3 = orbit.velocity
	var drift_time := age + DRIFT_HALF_TIME
	var envelope := float(Catalog.site(site).radius) * Terrain.MAX_RADIUS_FACTOR + Terrain.CONTACT_CLEARANCE
	var distance := envelope + LAUNCH_CLEARANCE + DRIFT_DISTANCE * age / drift_time
	var radial_speed := DRIFT_DISTANCE * DRIFT_HALF_TIME / (drift_time * drift_time)
	return {
		"site": site,
		"resource": Catalog.site(site).resource,
		"position": center + direction * distance,
		"velocity": orbital_velocity + direction * radial_speed,
	}


func spawn(rig: RefCounted, site: int, direction: Vector3, epoch: float) -> bool:
	if not _valid_epoch(epoch) or epoch < ready_at or not supports_site(site) or has_fragment(site):
		return false
	if not _valid_direction(direction) or rig.extract_remote(site, 1) != 1:
		return false
	_fragments[site] = {"direction": direction, "created": epoch}
	ready_at = epoch + PULSE_SECONDS
	return true


func collect(rig: RefCounted, site: int) -> bool:
	if not has_fragment(site) or not rig.insert_cargo(Catalog.site(site).resource, 1):
		return false
	_fragments.erase(site)
	return true


func snapshot() -> Dictionary:
	var fragments: Array[Dictionary] = []
	for site: int in fragment_sites():
		var fragment := _fragments[site]
		var direction: Vector3 = fragment.direction
		fragments.append({"site": site, "direction": [direction.x, direction.y, direction.z], "created": fragment.created})
	return {"ready_at": ready_at, "fragments": fragments}


func restore(raw: Variant, epoch: float, rig: RefCounted, remote_site := -1, remote_stored := 0) -> bool:
	if not _valid_epoch(epoch) or not raw is Dictionary or raw.size() != 2:
		return false
	if not _number(raw.get("ready_at"), 0.0, epoch + PULSE_SECONDS + CLOCK_TOLERANCE):
		return false
	var encoded: Variant = raw.get("fragments")
	if not encoded is Array or encoded.size() > Catalog.DESTINATION_COUNT:
		return false
	var restored: Dictionary[int, Dictionary] = {}
	var times: Array[float] = []
	var deadline := float(raw.ready_at)
	for fragment: Variant in encoded:
		if not fragment is Dictionary or fragment.size() != FRAGMENT_FIELDS.size() or not fragment.has_all(FRAGMENT_FIELDS):
			return false
		if not _integer(fragment.site, 0, Catalog.DESTINATION_COUNT - 1):
			return false
		var site := int(fragment.site)
		if restored.has(site) or not supports_site(site):
			return false
		var extracted := int(Catalog.site(site).reserve) - int(rig.reserve_at(site))
		var remote := remote_stored if site == remote_site else 0
		if extracted <= remote:
			return false
		if not _number(fragment.created, 0.0, epoch) or float(fragment.created) + PULSE_SECONDS > deadline + CLOCK_TOLERANCE:
			return false
		var direction := _decode_direction(fragment.direction)
		if not _valid_direction(direction):
			return false
		var created := float(fragment.created)
		restored[site] = {"direction": direction, "created": created}
		times.append(created)
	times.sort()
	for index in range(1, times.size()):
		if times[index] + CLOCK_TOLERANCE < times[index - 1] + PULSE_SECONDS:
			return false
	_fragments = restored
	ready_at = deadline
	return true


static func _decode_direction(raw: Variant) -> Vector3:
	if not raw is Array or raw.size() != 3:
		return Vector3.ZERO
	for number: Variant in raw:
		if not _number(number, -1.0, 1.0):
			return Vector3.ZERO
	return Vector3(raw[0], raw[1], raw[2])


static func _valid_direction(direction: Vector3) -> bool:
	return direction.is_finite() and direction.is_normalized()


static func _valid_epoch(epoch: float) -> bool:
	return is_finite(epoch) and epoch >= 0.0 and epoch <= MAX_EPOCH


static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, minimum, maximum) and value == floorf(float(value))
