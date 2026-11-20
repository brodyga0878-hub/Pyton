extends CanvasLayer

signal destination_selected(site_id: int)
signal orbit_requested(focus_id: int)
signal rendezvous_requested(site_id: int, gap: int)
signal rendezvous_finish_requested()
signal dismissed()

const Sector := preload("res://scripts/sector_catalog.gd")
const Atmosphere := preload("res://scripts/atmosphere.gd")
const Expedition := preload("res://scripts/expedition.gd")
const Orbit := preload("res://scripts/orbit_ephemeris.gd")
const Patrol := preload("res://scripts/patrol_encounter.gd")
const Rendezvous := preload("res://scripts/rendezvous_navigation.gd")
const TEXT := Color("e8f4fa")
const MUTED := Color("a5bac7")
const MINT := Color("9debd7")
const INTERCEPT := Color("ffb18e")
const TRAJECTORY := Color("dec1ff")
const RENDEZVOUS := Color("9bd9ff")
const BORDER := Color("365561")
const ORBIT_METRICS := [
	["radius", "Текущий радиус"],
	["relative_speed", "Относительная скорость"],
	["radial_speed", "Радиальная скорость"],
	["circular_speed", "Круговая скорость"],
	["periapsis", "Перицентр"],
	["apoapsis", "Апоцентр"],
	["eccentricity", "Эксцентриситет"],
	["period", "Период"],
]
const RENDEZVOUS_METRICS := [
	["eta", "Оценка времени встречи"],
	["distance", "До текущей точки (3D)"],
	["relative_speed", "Относительная скорость"],
	["shift", "Смещение точки"],
]

var _sheet: Control
var _insets: MarginContainer
var _chart: SectorChart
var _title: Label
var _here: Label
var _convoy_order: VBoxContainer
var _convoy_name: Label
var _convoy_info: Label
var _detail_title: Label
var _detail: Label
var _view_button: Button
var _trajectory_button: Button
var _rendezvous_button: Button
var _navigation_panel: VBoxContainer
var _trajectory_panel: VBoxContainer
var _rendezvous_panel: VBoxContainer
var _rendezvous_gap_buttons: Dictionary[int, Button] = {}
var _rendezvous_target: Label
var _rendezvous_stage: Label
var _rendezvous_values: Dictionary[String, Label] = {}
var _rendezvous_hint: Label
var _rendezvous_finish: Button
var _rendezvous_action: Button
var _focus_buttons: Dictionary[int, Button] = {}
var _orbit_state: Label
var _orbit_reference: Label
var _orbit_values: Dictionary[String, Label] = {}
var _orbit_window: Label
var _forecast_summary: Label
var _orbit_note: Label
var _orbit_button: Button
var _close_button: Button
var _select_button: Button
var _home_scoop_sites: HBoxContainer
var _site_buttons: Dictionary[int, Button] = {}
var _touches: Dictionary[int, Button] = {}
var _touch_sites: Dictionary[int, int] = {}
var _flight: RefCounted
var _candidate := -1
var _star_focus := -1
var _orbit_focus := -1
var _forecast_cache: Dictionary[int, Dictionary] = {}
var _rendezvous_status: Dictionary = {}
var _rendezvous_gap := 150


func build() -> void:
	if is_instance_valid(_sheet):
		return
	layer = 9
	_sheet = Control.new()
	add_child(_sheet)
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("07121b")
	_sheet.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_insets = MarginContainer.new()
	_sheet.add_child(_insets)
	_insets.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	_insets.add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	content.add_child(header)
	_title = _label(header, "Карта сектора", 32, TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_here = _label(header, "", 17, MUTED)
	_here.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_view_button = _button(header, "Сбоку", 44)
	_view_button.custom_minimum_size.x = 106
	_view_button.pressed.connect(_toggle_projection)
	_trajectory_button = _button(header, "Траектория", 44)
	_trajectory_button.custom_minimum_size.x = 138
	_trajectory_button.toggle_mode = true
	_trajectory_button.add_theme_stylebox_override("pressed", _panel_style(Color("35294b"), TRAJECTORY, 8, 9))
	_trajectory_button.pressed.connect(_toggle_trajectory)
	_rendezvous_button = _button(header, "Сближение", 44)
	_rendezvous_button.custom_minimum_size.x = 138
	_rendezvous_button.toggle_mode = true
	_rendezvous_button.add_theme_stylebox_override("pressed", _panel_style(Color("193952"), RENDEZVOUS, 8, 9))
	_rendezvous_button.pressed.connect(_toggle_rendezvous)
	_close_button = _button(header, "Закрыть", 44)
	_close_button.custom_minimum_size.x = 122
	_close_button.pressed.connect(func() -> void: dismissed.emit())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)

	_chart = SectorChart.new()
	_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart.gui_input.connect(_chart_mouse_input)
	body.add_child(_chart)

	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 344
	panel.add_theme_stylebox_override("panel", _panel_style(Color("0d1d28"), BORDER, 12, 14))
	body.add_child(panel)
	_navigation_panel = VBoxContainer.new()
	var list := _navigation_panel
	list.add_theme_constant_override("separation", 4)
	panel.add_child(list)
	for system_id in range(Sector.SYSTEM_COUNT):
		for id: int in Sector.ports_for(system_id):
			_add_site(list, id)
		for id: int in Sector.mines_for(system_id):
			_add_site(list, id)
		if system_id == Sector.HOME_SYSTEM:
			_home_scoop_sites = HBoxContainer.new()
			_home_scoop_sites.add_theme_constant_override("separation", 4)
			list.add_child(_home_scoop_sites)
			_add_site(_home_scoop_sites, Sector.star_for(system_id))
			_add_site(_home_scoop_sites, Sector.GAS_GIANT_ID)
		else:
			_add_site(list, Sector.star_for(system_id))
	_convoy_order = VBoxContainer.new()
	_convoy_order.add_theme_constant_override("separation", 3)
	list.add_child(_convoy_order)
	_convoy_order.add_child(HSeparator.new())
	_convoy_name = _label(_convoy_order, "", 19, MINT)
	_convoy_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_convoy_info = _label(_convoy_order, "", 16, MUTED)
	_convoy_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_convoy_order.hide()
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_child(spacer)
	_detail_title = _label(list, "", 21, TEXT)
	_detail = _label(list, "", 16, MUTED)
	_detail.custom_minimum_size.y = 58.0
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_select_button = _button(list, "Проложить маршрут", 52)
	_select_button.add_theme_stylebox_override("normal", _panel_style(Color("164f4c"), MINT, 8, 9))
	_select_button.add_theme_stylebox_override("hover", _panel_style(Color("206760"), MINT, 8, 9))
	_select_button.pressed.connect(_apply)
	_build_trajectory_panel(panel)
	_build_rendezvous_panel(panel)
	get_viewport().size_changed.connect(_size_changed)
	_size_changed()
	hide()


