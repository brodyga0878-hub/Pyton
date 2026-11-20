extends CanvasLayer

signal trade_requested(good: String, side: String, quantity: int)
signal courier_requested(route_id: String)
signal dismissed()

const Economy := preload("res://scripts/port_economy.gd")
const Sector := preload("res://scripts/sector_catalog.gd")
const TEXT := Color("e8f4fa")
const MUTED := Color("a5bac7")
const MINT := Color("9debd7")
const AMBER := Color("f3c991")
const BORDER := Color("365561")
const PANEL := Color("0d1d28")
const ACCENTS := {
	"ore": Color("d8ad72"), "crystal": Color("bba5f2"), "ice": Color("9ad8ff"),
	"circuits": Color("84dacf"), "medical": Color("edaac0"),
}

var _sim: RefCounted
var _insets: MarginContainer
var _station: Label
var _balance: Label
var _hold: Label
var _market_tab: Button
var _courier_tab: Button
var _close_button: Button
var _market_page: HBoxContainer
var _courier_page: HBoxContainer
var _goods_buttons: Dictionary[String, Button] = {}
var _goods_labels: Dictionary[String, Array] = {}
var _selection_title: Label
var _quantity_label: Label
var _minus_button: Button
var _plus_button: Button
var _buy_max_button: Button
var _sell_max_button: Button
var _buy_button: Button
var _sell_button: Button
var _buy_hint: Label
var _sell_hint: Label
var _route_rows: Array[PanelContainer] = []
var _route_names: Array[Label] = []
var _route_steps: Array[Label] = []
var _courier_title: Label
var _courier_cargo: Label
var _courier_reward: Label
var _courier_hint: Label
var _courier_button: Button
var _touches: Dictionary[int, Button] = {}
var _buttons: Array[Button] = []
var _selected_good := "ore"
var _quantity := 1


func build() -> void:
	if is_instance_valid(_insets):
		return
	layer = 9
	var backdrop := ColorRect.new()
	backdrop.color = Color("07121b")
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_insets = MarginContainer.new()
	add_child(_insets)
	_insets.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := _column(_insets, 12)
	var header := _row(page, 17)
	_label(header, "Биржа", 34, TEXT)
	_station = _label(header, "", 20, MINT)
	_station.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_balance = _label(header, "", 17, TEXT)
	_hold = _label(header, "", 17, MUTED)
	_close_button = _button(header, "Закрыть", 48.0)
	_close_button.custom_minimum_size.x = 126.0
	_close_button.pressed.connect(func() -> void: dismissed.emit())
	var tabs := _row(page, 8)
	_market_tab = _button(tabs, "Рынок", 44.0)
	_courier_tab = _button(tabs, "Рейсы", 44.0)
	for tab in [_market_tab, _courier_tab]:
		tab.toggle_mode = true
		tab.custom_minimum_size.x = 145.0
	_market_tab.pressed.connect(_show_courier.bind(false))
	_courier_tab.pressed.connect(_show_courier.bind(true))
	_market_page = _row(page, 16)
	_courier_page = _row(page, 16)
	for body in [_market_page, _courier_page]:
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_market()
	_build_courier()
	get_viewport().size_changed.connect(_update_insets)
	_update_insets()
	hide()


func open(sim: RefCounted) -> void:
	if sim == null or not Sector.is_port(sim.docked):
		return
	build()
	_sim = sim
	_selected_good = "ore"
	_quantity = 1
	show()
	_show_courier(false)


func close() -> void:
	_touches.clear()
	_sim = null
	hide()


func is_open() -> bool:
	return _sim != null and visible


func refresh() -> void:
	if not is_open():
		return
	if not Sector.is_port(_sim.docked):
		dismissed.emit()
		return
	_station.text = _sim.target_name(_sim.docked)
	_balance.text = "Баланс %d кр." % int(_sim.credits)
	_hold.text = "Трюм %d / %d ед." % [int(_sim.mining.ore_hold), int(_sim.mining.cargo_capacity)]
	if _courier_page.visible:
		_refresh_courier()
	else:
		_refresh_market()


