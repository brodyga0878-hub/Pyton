extends CanvasLayer

signal trade_requested(good: String, side: String, quantity: int)
signal courier_requested(route_id: String)
signal passenger_requested(action: String, destination: int)
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
	Economy.HYDROGEN: Color("b5e597"),
}
const INTERSTELLAR_PHASES := {
	"waiting": "Стоянка", "departure": "Отход от порта",
	"hyperspace": "Гиперпереход", "arrival": "Заход в порт",
}
const PASSENGER_OFFER_COUNT := 3

var _sim: RefCounted
var _insets: MarginContainer
var _station: Label
var _balance: Label
var _hold: Label
var _market_tab: Button
var _courier_tab: Button
var _passenger_tab: Button
var _freight_tab: Button
var _close_button: Button
var _market_page: HBoxContainer
var _courier_page: HBoxContainer
var _passenger_page: HBoxContainer
var _freight_page: VBoxContainer
var _freight_scroll: ScrollContainer
var _freight_list: VBoxContainer
var _freight_count: Label
var _freight_empty: PanelContainer
var _freight_empty_label: Label
var _freight_rows: Array[Dictionary] = []
var _freight_drag := -1
var _freight_drag_position := Vector2.ZERO
var _goods_buttons: Dictionary[String, Button] = {}
var _goods_labels: Dictionary[String, Array] = {}
var _medical_name: Label
var _customs_rule: Label
var _selection_icon: CommodityIcon
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
var _passenger_offer_rows: Array[Dictionary] = []
var _passenger_empty: Label
var _passenger_manifest: Label
var _passenger_route: Label
var _passenger_time: Label
var _passenger_payment: Label
var _passenger_reason: Label
var _passenger_ledger: Label
var _passenger_discharge_button: Button
var _passenger_repay_button: Button
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
	_passenger_tab = _button(tabs, "Пассажиры", 44.0)
	_freight_tab = _button(tabs, "Снабжение", 44.0)
	for tab in [_market_tab, _courier_tab, _passenger_tab, _freight_tab]:
		tab.toggle_mode = true
		tab.custom_minimum_size.x = 145.0
	_market_tab.pressed.connect(_show_courier.bind(false))
	_courier_tab.pressed.connect(_show_courier.bind(true))
	_passenger_tab.pressed.connect(_show_page.bind("passenger"))
	_freight_tab.pressed.connect(_show_page.bind("freight"))
	_market_page = _row(page, 16)
	_courier_page = _row(page, 16)
	_passenger_page = _row(page, 16)
	_freight_page = _column(page, 10)
	for body in [_market_page, _courier_page, _passenger_page, _freight_page]:
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_market()
	_build_courier()
	_build_passengers()
	_build_freight()
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
	_freight_drag = -1
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
	if _freight_page.visible:
		_refresh_freight()
	elif _passenger_page.visible:
		_refresh_passengers()
	elif _courier_page.visible:
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
		var icon := _commodity_icon(cells, 34.0)
		icon.select(good, ACCENTS[good])
		var name := _label(cells, Economy.good_name(good), 21, TEXT)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if good == "medical":
			_medical_name = name
		_goods_labels[good] = [
			_table_cell(cells, "", 19, TEXT), _table_cell(cells, "", 19, TEXT),
			_table_cell(cells, "", 19, AMBER), _table_cell(cells, "", 19, MINT),
		]
	var prices := _label(table, "Цены зависят от запасов. Итог пересчитывается с количеством.", 14, MUTED)
	prices.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var order := _card(_market_page, 377.0, false)
	var selected := _row(order, 12)
	_selection_icon = _commodity_icon(selected, 42.0)
	_selection_title = _label(selected, "", 28, TEXT)
	_customs_rule = _label(order, "", 16, AMBER)
	_customs_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_customs_rule.hide()
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
	# Preserve this entry point for the existing market/courier integration.
	_show_page("courier" if show_courier else "market")


