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
const RANGE_DRIVE_COST := 450
const DRIVE_STANDARD := "standard"
const DRIVE_RANGE := "range"
const DRIVE_MILITARY := "military"
const MILITARY_DRIVE_NAME := "Арсенал"
const MILITARY_DRIVE_COST := 680
const MILITARY_CAPACITY := 120.0
const MILITARY_WASTE_CAPACITY := 18
const MILITARY_WASTE_INTERVAL := 10.0
const MILITARY_FUEL_SURCHARGE := 3
const MILITARY_DISPOSAL_PRICE := 2
const MILITARY_TARIFF_FACTOR := 0.56
const MILITARY_MASS_SENSITIVITY := 0.70
const RANGE_TARIFF_FACTOR := 0.75
const RANGE_MASS_SENSITIVITY := 0.82
const STANDARD_MASS_SENSITIVITY := 1.0
const COURIER_DRY_MASS := 50.0
const COURIER_ROLL_RATE := 1.9
const FREIGHTER_DRY_MASS := 64.0
const FUEL_UNIT_MASS := 0.004
const CARGO_UNIT_MASS := 0.28
const TANK_HARDWARE_MASS := 0.9
const SCOOP_MASS := 0.16
const AUTOPILOT_MASS := 0.12
const REFERENCE_MASS := COURIER_DRY_MASS + 2.0 * BASE_CAPACITY * FUEL_UNIT_MASS
const RESERVE_THRUST_FRACTION := 20.0 / 34.0
const TARIFF_TOLERANCE := 0.000000001
const STANDARD_DRIVE_NAME := "Штатный"
const RANGE_DRIVE_NAME := "Вектор"
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
const SURVEY_HULL := "surveyor"
const UTILITY_HULL := "utility"
const TRADE_IN_PERCENT := 68
const HULLS := {
	STARTER_HULL: {"id": STARTER_HULL, "name": "Курьер «Стриж»",
		"description": "Курьерский корабль для одиночного пилота. Быстро меняет курс и скорость.",
		"price": 1000, "cargo": BASE_CARGO_CAPACITY, "expanded_cargo": EXPANDED_CARGO_CAPACITY,
		"dry_mass": COURIER_DRY_MASS, "roll_rate": COURIER_ROLL_RATE,
		"thrust_positive": Vector3(1600.2, 1625.6, 1651.0), "thrust_negative": Vector3(1574.8, 1320.8, 1727.2),
		"crew_required": 0, "speed_factor": 1.0, "accel_factor": 1.0, "burn_factor": 1.0},
	FREIGHTER_HULL: {"id": FREIGHTER_HULL, "name": "Фрахтовик «Кедр»",
		"description": "Фрахтовик с вместительным трюмом и местом специалиста. Медленнее разгоняется и расходует больше топлива.",
		"price": 2200, "cargo": 44, "expanded_cargo": 60,
		"dry_mass": FREIGHTER_DRY_MASS, "roll_rate": 1.35,
		"thrust_positive": Vector3(1250.0, 1310.0, 1180.0), "thrust_negative": Vector3(1130.0, 1070.0, 1674.432),
		"crew_required": 1, "speed_factor": 0.80, "accel_factor": 0.76, "burn_factor": 1.18},
	SURVEY_HULL: {"id": SURVEY_HULL, "name": "Разведчик «Отклик»",
		"description": "Лёгкий разведчик с быстрым разворотом и небольшим трюмом.",
		"price": 1680, "cargo": 18, "expanded_cargo": 32, "dry_mass": 43.0, "roll_rate": 2.35,
		"thrust_positive": Vector3(1780.0, 1560.0, 1840.0), "thrust_negative": Vector3(1650.0, 1420.0, 2110.0),
		"crew_required": 0, "speed_factor": 1.12, "accel_factor": 1.16, "burn_factor": 0.92},
	UTILITY_HULL: {"id": UTILITY_HULL, "name": "Буксир «Призма»",
		"description": "Рабочий корабль с мощными боковыми двигателями. Нужен один специалист.",
		"price": 2450, "cargo": 34, "expanded_cargo": 50, "dry_mass": 58.0, "roll_rate": 1.48,
		"thrust_positive": Vector3(2690.0, 2850.0, 1540.0), "thrust_negative": Vector3(2710.0, 2600.0, 1630.0),
		"crew_required": 1, "speed_factor": 0.89, "accel_factor": 0.81, "burn_factor": 1.08},
}
const LEGACY_SAVE_FIELDS := ["fuel", "tank_upgraded", "eco_upgraded"]
const PRE_SHIELD_SAVE_FIELDS := ["fuel", "tank_upgraded", "eco_upgraded", "hull", "cargo_upgraded"]
const PRE_DUAL_FUEL_FIELDS := ["fuel", "tank_upgraded", "eco_upgraded", "hull", "cargo_upgraded", "heat_shield"]
const PRE_SHIPYARD_FIELDS := ["fuel", "jump_fuel", "tank_upgraded", "eco_upgraded", "hull", "cargo_upgraded", "heat_shield"]
const PRE_ORBITAL_MINING_FIELDS := ["hull_id", "fuel", "jump_fuel", "tank_upgraded", "eco_upgraded", "hull", "cargo_upgraded", "heat_shield"]
const PRE_FUEL_EQUIPMENT_FIELDS := ["hull_id", "fuel", "jump_fuel", "tank_upgraded", "eco_upgraded", "hull",
	"cargo_upgraded", "heat_shield", "mining_laser", "fragment_collector"]
