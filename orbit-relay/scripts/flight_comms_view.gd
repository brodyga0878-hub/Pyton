extends CanvasLayer

signal command_requested(action: String)
signal dismissed()

const Text := preload("res://scripts/flight_text.gd")
const INK := Color("e8f7f7")
const MINT := Color("9be7d3")
const MUTED := Color("9cb8c4")
const BORDER := Color("3a5962")
const CONNECT_TIME := 0.34
const DRAG_THRESHOLD := 12.0

var _flight: RefCounted
var _contact := ""
var _insets: MarginContainer
var _scroll: ScrollContainer
var _portrait: TransmissionPortrait
var _title: Label
var _caption: Label
var _summary: Label
var _receipt: Label
var _actions: VBoxContainer
var _close: Button
var _buttons: Dictionary[String, Button] = {}
var _action_ids: Array[String] = []
var _finger := -1
var _pressed: Button
var _touch_start := Vector2.ZERO
var _scroll_start := 0
var _scrolling := false
var _dragged := false


func build() -> void:
	if is_instance_valid(_insets):
		return
	layer = 12
	var shade := ColorRect.new()
	shade.color = Color(0.008, 0.019, 0.029, 0.88)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_insets = MarginContainer.new()
	add_child(_insets)
	_insets.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_insets.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(850, 454)
	panel.add_theme_stylebox_override("panel", _style(Color("111f29"), BORDER, 14, 16))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	_title = _label(header, 27, INK)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close = _button(header, Text.text("LINK_CLOSE"))
	_close.pressed.connect(_request_close)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	content.add_child(body)
	var image := VBoxContainer.new()
	image.custom_minimum_size.x = 245
	body.add_child(image)
	_portrait = TransmissionPortrait.new()
	_portrait.custom_minimum_size = Vector2(245, 302)
	_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image.add_child(_portrait)
	_caption = _label(image, 16, MINT)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_scroll)
	var transcript := VBoxContainer.new()
	transcript.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transcript.add_theme_constant_override("separation", 8)
	_scroll.add_child(transcript)
	_summary = _label(transcript, 19, INK)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_receipt = _label(transcript, 18, MINT)
	_receipt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 6)
	transcript.add_child(_actions)
	get_viewport().size_changed.connect(_update_insets)
	_update_insets()
	hide()


func open(flight: RefCounted, selected_contact := "") -> void:
	if flight == null:
		return
	build()
	_flight = flight
	_contact = selected_contact
	_reset_touch()
	_scroll.scroll_vertical = 0
	_receipt.text = ""
	_portrait.clock = 0.0
	_portrait.reply_until = 0.0
	show()
	refresh()


func refresh() -> void:
	if not is_open():
		return
	var state: Dictionary = _flight.comms_status(_contact)
	var title := Text.field(state, "title")
	_title.text = Text.text("LINK_TITLE") if title.is_empty() else "%s · %s" % [Text.text("LINK_TITLE"), title]
	_close.text = Text.text("LINK_CLOSE")
	_summary.text = Text.field(state, "summary")
	var receipt := Text.field(state, "receipt")
	var displayed := "" if receipt.is_empty() else "%s\n%s" % [Text.text("LINK_RECEIPT"), receipt]
	if _receipt.text != displayed and not displayed.is_empty():
		_portrait.reply_until = _portrait.clock + 2.8
	_receipt.text = displayed
	_receipt.visible = not displayed.is_empty()
	_portrait.seed = ("%s/%s" % [_contact, str(state.get("title", ""))]).hash()
	_refresh_actions(state.get("actions", []))
	_update_caption()
	_portrait.queue_redraw()