func _show_page(page: String) -> void:
	_touches.clear()
	_freight_drag = -1
	_market_page.visible = page == "market"
	_courier_page.visible = page == "courier"
	_passenger_page.visible = page == "passenger"
	_freight_page.visible = page == "freight"
	_market_tab.set_pressed_no_signal(page == "market")
	_courier_tab.set_pressed_no_signal(page == "courier")
	_passenger_tab.set_pressed_no_signal(page == "passenger")
	_freight_tab.set_pressed_no_signal(page == "freight")
	refresh()


func _build_passengers() -> void:
	var offers := _card(_passenger_page, 530.0, true)
	_label(offers, "Рейсы из порта", 28, TEXT)
	_passenger_empty = _label(offers, "Из этого порта пока нет пассажирских рейсов.", 18, MUTED)
	_passenger_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for index in range(PASSENGER_OFFER_COUNT):
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(Color("112631"), BORDER, 9, 12))
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		offers.add_child(card)
		var row := _row(card, 16)
		var detail := _column(row, 2)
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var route := _label(detail, "", 22, TEXT)
		route.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var terms := _label(detail, "", 16, MUTED)
		var payment := _label(detail, "", 16, MINT)
		payment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var accept := _button(row, "Принять", 48.0, true)
		accept.custom_minimum_size.x = 126.0
		accept.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		accept.pressed.connect(_accept_passenger.bind(index))
		_passenger_offer_rows.append({
			"card": card, "route": route, "terms": terms, "payment": payment, "accept": accept, "destination": -1,
		})
	_spacer(offers)

	var manifest := _card(_passenger_page, 414.0, false)
	_passenger_manifest = _label(manifest, "", 28, TEXT)
	_passenger_route = _label(manifest, "", 20, TEXT)
	_passenger_time = _label(manifest, "", 21, MINT)
	_passenger_payment = _label(manifest, "", 17, MUTED)
	for line in [_passenger_manifest, _passenger_route, _passenger_payment]:
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spacer(manifest)
	_passenger_reason = _label(manifest, "", 17, MUTED)
	_passenger_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_passenger_ledger = _label(manifest, "", 17, MUTED)
	_passenger_ledger.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_passenger_discharge_button = _button(manifest, "Высадить", 52.0, true)
	_passenger_discharge_button.pressed.connect(_settle_passengers.bind("discharge"))
	_passenger_repay_button = _button(manifest, "Погасить долг", 52.0, true)
	_passenger_repay_button.pressed.connect(_settle_passengers.bind("repay"))


