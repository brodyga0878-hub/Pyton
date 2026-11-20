extends RefCounted
## The detachable rig loads the same hold used for market cargo.

const Catalog = preload("res://scripts/sector_catalog.gd")
const Economy = preload("res://scripts/port_economy.gd")
const ShipSystems = preload("res://scripts/ship_systems.gd")

const STOWED := 0
const DEPLOYING := 1
const DRILLING := 2
const READY := 3
const RETURNING := 4
const CAPACITY := ShipSystems.BASE_CARGO_CAPACITY
const BATCH := 12
const PRICE := 20
const INITIAL_RESERVE := 120
const DEPLOY_SECONDS := 2.0
const DRILL_SECONDS := 9.0
const RETURN_SECONDS := 2.0
const FIRST_MINE_SITE := 2
const RESOURCES := Catalog.RESOURCES
const SAVE_FIELDS := ["site_id", "phase", "phase_seconds", "cargo", "reserves", "pending_ore"]
const LEGACY_SAVE_FIELDS := ["phase", "phase_seconds", "ore_hold", "reserve", "pending_ore"]

var phase: int = STOWED
var phase_seconds := 0.0
var pending_ore := 0
var cargo_capacity := CAPACITY
var site_id: int:
	get:
		return _site_id
var ore_hold: int:
	get:
		return _hold_size(_cargo)
var reserve: int:
	get:
		return _reserves[_site_id]

var _site_id := FIRST_MINE_SITE
var _cargo: Dictionary = _empty_cargo()
var _reserves: Array[int] = _initial_reserves()


func select_site(id: int) -> bool:
	if phase != STOWED or not Catalog.is_mine_site(id):
		return false
	_site_id = id
	return true


func reserve_at(id: int) -> int:
	return _reserves[id] if id >= 0 and id < _reserves.size() else 0


func cargo_amount(resource: String) -> int:
	return int(_cargo.get(resource, 0))


func free_capacity() -> int:
	return maxi(0, cargo_capacity - ore_hold)


func insert_cargo(good: String, count: int) -> bool:
	if phase != STOWED or not _cargo.has(good) or count <= 0 or count > free_capacity():
		return false
	_cargo[good] += count
	return true


func remove_cargo(good: String, count: int) -> bool:
	if phase != STOWED or count <= 0 or count > cargo_amount(good):
		return false
	_cargo[good] -= count
	return true


func available_to_deploy() -> bool:
	return phase == STOWED and _next_batch(free_capacity(), reserve) > 0


func action() -> String:
	if available_to_deploy():
		phase = DEPLOYING
		return "mining_deploy"
	if phase == READY:
		phase = RETURNING
		return "mining_recover"
	return ""


func update(delta: float) -> String:
	if not is_finite(delta) or delta <= 0.0:
		return ""
	while delta > 0.0:
		var duration := _phase_duration(phase, _site_id)
		if duration == 0.0:
			return ""
		var advanced := phase_seconds + delta
		if advanced < duration:
			phase_seconds = advanced
			return ""
		delta = advanced - duration
		phase_seconds = 0.0
		match phase:
			DEPLOYING:
				phase = DRILLING
			DRILLING:
				phase = READY
				pending_ore = _next_batch(free_capacity(), reserve)
				return "mining_ready"
			RETURNING:
				var resource: String = Catalog.site(_site_id).resource
				phase = STOWED
				_cargo[resource] += pending_ore
				_reserves[_site_id] -= pending_ore
				pending_ore = 0
				return "mining_loaded"
	return ""


func sale_quote(port_id: int) -> int:
	if phase != STOWED or not Catalog.is_port(port_id):
		return 0
	var total := 0
	for resource: String in RESOURCES:
		total += cargo_amount(resource) * maxi(0, Catalog.price(port_id, resource))
	return total


func sell(port_id: int = 0) -> int:
	var payment := sale_quote(port_id)
	if payment > 0:
		for resource: String in RESOURCES:
			if Catalog.price(port_id, resource) > 0:
				_cargo[resource] = 0
	return payment


func progress() -> float:
	if phase == READY:
		return 1.0
	var duration := _phase_duration(phase, _site_id)
	return clampf(phase_seconds / duration, 0.0, 1.0) if duration > 0.0 else 0.0


func snapshot() -> Dictionary:
	return {
		"site_id": _site_id,
		"phase": phase,
		"phase_seconds": phase_seconds,
		"cargo": _cargo.duplicate(),
		"reserves": _reserves.duplicate(),
		"pending_ore": pending_ore,
	}


