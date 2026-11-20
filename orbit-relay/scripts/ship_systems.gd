extends RefCounted
## Hull profile, fuel, condition and compatible installed equipment for one ship.

const BASE_CAPACITY := 100.0
const EXTRA_CAPACITY := 50.0
const HYDROGEN_UNITS_PER_CANISTER := 10
const TANK_COST := 260
const ECO_COST := 320
const CARGO_COST := 300
const HEAT_SHIELD_COST := 340
const MINING_LASER_COST := 140
const FRAGMENT_COLLECTOR_COST := 90
const SCOOP_COST := 150
const SCOOP_RESALE := 75
const FUEL_PUMP_COST := 110
const FUEL_PUMP_RESALE := 55
const PUMP_OFF := "off"
const PUMP_REACTION := "reaction"
const PUMP_JUMP := "jump"
const PUMP_MODES := [PUMP_OFF, PUMP_REACTION, PUMP_JUMP]
const HEAT_SHIELD_REDUCTION := 48
const BASE_CARGO_CAPACITY := 24
const EXPANDED_CARGO_CAPACITY := 40
const MAX_HULL := 100.0
const MIN_HULL := 1.0
const STARTER_HULL := "courier"
const FREIGHTER_HULL := "freighter"
const TRADE_IN_PERCENT := 68
const HULLS := {
	STARTER_HULL: {"id": STARTER_HULL, "name": "Курьер «Стриж»",
		"description": "Курьерский корабль для одиночного пилота. Быстро меняет курс и скорость.",
		"price": 1000, "cargo": BASE_CARGO_CAPACITY, "expanded_cargo": EXPANDED_CARGO_CAPACITY,
		"crew_required": 0, "speed_factor": 1.0, "accel_factor": 1.0, "burn_factor": 1.0},
	FREIGHTER_HULL: {"id": FREIGHTER_HULL, "name": "Фрахтовик «Кедр»",
		"description": "Фрахтовик с вместительным трюмом и местом специалиста. Медленнее разгоняется и расходует больше топлива.",
		"price": 2200, "cargo": 44, "expanded_cargo": 60,
		"crew_required": 1, "speed_factor": 0.80, "accel_factor": 0.76, "burn_factor": 1.18},
}
const LEGACY_SAVE_FIELDS := ["fuel", "tank_upgraded", "eco_upgraded"]
const PRE_SHIELD_SAVE_FIELDS := ["fuel", "tank_upgraded", "eco_upgraded", "hull", "cargo_upgraded"]
const PRE_DUAL_FUEL_FIELDS := ["fuel", "tank_upgraded", "eco_upgraded", "hull", "cargo_upgraded", "heat_shield"]
const PRE_SHIPYARD_FIELDS := ["fuel", "jump_fuel", "tank_upgraded", "eco_upgraded", "hull", "cargo_upgraded", "heat_shield"]
const PRE_ORBITAL_MINING_FIELDS := ["hull_id", "fuel", "jump_fuel", "tank_upgraded", "eco_upgraded", "hull", "cargo_upgraded", "heat_shield"]
const PRE_FUEL_EQUIPMENT_FIELDS := ["hull_id", "fuel", "jump_fuel", "tank_upgraded", "eco_upgraded", "hull",
	"cargo_upgraded", "heat_shield", "mining_laser", "fragment_collector"]
const SAVE_FIELDS := ["hull_id", "fuel", "jump_fuel", "tank_upgraded", "eco_upgraded", "hull",
	"cargo_upgraded", "heat_shield", "mining_laser", "fragment_collector", "hydrogen_scoop", "fuel_pump", "pump_mode"]

var fuel: float = BASE_CAPACITY
var jump_fuel: float = BASE_CAPACITY
var tank_upgraded := false
var eco_upgraded := false
var hull: float = MAX_HULL
var cargo_upgraded := false
var heat_shield := false
var mining_laser := false
var fragment_collector := false
var hydrogen_scoop := true
var fuel_pump := false
var pump_mode := PUMP_OFF
var hull_id: String:
	get:
		return _hull_id
var _hull_id := STARTER_HULL


static func profile(id: String) -> Dictionary:
	var entry: Dictionary = HULLS.get(id, {})
	return entry.duplicate()


static func hull_ids() -> Array[String]:
	return [STARTER_HULL, FREIGHTER_HULL]


static func is_cargo_capacity(capacity: int) -> bool:
	for entry: Dictionary in HULLS.values():
		if capacity == entry.cargo or capacity == entry.expanded_cargo:
			return true
	return false


func capacity() -> float:
	return BASE_CAPACITY + EXTRA_CAPACITY if tank_upgraded else BASE_CAPACITY


