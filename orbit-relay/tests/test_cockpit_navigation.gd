extends SceneTree

const CockpitContacts := preload("res://scripts/cockpit_contacts.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Game := preload("res://main.tscn")

var _checks := 0
var _failures: Array[String] = []


class Sightline extends RefCounted:
	var target := 2
	var positions := {0: Vector3(0, 0, -80), 2: Vector3(0, 0, -450)}

	func target_position(site: int) -> Vector3:
		return positions[site]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := Game.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	_expect(game._hud._marks.navigation.is_empty() and game._hud._actions["navigation_toggle"].disabled,
		"The normal berthed startup suppresses screen marks and the in-flight drawer")
	Fixture.launch(game.flight)
	game.flight.ship.set_autopilot_fitted(false)
	game.flight.position = Vector3(0, 80, 320)
	game.flight.yaw = 0.0
	game.flight.pitch = 0.0
	game.flight.roll = 0.0
	game._handle_action("camera")
	game._update_display(0.5)
	await process_frame
	game._update_display(0.0)

	var hud: CanvasLayer = game._hud
	var list: ItemList = hud._navigation_list
	_tap(viewport, hud._actions["navigation_toggle"].get_global_rect().get_center(), 1)
	await process_frame
	_expect(hud._navigation_drawer.visible and list.item_count == game.flight.local_targets().size(),
		"The actual HUD touch shortcut opens the current-system list without requiring autopilot")
	var row := list.get_item_rect(2).get_center() + list.get_global_rect().position
	_tap(viewport, row, 1)
	_expect(game.flight.target == hud._navigation_sites[2] and not hud._navigation_drawer.visible,
		"Tapping the second non-default body in the live list assigns its nav ID and closes the list")

	var toggle: Button = hud._actions["navigation_toggle"]
	_tap(viewport, toggle.get_global_rect().get_center(), 1)
	await process_frame
	var labels: Button = hud._actions["object_labels"]
	_tap(viewport, labels.get_global_rect().get_center(), 1)
	_expect(not hud._marks.object_labels and hud._marks.flight and game._view._ship.is_inside_tree(),
		"The separate label toggle retains cockpit instruments and world scene")
	_tap(viewport, hud._actions["navigation_close"].get_global_rect().get_center(), 1)
	await process_frame
	game._update_display(0.0)

	var markers: Array[Dictionary] = hud._marks.navigation
	var other := _other_marker(markers, game.flight.target)
	if _expect(not other.is_empty(), "Unlabeled non-active bodies still have visible selectable icons"):
		await _test_marker_touch(viewport, game, other)

	var camera: Camera3D = game._view.camera
	camera.global_transform = Transform3D.IDENTITY
	_test_occlusion(camera)
	viewport.queue_free()
	await process_frame
	print("Cockpit navigation: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_marker_touch(viewport: SubViewport, game: Node, mark: Dictionary) -> void:
	var hud: CanvasLayer = game._hud
	var before: int = game.flight.target
	var point: Vector2 = mark.screen
	var steer: Vector2 = hud._steer.get_global_rect().get_center() + Vector2(30, -20)
	_touch(viewport, steer, true, 2)
	var course: Vector2 = hud.move_input()
	_touch(viewport, point, true, 3)
	_touch(viewport, point, false, 3, true)
	_expect(game.flight.target == before and not course.is_zero_approx() and hud.move_input() == course,
		"Cancelled marker input leaves both navigation and held steering unchanged")
	_touch(viewport, point, true, 3)
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.position = point + Vector2(36, 0)
	viewport.push_input(drag, true)
	_touch(viewport, point, false, 3)
	_expect(game.flight.target == before and hud.move_input() == course,
		"Dragging away and back cannot commit a marker tap")
	_touch(viewport, point, true, 3)
	game.flight.jump_seconds_left = 0.5
	_touch(viewport, point, false, 3)
	_expect(game.flight.target == before, "A maneuver beginning before release invalidates the visible marker")
	game.flight.jump_seconds_left = 0.0
	_tap(viewport, point, 3)
	_expect(game.flight.target == int(mark.id) and hud.move_input() == course,
		"An independent marker tap selects the visible body while the other finger keeps steering")
	_touch(viewport, steer, false, 2)
	_expect(hud.move_input().is_zero_approx(), "Releasing the steering finger resets the control normally")
	await process_frame


func _test_occlusion(camera: Camera3D) -> void:
	var scene := Sightline.new()
	var sites := [0, 2]
	var markers := CockpitContacts.project(scene, camera, sites)
	_expect(markers.size() == 1 and markers[0].id == 0 and not CockpitContacts.is_visible(scene, camera, sites, 2),
		"The near hull blocks projection and release validation of a body directly behind it")
	scene.positions[0] = Vector3(100, 0, -80)
	_expect(CockpitContacts.is_visible(scene, camera, sites, 2),
		"Moving the hull off the viewing ray restores the body marker")
	scene.positions[2] = Vector3(0, 0, 150)
	_expect(not CockpitContacts.is_visible(scene, camera, sites, 2),
		"A body behind the camera has no selectable projection")


func _other_marker(markers: Array[Dictionary], active: int) -> Dictionary:
	for marker: Dictionary in markers:
		if marker.id != active:
			return marker
	return {}


func _tap(viewport: SubViewport, point: Vector2, index: int) -> void:
	_touch(viewport, point, true, index)
	_touch(viewport, point, false, index)


func _touch(viewport: SubViewport, point: Vector2, pressed: bool, index: int, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	viewport.push_input(event, true)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
