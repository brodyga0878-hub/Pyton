extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Camera := preload("res://scripts/flight_camera.gd")
const Combat := preload("res://scripts/combat_systems.gd")
const Traffic := preload("res://scripts/civilian_traffic.gd")
const Ships := preload("res://scripts/ship_systems.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Session := preload("res://scripts/session_io.gd")

var _checks := 0
var _failures: Array[String] = []


class CombatGame extends "res://scripts/main.gd":
	func _save(_keep_backup: bool = false) -> void:
		pass


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1544, 720)]:
		for mirrored: bool in [false, true]:
			var hull := Ships.STARTER_HULL
			if dimensions.x == 1280 and mirrored:
				hull = Ships.INTERCEPTOR_HULL
			elif dimensions.x == 1544 and not mirrored:
				hull = Ships.HAULER_HULL
			await _test_combat_touches(dimensions, mirrored, hull)
	for weapon: String in [Combat.PULSE, Combat.FOCUS]:
		await _test_repeat(weapon)
	await _test_interruption()
	print("Combat touch integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	await create_timer(0.15).timeout
	quit(int(not _failures.is_empty()))


func _test_combat_touches(dimensions: Vector2i, mirrored: bool, hull: String) -> void:
	var label := "%s %s %s" % [dimensions, "mirrored" if mirrored else "standard", hull]
	var game := _open_game(dimensions, mirrored)
	var viewport := game.get_viewport()
	var flight: Flight = game.flight
	if not _prepare_raid(game, Combat.PULSE, hull) or not _equip_inbound_threat(flight):
		_expect(false, label + " prepares the outfitted ship and a real raid")
		await _close_game(game)
		return
	game._update_display(0.5)
	await process_frame
	var hud := game._hud
	_assert_layout(hud, viewport.get_visible_rect(), label)

	var steer := hud._steer.get_global_rect().get_center() + Vector2(12.0, -7.0)
	var roll := hud._bank.get_global_rect().get_center() + Vector2(10.0, 0.0)
	_touch(viewport, 1, steer, true)
	_touch(viewport, 3, roll, true)
	var locked := flight.ambient_status().id as String
	var nav := flight.target
	_tap(game, "aim_lock")
	_expect(flight.combat_lock_id() == locked and flight.target == nav
		and hud.move_input().length() > 0.05 and absf(hud.roll_input()) > 0.05,
		label + " can lock the live raider without losing either held flight axis")

	var fire: Vector2 = hud._actions["fire"].get_global_rect().get_center()
	var before := _ready_at(flight)
	_touch(viewport, 2, fire, true)
	var first := _ready_at(flight)
	_expect(first > before and hud.fire_held() and hud.move_input().length() > 0.05 and absf(hud.roll_input()) > 0.05,
		label + " fires on press while independent steering and roll remain held")
	var previous_attitude := flight.attitude()
	game._physics_process(Fixture.STEP)
	_expect(not flight.attitude().is_equal_approx(previous_attitude) and hud.fire_held(),
		label + " held steering and roll actually turn the firing hull in simulation")
	_touch(viewport, 2, fire, false)
	_expect(_ready_at(flight) == first and not hud.fire_held() and hud.move_input().length() > 0.05,
		label + " a short tap does not fire a second shot on release")
	_touch(viewport, 1, steer, false, true)
	_touch(viewport, 3, roll, false)
	_expect(hud.move_input().is_zero_approx() and is_zero_approx(hud.roll_input()),
		label + " cancellation and release clear only their corresponding controls")
	_aim_at_raid(flight)
	game._update_display(0.0)

	var shots: Array = flight.combat_equipment_status().missile_slots.duplicate()
	_tap(game, "missile_fire")
	_expect(flight.missile_status().projectile.get("target") == locked
		and flight.combat_equipment_status().missile_slots.count("dart") == shots.count("dart") - 1,
		label + " touch launch commits the locked target and spends exactly one round")
	_tap(game, "decoy")
	_expect(flight.decoy_status().active and flight.decoy_status().count == 0
		and not flight.combat.projectile_status().is_empty(),
		label + " touch decoy spends one charge and leaves both projectiles in flight")
	_tap(game, "ecm")
	_expect(flight.combat.projectile_status().is_empty() and flight.decoy_status().active
		and flight.missile_status().projectile.get("target") == locked,
		label + " touch enhanced ECM clears the hardened incoming missile")

	var path := "user://touch-combat-roundtrip.json"
	var cold := Flight.new()
	_expect(Session.save_state(flight.snapshot(), path) == OK and cold.restore(Session.load_state(path))
		and cold.ship.hull_id == hull and cold.combat_lock_id() == locked and cold.target == nav and cold.decoy_status().active
		and cold.missile_status().projectile == flight.missile_status().projectile
		and cold.combat_equipment_status().missile_slots == flight.combat_equipment_status().missile_slots,
		label + " reload retains the live projectile, expended fitting and original navigation route")
	await _close_game(game)


func _test_repeat(weapon: String) -> void:
	var game := _open_game(Vector2i(1280, 720))
	var flight: Flight = game.flight
	var hud := game._hud
	if not _prepare_raid(game, weapon) or not flight.select_combat_contact(flight.ambient_status().id):
		_expect(false, weapon + " sets up a valid lock for held fire")
		await _close_game(game)
		return
	game._update_display(0.5)
	await process_frame
	var button: Button = hud._actions["fire"]
	flight.yaw += PI * 0.25
	game._update_display(0.0)
	var point := button.get_global_rect().get_center()
	var before := _ready_at(flight)
	_touch(game.get_viewport(), 2, point, true)
	_expect(hud.fire_held() and _ready_at(flight) == before, weapon + " accepts a hold before alignment without firing")
	for step: int in range(10):
		_advance(game, Fixture.STEP)
		if _ready_at(flight) > before:
			break
	var ready := _ready_at(flight)
	var cooldown: float = Combat.PROFILES[weapon].cooldown
	_expect(is_equal_approx(ready, flight.orbit_time + cooldown), weapon + " acquires alignment and uses the mounted cooldown")
	_advance(game, cooldown * 0.55)
	_expect(_ready_at(flight) == ready and hud.fire_held(), weapon + " stays held during cooldown with no early shot")
	_advance(game, cooldown * 0.65)
	var repeated := _ready_at(flight)
	_expect(repeated - ready >= cooldown - 0.00001 and repeated - ready <= cooldown + 2.0 * Fixture.STEP
		and hud.fire_held(), weapon + " repeats only after its native recharge interval")
	_touch(game.get_viewport(), 2, point, false)
	_advance(game, cooldown * 1.1)
	_expect(not hud.fire_held() and _ready_at(flight) == repeated, weapon + " release stops repeating even with clear aim")
	await _close_game(game)


func _test_interruption() -> void:
	for action: String in ["cancel", "map", "pause", "focus", "camera", "target"]:
		var game := _open_game(Vector2i(1280, 720))
		var flight: Flight = game.flight
		if not _prepare_raid(game) or not flight.select_combat_contact(flight.ambient_status().id):
			_expect(false, action + " sets up a valid lock for hold interruption")
			await _close_game(game)
			continue
		game._update_display(0.5)
		await process_frame
		var hud := game._hud
		var point: Vector2 = hud._actions["fire"].get_global_rect().get_center()
		var viewport := game.get_viewport()
		_touch(viewport, 2, point, true)
		var ready := _ready_at(flight)
		_expect(ready > flight.orbit_time and hud.fire_held(), action + " begins with an active hold and actual shot")
		match action:
			"cancel":
				_touch(viewport, 2, point, false, true)
			"map":
				_tap(game, "map")
				_expect(game._map.is_open(), "real map touch opens its overlay")
				game._close_map()
			"pause":
				_tap(game, "time_pause")
				_expect(flight.time_paused, "real pause touch freezes time with a held fire pointer")
				_tap(game, "time_pause")
			"focus":
				hud.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
			"camera":
				_tap(game, "camera")
				game._update_display(0.5)
				_expect(game._view.preferred_camera_mode() == Camera.Mode.REAR, "real camera touch selects the aft view")
			"target":
				flight.select_combat_contact("")
				_advance(game, Fixture.STEP)
				_expect(not hud.fire_held(), "clearing the target releases the hold during the original cooldown")
		_advance(game, Combat.PROFILES.pulse.cooldown * 1.3)
		_expect(_ready_at(flight) == ready and not hud.fire_held(),
			action + " clears the active hold without another shot or fallback target")
		_touch(viewport, 2, point, false)
		await _close_game(game)


func _prepare_raid(game: CombatGame, weapon := Combat.PULSE, hull := Ships.STARTER_HULL) -> bool:
	var flight: Flight = game.flight
	flight.credits = 16000
	if hull != Ships.STARTER_HULL:
		var stock_shift := 5.0 if hull == Ships.INTERCEPTOR_HULL else 8.0
		flight.update(stock_shift * Flight.SHIPYARD_STOCK_SECONDS, Vector2.ZERO, 0.0, false, false)
		if not flight.shipyard_swap(hull):
			return false
		var candidates := flight.crew_candidates()
		for index: int in range(flight.ship.crew_required()):
			if not flight.crew_hire(int(candidates[index].id)):
				return false
	for fitting: String in ["combat_launcher", "combat_missile_dart", "combat_ecm", "combat_ecm_advanced",
			"combat_decoy", "combat_energy_pulse", "combat_shield"]:
		if not flight.service_action(fitting):
			return false
	if weapon == Combat.FOCUS and not flight.service_action("combat_focus"):
		return false
	if not Fixture.depart(flight):
		return false
	var phase := fposmod(flight.orbit_time, Traffic.PERIOD)
	flight._advance_background_clock(fposmod(Traffic.RAID + 0.5 - phase, Traffic.PERIOD))
	var raid := flight.ambient_status()
	if not raid.hostile:
		return false
	flight.position = raid.position + Vector3(0.0, -38.0, 100.0)
	flight.velocity = Vector3.ZERO
	_aim_at_raid(flight)
	game._handle_action("camera")
	return true


func _equip_inbound_threat(flight: Flight) -> bool:
	var source := flight.position + Vector3.BACK * 120.0
	flight.combat.incoming_shot(source, flight.position, flight.system_id, flight.orbit_time, true)
	return flight.combat.incoming_shot(source, flight.position, flight.system_id, flight.orbit_time, true)


func _assert_layout(hud: CanvasLayer, screen: Rect2, label: String) -> void:
	var rects := {"steer": hud._steer.get_global_rect(), "bank": hud._bank.get_global_rect()}
	for action: String in ["aim_lock", "fire", "ecm", "missile_next", "missile_fire", "decoy",
			"energy_pulse", "brake", "boost", "camera", "navigation_toggle", "dock"]:
		var button: Button = hud._actions[action]
		var rect := button.get_global_rect()
		if _expect(button.is_visible_in_tree() and screen.encloses(rect) and rect.size.y >= 40.0,
			label + " fits " + action + " at a full touch size"):
			rects[action] = rect
	var names := rects.keys()
	var overlaps: Array[String] = []
	for index: int in range(names.size()):
		for earlier: int in range(index):
			if rects[names[index]].intersects(rects[names[earlier]]):
				overlaps.append("%s/%s" % [names[index], names[earlier]])
	_expect(overlaps.is_empty(), label + " keeps flight and combat touch regions separate " + str(overlaps))


func _advance(game: CombatGame, seconds: float) -> void:
	for step: int in range(ceili(seconds / Fixture.STEP)):
		_aim_at_raid(game.flight)
		game._physics_process(Fixture.STEP)
	game._update_display(0.0)


func _aim_at_raid(flight: Flight) -> void:
	var aim := flight.position.direction_to(flight.ambient_status().position)
	flight.yaw = atan2(-aim.x, -aim.z)
	flight.pitch = clampf(asin(aim.y), -Flight.MAX_PITCH, Flight.MAX_PITCH)
	flight.roll = 0.0


func _ready_at(flight: Flight) -> float:
	return float(flight.combat.snapshot().fire_ready_at)


func _open_game(dimensions: Vector2i, mirrored := false) -> CombatGame:
	var viewport := SubViewport.new()
	viewport.size = dimensions
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := CombatGame.new()
	game.show_voyage_menu_on_launch = true
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game._flight_active = true
	game._voyages.close()
	game._hud.set_input_enabled(true)
	game._hud.set_touch_preferences(1, mirrored)
	return game


func _close_game(game: CombatGame) -> void:
	game.get_viewport().queue_free()
	await process_frame


func _tap(game: CombatGame, action: String) -> void:
	var button: Button = game._hud._actions[action]
	var point := button.get_global_rect().get_center()
	_touch(game.get_viewport(), 4, point, true)
	_touch(game.get_viewport(), 4, point, false)


func _touch(viewport: Viewport, index: int, at: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	event.canceled = canceled
	viewport.push_input(event, true)


func _expect(value: bool, description: String) -> bool:
	_checks += 1
	if not value:
		_failures.append(description)
	return value
