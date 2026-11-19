extends CanvasLayer

signal service_requested(action: String)
signal dismissed()

const TEXT := Color("e8f4fa")
const MUTED := Color("a5bac7")
const MINT := Color("9debd7")
const BORDER := Color("365561")
const Sector := preload("res://scripts/sector_catalog.gd")

var _sim: RefCounted
var _insets: MarginContainer
var _station: Label
var _balance: Label
var _fuel: Label
var _fuel_level: ProgressBar
var _tariff: Label
var _close_button: Button
var _action_buttons: Dictionary[String, Button] = {}
var _touches: Dictionary[int, Button] = {}


func build() -> void:
	if is_instance_valid(_insets):
		return
	layer = 9
	var shade := ColorRect.new()
	shade.color = Color(0.012, 0.026, 0.04, 0.86)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_insets = MarginContainer.new()
	add_child(_insets)
	_insets.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_insets.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 700.0
	panel.add_theme_stylebox_override("panel", _style(Color("0d1d28"), BORDER, 16, 22))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	_label(header, "Портовые службы", 30, TEXT).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close_button = _button(header)
	_close_button.text = "Закрыть"
	_close_button.custom_minimum_size.x = 126.0
	_close_button.pressed.connect(func() -> void: dismissed.emit())

	var details := HBoxContainer.new()
	content.add_child(details)
	_station = _label(details, "", 20, MINT)
	_station.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_balance = _label(details, "", 20, TEXT)

	var gauge := HBoxContainer.new()
	gauge.add_theme_constant_override("separation", 14)
	content.add_child(gauge)
	_label(gauge, "Топливо", 17, MUTED)
	_fuel_level = ProgressBar.new()
	_fuel_level.show_percentage = false
	_fuel_level.step = 0.0
	_fuel_level.custom_minimum_size.y = 10.0
	_fuel_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fuel_level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fuel_level.add_theme_stylebox_override("background", _style(Color("07121b"), BORDER, 5, 0))
	_fuel_level.add_theme_stylebox_override("fill", _style(Color("398c82"), MINT, 5, 0))
	gauge.add_child(_fuel_level)
	_fuel = _label(gauge, "", 17, TEXT)
	_fuel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fuel.custom_minimum_size.x = 120.0

	_tariff = _add_service(content, "refuel", "Полная заправка", "")
	_add_service(content, "tank", "Увеличенный бак", "Ёмкость 150 ед.")
	_add_service(content, "eco", "Экономичный привод", "Расход топлива ниже на 30%")
	get_viewport().size_changed.connect(_update_insets)
	_update_insets()
	hide()


func open(sim: RefCounted) -> void:
	if sim == null or not Sector.is_port(sim.docked):
		return
	build()
	_sim = sim
	_touches.clear()
	show()
	refresh()


func refresh() -> void:
	if not is_open():
		return
	if not Sector.is_port(_sim.docked):
		dismissed.emit()
		return
	var capacity: float = _sim.ship.capacity()
	var fuel: float = _sim.ship.fuel
	_station.text = _sim.target_name(_sim.docked)
	_balance.text = "Баланс %d кр." % _sim.credits
	_fuel_level.max_value = capacity
	_fuel_level.value = fuel
	_fuel.text = "%s / %d ед." % [("%.1f" % fuel).replace(".", ","), roundi(capacity)]
	_tariff.text = "Тариф порта · %d кр. за ед." % _sim.refuel_unit_price()
	for action: String in _action_buttons:
		var offer: Dictionary = _sim.service_offer(action)
		var button := _action_buttons[action]
		button.disabled = not offer.allowed
		if offer.installed:
			button.text = "Установлено"
		elif action == "refuel" and offer.cost == 0:
			button.text = "Бак полон"
		elif button.disabled:
			button.text = "%d кр. · не хватает средств" % offer.cost
		else:
			var verb := "Заправить" if action == "refuel" else "Установить"
			button.text = "%s · %d кр." % [verb, offer.cost]


func close() -> void:
	_touches.clear()
	_sim = null
	hide()


func is_open() -> bool:
	return _sim != null and visible


func _request_service(action: String) -> void:
	if is_open() and _sim.service_offer(action).allowed:
		# A purchase can change the price shown for another service.
		_touches.clear()
		service_requested.emit(action)


func _add_service(parent: VBoxContainer, action: String, title: String, detail: String) -> Label:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("112631"), Color("263f4b"), 9, 12))
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 1)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(copy)
	_label(copy, title, 20, TEXT)
	var description := _label(copy, detail, 15, MUTED)
	var button := _button(row)
	button.custom_minimum_size.x = 268.0
	button.pressed.connect(_request_service.bind(action))
	_action_buttons[action] = button
	return description


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventScreenTouch:
		var button: Button = _touches.get(event.index)
		_touches.erase(event.index)
		if not event.canceled:
			if event.pressed:
				var hit := _button_at(event.position)
				if hit != null and hit not in _touches.values():
					_touches[event.index] = hit
			elif button != null and not button.disabled and button.get_global_rect().has_point(event.position):
				button.pressed.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var button: Button = _touches.get(event.index)
		if button != null and not button.get_global_rect().has_point(event.position):
			_touches.erase(event.index)
		get_viewport().set_input_as_handled()


func _button_at(point: Vector2) -> Button:
	if _close_button.get_global_rect().has_point(point):
		return _close_button
	for button: Button in _action_buttons.values():
		if not button.disabled and button.get_global_rect().has_point(point):
			return button
	return null


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_touches.clear()


func _update_insets() -> void:
	var insets := Vector4(24, 20, 24, 20)
	if OS.has_feature("android"):
		var window := Vector2(DisplayServer.window_get_size())
		var safe_area := DisplayServer.get_display_safe_area()
		if window.x > 0.0 and window.y > 0.0 and safe_area.has_area():
			var scale := get_viewport().get_visible_rect().size / window
			insets.x += maxf(0.0, safe_area.position.x * scale.x)
			insets.y += maxf(0.0, safe_area.position.y * scale.y)
			insets.z += maxf(0.0, (window.x - safe_area.end.x) * scale.x)
			insets.w += maxf(0.0, (window.y - safe_area.end.y) * scale.y)
	_insets.add_theme_constant_override("margin_left", ceili(insets.x))
	_insets.add_theme_constant_override("margin_top", ceili(insets.y))
	_insets.add_theme_constant_override("margin_right", ceili(insets.z))
	_insets.add_theme_constant_override("margin_bottom", ceili(insets.w))


static func _label(parent: Container, caption: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)
	return label


static func _button(parent: Container) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = 52.0
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", _style(Color("16403d"), Color("4e8b82"), 7, 12))
	button.add_theme_stylebox_override("hover", _style(Color("206058"), MINT, 7, 12))
	button.add_theme_stylebox_override("pressed", _style(Color("143331"), MINT, 7, 12))
	button.add_theme_stylebox_override("disabled", _style(Color("14242d"), BORDER, 7, 12))
	var focus := _style(Color.TRANSPARENT, MINT, 7, 0)
	focus.draw_center = false
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	parent.add_child(button)
	return button


static func _style(fill: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding * 0.75
	style.content_margin_bottom = padding * 0.75
	return style
