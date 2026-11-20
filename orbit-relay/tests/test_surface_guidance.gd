extends SceneTree

const Catalog = preload("res://scripts/sector_catalog.gd")
const Flight = preload("res://scripts/flight_sim.gd")
const Rig = preload("res://scripts/mining_rig.gd")
const Terrain = preload("res://scripts/surface_terrain.gd")
const SessionIO = preload("res://scripts/session_io.gd")
const Game = preload("res://main.tscn")
const ASTEROID := 2
const COMET := 8
const EPOCH := 135.0
const STEP := 1.0 / 60.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for site: int in [ASTEROID, COMET, 12, Catalog.TERRACE_ID]:
		_test_relative_geometry(site)
	_test_readiness_gates()
	await _test_touch_cycle()
	print("Surface approach guidance: %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_relative_geometry(site: int) -> void:
	var direction := _patch(site, true)
	if not _expect(direction != Vector3.ZERO, "Site %d has sloped but landable off-pad terrain" % site):
		return
	var flight := _approach(site, direction, 8.0)
	var normal := Terrain.normal(site, direction)
	var tangent := Terrain.basis(site, direction).x
	var site_velocity := flight.target_velocity(site)
	flight.velocity = site_velocity - 2.0 * normal + 1.5 * tangent
	var status := flight.surface_status()
	_expect(status.guide and status.near and status.ok and not status.pad
		and status.height_ok and status.speed_ok and status.slope_ok and status.aim_ok,
		"Site %d reports a ready off-pad approach without changing the landing mode" % site)
	_expect(status.direction.distance_to(direction) < 0.001 and status.surface_normal.distance_to(normal) < 0.001
		and status.ground_point.distance_to(flight.target_position(site) + Terrain.point(site, direction)) < 0.004
		and absf(status.altitude - 8.0) < 0.004 and status.aim_error_deg < 0.2,
		"Site %d ground projection and nose angle use the actual terrain" % site)
	_expect(site_velocity.length() > 0.01 and absf(status.descent_speed - 2.0) < 0.004
		and absf(status.drift_speed - 1.5) < 0.004 and absf(status.relative_speed - 2.5) < 0.004,
		"Site %d decomposes velocity in the moving surface frame" % site)
	flight.velocity = site_velocity + 1.25 * normal - 1.5 * tangent
	status = flight.surface_status()
	_expect(absf(status.descent_speed + 1.25) < 0.004 and absf(status.drift_speed - 1.5) < 0.004,
		"Site %d distinguishes climbing from descending" % site)


func _test_readiness_gates() -> void:
	var direction := _patch(ASTEROID, true)
	var normal := Terrain.normal(ASTEROID, direction)
	var flight := _approach(ASTEROID, direction, 8.0)
	var center := flight.target_position(ASTEROID)
	var tangent := Terrain.basis(ASTEROID, direction).x
	flight.velocity = flight.target_velocity(ASTEROID) - 3.0 * normal + 3.0 * tangent
	var status := flight.surface_status()
	_expect(status.guide and status.height_ok and not status.speed_ok and status.slope_ok and status.aim_ok
		and status.relative_speed > Flight.LANDING_SPEED and not status.ok and not flight.dock_action(),
		"Two small velocity components together exceed the touchdown speed limit")
	flight.velocity = flight.target_velocity(ASTEROID)
	_aim(flight, normal)
	status = flight.surface_status()
	_expect(status.guide and status.height_ok and status.speed_ok and status.slope_ok and not status.aim_ok
		and status.aim_error_deg > 179.8 and not status.ok and not flight.dock_action(),
		"Facing away from the plane blocks an otherwise ready touchdown")
	_aim(flight, -normal)
	flight.position = center + Terrain.point(ASTEROID, direction) + direction * 45.0
	status = flight.surface_status()
	_expect(status.guide and status.near and not status.height_ok and status.speed_ok and status.aim_ok
		and not status.ok and not flight.dock_action(), "High nearby flight gives guidance without allowing landing")
	flight.position = center + Terrain.point(ASTEROID, direction) + direction * 92.0
	status = flight.surface_status()
	_expect(not status.guide and not status.ok, "The display drops above its 90-meter measurement range")
	flight.position = center + direction * 280.0
	status = flight.surface_status()
	_expect(not status.guide and not status.near and not status.ok, "Distant tracking has no surface guide")
	flight.position = center + Terrain.point(ASTEROID, direction) + direction * 78.0
	if _expect(flight.surface_status().guide and flight.plan_jump(Catalog.VELAR_SYSTEM) and flight.start_jump(),
		"A nearby surface may already be clear enough for a real jump charge"):
		_expect(not flight.surface_status().guide and not flight.surface_status().ok and flight.cancel_jump(),
			"Charging suppresses guidance and denies touchdown")
		_expect(flight.surface_status().guide, "The display resumes after canceling a jump")
	_expect(flight.select_target(Catalog.STAR_ID) and not flight.surface_status().guide
		and not flight.surface_status().ok, "A fuel target has no solid-ground approach")
	_expect(flight.select_target(1) and not flight.surface_status().guide,
		"The station uses a separate docking guide")

	var steep := _patch(ASTEROID, false)
	if _expect(steep != Vector3.ZERO, "The asteroid has a steep patch to reject"):
		var steep_flight := _approach(ASTEROID, steep, 8.0)
		var slope := steep_flight.surface_status()
		_expect(slope.guide and slope.height_ok and slope.speed_ok and not slope.slope_ok and slope.aim_ok
			and slope.slope > Terrain.MAX_LANDING_SLOPE and not slope.ok and not steep_flight.dock_action(),
			"The guidance identifies terrain steepness as the only closed gate")

	var pad_flight := _approach(ASTEROID, Vector3.BACK, 10.5)
	pad_flight.position.x += 2.0
	var along_pad := pad_flight.surface_status()
	_expect(along_pad.guide and along_pad.pad and along_pad.height_ok and along_pad.ok
		and along_pad.direction == Vector3.BACK and along_pad.surface_normal == Vector3.BACK
		and along_pad.ground_point.distance_to(center + Terrain.point(ASTEROID, Vector3.BACK)) < 0.002,
		"A nearby marked pad keeps the original 11-meter limit and projects its real center")
	_aim(pad_flight, Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(15.0)))
	var tight := pad_flight.surface_status()
	_expect(tight.pad and tight.height_ok and tight.speed_ok and tight.slope_ok
		and not tight.aim_ok and not tight.ok, "Landing on a marked pad keeps the tighter 12-degree nose limit")


