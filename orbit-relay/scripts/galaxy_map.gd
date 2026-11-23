extends CanvasLayer

signal destination_selected(system_id: int)
signal jump_requested()
signal emergency_jump_requested()
signal hyperspace_track_requested()
signal hyperspace_analysis_requested(id: String)
signal route_cancel_requested()
signal galaxy_scan_requested()
signal dismissed()

const Sector := preload("res://scripts/sector_catalog.gd")
const GalaxyChart := preload("res://scripts/galaxy_chart.gd")
const Expedition := preload("res://scripts/expedition.gd")
const Economy := preload("res://scripts/port_economy.gd")
const MissionCalendar := preload("res://scripts/mission_calendar.gd")
const SystemDossier := preload("res://scripts/system_dossier.gd")
const NamedSystems := preload("res://scripts/named_systems.gd")
const FactionFronts := preload("res://scripts/faction_fronts.gd")
const TEXT := Color("e8f4fa")
const MUTED := Color("a5bac7")
const MINT := Color("9debd7")
const AMBER := Color("f3c991")
const BORDER := Color("365561")
const SYSTEMS_PER_PAGE := 6
const CHART_MOUSE := -2
const DRAG_THRESHOLD := 12.0

enum DossierPage { OVERVIEW, TRADE, ARCHIVE }

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
var _drive: Label
var _travel_time: Label
var _arrival: Label
var _itinerary: Label
var _budget: Label
var _leg_times: Label
var _status: Label
var _plan_button: Button
var _jump_button: Button
var _emergency_row: HBoxContainer
var _emergency_label: Label
var _emergency_button: Button
var _emergency_armed := false
var _echo_row: HBoxContainer
var _echo_label: Label
var _echo_track: Button
var _echo_analyze: Button
var _cancel_route_button: Button
var _close_button: Button
var _dossier_button: Button
var _scope_button: Button
var _atlas_button: Button
var _projection_button: Button
var _drag_button: Button
var _ship_button: Button
var _core_button: Button
var _zoom_in_button: Button
var _zoom_out_button: Button
var _scan_button: Button
var _scope_label: Label
var _scan_label: Label
var _page_label: Label
var _previous_page_button: Button
var _next_page_button: Button
var _directory_button: Button
var _route_scroll: ScrollContainer
var _route_details: VBoxContainer
var _dossier_layout: VBoxContainer
var _dossier_scroll: ScrollContainer
var _dossier_pages: Array[VBoxContainer] = []
var _dossier_tabs: Array[Button] = []
var _dossier_stars: Label
var _dossier_population: Label
var _dossier_ports: Label
var _dossier_customs: PanelContainer
var _dossier_customs_rule: Label
var _dossier_stock: Label
var _dossier_imports: Label
var _dossier_exports: Label
var _dossier_secondary: Label
var _dossier_observations: Label
var _dossier_archive_title: Label
var _dossier_archive_text: Label
var _scroll_touch := -1
var _catalog_buttons: Array[Button] = []
var _system_buttons: Dictionary[int, Button] = {}
var _touches: Dictionary[int, Button] = {}
var _mouse_catalog_button: Button
var _chart_pointer := -1
var _chart_press_point := Vector2.ZERO
var _chart_last_point := Vector2.ZERO
var _chart_pressed_system := -1
var _chart_dragged := false
var _rotate_drag := false
var _flight: RefCounted
var _candidate := -1
var _sector_focus := -1
var _atlas := false
var _directory := false
var _elevation := false
var _system_page := 0
var _last_scan_count := 0
var _known: Array[int] = []
var _known_lookup: Dictionary[int, bool] = {}


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
	for _slot in range(SYSTEMS_PER_PAGE):
		var button := _button(systems, "", 44)
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(_select_listed_system.bind(button))
		_catalog_buttons.append(button)
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
	_drive = _metric(_route_details, "Привод")
	_travel_time = _metric(_route_details, "Время переходов")
	_arrival = _label(_route_details, "", 14, MUTED)
	_arrival.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_itinerary = _label(_route_details, "", 14, MINT)
	_itinerary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_budget = _label(_route_details, "", 14, MUTED)
	_budget.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_leg_times = _label(_route_details, "", 14, MUTED)
	_leg_times.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_route_details.add_child(space)

	_status = _label(_route_details, "", 14, AMBER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 27
	_status.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_build_dossier(pages)
	_emergency_row = HBoxContainer.new()
	_emergency_row.add_theme_constant_override("separation", 8)
	details.add_child(_emergency_row)
	_emergency_label = _label(_emergency_row, "", 14, AMBER)
	_emergency_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_emergency_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_emergency_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_emergency_button = _button(_emergency_row, "Аварийный прыжок", 44)
	_emergency_button.pressed.connect(_request_emergency_jump)
	_emergency_row.hide()
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
	_atlas_button = _button(tools, "Атлас", 44)
	_atlas_button.toggle_mode = true
	_atlas_button.tooltip_text = "Показать плотность всего звёздного каталога"
	_atlas_button.pressed.connect(_toggle_atlas)
	_projection_button = _button(tools, "Вид X/Y", 44)
	_projection_button.custom_minimum_size.x = 110
	_projection_button.tooltip_text = "Переключить горизонтальную и боковую проекции, сбросив поворот"
	_projection_button.pressed.connect(_toggle_projection)
	_ship_button = _button(tools, "К кораблю", 44)
	_ship_button.pressed.connect(_go_to_ship)
	_zoom_out_button = _button(tools, "−", 44)
	_zoom_out_button.custom_minimum_size.x = 44
	_zoom_out_button.tooltip_text = "Уменьшить масштаб карты"
	_zoom_out_button.pressed.connect(_zoom_chart.bind(1.0 / 1.5))
	_zoom_in_button = _button(tools, "+", 44)
	_zoom_in_button.custom_minimum_size.x = 44
	_zoom_in_button.tooltip_text = "Увеличить масштаб карты"
	_zoom_in_button.pressed.connect(_zoom_chart.bind(1.5))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tools.add_child(gap)
	_scan_button = _button(tools, "Радиоскан", 44)
	_scan_button.pressed.connect(_scan_galaxy)
	var scope := HBoxContainer.new()
	scope.add_theme_constant_override("separation", 7)
	column.add_child(scope)
	_scope_label = _label(scope, "", 15, MINT)
	_scope_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scope_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scope_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_drag_button = _button(scope, "Поворот", 44)
	_drag_button.custom_minimum_size.x = 108
	_drag_button.toggle_mode = true
	_drag_button.pressed.connect(_toggle_drag_mode)
	_core_button = _button(scope, "К ядру", 44)
	_core_button.tooltip_text = "Показать ядро на атласе. Для полёта открывайте соседние системы радиосканом."
	_core_button.pressed.connect(_go_to_core)
	_chart = GalaxyChart.new()
	_chart.rotation_availability_changed.connect(_set_rotation_available)
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_chart)
	_chart.resized.connect(_refresh_atlas_caption)
	_set_rotation_available(true)
	_scan_label = _label(column, "", 14, MUTED)
	_scan_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_echo_row = HBoxContainer.new()
	_echo_row.add_theme_constant_override("separation", 7)
	column.add_child(_echo_row)
	_echo_label = _label(_echo_row, "", 14, MINT)
	_echo_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_echo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_echo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_echo_track = _button(_echo_row, "Навестись", 44)
	_echo_track.pressed.connect(_request_hyperspace_track)
	_echo_analyze = _button(_echo_row, "Анализ", 44)
	_echo_analyze.pressed.connect(_request_hyperspace_analysis)
	_echo_row.hide()


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
	_directory_button = _button(pager, "Именные", 44)
	_directory_button.toggle_mode = true
	_directory_button.pressed.connect(_toggle_directory)