func jump_capacity() -> float:
	return capacity()


func cargo_capacity() -> int:
	return cargo_capacity_for(_hull_id)


func cargo_capacity_for(id: String) -> int:
	var entry: Dictionary = HULLS.get(id, {})
	return int(entry.get("expanded_cargo" if cargo_upgraded else "cargo", 0))


func crew_required() -> int:
	return int(HULLS[_hull_id].crew_required)


func speed_factor() -> float:
	return float(HULLS[_hull_id].speed_factor)


func accel_factor() -> float:
	return float(HULLS[_hull_id].accel_factor)


func trade_in_value() -> int:
	var price := int(HULLS[_hull_id].price)
	return floori(price * clampf(hull, MIN_HULL, MAX_HULL) * TRADE_IN_PERCENT / 10000.0)


func swap_hull(id: String) -> bool:
	if id == _hull_id or not HULLS.has(id):
		return false
	_hull_id = id
	hull = MAX_HULL
	return true


func entry_heat_factor() -> float:
	return 1.0 - HEAT_SHIELD_REDUCTION / 100.0 if heat_shield else 1.0


func burn(delta: float, load: float, boost: bool) -> void:
	if fuel <= 0.0 or delta <= 0.0 or not is_finite(delta) or not is_finite(load):
		return
	var throttle := clampf(load, 0.0, 1.0)
	if throttle == 0.0 and not boost:
		return
	var rate := (3.0 if boost else 0.2 + 0.9 * throttle) * float(HULLS[_hull_id].burn_factor)
	if eco_upgraded:
		rate *= 0.7
	fuel = maxf(0.0, fuel - delta * rate)


func add_fuel(amount: float) -> float:
	if amount <= 0.0 or not is_finite(amount):
		return 0.0
	var previous := fuel
	fuel = minf(capacity(), fuel + amount)
	return fuel - previous


func add_jump_fuel(amount: float) -> float:
	if amount <= 0.0 or not is_finite(amount):
		return 0.0
	var previous := jump_fuel
	jump_fuel = minf(jump_capacity(), jump_fuel + amount)
	return jump_fuel - previous


func quote_refill(unit_price: int) -> int:
	return _service_cost(ceili(capacity() - fuel), unit_price)


func quote_jump_refill(unit_price: int) -> int:
	return _service_cost(ceili(jump_capacity() - jump_fuel), unit_price)


func quote_repair(unit_price: int) -> int:
	return _service_cost(ceili(MAX_HULL - hull), unit_price)


func apply_damage(amount: float) -> float:
	if amount <= 0.0 or not is_finite(amount):
		return 0.0
	var previous := hull
	hull = maxf(MIN_HULL, hull - amount)
	return previous - hull


static func _service_cost(missing_units: int, unit_price: int) -> int:
	if missing_units <= 0 or unit_price <= 0:
		return 0
	@warning_ignore("integer_division")
	if unit_price > 9223372036854775807 / missing_units:
		return 0
	return missing_units * unit_price


func service_offer(action: String, unit_price: int, credits: int) -> Dictionary:
	var cost := 0
	var installed := false
	match action:
		"refuel":
			cost = quote_refill(unit_price)
		"jump_refuel":
			cost = quote_jump_refill(unit_price)
		"repair":
			cost = quote_repair(unit_price)
		"tank":
			cost = TANK_COST
			installed = tank_upgraded
		"eco":
			cost = ECO_COST
			installed = eco_upgraded
		"cargo":
			cost = CARGO_COST
			installed = cargo_upgraded
		"heat_shield":
			cost = HEAT_SHIELD_COST
			installed = heat_shield
		"mining_laser":
			cost = MINING_LASER_COST
			installed = mining_laser
		"fragment_collector":
			cost = FRAGMENT_COLLECTOR_COST
			installed = fragment_collector
		"hydrogen_scoop":
			cost = SCOOP_COST
			installed = hydrogen_scoop
		"fuel_pump":
			cost = FUEL_PUMP_COST
			installed = fuel_pump
	return {"cost": cost, "allowed": cost > 0 and cost <= credits and not installed, "installed": installed}


func buy(action: String, unit_price: int, credits: int) -> int:
	var offer := service_offer(action, unit_price, credits)
	if not offer.allowed:
		return 0
	match action:
		"refuel":
			fuel = capacity()
		"jump_refuel":
			jump_fuel = jump_capacity()
		"repair":
			hull = MAX_HULL
		"tank":
			tank_upgraded = true
		"eco":
			eco_upgraded = true
		"cargo":
			cargo_upgraded = true
		"heat_shield":
			heat_shield = true
		"mining_laser":
			mining_laser = true
		"fragment_collector":
			fragment_collector = true
		"hydrogen_scoop":
			hydrogen_scoop = true
		"fuel_pump":
			fuel_pump = true
	return offer.cost


