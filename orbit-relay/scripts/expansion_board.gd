extends CanvasLayer

signal project_requested()
signal dismissed()

const Sector = preload("res://scripts/sector_catalog.gd")
const Economy = preload("res://scripts/port_economy.gd")
const Factions = preload("res://scripts/faction_fronts.gd")
const INK := Color("edf7f9")
const MUTED := Color("adc0c9")
const MINT := Color("a4e9d6")
const AMBER := Color("f0c59a")
const ALERT := Color("ffa79e")
const BORDER := Color("355360")
const STAGES := ["Принять заказ", "Обследовать систему", "Сдать отчёт", "Снабдить стройку"]
const NEWS_LIMIT := 3

var _sim: RefCounted
var _insets: MarginContainer
var _location: Label
var _project_title: Label
var _issuer: Label
var _reward: Label
var _steps: Array[Dictionary] = []
var _supplies: VBoxContainer
var _materials: Array[Label] = []
var _reason: Label
var _project_button: Button
var _close_button: Button
var _systems: Array[Dictionary] = []
var _convoy_panel: VBoxContainer
var _convoys: Array[Label] = []
var _news_scroll: ScrollContainer
var _news: Array[Label] = []
var _touches: Dictionary[int, Button] = {}
var _news_finger := -1


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
	var page := _column(_insets, 14)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	page.add_child(header)
	_label(header, "Освоение рубежей", 33, INK).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_location = _label(header, "", 19, MINT)
	_location.autowrap_mode = TextServer.AUTOWRAP_OFF
	_close_button = _button(header, "Закрыть")
	_close_button.custom_minimum_size.x = 128.0
	_close_button.pressed.connect(func() -> void: dismissed.emit())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	_build_project(body)
	_build_fronts(body)
	get_viewport().size_changed.connect(_update_insets)
	_update_insets()
	hide()


func open(sim: RefCounted) -> void:
	if sim == null:
		return
	build()
	_sim = sim
	_touches.clear()
	_news_finger = -1
	_news_scroll.scroll_vertical = 0
	show()
	refresh()


func refresh() -> void:
	if not is_open():
		return
	var status: Dictionary = _sim.frontier_status()
	_location.text = "Система «%s»" % Sector.system(_sim.system_id).name
	_refresh_project(status)
	_refresh_fronts(status)


func close() -> void:
	_touches.clear()
	_news_finger = -1
	_sim = null
	hide()


func is_open() -> bool:
	return _sim != null and visible


func _build_project(body: HBoxContainer) -> void:
	var card := _card(body, 458.0)
	_project_title = _label(card, "", 29, INK)
	_issuer = _label(card, "", 17, MUTED)
	_reward = _label(card, "", 16, MINT)
	var stages := _column(card, 4)
	for caption: String in STAGES:
		_steps.append(_status_row(stages, caption))
	_supplies = _column(card, 3)
	_label(_supplies, "Груз для следующей поставки", 17, MINT)
	for good: String in Economy.GOODS:
		_materials.append(_label(_supplies, "", 17, INK))
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(spacer)
	_reason = _label(card, "", 18, INK)
	_project_button = _button(card, "")
	_project_button.pressed.connect(_request_project)


func _build_fronts(body: HBoxContainer) -> void:
	var card := _card(body, 414.0)
	_label(card, "Контроль систем", 25, INK)
	var systems := _column(card, 3)
	for id in range(Sector.SYSTEM_COUNT):
		_systems.append(_status_row(systems, str(Sector.system(id).name)))
	var divider := HSeparator.new()
	card.add_child(divider)
	_convoy_panel = _column(card, 3)
	_label(_convoy_panel, "Конвои фракций", 23, INK)
	for index in range(Factions.FRONTIER_SYSTEMS.size() * Factions.FACTIONS.size()):
		_convoys.append(_label(_convoy_panel, "", 16, INK))
	_label(card, "События фракций", 23, INK)
	_news_scroll = ScrollContainer.new()
	_news_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_news_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(_news_scroll)
	var events := _column(_news_scroll, 8)
	events.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index in range(NEWS_LIMIT):
		_news.append(_label(events, "", 16, MUTED))