func open(sim: RefCounted) -> void:
	build()
	_flight = sim
	_emergency_armed = false
	var route: Dictionary = sim.planned_route()
	_candidate = int(route.goal) if route.get("available", false) else int(sim.system_id)
	_sector_focus = -1
	_atlas = false
	_directory = false
	_chart.reset_view()
	_last_scan_count = 0
	_collect_known_systems()
	# A large survey opens on its bounded density/sector atlas. The catalogue
	# still contains every discovery and the traditional view stays selectable.
	_atlas = _known.size() > Sector.SYSTEM_COUNT
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
	var drive: Dictionary = _flight.jump_drive_status()
	_chart.current = current
	_chart.planned = planned
	_chart.candidate = _candidate
	_chart.jump_capacity = float(drive.jump_capacity)
	_chart.jump_tariff = Callable(_flight, "jump_tariff")
	_chart.planned_path.assign(plan.path if has_plan else [])
	_chart.preview_path.assign(preview.path if available and not is_planned else [])
	_current.text = "Система «%s»" % Sector.system(current).name
	var contested: Array[int] = []
	for id: int in FactionFronts.FRONTIER_SYSTEMS:
		if _known_lookup.has(id) and _flight.factions.system_state(id).stage == "war":
			contested.append(id)
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
	var jump_fuel: float = drive.reserve
	_fuel.text = "%s / %d ед." % [_decimal(jump_fuel), roundi(_chart.jump_capacity)]
	_cost.text = "%d ед." % int(preview.fuel) if available else "—"
	_drive.text = "%s · %s т · до %s св. л." % [
		drive.name, _decimal(float(drive.mass_t)), _decimal(float(drive.range_ly)),
	]
	_drive.tooltip_text = "Расчёт по текущей массе и запасу. При полном баке до %s св. л." % _decimal(float(drive.max_range_ly))
	_refresh_travel_estimates(preview, available)
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
	_refresh_emergency_jump(is_planned, charging)
	_refresh_hyperspace_echo()
	var hint := "Выберите систему назначения."
	if not is_current:
		if not available:
			hint = str(preview.get("reason", "Нет доступного маршрута."))
		elif is_planned:
			hint = "Привод готов. Следующий переход — %s." % Sector.system(planned).name if status.get("ok", false) else str(status.get("reason", ""))
		else:
			hint = "Проложите маршрут. Каждый прыжок запускается вручную."
	if charging:
		hint = "Идёт межзвёздный переход." if _flight.jump_progress_status().is_transit else "Идёт зарядка прыжкового привода."
	_status.text = hint
	_status.add_theme_color_override("font_color", MINT if not _jump_button.disabled else MUTED if is_current else AMBER)
	if _dossier_scroll.visible:
		_refresh_dossier()


