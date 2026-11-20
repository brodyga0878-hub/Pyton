extends CanvasLayer

signal action_requested(action: String)

const MiningRig := preload("res://scripts/mining_rig.gd")
const Sector := preload("res://scripts/sector_catalog.gd")
const Patrol := preload("res://scripts/patrol_encounter.gd")
const INK := Color("eef8ff")
const MUTED := Color("a7bac9")
const CYAN := Color("8fe9db")
const AMBER := Color("ffd396")
const ALERT := Color("ff978c")
const ALLY := Color("90c6ff")
const BACK := Color(0.024, 0.057, 0.081, 0.94)
const LINE := Color(0.24, 0.43, 0.49, 0.58)
const COURSE_PAD := Rect2(26, -170, 172, 144)
const ROLL_PAD := Rect2(210, -108, 112, 82)
const ACTION_COLUMN := Rect2(-340, -215, 314, 189)
const TOUCH_GAINS := [0.72, 1.0, 1.36]

var _hud: Control
var _safe: Control
var _marks: FlightMarks
var _steer: SteeringPad
var _bank: SteeringPad
var _route: Label
var _route_detail: Label
var _telemetry: Label
var _condition: Label
var _fuel: Label
var _fuel_level: ProgressBar
var _clock: Label
var _time_hint: Label
var _guidance: Label
var _notice: Label
var _notice_panel: PanelContainer
var _commands_panel: PanelContainer
var _mining_progress: ProgressBar
var _right_panel: PanelContainer
var _throttle_controls: GridContainer
var _port_tools: HBoxContainer
var _actions: Dictionary = {}
var _touch_owner: Dictionary = {}
var _steer_finger := -1
var _bank_finger := -1
var _boost := false
var _brake := false
var _mouse_boost := false
var _mouse_brake := false
var _input_enabled := true
var _touch_gain := 1.0
var _touch_mirrored := false
var _parked := true
var _lift_blocked := false
var _mining_blocked := false
var _scoop_blocked := false
var _time_blocked := false
var _patrol_blocked := false
var _fire_blocked := false
var _jumping := false
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
	var course_card := route_stack.get_parent() as PanelContainer
	var shortcuts := HBoxContainer.new()
	shortcuts.add_theme_constant_override("separation", 8)
	_pin(shortcuts, _safe, Vector2.ZERO, Rect2(26, 131, 407, 48))
	_button(shortcuts, "journal", "Журнал")
	_button(shortcuts, "settings", "Настройки")
	_button(shortcuts, "frontier", "Освоение")
	for action: String in ["journal", "settings", "frontier"]:
		var button: Button = _actions[action]
		button.custom_minimum_size.y = 48.0
		button.add_theme_font_size_override("font_size", 16)
	_actions["journal"].tooltip_text = "Журнал заданий"
	_actions["settings"].tooltip_text = "Графика и управление"
	_actions["frontier"].tooltip_text = "Разведка, строительство и фракции"
	course_card.resized.connect(func() -> void:
		shortcuts.offset_top = course_card.position.y + course_card.size.y + 8.0
		shortcuts.offset_bottom = shortcuts.offset_top + 48.0
	)
	var instrument_stack := _panel(_safe, Vector2(1, 0), Rect2(-310, 24, 284, 159))
	instrument_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	_telemetry = _label(instrument_stack, 17, INK)
	_telemetry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_condition = _label(instrument_stack, 16, INK)
	_fuel = _label(instrument_stack, 16, CYAN)
	_fuel_level = ProgressBar.new()
	_fuel_level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fuel_level.step = 0.0
	_fuel_level.show_percentage = false
	_fuel_level.custom_minimum_size.y = 7.0
	_fuel_level.add_theme_stylebox_override("background", _box(Color("12313d"), LINE, 4, 0.0))
	_fuel_level.add_theme_stylebox_override("fill", _box(CYAN, CYAN, 4, 0.0))
	instrument_stack.add_child(_fuel_level)
	var clock_row := HBoxContainer.new()
	clock_row.add_theme_constant_override("separation", 8)
	instrument_stack.add_child(clock_row)
	_clock = _label(clock_row, 16, MUTED)
	_clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_button(clock_row, "time", "1×")
	var time_button: Button = _actions["time"]
	time_button.custom_minimum_size.x = 68.0
	time_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_time_hint = _label(instrument_stack, 15, AMBER)
	_time_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_time_hint.hide()

	_steer = SteeringPad.new()
	_steer.caption = "КУРС"
	_pin(_steer, _safe, Vector2(0, 1), COURSE_PAD)
	_bank = SteeringPad.new()
	_bank.caption = "КРЕН"
	_bank.horizontal = true
	_pin(_bank, _safe, Vector2(0, 1), ROLL_PAD)

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
	_button(commands, "scoop", "Сбор топлива")
	_button(commands, "contract", "Контракт")
	_button(commands, "mine", "Развернуть модуль")
	_button(commands, "sell_ore", "Продать сырьё")

	var right := _panel(_safe, Vector2(1, 1), ACTION_COLUMN)
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
	_button(utilities, "galaxy", "Галактика")
	_button(utilities, "report", "Отчёт")
	_port_tools = HBoxContainer.new()
	_port_tools.add_theme_constant_override("separation", 7)
	right.add_child(_port_tools)
	_button(_port_tools, "market", "Биржа")
	_button(_port_tools, "services", "Сервис")
	_button(_port_tools, "patrol", "Дозор")
	_button(_port_tools, "fire", "Огонь")
	var fire_button: Button = _actions["fire"]
	fire_button.size_flags_stretch_ratio = 1.35
	fire_button.add_theme_color_override("font_color", ALERT)
	fire_button.add_theme_stylebox_override("normal", _box(Color("482b32"), ALERT, 9, 7.0))
	fire_button.add_theme_stylebox_override("hover", _box(Color("633c45"), ALERT, 9, 7.0))
	fire_button.add_theme_stylebox_override("pressed", _box(Color("78505a"), ALERT, 9, 7.0))
	_actions["map"].tooltip_text = "Карта звёздной системы"
	_actions["galaxy"].tooltip_text = "Карта галактики"
	_actions["report"].tooltip_text = "Отчёт об ошибке"
	_actions["market"].tooltip_text = "Рынок и курьерские рейсы"

	var notice_stack := _panel(_safe, Vector2(0.5, 1), Rect2(-243, -199, 486, 46))
	_notice_panel = notice_stack.get_parent() as PanelContainer
	_notice = _label(notice_stack, 17, AMBER)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_panel.hide()
	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()
	_apply_touch_layout()