func _refresh_actions(rows: Array) -> void:
	var ids: Array[String] = []
	for row: Dictionary in rows:
		ids.append(str(row.id))
	if ids != _action_ids:
		_reset_touch()
		for child: Node in _actions.get_children():
			_actions.remove_child(child)
			child.queue_free()
		_buttons.clear()
		for id: String in ids:
			var button := _button(_actions, "")
			button.pressed.connect(_request_command.bind(id))
			_buttons[id] = button
		_action_ids = ids
	for row: Dictionary in rows:
		var button := _buttons[str(row.id)]
		var reason := Text.field(row, "reason")
		button.text = Text.field(row, "label")
		button.disabled = not bool(row.enabled)
		button.tooltip_text = reason
		if button.disabled and not reason.is_empty():
			button.text += " · " + reason


func close() -> void:
	_reset_touch()
	_flight = null
	_contact = ""
	hide()


func is_open() -> bool:
	return _flight != null and visible


func contact_id() -> String:
	return _contact


func handle_back() -> bool:
	if not is_open():
		return false
	_request_close()
	return true


func _process(delta: float) -> void:
	if not is_open():
		return
	_portrait.clock += delta
	_update_caption()
	_portrait.queue_redraw()


func _update_caption() -> void:
	_caption.text = Text.text("LINK_CONNECTING" if _portrait.clock < CONNECT_TIME else "LINK_OPEN")


func _request_close() -> void:
	if is_open():
		_reset_touch()
		dismissed.emit()


func _request_command(id: String) -> void:
	if is_open() and _buttons.has(id) and not _buttons[id].disabled:
		_reset_touch()
		command_requested.emit(id)


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventScreenTouch:
		_touch(event)
	elif event is InputEventScreenDrag:
		if event.index == _finger:
			_dragged = _dragged or _touch_start.distance_to(event.position) > DRAG_THRESHOLD
			if _dragged and _scrolling:
				_scroll.scroll_vertical = _scroll_start + roundi(_touch_start.y - event.position.y)
	else:
		return
	get_viewport().set_input_as_handled()


func _touch(event: InputEventScreenTouch) -> void:
	if event.pressed and not event.canceled and _finger < 0:
		_finger = event.index
		_touch_start = event.position
		_scrolling = _scroll.get_global_rect().has_point(event.position)
		_scroll_start = _scroll.scroll_vertical
		_pressed = _button_at(event.position)
	elif event.index == _finger:
		var button := _pressed
		var activate := not event.pressed and not event.canceled and not _dragged
		_reset_touch()
		if activate and button != null and button == _button_at(event.position):
			button.pressed.emit()


func _button_at(point: Vector2) -> Button:
	if _hits(_close, point):
		return _close
	if _scroll.get_global_rect().has_point(point):
		for button: Button in _buttons.values():
			if _hits(button, point):
				return button
	return null


func _reset_touch() -> void:
	_finger = -1
	_pressed = null
	_scrolling = false
	_dragged = false


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_reset_touch()


func _update_insets() -> void:
	var margins := Rect2(24, 20, 24, 20)
	if OS.has_feature("android"):
		var window := Vector2(DisplayServer.window_get_size())
		var safe := DisplayServer.get_display_safe_area()
		if window.x > 0.0 and window.y > 0.0 and safe.has_area():
			var scale := get_viewport().get_visible_rect().size / window
			margins.position += (Vector2(safe.position) * scale).max(Vector2.ZERO)
			margins.size += ((window - Vector2(safe.end)) * scale).max(Vector2.ZERO)
	_insets.add_theme_constant_override("margin_left", ceili(margins.position.x))
	_insets.add_theme_constant_override("margin_top", ceili(margins.position.y))
	_insets.add_theme_constant_override("margin_right", ceili(margins.size.x))
	_insets.add_theme_constant_override("margin_bottom", ceili(margins.size.y))


static func _hits(button: Button, at: Vector2) -> bool:
	return button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(at)


static func _label(parent: Container, size: int, tint: Color) -> Label:
	var item := Label.new()
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", tint)
	parent.add_child(item)
	return item