const PRE_JUMP_DRIVE_FIELDS := ["hull_id", "fuel", "jump_fuel", "tank_upgraded", "eco_upgraded", "hull",
	"cargo_upgraded", "heat_shield", "mining_laser", "fragment_collector", "hydrogen_scoop", "fuel_pump", "pump_mode"]
const PRE_AUTOPILOT_EQUIPMENT_FIELDS := ["hull_id", "fuel", "jump_fuel", "tank_upgraded", "eco_upgraded", "hull",
	"cargo_upgraded", "heat_shield", "mining_laser", "fragment_collector", "hydrogen_scoop", "fuel_pump", "pump_mode",
	"range_drive", "drive_kind"]
const SAVE_FIELDS := ["hull_id", "fuel", "jump_fuel", "tank_upgraded", "eco_upgraded", "hull",
	"cargo_upgraded", "heat_shield", "mining_laser", "fragment_collector", "hydrogen_scoop", "fuel_pump", "pump_mode",
	"range_drive", "drive_kind", "autopilot_fitted"]

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
var range_drive := false
var military_drive := false
var military_fuel := 0.0
var military_waste := 0
var drive_kind := DRIVE_STANDARD
var autopilot_fitted := true
var hull_id: String:
	get:
		return _hull_id
var _hull_id := STARTER_HULL


static func profile(id: String) -> Dictionary:
	var entry: Dictionary = HULLS.get(id, {})
	return entry.duplicate()


static func hull_ids() -> Array[String]:
	return [STARTER_HULL, FREIGHTER_HULL, SURVEY_HULL, UTILITY_HULL]


static func is_cargo_capacity(capacity: int) -> bool:
	for entry: Dictionary in HULLS.values():
		if capacity == entry.cargo or capacity == entry.expanded_cargo:
			return true
	return false


func capacity() -> float:
	return BASE_CAPACITY + EXTRA_CAPACITY if tank_upgraded else BASE_CAPACITY


func jump_capacity() -> float:
	return capacity()


func drive_name() -> String:
	match drive_kind:
		DRIVE_RANGE: return RANGE_DRIVE_NAME
		DRIVE_MILITARY: return MILITARY_DRIVE_NAME
	return STANDARD_DRIVE_NAME


func select_drive(id: String) -> bool:
	if id == drive_kind or not drive_available(id):
		return false
	drive_kind = id
	return true


func drive_available(id: String) -> bool:
	return id == DRIVE_STANDARD or (id == DRIVE_RANGE and range_drive) or (id == DRIVE_MILITARY and military_drive)


func active_jump_fuel() -> float:
	return military_fuel if drive_kind == DRIVE_MILITARY else jump_fuel


func active_jump_capacity() -> float:
	return MILITARY_CAPACITY if drive_kind == DRIVE_MILITARY else jump_capacity()


func waste_for_jump(cost: int) -> int:
	return ceili(float(cost) / MILITARY_WASTE_INTERVAL) if drive_kind == DRIVE_MILITARY else 0


func waste_budget(waste := -1) -> float:
	if drive_kind != DRIVE_MILITARY:
		return active_jump_capacity()
	var inventory := military_waste if waste < 0 else waste
	return float(MILITARY_WASTE_CAPACITY - inventory) * MILITARY_WASTE_INTERVAL


func pay_jump(cost: int) -> bool:
	if cost <= 0 or cost > active_jump_fuel() or cost > waste_budget():
		return false
	if drive_kind == DRIVE_MILITARY:
		military_fuel -= cost
		military_waste += waste_for_jump(cost)
	else:
		jump_fuel -= cost
	return true


func legacy_jump_tariff(base: int) -> int:
	return ceili(base * RANGE_TARIFF_FACTOR) if drive_kind == DRIVE_RANGE and base > 0 else base


