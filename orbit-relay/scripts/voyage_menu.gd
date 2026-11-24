extends CanvasLayer

signal action_requested(action: String, slot_id: String, name: String)

const Library := preload("res://scripts/voyage_library.gd")
const CHANGE_NOTICE := "При переключении автосохранение изменится. Для отдельного хранения сохраните именную копию."
const TEXT := Color("e9f4f7")
const MUTED := Color("a9bec8")
const ACCENT := Color("a2e7d2")
const WARNING := Color("f2bc91")
const BORDER := Color("36515c")
const DRAG_THRESHOLD := 10.0

var _shade: ColorRect
var _insets: MarginContainer
var _heading: Label
var _status: Label
var _scroll: ScrollContainer
var _slot_rows: VBoxContainer
var _slot_actions: HBoxContainer
var _empty: Label
var _details: VBoxContainer
var _prompt: Label
var _name_field: LineEdit
var _accept: Button
var _cancel: Button
var _actions: Dictionary[String, Button] = {}
var _slot_buttons: Dictionary[String, Button] = {}
var _slot_names: Dictionary[String, String] = {}

var _startup := false
var _primary_available := false
var _backup_available := false
var _selected_slot := ""
var _pending_action := ""
var _pending_slot := ""
var _touch_index := -1
var _touch_button: Button
var _touch_field := false
var _touch_scroll := false
var _touch_moved := false
var _touch_origin := Vector2.ZERO
var _scroll_origin := 0


