extends CanvasLayer

signal service_requested(action: String)
signal transfer_requested(destination: String)
signal jettison_requested(good: String)
signal crew_requested(action: String, member: int)
signal ship_exchange_requested(hull: String)
signal dismissed()

const TEXT := Color("e8f4fa")
const MUTED := Color("a5bac7")
const MINT := Color("9debd7")
const AMBER := Color("ffd396")
const BORDER := Color("365561")
const ShipSystems := preload("res://scripts/ship_systems.gd")
const Crew := preload("res://scripts/crew.gd")

enum StationPage { SERVICES, CREW, YARD }

var _sim: RefCounted
var _insets: MarginContainer
var _title: Label
var _port_details: HBoxContainer
var _station: Label
var _balance: Label
var _gauges: HBoxContainer
var _fuel: Label
var _fuel_level: ProgressBar
var _jump_fuel: Label
var _jump_fuel_level: ProgressBar
var _hull: Label
var _hull_level: ProgressBar
var _tariff: Label
var _jump_tariff: Label
var _repair_tariff: Label
var _cargo_detail: Label
var _services: VBoxContainer
var _crew: VBoxContainer
var _crew_toggle: Button
var _crew_summary: Label
var _crew_payroll: Label
var _crew_empty: Label
var _crew_candidate_rows: Array[Dictionary] = []
var _crew_member_rows: Array[Dictionary] = []
var _crew_buttons: Array[Button] = []
var _yard: VBoxContainer
var _yard_toggle: Button
var _yard_rows: Array[Dictionary] = []
var _station_page := StationPage.SERVICES
var _transfers: VBoxContainer
var _hydrogen: Label
var _close_button: Button
var _action_buttons: Dictionary[String, Button] = {}
var _transfer_buttons: Dictionary[String, Button] = {}
var _transfer_labels: Dictionary[String, Label] = {}
var _discard_row: PanelContainer
var _discard_choice: Button
var _discard_detail: Label
var _discard_button: Button
var _cargo_options: Array[Dictionary] = []
var _cargo_index := 0
var _discard_pending_good := ""
var _fuel_only := false
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
	panel.custom_minimum_size.x = 748.0
	panel.add_theme_stylebox_override("panel", _style(Color("0d1d28"), BORDER, 16, 22))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	_title = _label(header, "Портовые службы", 30, TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crew_toggle = _button(header)
	_crew_toggle.custom_minimum_size.x = 126.0
	_crew_toggle.pressed.connect(_toggle_station_page.bind(StationPage.CREW))
	_yard_toggle = _button(header)
	_yard_toggle.custom_minimum_size.x = 126.0
	_yard_toggle.pressed.connect(_toggle_station_page.bind(StationPage.YARD))
	_close_button = _button(header)
	_close_button.text = "Закрыть"
	_close_button.custom_minimum_size.x = 126.0
	_close_button.pressed.connect(func() -> void: dismissed.emit())

	_port_details = HBoxContainer.new()
	content.add_child(_port_details)
	_station = _label(_port_details, "", 20, MINT)
	_station.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_balance = _label(_port_details, "", 20, TEXT)

	_gauges = HBoxContainer.new()
	_gauges.add_theme_constant_override("separation", 22)
	content.add_child(_gauges)
	var fuel_meter := _add_meter(_gauges, "Тяга", Color("398c82"), MINT)
	_fuel = fuel_meter[0]
	_fuel_level = fuel_meter[1]
	var jump_meter := _add_meter(_gauges, "Прыжки", Color("396c89"), Color("9edcff"))
	_jump_fuel = jump_meter[0]
	_jump_fuel_level = jump_meter[1]
	var hull_meter := _add_meter(_gauges, "Корпус", Color("947251"), AMBER)
	_hull = hull_meter[0]
	_hull_level = hull_meter[1]

	_services = VBoxContainer.new()
	_services.add_theme_constant_override("separation", 8)
	content.add_child(_services)
	_tariff = _add_service("refuel", "Заправка реактивного бака", "")
	_jump_tariff = _add_service("jump_refuel", "Заправка прыжкового запаса", "")
	_repair_tariff = _add_service("repair", "Ремонт корпуса", "")
	_add_service("tank", "Увеличенные баки", "Ёмкость каждого бака 150 ед.")
	_add_service("eco", "Экономичный привод", "Расход реактивного топлива ниже на 30%")
	_cargo_detail = _add_service("cargo", "Расширение трюма", "")
	_add_service("heat_shield", "Теплозащита", "Тепловая нагрузка в атмосфере ниже на %d%%" % ShipSystems.HEAT_SHIELD_REDUCTION)
	_build_crew(content)
	_build_yard(content)
	_transfers = VBoxContainer.new()
	_transfers.add_theme_constant_override("separation", 8)
	content.add_child(_transfers)
	_hydrogen = _label(_transfers, "", 19, TEXT)
	_add_transfer("reaction", "В реактивный бак")
	_add_transfer("jump", "В прыжковый запас")
	_build_discard_row()
	_transfers.hide()
	get_viewport().size_changed.connect(_update_insets)
	_update_insets()
	hide()


func open(sim: RefCounted, fuel_only := false) -> void:
	if sim == null or (not fuel_only and not sim.station_services_available()):
		return
	build()
	_sim = sim
	_fuel_only = fuel_only
	_station_page = StationPage.SERVICES
	_cargo_index = 0
	_discard_pending_good = ""
	_touches.clear()
	_show_page()
	show()
	refresh()


func refresh() -> void:
	if not is_open():
		return
	if not _fuel_only and not _sim.station_services_available():
		dismissed.emit()
		return
	var capacity: float = _sim.ship.capacity()
	var fuel: float = _sim.ship.fuel
	var jump_capacity: float = _sim.ship.jump_capacity()
	var jump_fuel: float = _sim.ship.jump_fuel
	var hull: float = _sim.ship.hull
	_fuel_level.max_value = capacity
	_fuel_level.value = fuel
	_fuel.text = "%s / %d ед." % [_decimal(fuel), roundi(capacity)]
	_jump_fuel_level.max_value = jump_capacity
	_jump_fuel_level.value = jump_fuel
	_jump_fuel.text = "%s / %d ед." % [_decimal(jump_fuel), roundi(jump_capacity)]
	_hull_level.value = hull
	_hull.text = "%s%%" % _decimal(hull)
	if _fuel_only:
		_refresh_transfers()
	else:
		_station.text = _sim.target_name(_sim.docked)
		_balance.text = "Баланс %d кр." % _sim.credits
		match _station_page:
			StationPage.CREW: _refresh_crew()
			StationPage.YARD: _refresh_yard()
			_: _refresh_services()


func _refresh_services() -> void:
	_tariff.text = "Тариф порта · %d кр. за ед." % _sim.refuel_unit_price()
	_jump_tariff.text = _tariff.text
	_repair_tariff.text = "Тариф порта · %d кр. за 1%%" % _sim.repair_unit_price()
	var profile := ShipSystems.profile(_sim.ship.hull_id)
	if _sim.ship.cargo_upgraded:
		_cargo_detail.text = "Ёмкость %d ед." % int(profile.expanded_cargo)
	else:
		_cargo_detail.text = "Ёмкость %d → %d ед." % [int(profile.cargo), int(profile.expanded_cargo)]
	for action: String in _action_buttons:
		var offer: Dictionary = _sim.service_offer(action)
		var button := _action_buttons[action]
		button.disabled = not offer.allowed
		if offer.installed:
			button.text = "Установлено"
		elif action in ["refuel", "jump_refuel"] and offer.cost == 0:
			button.text = "Бак полон"
		elif action == "repair" and offer.cost == 0:
			button.text = "Корпус цел"
		elif button.disabled:
			button.text = "%d кр. · не хватает средств" % offer.cost
		else:
			var verb := "Установить"
			match action:
				"refuel", "jump_refuel": verb = "Заправить"
				"repair": verb = "Починить"
			button.text = "%s · %d кр." % [verb, offer.cost]


func _show_page() -> void:
	var crew_open := not _fuel_only and _station_page == StationPage.CREW
	var yard_open := not _fuel_only and _station_page == StationPage.YARD
	_title.text = "Портовые службы"
	if _fuel_only:
		_title.text = "Топливо"
	elif crew_open:
		_title.text = "Экипаж"
	elif yard_open:
		_title.text = "Верфь"
	_crew_toggle.text = "Сервис" if crew_open else "Экипаж"
	_crew_toggle.visible = not _fuel_only
	_yard_toggle.text = "Сервис" if yard_open else "Верфь"
	_yard_toggle.visible = not _fuel_only and _sim.shipyard_available()
	_port_details.visible = not _fuel_only
	_gauges.visible = not crew_open and not yard_open
	_services.visible = not _fuel_only and _station_page == StationPage.SERVICES
	_crew.visible = crew_open
	_yard.visible = yard_open
	_transfers.visible = _fuel_only


func _toggle_station_page(page: StationPage) -> void:
	if not is_open() or _fuel_only:
		return
	if page == StationPage.YARD and not _sim.shipyard_available():
		return
	_station_page = StationPage.SERVICES if _station_page == page else page
	_touches.clear()
	_show_page()
	refresh()


func _build_crew(parent: VBoxContainer) -> void:
	_crew = VBoxContainer.new()
	_crew.add_theme_constant_override("separation", 12)
	parent.add_child(_crew)
	var overview := HBoxContainer.new()
	_crew.add_child(overview)
	_crew_summary = _label(overview, "", 21, TEXT)
	_crew_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crew_payroll = _label(overview, "", 17, MUTED)
	var panels := HBoxContainer.new()
	panels.add_theme_constant_override("separation", 12)
	_crew.add_child(panels)
	var candidates := _crew_column(panels, "Кандидаты в порту")
	var members := _crew_column(panels, "На борту")
	_crew_empty = _label(members, "На борту пока только пилот.", 17, MUTED)
	_crew_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for index in range(Crew.CAPACITY):
		var candidate := _crew_card(candidates)
		candidate.hire = _button(candidate.actions)
		candidate.hire.pressed.connect(_request_crew.bind("hire", index))
		_crew_buttons.append(candidate.hire)
		_crew_candidate_rows.append(candidate)

		var member := _crew_card(members)
		member.pay = _button(member.actions)
		member.pay.pressed.connect(_request_crew.bind("pay", index))
		member.dismiss = _button(member.actions)
		member.dismiss.text = "Уволить"
		member.dismiss.pressed.connect(_request_crew.bind("dismiss", index))
		_crew_buttons.append_array([member.pay, member.dismiss])
		_crew_member_rows.append(member)
	_crew.hide()


func _crew_column(parent: HBoxContainer, title: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 338.0
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)
	_label(column, title, 20, TEXT)
	return column


func _crew_card(parent: VBoxContainer) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("112631"), Color("263f4b"), 9, 10))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	panel.add_child(content)
	var title := _label(content, "", 20, TEXT)
	var role := _label(content, "", 16, MINT)
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var detail := _label(content, "", 15, MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)
	return {"panel": panel, "title": title, "role": role, "detail": detail, "actions": actions, "id": -1}