func _refresh_travel_estimates(preview: Dictionary, available: bool) -> void:
	var seconds := float(preview.get("seconds", 0.0)) if available else 0.0
	_travel_time.text = _duration(seconds) if seconds > 0.0 else "—"
	_arrival.visible = seconds > 0.0
	_leg_times.visible = seconds > 0.0
	if seconds <= 0.0:
		return
	_arrival.text = "Прибытие по расчёту · %s" % MissionCalendar.stamp(float(_flight.orbit_time) + seconds)
	var schedule := PackedStringArray()
	for leg: Dictionary in preview.legs:
		var origin := str(Sector.system(int(leg.origin)).name)
		var destination := str(Sector.system(int(leg.destination)).name)
		schedule.append("%s → %s · %s" % [origin, destination, _duration(float(leg.seconds))])
	_leg_times.text = "\n".join(schedule)


func _refresh_emergency_jump(planned: bool, charging: bool) -> void:
	var status: Dictionary = _flight.emergency_jump_status()
	_emergency_row.visible = planned and not charging and bool(status.damage_eligible)
	_emergency_button.disabled = not bool(status.ok)
	if not _emergency_row.visible or _emergency_button.disabled:
		_emergency_armed = false
	_emergency_button.text = "Подтвердить" if _emergency_armed else "Аварийный прыжок"
	if int(status.destination) < 0 or not status.ok:
		_emergency_label.text = str(status.reason)
	else:
		var refuge := str(Sector.system(int(status.destination)).name)
		_emergency_label.text = "Выход в «%s» · %d ед." % [refuge, int(status.cost)]
		if status.fault_risk:
			_emergency_label.text += " · Привод потребует перезапуска"


func _refresh_hyperspace_echo() -> void:
	var echo: Dictionary = _flight.hyperspace_trail_status()
	_echo_row.visible = bool(echo.active)
	_echo_track.disabled = not bool(echo.targetable)
	_echo_track.text = "Следующий" if echo.tracking and int(echo.count) > 1 else "Навестись"
	_echo_analyze.disabled = not bool(echo.readable)
	if not echo.active:
		return
	var distance := "%d м" % roundi(float(echo.distance))
	if not echo.readable:
		_echo_label.text = "Гиперпространственный след · %s\n%s" % [distance, echo.reason]
		return
	var kind: String = {"departure": "Уходящий", "incoming": "Прибывающий", "residual": "Остаточный"}.get(echo.kind, "След")
	var origin := str(Sector.system(int(echo.origin)).name)
	var destination := str(Sector.system(int(echo.destination)).name)
	var timing := " · до выхода %s" % _duration(float(echo.eta)) if float(echo.eta) > 0.0 else ""
	_echo_label.text = "%s · %s · %s\n%s → %s · %s т%s" % [
		kind, echo.name, distance, origin, destination, _decimal(float(echo.mass)), timing]