func build() -> void:
	if is_instance_valid(_insets):
		return
	layer = 11
	_shade = ColorRect.new()
	_shade.color = Color(0.008, 0.019, 0.026, 0.88)
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_insets = MarginContainer.new()
	add_child(_insets)
	_insets.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("101e27"), BORDER, 18, 20))
	_insets.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	_heading = _label(header, "Рейсы", 32, TEXT)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_action(header, "report", "Отчёт").custom_minimum_size.x = 112
	_add_action(header, "close", "Закрыть").custom_minimum_size.x = 112

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	_build_session_actions(body)
	_build_saved_flights(body)
	_status = _label(content, "", 17, ACCENT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.hide()

	get_viewport().size_changed.connect(_update_insets)
	_update_insets()
	hide()


func open(startup: bool, primary_available: bool, backup_available: bool, slots: Array[Dictionary]) -> void:
	build()
	_startup = startup
	_selected_slot = ""
	_clear_pending()
	_scroll.scroll_vertical = 0
	notify("")
	refresh(primary_available, backup_available, slots)
	_shade.color.a = 1.0 if startup else 0.88
	show()
	if not _actions["continue"].disabled:
		_actions["continue"].grab_focus()
	else:
		_actions["new"].grab_focus()


func refresh(primary_available: bool, backup_available: bool, slots: Array[Dictionary]) -> void:
	build()
	_primary_available = primary_available
	_backup_available = backup_available
	_reset_touch()
	var previous_scroll := _scroll.scroll_vertical
	for button: Button in _slot_buttons.values():
		_slot_rows.remove_child(button)
		button.queue_free()
	_slot_buttons.clear()
	_slot_names.clear()
	for slot: Dictionary in slots:
		var id := str(slot.get("id", ""))
		var name := str(slot.get("name", ""))
		if id.is_empty() or name.is_empty() or _slot_names.has(id):
			continue
		_slot_names[id] = name
		var row := _button(_slot_rows, name)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.toggle_mode = true
		row.tooltip_text = name
		row.pressed.connect(_select_slot.bind(id))
		_slot_buttons[id] = row
	if not _slot_names.has(_selected_slot):
		_selected_slot = "" if _slot_names.is_empty() else _slot_names.keys()[0]
	_restore_scroll.call_deferred(previous_scroll)
	_sync()


func close() -> void:
	if not is_instance_valid(_insets):
		return
	_clear_pending()
	hide()


func is_open() -> bool:
	return is_instance_valid(_insets) and visible


func notify(message: String) -> void:
	build()
	_status.text = message
	_status.visible = not message.is_empty()


func handle_back() -> bool:
	if not is_open():
		return false
	if not _pending_action.is_empty():
		_cancel_pending()
	elif not _startup:
		_emit_action("close")
	return true


func _build_session_actions(parent: HBoxContainer) -> void:
	var group := VBoxContainer.new()
	group.custom_minimum_size.x = 290
	group.add_theme_constant_override("separation", 10)
	parent.add_child(group)
	_label(group, "Текущий рейс", 22, MUTED)
	_add_action(group, "continue", "Продолжить")
	_add_action(group, "new_solar", "Рейс у Земли").tooltip_text = "Начать рядом с Землёй в Солнечной системе."
	_add_action(group, "new", "Новый рейс · кампания")
	_add_action(group, "recover", "Восстановить резерв")
	_add_action(group, "import", "Загрузить файл")


func _build_saved_flights(parent: HBoxContainer) -> void:
	var group := VBoxContainer.new()
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.add_theme_constant_override("separation", 10)
	parent.add_child(group)
	_label(group, "Сохранённые рейсы", 22, MUTED)
	_build_action_details(group)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	group.add_child(_scroll)
	_slot_rows = VBoxContainer.new()
	_slot_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_rows.add_theme_constant_override("separation", 6)
	_scroll.add_child(_slot_rows)
	_empty = _label(_slot_rows, "Именных копий пока нет.", 18, MUTED)
	_slot_actions = HBoxContainer.new()
	_slot_actions.add_theme_constant_override("separation", 8)
	group.add_child(_slot_actions)
	_add_action(_slot_actions, "create", "Сохранить копию")
	_add_action(_slot_actions, "load", "Открыть")
	_add_action(_slot_actions, "rename", "Переименовать")
	_add_action(_slot_actions, "delete", "Удалить")


func _build_action_details(parent: VBoxContainer) -> void:
	_details = VBoxContainer.new()
	_details.add_theme_constant_override("separation", 8)
	parent.add_child(_details)
	_prompt = _label(_details, "", 19, WARNING)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_field = LineEdit.new()
	_name_field.custom_minimum_size.y = 53
	_name_field.placeholder_text = "Название рейса"
	_name_field.max_length = Library.MAX_NAME_LENGTH
	_name_field.add_theme_font_size_override("font_size", 20)
	_name_field.text_changed.connect(_on_name_changed)
	_name_field.text_submitted.connect(_on_name_submitted)
	_details.add_child(_name_field)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_details.add_child(actions)
	_cancel = _button(actions, "Отмена")
	_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel.pressed.connect(_cancel_pending)
	_accept = _button(actions, "Подтвердить")
	_accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_accept.pressed.connect(_accept_pending)
	_details.hide()
	_name_field.hide()


func _sync() -> void:
	var pending := not _pending_action.is_empty()
	var selected := _slot_names.has(_selected_slot)
	_heading.text = str(ProjectSettings.get_setting("application/config/name")) if _startup else "Рейсы"
	_actions["close"].visible = not _startup
	_actions["close"].disabled = pending
	_actions["report"].disabled = pending
	_actions["continue"].disabled = pending or (_startup and not _primary_available)
	_actions["new"].disabled = pending
	_actions["new_solar"].disabled = pending
	_actions["recover"].disabled = pending or not _backup_available
	_actions["import"].disabled = pending
	_actions["create"].disabled = _startup or _slot_names.size() >= Library.MAX_SLOTS
	_actions["create"].tooltip_text = ""
	if _startup:
		_actions["create"].tooltip_text = "Начните или откройте рейс, чтобы сохранить копию."
	elif _slot_names.size() >= Library.MAX_SLOTS:
		_actions["create"].tooltip_text = "Список именных копий заполнен."
	for action: String in ["load", "rename", "delete"]:
		_actions[action].disabled = not selected
	_slot_actions.visible = not pending
	_details.visible = pending
	_empty.visible = _slot_names.is_empty()
	for id: String in _slot_buttons:
		var row := _slot_buttons[id]
		row.disabled = pending
		row.set_pressed_no_signal(id == _selected_slot)


func _select_slot(id: String) -> void:
	if is_open() and _pending_action.is_empty() and _slot_names.has(id):
		_selected_slot = id
		_sync()


func _request_action(action: String) -> void:
	if not is_open() or _actions[action].disabled or not _pending_action.is_empty():
		return
	notify("")
	var name: String = _slot_names.get(_selected_slot, "")
	match action:
		"new", "new_solar":
			if _startup and not _primary_available and not _backup_available:
				_emit_action(action)
			else:
				var label := "Начать у Земли" if action == "new_solar" else "Начать новый рейс"
				_begin_pending(action, "", CHANGE_NOTICE, label)
		"recover":
			if _startup and not _primary_available:
				_emit_action(action)
			else:
				_begin_pending(action, "", CHANGE_NOTICE, "Восстановить")
		"load":
			if _startup and not _primary_available and not _backup_available:
				_emit_action(action, _selected_slot)
			else:
				_begin_pending(action, _selected_slot, "Открыть рейс «%s»?\n%s" % [name, CHANGE_NOTICE], "Открыть рейс")
		"delete":
			_begin_pending(action, _selected_slot, "Удалить сохранённую копию «%s»?" % name, "Удалить копию")
		"rename":
			_begin_pending(action, _selected_slot, "Введите новое название рейса.", "Переименовать", name)
		"create":
			_begin_pending(action, "", "Введите название копии текущего рейса.", "Сохранить копию")
		"import":
			if _startup and not _primary_available:
				_emit_action(action)
			else:
				_begin_pending(action, "", CHANGE_NOTICE, "Выбрать файл")
		_:
			_emit_action(action)


func _begin_pending(action: String, slot_id: String, prompt: String, label: String, existing_name := "") -> void:
	_reset_touch()
	_pending_action = action
	_pending_slot = slot_id
	_prompt.text = prompt
	_accept.text = label
	_name_field.visible = action == "create" or action == "rename"
	_name_field.text = existing_name
	_accept.disabled = _name_field.visible and existing_name.is_empty()
	_sync()
	if _name_field.visible:
		_name_field.select_all()
		_focus_name()
	else:
		_cancel.grab_focus()


func _accept_pending() -> void:
	if not is_open() or _pending_action.is_empty() or _accept.disabled:
		return
	var action := _pending_action
	var slot_id := _pending_slot
	var name := _name_field.text.strip_edges() if _name_field.visible else ""
	_clear_pending()
	_sync()
	_emit_action(action, slot_id, name)


func _cancel_pending() -> void:
	_clear_pending()
	_sync()
	if not _startup:
		_actions["close"].grab_focus()


func _clear_pending() -> void:
	_reset_touch()
	if _name_field.visible and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
	if _name_field.has_focus():
		_name_field.release_focus()
	_pending_action = ""
	_pending_slot = ""
	_name_field.hide()


func _emit_action(action: String, slot_id := "", name := "") -> void:
	_reset_touch()
	action_requested.emit(action, slot_id, name)


func _on_name_changed(text: String) -> void:
	_accept.disabled = text.strip_edges().is_empty()


func _on_name_submitted(_text: String) -> void:
	_accept_pending()


func _focus_name() -> void:
	_name_field.grab_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(_name_field.text, _name_field.get_global_rect(),
			DisplayServer.KEYBOARD_TYPE_DEFAULT, Library.MAX_NAME_LENGTH,
			_name_field.get_selection_from_column(), _name_field.get_selection_to_column())


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_touch_moved = _touch_moved or _touch_origin.distance_to(event.position) > DRAG_THRESHOLD
			if _touch_moved and _touch_scroll:
				_scroll.scroll_vertical = _scroll_origin + roundi(_touch_origin.y - event.position.y)
	else:
		return
	get_viewport().set_input_as_handled()


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed and not event.canceled and _touch_index < 0:
		_touch_index = event.index
		_touch_origin = event.position
		_touch_scroll = _scroll.get_global_rect().has_point(event.position)
		_scroll_origin = _scroll.scroll_vertical
		_touch_field = _name_field.is_visible_in_tree() and _name_field.get_global_rect().has_point(event.position)
		_touch_button = _button_at(event.position)
	elif event.index == _touch_index:
		var button := _touch_button
		var field := _touch_field
		var activate := not event.pressed and not event.canceled and not _touch_moved
		_reset_touch()
		if activate and button != null and button == _button_at(event.position):
			button.pressed.emit()
		elif activate and field and _name_field.get_global_rect().has_point(event.position):
			_focus_name()


func _button_at(position: Vector2) -> Button:
	for button: Button in [_accept, _cancel]:
		if _hits(button, position):
			return button
	for button: Button in _actions.values():
		if _hits(button, position):
			return button
	if _scroll.get_global_rect().has_point(position):
		for button: Button in _slot_buttons.values():
			if _hits(button, position):
				return button
	return null


func _reset_touch() -> void:
	_touch_index = -1
	_touch_button = null
	_touch_field = false
	_touch_scroll = false
	_touch_moved = false


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_reset_touch()


func _restore_scroll(offset: int) -> void:
	_scroll.scroll_vertical = offset


func _update_insets() -> void:
	var margins := Vector4(28, 22, 28, 22)
	if OS.has_feature("android"):
		var window := Vector2(DisplayServer.window_get_size())
		var safe_area := DisplayServer.get_display_safe_area()
		if window.x > 0.0 and window.y > 0.0 and safe_area.has_area():
			var scale := get_viewport().get_visible_rect().size / window
			margins.x += maxf(0.0, safe_area.position.x * scale.x)
			margins.y += maxf(0.0, safe_area.position.y * scale.y)
			margins.z += maxf(0.0, (window.x - safe_area.end.x) * scale.x)
			margins.w += maxf(0.0, (window.y - safe_area.end.y) * scale.y)
	_insets.add_theme_constant_override("margin_left", ceili(margins.x))
	_insets.add_theme_constant_override("margin_top", ceili(margins.y))
	_insets.add_theme_constant_override("margin_right", ceili(margins.z))
	_insets.add_theme_constant_override("margin_bottom", ceili(margins.w))


func _add_action(parent: Container, action: String, caption: String) -> Button:
	var item := _button(parent, caption)
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL if action != "close" else Control.SIZE_SHRINK_END
	item.pressed.connect(_request_action.bind(action))
	_actions[action] = item
	return item


static func _button(parent: Container, caption: String) -> Button:
	var item := Button.new()
	item.text = caption
	item.custom_minimum_size.y = 53
	item.add_theme_font_size_override("font_size", 18)
	item.add_theme_color_override("font_color", TEXT)
	item.add_theme_color_override("font_pressed_color", ACCENT)
	item.add_theme_color_override("font_disabled_color", Color("778d98"))
	item.add_theme_stylebox_override("normal", _style(Color("19323e"), BORDER, 8, 13))
	item.add_theme_stylebox_override("hover", _style(Color("254651"), Color("7296a1"), 8, 13))
	item.add_theme_stylebox_override("pressed", _style(Color("21433f"), ACCENT, 8, 13))
	item.add_theme_stylebox_override("hover_pressed", _style(Color("2b514c"), ACCENT, 8, 13))
	item.add_theme_stylebox_override("disabled", _style(Color("18262e"), Color("2e434d"), 8, 13))
	var focus := _style(Color.TRANSPARENT, TEXT, 8, 0)
	focus.draw_center = false
	focus.set_border_width_all(2)
	item.add_theme_stylebox_override("focus", focus)
	parent.add_child(item)
	return item


static func _hits(item: Button, position: Vector2) -> bool:
	return item.is_visible_in_tree() and not item.disabled and item.get_global_rect().has_point(position)


static func _label(parent: Container, caption: String, size: int, color: Color) -> Label:
	var item := Label.new()
	item.text = caption
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	parent.add_child(item)
	return item


static func _style(fill: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
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