func jump_tariff(base: int, payload: int, jump_reserve := -1.0, waste := -1) -> int:
	if base <= 0:
		return 0
	return ceili(float(base) * _jump_mass_multiplier(payload, jump_reserve, waste) - TARIFF_TOLERANCE)


func base_jump_budget(budget: float, payload: int, jump_reserve := -1.0, waste := -1) -> int:
	return floori((floorf(budget) + TARIFF_TOLERANCE) / _jump_mass_multiplier(payload, jump_reserve, waste))


func _jump_mass_multiplier(payload: int, jump_reserve: float, waste: int) -> float:
	var relative_mass := flight_mass(payload, jump_reserve, waste) / REFERENCE_MASS
	if drive_kind == DRIVE_MILITARY:
		return MILITARY_TARIFF_FACTOR * (1.0 + (relative_mass - 1.0) * MILITARY_MASS_SENSITIVITY)
	if drive_kind == DRIVE_RANGE:
		return RANGE_TARIFF_FACTOR * (1.0 + (relative_mass - 1.0) * RANGE_MASS_SENSITIVITY)
	return 1.0 + (relative_mass - 1.0) * STANDARD_MASS_SENSITIVITY


static func minimum_jump_tariff(base: int) -> int:
	# A saved itinerary can outlive a hull or load change. This lower bound
	# rejects impossible legs while allowing a previously valid route to remain selected.
	var lightest_mass := COURIER_DRY_MASS - SCOOP_MASS - AUTOPILOT_MASS
	var relative_mass := lightest_mass / REFERENCE_MASS
	return ceili(float(base) * MILITARY_TARIFF_FACTOR * (1.0 + (relative_mass - 1.0) * MILITARY_MASS_SENSITIVITY) - TARIFF_TOLERANCE)


func jump_duration(distance: float, payload: int) -> float:
	if not is_finite(distance) or distance <= 0.0:
		return 0.0
	var unloaded_seconds := 7.0 + 2.5 * distance if drive_kind == DRIVE_RANGE else 12.0 + 4.0 * distance
	if drive_kind == DRIVE_MILITARY:
		unloaded_seconds = 6.0 + 2.1 * distance
	var load_ratio := clampf(float(payload) / cargo_capacity(), 0.0, 1.0)
	return ceilf(unloaded_seconds * (1.0 + 0.6 * load_ratio))


func cargo_capacity() -> int:
	return cargo_capacity_for(_hull_id)


func cargo_capacity_for(id: String) -> int:
	var entry: Dictionary = HULLS.get(id, {})
	return int(entry.get("expanded_cargo" if cargo_upgraded else "cargo", 0))


func crew_required() -> int:
	return int(HULLS[_hull_id].crew_required)


func speed_factor() -> float:
	return float(HULLS[_hull_id].speed_factor)


func dry_mass() -> float:
	return float(HULLS[_hull_id].dry_mass)


func flight_mass(payload: int, jump_reserve := -1.0, waste := -1) -> float:
	var military_selected := drive_kind == DRIVE_MILITARY
	var reserve := jump_fuel if jump_reserve < 0.0 or military_selected else jump_reserve
	var special := military_fuel if jump_reserve < 0.0 or not military_selected else jump_reserve
	var mass := dry_mass() + float(payload) * CARGO_UNIT_MASS + (fuel + reserve) * FUEL_UNIT_MASS
	mass += 0.9 + special * 0.006 + float(military_waste if waste < 0 else waste) * 0.06 if military_drive else 0.0
	mass += TANK_HARDWARE_MASS if tank_upgraded else 0.0
	mass += 0.45 if cargo_upgraded else 0.0
	mass += 0.45 if heat_shield else 0.0
	mass += 0.35 if range_drive else 0.0
	mass += 0.2 if eco_upgraded else 0.0
	mass += 0.15 if mining_laser else 0.0
	mass += 0.16 if fragment_collector else 0.0
	mass += 0.1 if fuel_pump else 0.0
	mass -= SCOOP_MASS if not hydrogen_scoop else 0.0
	mass -= AUTOPILOT_MASS if not autopilot_fitted else 0.0
	return mass


func thrust_acceleration(local_direction: Vector3, payload: int) -> Vector3:
	var profile: Dictionary = HULLS[_hull_id]
	var positive: Vector3 = profile.thrust_positive
	var negative: Vector3 = profile.thrust_negative
	var axes := Vector3(positive.x if local_direction.x >= 0.0 else negative.x,
		positive.y if local_direction.y >= 0.0 else negative.y, positive.z if local_direction.z >= 0.0 else negative.z)
	var power := 1.0 if fuel > 0.0 else RESERVE_THRUST_FRACTION
	return axes * (power / flight_mass(payload))


