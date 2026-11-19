extends CanvasLayer

signal action_requested(action: String)

const INK := Color("eef8ff")
const MUTED := Color("a7bac9")
const CYAN := Color("8fe9db")
const AMBER := Color("ffd396")
const BACK := Color(0.024, 0.057, 0.081, 0.94)
const LINE := Color(0.24, 0.43, 0.49, 0.58)

var _hud: Control
var _safe: Control
var _marks: FlightMarks
var _steer: SteeringPad
var _bank: SteeringPad
var _route: Label
var _route_detail: Label
var _telemetry: Label
var _guidance: Label
var _notice: Label
var _right_panel: PanelContainer
var _throttle_controls: GridContainer
var _actions: Dictionary = {}
var _touch_owner: Dictionary = {}
var _steer_finger := -1
var _bank_finger := -1
var _boost := false
var _brake := false
var _mouse_boost := false
var _mouse_brake := false
var _input_enabled := true
var _docked := true
var _notice_left := 0.0
var _mouse_pad: SteeringPad

func build() -> void:
	if is_instance_valid(_hud):
		return
	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marks = FlightMarks.new()
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_marks)
	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_safe = Control.new()
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_safe)
	_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var route_stack := _panel(_safe, Vector2.ZERO, Rect2(26, 24, 407, 99))
	_route = _label(route_stack, 23, CYAN)
	_route_detail = _label(route_stack, 17, INK)
	_route_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var instrument_stack := _panel(_safe, Vector2(1, 0), Rect2(-310, 24, 284, 99))
	instrument_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	_telemetry = _label(instrument_stack, 17, INK)

	_steer = SteeringPad.new()
	_steer.caption = "КУРС"
	_pin(_steer, _safe, Vector2(0, 1), Rect2(26, -170, 172, 144))
	_bank = SteeringPad.new()
	_bank.caption = "КРЕН"
	_bank.horizontal = true
	_pin(_bank, _safe, Vector2(0, 1), Rect2(210, -108, 112, 82))

	var center := _panel(_safe, Vector2(0.5, 1), Rect2(-258, -143, 503, 117))
	_guidance = _label(center, 17, INK)
	_guidance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guidance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guidance.custom_minimum_size.y = 38
	var commands := HBoxContainer.new()
	commands.add_theme_constant_override("separation", 7)
	center.add_child(commands)
	_button(commands, "target", "Цель")
	_button(commands, "autopilot", "Авто")
	_button(commands, "dock", "Старт")
	_button(commands, "contract", "Контракт")

	var right := _panel(_safe, Vector2(1, 1), Rect2(-340, -215, 314, 189))
	_right_panel = right.get_parent() as PanelContainer
	_throttle_controls = GridContainer.new()
	_throttle_controls.columns = 2
	_throttle_controls.add_theme_constant_override("h_separation", 7)
	_throttle_controls.add_theme_constant_override("v_separation", 7)
	right.add_child(_throttle_controls)
	_button(_throttle_controls, "throttle_down", "Тяга −")
	_button(_throttle_controls, "throttle_up", "Тяга +")
	_button(_throttle_controls, "brake", "Тормоз")
	_button(_throttle_controls, "boost", "Форсаж")
	_button(right, "report", "Отчёт об ошибке")

	var notice_stack := _panel(_safe, Vector2(0.5, 0.8), Rect2(-243, -49, 486, 46))
	_notice = _label(notice_stack, 17, AMBER)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.get_parent().get_parent().hide()
	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()

