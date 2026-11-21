extends SceneTree

const Fixture = preload("res://tests/flight_fixture.gd")

const OrbitRelay := preload("res://main.tscn")
const Flight := preload("res://scripts/flight_sim.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Patrol := preload("res://scripts/patrol_encounter.gd")
const Settings := preload("res://scripts/display_settings.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const DEFAULTS := {
	"quality": 1, "sensitivity": 1, "layout": 0, "notification_volume": 2,
	"invert_yaw": 0, "invert_pitch": 0,
}

var _viewport: SubViewport
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_preferences()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.own_world_3d = true
	root.add_child(_viewport)
	await _test_settings_scene()
	await _test_pilot_axes_scene()
	await _test_journal_scene()
	print("Presentation integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_preferences() -> void:
	var settings := Settings.new()
	_expect(settings.snapshot() == DEFAULTS and settings.fps_limit() == 60,
		"New installations use the balanced preset and normal controls")
	_expect(settings.change("quality", 0) and settings.fps_limit() == 30,
		"The economy preset caps rendering at 30 FPS")
	_expect(settings.change("quality", 2) and settings.fps_limit() == 60,
		"The detail preset caps rendering at 60 FPS")
	_expect(settings.change("sensitivity", 0) and settings.change("layout", 1)
		and settings.change("notification_volume", 3),
		"The preference model accepts precise sensitivity, mirrored controls and louder cues")
	_expect(settings.change("invert_yaw", 1) and settings.invert_pitch == 0,
		"Changing the horizontal axis leaves the vertical setting alone")
	_expect(settings.change("invert_pitch", 1) and settings.invert_yaw == 1,
		"Changing the vertical axis leaves the horizontal setting alone")
	var changed := settings.snapshot()
	for invalid: Variant in [null, [], {"quality": 2}, {"quality": 2, "sensitivity": 1, "layout": 1, "extra": 1},
		{"quality": 3, "sensitivity": 1, "layout": 1}, {"quality": 0, "sensitivity": 1.25, "layout": 0},
		{"quality": 0, "sensitivity": 1, "layout": true}]:
		_expect(not settings.restore(invalid) and settings.snapshot() == changed,
			"Malformed preferences are rejected atomically")
	_expect(not settings.change("unknown", 0) and not settings.change("quality", -1) and settings.snapshot() == changed,
		"Invalid live selections leave all existing choices intact")
	for malformed_volume: Variant in [-1, 4, true, 1.5, "2"]:
		var invalid := changed.duplicate()
		invalid.notification_volume = malformed_volume
		_expect(not settings.restore(invalid) and settings.snapshot() == changed,
			"Out-of-range, fractional and nonnumeric volume values are rejected atomically")
	for axis: String in ["invert_yaw", "invert_pitch"]:
		for value: Variant in [-1, 2, true, 0.5, "1"]:
			var invalid := changed.duplicate()
			invalid[axis] = value
			_expect(not settings.restore(invalid) and settings.snapshot() == changed,
				"An invalid %s preference changes none of the saved choices" % axis)
	var path := "user://presentation-integration-%d.json" % OS.get_process_id()
	var previous_flight := SessionIO.load_state()
	_expect(settings.save_preferences(path) == OK, "Preferences write their own JSON file")
	var reloaded := Settings.new()
	_expect(reloaded.load_preferences(path) and reloaded.snapshot() == changed,
		"A fresh preference object restores all choices including both axes")
	_expect(SessionIO.save_state({"quality": 0, "sensitivity": "fast", "layout": 0}, path) == OK,
		"Write a valid JSON file with invalid preference values")
	_expect(not reloaded.load_preferences(path) and reloaded.snapshot() == changed,
		"An invalid on-disk preference record applies none of its values")
	var legacy := {"quality": 0, "sensitivity": 2, "layout": 1}
	_expect(SessionIO.save_state(legacy, path) == OK and reloaded.load_preferences(path)
		and reloaded.snapshot() == legacy.merged({"notification_volume": 2, "invert_yaw": 0, "invert_pitch": 0}),
		"An older three-field file migrates with the normal axes and notification level")
	var version_095 := legacy.merged({"notification_volume": 3})
	_expect(SessionIO.save_state(version_095, path) == OK and reloaded.load_preferences(path)
		and reloaded.snapshot() == version_095.merged({"invert_yaw": 0, "invert_pitch": 0}),
		"A 0.95 preference file preserves existing choices and defaults both axes")
	_expect(SessionIO.load_state() == previous_flight, "Preference I/O leaves the existing flight record untouched")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".previous")


func _test_settings_scene() -> void:
	var game := _open_game()
	game.flight = Flight.new()
	game.flight.credits = 178
	game.flight.ship.hull = 73.0
	game.flight.select_target(3)
	game.presentation.restore(DEFAULTS)
	game._apply_presentation()
	game._update_display(0.0)
	await process_frame
	_expect(game._view._visual_profile == 1 and _viewport.msaa_3d == Viewport.MSAA_2X,
		"Balanced presentation configures the real view and viewport")
	_expect(SessionIO.save_state(game.flight.snapshot()) == OK, "Write a docked flight before changing visual choices")
	var flight_before := SessionIO.load_state()
	_tap(game._hud._actions.get("settings"), "Open settings using the dock HUD")
	await process_frame
	_expect(game._settings.is_open() and not game._hud._input_enabled, "The settings sheet captures flight input")
	var elapsed: float = game.flight.orbit_time
	game._physics_process(0.5)
	_expect(game.flight.orbit_time == elapsed, "Presentation changes pause simulation time while the sheet is open")
	_tap(game._settings._choice_buttons["quality"][2], "Select the detail preset by touch")
	_expect(game.presentation.quality == 2 and game._view._visual_profile == 2 and _viewport.msaa_3d == Viewport.MSAA_4X,
		"The live scene applies the detail preset and four-sample MSAA")
	_tap(game._settings._choice_buttons["quality"][0], "Select the economy preset by touch")
	_expect(game.presentation.quality == 0 and game._view._visual_profile == 0 and _viewport.msaa_3d == Viewport.MSAA_DISABLED,
		"The economy preset disables MSAA and changes the live scene profile")
	if DisplayServer.get_name() != "headless":
		_expect(Engine.max_fps == 30, "The desktop-rendered economy preset actually applies the frame cap")
	_tap(game._settings._choice_buttons["layout"][1], "Move the action column to the left using a real touch")
	_tap(game._settings._choice_buttons["sensitivity"][0], "Select precise steering using a real touch")
	_tap(game._settings._choice_buttons["notification_volume"][1], "Select quiet notification cues using a real touch")
	_tap(game._settings._choice_buttons["invert_yaw"][1], "Toggle horizontal inversion using a real touch")
	_expect(game.presentation.invert_yaw == 1 and game.presentation.invert_pitch == 0,
		"Horizontal inversion remains independent in the settings scene")
	_tap(game._settings._choice_buttons["invert_pitch"][1], "Toggle vertical inversion using a real touch")
	var saved_settings: Dictionary = game.presentation.snapshot()
	_expect(saved_settings == {"quality": 0, "sensitivity": 0, "layout": 1, "notification_volume": 1,
		"invert_yaw": 1, "invert_pitch": 1}
		and game._audio.level == 1,
		"The accepted choices are reflected in the running game")
	_expect(SessionIO.load_state() == flight_before and not flight_before.has("quality"),
		"Changing presentation leaves both in-progress flight values and the schema independent")
	_press_escape()
	await process_frame
	_expect(not game._settings.is_open() and game._hud._input_enabled, "Escape closes settings and resumes HUD input")
	game.queue_free()
	await process_frame

	game = _open_game()
	await process_frame
	_expect(game.presentation.snapshot() == saved_settings and game._view._visual_profile == 0
		and _viewport.msaa_3d == Viewport.MSAA_DISABLED and game._audio.level == 1,
		"Reopening the application restores the saved view preset and cue level")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(game.flight.snapshot()))
	_expect(restored == flight_before and restored.schema == Flight.SAVE_SCHEMA,
		"Cold start restores the unchanged docked flight alongside the preferences")
	_tap(game._hud._actions.get("dock"), "Request departure after restarting with mirrored settings")
	_expect(Fixture.await_departure(game.flight, 15.0, game._physics_process), "The normal departure sequence works with mirrored settings")
	game._update_display(0.0)
	await process_frame
	_check_layout(game._hud, true, "1280×720 mirrored")
	var touchdown_throttle: float = game.flight.throttle
	_tap(game._hud._actions.get("throttle_up"), "Increase throttle from the mirrored left action column")
	_expect(game.flight.throttle > touchdown_throttle, "The moved throttle control reaches normal flight simulation")
	var precise := _steering_probe(game._hud)
	var precise_roll := _roll_probe(game._hud)

	_tap(game._hud._actions.get("settings"), "Open settings while flying")
	await process_frame
	_tap(game._settings._choice_buttons["layout"][0], "Restore the standard control layout")
	_tap(game._settings._choice_buttons["sensitivity"][2], "Select the faster steering preset")
	_tap(game._settings._close_button, "Close the settings sheet through its real close button")
	await process_frame
	_check_layout(game._hud, false, "1280×720 standard")
	var fast := _steering_probe(game._hud)
	var fast_roll := _roll_probe(game._hud)
	_expect(precise > 0.05 and fast > precise * 1.45 and fast <= 1.0,
		"The same indexed steering movement produces faster response in the fast preset")
	_expect(precise_roll > 0.05 and fast_roll > precise_roll * 1.45 and fast_roll <= 1.0,
		"The same indexed roll movement respects the touch sensitivity preset")
	_expect(_keyboard_steering(game._hud).is_equal_approx(Vector2(0.0, 1.0)),
		"The fast preset leaves digital keyboard steering at its original value")
	_viewport.size = Vector2i(1600, 720)
	await process_frame
	_check_layout(game._hud, false, "1600×720 standard")
	var steer: Control = game._hud._steer
	var held_at := steer.get_global_rect().get_center() + Vector2(20.0, -9.0)
	_touch(33, held_at, true)
	_expect(game._hud.move_input().length() > 0.05, "Verify a pointer command is held before changing hands")
	_tap(game._hud._actions.get("settings"), "Open settings with a flight pointer held")
	await process_frame
	_tap(game._settings._choice_buttons["layout"][1], "Mirror controls on the wide viewport")
	_tap(game._settings._close_button, "Resume flight after mirroring the wide viewport")
	_touch(33, held_at, false)
	await process_frame
	_expect(game._hud.move_input().is_zero_approx(), "Changing layout clears held controls instead of retaining steering")
	_check_layout(game._hud, true, "1600×720 mirrored")
	game.queue_free()
	await process_frame


