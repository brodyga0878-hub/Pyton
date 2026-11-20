extends Node

const Flight = preload("res://scripts/flight_sim.gd")
const FlightView = preload("res://scripts/flight_view.gd")
const FlightHUD = preload("res://scripts/flight_hud.gd")
const SectorMap = preload("res://scripts/sector_map.gd")
const GalaxyMap = preload("res://scripts/galaxy_map.gd")
const PortServices = preload("res://scripts/port_services.gd")
const PortMarket = preload("res://scripts/port_market.gd")
const SessionIO = preload("res://scripts/session_io.gd")
const SAVE_INTERVAL := 8.0

var flight := Flight.new()
var _view := FlightView.new()
var _hud := FlightHUD.new()
var _map := SectorMap.new()
var _galaxy := GalaxyMap.new()
var _services := PortServices.new()
var _market := PortMarket.new()
var _io := SessionIO.new()
var _save_elapsed := 0.0
var _save_error_shown := false
var _report: CenterContainer
var _report_text: Label
var _report_buttons: Array[Button] = []
var _report_touches: Dictionary[int, Button] = {}


func _ready() -> void:
	var saved := SessionIO.load_state()
	if not saved.is_empty():
		_io.trace("load", {"accepted": flight.restore(saved)})
	add_child(_view)
	_view.build()
	add_child(_hud)
	_hud.build()
	_hud.action_requested.connect(_handle_action)
	add_child(_map)
	_map.build()
	_map.destination_selected.connect(_select_destination)
	_map.dismissed.connect(_close_map)
	add_child(_galaxy)
	_galaxy.build()
	_galaxy.destination_selected.connect(_plan_jump)
	_galaxy.jump_requested.connect(_start_jump)
	_galaxy.dismissed.connect(_close_galaxy)
	add_child(_services)
	_services.build()
	_services.service_requested.connect(_service_purchase)
	_services.dismissed.connect(_close_services)
	add_child(_market)
	_market.build()
	_market.trade_requested.connect(_market_trade)
	_market.courier_requested.connect(_accept_courier)
	_market.dismissed.connect(_close_market)
	_build_report_panel()
	_update_display(0.0)
	_io.trace("session_started", {"system_id": flight.system_id, "docked": flight.docked, "deliveries": flight.deliveries})


func _process(delta: float) -> void:
	_update_display(delta)


func _overlay_open() -> bool:
	return _report.visible or _map.is_open() or _galaxy.is_open() or _services.is_open() or _market.is_open()


func _physics_process(delta: float) -> void:
	if _overlay_open():
		return
	flight.update(delta, _hud.move_input(), _hud.roll_input(), _hud.boost_held(), _hud.brake_held())
	_deliver_notice()
	_save_elapsed += delta
	if _save_elapsed >= SAVE_INTERVAL:
		_save()


func _update_display(delta: float) -> void:
	_view.sync(flight, delta)
	_hud.sync(flight, delta)
	var final_approach := flight.autopilot and flight.autopilot_phase in ["Стыковка", "Посадка", "Вход в зону сбора"]
	var marker := flight.target_contact(flight.target) if final_approach else flight.target_gate(flight.target)
	var in_view := flight.docked < 0 and not flight.landed and not _view.camera.is_position_behind(marker)
	if in_view and not flight.autopilot:
		var surface := flight.surface_status()
		in_view = not surface.near or surface.pad
	_hud.set_target_marker(_view.camera.unproject_position(marker) if in_view else Vector2.ZERO, in_view and not _overlay_open() and flight.jump_seconds_left <= 0.0)


