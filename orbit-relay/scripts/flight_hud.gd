extends CanvasLayer

signal action_requested(action: String)
signal frame_requested()
signal navigation_requested(site: int, from_view: bool)
signal combat_target_requested(id: String)

const MiningRig := preload("res://scripts/mining_rig.gd")
const Sector := preload("res://scripts/sector_catalog.gd")
const Ground := preload("res://scripts/ground_port.gd")
const Patrol := preload("res://scripts/patrol_encounter.gd")
const MissionCalendar := preload("res://scripts/mission_calendar.gd")
const FlightCamera := preload("res://scripts/flight_camera.gd")
const Text := preload("res://scripts/flight_text.gd")
const FlightScanner := preload("res://scripts/flight_scanner_view.gd")
const INK := Color("eef8ff")
const MUTED := Color("b2c8d3")
const CYAN := Color("8fe9db")
const AMBER := Color("ffd396")
const ALERT := Color("ff978c")
const ALLY := Color("90c6ff")
const CONVOY := Color("ffd081")
const BACK := Color(0.024, 0.051, 0.073, 0.96)
const LINE := Color(0.27, 0.45, 0.52, 0.72)
const COURSE_CARD := Rect2(26, 24, 407, 99)
const SHORTCUT_BAR := Rect2(26, 131, 502, 48)
const HUD_GAP := 8.0
const COURSE_PAD := Rect2(26, -170, 172, 144)
const ROLL_PAD := Rect2(210, -108, 112, 82)
const CAMERA_CONTROL := Rect2(210, -171, 112, 52)
const FLIGHT_MODE_ROW := Rect2(26, -224, 350, 46)
const TRANSLATION_ROW := Rect2(26, -279, 296, 46)
const ACTION_COLUMN := Rect2(-340, -215, 314, 189)
const TOUCH_GAINS := [0.72, 1.0, 1.36]
const CONTACT_NOTICE_DISTANCE := 1100.0
const HOLD_ACTIONS := ["boost", "brake", "translation_forward", "translation_reverse", "fire"]
const MARK_PRIORITY := {"raider": 0, "convoy": 1}
const NAV_DRAG_THRESHOLD := 12.0
const NAV_MOUSE := -2
const RIG_ACTIONS := {
	"rig_deploy": "can_deploy", "rig_unload": "can_unload",
	"rig_retrieve": "can_retrieve", "rig_route": "can_route",
}
const ORBITAL_MINING_ACTIONS := {"mining_pulse": "fire_ok", "fragment_collect": "collect_ok"}
const PROCESSOR_ACTIONS := {
	"processor_deploy": "can_deploy", "processor_feed": "can_feed", "processor_unload": "can_unload",
	"processor_retrieve": "can_retrieve", "processor_route": "can_route"}

var _hud: Control
var _safe: Control
var _marks: FlightMarks
var _steer: SteeringPad
var _bank: SteeringPad
var _flight_modes: HBoxContainer
var _camera_controls: HBoxContainer
var _camera_instrument: Label
var _translation_controls: HBoxContainer
var _course_card: PanelContainer
var _shortcuts: GridContainer
var _route: Label
var _route_detail: Label
var _passenger_route: Label
var _ambient_alert: Label
var _rig_readout: HBoxContainer
var _rig_summary: Label
var _rig_status: Dictionary = {}
var _orbital_mining_readout: Label
var _orbital_mining_tools: HBoxContainer
var _orbital_mining_status: Dictionary = {}
var _processor_status: Dictionary = {}
var _processor_readout: HBoxContainer
var _processor_summary: Label
var _motion_readout: HBoxContainer
var _speed_caption: Label
var _speed_value: Label
var _thrust_caption: Label
var _thrust_value: Label
var _telemetry: Label
var _condition: Label
var _drive_tank_caption: Label
var _fuel: Label
var _fuel_level: ProgressBar
var _fuel_fill: StyleBoxFlat
var _jump_tank_caption: Label
var _jump_fuel: Label
var _jump_fuel_level: ProgressBar
var _jump_fuel_fill: StyleBoxFlat
var _pump_mode: Label
var _combat_readout: VBoxContainer
var _ordnance_tools: HBoxContainer
var _missile_blocked := true
var _missile_next_blocked := true
var _decoy_blocked := true
var _pulse_blocked := true
var _in_escape := false
var _rescue_signal_blocked := true
var _rescue_panel: PanelContainer
var _rescue_caption: Label
var _combat_weapon: Label
var _combat_shield_status: Label
var _combat_shield: ProgressBar
var _combat_shield_fill: StyleBoxFlat
var _combat_damage: Label
var _combat_lock_readout: Label
var _projectile_alert: Label
var _thermal_panel: VBoxContainer
var _entry_readout: Label
var _thermal_label: Label
var _thermal_level: ProgressBar
var _thermal_fill: StyleBoxFlat
var _clock: Label
var _time_hint: Label
var _docking_panel: PanelContainer
var _docking_status: Label
var _docking_position: Label
var _docking_motion: Label
var _docking_roll: Label
var _docking_ready: Label
var _docking_access: Label
var _surface_panel: PanelContainer
var _surface_status: Label
var _surface_height: Label
var _surface_motion: Label
var _surface_alignment: Label
var _surface_ready: Label
var _surface_gear: Label
var _guidance: Label
var _notice: Label
var _notice_panel: PanelContainer
var _commands_panel: PanelContainer
var _operation_progress: ProgressBar
var _right_panel: PanelContainer
var _throttle_controls: GridContainer
var _port_tools: HBoxContainer
var _combat_tools: HBoxContainer
var _navigation_drawer: PanelContainer
var _navigation_switches: HBoxContainer
var _navigation_cameras: HBoxContainer
var _navigation_hint: Label
var _navigation_title: Label
var _navigation_list: ItemList
var _navigation_computer_ready := true
var _missile_camera_ready := false
var _navigation_corridor_enabled := false
var _navigation_sites: Array[int] = []
var _navigation_blockers: Array[Control] = []
var _navigation_presses: Dictionary[int, NavigationPress] = {}
var _scanner_panel: VBoxContainer
var _scanner_radar: Control
var _scanner_list: ItemList
var _scanner_detail: Label
var _scanner_rows: Array[Dictionary] = []
var _scanner_ids: Array[String] = []
var _scanner_focus := ""
var _combat_lock := ""
var _scanner_range := 1400.0
var _mapper_fitted := false
var _scanner_can_lock := false
var _contact_action_presses: Dictionary[int, String] = {}
var _actions: Dictionary = {}
var _touch_owner: Dictionary = {}
var _steer_finger := -1
var _bank_finger := -1
var _boost := false
var _brake := false
var _mouse_held: Dictionary[String, bool] = {}
var _translation_mode := false
var _translation_depth := 0.0
var _input_enabled := true
var _touch_gain := 1.0
var _touch_mirrored := false
var _parked := true
var _departure_active := false
var _departure_can_cancel := false
var _departure_blocked := false
var _lift_blocked := false
var _mining_blocked := false
var _scoop_blocked := false
var _time_blocked := false
var _time_paused := false
var _patrol_blocked := false
var _convoy_blocked := false
var _rendezvous_finish_blocked := true
var _dock_sync_blocked := true
var _dock_clearance_blocked := true
var _gear_blocked := true
var _frame_blocked := true
var _autopilot_blocked := false
var _speed_hold_blocked := true
var _fire_held := false
var _ecm_blocked := true
var _jumping := false
var _jump_transit := false
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

	var route_stack := _panel(_safe, Vector2.ZERO, COURSE_CARD)
	_course_card = route_stack.get_parent() as PanelContainer
	_route = _label(route_stack, 23, CYAN)
	_route.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_route_detail = _label(route_stack, 17, INK)
	_route_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_passenger_route = _label(route_stack, 16, CYAN)
	_passenger_route.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_passenger_route.hide()
	_ambient_alert = _label(route_stack, 16, AMBER)
	_ambient_alert.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ambient_alert.hide()
	_rig_readout = HBoxContainer.new()
	_rig_readout.add_theme_constant_override("separation", 8)
	route_stack.add_child(_rig_readout)
	_rig_summary = _label(_rig_readout, 16, CYAN)
	_rig_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rig_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rig_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(_rig_readout, "rig_route", "К буру")
	_actions["rig_route"].size_flags_horizontal = Control.SIZE_SHRINK_END
	_rig_readout.hide()
	_processor_readout = HBoxContainer.new()
	_processor_readout.add_theme_constant_override("separation", 8)
	route_stack.add_child(_processor_readout)
	_processor_summary = _label(_processor_readout, 16, CYAN)
	_processor_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_processor_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(_processor_readout, "processor_route", "К лаборатории")
	_processor_readout.hide()
	_orbital_mining_readout = _label(route_stack, 16, CYAN)
	_orbital_mining_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_orbital_mining_readout.hide()
	_shortcuts = GridContainer.new()
	_shortcuts.columns = 6
	_shortcuts.add_theme_constant_override("h_separation", int(HUD_GAP))
	_shortcuts.add_theme_constant_override("v_separation", int(HUD_GAP))
	_pin(_shortcuts, _safe, Vector2.ZERO, SHORTCUT_BAR)
	_button(_shortcuts, "journal", "Журнал")
	_button(_shortcuts, "settings", "Настройки")
	_button(_shortcuts, "frontier", "Освоение")
	_button(_shortcuts, "navigation_toggle", Text.text("NAV_SHORTCUT"))
	_button(_shortcuts, "recon", "Съёмка")
	_button(_shortcuts, "comms", Text.text("LINK_SHORTCUT"))
	for action: String in ["journal", "settings", "frontier", "navigation_toggle", "recon", "comms"]:
		var button: Button = _actions[action]
		button.custom_minimum_size.y = SHORTCUT_BAR.size.y
		button.add_theme_font_size_override("font_size", 16)
	_actions["journal"].tooltip_text = "Журнал заданий"
	_actions["settings"].tooltip_text = "Графика и управление"
	_actions["frontier"].tooltip_text = "Разведка, строительство и фракции"
	_actions["navigation_toggle"].tooltip_text = "Цели и отображение объектов в полёте (F12)"
	_actions["recon"].tooltip_text = "Бортовая камера и задания на съёмку (Q)"
	var instrument_stack := _panel(_safe, Vector2(1, 0), Rect2(-332, 24, 306, 159))
	instrument_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	var instrument_card := instrument_stack.get_parent() as PanelContainer
	var instrument_skin := _box(BACK, LINE, 13, 10.0)
	instrument_skin.set_border_width(SIDE_TOP, 2)
	instrument_card.add_theme_stylebox_override("panel", instrument_skin)
	_motion_readout = _instrument_row(instrument_stack)
	var speed_column := _instrument_column(_motion_readout)
	_speed_caption = _label(speed_column, 15, MUTED)
	_speed_value = _label(speed_column, 24, INK)
	var thrust_column := _instrument_column(_motion_readout)
	_thrust_caption = _label(thrust_column, 15, MUTED)
	_thrust_value = _label(thrust_column, 24, CYAN)
	_motion_readout.hide()
	_telemetry = _label(instrument_stack, 16, MUTED)
	_telemetry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_condition = _label(instrument_stack, 16, INK)
	_camera_instrument = _label(instrument_stack, 15, CYAN)
	_camera_instrument.hide()
	var fuel_row := _instrument_row(instrument_stack)
	var drive_tank := _instrument_column(fuel_row)
	_drive_tank_caption = _label(drive_tank, 15, MUTED)
	_fuel = _label(drive_tank, 17, INK)
	_fuel_fill = _box(CYAN, CYAN, 4, 0.0)
	_fuel_level = _instrument_gauge(drive_tank, _fuel_fill)
	var jump_tank := _instrument_column(fuel_row)
	_jump_tank_caption = _label(jump_tank, 15, MUTED)
	_jump_fuel = _label(jump_tank, 17, INK)
	_jump_fuel_fill = _box(CYAN, CYAN, 4, 0.0)
	_jump_fuel_level = _instrument_gauge(jump_tank, _jump_fuel_fill)
	_pump_mode = _label(instrument_stack, 15, CYAN)
	_pump_mode.hide()
	_build_combat_instrument(instrument_stack)
	_thermal_panel = VBoxContainer.new()
	_thermal_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_thermal_panel.add_theme_constant_override("separation", 3)
	instrument_stack.add_child(_thermal_panel)
	_entry_readout = _label(_thermal_panel, 15, INK)
	_entry_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_entry_readout.hide()
	_thermal_label = _label(_thermal_panel, 17, CYAN)
	_thermal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_thermal_fill = _box(CYAN, CYAN, 4, 0.0)
	_thermal_level = _instrument_gauge(_thermal_panel, _thermal_fill)
	_thermal_panel.hide()
	var clock_row := HBoxContainer.new()
	clock_row.add_theme_constant_override("separation", 5)
	instrument_stack.add_child(clock_row)
	_clock = _label(clock_row, 16, MUTED)
	_clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_button(clock_row, "time", "1×")
	var time_button: Button = _actions["time"]
	time_button.custom_minimum_size.x = 48.0
	time_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_button(clock_row, "time_pause", "Пауза")
	var pause_button: Button = _actions["time_pause"]
	pause_button.custom_minimum_size.x = 108.0
	pause_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	pause_button.add_theme_font_size_override("font_size", 16)
	_time_hint = _label(instrument_stack, 15, AMBER)
	_time_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_time_hint.hide()
	_build_docking_instrument()
	_build_surface_instrument()

	_steer = SteeringPad.new()
	_steer.caption = "КУРС"
	_pin(_steer, _safe, Vector2(0, 1), COURSE_PAD)
	_bank = SteeringPad.new()
	_bank.caption = "КРЕН"
	_bank.horizontal = true
	_pin(_bank, _safe, Vector2(0, 1), ROLL_PAD)
	_camera_controls = HBoxContainer.new()
	_pin(_camera_controls, _safe, Vector2(0, 1), CAMERA_CONTROL)
	_button(_camera_controls, "camera", "Снаружи")
	_actions["camera"].add_theme_font_size_override("font_size", 16)
	_camera_controls.hide()
	_build_flight_modes()

	var center := _panel(_safe, Vector2(0.5, 1), Rect2(-258, -143, 503, 117))
	_commands_panel = center.get_parent() as PanelContainer
	_guidance = _label(center, 17, INK)
	_guidance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guidance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guidance.custom_minimum_size.y = 38
	_operation_progress = ProgressBar.new()
	_operation_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_operation_progress.max_value = 1.0
	_operation_progress.step = 0.0
	_operation_progress.show_percentage = false
	_operation_progress.custom_minimum_size.y = 9.0
	_operation_progress.add_theme_stylebox_override("background", _box(Color("12313d"), LINE, 5, 0.0))
	_operation_progress.add_theme_stylebox_override("fill", _box(AMBER, AMBER, 5, 0.0))
	center.add_child(_operation_progress)
	_operation_progress.hide()
	var commands := HBoxContainer.new()
	commands.add_theme_constant_override("separation", 7)
	center.add_child(commands)
	_button(commands, "target", "Цель")
	_button(commands, "autopilot", "Авто")
	_button(commands, "dock_sync", "Крен дока")
	_actions["dock_sync"].tooltip_text = "Следовать вращению кольца по крену (F5). Курс, сдвиг и тяга остаются под вашим управлением."
	_actions["dock_sync"].hide()
	_button(commands, "gear", "Шасси")
	var gear_button: Button = _actions["gear"]
	gear_button.name = "LandingGear"
	gear_button.custom_minimum_size.x = 118.0
	gear_button.hide()
	_button(commands, "dock", "Запросить выход")
	_button(commands, "scoop", "Сбор топлива")
	_button(commands, "contract", "Контракт")
	_button(commands, "mine", "Развернуть модуль")
	_button(commands, "rig_deploy", "Оставить бур")
	_actions["rig_deploy"].tooltip_text = "Бур будет добывать сырьё после взлёта"
	_button(commands, "rig_unload", "Выгрузить")
	_button(commands, "rig_retrieve", "Забрать бур")
	_actions["rig_retrieve"].tooltip_text = "Вернуть пустой бур на борт"
	_button(commands, "processor_deploy", "Установить лабораторию")
	_actions["processor_deploy"].tooltip_text = "Переработать 2 ед. льда и 1 ед. зерна"
	_button(commands, "processor_feed", "Загрузить сырьё")
	_button(commands, "processor_unload", "Забрать медикаменты")
	_button(commands, "processor_retrieve", "Забрать лабораторию")
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
	utilities.add_theme_constant_override("separation", 5)
	right.add_child(utilities)
	_button(utilities, "map", "Карта")
	_button(utilities, "galaxy", "Галактика")
	_button(utilities, "fuel", "Топливо")
	_button(utilities, "report", "Отчёт")
	for action: String in ["map", "galaxy", "fuel", "report"]:
		var utility: Button = _actions[action]
		utility.add_theme_font_size_override("font_size", 16)
		for state: String in ["normal", "hover", "pressed"]:
			var skin := utility.get_theme_stylebox(state)
			skin.set_content_margin(SIDE_LEFT, 3.0)
			skin.set_content_margin(SIDE_RIGHT, 3.0)
	_actions["fuel"].tooltip_text = "Топливные запасы и перелив водорода (C)"
	_port_tools = HBoxContainer.new()
	_port_tools.add_theme_constant_override("separation", 7)
	right.add_child(_port_tools)
	_button(_port_tools, "market", "Биржа")
	_button(_port_tools, "services", "Сервис")
	_button(_port_tools, "patrol", "Дозор")
	_button(_port_tools, "convoy", "К конвою")
	_button(_port_tools, "orbit_cancel", "Отменить манёвр")
	_actions["orbit_cancel"].tooltip_text = "Прекратить орбитальный манёвр и остаться в режиме инерции"
	_actions["orbit_cancel"].add_theme_color_override("font_color", AMBER)
	_actions["orbit_cancel"].hide()
	_button(_port_tools, "rendezvous_cancel", "Отмена")
	_actions["rendezvous_cancel"].tooltip_text = "Прервать сближение с выбранной целью"
	_actions["rendezvous_cancel"].add_theme_color_override("font_color", AMBER)
	_actions["rendezvous_cancel"].hide()
	_button(_port_tools, "rendezvous_finish", "К швартовке")
	_actions["rendezvous_finish"].add_theme_color_override("font_color", CYAN)
	_actions["rendezvous_finish"].hide()
	_combat_tools = HBoxContainer.new()
	_combat_tools.add_theme_constant_override("separation", 7)
	right.add_child(_combat_tools)
	_button(_combat_tools, "aim_lock", Text.text("AIM_LOCK"))
	var aim_lock: Button = _actions["aim_lock"]
	aim_lock.add_theme_font_size_override("font_size", 16)
	aim_lock.add_theme_color_override("font_color", CYAN)
	aim_lock.tooltip_text = Text.text("AIM_LOCK_TOOLTIP")
	aim_lock.hide()
	_button(_combat_tools, "fire", "Огонь")
	var fire_button: Button = _actions["fire"]
	fire_button.size_flags_stretch_ratio = 1.35
	fire_button.add_theme_color_override("font_color", ALERT)
	fire_button.add_theme_stylebox_override("normal", _box(Color("482b32"), ALERT, 9, 7.0))
	fire_button.add_theme_stylebox_override("hover", _box(Color("633c45"), ALERT, 9, 7.0))
	fire_button.add_theme_stylebox_override("pressed", _box(Color("78505a"), ALERT, 9, 7.0))
	_button(_combat_tools, "ecm", "РЭБ")
	var ecm: Button = _actions["ecm"]
	ecm.add_theme_color_override("font_color", AMBER)
	ecm.add_theme_stylebox_override("normal", _box(Color("443323"), AMBER, 9, 7.0))
	ecm.hide()
	_ordnance_tools = HBoxContainer.new()
	_ordnance_tools.add_theme_constant_override("separation", 4)
	right.add_child(_ordnance_tools)
	_button(_ordnance_tools, "missile_next", "Место")
	_button(_ordnance_tools, "missile_fire", "Пуск")
	_button(_ordnance_tools, "decoy", "Ловушка")
	_button(_ordnance_tools, "energy_pulse", "Импульс")
	for action: String in ["missile_next", "missile_fire", "decoy", "energy_pulse"]:
		var control: Button = _actions[action]
		control.add_theme_font_size_override("font_size", 16)
		for state: String in ["normal", "hover", "pressed"]:
			var skin := control.get_theme_stylebox(state)
			skin.set_content_margin(SIDE_LEFT, 2.0)
			skin.set_content_margin(SIDE_RIGHT, 2.0)
	_ordnance_tools.hide()
	_button(right, "rescue_eject", "Покинуть корабль")
	_actions["rescue_eject"].hide()
	_orbital_mining_tools = HBoxContainer.new()
	_orbital_mining_tools.add_theme_constant_override("separation", 7)
	right.add_child(_orbital_mining_tools)
	_button(_orbital_mining_tools, "mining_pulse", "Горный лазер")
	_button(_orbital_mining_tools, "fragment_collect", "Подобрать обломок")
	_orbital_mining_tools.hide()
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
	_build_navigation_drawer()
	_build_rescue_panel()
	_navigation_blockers.assign([
		_course_card, _shortcuts, instrument_card, _steer, _bank, _camera_controls,
		_flight_modes, _translation_controls, _commands_panel, _right_panel, _notice_panel,
		_docking_panel, _surface_panel, _navigation_drawer, _rescue_panel,
	])
	get_viewport().size_changed.connect(_update_safe_area)
	_course_card.resized.connect(_place_shortcuts)
	_safe.resized.connect(_place_shortcuts)
	_update_safe_area()
	_place_shortcuts()
	_apply_touch_layout()