func _collect_known_systems() -> void:
	var discovered: Array[int] = _flight.known_systems()
	if discovered == _known:
		return
	_known = discovered
	_known_lookup.clear()
	for id in _known:
		_known_lookup[id] = true


func _scope_systems() -> Array[int]:
	if _sector_focus < 0:
		return _known
	var coordinates := Sector.sector_coordinates(_sector_focus)
	var systems: Array[int] = []
	for id: int in Sector.sector_system_ids(coordinates):
		if _known_lookup.has(id):
			systems.append(id)
	systems.sort()
	return systems


func _page_for_candidate() -> void:
	var index := _listed_systems().find(_candidate)
	_system_page = maxi(0, floori(float(index) / SYSTEMS_PER_PAGE))


func _listed_systems() -> Array[int]:
	if not _directory:
		return _scope_systems()
	var systems: Array[int] = []
	for id: int in NamedSystems.IDS:
		if _known_lookup.has(id):
			systems.append(id)
	systems.sort()
	return systems


func _refresh_catalog(current: int, goal: int, planned: int) -> void:
	var scoped := _scope_systems()
	var systems := _listed_systems()
	var pages := maxi(1, ceili(float(systems.size()) / SYSTEMS_PER_PAGE))
	_system_page = clampi(_system_page, 0, pages - 1)
	var first := _system_page * SYSTEMS_PER_PAGE
	var last := mini(first + SYSTEMS_PER_PAGE, systems.size())
	var listed := systems.slice(first, last)
	if _system_buttons.keys() != listed:
		_clear_touches()
	_system_buttons.clear()
	for slot in range(_catalog_buttons.size()):
		var button := _catalog_buttons[slot]
		button.visible = slot < listed.size()
		if not button.visible:
			button.text = ""
			continue
		var id: int = listed[slot]
		_system_buttons[id] = button
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
	_directory_button.set_pressed_no_signal(_directory)
	_directory_button.text = "Все" if _directory else "Именные"
	_directory_button.tooltip_text = "Показать все открытые системы" if _directory else "Открыть справочник известных именных систем"
	_scope_button.text = "Обзор" if _sector_focus >= 0 else "Сектор"
	_atlas_button.set_pressed_no_signal(_atlas)
	_projection_button.text = "Вид X/Z" if _elevation else "Вид X/Y"
	_chart.set_atlas(_atlas)
	_chart.set_systems(_known, scoped, _sector_focus, _elevation)
	_scope_label.tooltip_text = ""
	if _sector_focus >= 0:
		var sector := Sector.sector_coordinates(_sector_focus)
		_scope_label.text = "Сектор %d / %d · %d × %d св. л. в X/Y · Известно систем: %d" % [
			sector.x, sector.y, int(Sector.SECTOR_SIZE), int(Sector.SECTOR_SIZE), scoped.size()
		]
	elif _atlas:
		_refresh_atlas_caption()
	else:
		_scope_label.text = "Обзор · Известно систем: %d" % scoped.size()
	_update_zoom_buttons()


func _refresh_atlas_caption() -> void:
	if not _atlas:
		return
	if _chart.atlas_is_local():
		var sector := _chart.atlas_center_sector()
		_scope_label.text = "Локальный атлас · Сектор %d / %d" % [sector.x, sector.y]
		_scope_label.tooltip_text = "Серые точки показывают звёздные сигналы. Открытые системы отмечены цветом."
	else:
		var count := str(Sector.GALAXY_SYSTEM_COUNT)
		for index in range(count.length() - 3, 0, -3):
			count = count.insert(index, " ")
		_scope_label.text = "Атлас плотности · Систем: %s · Открыто: %d" % [count, _known.size()]
		_scope_label.tooltip_text = "Приблизьте атлас, чтобы увидеть звёздные сигналы в отдельных секторах."


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
		_atlas = false
		_sector_focus = _candidate if _sector_focus < 0 else -1
		_page_for_candidate()
		refresh()