func sync(sim: RefCounted, delta: float) -> void:
	var docked: bool = sim.docked >= 0
	var landed: bool = sim.landed_site >= 0
	var parked := docked or landed
	var patrol: Dictionary = sim.patrol_status()
	if not _parked and parked:
		_reset_controls()
	_parked = parked
	_jumping = sim.jump_seconds_left > 0.0
	_steer.visible = not parked
	_bank.visible = not parked
	_throttle_controls.visible = not parked
	_actions["target"].visible = not parked
	_actions["autopilot"].visible = not parked
	_actions["services"].visible = docked
	_actions["market"].visible = docked
	var patrol_button: Button = _actions["patrol"]
	patrol_button.visible = not landed and not _jumping and bool(patrol.get("visible", false))
	patrol_button.text = str(patrol.get("caption", "Дозор"))
	patrol_button.tooltip_text = str(patrol.get("reason", ""))
	_patrol_blocked = not bool(patrol.get("available", false))
	var fire_button: Button = _actions["fire"]
	fire_button.visible = not parked and not _jumping and patrol.get("phase") == Patrol.ENGAGED and bool(patrol.get("same_system", false))
	var fire: Dictionary = sim.fire_status() if fire_button.visible else {}
	fire_button.tooltip_text = str(fire.get("reason", ""))
	_fire_blocked = not fire.get("ok", false)
	var encounter_tools := patrol_button.visible or fire_button.visible
	_port_tools.visible = docked or encounter_tools
	_right_panel.offset_top = -157.0 if docked else (-101.0 if landed else (-274.0 if encounter_tools else -215.0))
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
	var star_target: bool = sim.target == Sector.star_for(sim.system_id)
	_actions["dock"].visible = parked or not star_target
	_actions["dock"].text = "Швартовка" if Sector.is_port(sim.target) else "Посадка"
	_actions["dock"].tooltip_text = ""
	if parked:
		_actions["dock"].text = "Взлёт" if landed else "Старт"
		if _lift_blocked:
			_actions["dock"].tooltip_text = "Сначала верните модуль на борт"
	var scoop_status: Dictionary = {} if parked else sim.scoop_status()
	_scoop_blocked = not sim.scooping and not scoop_status.get("ok", false)
	_actions["scoop"].visible = not parked and (star_target or scoop_status.get("near", false) or sim.scooping)
	_actions["scoop"].text = "Откл. сбор" if sim.scooping else "Сбор топлива"
	_actions["autopilot"].text = "Выкл. авто" if sim.autopilot else "Авто"
	var itinerary: Dictionary = sim.contract_itinerary() if sim.contract_stage == 1 else {}
	var transfer: bool = not itinerary.is_empty() and int(itinerary.leg) + 1 < itinerary.stops.size()
	_actions["contract"].visible = docked and (sim.contract_stage != 1 or sim.docked == sim.contract_destination)
	_actions["contract"].text = "Отметить этап" if transfer else ("Сдать груз" if sim.contract_stage == 1 else "Взять контракт")
	var sale_quote: int = mining.sale_quote(sim.docked) if docked and mining.ore_hold > 0 else 0
	_actions["sell_ore"].visible = sale_quote > 0
	_sync_clock(sim)
	_refresh_disabled_actions()
	_sync_fuel(sim.ship)
	_sync_condition(sim.ship.hull, mining.ore_hold, mining.cargo_capacity)

	if landed:
		_sync_surface(sim, mining)
	elif docked:
		_sync_port(sim, sale_quote, itinerary, transfer)
		if sim.contract_stage != 1 and patrol.get("phase") in [Patrol.OUTBOUND, Patrol.RETURN] and patrol_button.visible:
			_guidance.text = str(patrol.get("reason", ""))
	else:
		_sync_flight(sim, scoop_status, itinerary, patrol, fire)
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_notice_panel.hide()