func roll_rate(payload: int) -> float:
	var nominal_mass := dry_mass() + 2.0 * BASE_CAPACITY * FUEL_UNIT_MASS
	return float(HULLS[_hull_id].roll_rate) * nominal_mass / flight_mass(payload)


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


func apply_damage(amount: float, can_destroy := false) -> float:
	if amount <= 0.0 or not is_finite(amount):
		return 0.0
	var previous := hull
	hull = maxf(0.0 if can_destroy else MIN_HULL, hull - amount)
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
	var units := 0
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
		"range_drive":
			cost = RANGE_DRIVE_COST
			installed = range_drive
		"military_drive":
			cost = MILITARY_DRIVE_COST
			installed = military_drive
		"military_refuel":
			var price := unit_price + MILITARY_FUEL_SURCHARGE
			if military_drive and price > 0:
				units = mini(int(MILITARY_CAPACITY - military_fuel), floori(float(credits) / price))
				cost = _service_cost(units, price)
		"military_waste":
			units = mini(military_waste, floori(float(credits) / MILITARY_DISPOSAL_PRICE))
			cost = _service_cost(units, MILITARY_DISPOSAL_PRICE)
	return {"cost": cost, "units": units, "allowed": cost > 0 and cost <= credits and not installed, "installed": installed}


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
		"range_drive":
			range_drive = true
			drive_kind = DRIVE_RANGE
		"military_drive":
			military_drive = true
		"military_refuel":
			military_fuel += int(offer.units)
		"military_waste":
			military_waste -= int(offer.units)
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


func set_autopilot_fitted(fitted: bool) -> bool:
	if autopilot_fitted == fitted:
		return false
	autopilot_fitted = fitted
	return true


func snapshot() -> Dictionary:
	return {
		"hull_id": _hull_id,
		"fuel": fuel, "jump_fuel": jump_fuel,
		"tank_upgraded": tank_upgraded, "eco_upgraded": eco_upgraded,
		"hull": hull, "cargo_upgraded": cargo_upgraded, "heat_shield": heat_shield,
		"mining_laser": mining_laser, "fragment_collector": fragment_collector,
		"hydrogen_scoop": hydrogen_scoop, "fuel_pump": fuel_pump, "pump_mode": pump_mode,
		"range_drive": range_drive, "drive_kind": drive_kind, "autopilot_fitted": autopilot_fitted,
	}


func military_snapshot() -> Dictionary:
	return {"installed": military_drive, "fuel": military_fuel, "waste": military_waste}


func restore(value: Variant, legacy := false, pre_shield := false, pre_dual_fuel := false,
		pre_shipyard := false, pre_orbital_mining := false, pre_fuel_equipment := false, pre_jump_drive := false,
		pre_autopilot_equipment := false, military: Variant = null, can_destroy := false) -> bool:
	var fitted := false
	var reserve := 0.0
	var waste := 0
	if military != null:
		if not military is Dictionary or military.size() != 3 or not military.get("installed") is bool:
			return false
		if not _storage_units(military.get("fuel"), MILITARY_CAPACITY) or not _storage_units(military.get("waste"), MILITARY_WASTE_CAPACITY):
			return false
		fitted = military.installed
		reserve = float(military.fuel)
		waste = int(military.waste)
		if not fitted and (reserve != 0.0 or waste != 0):
			return false
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
	elif pre_jump_drive:
		fields = PRE_JUMP_DRIVE_FIELDS
	elif pre_autopilot_equipment:
		fields = PRE_AUTOPILOT_EQUIPMENT_FIELDS
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
	if "pump_mode" in fields and (not value.hydrogen_scoop is bool or not value.fuel_pump is bool
			or not value.pump_mode is String or value.pump_mode not in PUMP_MODES
			or (not value.fuel_pump and value.pump_mode != PUMP_OFF)):
		return false
	if "drive_kind" in fields and (not value.range_drive is bool or not value.drive_kind is String
			or value.drive_kind not in [DRIVE_STANDARD, DRIVE_RANGE, DRIVE_MILITARY]
			or (not value.range_drive and value.drive_kind == DRIVE_RANGE)
			or (not fitted and value.drive_kind == DRIVE_MILITARY)):
		return false
	if "autopilot_fitted" in fields and not value.autopilot_fitted is bool:
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
		if not is_finite(restored_hull) or restored_hull < (0.0 if can_destroy else MIN_HULL) or restored_hull > MAX_HULL:
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
	autopilot_fitted = value.get("autopilot_fitted", true)
	range_drive = value.get("range_drive", false)
	drive_kind = value.get("drive_kind", DRIVE_STANDARD)
	military_drive = fitted
	military_fuel = reserve
	military_waste = waste
	return true


static func _storage_units(value: Variant, limit: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= limit and value == int(value)