func _toggle_atlas() -> void:
	if is_open():
		_clear_touches()
		_atlas = not _atlas
		_sector_focus = -1
		_page_for_candidate()
		refresh()


func _toggle_projection() -> void:
	if is_open():
		_clear_touches()
		_elevation = not _elevation
		refresh()


func _toggle_drag_mode() -> void:
	if is_open() and not _drag_button.disabled:
		_clear_touches()
		_rotate_drag = not _rotate_drag
		_set_rotation_available(true)


func _set_rotation_available(available: bool) -> void:
	if not available:
		_rotate_drag = false
	_drag_button.disabled = not available
	_drag_button.set_pressed_no_signal(_rotate_drag)
	if not available:
		_drag_button.tooltip_text = "Атлас плотности поддерживает две проекции. Свободный поворот доступен в обзоре и секторе."
	elif _rotate_drag:
		_drag_button.tooltip_text = "Проведите по карте для поворота. Нажмите сюда для сдвига карты."
	else:
		_drag_button.tooltip_text = "Проведите по карте для сдвига. Нажмите сюда для поворота карты."


func _go_to_ship() -> void:
	if is_open():
		_atlas = false
		_chart.reset_view()
		_sector_focus = int(_flight.system_id)
		_select_system(_sector_focus)


func _go_to_core() -> void:
	if not is_open():
		return
	_clear_touches()
	_atlas = true
	_sector_focus = -1
	_elevation = false
	_page_for_candidate()
	refresh()
	_chart.focus_atlas_core()
	_refresh_atlas_caption()
	_update_zoom_buttons()


func _zoom_chart(factor: float, anchor := Vector2.INF) -> void:
	if is_open():
		_clear_touches()
		_chart.zoom_by(factor, anchor if anchor.is_finite() else _chart.size * 0.5)
		_refresh_atlas_caption()
		_update_zoom_buttons()


func _update_zoom_buttons() -> void:
	_zoom_in_button.disabled = not _chart.can_zoom_in()
	_zoom_out_button.disabled = not _chart.can_zoom_out()


func _turn_page(delta: int) -> void:
	if is_open():
		_clear_touches()
		_system_page += delta
		refresh()


func _toggle_directory() -> void:
	if not is_open():
		return
	_clear_touches()
	_directory = not _directory
	_page_for_candidate()
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
	_dossier_layout = VBoxContainer.new()
	_dossier_layout.add_theme_constant_override("separation", 6)
	parent.add_child(_dossier_layout)
	_dossier_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tabs := HBoxContainer.new()
	_dossier_layout.add_child(tabs)
	_dossier_scroll = ScrollContainer.new()
	_dossier_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dossier_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dossier_layout.add_child(_dossier_scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dossier_scroll.add_child(pages)
	for title: String in ["Сведения", "Торговля", "Архив"]:
		var tab := _button(tabs, title, 44)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.toggle_mode = true
		tab.pressed.connect(_set_dossier_page.bind(_dossier_tabs.size()))
		_dossier_tabs.append(tab)
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 6)
		pages.add_child(page)
		_dossier_pages.append(page)

	var overview := _dossier_pages[DossierPage.OVERVIEW]
	_label(overview, "Звёзды системы", 17, MINT)
	_dossier_stars = _dossier_text(overview)
	_label(overview, "Население и управление", 17, MINT)
	_dossier_population = _dossier_text(overview)
	_label(overview, "Действующие порты", 17, MINT)
	_dossier_ports = _dossier_text(overview)
	_label(overview, "Замеры тел", 17, MINT)
	_dossier_observations = _dossier_text(overview)

	var trade := _dossier_pages[DossierPage.TRADE]
	_dossier_customs = PanelContainer.new()
	_dossier_customs.add_theme_stylebox_override("panel", _style(Color("27241e"), Color("7a5f40"), 8, 9.0))
	trade.add_child(_dossier_customs)
	_dossier_customs_rule = _dossier_text(_dossier_customs)
	_dossier_customs_rule.add_theme_color_override("font_color", AMBER)
	_dossier_customs.hide()
	_label(trade, "Складские остатки по категориям", 17, MINT)
	_dossier_stock = _dossier_text(trade)
	_label(trade, "Импорт в пути", 17, MINT)
	_dossier_imports = _dossier_text(trade)
	_label(trade, "Экспорт в пути", 17, MINT)
	_dossier_exports = _dossier_text(trade)
	_label(trade, "Второстепенные потребности и производство", 17, MINT)
	_dossier_secondary = _dossier_text(trade)
	var archive := _dossier_pages[DossierPage.ARCHIVE]
	_dossier_archive_title = _label(archive, "", 20, MINT)
	_dossier_archive_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dossier_archive_text = _dossier_text(archive)
	_show_dossier(false)