func _sync_fuel(ship: RefCounted) -> void:
	var capacity: float = ship.capacity()
	var empty: bool = ship.fuel <= 0.0
	_fuel.text = "Топливо %.1f / %.0f ед." % [ship.fuel, capacity]
	if empty:
		_fuel.text += " · резерв"
	var color := AMBER if empty else CYAN
	if _fuel.get_theme_color("font_color") != color:
		_fuel.add_theme_color_override("font_color", color)
	_fuel_level.max_value = capacity
	_fuel_level.value = ship.fuel

func _sync_condition(hull: float, cargo: int, capacity: int) -> void:
	_condition.text = "Корпус %d%% · Трюм %d / %d ед." % [roundi(hull), cargo, capacity]
	var color := AMBER if hull < 40.0 else INK
	if _condition.get_theme_color("font_color") != color:
		_condition.add_theme_color_override("font_color", color)

func _sync_clock(sim: RefCounted) -> void:
	var seconds := floori(sim.orbit_time + 0.000001)
	var hours := floori(seconds / 3600.0)
	var minutes := floori(seconds / 60.0) % 60
	_clock.text = "Время %02d:%02d:%02d" % [hours, minutes, seconds % 60]
	var status: Dictionary = sim.time_status()
	var scale: int = sim.time_scale
	var button: Button = _actions["time"]
	_time_blocked = not status.allowed and scale <= 1
	button.text = "%d×" % scale
	_time_hint.visible = not status.allowed
	_time_hint.text = "Ускорение недоступно. %s" % status.reason if _time_hint.visible else ""
	button.tooltip_text = _time_hint.text if _time_hint.visible else "Сменить скорость игрового времени (O)"

