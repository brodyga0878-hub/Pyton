extends CanvasLayer

signal preference_requested(field: String, value: int)
signal dismissed()

const Settings := preload("res://scripts/display_settings.gd")
const TEXT := Color("e8f4fa")
const MUTED := Color("a5bac7")
const MINT := Color("9debd7")
const BORDER := Color("365561")
const ROW_TITLES := {
	"quality": "Графика",
	"sensitivity": "Чувствительность",
	"layout": "Сенсорная раскладка",
}
const ROW_HINTS := {
	"quality": [
		"До 30 кадров/с · упрощённые материалы и эффекты",
		"До 60 кадров/с · сглаживание 2×",
		"До 60 кадров/с · сглаживание 4× и дополнительные детали",
	],
	"sensitivity": [
		"Плавнее на малых отклонениях",
		"Стандартный отклик на отклонение",
		"Быстрее на малых отклонениях",
	],
	"layout": [
		"Курс и крен слева. Тяга и действия справа.",
		"Тяга и действия слева. Курс и крен справа.",
	],
}

var _settings: RefCounted
var _insets: MarginContainer
var _close_button: Button
var _choice_buttons: Dictionary[String, Array] = {}
var _descriptions: Dictionary[String, Label] = {}
var _touches: Dictionary[int, Button] = {}
var _buttons: Array[Button] = []


func build() -> void:
	if is_instance_valid(_insets):
		return
	layer = 9
	var shade := ColorRect.new()
	shade.color = Color(0.008, 0.020, 0.030, 0.86)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_insets = MarginContainer.new()
	add_child(_insets)
	_insets.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_insets.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 790
	panel.add_theme_stylebox_override("panel", _style(Color("0d1d28"), BORDER, 16, 22))
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 13)
	panel.add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)
	_label(header, "Настройки", 31, TEXT).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close_button = _button(header, "Закрыть")
	_close_button.custom_minimum_size.x = 126
	_close_button.pressed.connect(_request_close)

	for field: String in Settings.OPTIONS:
		_add_choices(content, field)
	get_viewport().size_changed.connect(_update_insets)
	_update_insets()
	hide()


func open(settings: RefCounted) -> void:
	if settings == null:
		return
	build()
	_settings = settings
	_touches.clear()
	show()
	refresh()


func refresh() -> void:
	if not is_open():
		return
	for field: String in _choice_buttons:
		var selected: int = _settings.get(field)
		var buttons: Array = _choice_buttons[field]
		for index in range(buttons.size()):
			var button: Button = buttons[index]
			button.set_pressed_no_signal(index == selected)
		_descriptions[field].text = ROW_HINTS[field][selected]


func close() -> void:
	_touches.clear()
	_settings = null
	hide()


func is_open() -> bool:
	return _settings != null and visible


func _add_choices(parent: Container, field: String) -> void:
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", _style(Color("10242e"), Color("263f4d"), 10, 14))
	parent.add_child(strip)
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 7)
	strip.add_child(group)
	_label(group, ROW_TITLES[field], 21, TEXT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	group.add_child(row)
	var radio := ButtonGroup.new()
	var buttons: Array[Button] = []
	var names: Array = Settings.OPTIONS[field]
	for index in range(names.size()):
		var button := _button(row, names[index])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_group = radio
		button.pressed.connect(_request_preference.bind(field, index))
		buttons.append(button)
	_choice_buttons[field] = buttons
	_descriptions[field] = _label(group, "", 16, MUTED)


func _request_preference(field: String, value: int) -> void:
	if not is_open():
		return
	_touches.clear()
	if _settings.get(field) != value:
		preference_requested.emit(field, value)
	refresh()


func _request_close() -> void:
	if is_open():
		_touches.clear()
		dismissed.emit()


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventScreenDrag:
		var button := _touches.get(event.index) as Button
		if button != null and not _hits(button, event.position):
			_touches.erase(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var released := _touches.get(event.index) as Button
		_touches.erase(event.index)
		if not event.canceled:
			if event.pressed:
				for button: Button in _buttons:
					if _hits(button, event.position) and not _touches.values().has(button):
						_touches[event.index] = button
						break
			elif released != null and _hits(released, event.position):
				released.pressed.emit()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_touches.clear()


func _hits(button: Button, position: Vector2) -> bool:
	return button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(position)


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


func _button(parent: Container, caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 54
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_pressed_color", MINT)
	button.add_theme_stylebox_override("normal", _style(Color("142e3a"), BORDER, 8, 12))
	button.add_theme_stylebox_override("hover", _style(Color("1b4250"), Color("55848d"), 8, 12))
	button.add_theme_stylebox_override("pressed", _style(Color("174441"), MINT, 8, 12))
	button.add_theme_stylebox_override("hover_pressed", _style(Color("1b514e"), MINT, 8, 12))
	var focus := _style(Color.TRANSPARENT, TEXT, 8, 0)
	focus.draw_center = false
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	parent.add_child(button)
	_buttons.append(button)
	return button


static func _label(parent: Container, caption: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)
	return label


static func _style(fill: Color, border: Color, radius: int, pad: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = pad
	style.content_margin_right = pad
	style.content_margin_top = pad * 0.75
	style.content_margin_bottom = pad * 0.75
	return style