func _refresh_dossier() -> void:
	var system := SystemDossier.read(_flight, _candidate)
	_dossier_customs_rule.text = _dossier_customs_warning(system)
	_dossier_customs.visible = not _dossier_customs_rule.text.is_empty()
	if not system.known:
		for label: Label in [_dossier_stars, _dossier_population, _dossier_ports, _dossier_observations,
				_dossier_stock, _dossier_imports, _dossier_exports, _dossier_secondary, _dossier_archive_text]:
			label.text = "Сведения о системе ещё не получены."
		_dossier_archive_title.text = ""
		return
	_dossier_stars.text = _stellar_summary(system.stars)
	_dossier_population.text = "%s\n%s\n%s" % [system.population, system.economy, system.authority]
	var inhabitants: Vector2i = system.population_range
	if inhabitants.y > 0:
		_dossier_population.text += "\nПостоянные вахты · %d–%d человек" % [inhabitants.x, inhabitants.y]
	if not str(system.regime).is_empty():
		_dossier_population.text += "\n" + str(system.regime)
	var archive: Array = system.archive
	_dossier_archive_title.text = str(archive[0]) if not archive.is_empty() else "Описание системы"
	_dossier_archive_text.text = "\n\n".join(archive.slice(1)) if not archive.is_empty() else str(system.description)
	var ports := PackedStringArray()
	for port: int in system.ports:
		ports.append(str(Sector.site(port).name))
	_dossier_ports.text = " · ".join(ports) if not ports.is_empty() else "Действующих портов нет."
	var stock := PackedStringArray()
	for group in range(Economy.GROUPS.size()):
		var items := PackedStringArray()
		for good: String in Economy.goods_for_group(group):
			if system.goods.has(good):
				items.append("%s %d" % [Economy.good_name(good), int(system.goods[good])])
		if not items.is_empty():
			stock.append("%s · %s" % [Economy.GROUPS[group], ", ".join(items)])
	_dossier_stock.text = "\n".join(stock) if not stock.is_empty() else "Действующих портовых рынков нет."
	_dossier_imports.text = _shipment_list(system.imports, "origin")
	_dossier_exports.text = _shipment_list(system.exports, "destination")
	var flows := _port_supply_flows(system.ports)
	if not flows.imports.is_empty():
		_dossier_imports.text += "\nПортам нужны: " + ", ".join(flows.imports)
	if not flows.exports.is_empty():
		_dossier_exports.text += "\nМестное производство: " + ", ".join(flows.exports)
	_dossier_secondary.text = "Потребности · %s\nПроизводство · %s" % [
		", ".join(flows.secondary_imports) if not flows.secondary_imports.is_empty() else "—",
		", ".join(flows.secondary_exports) if not flows.secondary_exports.is_empty() else "—",
	] if not system.ports.is_empty() else "Действующих портовых рынков нет."
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


func _dossier_customs_warning(system: Dictionary) -> String:
	if not system.known or system.ports.is_empty():
		return ""
	var customs: Dictionary = _flight.customs_status(_candidate)
	var authority := int(customs.get("authority", -1))
	if authority < 0:
		return ""
	var rules := PackedStringArray(["Таможня · %s" % customs.authority_name])
	for good: String in Economy.ALLOWANCES:
		var allowance := Economy.allowance(authority, good)
		if allowance < 0:
			continue
		var aboard := int(_flight.mining.cargo_amount(good))
		var rule := "%s: ввоз запрещён." % Economy.good_name(good) if allowance == 0 else \
			"До %d ед. · %s." % [allowance, Economy.good_name(good)]
		if aboard > allowance:
			rule += " При стыковке изымут %d ед. и начислят штраф." % (aboard - allowance)
		rules.append(rule)
	return "\n".join(rules)


