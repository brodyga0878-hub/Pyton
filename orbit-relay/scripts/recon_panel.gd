extends CanvasLayer

signal action_requested(action: String)
signal dismissed()

const TEXT := Color("e8f4fa")
const MUTED := Color("a5bac7")
const MINT := Color("9debd7")

var _sim: RefCounted
var _layout: MarginContainer
var _title: Label
var _detail: Label
var _hint: Label
var _result: Label
var _buttons: Dictionary[String, Button] = {}
var _touches: Dictionary[int, Button] = {}


func build() -> void:
	layer = 9
	var backdrop := ColorRect.new()
	backdrop.color = Color("09141d")
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout = MarginContainer.new()
	add_child(_layout)
	_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	_layout.add_child(rows)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	rows.add_child(header)
	_label(header, "Фотосъёмка", 31, TEXT).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "close", "Закрыть")
	_title = _label(rows, "", 24, MINT)
	_detail = _label(rows, "", 19, TEXT)
	_hint = _label(rows, "", 18, MUTED)
	_result = _label(rows, "", 19, MINT)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	rows.add_child(controls)
	_button(controls, "buy", "Установить камеру")
	_button(controls, "accept", "Взять заказ")
	_button(controls, "follow", "Построить курс")
	_button(controls, "photo", "Сделать снимок")
	_button(controls, "report", "Сдать материалы")
	_button(controls, "cancel", "Отменить заказ")
	get_viewport().size_changed.connect(_update_insets)
	_update_insets()
	hide()


func open(sim: RefCounted) -> void:
	_sim = sim
	_touches.clear()
	_result.text = ""
	show()
	refresh()


func close() -> void:
	_touches.clear()
	_sim = null
	hide()


func is_open() -> bool:
	return visible and _sim != null


func refresh(message := "") -> void:
	if not is_open():
		return
	var info: Dictionary = _sim.recon_status()
	_buttons.buy.visible = not info.fitted
	_buttons.buy.disabled = not info.can_buy
	_buttons.buy.text = "Камера · %d кр." % int(info.cost)
	_buttons.accept.visible = not info.active and info.available and not info.completed
	_buttons.accept.disabled = not info.can_accept
	_buttons.follow.visible = info.active and info.can_plot
	_buttons.photo.visible = info.active and _sim.docked < 0
	_buttons.photo.disabled = not info.can_photo
	_buttons.report.visible = info.can_cancel
	_buttons.report.disabled = not info.can_report
	_buttons.cancel.visible = info.can_cancel
	_hint.text = info.photo_hint if info.active else "Камеру можно установить в порту."
	if info.active:
		var seconds := ceili(float(info.remaining))
		_title.text = "Съёмка «%s»" % info.target_name
		_detail.text = "Сдача в порту «%s» · осталось %d мин %02d с\nЛучший снимок %d из 100 · минимум %d · награда %d кр." % [
			info.issuer_name, floori(seconds / 60.0), seconds % 60, info.score, info.minimum_score, info.reward,
		]
		if info.can_report:
			_hint.text = "Материалы готовы к сдаче."
	elif info.available:
		_title.text = "Заказ выполнен" if info.completed else "Заказ на съёмку «%s»" % info.target_name
		_detail.text = "Основная награда %d кр. Премия зависит от качества снимка." % info.reward
	else:
		_title.text = "Бортовая камера установлена" if info.fitted else "Бортовая камера не установлена"
		_detail.text = "Заказы на съёмку выдают на Маяке-7 и в порту «Створ»."
	if not message.is_empty():
		_result.text = message


func _label(parent: Control, caption: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Control, action: String, caption: String) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(114, 52)
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(_request.bind(action))
	parent.add_child(button)
	_buttons[action] = button


func _request(action: String) -> void:
	if action == "close":
		dismissed.emit()
	else:
		action_requested.emit(action)


func _input(event: InputEvent) -> void:
	if not is_open() or not event is InputEventScreenTouch:
		return
	get_viewport().set_input_as_handled()
	if event.pressed:
		for button: Button in _buttons.values():
			if _hit(button, event.position):
				_touches[event.index] = button
				return
		return
	var captured: Button = _touches.get(event.index)
	_touches.erase(event.index)
	if not event.canceled and captured != null and _hit(captured, event.position):
		captured.pressed.emit()


func _hit(button: Button, point: Vector2) -> bool:
	return button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(point)


func _update_insets() -> void:
	var inset := clampi(roundi(get_viewport().get_visible_rect().size.x * 0.07), 18, 110)
	for side: String in ["left", "right"]:
		_layout.add_theme_constant_override("margin_" + side, inset)
	for side: String in ["top", "bottom"]:
		_layout.add_theme_constant_override("margin_" + side, 16)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_touches.clear()