func _refresh_passengers() -> void:
	var status: Dictionary = _sim.passenger_status()
	var offers: Array[Dictionary] = _sim.passenger_board()
	_hold.text = "Места %d / %d" % [int(status.seats), int(status.capacity)]
	_passenger_empty.visible = offers.is_empty()
	for index in range(_passenger_offer_rows.size()):
		var widgets := _passenger_offer_rows[index]
		widgets.card.visible = index < offers.size()
		widgets.destination = -1
		if not widgets.card.visible:
			continue
		var offer := offers[index]
		widgets.destination = int(offer.destination)
		var interstellar: bool = Sector.system_of_site(widgets.destination) != _sim.system_id
		widgets.route.text = _freight_port_name(widgets.destination, interstellar)
		widgets.terms.text = "%s · срок %s" % [_passenger_count(int(offer.seats)), _eta(float(offer.duration))]
		widgets.payment.text = "Аванс %d кр. · При высадке %d кр." % [int(offer.advance), int(offer.fare) - int(offer.advance)]
		widgets.accept.disabled = not bool(offer.available)
	_passenger_manifest.text = "На борту · %s" % _passenger_count(int(status.seats)) if status.active else "Свободных мест · %d" % int(status.capacity)
	_passenger_route.visible = status.active
	_passenger_time.visible = status.active
	_passenger_payment.visible = status.active
	if status.active:
		var origin := int(status.origin)
		var destination := int(status.destination)
		var interstellar := Sector.system_of_site(origin) != Sector.system_of_site(destination)
		_passenger_route.text = "%s\n→ %s" % [_freight_port_name(origin, interstellar), _freight_port_name(destination, interstellar)]
		_passenger_time.text = "Срок истёк" if status.overdue else "До срока %s" % _eta(float(status.remaining))
		_passenger_time.add_theme_color_override("font_color", AMBER if status.overdue else MINT)
		_passenger_payment.text = ("К возврату %d кр. аванса" % int(status.advance)) if status.overdue \
			else "Аванс %d кр. · При высадке %d кр." % [int(status.advance), int(status.fare) - int(status.advance)]
	_passenger_reason.text = str(status.reason)
	if status.canceling:
		_passenger_reason.text += "\nПри отмене потребуется вернуть аванс."
	_passenger_ledger.text = "Репутация %d · Выполнено %d · Просрочено %d" % [int(status.reputation), int(status.completed), int(status.late)]
	var debt := int(status.debt)
	_passenger_reason.visible = (status.active or debt > 0) and not _passenger_reason.text.is_empty()
	if debt > 0:
		_passenger_ledger.text += "\nДолг по авансу %d кр." % debt
	_passenger_discharge_button.visible = status.active
	_passenger_discharge_button.disabled = not status.can_discharge
	_passenger_discharge_button.text = "Отменить рейс" if status.canceling else "Высадить пассажиров"
	_passenger_repay_button.visible = debt > 0
	_passenger_repay_button.disabled = not status.can_repay
	var payment := mini(debt, int(_sim.credits))
	_passenger_repay_button.text = "Внести %d кр." % payment if payment > 0 and payment < debt else "Погасить долг"


func _accept_passenger(index: int) -> void:
	if not is_open() or not _passenger_page.visible:
		return
	var offer := _passenger_offer_rows[index]
	if offer.card.visible and not offer.accept.disabled:
		_touches.clear()
		passenger_requested.emit("accept", offer.destination)


func _settle_passengers(action: String) -> void:
	if not is_open() or not _passenger_page.visible:
		return
	var button := _passenger_discharge_button if action == "discharge" else _passenger_repay_button
	if button.visible and not button.disabled:
		_touches.clear()
		passenger_requested.emit(action, -1)


static func _passenger_count(seats: int) -> String:
	return "1 пассажир" if seats == 1 else "%d пассажира" % seats


