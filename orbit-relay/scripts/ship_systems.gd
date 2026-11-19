extends RefCounted
## Fuel and permanently installed equipment for one ship.

const BASE_CAPACITY := 100.0
const EXTRA_CAPACITY := 50.0
const TANK_COST := 260
const ECO_COST := 320
const SAVE_FIELDS := ["fuel", "tank_upgraded", "eco_upgraded"]

var fuel: float = BASE_CAPACITY
var tank_upgraded := false
var eco_upgraded := false


func capacity() -> float:
	return BASE_CAPACITY + EXTRA_CAPACITY if tank_upgraded else BASE_CAPACITY


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


func quote_refill(unit_price: int) -> int:
	var missing_units := ceili(capacity() - fuel)
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
		"tank":
			cost = TANK_COST
			installed = tank_upgraded
		"eco":
			cost = ECO_COST
			installed = eco_upgraded
	return {"cost": cost, "allowed": cost > 0 and cost <= credits and not installed, "installed": installed}


func buy(action: String, unit_price: int, credits: int) -> int:
	var offer := service_offer(action, unit_price, credits)
	if not offer.allowed:
		return 0
	match action:
		"refuel":
			fuel = capacity()
		"tank":
			tank_upgraded = true
		"eco":
			eco_upgraded = true
	return offer.cost


func snapshot() -> Dictionary:
	return {"fuel": fuel, "tank_upgraded": tank_upgraded, "eco_upgraded": eco_upgraded}


func restore(value: Variant) -> bool:
	if not value is Dictionary or value.size() != SAVE_FIELDS.size() or not value.has_all(SAVE_FIELDS):
		return false
	if not value.tank_upgraded is bool or not value.eco_upgraded is bool:
		return false
	if not (value.fuel is float or value.fuel is int):
		return false
	var restored_fuel := float(value.fuel)
	var restored_capacity := BASE_CAPACITY + EXTRA_CAPACITY if value.tank_upgraded else BASE_CAPACITY
	if not is_finite(restored_fuel) or restored_fuel < 0.0 or restored_fuel > restored_capacity:
		return false
	fuel = restored_fuel
	tank_upgraded = value.tank_upgraded
	eco_upgraded = value.eco_upgraded
	return true