func _instrument_row(parent: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	return row

func _instrument_column(parent: HBoxContainer) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	parent.add_child(column)
	return column

func _instrument_gauge(parent: VBoxContainer, fill: StyleBoxFlat) -> ProgressBar:
	var gauge := ProgressBar.new()
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge.step = 0.0
	gauge.show_percentage = false
	gauge.custom_minimum_size.y = 7.0
	gauge.add_theme_stylebox_override("background", _box(Color("12313d"), LINE, 4, 0.0))
	gauge.add_theme_stylebox_override("fill", fill)
	parent.add_child(gauge)
	return gauge

func _place_shortcuts() -> void:
	var approach := _docking_panel if _docking_panel.visible else _surface_panel
	var width := SHORTCUT_BAR.size.x
	var stacked := false
	if approach.visible:
		var single_row := HUD_GAP * (_shortcuts.get_child_count() - 1)
		for button: Button in _shortcuts.get_children():
			single_row += button.get_combined_minimum_size().x
		var available := maxf(0.0, approach.position.x - SHORTCUT_BAR.position.x - HUD_GAP)
		stacked = available < maxf(width, single_row)
		width = minf(width, available)
	_course_card.offset_right = COURSE_CARD.position.x + minf(COURSE_CARD.size.x, width)
	_shortcuts.columns = 3 if stacked else 6
	_shortcuts.offset_right = SHORTCUT_BAR.position.x + width
	_shortcuts.offset_top = _course_card.position.y + _course_card.size.y + HUD_GAP
	var height := SHORTCUT_BAR.size.y * 2.0 + HUD_GAP if stacked else SHORTCUT_BAR.size.y
	_shortcuts.offset_bottom = _shortcuts.offset_top + height

func _build_rescue_panel() -> void:
	var body := _panel(_safe, Vector2(0.5, 0.5), Rect2(-222, -108, 444, 164))
	_rescue_panel = body.get_parent() as PanelContainer
	var title := _label(body, 24, AMBER)
	title.text = "Спасательная капсула"
	_rescue_caption = _label(body, 18, INK)
	_rescue_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(body, "rescue_signal", "Передать сигнал бедствия")
	_rescue_panel.hide()

func _build_navigation_drawer() -> void:
	var stack := _panel(_safe, Vector2(0.5, 0.5), Rect2(-240, -176, 480, 330))
	_navigation_drawer = stack.get_parent() as PanelContainer
	_navigation_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	stack.add_child(header)
	_navigation_title = _label(header, 21, CYAN)
	_navigation_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "scanner_toggle", Text.text("SCANNER"))
	_button(header, "navigation_close", Text.text("NAV_CLOSE"))
	_actions["navigation_close"].size_flags_horizontal = Control.SIZE_SHRINK_END
	_actions["scanner_toggle"].size_flags_horizontal = Control.SIZE_SHRINK_END
	_navigation_switches = HBoxContainer.new()
	_navigation_switches.add_theme_constant_override("separation", 6)
	stack.add_child(_navigation_switches)
	_button(_navigation_switches, "object_labels", "")
	_button(_navigation_switches, "navigation_corridor", "")
	_button(_navigation_switches, "ship_markers", "")
	_navigation_cameras = HBoxContainer.new()
	_navigation_cameras.add_theme_constant_override("separation", 6)
	stack.add_child(_navigation_cameras)
	_button(_navigation_cameras, "camera_observer", Text.text("CAMERA_OBSERVER"))
	_button(_navigation_cameras, "camera_missile", Text.text("CAMERA_MISSILE"))
	for action: String in ["navigation_close", "scanner_toggle", "object_labels", "navigation_corridor", "ship_markers", "camera_observer", "camera_missile"]:
		_actions[action].add_theme_font_size_override("font_size", 16)
		_actions[action].custom_minimum_size.y = 46.0
	_actions["object_labels"].tooltip_text = "Показывать названия объектов и контактов поверх сцены"
	_actions["navigation_corridor"].tooltip_text = "Показывать направляющие к выбранному объекту"
	_actions["ship_markers"].tooltip_text = "Показывать метки кораблей фонового движения"
	_update_navigation_switches()
	_navigation_list = ItemList.new()
	_navigation_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_navigation_list.add_theme_font_size_override("font_size", 18)
	_navigation_list.add_theme_constant_override("v_separation", 16)
	_navigation_list.add_theme_stylebox_override("panel", _box(Color("102730"), LINE, 8, 8.0))
	_navigation_list.item_selected.connect(_select_navigation_row)
	stack.add_child(_navigation_list)
	_navigation_hint = _label(stack, 17, MUTED)
	_navigation_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_navigation_hint.hide()
	_build_scanner(stack)
	_refresh_navigation_language()
	_navigation_drawer.hide()

func _build_scanner(parent: VBoxContainer) -> void:
	_scanner_panel = VBoxContainer.new()
	_scanner_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scanner_panel.add_theme_constant_override("separation", 5)
	parent.add_child(_scanner_panel)
	var readout := HBoxContainer.new()
	readout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scanner_panel.add_child(readout)
	_scanner_radar = FlightScanner.new()
	_scanner_radar.custom_minimum_size = Vector2(160, 135)
	readout.add_child(_scanner_radar)
	_scanner_list = ItemList.new()
	_scanner_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scanner_list.add_theme_font_size_override("font_size", 16)
	_scanner_list.add_theme_constant_override("v_separation", 14)
	_scanner_list.add_theme_stylebox_override("panel", _box(Color("102730"), LINE, 8, 8.0))
	_scanner_list.item_selected.connect(_select_scanner_row)
	readout.add_child(_scanner_list)
	_scanner_detail = _label(_scanner_panel, 15, MUTED)
	_scanner_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scanner_detail.custom_minimum_size.y = 42
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 7)
	_scanner_panel.add_child(actions)
	_button(actions, "combat_lock", Text.text("SCANNER_LOCK"))
	_button(actions, "combat_unlock", Text.text("SCANNER_CLEAR"))
	_button(actions, "comms_contact", Text.text("LINK_SHORTCUT"))
	for action: String in ["combat_lock", "combat_unlock", "comms_contact"]:
		_actions[action].custom_minimum_size.y = 46.0
		_actions[action].add_theme_font_size_override("font_size", 16)
	_scanner_panel.hide()

func _update_navigation_switches() -> void:
	_actions["object_labels"].text = Text.text("NAV_LABELS_ON" if _marks.object_labels else "NAV_LABELS_OFF")
	_actions["navigation_corridor"].text = Text.text("NAV_GUIDE_ON" if _navigation_corridor_enabled else "NAV_GUIDE_OFF")
	_actions["ship_markers"].text = Text.text("NAV_SHIPS_ON" if _marks.ship_markers else "NAV_SHIPS_OFF")

func _build_combat_instrument(parent: VBoxContainer) -> void:
	_combat_readout = VBoxContainer.new()
	_combat_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_readout.add_theme_constant_override("separation", 3)
	parent.add_child(_combat_readout)
	_projectile_alert = _label(_combat_readout, 18, ALERT)
	_projectile_alert.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_combat_weapon = _label(_combat_readout, 15, INK)
	_combat_weapon.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_combat_shield_status = _label(_combat_readout, 15, CYAN)
	_combat_shield_fill = _box(CYAN, CYAN, 4, 0.0)
	_combat_shield = _instrument_gauge(_combat_readout, _combat_shield_fill)
	_combat_shield.max_value = 1.0
	_combat_damage = _label(_combat_readout, 15, ALERT)
	_combat_lock_readout = _label(parent, 15, ALERT)
	_combat_lock_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_combat_lock_readout.hide()
	_combat_readout.hide()

