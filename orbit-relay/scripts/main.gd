extends Node

const Flight = preload("res://scripts/flight_sim.gd")
const FlightView = preload("res://scripts/flight_view.gd")
const FlightHUD = preload("res://scripts/flight_hud.gd")
const SectorMap = preload("res://scripts/sector_map.gd")
const SessionIO = preload("res://scripts/session_io.gd")
const SAVE_INTERVAL := 8.0

var flight := Flight.new()
var _view := FlightView.new()
var _hud := FlightHUD.new()
var _map := SectorMap.new()
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
	_build_report_panel()
	_update_display(0.0)
	_io.trace("session_started", {"docked": flight.docked, "deliveries": flight.deliveries})


func _process(delta: float) -> void:
	_update_display(delta)


func _physics_process(delta: float) -> void:
	if _report.visible or _map.is_open():
		return
	flight.update(delta, _hud.move_input(), _hud.roll_input(), _hud.boost_held(), _hud.brake_held())
	_deliver_notice()
	_save_elapsed += delta
	if _save_elapsed >= SAVE_INTERVAL:
		_save()


func _update_display(delta: float) -> void:
	_view.sync(flight, delta)
	_hud.sync(flight, delta)
	var final_approach := flight.autopilot and flight.autopilot_phase in ["Стыковка", "Посадка"]
	var marker := flight.target_contact(flight.target) if final_approach else flight.target_gate(flight.target)
	var in_view := flight.docked < 0 and not flight.landed and not _view.camera.is_position_behind(marker)
	_hud.set_target_marker(_view.camera.unproject_position(marker) if in_view else Vector2.ZERO, in_view and not _report.visible and not _map.is_open())


func _handle_action(action: String) -> void:
	if _report.visible or _map.is_open():
		return
	var throttle_step := 0.025 if flight.position.distance_to(flight.target_position(flight.target)) < 150.0 else 0.1
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
		"map":
			_hud.set_input_enabled(false)
			_map.open(flight)
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
	_io.trace(event, {
		"docked": flight.docked, "landed_site": flight.landed_site, "target": flight.target,
		"planned_target": flight.planned_target, "speed": flight.speed(), "credits": flight.credits,
		"mining_phase": flight.mining.phase, "cargo_units": flight.mining.ore_hold,
	})
	_hud.notify(flight.status_message)
	flight.status_event = ""
	if event in ["launch", "dock", "land", "lift", "contract", "delivery", "mining_deploy", "mining_recover", "mining_ready", "mining_loaded", "ore_sold"]:
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
	var actions := {
		KEY_T: "target", KEY_F: "autopilot", KEY_R: "throttle_up", KEY_V: "throttle_down",
		KEY_ENTER: "dock", KEY_M: "contract", KEY_G: "mine", KEY_B: "sell_ore", KEY_F8: "report",
		KEY_N: "map",
	}
	if actions.has(event.physical_keycode):
		_handle_action(actions[event.physical_keycode])
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _report.visible:
			_close_report()
		elif _map.is_open():
			_close_map()
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