func _test_touch_cycle() -> void:
	var direction := _patch(COMET, true)
	var seed := _approach(COMET, direction, 8.0)
	var tangent := Terrain.basis(COMET, direction).x
	seed.ship.fuel = 0.0
	seed.velocity += tangent * 5.0
	seed.gear_extension = 0.0
	seed.gear_deployed = false
	if not _expect(SessionIO.save_state(seed.snapshot()) == OK, "The off-pad approach can be saved"):
		return
	var game := _open_game()
	await process_frame
	var flight: Flight = game.flight
	_expect(game._hud._surface_panel.is_visible_in_tree() and not flight.surface_status().speed_ok
		and "Скорость —" in game._hud._surface_ready.text,
		"The first displayed approach detects dangerous sideways motion from the saved flight")
	_expect(game._hud._surface_gear.text == "Шасси убрано" and not game._view._landing_gear.visible,
		"The retracted gear matches the instrument and is hidden on the ship")
	_touch(game._hud._actions["dock"])
	_expect(not flight.landed, "Touch does not bypass the surface warning")
	flight.velocity = flight.target_velocity(COMET)
	game._update_display(0.0)
	await process_frame
	_expect(game._hud._surface_panel.is_visible_in_tree() and not flight.surface_status().ok
		and not flight.surface_status().gear_ok
		and "Скорость ✓" in game._hud._surface_ready.text,
		"Matching ground speed clears the speed warning while the retracted gear still blocks touchdown")
	_touch(game._hud._actions["map"])
	_expect(game._map.visible and not game._hud._surface_panel.is_visible_in_tree(),
		"The surface guide goes away while the system map is open")
	await process_frame
	_touch(game._map._close_button)
	game._update_display(0.0)
	await process_frame
	_expect(game._hud._surface_panel.is_visible_in_tree(), "Closing the map restores live surface guidance")
	_touch(game._hud._actions["gear"])
	_expect(flight.gear_deployed and not flight.surface_status().gear_ok,
		"The touch gear control starts the timed deployment")
	var travel_ticks := ceili(Flight.GEAR_TRAVEL_SECONDS / STEP)
	var first_ticks := floori(travel_ticks * 0.5)
	for _frame in range(first_ticks):
		game._physics_process(STEP)
	game._update_display(0.0)
	_expect(game._view._landing_gear.visible and "Выпуск шасси" in game._hud._surface_gear.text
		and "%" in game._hud._actions["gear"].text and not flight.surface_status().ok,
		"The moving struts and percentage are visible while touchdown remains unavailable")
	for _frame in range(travel_ticks - first_ticks + 1):
		game._physics_process(STEP)
	game._update_display(0.0)
	await process_frame
	_expect(flight.surface_status().ok and flight.surface_status().gear_ok
		and game._hud._surface_gear.text == "Шасси выпущено",
		"Touchdown is ready only once the visible approach has fully extended gear")
	_touch(game._hud._actions["dock"])
	game._update_display(0.0)
	await process_frame
	var dock_button: Button = game._hud._actions["dock"]
	_expect(flight.landed_offpad() and flight.landed_site == COMET and flight.landing_direction.dot(direction) > 0.9999
		and not game._hud._surface_panel.is_visible_in_tree() and not flight.surface_status().guide
		and not game._hud._actions["gear"].visible and game._view._landing_gear.visible
		and dock_button.text == "Взлёт" and not dock_button.disabled,
		"After touchdown on the sampled patch the flight guide is replaced by an enabled lift action")
	var reserve := flight.mining.reserve_at(COMET)
	_touch(game._hud._actions["mine"])
	_advance_until(game, Rig.DRILLING, 4.0)
	game._update_display(0.0)
	await process_frame
	_expect(flight.mining.phase == Rig.DRILLING and dock_button.disabled
		and flight.surface_deposit().origin.distance_to(flight.position) > 3.0,
		"The separate drilling module blocks takeoff while it works at a nearby deposit")
	_touch(dock_button)
	_expect(flight.landed_offpad(), "Touch cannot bypass the deployed module")
	var checkpoint := flight.snapshot()
	_expect(SessionIO.save_state(checkpoint) == OK, "The deployed surface module can be saved")
	game.queue_free()
	await process_frame
	game = _open_game()
	await process_frame
	flight = game.flight
	_expect(flight.landed_offpad() and flight.landing_direction.dot(direction) > 0.9999
		and flight.mining.phase == Rig.DRILLING and not game._hud._surface_panel.is_visible_in_tree(),
		"Cold reload restores the same patch and still suppresses flight guidance on the ground")
	_advance_until(game, Rig.READY, float(Catalog.site(COMET).drill_seconds) + 3.0)
	game._update_display(0.0)
	await process_frame
	_touch(game._hud._actions["mine"])
	_advance_until(game, Rig.STOWED, 4.0)
	game._update_display(0.0)
	await process_frame
	_expect(flight.mining.phase == Rig.STOWED and flight.mining.reserve_at(COMET) == reserve - Rig.BATCH
		and flight.mining.cargo_amount("ice") == Rig.BATCH and not game._hud._actions["dock"].disabled,
		"One recovered batch depletes the deposit and re-enables touch takeoff")
	var body_velocity := flight.target_velocity(COMET)
	var normal := Terrain.normal(COMET, direction)
	_touch(game._hud._actions["dock"])
	var relative := flight.velocity - body_velocity
	_expect(not flight.landed and flight.ship.fuel == 0.0 and relative.dot(normal) > 7.0
		and relative.slide(normal).length() < 0.05, "Touch launches outward from the saved patch with an empty tank")
	game.queue_free()
	await process_frame