func _build_trajectory_panel(parent: PanelContainer) -> void:
	_trajectory_panel = VBoxContainer.new()
	_trajectory_panel.add_theme_constant_override("separation", 8)
	parent.add_child(_trajectory_panel)
	_label(_trajectory_panel, "Траектория корабля", 21, TRAJECTORY)
	var focus_choices := HBoxContainer.new()
	focus_choices.add_theme_constant_override("separation", 5)
	_trajectory_panel.add_child(focus_choices)
	_add_focus_button(focus_choices, -1, "Звезда")
	for system_id in range(Sector.SYSTEM_COUNT):
		for id: int in Sector.targets_for(system_id):
			var body := Sector.site(id)
			if body.kind in ["planet", "moon", "gas"]:
				_add_focus_button(focus_choices, id, str(body.name))
	_orbit_state = _label(_trajectory_panel, "", 18, TEXT)
	_orbit_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_orbit_reference = _label(_trajectory_panel, "", 16, MUTED)
	_orbit_reference.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trajectory_panel.add_child(HSeparator.new())
	_orbit_values = _build_metrics(_trajectory_panel, ORBIT_METRICS)
	_trajectory_panel.add_child(HSeparator.new())
	_forecast_summary = _label(_trajectory_panel, "", 16, TRAJECTORY)
	_forecast_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_orbit_window = _label(_trajectory_panel, "", 16, MUTED)
	_orbit_window.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trajectory_panel.add_child(spacer)
	_orbit_note = _label(_trajectory_panel, "", 16, MUTED)
	_orbit_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_orbit_button = _button(_trajectory_panel, "Круговая орбита", 52)
	_orbit_button.add_theme_stylebox_override("normal", _panel_style(Color("35294b"), TRAJECTORY, 8, 9))
	_orbit_button.add_theme_stylebox_override("hover", _panel_style(Color("53416b"), TRAJECTORY, 8, 9))
	_orbit_button.pressed.connect(_request_orbit)
	_trajectory_panel.hide()


func _build_rendezvous_panel(parent: PanelContainer) -> void:
	_rendezvous_panel = VBoxContainer.new()
	_rendezvous_panel.add_theme_constant_override("separation", 8)
	parent.add_child(_rendezvous_panel)
	_label(_rendezvous_panel, "План сближения", 21, RENDEZVOUS)
	_rendezvous_target = _label(_rendezvous_panel, "", 21, TEXT)
	_rendezvous_target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rendezvous_stage = _label(_rendezvous_panel, "", 16, MUTED)
	_rendezvous_panel.add_child(HSeparator.new())
	_label(_rendezvous_panel, "Отступ от расчётного контура", 16, MUTED)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 5)
	_rendezvous_panel.add_child(choices)
	for gap: int in Rendezvous.GAPS:
		var button := _button(choices, "%d м" % gap, 43)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.add_theme_stylebox_override("pressed", _panel_style(Color("193952"), RENDEZVOUS, 8, 8))
		button.pressed.connect(_select_rendezvous_gap.bind(gap))
		_rendezvous_gap_buttons[gap] = button
	_rendezvous_panel.add_child(HSeparator.new())
	_rendezvous_values = _build_metrics(_rendezvous_panel, RENDEZVOUS_METRICS)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rendezvous_panel.add_child(spacer)
	_rendezvous_hint = _label(_rendezvous_panel, "", 16, MUTED)
	_rendezvous_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rendezvous_finish = _button(_rendezvous_panel, "Передать на стыковку", 48)
	_rendezvous_finish.add_theme_stylebox_override("normal", _panel_style(Color("174455"), MINT, 8, 9))
	_rendezvous_finish.pressed.connect(_request_rendezvous_finish)
	_rendezvous_action = _button(_rendezvous_panel, "Начать сближение", 52)
	_rendezvous_action.add_theme_stylebox_override("normal", _panel_style(Color("193952"), RENDEZVOUS, 8, 9))
	_rendezvous_action.add_theme_stylebox_override("hover", _panel_style(Color("264f6e"), RENDEZVOUS, 8, 9))
	_rendezvous_action.pressed.connect(_request_rendezvous)
	_rendezvous_panel.hide()