func _build_freight() -> void:
	var header := _row(_freight_page, 12)
	_label(header, "Грузовые корабли порта", 26, TEXT).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_freight_count = _label(header, "", 18, MINT)
	var note := _label(_freight_page, "Груз списывается при отправлении и поступает на склад по прибытии. Пока биржа открыта, время приостановлено.", 16, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_freight_scroll = ScrollContainer.new()
	_freight_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_freight_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_freight_page.add_child(_freight_scroll)
	_freight_list = _column(_freight_scroll, 10)
	_freight_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_freight_empty = PanelContainer.new()
	_freight_empty.add_theme_stylebox_override("panel", _style(PANEL, BORDER, 12, 20))
	_freight_empty.custom_minimum_size.y = 180.0
	_freight_list.add_child(_freight_empty)
	var empty_content := _column(_freight_empty, 10)
	_label(empty_content, "У этого порта пока нет регулярных грузовых рейсов", 24, TEXT)
	_freight_empty_label = _label(empty_content, "Доступные товары и цены — на вкладке «Рынок».", 19, MUTED)
	_freight_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _add_freight_row() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(PANEL, BORDER, 11, 15))
	panel.custom_minimum_size.y = 152.0
	_freight_list.add_child(panel)
	var content := _column(panel, 6)
	var header := _row(content, 14)
	var name := _label(header, "", 22, TEXT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var state := _label(header, "", 17, MINT)
	var route := _label(content, "", 19, MUTED)
	route.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var manifest := _row(content, 10)
	var icon := _commodity_icon(manifest, 30.0)
	var cargo := _label(manifest, "", 19, TEXT)
	cargo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var eta := _label(manifest, "", 18, AMBER)
	var progress := ProgressBar.new()
	progress.min_value = 0.0
	progress.max_value = 1.0
	progress.show_percentage = false
	progress.custom_minimum_size.y = 5.0
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.add_theme_stylebox_override("background", _style(Color("172e3a"), Color("172e3a"), 2, 0))
	progress.add_theme_stylebox_override("fill", _style(Color("70bfb0"), Color("70bfb0"), 2, 0))
	content.add_child(progress)
	var delivered := _label(content, "", 15, MUTED)
	delivered.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_freight_rows.append({"panel": panel, "name": name, "state": state, "route": route, "icon": icon, "cargo": cargo, "eta": eta, "progress": progress, "delivered": delivered})


func _refresh_freight() -> void:
	var statuses: Array[Dictionary] = _sim.freight_status(int(_sim.docked))
	_freight_count.text = "%d корабля" % statuses.size() if statuses.size() in [2, 3, 4] else "%d корабль" % statuses.size() if statuses.size() == 1 else "%d кораблей" % statuses.size()
	_freight_empty.visible = statuses.is_empty()
	while _freight_rows.size() < statuses.size():
		_add_freight_row()
	for i in range(_freight_rows.size()):
		var widgets: Dictionary = _freight_rows[i]
		widgets.panel.visible = i < statuses.size()
		if i >= statuses.size():
			continue
		var status: Dictionary = statuses[i]
		var travelling := bool(status.in_transit)
		var interstellar := bool(status.get("interstellar", false))
		widgets.name.text = str(status.name)
		var phase_label := "В пути" if travelling else "Стоянка"
		if interstellar:
			phase_label = str(INTERSTELLAR_PHASES.get(str(status.get("visual_phase", "")), phase_label))
		widgets.state.text = phase_label
		widgets.state.add_theme_color_override("font_color", MINT if travelling else AMBER)
		widgets.route.text = "%s  →  %s" % [_freight_port_name(int(status.origin), interstellar), _freight_port_name(int(status.destination), interstellar)]
		var good := str(status.good)
		var amount := int(status.amount)
		widgets.icon.visible = amount > 0
		widgets.icon.select(good, ACCENTS.get(good, MUTED))
		widgets.cargo.text = "%s · %d ед. на борту" % [Economy.good_name(good), amount] if amount > 0 else "На борту нет груза"
		widgets.eta.text = "Прибытие через %s" % _eta(float(status.arrival_eta)) if travelling else "Вылет %s · прибытие %s" % [_eta(float(status.departure_eta)), _eta(float(status.arrival_eta))]
		widgets.progress.value = clampf(float(status.progress), 0.0, 1.0)
		widgets.progress.visible = travelling
		var last_port := int(status.last_port)
		var last_good := str(status.last_good)
		var last_delivered := int(status.last_delivered)
		var where: String = "здесь" if last_port == int(_sim.docked) else _freight_port_name(last_port, interstellar) if last_port >= 0 else ""
		if last_port < 0:
			widgets.delivered.text = "Первое прибытие ещё впереди."
		elif last_good.is_empty():
			widgets.delivered.text = "В последнем прибытии груз не разгружался."
		elif last_delivered > 0:
			widgets.delivered.text = "Последняя разгрузка (%s): +%d ед. · %s" % [where, last_delivered, Economy.good_name(last_good)]
		else:
			widgets.delivered.text = "Последняя разгрузка (%s): склад заполнен, груз остался на борту." % where


func _freight_port_name(port: int, interstellar: bool) -> String:
	var name: String = _sim.target_name(port)
	if not interstellar:
		return name
	var system := Sector.system_of_site(port)
	return "%s · %s" % [Sector.system(system).name, name] if system >= 0 else name


static func _eta(seconds: float) -> String:
	var total := maxi(0, ceili(seconds))
	return "%d:%02d" % [total / 60, total % 60]


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
	_selection_icon.select(_selected_good, ACCENTS[_selected_good])
	_selection_title.text = Economy.good_name(_selected_good)
	_refresh_customs()
	_quantity_label.text = "%d ед." % _quantity
	_minus_button.disabled = _quantity <= 1
	_plus_button.disabled = _quantity >= capacity
	_buy_max_button.disabled = _limit("buy") < 1
	_sell_max_button.disabled = _limit("sell") < 1
	_quote(_buy_button, _buy_hint, "Купить", buy)
	_quote(_sell_button, _sell_hint, "Продать", sell)


func _refresh_customs() -> void:
	var customs: Dictionary = _sim.customs_status()
	var authority := int(customs.get("authority", -1))
	var allowance := int(customs.get("medical_allowance", -1))
	var aboard := int(customs.get("medical_aboard", 0))
	var restricted := authority >= 0 and allowance >= 0
	var medicine_selected := _selected_good == "medical"
	var authority_name := str(customs.get("authority_name", ""))
	_medical_name.add_theme_color_override("font_color", AMBER if restricted else TEXT)
	_goods_buttons["medical"].tooltip_text = "Лимит медикаментов · %d ед. В трюме %d ед." % [allowance, aboard] if restricted else ""
	_customs_rule.visible = restricted or (authority >= 0 and medicine_selected)
	_customs_rule.add_theme_color_override("font_color", AMBER if restricted else MUTED)
	if restricted:
		_customs_rule.text = "%s допускает до %d ед. медикаментов для личного пользования.\nВ трюме %d ед." % [authority_name, allowance, aboard]
	else:
		_customs_rule.text = "%s · свободная торговля медикаментами." % authority_name if _customs_rule.visible else ""


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


func _limit(side: String) -> int:
	return int(_sim.market_limit(_selected_good, side))


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
		_quantity = maxi(1, _limit(side))
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
		if event.index == _freight_drag:
			if not event.pressed or event.canceled:
				_freight_drag = -1
			get_viewport().set_input_as_handled()
			return
		if event.pressed and not event.canceled and _freight_page.visible and _freight_drag < 0 and _freight_scroll.get_global_rect().has_point(event.position):
			_freight_drag = event.index
			_freight_drag_position = event.position
			get_viewport().set_input_as_handled()
			return
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
		if event.index == _freight_drag:
			_freight_scroll.scroll_vertical -= roundi(event.position.y - _freight_drag_position.y)
			_freight_drag_position = event.position
			get_viewport().set_input_as_handled()
			return
		var button: Button = _touches.get(event.index)
		if button != null and not _hit(button, event.position):
			_touches.erase(event.index)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_touches.clear()
		_freight_drag = -1


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


static func _commodity_icon(parent: Container, diameter: float) -> CommodityIcon:
	var icon := CommodityIcon.new()
	icon.custom_minimum_size = Vector2.ONE * diameter
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon


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


class CommodityIcon extends Control:
	## One 36-unit drawing grid serves the table and the order panel.

	var _commodity := ""
	var _accent := Color.WHITE
	var _tile := StyleBoxFlat.new()

	func select(commodity: String, accent: Color) -> void:
		if _commodity == commodity:
			return
		_commodity = commodity
		_accent = accent
		_tile.bg_color = Color("091720")
		_tile.border_color = accent.lerp(Color("253946"), 0.70)
		_tile.set_border_width_all(1)
		_tile.set_corner_radius_all(7)
		queue_redraw()

	func _draw() -> void:
		var scale_factor := minf(size.x, size.y) / 36.0
		var scale_vector := Vector2.ONE * scale_factor
		draw_set_transform((size - scale_vector * 36.0) * 0.5, 0.0, scale_vector)
		draw_style_box(_tile, Rect2(0, 0, 36, 36))
		var shadow := _accent.darkened(0.48)
		var light := _accent.lightened(0.27)
		match _commodity:
			"ore":
				_shape([Vector2(5, 23), Vector2(8, 17), Vector2(14, 16), Vector2(18, 23), Vector2(15, 29), Vector2(8, 28)], _accent)
				_shape([Vector2(5, 23), Vector2(13, 25), Vector2(15, 29), Vector2(8, 28)], shadow)
				_shape([Vector2(15, 20), Vector2(16, 11), Vector2(23, 7), Vector2(30, 12), Vector2(31, 21), Vector2(25, 27), Vector2(19, 25)], _accent)
				_shape([Vector2(15, 20), Vector2(23, 17), Vector2(25, 27), Vector2(19, 25)], shadow)
				_shape([Vector2(16, 11), Vector2(23, 7), Vector2(30, 12), Vector2(23, 17)], light)
			"crystal":
				_shape([Vector2(6, 24), Vector2(8, 16), Vector2(14, 19), Vector2(19, 28), Vector2(14, 30)], shadow)
				_shape([Vector2(13, 24), Vector2(17, 10), Vector2(26, 5), Vector2(30, 13), Vector2(24, 28), Vector2(18, 31)], _accent)
				_shape([Vector2(17, 10), Vector2(26, 5), Vector2(22, 16), Vector2(13, 24)], light)
				_shape([Vector2(30, 13), Vector2(24, 28), Vector2(18, 31), Vector2(22, 16)], shadow)
			"ice":
				_shape([Vector2(7, 12), Vector2(18, 6), Vector2(29, 12), Vector2(29, 24), Vector2(18, 30), Vector2(7, 24)], _accent)
				_shape([Vector2(7, 12), Vector2(18, 6), Vector2(29, 12), Vector2(18, 18)], light)
				_shape([Vector2(18, 18), Vector2(29, 12), Vector2(29, 24), Vector2(18, 30)], shadow)
				draw_line(Vector2(11, 17), Vector2(14, 23), light, 1.4, true)
			"circuits":
				for offset in [12, 18, 24]:
					draw_line(Vector2(offset, 6), Vector2(offset, 30), light, 1.65, true)
					draw_line(Vector2(6, offset), Vector2(30, offset), light, 1.65, true)
				draw_rect(Rect2(9, 9, 18, 18), _accent)
				draw_rect(Rect2(13, 13, 10, 10), shadow)
				draw_rect(Rect2(16, 16, 4, 4), light)
			"medical":
				draw_polyline(PackedVector2Array([Vector2(13, 12), Vector2(13, 8), Vector2(23, 8), Vector2(23, 12)]), light, 1.5, true)
				_shape([Vector2(5, 15), Vector2(8, 12), Vector2(28, 12), Vector2(31, 15), Vector2(31, 26), Vector2(28, 29), Vector2(8, 29), Vector2(5, 26)], _accent)
				draw_rect(Rect2(7, 25, 22, 3), shadow)
				draw_line(Vector2(18, 15), Vector2(18, 25), Color("482338"), 3.2, true)
				draw_line(Vector2(13, 20), Vector2(23, 20), Color("482338"), 3.2, true)
			Economy.HYDROGEN:
				var ink := Color("23392f")
				draw_rect(Rect2(15, 5, 8, 5), light)
				_shape([Vector2(11, 12), Vector2(15, 9), Vector2(23, 9), Vector2(27, 12),
					Vector2(27, 28), Vector2(24, 31), Vector2(14, 31), Vector2(11, 28)], _accent)
				draw_rect(Rect2(24, 12, 3, 16), shadow)
				draw_line(Vector2(14, 13), Vector2(14, 26), light, 1.2, true)
				draw_line(Vector2(16, 15), Vector2(16, 23), ink, 1.5, true)
				draw_line(Vector2(21, 15), Vector2(21, 23), ink, 1.5, true)
				draw_line(Vector2(16, 19), Vector2(21, 19), ink, 1.5, true)
				draw_line(Vector2(13, 27), Vector2(25, 27), shadow, 1.5, true)

	func _shape(points: Array[Vector2], color: Color) -> void:
		draw_colored_polygon(PackedVector2Array(points), color)
