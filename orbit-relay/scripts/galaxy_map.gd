extends CanvasLayer

signal destination_selected(system_id: int)
signal jump_requested()
signal route_cancel_requested()
signal galaxy_scan_requested()
signal dismissed()

const Sector := preload("res://scripts/sector_catalog.gd")
const Expedition := preload("res://scripts/expedition.gd")
const Economy := preload("res://scripts/port_economy.gd")
const TEXT := Color("e8f4fa")
const MUTED := Color("a5bac7")
const MINT := Color("9debd7")
const AMBER := Color("f3c991")
const BORDER := Color("365561")
const SYSTEMS_PER_PAGE := 6

var _insets: MarginContainer
var _chart: GalaxyChart
var _current: Label
var _destination: Label
var _affiliation: Label
var _coordinates: Label
var _description: Label
var _distance: Label
var _cost: Label
var _fuel: Label
var _itinerary: Label
var _budget: Label
var _status: Label
var _plan_button: Button
var _jump_button: Button
var _cancel_route_button: Button
var _close_button: Button
var _dossier_button: Button
var _scope_button: Button
var _projection_button: Button
var _ship_button: Button
var _scan_button: Button
var _scope_label: Label
var _scan_label: Label
var _page_label: Label
var _previous_page_button: Button
var _next_page_button: Button
var _route_scroll: ScrollContainer
var _route_details: VBoxContainer
var _dossier_scroll: ScrollContainer
var _dossier_ports: Label
var _dossier_stock: Label
var _dossier_freight: Label
var _dossier_observations: Label
var _scroll_touch := -1
var _system_buttons: Dictionary[int, Button] = {}
var _touches: Dictionary[int, Button] = {}
var _map_touches: Dictionary[int, int] = {}
var _flight: RefCounted
var _candidate := -1
var _sector_focus := -1
var _elevation := false
var _system_page := 0
var _last_scan_count := 0
var _known: Array[int] = []


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
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	_insets.add_child(page)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	page.add_child(header)
	var title := _label(header, "Галактическая карта", 32, TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_current = _label(header, "", 18, MINT)
	_current.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dossier_button = _button(header, "Досье", 48)
	_dossier_button.custom_minimum_size.x = 124
	_dossier_button.toggle_mode = true
	_dossier_button.pressed.connect(_toggle_dossier)
	_close_button = _button(header, "Закрыть", 48)
	_close_button.custom_minimum_size.x = 124
	_close_button.pressed.connect(func() -> void: dismissed.emit())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	_build_chart(body)

	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 410
	panel.add_theme_stylebox_override("panel", _style(Color("0d1d28"), BORDER, 12, 18))
	body.add_child(panel)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 3)
	panel.add_child(details)
	var systems := GridContainer.new()
	systems.columns = 2
	systems.custom_minimum_size.y = 138
	systems.add_theme_constant_override("h_separation", 6)
	systems.add_theme_constant_override("v_separation", 3)
	details.add_child(systems)
	for id in range(Sector.SYSTEM_COUNT):
		var button := _button(systems, "", 44)
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(_select_system.bind(id))
		_system_buttons[id] = button
	_build_pager(details)
	details.add_child(HSeparator.new())
	_destination = _label(details, "", 26, TEXT)
	_affiliation = _label(details, "", 16, MINT)
	_affiliation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coordinates = _label(details, "", 14, MUTED)
	var pages := Control.new()
	pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(pages)
	_route_scroll = _page_scroll(pages)
	_route_details = VBoxContainer.new()
	_route_details.add_theme_constant_override("separation", 3)
	_route_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_route_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_route_scroll.add_child(_route_details)
	_description = _label(_route_details, "", 15, MUTED)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size.y = 47
	_distance = _metric(_route_details, "Длина пути")
	_cost = _metric(_route_details, "Расход пути")
	_fuel = _metric(_route_details, "Прыжковый запас")
	_itinerary = _label(_route_details, "", 14, MINT)
	_itinerary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_budget = _label(_route_details, "", 14, MUTED)
	_budget.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_route_details.add_child(space)

	_status = _label(_route_details, "", 14, AMBER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 27
	_status.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_build_dossier(pages)
	var routes := HBoxContainer.new()
	routes.add_theme_constant_override("separation", 8)
	details.add_child(routes)
	_plan_button = _button(routes, "Проложить", 53)
	_plan_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plan_button.pressed.connect(_plan_route)
	_cancel_route_button = _button(routes, "Сброс", 53)
	_cancel_route_button.tooltip_text = "Удалить сохранённый маршрут без расхода топлива"
	_cancel_route_button.pressed.connect(_cancel_route)
	_jump_button = _button(routes, "Прыжок", 53)
	_jump_button.custom_minimum_size.x = 106
	_jump_button.add_theme_stylebox_override("normal", _style(Color("164f4c"), MINT, 8, 12))
	_jump_button.add_theme_stylebox_override("hover", _style(Color("206760"), MINT, 8, 12))
	_jump_button.pressed.connect(_start_jump)
	get_viewport().size_changed.connect(_update_insets)
	_update_insets()
	hide()


func _build_chart(parent: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 7)
	parent.add_child(column)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 7)
	column.add_child(tools)
	_scope_button = _button(tools, "Сектор", 44)
	_scope_button.custom_minimum_size.x = 110
	_scope_button.tooltip_text = "Переключить обзор и ближний вид выбранной системы"
	_scope_button.pressed.connect(_toggle_scope)
	_projection_button = _button(tools, "Вид X/Y", 44)
	_projection_button.custom_minimum_size.x = 110
	_projection_button.tooltip_text = "Переключить горизонтальную и боковую проекции"
	_projection_button.pressed.connect(_toggle_projection)
	_ship_button = _button(tools, "К кораблю", 44)
	_ship_button.pressed.connect(_go_to_ship)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tools.add_child(gap)
	_scan_button = _button(tools, "Радиоскан", 44)
	_scan_button.pressed.connect(_scan_galaxy)
	_scope_label = _label(column, "", 15, MINT)
	_scope_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_chart = GalaxyChart.new()
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart.gui_input.connect(_chart_mouse_input)
	column.add_child(_chart)
	_scan_label = _label(column, "", 14, MUTED)
	_scan_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _build_pager(parent: VBoxContainer) -> void:
	var pager := HBoxContainer.new()
	pager.add_theme_constant_override("separation", 8)
	parent.add_child(pager)
	_previous_page_button = _button(pager, "‹", 44)
	_previous_page_button.custom_minimum_size.x = 56
	_previous_page_button.add_theme_font_size_override("font_size", 24)
	_previous_page_button.tooltip_text = "Предыдущая страница систем"
	_previous_page_button.pressed.connect(_turn_page.bind(-1))
	_page_label = _label(pager, "", 15, MUTED)
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_next_page_button = _button(pager, "›", 44)
	_next_page_button.custom_minimum_size.x = 56
	_next_page_button.add_theme_font_size_override("font_size", 24)
	_next_page_button.tooltip_text = "Следующая страница систем"
	_next_page_button.pressed.connect(_turn_page.bind(1))