func _test_pilot_axes_scene() -> void:
	_viewport.size = Vector2i(854, 480)
	var game := _open_game()
	game.presentation.restore(DEFAULTS)
	game._apply_presentation()
	await process_frame
	_tap(game._hud._actions.get("settings"), "Open settings in a compact landscape viewport")
	await process_frame
	var visible := _viewport.get_visible_rect().grow(0.5)
	for button: Button in game._settings._buttons:
		_expect(visible.encloses(button.get_global_rect()) and button.size.y >= 40.0,
			"The compact settings screen fits the full touch target for %s" % button.text)
	for hint: Label in game._settings._descriptions.values():
		_expect(visible.encloses(hint.get_global_rect()), "The compact settings screen keeps each setting description visible")
	_tap(game._settings._close_button, "Close the compact settings sheet")
	_viewport.size = Vector2i(1280, 720)
	await process_frame

	for use_keyboard: bool in [false, true]:
		var source := "Keyboard" if use_keyboard else "Touch pad"
		var normal := _manual_turn(game, 0, 0, use_keyboard)
		_expect(normal.x < -0.005 and normal.y > 0.005,
			"%s reaches both manual ship rotation axes" % source)
		_expect(_manual_turn(game, 1, 0, use_keyboard).is_equal_approx(Vector2(-normal.x, normal.y)),
			"%s reverses only yaw with horizontal inversion" % source)
		_expect(_manual_turn(game, 0, 1, use_keyboard).is_equal_approx(Vector2(normal.x, -normal.y)),
			"%s reverses only pitch with vertical inversion" % source)
		_expect(_manual_turn(game, 1, 1, use_keyboard).is_equal_approx(-normal),
			"%s reverses both axes when both options are enabled" % source)

	var normal_motion := _translation_and_roll(game, 0)
	_expect(absf(normal_motion.w) > 0.005 and Vector3(normal_motion.x, normal_motion.y, normal_motion.z).length() > 0.05
		and _translation_and_roll(game, 1).is_equal_approx(normal_motion),
		"Pilot axis inversion preserves independent roll and lateral thrust")
	var normal_autopilot := _autopilot_facing(game, 0)
	_expect(normal_autopilot.is_equal_approx(_autopilot_facing(game, 1)),
		"Steering inversion leaves the autopilot's commands unchanged")
	game.queue_free()
	await process_frame