func sync(sim: RefCounted, delta: float) -> void:
	if not _docked and sim.docked >= 0:
		_reset_controls()
	_docked = sim.docked >= 0
	_steer.visible = not _docked
	_bank.visible = not _docked
	_throttle_controls.visible = not _docked
	_right_panel.offset_top = -101.0 if _docked else -215.0
	_actions["target"].visible = not _docked
	_actions["autopilot"].visible = not _docked
	_marks.flight = not _docked
	_marks.queue_redraw()
	var target_name: String = sim.station_names[sim.target]
	var meters: float = sim.position.distance_to(sim.station_positions[sim.target])
	var contract_here: bool = sim.contract_stage != 1 or sim.docked == sim.contract_destination
	_actions["contract"].visible = _docked and contract_here
	if sim.contract_stage == 1:
		_actions["contract"].text = "Сдать груз"
	else:
		_actions["contract"].text = "Взять контракт"
	_actions["dock"].text = "Старт" if _docked else "Швартовка"
	_actions["autopilot"].text = "Выкл. авто" if sim.autopilot else "Авто"
	if _docked:
		_route.text = "Порт  /  %s" % sim.station_names[sim.docked]
		if sim.contract_stage == 1:
			var destination_name: String = sim.station_names[sim.contract_destination]
			_route_detail.text = "%s → %s" % [sim.contract_cargo(), destination_name]
			_guidance.text = "Груз готов к сдаче." if contract_here else "Вылетите к месту доставки."
		else:
			var offer_name: String = sim.station_names[sim.offer_destination()]
			_route_detail.text = "%s → %s\nОплата %d кр." % [sim.contract_cargo(), offer_name, sim.contract_reward()]
			_guidance.text = "Выберите контракт или отправляйтесь в свободный полёт."
		_telemetry.text = "Швартовка выполнена\nБаланс %d кр." % sim.credits
	else:
		_route.text = "Курс  /  %s" % target_name
		var distance := "%.0f м" % meters if meters < 1000.0 else "%.2f км" % (meters / 1000.0)
		_route_detail.text = distance
		var local_target: Vector3 = sim.attitude().transposed() * (sim.station_positions[sim.target] - sim.position)
		if local_target.z > 0.0:
			_route_detail.text += "  ·  цель позади"
		if sim.contract_stage == 1:
			_route_detail.text += "  ·  Груз для «%s»" % sim.station_names[sim.contract_destination]
		_telemetry.text = "Скорость %.0f м/с  ·  Тяга %d%%\nКрен к порту %+.0f°" % [sim.velocity.length(), sim.throttle * 100.0, rad_to_deg(sim.roll_error(sim.target))]
		var status: Dictionary = sim.selected_dock_status()
		if sim.autopilot:
			_guidance.text = "Авто  /  %s" % sim.autopilot_phase
		elif meters < 210.0:
			_guidance.text = "Порт готов к швартовке." if status.get("ok", false) else str(status.get("reason", ""))
		else:
			_guidance.text = "Курс и крен слева. Тяга и тормоз справа."
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_notice.get_parent().get_parent().hide()

func notify(message: String) -> void:
	_notice.text = message
	_notice_left = 4.0
	_notice.get_parent().get_parent().show()

func set_target_marker(screen_position: Vector2, visible: bool) -> void:
	_marks.target_position = screen_position
	_marks.target_visible = visible
	_marks.queue_redraw()

func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	if not is_instance_valid(_hud):
		return
	if not enabled:
		_reset_controls()
	for button: Button in _actions.values():
		button.disabled = not enabled

func move_input() -> Vector2:
	if _docked or not _input_enabled:
		return Vector2.ZERO
	var horizontal := float(_key(KEY_D, KEY_RIGHT)) - float(_key(KEY_A, KEY_LEFT))
	var vertical := float(_key(KEY_W, KEY_UP)) - float(_key(KEY_S, KEY_DOWN))
	return (_steer.axis + Vector2(horizontal, vertical)).limit_length()

func roll_input() -> float:
	if _docked or not _input_enabled:
		return 0.0
	return clampf(_bank.axis.x + float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)), -1.0, 1.0)

func boost_held() -> bool:
	return not _docked and _input_enabled and (_boost or Input.is_physical_key_pressed(KEY_SHIFT))

func brake_held() -> bool:
	return not _docked and _input_enabled and (_brake or Input.is_physical_key_pressed(KEY_SPACE))

func _key(primary: Key, alternate: Key) -> bool:
	return Input.is_physical_key_pressed(primary) or Input.is_physical_key_pressed(alternate)