func open(sim: RefCounted) -> void:
	build()
	_flight = sim
	var route: Dictionary = sim.planned_route()
	_candidate = int(route.goal) if route.get("available", false) else int(sim.system_id)
	_sector_focus = -1
	_last_scan_count = 0
	_collect_known_systems()
	_page_for_candidate()
	_clear_touches()
	_route_scroll.scroll_vertical = 0
	_show_dossier(false)
	show()
	refresh()


func refresh() -> void:
	if not is_open():
		return
	var current: int = _flight.system_id
	var plan: Dictionary = _flight.planned_route()
	var has_plan: bool = plan.get("available", false)
	var charging: bool = _flight.jump_seconds_left > 0.0
	var planned: int = int(plan.next) if has_plan else -1
	var goal: int = int(plan.goal) if has_plan else -1
	_collect_known_systems()
	if not _flight.system_known(_candidate):
		_candidate = current
		_page_for_candidate()
	var selected := Sector.system(_candidate)
	var is_current := _candidate == current
	var is_planned := _candidate == goal
	# A committed route remains exact after refuelling or equipment changes.
	var preview: Dictionary = plan if is_planned else _flight.route_preview(_candidate)
	var available: bool = preview.get("available", false) and not preview.get("legs", []).is_empty()
	_chart.current = current
	_chart.planned = planned
	_chart.candidate = _candidate
	_chart.jump_capacity = float(_flight.ship.jump_capacity())
	_chart.planned_path.assign(plan.path if has_plan else [])
	_chart.preview_path.assign(preview.path if available and not is_planned else [])
	_current.text = "Система «%s»" % Sector.system(current).name
	var contested: Array[int] = _known.filter(func(id: int) -> bool: return _flight.factions.system_state(id).stage == "war")
	_refresh_catalog(current, goal, planned)
	_refresh_scanner()
	_chart.contested = contested
	_chart.queue_redraw()

	_destination.text = str(selected.name)
	var position := Sector.system_position3(_candidate)
	_coordinates.text = "X %s   Y %s   Z %s св. л." % [_decimal(position.x), _decimal(position.y), _decimal(position.z)]
	_affiliation.text = _flight.system_faction_name(_candidate)
	if contested.has(_candidate):
		_affiliation.text += " · Оспаривается"
	var frontier: Dictionary = _flight.frontier_status()
	if int(frontier.get("system", -1)) == _candidate:
		match int(frontier.get("phase", Expedition.LOCKED)):
			Expedition.SURVEY:
				_affiliation.text += " · Идёт обследование"
			Expedition.REPORT:
				_affiliation.text += " · Ожидается отчёт"
			Expedition.BUILD:
				_affiliation.text += " · Строится станция"
	_description.text = str(selected.description)
	_distance.text = "%s св. л." % _decimal(float(preview.distance)) if available else "—"
	var jump_fuel: float = _flight.ship.jump_fuel
	_fuel.text = "%s / %d ед." % [_decimal(jump_fuel), int(_flight.ship.jump_capacity())]
	_cost.text = "%d ед." % int(preview.fuel) if available else "—"
	_itinerary.visible = available
	_budget.visible = available
	if available:
		var names := PackedStringArray()
		for system: int in preview.path:
			names.append(str(Sector.system(system).name))
		var count: int = preview.legs.size()
		_itinerary.text = "%d %s · %s" % [count, "прыжок" if count == 1 else "прыжка" if count in [2, 3, 4] else "прыжков", " → ".join(names)]
		var first: Dictionary = preview.legs[0]
		var after_first := jump_fuel - float(first.fuel)
		var after_route := jump_fuel - float(preview.fuel)
		var first_balance := "остаток %s ед." % _decimal(after_first) if after_first >= 0.0 else "не хватает %s ед." % _decimal(-after_first)
		var route_balance := "После всего пути: %s ед." % _decimal(after_route) if after_route >= 0.0 else "На весь путь не хватает: %s ед." % _decimal(-after_route)
		_budget.text = "Далее %s: %d ед. · %s\n%s" % [Sector.system(int(preview.next)).name, int(first.fuel), first_balance, route_balance]
		_budget.add_theme_color_override("font_color", MINT if after_route >= 0.0 else AMBER)
	_plan_button.disabled = is_current or is_planned or not available or charging
	_plan_button.text = "Сохранён" if is_planned else "Проложить"
	_cancel_route_button.disabled = not has_plan or charging
	var status: Dictionary = _flight.jump_status(planned) if has_plan else {}
	_jump_button.disabled = not is_planned or not status.get("ok", false) or charging
	var hint := "Выберите систему назначения."
	if not is_current:
		if not available:
			hint = str(preview.get("reason", "Нет доступного маршрута."))
		elif is_planned:
			hint = "Привод готов. Следующий переход — %s." % Sector.system(planned).name if status.get("ok", false) else str(status.get("reason", ""))
		else:
			hint = "Проложите маршрут. Каждый прыжок запускается вручную."
	if charging:
		hint = "Идёт зарядка прыжкового привода."
	_status.text = hint
	_status.add_theme_color_override("font_color", MINT if not _jump_button.disabled else MUTED if is_current else AMBER)
	if _dossier_scroll.visible:
		_refresh_dossier()