func _refresh_project(status: Dictionary) -> void:
	var phase: int = status.phase
	var system: int = status.system
	var sponsor: int = status.sponsor
	var sponsor_port: int = status.sponsor_port
	var known: bool = system >= 0 and _sim.system_known(system)
	var series_done: bool = status.series_done
	_project_title.text = "Экспедиция в «%s»" % Sector.system(system).name if known else "Пограничная экспедиция"
	if series_done:
		_project_title.text = "Станции введены в строй"
	_issuer.visible = not series_done
	_issuer.text = "Заказчик появится после принятия заказа."
	if sponsor >= 0 and sponsor_port >= 0:
		_issuer.text = "%s · «%s»" % [Factions.faction_name(sponsor), _sim.target_name(sponsor_port)]
	elif status.can_act and _sim.docked >= 0:
		_issuer.text = "%s · «%s»" % [_sim.system_faction_name(_sim.system_id), _sim.target_name(_sim.docked)]
	_reward.visible = not series_done
	_reward.text = "За ввод станции %d кр." % status.build_reward
	if phase < 3:
		_reward.text = "За отчёт %d кр. · За ввод станции %d кр." % [status.survey_reward, status.build_reward]
	for index in range(_steps.size()):
		var row := _steps[index]
		var caption: String = STAGES[index]
		if index == 1 and phase >= 1:
			caption += " · %d из %d" % [status.scan_index, status.scan_total]
		elif index == 3 and phase >= 3:
			caption += " · %d из %d" % [status.build_index, status.build_total]
		row.name.text = caption
		var active := not series_done and phase == index
		row.state.text = "В работе" if active else ("Готово" if series_done or phase > index else "")
		if active and index == 0:
			row.state.text = "Доступно" if status.can_act else "В порту"
		row.name.modulate = Color.WHITE if active else MUTED
		row.state.modulate = MINT if active else MUTED
	var needs: Dictionary = status.needs
	_supplies.visible = not needs.is_empty()
	for index in range(_materials.size()):
		var good: String = Economy.GOODS[index]
		var line := _materials[index]
		var quantity := int(needs.get(good, 0))
		line.visible = quantity > 0
		if not line.visible:
			continue
		var owned: int = _sim.mining.cargo_amount(good)
		line.text = "%s · %d из %d ед." % [Economy.good_name(good), owned, quantity]
		line.modulate = MINT if owned >= quantity else AMBER
	_reason.text = str(status.reason)
	if status.has_point and not status.can_act:
		var distance := float(status.distance)
		var distance_text := "%.1f км" % (distance / 1000.0) if distance >= 1000.0 else "%d м" % roundi(distance)
		_reason.text += "\n«%s» · %s" % [_sim.target_name(status.site), distance_text]
	_project_button.visible = not series_done
	var route_system := int(status.route_system)
	var route_port := int(status.route_port)
	var can_plan_jump: bool = route_system >= 0 and route_system != _sim.system_id
	var can_plan_docking: bool = phase == 2 and route_port >= 0 and _sim.docked != route_port
	_project_button.text = str(status.caption)
	if not status.can_act:
		if status.can_follow:
			_project_button.text = "К точке экспедиции"
		elif can_plan_jump:
			_project_button.text = "Проложить прыжок"
		elif can_plan_docking:
			_project_button.text = "К порту заказчика"
	_project_button.disabled = _sim.jump_seconds_left > 0.0 or not (
		status.can_act or status.can_follow or can_plan_jump or can_plan_docking
	)


