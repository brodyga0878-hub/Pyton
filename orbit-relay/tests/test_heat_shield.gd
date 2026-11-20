extends SceneTree

const Fixture = preload("res://tests/flight_fixture.gd")

const Flight := preload("res://scripts/flight_sim.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Terrain := preload("res://scripts/surface_terrain.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const OrbitRelay := preload("res://main.tscn")
const PLANET := Catalog.TERRACE_ID
const COST := 340
const SERVICE := "heat_shield"
const STEP := 1.0 / 60.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_purchase()
	_test_entry_pass()
	_test_other_damage()
	_test_migration()
	await _test_touch_purchase()
	print("Heat shield integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_purchase() -> void:
	var flight := Flight.new()
	for balance: int in [0, COST - 1]:
		flight.credits = balance
		var before := flight.snapshot()
		var offer := flight.service_offer(SERVICE)
		_expect(offer.cost == COST and not offer.allowed and not offer.installed
			and not flight.service_action(SERVICE) and flight.snapshot() == before,
			"An unaffordable quote does not change credits, equipment, fuel or ship condition")
	flight.credits = COST
	flight.ship.hull = 81.25
	flight.ship.fuel = 57.5
	flight.entry_heat = 43.25
	flight.star_heat = 24.0
	var expected := flight.snapshot()
	expected.credits = 0
	expected.ship.heat_shield = true
	_expect(flight.service_offer(SERVICE).allowed and flight.service_action(SERVICE)
		and flight.snapshot() == expected and is_equal_approx(flight.ship.entry_heat_factor(), 0.52),
		"The port installs the permanent shield once for 340 credits while retaining existing heat and hull damage")
	flight.credits = COST * 2
	var once := flight.snapshot()
	_expect(flight.service_offer(SERVICE).installed and not flight.service_offer(SERVICE).allowed
		and not flight.service_action(SERVICE) and flight.snapshot() == once,
		"Even a sufficient balance cannot purchase the installed equipment twice")
	var airborne := Flight.new()
	airborne.credits = COST
	Fixture.launch(airborne)
	var airborne_state := airborne.snapshot()
	_expect(not airborne.service_offer(SERVICE).allowed and not airborne.service_action(SERVICE)
		and airborne.snapshot() == airborne_state, "An airborne customer cannot buy port equipment")


func _test_entry_pass() -> void:
	var ordinary := _entry(_ship(false))
	var protected := _entry(_ship(true))
	var normal_peak := ordinary.entry_heat
	var shielded_peak := protected.entry_heat
	var strongest_speed := ordinary.speed_relative_to(PLANET)
	var fuel := ordinary.ship.fuel
	for _frame in range(roundi(1.4 / STEP)):
		_tick(ordinary)
		_tick(protected)
		normal_peak = maxf(normal_peak, ordinary.entry_heat)
		shielded_peak = maxf(shielded_peak, protected.entry_heat)
	_expect(normal_peak > 85.0 and shielded_peak < 85.0 and normal_peak - shielded_peak > 5.0
		and ordinary.ship.hull < 100.0 and protected.ship.hull == 100.0,
		"A matched hot atmosphere pass heats and damages the ordinary hull while the protected ship stays intact")
	_expect(ordinary.speed_relative_to(PLANET) < strongest_speed - 2.0 and ordinary.ship.fuel < fuel
		and protected.ship.fuel == ordinary.ship.fuel and protected.position.distance_to(ordinary.position) < 0.004
		and protected.velocity.distance_to(ordinary.velocity) < 0.004,
		"Identically powered ships experience the same atmospheric braking, fuel burn and position changes")
	_expect(protected.star_heat == ordinary.star_heat and protected.entry_heat < ordinary.entry_heat,
		"The shield changes only the entry-heating channel after the passage")


func _test_other_damage() -> void:
	var ordinary := _ship(false)
	var protected := _ship(true)
	var star := Catalog.STAR_ID
	for flight: Flight in [ordinary, protected]:
		Fixture.launch(flight)
		flight.position = flight.target_position(star) + Vector3.BACK * 251.0
		flight.velocity = Vector3.ZERO
		_tick(flight, 13.0)
	_expect(ordinary.star_heat > 85.0 and ordinary.ship.hull < 100.0 and protected.entry_heat == 0.0
		and is_equal_approx(protected.star_heat, ordinary.star_heat)
		and is_equal_approx(protected.ship.hull, ordinary.ship.hull),
		"The atmospheric equipment gives no immunity to stellar heating or its hull damage")
	ordinary = _ship(false)
	protected = _ship(true)
	for flight: Flight in [ordinary, protected]:
		Fixture.launch(flight)
		flight.select_target(2)
		flight.set_flight_assist(false)
		flight.position = flight.target_position(2) + Terrain.contact(2, Vector3.BACK) + Vector3.BACK * 5.0
		flight.velocity = flight.target_velocity(2) + Vector3.FORWARD * 27.0
		_tick(flight, 0.25)
	_expect(ordinary.ship.hull < 100.0 and is_equal_approx(protected.ship.hull, ordinary.ship.hull)
		and protected.entry_heat == 0.0, "A collision still applies identical damage with the shield installed")


func _test_migration() -> void:
	var flight := _entry(_ship(true))
	flight.credits = 551
	flight.star_heat = 12.25
	var saved := _json(flight.snapshot())
	var reopened := Flight.new()
	if not _expect(saved.schema == Flight.SAVE_SCHEMA and reopened.restore(saved) and reopened.ship.heat_shield
		and is_equal_approx(reopened.entry_heat, flight.entry_heat) and is_equal_approx(reopened.star_heat, 12.25)
		and reopened.velocity.distance_to(flight.velocity) < 0.001,
		"The new format reloads the installed shield and both saved temperatures without dropping momentum"):
		return
	var before := reopened.snapshot()
	for invalid: Variant in [1, "true", null]:
		var corrupt := saved.duplicate(true)
		corrupt.ship.heat_shield = invalid
		_expect(not reopened.restore(corrupt) and reopened.snapshot() == before,
			"A malformed equipment flag is rejected without mutating the restored flight")
	var previous := saved.duplicate(true)
	previous.schema = 14
	previous.ship.erase("mining_laser")
	previous.ship.erase("fragment_collector")
	previous.ship.erase("hydrogen_scoop")
	previous.ship.erase("fuel_pump")
	previous.ship.erase("pump_mode")
	previous.ship.erase("hull_id")
	previous.ship.erase("jump_fuel")
	previous.mining.cargo.erase("hydrogen")
	previous.mining.reserves.resize(Catalog.PRE_GAS_DESTINATION_COUNT)
	for stocks: Dictionary in previous.market.values():
		stocks.erase("hydrogen")
	previous.ship.erase("heat_shield")
	_expect(reopened.restore(previous) and not reopened.ship.heat_shield and reopened.ship.entry_heat_factor() == 1.0
		and reopened.credits == 551 and reopened.entry_heat == flight.entry_heat and is_equal_approx(reopened.star_heat, 12.25),
		"An authentic schema-14 payload preserves old heat and progress and starts without the new shield")


func _test_touch_purchase() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := OrbitRelay.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = Flight.new()
	game.flight.credits = COST
	game._update_display(0.0)
	await process_frame
	_tap(viewport, game._hud._actions["services"], "Open the actual port service console by touch")
	await process_frame
	var button: Button = game._services._action_buttons["heat_shield"]
	_tap(viewport, button, "Install the heat shield through the service button")
	await process_frame
	_expect(game.flight.ship.heat_shield and game.flight.credits == 0 and button.disabled
		and SessionIO.load_state().ship.get("heat_shield", false),
		"The service marks the shield installed and saves the purchase immediately")
	_tap(viewport, game._services._close_button, "Return from the service console")
	await process_frame
	var flight: Flight = game.flight
	_entry(flight)
	game._update_display(0.0)
	await process_frame
	_expect(game._hud._entry_readout.is_visible_in_tree() and "Теплозащита" in game._hud._entry_readout.text
		and "48%" in game._hud._entry_readout.text and flight.atmosphere_status().shielded,
		"The shield purchased by touch appears on the actual atmospheric HUD")
	viewport.queue_free()
	await process_frame


func _ship(protected: bool) -> Flight:
	var flight := Flight.new()
	if protected:
		flight.credits = COST
		_expect(flight.service_action(SERVICE), "Install an actual ship shield before launching the test scenario")
	return flight


func _entry(flight: Flight) -> Flight:
	var current := flight.snapshot()
	var port: int = Catalog.system(Catalog.VELAR_SYSTEM).arrival_port
	var dock := flight.docking_position(port)
	current.merge({"system_id": Catalog.VELAR_SYSTEM, "docked": port, "target": port,
		"position": [dock.x, dock.y, dock.z]}, true)
	_expect(flight.restore(current) and Fixture.launch(flight) and flight.select_target(PLANET) and flight.set_flight_assist(false),
		"Launch a live inertial ship for an equivalent atmospheric pass")
	var stand_off := float(Catalog.site(PLANET).radius) * Terrain.MAX_RADIUS_FACTOR + Terrain.CONTACT_CLEARANCE + 4.0
	flight.position = flight.target_position(PLANET) + Vector3.RIGHT * stand_off
	flight.velocity = flight.target_velocity(PLANET) + Vector3.UP * 196.0
	flight.pitch = PI * 0.5
	flight.change_throttle(0.12)
	flight.entry_heat = 72.0
	return flight


func _tick(flight: Flight, delta: float = STEP) -> void:
	flight.update(delta, Vector2.ZERO, 0.0, false, false)


func _json(value: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value, "", true, true)) as Dictionary


func _tap(viewport: SubViewport, button: Button, description: String) -> void:
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, description):
		return
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 9
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		viewport.push_input(event, true)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
