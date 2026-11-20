extends RefCounted

const Catalog := preload("res://scripts/sector_catalog.gd")
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
	state.mining.reserves.resize(Catalog.PRE_GROUND_DESTINATION_COUNT)
	state.market.erase(str(Catalog.GROUND_PAD))
	state.market.erase(str(Catalog.GROUND_HANGAR))