func _build_docking_instrument() -> void:
	var readout := _panel(_safe, Vector2(0.5, 0), Rect2(-196, 24, 392, 148))
	_docking_panel = readout.get_parent() as PanelContainer
	_docking_status = _label(readout, 20, CYAN)
	_docking_position = _label(readout, 17, INK)
	_docking_motion = _label(readout, 17, INK)
	_docking_roll = _label(readout, 16, AMBER)
	_docking_ready = _label(readout, 15, MUTED)
	_docking_access = _label(readout, 16, AMBER)
	for label in [_docking_status, _docking_position, _docking_motion, _docking_roll, _docking_ready, _docking_access]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(readout, "dock_clearance", "Запросить допуск")
	var request: Button = _actions["dock_clearance"]
	request.tooltip_text = "Запросить разрешение на вход в выбранный док (F6)"
	request.custom_minimum_size.y = 48.0
	request.hide()
	_docking_panel.hide()

func _sync_docking(status: Dictionary, automatic: bool) -> void:
	var visible_approach := not status.is_empty() and bool(status.get("near", false))
	_docking_panel.visible = visible_approach and _input_enabled
	var access: Dictionary = status.get("access", {})
	var ground := bool(status.get("ground", false))
	var hangar := bool(status.get("ground_hangar", false))
	var request: Button = _actions["dock_clearance"]
	request.tooltip_text = "Запросить разрешение на посадку в ангар (F6)" if hangar else "Запросить разрешение на вход в выбранный док (F6)"
	_dock_clearance_blocked = automatic or not access.get("request_available", false)
	request.visible = _docking_panel.visible and not _dock_clearance_blocked
	var button: Button = _actions["dock_sync"]
	button.visible = visible_approach and not ground and not automatic and _input_enabled
	_dock_sync_blocked = not (status.get("sync_available", false) or status.get("sync_active", false))
	if not visible_approach:
		return
	var ready := bool(status.ok)
	var synced := bool(status.sync_active)
	_docking_status.text = "Автоматическая швартовка" if automatic else "Ручная швартовка"
	if ground:
		if not status.in_front:
			_docking_status.text = "Заходите сверху"
		elif ready:
			_docking_status.text = "Можно садиться"
		else:
			_docking_status.text = "Посадка в ангар" if hangar else "Посадка на площадку"
	elif ready:
		_docking_status.text = "Можно швартоваться"
	elif not status.in_front:
		_docking_status.text = "Створ с обратной стороны"
	_docking_status.add_theme_color_override("font_color", CYAN if ready else AMBER)
	var axis_label := "Над палубой" if ground else "По оси"
	_docking_position.text = ("%s %.1f м · вбок %.1f м" % [axis_label, float(status.axis_distance), float(status.lateral_error)]).replace(".", ",")
	_docking_position.add_theme_color_override("font_color", CYAN if status.position_ok else INK)
	var closing_speed := float(status.closing_speed)
	if absf(closing_speed) < 0.05:
		closing_speed = 0.0
	_docking_motion.text = ("Сближение %+.1f · скорость %.1f м/с" % [closing_speed, float(status.relative_speed)]).replace(".", ",")
	_docking_motion.add_theme_color_override("font_color", CYAN if status.speed_ok else AMBER)
	var alignment := "Отклонение от вертикали %.1f°" % float(status.aim_error_deg) if ground else "Крен %+.1f° · курс %.1f°" % [float(status.roll_error_deg), float(status.aim_error_deg)]
	_docking_roll.text = alignment.replace(".", ",") + (" · синхр." if synced else "")
	_docking_roll.add_theme_color_override("font_color", CYAN if status.roll_ok and status.aim_ok else AMBER)
	if ground:
		_docking_ready.text = "Палуба %s · Скорость %s · Ориентация %s · Шасси %s" % ["✓" if status.position_ok else "—", "✓" if status.speed_ok else "—", "✓" if status.roll_ok and status.aim_ok else "—", "✓" if status.get("gear_ok", false) else "—"]
	else:
		_docking_ready.text = "Створ %s · Скорость %s · Крен %s · Курс %s" % ["✓" if status.position_ok else "—", "✓" if status.speed_ok else "—", "✓" if status.roll_ok else "—", "✓" if status.aim_ok else "—"]
	_docking_access.visible = not ground or hangar
	_docking_access.text = _dock_access_caption(access)
	var tariff: Vector2i = status.get("port_tariff", Vector2i.ZERO)
	if tariff.x > 0:
		_docking_access.text += "\nСбор %d кр. · Стоянка %d кр./сутки" % [tariff.x, tariff.y]
	_docking_access.add_theme_color_override("font_color", CYAN if status.get("cleared", false) else AMBER)
	_actions["dock"].tooltip_text = str(status.get("reason", ""))
	button.text = "Снять синхр." if synced else "Крен дока"
	button.add_theme_color_override("font_color", CYAN if synced else INK)
	button.tooltip_text = "Отключить следование крену дока (F5)" if synced else "Следовать вращению кольца по крену (F5). Курс, сдвиг и тяга остаются ручными."

func _dock_access_caption(access: Dictionary) -> String:
	match access.get("phase", "closed"):
		"queued":
			return "Ожидание допуска · %d с" % ceili(float(access.wait))
		"opening":
			return "Створ открывается · %d%%" % roundi(float(access.open_fraction) * 100.0)
		"open":
			return "Проход открыт · допуск ещё %d с" % ceili(float(access.remaining))
		"closing":
			return "Створ закрывается"
	return "Допуск не запрошен"

func _build_surface_instrument() -> void:
	var readout := _panel(_safe, Vector2(0.5, 0), Rect2(-196, 24, 392, 148))
	_surface_panel = readout.get_parent() as PanelContainer
	_surface_status = _label(readout, 20, CYAN)
	_surface_height = _label(readout, 17, INK)
	_surface_motion = _label(readout, 17, INK)
	_surface_alignment = _label(readout, 16, INK)
	_surface_ready = _label(readout, 15, MUTED)
	_surface_gear = _label(readout, 15, AMBER)
	for label in [_surface_status, _surface_height, _surface_motion, _surface_alignment, _surface_ready, _surface_gear]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_surface_panel.hide()

func _sync_surface_guidance(status: Dictionary, gear: Dictionary) -> void:
	var approach := not status.is_empty() and bool(status.get("guide", false))
	_surface_panel.visible = approach and _input_enabled
	if not approach:
		return
	var ready := bool(status.ok)
	_surface_status.text = "Можно садиться" if ready else "Посадка на площадку" if status.pad else "Посадка вне площадки"
	_surface_status.add_theme_color_override("font_color", CYAN if ready else AMBER)
	_surface_height.text = ("Высота %.1f м · уклон %.1f°" % [float(status.altitude), float(status.slope)]).replace(".", ",")
	_surface_height.add_theme_color_override("font_color", CYAN if status.height_ok and status.slope_ok else AMBER)
	var descent_speed := float(status.descent_speed)
	if absf(descent_speed) < 0.05:
		descent_speed = 0.0
	_surface_motion.text = ("Снижение %+.1f · снос %.1f м/с" % [descent_speed, float(status.drift_speed)]).replace(".", ",")
	_surface_motion.add_theme_color_override("font_color", CYAN if status.speed_ok else AMBER)
	_surface_alignment.text = ("Скорость %.1f м/с · нос %.1f°" % [float(status.relative_speed), float(status.aim_error_deg)]).replace(".", ",")
	_surface_alignment.add_theme_color_override("font_color", CYAN if status.aim_ok else AMBER)
	_surface_ready.text = "Высота %s · Скорость %s · Уклон %s · Нос %s" % ["✓" if status.height_ok else "—", "✓" if status.speed_ok else "—", "✓" if status.slope_ok else "—", "✓" if status.aim_ok else "—"]
	_surface_gear.text = str(gear.text)
	_surface_gear.add_theme_color_override("font_color", CYAN if gear.locked else AMBER)

func _sync_gear(gear: Dictionary, shown: bool) -> void:
	var button: Button = _actions["gear"]
	button.visible = shown and _input_enabled
	_gear_blocked = not bool(gear.allowed)
	if not button.visible:
		return
	var moving := (float(gear.progress) != (1.0 if gear.deployed else 0.0))
	var percentage := floori(100.0 * float(gear.progress))
	button.text = "Шасси %d%%" % percentage if moving else "Шасси"
	button.add_theme_color_override("font_color", CYAN if gear.locked else AMBER)
	var hint := "Убрать шасси (Y)" if gear.deployed else "Выпустить шасси (Y)"
	button.tooltip_text = "%s\n%s" % [gear.text, gear.reason if _gear_blocked else hint]

func _build_flight_modes() -> void:
	_flight_modes = HBoxContainer.new()
	_flight_modes.add_theme_constant_override("separation", 8)
	_pin(_flight_modes, _safe, Vector2(0, 1), FLIGHT_MODE_ROW)
	_button(_flight_modes, "translation_mode", "Курс")
	_button(_flight_modes, "flight_assist", "Стабилизация")
	_button(_flight_modes, "frame", "Отсчёт")
	_actions["frame"].custom_minimum_size.x = 66.0
	_actions["frame"].tooltip_text = "Сменить систему отсчёта полёта (F7)"
	_button(_flight_modes, "speed_hold", "Скорость")
	_actions["speed_hold"].toggle_mode = true
	_translation_controls = HBoxContainer.new()
	_translation_controls.add_theme_constant_override("separation", 8)
	_pin(_translation_controls, _safe, Vector2(0, 1), TRANSLATION_ROW)
	_button(_translation_controls, "translation_forward", "Вперёд")
	_button(_translation_controls, "translation_reverse", "Назад")
	for action: String in ["translation_mode", "flight_assist", "frame", "speed_hold", "translation_forward", "translation_reverse"]:
		var button: Button = _actions[action]
		button.custom_minimum_size.y = 46.0
		button.add_theme_font_size_override("font_size", 16)
	_actions["translation_forward"].tooltip_text = "Удерживайте для движения вперёд (9)"
	_actions["translation_reverse"].tooltip_text = "Удерживайте для движения назад (3)"
	_flight_modes.hide()
	_update_translation_mode()