func _handle_action(action: String) -> void:
	if _overlay_open():
		return
	if flight.jump_seconds_left > 0.0 and action not in ["throttle_up", "throttle_down"]:
		return
	var near_target := flight.reference_site() >= 0 or flight.position.distance_to(flight.target_position(flight.target)) < 150.0
	var throttle_step := 0.025 if near_target else 0.1
	match action:
		"target":
			flight.change_target()
		"autopilot":
			flight.set_autopilot(not flight.autopilot)
		"throttle_up":
			flight.change_throttle(throttle_step)
		"throttle_down":
			flight.change_throttle(-throttle_step)
		"dock":
			flight.dock_action()
		"contract":
			flight.contract_action()
		"mine":
			flight.mine_action()
		"sell_ore":
			flight.sell_ore_action()
		"scoop":
			flight.scoop_action()
		"time":
			flight.cycle_time_scale()
		"services":
			if flight.docked >= 0:
				_hud.set_input_enabled(false)
				_services.open(flight)
			return
		"market":
			if flight.docked >= 0:
				_hud.set_input_enabled(false)
				_market.open(flight)
			return
		"map":
			_hud.set_input_enabled(false)
			_map.open(flight)
			return
		"galaxy":
			_hud.set_input_enabled(false)
			_galaxy.open(flight)
			return
		"report":
			_open_report()
			return
		_:
			return
	if action in ["target", "autopilot", "throttle_up", "throttle_down"]:
		_io.trace(action, {"target": flight.target, "autopilot": flight.autopilot, "throttle": flight.throttle})
	_deliver_notice()
	if action == "target":
		_save()
	_update_display(0.0)


func _deliver_notice() -> void:
	if flight.status_event.is_empty():
		return
	var event := flight.status_event
	var touchdown := flight.landing_direction
	_io.trace(event, {
		"docked": flight.docked, "landed_site": flight.landed_site, "target": flight.target,
		"planned_target": flight.planned_target, "speed": flight.speed(), "credits": flight.credits,
		"mining_phase": flight.mining.phase, "cargo_units": flight.mining.ore_hold,
		"fuel": flight.ship.fuel, "scooping": flight.scooping,
		"hull": flight.ship.hull, "contract_route": flight.contract_route_id, "contract_leg": flight.contract_leg,
		"system_id": flight.system_id, "jump_target": flight.jump_target,
		"orbit_time": flight.orbit_time, "time_scale": flight.time_scale,
		"offpad": flight.landed_offpad(), "landing_direction": [touchdown.x, touchdown.y, touchdown.z],
	})
	_hud.notify(flight.status_message)
	flight.status_event = ""
	if event in [
		"launch", "dock", "land", "lift", "contract", "delivery", "mining_deploy", "mining_recover",
		"mining_ready", "mining_loaded", "ore_sold", "service_refuel", "service_tank", "service_eco",
		"scoop_full", "scoop_stop", "star_arrival", "fuel_empty",
		"jump_planned", "jump_complete",
		"market_buy", "market_sell", "service_repair", "service_cargo", "hull_damage", "contract_leg",
	]:
		_save()


func _save() -> void:
	_save_elapsed = 0.0
	var result := SessionIO.save_state(flight.snapshot())
	if result != OK and not _save_error_shown:
		_hud.notify("Не удалось сохранить рейс.")
		_io.trace("save_error", {"error": int(result)})
	_save_error_shown = result != OK


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if _report.visible:
		if event.physical_keycode == KEY_ESCAPE:
			_close_report()
		return
	if _map.is_open():
		if event.physical_keycode == KEY_ESCAPE:
			_close_map()
		return
	if _galaxy.is_open():
		if event.physical_keycode == KEY_ESCAPE:
			_close_galaxy()
		return
	if _services.is_open():
		if event.physical_keycode == KEY_ESCAPE:
			_close_services()
		return
	if _market.is_open():
		if event.physical_keycode == KEY_ESCAPE:
			_close_market()
		return
	if event.physical_keycode == KEY_ESCAPE and flight.cancel_jump():
		_deliver_notice()
		get_viewport().set_input_as_handled()
		return
	var actions := {
		KEY_T: "target", KEY_F: "autopilot", KEY_R: "throttle_up", KEY_V: "throttle_down",
		KEY_ENTER: "dock", KEY_M: "contract", KEY_G: "mine", KEY_B: "sell_ore", KEY_F8: "report",
		KEY_N: "map", KEY_J: "galaxy", KEY_K: "scoop", KEY_P: "services", KEY_O: "time", KEY_L: "market",
	}
	if actions.has(event.physical_keycode):
		_handle_action(actions[event.physical_keycode])
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		flight.cancel_jump()
		flight.reset_time_scale()
		_save()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _report.visible:
			_close_report()
		elif _map.is_open():
			_close_map()
		elif _galaxy.is_open():
			_close_galaxy()
		elif _services.is_open():
			_close_services()
		elif _market.is_open():
			_close_market()
		elif flight.cancel_jump():
			_deliver_notice()
		else:
			_save()
			get_tree().quit()


