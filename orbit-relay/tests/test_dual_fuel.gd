extends SceneTree

const Catalog = preload("res://scripts/sector_catalog.gd")
const Economy = preload("res://scripts/port_economy.gd")
const Flight = preload("res://scripts/flight_sim.gd")
const Step := 1.0 / 60.0
const Giant := Catalog.GAS_GIANT_ID
const Hydrogen := Economy.HYDROGEN

var _checks := 0
var _errors: Array[String] = []


func _initialize() -> void:
	_check_gas_conditions()
	_check_gas_autopilot_and_jump()
	_check_collecting_with_full_cargo()
	print("Separate fuel and giant skimming: %d checks, %d failures" % [_checks, _errors.size()])
	for error in _errors:
		printerr(error)
	quit(1 if not _errors.is_empty() else 0)


func _check_gas_conditions() -> void:
	var flight := _gas_approach(45.0)
	var status := flight.scoop_status()
	var air := flight.atmosphere_status()
	_check(Catalog.is_gas_giant(Giant) and not Catalog.is_port(Giant) and not Catalog.is_mine_site(Giant),
		"Gas giant is a real non-landable body")
	_check(status.ok and status.kind == "gas" and status.body == Giant and absf(status.altitude - 45.0) < 0.01,
		"Skimming uses gas altitude while tracking the moving body's frame")
	_check(air.inside and air.density > 0.0 and absf(air.altitude - 45.0) < 0.01
		and not flight.cycle_time_scale(), "Atmosphere instrument and time safety agree with the scoop band")
	_check(not flight.dock_action() and not flight.mine_action() and not flight.landed,
		"A gas collector cannot accidentally invoke landing or mining")
	_check(not _gas_approach(90.0).scoop_action() and not _gas_approach(20.0).scoop_action(),
		"Collection below and above the useful layer is rejected")
	flight.velocity += Vector3.RIGHT * (Flight.GAS_SCOOP_SPEED + 2.0)
	_check(not flight.scoop_status().ok and not flight.scoop_action(),
		"Excess speed is checked relative to the moving atmosphere")
	flight.velocity = flight.target_velocity(Giant)
	flight.entry_heat = Flight.HEAT_SCOOP_LIMIT
	_check(not flight.scoop_action(), "A heat-cutoff gas scoop cannot be restarted")
	flight.entry_heat = 0.0
	_check(flight.scoop_action(), "Cooling unlocks the collector at the same site")
	_tick(flight, 0.6)
	_check(flight.scoop_status().progress > 0.0 and flight.scoop_status().progress < 1.0
		and flight.mining.cargo_amount(Hydrogen) == 0, "A partial canister has no cargo or fuel value")
	flight.position = flight.target_position(Giant) + Vector3.BACK * 610.0
	_tick(flight, Step)
	_check(not flight.scooping and flight.scoop_status().progress == 0.0
		and flight.status_event == "scoop_stop", "Exiting the shell discards only unfinished collection")


func _check_gas_autopilot_and_jump() -> void:
	var flight := Flight.new()
	flight.ship.fuel = 0.0
	flight.ship.jump_fuel = 2.0
	_check(flight.dock_action() and flight.select_target(Giant), "An empty maneuver tank still allows station departure")
	flight.set_autopilot(true)
	for _frame in range(60 * 180):
		if not flight.autopilot:
			break
		_tick(flight, Step)
	if not _check(not flight.autopilot and flight.status_event == "gas_arrival" and flight.scoop_status().ok
		and flight.ship.hull == 100.0, "The normal autopilot reaches the moving scoop band safely on reserve thrust"):
		return
	_check(flight.scoop_action() and not flight.fuel_transfer("jump")
		and flight.scoop_active_at(Giant), "Active collection blocks fuel transfer and remembers the source")
	_tick(flight, 6.0)
	_check(flight.mining.cargo_amount(Hydrogen) >= 4 and flight.ship.fuel == 0.0 and flight.ship.jump_fuel == 2.0,
		"Gas produces transferable canisters in the hold without filling either reserve")
	_check(flight.scoop_action(), "The player stops the collector before opening the transfer lines")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(flight.snapshot()))
	var restored := Flight.new()
	if not _check(restored.restore(saved) and not restored.scooping and restored.scoop_status().progress == 0.0,
		"The game can resume a save inside the shell with its finished canisters"):
		return
	var canisters := restored.mining.cargo_amount(Hydrogen)
	var jump_offer := restored.fuel_transfer_offer("jump")
	_check(jump_offer.ok and jump_offer.canisters == canisters and jump_offer.added == canisters * 10.0
		and restored.fuel_transfer("jump") and restored.ship.fuel == 0.0, "Canister transfer accepts only the selected reserve")
	_check(restored.plan_jump(Catalog.VELAR_SYSTEM) and not restored.start_jump(),
		"Having enough fuel still cannot charge the jump drive inside the atmosphere")
	restored.position = restored.target_position(Giant) + Vector3.BACK * 780.0
	restored.velocity = Vector3.ZERO
	var previous := restored.ship.jump_fuel
	_check(restored.start_jump(), "The transfer finances a normal jump after clearing the gas giant")
	_tick(restored, Flight.JUMP_CHARGE + Step)
	_check(restored.system_id == Catalog.VELAR_SYSTEM and restored.ship.fuel == 0.0
		and is_equal_approx(restored.ship.jump_fuel, previous - float(Catalog.JUMP_FUEL)),
		"Completed jump debits only the jump reserve")


func _check_collecting_with_full_cargo() -> void:
	var flight := Flight.new()
	flight.dock_action()
	flight.select_target(Catalog.STAR_ID)
	flight.position = flight.target_contact(Catalog.STAR_ID)
	flight.velocity = Vector3.ZERO
	flight.ship.fuel = 92.5
	flight.ship.jump_fuel = 0.0
	_check(flight.mining.insert_cargo("ore", flight.ship.cargo_capacity()) and not flight.scoop_action(),
		"A full ordinary hold prevents stellar collection")
	_check(flight.fuel_cargo_options().size() == 1 and not flight.jettison_cargo("invalid")
		and flight.jettison_cargo("ore") and flight.mining.free_capacity() == 1,
		"Explicit jettison frees exactly one selected unit")
	_check(flight.scoop_action() and flight.scoop_active_at(Catalog.STAR_ID), "A free slot permits stellar collection")
	_tick(flight, 3.0)
	var offer := flight.fuel_transfer_offer("reaction")
	_check(not flight.scooping and flight.status_event == "scoop_full" and flight.mining.cargo_amount(Hydrogen) == 1
		and offer.canisters == 1 and is_equal_approx(offer.added, 7.5), "Collection stops at capacity and quotes the final partial refill")
	_check(flight.fuel_transfer("reaction") and flight.ship.fuel == 100.0 and flight.ship.jump_fuel == 0.0
		and flight.mining.free_capacity() == 1, "Moving hydrogen to the maneuver reserve leaves the empty jump circuit untouched")


func _gas_approach(altitude: float) -> Flight:
	var flight := Flight.new()
	flight.dock_action()
	flight.select_target(Giant)
	flight.position = flight.target_position(Giant) + Vector3.BACK * (float(Catalog.site(Giant).radius) + altitude)
	flight.velocity = flight.target_velocity(Giant)
	return flight


func _tick(flight: Flight, delta: float) -> void:
	flight.update(delta, Vector2.ZERO, 0.0, false, false)


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_errors.append(message)
	return condition
