extends SceneTree

const Flight = preload("res://scripts/flight_sim.gd")
const Catalog = preload("res://scripts/sector_catalog.gd")
const Patrol = preload("res://scripts/patrol_encounter.gd")
const OrbitRelay = preload("res://main.tscn")
const STEP := 1.0 / 60.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_traffic()
	_test_third_system()
	_test_previous_economy_save()
	await _test_galaxy_touch()
	await _test_touch_patrol()
	print("Living galaxy integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_traffic() -> void:
	for system: int in range(Catalog.CORE_SYSTEM_COUNT):
		var arrival: int = Catalog.system(system).arrival_port
		var flight := _at_port(arrival)
		var initial := flight.traffic_contacts()
		var unique := {}
		var traders := 0
		var patrols := 0
		for contact: Dictionary in initial:
			var id: String = contact.id
			_expect(not id.is_empty() and not unique.has(id) and not str(contact.name).is_empty()
				and contact.position.is_finite() and contact.velocity.is_finite(),
				"System %d has a named, uniquely identifiable finite contact" % system)
			unique[id] = contact.position
			if contact.role == "trader":
				traders += 1
			elif contact.role == "patrol":
				patrols += 1
		_expect(traders >= 2 and patrols >= 1 and traders + patrols == initial.size(),
			"System %d has civilian and patrol traffic before accepting a task" % system)
		_expect(flight.traffic_contacts() == initial and not flight.fire_status().ok and not flight.fire_action(),
			"Sampling the same time is deterministic and friendly contacts are not combat targets")
		_expect(flight.dock_action(), "Traffic does not block a normal launch in system %d" % system)
		_step(flight, 12.0)
		var moved := 0
		for contact: Dictionary in flight.traffic_contacts():
			if unique.has(contact.id) and contact.position.distance_to(unique[contact.id]) > 0.1:
				moved += 1
		_expect(moved >= 3 and flight.ship.hull == 100.0 and flight.patrol_status().phase == Patrol.IDLE
			and flight.combat_beams().is_empty(), "Moving traffic does not damage a ship on a routine flight")


func _test_third_system() -> void:
	var fringe := Catalog.FRINGE_SYSTEM
	_expect(Catalog.system(fringe).name == "Кромка" and Catalog.system(fringe).arrival_port == 16
		and Catalog.is_port(17) and Catalog.is_mine_site(18) and Catalog.star_for(fringe) == 19,
		"The frontier system exposes two ports, a solid mining site and a star")
	_expect(Catalog.jump_cost(Catalog.HOME_SYSTEM, Catalog.VELAR_SYSTEM) == 26
		and Catalog.jump_cost(Catalog.VELAR_SYSTEM, fringe) == 19
		and Catalog.jump_cost(fringe, Catalog.HOME_SYSTEM) == 36,
		"The map has symmetric new fares and keeps the previous route fare")
	var flight := _at_port(10)
	if not _expect(_jump_from_dock(flight, fringe), "The actual jump drive reaches Кромка from Велар"):
		return
	_expect(flight.target == 16 and flight.jump_target == -1 and flight.docked < 0,
		"The third system starts airborne at the Рубеж approach")
	_expect(not flight.select_target(10), "The local navigation rejects targets in a different system")
	if not _expect(_fly_to(flight, 16), "The rotating arrival port accepts the local autopilot"):
		return
	flight.credits = 300
	var purchase := flight.market_quote("circuits", "buy", 2)
	_expect(purchase.ok and flight.market_trade("circuits", "buy", 2)
		and flight.market_quote("circuits", "buy", 1).stock == purchase.stock - 2,
		"The market at the frontier arrival port debits its own inventory")
	var reward := flight.contract_reward()
	_expect(reward > 0 and flight.offer_destination() == 17 and flight.contract_action(),
		"The frontier offers a local freight contract using its second port")
	if not _expect(_fly_to(flight, 17) and flight.contract_action(), "Local frontier freight is delivered physically"):
		return
	var sale := flight.market_quote("circuits", "sell", 2)
	_expect(sale.ok and flight.market_trade("circuits", "sell", 2)
		and flight.credits == 300 - purchase.cost + reward + sale.cost and flight.deliveries == 1,
		"The other frontier market pays for the transported goods independently of freight")
	_expect(_jump_from_dock(flight, Catalog.HOME_SYSTEM), "Кромка can jump back to Гелион directly")


func _test_previous_economy_save() -> void:
	# Version 0.40 has exactly five port inventories and sixteen deposit slots.
	var legacy := {
		"schema": 8, "system_id": 1, "jump_target": 0, "docked": 10, "landed_site": -1,
		"target": 11, "planned_target": -1, "landing_direction": [0.0, 0.0, 0.0],
		"position": [0.0, 0.0, -152.0], "velocity": [0.0, 0.0, 0.0], "yaw": 0.0, "pitch": 0.0,
		"roll": 0.0, "elapsed": 0.0, "orbit_time": 0.0, "throttle": 0.0,
		"credits": 836, "deliveries": 4, "contract_stage": 1, "contract_origin": 3,
		"contract_destination": 10, "contract_route_id": "outer_relay", "contract_leg": 1,
		"ship": {"fuel": 70.0, "tank_upgraded": true, "eco_upgraded": true, "hull": 82.5, "cargo_upgraded": true},
		"mining": {"site_id": 2, "phase": 0, "phase_seconds": 0.0, "pending_ore": 0,
			"cargo": {"ore": 5, "crystal": 0, "ice": 0, "circuits": 10, "medical": 9},
			"reserves": [0, 0, 113, 0, 96, 180, 156, 132, 216, 0, 0, 0, 192, 144, 0, 240]},
		"market": {
			"0": {"ore": 45, "crystal": 12, "ice": 56, "circuits": 38, "medical": 13},
			"1": {"ore": 31, "crystal": 38, "ice": 9, "circuits": 15, "medical": 38},
			"3": {"ore": 14, "crystal": 8, "ice": 24, "circuits": 11, "medical": 7},
			"10": {"ore": 18, "crystal": 11, "ice": 47, "circuits": 26, "medical": 46},
			"11": {"ore": 8, "crystal": 32, "ice": 7, "circuits": 8, "medical": 9},
		},
	}
	var flight := Flight.new()
	if not _expect(flight.restore(_round_trip(legacy)), "A literal paid 0.40 economy save migrates"):
		return
	_expect(flight.system_id == Catalog.VELAR_SYSTEM and flight.docked == 10 and flight.jump_target == 0
		and flight.credits == 836 and flight.deliveries == 4 and flight.contract_itinerary().leg == 1
		and flight.contract_destination == 10, "System, jump plan and active courier progress survive the migration")
	_expect(flight.ship.fuel == 70.0 and flight.ship.hull == 82.5 and flight.mining.cargo_capacity == 40
		and flight.mining.cargo_amount("circuits") == 10 and flight.mining.cargo_amount("medical") == 9
		and flight.mining.reserve_at(2) == 113 and flight.market.stock(0, "circuits") == 38,
		"Upgrades, fuel, purchased freight, reserves and existing port stocks are preserved")
	var latest := flight.snapshot()
	_expect(latest.schema == Flight.SAVE_SCHEMA and latest.mining.reserves.size() == Catalog.DESTINATION_COUNT
		and flight.mining.reserve_at(18) == Catalog.site(18).reserve and flight.market.stock(16, "ore") > 0
		and flight.market.stock(17, "ore") > 0 and flight.patrol_status().phase == Patrol.IDLE,
		"The new depot and markets are initialized and previous flights begin with no patrol")
	var invalid := legacy.duplicate(true)
	invalid.jump_target = Catalog.FRINGE_SYSTEM
	_expect(not flight.restore(invalid) and flight.snapshot() == latest,
		"A historical schema cannot encode a jump target that did not yet exist")
	invalid = latest.duplicate(true)
	invalid.patrol.phase = 999
	_expect(not flight.restore(invalid) and flight.snapshot() == latest,
		"A malformed patrol phase is rejected without changing the live save")


func _test_galaxy_touch() -> void:
	var game := _open_scene()
	game.flight = _at_port(10)
	game._update_display(0.0)
	await process_frame
	_tap(game._hud._actions.get("galaxy"), "Open the three-system chart from the dock HUD")
	await process_frame
	var map: Node = game._galaxy
	var button: Button = map._system_buttons.get(Catalog.FRINGE_SYSTEM)
	_tap(button, "Select Кромка through the existing touchscreen chart")
	await process_frame
	_tap(map._plan_button, "Plan the selected frontier route")
	_expect(game.flight.jump_target == Catalog.FRINGE_SYSTEM and map._jump_button.disabled,
		"The frontier route is selected and the existing dock safety lock remains active")
	game.queue_free()
	await process_frame


func _test_touch_patrol() -> void:
	var game := _open_scene()
	game.flight = Flight.new()
	var flight: Flight = game.flight
	game._update_display(0.0)
	await process_frame
	_tap(game._hud._actions.get("patrol"), "Take a patrol at the actual dock HUD")
	_expect(flight.patrol_status().phase == Patrol.OUTBOUND and flight.credits == 0,
		"Accepting a patrol starts an optional mission without paying its reward")
	_expect(not flight.fire_action(), "The accepted assignment does not enable shooting in dock")
	_tap(game._hud._actions.get("dock"), "Launch for the assigned patrol")
	await process_frame
	_tap(game._hud._actions.get("patrol"), "Switch on the guidance to the incident by touch")
	_expect(flight.patrol_course, "The touch command engages actual patrol course assistance")
	for _frame in range(roundi(50.0 / STEP)):
		if flight.patrol_status().phase == Patrol.ENGAGED:
			break
		game._physics_process(STEP)
	if not _expect(flight.patrol_status().phase == Patrol.ENGAGED and not flight.patrol_course
		and not _raider(flight).is_empty(), "Flying to the signal reveals a real hostile contact and disables approach assist"):
		game.queue_free()
		await process_frame
		return
	_expect(not flight.time_status().allowed, "Threat proximity prevents accelerated simulation time")
	var star := flight.target_position(Catalog.star_for(flight.system_id))
	_expect(not flight.combat_line_clear(star + Vector3.BACK * 380.0, star + Vector3.FORWARD * 380.0),
		"A stellar body blocks direct beams instead of allowing shots through it")
	var enemy := _raider(flight)
	_aim(flight, flight.position - enemy.position)
	_expect(not flight.fire_status().ok and not flight.fire_action(), "Facing away from the raider does not damage it")
	var initial_hull: float = flight.ship.hull
	for _frame in range(roundi(5.0 / STEP)):
		game._physics_process(STEP)
		if flight.ship.hull < initial_hull:
			break
	_expect(flight.ship.hull < initial_hull and flight.ship.hull > 0.0,
		"The raider shoots back during an opt-in encounter and damages the actual ship")
	_expect(flight.combat_beams().any(func(beam: Dictionary) -> bool: return beam.hostile),
		"A real hostile hit shows its firing beam")

	game._update_display(0.0)
	await process_frame
	_tap(game._hud._actions.get("patrol"), "Engage the combat aiming assist by touch")
	for _frame in range(roundi(4.0 / STEP)):
		if flight.fire_status().ok:
			break
		game._physics_process(STEP)
	_expect(flight.patrol_course and flight.fire_status().ok, "Combat assist aims the nose at the raider without firing")
	game._update_display(0.0)
	await process_frame
	var enemy_before: float = flight.patrol_status().enemy_hull
	_tap(game._hud._actions.get("fire"), "Fire at the aligned hostile with the flight HUD")
	var enemy_after: float = flight.patrol_status().enemy_hull
	_expect(enemy_after < enemy_before and enemy_after > 0.0 and not flight.combat_beams().is_empty(),
		"The aimed shot reduces hostile hull and produces a visible beam")
	_expect(not flight.fire_action() and flight.patrol_status().enemy_hull == enemy_after,
		"The same frame cannot repeat a successful shot before cooldown")

	_test_retreat(flight.snapshot())
	var resumed := Flight.new()
	if not _expect(resumed.restore(_round_trip(flight.snapshot()))
		and resumed.patrol_status().phase == Patrol.ENGAGED and resumed.patrol_status().enemy_hull == enemy_after
		and is_equal_approx(resumed.ship.hull, flight.ship.hull) and not resumed.patrol_course,
		"Cold restore keeps both damaged hulls and the active encounter without automatically targeting"):
		game.queue_free()
		await process_frame
		return
	game.flight = resumed
	flight = resumed
	for _frame in range(roundi(10.0 / STEP)):
		if flight.patrol_status().phase != Patrol.ENGAGED:
			break
		var hostile := _raider(flight)
		if not hostile.is_empty():
			_aim(flight, hostile.position - flight.position)
			if flight.fire_status().ok:
				flight.fire_action()
		game._physics_process(STEP)
	if not _expect(flight.patrol_status().phase == Patrol.RETURN and flight.credits == 0
		and _raider(flight).is_empty(), "Defeating the hostile opens the return phase without crediting a premature payout"):
		game.queue_free()
		await process_frame
		return
	game._update_display(0.0)
	await process_frame
	_tap(game._hud._actions.get("patrol"), "Use the patrol command to return to the issuing port")
	_expect(flight.target == 0 and flight.autopilot, "Return assistance selects the original port and normal docking autopilot")
	for _frame in range(roundi(90.0 / STEP)):
		if not flight.autopilot:
			break
		game._physics_process(STEP)
	game._update_display(0.0)
	await process_frame
	if _expect(flight.docked == 0, "The victorious ship can dock normally at the commissioning port"):
		_tap(game._hud._actions.get("patrol"), "Report the patrol result by touch")
		var paid: int = flight.credits
		_expect(paid > 0 and flight.patrol_status().phase == Patrol.COMPLETE, "The signed report grants one real bounty")
		game.queue_free()
		await process_frame
		game = _open_scene()
		flight = game.flight
		_expect(flight.patrol_status().phase == Patrol.COMPLETE and flight.credits == paid,
			"Completing the report saves the reward and mission result")
		flight.patrol_action()
		_expect(flight.credits == paid, "A report after reload cannot pay the same bounty again")
	game.queue_free()
	await process_frame


func _test_retreat(active: Dictionary) -> void:
	var flight := Flight.new()
	if not _expect(flight.restore(_round_trip(active)), "Copy the active encounter for a retreat check"):
		return
	var hostile_hull: float = flight.patrol_status().enemy_hull
	var own_hull: float = flight.ship.hull
	flight.position = flight.patrol.signal_position(flight) + Vector3.BACK * (Patrol.RETREAT_RANGE + 40.0)
	flight.velocity = Vector3.ZERO
	_step(flight, 0.5)
	_expect(flight.patrol_status().phase == Patrol.OUTBOUND and _raider(flight).is_empty()
		and flight.patrol_status().enemy_hull == hostile_hull and is_equal_approx(flight.ship.hull, own_hull),
		"Leaving the encounter range stops the attack and retains progress without a bounty")
	flight.position = flight.patrol.signal_position(flight) + Vector3.BACK * 40.0
	_step(flight, STEP)
	_expect(flight.patrol_status().phase == Patrol.ENGAGED and flight.patrol_status().enemy_hull == hostile_hull,
		"Approaching the same signal can resume a partially completed fight")


func _at_port(port: int) -> Flight:
	var flight := Flight.new()
	var state := flight.snapshot()
	var contact := flight.docking_position(port)
	state.position = [contact.x, contact.y, contact.z]
	state.system_id = Catalog.system_of_site(port)
	state.docked = port
	state.target = port
	_expect(flight.restore(state), "Initialize a physically docked ship at port %d" % port)
	return flight


func _jump_from_dock(flight: Flight, system: int) -> bool:
	if not flight.dock_action() or not flight.plan_jump(system):
		return false
	flight.change_throttle(0.18)
	for _frame in range(roundi(12.0 / STEP)):
		if flight.jump_status(system).ok:
			break
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	var before: float = flight.ship.fuel
	var fare: int = Catalog.jump_cost(flight.system_id, system)
	if not flight.start_jump():
		return false
	_step(flight, 3.0)
	return flight.system_id == system and is_equal_approx(flight.ship.fuel, before - fare)


func _fly_to(flight: Flight, port: int) -> bool:
	if not flight.select_target(port) or (flight.docked >= 0 and not flight.dock_action()):
		return false
	flight.set_autopilot(true)
	for _frame in range(roundi(100.0 / STEP)):
		if not flight.autopilot:
			break
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	return flight.docked == port


func _raider(flight: Flight) -> Dictionary:
	for contact: Dictionary in flight.traffic_contacts():
		if contact.role == "raider":
			return contact
	return {}


func _aim(flight: Flight, direction: Vector3) -> void:
	var aim := direction.normalized()
	flight.yaw = atan2(-aim.x, -aim.z)
	flight.pitch = clampf(asin(aim.y), -Flight.MAX_PITCH, Flight.MAX_PITCH)


func _step(flight: Flight, seconds: float) -> void:
	for _frame in range(roundi(seconds / STEP)):
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)


func _open_scene() -> Node:
	var game := OrbitRelay.instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game._update_display(0.0)
	return game


func _tap(button: Button, description: String) -> bool:
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, description):
		return false
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 7
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event, true)
	return true


func _round_trip(state: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(state))


func _expect(passed: bool, description: String) -> bool:
	_checks += 1
	if not passed:
		_failures.append(description)
	return passed
