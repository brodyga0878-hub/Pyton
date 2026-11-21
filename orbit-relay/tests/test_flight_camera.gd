extends SceneTree

const Camera := preload("res://scripts/flight_camera.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const OrbitRelay := preload("res://main.tscn")
const Session := preload("res://scripts/session_io.gd")

const TEST_SIZE := Vector2i(1280, 720)
const TRANSITION := Camera.TRANSITION_SECONDS
const POSITION_PRECISION := 0.001
const MANUAL_SAVE := "user://view-without-computer.json"

var _viewport: SubViewport
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_camera_geometry()
	_viewport = SubViewport.new()
	_viewport.size = TEST_SIZE
	_viewport.own_world_3d = true
	root.add_child(_viewport)
	await _test_real_views()
	print("Flight camera integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_camera_geometry() -> void:
	var camera := Camera.new()
	var ship := Transform3D(Basis.from_euler(Vector3(0.18, 0.27, -0.48)), Vector3(660.0, -20.0, 410.0))
	var exterior := ship * Transform3D(Basis.IDENTITY, Vector3(0.4, 4.0, 21.0))
	_expect(camera.sample(ship, exterior, 0.0).is_equal_approx(exterior) and camera.shows_hull()
		and camera.shows_forward_aim() and camera.cockpit_mix == 0.0 and camera.field_of_view == 67.0,
		"Existing outside framing remains the default camera")
	_expect(not camera.select(-1) and not camera.select(3) and not camera.select(Camera.Mode.EXTERIOR),
		"An invalid or already selected camera leaves the current mode untouched")
	if not _expect(camera.select(Camera.Mode.COCKPIT) and camera.transitioning()
		and camera.sample(ship, exterior, 0.0).is_equal_approx(exterior),
		"Selecting the cockpit begins at the current rendered shot without a position jump"):
		return
	var transition := camera.sample(ship, exterior, TRANSITION * 0.5)
	_expect(not transition.is_equal_approx(exterior) and is_equal_approx(camera.cockpit_mix, 0.5)
		and camera.field_of_view > 67.0 and camera.field_of_view < 73.0,
		"Mid-transition eases the actual viewpoint, view angle and canopy alpha")
	if not _expect(camera.select(Camera.Mode.REAR) and camera.sample(ship, exterior, 0.0).is_equal_approx(transition),
		"A rapid change rebases from the current interpolated pose"):
		return
	var turned := camera.sample(ship, exterior, TRANSITION)
	var local := ship.affine_inverse() * turned
	_expect(not camera.transitioning() and local.origin.distance_to(Camera.STARTER_SEAT) < POSITION_PRECISION
		and local.basis.z.dot(Vector3.FORWARD) > 0.9999 and not camera.shows_forward_aim()
		and not camera.shows_hull() and camera.cockpit_mix == 0.0 and camera.field_of_view == 69.0,
		"The rear camera sits in the cabin, looks aft and hides the forward aiming cue")
	camera.select(Camera.Mode.COCKPIT)
	var moved := Transform3D(Basis.from_euler(Vector3(-0.15, 2.87, 0.72)), Vector3(687.0, 32.0, 407.0))
	var cockpit := camera.sample(moved, exterior, TRANSITION, true)
	local = moved.affine_inverse() * cockpit
	_expect(local.origin.distance_to(Camera.FREIGHTER_SEAT) < POSITION_PRECISION and local.basis.is_equal_approx(Basis.IDENTITY)
		and camera.shows_forward_aim() and not camera.shows_hull() and camera.cockpit_mix == 1.0
		and camera.field_of_view == 73.0, "The freighter cockpit follows all ship axes from its own seat")
	camera.cycle()
	camera.cycle()
	_expect(camera.mode == Camera.Mode.EXTERIOR and camera.sample(moved, exterior, 0.0, true, true).is_equal_approx(exterior)
		and camera.shows_hull() and not camera.transitioning(), "A safe release or return snap uses the original exterior instead of a stale cabin pose")


func _test_real_views() -> void:
	var game := OrbitRelay.instantiate()
	_viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = Flight.new()
	var flight: Flight = game.flight
	if not _expect(flight.select_target(1) and Fixture.depart(flight), "Physically undock through the default game's flight model"):
		game.queue_free()
		return
	_aim(flight, flight.target_gate(1))
	game._update_display(TRANSITION)
	await process_frame
	var before := flight.snapshot()
	var camera_button: Button = game._hud._actions.get("camera")
	var fitted: Button = game._hud._actions.get("autopilot")
	if not _expect(is_instance_valid(camera_button) and camera_button.is_visible_in_tree() and not camera_button.disabled
		and game._view._camera_director.mode == Camera.Mode.EXTERIOR and game._view._ship.visible
		and is_instance_valid(fitted) and not fitted.disabled, "The real airborne HUD exposes camera and fitted navigation controls"):
		game.queue_free()
		return
	var normal_center := camera_button.get_global_rect().get_center()
	_tap(camera_button)
	game._update_display(TRANSITION)
	await process_frame
	var cockpit := _relative_camera(game)
	_expect(game._camera_mode == Camera.Mode.COCKPIT and cockpit.origin.distance_to(Camera.STARTER_SEAT) < POSITION_PRECISION
		and game._view._cockpit_canopy.is_visible_in_tree() and not game._view._ship.visible
		and game._view.shows_forward_aim() and game._hud._marks.target_visible
		and game._hud._camera_instrument.is_visible_in_tree() and game._hud._camera_instrument.text.begins_with("Пеленг")
		and not fitted.disabled and flight.snapshot() == before, "Touch opens the live forward cockpit, retains instruments, and changes no flight state")
	_press_camera_shortcut()
	game._update_display(TRANSITION)
	await process_frame
	var rear := _relative_camera(game)
	_expect(game._camera_mode == Camera.Mode.REAR and rear.origin.distance_to(Camera.STARTER_SEAT) < POSITION_PRECISION
		and rear.basis.z.dot(Vector3.FORWARD) > 0.9999 and not game._view.shows_forward_aim()
		and not game._view._cockpit_canopy.is_visible_in_tree() and not game._hud._marks.target_visible
		and not game._hud._marks.forward_aim and not game._hud._camera_instrument.is_visible_in_tree()
		and flight.snapshot() == before, "F1 opens the real aft view from the same seat and excludes the front target without steering")
	var marker := flight.target_gate(1)
	_aim(flight, flight.position - flight.position.direction_to(marker))
	game._update_display(0.0)
	_expect(game._hud._marks.target_visible and not game._view.shows_forward_aim(),
		"A contact actually behind the hull is shown by the rear camera without enabling the forward sight")
	game.presentation.change("layout", 1)
	game._apply_presentation()
	await process_frame
	var mirrored := camera_button.get_global_rect().get_center()
	_expect(absf(mirrored.x + normal_center.x - float(TEST_SIZE.x)) < 3.0 and absf(mirrored.y - normal_center.y) < 5.0
		and not camera_button.disabled, "Camera touch control mirrors with the rest of the flight instruments")
	_tap(camera_button)
	game._update_display(TRANSITION)
	await process_frame
	_expect(game._camera_mode == Camera.Mode.EXTERIOR and game._view._ship.visible and game._view.shows_forward_aim(),
		"The mirrored touch command wraps from rear back to the native exterior view")
	_test_unfitted_camera(game)
	game.queue_free()
	await process_frame


func _test_unfitted_camera(game: Node) -> void:
	var old := Flight.new()
	if not _expect(old.autopilot_equipment_action() and not old.ship.autopilot_fitted
		and Session.save_state(old.snapshot(), MANUAL_SAVE) == OK, "Save a pilot with the navigation computer removed at its actual port"):
		return
	var pilot := Flight.new()
	if not _expect(pilot.restore(Session.load_state(MANUAL_SAVE)) and not pilot.ship.autopilot_fitted and Fixture.depart(pilot),
		"An unfitted cold ship still releases normally into manual flight"):
		return
	game.flight = pilot
	game._update_display(TRANSITION)
	var baseline := pilot.snapshot()
	_tap(game._hud._actions["camera"])
	game._update_display(TRANSITION)
	var navigation: Button = game._hud._actions["autopilot"]
	var velocity_hold: Button = game._hud._actions["speed_hold"]
	_expect(game._camera_mode == Camera.Mode.COCKPIT and game._view._cockpit_canopy.is_visible_in_tree()
		and not game._hud._camera_instrument.is_visible_in_tree() and game._hud._camera_instrument.text.is_empty()
		and navigation.disabled and not velocity_hold.disabled and pilot.snapshot() == baseline,
		"The same real cockpit works with manual speed instrumentation while the missing course computer stays disabled")


func _relative_camera(game: Node) -> Transform3D:
	return game._view._ship.transform.affine_inverse() * game._view.camera.transform


func _aim(flight: Flight, toward: Vector3) -> void:
	var forward := flight.position.direction_to(toward)
	flight.yaw = atan2(-forward.x, -forward.z)
	flight.pitch = clampf(asin(forward.y), -Flight.MAX_PITCH, Flight.MAX_PITCH)


func _tap(button: Button) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 8
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		_viewport.push_input(event, true)


func _press_camera_shortcut() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_F1
		event.pressed = pressed
		_viewport.push_input(event)


func _expect(value: bool, description: String) -> bool:
	_checks += 1
	if not value:
		_failures.append("FAIL: " + description)
	return value