func _sync_port(sim: RefCounted, sale_quote: int, itinerary: Dictionary, transfer: bool) -> void:
	_route.text = "Порт  /  %s" % sim.target_name(sim.docked)
	if sim.contract_stage == 1:
		var destination: String = sim.target_name(sim.contract_destination)
		_route_detail.text = "%s → %s" % [sim.contract_cargo(), destination]
		if not itinerary.is_empty():
			_route_detail.text = "%s · %s\nСледующий порт — «%s»" % [_leg_label(itinerary), itinerary.title, destination]
		var remote_system := _delivery_system(sim)
		if not remote_system.is_empty():
			_guidance.text = "Следующая остановка в системе «%s». Проверьте курс на галактической карте." % remote_system
		else:
			_guidance.text = "Вылетите к месту доставки."
			if sim.docked == sim.contract_destination:
				_guidance.text = "Отметьте прибытие, чтобы продолжить рейс." if transfer else "Груз готов к сдаче."
	else:
		var destination: String = sim.target_name(sim.offer_destination())
		_route_detail.text = "%s → %s\nОплата %d кр." % [sim.contract_cargo(), destination, sim.contract_reward()]
		_guidance.text = "Выберите пункт назначения на карте."
	var ready_to_deliver: bool = sim.contract_stage == 1 and sim.docked == sim.contract_destination
	if sim.planned_target >= 0 and not ready_to_deliver:
		_guidance.text = "После старта курс на «%s»." % sim.target_name(sim.planned_target)
	if sale_quote > 0 and sim.contract_stage != 1:
		_guidance.text = "Сырьё можно продать за %d кр." % sale_quote
	_telemetry.text = "Баланс %d кр." % sim.credits

func _sync_surface(sim: RefCounted, mining: RefCounted) -> void:
	_route.text = "Поверхность  /  %s" % sim.target_name(sim.landed_site)
	var site := Sector.site(sim.landed_site)
	_route_detail.text = "%s · запас %d ед." % [Sector.resource_name(site.resource), mining.reserve_at(sim.landed_site)]
	if sim.planned_target >= 0:
		_route_detail.text += "\nПосле взлёта → %s" % sim.target_name(sim.planned_target)
	var landing_site := "Вне площадки" if sim.landed_offpad() else "Площадка"
	_telemetry.text = landing_site
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
			if mining.ore_hold >= mining.cargo_capacity:
				_guidance.text = "Трюм заполнен. Продайте груз в порту."
			elif mining.reserve == 0:
				_guidance.text = "Жила исчерпана."
			else:
				_guidance.text = "Разверните добывающий модуль."