func _refresh_crew() -> void:
	var status: Dictionary = _sim.crew_status()
	var candidates: Array = _sim.crew_candidates()
	var members: Array = status.members
	_crew_summary.text = "Места %d / %d" % [status.count, status.capacity]
	var arrears := int(status.arrears)
	if arrears > 0:
		_crew_payroll.text = "Задолженность %d кр." % arrears
	elif not members.is_empty():
		_crew_payroll.text = "Следующая выплата через %s" % _crew_eta(float(status.next_due))
	_crew_payroll.visible = not members.is_empty()
	_crew_payroll.add_theme_color_override("font_color", AMBER if arrears > 0 else MUTED)
	_crew_empty.visible = members.is_empty()
	var aboard: Array[int] = []
	for member: Dictionary in members:
		aboard.append(int(member.id))
	for index in range(_crew_candidate_rows.size()):
		var row := _crew_candidate_rows[index]
		row.panel.visible = index < candidates.size()
		row.id = -1
		if not row.panel.visible:
			continue
		var candidate: Dictionary = candidates[index]
		row.id = int(candidate.id)
		row.title.text = str(candidate.name)
		row.role.text = _crew_role(str(candidate.role))
		row.detail.text = "Жалованье %d кр. каждые 4:00" % int(candidate.wage)
		row.hire.disabled = not bool(candidate.available)
		if row.id in aboard:
			row.hire.text = "Уже на борту"
		elif members.size() >= int(status.capacity):
			row.hire.text = "Нет места"
		elif int(candidate.fee) > int(_sim.credits):
			row.hire.text = "Нужно %d кр." % int(candidate.fee)
		else:
			row.hire.text = "Нанять · %d кр." % int(candidate.fee)
	for index in range(_crew_member_rows.size()):
		var row := _crew_member_rows[index]
		row.panel.visible = index < members.size()
		row.id = -1
		if not row.panel.visible:
			continue
		var member: Dictionary = members[index]
		var debt := int(member.get("arrears", member.get("debt", 0)))
		row.id = int(member.id)
		row.title.text = str(member.name)
		row.role.text = _crew_role(str(member.role))
		row.role.add_theme_color_override("font_color", AMBER if debt > 0 else MINT)
		row.detail.text = "Жалованье %d кр. через %s" % [int(member.wage), _crew_eta(float(member.next_due))]
		if debt > 0:
			row.detail.text += "\nДолг %d кр. · Не на вахте" % debt
		row.pay.visible = debt > 0
		var payment := mini(debt, int(_sim.credits))
		row.pay.disabled = not bool(member.get("can_pay", payment > 0))
		row.pay.text = "Внести %d кр." % payment if payment > 0 else "Погасить долг"
		row.dismiss.disabled = not bool(member.get("can_dismiss", debt == 0))
		row.dismiss.tooltip_text = "Сначала погасите долг" if debt > 0 else ""