func _collect_known_systems() -> void:
	_known.clear()
	for id in range(Sector.SYSTEM_COUNT):
		if _flight.system_known(id):
			_known.append(id)


func _scope_systems() -> Array[int]:
	if _sector_focus < 0:
		return _known
	var coordinates := Sector.sector_coordinates(_sector_focus)
	return _known.filter(func(id: int) -> bool: return Sector.sector_coordinates(id) == coordinates)


func _page_for_candidate() -> void:
	var index := _scope_systems().find(_candidate)
	_system_page = maxi(0, floori(float(index) / SYSTEMS_PER_PAGE))


func _refresh_catalog(current: int, goal: int, planned: int) -> void:
	var systems := _scope_systems()
	var pages := maxi(1, ceili(float(systems.size()) / SYSTEMS_PER_PAGE))
	_system_page = clampi(_system_page, 0, pages - 1)
	var first := _system_page * SYSTEMS_PER_PAGE
	var last := mini(first + SYSTEMS_PER_PAGE, systems.size())
	var listed := systems.slice(first, last)
	for id in _system_buttons:
		var button := _system_buttons[id]
		button.visible = listed.has(id)
		if not button.visible:
			button.text = ""
			continue
		var suffix := ""
		if id == current:
			suffix = " · Корабль"
		elif id == goal:
			suffix = " · Цель"
		elif id == planned:
			suffix = " · Далее"
		button.text = str(Sector.system(id).name) + suffix
		button.set_pressed_no_signal(id == _candidate)
	_previous_page_button.disabled = _system_page == 0
	_next_page_button.disabled = _system_page + 1 >= pages
	_page_label.text = "%d–%d из %d" % [first + 1, last, systems.size()]
	_scope_button.text = "Обзор" if _sector_focus >= 0 else "Сектор"
	_projection_button.text = "Вид X/Z" if _elevation else "Вид X/Y"
	if _sector_focus >= 0:
		var sector := Sector.sector_coordinates(_sector_focus)
		_scope_label.text = "Сектор %d / %d · %d × %d св. л. в X/Y · Известно систем: %d" % [
			sector.x, sector.y, int(Sector.SECTOR_SIZE), int(Sector.SECTOR_SIZE), systems.size()
		]
	else:
		_scope_label.text = "Обзор · Известно систем: %d" % systems.size()
	_chart.set_systems(_known, systems, _sector_focus, _elevation)