func sync(sim: RefCounted, delta: float, aim_lock_available := false, forward_aim := true) -> void:
	var docked: bool = sim.docked >= 0
	var landed: bool = sim.landed_site >= 0
	var parked := docked or landed
	var departure: Dictionary = sim.departure_status()
	if not _departure_active and departure.active:
		clear_held_input()
	_departure_active = departure.active
	_departure_can_cancel = departure.can_cancel
	_departure_blocked = docked and not _departure_active and not bool(departure.get("can_request", true))
	var port_services: bool = sim.station_services_available()
	var patrol: Dictionary = sim.patrol_status()
	if not _parked and parked:
		clear_held_input()
	_parked = parked
	var jump: Dictionary = sim.jump_progress_status()
	if bool(jump.is_transit) and not _jump_transit:
		clear_held_input()
	_jumping = bool(jump.active)
	_jump_transit = bool(jump.is_transit)
	_steer.visible = not parked and not _jump_transit
	_bank.visible = _steer.visible
	_camera_controls.visible = _steer.visible
	_flight_modes.visible = _steer.visible
	_translation_controls.visible = _steer.visible and _translation_mode
	var assist: Button = _actions["flight_assist"]
	assist.text = "Стабилизация" if sim.flight_assist else "Инерция"
	assist.tooltip_text = "Отключить автоматическую стабилизацию" if sim.flight_assist else "Включить автоматическую стабилизацию"
	var assist_color := CYAN if sim.flight_assist else AMBER
	if assist.get_theme_color("font_color") != assist_color:
		assist.add_theme_color_override("font_color", assist_color)
	var frame: Dictionary = {} if parked else sim.frame_status()
	_frame_blocked = not frame.get("available", false)
	var speed_hold: Dictionary = {} if parked else sim.speed_hold_status()
	_sync_speed_hold(speed_hold)
	_throttle_controls.visible = not parked
	_actions["target"].visible = not parked
	_actions["services"].visible = port_services
	_actions["market"].visible = port_services
	var orbit_active: bool = not parked and not _jumping and sim.orbit_maneuver
	_actions["orbit_cancel"].visible = orbit_active
	var rendezvous: Dictionary = {}
	if not parked and not _jumping and sim.rendezvous_active:
		rendezvous = sim.rendezvous_status()
	var rendezvous_active := not rendezvous.is_empty()
	_actions["autopilot"].visible = not parked and not rendezvous_active
	_sync_rendezvous_actions(rendezvous)
	var approach_active := orbit_active or rendezvous_active
	var patrol_fight: bool = patrol.get("phase") == Patrol.ENGAGED and patrol.get("same_system", false)
	var convoy: Dictionary = {}
	if not parked and not _jumping and not patrol_fight:
		var mission: Dictionary = sim.convoy_status()
		if mission.active and mission.local:
			convoy = mission
	var convoy_button: Button = _actions["convoy"]
	convoy_button.visible = not approach_active and not convoy.is_empty()
	convoy_button.text = "Снять курс" if sim.convoy_course else "К конвою"
	if convoy.get("phase") == "escorted":
		convoy_button.text = "Сопровождён"
	convoy_button.tooltip_text = str(convoy.get("reason", ""))
	_convoy_blocked = not convoy.get("can_route", false)
	var patrol_button: Button = _actions["patrol"]
	patrol_button.visible = not landed and not _departure_active and not _jumping and not approach_active and not convoy_button.visible and bool(patrol.get("visible", false))
	patrol_button.text = str(patrol.get("caption", "Дозор"))
	patrol_button.tooltip_text = str(patrol.get("reason", ""))
	_patrol_blocked = not bool(patrol.get("available", false))
	var ambient: Dictionary = {} if parked or _jumping else sim.ambient_status()
	_sync_ambient(ambient)
	var mission_fire := patrol_fight or bool(convoy.get("fire_visible", false))
	var fire_button: Button = _actions["fire"]
	fire_button.visible = (forward_aim and not parked and not _jumping
		and (mission_fire or ambient.get("fire_visible", false) or not sim.combat_lock_id().is_empty()))
	var fire: Dictionary = sim.fire_status() if fire_button.visible else {}
	fire_button.tooltip_text = "Удерживайте для огня · X — одиночный выстрел" if fire.get("ok", false) else str(fire.get("reason", ""))
	if not fire_button.visible and _fire_held:
		release_fire()
	var aim_lock: Button = _actions["aim_lock"]
	aim_lock.visible = aim_lock_available and _input_enabled and not parked and not _jumping
	_sync_combat({} if parked or _jumping else sim.combat_status())
	_port_tools.visible = port_services or patrol_button.visible or convoy_button.visible or approach_active
	_combat_tools.visible = aim_lock.visible or fire_button.visible or _actions["ecm"].visible
	var flight_tools := _port_tools.visible or _combat_tools.visible
	_sync_orbital_mining({} if parked or _jumping else sim.orbital_mining_status())
	_right_panel.visible = not _departure_active
	_right_panel.offset_top = -157.0 if docked else (-101.0 if landed else (-274.0 if flight_tools else -215.0))
	if _port_tools.visible and _combat_tools.visible:
		_right_panel.offset_top -= 57.0
	if _ordnance_tools.visible:
		_right_panel.offset_top -= 57.0
	if _orbital_mining_tools.visible:
		_right_panel.offset_top -= 57.0
	_marks.flight = not parked and not _jump_transit
	if (not _marks.flight or _jumping) and _navigation_drawer.visible:
		close_navigation()
	_marks.queue_redraw()
	_sync_remote_rig(sim.remote_rig_status(), docked, landed)
	_sync_processor(sim.processor_status(), landed)

	var mining: RefCounted = sim.mining
	var drilling: bool = landed and mining.phase in [MiningRig.DEPLOYING, MiningRig.DRILLING, MiningRig.RETURNING]
	var departure_progress: bool = _departure_active and departure.phase in ["opening", "transit"]
	var show_progress := drilling or departure_progress or _jumping
	_operation_progress.visible = show_progress
	if drilling:
		_operation_progress.value = mining.progress()
	elif departure_progress:
		_operation_progress.value = departure.progress
	elif _jumping:
		_operation_progress.value = float(jump.progress)
	_commands_panel.offset_top = -160.0 if show_progress else -143.0
	_notice_panel.offset_top = -215.0 if show_progress else -199.0
	_notice_panel.offset_bottom = -169.0 if show_progress else -153.0
	_lift_blocked = landed and mining.phase != MiningRig.STOWED
	_mining_blocked = landed and mining.phase != MiningRig.READY and not mining.available_to_deploy()
	_actions["mine"].visible = landed and not _rig_status.active
	match mining.phase:
		MiningRig.READY:
			_actions["mine"].text = "Забрать модуль"
		MiningRig.DEPLOYING, MiningRig.DRILLING:
			_actions["mine"].text = "Модуль в работе"
		MiningRig.RETURNING:
			_actions["mine"].text = "Подъём модуля"
		_:
			_actions["mine"].text = "Развернуть модуль"
	var scoop_target: bool = sim.is_scoop_site(sim.target)
	_actions["dock"].visible = parked or (not rendezvous_active and (Sector.is_port(sim.target) or Sector.is_mine_site(sim.target)))
	_actions["dock"].text = "Швартовка" if Sector.is_port(sim.target) and not Ground.is_port(sim.target) else "Посадка"
	_actions["dock"].tooltip_text = ""
	if parked:
		var ground_pad := Ground.is_port(sim.docked) and not Ground.is_hangar(sim.docked)
		_actions["dock"].text = "Взлёт" if landed or ground_pad else "Запросить взлёт" if Ground.is_hangar(sim.docked) else "Запросить выход"
		if _lift_blocked:
			_actions["dock"].tooltip_text = "Сначала верните модуль на борт"
		elif _departure_active:
			var hangar := Ground.is_hangar(sim.docked)
			if _departure_can_cancel:
				_actions["dock"].text = "Отменить взлёт" if hangar else "Отменить выход"
			else:
				_actions["dock"].text = "Автоматический взлёт" if hangar else "Автоматический выход"
			_actions["dock"].tooltip_text = str(departure.reason)
		elif _departure_blocked:
			_actions["dock"].text = "Нужен экипаж" if sim.ship.crew_required() > 0 else "Выход недоступен"
			_actions["dock"].tooltip_text = str(departure.reason)
	var scoop_status: Dictionary = {} if parked else sim.scoop_status()
	_scoop_blocked = not sim.scooping and not scoop_status.get("ok", false)
	_actions["scoop"].visible = not parked and (scoop_target or scoop_status.get("near", false) or sim.scooping)
	_actions["scoop"].text = "Остановить" if sim.scooping else "Сбор H₂"
	_actions["scoop"].tooltip_text = "Остановить сбор" if sim.scooping else str(scoop_status.get("reason", ""))
	var autopilot: Button = _actions["autopilot"]
	var equipment: Dictionary = sim.autopilot_equipment_status()
	_autopilot_blocked = not bool(equipment.can_engage) and not sim.autopilot
	if not equipment.installed:
		autopilot.text = "Без авто"
		autopilot.tooltip_text = "Автопилот не установлен. Оборудование доступно в сервисе порта."
	else:
		autopilot.text = "Выкл. авто" if sim.autopilot else "Авто"
		autopilot.tooltip_text = "Отключить автопилот (F)" if sim.autopilot else "Включить автопилот (F)"
	var itinerary: Dictionary = sim.contract_itinerary() if sim.contract_stage == 1 else {}
	var transfer: bool = not itinerary.is_empty() and int(itinerary.leg) + 1 < itinerary.stops.size()
	_actions["contract"].visible = port_services and (sim.docked == sim.contract_destination if sim.contract_stage == 1 else sim.offer_destination() >= 0)
	_actions["contract"].text = "Отметить этап" if transfer else ("Сдать груз" if sim.contract_stage == 1 else "Взять контракт")
	var sale_quote: int = sim.raw_sale_quote() if port_services and mining.ore_hold > 0 else 0
	_actions["sell_ore"].visible = sale_quote > 0
	var dock_approach: bool = not parked and not _jumping and not approach_active \
		and not sim.patrol_course and not sim.project_course and not sim.convoy_course
	var manual_approach: bool = dock_approach and not sim.autopilot
	var surface: Dictionary = sim.surface_status() if not parked and Sector.is_mine_site(sim.target) else {}
	var gear: Dictionary = sim.gear_status()
	var docking: Dictionary = sim.docking_guidance() if dock_approach and Sector.is_port(sim.target) else {}
	_sync_docking(docking, sim.autopilot)
	_sync_surface_guidance(surface if manual_approach and not sim.scooping else {}, gear)
	var ground_approach := bool(docking.get("ground", false)) and bool(docking.get("near", false))
	_sync_gear(gear, not parked and not _jumping and (ground_approach or surface.get("near", false) or gear.progress > 0.0 or gear.deployed))
	_sync_escape(sim.escape_status())
	_place_shortcuts()
	_motion_readout.visible = not parked and not _jumping and not _in_escape
	_sync_clock(sim)
	_refresh_disabled_actions()
	_sync_fuel(sim.ship)
	_sync_condition(sim.ship.hull, mining.ore_hold, mining.cargo_capacity)
	var stellar: Dictionary = {} if parked or _jump_transit else sim.thermal_status()
	var entry: Dictionary = {} if parked or _jump_transit else sim.atmosphere_status()
	var stellar_scoop: bool = sim.scooping and scoop_status.get("kind", "") == "star"
	var show_entry := _prefer_entry_meter(stellar, entry, stellar_scoop)
	var entry_site := int(entry.site) if show_entry and (entry.near or entry.inside) else -1

	if landed:
		_sync_surface(sim, mining)
	elif _departure_active:
		_sync_departure(sim, departure)
	elif docked:
		_sync_port(sim, sale_quote, itinerary, transfer)
		if sim.contract_stage != 1 and patrol.get("phase") in [Patrol.OUTBOUND, Patrol.RETURN] and patrol_button.visible:
			_guidance.text = str(patrol.get("reason", ""))
	else:
		_sync_flight(sim, scoop_status, itinerary, patrol, fire, convoy, rendezvous, entry_site, surface, frame, jump, speed_hold)
	_sync_passengers(sim)
	_sync_thermal(stellar, entry, stellar_scoop, show_entry)
	if _departure_blocked:
		_guidance.text = str(departure.reason)
		_guidance.add_theme_color_override("font_color", AMBER)
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_notice_panel.hide()

func _sync_escape(status: Dictionary) -> void:
	var active: bool = status.active
	if active and not _in_escape:
		clear_held_input()
		close_navigation()
	_in_escape = active
	var eject: Button = _actions["rescue_eject"]
	eject.visible = status.can_eject
	eject.tooltip_text = "Отделить спасательную капсулу"
	if eject.visible:
		_right_panel.offset_top -= 57.0
	_rescue_panel.visible = active and _input_enabled
	_rescue_signal_blocked = not status.can_signal
	if active:
		_steer.hide()
		_bank.hide()
		_camera_controls.hide()
		_flight_modes.hide()
		_translation_controls.hide()
		_throttle_controls.hide()
		_actions["aim_lock"].hide()
		_port_tools.hide()
		_combat_tools.hide()
		_ordnance_tools.hide()
		_orbital_mining_tools.hide()
		_docking_panel.hide()
		_surface_panel.hide()
		_marks.flight = false
		_rescue_caption.text = str(status.reason)
		if status.waiting:
			_rescue_caption.text += "\n«%s» · %d с" % [status.destination_name, ceili(status.remaining)]

func _sync_speed_hold(status: Dictionary) -> void:
	var enabled := bool(status.get("enabled", false))
	_speed_hold_blocked = not bool(status.get("available", false)) and not enabled
	var button: Button = _actions["speed_hold"]
	button.set_pressed_no_signal(enabled)
	var tint := CYAN if enabled else INK
	if button.get_theme_color("font_color") != tint:
		button.add_theme_color_override("font_color", tint)
	button.tooltip_text = "Отключить удержание скорости (F10)" if enabled else "Удерживать скорость в выбранной системе отсчёта (F10)"
	_actions["throttle_down"].text = "Скорость −" if enabled else "Тяга −"
	_actions["throttle_up"].text = "Скорость +" if enabled else "Тяга +"
	var step := int(status.get("step", 0))
	_actions["throttle_down"].tooltip_text = "Уменьшить заданную скорость на %d м/с (V)" % step if enabled else "Уменьшить тягу (V)"
	_actions["throttle_up"].tooltip_text = "Увеличить заданную скорость на %d м/с (R)" % step if enabled else "Увеличить тягу (R)"

func _sync_ambient(status: Dictionary) -> void:
	var phase := str(status.get("phase", "clear"))
	var distance := float(status.get("distance", INF))
	var hostile := bool(status.get("hostile", false)) and distance >= 0.0 and distance <= CONTACT_NOTICE_DISTANCE
	_ambient_alert.visible = hostile or phase == "relief"
	if not _ambient_alert.visible:
		return
	var tint := AMBER
	if phase == "relief":
		_ambient_alert.text = "Транспорт вернулся на маршрут."
		tint = CYAN
	else:
		var motion := " отступает" if phase == "retreat" else ""
		_ambient_alert.text = "%s%s · %d м · корпус %d%%" % [status.name, motion, roundi(distance), ceili(float(status.hull))]
		if phase == "retreat":
			tint = CYAN
		elif status.get("danger", false):
			tint = ALERT
	if _ambient_alert.get_theme_color("font_color") != tint:
		_ambient_alert.add_theme_color_override("font_color", tint)

func _sync_combat(status: Dictionary) -> void:
	var ecm: Button = _actions["ecm"]
	var incoming := bool(status.get("projectile", false))
	_combat_readout.visible = bool(status.get("visible", false)) or incoming
	ecm.visible = incoming and bool(status.get("ecm_fitted", false))
	_ecm_blocked = not bool(status.get("ecm_ok", false))
	ecm.tooltip_text = str(status.get("ecm_reason", "")) if _ecm_blocked else "Сбить приближающуюся ракету"
	_sync_ordnance(status.get("missile", {}), status.get("decoy", {}), status.get("pulse", {}))
	if not _combat_readout.visible:
		return
	var heat := clampi(roundi(float(status.heat)), 0, 100)
	_combat_weapon.text = "%s · нагрев %d%%" % [str(status.name), heat]
	var heat_color := AMBER if heat >= 65 else INK
	if str(status.get("fire_blocked", "")).begins_with("Перегрев"):
		heat_color = ALERT
	if _combat_weapon.get_theme_color("font_color") != heat_color:
		_combat_weapon.add_theme_color_override("font_color", heat_color)
	var shield_max := maxf(0.0, float(status.shield_max))
	var shield := clampf(float(status.shield), 0.0, shield_max)
	_combat_shield.visible = shield_max > 0.0
	_combat_shield_status.text = "Щит %d / %d ед." % [roundi(shield), roundi(shield_max)] if _combat_shield.visible else "Щит 0 ед."
	if _combat_shield.visible:
		_combat_shield.value = shield / shield_max
		var shield_color := CYAN if _combat_shield.value >= 0.35 else AMBER
		if _combat_shield_fill.bg_color != shield_color:
			_combat_shield_fill.bg_color = shield_color
			_combat_shield_fill.border_color = shield_color
	var damaged := str(status.get("damaged", ""))
	_combat_damage.visible = not damaged.is_empty()
	if _combat_damage.visible:
		_combat_damage.text = "Повреждено устройство РЭБ" if damaged == "ecm" else "Повреждён лазер «Нить»"
	_projectile_alert.visible = incoming
	if incoming:
		_projectile_alert.text = "Приближается ракета · %d м" % ceili(float(status.projectile_distance))

func _sync_remote_rig(status: Dictionary, docked: bool, landed: bool) -> void:
	_rig_status = status
	_rig_readout.visible = status.active
	_actions["rig_deploy"].visible = landed and status.can_deploy
	_actions["rig_unload"].visible = status.near and int(status.stored) > 0
	_actions["rig_retrieve"].visible = status.near
	_actions["rig_retrieve"].tooltip_text = "Сначала выгрузите сырьё" if int(status.stored) > 0 else "Вернуть пустой бур на борт"
	_actions["rig_unload"].tooltip_text = "Перенести добычу в трюм" if status.can_unload else "Освободите место в трюме"
	_actions["rig_route"].visible = status.can_route and not status.navigating
	_actions["rig_route"].tooltip_text = "Выбрать цель после выхода" if status.same_system and docked else "Заход к точке установки" if status.same_system else "Проложить межзвёздный маршрут к буру"
	if not status.active:
		return
	var place := str(status.name)
	if not status.same_system:
		place = "%s · %s" % [Sector.system(int(status.system)).name, place]
	var work := "Добыча" if status.working else "Буфер полон" if int(status.stored) >= int(status.capacity) else "Жила исчерпана"
	_rig_summary.text = "Бур · %s\n%s · %d/%d ед." % [place, work, int(status.stored), int(status.capacity)]