func _manual_turn(game: Node, yaw_mode: int, pitch_mode: int, use_keyboard: bool) -> Vector2:
	var pilot := _airborne_pilot(game, yaw_mode, pitch_mode)
	var area: Rect2 = game._hud._steer.get_global_rect()
	var neutral := area.get_center() - Vector2(0.0, 9.0)
	var position := neutral + Vector2(area.size.x * 0.18, -area.size.y * 0.16)
	if use_keyboard:
		_key_event(KEY_D, true)
		_key_event(KEY_W, true)
	else:
		_touch(34, position, true)
	game._physics_process(Fixture.STEP)
	if use_keyboard:
		_key_event(KEY_D, false)
		_key_event(KEY_W, false)
	else:
		_touch(34, position, false)
	return Vector2(pilot.yaw, pilot.pitch)


func _translation_and_roll(game: Node, inversion: int) -> Vector4:
	var pilot := _airborne_pilot(game, inversion, inversion)
	var before := pilot.velocity
	for key: Key in [KEY_6, KEY_8, KEY_E]:
		_key_event(key, true)
	game._physics_process(Fixture.STEP)
	for key: Key in [KEY_6, KEY_8, KEY_E]:
		_key_event(key, false)
	var movement := pilot.velocity - before
	return Vector4(movement.x, movement.y, movement.z, pilot.roll)