func _build_report_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_report = CenterContainer.new()
	layer.add_child(_report)
	_report.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.015, 0.025, 0.86)
	layer.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.move_child(shade, 0)
	_report.visibility_changed.connect(func(): shade.visible = _report.visible)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101f29")
	style.border_color = Color("547b86")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	_report.add_child(panel)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 12)
	panel.add_child(contents)
	var title := Label.new()
	title.text = "Отчёт о рейсе"
	title.add_theme_font_size_override("font_size", 28)
	contents.add_child(title)
	_report_text = Label.new()
	_report_text.custom_minimum_size = Vector2(490, 80)
	_report_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_report_text.add_theme_font_size_override("font_size", 18)
	contents.add_child(_report_text)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	contents.add_child(buttons)
	_add_report_button(buttons, "Сохранить ZIP", _export_report)
	_add_report_button(buttons, "Копировать текст", _copy_report)
	_add_report_button(buttons, "Закрыть", _close_report)
	_report.hide()


func _add_report_button(parent: Container, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 54)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 17)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	_report_buttons.append(button)


func _input(event: InputEvent) -> void:
	if _report == null or not _report.visible or not event is InputEventScreenTouch:
		return
	var touch := event as InputEventScreenTouch
	if touch.pressed:
		for button in _report_buttons:
			if button.get_global_rect().has_point(touch.position):
				_report_touches[touch.index] = button
				break
	else:
		var button: Button = _report_touches.get(touch.index)
		_report_touches.erase(touch.index)
		if button != null and not touch.canceled and button.get_global_rect().has_point(touch.position):
			button.pressed.emit()
	get_viewport().set_input_as_handled()


func _open_report() -> void:
	_hud.set_input_enabled(false)
	_report_text.text = "В архив входят состояние рейса и журнал последних действий."
	_report.show()


func _select_destination(site_id: int) -> void:
	if not _map.is_open() or not flight.select_target(site_id):
		return
	_close_map()
	_io.trace("route_selected", {"target": site_id})
	_hud.notify("Маршрут проложен. «%s»." % flight.target_name(site_id))
	_save()
	_update_display(0.0)


func _close_map() -> void:
	_map.close()
	_hud.set_input_enabled(true)


func _plan_jump(destination: int) -> void:
	if _galaxy.is_open() and flight.plan_jump(destination):
		_deliver_notice()
		_galaxy.refresh()


func _start_jump() -> void:
	if not _galaxy.is_open():
		return
	if flight.start_jump():
		_close_galaxy()
	else:
		_galaxy.refresh()
	_deliver_notice()
	_update_display(0.0)


func _close_galaxy() -> void:
	_galaxy.close()
	_hud.set_input_enabled(true)


func _service_purchase(action: String) -> void:
	if not _services.is_open():
		return
	flight.service_action(action)
	_deliver_notice()
	_services.refresh()
	_update_display(0.0)


func _close_services() -> void:
	_services.close()
	_hud.set_input_enabled(true)


func _market_trade(good: String, side: String, quantity: int) -> void:
	if _market.is_open() and flight.market_trade(good, side, quantity):
		_deliver_notice()
		_update_display(0.0)
	_market.refresh()


func _accept_courier(route_id: String) -> void:
	if _market.is_open() and flight.accept_courier(route_id):
		_deliver_notice()
		_update_display(0.0)
	_market.refresh()


func _close_market() -> void:
	_market.close()
	_hud.set_input_enabled(true)


func _close_report() -> void:
	_report_touches.clear()
	_report.hide()
	_hud.set_input_enabled(true)


func _export_report() -> void:
	var result := _io.export_report(flight.snapshot())
	if not result.ok:
		_report_text.text = "Не удалось записать архив. Можно скопировать текст отчёта."
		return
	if result.get("public_downloads", false):
		_report_text.text = "Архив сохранён в папке загрузок.\n%s" % result.path
	elif OS.has_feature("android"):
		_report_text.text = "Архив сохранён в памяти игры. %s" % ("Текст отчёта скопирован." if result.get("clipboard_copied", false) else "Можно скопировать текст отчёта.")
	else:
		_report_text.text = "Архив сохранён.\n%s" % result.path


func _copy_report() -> void:
	_report_text.text = "Текст отчёта скопирован." if _io.copy_report_text(flight.snapshot()) else "Буфер обмена сейчас недоступен."
