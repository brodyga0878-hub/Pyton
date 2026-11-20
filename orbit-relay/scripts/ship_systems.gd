extends RefCounted
## Fuel, hull condition and permanently installed equipment for one ship.

const BASE_CAPACITY := 100.0
const EXTRA_CAPACITY := 50.0
const HYDROGEN_UNITS_PER_CANISTER := 10
const TANK_COST := 260
const ECO_COST := 320
const CARGO_COST := 300
const HEAT_SHIELD_COST := 340
const HEAT_SHIELD_REDUCTION := 48
const BASE_CARGO_CAPACITY := 24
const EXPANDED_CARGO_CAPACITY := 40
const MAX_HULL := 100.0
const MIN_HULL := 1.0
const LEGACY_SAVE_FIELDS := ["fuel", "tank_upgraded", "eco_upgraded"]
const PRE_SHIELD_SAVE_FIELDS := ["fuel", "tank_upgraded", "eco_upgraded", "hull", "cargo_upgraded"]
const PRE_DUAL_FUEL_FIELDS := ["fuel", "tank_upgraded", "eco_upgraded", "hull", "cargo_upgraded", "heat_shield"]
const SAVE_FIELDS := ["fuel", "jump_fuel", "tank_upgraded", "eco_upgraded", "hull", "cargo_upgraded", "heat_shield"]

var fuel: float = BASE_CAPACITY
var jump_fuel: float = BASE_CAPACITY
var tank_upgraded := false
var eco_upgraded := false
var hull: float = MAX_HULL
var cargo_upgraded := false
var heat_shield := false


func capacity() -> float:
	return BASE_CAPACITY + EXTRA_CAPACITY if tank_upgraded else BASE_CAPACITY


func jump_capacity() -> float:
	return capacity()


func cargo_capacity() -> int:
	return EXPANDED_CARGO_CAPACITY if cargo_upgraded else BASE_CARGO_CAPACITY


func entry_heat_factor() -> float:
	return 1.0 - HEAT_SHIELD_REDUCTION / 100.0 if heat_shield else 1.0


func burn(delta: float, load: float, boost: bool) -> void:
	if fuel <= 0.0 or delta <= 0.0 or not is_finite(delta) or not is_finite(load):
		return
	var throttle := clampf(load, 0.0, 1.0)
	if throttle == 0.0 and not boost:
		return
	var rate := 3.0 if boost else 0.2 + 0.9 * throttle
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
	return offer.cost


func snapshot() -> Dictionary:
	return {
		"fuel": fuel, "jump_fuel": jump_fuel,
		"tank_upgraded": tank_upgraded, "eco_upgraded": eco_upgraded,
		"hull": hull, "cargo_upgraded": cargo_upgraded, "heat_shield": heat_shield,
	}


func restore(value: Variant, legacy := false, pre_shield := false, pre_dual_fuel := false) -> bool:
	var fields := PRE_DUAL_FUEL_FIELDS if pre_dual_fuel else SAVE_FIELDS
	if legacy:
		fields = LEGACY_SAVE_FIELDS
	elif pre_shield:
		fields = PRE_SHIELD_SAVE_FIELDS
	if not value is Dictionary or value.size() != fields.size() or not value.has_all(fields):
		return false
	if not value.tank_upgraded is bool or not value.eco_upgraded is bool:
		return false
	if not (legacy or pre_shield) and not value.heat_shield is bool:
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
	hull = restored_hull
	cargo_upgraded = restored_cargo_upgrade
	heat_shield = false if legacy or pre_shield else value.heat_shield
	return true