func _sync_processor(status: Dictionary, landed: bool) -> void:
	_processor_status = status
	_processor_readout.visible = status.active or (status.installed and landed)
	_actions["processor_route"].visible = status.can_route and not status.navigating
	_actions["processor_deploy"].visible = status.can_deploy
	_actions["processor_feed"].visible = status.can_feed
	_actions["processor_unload"].visible = status.near and int(status.ready) > 0
	_actions["processor_retrieve"].visible = status.can_retrieve
	if not status.active:
		_processor_summary.text = "Медлаборатория · нужно 2 ед. льда и 1 ед. зерна"
		return
	var place := str(status.name)
	if not status.same_system:
		place = "%s · %s" % [Sector.system(int(status.system)).name, place]
	var progress := "%d с до готовности" % ceili(float(status.remaining)) if status.working else "%d ед. медикаментов" % int(status.ready)
	_processor_summary.text = "Медлаборатория · %s\n%s" % [place, progress]


func _sync_orbital_mining(status: Dictionary) -> void:
	_orbital_mining_status = status
	var laser: Button = _actions["mining_pulse"]
	var collector: Button = _actions["fragment_collect"]
	var fragment := bool(status.get("fragment", false))
	var installed := bool(status.get("installed", false))
	var visible := bool(status.get("visible", false)) and (installed or bool(status.get("collector", false)) or fragment)
	laser.visible = visible and installed and not fragment
	collector.visible = visible and fragment
	_orbital_mining_tools.visible = laser.visible or collector.visible
	_orbital_mining_readout.visible = visible
	if not visible:
		return
	var resource := str(status.resource)
	var distance := roundi(float(status.distance))
	var reason := ""
	if fragment:
		_orbital_mining_readout.text = ("Обломок · %s · %d м · %.1f м/с" % [resource, distance, float(status.relative_speed)]).replace(".", ",")
		reason = "" if status.collect_ok else str(status.collect_reason)
		collector.tooltip_text = "Перенести обломок в трюм" if status.collect_ok else reason
	else:
		_orbital_mining_readout.text = "Добыча · %s · %d м" % [resource, distance]
		var cooldown := float(status.ready_in)
		reason = "" if status.fire_ok else str(status.fire_reason)
		if cooldown > 0.0:
			_orbital_mining_readout.text += (" · %.1f с" % cooldown).replace(".", ",")
		laser.tooltip_text = "Отколоть породу горным лазером" if status.fire_ok else reason
	if not reason.is_empty():
		_orbital_mining_readout.text += "\n" + reason
	_orbital_mining_readout.add_theme_color_override("font_color", CYAN if reason.is_empty() else AMBER)

func _sync_passengers(sim: RefCounted) -> void:
	var status: Dictionary = sim.passenger_status()
	_passenger_route.visible = bool(status.active)
	if not _passenger_route.visible:
		return
	var overdue := bool(status.overdue)
	var remaining := ceili(maxf(0.0, float(status.remaining)))
	var color := ALERT if overdue else (AMBER if remaining <= 60 else CYAN)
	if _passenger_route.get_theme_color("font_color") != color:
		_passenger_route.add_theme_color_override("font_color", color)
	if overdue:
		_passenger_route.text = "Пассажиры · Просрочка · Высадка в порту"
	else:
		_passenger_route.text = "Пассажиры → %s · %d с" % [sim.target_name(status.destination), remaining]

func _sync_departure(sim: RefCounted, departure: Dictionary) -> void:
	var hangar := Ground.is_hangar(departure.port)
	_route.text = "%s / %s" % ["Взлёт" if hangar else "Выход", sim.target_name(departure.port)]
	_route_detail.text = "После выхода → %s" % sim.target_name(sim.planned_target) if sim.planned_target >= 0 else ""
	_telemetry.text = "Корабль в ангаре" if hangar else "Корабль у причала"
	if departure.phase == "transit":
		var speed: float = sim.speed_relative_to(departure.port)
		_telemetry.text = "%s · %s м/с" % ["Подъём" if hangar else "У дока", ("%.1f" % speed).replace(".", ",")]
	match departure.phase:
		"opening":
			_guidance.text = "Створ открывается · %d%%" % roundi(_operation_progress.value * 100.0)
		"transit":
			_guidance.text = "Проход через створ · %d%%" % roundi(_operation_progress.value * 100.0)
		_:
			_guidance.text = str(departure.reason)
			if departure.wait > 0.0:
				_guidance.text += " · %d с" % ceili(departure.wait)

func _sync_fuel(ship: RefCounted) -> void:
	var capacity: float = ship.capacity()
	_drive_tank_caption.text = "Резерв тяги" if ship.fuel <= 0.0 else "Бак тяги"
	_fuel.text = ("%.1f / %.0f" % [ship.fuel, capacity]).replace(".", ",") + " ед."
	_sync_tank_gauge(_fuel, _fuel_level, _fuel_fill, ship.fuel, capacity)
	var jump_reserve: float = ship.active_jump_fuel()
	var jump_capacity: float = ship.active_jump_capacity()
	_jump_tank_caption.text = "Военный бак" if ship.drive_kind == "military" else "Прыжковый бак"
	_jump_fuel.text = ("%.1f / %.0f" % [jump_reserve, jump_capacity]).replace(".", ",") + " ед."
	_sync_tank_gauge(_jump_fuel, _jump_fuel_level, _jump_fuel_fill, jump_reserve, jump_capacity)
	var pump_mode := str(ship.pump_mode)
	_pump_mode.visible = ship.fuel_pump and pump_mode != "off"
	if _pump_mode.visible:
		_pump_mode.text = "Автоперекачка · реактивный бак" if pump_mode == "reaction" else "Автоперекачка · прыжковый бак"

func _sync_tank_gauge(label: Label, gauge: ProgressBar, fill: StyleBoxFlat, amount: float, capacity: float) -> void:
	gauge.max_value = maxf(1.0, capacity)
	gauge.value = amount
	var low := amount <= capacity * 0.15
	var fill_color := AMBER if low else CYAN
	if fill.bg_color != fill_color:
		fill.bg_color = fill_color
		fill.border_color = fill_color
		label.add_theme_color_override("font_color", fill_color if low else INK)

func _sync_condition(hull: float, cargo: int, capacity: int) -> void:
	_condition.text = "Корпус %d%% · Трюм %d / %d ед." % [roundi(hull), cargo, capacity]
	var color := AMBER if hull < 40.0 else INK
	if _condition.get_theme_color("font_color") != color:
		_condition.add_theme_color_override("font_color", color)

func _prefer_entry_meter(stellar: Dictionary, entry: Dictionary, scooping: bool) -> bool:
	var stellar_close: bool = stellar.get("visible", false) and stellar.distance <= Sector.SCOOP_OUTER
	var stellar_priority: bool = stellar_close and (scooping or stellar.danger or stellar.blocked)
	return entry.get("visible", false) and not stellar_priority

func _sync_thermal(stellar: Dictionary, entry: Dictionary, scooping: bool, atmosphere: bool) -> void:
	var status := entry if atmosphere else stellar
	_thermal_panel.visible = status.get("visible", false)
	_entry_readout.visible = atmosphere and (entry.near or entry.inside)
	if _entry_readout.visible:
		_entry_readout.text = "%s · высота %s м\nСкорость %s · вертикальная %s м/с" % [
			entry.name, ("%.1f" % entry.altitude).replace(".", ","),
			("%.1f" % entry.relative_speed).replace(".", ","), ("%+.1f" % entry.vertical_speed).replace(".", ","),
		]
		if entry.inside and entry.get("shielded", false):
			_entry_readout.text += "\nТеплозащита · −%d%% нагрузки" % int(entry.heat_reduction)
	var guidance_color := INK
	if _thermal_panel.visible:
		var entering: bool = atmosphere and (entry.inside or (entry.near and entry.vertical_speed < 0.0))
		var too_fast: bool = entering and entry.relative_speed > entry.safe_speed
		var meter_color := CYAN
		var suffix := " · остывает" if status.cooling else ""
		if status.get("danger", false) or status.level == "critical":
			meter_color = ALERT
			suffix = " · критический" if status.level == "critical" else " · опасность"
		elif too_fast or status.level == "warm" or status.level == "hot":
			meter_color = AMBER
		var caption := "Нагрев корпуса" if atmosphere else "Нагрев"
		if atmosphere and status.level == "critical":
			caption = "Критический нагрев"
			suffix = ""
		_thermal_label.text = "%s %d%%%s" % [caption, roundi(status.heat), suffix]
		_thermal_level.value = status.heat
		if _thermal_fill.bg_color != meter_color:
			_thermal_fill.bg_color = meter_color
			_thermal_fill.border_color = meter_color
			_thermal_label.add_theme_color_override("font_color", meter_color)
		if not _jumping:
			guidance_color = _entry_guidance(entry, too_fast) if atmosphere else _stellar_guidance(stellar, scooping)
	if _guidance.get_theme_color("font_color") != guidance_color:
		_guidance.add_theme_color_override("font_color", guidance_color)

func _entry_guidance(entry: Dictionary, too_fast: bool) -> Color:
	if entry.level == "critical":
		_guidance.text = "Критический нагрев. Дождитесь остывания корпуса."
		if too_fast:
			_guidance.text = "Критический нагрев. Снизьте скорость до %d м/с." % int(entry.safe_speed)
		return ALERT
	if too_fast:
		_guidance.text = "Снизьте скорость до %d м/с для безопасного входа." % int(entry.safe_speed)
		return AMBER
	return INK

func _stellar_guidance(status: Dictionary, scooping: bool) -> Color:
	if status.level == "critical":
		_guidance.text = "Критический перегрев. Корпус повреждается. Уходите от звезды."
		return ALERT
	if status.danger:
		_guidance.text = "Опасная близость к звезде. Развернитесь от неё и увеличьте тягу."
		return ALERT
	if status.blocked:
		_guidance.text = "Перегрев. Отойдите от звезды и дождитесь остывания."
		if status.cooling and status.distance > Sector.SCOOP_OUTER:
			_guidance.text = "Корпус остывает. Сбор топлива пока заблокирован."
		return ALERT
	if status.level == "hot" and scooping:
		_guidance.text = "Высокий нагрев. Остановите сбор и отойдите от звезды."
		return AMBER
	return INK

func _sync_clock(sim: RefCounted) -> void:
	var calendar: Dictionary = sim.clock_status()
	var paused := bool(calendar.paused)
	if _time_paused != paused:
		_time_paused = paused
		clear_held_input()
		_clock.add_theme_color_override("font_color", AMBER if paused else MUTED)
	_clock.text = "%s\n%s" % [calendar.date, calendar.clock]
	var status: Dictionary = sim.time_status()
	var scale: int = calendar.scale
	var button: Button = _actions["time"]
	var pause_button: Button = _actions["time_pause"]
	pause_button.text = "Продолжить" if paused else "Пауза"
	pause_button.tooltip_text = "Продолжить игровое время (F9)" if paused else "Остановить игровое время (F9)"
	_time_blocked = paused or (not status.allowed and scale <= 1)
	button.text = "%d×" % scale
	_time_hint.visible = not paused and not _jumping and not status.allowed
	_time_hint.text = "Ускорение недоступно. %s" % status.reason if _time_hint.visible else ""
	button.tooltip_text = _time_hint.text if _time_hint.visible else "Сменить скорость игрового времени (O). Доступно до ×%d." % int(status.get("max_rate", 1))
	if paused:
		button.tooltip_text = "Продолжите игру для смены скорости"

func _sync_port(sim: RefCounted, sale_quote: int, itinerary: Dictionary, transfer: bool) -> void:
	var berth := "Порт"
	if Ground.is_port(sim.docked):
		berth = "Ангар" if Ground.is_hangar(sim.docked) else "Площадка"
	_route.text = "%s  /  %s" % [berth, sim.target_name(sim.docked)]
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
	elif sim.offer_destination() >= 0:
		var destination: String = sim.target_name(sim.offer_destination())
		_route_detail.text = "%s → %s\nОплата %d кр." % [sim.contract_cargo(), destination, sim.contract_reward()]
		_guidance.text = "Возьмите контракт. После вылета можно включить «Авто»." if sim.deliveries == 0 else "Выберите пункт назначения на карте."
	else:
		_route_detail.text = "Новых доставок здесь нет."
		_guidance.text = ""
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
	if _rig_status.active:
		if _rig_status.near:
			_guidance.text = "Выгрузите сырьё или оставьте бур на грунте." if int(_rig_status.stored) > 0 else "Можно забрать бур или оставить его на грунте."
			if int(_rig_status.stored) > 0 and not _rig_status.can_unload:
				_guidance.text = "Трюм заполнен. Бур хранит добытое сырьё."
		elif int(_rig_status.site) == int(sim.landed_site):
			_guidance.text = "Взлетите и выберите «К буру» для посадки рядом с установкой."
		else:
			_guidance.text = "Бур оставлен на другом теле. Можно взлететь."
		return
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