func _sync_flight(sim: RefCounted, scoop_status: Dictionary, itinerary: Dictionary, patrol: Dictionary, fire: Dictionary) -> void:
	var project_course := bool(sim.get("project_course"))
	var aimed_at_port := Sector.is_port(sim.target) and fire.is_empty() and not bool(sim.patrol_course) and not project_course
	var surface: Dictionary = sim.surface_status() if Sector.is_mine_site(sim.target) else {}
	var near_surface: bool = surface.get("near", false)
	var to_target: Vector3 = sim.target_position(sim.target) - sim.position
	var meters := to_target.length()
	_route.text = "Курс  /  %s" % sim.target_name(sim.target)
	_route_detail.text = "%.0f м" % meters if meters < 1000.0 else "%.2f км" % (meters / 1000.0)
	var local_target: Vector3 = sim.attitude().transposed() * to_target
	if local_target.z > 0.0:
		_route_detail.text += "  ·  цель позади"
	if sim.contract_stage == 1:
		var delivery := "Груз для" if itinerary.is_empty() else _leg_label(itinerary)
		_route_detail.text += "\n%s · «%s»" % [delivery, sim.target_name(sim.contract_destination)]
		var remote_system := _delivery_system(sim)
		if not remote_system.is_empty():
			_route_detail.text += " (%s)" % remote_system
	var reference: int = sim.reference_site()
	var speed: float = sim.relative_speed() if reference >= 0 else sim.speed()
	var speed_text := ("%.1f" % speed).replace(".", ",") if near_surface else "%d" % roundi(speed)
	_telemetry.text = "Скорость %s м/с  ·  Тяга %d%%" % [speed_text, sim.throttle * 100.0]
	if reference >= 0:
		_telemetry.text += "\nОтносительно «%s»" % sim.target_name(reference)
	if aimed_at_port:
		_telemetry.text += "\nКрен к порту %+.0f°" % rad_to_deg(sim.roll_error(sim.target))
	elif near_surface:
		var altitude := ("%.1f" % maxf(0.0, float(surface.altitude))).replace(".", ",")
		_telemetry.text += "\nВысота %s м · уклон %.0f°" % [altitude, surface.slope]
		_actions["dock"].tooltip_text = str(surface.reason)
	if _jumping:
		_route.text = "Прыжок  /  %s" % Sector.system(sim.jump_target).name
		_route_detail.text = "До перехода %.1f с" % sim.jump_seconds_left
		_guidance.text = "Тормоз отменяет прыжок."
	elif not fire.is_empty():
		_route.text = "Дозор  /  Рейдер"
		_route_detail.text = "Дистанция %d м · корпус %d%%" % [roundi(fire.get("distance", 0.0)), ceili(patrol.get("enemy_hull", 0.0))]
		_guidance.text = "Цель в прицеле. Нажмите «Огонь»." if fire.ok else str(fire.get("reason", ""))
	elif patrol.get("phase") == Patrol.OUTBOUND and sim.patrol_course and patrol.get("same_system", false):
		_route.text = "Дозор  /  Сигнал"
		_route_detail.text = "До района сигнала %d м" % roundi(patrol.distance)
		_guidance.text = "Авто  /  К источнику сигнала"
	elif project_course:
		var project: Dictionary = sim.frontier_status()
		_route.text = "Освоение  /  %s" % ("Стройплощадка" if int(project.phase) == 3 else "Разведка")
		_route_detail.text = "До точки экспедиции %d м" % roundi(project.distance)
		_guidance.text = "Авто  /  К точке экспедиции"
	elif sim.scooping:
		_guidance.text = "Идёт сбор топлива. Удерживайте положение."
	elif scoop_status.get("near", false):
		_guidance.text = "Зона сбора. Включите сбор топлива." if scoop_status.get("ok", false) else str(scoop_status.get("reason", ""))
	elif sim.target == Sector.star_for(sim.system_id):
		_guidance.text = "Зона сбора %d–%d м от центра · до %d м/с." % [Sector.SCOOP_INNER, Sector.SCOOP_OUTER, Sector.SCOOP_SPEED]
		if sim.autopilot:
			_guidance.text = "Авто  /  %s\n%s" % [sim.autopilot_phase, _guidance.text]
	elif sim.autopilot:
		_guidance.text = "Авто  /  %s" % sim.autopilot_phase
	elif near_surface:
		if surface.ok:
			_guidance.text = "Можно сесть на площадку." if surface.pad else "Можно сесть вне площадки."
		else:
			_guidance.text = str(surface.reason)
	elif aimed_at_port and meters < 210.0:
		var status: Dictionary = sim.selected_dock_status()
		if status.get("ok", false):
			_guidance.text = "Порт готов к швартовке."
		else:
			_guidance.text = str(status.get("reason", ""))
	elif patrol.get("phase") in [Patrol.OUTBOUND, Patrol.RETURN] and _actions["patrol"].visible:
		_guidance.text = str(patrol.get("reason", ""))
	elif sim.ship.fuel <= 0.0:
		_guidance.text = "Резервная тяга. Заправьтесь в порту или у звезды."
	elif not surface.is_empty():
		_guidance.text = "Подойдите к поверхности вручную или включите «Авто» для захода на площадку."
	else:
		_guidance.text = "Курс и крен справа. Тяга и тормоз слева." if _touch_mirrored else "Курс и крен слева. Тяга и тормоз справа."

func _delivery_system(sim: RefCounted) -> String:
	var destination_system := Sector.system_of_site(sim.contract_destination)
	return "" if destination_system == sim.system_id else str(Sector.system(destination_system).name)

func _leg_label(itinerary: Dictionary) -> String:
	return "Этап %d/%d" % [int(itinerary.leg) + 1, itinerary.stops.size()]

func notify(message: String) -> void:
	_notice.text = message
	_notice_left = 4.0
	_notice_panel.show()

func set_target_marker(screen_position: Vector2, visible: bool) -> void:
	_marks.target_position = screen_position
	_marks.target_visible = visible
	_marks.queue_redraw()

func set_traffic_markers(markers: Array[Dictionary]) -> void:
	_marks.traffic = markers.duplicate()
	_marks.traffic.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_hostile: bool = left.role == "raider"
		var right_hostile: bool = right.role == "raider"
		return left_hostile if left_hostile != right_hostile else float(left.distance) < float(right.distance))
	_marks.queue_redraw()

func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	if not is_instance_valid(_hud):
		return
	if not enabled:
		_reset_controls()
	_refresh_disabled_actions()

func set_touch_preferences(sensitivity: int, mirrored: bool) -> void:
	_touch_gain = TOUCH_GAINS[clampi(sensitivity, 0, TOUCH_GAINS.size() - 1)]
	if _touch_mirrored == mirrored:
		return
	_touch_mirrored = mirrored
	if is_instance_valid(_hud):
		_reset_controls()
		_apply_touch_layout()