func _approach(site: int, direction: Vector3, height: float) -> Flight:
	var flight := Flight.new()
	flight.system_id = Catalog.system_of_site(site)
	flight.orbit_time = EPOCH
	flight.elapsed = EPOCH
	flight.freight.reset(EPOCH)
	flight.docked = -1
	flight.target = site
	flight.position = flight.target_position(site) + Terrain.point(site, direction) + direction * height
	flight.velocity = flight.target_velocity(site)
	_aim(flight, -Terrain.normal(site, direction))
	flight.gear_extension = 1.0
	flight.gear_deployed = true
	return flight


func _aim(flight: Flight, direction: Vector3) -> void:
	flight.yaw = atan2(-direction.x, -direction.z)
	flight.pitch = asin(clampf(direction.y, -1.0, 1.0))
	flight.roll = 0.0


func _patch(site: int, safe: bool) -> Vector3:
	for index in range(128):
		var y := 2.0 * (index + 0.5) / 128.0 - 1.0
		var ring := sqrt(1.0 - y * y)
		var angle := TAU * fposmod(index * 0.381966, 1.0)
		var direction := Vector3(cos(angle) * ring, y, sin(angle) * ring)
		var normal := Terrain.normal(site, direction)
		if (direction.z < 0.6 and absf(normal.y) < 0.9 and normal.dot(direction) < 0.999
				and Terrain.landable(site, direction) == safe):
			return direction
	return Vector3.ZERO


func _open_game() -> Node:
	var game := Game.instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game._update_display(0.0)
	return game


func _touch(button: Button) -> void:
	if not _expect(button != null and button.is_visible_in_tree(), "The intended touch control is visible"):
		return
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 9
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event, true)


func _advance_until(game: Node, phase: int, seconds: float) -> void:
	for _frame in range(roundi(seconds / STEP)):
		if game.flight.mining.phase == phase:
			return
		game._physics_process(STEP)


func _expect(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
	return condition