func _sync_flight(sim: RefCounted, scoop_status: Dictionary, itinerary: Dictionary, patrol: Dictionary, fire: Dictionary, convoy: Dictionary, rendezvous: Dictionary, entry_site: int, surface: Dictionary, frame: Dictionary, jump: Dictionary, speed_hold: Dictionary) -> void:
	if _jumping:
		_sync_jump(jump)
		return
	var project_course := bool(sim.get("project_course"))
	var convoy_course: bool = sim.convoy_course
	var aimed_at_port := Sector.is_port(sim.target) and fire.is_empty() and not bool(sim.patrol_course) and not project_course and not convoy_course and not bool(sim.orbit_maneuver)
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
	var reference: int = frame.reference
	var entry_frame: bool = entry_site >= 0 and reference == entry_site and not frame.surface
	_telemetry.text = ""
	var holding := bool(speed_hold.get("enabled", false))
	if holding:
		_speed_caption.text = "Факт. скорость"
		_speed_value.text = ("%+.1f м/с" % snappedf(float(speed_hold.actual), 0.1)).replace(".", ",")
		_thrust_caption.text = "Задано"
		_thrust_value.text = ("%+.1f м/с" % snappedf(float(speed_hold.setpoint), 0.1)).replace(".", ",")
	else:
		_sync_motion_values(float(frame.relative_speed), sim.throttle, near_surface or entry_frame)
	if aimed_at_port and not Ground.is_port(sim.target) and not _docking_panel.visible:
		_telemetry.text = "Крен к порту %+.0f°" % rad_to_deg(sim.roll_error(sim.target))
	elif near_surface:
		if not _surface_panel.visible:
			if entry_frame:
				_telemetry.text = "Уклон %.0f°" % surface.slope
			else:
				var altitude := ("%.1f" % maxf(0.0, float(surface.altitude))).replace(".", ",")
				_telemetry.text = "Высота %s м · уклон %.0f°" % [altitude, surface.slope]
		_actions["dock"].tooltip_text = str(surface.reason)
	var ambient_fire := str(fire.get("channel", "")) == "ambient"
	if not fire.is_empty() and not ambient_fire and convoy.is_empty():
		_route.text = "Дозор  /  Рейдер"
		_route_detail.text = "Дистанция %d м · корпус %d%%" % [roundi(fire.get("distance", 0.0)), ceili(patrol.get("enemy_hull", 0.0))]
		_guidance.text = "Цель в прицеле. Удерживайте «Огонь»." if fire.ok else str(fire.get("reason", ""))
	elif sim.orbit_maneuver:
		_sync_orbit_flight(sim.orbit_status(), sim.throttle)
	elif not rendezvous.is_empty():
		_sync_rendezvous_flight(rendezvous, sim.throttle)
	elif not convoy.is_empty() and (convoy_course or (not ambient_fire and not fire.is_empty())):
		_sync_convoy_flight(convoy, {} if ambient_fire else fire)
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
		_guidance.text = "Сбор водорода · %d%%\nВ трюме %d кан. · свободно %d мест" % [
			floori(100.0 * float(scoop_status.get("progress", 0.0))),
			int(scoop_status.get("cargo_units", 0)), int(scoop_status.get("free", 0)),
		]
	elif not convoy.is_empty() and not sim.autopilot:
		_sync_convoy_flight(convoy, {} if ambient_fire else fire)
	elif scoop_status.get("near", false) or sim.is_scoop_site(sim.target):
		_guidance.text = _scoop_hint(scoop_status)
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
			_guidance.text = "Можно садиться." if Ground.is_port(sim.target) else "Порт готов к швартовке."
		else:
			_guidance.text = str(status.get("reason", ""))
	elif patrol.get("phase") in [Patrol.OUTBOUND, Patrol.RETURN] and _actions["patrol"].visible:
		_guidance.text = str(patrol.get("reason", ""))
	elif sim.ship.fuel <= 0.0:
		_guidance.text = "Резервная тяга. Откройте «Топливо» для перелива водорода."
	elif not surface.is_empty():
		_guidance.text = "Подойдите к поверхности вручную."
		if not _autopilot_blocked:
			_guidance.text += " Для захода на площадку можно включить «Авто»."
	elif ambient_fire:
		_guidance.text = "Рейдер в прицеле. Удерживайте «Огонь»." if fire.ok else str(fire.get("reason", ""))
	elif _translation_mode:
		_guidance.text = "Круглая панель — сдвиг вбок и по высоте. «Вперёд» и «Назад» удерживайте."
	elif holding:
		_guidance.text = "Кнопки «Скорость ±» меняют задание. Тормоз отключает удержание."
	else:
		_guidance.text = "Курс и крен справа. Тяга и тормоз слева." if _touch_mirrored else "Курс и крен слева. Тяга и тормоз справа."
	if not _telemetry.text.is_empty():
		_telemetry.text += "\n"
	var frame_label := "Ручной отсчёт" if sim.orbit_maneuver or not rendezvous.is_empty() else "Отсчёт"
	_telemetry.text += "%s · %s" % [frame_label, _frame_caption(frame)]

func _sync_jump(jump: Dictionary) -> void:
	var destination := str(Sector.system(int(jump.destination)).name)
	var remaining := ("%.1f" % float(jump.remaining)).replace(".", ",")
	var arrival := MissionCalendar.stamp(float(jump.get("arrival_epoch", -1.0)))
	var duration_seconds := ceili(float(jump.duration))
	var duration := "%d мин %02d с" % [floori(duration_seconds / 60.0), duration_seconds % 60]
	if duration_seconds < 60:
		duration = "%d с" % duration_seconds
	if _jump_transit:
		_route.text = "Гиперпространство"
		_route_detail.text = "До выхода %s с · %s" % [remaining, destination]
		_telemetry.text = "Время перелёта · %s" % duration
		_guidance.text = "Топливо списано · %d ед." % int(jump.fare)
	else:
		_route.text = "Зарядка  /  %s" % destination
		_route_detail.text = "До старта %s с · расход %d ед." % [remaining, int(jump.fare)]
		_telemetry.text = "Время перелёта · %s" % duration
		_guidance.text = "Тормоз отменяет зарядку."
	if not arrival.is_empty():
		_route_detail.text += "\nПрибытие · %s" % arrival

func _frame_caption(frame: Dictionary) -> String:
	if frame.rotating:
		return "Вращение «%s»" % frame.name
	var name := "система" if int(frame.reference) < 0 else "«%s»" % frame.name
	if frame.surface:
		name = "поверхность %s" % name
	match str(frame.mode):
		"auto": return "Авто · %s" % name
		"body": return name
	return "Система"

func _scoop_hint(status: Dictionary) -> String:
	if status.ok:
		return "Зона сбора водорода · свободно %d мест" % int(status.free)
	if status.near or not status.get("installed", true):
		return str(status.reason)
	if status.kind == "gas":
		var radius := float(status.distance) - float(status.altitude)
		return "Слой сбора %d–%d м над облаками · до %d м/с." % [
			roundi(float(status.inner) - radius), roundi(float(status.outer) - radius), int(status.max_speed),
		]
	return "Зона сбора %d–%d м от центра · до %d м/с." % [status.inner, status.outer, status.max_speed]

func _sync_orbit_flight(orbit: Dictionary, throttle: float) -> void:
	_route.text = "Орбита  /  %s" % orbit.name
	var altitude := "%d м" % roundi(orbit.altitude) if orbit.altitude < 1000.0 else "%.2f км" % (orbit.altitude / 1000.0)
	_route_detail.text = ("Осталось Δv %.1f м/с · круговая %.1f м/с\nВысота %s · радиальная %+.1f м/с" % [
		orbit.delta_v, orbit.circular_speed, altitude, orbit.radial_speed,
	]).replace(".", ",")
	_sync_relative_motion(orbit.name, orbit.relative_speed, throttle)
	var phase := "Разворот на манёвр" if orbit.maneuver_phase == "turn" else "Корректируем скорость"
	var hint := "Ручное управление прервёт манёвр."
	var periapsis := float(orbit.periapsis)
	var future_approach: bool = orbit.classification == "bound" or orbit.radial_speed < 0.0
	if future_approach and periapsis >= 0.0:
		var stellar: bool = orbit.focus_kind == "star"
		if periapsis <= float(orbit.collision_radius):
			hint = "Без тяги возможно столкновение со звездой." if stellar else "Без тяги возможен удар о поверхность."
		elif stellar and periapsis < Sector.SCOOP_INNER:
			hint = "Без тяги траектория проходит через зону сильного нагрева."
	_guidance.text = "%s. %s" % [phase, hint]

func _sync_rendezvous_actions(status: Dictionary) -> void:
	_actions["rendezvous_cancel"].visible = not status.is_empty()
	var finish: Button = _actions["rendezvous_finish"]
	finish.visible = status.get("phase") == "hold"
	_rendezvous_finish_blocked = not status.get("can_finish", false)
	if finish.visible:
		finish.text = _rendezvous_finish_caption(status.kind)
		finish.tooltip_text = str(status.reason) if _rendezvous_finish_blocked else "Передать управление автопилоту для финального захода"

func _sync_rendezvous_flight(status: Dictionary, throttle: float) -> void:
	var holding: bool = status.phase == "hold"
	_route.text = "%s  /  %s" % ["Ожидание" if holding else "Сближение", status.name]
	var distance := "—"
	if status.has_point:
		distance = ("%.1f м" % status.distance).replace(".", ",") if status.distance < 100.0 else "%d м" % roundi(status.distance)
	_route_detail.text = "До точки %s · отступ %d м" % [distance, status.gap]
	if not holding and status.eta > 0.0:
		_route_detail.text += "\nПодход примерно через %d с" % ceili(status.eta)
	_sync_relative_motion(status.name, status.relative_speed, throttle)
	_guidance.text = str(status.reason)
	if holding and status.can_finish:
		_guidance.text = "Точка ожидания удерживается. Для захода нажмите «%s»." % _rendezvous_finish_caption(status.kind)

func _sync_relative_motion(label: String, speed: float, throttle: float) -> void:
	_sync_motion_values(speed, throttle, true)
	_telemetry.text = "Относительно «%s»" % label

func _sync_motion_values(speed: float, throttle: float, precise: bool) -> void:
	_speed_caption.text = "Скорость"
	_speed_value.text = ("%.1f м/с" % speed).replace(".", ",") if precise else "%d м/с" % roundi(speed)
	_thrust_caption.text = "Тяга"
	_thrust_value.text = "%d%%" % (throttle * 100.0)

static func _rendezvous_finish_caption(kind: String) -> String:
	return "К швартовке" if kind == "port" else "К посадке"

func _sync_convoy_flight(convoy: Dictionary, fire: Dictionary) -> void:
	var escort: bool = convoy.kind == "escort"
	_route.text = "%s  /  %s" % ["Эскорт" if escort else "Перехват", convoy.name]
	var distance := roundi(convoy.distance)
	_route_detail.text = "Дистанция %d м" % distance if distance >= 0 else ""
	if not _route_detail.text.is_empty():
		_route_detail.text += " · "
	if escort:
		_route_detail.text += "Рядом %d из %d с" % [floori(convoy.escort_time), ceili(convoy.escort_total)]
	else:
		_route_detail.text += "Корпус цели %d%%" % ceili(convoy.enemy_hull)
	_guidance.text = str(convoy.reason)
	if not fire.is_empty():
		_guidance.text = "Цель в прицеле. Удерживайте «Огонь»." if fire.ok else str(fire.get("reason", convoy.reason))

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

func set_camera_view(mode: int, shows_forward_aim: bool, bearing: String) -> void:
	var button: Button = _actions["camera"]
	button.text = FlightCamera.translated_name(mode)
	var next_mode := FlightCamera.translated_name(FlightCamera.next_basic(mode))
	button.tooltip_text = Text.text("CAMERA_NEXT") % next_mode
	_marks.forward_aim = shows_forward_aim
	_camera_instrument.text = bearing
	_camera_instrument.visible = not bearing.is_empty()

func set_traffic_markers(markers: Array[Dictionary]) -> void:
	_marks.traffic = markers.duplicate()
	_marks.traffic.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_priority: int = MARK_PRIORITY.get(left.role, 2)
		var right_priority: int = MARK_PRIORITY.get(right.role, 2)
		return left_priority < right_priority if left_priority != right_priority else float(left.distance) < float(right.distance))
	_marks.queue_redraw()

func set_navigation_targets(sites: Array, selected: int, computer_installed := true, missile_ready := false) -> void:
	var equipment_changed := computer_installed != _navigation_computer_ready or missile_ready != _missile_camera_ready
	_navigation_computer_ready = computer_installed
	_missile_camera_ready = missile_ready
	if equipment_changed:
		_show_scanner(_scanner_panel.visible)
		_refresh_disabled_actions()
	if _navigation_sites != sites:
		_navigation_sites.assign(sites)
		_navigation_list.clear()
		for site: int in _navigation_sites:
			var body := Sector.site(site)
			_navigation_list.add_item("%s  ·  %s" % [body.name, Sector.kind_name(body.kind)])
		_refresh_disabled_actions()
	var index := _navigation_sites.find(selected)
	if index < 0:
		_navigation_list.deselect_all()
	elif not _navigation_list.is_selected(index):
		_navigation_list.select(index)

func scanner_is_open() -> bool:
	return _navigation_drawer.visible and _scanner_panel.visible

func radio_contact_id() -> String:
	return _scanner_focus if scanner_is_open() and _scanner_ids.has(_scanner_focus) else ""

func set_combat_lock(id: String, caption: String, marker: Dictionary) -> void:
	_combat_lock = id
	_combat_lock_readout.text = Text.text("SCANNER_LOCKED") % caption
	_combat_lock_readout.visible = not id.is_empty()
	_marks.combat_lock = marker
	_marks.queue_redraw()

func set_scanner_status(status: Dictionary) -> void:
	_mapper_fitted = status.radar_mapper
	_scanner_range = status.range
	_scanner_rows = status.contacts
	var ids: Array[String] = []
	for row: Dictionary in _scanner_rows:
		ids.append(row.id)
	if ids != _scanner_ids:
		_scanner_ids = ids
		_scanner_list.clear()
		for row: Dictionary in _scanner_rows:
			_scanner_list.add_item(row.name)
	if not _scanner_ids.has(_scanner_focus):
		_scanner_focus = _combat_lock if _scanner_ids.has(_combat_lock) else ""
	_refresh_scanner_selection()

func _refresh_scanner_selection() -> void:
	var index := _scanner_ids.find(_scanner_focus)
	_scanner_can_lock = false
	if index >= 0:
		var contact := _scanner_rows[index]
		_scanner_list.select(index)
		_scanner_can_lock = contact.attackable and _scanner_focus != _combat_lock
		var relative: Vector3 = contact.relative
		_scanner_detail.text = Text.text("SCANNER_ALTITUDE") % [roundi(contact.distance), relative.y]
		if _mapper_fitted:
			var names := {"raider": "SCANNER_RAIDER", "convoy": "SCANNER_CONVOY", "trader": "SCANNER_TRADER",
				"patrol": "SCANNER_PATROL", "relay": "SCANNER_RELAY"}
			var role := Text.text(names.get(contact.role, "SCANNER_SHIP"))
			_scanner_detail.text += "\n" + Text.text("SCANNER_DETAIL") % [role, contact.relative_speed, contact.hull]
		else:
			_scanner_detail.text += "\n" + Text.text("SCANNER_MAPPER")
	else:
		_scanner_list.deselect_all()
		_scanner_detail.text = Text.text("SCANNER_NONE" if _scanner_ids.is_empty() else "SCANNER_PICK")
	_scanner_radar.read_contacts(_scanner_rows, _scanner_range, _scanner_focus, _combat_lock)
	_refresh_disabled_actions()

func _select_scanner_row(index: int) -> void:
	if scanner_is_open() and _input_enabled and index >= 0 and index < _scanner_ids.size():
		_scanner_focus = _scanner_ids[index]
		_refresh_scanner_selection()

func _show_scanner(active: bool) -> void:
	_scanner_panel.visible = active
	_navigation_list.visible = not active and _navigation_computer_ready
	_navigation_hint.visible = not active and not _navigation_computer_ready
	_navigation_switches.visible = not active
	_navigation_cameras.visible = not active
	_actions["scanner_toggle"].text = Text.text("NAV_LIST" if active else "SCANNER")

func _refresh_navigation_language() -> void:
	_navigation_title.text = Text.text("NAV_TITLE")
	_navigation_hint.text = Text.text("NAV_NO_COMPUTER")
	_actions["navigation_toggle"].text = Text.text("NAV_SHORTCUT")
	_actions["navigation_close"].text = Text.text("NAV_CLOSE")
	_actions["camera_observer"].text = Text.text("CAMERA_OBSERVER")
	_actions["camera_missile"].text = Text.text("CAMERA_MISSILE")
	_actions["camera_missile"].tooltip_text = Text.text("CAMERA_LOCK_REQUIRED")
	_actions["combat_lock"].text = Text.text("SCANNER_LOCK")
	_actions["combat_unlock"].text = Text.text("SCANNER_CLEAR")