func _request_crew(action: String, index: int) -> void:
	if not is_open() or _station_page != StationPage.CREW:
		return
	var row := _crew_candidate_rows[index] if action == "hire" else _crew_member_rows[index]
	var button: Button = row[action]
	if row.id >= 0 and button.is_visible_in_tree() and not button.disabled:
		_touches.clear()
		crew_requested.emit(action, int(row.id))


func _crew_eta(due: float) -> String:
	var seconds := ceili(maxf(0.0, due - float(_sim.orbit_time)))
	return "%d:%02d" % [floori(seconds / 60.0), seconds % 60]


static func _crew_role(role: String) -> String:
	if role == "engineer":
		return "Механик · ремонт дешевле на 1 кр. за 1% корпуса"
	return "Штурман · зарядка прыжка за 2,2 с"


func _build_yard(parent: VBoxContainer) -> void:
	_yard = VBoxContainer.new()
	_yard.add_theme_constant_override("separation", 12)
	parent.add_child(_yard)
	var hulls := HBoxContainer.new()
	hulls.add_theme_constant_override("separation", 12)
	_yard.add_child(hulls)
	for id: String in ShipSystems.hull_ids():
		var row := _yard_card(hulls, ShipSystems.profile(id))
		_yard_rows.append(row)
	var terms := _label(_yard,
		"Верфь переносит оборудование, топливо и данные кают. Новый корпус выдаётся исправным. Весь груз должен помещаться в новый трюм.",
		16, MUTED)
	terms.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_yard.hide()