func _port_supply_flows(ports: Array) -> Dictionary:
	var supply := {}
	for port: int in ports:
		var local: Dictionary = _flight.market_profile(port)
		for good: String in Economy.NEW_GOODS:
			supply[good] = int(supply.get(good, 0)) + Economy.supply_flow(good, local)
	var ranked := supply.keys()
	var imports := PackedStringArray()
	var exports := PackedStringArray()
	ranked.sort_custom(func(a: String, b: String) -> bool:
		return absi(int(supply[a])) > absi(int(supply[b])) if absi(int(supply[a])) != absi(int(supply[b])) else a < b)
	for good: String in ranked:
		if supply[good] < 0:
			imports.append(Economy.good_name(good))
		elif supply[good] > 0:
			exports.append(Economy.good_name(good))
	return {"imports": imports.slice(0, 3), "exports": exports.slice(0, 3),
		"secondary_imports": imports.slice(3), "secondary_exports": exports.slice(3)}


func _toggle_dossier() -> void:
	if is_open():
		_clear_touches()
		_show_dossier(not _dossier_scroll.visible)
		if _dossier_scroll.visible:
			_refresh_dossier()


func _show_dossier(shown: bool) -> void:
	_dossier_layout.visible = shown
	_dossier_scroll.visible = shown
	_set_dossier_page(DossierPage.OVERVIEW)
	_route_scroll.visible = not shown
	_route_details.visible = not shown
	_dossier_button.text = "Маршрут" if shown else "Досье"
	_dossier_button.set_pressed_no_signal(shown)


func _set_dossier_page(index: int) -> void:
	for page in range(_dossier_pages.size()):
		_dossier_pages[page].visible = index == page
		_dossier_tabs[page].set_pressed_no_signal(index == page)
	_dossier_scroll.scroll_vertical = 0
	_scroll_touch = -1