func apply_interface_language() -> void:
	_refresh_navigation_language()
	_update_navigation_switches()
	_actions["aim_lock"].text = Text.text("AIM_LOCK")
	_actions["aim_lock"].tooltip_text = Text.text("AIM_LOCK_TOOLTIP")
	_actions["comms"].text = Text.text("LINK_SHORTCUT")
	_actions["comms_contact"].text = Text.text("LINK_SHORTCUT")
	_show_scanner(_scanner_panel.visible)

func set_navigation_markers(markers: Array[Dictionary]) -> void:
	var exclude: Array[Rect2] = []
	for control: Control in _navigation_blockers:
		if control.is_visible_in_tree():
			exclude.append(control.get_global_rect())
	_marks.set_navigation(markers, _safe.get_global_rect().grow(-20.0), exclude)

func navigation_corridor_enabled() -> bool:
	return _navigation_corridor_enabled

func ship_markers_enabled() -> bool:
	return _marks.ship_markers

func toggle_navigation() -> void:
	if not _input_enabled or _parked or _jumping or _in_escape:
		return
	if _navigation_drawer.visible:
		close_navigation()
	elif not _navigation_sites.is_empty():
		_refresh_navigation_language()
		_show_scanner(false)
		_navigation_drawer.show()

func close_navigation() -> bool:
	if not _navigation_drawer.visible:
		return false
	_navigation_drawer.hide()
	return true

func _select_navigation_row(index: int) -> void:
	if _navigation_drawer.visible and _navigation_computer_ready and _input_enabled and index >= 0 and index < _navigation_sites.size():
		_request_navigation(_navigation_sites[index], false)

func _request_navigation(site: int, from_view: bool) -> void:
	close_navigation()
	navigation_requested.emit(site, from_view)

func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	if not is_instance_valid(_hud):
		return
	if not enabled:
		clear_held_input()
		close_navigation()
		_actions["aim_lock"].hide()
		_docking_panel.hide()
		_surface_panel.hide()
		_actions["dock_sync"].hide()
		_actions["dock_clearance"].hide()
		_actions["gear"].hide()
	_refresh_disabled_actions()

func set_touch_preferences(sensitivity: int, mirrored: bool) -> void:
	_touch_gain = TOUCH_GAINS[clampi(sensitivity, 0, TOUCH_GAINS.size() - 1)]
	if _touch_mirrored == mirrored:
		return
	_touch_mirrored = mirrored
	if is_instance_valid(_hud):
		clear_held_input()
		_apply_touch_layout()

func _apply_touch_layout() -> void:
	_place_touch_control(_steer, COURSE_PAD, false)
	_place_touch_control(_bank, ROLL_PAD, false)
	_place_touch_control(_camera_controls, CAMERA_CONTROL, false)
	_place_touch_control(_flight_modes, FLIGHT_MODE_ROW, false)
	_place_touch_control(_translation_controls, TRANSLATION_ROW, false)
	_place_touch_control(_right_panel, ACTION_COLUMN, true)

func _place_touch_control(control: Control, placement: Rect2, starts_right: bool) -> void:
	var anchor := 1.0 if starts_right != _touch_mirrored else 0.0
	control.anchor_left = anchor
	control.anchor_right = anchor
	control.offset_left = -placement.end.x if _touch_mirrored else placement.position.x
	control.offset_right = -placement.position.x if _touch_mirrored else placement.end.x

func _sync_ordnance(missile: Dictionary, decoy: Dictionary, pulse: Dictionary) -> void:
	var next_button: Button = _actions["missile_next"]
	var fire_button: Button = _actions["missile_fire"]
	var decoy_button: Button = _actions["decoy"]
	var armed := int(missile.get("slot", -1))
	var loaded := int(missile.get("ammo", 0))
	var count := int(decoy.get("count", 0))
	fire_button.visible = bool(missile.get("fitted", false))
	next_button.visible = fire_button.visible
	decoy_button.visible = count > 0 or bool(decoy.get("active", false))
	var pulse_button: Button = _actions["energy_pulse"]
	pulse_button.visible = int(pulse.get("count", 0)) > 0 or bool(pulse.get("active", false))
	pulse_button.text = "Импульс %d" % int(pulse.get("count", 0))
	pulse_button.tooltip_text = str(pulse.get("reason", ""))
	_pulse_blocked = not bool(pulse.get("ready", false))
	_ordnance_tools.visible = fire_button.visible or decoy_button.visible or pulse_button.visible
	_missile_next_blocked = int(missile.get("next_slot", -1)) < 0
	_missile_blocked = not bool(missile.get("ready", false))
	_decoy_blocked = not bool(decoy.get("ready", false))
	next_button.text = "Место %d" % (armed + 1) if armed >= 0 else "Пусто"
	next_button.tooltip_text = "Следующее заряженное место (])"
	fire_button.text = "Пуск %d" % loaded
	fire_button.tooltip_text = str(missile.get("reason", "")) if _missile_blocked else "Пуск «%s» (Z)" % missile.name
	decoy_button.text = "Ловушка %d" % count
	decoy_button.tooltip_text = str(decoy.get("reason", "")) if _decoy_blocked else "Выбросить ложную цель ([)"


func _refresh_disabled_actions() -> void:
	for action: String in _actions:
		var button: Button = _actions[action]
		var blocked := (action == "dock" and (_lift_blocked or _departure_blocked)) or (action == "mine" and _mining_blocked)
		blocked = blocked or (action == "scoop" and _scoop_blocked) or (action == "time" and _time_blocked)
		blocked = blocked or (action == "patrol" and _patrol_blocked) or (action == "convoy" and _convoy_blocked)
		blocked = blocked or (action == "ecm" and (_ecm_blocked or _time_paused))
		blocked = blocked or (action == "missile_next" and (_missile_next_blocked or _time_paused))
		blocked = blocked or (action == "missile_fire" and _missile_blocked) or (action == "decoy" and _decoy_blocked)
		blocked = blocked or (action == "energy_pulse" and _pulse_blocked) or (action == "rescue_signal" and _rescue_signal_blocked)
		blocked = blocked or (_in_escape and action not in ["rescue_signal", "settings", "report", "time_pause"])
		blocked = blocked or (action == "rendezvous_finish" and _rendezvous_finish_blocked)
		blocked = blocked or (action == "dock_sync" and _dock_sync_blocked)
		blocked = blocked or (action == "dock_clearance" and _dock_clearance_blocked)
		blocked = blocked or (action == "gear" and _gear_blocked)
		blocked = blocked or (action == "frame" and _frame_blocked)
		blocked = blocked or (action == "autopilot" and _autopilot_blocked)
		blocked = blocked or (action == "speed_hold" and (_speed_hold_blocked or _time_paused))
		blocked = blocked or (action == "navigation_toggle" and (_parked or _navigation_sites.is_empty()))
		blocked = blocked or (action == "combat_lock" and not _scanner_can_lock)
		blocked = blocked or (action == "combat_unlock" and _combat_lock.is_empty())
		blocked = blocked or (action == "comms_contact" and _scanner_focus.is_empty())
		blocked = blocked or (action == "camera_missile" and not _missile_camera_ready)
		blocked = blocked or (RIG_ACTIONS.has(action) and not _rig_status.get(RIG_ACTIONS[action], false))
		blocked = blocked or (PROCESSOR_ACTIONS.has(action) and not _processor_status.get(PROCESSOR_ACTIONS[action], false))
		blocked = blocked or (ORBITAL_MINING_ACTIONS.has(action) and not _orbital_mining_status.get(ORBITAL_MINING_ACTIONS[action], false))
		var manual_action := action in HOLD_ACTIONS or action in ["throttle_down", "throttle_up"]
		var charge_control := action in ["throttle_down", "throttle_up", "boost", "brake"] and not _jump_transit
		var during_jump := _jumping and action != "time_pause" and not charge_control
		var during_departure := _departure_active and action != "time_pause" and (action != "dock" or not _departure_can_cancel)
		button.disabled = not _input_enabled or blocked or during_jump or during_departure or (_time_paused and manual_action)

func move_input() -> Vector2:
	if _parked or _in_escape or _jump_transit or _time_paused or not _input_enabled:
		return Vector2.ZERO
	var horizontal := float(_key(KEY_D, KEY_RIGHT)) - float(_key(KEY_A, KEY_LEFT))
	var vertical := float(_key(KEY_W, KEY_UP)) - float(_key(KEY_S, KEY_DOWN))
	var touch := Vector2.ZERO if _translation_mode else _steer.axis * _touch_gain
	return (touch + Vector2(horizontal, vertical)).limit_length()

func translation_input() -> Vector3:
	if _parked or _in_escape or _jumping or _time_paused or not _input_enabled:
		return Vector3.ZERO
	var horizontal := float(_key(KEY_6, KEY_KP_6)) - float(_key(KEY_4, KEY_KP_4))
	var vertical := float(_key(KEY_8, KEY_KP_8)) - float(_key(KEY_2, KEY_KP_2))
	var depth := float(_key(KEY_9, KEY_KP_9)) - float(_key(KEY_3, KEY_KP_3))
	var keyboard := Vector3(horizontal, vertical, depth)
	if not _translation_mode:
		return keyboard.limit_length()
	var stick := _steer.axis * _touch_gain
	return (keyboard + Vector3(stick.x, stick.y, _translation_depth)).limit_length()

func roll_input() -> float:
	if _parked or _in_escape or _jump_transit or _time_paused or not _input_enabled:
		return 0.0
	var keyboard := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	return clampf(_bank.axis.x * _touch_gain + keyboard, -1.0, 1.0)

func boost_held() -> bool:
	return not _parked and not _in_escape and not _jump_transit and not _time_paused and _input_enabled and (_boost or Input.is_physical_key_pressed(KEY_SHIFT))

func brake_held() -> bool:
	return not _parked and not _in_escape and not _jump_transit and not _time_paused and _input_enabled and (_brake or Input.is_physical_key_pressed(KEY_SPACE))

func fire_held() -> bool:
	var button: Button = _actions["fire"]
	return _fire_held and not button.disabled and button.is_visible_in_tree()