func _build_market() -> void:
	var table := _card(_market_page, 590.0, true)
	var table_header := _row(table, 10)
	var caption := _label(table_header, "Товар", 17, MUTED)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for heading: String in ["На рынке", "В трюме", "Покупка", "Продажа"]:
		_table_cell(table_header, heading, 15, MUTED)
	for value in Economy.GOODS:
		var good := str(value)
		var button := _button(table, "", 56.0)
		button.toggle_mode = true
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_good.bind(good))
		_goods_buttons[good] = button
		var cells := HBoxContainer.new()
		cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cells.add_theme_constant_override("separation", 10)
		button.add_child(cells)
		cells.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cells.offset_left = 12.0
		cells.offset_right = -4.0
		var mark := ColorRect.new()
		mark.color = ACCENTS[good]
		mark.custom_minimum_size = Vector2(5.0, 25.0)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cells.add_child(mark)
		var name := _label(cells, Economy.good_name(good), 21, TEXT)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_goods_labels[good] = [
			_table_cell(cells, "", 19, TEXT), _table_cell(cells, "", 19, TEXT),
			_table_cell(cells, "", 19, AMBER), _table_cell(cells, "", 19, MINT),
		]
	_label(table, "Цены за единицу товара", 14, MUTED)

	var order := _card(_market_page, 377.0, false)
	_selection_title = _label(order, "", 28, TEXT)
	_spacer(order)
	_label(order, "Количество", 16, MUTED)
	var quantity := _row(order, 8)
	_minus_button = _button(quantity, "−", 54.0)
	_minus_button.custom_minimum_size.x = 64.0
	_minus_button.pressed.connect(_change_quantity.bind(-1))
	_quantity_label = _label(quantity, "", 26, TEXT)
	_quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quantity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plus_button = _button(quantity, "+", 54.0)
	_plus_button.custom_minimum_size.x = 64.0
	_plus_button.pressed.connect(_change_quantity.bind(1))
	var limits := _row(order, 8)
	_buy_max_button = _button(limits, "Макс. покупки", 44.0)
	_buy_max_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy_max_button.pressed.connect(_max_quantity.bind("buy"))
	_sell_max_button = _button(limits, "Макс. продажи", 44.0)
	_sell_max_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_max_button.pressed.connect(_max_quantity.bind("sell"))
	_buy_button = _button(order, "Купить", 54.0, true)
	_buy_button.pressed.connect(_trade.bind("buy"))
	_buy_hint = _label(order, "", 15, AMBER)
	_buy_hint.custom_minimum_size.y = 21.0
	_buy_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sell_button = _button(order, "Продать", 54.0, true)
	_sell_button.pressed.connect(_trade.bind("sell"))
	_sell_hint = _label(order, "", 15, AMBER)
	_sell_hint.custom_minimum_size.y = 21.0
	_sell_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_courier() -> void:
	var itinerary := _card(_courier_page, 560.0, true)
	_label(itinerary, "Маршрут", 28, TEXT)
	for index in range(4):
		var stop := PanelContainer.new()
		stop.custom_minimum_size.y = 76.0
		stop.size_flags_vertical = Control.SIZE_EXPAND_FILL
		itinerary.add_child(stop)
		var detail := _column(stop, 2)
		var name := _label(detail, "", 22, TEXT)
		var step := _label(detail, "", 16, MUTED)
		_route_rows.append(stop)
		_route_names.append(name)
		_route_steps.append(step)
	var assignment := _card(_courier_page, 402.0, false)
	_courier_title = _label(assignment, "", 28, TEXT)
	_courier_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_courier_cargo = _label(assignment, "", 19, MUTED)
	_courier_cargo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spacer(assignment)
	_courier_reward = _label(assignment, "", 24, MINT)
	_courier_hint = _label(assignment, "", 17, MUTED)
	_courier_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_courier_hint.custom_minimum_size.y = 51.0
	_courier_button = _button(assignment, "Взять рейс", 55.0, true)
	_courier_button.pressed.connect(_accept_courier)


func _show_courier(show_courier: bool) -> void:
	_touches.clear()
	_market_page.visible = not show_courier
	_courier_page.visible = show_courier
	_market_tab.set_pressed_no_signal(not show_courier)
	_courier_tab.set_pressed_no_signal(show_courier)
	refresh()


func _refresh_market() -> void:
	for good: String in _goods_buttons:
		var buy: Dictionary = _sim.market_quote(good, "buy", 1)
		var sell: Dictionary = _sim.market_quote(good, "sell", 1)
		var labels := _goods_labels[good]
		labels[0].text = str(buy.stock)
		labels[1].text = str(buy.owned)
		labels[2].text = "%d кр." % int(buy.unit)
		labels[3].text = "%d кр." % int(sell.unit)
		_goods_buttons[good].set_pressed_no_signal(good == _selected_good)
	var capacity := int(_sim.mining.cargo_capacity)
	_quantity = clampi(_quantity, 1, capacity)
	var buy: Dictionary = _sim.market_quote(_selected_good, "buy", _quantity)
	var sell: Dictionary = _sim.market_quote(_selected_good, "sell", _quantity)
	_selection_title.text = Economy.good_name(_selected_good)
	_quantity_label.text = "%d ед." % _quantity
	_minus_button.disabled = _quantity <= 1
	_plus_button.disabled = _quantity >= capacity
	_buy_max_button.disabled = _limit("buy", buy) < 1
	_sell_max_button.disabled = _limit("sell", sell) < 1
	_quote(_buy_button, _buy_hint, "Купить", buy)
	_quote(_sell_button, _sell_hint, "Продать", sell)


