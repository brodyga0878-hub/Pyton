extends CanvasLayer

signal follow_requested(kind: String)
signal dismissed()

const Sector = preload("res://scripts/sector_catalog.gd")
const Patrol = preload("res://scripts/patrol_encounter.gd")
const INK := Color("edf7f9")
const MUTED := Color("adc0c9")
const MINT := Color("a4e9d6")
const AMBER := Color("f0c59a")
const BORDER := Color("355360")
const PATROL_STEPS := ["Найти источник сигнала", "Перехватить рейдера", "Вернуться с докладом"]

var _sim: RefCounted
var _insets: MarginContainer
var _location: Label
var _delivery_title: Label
var _delivery_step: Label
var _delivery_cargo: Label
var _delivery_next: Label
var _delivery_rows: Array[HBoxContainer] = []
var _delivery_stops: Array[Label] = []
var _delivery_tags: Array[Label] = []
var _patrol_step: Label
var _patrol_origin: Label
var _patrol_next: Label
var _patrol_reward: Label
var _patrol_rows: Array[HBoxContainer] = []
var _patrol_stops: Array[Label] = []
var _patrol_tags: Array[Label] = []
var _close_button: Button
var _follow_buttons: Dictionary[String, Button] = {}
var _touches: Dictionary[int, Button] = {}


func build() -> void:
	if is_instance_valid(_insets):
		return
	layer = 9
	var backdrop := ColorRect.new()
	backdrop.color = Color("09141d")
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_insets = MarginContainer.new()
	add_child(_insets)
	_insets.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	_insets.add_child(page)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	page.add_child(header)
	_label(header, "Журнал заданий", 34, INK).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_location = _label(header, "", 19, MINT)
	_location.autowrap_mode = TextServer.AUTOWRAP_OFF
	_location.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_close_button = _button(header, "Закрыть")
	_close_button.custom_minimum_size.x = 128.0
	_close_button.pressed.connect(func() -> void: dismissed.emit())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	_build_delivery(body)
	_build_patrol(body)
	get_viewport().size_changed.connect(_update_insets)
	_update_insets()
	hide()


func open(sim: RefCounted) -> void:
	if sim == null:
		return
	build()
	_sim = sim
	_touches.clear()
	show()
	refresh()


func refresh() -> void:
	if not is_open():
		return
	_location.text = "Система «%s»" % Sector.system(_sim.system_id).name
	_refresh_delivery()
	_refresh_patrol()


func close() -> void:
	_touches.clear()
	_sim = null
	hide()


func is_open() -> bool:
	return _sim != null and visible


func _build_delivery(parent: HBoxContainer) -> void:
	var card := _card(parent)
	_delivery_title = _label(card, "Доставка", 29, INK)
	_delivery_step = _label(card, "", 19, MINT)
	_delivery_cargo = _label(card, "", 18, MUTED)
	for i in range(4):
		var row := _step_row(card, "")
		_delivery_rows.append(row)
		_delivery_stops.append(row.get_child(0))
		_delivery_tags.append(row.get_child(1))
	_spacer(card)
	_delivery_next = _label(card, "", 19, INK)
	_add_follow_button(card, "delivery")


func _build_patrol(parent: HBoxContainer) -> void:
	var card := _card(parent)
	_label(card, "Дозор", 29, INK)
	_patrol_step = _label(card, "", 19, AMBER)
	_patrol_origin = _label(card, "", 18, MUTED)
	_patrol_reward = _label(card, "", 19, INK)
	for caption: String in PATROL_STEPS:
		var row := _step_row(card, caption)
		_patrol_rows.append(row)
		_patrol_stops.append(row.get_child(0))
		_patrol_tags.append(row.get_child(1))
	_spacer(card)
	_patrol_next = _label(card, "", 19, INK)
	_add_follow_button(card, "patrol")


func _refresh_delivery() -> void:
	var active: bool = _sim.contract_stage == 1
	var itinerary: Dictionary = _sim.contract_itinerary()
	var title := "Доставка"
	var step := "Завершено доставок · %d" % _sim.deliveries
	var cargo := ""
	var next := "Действующих доставок нет. Контракт можно взять в порту."
	var origin := -1
	var stops: Array = []
	var leg := -1
	var follow_caption := ""
	if active:
		origin = _sim.contract_origin
		var destination: int = _sim.contract_destination
		stops = [destination]
		leg = 0
		if not itinerary.is_empty():
			title = itinerary.title
			stops = itinerary.stops
			leg = itinerary.leg
		step = "Этап %d из %d · Награда %d кр." % [leg + 1, stops.size(), _sim.contract_reward()]
		cargo = "Груз · %s" % _sim.contract_cargo()
		var destination_system := Sector.system_of_site(destination)
		var port: String = _sim.target_name(destination)
		if _sim.docked == destination:
			var command := "Отметить этап" if leg + 1 < stops.size() else "Сдать груз"
			next = "Нажмите «%s» на панели полёта." % command
		elif destination_system != _sim.system_id:
			next = "Прыгните в систему «%s» и прибудьте в порт «%s»." % [Sector.system(destination_system).name, port]
			follow_caption = "Проложить прыжок"
		else:
			next = "Состыкуйтесь в порту «%s»." % port
			follow_caption = "Курс к порту"
	_delivery_title.text = title
	_delivery_step.text = step
	_delivery_cargo.text = cargo
	_delivery_cargo.visible = active
	_delivery_next.text = next
	var visited: Array = [origin] + stops if active else []
	for i in range(_delivery_rows.size()):
		_delivery_rows[i].visible = i < visited.size()
		if i >= visited.size():
			continue
		var current := i == leg + 1
		var port_id: int = visited[i]
		_delivery_stops[i].text = _sim.target_name(port_id)
		_delivery_stops[i].add_theme_color_override("font_color", MINT if current else INK)
		var tag := "Старт" if i == 0 else ("Финиш" if i == stops.size() else "Остановка %d" % i)
		if current:
			tag += " · Сейчас"
		elif i > 0 and i <= leg:
			tag += " · Пройдено"
		_delivery_tags[i].text = tag
	_follow("delivery", follow_caption)