func _autopilot_facing(game: Node, inversion: int) -> Basis:
	var pilot := _airborne_pilot(game, inversion, inversion)
	pilot.select_target(1)
	pilot.set_autopilot(true)
	game._physics_process(0.15)
	_expect(pilot.autopilot and not pilot.attitude().is_equal_approx(Basis.IDENTITY),
		"The real route autopilot remains active and rotates the ship")
	return pilot.attitude()


func _airborne_pilot(game: Node, yaw_mode: int, pitch_mode: int) -> Flight:
	game.presentation.change("invert_yaw", yaw_mode)
	game.presentation.change("invert_pitch", pitch_mode)
	var pilot := Flight.new()
	Fixture.launch(pilot)
	pilot.yaw = 0.0
	pilot.pitch = 0.0
	pilot.roll = 0.0
	game.flight = pilot
	game._update_display(0.0)
	return pilot


func _test_journal_scene() -> void:
	var game := _open_game()
	var flight := Flight.new()
	game.flight = flight
	_expect(flight.accept_courier("relay_calibration") and flight.patrol_action(), "Prepare concurrent saved courier and patrol tasks")
	_expect(flight.select_target(3), "Start with a local navigation plan different from the next courier stop")
	game._update_display(0.0)
	await process_frame
	_tap(game._hud._actions.get("journal"), "Open the journal through the real HUD")
	await process_frame
	_expect(game._journal.is_open() and not game._hud._input_enabled, "The journal opens as a flight-input modal")
	var title: String = game._journal._delivery_title.text
	var delivery_stops: String = " ".join(_visible_labels(game._journal))
	_expect(not title.is_empty() and "Тихий порт" in delivery_stops and "Перевал" in delivery_stops,
		"The actual courier displays both ordered ports in the journal")
	_expect(not game._journal._patrol_step.text.is_empty() and flight.patrol.phase == Patrol.OUTBOUND,
		"The journal also displays the independently active patrol")
	var courier_leg := flight.contract_leg
	_tap(game._journal._follow_buttons["delivery"], "Follow the displayed local courier destination")
	await process_frame
	_expect(not game._journal.is_open() and flight.planned_target == 1 and flight.contract_leg == courier_leg
		and flight.credits == 0, "Following a courier sets its port without advancing or paying the contract")
	_tap(game._hud._actions.get("dock"), "Request departure with concurrent journal tasks")
	_expect(Fixture.await_departure(flight, 15.0, game._physics_process), "The departure completes with both tasks still active")
	game._update_display(0.0)
	await process_frame
	_tap(game._hud._actions.get("journal"), "Open the journal from flight again")
	await process_frame
	_tap(game._journal._follow_buttons["patrol"], "Follow an active local patrol from the journal")
	_expect(flight.patrol_course and flight.patrol.phase == Patrol.OUTBOUND and flight.credits == 0,
		"Following a local patrol enables course assistance without accepting it again")

	var remote := _with_remote_dock(flight.snapshot())
	if _expect(remote != null, "Restore the same active tasks while docked in a remote system"):
		game.flight = remote
		game._update_display(0.0)
		await process_frame
		_tap(game._hud._actions.get("journal"), "Open the journal in the remote system")
		await process_frame
		_tap(game._journal._follow_buttons["delivery"], "Plan an interstellar route from a remote courier entry")
		_expect(remote.jump_target == Catalog.HOME_SYSTEM and remote.system_id == Catalog.FRINGE_SYSTEM
			and remote.docked == Catalog.FRINGE_ARRIVAL_PORT and remote.credits == 0,
			"Remote follow plans the next system without launching or jumping automatically")
		remote.jump_target = -1
		game._update_display(0.0)
		await process_frame
		_tap(game._hud._actions.get("journal"), "Reopen the journal from a remote dock")
		await process_frame
		_tap(game._journal._follow_buttons["patrol"], "Plan a return jump to the active patrol from a remote dock")
		_expect(remote.jump_target == Catalog.HOME_SYSTEM and remote.patrol.phase == Patrol.OUTBOUND and remote.credits == 0,
			"Remote patrol follow preserves progress and sets only the return jump plan")

	game.flight = Flight.new()
	game._update_display(0.0)
	await process_frame
	_tap(game._hud._actions.get("journal"), "Open an empty journal with no contracts")
	await process_frame
	for kind in ["delivery", "patrol"]:
		var follow: Button = game._journal._follow_buttons[kind]
		_expect(follow.disabled or not follow.is_visible_in_tree(), "Empty journal cannot begin a %s task" % kind)
	_press_escape()
	_expect(not game._journal.is_open() and game.flight.contract_stage == 0 and game.flight.patrol.phase == Patrol.IDLE,
		"Closing the journal leaves an idle flight idle")
	game.queue_free()
	await process_frame