static func _build_metrics(parent: Container, metrics: Array) -> Dictionary[String, Label]:
	var result: Dictionary[String, Label] = {}
	var values := GridContainer.new()
	values.columns = 2
	values.add_theme_constant_override("h_separation", 10)
	values.add_theme_constant_override("v_separation", 4)
	parent.add_child(values)
	for metric: Array in metrics:
		var caption := _label(values, metric[1], 16, MUTED)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := _label(values, "", 16, TEXT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		result[metric[0]] = value
	return result


func _add_focus_button(parent: Container, id: int, caption: String) -> void:
	var button := _button(parent, caption, 43)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("pressed", _panel_style(Color("35294b"), TRAJECTORY, 8, 8))
	button.pressed.connect(_select_orbit_focus.bind(id))
	_focus_buttons[id] = button


func open(sim: RefCounted) -> void:
	if not is_instance_valid(_sheet):
		build()
	_flight = sim
	_forecast_cache.clear()
	_rendezvous_status.clear()
	_rendezvous_gap = 150
	_chart.rendezvous = {}
	_chart.forecast = PackedVector3Array()
	_chart.system_forecast = PackedVector3Array()
	_chart.forecast_impact = -1
	_touches.clear()
	_touch_sites.clear()
	var system_id: int = sim.system_id
	_star_focus = Sector.star_for(system_id)
	_orbit_focus = int(sim.orbit_maneuver_focus) if sim.orbit_maneuver and sim.orbit_maneuver_focus >= 0 else _star_focus
	_title.text = "Карта системы «%s»" % Sector.system(system_id).name
	var here := _current_site()
	_here.text = "В полёте" if here < 0 else str(Sector.site(here).name)
	var targets: Array = sim.local_targets()
	_home_scoop_sites.visible = system_id == Sector.HOME_SYSTEM
	for id: int in _site_buttons:
		_site_buttons[id].visible = targets.has(id)
	for id: int in _focus_buttons:
		_focus_buttons[id].visible = id == -1 or targets.has(id)
	_chart.ship_position = sim.position
	_chart.ship_heading = sim.forward()
	var star_center: Vector3 = sim.target_position(_star_focus)
	_chart.star_plane_y = star_center.y
	var height := _chart.ship_position.y - star_center.y
	var height_sign := "+" if height >= 0.5 else "−" if height <= -0.5 else ""
	_chart.ship_height = height_sign + _distance_label(absf(height))
	_chart.centers.clear()
	for id: int in targets:
		_chart.centers[id] = sim.target_position(id)
	_chart.traffic = sim.traffic_contacts()
	_set_convoy_order(sim.convoy_status())
	var patrol: Dictionary = sim.patrol_status()
	if patrol.get("phase") == Patrol.OUTBOUND and patrol.get("same_system", false):
		_chart.traffic.append({"role": "signal", "position": patrol.point})
	var frontier: Dictionary = sim.frontier_status()
	if frontier.get("phase") == Expedition.BUILD and frontier.get("system") == system_id and frontier.get("has_point", false):
		_chart.traffic.append({"role": "worksite", "position": frontier.point})
	var planned: int = sim.planned_target
	_chart.active_site = planned if targets.has(planned) else int(sim.target)
	if not targets.has(_chart.active_site):
		_chart.active_site = targets[0] if not targets.is_empty() else -1
	show()
	_select_site(_chart.active_site)
	if _chart.forecast_visible:
		_refresh_trajectory()


func _set_convoy_order(order: Dictionary) -> void:
	_convoy_order.visible = order.get("active", false) and order.get("local", false) and order.get("has_point", false)
	_chart.order_convoy = str(order.id) if _convoy_order.visible else ""
	if not _convoy_order.visible:
		return
	var intercept: bool = order.kind == "intercept"
	_chart.order_color = INTERCEPT if intercept else MINT
	_convoy_name.add_theme_color_override("font_color", _chart.order_color)
	_convoy_name.text = str(order.name)
	var objective := "Перехват" if intercept else ("Под охраной" if order.phase == "escorted" else "Сопровождение")
	var remaining := maxi(0, ceili(float(order.remaining)))
	var time := "%d:%02d" % [floori(remaining / 60.0), remaining % 60]
	_convoy_info.text = "%s · %s\nДо цели %s (3D)" % [objective, time, _distance_label(float(order.distance))]


func close() -> void:
	_touches.clear()
	_touch_sites.clear()
	_flight = null
	hide()


func is_open() -> bool:
	return is_instance_valid(_sheet) and visible


func _add_site(parent: Container, id: int) -> void:
	var site = Sector.site(id)
	var button := _button(parent, str(site.name), 39)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.pressed.connect(_select_site.bind(id))
	_site_buttons[id] = button


func _select_site(id: int) -> void:
	if _flight == null or not _chart.centers.has(id):
		return
	if _rendezvous_panel.visible and _rendezvous_status.get("active", false):
		return
	_candidate = id
	_chart.selected_site = id
	_chart.orbit = Orbit.orbit_points(id)
	_chart.orbit_caption = ""
	if not _chart.orbit.is_empty():
		var orbital_velocity: Vector3 = _flight.target_velocity(id)
		_chart.orbit_caption = "Орбита цели · %s м/с" % ("%.1f" % orbital_velocity.length()).replace(".", ",")
	_chart.queue_redraw()
	for key: int in _site_buttons:
		_site_buttons[key].set_pressed_no_signal(key == id)
	var entry = Sector.site(id)
	_detail_title.text = str(entry.name)
	var distance := _distance_label(_flight.position.distance_to(_chart.centers[id]))
	var category := str(Sector.kind_name(entry.kind))
	var here := id == _current_site()
	_detail.text = "%s · текущая стоянка" % category if here else "%s · %s (3D)" % [category, distance]
	if entry.kind == "port":
		var quote: int = _flight.mining.sale_quote(id)
		if quote > 0:
			_detail.text += " · за груз %d кр." % quote
		_detail.text += "\nРуда %d · кристаллы %d · лёд %d кр.\nТопливо %d кр./ед." % [
			Sector.price(id, "ore"), Sector.price(id, "crystal"), Sector.price(id, "ice"),
			Sector.refuel_price(id),
		]
	elif entry.kind == "star":
		_detail.text += "\nСбор в %d–%d м от центра\nСкорость до %d м/с" % [Sector.SCOOP_INNER, Sector.SCOOP_OUTER, Sector.SCOOP_SPEED]
	elif Sector.is_gas_giant(id):
		var atmosphere := Atmosphere.profile(id)
		_detail.text += "\nСбор водорода в облаках · без посадки"
		if not atmosphere.is_empty():
			_detail.text += "\nТолщина атмосферы · %d м" % roundi(float(atmosphere.height))
	else:
		var remaining: int = _flight.mining.reserve_at(id)
		_detail.text += "\n%s · %d ед. в залежи" % [Sector.resource_name(entry.resource), remaining]
		if entry.kind == "planet":
			_detail.text += "\nТвёрдая поверхность"
			var atmosphere := Atmosphere.profile(id)
			if not atmosphere.is_empty():
				_detail.text += "\nТолщина атмосферы · %d м" % roundi(float(atmosphere.height))
				_detail.text += "\nОтн. плотность у поверхности · %s" % ("%.2f" % float(atmosphere.density)).replace(".", ",")
	_select_button.disabled = here
	if _rendezvous_panel.visible:
		_refresh_rendezvous()


func _apply() -> void:
	if _flight != null and _chart.centers.has(_candidate) and _candidate != _current_site():
		destination_selected.emit(_candidate)


func _toggle_projection() -> void:
	_touch_sites.clear()
	_chart.side_view = not _chart.side_view
	_view_button.text = "Сверху" if _chart.side_view else "Сбоку"
	_chart.queue_redraw()


func _toggle_trajectory() -> void:
	_set_panel("navigation" if _trajectory_panel.visible else "trajectory")


func _toggle_rendezvous() -> void:
	_set_panel("navigation" if _rendezvous_panel.visible else "rendezvous")


func _set_panel(panel: String) -> void:
	_touch_sites.clear()
	_navigation_panel.visible = panel == "navigation"
	_trajectory_panel.visible = panel == "trajectory"
	_rendezvous_panel.visible = panel == "rendezvous"
	_chart.forecast_visible = _trajectory_panel.visible
	_chart.rendezvous_visible = _rendezvous_panel.visible
	_trajectory_button.set_pressed_no_signal(_trajectory_panel.visible)
	_rendezvous_button.set_pressed_no_signal(_rendezvous_panel.visible)
	if _trajectory_panel.visible:
		_refresh_trajectory()
	elif _rendezvous_panel.visible:
		_refresh_rendezvous()
	_chart.queue_redraw()


func _refresh_rendezvous() -> void:
	_rendezvous_status = _flight.rendezvous_status(_candidate, _rendezvous_gap)
	var status := _rendezvous_status
	var site: int = status.site
	var active: bool = status.active
	var supported := _chart.centers.has(site) and Rendezvous.supports(site)
	var has_point: bool = supported and status.has_point
	_chart.rendezvous = status if has_point else {}
	_rendezvous_target.text = str(Sector.site(site).name) if _chart.centers.has(site) else "Цель не выбрана"
	_rendezvous_stage.text = "Удержание позиции" if status.phase == "hold" else "Автосближение" if active else "Предварительный расчёт"
	var selected_gap: int = status.gap if active else _rendezvous_gap
	for gap: int in _rendezvous_gap_buttons:
		var button := _rendezvous_gap_buttons[gap]
		button.disabled = active or not supported
		button.set_pressed_no_signal(gap == selected_gap)
	_rendezvous_values["eta"].text = _duration_label(float(status.eta)) if has_point else "—"
	_rendezvous_values["distance"].text = _distance_label(float(status.distance)).replace(".", ",") if has_point else "—"
	_rendezvous_values["relative_speed"].text = _number_label(float(status.relative_speed), "м/с") if supported else "—"
	var shift: float = status.point.distance_to(status.predicted) if has_point else 0.0
	_rendezvous_values["shift"].text = _distance_label(shift).replace(".", ",") if has_point and status.eta >= 0.0 else "—"
	_rendezvous_hint.text = str(status.reason)
	_rendezvous_action.text = "Отменить сближение" if active else "Начать сближение"
	_rendezvous_action.disabled = not active and (not supported or not status.allowed)
	_rendezvous_finish.visible = active and status.can_finish
	_rendezvous_finish.text = "Передать на стыковку" if Sector.is_port(site) else "Передать на посадку"
	_chart.queue_redraw()


func _select_rendezvous_gap(gap: int) -> void:
	if not is_open() or not _rendezvous_panel.visible or not _rendezvous_gap_buttons.has(gap):
		return
	if not _rendezvous_gap_buttons[gap].disabled:
		_rendezvous_gap = gap
		_refresh_rendezvous()


func _request_rendezvous() -> void:
	if is_open() and _rendezvous_panel.visible and not _rendezvous_action.disabled:
		rendezvous_requested.emit(int(_rendezvous_status.site), int(_rendezvous_status.gap))


func _request_rendezvous_finish() -> void:
	if is_open() and _rendezvous_finish.is_visible_in_tree() and _rendezvous_status.get("can_finish", false):
		rendezvous_finish_requested.emit()


func _refresh_trajectory() -> void:
	if _flight == null:
		return
	if not _forecast_cache.has(_orbit_focus):
		_forecast_cache[_orbit_focus] = {
			"status": _flight.orbit_status(_orbit_focus),
			"forecast": _flight.orbit_forecast(_orbit_focus),
		}
	var entry := _forecast_cache[_orbit_focus]
	var status: Dictionary = entry.status
	var forecast: Dictionary = entry.forecast
	var stellar := _orbit_focus == _star_focus
	_chart.orbit_focus = _orbit_focus
	_chart.forecast = forecast.points if stellar else forecast.relative_points
	_chart.system_forecast = PackedVector3Array() if stellar else forecast.points
	_chart.forecast_impact = int(forecast.impact)
	var maneuver: bool = status.maneuver
	for id: int in _focus_buttons:
		var button := _focus_buttons[id]
		button.disabled = maneuver
		button.set_pressed_no_signal(id == _orbit_focus or (id == -1 and stellar))
	match str(status.classification):
		"bound": _orbit_state.text = "Связанная орбита"
		"escape": _orbit_state.text = "Незамкнутая траектория"
		_: _orbit_state.text = "Орбита не рассчитана"
	_orbit_reference.text = ("Радиусы от центра звезды «%s»" if stellar else "Радиусы от центра тела «%s»") % status.name
	var measurable: bool = status.classification != "unavailable"
	for key: String in ["radius", "periapsis", "apoapsis"]:
		var radius := float(status[key])
		var show_radius := (key == "radius" or measurable) and radius >= 0.0 and is_finite(radius)
		_orbit_values[key].text = _distance_label(radius).replace(".", ",") if show_radius else "—"
	_orbit_values["radial_speed"].text = _number_label(float(status.radial_speed), "м/с", true) if measurable else "—"
	_orbit_values["relative_speed"].text = _number_label(float(status.relative_speed), "м/с") if measurable else "—"
	_orbit_values["circular_speed"].text = _number_label(float(status.circular_speed), "м/с")
	var eccentricity := float(status.eccentricity)
	_orbit_values["eccentricity"].text = ("%.3f" % eccentricity).replace(".", ",") if measurable and eccentricity >= 0.0 and is_finite(eccentricity) else "—"
	_orbit_values["period"].text = _duration_label(float(status.period)) if measurable else "—"
	_forecast_summary.add_theme_color_override("font_color", INTERCEPT if _chart.forecast_impact >= 0 else TRAJECTORY)
	_forecast_summary.text = "Прогноз без тяги недоступен"
	if _chart.forecast.size() >= 2 or _chart.forecast_impact >= 0:
		var duration := _duration_label(float(forecast.seconds))
		_forecast_summary.text = "Прогноз без тяги · %s" % duration
		if _chart.forecast_impact >= 0:
			_forecast_summary.text += "\nСтолкновение с объектом «%s»" % Sector.site(_chart.forecast_impact).name
	var approach_min := float(status.approach_min)
	var approach_max := float(status.approach_max)
	_orbit_window.visible = not stellar and approach_min >= 0.0 and approach_max > approach_min and is_finite(approach_max)
	if _orbit_window.visible:
		_orbit_window.text = "Радиус манёвра · %d–%d м" % [ceili(approach_min), floori(approach_max)]
	_orbit_button.text = "Отменить манёвр" if maneuver else "Круговая орбита"
	_orbit_button.disabled = not maneuver and not status.allowed
	_orbit_note.text = str(status.reason) if _orbit_button.disabled else "Нужно Δv %s" % _number_label(float(status.delta_v), "м/с")
	if maneuver:
		_orbit_note.text = "Разворот на манёвр" if status.maneuver_phase == "turn" else "Корректируем скорость"
	_chart.queue_redraw()


func _select_orbit_focus(id: int) -> void:
	if not is_open() or not _trajectory_panel.visible or _flight.orbit_maneuver:
		return
	var body := _star_focus if id == -1 else id
	if not _focus_buttons.has(id) or not _chart.centers.has(body):
		return
	_orbit_focus = body
	_refresh_trajectory()


func _request_orbit() -> void:
	if is_open() and _trajectory_panel.visible and not _orbit_button.disabled:
		orbit_requested.emit(_orbit_focus)


func _current_site() -> int:
	if _flight.docked >= 0:
		return _flight.docked
	return _flight.landed_site


func _chart_mouse_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or event.pressed:
		return
	var site_id := _chart.site_at(event.position)
	if site_id != -1:
		_select_site(site_id)


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			var button := _button_at(touch.position)
			if button != null:
				_touches[touch.index] = button
			elif _chart.get_global_rect().has_point(touch.position):
				var id := _chart_site_at(touch.position)
				if id != -1:
					_touch_sites[touch.index] = id
		else:
			var button: Button = _touches.get(touch.index)
			var id: int = _touch_sites.get(touch.index, -1)
			_touches.erase(touch.index)
			_touch_sites.erase(touch.index)
			if not touch.canceled:
				if button != null and button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(touch.position):
					button.pressed.emit()
				elif id != -1 and id == _chart_site_at(touch.position):
					_select_site(id)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_touches.clear()
		_touch_sites.clear()


func _button_at(point: Vector2) -> Button:
	for button: Button in [_select_button, _orbit_button, _rendezvous_action, _rendezvous_finish, _view_button, _trajectory_button, _rendezvous_button, _close_button]:
		if button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(point):
			return button
	for button: Button in _focus_buttons.values():
		if button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(point):
			return button
	for button: Button in _rendezvous_gap_buttons.values():
		if button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(point):
			return button
	for button: Button in _site_buttons.values():
		if button.is_visible_in_tree() and button.get_global_rect().has_point(point):
			return button
	return null


func _chart_site_at(point: Vector2) -> int:
	var local := _chart.get_global_transform_with_canvas().affine_inverse() * point
	return _chart.site_at(local)


func _size_changed() -> void:
	var safe_insets := Vector4(24, 20, 24, 20)
	if OS.get_name() == "Android":
		var window_size := Vector2(DisplayServer.window_get_size())
		var map_size := get_viewport().get_visible_rect().size
		var safe_area := DisplayServer.get_display_safe_area()
		if window_size.x > 0 and window_size.y > 0 and safe_area.has_area():
			var scale := map_size / window_size
			safe_insets.x += maxf(0.0, safe_area.position.x * scale.x)
			safe_insets.y += maxf(0.0, safe_area.position.y * scale.y)
			safe_insets.z += maxf(0.0, (window_size.x - safe_area.end.x) * scale.x)
			safe_insets.w += maxf(0.0, (window_size.y - safe_area.end.y) * scale.y)
	_insets.add_theme_constant_override("margin_left", int(safe_insets.x))
	_insets.add_theme_constant_override("margin_top", int(safe_insets.y))
	_insets.add_theme_constant_override("margin_right", int(safe_insets.z))
	_insets.add_theme_constant_override("margin_bottom", int(safe_insets.w))
	_chart.queue_redraw()


static func _distance_label(meters: float) -> String:
	return "%d м" % roundi(meters) if meters < 1000.0 else "%.1f км" % (meters / 1000.0)


static func _number_label(value: float, units: String, signed := false) -> String:
	if not is_finite(value) or (value < 0.0 and not signed):
		return "—"
	var prefix := "+" if signed and value >= 0.05 else "−" if value <= -0.05 else ""
	return prefix + ("%.1f" % absf(value)).replace(".", ",") + " " + units


static func _duration_label(seconds: float) -> String:
	if seconds < 0.0 or not is_finite(seconds):
		return "—"
	if seconds >= 3600.0:
		return ("%.1f ч" % (seconds / 3600.0)).replace(".", ",")
	var whole := roundi(seconds)
	return "%d мин %02d с" % [floori(whole / 60.0), whole % 60] if whole >= 60 else "%d с" % whole


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
	button.add_theme_stylebox_override("normal", _panel_style(Color("102632"), Color("21404e"), 8, 9))
	button.add_theme_stylebox_override("hover", _panel_style(Color("163743"), BORDER, 8, 9))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("1b454d"), MINT, 8, 9))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("0e2630"), BORDER, 8, 9))
	parent.add_child(button)
	return button