func _refresh_scanner() -> void:
	var scan: Dictionary = _flight.galaxy_scan_status()
	_scan_button.disabled = not scan.allowed
	_scan_button.tooltip_text = "Искать новые системы возле корабля" if scan.allowed else str(scan.reason)
	var result := "Новых сигналов: %d" % int(scan.unseen_count) if scan.allowed else str(scan.reason)
	if _last_scan_count > 0:
		result = "Открыто систем: %d · %s" % [_last_scan_count, result]
	_scan_label.text = "Радиус поиска %s св. л. · %s" % [_decimal(float(scan.range)), result]


func _toggle_scope() -> void:
	if is_open():
		_clear_touches()
		_sector_focus = _candidate if _sector_focus < 0 else -1
		_page_for_candidate()
		refresh()


func _toggle_projection() -> void:
	if is_open():
		_clear_touches()
		_elevation = not _elevation
		refresh()


func _go_to_ship() -> void:
	if is_open():
		_sector_focus = int(_flight.system_id)
		_select_system(_sector_focus)


func _turn_page(delta: int) -> void:
	if is_open():
		_clear_touches()
		_system_page += delta
		refresh()


func _scan_galaxy() -> void:
	if is_open() and not _scan_button.disabled:
		_clear_touches()
		var before := _known.size()
		galaxy_scan_requested.emit()
		if is_open():
			_collect_known_systems()
			_last_scan_count = maxi(0, _known.size() - before)
			refresh()