func _refresh_patrol() -> void:
	var status: Dictionary = _sim.patrol_status()
	var phase: int = status.phase
	var active := phase in [Patrol.OUTBOUND, Patrol.ENGAGED, Patrol.RETURN]
	_patrol_origin.visible = active
	_patrol_reward.visible = active
	for i in range(_patrol_rows.size()):
		_patrol_rows[i].visible = active
		var step := i + Patrol.OUTBOUND
		_patrol_stops[i].add_theme_color_override("font_color", AMBER if phase == step else INK)
		_patrol_tags[i].text = "Сейчас" if phase == step else ("Пройдено" if phase > step else "")
	if not active:
		_patrol_step.text = "Завершено дозоров · %d" % _sim.patrol.completed
		_patrol_next.text = "Действующего дозора нет. Его можно принять в порту."
		_follow("patrol", "")
		return
	var system_name: String = Sector.system(Sector.system_of_site(status.origin)).name
	var port: String = _sim.target_name(status.origin)
	_patrol_origin.text = "Порт «%s» · %s" % [port, system_name]
	_patrol_reward.text = "Награда %d кр." % status.reward
	var instruction: String = status.reason
	var follow_caption := ""
	match phase:
		Patrol.OUTBOUND:
			_patrol_step.text = "Поиск сигнала"
			if status.available and not _sim.patrol_course:
				follow_caption = "К сигналу"
			elif _sim.patrol_course:
				instruction = "Курс к сигналу уже включён."
		Patrol.ENGAGED:
			_patrol_step.text = "Перехват · Корпус рейдера %.0f%%" % status.enemy_hull
			if status.available and not _sim.patrol_course:
				follow_caption = "Навести на рейдера"
			elif _sim.patrol_course:
				instruction = "Прицел включён. Следите за дальностью огня."
		Patrol.RETURN:
			_patrol_step.text = "Возвращение с докладом"
			if _sim.docked == status.origin:
				instruction = "Нажмите «Доложить» на панели полёта."
			elif status.available and _sim.docked < 0 and not _sim.landed:
				follow_caption = "Курс к порту"
	if not status.same_system:
		follow_caption = "Проложить прыжок"
	_patrol_next.text = instruction
	_follow("patrol", follow_caption)


func _follow(kind: String, caption: String) -> void:
	var button := _follow_buttons[kind]
	button.text = caption
	button.visible = not caption.is_empty()
	button.disabled = not button.visible or _sim.jump_seconds_left > 0.0


func _add_follow_button(parent: Control, kind: String) -> void:
	var button := _button(parent, "")
	_follow_buttons[kind] = button
	button.pressed.connect(_request_follow.bind(kind))


func _request_follow(kind: String) -> void:
	var button := _follow_buttons[kind]
	if is_open() and button.visible and not button.disabled:
		_touches.clear()
		follow_requested.emit(kind)


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
			elif button != null and button.visible and not button.disabled and button.get_global_rect().has_point(event.position):
				button.pressed.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var held: Button = _touches.get(event.index)
		if held != null and not held.get_global_rect().has_point(event.position):
			_touches.erase(event.index)
		get_viewport().set_input_as_handled()


func _button_at(point: Vector2) -> Button:
	if _close_button.get_global_rect().has_point(point):
		return _close_button
	for button: Button in _follow_buttons.values():
		if button.visible and not button.disabled and button.get_global_rect().has_point(point):
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


static func _card(parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 400.0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(Color("101f2a"), BORDER, 14, 20))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	return column


static func _spacer(parent: Control) -> void:
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(space)


static func _step_row(parent: Control, caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size.y = 42.0
	parent.add_child(row)
	var name := _label(row, caption, 20, INK)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var tag := _label(row, "", 16, MUTED)
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return row


static func _label(parent: Control, caption: String, points: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)
	return label


static func _button(parent: Control, caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 52.0
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_stylebox_override("normal", _style(Color("173a41"), Color("457783"), 8, 12))
	button.add_theme_stylebox_override("hover", _style(Color("205459"), MINT, 8, 12))
	button.add_theme_stylebox_override("pressed", _style(Color("14313a"), MINT, 8, 12))
	button.add_theme_stylebox_override("disabled", _style(Color("15242e"), BORDER, 8, 12))
	var focus := _style(Color.TRANSPARENT, MINT, 8, 0)
	focus.draw_center = false
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	parent.add_child(button)
	return button


static func _style(fill: Color, border: Color, radius: int, padding: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding * 0.8
	box.content_margin_bottom = padding * 0.8
	return box