static func _panel_style(fill: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding / 2.0
	style.content_margin_bottom = padding / 2.0
	return style


class SectorChart extends Control:
	const GRID := Color("233c48")
	const EDGE := Color("426775")
	const CHART_BACKGROUND := Color("0b1a25")
	const ORBIT_COLOR := Color("78b0daae")
	const SYSTEM_FORECAST_COLOR := Color("a1b2be")
	const STAR_PLANE_COLOR := Color("496879")
	const PLOT_MARGIN := Vector2(63, 42)
	const CONTACT_COLORS := {
		"trader": Color("8fe9db"),
		"patrol": Color("90c6ff"),
		"raider": Color("ff978c"),
		"convoy": Color("ffd081"),
		"signal": Color("ffd396"),
		"worksite": Color("ffc077"),
	}

	var ship_position := Vector3.ZERO
	var ship_heading := Vector3.FORWARD
	var ship_height := ""
	var star_plane_y := 0.0
	var side_view := false
	var centers: Dictionary[int, Vector3] = {}
	var active_site := -1
	var selected_site := -1
	var orbit := PackedVector3Array()
	var orbit_caption := ""
	var orbit_focus := -1
	var forecast := PackedVector3Array()
	var system_forecast := PackedVector3Array()
	var forecast_visible := false
	var forecast_impact := -1
	var rendezvous_visible := false
	var rendezvous: Dictionary = {}
	var traffic: Array[Dictionary] = []
	var order_convoy := ""
	var order_color := MINT

	func _ready() -> void:
		clip_contents = true
		resized.connect(queue_redraw)

	func _plot_bounds() -> Rect2:
		return Rect2(PLOT_MARGIN, (size - 2.0 * PLOT_MARGIN).max(Vector2.ONE))

	func _bounds_xz() -> Rect2:
		return _bounds_for_plane(false)

	func _bounds() -> Rect2:
		return _bounds_for_plane(true) if side_view else _bounds_xz()

	func _bounds_for_plane(side: bool) -> Rect2:
		var minimum := Vector2(INF, INF)
		var maximum := Vector2(-INF, -INF)
		var positions: Array[Vector3] = centers.values()
		if side:
			positions.append(ship_position)
			for orbit_point: Vector3 in orbit:
				positions.append(orbit_point)
		if rendezvous_visible and not rendezvous.is_empty():
			positions.append(rendezvous.point)
			if rendezvous.eta >= 0.0:
				positions.append(rendezvous.predicted)
		for contact: Dictionary in traffic:
			if side or contact.role in ["signal", "worksite"]:
				positions.append(contact.position)
			if contact.role == "convoy":
				positions.append(contact.route_start)
				positions.append(contact.route_end)
		for position_3d: Vector3 in positions:
			var point := _plane_point(position_3d, side)
			minimum = minimum.min(point)
			maximum = maximum.max(point)
		var atmosphere := _atmosphere_outline()
		if not atmosphere.is_empty():
			var center := _plane_point(centers[atmosphere.site], side)
			var radius := Vector2.ONE * float(atmosphere.outer_radius)
			minimum = minimum.min(center - radius)
			maximum = maximum.max(center + radius)
		return Rect2(minimum, (maximum - minimum).max(Vector2.ONE))

	func _atmosphere_outline() -> Dictionary:
		var site := selected_site
		if forecast_visible and not Atmosphere.profile(orbit_focus).is_empty():
			site = orbit_focus
		elif rendezvous_visible and not rendezvous.is_empty():
			site = int(rendezvous.site)
		if not centers.has(site):
			return {}
		var atmosphere := Atmosphere.profile(site)
		if atmosphere.is_empty():
			return {}
		var radius := float(Sector.site(site).radius)
		var tint: Color = atmosphere.color
		return {
			"site": site, "inner_radius": radius, "outer_radius": radius + float(atmosphere.height),
			"color": tint.lightened(0.24),
		}

	static func _plane_point(position_3d: Vector3, side: bool) -> Vector2:
		# East points right in both views. The side view replaces north with elevation.
		return Vector2(position_3d.x, -position_3d.y if side else position_3d.z)

	func _project(position_3d: Vector3, plot: Rect2, bounds: Rect2) -> Vector2:
		var ratio := minf(plot.size.x / bounds.size.x, plot.size.y / bounds.size.y)
		return plot.get_center() + (_plane_point(position_3d, side_view) - bounds.get_center()) * ratio

	func site_at(point: Vector2) -> int:
		if centers.is_empty() or not Rect2(Vector2.ZERO, size).has_point(point):
			return -1
		var best := -1
		var distance := 30.0
		var plot := _plot_bounds()
		var bounds := _bounds()
		for id: int in centers:
			var marker := _project(centers[id], plot, bounds)
			var separation := point.distance_to(marker)
			if separation < distance:
				best = id
				distance = separation
		return best

	func _draw() -> void:
		var area := Rect2(Vector2.ZERO, size)
		draw_rect(area, CHART_BACKGROUND)
		if centers.is_empty():
			return
		draw_rect(area.grow(-0.5), EDGE, false, 1.0)
		for x in range(28, int(size.x), 48):
			draw_line(Vector2(x, 1), Vector2(x, size.y - 1), GRID)
		for y in range(24, int(size.y), 48):
			draw_line(Vector2(1, y), Vector2(size.x - 1, y), GRID)
		var font := ThemeDB.fallback_font
		var plot := _plot_bounds()
		var bounds := _bounds()
		var plane_y := _project(Vector3(0.0, star_plane_y, 0.0), plot, bounds).y
		if side_view:
			draw_dashed_line(Vector2(1.0, plane_y), Vector2(size.x - 1.0, plane_y), STAR_PLANE_COLOR, 1.2, 7.0, true, true)
		var atmosphere := _atmosphere_outline()
		if not atmosphere.is_empty():
			_draw_atmosphere(atmosphere, plot, bounds)
		if orbit.size() >= 2:
			var track := PackedVector2Array()
			track.resize(orbit.size())
			for index in orbit.size():
				track[index] = _project(orbit[index], plot, bounds)
			draw_polyline(track, ORBIT_COLOR, 1.7, true)
		if forecast_visible:
			if not system_forecast.is_empty():
				_draw_forecast(system_forecast, plot, bounds, SYSTEM_FORECAST_COLOR, true)
			if not forecast.is_empty():
				_draw_forecast(forecast, plot, bounds, TRAJECTORY, system_forecast.is_empty())
		var ship := _project(ship_position, plot, bounds).clamp(Vector2(18, 35), size - Vector2(18, 28))
		if side_view:
			draw_line(ship, Vector2(ship.x, plane_y), Color(STAR_PLANE_COLOR, 0.72), 1.0, true)
		var has_rendezvous := rendezvous_visible and not rendezvous.is_empty()
		if has_rendezvous:
			_draw_rendezvous(plot, bounds, ship)
		if not has_rendezvous and centers.has(active_site):
			_draw_course(ship, _project(centers[active_site], plot, bounds), Color("4d928c"), 1.5)
		if not has_rendezvous and centers.has(selected_site) and selected_site != active_site:
			_draw_course(ship, _project(centers[selected_site], plot, bounds), Color("d9a569"), 1.8)
		var view_caption := "ВИД СБОКУ · XY" if side_view else "ВИД СВЕРХУ · XZ"
		var ship_caption := "▲  Корабль"
		if side_view:
			ship_caption += " · Высота %s" % ship_height
		var ship_legend_width := font.get_string_size(ship_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 22.0
		var label_boxes: Array[Rect2] = [Rect2(11, 10, 148, 24), Rect2(11, size.y - 32, ship_legend_width, 24)]
		for box: Rect2 in label_boxes:
			draw_rect(box, CHART_BACKGROUND)
		draw_string(font, Vector2(18, 28), view_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, EDGE.lightened(0.32))
		draw_string(font, Vector2(18, size.y - 14), ship_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
		if forecast_visible and forecast.size() >= 2:
			var relative := not system_forecast.is_empty()
			var caption := "Относительно тела" if relative else "Прогноз без тяги"
			var legend := _draw_line_legend(font, 165.0, caption, TRAJECTORY)
			label_boxes.append(legend)
			if relative:
				label_boxes.append(_draw_line_legend(font, legend.end.x + 6.0, "В системе", SYSTEM_FORECAST_COLOR))
		elif has_rendezvous:
			label_boxes.append(_draw_rendezvous_legend(font, 165.0, "Точка сейчас", SYSTEM_FORECAST_COLOR, false))
			if rendezvous.eta >= 0.0:
				label_boxes.append(_draw_rendezvous_legend(font, label_boxes[-1].end.x + 6.0, "Точка встречи", RENDEZVOUS, true))
		if not atmosphere.is_empty():
			var y := 37.0 if forecast_visible or has_rendezvous else 10.0
			var caption := "Граница атмосферы · %s" % Sector.site(atmosphere.site).name
			label_boxes.append(_draw_line_legend(font, 165.0, caption, atmosphere.color, y))
		if side_view:
			var plane_label_y := plane_y - 30.0 if plane_y >= 66.0 else plane_y + 6.0
			var plane_legend := Rect2(11.0, plane_label_y, 145.0, 24.0)
			label_boxes.append(plane_legend)
			draw_rect(plane_legend, CHART_BACKGROUND)
			draw_string(font, plane_legend.position + Vector2(7, 17), "Плоскость звезды", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
		if not orbit_caption.is_empty():
			var width := font.get_string_size(orbit_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 40.0
			var legend := Rect2(size.x - width - 11.0, 10, width, 24)
			label_boxes.append(legend)
			draw_rect(legend, CHART_BACKGROUND)
			var swatch := legend.position + Vector2(6, 12)
			draw_line(swatch, swatch + Vector2(20, 0), ORBIT_COLOR, 1.7, true)
			draw_string(font, legend.position + Vector2(32, 17), orbit_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
		_draw_traffic(font, plot, bounds, ship, label_boxes)
		for center: Vector3 in centers.values():
			var point := _project(center, plot, bounds)
			label_boxes.append(Rect2(point - Vector2(15, 15), Vector2(30, 30)))
		for id: int in centers:
			var entry = Sector.site(id)
			var marker := _project(centers[id], plot, bounds)
			var tint: Color = entry.accent
			if has_rendezvous and rendezvous.site == id:
				draw_arc(marker, 28.0, 0.0, TAU, 36, RENDEZVOUS, 1.7, true)
			if forecast_visible and orbit_focus == id:
				for quarter in range(4):
					var start_angle := quarter * TAU / 4.0 + 0.14
					draw_arc(marker, 28.0, start_angle, start_angle + 1.29, 12, TRAJECTORY, 1.7, true)
			if active_site == id:
				draw_arc(marker, 17, 0, TAU, 32, MINT, 1.2, true)
			if selected_site == id:
				draw_arc(marker, 23, 0, TAU, 32, Color("f5ca8d"), 1.7, true)
			if entry.kind == "port":
				draw_rect(Rect2(marker - Vector2(7, 7), Vector2(14, 14)), tint)
			elif entry.kind == "star":
				draw_circle(marker, 7.0, tint, true, -1.0, true)
				for ray in range(8):
					var direction := Vector2.from_angle(ray * TAU / 8.0)
					draw_line(marker + direction * 10.0, marker + direction * 14.0, tint, 1.7, true)
			elif entry.kind == "comet":
				draw_line(marker - Vector2(16, -10), marker, tint, 2.0, true)
				draw_circle(marker, 7.0, tint, true, -1.0, true)
			elif entry.kind == "moon":
				draw_circle(marker, 9.0, tint, true, -1.0, true)
			elif entry.kind == "planet":
				draw_circle(marker, 12.0, tint, true, -1.0, true)
				draw_line(marker + Vector2(-10, 4), marker + Vector2(10, -4), tint.darkened(0.34), 2.5, true)
				draw_arc(marker, 12.0, 0.0, TAU, 32, tint.lightened(0.38), 1.4, true)
			elif entry.kind == "gas":
				draw_circle(marker, 13.0, tint, true, -1.0, true)
				for stripe: int in [-5, 0, 5]:
					draw_line(marker + Vector2(-11, stripe), marker + Vector2(11, stripe), tint.darkened(0.34), 1.7, true)
				draw_arc(marker, 13.0, 0.0, TAU, 36, tint.lightened(0.32), 1.4, true)
			else:
				draw_colored_polygon(PackedVector2Array([marker + Vector2(-8, 3), marker + Vector2(-3, -8), marker + Vector2(7, -3), marker + Vector2(6, 7)]), tint)
			_draw_site_label(font, str(entry.name), marker, label_boxes)
		if not order_convoy.is_empty():
			for contact: Dictionary in traffic:
				if contact.get("id", "") == order_convoy:
					var point := _project(contact.position, plot, bounds)
					_draw_site_label(font, str(contact.name), point, label_boxes)
					break
		_draw_ship(ship)

	func _draw_atmosphere(atmosphere: Dictionary, plot: Rect2, bounds: Rect2) -> void:
		var center: Vector3 = centers[atmosphere.site]
		var marker := _project(center, plot, bounds)
		var inner := _project(center + Vector3.RIGHT * float(atmosphere.inner_radius), plot, bounds).distance_to(marker)
		var outer := _project(center + Vector3.RIGHT * float(atmosphere.outer_radius), plot, bounds).distance_to(marker)
		var tint: Color = atmosphere.color
		draw_arc(marker, (inner + outer) * 0.5, 0.0, TAU, 64, Color(tint, 0.12), outer - inner, true)
		draw_arc(marker, outer, 0.0, TAU, 64, tint, 1.6, true)

	func _draw_line_legend(font: Font, x: float, caption: String, color: Color, y := 10.0) -> Rect2:
		var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 40.0
		var legend := Rect2(x, y, width, 24.0)
		draw_rect(legend, CHART_BACKGROUND)
		draw_line(legend.position + Vector2(7, 12), legend.position + Vector2(25, 12), color, 2.0, true)
		draw_string(font, legend.position + Vector2(32, 17), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
		return legend

	func _draw_rendezvous(plot: Rect2, bounds: Rect2, ship: Vector2) -> void:
		var current := _project(rendezvous.point, plot, bounds)
		if rendezvous.eta < 0.0:
			_draw_rendezvous_point(current, SYSTEM_FORECAST_COLOR, false)
			return
		var predicted := _project(rendezvous.predicted, plot, bounds)
		if current.distance_squared_to(predicted) > 16.0:
			draw_dashed_line(current, predicted, SYSTEM_FORECAST_COLOR, 1.4, 5.0, true, true)
			_draw_rendezvous_point(current, SYSTEM_FORECAST_COLOR, false)
		_draw_course(ship, predicted, RENDEZVOUS, 1.9)
		_draw_rendezvous_point(predicted, RENDEZVOUS, true)

	func _draw_rendezvous_legend(font: Font, x: float, caption: String, color: Color, filled: bool) -> Rect2:
		var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 32.0
		var legend := Rect2(x, 10.0, width, 24.0)
		draw_rect(legend, CHART_BACKGROUND)
		_draw_rendezvous_point(legend.position + Vector2(12.0, 12.0), color, filled)
		draw_string(font, legend.position + Vector2(24.0, 17.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
		return legend

	func _draw_rendezvous_point(point: Vector2, color: Color, filled: bool) -> void:
		var mark := PackedVector2Array([
			point + Vector2.UP * 6.0, point + Vector2.RIGHT * 6.0,
			point + Vector2.DOWN * 6.0, point + Vector2.LEFT * 6.0,
		])
		if filled:
			draw_colored_polygon(mark, color)
		else:
			mark.append(mark[0])
			draw_polyline(mark, color, 1.5, true)

	func _draw_forecast(points: PackedVector3Array, plot: Rect2, bounds: Rect2, color: Color, mark_impact: bool) -> void:
		var track := PackedVector2Array()
		track.resize(points.size())
		for index in points.size():
			track[index] = _project(points[index], plot, bounds)
		if track.size() >= 2:
			draw_polyline(track, color, 2.0, true)
		var finish := track[track.size() - 1]
		if not Rect2(Vector2.ZERO, size).grow(-5.0).has_point(finish):
			return
		if not mark_impact or forecast_impact < 0:
			draw_circle(finish, 3.5, color, true, -1.0, true)
		else:
			draw_line(finish - Vector2(4, 4), finish + Vector2(4, 4), INTERCEPT, 2.0, true)
			draw_line(finish - Vector2(4, -4), finish + Vector2(4, -4), INTERCEPT, 2.0, true)

	func _draw_ship(position_2d: Vector2) -> void:
		var heading := _plane_point(ship_heading, side_view)
		if heading.length_squared() < 0.001:
			draw_arc(position_2d, 6.0, 0.0, TAU, 18, TEXT, 1.5, true)
			draw_circle(position_2d, 2.0, TEXT, true, -1.0, true)
			return
		var ahead := heading.normalized()
		var right := ahead.orthogonal()
		draw_colored_polygon(PackedVector2Array([
			position_2d + ahead * 9.0,
			position_2d - ahead * 6.0 + right * 6.0,
			position_2d - ahead * 3.0,
			position_2d - ahead * 6.0 - right * 6.0,
		]), TEXT)

	func _draw_traffic(font: Font, plot: Rect2, bounds: Rect2, ship: Vector2, label_boxes: Array[Rect2]) -> void:
		var roles: Dictionary[String, String] = {
			"trader": "Торговец", "patrol": "Патруль", "raider": "Рейдер", "signal": "Сигнал",
			"convoy": "Конвой", "worksite": "Стройплощадка",
		}
		var visible_roles: Array[String] = []
		var limits := Rect2(Vector2(16, 36), (size - Vector2(32, 77)).max(Vector2.ONE))
		for contact: Dictionary in traffic:
			var point := _project(contact.position, plot, bounds)
			if not limits.has_point(point) or not roles.has(contact.role):
				continue
			if contact.role == "convoy":
				var arrival := _project(contact.route_end, plot, bounds)
				if contact.id == order_convoy:
					_draw_course(ship, point, order_color, 1.8)
					_draw_course(point, arrival, Color(order_color, 0.66), 1.5)
					draw_arc(point, 13.0, 0.0, TAU, 24, order_color, 1.7, true)
				else:
					_draw_course(point, arrival, Color("ffd08191"), 1.3)
			_draw_contact(point, contact.role)
			if not visible_roles.has(contact.role):
				visible_roles.append(contact.role)
		if visible_roles.is_empty():
			return
		var width := 10.0
		for role: String in visible_roles:
			width += 29.0 + font.get_string_size(roles[role], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var legend := Rect2(size.x - width - 11.0, size.y - 32.0, width, 24.0)
		label_boxes.append(legend)
		draw_rect(legend, CHART_BACKGROUND)
		var left := legend.position + Vector2(12, 12)
		for role: String in visible_roles:
			_draw_contact(left, role)
			draw_string(font, left + Vector2(12, 5), roles[role], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
			left.x += 29.0 + font.get_string_size(roles[role], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x

	func _draw_contact(point: Vector2, role: String) -> void:
		var color: Color = CONTACT_COLORS[role]
		match role:
			"trader":
				draw_arc(point, 5.5, 0.0, TAU, 20, color, 1.4, true)
			"patrol":
				draw_rect(Rect2(point - Vector2(5, 5), Vector2(10, 10)), color, false, 1.4)
			"convoy":
				draw_rect(Rect2(point - Vector2(8, 4), Vector2(16, 8)), color, false, 1.4)
				draw_line(point - Vector2(0, 4), point + Vector2(0, 4), color, 1.4, true)
			"worksite":
				draw_arc(point, 8.0, 0.0, TAU, 24, color, 1.4, true)
				draw_line(point - Vector2(4, 0), point + Vector2(4, 0), color, 1.4, true)
				draw_line(point - Vector2(0, 4), point + Vector2(0, 4), color, 1.4, true)
			_:
				var radius := 7.0 if role == "raider" else 5.0
				var diamond := PackedVector2Array([
					point + Vector2.UP * radius, point + Vector2.RIGHT * radius,
					point + Vector2.DOWN * radius, point + Vector2.LEFT * radius,
					point + Vector2.UP * radius,
				])
				draw_polyline(diamond, color, 1.5, true)

	func _draw_course(start: Vector2, finish: Vector2, color: Color, width: float) -> void:
		if start.distance_squared_to(finish) > 100.0:
			draw_dashed_line(start, finish, color, width, 9.0, true, true)

	func _draw_site_label(font: Font, caption: String, marker: Vector2, used: Array[Rect2]) -> void:
		const FONT_SIZE := 16
		var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var size_px := Vector2(width + 10, 22)
		var positions := [
			marker + Vector2(17, -10),
			marker + Vector2(-width - 26, -10),
			marker + Vector2(-width / 2.0 - 5, 22),
			marker + Vector2(-width / 2.0 - 5, -39),
		]
		var box := Rect2(positions[0].clamp(Vector2.ONE, size - size_px - Vector2.ONE), size_px)
		for label_position: Vector2 in positions:
			var proposed := Rect2(label_position.clamp(Vector2.ONE, size - size_px - Vector2.ONE), size_px)
			var free := true
			for other: Rect2 in used:
				if other.intersects(proposed):
					free = false
					break
			if free:
				box = proposed
				break
		used.append(box)
		draw_rect(box, CHART_BACKGROUND.lightened(0.022))
		draw_string(font, box.position + Vector2(5, 16), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT)