func _apply_touch_layout() -> void:
	_place_touch_control(_steer, COURSE_PAD, false)
	_place_touch_control(_bank, ROLL_PAD, false)
	_place_touch_control(_right_panel, ACTION_COLUMN, true)

func _place_touch_control(control: Control, placement: Rect2, starts_right: bool) -> void:
	var anchor := 1.0 if starts_right != _touch_mirrored else 0.0
	control.anchor_left = anchor
	control.anchor_right = anchor
	control.offset_left = -placement.end.x if _touch_mirrored else placement.position.x
	control.offset_right = -placement.position.x if _touch_mirrored else placement.end.x

func _refresh_disabled_actions() -> void:
	for action: String in _actions:
		var button: Button = _actions[action]
		var blocked := (action == "dock" and _lift_blocked) or (action == "mine" and _mining_blocked) or (action == "scoop" and _scoop_blocked) or (action == "time" and _time_blocked)
		blocked = blocked or (action == "patrol" and _patrol_blocked) or (action == "fire" and _fire_blocked)
		var during_jump := _jumping and action not in ["throttle_down", "throttle_up", "boost", "brake"]
		button.disabled = not _input_enabled or blocked or during_jump

func move_input() -> Vector2:
	if _parked or not _input_enabled:
		return Vector2.ZERO
	var horizontal := float(_key(KEY_D, KEY_RIGHT)) - float(_key(KEY_A, KEY_LEFT))
	var vertical := float(_key(KEY_W, KEY_UP)) - float(_key(KEY_S, KEY_DOWN))
	return (_steer.axis * _touch_gain + Vector2(horizontal, vertical)).limit_length()

func roll_input() -> float:
	if _parked or not _input_enabled:
		return 0.0
	var keyboard := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	return clampf(_bank.axis.x * _touch_gain + keyboard, -1.0, 1.0)

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
	button.add_theme_color_override("font_color", CYAN if action in ["dock", "scoop", "contract", "mine", "sell_ore", "map", "galaxy", "market", "services", "time", "patrol"] else INK)
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
	const MAX_CONTACTS := 3

	var flight := false
	var target_visible := false
	var target_position := Vector2.ZERO
	var traffic: Array[Dictionary] = []

	func _draw() -> void:
		if not flight:
			return
		var center := size * 0.5
		for direction: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
			draw_line(center + direction * 13.0, center + direction * 23.0, Color(0.57, 0.92, 0.9, 0.65), 1.5, true)
		_draw_traffic()
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

	func _draw_traffic() -> void:
		var safe := Rect2(Vector2(24, 142), (size - Vector2(48, 285)).max(Vector2.ONE))
		var font := ThemeDB.fallback_font
		var occupied: Array[Rect2] = []
		for contact: Dictionary in traffic:
			var screen: Vector2 = contact.screen
			if not safe.has_point(screen):
				continue
			var hostile: bool = contact.role == "raider"
			var color := ALERT if hostile else (ALLY if contact.role == "patrol" else CYAN)
			var caption := "%s · %d м" % [contact.name, roundi(contact.distance)]
			var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			var text_at := Vector2(clampf(screen.x - width * 0.5, 20.0, maxf(20.0, size.x - width - 20.0)), screen.y + 27.0)
			var label_box := Rect2(text_at - Vector2(6, 15), Vector2(width + 12, 21))
			var footprint := label_box.merge(Rect2(screen - Vector2(12, 12), Vector2(24, 24)))
			if occupied.any(func(box: Rect2) -> bool: return box.intersects(footprint)):
				continue
			occupied.append(footprint)
			if hostile:
				var diamond := PackedVector2Array([
					screen + Vector2(0, -11), screen + Vector2(9, 0), screen + Vector2(0, 11),
					screen + Vector2(-9, 0), screen + Vector2(0, -11),
				])
				draw_polyline(diamond, color, 1.7, true)
			elif contact.role == "patrol":
				draw_rect(Rect2(screen - Vector2(7, 7), Vector2(14, 14)), color, false, 1.4)
			else:
				draw_arc(screen, 7.0, 0.0, TAU, 20, color, 1.4, true)
			draw_rect(label_box, BACK)
			draw_string(font, text_at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
			if occupied.size() >= MAX_CONTACTS:
				break
