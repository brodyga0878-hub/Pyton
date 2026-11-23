extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Game := preload("res://main.tscn")
const PortServices := preload("res://scripts/port_services.gd")

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_lock_model()
	await _test_scanner_touch()
	await _test_aim_lock_touch()
	print("Combat scanner: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	# Allow stopped scene audio to retire before headless shutdown.
	await create_timer(0.15).timeout
	quit(0 if _failures.is_empty() else 1)


func _test_lock_model() -> void:
	var flight := Flight.new()
	flight.credits = 1500
	var cost: int = flight.service_offer("radar_mapper").cost
	_expect(flight.service_action("radar_mapper") and flight.credits == 1500 - cost
		and not flight.service_action("radar_mapper"), "A port equips the mapper once and debits the quoted price")
	_expect(flight.patrol_action(), "The normal port action accepts the patrol and creates its career record")
	Fixture.launch(flight)
	flight.position = flight.patrol.signal_position(flight)
	flight.update(0.01, Vector2.ZERO, 0.0, false, false)
	var raid := _place_near_raid(flight)
	var attack_id: String = raid.id
	var nav: int = flight.target
	_expect(flight.fire_status().channel == "patrol", "The original automatic fire policy prefers the live patrol encounter")
	if not _expect(not attack_id.is_empty() and flight.select_combat_contact(attack_id)
		and flight.combat_lock_id() == attack_id and flight.target == nav, "Manual lock acquires a different live hostile without altering navigation"):
		return
	var status := flight.fire_status()
	_expect(status.ok and status.channel == "ambient" and status.id == attack_id,
		"The laser aim test resolves the explicitly acquired contact even with a patrol target available")

	var cold := Flight.new()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(flight.snapshot()))
	_expect(cold.restore(saved) and cold.combat_lock_id() == attack_id and cold.target == nav
		and cold.service_offer("radar_mapper").installed, "A live contact lock, navigation and mapper survive a cold round-trip")
	var malformed := saved.duplicate(true)
	malformed.targeting.lock = 123
	_expect(not cold.restore(malformed) and cold.combat_lock_id() == attack_id,
		"A malformed lock record does not partially overwrite the running state")
	var stale := saved.duplicate(true)
	stale.targeting.lock = "departed-ship"
	_expect(cold.restore(stale) and cold.combat_lock_id().is_empty(), "A vanished contact does not become a phantom lock after restore")

	var patrol_hull: float = flight.patrol.enemy_hull
	var shots := 0
	while shots < 8 and not flight.combat_lock_id().is_empty():
		raid = flight.ambient_status()
		_aim(flight, raid.position)
		if not flight.fire_action():
			flight._advance_background_clock(0.3)
		else:
			shots += 1
			flight._advance_background_clock(1.25)
		if flight.orbit_time > 56.0:
			break
	_expect(shots > 0 and flight.patrol.enemy_hull == patrol_hull and flight.target == nav,
		"Only the acquired opponent takes damage and the navigation selection stays unchanged")
	_expect(not flight.ambient_status().hostile and flight.combat_lock_id().is_empty(),
		"Destroying the acquired ship releases the explicit lock")
	cold.restore(saved)
	cold.position += Vector3.BACK * 1700.0
	_expect(cold.combat_lock_id().is_empty(), "A ship leaving scanner range releases the lock")
	cold.restore(saved)
	cold.jump_seconds_left = 0.5
	_expect(cold.combat_lock_id().is_empty(), "A jump charge closes the old in-system lock")


func _test_scanner_touch() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := Game.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight.credits = 1500
	var hud: CanvasLayer = game._hud
	await process_frame
	_tap(viewport, hud._actions["services"])
	await process_frame
	_tap(viewport, game._services._mining_toggle)
	await process_frame
	_tap(viewport, game._services._equipment_tabs[PortServices.EquipmentPage.NAVIGATION])
	await process_frame
	_tap(viewport, game._services._action_buttons["radar_mapper"])
	_expect(game.flight.service_offer("radar_mapper").installed, "The actual touch equipment page can install the radar mapper")
	game._close_services()
	Fixture.launch(game.flight)
	var raid := _place_near_raid(game.flight)
	var attack_id: String = raid.id
	var nav: int = game.flight.target
	game._update_display(0.0)
	await process_frame
	_tap(viewport, hud._actions["navigation_toggle"])
	await process_frame
	_tap(viewport, hud._actions["scanner_toggle"])
	game._update_display(0.0)
	await process_frame
	var match_index: int = hud._scanner_ids.find(attack_id)
	if _expect(hud.scanner_is_open() and match_index >= 0 and hud._scanner_radar.is_visible_in_tree(),
		"The real touch drawer opens a moving, populated scanner"):
		var list: ItemList = hud._scanner_list
		var touch_point := list.get_global_rect().position + list.get_item_rect(match_index).get_center()
		_touch(viewport, touch_point, true)
		_touch(viewport, touch_point, false)
		_expect(hud._scanner_focus == attack_id and "высота" in hud._scanner_detail.text
			and "корпус" in hud._scanner_detail.text and "м/с" in hud._scanner_detail.text,
			"Selecting a scanner contact shows signed altitude and equipped mapper detail")
		var upper: PackedVector2Array = hud._scanner_radar._contact_points(Vector3(180, 140, -50), Vector2(75, 75), 60.0)
		var lower: PackedVector2Array = hud._scanner_radar._contact_points(Vector3(180, -140, -50), Vector2(75, 75), 60.0)
		_expect(upper[0] == lower[0] and upper[1].y < upper[0].y and lower[1].y > lower[0].y,
			"Equal horizontal vectors get opposite vertical stems above and below")
		_tap(viewport, hud._actions["combat_lock"])
		_expect(game.flight.combat_lock_id() == attack_id and game.flight.target == nav and hud._combat_lock_readout.visible,
			"The touch lock displays an independent combat selection with the original route intact")
		_tap(viewport, hud._actions["combat_unlock"])
		_expect(game.flight.combat_lock_id().is_empty() and game.flight.target == nav and not hud._combat_lock_readout.visible,
			"The touch clear removes the combat selection only")
	_tap(viewport, hud._actions["navigation_close"])
	game._handle_action("camera")
	game._update_display(0.5)
	await process_frame
	var on_screen: Variant = hud._marks._visible_combat.get(attack_id)
	if _expect(on_screen is Vector2, "The real forward scene draws the chosen hostile's touchable mark"):
		_touch(viewport, on_screen, true)
		_touch(viewport, on_screen, false)
		_expect(game.flight.combat_lock_id() == attack_id and game.flight.target == nav,
			"Touching the visible hostile mark selects its live identity")
		game.flight.select_combat_contact("")
		_touch(viewport, on_screen, true)
		game.flight._advance_background_clock(78.0 - game.flight.orbit_time)
		game._update_display(0.0)
		_touch(viewport, on_screen, false)
		_expect(game.flight.combat_lock_id().is_empty(), "A ship disappearing before marker release cannot acquire another target")
	viewport.queue_free()
	await process_frame