static func _page_scroll(parent: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return scroll


func _build_dossier(parent: Control) -> void:
	_dossier_scroll = _page_scroll(parent)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	_dossier_scroll.add_child(content)
	_label(content, "Действующие порты", 17, MINT)
	_dossier_ports = _dossier_text(content)
	_label(content, "Товары на складах", 17, MINT)
	_dossier_stock = _dossier_text(content)
	_label(content, "Межзвёздные поставки", 17, MINT)
	_dossier_freight = _dossier_text(content)
	_label(content, "Замеры тел", 17, MINT)
	_dossier_observations = _dossier_text(content)
	_dossier_scroll.hide()


func _refresh_dossier() -> void:
	var system: Dictionary = _flight.system_dossier(_candidate)
	if not system.known:
		_dossier_ports.text = "Сведения о системе ещё не получены."
		_dossier_stock.text = "Нет сведений."
		_dossier_freight.text = "Нет сведений."
		_dossier_observations.text = "Нет замеров."
		return
	var ports := PackedStringArray()
	for port: int in system.ports:
		ports.append(str(Sector.site(port).name))
	_dossier_ports.text = " · ".join(ports) if not ports.is_empty() else "Действующих портов нет."
	var stock := PackedStringArray()
	for good: String in Economy.GOODS:
		if system.goods.has(good):
			stock.append("%s %d" % [Economy.good_name(good), int(system.goods[good])])
	_dossier_stock.text = " · ".join(stock) if not stock.is_empty() else "Нет складских записей."
	var freight := PackedStringArray()
	for shipment: Dictionary in system.imports:
		freight.append(_shipment_text("Входящий", shipment, int(shipment.origin)))
	for shipment: Dictionary in system.exports:
		freight.append(_shipment_text("Исходящий", shipment, int(shipment.destination)))
	_dossier_freight.text = "\n".join(freight) if not freight.is_empty() else "Межзвёздных грузов в пути нет."
	var observations := PackedStringArray([
		"Обследовано %d из %d." % [int(system.scan_count), int(system.target_count)]
	])
	for site: int in system.observations:
		var report: Dictionary = _flight.body_dossier(site)
		if report.known:
			observations.append(_observation_text(report))
	if system.observations.is_empty():
		observations.append("Для замера подойдите к телу и откройте данные на карте системы.")
	_dossier_observations.text = "\n".join(observations)


func _toggle_dossier() -> void:
	if is_open():
		_clear_touches()
		_show_dossier(not _dossier_scroll.visible)
		if _dossier_scroll.visible:
			_refresh_dossier()


func _show_dossier(shown: bool) -> void:
	_dossier_scroll.visible = shown
	_dossier_scroll.scroll_vertical = 0
	_route_scroll.visible = not shown
	_route_details.visible = not shown
	_dossier_button.text = "Маршрут" if shown else "Досье"
	_dossier_button.set_pressed_no_signal(shown)


static func _dossier_text(content: Container) -> Label:
	var label := _label(content, "", 15, TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func _shipment_text(direction: String, shipment: Dictionary, port: int) -> String:
	var system := Sector.system(Sector.system_of_site(port))
	return "%s · %s, %d ед. · %s" % [direction, shipment.good_name, int(shipment.amount), system.name]


static func _observation_text(report: Dictionary) -> String:
	var data: Dictionary = report.data
	var details := PackedStringArray(["радиус %s м" % _decimal(float(data.radius))])
	if float(data.period) > 0.0:
		details.append("период %s мин" % _decimal(float(data.period) / 60.0))
	if float(data.atmosphere_height) > 0.0:
		details.append("атмосфера %s м" % _decimal(float(data.atmosphere_height)))
	return "%s · %s" % [report.name, " · ".join(details)]


func close() -> void:
	_clear_touches()
	_flight = null
	hide()


func is_open() -> bool:
	return _flight != null and visible


func _select_system(id: int) -> void:
	if is_open() and _flight.system_known(id):
		if _candidate != id:
			_dossier_scroll.scroll_vertical = 0
			_route_scroll.scroll_vertical = 0
		_candidate = id
		_page_for_candidate()
		_clear_touches()
		refresh()


func _plan_route() -> void:
	if is_open() and not _plan_button.disabled:
		_clear_touches()
		destination_selected.emit(_candidate)


func _start_jump() -> void:
	if not is_open():
		return
	var route: Dictionary = _flight.planned_route()
	if _flight.jump_seconds_left <= 0.0 and route.get("available", false) and int(route.goal) == _candidate and _flight.jump_status(int(route.next)).ok:
		_clear_touches()
		jump_requested.emit()


func _cancel_route() -> void:
	if is_open() and not _cancel_route_button.disabled:
		_clear_touches()
		_candidate = int(_flight.system_id)
		if _sector_focus >= 0:
			_sector_focus = _candidate
		_page_for_candidate()
		route_cancel_requested.emit()


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	var scroll := _dossier_scroll if _dossier_scroll.visible else _route_scroll
	if event is InputEventScreenTouch:
		var button: Button = _touches.get(event.index)
		var system_id: int = _map_touches.get(event.index, -1)
		_touches.erase(event.index)
		_map_touches.erase(event.index)
		if event.index == _scroll_touch:
			_scroll_touch = -1
		if not event.canceled:
			if event.pressed:
				var hit := _button_at(event.position)
				if hit != null:
					if hit not in _touches.values():
						_touches[event.index] = hit
				elif scroll.get_global_rect().has_point(event.position):
					if _scroll_touch < 0:
						_scroll_touch = event.index
				else:
					var marker := _chart_system_at(event.position)
					if marker >= 0 and marker not in _map_touches.values():
						_map_touches[event.index] = marker
			elif button != null and button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(event.position):
				button.pressed.emit()
			elif system_id >= 0 and _chart_system_at(event.position) == system_id:
				_select_system(system_id)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _scroll_touch:
			scroll.scroll_vertical = maxi(0, scroll.scroll_vertical - roundi(event.relative.y))
		var button: Button = _touches.get(event.index)
		if button != null and not button.get_global_rect().has_point(event.position):
			_touches.erase(event.index)
		if _map_touches.has(event.index) and _chart_system_at(event.position) != _map_touches[event.index]:
			_map_touches.erase(event.index)
		get_viewport().set_input_as_handled()


func _chart_mouse_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var id := _chart.system_at(event.position)
		if id >= 0:
			_select_system(id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_clear_touches()


func _clear_touches() -> void:
	_touches.clear()
	_map_touches.clear()
	_scroll_touch = -1


func _button_at(point: Vector2) -> Button:
	for button: Button in [
		_plan_button, _cancel_route_button, _jump_button, _dossier_button, _close_button,
		_scope_button, _projection_button, _ship_button, _scan_button, _previous_page_button, _next_page_button
	]:
		if not button.disabled and button.get_global_rect().has_point(point):
			return button
	for button: Button in _system_buttons.values():
		if button.is_visible_in_tree() and button.get_global_rect().has_point(point):
			return button
	return null


func _chart_system_at(point: Vector2) -> int:
	var local := _chart.get_global_transform_with_canvas().affine_inverse() * point
	return _chart.system_at(local)


func _update_insets() -> void:
	var insets := Vector4(24, 20, 24, 20)
	if OS.has_feature("android"):
		var display := Vector2(DisplayServer.window_get_size())
		var safe := DisplayServer.get_display_safe_area()
		if display.x > 0.0 and display.y > 0.0 and safe.has_area():
			var scale := get_viewport().get_visible_rect().size / display
			insets.x += maxf(0.0, safe.position.x * scale.x)
			insets.y += maxf(0.0, safe.position.y * scale.y)
			insets.z += maxf(0.0, (display.x - safe.end.x) * scale.x)
			insets.w += maxf(0.0, (display.y - safe.end.y) * scale.y)
	_insets.add_theme_constant_override("margin_left", ceili(insets.x))
	_insets.add_theme_constant_override("margin_top", ceili(insets.y))
	_insets.add_theme_constant_override("margin_right", ceili(insets.z))
	_insets.add_theme_constant_override("margin_bottom", ceili(insets.w))


static func _decimal(value: float) -> String:
	return ("%.1f" % value).replace(".", ",")


static func _metric(parent: Container, caption: String) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)
	_label(row, caption, 16, MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var metric := _label(row, "", 18, TEXT)
	metric.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return metric


static func _label(parent: Container, caption: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)
	return label


static func _button(parent: Container, caption: String, height: float) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = height
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_pressed_color", MINT)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", _style(Color("102632"), Color("21404e"), 8, 12))
	button.add_theme_stylebox_override("hover", _style(Color("163743"), BORDER, 8, 12))
	button.add_theme_stylebox_override("pressed", _style(Color("1b454d"), MINT, 8, 12))
	button.add_theme_stylebox_override("disabled", _style(Color("10202a"), BORDER, 8, 12))
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
	box.content_margin_top = padding * 0.65
	box.content_margin_bottom = padding * 0.65
	return box


class GalaxyChart extends Control:
	const FIELD := Color("081622")
	const GRID := Color("162c39")

	var current := -1
	var planned := -1
	var candidate := -1
	var jump_capacity := 0.0
	var planned_path: Array[int] = []
	var preview_path: Array[int] = []
	var contested: Array[int] = []
	var _sky := PackedVector3Array()
	var _known_systems: Array[int] = []
	var _systems: Array[int] = []
	var _points: Dictionary[int, Vector2] = {}
	var _center := Vector2.ZERO
	var _extent := Vector2.ONE
	var _label_boxes: Array[Rect2] = []
	var _detailed := false
	var _elevation := false

	func _ready() -> void:
		var random := RandomNumberGenerator.new()
		random.seed = 77106
		for i in range(128):
			_sky.append(Vector3(random.randf(), random.randf(), random.randf()))
		resized.connect(queue_redraw)

	func set_systems(known: Array[int], systems: Array[int], focus: int, elevation: bool) -> void:
		_known_systems = known
		_systems = systems
		_detailed = focus >= 0
		_elevation = elevation
		_points.clear()
		if _systems.is_empty():
			return
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for id in _systems:
			var coordinates := Sector.system_position3(id)
			var point := Vector2(coordinates.x, -coordinates.z if elevation else coordinates.y)
			_points[id] = point
			low = low.min(point)
			high = high.max(point)
		if _detailed:
			var corner := Vector2(Sector.sector_coordinates(focus)) * Sector.SECTOR_SIZE
			low.x = corner.x
			high.x = corner.x + Sector.SECTOR_SIZE
			if elevation:
				low.y = minf(low.y, -Sector.SECTOR_SIZE * 0.5)
				high.y = maxf(high.y, Sector.SECTOR_SIZE * 0.5)
			else:
				low.y = corner.y
				high.y = corner.y + Sector.SECTOR_SIZE
		_center = (low + high) * 0.5
		_extent = (high - low).max(Vector2.ONE)

	func marker_position(id: int) -> Vector2:
		return size * 0.5 + (_points.get(id, _center) - _center) * _pixels_per_light_year()

	func system_at(point: Vector2) -> int:
		if not Rect2(Vector2.ZERO, size).has_point(point):
			return -1
		var nearest := -1
		var limit := 45.0 * 45.0
		for id in _systems:
			var distance := marker_position(id).distance_squared_to(point)
			if distance <= limit:
				nearest = id
				limit = distance
		return nearest

	func _pixels_per_light_year() -> float:
		var span := (size - Vector2(210, 200)).max(Vector2.ONE)
		return minf(span.x / _extent.x, span.y / _extent.y)

	func _draw() -> void:
		var bounds := Rect2(Vector2.ZERO, size)
		draw_rect(bounds, FIELD)
		draw_rect(bounds.grow(-0.5), BORDER, false, 1.0)
		for step in range(1, 8):
			var x := size.x * step / 8.0
			draw_line(Vector2(x, 1), Vector2(x, size.y - 1), GRID)
		for step in range(1, 6):
			var y := size.y * step / 6.0
			draw_line(Vector2(1, y), Vector2(size.x - 1, y), GRID)
		for star in _sky:
			var point := Vector2(star.x, star.y) * (size - Vector2.ONE * 18.0) + Vector2.ONE * 9.0
			draw_circle(point, 0.65 + star.z * 0.95, Color(0.65, 0.80, 1.0, 0.08 + star.z * 0.32), true, -1.0, true)
		if _detailed:
			var span := _extent * _pixels_per_light_year()
			draw_rect(Rect2((size - span) * 0.5, span), BORDER, false, 1.0)
		var active := _route_path(planned_path, planned)
		var preview_fallback := -1 if not active.is_empty() and candidate == active[-1] else candidate
		var preview := _route_path(preview_path, preview_fallback)
		if preview == active:
			preview = []
		_draw_routes(active, preview)
		for id in _systems:
			_draw_marker(id, active)
		_label_boxes.clear()
		# Route endpoints receive space before optional intermediate captions.
		var order := _systems.duplicate()
		order.sort_custom(func(a: int, b: int) -> bool:
			return _label_priority(a, active, preview) < _label_priority(b, active, preview))
		for id in order:
			_draw_label(id, active, preview)
		_draw_scale()
		draw_string(ThemeDB.fallback_font, size - Vector2(81, 17), "X →  Z ↑" if _elevation else "X →  Y ↓",
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, MUTED)

	func _route_path(requested: Array[int], fallback: int) -> Array[int]:
		var path: Array[int] = requested.duplicate()
		if path.is_empty() and _known_systems.has(current) and _known_systems.has(fallback) and current != fallback:
			path = [current, fallback]
		if path.size() < 2 or path.size() > _known_systems.size() or path[0] != current:
			return []
		var visited: Array[int] = []
		for step in range(path.size()):
			var id := path[step]
			if not _known_systems.has(id) or visited.has(id):
				return []
			if step > 0 and Sector.jump_cost(path[step - 1], id) <= 0:
				return []
			visited.append(id)
		return path

	func _has_edge(path: Array[int], a: int, b: int) -> bool:
		for step in range(1, path.size()):
			if (path[step - 1] == a and path[step] == b) or (path[step - 1] == b and path[step] == a):
				return true
		return false

	func _draw_routes(active: Array[int], preview: Array[int]) -> void:
		if _systems.has(current):
			for id in _systems:
				var cost := Sector.jump_cost(current, id)
				if cost <= 0 or cost > jump_capacity or _has_edge(active, current, id) or _has_edge(preview, current, id):
					continue
				_draw_leg(current, id, Color("425e69"), 1.1, true, false)
		for step in range(1, active.size()):
			_draw_leg(active[step - 1], active[step], MINT, 2.6, false, true)
		for step in range(1, preview.size()):
			var shift := 4.0 if _has_edge(active, preview[step - 1], preview[step]) else 0.0
			_draw_leg(preview[step - 1], preview[step], AMBER, 1.8, true, true, shift)

	func _leg_points(a: int, b: int, shift := 0.0) -> PackedVector2Array:
		if not _systems.has(a) or not _systems.has(b) or Sector.jump_cost(a, b) <= 0:
			return PackedVector2Array()
		var origin := marker_position(a)
		var end := marker_position(b)
		var distance := origin.distance_to(end)
		if distance <= 2.0:
			return PackedVector2Array()
		var direction := origin.direction_to(end)
		var offset := direction.orthogonal() * shift
		var clearance := minf(37.0, distance * 0.34)
		return PackedVector2Array([origin + direction * clearance + offset, end - direction * clearance + offset])

	func _draw_leg(a: int, b: int, tint: Color, width: float, dashed: bool, arrow: bool, shift := 0.0) -> void:
		var points := _leg_points(a, b, shift)
		if points.is_empty():
			return
		var direction := points[0].direction_to(points[1])
		if dashed:
			draw_dashed_line(points[0], points[1], tint, width, 7.0, true, true)
		else:
			draw_line(points[0], points[1], Color(tint, 0.12), width + 4.0, true)
			draw_line(points[0], points[1], tint, width, true)
		if arrow:
			var length := minf(10.0, points[0].distance_to(points[1]) * 0.45)
			var side := direction.orthogonal() * length * 0.52
			var base := points[1] - direction * length
			draw_colored_polygon(PackedVector2Array([points[1], base + side, base - side]), tint)

	func _draw_marker(id: int, active: Array[int]) -> void:
		var system := Sector.system(id)
		var point := marker_position(id)
		var accent: Color = system.accent
		var scale := _marker_scale(id, active)
		draw_circle(point, 32.0 * scale, Color(accent, 0.07), true, -1.0, true)
		draw_circle(point, 18.0 * scale, Color(accent, 0.16), true, -1.0, true)
		draw_arc(point, 23.0 * scale, 0.0, TAU, 48, Color(accent, 0.70), 1.2, true)
		draw_circle(point, 9.0 * scale, accent, true, -1.0, true)
		draw_circle(point, 4.0 * scale, accent.lerp(Color.WHITE, 0.72), true, -1.0, true)
		if contested.has(id):
			var warning := point + Vector2(20, -19)
			draw_circle(warning, 8.0, FIELD, true, -1.0, true)
			draw_arc(warning, 6.0, 0.0, TAU, 18, AMBER, 1.5, true)
			draw_line(warning - Vector2(0, 3), warning, AMBER, 1.4, true)
			draw_circle(warning + Vector2(0, 2.4), 0.9, AMBER, true, -1.0, true)
		if id == current:
			draw_colored_polygon(PackedVector2Array([point + Vector2(0, -43), point + Vector2(6, -34), point + Vector2(-6, -34)]), MINT)
		if id == candidate:
			for i in range(4):
				var angle := i * TAU * 0.25 + 0.15
				draw_arc(point, 32.0, angle, angle + 1.27, 12, MINT if active.has(id) or id == current else AMBER, 2.2, true)
		if active.size() > 2 and (id == active[1] or id == active.back()):
			draw_arc(point, 27.0, 0.0, TAU, 48, MINT, 1.4, true)

	func _marker_scale(id: int, active: Array[int]) -> float:
		return 0.55 if not _detailed and Sector.is_generated_system(id) and id != current and id != candidate and not active.has(id) else 1.0

	func _label_priority(id: int, active: Array[int], preview: Array[int]) -> int:
		if id == current:
			return 0
		if not active.is_empty() and id == active.back():
			return 1
		if active.size() > 2 and id == active[1]:
			return 2
		if id == candidate or (not preview.is_empty() and id == preview.back()):
			return 3
		return 4 + id

	func _draw_label(id: int, active: Array[int], preview: Array[int]) -> void:
		var point := marker_position(id)
		var annotation := ""
		var tint := MINT
		if id == current:
			annotation = "Корабль"
		elif not active.is_empty() and id == active.back():
			annotation = "Цель маршрута"
		elif active.size() > 2 and id == active[1]:
			annotation = "Следующий"
		elif active.has(id):
			annotation = "Переход %d" % active.find(id)
		elif not preview.is_empty() and id == preview.back():
			annotation = "Просмотр"
			tint = AMBER
		elif id == candidate:
			annotation = "Выбрано"
			tint = AMBER
		var font := ThemeDB.fallback_font
		var name: String = Sector.system(id).name
		for sizes: Vector2i in [Vector2i(21, 14), Vector2i(18, 12)]:
			var name_width := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sizes.x).x
			var note_width := font.get_string_size(annotation, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sizes.y).x
			var extent := Vector2(maxf(name_width, note_width) + 16.0, sizes.x + sizes.y + 11.0 if not annotation.is_empty() else sizes.x + 8.0)
			for at: Vector2 in [point + Vector2(-extent.x * 0.5, 43.0), point - Vector2(extent.x * 0.5, 54.0 + extent.y), point + Vector2(43.0, -extent.y * 0.5), point - Vector2(43.0 + extent.x, extent.y * 0.5)]:
				var box := Rect2(at.clamp(Vector2.ONE * 8.0, (size - extent - Vector2.ONE * 8.0).max(Vector2.ONE * 8.0)), extent)
				var blocked := not Rect2(Vector2.ZERO, size).encloses(box)
				for other in _label_boxes:
					blocked = blocked or box.grow(3.0).intersects(other)
				for system_id in _systems:
					var scale := _marker_scale(system_id, active)
					blocked = blocked or box.intersects(Rect2(marker_position(system_id) - Vector2(35, 45) * scale, Vector2(70, 80) * scale))
				if blocked:
					continue
				_label_boxes.append(box)
				draw_rect(box, FIELD)
				draw_string(font, box.position + Vector2((extent.x - name_width) * 0.5, sizes.x + 1.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sizes.x, TEXT)
				if not annotation.is_empty():
					draw_string(font, box.position + Vector2((extent.x - note_width) * 0.5, sizes.x + sizes.y + 5.0), annotation, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sizes.y, tint)
				return

	func _draw_scale() -> void:
		var pixels := _pixels_per_light_year()
		var units := 1.0
		if pixels < 20.0:
			units = 5.0
		var left := Vector2(22, 27)
		var right := left + Vector2(pixels * units, 0)
		draw_line(left, right, MUTED, 1.0, true)
		draw_line(left - Vector2(0, 4), left + Vector2(0, 4), MUTED, 1.0, true)
		draw_line(right - Vector2(0, 4), right + Vector2(0, 4), MUTED, 1.0, true)
		draw_string(ThemeDB.fallback_font, right + Vector2(10, 5), "%d св. л." % int(units), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, MUTED)
