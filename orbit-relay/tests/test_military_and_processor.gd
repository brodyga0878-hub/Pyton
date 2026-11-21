extends SceneTree

const Main := preload("res://main.tscn")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Ports := preload("res://scripts/port_services.gd")
const Ship := preload("res://scripts/ship_systems.gd")
const Processor := preload("res://scripts/surface_processor.gd")
const Session := preload("res://scripts/session_io.gd")
const Atmosphere := preload("res://scripts/atmosphere.gd")
const Dynamics := preload("res://scripts/orbital_dynamics.gd")
const OPEN := Vector3(3600.0, 8600.0, 9200.0)
const SITE := Flight.ASTEROID_TARGET
const HOME := Catalog.HOME_SYSTEM
const VELAR := Catalog.VELAR_SYSTEM
const SAVE := "user://military-processor-test.json"

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_military_cycle()
	_test_processor_cycle()
	_test_environment()
	await _test_controls()
	print("Military drive and surface processor integration: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _test_military_cycle() -> void:
	var flight := Flight.new()
	flight.credits = 2200
	var legacy := flight.snapshot()
	legacy.schema = 50
	legacy.erase("military_drive")
	legacy.erase("surface_processor")
	Fixture.remove_schema_51_from_legacy(legacy)
	var migrated := Flight.new()
	_expect(migrated.restore(legacy) and not migrated.jump_drive_status().have_military
		and not migrated.processor_status().installed and migrated.ship.jump_fuel == 100.0,
		"Schema 50 keeps its ordinary tank and starts with neither optional module fitted")
	var standard: int = flight.jump_tariff(HOME, VELAR)
	if not _expect(not flight.select_jump_drive(Ship.DRIVE_MILITARY) and not flight.service_action("military_refuel")
		and flight.service_action("military_drive") and flight.ship.drive_kind == Ship.DRIVE_STANDARD
		and flight.credits == 2200 - Ship.MILITARY_DRIVE_COST,
		"The port buys one fitted drive and a separate empty tank without silently replacing the active drive"):
		return
	var refill := flight.service_offer("military_refuel")
	if not _expect(flight.service_action("military_refuel") and int(refill.units) == int(Ship.MILITARY_CAPACITY)
		and flight.ship.military_fuel == Ship.MILITARY_CAPACITY and flight.ship.jump_fuel == 100.0
		and flight.select_jump_drive(Ship.DRIVE_MILITARY), "A port fills only the military reserve before selecting it"):
		return
	Fixture.launch(flight)
	_open_space(flight)
	var military: int = flight.jump_tariff(HOME, VELAR)
	_expect(military < standard and flight.plan_route(VELAR) and int(flight.planned_route().legs[0].fuel) == military
		and not flight.service_action("military_refuel") and not flight.service_action("military_waste"),
		"Route and cockpit price the active drive, with no depot service in flight")
	flight.ship.military_waste = Ship.MILITARY_WASTE_CAPACITY - 1
	_expect(not flight.jump_status(VELAR).ok and flight.jump_status(VELAR).reason.contains("отходов")
		and not flight.start_jump() and flight.ship.military_fuel == Ship.MILITARY_CAPACITY,
		"Insufficient sealed storage prevents a jump before charging or spending")
	flight.ship.military_waste = 0
	_expect(flight.start_jump() and flight.cancel_jump() and flight.ship.military_fuel == Ship.MILITARY_CAPACITY
		and flight.ship.military_waste == 0, "Canceling charge produces no waste and spends no reserve")
	if not _expect(flight.start_jump() and _until(flight, func() -> bool: return flight.jump_progress_status().is_transit, 3.0),
		"The authorized jump enters paid transit"):
		return
	var paid := flight.snapshot()
	var waste := flight.ship.waste_for_jump(military)
	_expect(flight.ship.jump_fuel == 100.0 and flight.ship.military_fuel == Ship.MILITARY_CAPACITY - military
		and flight.ship.military_waste == waste and int(paid.jump_transit.fare) == military,
		"Committing spends military fuel and produces the corresponding waste exactly once")
	var malformed := paid.duplicate(true)
	malformed.military_drive.waste = 0
	var cold := Flight.new()
	_expect(not cold.restore(malformed), "A paid military ticket cannot restore with the waste receipt missing")
	if not _expect(Session.save_state(paid, SAVE) == OK and cold.restore(Session.load_state(SAVE))
		and _until(cold, func() -> bool: return cold.system_id == VELAR, 2.0)
		and cold.ship.military_fuel == Ship.MILITARY_CAPACITY - military and cold.ship.military_waste == waste,
		"A cold paid reload arrives without repeating either fuel debit or waste deposit"):
		return
	var station := int(Catalog.system(VELAR).arrival_port)
	cold.select_target(station)
	cold.set_autopilot(true)
	if not _expect(_until(cold, func() -> bool: return cold.docked == station, 90.0), "Arrive at an operational depot"):
		return
	var balance := cold.credits
	var disposal := cold.service_offer("military_waste")
	_expect(cold.service_action("military_waste") and int(disposal.units) == waste and cold.ship.military_waste == 0
		and cold.credits == balance - waste * Ship.MILITARY_DISPOSAL_PRICE and not cold.service_action("military_waste"),
		"The disposal service pays for the real waste once and frees its container")
	_expect(cold.service_action("military_refuel") and cold.select_jump_drive(Ship.DRIVE_STANDARD)
		and cold.ship.active_jump_fuel() == 100.0 and cold.ship.military_fuel == Ship.MILITARY_CAPACITY,
		"Refilling and switching drive leave the two reserves distinct")


func _test_processor_cycle() -> void:
	var flight := Flight.new()
	flight.credits = 2500
	if not _expect(flight.service_action("surface_processor") and not flight.service_action("surface_processor")
		and flight.market_trade("ice", "buy", 4) and flight.market_trade("grain", "buy", 2)
		and not flight.processor_action("processor_deploy"), "Acquire the module and two recipes in the actual port"):
		return
	Fixture.launch(flight)
	flight.select_target(SITE)
	flight.set_autopilot(true)
	if not _expect(_until(flight, func() -> bool: return flight.landed_site == SITE, 150.0),
		"Reach a physical surface before deploying the processor"):
		return
	if not _expect(flight.processor_action("processor_deploy") and flight.processor_status().working
		and flight.mining.cargo_amount("ice") == 2 and flight.mining.cargo_amount("grain") == 1
		and not flight.processor_action("processor_unload") and not flight.processor_action("processor_retrieve"),
		"Deploying consumes the exact supplies and prevents early output or retrieval"):
		return
	var point: Vector3 = flight.processor_status().point
	var cold := Flight.new()
	if not _expect(Session.save_state(flight.snapshot(), SAVE) == OK and cold.restore(Session.load_state(SAVE))
		and cold.processor_status().working and cold.processor_status().point.is_equal_approx(point),
		"Restore the actual patch and unfinished processing deadline from disk"):
		return
	cold.update(Processor.SECONDS - 2.0, Vector2.ZERO, 0.0, false, false)
	_expect(cold.processor_status().ready == 0 and cold.mining.cargo_amount("medical") == 0,
		"An unfinished recipe cannot mint medicines in the hold")
	if not _expect(cold.dock_action() and not cold.landed, "Leave the detached processor behind while lifting"):
		return
	_open_space(cold)
	if not _expect(_jump(cold, VELAR) and not cold.processor_status().same_system
		and cold.processor_status().ready == Processor.OUTPUT and not cold.processor_action("processor_unload")
		and cold.processor_action("processor_route") and cold.jump_target == HOME,
		"The remote cycle completes during elapsed transit and plots a genuine return route"):
		return
	_open_space(cold)
	if not _expect(_jump(cold, HOME) and cold.processor_action("processor_route") and cold.processor_status().navigating
		and _until(cold, func() -> bool: return cold.landed_site == SITE, 155.0)
		and cold.processor_status().near, "An autopilot return targets the exact deployed patch"):
		return
	var free := cold.mining.free_capacity()
	cold.mining.insert_cargo("ore", free)
	_expect(not cold.processor_action("processor_unload") and cold.processor_status().ready == Processor.OUTPUT
		and not cold.processor_action("processor_retrieve") and cold.mining.remove_cargo("ore", free),
		"A full shared hold cannot steal or discard the buffered batch")
	_expect(cold.processor_action("processor_unload") and cold.mining.cargo_amount("medical") == Processor.OUTPUT
		and not cold.processor_action("processor_unload") and cold.processor_action("processor_feed"),
		"The first batch transfers once, then a second independently funded batch can start")
	_expect(_until(cold, func() -> bool: return cold.processor_status().ready == Processor.OUTPUT, Processor.SECONDS + 1.0)
		and cold.processor_action("processor_unload") and cold.processor_action("processor_retrieve")
		and cold.mining.cargo_amount("medical") == 2 * Processor.OUTPUT and not cold.processor_status().active
		and cold.mining.cargo_amount("ice") == 0 and cold.mining.cargo_amount("grain") == 0,
		"The second batch consumes its own inputs and the empty module is physically recoverable")


func _test_controls() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1544, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := Main.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game._audio.set_level(0)
	await process_frame
	game.flight.credits = 2200
	_tap(viewport, game._hud._actions["services"])
	await process_frame
	var services: Node = game._services
	_tap(viewport, services._mining_toggle)
	await process_frame
	_expect(services._action_buttons["surface_processor"].is_visible_in_tree()
		and not services._action_buttons["surface_processor"].disabled, "The physical module is purchasable in equipment")
	_tap(viewport, services._action_buttons["surface_processor"])
	_tap(viewport, services._equipment_tabs[Ports.EquipmentPage.MILITARY])
	await process_frame
	_tap(viewport, services._action_buttons["military_drive"])
	await process_frame
	_tap(viewport, services._action_buttons["military_refuel"])
	_tap(viewport, services._military_select)
	_expect(game.flight.processor_status().installed and game.flight.ship.drive_kind == Ship.DRIVE_MILITARY
		and game.flight.ship.military_fuel > 0.0 and services._military_summary.text.contains("Топливо"),
		"Ordinary touch controls purchase the laboratory, fit/refuel the drive and select it")
	viewport.queue_free()
	await process_frame


func _test_environment() -> void:
	var flight := Flight.new()
	Fixture.launch(flight)
	var giant := Catalog.GAS_GIANT_ID
	flight.select_target(giant)
	var radial := Vector3.RIGHT * (float(Catalog.site(giant).radius) + 50.0)
	flight.position = flight.target_position(giant) + radial
	var orbit := flight.target_velocity(giant)
	flight.velocity = orbit
	var air := Atmosphere.sample(flight, flight.position, flight.velocity)
	var drag := Atmosphere.drag_at_epoch(HOME, flight.position, orbit, flight.orbit_time, 1.0)
	var local := Atmosphere.drag(orbit, air.drift, air.density, 1.0)
	_expect(air.inside and float(air.relative_speed) > 1.0 and drag.is_equal_approx(local)
		and (drag - orbit).dot(Vector3(air.drift) - orbit) > 0.0,
		"Rotating cloud belts drag both the live ship and the route forecast toward the same moving air")
	flight.velocity = air.drift
	_expect(flight.scoop_status().ok and float(flight.scoop_status().relative_speed) < 0.0001,
		"Co-moving with the cloud belt removes airspeed from the skimmer's entry constraint")
	flight.set_flight_assist(false)
	flight.position = flight.target_position(Catalog.STAR_ID) + Vector3.UP * 700.0
	flight.velocity = Vector3.RIGHT * 19.0
	var delta := Fixture.STEP
	var start := flight.position
	var epoch := flight.orbit_time
	var half := delta * 0.5
	var coasting := flight.velocity + Dynamics.acceleration_at_epoch(HOME, start, epoch) * half
	var next := start + coasting * delta
	var finish := coasting + Dynamics.acceleration_at_epoch(HOME, next, epoch + delta) * half
	flight.update(delta, Vector2.ZERO, 0.0, false, false)
	_expect(flight.position.is_equal_approx(next) and flight.velocity.is_equal_approx(finish),
		"The inertial step uses both the previous and new orbital gravitational fields")


func _jump(flight: Flight, destination: int) -> bool:
	return flight.plan_jump(destination) and flight.start_jump() \
		and _until(flight, func() -> bool: return flight.system_id == destination, 4.0)


func _open_space(flight: Flight) -> void:
	flight.position = OPEN
	flight.velocity = Vector3.ZERO
	flight.set_autopilot(false)


func _until(flight: Flight, done: Callable, seconds: float) -> bool:
	for _step in range(ceili(seconds / Fixture.STEP)):
		if done.call():
			return true
		flight.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
	return done.call()


func _tap(viewport: SubViewport, button: Button) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 5
		event.pressed = pressed
		event.position = button.get_global_rect().get_center()
		viewport.push_input(event, true)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures += 1
		printerr(description)
	return condition
