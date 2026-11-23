extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Expedition := preload("res://scripts/expedition.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const ShipSystems := preload("res://scripts/ship_systems.gd")
const OrbitRelay := preload("res://main.tscn")
const STEP := 1.0 / 30.0
const SAVE_PATH := "user://frontier_voyage.json"

var _flight := Flight.new()
var _supply_fixture: Dictionary = {}
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_voyage()
	if not _supply_fixture.is_empty():
		await _test_supply_button()
	print("Frontier voyage integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	await create_timer(0.15).timeout
	quit(0 if _failures.is_empty() else 1)


func _voyage() -> void:
	var heather := Catalog.HEATHER_SYSTEM
	var limit := Catalog.LIMIT_SYSTEM
	if not _expect(_flight.credits == 0 and _flight.docked == 0 and _flight.contract_action(),
			"Accept a courier contract from a fresh profile"):
		return
	var sponsor := _flight.contract_destination
	if not _expect(Fixture.depart(_flight) and _dock(sponsor) and _flight.contract_action()
			and _flight.deliveries == 1 and _flight.credits > 0,
			"Fly and deliver the first contract without relocating or funding the ship"):
		return
	if not _expect(_flight.project_action() and _flight.frontier_status().sponsor_port == sponsor
			and _flight.jump_target == heather and _flight.factions.owner(heather) == -1,
			"Accept the first expedition from the port actually reached by the courier"):
		return
	if not _expect(_jump(heather) and _survey() and _jump(Catalog.HOME_SYSTEM) and _dock(sponsor),
			"Reach both survey locations and fly back with the report"):
		return
	var survey_payment := _flight.credits + int(_flight.frontier_status().survey_reward)
	if not _expect(_flight.project_action() and _flight.credits == survey_payment
			and _flight.frontier_status().remaining_needs == {"ore": 10, "circuits": 2, "crystal": 3},
			"The report funds the work and the board lists both construction lots"):
		return
	if not _expect(_buy(_flight.frontier_status().remaining_needs) and _fuel_for(heather) and _jump(heather) and _guide()
			and _flight.project_action() and _flight.frontier_status().build_index == 1,
			"Buy both lots, transport them and unload the first lot using the ordinary market and flight"):
		return
	if not _expect(_missing_supply_route(),
			"An incomplete lot is atomic and there is an explicit trip to its supplier"):
		return
	if not _expect(_reload() and _flight.frontier_status().remaining_needs == {"ore": 4, "crystal": 3},
			"Cold restore the cargo and remaining requirements before commissioning"):
		return
	if not _expect(_reject_overflow() and _flight.project_action() and _flight.station_operational(Catalog.HEATHER_PORT)
			and _flight.factions.owner(heather) == _flight.factions.owner(Catalog.HOME_SYSTEM)
			and _flight.freight.frontier_active(heather),
			"The second lot opens the station, assigns its original faction and starts its freight route"):
		return
	if not _expect(_dock(Catalog.HEATHER_PORT) and _flight.project_action() and _fuel_for(limit, 2)
			and _flight.frontier_status().sponsor_port == Catalog.HEATHER_PORT,
			"Visit the newly opened port and accept the next expedition there"):
		return
	var issuer := int(_flight.frontier_status().sponsor)
	if not _expect(_jump(limit) and _survey() and _jump(heather) and _dock(Catalog.HEATHER_PORT) and _reload(),
			"Survey the second system and cold restore at its reporting port"):
		return
	if not _expect(_wait_for_transfer(heather, issuer) and _flight.frontier_status().sponsor == issuer
			and _flight.frontier_status().sponsor_port == Catalog.HEATHER_PORT and _flight.project_action(),
			"The commissioning contract retains its original issuer after an autonomous change of control"):
		return
	if not _expect(_buy(_flight.frontier_status().remaining_needs) and _fuel_for(limit) and _jump(limit) and _guide()
			and _flight.project_action() and _flight.project_action() and _reload(),
			"Complete both second-system lots and keep their outcome after restart"):
		return
	var settled := _flight.snapshot()
	_expect(_flight.station_operational(Catalog.LIMIT_PORT) and _flight.factions.owner(limit) == issuer
		and _flight.factions.owner(heather) != issuer and _flight.freight.frontier_active(limit)
		and _flight.frontier_status().series_done and not _flight.project_action() and _flight.snapshot() == settled,
		"The second station belongs to the original sponsor and cannot issue a repeated reward")


func _jump(destination: int) -> bool:
	if _flight.jump_target != destination or (_flight.docked >= 0 and not Fixture.depart(_flight)):
		return false
	_flight.change_throttle(0.18)
	for _frame in range(ceili(30.0 / STEP)):
		if _flight.jump_status(destination).ok:
			break
		_tick()
	if not _flight.start_jump():
		printerr(_flight.jump_status(destination).reason)
		return false
	for _frame in range(ceili(4.0 / STEP)):
		_tick()
		if _flight.jump_seconds_left <= 0.0:
			return _flight.system_id == destination
	return false


func _dock(port: int) -> bool:
	if not _flight.select_target(port):
		return false
	_flight.set_autopilot(true)
	for _frame in range(ceili(160.0 / STEP)):
		_tick()
		if not _flight.autopilot:
			return _flight.docked == port
	return false


func _survey() -> bool:
	for _body in range(Expedition.SURVEY_TOTAL):
		if not _guide() or not _flight.project_action():
			return false
	return _flight.frontier_status().phase == Expedition.REPORT


func _guide() -> bool:
	if not _flight.frontier_status().ready and not _flight.project_action():
		return false
	for _frame in range(ceili(140.0 / STEP)):
		if _flight.frontier_status().ready:
			return true
		_tick()
	return false


func _buy(goods: Dictionary) -> bool:
	for good: String in goods:
		if not _flight.market_trade(good, "buy", goods[good]):
			printerr("Could not buy ", good, " at ", _flight.target_name(_flight.docked))
			return false
	return true


func _fuel_for(destination: int, legs := 1) -> bool:
	# Pay for the departure reserve instead of filling both tanks with expedition money.
	var needed: float = _flight.jump_tariff(_flight.system_id, destination) * legs - _flight.ship.jump_fuel
	var canisters := ceili(needed / ShipSystems.HYDROGEN_UNITS_PER_CANISTER)
	return canisters <= 0 or (_flight.market_trade("hydrogen", "buy", canisters) and _flight.fuel_transfer("jump"))


func _reload() -> bool:
	if SessionIO.save_state(_flight.snapshot(), SAVE_PATH) != OK:
		return false
	var restored := Flight.new()
	if SessionIO.load_valid_state(SAVE_PATH, restored.restore) != SessionIO.LoadResult.PRIMARY:
		return false
	_flight = restored
	return true


func _reject_overflow() -> bool:
	var state := _flight.snapshot()
	state.credits = Expedition.MAX_CREDITS
	var full := Flight.new()
	if not full.restore(state):
		return false
	var before := full.snapshot()
	return not full.frontier_status().can_act and not full.project_action() and full.snapshot() == before


func _missing_supply_route() -> bool:
	var clone := Flight.new()
	if not clone.restore(_flight.snapshot()) or not clone.mining.remove_cargo("crystal", 1):
		return false
	var before := clone.snapshot()
	_supply_fixture = before
	return not clone.project_action() and clone.snapshot() == before \
		and clone.frontier_status().can_route_supply and clone.project_supply_route() \
		and clone.planned_route().goal == Catalog.HOME_SYSTEM


func _wait_for_transfer(system: int, former_owner: int) -> bool:
	for _event in range(80):
		if _flight.factions.owner(system) != former_owner:
			return true
		var due := _flight.factions.next_event_time()
		if not is_finite(due):
			return false
		_tick(maxf(STEP, due - _flight.orbit_time + STEP))
	return false


func _tick(delta := STEP) -> void:
	_flight.update(delta, Vector2.ZERO, 0.0, false, false)


func _test_supply_button() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := OrbitRelay.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	if _expect(game.flight.restore(_supply_fixture), "Load a missing-supplies state in the flight scene"):
		game._handle_action("frontier")
		await process_frame
		var board = game._frontier
		var supply: Button = board._supply_route_button
		var cargo_visible := false
		for material: Label in board._materials:
			if material.is_visible_in_tree() and "2 из 3" in material.text:
				cargo_visible = true
		if _expect(board.is_open() and board._project_button.disabled and cargo_visible
				and supply.is_visible_in_tree() and not supply.disabled
				and viewport.get_visible_rect().encloses(supply.get_global_rect()),
				"The touch board shows missing cargo and the supplier action fits at 1280×720"):
			for pressed in [true, false]:
				var event := InputEventScreenTouch.new()
				event.index = 15
				event.position = supply.get_global_rect().get_center()
				event.pressed = pressed
				viewport.push_input(event, true)
			await process_frame
			_expect(not board.is_open() and game.flight.planned_route().goal == Catalog.HOME_SYSTEM,
				"Touching the supplier action closes the board and sets the saved flight route")
	viewport.queue_free()
	await process_frame


func _expect(value: bool, label: String) -> bool:
	_checks += 1
	if not value:
		_failures.append(label + " · " + _flight.status_message)
	return value
