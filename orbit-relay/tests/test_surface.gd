extends SceneTree

const Fixture = preload("res://tests/flight_fixture.gd")

const Flight = preload("res://scripts/flight_sim.gd")
const Catalog = preload("res://scripts/sector_catalog.gd")
const Orbit = preload("res://scripts/orbit_ephemeris.gd")
const Terrain = preload("res://scripts/surface_terrain.gd")
const Rig = preload("res://scripts/mining_rig.gd")
const OrbitRelay = preload("res://main.tscn")
const SessionIO = preload("res://scripts/session_io.gd")
const STEP := 1.0 / 60.0
const EPOCH := 135.0
const PLANET := 15
const SURFACE_EXAMPLES := [2, 8, 12, PLANET]
const DIRECTIONS := [
	Vector3.RIGHT, Vector3(1.0, 0.2, -0.4), Vector3.LEFT, Vector3(0.3, 0.4, -0.8),
	Vector3(0.9, -0.4, 0.25), Vector3(0.18, 0.9, 0.3), Vector3.FORWARD,
]

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_terrain_geometry()
	_test_landing_limits()
	_test_terrain_collision()
	_test_orbital_save_migration()
	_test_empty_tank_comet_departure()
	for site: int in SURFACE_EXAMPLES:
		await _test_surface_cycle(site)
	print("Surface integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_terrain_geometry() -> void:
	_expect(Catalog.site(PLANET).kind == "planet" and Catalog.is_mine_site(PLANET)
		and Catalog.system_of_site(PLANET) == Catalog.VELAR_SYSTEM,
		"The rocky planet is a real local target with extractable ground")
	for system in range(Catalog.SYSTEM_COUNT):
		for site: int in Catalog.mines_for(system):
			var name: String = Catalog.site(site).name
			var pad := Vector3.BACK * float(Catalog.site(site).pad_offset)
			_expect(Terrain.contact(site, Vector3.BACK).is_equal_approx(pad)
				and Terrain.normal(site, Vector3.BACK).is_equal_approx(Vector3.BACK)
				and Terrain.landable(site, Vector3.BACK), "%s keeps its marked pad" % name)
			var direction := _safe_direction(site)
			if not _expect(direction != Vector3.ZERO and absf(direction.z) < 0.98,
				"%s has a safe area away from its marked pad" % name):
				continue
			var point := Terrain.point(site, direction)
			var normal := Terrain.normal(site, direction)
			var basis := Terrain.basis(site, direction)
			_expect(is_equal_approx(point.length(), Terrain.radius_at(site, direction))
				and point.normalized().is_equal_approx(direction)
				and is_equal_approx(Terrain.contact(site, direction).distance_to(point), 4.0),
				"%s terrain sampling and touchdown clearance agree" % name)
			_expect(basis.z.is_equal_approx(normal) and is_equal_approx(basis.determinant(), 1.0)
				and normal.dot(direction) > 0.8, "%s produces an outward orthonormal ground frame" % name)
			var deposit := Terrain.deposit(site, direction)
			var ground := Terrain.point(site, deposit.origin.normalized())
			_expect(deposit.origin.distance_to(point) < 12.0 and deposit.origin.distance_to(ground) < 4.0
				and deposit.basis.z.dot(ground.normalized()) > 0.8,
				"%s offers nearby solid ground for the detachable drill" % name)


func _test_landing_limits() -> void:
	var direction := _safe_direction(2)
	if direction == Vector3.ZERO:
		return
	var flight := _approach(2, direction)
	var approach_position := flight.position
	var normal := Terrain.normal(2, direction)
	var drift := flight.target_velocity(2)
	var tangent := Terrain.basis(2, direction).x
	_expect(flight.surface_status().ok and not flight.surface_status().pad,
		"A slow aligned approach to safe terrain is recognized as off-pad")
	flight.velocity = drift + tangent * 4.25
	_expect(not flight.surface_status().ok and not flight.dock_action() and not flight.landed,
		"Fast lateral motion relative to the asteroid blocks touchdown")
	flight.velocity = drift
	_aim(flight, normal)
	_expect(not flight.surface_status().ok and not flight.dock_action() and not flight.landed,
		"Facing away from the terrain blocks touchdown even at zero relative speed")
	_aim(flight, -normal)
	flight.position += direction * 18.0
	_expect(not flight.surface_status().ok and not flight.dock_action(),
		"A position high over landable ground cannot teleport into touchdown")
	flight.position = approach_position
	if _expect(flight.dock_action(), "Correcting the attitude and height makes touchdown possible"):
		_expect(flight.landed_offpad() and flight.landing_direction.dot(direction) > 0.9999,
			"Touchdown records the selected patch instead of relocating to the marked pad")
	var star := Flight.new()
	Fixture.launch(star)
	star.select_target(Catalog.STAR_ID)
	star.position = star.target_contact(Catalog.STAR_ID)
	star.velocity = Vector3.ZERO
	_expect(not star.surface_status().ok and not star.dock_action() and not star.mine_action(),
		"An active star remains a fuel target with no touchdown or mineral extraction")
	var steep := Vector3.ZERO
	for index in range(128):
		var candidate := _surface_direction(index)
		if absf(Terrain.normal(2, candidate).y) < 0.85 and not Terrain.landable(2, candidate):
			steep = candidate
			break
	if _expect(steep != Vector3.ZERO, "The asteroid has unsafe slopes as well as safe patches"):
		var slope_approach := _approach(2, steep)
		var status := slope_approach.surface_status()
		_expect(status.near and not status.pad and status.slope > 28.0 and not status.ok
			and not slope_approach.dock_action(), "A steep patch rejects an otherwise slow, aligned landing")


func _test_terrain_collision() -> void:
	var direction := _safe_direction(8)
	if direction == Vector3.ZERO:
		return
	var flight := _approach(8, direction)
	flight.position -= direction * 2.4
	flight.velocity -= direction * 20.0
	var protected := false
	for _frame in range(30):
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
		protected = protected or flight.status_event in ["clearance", "hull_damage"]
	var relative := flight.position - flight.target_position(8)
	_expect(protected and flight.ship.hull < 100.0 and not flight.landed
		and relative.length() >= Terrain.radius_at(8, relative.normalized()) + 3.9,
		"A fast descent damages the hull, and protective braking keeps it outside the comet terrain")


func _test_empty_tank_comet_departure() -> void:
	var flight := _approach(8, _surface_direction(4, 8), 0.0)
	flight.ship.fuel = 0.0
	if not _expect(flight.dock_action() and flight.landed_offpad() and flight.select_target(1)
		and flight.dock_action(), "A ship with an empty tank can leave the comet's far-side patch"):
		return
	flight.set_autopilot(true)
	var detour_seen := false
	for _frame in range(roundi(180.0 / STEP)):
		if not flight.autopilot or flight.docked >= 0:
			break
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
		detour_seen = detour_seen or flight.autopilot_phase == "Обход препятствия"
	_expect(detour_seen and flight.docked == 1 and flight.ship.fuel == 0.0,
		"Autopilot avoids the comet on the reserve route to the destination port")


func _test_orbital_save_migration() -> void:
	# Version 0.38 kept landed ships at a single pad and saved exactly 15 reserves.
	var center: Vector3 = Orbit.sample(8, 210.5).position
	var contact := center + Vector3.BACK * 68.0
	var previous := {
		"schema": 6, "position": _components(contact), "velocity": [0.0, 0.0, 0.0],
		"yaw": 0.0, "pitch": 0.0, "roll": 0.0, "elapsed": 215.25, "orbit_time": 210.5, "throttle": 0.0,
		"docked": -1, "target": 8, "landed_site": 8, "planned_target": 1,
		"system_id": 0, "jump_target": 1,
		"credits": 741, "deliveries": 2, "contract_stage": 0, "contract_origin": -1, "contract_destination": -1,
		"ship": {"fuel": 0.0, "tank_upgraded": false, "eco_upgraded": true},
		"mining": {
			"site_id": 8, "phase": Rig.RETURNING, "phase_seconds": 0.6, "pending_ore": Rig.BATCH,
			"cargo": {"ore": 0, "crystal": 0, "ice": 0},
			"reserves": [0, 0, 120, 0, 96, 180, 156, 132, 216, 0, 0, 0, 192, 144, 0],
		},
	}
	var flight := Flight.new()
	if not _expect(flight.restore(_round_trip(previous)), "A literal schema-6 save restores during comet rig recovery"):
		return
	_expect(flight.landed and not flight.landed_offpad() and flight.landing_direction == Vector3.BACK
		and flight.position.is_equal_approx(contact) and flight.orbit_time == 210.5 and flight.planned_target == 1,
		"Migration preserves the moving pad pose, epoch and planned route")
	var upgraded := flight.snapshot()
	_expect(upgraded.schema == Flight.SAVE_SCHEMA and upgraded.mining.reserves.size() == Catalog.DESTINATION_COUNT
		and flight.mining.reserve_at(PLANET) == int(Catalog.site(PLANET).reserve)
		and flight.mining.reserve_at(8) == 216 and flight.mining.phase == Rig.RETURNING,
		"The current schema keeps old reserves and initializes the rocky planet deposit")
	flight.update(2.0, Vector2.ZERO, 0.0, false, false)
	_expect(flight.mining.cargo_amount("ice") == Rig.BATCH and flight.mining.reserve_at(8) == 216 - Rig.BATCH
		and flight.mining.phase == Rig.STOWED and flight.dock_action() and flight.target == 1,
		"The migrated ship finishes recovery once and lifts with its planned course")
	_test_airborne_migration(previous, center)


func _test_airborne_migration(previous: Dictionary, center: Vector3) -> void:
	var airborne := previous.duplicate(true)
	airborne.landed_site = -1
	airborne.planned_target = -1
	airborne.mining.phase = Rig.STOWED
	airborne.mining.phase_seconds = 0.0
	airborne.mining.pending_ore = 0
	var high_ground := Vector3.ZERO
	for index in range(128):
		var candidate := _surface_direction(index)
		if Terrain.contact(8, candidate).length() > 68.5:
			high_ground = candidate
			break
	if _expect(high_ground != Vector3.ZERO, "The shared comet surface can extend above the former sphere"):
		airborne.position = _components(center + high_ground * 68.25)
		airborne.velocity = [1.0, 0.0, 0.0]
		var flight := Flight.new()
		if _expect(flight.restore(_round_trip(airborne)), "Formerly clear comet fly-by is still loadable"):
			var offset := flight.position - flight.target_position(8)
			_expect(not flight.landed and flight.landing_direction == Vector3.ZERO and flight.orbit_time == 210.5
				and offset.normalized().dot(high_ground) > 0.9999
				and offset.length() > Terrain.contact(8, high_ground).length()
				and flight.velocity == Vector3.ZERO, "Legacy fly-by is moved outward along its existing line of approach")
	airborne.system_id = Catalog.VELAR_SYSTEM
	airborne.jump_target = Catalog.HOME_SYSTEM
	airborne.target = 10
	airborne.position = _components(Orbit.sample(PLANET, 210.5).position)
	var migrated := Flight.new()
	_expect(migrated.restore(_round_trip(airborne)) and migrated.position.is_equal_approx(migrated.target_gate(PLANET))
		and migrated.target == 10 and not migrated.landed and migrated.velocity == Vector3.ZERO,
		"A flight saved in space now occupied by the new planet resumes at its approach gate")


func _test_surface_cycle(site: int) -> void:
	var name: String = Catalog.site(site).name
	var direction := _safe_direction(site)
	if direction == Vector3.ZERO:
		return
	var seed := _approach(site, direction)
	seed.ship.fuel = 0.0
	if not _expect(SessionIO.save_state(seed.snapshot()) == OK, "%s approach can be saved" % name):
		return
	var game := _open_scene()
	await process_frame
	var flight: Flight = game.flight
	if not _expect(flight.target == site and flight.surface_status().ok, "%s reloads at the off-pad approach" % name):
		await _close_scene(game)
		return
	_tap(game, "dock", true, name)
	var local_offset: Vector3 = Terrain.contact(site, direction)
	if not _expect(flight.landed_site == site and flight.landed_offpad()
		and flight.position.distance_to(flight.target_position(site) + local_offset) < 0.01,
		"%s lands at the chosen surface by touch" % name):
		await _close_scene(game)
		return
	var landing_normal := Terrain.normal(site, direction)
	_expect(flight.landed_basis().z.dot(landing_normal) > 0.9999 and flight.reference_site() == site,
		"%s aligns with the local ground frame" % name)
	var reserve := flight.mining.reserve_at(site)
	var resource: String = Catalog.site(site).resource
	await process_frame
	_tap(game, "mine", true, name)
	_advance(game, func() -> bool: return flight.mining.phase == Rig.DRILLING, 3.0)
	for _frame in range(30):
		game._physics_process(STEP)
	game._update_display(0.0)
	await process_frame
	_expect(flight.mining.phase == Rig.DRILLING and flight.mining.ore_hold == 0
		and flight.mining.reserve_at(site) == reserve, "%s sends the mining rig ahead of cargo transfer" % name)
	var deposit := flight.surface_deposit()
	var rig_pose: Transform3D = game._view._mining_rig._rig.global_transform
	_expect(rig_pose.origin.distance_to(deposit.origin) < 0.08 and rig_pose.basis.z.dot(deposit.basis.z) > 0.99
		and deposit.origin.distance_to(flight.position) > 3.0,
		"%s renders a detached rig aligned to the nearby deposit" % name)
	_tap(game, "dock", false, name)
	_expect(flight.landed, "%s launch is held while the rig is deployed" % name)
	var next: int = Catalog.ports_for(flight.system_id)[0]
	_expect(flight.select_target(next), "%s can select a post-launch route while stopped" % name)
	var checkpoint: Dictionary = flight.snapshot()
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await _close_scene(game)
	game = _open_scene()
	await process_frame
	flight = game.flight
	if not _expect(flight.landed_site == site and flight.landed_offpad()
		and flight.landing_direction.dot(direction) > 0.9999 and flight.planned_target == next
		and flight.mining.phase == Rig.DRILLING
		and is_equal_approx(flight.mining.phase_seconds, checkpoint.mining.phase_seconds)
		and flight.surface_deposit().origin.distance_to(deposit.origin) < 0.01,
		"%s cold restart restores the ship and drill on the same surface patch" % name):
		await _close_scene(game)
		return
	_test_invalid_patch(flight, name)
	_advance(game, func() -> bool: return flight.mining.phase == Rig.READY, float(Catalog.site(site).drill_seconds) + 2.0)
	_expect(flight.mining.phase == Rig.READY and flight.mining.pending_ore == Rig.BATCH
		and flight.mining.ore_hold == 0, "%s finishes the saved drill cycle" % name)
	game._update_display(0.0)
	await process_frame
	_tap(game, "mine", true, name)
	_advance(game, func() -> bool: return flight.mining.phase == Rig.STOWED, 3.0)
	for _frame in range(20):
		game._physics_process(STEP)
	_expect(flight.mining.phase == Rig.STOWED and flight.mining.pending_ore == 0
		and flight.mining.cargo_amount(resource) == Rig.BATCH and flight.mining.reserve_at(site) == reserve - Rig.BATCH,
		"%s recovery loads one batch and depletes the matching stock once" % name)
	game._update_display(0.0)
	await process_frame
	var body_velocity := flight.target_velocity(site)
	_tap(game, "dock", true, name)
	var departure := flight.velocity - body_velocity
	_expect(not flight.landed and flight.landing_direction == Vector3.ZERO and flight.target == next
		and flight.ship.fuel == 0.0 and departure.dot(landing_normal) > 7.0
		and departure.slide(landing_normal).length() < 0.05,
		"%s lifts by touch in the local outward direction with an empty tank" % name)
	for _frame in range(40):
		game._physics_process(STEP)
	var clearance := flight.position - flight.target_position(site)
	_expect(clearance.length() > Terrain.radius_at(site, clearance.normalized()) + 4.4
		and flight.mining.cargo_amount(resource) == Rig.BATCH,
		"%s can leave the actual terrain cleanly with the recovered cargo" % name)
	await _close_scene(game)


func _test_invalid_patch(flight: Flight, name: String) -> void:
	var live := flight.snapshot()
	var malformed := live.duplicate(true)
	malformed.landing_direction = [0.0, 0.0, 0.0]
	_expect(not flight.restore(malformed) and flight.snapshot() == live,
		"%s rejects an invalid surface direction without changing the live drill" % name)
	malformed = live.duplicate(true)
	malformed.landing_direction = [0.0, 0.0, 1.0]
	_expect(not flight.restore(malformed) and flight.snapshot() == live,
		"%s rejects a saved patch inconsistent with the physical position" % name)


func _approach(site: int, direction: Vector3, epoch := EPOCH) -> Flight:
	var flight := Flight.new()
	flight.system_id = Catalog.system_of_site(site)
	flight.orbit_time = epoch
	flight.elapsed = epoch
	flight.freight.reset(epoch)
	flight.docked = -1
	flight.target = site
	flight.position = flight.target_position(site) + Terrain.contact(site, direction) + direction * 3.0
	flight.velocity = flight.target_velocity(site)
	_aim(flight, -Terrain.normal(site, direction))
	flight.gear_extension = 1.0
	flight.gear_deployed = true
	return flight


func _aim(flight: Flight, forward: Vector3) -> void:
	flight.yaw = atan2(-forward.x, -forward.z)
	flight.pitch = asin(clampf(forward.y, -1.0, 1.0))
	flight.roll = 0.0


func _safe_direction(site: int) -> Vector3:
	for candidate: Vector3 in DIRECTIONS:
		var direction := candidate.normalized()
		if Terrain.landable(site, direction) and absf(Terrain.normal(site, direction).y) < 0.85:
			return direction
	return Vector3.ZERO


func _surface_direction(index: int, count := 128) -> Vector3:
	var y := 2.0 * (float(index) + 0.5) / float(count) - 1.0
	var ring := sqrt(1.0 - y * y)
	var angle := TAU * fposmod(index * 0.381966, 1.0)
	return Vector3(cos(angle) * ring, y, sin(angle) * ring)


func _open_scene() -> Node:
	var game := OrbitRelay.instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game._update_display(0.0)
	return game


func _close_scene(game: Node) -> void:
	game.queue_free()
	await process_frame


func _advance(game: Node, done: Callable, maximum_seconds: float) -> void:
	for _frame in range(roundi(maximum_seconds / STEP)):
		if done.call():
			return
		game._physics_process(STEP)


func _tap(game: Node, action: String, enabled: bool, site: String) -> void:
	var button: Button = game._hud._actions.get(action)
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree(), "%s displays touch action %s" % [site, action]):
		return
	_expect(button.disabled == (not enabled), "%s touch action %s has the expected availability" % [site, action])
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 9
		touch.position = button.get_global_rect().get_center()
		touch.pressed = pressed
		root.push_input(touch, true)


func _components(vector: Vector3) -> Array[float]:
	return [vector.x, vector.y, vector.z]


func _round_trip(value: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value, "", true, true))


func _expect(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
	return condition
