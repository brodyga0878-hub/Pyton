extends SceneTree

const Main := preload("res://main.tscn")
const Flight := preload("res://scripts/flight_sim.gd")
const Session := preload("res://scripts/session_io.gd")
const GOOD := "ore"

var _checks := 0
var _failures: Array[String] = []
var _viewport: SubViewport


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.own_world_3d = true
	root.add_child(_viewport)
	await _test_cargo_console()
	_viewport.queue_free()
	await process_frame
	for failure: String in _failures:
		printerr(failure)
	print("Cargo console integration: %d checks, %d failures" % [_checks, _failures.size()])
	quit(int(not _failures.is_empty()))


func _test_cargo_console() -> void:
	var game := Main.instantiate()
	_viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight._launch()
	if not _expect(game.flight.docked < 0 and game.flight.mining.insert_cargo(GOOD, 2),
		"Prepare a real airborne ship whose storage still has room"):
		return
	game.flight.position = Vector3(0, 0, 730)
	game.flight.velocity = Vector3.ZERO
	game.flight.autopilot = false
	game._handle_action("fuel")
	await process_frame
	var console: CanvasLayer = game._services
	if not _expect(console.is_open() and console._discard_row.visible and not console._discard_button.disabled,
		"An airborne ship can select and eject goods through the fuel and cargo console"):
		return
	await _tap(console._discard_button)
	_expect(game.flight.local_cargo_pods().is_empty() and game.flight.mining.cargo_amount(GOOD) == 2,
		"Arming the discard does not move cargo before confirmation")
	await _tap(console._discard_button)
	var pod: Dictionary = game.flight.cargo_pod_status()
	if not _expect(pod.active and game.flight.mining.cargo_amount(GOOD) == 1 and console._cargo_pod_row.visible,
		"Confirming launches a physical one-unit pod and updates the cargo console"):
		return
	var id: int = pod.id
	var mesh: Node3D = game._view._cargo_pod_views.get(id)
	_expect(is_instance_valid(mesh) and mesh.visible and mesh.position.is_equal_approx(pod.position),
		"The flight renderer creates a marked container at its simulated position")
	_expect(console._cargo_pod_collect.disabled, "A ship without the collection module cannot take a pod aboard")
	await _tap(console._cargo_pod_track)
	_expect(not console.is_open() and game.flight.cargo_pod_status().tracking and game._hud._input_enabled,
		"Tracking a container from the menu returns control to the pilot")
	var persisted := Flight.new()
	_expect(persisted.restore(Session.load_state()) and persisted.cargo_pod_status().tracking
		and persisted.cargo_pod_status().id == id, "The tracked physical pod is restored from the real autosave")

	game.flight.ship.fragment_collector = true
	game.flight.position = Vector3(pod.position) + Vector3(0, 0, 3)
	game.flight.velocity = pod.velocity
	game._handle_action("fuel")
	await process_frame
	if not _expect(console.is_open() and not console._cargo_pod_collect.disabled,
		"Matching the pod's position and motion with a fitted collector enables pickup"):
		return
	await _tap(console._cargo_pod_collect)
	_expect(not game.flight.cargo_pod_status().active and game.flight.mining.cargo_amount(GOOD) == 2
		and not console._cargo_pod_row.visible and not game._view._cargo_pod_views.has(id),
		"Pickup returns exactly one original unit and removes the container from the console and scene")


func _tap(button: Button) -> void:
	await process_frame
	if not _expect(button.is_visible_in_tree() and not button.disabled, "Interactive cargo button: " + button.text):
		return
	var at := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 4
		touch.position = at
		touch.pressed = pressed
		_viewport.push_input(touch, true)
	await process_frame


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