func _refresh_fronts(status: Dictionary) -> void:
	var convoy_count := 0
	for id in range(_systems.size()):
		var row := _systems[id]
		row.panel.visible = _sim.system_known(id)
		if not row.panel.visible:
			continue
		var front: Dictionary = _sim.factions.system_state(id)
		if int(front.owner) < 0:
			row.state.text = "Строительство" if status.system == id and status.phase == 3 else "Разведка"
			row.state.modulate = MUTED
		else:
			row.state.text = _sim.system_faction_name(id)
			row.state.modulate = MINT
			if front.stage == "war":
				row.state.text += " · Оспаривается (%d%%)" % int(front.pressure)
				row.state.modulate = AMBER
		for convoy: Dictionary in front.get("convoys", []):
			_sync_convoy(_convoys[convoy_count], id, convoy)
			convoy_count += 1
	_convoy_panel.visible = convoy_count > 0
	for index in range(_convoys.size()):
		_convoys[index].visible = index < convoy_count
	var news: Array = _sim.factions.news()
	for index in range(_news.size()):
		var item := _news[index]
		item.visible = index < news.size() or index == 0
		if item.visible:
			item.text = str(news[index]) if index < news.size() else "Сводок пока нет."


func _sync_convoy(line: Label, system: int, convoy: Dictionary) -> void:
	var seconds := maxi(0, ceili(float(convoy.due_at) - _sim.orbit_time))
	var state := "В пути · %d с" % seconds
	var tint := INK
	match convoy.stage:
		"delivered":
			state = "Доставлен"
			tint = MINT
		"intercepted":
			state = "Перехвачен"
			tint = ALERT
	line.text = "%s · %s · %s ×%d · %s" % [
		Sector.system(system).name, Factions.faction_name(convoy.faction), convoy.shipment, convoy.units, state,
	]
	line.add_theme_color_override("font_color", tint)


func _request_project() -> void:
	if is_open() and _project_button.visible and not _project_button.disabled:
		_touches.clear()
		project_requested.emit()


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventScreenTouch:
		var button: Button = _touches.get(event.index)
		_touches.erase(event.index)
		if event.index == _news_finger:
			_news_finger = -1
		if not event.canceled:
			if event.pressed:
				var hit := _button_at(event.position)
				if hit != null and hit not in _touches.values():
					_touches[event.index] = hit
				elif _news_finger < 0 and _news_scroll.get_v_scroll_bar().visible and _news_scroll.get_global_rect().has_point(event.position):
					_news_finger = event.index
			elif button != null and button.visible and not button.disabled and button.get_global_rect().has_point(event.position):
				button.pressed.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _news_finger:
			_news_scroll.scroll_vertical -= roundi(event.relative.y)
		else:
			var held: Button = _touches.get(event.index)
			if held != null and not held.get_global_rect().has_point(event.position):
				_touches.erase(event.index)
		get_viewport().set_input_as_handled()


func _button_at(point: Vector2) -> Button:
	for button: Button in [_close_button, _project_button]:
		if button.visible and not button.disabled and button.get_global_rect().has_point(point):
			return button
	return null


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_touches.clear()
		_news_finger = -1


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


static func _card(parent: Control, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(Color("101f2a"), BORDER, 14, 19))
	parent.add_child(panel)
	return _column(panel, 10)


static func _column(parent: Control, gap: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", gap)
	parent.add_child(column)
	return column


static func _status_row(parent: Control, caption: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 39.0
	panel.add_theme_stylebox_override("panel", _style(Color("142733"), Color("253f4c"), 7, 8))
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var name := _label(row, caption, 18, INK)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var state := _label(row, "", 16, INK)
	state.autowrap_mode = TextServer.AUTOWRAP_OFF
	return {"panel": panel, "name": name, "state": state}


static func _label(parent: Control, caption: String, points: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
	button.add_theme_stylebox_override("normal", _style(Color("173b41"), Color("457783"), 8, 12))
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
	box.content_margin_top = padding * 0.7
	box.content_margin_bottom = padding * 0.7
	return box
