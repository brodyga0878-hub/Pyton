extends CanvasLayer

signal destination_selected(system_id: int)
signal jump_requested()
signal dismissed()

const Sector := preload("res://scripts/sector_catalog.gd")
const Expedition := preload("res://scripts/expedition.gd")
const TEXT := Color("e8f4fa")
const MUTED := Color("a5bac7")
const MINT := Color("9debd7")
const AMBER := Color("f3c991")
const BORDER := Color("365561")

var _insets: MarginContainer
var _chart: GalaxyChart
var _current: Label
var _destination: Label
var _affiliation: Label
var _description: Label
var _distance: Label
var _cost: Label
var _fuel: Label
var _status: Label
var _plan_button: Button
var _jump_button: Button
var _close_button: Button
var _system_buttons: Dictionary[int, Button] = {}
var _touches: Dictionary[int, Button] = {}
var _map_touches: Dictionary[int, int] = {}
var _flight: RefCounted
var _candidate := -1


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
	page.add_theme_constant_override("separation", 16)
	_insets.add_child(page)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	page.add_child(header)
	var title := _label(header, "Галактическая карта", 32, TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_current = _label(header, "", 18, MINT)
	_current.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_close_button = _button(header, "Закрыть", 48)
	_close_button.custom_minimum_size.x = 124
	_close_button.pressed.connect(func() -> void: dismissed.emit())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	_chart = GalaxyChart.new()
	_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart.gui_input.connect(_chart_mouse_input)
	body.add_child(_chart)

	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 374
	panel.add_theme_stylebox_override("panel", _style(Color("0d1d28"), BORDER, 12, 18))
	body.add_child(panel)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 5)
	panel.add_child(details)
	for id in range(Sector.SYSTEM_COUNT):
		var button := _button(details, str(Sector.system(id).name), 42)
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_system.bind(id))
		_system_buttons[id] = button
	details.add_child(HSeparator.new())
	_destination = _label(details, "", 26, TEXT)
	_affiliation = _label(details, "", 16, MINT)
	_affiliation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description = _label(details, "", 16, MUTED)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size.y = 47
	_distance = _metric(details, "Расстояние")
	_cost = _metric(details, "Цена прыжка")
	_fuel = _metric(details, "Топливо на борту")
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(space)

	_status = _label(details, "", 16, AMBER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 27
	_status.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var routes := HBoxContainer.new()
	routes.add_theme_constant_override("separation", 8)
	details.add_child(routes)
	_plan_button = _button(routes, "Проложить маршрут", 53)
	_plan_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plan_button.pressed.connect(_plan_route)
	_jump_button = _button(routes, "Прыжок", 53)
	_jump_button.custom_minimum_size.x = 112
	_jump_button.add_theme_stylebox_override("normal", _style(Color("164f4c"), MINT, 8, 12))
	_jump_button.add_theme_stylebox_override("hover", _style(Color("206760"), MINT, 8, 12))
	_jump_button.pressed.connect(_start_jump)
	get_viewport().size_changed.connect(_update_insets)
	_update_insets()
	hide()


func open(sim: RefCounted) -> void:
	build()
	_flight = sim
	_candidate = int(sim.jump_target if sim.jump_target >= 0 else sim.system_id)
	_clear_touches()
	show()
	refresh()


func refresh() -> void:
	if not is_open():
		return
	var current: int = _flight.system_id
	var planned: int = _flight.jump_target
	if not _flight.system_known(_candidate):
		_candidate = current
	var selected := Sector.system(_candidate)
	var is_current := _candidate == current
	var is_planned := _candidate == planned
	_chart.current = current
	_chart.planned = planned
	_chart.candidate = _candidate
	_current.text = "Система «%s»" % Sector.system(current).name
	var known: Array[int] = []
	for id in _system_buttons:
		var button := _system_buttons[id]
		button.visible = _flight.system_known(id)
		if not button.visible:
			continue
		known.append(id)
		var suffix := ""
		if id == current:
			suffix = "   ·   Корабль"
		elif id == planned:
			suffix = "   ·   По маршруту"
		button.text = str(Sector.system(id).name) + suffix
		button.set_pressed_no_signal(id == _candidate)
	_chart.set_systems(known)
	_chart.queue_redraw()

	_destination.text = str(selected.name)
	_affiliation.text = _flight.system_faction_name(_candidate)
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
	_distance.text = "—" if is_current else "%s св. л." % _decimal(Sector.jump_distance(current, _candidate))
	_fuel.text = "%s / %d ед." % [_decimal(_flight.ship.fuel), int(_flight.ship.capacity())]
	var status: Dictionary = _flight.jump_status(_candidate)
	_cost.text = "—" if is_current else "%d ед." % int(status.cost)
	_plan_button.disabled = is_current or is_planned
	_plan_button.text = "Маршрут проложен" if is_planned else "Проложить маршрут"
	_jump_button.disabled = not is_planned or not status.ok
	var hint := "Выберите систему назначения."
	if not is_current:
		if not status.ok:
			hint = str(status.reason)
		elif is_planned:
			hint = "Привод готов к прыжку."
		else:
			hint = "Сохраните маршрут, чтобы запустить привод."
	_status.text = hint
	_status.add_theme_color_override("font_color", MINT if not _jump_button.disabled else MUTED if is_current else AMBER)


func close() -> void:
	_clear_touches()
	_flight = null
	hide()


func is_open() -> bool:
	return _flight != null and visible


func _select_system(id: int) -> void:
	if is_open() and _flight.system_known(id):
		_candidate = id
		_clear_touches()
		refresh()


func _plan_route() -> void:
	if is_open() and not _plan_button.disabled:
		_clear_touches()
		destination_selected.emit(_candidate)


func _start_jump() -> void:
	if is_open() and _flight.jump_target == _candidate and _flight.jump_status(_candidate).ok:
		_clear_touches()
		jump_requested.emit()


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventScreenTouch:
		var button: Button = _touches.get(event.index)
		var system_id: int = _map_touches.get(event.index, -1)
		_touches.erase(event.index)
		_map_touches.erase(event.index)
		if not event.canceled:
			if event.pressed:
				var hit := _button_at(event.position)
				if hit != null:
					if hit not in _touches.values():
						_touches[event.index] = hit
				else:
					var marker := _chart_system_at(event.position)
					if marker >= 0 and marker not in _map_touches.values():
						_map_touches[event.index] = marker
			elif button != null and not button.disabled and button.get_global_rect().has_point(event.position):
				button.pressed.emit()
			elif system_id >= 0 and _chart_system_at(event.position) == system_id:
				_select_system(system_id)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
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


func _button_at(point: Vector2) -> Button:
	for button: Button in [_plan_button, _jump_button, _close_button]:
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
	var _sky := PackedVector3Array()
	var _systems: Array[int] = []
	var _center := Vector2.ZERO
	var _extent := Vector2.ONE

	func _ready() -> void:
		var random := RandomNumberGenerator.new()
		random.seed = 77106
		for i in range(128):
			_sky.append(Vector3(random.randf(), random.randf(), random.randf()))
		resized.connect(queue_redraw)

	func set_systems(systems: Array[int]) -> void:
		_systems = systems
		if _systems.is_empty():
			return
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for id in _systems:
			var point: Vector2 = Sector.system(id).position
			low = low.min(point)
			high = high.max(point)
		_center = (low + high) * 0.5
		_extent = (high - low).max(Vector2.ONE)

	func marker_position(id: int) -> Vector2:
		return size * 0.5 + (Sector.system(id).position - _center) * _pixels_per_light_year()

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
		if _systems.has(current):
			_draw_routes()
		for id in _systems:
			_draw_marker(id)
		_draw_scale()

	func _draw_routes() -> void:
		var origin := marker_position(current)
		for id in _systems:
			if Sector.jump_cost(current, id) <= 0:
				continue
			var end := marker_position(id)
			var direction := origin.direction_to(end)
			var start := origin + direction * 37.0
			var finish := end - direction * 37.0
			var tint := Color("425e69")
			var width := 1.2
			if id == planned:
				tint = MINT
				width = 2.2
			elif id == candidate:
				tint = AMBER
				width = 1.8
			draw_dashed_line(start, finish, tint, width, 8.0, true, true)
			if id == planned:
				var side := direction.orthogonal() * 6.0
				var base := finish - direction * 12.0
				draw_colored_polygon(PackedVector2Array([finish, base + side, base - side]), tint)

	func _draw_marker(id: int) -> void:
		var system := Sector.system(id)
		var point := marker_position(id)
		var accent: Color = system.accent
		draw_circle(point, 32.0, Color(accent, 0.07), true, -1.0, true)
		draw_circle(point, 18.0, Color(accent, 0.16), true, -1.0, true)
		draw_arc(point, 23.0, 0.0, TAU, 48, Color(accent, 0.70), 1.2, true)
		draw_circle(point, 9.0, accent, true, -1.0, true)
		draw_circle(point, 4.0, accent.lerp(Color.WHITE, 0.72), true, -1.0, true)
		if id == current:
			draw_colored_polygon(PackedVector2Array([point + Vector2(0, -43), point + Vector2(6, -34), point + Vector2(-6, -34)]), MINT)
		if id == candidate:
			for i in range(4):
				var angle := i * TAU * 0.25 + 0.15
				draw_arc(point, 32.0, angle, angle + 1.27, 12, MINT if id == planned or id == current else AMBER, 2.2, true)

		var annotation := "Корабль" if id == current else "Пункт назначения" if id == planned else ""
		var font := ThemeDB.fallback_font
		var name_width := font.get_string_size(str(system.name), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 23).x
		var note_width := font.get_string_size(annotation, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15).x
		var width := maxf(name_width, note_width) + 24.0
		var height := 55.0 if not annotation.is_empty() else 32.0
		var label_box := Rect2(point.x - width * 0.5, point.y + 43.0, width, height)
		draw_rect(label_box, FIELD)
		draw_string(font, point + Vector2(-name_width * 0.5, 66.0), str(system.name), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 23, TEXT)
		if not annotation.is_empty():
			draw_string(font, point + Vector2(-note_width * 0.5, 90.0), annotation, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, MINT)

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
