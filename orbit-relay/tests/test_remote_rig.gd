extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Terrain := preload("res://scripts/surface_terrain.gd")
const Mining := preload("res://scripts/mining_rig.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const HOME := Catalog.HOME_SYSTEM
const REGION := Catalog.AUTHORED_SYSTEM_COUNT
const SITE := Catalog.AUTHORED_DESTINATION_COUNT + 1
const STEP := Fixture.STEP
const SAVE_PATH := "user://remote-rig-test.json"

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_remote_operation()
	print("Remote mining integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_remote_operation() -> void:
	var flight := Flight.new()
	flight.credits = 3000
	_expect(not flight.remote_rig_status().active and not flight.remote_rig_status().can_deploy
		and not flight.leave_remote_rig() and not flight.unload_remote_rig() and not flight.retrieve_remote_rig(),
		"Parked in a station without an installation, the ship cannot act on a remote drill")
	if not _expect(flight.scan_galaxy() and flight.plan_jump(REGION) and Fixture.depart(flight) and _jump(flight, REGION, 0),
		"Reach the generated mining system through a real dock departure and jump"):
		return
	var direction := _choose_offpad_patch(flight)
	if not _expect(direction != Vector3.ZERO and _land_offpad(flight, direction)
		and flight.landed_site == SITE and flight.landed_offpad(), "Land on an actual safe off-pad point of the rotating planet"):
		return
	_test_resumes_after_full_buffer(flight.snapshot())
	var prepared := flight.snapshot()
	prepared.mining.reserves[SITE] = 48
	if not _expect(flight.restore(prepared) and flight.remote_rig_status().can_deploy and flight.leave_remote_rig(),
		"Install the unattended drill on a previously worked deposit with 48 units left"):
		return
	var initial := flight.remote_rig_status()
	var deposit := flight.surface_deposit()
	_expect(initial.active and initial.same_system and initial.near and initial.capacity == 48 and initial.stored == 0
		and initial.reserve == 48 and initial.working and initial.remaining > 2.0
		and initial.direction.distance_to(direction) < 0.001 and initial.point.distance_to(deposit.origin) < 0.002,
		"The installation is tied to the actual rotating deposit and starts empty")
	_expect(not flight.leave_remote_rig() and not flight.mine_action() and not flight.unload_remote_rig()
		and flight.mining.phase == Mining.STOWED,
		"The detached installation cannot be deployed again or used as a second standard mining module")
	_tick(flight, float(initial.remaining) - 0.15)
	_expect(flight.remote_rig_status().stored == 0 and flight.mining.reserve_at(SITE) == 48,
		"Before the first drilling interval, no cargo is created and no reserve is consumed")
	_tick(flight, 0.25)
	_expect(flight.remote_rig_status().stored == Mining.BATCH and flight.mining.reserve_at(SITE) == 48 - Mining.BATCH
		and flight.mining.ore_hold == 0, "The first complete batch reduces the shared reserve and goes into the installation")

	var home := _leave_site_and_save_away(flight)
	if home == null:
		return
	if not _expect(_dock_at(home, 0), "Return to the real Home port with the drill still working elsewhere"):
		return
	var elapsed_before := home.orbit_time
	_tick(home, 65.0)
	var full := home.remote_rig_status()
	_expect(home.orbit_time > elapsed_before and full.active and not full.same_system and not full.near
		and full.stored == 48 and full.reserve == 0 and not full.working and home.mining.ore_hold == 0,
		"The game clock completes all remaining batches in another system without remotely filling the ship")
	if not _expect(home.service_action("jump_refuel") and home.track_remote_rig() and home.planned_route().goal == REGION
		and Fixture.depart(home) and _jump(home, REGION, 0), "Tracking from another system plots a real interstellar return route"):
		return
	if not _expect(_land_marked(home), "Normal autopilot can still land at the marked pad on the same planet"):
		return
	var elsewhere := home.remote_rig_status()
	_expect(elsewhere.same_system and not elsewhere.near and not elsewhere.can_unload and not elsewhere.can_retrieve
		and not home.unload_remote_rig() and not home.retrieve_remote_rig() and not home.mine_action(),
		"The other landing patch cannot manipulate a rig left beyond physical reach")
	if not _expect(home.dock_action() and _land_at_rig(home, direction),
		"The drill route follows the orbiting and rotating planet to the stored off-pad point (%s)" % home.status_message):
		return
	_test_unload_and_retrieve(home, direction)


func _test_resumes_after_full_buffer(checkpoint: Dictionary) -> void:
	var flight := Flight.new()
	if not _expect(flight.restore(checkpoint) and flight.leave_remote_rig(), "Install a separate drill on an undepleted copy of the site"):
		return
	_tick(flight, 95.0)
	var full := flight.remote_rig_status()
	if not _expect(full.stored == 48 and full.reserve > Mining.BATCH and not full.working
		and flight.unload_remote_rig(), "No resource is wasted when the installation fills before its deposit is exhausted"):
		return
	var resumed := flight.remote_rig_status()
	if not _expect(resumed.working and resumed.remaining > 0.5 and resumed.stored < 48
		and resumed.reserve == full.reserve and flight.dock_action(), "Making space schedules a fresh batch and does not extract instantly"):
		return
	_tick(flight, float(resumed.remaining) - 0.2)
	_expect(flight.remote_rig_status().stored == resumed.stored, "No extra batch appears before the resumed interval ends")
	_tick(flight, 0.3)
	_expect(flight.remote_rig_status().stored == int(resumed.stored) + Mining.BATCH
		and flight.remote_rig_status().reserve == int(full.reserve) - Mining.BATCH,
		"A new batch is mined into the resumed installation even after an actual lift-off")


func _leave_site_and_save_away(flight: Flight) -> Flight:
	if not _expect(flight.dock_action() and not flight.landed and flight.remote_rig_status().active, "Lift off while keeping the unattended drill installed"):
		return null
	_expect(not flight.unload_remote_rig() and not flight.retrieve_remote_rig(), "The drill cannot be accessed by an airborne ship")
	var local := flight.remote_rig_status()
	if not _expect(flight.plan_jump(HOME) and _jump(flight, HOME, SITE), "Leave the installation behind across a real interstellar jump"):
		return null
	var remote := flight.remote_rig_status()
	if not _expect(remote.active and not remote.same_system and not remote.near and remote.system == REGION and remote.point == Vector3.ZERO
		and remote.stored > local.stored and remote.stored + remote.reserve == local.stored + local.reserve
		and remote.working == (remote.reserve > 0 and remote.stored < remote.capacity)
		and not remote.can_unload and not remote.can_retrieve and SessionIO.save_state(flight.snapshot(), SAVE_PATH) == OK,
		"Mining progresses over the calendar jump without duplicating stock, and the distant drill remains inaccessible and saveable"):
		return null
	var cold := Flight.new()
	if not _expect(cold.restore(SessionIO.load_state(SAVE_PATH)), "Reload the active drill while elsewhere"):
		return null
	var after := cold.remote_rig_status()
	_expect(after.active and after.stored == remote.stored and after.reserve == remote.reserve and after.site == SITE
		and after.direction.distance_to(remote.direction) < 0.001
		and absf(float(after.remaining) - float(remote.remaining)) < 0.000001,
		"Restart preserves the distant rig, remaining game time and actual local patch")
	return cold


func _test_unload_and_retrieve(flight: Flight, direction: Vector3) -> void:
	var resource: String = Catalog.site(SITE).resource
	var capacity := flight.mining.free_capacity()
	var status := flight.remote_rig_status()
	var point := flight.target_position(SITE) + Terrain.spin_basis(SITE, flight.orbit_time) * Terrain.deposit(SITE, direction).origin
	_expect(status.near and status.can_unload and not status.can_retrieve and status.point.distance_to(point) < 0.002
		and not flight.retrieve_remote_rig(), "Back at the installation, nonempty storage requires unloading before retrieval")
	if not _expect(capacity > 0 and capacity < 48 and flight.unload_remote_rig()
		and flight.mining.cargo_amount(resource) == capacity and flight.remote_rig_status().stored == 48 - capacity
		and flight.remote_rig_status().active, "Unload only what fits in the real hold and leave the rest in the installation"):
		return
	_expect(not flight.unload_remote_rig() and not flight.retrieve_remote_rig() and flight.mining.reserve_at(SITE) == 0,
		"A full hold or stored remainder prevents repetition and the depleted deposit does not respawn")
	_test_reject_invalid_save(flight)
	if not _expect(flight.dock_action() and flight.plan_jump(HOME) and _jump(flight, HOME, SITE) and _dock_at(flight, 0),
		"Physically carry the first load to a trade port while leaving the remainder in place"):
		return
	if not _expect(flight.market_trade(resource, "sell", capacity) and flight.mining.ore_hold == 0
		and flight.service_action("jump_refuel") and flight.track_remote_rig() and Fixture.depart(flight) and _jump(flight, REGION, 0),
		"Sell the first load, refuel and return for the remaining physical reserve"):
		return
	if not _expect(_land_at_rig(flight, direction), "Return to the same off-pad patch after another real pair of jumps (%s)" % flight.status_message):
		return
	if not _expect(flight.unload_remote_rig() and flight.mining.cargo_amount(resource) == 48 - capacity
		and flight.remote_rig_status().stored == 0 and flight.remote_rig_status().can_retrieve,
		"The second real unload accounts for the rest exactly once and makes the empty drill retrievable"):
		return
	_expect(flight.retrieve_remote_rig() and not flight.remote_rig_status().active and not flight.retrieve_remote_rig()
		and not flight.track_remote_rig() and flight.mining.reserve_at(SITE) == 0 and flight.mining.cargo_amount(resource) == 48 - capacity,
		"Retrieve the empty drill exactly once without altering the remaining hold or depleted reserve")


func _test_reject_invalid_save(flight: Flight) -> void:
	var invalid := flight.snapshot()
	invalid.remote_rig.direction = [0.0, 0.0, 0.0]
	_expect(not Flight.new().restore(invalid), "The current save cannot replace a functioning rig's patch with an invalid ray")
	invalid = flight.snapshot()
	invalid.remote_rig.stored = 49
	_expect(not Flight.new().restore(invalid), "The current save cannot restore more than the installation's physical capacity")


func _choose_offpad_patch(flight: Flight) -> Vector3:
	var spin := Terrain.spin_basis(SITE, flight.orbit_time)
	for example: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3(1.0, 0.2, -0.4), Vector3(0.3, 0.4, -0.8)]:
		var direction := example.normalized()
		var normal := spin * Terrain.normal(SITE, direction)
		if Terrain.landable(SITE, direction) and absf(normal.y) < 0.72:
			return direction
	return Vector3.ZERO


func _land_offpad(flight: Flight, direction: Vector3) -> bool:
	if not flight.select_target(SITE):
		return false
	var spin := Terrain.spin_basis(SITE, flight.orbit_time)
	var center := flight.target_position(SITE)
	var ground := center + spin * Terrain.point(SITE, direction)
	var aim := -(spin * Terrain.normal(SITE, direction))
	flight.position = center + spin * (Terrain.contact(SITE, direction) + direction * 3.0)
	flight.velocity = flight.surface_velocity(SITE, ground)
	flight.yaw = atan2(-aim.x, -aim.z)
	flight.pitch = asin(clampf(aim.y, -1.0, 1.0))
	flight.gear_deployed = true
	flight.gear_extension = 1.0
	return flight.dock_action()


func _land_marked(flight: Flight) -> bool:
	if not flight.select_target(SITE):
		return false
	flight.set_autopilot(true)
	return _advance(flight, func() -> bool: return flight.landed_site == SITE, 180.0) and not flight.landed_offpad()


func _land_at_rig(flight: Flight, original: Vector3) -> bool:
	var before := flight.position
	return flight.track_remote_rig() and flight.autopilot and flight.position == before \
		and _advance(flight, func() -> bool: return flight.landed_site == SITE, 200.0) \
		and flight.landed_offpad() and flight.landing_direction.distance_to(original) < 0.055 and flight.remote_rig_status().near


func _dock_at(flight: Flight, port: int) -> bool:
	if not flight.select_target(port):
		return false
	flight.set_autopilot(true)
	return _advance(flight, func() -> bool: return flight.docked == port, 140.0)


func _jump(flight: Flight, destination: int, nearby: int) -> bool:
	var outward := (flight.position - flight.target_position(nearby)).normalized()
	flight.yaw = atan2(-outward.x, -outward.z)
	flight.pitch = asin(clampf(outward.y, -1.0, 1.0))
	flight.change_throttle(0.18)
	return _advance(flight, func() -> bool: return flight.jump_status(destination).ok, 25.0) \
		and flight.start_jump() and _advance(flight, func() -> bool: return flight.system_id == destination, 4.0)


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
