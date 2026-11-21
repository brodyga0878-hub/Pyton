extends RefCounted

const Catalog := preload("res://scripts/sector_catalog.gd")
const Economy := preload("res://scripts/port_economy.gd")
const STEP := 1.0 / 60.0


static func launch(flight: RefCounted) -> bool:
	# Set up the first airborne frame without advancing the epoch of unrelated tests.
	if flight.docked < 0:
		return false
	flight._launch()
	return flight.docked < 0


static func await_departure(flight: RefCounted, maximum := 15.0, tick := Callable()) -> bool:
	for _frame in range(ceili(maximum / STEP)):
		if flight.docked < 0:
			return true
		if tick.is_valid():
			tick.call(STEP)
		else:
			flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	return flight.docked < 0


static func depart(flight: RefCounted) -> bool:
	return flight.docked >= 0 and flight.dock_action() and await_departure(flight)


static func remove_ground_ports_from_legacy(state: Dictionary) -> void:
	remove_expanded_market_from_legacy(state)
	state.mining.reserves.resize(Catalog.PRE_GROUND_DESTINATION_COUNT)
	state.market.erase(str(Catalog.GROUND_PAD))
	state.market.erase(str(Catalog.GROUND_HANGAR))


static func remove_expanded_market_from_legacy(state: Dictionary) -> void:
	remove_schema_51_from_legacy(state)
	remove_extended_career_from_legacy(state)
	remove_ordnance_from_legacy(state)
	for good: String in Economy.NEW_GOODS:
		state.mining.cargo.erase(good)
		for inventory: Dictionary in state.market.values():
			inventory.erase(good)
	state.erase("market_contacts")


static func remove_schema_51_from_legacy(state: Dictionary) -> void:
	if state.mining.reserves.size() > Catalog.PRE_REACH_DESTINATION_COUNT:
		state.mining.reserves.resize(Catalog.PRE_REACH_DESTINATION_COUNT)
	state.combat.erase("energy_pulse")
	state.patrol.erase("tactics")
	state.erase("law")


static func remove_extended_career_from_legacy(state: Dictionary) -> void:
	if state.has("career"):
		state.career.erase("order")
		state.career.erase("bounty")


static func remove_ordnance_from_legacy(state: Dictionary) -> void:
	if state.has("combat"):
		state.combat.erase("ordnance")
		state.combat.erase("ecm_advanced")
		state.combat.erase("energy_pulse")
		state.combat.projectile.erase("hardened")
	if state.get("patrol") is Dictionary:
		state.patrol.erase("tactics")