func restore(value: Variant, legacy := false, reserve_slots := Catalog.DESTINATION_COUNT,
		capacity := CAPACITY, market_cargo := false, pre_hydrogen := false) -> bool:
	if legacy and value is Dictionary and value.size() == LEGACY_SAVE_FIELDS.size() and value.has_all(LEGACY_SAVE_FIELDS):
		value = _upgrade_legacy(value)
	if not value is Dictionary or value.size() != SAVE_FIELDS.size() or not value.has_all(SAVE_FIELDS):
		return false
	if not _integer_in_range(value.phase, STOWED, RETURNING):
		return false
	var saved_count := Catalog.SITE_COUNT if legacy else reserve_slots
	if saved_count <= 0 or saved_count > Catalog.DESTINATION_COUNT:
		return false
	if capacity != CAPACITY and capacity != ShipSystems.EXPANDED_CARGO_CAPACITY:
		return false
	if not _integer_in_range(value.site_id, 0, saved_count - 1) or not Catalog.is_mine_site(int(value.site_id)):
		return false
	if not _integer_in_range(value.pending_ore, 0, BATCH):
		return false
	if not (value.phase_seconds is int or value.phase_seconds is float):
		return false
	var cargo_fields := RESOURCES
	if market_cargo:
		cargo_fields = Economy.PRE_HYDROGEN_GOODS if pre_hydrogen else Economy.GOODS
	if not value.cargo is Dictionary or value.cargo.size() != cargo_fields.size() or not value.cargo.has_all(cargo_fields):
		return false
	if not value.reserves is Array or value.reserves.size() != saved_count:
		return false

	var restored_site := int(value.site_id)
	var restored_phase := int(value.phase)
	var restored_seconds := float(value.phase_seconds)
	var restored_pending := int(value.pending_ore)
	var duration := _phase_duration(restored_phase, restored_site)
	if not is_finite(restored_seconds) or restored_seconds < 0.0:
		return false
	if (duration == 0.0 and restored_seconds != 0.0) or (duration > 0.0 and restored_seconds >= duration):
		return false

	var restored_reserves := _initial_reserves()
	var extracted := {"ore": 0, "crystal": 0, "ice": 0}
	for id in range(saved_count):
		var deposit := Catalog.site(id)
		var initial_reserve := restored_reserves[id]
		if not _integer_in_range(value.reserves[id], 0, initial_reserve):
			return false
		var remaining := int(value.reserves[id])
		restored_reserves[id] = remaining
		if not market_cargo and Catalog.is_mine_site(id):
			extracted[deposit.resource] += initial_reserve - remaining
	var restored_cargo := _empty_cargo()
	for good: String in cargo_fields:
		var limit := capacity if market_cargo else mini(capacity, int(extracted[good]))
		if not _integer_in_range(value.cargo[good], 0, limit):
			return false
		restored_cargo[good] = int(value.cargo[good])
	var restored_hold := _hold_size(restored_cargo)
	if restored_hold > capacity:
		return false
	var batch := _next_batch(capacity - restored_hold, restored_reserves[restored_site])
	if restored_phase != STOWED and batch == 0:
		return false
	var expected_pending := batch if restored_phase in [READY, RETURNING] else 0
	if restored_pending != expected_pending:
		return false

	_site_id = restored_site
	phase = restored_phase
	phase_seconds = restored_seconds
	_cargo = restored_cargo
	_reserves = restored_reserves
	pending_ore = restored_pending
	cargo_capacity = capacity
	return true


static func _upgrade_legacy(value: Dictionary) -> Dictionary:
	# The original deposit keeps its site ID and resource. Other sites open intact.
	var reserves: Array = []
	reserves.assign(_initial_reserves().slice(0, Catalog.SITE_COUNT))
	reserves[FIRST_MINE_SITE] = value.reserve
	return {
		"site_id": FIRST_MINE_SITE,
		"phase": value.phase,
		"phase_seconds": value.phase_seconds,
		"cargo": {"ore": value.ore_hold, "crystal": 0, "ice": 0},
		"reserves": reserves,
		"pending_ore": value.pending_ore,
	}


static func _initial_reserves() -> Array[int]:
	var result: Array[int] = []
	for id in range(Catalog.DESTINATION_COUNT):
		result.append(int(Catalog.site(id).get("reserve", 0)))
	return result


static func _empty_cargo() -> Dictionary:
	var cargo := {}
	for good: String in Economy.GOODS:
		cargo[good] = 0
	return cargo


static func _hold_size(cargo: Dictionary) -> int:
	var total := 0
	for good: String in Economy.GOODS:
		total += int(cargo[good])
	return total


static func _phase_duration(value: int, id: int) -> float:
	match value:
		DEPLOYING:
			return DEPLOY_SECONDS
		DRILLING:
			return float(Catalog.site(id).drill_seconds)
		RETURNING:
			return RETURN_SECONDS
		_:
			return 0.0


static func _next_batch(available_space: int, deposit: int) -> int:
	return mini(BATCH, mini(available_space, deposit))


static func _integer_in_range(value: Variant, lower: int, upper: int) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and value >= lower and value <= upper and floorf(float(value)) == float(value)
