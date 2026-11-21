extends SceneTree

const ShipSystems := preload("res://scripts/ship_systems.gd")
const Services := preload("res://scripts/port_services.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Camera := preload("res://scripts/flight_camera.gd")

var _checks := 0
var _failures: Array[String] = []


class YardGame extends "res://scripts/main.gd":
	func _save(_keep_backup: bool = false) -> void:
		pass


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := YardGame.new()
	game.show_voyage_menu_on_launch = true
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game._flight_active = true
	game._voyages.close()
	game._hud.set_input_enabled(true)
	var flight := game.flight
	flight.credits = 30000
	flight.ship.hull = 83.0
	game._update_display(0.0)
	await process_frame
	_tap(viewport, game._hud._actions["services"])
	await process_frame
	var yard := game._services
	_tap(viewport, yard._yard_toggle)
	await process_frame
	await _test_yard(viewport, game, yard)
	viewport.queue_free()
	await process_frame
	print("Touch hangar and playable hulls: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(int(not _failures.is_empty()))


func _test_yard(viewport: SubViewport, game: YardGame, yard: Services) -> void:
	var flight := game.flight
	var initial := _offer(yard, ShipSystems.FREIGHTER_HULL)
	if not _expect(yard.is_open() and _inside(viewport, initial.exchange) and _inside(viewport, initial.purchase)
		and not initial.exchange.get_global_rect().intersects(initial.purchase.get_global_rect()),
		"The freighter shows separately tappable trade-in and full-price controls in a landscape viewport"):
		return
	var quote := flight.shipyard_offer(ShipSystems.FREIGHTER_HULL)
	_tap(viewport, initial.purchase)
	_tap(viewport, yard._yard_tabs[Services.YardPage.HANGAR])
	await process_frame
	var stored := flight.shipyard_storage()
	if not _expect(flight.ship.hull_id == ShipSystems.FREIGHTER_HULL and flight.credits == 30000 - int(quote.purchase_cost)
		and stored.size() == 1 and stored[0].hull == ShipSystems.STARTER_HULL
		and "83%" in yard._yard_stored_rows[0].condition.text and not yard._yard_stored_pager.visible,
		"The real purchase parks the old damaged hull, displayed with condition, and charges full price"):
		return
	_expect(flight.shipyard_action("purchase", ShipSystems.STARTER_HULL), "Park another hull through the same yard rules")
	_tap(viewport, yard._yard_tabs[Services.YardPage.OFFERS])
	_go_to_stock_shift(flight, Flight.SHIPYARD_FEATURES_START)
	yard.refresh()
	await process_frame
	_tap(viewport, _offer(yard, ShipSystems.INTERCEPTOR_HULL).purchase)
	if not _expect(flight.ship.hull_id == ShipSystems.INTERCEPTOR_HULL and game._view._ship.name == "InterceptorHull"
		and _paired_exhaust(game._view, 1.18), "The featured interceptor is actually installed and has its own twin-engine model"):
		return
	_go_to_stock_shift(flight, Flight.SHIPYARD_FEATURES_START + 3)
	yard.refresh()
	await process_frame
	_tap(viewport, _offer(yard, ShipSystems.HAULER_HULL).purchase)
	if not _expect(flight.ship.hull_id == ShipSystems.HAULER_HULL and game._view._ship.name == "HaulerHull"
		and _paired_exhaust(game._view, 3.8), "The featured hauler is separately installed and has its own wide-span engines"):
		return
	_expect(flight.shipyard_action("purchase", ShipSystems.STARTER_HULL), "Fill a fifth place with the known hauler")
	_tap(viewport, yard._yard_tabs[Services.YardPage.HANGAR])
	await process_frame
	_expect(yard._yard_stored_position.text == "1 / 3" and yard._yard_stored_status.text.ends_with("5 из 5")
		and yard._yard_stored_prev.disabled, "Five parked hulls are split across three landscape pages")
	_tap(viewport, yard._yard_stored_next)
	await process_frame
	_tap(viewport, yard._yard_stored_next)
	await process_frame
	var last: Dictionary = yard._yard_stored_rows[0]
	if not _expect(yard._yard_stored_position.text == "3 / 3" and yard._yard_stored_next.disabled
		and "Меридиан" in last.title.text and _inside(viewport, last.switch) and _inside(viewport, last.sell),
		"The last page is touch-accessible and addresses the correct parked ship"):
		return
	var credits := flight.credits
	_tap(viewport, last.switch)
	await process_frame
	_expect(flight.ship.hull_id == ShipSystems.HAULER_HULL and flight.credits == credits
		and "Стриж" in last.title.text and flight.shipyard_storage().size() == 5,
		"Touch switching trades the active and stored hull without a charge or losing either hull")
	var sale: Dictionary = flight.shipyard_storage().back()
	_tap(viewport, last.sell)
	await process_frame
	_expect(yard._yard_sale.visible and "Стриж" in yard._yard_sale_summary.text and flight.credits == credits,
		"Selling first opens a confirmation for the addressed hull")
	_tap(viewport, yard._yard_sale_cancel)
	await process_frame
	_expect(not yard._yard_sale.visible and flight.shipyard_storage().size() == 5,
		"Cancel returns to the same hangar page without selling")
	_tap(viewport, last.sell)
	await process_frame
	_tap(viewport, yard._yard_sale_confirm)
	await process_frame
	_expect(flight.credits == credits + int(sale.sell_price) and flight.shipyard_storage().size() == 4
		and yard._yard_stored_position.text == "2 / 2", "Confirmed sale pays the exact quote and clamps a now-empty last page")
	await _test_remote_berth(viewport, flight, yard)
	_tap(viewport, yard._close_button)
	Fixture.launch(flight)
	flight.position = Vector3(1200.0, 500.0, 1000.0)
	flight.change_throttle(0.65)
	game._update_display(0.0)
	_expect(game._view._ship.is_visible_in_tree() and game._view._jets[0].is_visible_in_tree()
		and game._view._jets[1].is_visible_in_tree() and game._view.camera.position.distance_to(flight.position) >= 13.0,
		"The new hauler flies with both engines and its wider exterior camera framing")
	game._view.select_camera_mode(Camera.Mode.COCKPIT)
	game._update_display(0.5)
	var eye: Vector3 = game._view._ship.to_local(game._view.camera.global_position)
	_expect(eye.distance_to(Camera.FREIGHTER_SEAT) < 0.002 and not game._view._ship.visible,
		"The hauler uses the larger cockpit seat through the actual flight camera")


func _test_remote_berth(viewport: SubViewport, flight: Flight, yard: Services) -> void:
	var snapshot := flight.snapshot()
	var velar_berth := 10
	snapshot.ship_hangar.rows[0].port = velar_berth
	if not _expect(flight.restore(snapshot), "Load the same hangar with its first hull at a different licensed port"):
		return
	viewport.size = Vector2i(1600, 720)
	yard.refresh()
	await process_frame
	_tap(viewport, yard._yard_stored_prev)
	await process_frame
	var remote: Dictionary = yard._yard_stored_rows[0]
	var other: Dictionary = yard._yard_stored_rows[1]
	_expect(flight.target_name(velar_berth) in remote.location.text and remote.switch.disabled and remote.sell.disabled
		and _inside(viewport, remote.switch) and _inside(viewport, other.sell) and not other.sell.disabled,
		"The wide phone layout displays the remote berth and disables only that remote hull's actions")


func _go_to_stock_shift(flight: Flight, shift: int) -> void:
	var advance := shift * Flight.SHIPYARD_STOCK_SECONDS + 1.0 - flight.orbit_time
	flight.update(advance, Vector2.ZERO, 0.0, false, false)


func _offer(yard: Services, hull: String) -> Dictionary:
	for row: Dictionary in yard._yard_rows:
		if row.id == hull:
			return row
	return {}


func _paired_exhaust(view: Node3D, separation: float) -> bool:
	return view._jets.size() == 2 and is_equal_approx(view._jets[0].position.distance_to(view._jets[1].position), separation)


func _inside(viewport: SubViewport, button: Button) -> bool:
	return button.is_visible_in_tree() and viewport.get_visible_rect().encloses(button.get_global_rect())


func _tap(viewport: SubViewport, button: Button) -> void:
	var position := button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 4
		touch.position = position
		touch.pressed = pressed
		viewport.push_input(touch, true)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