func release_fire() -> void:
	for pointer: int in _touch_owner.keys():
		if _touch_owner[pointer] == "fire":
			_touch_owner.erase(pointer)
	_mouse_held.erase("fire")
	_update_held()

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
		var handled := _touch_begin(event.index, event.position) if event.pressed and not event.canceled else _touch_end(event.index, event.position, event.canceled)
		if handled:
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _touch_owner.has(event.index):
		if event.index == _steer_finger:
			_steer.update_point(event.position)
		elif event.index == _bank_finger:
			_bank.update_point(event.position)
		elif _navigation_presses.has(event.index):
			_drag_navigation(event.index, event.position)
		elif _touch_owner[event.index] == "fire" and not _hit(_actions["fire"], event.position):
			_touch_end(event.index, event.position, true)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not _time_paused:
				if _hit(_steer, event.position):
					_mouse_pad = _steer
				elif _hit(_bank, event.position):
					_mouse_pad = _bank
			if is_instance_valid(_mouse_pad):
				_mouse_pad.update_point(event.position)
				get_viewport().set_input_as_handled()
			elif _begin_navigation_press(NAV_MOUSE, event.position, false):
				get_viewport().set_input_as_handled()
		elif is_instance_valid(_mouse_pad):
			_mouse_pad.reset()
			_mouse_pad = null
			get_viewport().set_input_as_handled()
		elif _end_navigation_press(NAV_MOUSE, event.position, false):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and is_instance_valid(_mouse_pad):
		_mouse_pad.update_point(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _navigation_presses.has(NAV_MOUSE):
		_drag_navigation(NAV_MOUSE, event.position)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and is_instance_valid(_hud):
		clear_held_input()

func clear_held_input() -> void:
	_touch_owner.clear()
	_navigation_presses.clear()
	_contact_action_presses.clear()
	_steer_finger = -1
	_bank_finger = -1
	_mouse_pad = null
	_mouse_held.clear()
	_steer.reset()
	_bank.reset()
	for button: Button in _actions.values():
		button.self_modulate = Color.WHITE
	_update_held()

func _touch_begin(index: int, point: Vector2) -> bool:
	if _touch_owner.has(index):
		return true
	if not _time_paused and _hit(_steer, point) and _steer_finger == -1:
		_steer_finger = index
		_touch_owner[index] = "steer"
		_steer.update_point(point)
		return true
	if not _time_paused and _hit(_bank, point) and _bank_finger == -1:
		_bank_finger = index
		_touch_owner[index] = "bank"
		_bank.update_point(point)
		return true
	for action: String in _actions:
		var button: Button = _actions[action]
		if not button.disabled and _hit(button, point):
			_touch_owner[index] = action
			if action in ["combat_lock", "comms_contact"]:
				_contact_action_presses[index] = _scanner_focus
			if action in HOLD_ACTIONS:
				_update_held(true)
			else:
				button.self_modulate = CYAN
			return true
	if _begin_navigation_press(index, point, true):
		_touch_owner[index] = "navigation_press"
		return true
	return false

func _touch_end(index: int, point: Vector2, canceled: bool) -> bool:
	if not _touch_owner.has(index):
		return false
	var action: String = _touch_owner[index]
	_touch_owner.erase(index)
	var selected_contact: String = _contact_action_presses.get(index, "")
	_contact_action_presses.erase(index)
	match action:
		"steer":
			_steer_finger = -1
			_steer.reset()
		"bank":
			_bank_finger = -1
			_bank.reset()
		"boost", "brake", "translation_forward", "translation_reverse", "fire":
			_update_held()
		"navigation_press":
			_end_navigation_press(index, point, canceled)
		_:
			var button: Button = _actions[action]
			if not _touch_owner.values().has(action):
				button.self_modulate = Color.WHITE
			var unchanged := action not in ["combat_lock", "comms_contact"] or selected_contact == _scanner_focus
			if not canceled and unchanged and not button.disabled and _hit(button, point):
				_commit_action(action)
	return true

func _begin_navigation_press(index: int, point: Vector2, allow_drawer: bool) -> bool:
	if _parked or _jumping:
		return false
	var from_view := not _hit(_navigation_drawer, point)
	if not from_view and not allow_drawer:
		return false
	var scanner := not from_view and scanner_is_open()
	var site := _navigation_marker_at(point) if from_view else (-1 if scanner else _navigation_row_at(point))
	var contact := _combat_marker_at(point) if from_view and site < 0 else ""
	if from_view and site < 0 and contact.is_empty():
		return false
	var press := NavigationPress.new()
	press.site = site
	press.point = point
	press.from_view = from_view
	press.scanner = scanner
	if scanner:
		press.contact = _scanner_row_at(point)
	else:
		press.contact = contact
	press.scroll_origin = (_scanner_list if scanner else _navigation_list).get_v_scroll_bar().value
	_navigation_presses[index] = press
	return true

func _drag_navigation(index: int, point: Vector2) -> void:
	var press := _navigation_presses[index]
	var movement := point - press.point
	press.dragged = press.dragged or movement.length() > NAV_DRAG_THRESHOLD
	if press.dragged and not press.from_view:
		var list := _scanner_list if press.scanner else _navigation_list
		list.get_v_scroll_bar().value = press.scroll_origin - movement.y

func _end_navigation_press(index: int, point: Vector2, canceled: bool) -> bool:
	var press: NavigationPress = _navigation_presses.get(index)
	if press == null:
		return false
	_navigation_presses.erase(index)
	if canceled or press.dragged or _parked or _jumping:
		return true
	if press.scanner:
		if not press.contact.is_empty() and _scanner_row_at(point) == press.contact:
			_select_scanner_row(_scanner_ids.find(press.contact))
	elif press.from_view and not press.contact.is_empty():
		if _combat_marker_at(point) == press.contact:
			combat_target_requested.emit(press.contact)
	elif press.site >= 0:
		var current := _navigation_marker_at(point) if press.from_view else _navigation_row_at(point)
		if current == press.site:
			_request_navigation(press.site, press.from_view)
	return true

func _navigation_row_at(point: Vector2) -> int:
	if not _hit(_navigation_list, point):
		return -1
	var index := _navigation_list.get_item_at_position(point - _navigation_list.get_global_rect().position, true)
	return _navigation_sites[index] if index >= 0 and index < _navigation_sites.size() else -1

func _scanner_row_at(point: Vector2) -> String:
	if not _hit(_scanner_list, point):
		return ""
	var index := _scanner_list.get_item_at_position(point - _scanner_list.get_global_rect().position, true)
	return _scanner_ids[index] if index >= 0 and index < _scanner_ids.size() else ""

func _navigation_marker_at(point: Vector2) -> int:
	return -1 if _world_marker_blocked(point) else _marks.navigation_at(point)

func _combat_marker_at(point: Vector2) -> String:
	return "" if _world_marker_blocked(point) else _marks.combat_pick_at(point)

func _world_marker_blocked(point: Vector2) -> bool:
	for control: Control in _navigation_blockers:
		if _hit(control, point):
			return true
	return false

func _update_held(entered_press := false) -> void:
	var touches := _touch_owner.values()
	var was_firing := _fire_held
	_boost = "boost" in touches or _mouse_held.has("boost")
	_brake = "brake" in touches or _mouse_held.has("brake")
	_fire_held = "fire" in touches or _mouse_held.has("fire")
	var forward := "translation_forward" in touches or _mouse_held.has("translation_forward")
	var reverse := "translation_reverse" in touches or _mouse_held.has("translation_reverse")
	_translation_depth = float(forward) - float(reverse)
	_actions["boost"].self_modulate = CYAN if _boost else Color.WHITE
	_actions["brake"].self_modulate = AMBER if _brake else Color.WHITE
	_actions["fire"].self_modulate = Color("ffb5a5") if _fire_held else Color.WHITE
	_actions["translation_forward"].self_modulate = CYAN if forward else Color.WHITE
	_actions["translation_reverse"].self_modulate = CYAN if reverse else Color.WHITE
	if entered_press and _fire_held and not was_firing:
		action_requested.emit("fire_hold")

func _set_mouse_hold(action: String, active: bool) -> void:
	if active:
		_mouse_held[action] = true
	else:
		_mouse_held.erase(action)
	_update_held(active)

func _commit_action(action: String) -> void:
	if action == "translation_mode":
		_translation_mode = not _translation_mode
		clear_held_input()
		_update_translation_mode()
	elif action == "frame":
		frame_requested.emit()
	elif action == "navigation_toggle":
		toggle_navigation()
	elif action == "navigation_close":
		close_navigation()
	elif action == "camera_observer" or action == "camera_missile":
		close_navigation()
		action_requested.emit(action)
	elif action == "scanner_toggle":
		_show_scanner(not scanner_is_open())
	elif action == "comms":
		close_navigation()
		action_requested.emit("comms")
	elif action == "comms_contact":
		action_requested.emit("comms")
	elif action == "combat_lock":
		combat_target_requested.emit(_scanner_focus)
	elif action == "combat_unlock":
		combat_target_requested.emit("")
	elif action == "object_labels":
		_marks.object_labels = not _marks.object_labels
		_update_navigation_switches()
		_marks.queue_redraw()
	elif action == "navigation_corridor":
		_navigation_corridor_enabled = not _navigation_corridor_enabled
		_update_navigation_switches()
	elif action == "ship_markers":
		_marks.ship_markers = not _marks.ship_markers
		_update_navigation_switches()
		_marks.queue_redraw()
	else:
		if action == "flight_assist":
			clear_held_input()
		action_requested.emit(action)

func _update_translation_mode() -> void:
	_translation_controls.visible = not _parked and _translation_mode
	_steer.caption = "СДВИГ" if _translation_mode else "КУРС"
	_steer.queue_redraw()
	var toggle: Button = _actions["translation_mode"]
	toggle.text = "Сдвиг" if _translation_mode else "Курс"
	toggle.add_theme_color_override("font_color", CYAN if _translation_mode else INK)
	toggle.tooltip_text = "Переключить на поворот корабля" if _translation_mode else "Переключить на сдвиг вбок и по высоте"

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
	button.add_theme_color_override("font_color", CYAN if action in ["dock", "scoop", "contract", "mine", "sell_ore", "map", "galaxy", "fuel", "market", "services", "time", "patrol", "convoy"] else INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_stylebox_override("normal", _box(Color("12313d"), LINE, 9, 7.0))
	button.add_theme_stylebox_override("hover", _box(Color("214454"), CYAN, 9, 7.0))
	button.add_theme_stylebox_override("pressed", _box(Color("2c5a65"), CYAN, 9, 7.0))
	parent.add_child(button)
	_actions[action] = button
	if action in HOLD_ACTIONS:
		button.button_down.connect(func() -> void: _set_mouse_hold(action, true))
		button.button_up.connect(func() -> void: _set_mouse_hold(action, false))
	else:
		button.pressed.connect(_commit_action.bind(action))

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

class NavigationPress extends RefCounted:
	var site := -1
	var point := Vector2.ZERO
	var from_view := false
	var scanner := false
	var contact := ""
	var dragged := false
	var scroll_origin := 0.0

class FlightMarks extends Control:
	const MAX_CONTACTS := 3
	const MAX_NAVIGATION_MARKERS := 6
	const NAVIGATION_HIT_RADIUS := 22.0
	const SIGHT_EDGE := Color(0.015, 0.035, 0.052, 0.9)

	var flight := false
	var forward_aim := true
	var target_visible := false
	var target_position := Vector2.ZERO
	var object_labels := true
	var ship_markers := true
	var combat_lock: Dictionary = {}
	var traffic: Array[Dictionary] = []
	var navigation: Array[Dictionary] = []
	var _visible_combat: Dictionary[String, Vector2] = {}
	var _excluded: Array[Rect2] = []

	func set_navigation(markers: Array[Dictionary], safe_area: Rect2, excluded: Array[Rect2]) -> void:
		navigation.clear()
		_excluded = excluded
		for marker: Dictionary in markers:
			var screen: Vector2 = marker.screen
			if not safe_area.has_point(screen) or _excluded.any(func(rect: Rect2) -> bool: return rect.grow(12.0).has_point(screen)):
				continue
			if target_visible and not marker.active and screen.distance_to(target_position) < NAVIGATION_HIT_RADIUS * 1.5:
				continue
			if navigation.any(func(other: Dictionary) -> bool: return screen.distance_to(other.screen) < NAVIGATION_HIT_RADIUS * 2.0):
				continue
			navigation.append(marker)
			if navigation.size() >= MAX_NAVIGATION_MARKERS:
				break
		queue_redraw()

	func navigation_at(point: Vector2) -> int:
		if not flight:
			return -1
		for marker: Dictionary in navigation:
			var screen: Vector2 = marker.screen
			if screen.distance_squared_to(point) <= NAVIGATION_HIT_RADIUS * NAVIGATION_HIT_RADIUS:
				return marker.id
		return -1

	func combat_pick_at(point: Vector2) -> String:
		if not flight or not ship_markers:
			return ""
		for marker: Dictionary in traffic:
			if not marker.get("lockable", false) or not _visible_combat.has(marker.id):
				continue
			var screen: Vector2 = marker.screen
			if screen.distance_to(point) <= NAVIGATION_HIT_RADIUS and _visible_combat[marker.id].distance_to(point) <= NAVIGATION_HIT_RADIUS:
				return marker.id
		return ""

	func _draw() -> void:
		if not flight:
			return
		var center := size * 0.5
		if forward_aim:
			for direction: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
				var start := center + direction * 13.0
				var end := center + direction * 23.0
				draw_line(start, end, SIGHT_EDGE, 4.0, true)
				draw_line(start, end, CYAN, 1.5, true)
		_draw_navigation(_draw_traffic())
		_draw_combat_lock()
		if not target_visible:
			return
		var margin := Vector2(42, 112)
		var target := target_position.clamp(margin, size - margin - Vector2(0, 86))
		if target != target_position:
			var direction := (target_position - center).normalized()
			var side := direction.orthogonal()
			var arrow := PackedVector2Array([target + direction * 13.0, target - direction * 8.0 + side * 7.0, target - direction * 8.0 - side * 7.0])
			draw_colored_polygon(arrow, AMBER)
			arrow.append(arrow[0])
			draw_polyline(arrow, SIGHT_EDGE, 1.8, true)
			return
		var distance := 10.0
		var vertices := PackedVector2Array([target + Vector2(0, -distance), target + Vector2(distance, 0), target + Vector2(0, distance), target + Vector2(-distance, 0), target + Vector2(0, -distance)])
		draw_polyline(vertices, SIGHT_EDGE, 4.5, true)
		draw_polyline(vertices, AMBER, 2.0, true)

	func _draw_combat_lock() -> void:
		if combat_lock.is_empty():
			return
		var at: Vector2 = combat_lock.screen
		if not Rect2(Vector2(25, 118), size - Vector2(50, 243)).has_point(at):
			return
		draw_arc(at, 16.0, 0.0, TAU, 32, SIGHT_EDGE, 4.5, true)
		draw_arc(at, 16.0, 0.0, TAU, 32, ALERT, 2.0, true)
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var start := at + direction * 12.0
			var end := at + direction * 22.0
			draw_line(start, end, SIGHT_EDGE, 4.0, true)
			draw_line(start, end, ALERT, 1.6, true)

	func _draw_navigation(occupied: Array[Rect2]) -> void:
		var font := ThemeDB.fallback_font
		for marker: Dictionary in navigation:
			var screen: Vector2 = marker.screen
			var color := AMBER if marker.active else CYAN
			draw_line(screen - Vector2(10, 6), screen - Vector2(4, 6), color, 1.8, true)
			draw_line(screen + Vector2(4, -6), screen + Vector2(10, -6), color, 1.8, true)
			draw_line(screen + Vector2(-10, 6), screen + Vector2(-4, 6), color, 1.8, true)
			draw_line(screen + Vector2(4, 6), screen + Vector2(10, 6), color, 1.8, true)
			draw_circle(screen, 1.8, color, true, -1.0, true)
			if not object_labels:
				continue
			var caption: String = marker.name
			var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			var text_at := Vector2(clampf(screen.x - width * 0.5, 16.0, maxf(16.0, size.x - width - 16.0)), screen.y + 25.0)
			var label_box := Rect2(text_at - Vector2(5, 14), Vector2(width + 10, 19))
			if _excluded.any(func(rect: Rect2) -> bool: return rect.intersects(label_box)):
				continue
			if occupied.any(func(rect: Rect2) -> bool: return rect.intersects(label_box)):
				continue
			occupied.append(label_box)
			draw_rect(label_box, BACK)
			draw_string(font, text_at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)

	func _draw_traffic() -> Array[Rect2]:
		var occupied: Array[Rect2] = []
		_visible_combat.clear()
		if not ship_markers:
			return occupied
		var safe := Rect2(Vector2(24, 142), (size - Vector2(48, 285)).max(Vector2.ONE))
		var font := ThemeDB.fallback_font
		for contact: Dictionary in traffic:
			var screen: Vector2 = contact.screen
			if not safe.has_point(screen):
				continue
			var hostile: bool = contact.role == "raider"
			var convoy: bool = contact.role == "convoy"
			var color := ALERT if hostile else (ALLY if contact.role == "patrol" else CYAN)
			if convoy:
				color = CONVOY
			var caption := "%s · %d м" % [contact.name, roundi(contact.distance)]
			var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			var text_at := Vector2(clampf(screen.x - width * 0.5, 20.0, maxf(20.0, size.x - width - 20.0)), screen.y + 27.0)
			var label_box := Rect2(text_at - Vector2(6, 15), Vector2(width + 12, 21))
			var footprint := Rect2(screen - Vector2(12, 12), Vector2(24, 24))
			if _excluded.any(func(box: Rect2) -> bool: return box.intersects(footprint)):
				continue
			var show_caption := object_labels and not _excluded.any(func(box: Rect2) -> bool: return box.intersects(label_box))
			if show_caption:
				footprint = label_box.merge(footprint)
			if occupied.any(func(box: Rect2) -> bool: return box.intersects(footprint)):
				continue
			occupied.append(footprint)
			if contact.get("lockable", false):
				_visible_combat[contact.id] = screen
			if hostile:
				var diamond := PackedVector2Array([
					screen + Vector2(0, -11), screen + Vector2(9, 0), screen + Vector2(0, 11),
					screen + Vector2(-9, 0), screen + Vector2(0, -11),
				])
				draw_polyline(diamond, color, 1.7, true)
			elif contact.role == "patrol":
				draw_rect(Rect2(screen - Vector2(7, 7), Vector2(14, 14)), color, false, 1.4)
			elif convoy:
				draw_rect(Rect2(screen - Vector2(10, 8), Vector2(20, 16)), color, false, 1.4)
				draw_rect(Rect2(screen - Vector2(5, 4), Vector2(10, 8)), color, false, 1.4)
			else:
				draw_arc(screen, 7.0, 0.0, TAU, 20, color, 1.4, true)
			if show_caption:
				draw_rect(label_box, BACK)
				draw_string(font, text_at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
			if occupied.size() >= MAX_CONTACTS:
				break
		return occupied
