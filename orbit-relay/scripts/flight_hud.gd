extends CanvasLayer

signal action_requested(action: String)

const MiningRig := preload("res://scripts/mining_rig.gd")
const Sector := preload("res://scripts/sector_catalog.gd")
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
var _notice_panel: PanelContainer
var _commands_panel: PanelContainer
var _mining_progress: ProgressBar
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
var _parked := true
var _lift_blocked := false
var _mining_blocked := false
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
	_commands_panel = center.get_parent() as PanelContainer
	_guidance = _label(center, 17, INK)
	_guidance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guidance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guidance.custom_minimum_size.y = 38
	_mining_progress = ProgressBar.new()
	_mining_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mining_progress.max_value = 1.0
	_mining_progress.step = 0.0
	_mining_progress.show_percentage = false
	_mining_progress.custom_minimum_size.y = 9.0
	_mining_progress.add_theme_stylebox_override("background", _box(Color("12313d"), LINE, 5, 0.0))
	_mining_progress.add_theme_stylebox_override("fill", _box(AMBER, AMBER, 5, 0.0))
	center.add_child(_mining_progress)
	_mining_progress.hide()
	var commands := HBoxContainer.new()
	commands.add_theme_constant_override("separation", 7)
	center.add_child(commands)
	_button(commands, "target", "Цель")
	_button(commands, "autopilot", "Авто")
	_button(commands, "dock", "Старт")
	_button(commands, "contract", "Контракт")
	_button(commands, "mine", "Развернуть модуль")
	_button(commands, "sell_ore", "Продать сырьё")

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
	var utilities := HBoxContainer.new()
	utilities.add_theme_constant_override("separation", 7)
	right.add_child(utilities)
	_button(utilities, "map", "Карта")
	_button(utilities, "report", "Отчёт")
	_actions["report"].tooltip_text = "Отчёт об ошибке"

	var notice_stack := _panel(_safe, Vector2(0.5, 1), Rect2(-243, -199, 486, 46))
	_notice_panel = notice_stack.get_parent() as PanelContainer
	_notice = _label(notice_stack, 17, AMBER)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_panel.hide()
	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()

func sync(sim: RefCounted, delta: float) -> void:
	var docked: bool = sim.docked >= 0
	var landed: bool = sim.landed_site >= 0
	var parked := docked or landed
	if not _parked and parked:
		_reset_controls()
	_parked = parked
	_steer.visible = not parked
	_bank.visible = not parked
	_throttle_controls.visible = not parked
	_right_panel.offset_left = -277.0 if parked else -340.0
	_right_panel.offset_top = -101.0 if parked else -215.0
	_actions["target"].visible = not parked
	_actions["autopilot"].visible = not parked
	_marks.flight = not parked
	_marks.queue_redraw()

	var mining: RefCounted = sim.mining
	var drilling: bool = landed and mining.phase in [MiningRig.DEPLOYING, MiningRig.DRILLING, MiningRig.RETURNING]
	_mining_progress.visible = drilling
	if drilling:
		_mining_progress.value = mining.progress()
	_commands_panel.offset_top = -160.0 if drilling else -143.0
	_notice_panel.offset_top = -215.0 if drilling else -199.0
	_notice_panel.offset_bottom = -169.0 if drilling else -153.0
	_lift_blocked = landed and mining.phase != MiningRig.STOWED
	_mining_blocked = landed and mining.phase != MiningRig.READY and not mining.available_to_deploy()
	_actions["mine"].visible = landed
	match mining.phase:
		MiningRig.READY:
			_actions["mine"].text = "Забрать модуль"
		MiningRig.DEPLOYING, MiningRig.DRILLING:
			_actions["mine"].text = "Модуль в работе"
		MiningRig.RETURNING:
			_actions["mine"].text = "Подъём модуля"
		_:
			_actions["mine"].text = "Развернуть модуль"
	_actions["dock"].text = "Швартовка" if Sector.is_port(sim.target) else "Посадка"
	if parked:
		_actions["dock"].text = "Взлёт" if landed else "Старт"
	_actions["autopilot"].text = "Выкл. авто" if sim.autopilot else "Авто"
	_actions["contract"].visible = docked and (sim.contract_stage != 1 or sim.docked == sim.contract_destination)
	_actions["contract"].text = "Сдать груз" if sim.contract_stage == 1 else "Взять контракт"
	var sale_quote: int = mining.sale_quote(sim.docked) if docked and mining.ore_hold > 0 else 0
	_actions["sell_ore"].visible = sale_quote > 0
	_refresh_disabled_actions()

	if landed:
		_sync_surface(sim, mining)
	elif docked:
		_sync_port(sim, mining.ore_hold, sale_quote)
	else:
		_sync_flight(sim, mining.ore_hold)
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_notice_panel.hide()