func _test_aim_lock_touch() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := Game.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = Flight.new()
	var flight: Flight = game.flight
	var hud: CanvasLayer = game._hud
	game._update_display(0.0)
	await process_frame
	var button: Button = hud._actions.get("aim_lock")
	if not _expect(is_instance_valid(button) and not button.is_visible_in_tree(),
		"Quick lock stays out of the docked touch controls"):
		viewport.queue_free()
		await process_frame
		return

	Fixture.launch(flight)
	var raid := _place_near_raid(flight)
	var attack_id: String = raid.id
	var nav := flight.target
	var credits := flight.credits
	var combat := flight.combat.snapshot()
	game._handle_action("camera")
	hud._marks.ship_markers = false
	game._update_display(0.5)
	await process_frame

	_expect(button.is_visible_in_tree() and not button.disabled,
		"An in-range hostile offers a one-touch quick lock with ship labels hidden")
	_expect(Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(button.get_global_rect()),
		"Quick lock fits the landscape viewport next to the combat controls")
	var touch_point := button.get_global_rect().get_center()
	_touch(viewport, touch_point, true)
	flight.yaw += PI * 0.25
	game._update_display(0.0)
	_touch(viewport, touch_point, false)
	_expect(flight.combat_lock_id().is_empty(),
		"Turning away between touch and release does not acquire a stale target")

	_aim(flight, raid.position)
	game._update_display(0.0)
	await process_frame
	_tap(viewport, button)
	_expect(flight.combat_lock_id() == attack_id and flight.target == nav and hud._combat_lock_readout.visible,
		"One touch acquires the hostile in the reticle without changing the route")
	_expect(flight.credits == credits and flight.combat.snapshot() == combat and flight.ambient_status().hull == raid.hull,
		"Quick lock consumes no funds or ammo and does not fire at the target")

	flight.yaw += PI * 0.25
	game._update_display(0.0)
	game._handle_action("aim_lock")
	_expect(flight.combat_lock_id() == attack_id and flight.target == nav,
		"Requesting lock on an empty reticle keeps the previous valid lock and route")

	flight.select_combat_contact("")
	_aim(flight, raid.position)
	game._update_display(0.0)
	var period := InputEventKey.new()
	period.pressed = true
	period.physical_keycode = KEY_PERIOD
	viewport.push_input(period, true)
	_expect(flight.combat_lock_id() == attack_id, "The period key uses the same forward targeting rule")

	flight.select_combat_contact("")
	game._handle_action("camera")
	game._update_display(0.5)
	game._handle_action("aim_lock")
	_expect(not button.is_visible_in_tree() and flight.combat_lock_id().is_empty(),
		"The rear camera offers no quick lock and the direct action acquires nothing")
	viewport.queue_free()
	await process_frame


func _place_near_raid(flight: Flight) -> Dictionary:
	flight._advance_background_clock(40.5 - flight.orbit_time)
	var raid := flight.ambient_status()
	flight.position = raid.position + Vector3(0, -38, 100)
	flight.velocity = Vector3.ZERO
	_aim(flight, raid.position)
	return raid


func _aim(flight: Flight, target: Vector3) -> void:
	var aim := flight.position.direction_to(target)
	flight.yaw = atan2(-aim.x, -aim.z)
	flight.pitch = clampf(asin(aim.y), -Flight.MAX_PITCH, Flight.MAX_PITCH)
	flight.roll = 0.0


func _tap(viewport: SubViewport, button: Button) -> void:
	var point := button.get_global_rect().get_center()
	_touch(viewport, point, true)
	_touch(viewport, point, false)


func _touch(viewport: SubViewport, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 3
	event.position = point
	event.pressed = pressed
	viewport.push_input(event, true)


func _expect(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
	return condition
