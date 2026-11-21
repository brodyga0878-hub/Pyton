extends SceneTree

const Game := preload("res://main.tscn")
const Fixture := preload("res://tests/flight_fixture.gd")
const Link := preload("res://scripts/flight_comms_view.gd")

var _checks := 0
var _failures: Array[String] = []


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
	Fixture.launch(game.flight)
	var friendly := _friendly_contact(game.flight)
	if not friendly.is_empty():
		game.flight.position = friendly.position + Vector3.UP * 30.0
	game.flight.ship.fuel = 2.0
	game._update_display(0.0)
	await process_frame
	_tap(viewport, game._hud._actions["comms"])
	var panel: CanvasLayer = game._comms
	if _expect(panel.is_open() and not game._hud._input_enabled and panel._portrait.is_visible_in_tree()
		and "Видеоканал" in panel._title.text, "The live HUD touch opens an animated communication overlay"):
		panel._process(Link.CONNECT_TIME + 0.01)
		_expect(panel._caption.text == "Приём" and panel._portrait.clock >= Link.CONNECT_TIME,
			"The portrait connects and advances independently of flight simulation")
		await process_frame
		var distress: Button = panel._buttons["distress"]
		var point := distress.get_global_rect().get_center()
		_touch(viewport, point, true)
		_touch(viewport, point, false, true)
		_expect(is_equal_approx(game.flight.ship.fuel, 2.0) and not panel._receipt.visible,
			"Canceling the touch does not send an emergency request")
		_tap(viewport, distress)
		_expect(is_equal_approx(game.flight.ship.fuel, 6.0) and panel._receipt.visible
			and "аварийного топлива" in panel._receipt.text and panel._portrait.reply_until > panel._portrait.clock
			and distress.disabled, "A real response transfers fuel and animates the visible receipt")
		_tap(viewport, panel._close)
		_expect(not panel.is_open() and game._hud._input_enabled, "Touch closing the view restores the flight HUD")

	await _call_selected_ship(viewport, game, friendly, panel)
	game.presentation.change("language", 1)
	game._apply_presentation()
	game._update_display(0.0)
	await process_frame
	_tap(viewport, game._hud._actions["comms"])
	_expect(panel.is_open() and panel._title.text.begins_with("Video link")
		and panel._close.text == "End transmission" and game._hud._actions["comms"].text == "Comms",
		"English changes the camera and communication interface through the same preference")
	panel.handle_back()
	viewport.queue_free()
	await process_frame
	print("Flight communications view: %d checks, %d failures" % [_checks, _failures.size()])
	for message: String in _failures:
		printerr(message)
	quit(0 if _failures.is_empty() else 1)


func _call_selected_ship(viewport: SubViewport, game: Node, contact: Dictionary, panel: CanvasLayer) -> void:
	if not _expect(not contact.is_empty(), "A nearby friendly scanner contact exists for the mobile call"):
		return
	var hud: CanvasLayer = game._hud
	_tap(viewport, hud._actions["navigation_toggle"])
	await process_frame
	_tap(viewport, hud._actions["scanner_toggle"])
	game._update_display(0.0)
	await process_frame
	var index: int = hud._scanner_ids.find(contact.id)
	if not _expect(index >= 0 and hud.scanner_is_open(), "The open scanner lists the actual in-range ship"):
		return
	var list: ItemList = hud._scanner_list
	var point := list.get_item_rect(index).get_center() + list.get_global_rect().position
	_touch(viewport, point, true)
	_touch(viewport, point, false)
	_tap(viewport, hud._actions["comms_contact"])
	if _expect(panel.is_open() and panel.contact_id() == contact.id and contact.name in panel._title.text,
		"Tapping a scanner row and Comms opens the addressed ship channel"):
		await process_frame
		var report: Button = panel._buttons["report"]
		_tap(viewport, report)
		_expect(panel._receipt.visible and contact.name in panel._receipt.text,
			"The addressed ship returns its own report rather than the dispatcher view")
		_tap(viewport, panel._close)


func _friendly_contact(flight: RefCounted) -> Dictionary:
	for contact: Dictionary in flight.traffic_contacts():
		if contact.role in ["trader", "patrol"] and not contact.get("hostile", false):
			return contact
	return {}


func _tap(viewport: SubViewport, button: Button) -> void:
	var point := button.get_global_rect().get_center()
	_touch(viewport, point, true)
	_touch(viewport, point, false)


func _touch(viewport: SubViewport, point: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 9
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	viewport.push_input(event, true)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