static func _dossier_text(content: Container) -> Label:
	var label := _label(content, "", 15, TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func _stellar_summary(stars: Array[Dictionary]) -> String:
	var lines := PackedStringArray()
	match stars.size():
		1: lines.append("Одиночная звезда")
		2: lines.append("Двойная звезда")
		_: lines.append("Звёзд в системе: %d" % stars.size())
	for star in stars:
		var spectral := str(star.spectral_class)
		lines.append(str(star.name) if spectral.is_empty() else "%s · %s" % [star.name, spectral])
	return "\n".join(lines)


static func _shipment_list(shipments: Array[Dictionary], endpoint: String) -> String:
	var lines := PackedStringArray()
	for shipment in shipments:
		var port := int(shipment[endpoint])
		var system := Sector.system(Sector.system_of_site(port))
		lines.append("%s · %d ед. · %s, %s" % [shipment.good_name, int(shipment.amount), system.name, Sector.site(port).name])
	return "\n".join(lines) if not lines.is_empty() else "Межзвёздных грузов в пути нет."


static func _observation_text(report: Dictionary) -> String:
	var data: Dictionary = report.data
	var details := PackedStringArray(["радиус %s м" % _decimal(float(data.radius))])
	if float(data.period) > 0.0:
		details.append("период %s мин" % _decimal(float(data.period) / 60.0))
		if not str(data.orbit_reference).is_empty():
			details.append(str(data.orbit_reference))
	if float(data.atmosphere_height) > 0.0:
		details.append("атмосфера %s м" % _decimal(float(data.atmosphere_height)))
	return "%s · %s" % [report.name, " · ".join(details)]


func close() -> void:
	_clear_touches()
	_flight = null
	hide()


func is_open() -> bool:
	return _flight != null and visible


func _select_listed_system(button: Button) -> void:
	var id: Variant = _system_buttons.find_key(button)
	if id is int:
		_select_system(id)


func _select_system(id: int) -> void:
	if is_open() and _flight.system_known(id):
		if _candidate != id:
			_emergency_armed = false
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


func _request_emergency_jump() -> void:
	if not is_open() or not _emergency_row.visible or _emergency_button.disabled:
		return
	var status: Dictionary = _flight.emergency_jump_status()
	if not status.ok:
		refresh()
		return
	_clear_touches()
	if _emergency_armed:
		_emergency_armed = false
		emergency_jump_requested.emit()
	else:
		_emergency_armed = true
		_refresh_emergency_jump(true, false)


func _request_hyperspace_track() -> void:
	if is_open() and _echo_row.visible and not _echo_track.disabled:
		_clear_touches()
		hyperspace_track_requested.emit()


func _request_hyperspace_analysis() -> void:
	if is_open() and _echo_row.visible and not _echo_analyze.disabled:
		_clear_touches()
		hyperspace_analysis_requested.emit(str(_flight.hyperspace_trail_status().id))


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
		_touches.erase(event.index)
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
				elif _chart.get_global_rect().has_point(event.position):
					_begin_chart_gesture(event.index, event.position)
			elif button != null and button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(event.position):
				button.pressed.emit()
		if not event.pressed and event.index == _chart_pointer:
			_end_chart_gesture(event.position, event.canceled)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _chart_pointer:
			_move_chart_gesture(event.position)
		elif event.index == _scroll_touch:
			scroll.scroll_vertical = maxi(0, scroll.scroll_vertical - roundi(event.relative.y))
		var button: Button = _touches.get(event.index)
		if button != null and not button.get_global_rect().has_point(event.position):
			_touches.erase(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _chart_pointer == CHART_MOUSE:
		_move_chart_gesture(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		_mouse_chart_event(event)


func _mouse_chart_event(event: InputEventMouseButton) -> void:
	var over_chart := _chart.get_global_rect().has_point(event.position)
	if event.pressed and over_chart and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_zoom_chart(1.5 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.5, _chart_local(event.position))
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		# A physical button can show a different system after changing pages.
		var hit := _catalog_button_at(event.position)
		var held := _mouse_catalog_button
		_mouse_catalog_button = hit if event.pressed else null
		if not event.pressed and held != null and held == hit:
			hit.pressed.emit()
		if hit != null or held != null:
			get_viewport().set_input_as_handled()
		elif event.pressed and over_chart:
			_begin_chart_gesture(CHART_MOUSE, event.position)
			get_viewport().set_input_as_handled()
		if not event.pressed and _chart_pointer == CHART_MOUSE:
			_end_chart_gesture(event.position, false)
			get_viewport().set_input_as_handled()


func _begin_chart_gesture(pointer: int, point: Vector2) -> void:
	if _chart_pointer == -1:
		_chart_pointer = pointer
		_chart_press_point = _chart_local(point)
		_chart_last_point = _chart_press_point
		_chart_pressed_system = _chart.system_at(_chart_press_point)
		_chart_dragged = false


func _move_chart_gesture(point: Vector2) -> void:
	var local := _chart_local(point)
	if not _chart_dragged and local.distance_to(_chart_press_point) < DRAG_THRESHOLD:
		return
	_chart_dragged = true
	var delta := local - _chart_last_point
	if _rotate_drag:
		_chart.rotate_by(delta)
	else:
		_chart.pan_by(delta)
		_refresh_atlas_caption()
	_chart_last_point = local


func _end_chart_gesture(point: Vector2, canceled: bool) -> void:
	var keep := not canceled and not _chart_dragged and _chart_pressed_system >= 0
	var id := _chart_pressed_system
	_chart_pointer = -1
	if keep and _chart_system_at(point) == id:
		_select_system(id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_clear_touches()


func _clear_touches() -> void:
	_touches.clear()
	_scroll_touch = -1
	_mouse_catalog_button = null
	_chart_pointer = -1


func _button_at(point: Vector2) -> Button:
	for tab in _dossier_tabs:
		if tab.is_visible_in_tree() and tab.get_global_rect().has_point(point):
			return tab
	for button: Button in [
		_plan_button, _cancel_route_button, _jump_button, _emergency_button, _echo_track, _echo_analyze,
		_dossier_button, _close_button,
		_scope_button, _atlas_button, _projection_button, _drag_button, _ship_button, _core_button, _zoom_in_button, _zoom_out_button,
		_scan_button, _previous_page_button, _next_page_button, _directory_button
	]:
		if button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(point):
			return button
	return _catalog_button_at(point)


func _catalog_button_at(point: Vector2) -> Button:
	for button: Button in _system_buttons.values():
		if button.is_visible_in_tree() and button.get_global_rect().has_point(point):
			return button
	return null


func _chart_system_at(point: Vector2) -> int:
	return _chart.system_at(_chart_local(point))


func _chart_local(point: Vector2) -> Vector2:
	return _chart.get_global_transform_with_canvas().affine_inverse() * point


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


@warning_ignore("integer_division")
static func _duration(seconds: float) -> String:
	var rounded := ceili(maxf(0.0, seconds))
	return "%02d:%02d:%02d" % [rounded / 3600, rounded / 60 % 60, rounded % 60]


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
