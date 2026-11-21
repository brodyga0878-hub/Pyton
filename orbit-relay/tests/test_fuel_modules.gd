extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Economy := preload("res://scripts/port_economy.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const HYDROGEN := Economy.HYDROGEN
const STAR := Catalog.STAR_ID
const PORT := 1
const ASTEROID := 2
const STEP := Fixture.STEP
const SAVE_PATH := "user://fuel-modules-test.json"

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_modules_in_flight()
	print("Fuel module integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_modules_in_flight() -> void:
	var flight := Flight.new()
	var initial := flight.fuel_equipment_status()
	_expect(initial.scoop and not initial.pump and initial.mode == "off" and initial.station
		and not initial.can_set_mode and initial.canisters == 0 and not flight.set_fuel_pump_mode("reaction"),
		"The starter's removable scoop works by default and an absent pump has no active mode")
	if not _expect(flight.contract_action() and Fixture.depart(flight) and _dock_at(flight, PORT)
		and flight.contract_action() and flight.credits == 240,
		"Earn a real courier payout and dock at its recipient"):
		return
	var before := flight.fuel_equipment_status()
	if not _expect(before.scoop_resale == 75 and flight.remove_fuel_module("hydrogen_scoop")
		and flight.credits == 315 and not flight.fuel_equipment_status().scoop
		and not flight.remove_fuel_module("hydrogen_scoop") and flight.credits == 315
		and flight.service_offer("fuel_pump").cost == 110 and flight.service_action("fuel_pump")
		and not flight.service_action("fuel_pump") and flight.credits == 205 and flight.fuel_equipment_status().pump,
		"Trade the fitted scoop once and buy an independent pump with the real delivery money"):
		return
	if not _expect(Fixture.depart(flight) and _reach_star(flight), "Take the normal flight route to the star with the scoop removed"):
		return
	var band := flight.scoop_status()
	_expect(band.body == STAR and float(band.distance) >= Catalog.SCOOP_INNER and float(band.distance) <= Catalog.SCOOP_OUTER
		and not band.ok and not flight.scoop_action() and not flight.scooping
		and not flight.remove_fuel_module("fuel_pump") and not flight.service_action("hydrogen_scoop")
		and flight.credits == 205 and flight.mining.cargo_amount(HYDROGEN) == 0,
		"A real stellar-band arrival cannot collect without installed equipment and cannot buy or sell mid-flight")
	if not _expect(_dock_at(flight, PORT) and flight.service_offer("hydrogen_scoop").cost == 150
		and flight.service_action("hydrogen_scoop") and not flight.service_action("hydrogen_scoop")
		and flight.credits == 55 and flight.fuel_equipment_status().scoop,
		"Reinstall the scoop at the port through the regular outfitting service"):
		return
	if not _expect(Fixture.depart(flight) and _reach_star(flight) and flight.scoop_status().ok,
		"The refitted ship returns to the star and its normal collection interlocks permit intake"):
		return
	flight.ship.fuel = 5.0
	flight.ship.jump_fuel = 8.0
	if not _expect(flight.set_fuel_pump_mode("reaction") and flight.scoop_action()
		and not flight.set_fuel_pump_mode("jump") and not flight.fuel_equipment_status().can_set_mode
		and _advance(flight, func() -> bool: return flight.mining.cargo_amount(HYDROGEN) >= 7, 26.0),
		"Collect real hydrogen canisters while the selected pump is interlocked with the open scoop"):
		return
	var canisters := flight.mining.cargo_amount(HYDROGEN)
	_expect(flight.ship.fuel == 5.0 and flight.ship.jump_fuel == 8.0
		and flight.fuel_equipment_status().mode == "reaction",
		"The enabled pump neither transfers from an open scoop nor changes its selected circuit")
	if not _expect(flight.scoop_action() and flight.set_fuel_pump_mode("off") and not flight.set_fuel_pump_mode("both"),
		"Close the scoop, switch the pump off and reject an invalid simultaneous-circuit mode"):
		return
	_align_clock(flight)
	var stellar := flight.snapshot()
	_test_counted_pumping(flight, canisters)
	_test_jump_threshold(stellar, canisters)
	_test_surface_pause(stellar, canisters)
	_test_jump_charge_pause(stellar, canisters)
	_test_port_and_manual_transfer(stellar, canisters)


func _test_counted_pumping(flight: Flight, canisters: int) -> void:
	var elapsed := flight.orbit_time
	if not _expect(flight.set_fuel_pump_mode("reaction") and flight.orbit_time == elapsed
		and flight.mining.cargo_amount(HYDROGEN) == canisters,
		"Selecting a mode changes no stock and does not advance world time"):
		return
	_tick(flight, 0.60)
	_expect(flight.ship.fuel == 5.0 and flight.mining.cargo_amount(HYDROGEN) == canisters,
		"No canister transfers before the next whole game second")
	_tick(flight, 0.25)
	_expect(flight.ship.fuel == 15.0 and flight.ship.jump_fuel == 8.0
		and flight.mining.cargo_amount(HYDROGEN) == canisters - 1,
		"One elapsed whole second transfers one complete canister exclusively to the selected reaction tank")
	var resumed := Flight.new()
	if not _expect(SessionIO.save_state(flight.snapshot(), SAVE_PATH) == OK and resumed.restore(SessionIO.load_state(SAVE_PATH))
		and resumed.fuel_equipment_status().mode == "reaction" and resumed.fuel_equipment_status().pump
		and resumed.ship.fuel == 15.0 and resumed.mining.cargo_amount(HYDROGEN) == canisters - 1,
		"Reloading immediately after a transfer preserves its mode and the already-consumed canister"):
		return
	_tick(resumed, 0.50)
	_expect(resumed.ship.fuel == 15.0 and resumed.mining.cargo_amount(HYDROGEN) == canisters - 1,
		"Reloading cannot spend a second canister in the same elapsed second")
	_tick(resumed, 1.50)
	_expect(resumed.ship.fuel == 35.0 and resumed.ship.jump_fuel == 8.0
		and resumed.mining.cargo_amount(HYDROGEN) == canisters - 3,
		"Subsequent whole seconds replenish the reaction tank at one per second until it reaches 35 percent")
	_tick(resumed, 2.0)
	_expect(resumed.ship.fuel == 35.0 and resumed.mining.cargo_amount(HYDROGEN) == canisters - 3,
		"Automatic replenishment stops at the threshold with further canisters safely in cargo")
	for key: String in ["pump_mode", "fuel_pump", "hydrogen_scoop"]:
		var invalid := resumed.snapshot()
		invalid.ship[key] = 7
		var expected := resumed.snapshot()
		_expect(not resumed.restore(invalid) and resumed.snapshot() == expected,
			"An invalid equipment field cannot alter the active flight: %s" % key)


func _test_jump_threshold(stellar: Dictionary, canisters: int) -> void:
	var flight := Flight.new()
	if not _expect(flight.restore(stellar) and flight.set_fuel_pump_mode("jump"), "Choose automatic resupply specifically for the jump reserve"):
		return
	flight.ship.jump_fuel = 35.5
	_tick(flight, 1.0)
	_expect(flight.ship.jump_fuel == 35.5 and flight.ship.fuel == 5.0 and flight.mining.cargo_amount(HYDROGEN) == canisters,
		"With no selected fare and above 35 percent the jump pump consumes nothing")
	if not _expect(flight.plan_jump(Catalog.FRINGE_SYSTEM) and flight.jump_status(Catalog.FRINGE_SYSTEM).cost > 35.5,
		"Plot a genuine mass-adjusted fare above the default reserve threshold"):
		return
	_tick(flight, 1.0)
	_expect(flight.ship.jump_fuel == 45.5 and flight.ship.fuel == 5.0 and flight.mining.cargo_amount(HYDROGEN) == canisters - 1,
		"The next fare raises the threshold while the unselected reaction circuit remains untouched")
	_tick(flight, 2.0)
	_expect(flight.ship.jump_fuel == 45.5 and flight.mining.cargo_amount(HYDROGEN) == canisters - 1,
		"The jump pump stops when the published next fare can be paid")


func _test_surface_pause(stellar: Dictionary, canisters: int) -> void:
	var flight := Flight.new()
	if not _expect(flight.restore(stellar) and flight.select_target(ASTEROID), "Resume with stored stellar canisters and select a genuine landing approach"):
		return
	flight.set_autopilot(true)
	if not _expect(_advance(flight, func() -> bool: return flight.landed_site == ASTEROID, 150.0)
		and flight.set_fuel_pump_mode("reaction"),
		"Land physically on an asteroid before enabling the installed pump"):
		return
	var before: float = flight.ship.fuel
	_tick(flight, 2.5)
	_expect(flight.landed_site == ASTEROID and before < 35.0 and flight.ship.fuel == before
		and flight.mining.cargo_amount(HYDROGEN) == canisters,
		"An enabled pump stays idle on the surface despite low fuel and elapsed game seconds")


func _test_jump_charge_pause(stellar: Dictionary, canisters: int) -> void:
	var flight := Flight.new()
	if not _expect(flight.restore(stellar) and flight.plan_jump(Catalog.VELAR_SYSTEM),
		"Resume the stellar approach and plan a real interstellar jump"):
		return
	var direction := (flight.position - flight.target_position(STAR)).normalized()
	flight.yaw = atan2(-direction.x, -direction.z)
	flight.pitch = asin(clampf(direction.y, -1.0, 1.0))
	flight.change_throttle(0.18)
	flight.ship.jump_fuel = float(flight.jump_status(Catalog.VELAR_SYSTEM).cost)
	if not _expect(_advance(flight, func() -> bool: return flight.jump_status(Catalog.VELAR_SYSTEM).ok, 35.0),
		"Clear the stellar band before charging"):
		return
	var fare := float(flight.jump_status(Catalog.VELAR_SYSTEM).cost)
	flight.ship.jump_fuel = fare
	if not _expect(flight.set_fuel_pump_mode("jump") and flight.start_jump()
		and not flight.set_fuel_pump_mode("off") and not flight.fuel_equipment_status().can_set_mode,
		"Clear the stellar band and charge immediately after selecting the pump for the low jump reserve"):
		return
	_tick(flight, 1.1)
	_expect(flight.jump_seconds_left > 0.0 and flight.ship.jump_fuel == fare
		and flight.mining.cargo_amount(HYDROGEN) == canisters,
		"The pump holds its stock while the jump drive is charging across a whole second")
	_expect(_advance(flight, func() -> bool: return flight.system_id == Catalog.VELAR_SYSTEM, 4.0)
		and flight.ship.jump_fuel == 0.0 and flight.mining.cargo_amount(HYDROGEN) == canisters,
		"Completing the physical jump debits the fare without an extra canister on the arrival frame")


func _test_port_and_manual_transfer(stellar: Dictionary, canisters: int) -> void:
	var flight := Flight.new()
	if not _expect(flight.restore(stellar) and _dock_at(flight, PORT) and flight.set_fuel_pump_mode("reaction"),
		"Dock through autopilot with collected canisters and enable the pump in port"):
		return
	var reaction: float = flight.ship.fuel
	var jump: float = flight.ship.jump_fuel
	_tick(flight, 3.0)
	_expect(reaction < 35.0 and flight.ship.fuel == reaction and flight.ship.jump_fuel == jump
		and flight.mining.cargo_amount(HYDROGEN) == canisters, "The installed pump stays idle at the dock")
	var status := flight.fuel_equipment_status()
	var credits := flight.credits
	if not _expect(status.pump_resale == 55 and flight.remove_fuel_module("fuel_pump")
		and not flight.remove_fuel_module("fuel_pump") and flight.credits == credits + 55
		and not flight.fuel_equipment_status().pump and flight.fuel_equipment_status().mode == "off"
		and not flight.set_fuel_pump_mode("jump"),
		"Reselling the pump at the dock clears its mode, preserves the scoop and credits only once"):
		return
	flight.ship.fuel = 95.0
	_expect(flight.fuel_transfer("reaction") and flight.ship.fuel == 100.0
		and flight.ship.jump_fuel == jump and flight.mining.cargo_amount(HYDROGEN) == canisters - 1
		and flight.fuel_equipment_status().scoop,
		"The original manual last-canister transfer works independently of the sold pump")


func _reach_star(flight: Flight) -> bool:
	if not flight.select_target(STAR):
		return false
	flight.set_autopilot(true)
	return _advance(flight, func() -> bool: return not flight.autopilot, 160.0)


func _dock_at(flight: Flight, port: int) -> bool:
	if not flight.select_target(port):
		return false
	flight.set_autopilot(true)
	return _advance(flight, func() -> bool: return flight.docked == port, 160.0)


func _align_clock(flight: Flight) -> void:
	_tick(flight, floorf(flight.orbit_time) + 1.20 - flight.orbit_time)


func _advance(flight: Flight, reached: Callable, seconds: float) -> bool:
	for _frame in range(ceili(seconds / STEP)):
		if reached.call():
			return true
		_tick(flight, STEP)
	return reached.call()


func _tick(flight: Flight, seconds: float) -> void:
	flight.update(seconds, Vector2.ZERO, 0.0, false, false)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