func _update_safe_area() -> void:
	if OS.get_name() != "Android":
		return
	var safe_area := DisplayServer.get_display_safe_area()
	var window_size := Vector2(DisplayServer.window_get_size())
	if safe_area.size.x <= 0 or safe_area.size.y <= 0 or window_size.x <= 0 or window_size.y <= 0:
		return
	var scale := get_viewport().get_visible_rect().size / window_size
	_safe.offset_left = maxf(0.0, safe_area.position.x * scale.x)
	_safe.offset_top = maxf(0.0, safe_area.position.y * scale.y)
	_safe.offset_right = minf(0.0, (safe_area.end.x - window_size.x) * scale.x)
	_safe.offset_bottom = minf(0.0, (safe_area.end.y - window_size.y) * scale.y)

func _input(event: InputEvent) -> void:
	if not is_instance_valid(_hud) or not _input_enabled:
		return
	# Gameplay uses ScreenTouch directly. Report overlays can still use the
	# platform mouse emulation while these controls are disabled.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var handled := _touch_begin(event.index, event.position) if event.pressed else _touch_end(event.index, event.position, event.canceled)
		if handled:
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _touch_owner.has(event.index):
		if event.index == _steer_finger:
			_steer.update_point(event.position)
		elif event.index == _bank_finger:
			_bank.update_point(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _hit(_steer, event.position):
				_mouse_pad = _steer
			elif _hit(_bank, event.position):
				_mouse_pad = _bank
			if is_instance_valid(_mouse_pad):
				_mouse_pad.update_point(event.position)
				get_viewport().set_input_as_handled()
		elif is_instance_valid(_mouse_pad):
			_mouse_pad.reset()
			_mouse_pad = null
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and is_instance_valid(_mouse_pad):
		_mouse_pad.update_point(event.position)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(_hud):
		_reset_controls()

func _reset_controls() -> void:
	_touch_owner.clear()
	_steer_finger = -1
	_bank_finger = -1
	_mouse_pad = null
	_mouse_boost = false
	_mouse_brake = false
	_steer.reset()
	_bank.reset()
	_update_held()

func _touch_begin(index: int, point: Vector2) -> bool:
	if _touch_owner.has(index):
		return true
	if _hit(_steer, point) and _steer_finger == -1:
		_steer_finger = index
		_touch_owner[index] = "steer"
		_steer.update_point(point)
		return true
	if _hit(_bank, point) and _bank_finger == -1:
		_bank_finger = index
		_touch_owner[index] = "bank"
		_bank.update_point(point)
		return true
	for action: String in _actions:
		var button: Button = _actions[action]
		if not button.disabled and _hit(button, point):
			_touch_owner[index] = action
			if action == "boost" or action == "brake":
				_update_held()
			else:
				button.self_modulate = CYAN
			return true
	return false

func _touch_end(index: int, point: Vector2, canceled: bool) -> bool:
	if not _touch_owner.has(index):
		return false
	var action: String = _touch_owner[index]
	_touch_owner.erase(index)
	match action:
		"steer":
			_steer_finger = -1
			_steer.reset()
		"bank":
			_bank_finger = -1
			_bank.reset()
		"boost", "brake":
			_update_held()
		_:
			var button: Button = _actions[action]
			if not _touch_owner.values().has(action):
				button.self_modulate = Color.WHITE
			if not canceled and not button.disabled and _hit(button, point):
				action_requested.emit(action)
	return true

func _update_held() -> void:
	_boost = _touch_owner.values().has("boost") or _mouse_boost
	_brake = _touch_owner.values().has("brake") or _mouse_brake
	_actions["boost"].self_modulate = CYAN if _boost else Color.WHITE
	_actions["brake"].self_modulate = AMBER if _brake else Color.WHITE

func _set_mouse_hold(action: String, active: bool) -> void:
	if action == "boost":
		_mouse_boost = active
	else:
		_mouse_brake = active
	_update_held()

func _hit(control: Control, point: Vector2) -> bool:
	return control.is_visible_in_tree() and control.get_global_rect().has_point(point)

func _pin(control: Control, parent: Control, anchor: Vector2, rect: Rect2) -> void:
	parent.add_child(control)
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y

func _box(color: Color, border: Color, radius: int, padding: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, padding)
	return box

func _panel(parent: Control, anchor: Vector2, rect: Rect2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box(BACK, LINE, 13, 10.0))
	_pin(panel, parent, anchor, rect)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 5)
	panel.add_child(stack)
	return stack