func _open_game() -> Node:
	var game := OrbitRelay.instantiate()
	_viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game._update_display(0.0)
	return game


func _with_remote_dock(active: Dictionary) -> Flight:
	var flight := Flight.new()
	var port := Catalog.FRINGE_ARRIVAL_PORT
	var contact := flight.docking_position(port)
	active.merge({"system_id": Catalog.FRINGE_SYSTEM, "docked": port, "target": port,
		"position": [contact.x, contact.y, contact.z], "velocity": [0.0, 0.0, 0.0],
		"frame": flight.frame.snapshot(),
		"planned_target": -1, "jump_target": -1, "dock_access": flight.dock_access.snapshot()}, true)
	return flight if flight.restore(active) else null


func _check_layout(hud: CanvasLayer, mirrored: bool, label: String) -> void:
	var steer: Rect2 = hud._steer.get_global_rect()
	var roll: Rect2 = hud._bank.get_global_rect()
	var throttle: Rect2 = hud._actions["throttle_up"].get_global_rect()
	var half := _viewport.get_visible_rect().size.x * 0.5
	_expect((steer.get_center().x > half) == mirrored and (roll.get_center().x > half) == mirrored
		and (throttle.get_center().x < half) == mirrored, "%s keeps steering and actions on opposite sides" % label)
	var regions: Array[Rect2] = [steer, roll]
	for button: Button in hud._actions.values():
		if button.is_visible_in_tree():
			regions.append(button.get_global_rect())
	var visible := _viewport.get_visible_rect().grow(0.5)
	var usable := true
	for index in range(regions.size()):
		usable = usable and visible.encloses(regions[index]) and regions[index].size.y >= 40.0
		for other in range(index):
			usable = usable and not regions[index].intersects(regions[other])
	_expect(usable, "%s keeps all touch targets in bounds and separate" % label)


func _steering_probe(hud: CanvasLayer) -> float:
	var area: Rect2 = hud._steer.get_global_rect()
	var start := area.get_center() - Vector2(0.0, 9.0)
	var end := start + Vector2(area.size.x * 0.12, 0)
	_touch(32, start, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 32
	drag.position = end
	drag.relative = end - start
	_viewport.push_input(drag, true)
	var measured: float = hud.move_input().x
	_touch(32, end, false)
	return measured


func _roll_probe(hud: CanvasLayer) -> float:
	var area: Rect2 = hud._bank.get_global_rect()
	var position := area.get_center() + Vector2(area.size.x * 0.12, -9.0)
	_touch(32, position, true)
	var measured: float = hud.roll_input()
	_touch(32, position, false)
	return measured


func _keyboard_steering(hud: CanvasLayer) -> Vector2:
	_key_event(KEY_W, true)
	var measured: Vector2 = hud.move_input()
	_key_event(KEY_W, false)
	return measured


func _key_event(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _press_escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	_viewport.push_input(event, true)


func _tap(button: Button, description: String) -> void:
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, description):
		return
	var position := button.get_global_rect().get_center()
	_touch(7, position, true)
	_touch(7, position, false)


func _touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	_viewport.push_input(event, true)


func _visible_labels(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node is Label and node.is_visible_in_tree():
		result.append(node.text)
	for child: Node in node.get_children():
		result.append_array(_visible_labels(child))
	return result


func _expect(value: bool, description: String) -> bool:
	_checks += 1
	if not value:
		_failures.append(description)
	return value
