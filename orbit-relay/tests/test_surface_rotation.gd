extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Terrain := preload("res://scripts/surface_terrain.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Rig := preload("res://scripts/mining_rig.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const Main := preload("res://main.tscn")
const HOME := Catalog.HOME_SYSTEM
const DESTINATION := Catalog.AUTHORED_SYSTEM_COUNT
const PLANET := Catalog.AUTHORED_DESTINATION_COUNT + 1
const STEP := Fixture.STEP

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_spin_geometry()
	var flight := _fly_to_marked_pad()
	if flight != null:
		await _test_manual_touch(flight)
	print("Rotating surfaces integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_spin_geometry() -> void:
	var count := 0
	for site in range(Catalog.DESTINATION_COUNT):
		var rate := Terrain.spin_rate(site)
		var rotating := site >= Catalog.AUTHORED_DESTINATION_COUNT and Catalog.is_mine_site(site)
		if not rotating:
			_expect(rate == 0.0 and Terrain.spin_basis(site, 43.0) == Basis.IDENTITY
				and Terrain.spin_velocity(site, Vector3.BACK * 150.0) == Vector3.ZERO,
				"Existing or non-solid site %d keeps its original unrotated terrain API" % site)
			continue
		count += 1
		var start := Terrain.spin_basis(site, 0.0)
		var epoch := 31.0 + site
		var later := Terrain.spin_basis(site, epoch)
		var span := TAU / rate
		_expect(rate > 0.0 and start == Basis.IDENTITY and absf(later.determinant() - 1.0) < 0.0001
			and later.is_equal_approx(Terrain.spin_basis(site, epoch + span)),
			"Site %d rotates periodically from its original epoch-zero orientation" % site)
		var local := Terrain.contact(site, Vector3.BACK)
		var before := Terrain.spin_basis(site, epoch - 0.05) * local
		var after := Terrain.spin_basis(site, epoch + 0.05) * local
		var offset := later * local
		var spin_component := Terrain.spin_velocity(site, offset)
		_expect(spin_component.length() > 0.1 and absf(spin_component.dot(offset)) < 0.002
			and spin_component.distance_to((after - before) / 0.1) < 0.003,
			"Site %d has tangential ground velocity that agrees with numerical position change" % site)
	_expect(count == 38, "All generated solid surfaces, including the binary planet and moon, rotate")


func _fly_to_marked_pad() -> Flight:
	var flight := Flight.new()
	if not _expect(flight.scan_galaxy() and flight.plan_jump(DESTINATION) and Fixture.depart(flight),
		"Discover the generated destination and depart through the normal station corridor"):
		return null
	flight.change_throttle(0.18)
	if not _expect(_advance(flight, func() -> bool: return flight.jump_status(DESTINATION).ok, 25.0)
		and flight.start_jump() and _advance(flight, func() -> bool: return flight.system_id == DESTINATION, 4.0),
		"Charge and perform a real jump to the rotating surface system"):
		return null
	var gate := flight.target_gate(PLANET)
	var center := flight.target_position(PLANET)
	var local_gate := Vector3.BACK * float(Catalog.site(PLANET).gate_offset)
	_expect((gate - center).distance_to(Terrain.spin_basis(PLANET, flight.orbit_time) * local_gate) < 0.002
		and (gate - center).distance_to(local_gate) > 5.0, "The landing gate already follows the planet's rotating meridian")
	if not _expect(flight.select_target(PLANET), "Select the rotating planet as a destination"):
		return null
	var start := flight.position
	flight.set_autopilot(true)
	if not _expect(flight.position == start and _advance(flight, func() -> bool: return not flight.autopilot, 200.0)
		and flight.landed_site == PLANET and not flight.landed_offpad() and flight.ship.hull > 99.0,
		"Autopilot physically intercepts and lands on the moving marked pad (%s)" % flight.status_message):
		return null
	_expect(flight.survey_action(PLANET) and is_equal_approx(float(flight.body_dossier(PLANET).data.spin), Terrain.spin_rate(PLANET)),
		"A surface survey shows the same rotation rate used by flight physics")
	var local_contact := Terrain.contact(PLANET, Vector3.BACK)
	var first := flight.position
	var first_basis := flight.landed_basis()
	var elapsed := 4.0
	flight.update(elapsed, Vector2.ZERO, 0.0, false, false)
	var position_expected := flight.target_position(PLANET) + Terrain.spin_basis(PLANET, flight.orbit_time) * local_contact
	var surface_velocity := flight.surface_velocity(PLANET, flight.position)
	_expect(flight.position.distance_to(position_expected) < 0.002 and flight.position.distance_to(first) > 2.0
		and not first_basis.is_equal_approx(flight.landed_basis()) and flight.velocity.distance_to(surface_velocity) < 0.005,
		"A parked ship follows the actual rotating pad and carries its world-frame velocity")
	var before := flight.position
	var velocity := flight.velocity
	flight.update(0.05, Vector2.ZERO, 0.0, false, false)
	_expect(velocity.distance_to((flight.position - before) / 0.05) < 0.025,
		"The parked ship's reported velocity agrees with a finite difference of its world position")
	_expect(flight.dock_action() and not flight.landed, "The automatic marked landing remains available for manual lift-off")
	return flight


func _test_manual_touch(flight: Flight) -> void:
	if not _expect(flight.select_target(PLANET), "Choose the planet again after the automatic launch changes the destination"):
		return
	var direction := _find_direction(flight, true)
	var steep := _find_direction(flight, false)
	if not _expect(direction != Vector3.ZERO and steep != Vector3.ZERO,
		"The rotating body offers safe and independently steep off-pad terrain"):
		return
	_set_approach(flight, steep)
	var slope_check := flight.surface_status()
	_expect(slope_check.near and not slope_check.slope_ok and slope_check.speed_ok
		and slope_check.height_ok and slope_check.aim_ok and not flight.dock_action(),
		"Correct world-frame alignment and relative speed cannot bypass an unsafe local slope")
	_set_approach(flight, direction)
	var status := flight.surface_status()
	if not _expect(status.near, "The off-pad position is recognized as a surface approach"):
		return
	var drift := flight.surface_velocity(PLANET, status.ground_point)
	var spin := drift - flight.target_velocity(PLANET)
	flight.velocity = drift - spin.normalized() * (Flight.LANDING_SPEED + 0.2)
	_expect(flight.speed_relative_to(PLANET) < Flight.LANDING_SPEED
		and not flight.surface_status().speed_ok and not flight.dock_action(),
		"A ship slow relative to the center cannot land while drifting too fast relative to the rotating terrain")
	flight.velocity = drift
	flight.ship.fuel = 0.0
	if not _expect(flight.surface_status().ok and _set_session(flight), "Matching the chosen patch enables a zero-tank touchdown"):
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := Main.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game._update_display(0.0)
	await process_frame
	flight = game.flight
	_tap(viewport, game._hud._actions["dock"], true, "Land by touching the normal cockpit control")
	await process_frame
	if _expect(flight.landed_site == PLANET and flight.landed_offpad() and flight.landing_direction.dot(direction) > 0.99999,
		"The touch landing records the chosen local coordinates"):
		await _test_mining_and_lift(viewport, game, direction)
	viewport.queue_free()
	await process_frame


func _test_mining_and_lift(viewport: SubViewport, game: Node, direction: Vector3) -> void:
	var flight: Flight = game.flight
	var first_deposit := flight.surface_deposit()
	var resource: String = Catalog.site(PLANET).resource
	var reserve := flight.mining.reserve_at(PLANET)
	game._update_display(0.0)
	await process_frame
	_tap(viewport, game._hud._actions["mine"], true, "Send the drill out using the real touch control")
	if not _expect(_advance(flight, func() -> bool: return flight.mining.phase == Rig.DRILLING, 4.0),
		"The detachable drill reaches the rotating deposit"):
		return
	var local := Terrain.deposit(PLANET, direction)
	var spin := Terrain.spin_basis(PLANET, flight.orbit_time)
	var deposit := flight.surface_deposit()
	var expected_origin := flight.target_position(PLANET) + spin * local.origin
	_expect(deposit.origin.distance_to(expected_origin) < 0.002 and deposit.origin.distance_to(first_deposit.origin) > 1.0
		and deposit.basis.z.dot(spin * local.basis.z) > 0.99999,
		"The deployed drill and deposit follow the same rotated coordinates as the terrain")
	game._update_display(0.0)
	await process_frame
	_tap(viewport, game._hud._actions["dock"], false, "Touch lift-off remains locked while the drill is detached")
	_expect(flight.landed and _set_session(flight), "Persist the exact local patch while a drill run is active")
	var cold := Flight.new()
	if not _expect(cold.restore(SessionIO.load_state()) and cold.landed_site == PLANET and cold.landed_offpad()
		and cold.landing_direction.dot(direction) > 0.99999 and cold.position.distance_to(flight.position) < 0.002
		and cold.velocity.distance_to(flight.velocity) < 0.002 and cold.surface_deposit().origin.distance_to(deposit.origin) < 0.002
		and cold.mining.phase == Rig.DRILLING and cold.ship.fuel == 0.0,
		"Cold restart preserves rotation phase, local coordinates, surface speed and the active rig"):
		return
	var inconsistent := cold.snapshot()
	inconsistent.velocity = [0.0, 0.0, 0.0]
	_expect(not Flight.new().restore(inconsistent), "A current rotated ground save cannot replace the physical velocity with zero")
	game.flight = cold
	if not _expect(_advance(cold, func() -> bool: return cold.mining.phase == Rig.READY, 21.0)
		and cold.mine_action() and _advance(cold, func() -> bool: return cold.mining.phase == Rig.STOWED, 5.0)
		and cold.mining.cargo_amount(resource) == Rig.BATCH and cold.mining.reserve_at(PLANET) == reserve - Rig.BATCH,
		"After restart the drill run completes and reduces the original deposit by exactly one batch"):
		return
	game._update_display(0.0)
	await process_frame
	var ground_velocity := cold.surface_velocity(PLANET, cold.position)
	var world_normal := cold.landed_basis().z
	_tap(viewport, game._hud._actions["dock"], true, "Lift from the rotated off-pad surface by touch with no reaction fuel")
	var departure := cold.velocity - ground_velocity
	_expect(not cold.landed and cold.ship.fuel == 0.0 and departure.dot(world_normal) > 7.0
		and departure.slide(world_normal).length() < 0.12,
		"The emergency lift inherits tangential ground motion and adds only an outward impulse")
	_advance(cold, func() -> bool: return false, 0.6)
	var offset := cold.position - cold.target_position(PLANET)
	var local_offset := Terrain.spin_basis(PLANET, cold.orbit_time).transposed() * offset
	_expect(local_offset.length() > Terrain.radius_at(PLANET, local_offset.normalized()) + 4.4
		and cold.mining.cargo_amount(resource) == Rig.BATCH, "The departed ship clears the rotating terrain carrying its extracted minerals")


func _find_direction(flight: Flight, safe: bool) -> Vector3:
	for index in range(128):
		var y := 2.0 * (float(index) + 0.5) / 128.0 - 1.0
		var ring := sqrt(1.0 - y * y)
		var angle := TAU * fposmod(index * 0.381966, 1.0)
		var direction := Vector3(cos(angle) * ring, y, sin(angle) * ring)
		var spin := Terrain.spin_basis(PLANET, flight.orbit_time)
		var world_normal := spin * Terrain.normal(PLANET, direction)
		var drift := Terrain.spin_velocity(PLANET, spin * Terrain.point(PLANET, direction))
		if (Terrain.landable(PLANET, direction) == safe and absf(direction.z) < 0.8
			and absf(world_normal.y) < 0.76 and drift.length() > 0.6):
			return direction
	return Vector3.ZERO


func _set_approach(flight: Flight, direction: Vector3) -> void:
	var spin := Terrain.spin_basis(PLANET, flight.orbit_time)
	var center := flight.target_position(PLANET)
	var ground := center + spin * Terrain.point(PLANET, direction)
	var normal := spin * Terrain.normal(PLANET, direction)
	var aim := -normal
	flight.position = center + spin * (Terrain.contact(PLANET, direction) + direction * 3.0)
	flight.velocity = flight.surface_velocity(PLANET, ground)
	flight.yaw = atan2(-aim.x, -aim.z)
	flight.pitch = asin(clampf(aim.y, -1.0, 1.0))
	flight.gear_deployed = true
	flight.gear_extension = 1.0


func _set_session(flight: Flight) -> bool:
	return SessionIO.save_state(flight.snapshot()) == OK


func _tap(viewport: SubViewport, button: Button, enabled: bool, description: String) -> void:
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree() and button.disabled == (not enabled), description):
		return
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 23
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		viewport.push_input(event, true)


func _advance(flight: Flight, reached: Callable, seconds: float) -> bool:
	for _frame in range(ceili(seconds / STEP)):
		if reached.call():
			return true
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	return reached.call()


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