func remove_fuel_module(module: String) -> int:
	if module == "hydrogen_scoop" and hydrogen_scoop:
		hydrogen_scoop = false
		return SCOOP_RESALE
	if module == "fuel_pump" and fuel_pump:
		fuel_pump = false
		pump_mode = PUMP_OFF
		return FUEL_PUMP_RESALE
	return 0


func set_pump_mode(mode: String) -> bool:
	if not fuel_pump or mode not in PUMP_MODES:
		return false
	pump_mode = mode
	return true


func snapshot() -> Dictionary:
	return {
		"hull_id": _hull_id,
		"fuel": fuel, "jump_fuel": jump_fuel,
		"tank_upgraded": tank_upgraded, "eco_upgraded": eco_upgraded,
		"hull": hull, "cargo_upgraded": cargo_upgraded, "heat_shield": heat_shield,
		"mining_laser": mining_laser, "fragment_collector": fragment_collector,
		"hydrogen_scoop": hydrogen_scoop, "fuel_pump": fuel_pump, "pump_mode": pump_mode,
	}


func restore(value: Variant, legacy := false, pre_shield := false, pre_dual_fuel := false,
		pre_shipyard := false, pre_orbital_mining := false, pre_fuel_equipment := false) -> bool:
	var fields := SAVE_FIELDS
	if legacy:
		fields = LEGACY_SAVE_FIELDS
	elif pre_shield:
		fields = PRE_SHIELD_SAVE_FIELDS
	elif pre_dual_fuel:
		fields = PRE_DUAL_FUEL_FIELDS
	elif pre_shipyard:
		fields = PRE_SHIPYARD_FIELDS
	elif pre_orbital_mining:
		fields = PRE_ORBITAL_MINING_FIELDS
	elif pre_fuel_equipment:
		fields = PRE_FUEL_EQUIPMENT_FIELDS
	if not value is Dictionary or value.size() != fields.size() or not value.has_all(fields):
		return false
	var restored_hull_id := STARTER_HULL
	if "hull_id" in fields:
		if not value.hull_id is String or not HULLS.has(value.hull_id):
			return false
		restored_hull_id = value.hull_id
	if not value.tank_upgraded is bool or not value.eco_upgraded is bool:
		return false
	if not (legacy or pre_shield) and not value.heat_shield is bool:
		return false
	if "mining_laser" in fields and (not value.mining_laser is bool or not value.fragment_collector is bool):
		return false
	if fields == SAVE_FIELDS and (not value.hydrogen_scoop is bool or not value.fuel_pump is bool
			or not value.pump_mode is String or value.pump_mode not in PUMP_MODES
			or (not value.fuel_pump and value.pump_mode != PUMP_OFF)):
		return false
	if not (value.fuel is float or value.fuel is int):
		return false
	var restored_fuel := float(value.fuel)
	var restored_capacity := BASE_CAPACITY + EXTRA_CAPACITY if value.tank_upgraded else BASE_CAPACITY
	if not is_finite(restored_fuel) or restored_fuel < 0.0 or restored_fuel > restored_capacity:
		return false
	var restored_jump_fuel := restored_fuel
	if not (legacy or pre_shield or pre_dual_fuel):
		if not (value.jump_fuel is float or value.jump_fuel is int):
			return false
		restored_jump_fuel = float(value.jump_fuel)
		if not is_finite(restored_jump_fuel) or restored_jump_fuel < 0.0 or restored_jump_fuel > restored_capacity:
			return false
	var restored_hull := MAX_HULL
	var restored_cargo_upgrade := false
	if not legacy:
		if not value.cargo_upgraded is bool or not (value.hull is float or value.hull is int):
			return false
		restored_hull = float(value.hull)
		if not is_finite(restored_hull) or restored_hull < MIN_HULL or restored_hull > MAX_HULL:
			return false
		restored_cargo_upgrade = value.cargo_upgraded
	fuel = restored_fuel
	jump_fuel = restored_jump_fuel
	tank_upgraded = value.tank_upgraded
	eco_upgraded = value.eco_upgraded
	_hull_id = restored_hull_id
	hull = restored_hull
	cargo_upgraded = restored_cargo_upgrade
	heat_shield = false if legacy or pre_shield else value.heat_shield
	mining_laser = value.get("mining_laser", false)
	fragment_collector = value.get("fragment_collector", false)
	hydrogen_scoop = value.get("hydrogen_scoop", true)
	fuel_pump = value.get("fuel_pump", false)
	pump_mode = value.get("pump_mode", PUMP_OFF)
	return true
