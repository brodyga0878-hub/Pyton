extends SceneTree

const Flight = preload("res://scripts/flight_sim.gd")
const MiningRig = preload("res://scripts/mining_rig.gd")
const OrbitRelay = preload("res://main.tscn")
const SessionIO = preload("res://scripts/session_io.gd")
const STEP := 1.0 / 60.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_legacy_save()
	_test_manual_approach()
	await _test_mining_route()
	print("Asteroid integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_legacy_save() -> void:
	# The 0.33 layout is fixed independently of the current snapshot writer.
	var legacy_save := {
		"schema": 1,
		"position": [330.0, 65.0, -862.0],
		"velocity": [0.0, 0.0, 0.0],
		"yaw": 0.0, "pitch": 0.0, "roll": 0.0, "elapsed": 4.5, "throttle": 0.0,
		"docked": 1, "target": 1, "credits": 240, "deliveries": 1,
		"contract_stage": 1, "contract_origin": 1, "contract_destination": 0,
	}
	var flight := Flight.new()
	_expect(flight.restore(legacy_save), "A 0.33 save loads into the new flight format")
	_expect(flight.docked == 1 and flight.credits == 240 and flight.deliveries == 1,
		"Legacy save retains its station, balance and delivery counter")
	_expect(flight.contract_stage == 1 and flight.contract_destination == 0,
		"Legacy save retains an active return contract")
	_expect(not flight.landed and flight.mining.phase == MiningRig.STOWED
		and flight.mining.ore_hold == 0,
		"Legacy save starts with an unused mining module")
	var upgraded := flight.snapshot()
	_expect(upgraded.schema == Flight.SAVE_SCHEMA and upgraded.has_all([
		"landed_site", "landing_direction", "mining", "ship", "system_id", "jump_target", "orbit_time",
	]),
		"The next save is serialized in the current format")
	flight.dock_action()
	flight.change_target()
	flight.change_target()
	flight.set_autopilot(true)
	var passed_behind := false
	for _step in range(int(100.0 / STEP)):
		passed_behind = passed_behind or flight.position.z < flight.target_position(Flight.ASTEROID_TARGET).z
		if flight.landed or not flight.autopilot:
			break
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	_expect(passed_behind and flight.landed and flight.position.is_equal_approx(flight.target_contact(Flight.ASTEROID_TARGET)),
		"Departure from Тихий порт travels around the back of the asteroid before landing")
	var old_space_position := legacy_save.duplicate(true)
	old_space_position.docked = -1
	old_space_position.position = [-215.0, -70.0, -415.0]
	_expect(flight.restore(old_space_position) and flight.position.is_equal_approx(Flight.ASTEROID_GATE)
		and not flight.landed and flight.credits == 240 and flight.contract_destination == 0,
		"A legacy ship inside the new asteroid is relocated safely with progress retained")


func _test_manual_approach() -> void:
	var flight := Flight.new()
	flight.dock_action()
	flight.target = Flight.ASTEROID_TARGET
	flight.position = flight.target_contact(Flight.ASTEROID_TARGET) + Vector3(0.0, 0.0, 3.0)
	flight.velocity = flight.target_velocity(Flight.ASTEROID_TARGET) + Vector3(0.0, 0.0, -12.0)
	flight.yaw = 0.0
	flight.gear_extension = 1.0
	flight.gear_deployed = true
	_expect(not flight.dock_action() and not flight.landed, "Landing rejects excessive speed")
	flight.velocity = flight.target_velocity(Flight.ASTEROID_TARGET)
	flight.yaw = PI
	_expect(not flight.dock_action() and not flight.landed, "Landing rejects a ship facing away")
	flight.yaw = 0.0
	flight.position.z += 20.0
	_expect(not flight.dock_action() and not flight.landed, "Landing rejects a position too high above the site")
	flight.position = flight.target_contact(Flight.ASTEROID_TARGET) + Vector3(0.0, 0.0, 3.0)
	flight.velocity = flight.target_velocity(Flight.ASTEROID_TARGET) + Vector3(0.0, 0.0, -2.0)
	_expect(flight.dock_action() and flight.landed and flight.docked == -1,
		"An aligned, slow approach lands on the asteroid instead of at a port")


func _test_mining_route() -> void:
	var game := _open_scene()
	game.flight = Flight.new()
	game._update_display(0.0)
	await process_frame

	_touch(game, "contract")
	await process_frame
	_touch(game, "dock")
	_expect(game.flight.docked == -1 and game.flight.contract_destination == 1,
		"Touch controls launch with a station contract")
	await process_frame
	_touch(game, "target")
	_expect(game.flight.target == Flight.ASTEROID_TARGET,
		"Touch target control selects the asteroid")
	await process_frame
	_touch(game, "autopilot")
	_expect(game.flight.autopilot, "Touch controls engage approach assistance")
	_advance(game, func() -> bool: return game.flight.landed or not game.flight.autopilot, 100.0)
	if not _expect(game.flight.landed, "Autopilot reaches the asteroid: %s" % game.flight.status_message):
		await _close_scene(game)
		return
	var flight: RefCounted = game.flight
	_expect(flight.position.is_equal_approx(flight.target_contact(Flight.ASTEROID_TARGET)) and flight.relative_speed() < 0.001,
		"The landed ship is stationary on the site")
	_expect(not flight.sell_ore_action(), "Ore is sold through a port only")
	game._update_display(0.0)
	await process_frame
	_touch(game, "mine")
	_expect(flight.mining.phase == MiningRig.DEPLOYING, "Touch control deploys the separate module")
	await process_frame
	_touch(game, "dock", false)
	_expect(flight.landed and not flight.dock_action(), "The surface launch interlock holds the ship")
	_advance(game, func() -> bool: return flight.mining.phase == MiningRig.DRILLING, 4.0)
	_expect(flight.mining.phase == MiningRig.DRILLING, "The rig starts drilling after deployment")
	for _step in range(30):
		game._physics_process(STEP)
	var mid_drill: Dictionary = flight.snapshot()
	var stock: int = flight.mining.reserve
	_expect(flight.mining.ore_hold == 0 and flight.mining.pending_ore == 0,
		"Drilling alone does not fill the cargo bay")
	game = await _restart_scene(game)
	flight = game.flight
	var resumed_drill: Dictionary = flight.snapshot()
	_expect(_matches_disk_snapshot(resumed_drill, mid_drill), "Cold load retains mid-drill time, pose and contract")

	var malformed := resumed_drill.duplicate(true)
	malformed.landed_site = -1
	_expect(not flight.restore(malformed) and flight.snapshot() == resumed_drill,
		"An airborne save cannot carry a deployed module, and rejection is atomic")
	malformed = resumed_drill.duplicate(true)
	malformed.mining.phase_seconds = 999.0
	_expect(not flight.restore(malformed) and flight.snapshot() == resumed_drill,
		"An invalid phase timer is rejected before changing the flight")
	_advance(game, func() -> bool: return flight.mining.phase == MiningRig.READY, 15.0)
	_expect(flight.mining.phase == MiningRig.READY and flight.mining.ore_hold == 0
		and flight.mining.pending_ore == MiningRig.BATCH and flight.mining.reserve == stock,
		"Extracted ore remains in the rig until it is retrieved")
	game._update_display(0.0)
	await process_frame
	_touch(game, "mine")
	_expect(flight.mining.phase == MiningRig.RETURNING, "Touch control recalls the rig")
	for _step in range(30):
		game._physics_process(STEP)
	var mid_return: Dictionary = flight.snapshot()
	game = await _restart_scene(game)
	flight = game.flight
	_expect(_matches_disk_snapshot(flight.snapshot(), mid_return), "Cold load restores transit of the module")
	_advance(game, func() -> bool: return flight.mining.phase == MiningRig.STOWED, 4.0)
	_expect(flight.mining.phase == MiningRig.STOWED and flight.mining.ore_hold == MiningRig.BATCH
		and flight.mining.pending_ore == 0 and flight.mining.reserve == stock - MiningRig.BATCH,
		"Completed recovery loads one batch and debits the deposit once")
	for _step in range(120):
		game._physics_process(STEP)
	_expect(flight.mining.ore_hold == MiningRig.BATCH, "After recovery, further ticks do not duplicate ore")
	game._update_display(0.0)
	await process_frame
	_touch(game, "dock")
	_expect(not flight.landed and flight.docked == -1, "The launch control works after recovery")
	_expect(not flight.mine_action() and not flight.sell_ore_action(),
		"An airborne ship cannot deploy or sell the module's cargo")
	_expect(flight.target == 1, "The active port contract selects the onward destination after lift")
	await process_frame
	_touch(game, "autopilot")
	_advance(game, func() -> bool: return flight.docked >= 0 or not flight.autopilot, 110.0)
	if not _expect(flight.docked == 1, "Autopilot returns to port after mining: %s" % flight.status_message):
		await _close_scene(game)
		return
	game._update_display(0.0)
	await process_frame
	var ore_reward: int = flight.market_quote("ore", "sell", MiningRig.BATCH).cost
	_touch(game, "sell_ore")
	_expect(flight.credits == ore_reward and flight.mining.ore_hold == 0, "Touch sale exchanges the batch for credits")
	_expect(not flight.sell_ore_action() and flight.credits == ore_reward,
		"Selling an empty hold cannot credit the same ore again")
	await process_frame
	_touch(game, "contract")
	_expect(flight.credits == ore_reward + 240 and flight.deliveries == 1,
		"Ore sale coexists with completion of the original delivery")
	var saved := SessionIO.load_state()
	var final_load := Flight.new()
	_expect(final_load.restore(saved) and final_load.docked == 1
		and final_load.credits == ore_reward + 240 and final_load.mining.ore_hold == 0,
		"A normal port save retains the sale and delivery")
	await _close_scene(game)


func _open_scene() -> Node:
	var game := OrbitRelay.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	return game


func _restart_scene(game: Node) -> Node:
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await _close_scene(game)
	var resumed := _open_scene()
	await process_frame
	return resumed


func _advance(game: Node, stop: Callable, maximum_seconds: float) -> void:
	for _step in range(int(maximum_seconds / STEP)):
		if stop.call():
			return
		game._physics_process(STEP)


func _touch(game: Node, action: String, enabled := true) -> void:
	var button: Button = game._hud._actions.get(action)
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree(),
		"Touch action %s is visible" % action):
		return
	_expect(button.disabled == (not enabled), "Touch action %s has the correct enabled state" % action)
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 4
		touch.position = button.get_global_rect().get_center()
		touch.pressed = pressed
		root.push_input(touch, true)


func _close_scene(game: Node) -> void:
	game.queue_free()
	await process_frame


func _matches_disk_snapshot(actual: Dictionary, expected: Dictionary) -> bool:
	# The JSON parser can shift a full-precision fuel value by a few ulps.
	if absf(actual.ship.fuel - expected.ship.fuel) > 0.0000000001:
		return false
	var normalized := expected.duplicate(true)
	normalized.ship.fuel = actual.ship.fuel
	return actual == normalized


func _expect(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
	return condition
