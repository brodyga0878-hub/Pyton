extends CanvasLayer

signal destination_selected(site_id: int)
signal dismissed()

const Sector := preload("res://scripts/sector_catalog.gd")
const Expedition := preload("res://scripts/expedition.gd")
const Orbit := preload("res://scripts/orbit_ephemeris.gd")
const Patrol := preload("res://scripts/patrol_encounter.gd")
const TEXT := Color("e8f4fa")
const MUTED := Color("a5bac7")
const MINT := Color("9debd7")
const INTERCEPT := Color("ffb18e")
const BORDER := Color("365561")

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
var _close_button: Button
var _select_button: Button
var _site_buttons: Dictionary[int, Button] = {}
var _touches: Dictionary[int, Button] = {}
var _touch_sites: Dictionary[int, int] = {}
var _flight: RefCounted
var _candidate := -1


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
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	panel.add_child(list)
	for system_id in range(Sector.SYSTEM_COUNT):
		for id: int in Sector.ports_for(system_id):
			_add_site(list, id)
		for id: int in Sector.mines_for(system_id):
			_add_site(list, id)
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
	get_viewport().size_changed.connect(_size_changed)
	_size_changed()
	hide()


func open(sim: RefCounted) -> void:
	if not is_instance_valid(_sheet):
		build()
	_flight = sim
	_touches.clear()
	_touch_sites.clear()
	var system_id: int = sim.system_id
	_title.text = "Карта системы «%s»" % Sector.system(system_id).name
	var here := _current_site()
	_here.text = "В полёте" if here < 0 else str(Sector.site(here).name)
	var targets: Array = sim.local_targets()
	for id: int in _site_buttons:
		_site_buttons[id].visible = targets.has(id)
	_chart.ship_position = sim.position
	_chart.ship_heading = sim.forward()
	var star_center: Vector3 = sim.target_position(Sector.star_for(system_id))
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


func _add_site(parent: VBoxContainer, id: int) -> void:
	var site = Sector.site(id)
	var button := _button(parent, str(site.name), 39)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.toggle_mode = true
	button.pressed.connect(_select_site.bind(id))
	_site_buttons[id] = button


func _select_site(id: int) -> void:
	if _flight == null or not _chart.centers.has(id):
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
	else:
		var remaining: int = _flight.mining.reserve_at(id)
		_detail.text += "\n%s · %d ед. в залежи" % [Sector.resource_name(entry.resource), remaining]
		if entry.kind == "planet":
			_detail.text += "\nТвёрдая поверхность"
	_select_button.disabled = here


func _apply() -> void:
	if _flight != null and _chart.centers.has(_candidate) and _candidate != _current_site():
		destination_selected.emit(_candidate)


func _toggle_projection() -> void:
	_touch_sites.clear()
	_chart.side_view = not _chart.side_view
	_view_button.text = "Сверху" if _chart.side_view else "Сбоку"
	_chart.queue_redraw()


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
				if button != null and not button.disabled and button.get_global_rect().has_point(touch.position):
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
	for button: Button in [_select_button, _view_button, _close_button]:
		if not button.disabled and button.get_global_rect().has_point(point):
			return button
	for button: Button in _site_buttons.values():
		if button.visible and button.get_global_rect().has_point(point):
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
		return Rect2(minimum, (maximum - minimum).max(Vector2.ONE))

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
		if orbit.size() >= 2:
			var track := PackedVector2Array()
			track.resize(orbit.size())
			for index in orbit.size():
				track[index] = _project(orbit[index], plot, bounds)
			draw_polyline(track, ORBIT_COLOR, 1.7, true)
		var ship := _project(ship_position, plot, bounds).clamp(Vector2(18, 35), size - Vector2(18, 28))
		if side_view:
			draw_line(ship, Vector2(ship.x, plane_y), Color(STAR_PLANE_COLOR, 0.72), 1.0, true)
		if centers.has(active_site):
			_draw_course(ship, _project(centers[active_site], plot, bounds), Color("4d928c"), 1.5)
		if centers.has(selected_site) and selected_site != active_site:
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