static func _button(parent: Container, caption: String) -> Button:
	var item := Button.new()
	item.text = caption
	item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	item.custom_minimum_size.y = 48
	item.add_theme_font_size_override("font_size", 17)
	item.add_theme_stylebox_override("normal", _style(Color("1b3541"), BORDER, 8, 11))
	item.add_theme_stylebox_override("hover", _style(Color("28505a"), MINT, 8, 11))
	item.add_theme_stylebox_override("pressed", _style(Color("2f605e"), MINT, 8, 11))
	parent.add_child(item)
	return item


static func _style(fill: Color, edge: Color, radius: int, padding: int) -> StyleBoxFlat:
	var item := StyleBoxFlat.new()
	item.bg_color = fill
	item.border_color = edge
	item.set_border_width_all(1)
	item.set_corner_radius_all(radius)
	item.content_margin_left = padding
	item.content_margin_right = padding
	item.content_margin_top = padding * 0.6
	item.content_margin_bottom = padding * 0.6
	return item


class TransmissionPortrait extends Control:
	const PROFILES := [Color("50c4c0"), Color("a7c88c"), Color("8eaee7")]
	var clock := 0.0
	var reply_until := 0.0
	var seed := 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("091923"))
		var centre := size * 0.5
		var fit := minf(size.x / 228.0, size.y / 292.0)
		var tint: Color = PROFILES[posmod(seed, PROFILES.size())]
		draw_set_transform(centre - Vector2(114, 146) * fit, 0.0, Vector2.ONE * fit)
		draw_rect(Rect2(12, 10, 204, 272), tint.darkened(0.87))
		draw_circle(Vector2(114, 115), 82, tint.darkened(0.76), false, 2.0, true)
		draw_arc(Vector2(114, 115), 69, clock * 0.30, clock * 0.30 + PI * 0.75, 32, tint.darkened(0.33), 2.0, true)
		if clock >= CONNECT_TIME:
			_draw_subject(tint)
		draw_rect(Rect2(12, 10, 204, 272), tint.darkened(0.42), false, 2.0)
		var scan := fposmod(clock * 51.0, 270.0)
		draw_line(Vector2(14, 11 + scan), Vector2(214, 11 + scan), Color(tint, 0.46), 1.4, true)
		for stripe in range(8):
			var wave := (sin(clock * 3.1 + stripe * 1.23) + 1.0) * (5.0 if clock < reply_until else 1.8)
			draw_line(Vector2(32 + stripe * 6, 257 - wave), Vector2(32 + stripe * 6, 257 + wave), tint, 2.0, true)
		draw_circle(Vector2(193, 254), 3.3, tint, true, -1.0, true)

	func _draw_subject(tint: Color) -> void:
		var drift := sin(clock * 1.7) * 1.3
		draw_colored_polygon(PackedVector2Array([
			Vector2(35, 224), Vector2(50, 183), Vector2(76, 167), Vector2(151, 166),
			Vector2(176, 184), Vector2(193, 224)
		]), Color("263d48"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(70, 170), Vector2(90, 185), Vector2(138, 185), Vector2(157, 170),
			Vector2(168, 187), Vector2(139, 210), Vector2(84, 209), Vector2(60, 188)
		]), tint.darkened(0.46))
		var at := Vector2(114, 109 + drift)
		draw_circle(at, 58, Color("667f86"), true, -1.0, true)
		draw_circle(at + Vector2(0, 4), 51, Color("1b2e3b"), true, -1.0, true)
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(-46, -12), at + Vector2(-32, -31), at + Vector2(34, -31),
			at + Vector2(46, -14), at + Vector2(35, 13), at + Vector2(-31, 17)
		]), tint.darkened(0.61))
		draw_line(at + Vector2(-30, -20), at + Vector2(25, -20), tint.lightened(0.22), 2.0, true)
		draw_line(at + Vector2(11, -15), at + Vector2(34, -15), tint, 1.0, true)
		draw_rect(Rect2(at + Vector2(-45, 11), Vector2(13, 25)), tint.darkened(0.35))
		draw_line(at + Vector2(-36, 34), at + Vector2(-7, 43), tint.lightened(0.11), 2.0, true)
		draw_circle(at + Vector2(-6, 43), 3.6, tint, true, -1.0, true)