func _yard_card(parent: HBoxContainer, profile: Dictionary) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 338.0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(Color("112631"), Color("263f4b"), 9, 14))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	_label(content, str(profile.name), 24, TEXT)
	var description := _label(content, str(profile.description), 16, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hold := _label(content, "", 17, MINT)
	_label(content, "Специалисты для выхода · %d" % int(profile.crew_required), 17, TEXT)
	var mobility := _label(content, "Скорость %d%% · Разгон %d%%\nРасход реактивного топлива %d%%" % [
		roundi(float(profile.speed_factor) * 100.0), roundi(float(profile.accel_factor) * 100.0),
		roundi(float(profile.burn_factor) * 100.0),
	], 16, MUTED)
	mobility.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cost := _label(content, "", 17, TEXT)
	var reason := _label(content, "", 16, AMBER)
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var exchange := _button(content)
	exchange.pressed.connect(_request_yard_exchange.bind(str(profile.id)))
	return {"id": str(profile.id), "panel": panel, "hold": hold, "cost": cost, "reason": reason, "exchange": exchange}


func _refresh_yard() -> void:
	var offers: Array[Dictionary] = _sim.shipyard_offers()
	for row in _yard_rows:
		row.panel.hide()
	for offer in offers:
		for row in _yard_rows:
			if row.id != offer.id:
				continue
			row.panel.show()
			row.hold.text = "Трюм %d ед. · с расширением %d" % [int(offer.cargo), int(offer.expanded_cargo)]
			if _sim.ship.cargo_upgraded:
				row.hold.text = "Трюм %d ед. с установленным расширением" % int(offer.cargo_capacity)
			row.hold.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var installed := bool(offer.installed)
			var net := int(offer.net_cost)
			row.cost.text = "Цена %d кр." % int(offer.price)
			if not installed:
				row.cost.text += " · Зачёт %d кр." % int(offer.trade_in)
			row.cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.reason.text = "" if installed or offer.available else str(offer.reason)
			row.reason.visible = not row.reason.text.is_empty()
			row.exchange.disabled = installed or not bool(offer.available)
			if installed:
				row.exchange.text = "Ваш корабль"
			elif net >= 0:
				row.exchange.text = "Обменять · доплата %d кр." % net
			else:
				row.exchange.text = "Обменять · к получению %d кр." % -net
			break


func _request_yard_exchange(id: String) -> void:
	if not is_open() or _station_page != StationPage.YARD:
		return
	for row in _yard_rows:
		if row.id == id and row.exchange.is_visible_in_tree() and not row.exchange.disabled:
			_touches.clear()
			ship_exchange_requested.emit(id)
			return


func _refresh_transfers() -> void:
	var hold: RefCounted = _sim.mining
	_hydrogen.text = "Канистры водорода: %d · до %d ед. топлива из каждой" % [
		hold.cargo_amount("hydrogen"), ShipSystems.HYDROGEN_UNITS_PER_CANISTER,
	]
	for destination: String in _transfer_buttons:
		var offer: Dictionary = _sim.fuel_transfer_offer(destination)
		var button := _transfer_buttons[destination]
		button.disabled = not offer.ok
		_transfer_labels[destination].text = "%d кан. из трюма · +%s ед. топлива" % [
			offer.canisters, _decimal(offer.added),
		] if offer.ok else str(offer.reason)
	if hold.free_capacity() == 0:
		_cargo_options.assign(_sim.fuel_cargo_options())
	else:
		_cargo_options.clear()
	_discard_row.visible = not _cargo_options.is_empty()
	if not _discard_row.visible:
		return
	_cargo_index = posmod(_cargo_index, _cargo_options.size())
	var selected := _cargo_options[_cargo_index]
	_discard_choice.text = "%s  ›" % selected.name if _cargo_options.size() > 1 else str(selected.name)
	_discard_choice.disabled = _cargo_options.size() == 1
	var armed: bool = _discard_pending_good == selected.good
	_discard_detail.text = "Будет выброшена 1 ед. из %d." % selected.quantity if armed else "Полный трюм · %d ед. выбранного товара" % selected.quantity
	_discard_button.text = "Подтвердить выброс" if armed else "Освободить 1 место"


func close() -> void:
	_touches.clear()
	_sim = null
	hide()


func is_open() -> bool:
	return _sim != null and visible


func _request_service(action: String) -> void:
	if is_open() and not _fuel_only and _station_page == StationPage.SERVICES and _sim.service_offer(action).allowed:
		# A purchase can change the price shown for another service.
		_touches.clear()
		service_requested.emit(action)


func _request_transfer(destination: String) -> void:
	if is_open() and _fuel_only and _sim.fuel_transfer_offer(destination).ok:
		_touches.clear()
		_discard_pending_good = ""
		transfer_requested.emit(destination)


func _cycle_discard() -> void:
	if is_open() and _fuel_only and _discard_row.visible:
		_cargo_index += 1
		_discard_pending_good = ""
		_touches.clear()
		refresh()


func _confirm_discard() -> void:
	if not is_open() or not _fuel_only or not _discard_row.visible:
		return
	var good: String = _cargo_options[_cargo_index].good
	_touches.clear()
	if _discard_pending_good == good:
		_discard_pending_good = ""
		jettison_requested.emit(good)
	else:
		_discard_pending_good = good
		refresh()


func _build_discard_row() -> void:
	var row := _add_row(_transfers, "Освободить место для сбора", "")
	_discard_detail = row[0]
	_discard_button = row[1]
	_discard_button.pressed.connect(_confirm_discard)
	_discard_row = row[2]
	var actions: HBoxContainer = _discard_button.get_parent()
	_discard_choice = _button(actions)
	_discard_choice.custom_minimum_size.x = 140.0
	_discard_choice.add_theme_font_size_override("font_size", 16)
	_discard_choice.tooltip_text = "Выбрать следующий товар"
	_discard_choice.pressed.connect(_cycle_discard)
	actions.move_child(_discard_choice, _discard_button.get_index())
	_discard_button.custom_minimum_size.x = 192.0


func _add_meter(parent: HBoxContainer, title: String, fill: Color, border: Color) -> Array[Control]:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var caption := HBoxContainer.new()
	column.add_child(caption)
	_label(caption, title, 17, MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value := _label(caption, "", 17, TEXT)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.step = 0.0
	bar.custom_minimum_size.y = 10.0
	bar.add_theme_stylebox_override("background", _style(Color("07121b"), BORDER, 5, 0))
	bar.add_theme_stylebox_override("fill", _style(fill, border, 5, 0))
	column.add_child(bar)
	return [value, bar]


func _add_service(action: String, title: String, detail: String) -> Label:
	var row := _add_row(_services, title, detail)
	var button: Button = row[1]
	button.pressed.connect(_request_service.bind(action))
	_action_buttons[action] = button
	return row[0]


func _add_transfer(destination: String, title: String) -> void:
	var row := _add_row(_transfers, title, "")
	var button: Button = row[1]
	button.text = "Перелить"
	button.pressed.connect(_request_transfer.bind(destination))
	_transfer_buttons[destination] = button
	_transfer_labels[destination] = row[0]


func _add_row(parent: VBoxContainer, title: String, detail: String) -> Array[Control]:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("112631"), Color("263f4b"), 9, 6))
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
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var button := _button(row)
	button.custom_minimum_size.x = 268.0
	return [description, button, panel]


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
			elif button != null and button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(event.position):
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
	if _crew_toggle.is_visible_in_tree() and _crew_toggle.get_global_rect().has_point(point):
		return _crew_toggle
	if _yard_toggle.is_visible_in_tree() and _yard_toggle.get_global_rect().has_point(point):
		return _yard_toggle
	var buttons: Array = _action_buttons.values()
	if _fuel_only:
		buttons = _transfer_buttons.values() + [_discard_choice, _discard_button]
	elif _station_page == StationPage.CREW:
		buttons = _crew_buttons
	elif _station_page == StationPage.YARD:
		buttons = _yard_rows.map(func(row: Dictionary) -> Button: return row.exchange)
	for button: Button in buttons:
		if not button.disabled and button.is_visible_in_tree() and button.get_global_rect().has_point(point):
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


static func _decimal(value: float) -> String:
	return ("%.1f" % value).replace(".", ",")


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