func _refresh_courier() -> void:
	var offer: Dictionary = _sim.courier_offer()
	var progress: Dictionary = _sim.contract_itinerary()
	var active: bool = _sim.contract_stage == 1 and not progress.is_empty()
	var route := progress if active or offer.is_empty() else offer
	var known := not route.is_empty()
	var completed := known and bool(route.get("completed", false))
	var leg := int(route.get("leg", -1)) if active else -1
	var stops: Array = [route.origin] + Array(route.stops) if known else []
	for index in range(_route_rows.size()):
		var row := _route_rows[index]
		row.visible = index < stops.size()
		if not row.visible:
			continue
		var current := index == leg + 1 and active
		var visited := completed or (active and index <= leg)
		row.add_theme_stylebox_override("panel", _style(Color("153b41") if current else Color("112631"), MINT if current else BORDER, 9, 12))
		_route_names[index].text = _sim.target_name(int(stops[index]))
		var step := "Отправление" if index == 0 else "Финиш" if index == stops.size() - 1 else "Остановка %d" % index
		if current:
			step += " · Следующая цель"
		elif visited:
			step += " · Пройдено"
		_route_steps[index].text = step
		_route_steps[index].add_theme_color_override("font_color", MINT if current else MUTED)
	_courier_title.text = str(route.title) if known else "Нет рейсов из этого порта"
	_courier_cargo.text = "Груз · %s" % str(route.cargo) if known else ""
	_courier_reward.text = "%s %d кр." % ["Выплачено" if completed else "Оплата", int(route.reward)] if known else ""
	_courier_button.disabled = _sim.contract_stage == 1 or offer.is_empty()
	_courier_button.text = "Рейс принят" if active else "Взять рейс"
	if active:
		_courier_hint.text = "Этап %d из %d. Отметьте прибытие на панели полёта." % [leg + 1, stops.size() - 1]
	elif _sim.contract_stage == 1:
		_courier_hint.text = "Сначала завершите текущую доставку."
	elif known and not completed:
		_courier_hint.text = "Оплата после последней остановки."
	else:
		_courier_hint.text = ""


func _quote(button: Button, hint: Label, verb: String, quote: Dictionary) -> void:
	button.disabled = not quote.ok
	button.text = "%s · %d кр." % [verb, int(quote.cost)]
	hint.text = str(quote.reason) if button.disabled else ""


func _limit(side: String, quote: Dictionary) -> int:
	if side == "sell":
		return int(quote.owned)
	if int(quote.unit) < 1:
		return 0
	var free := int(_sim.mining.cargo_capacity) - int(_sim.mining.ore_hold)
	return mini(free, mini(int(quote.stock), floori(float(_sim.credits) / int(quote.unit))))


func _select_good(good: String) -> void:
	if is_open() and _goods_buttons.has(good):
		_touches.clear()
		_selected_good = good
		_quantity = 1
		refresh()


func _change_quantity(step: int) -> void:
	if is_open():
		_touches.clear()
		_quantity += step
		refresh()


func _max_quantity(side: String) -> void:
	if is_open():
		_touches.clear()
		_quantity = maxi(1, _limit(side, _sim.market_quote(_selected_good, side, 1)))
		refresh()


func _trade(side: String) -> void:
	if is_open() and _sim.market_quote(_selected_good, side, _quantity).ok:
		_touches.clear()
		trade_requested.emit(_selected_good, side, _quantity)


func _accept_courier() -> void:
	if is_open() and not _courier_button.disabled:
		var offer: Dictionary = _sim.courier_offer()
		if not offer.is_empty():
			_touches.clear()
			courier_requested.emit(str(offer.id))


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventScreenTouch:
		var button: Button = _touches.get(event.index)
		_touches.erase(event.index)
		if not event.canceled:
			if event.pressed:
				for hit in _buttons:
					if _hit(hit, event.position) and hit not in _touches.values():
						_touches[event.index] = hit
						break
			elif button != null and _hit(button, event.position):
				button.pressed.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var button: Button = _touches.get(event.index)
		if button != null and not _hit(button, event.position):
			_touches.erase(event.index)
		get_viewport().set_input_as_handled()


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


func _button(parent: Container, caption: String, height: float, accent := false) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = height
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", _style(Color("184847") if accent else Color("112631"), Color("4e8b82") if accent else BORDER, 8, 10))
	button.add_theme_stylebox_override("hover", _style(Color("205058"), MINT, 8, 10))
	button.add_theme_stylebox_override("pressed", _style(Color("24534f"), MINT, 8, 10))
	button.add_theme_stylebox_override("disabled", _style(Color("14242d"), BORDER, 8, 10))
	parent.add_child(button)
	_buttons.append(button)
	return button


static func _hit(button: Button, screen_position: Vector2) -> bool:
	return button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(screen_position)


static func _label(parent: Container, caption: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)
	return label


static func _table_cell(parent: Container, caption: String, font_size: int, tint: Color) -> Label:
	var label := _label(parent, caption, font_size, tint)
	label.custom_minimum_size.x = 84.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


static func _card(parent: Container, width: float, expand: bool) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	if expand:
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(PANEL, BORDER, 12, 16))
	parent.add_child(panel)
	return _column(panel, 9)


static func _column(parent: Container, spacing: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", spacing)
	parent.add_child(box)
	return box


static func _row(parent: Container, spacing: int) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", spacing)
	parent.add_child(box)
	return box


static func _spacer(parent: Container) -> void:
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(space)


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