func _label(container: Container, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	container.add_child(label)
	return label

func _button(parent: Container, action: String, caption: String) -> void:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 52)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", CYAN if action in ["dock", "contract"] else INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_stylebox_override("normal", _box(Color("12313d"), LINE, 9, 7.0))
	button.add_theme_stylebox_override("hover", _box(Color("214454"), CYAN, 9, 7.0))
	button.add_theme_stylebox_override("pressed", _box(Color("2c5a65"), CYAN, 9, 7.0))
	parent.add_child(button)
	_actions[action] = button
	if action in ["boost", "brake"]:
		button.button_down.connect(func() -> void: _set_mouse_hold(action, true))
		button.button_up.connect(func() -> void: _set_mouse_hold(action, false))
	else:
		button.pressed.connect(func() -> void: action_requested.emit(action))

class SteeringPad extends Control:
	var caption := ""
	var horizontal := false
	var axis := Vector2.ZERO

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func update_point(point: Vector2) -> void:
		var center := get_global_rect().get_center() - Vector2(0, 9)
		var radius := Vector2(size.x * 0.32, size.y * 0.34)
		var local := (point - center) / radius
		axis = Vector2(clampf(local.x, -1.0, 1.0), 0.0) if horizontal else Vector2(local.x, -local.y).limit_length()
		queue_redraw()

	func reset() -> void:
		axis = Vector2.ZERO
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5 - Vector2(0, 9)
		var radius := minf(size.x, size.y) * 0.34
		var color := Color(0.56, 0.91, 0.86, 0.64)
		if horizontal:
			var rect := Rect2(center - Vector2(size.x * 0.39, 17), Vector2(size.x * 0.78, 34))
			draw_rect(rect, Color(0.024, 0.057, 0.081, 0.86))
			draw_rect(rect, color, false, 1.0)
			draw_line(rect.position + Vector2(7, 17), rect.end - Vector2(7, 17), color, 1.0, true)
		else:
			draw_circle(center, radius + 9, Color(0.024, 0.057, 0.081, 0.8))
			draw_arc(center, radius + 9, 0, TAU, 48, color, 1.5, true)
			draw_arc(center, radius - 6, 0, TAU, 48, Color(0.56, 0.91, 0.86, 0.26), 1.0, true)
			for angle: float in [0.0, PI / 2.0, PI, PI * 1.5]:
				var direction := Vector2.from_angle(angle)
				draw_line(center + direction * (radius - 2), center + direction * (radius + 6), color, 2.0, true)
		var knob := center + Vector2(axis.x * size.x * 0.32, -axis.y * radius * 0.78)
		draw_circle(knob, 12.0 if horizontal else 16.0, Color("23505c"))
		draw_arc(knob, 12.0 if horizontal else 16.0, 0, TAU, 28, CYAN, 2.0, true)
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, Vector2((size.x - width) * 0.5, size.y - 4), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)

class FlightMarks extends Control:
	var flight := false
	var target_visible := false
	var target_position := Vector2.ZERO

	func _draw() -> void:
		if not flight:
			return
		var center := size * 0.5
		for direction: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
			draw_line(center + direction * 13.0, center + direction * 23.0, Color(0.57, 0.92, 0.9, 0.65), 1.5, true)
		if not target_visible:
			return
		var margin := Vector2(42, 112)
		var target := target_position.clamp(margin, size - margin - Vector2(0, 86))
		if target != target_position:
			var direction := (target_position - center).normalized()
			var side := direction.orthogonal()
			var arrow := PackedVector2Array([target + direction * 13.0, target - direction * 8.0 + side * 7.0, target - direction * 8.0 - side * 7.0])
			draw_colored_polygon(arrow, AMBER)
			return
		var distance := 10.0
		var vertices := PackedVector2Array([target + Vector2(0, -distance), target + Vector2(distance, 0), target + Vector2(0, distance), target + Vector2(-distance, 0), target + Vector2(0, -distance)])
		draw_polyline(vertices, AMBER, 2.0, true)