func _sync_port(sim: RefCounted, cargo: int, sale_quote: int) -> void:
	_route.text = "Порт  /  %s" % sim.target_name(sim.docked)
	if sim.contract_stage == 1:
		var destination: String = sim.target_name(sim.contract_destination)
		_route_detail.text = "%s → %s" % [sim.contract_cargo(), destination]
		_guidance.text = "Груз готов к сдаче." if sim.docked == sim.contract_destination else "Вылетите к месту доставки."
	else:
		var destination: String = sim.target_name(sim.offer_destination())
		_route_detail.text = "%s → %s\nОплата %d кр." % [sim.contract_cargo(), destination, sim.contract_reward()]
		_guidance.text = "Выберите пункт назначения на карте."
	if sim.planned_target >= 0:
		_guidance.text = "После старта курс на «%s»." % sim.target_name(sim.planned_target)
	if sale_quote > 0:
		_guidance.text = "Сырьё можно продать за %d кр." % sale_quote
	_telemetry.text = "Баланс %d кр.\nТрюм %d / %d ед." % [sim.credits, cargo, MiningRig.CAPACITY]

func _sync_surface(sim: RefCounted, mining: RefCounted) -> void:
	_route.text = "Поверхность  /  %s" % sim.target_name(sim.landed_site)
	var site := Sector.site(sim.landed_site)
	_route_detail.text = "%s · запас %d ед." % [Sector.resource_name(site.resource), mining.reserve_at(sim.landed_site)]
	if sim.planned_target >= 0:
		_route_detail.text += "\nПосле взлёта → %s" % sim.target_name(sim.planned_target)
	_telemetry.text = "Посадка выполнена\nТрюм %d / %d ед." % [mining.ore_hold, MiningRig.CAPACITY]
	match mining.phase:
		MiningRig.DEPLOYING:
			_guidance.text = "Модуль спускается на поверхность."
		MiningRig.DRILLING:
			_guidance.text = "Модуль добывает сырьё."
		MiningRig.READY:
			_guidance.text = "Добыто %d ед. Заберите модуль перед взлётом." % mining.pending_ore
		MiningRig.RETURNING:
			_guidance.text = "Модуль возвращается на борт."
		_:
			if mining.ore_hold >= MiningRig.CAPACITY:
				_guidance.text = "Трюм заполнен. Продайте сырьё в порту."
			elif mining.reserve == 0:
				_guidance.text = "Жила исчерпана."
			else:
				_guidance.text = "Разверните добывающий модуль."

func _sync_flight(sim: RefCounted, cargo: int) -> void:
	var aimed_at_port := Sector.is_port(sim.target)
	var to_target: Vector3 = sim.target_position(sim.target) - sim.position
	var meters := to_target.length()
	_route.text = "Курс  /  %s" % sim.target_name(sim.target)
	_route_detail.text = "%.0f м" % meters if meters < 1000.0 else "%.2f км" % (meters / 1000.0)
	var local_target: Vector3 = sim.attitude().transposed() * to_target
	if local_target.z > 0.0:
		_route_detail.text += "  ·  цель позади"
	if sim.contract_stage == 1:
		_route_detail.text += "  ·  Груз для «%s»" % sim.target_name(sim.contract_destination)
	_telemetry.text = "Скорость %.0f м/с  ·  Тяга %d%%" % [sim.velocity.length(), sim.throttle * 100.0]
	if aimed_at_port:
		_telemetry.text += "\nКрен к порту %+.0f°" % rad_to_deg(sim.roll_error(sim.target))
	else:
		_telemetry.text += "\nТрюм %d / %d ед." % [cargo, MiningRig.CAPACITY]
	if sim.autopilot:
		_guidance.text = "Авто  /  %s" % sim.autopilot_phase
	elif meters < 210.0:
		var status: Dictionary = sim.selected_dock_status()
		if status.get("ok", false):
			_guidance.text = "Порт готов к швартовке." if aimed_at_port else "Можно садиться."
		else:
			_guidance.text = str(status.get("reason", ""))
	else:
		_guidance.text = "Курс и крен слева. Тяга и тормоз справа."

func notify(message: String) -> void:
	_notice.text = message
	_notice_left = 4.0
	_notice_panel.show()

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
	_refresh_disabled_actions()

func _refresh_disabled_actions() -> void:
	for action: String in _actions:
		var button: Button = _actions[action]
		var blocked := (action == "dock" and _lift_blocked) or (action == "mine" and _mining_blocked)
		button.disabled = not _input_enabled or blocked

func move_input() -> Vector2:
	if _parked or not _input_enabled:
		return Vector2.ZERO
	var horizontal := float(_key(KEY_D, KEY_RIGHT)) - float(_key(KEY_A, KEY_LEFT))
	var vertical := float(_key(KEY_W, KEY_UP)) - float(_key(KEY_S, KEY_DOWN))
	return (_steer.axis + Vector2(horizontal, vertical)).limit_length()

func roll_input() -> float:
	if _parked or not _input_enabled:
		return 0.0
	return clampf(_bank.axis.x + float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)), -1.0, 1.0)

func boost_held() -> bool:
	return not _parked and _input_enabled and (_boost or Input.is_physical_key_pressed(KEY_SHIFT))

func brake_held() -> bool:
	return not _parked and _input_enabled and (_brake or Input.is_physical_key_pressed(KEY_SPACE))

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
	# Gameplay uses ScreenTouch directly.
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
	for button: Button in _actions.values():
		button.self_modulate = Color.WHITE
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
	button.add_theme_color_override("font_color", CYAN if action in ["dock", "contract", "mine", "sell_ore", "map"] else INK)
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
