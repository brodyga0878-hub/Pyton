extends CanvasLayer

signal follow_requested(kind: String)
signal career_requested(kind: String)
signal story_requested(action: String)
signal dismissed()

const Sector = preload("res://scripts/sector_catalog.gd")
const Patrol = preload("res://scripts/patrol_encounter.gd")
const MissionCalendar = preload("res://scripts/mission_calendar.gd")
const NewsJournal = preload("res://scripts/news_journal.gd")
const Story = preload("res://scripts/branching_story.gd")
const INK := Color("edf7f9")
const MUTED := Color("adc0c9")
const MINT := Color("a4e9d6")
const AMBER := Color("f0c59a")
const BORDER := Color("355360")
const PATROL_STEPS := ["Найти источник сигнала", "Перехватить рейдера", "Вернуться с докладом"]
const STORY_OPTION_COUNT := 4
const STORY_DATES := {
	"settled_at": "Завершено", "key_at": "Получен ключ",
	"chosen_at": "Принято решение", "briefed_at": "Получен запрос",
}

enum Page { WORK, PASSENGERS, RIG, CAREER, STORY, NEWS }

var _sim: RefCounted
var _insets: MarginContainer
var _location: Label
var _clock_readout: Label
var _delivery_title: Label
var _delivery_step: Label
var _delivery_cargo: Label
var _delivery_next: Label
var _delivery_rows: Array[HBoxContainer] = []
var _delivery_stops: Array[Label] = []
var _delivery_tags: Array[Label] = []
var _patrol_step: Label
var _patrol_origin: Label
var _patrol_next: Label
var _patrol_reward: Label
var _patrol_rows: Array[HBoxContainer] = []
var _patrol_stops: Array[Label] = []
var _patrol_tags: Array[Label] = []
var _work_page: HBoxContainer
var _passenger_page: HBoxContainer
var _rig_page: HBoxContainer
var _career_page: HBoxContainer
var _story_page: HBoxContainer
var _news_page: NewsJournal
var _work_tab: Button
var _passenger_tab: Button
var _rig_tab: Button
var _career_tab: Button
var _story_tab: Button
var _news_tab: Button
var _rig_title: Label
var _rig_location: Label
var _rig_work: Label
var _rig_stock: Label
var _rig_reserve: Label
var _rig_hint: Label
var _passenger_route: Label
var _passenger_status: Label
var _passenger_deadline: Label
var _passenger_cabins: Label
var _passenger_payment: Label
var _passenger_record: Label
var _passenger_next: Label
var _combat_title: Label
var _combat_points: Label
var _bounty_record: Label
var _faction_cards: Array[Dictionary] = []
var _dispatch_route: Label
var _dispatch_sponsor: Label
var _dispatch_time: Label
var _dispatch_hint: Label
var _career_action: Button
var _career_buttons: Dictionary[String, Button] = {}
var _career_choice := "dispatch"
var _career_action_kind := "dispatch"
var _order_title: Label
var _story_title: Label
var _story_branch: Label
var _story_objective: Label
var _story_route: Label
var _story_date: Label
var _story_choices: GridContainer
var _story_options: Array[Dictionary] = []
var _close_button: Button
var _follow_buttons: Dictionary[String, Button] = {}
var _touches: Dictionary[int, Button] = {}


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
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	_insets.add_child(page)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	page.add_child(header)
	_label(header, "Журнал заданий", 34, INK).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var context := VBoxContainer.new()
	context.alignment = BoxContainer.ALIGNMENT_CENTER
	context.add_theme_constant_override("separation", 2)
	header.add_child(context)
	_location = _label(context, "", 19, MINT)
	_location.autowrap_mode = TextServer.AUTOWRAP_OFF
	_location.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_readout = _label(context, "", 17, MUTED)
	_clock_readout.autowrap_mode = TextServer.AUTOWRAP_OFF
	_clock_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_close_button = _button(header, "Закрыть")
	_close_button.custom_minimum_size.x = 128.0
	_close_button.pressed.connect(func() -> void: dismissed.emit())
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	page.add_child(tabs)
	_work_tab = _button(tabs, "Доставка и дозор")
	_passenger_tab = _button(tabs, "Пассажиры")
	_rig_tab = _button(tabs, "Бур")
	_career_tab = _button(tabs, "Карьера")
	_story_tab = _button(tabs, "Сюжет")
	_news_tab = _button(tabs, "Новости")
	for tab: Button in [_work_tab, _passenger_tab, _rig_tab, _career_tab, _story_tab, _news_tab]:
		tab.toggle_mode = true
		tab.custom_minimum_size.x = 174.0
	_work_tab.pressed.connect(_show_page.bind(Page.WORK))
	_passenger_tab.pressed.connect(_show_page.bind(Page.PASSENGERS))
	_rig_tab.pressed.connect(_show_page.bind(Page.RIG))
	_career_tab.pressed.connect(_show_page.bind(Page.CAREER))
	_story_tab.pressed.connect(_show_page.bind(Page.STORY))
	_news_tab.pressed.connect(_show_page.bind(Page.NEWS))
	_rig_tab.hide()

	_work_page = HBoxContainer.new()
	_work_page.add_theme_constant_override("separation", 16)
	_work_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_work_page)
	_build_delivery(_work_page)
	_build_patrol(_work_page)
	_passenger_page = HBoxContainer.new()
	_passenger_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_passenger_page)
	_build_passengers()
	_rig_page = HBoxContainer.new()
	_rig_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_rig_page)
	_build_rig()
	_career_page = HBoxContainer.new()
	_career_page.add_theme_constant_override("separation", 16)
	_career_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_career_page)
	_build_career()
	_story_page = HBoxContainer.new()
	_story_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_story_page)
	_build_story()
	_news_page = NewsJournal.new()
	page.add_child(_news_page)
	_news_page.story_requested.connect(_show_page.bind(Page.STORY))
	_show_page(Page.WORK)
	get_viewport().size_changed.connect(_update_insets)
	_update_insets()
	hide()


func open(sim: RefCounted) -> void:
	if sim == null:
		return
	build()
	_sim = sim
	_touches.clear()
	show()
	refresh()


func refresh() -> void:
	if not is_open():
		return
	_location.text = "Система «%s»" % Sector.system(_sim.system_id).name
	var clock: Dictionary = _sim.clock_status()
	_clock_readout.text = str(clock.stamp)
	if clock.paused:
		_clock_readout.text += " · Пауза"
	_refresh_delivery()
	_refresh_patrol()
	_refresh_passengers()
	_refresh_rig()
	if _career_page.visible:
		_refresh_career()
	if _story_page.visible:
		_refresh_story()
	if _news_page.visible:
		_news_page.refresh(_sim)


func close() -> void:
	_touches.clear()
	if is_instance_valid(_news_page):
		_news_page.reset()
	_sim = null
	hide()


func is_open() -> bool:
	return _sim != null and visible


func _build_delivery(parent: HBoxContainer) -> void:
	var card := _card(parent)
	_delivery_title = _label(card, "Доставка", 29, INK)
	_delivery_step = _label(card, "", 19, MINT)
	_delivery_cargo = _label(card, "", 18, MUTED)
	for i in range(4):
		var row := _step_row(card, "")
		_delivery_rows.append(row)
		_delivery_stops.append(row.get_child(0))
		_delivery_tags.append(row.get_child(1))
	_spacer(card)
	_delivery_next = _label(card, "", 19, INK)
	_add_follow_button(card, "delivery")


func _build_patrol(parent: HBoxContainer) -> void:
	var card := _card(parent)
	_label(card, "Дозор", 29, INK)
	_patrol_step = _label(card, "", 19, AMBER)
	_patrol_origin = _label(card, "", 18, MUTED)
	_patrol_reward = _label(card, "", 19, INK)
	for caption: String in PATROL_STEPS:
		var row := _step_row(card, caption)
		_patrol_rows.append(row)
		_patrol_stops.append(row.get_child(0))
		_patrol_tags.append(row.get_child(1))
	_spacer(card)
	_patrol_next = _label(card, "", 19, INK)
	_add_follow_button(card, "patrol")


func _build_passengers() -> void:
	var card := _card(_passenger_page)
	_passenger_route = _label(card, "", 29, INK)
	_passenger_status = _label(card, "", 20, MINT)
	_passenger_deadline = _label(card, "", 18, MUTED)
	_passenger_cabins = _label(card, "", 18, MUTED)
	_passenger_payment = _label(card, "", 19, INK)
	_passenger_record = _label(card, "", 18, MUTED)
	_spacer(card)
	_passenger_next = _label(card, "", 19, INK)
	_add_follow_button(card, "passenger")


func _build_rig() -> void:
	var card := _card(_rig_page)
	_rig_title = _label(card, "", 29, INK)
	_rig_location = _label(card, "", 19, MINT)
	_rig_work = _label(card, "", 20, INK)
	_rig_stock = _label(card, "", 20, INK)
	_rig_reserve = _label(card, "", 19, MUTED)
	_spacer(card)
	_rig_hint = _label(card, "", 19, INK)
	_add_follow_button(card, "rig")


func _build_career() -> void:
	var standing := _card(_career_page)
	_combat_title = _label(standing, "", 28, INK)
	_combat_points = _label(standing, "", 18, MUTED)
	_bounty_record = _label(standing, "", 16, MINT)
	for _issuer in range(2):
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _style(Color("132832"), BORDER, 9, 12))
		standing.add_child(panel)
		var faction := VBoxContainer.new()
		faction.add_theme_constant_override("separation", 5)
		panel.add_child(faction)
		var title := _label(faction, "", 22, INK)
		var ranks := HBoxContainer.new()
		ranks.add_theme_constant_override("separation", 12)
		faction.add_child(ranks)
		var rank := _label(ranks, "", 19, INK)
		rank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var trust := _label(ranks, "", 18, MINT)
		trust.autowrap_mode = TextServer.AUTOWRAP_OFF
		var access := _label(faction, "", 17, MUTED)
		_faction_cards.append({"title": title, "rank": rank, "trust": trust, "access": access})

	var board := _card(_career_page)
	_order_title = _label(board, "Приказы фракций", 27, INK)
	var kinds := HBoxContainer.new()
	kinds.add_theme_constant_override("separation", 7)
	board.add_child(kinds)
	var options := {"dispatch": "Депеша", "recon": "Разведка", "intercept": "Охрана"}
	for kind: String in options:
		var option := _button(kinds, options[kind])
		option.toggle_mode = true
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.pressed.connect(_choose_career_order.bind(kind))
		_career_buttons[kind] = option
	_dispatch_route = _label(board, "", 23, INK)
	_dispatch_sponsor = _label(board, "", 19, MINT)
	_dispatch_time = _label(board, "", 18, MUTED)
	_spacer(board)
	_dispatch_hint = _label(board, "", 18, MUTED)
	_career_action = _button(board, "")
	_career_action.pressed.connect(_request_career)
	_add_follow_button(board, "career")


func _build_story() -> void:
	var card := _card(_story_page)
	_story_title = _label(card, "", 29, INK)
	_story_branch = _label(card, "", 19, AMBER)
	_story_objective = _label(card, "", 22, INK)
	_story_route = _label(card, "", 19, MINT)
	_story_date = _label(card, "", 17, MUTED)
	_spacer(card)
	_story_choices = GridContainer.new()
	_story_choices.add_theme_constant_override("h_separation", 16)
	_story_choices.add_theme_constant_override("v_separation", 14)
	card.add_child(_story_choices)
	for _index in range(STORY_OPTION_COUNT):
		var choice := VBoxContainer.new()
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.add_theme_constant_override("separation", 7)
		_story_choices.add_child(choice)
		var button := _button(choice, "")
		button.pressed.connect(_request_story.bind(button))
		var detail := _label(choice, "", 17, MUTED)
		_story_options.append({"row": choice, "button": button, "detail": detail})
	_add_follow_button(card, "story")


func _show_page(page: Page) -> void:
	_touches.clear()
	_work_page.visible = page == Page.WORK
	_passenger_page.visible = page == Page.PASSENGERS
	_rig_page.visible = page == Page.RIG
	_career_page.visible = page == Page.CAREER
	_story_page.visible = page == Page.STORY
	_news_page.visible = page == Page.NEWS
	_work_tab.set_pressed_no_signal(_work_page.visible)
	_passenger_tab.set_pressed_no_signal(_passenger_page.visible)
	_rig_tab.set_pressed_no_signal(_rig_page.visible)
	_career_tab.set_pressed_no_signal(_career_page.visible)
	_story_tab.set_pressed_no_signal(_story_page.visible)
	_news_tab.set_pressed_no_signal(_news_page.visible)
	if _career_page.visible and is_open():
		_refresh_career()
	if _story_page.visible and is_open():
		_refresh_story()
	if _news_page.visible and is_open():
		_news_page.refresh(_sim)


func _refresh_rig() -> void:
	var status: Dictionary = _sim.remote_rig_status()
	_rig_tab.visible = status.active
	if not status.active:
		if _rig_page.visible:
			_show_page(Page.WORK)
		return
	_rig_title.text = "Бур на «%s»" % status.name
	_rig_location.text = "Система «%s»" % Sector.system(int(status.system)).name
	if status.same_system and float(status.distance) >= 0.0:
		var distance := float(status.distance)
		var range_text := "%.0f м" % distance if distance < 1000.0 else "%.2f км" % (distance / 1000.0)
		_rig_location.text += " · До установки %s" % range_text.replace(".", ",")
	var stored := int(status.stored)
	var capacity := int(status.capacity)
	_rig_stock.text = "%s в буфере · %d / %d ед." % [status.resource, stored, capacity]
	_rig_reserve.text = "Запас в грунте · %d ед." % int(status.reserve)
	_rig_work.text = "Следующая партия через %d с" % ceili(float(status.remaining)) if status.working else "Буфер заполнен" if stored >= capacity else "Запас в грунте исчерпан"
	if status.near:
		if stored == 0:
			_rig_hint.text = "Пустой бур можно забрать на борт."
		else:
			_rig_hint.text = "Выгрузите сырьё в трюм." if status.can_unload else "Освободите место в трюме для выгрузки."
	elif _sim.landed_site >= 0:
		_rig_hint.text = "Взлетите, чтобы вернуться к установке."
	elif status.navigating:
		_rig_hint.text = "Автопилот ведёт к установке."
	elif status.same_system and _sim.docked >= 0:
		_rig_hint.text = "Выберите установку целью после выхода из дока."
	else:
		_rig_hint.text = "Автопилот зайдёт на точку установки." if status.same_system else "Маршрут вернёт к системе, где работает бур."
	_follow("rig", "К буру" if status.can_route and not status.navigating else "")


func _refresh_delivery() -> void:
	var active: bool = _sim.contract_stage == 1
	var itinerary: Dictionary = _sim.contract_itinerary()
	var title := "Доставка"
	var step := "Завершено доставок · %d" % _sim.deliveries
	var cargo := ""
	var next := "Действующих доставок нет. Контракт можно взять в порту."
	var origin := -1
	var stops: Array = []
	var leg := -1
	var follow_caption := ""
	if active:
		origin = _sim.contract_origin
		var destination: int = _sim.contract_destination
		stops = [destination]
		leg = 0
		if not itinerary.is_empty():
			title = itinerary.title
			stops = itinerary.stops
			leg = itinerary.leg
		step = "Этап %d из %d · Награда %d кр." % [leg + 1, stops.size(), _sim.contract_reward()]
		cargo = "Груз · %s" % _sim.contract_cargo()
		var destination_system := Sector.system_of_site(destination)
		var port: String = _sim.target_name(destination)
		if _sim.docked == destination:
			var command := "Отметить этап" if leg + 1 < stops.size() else "Сдать груз"
			next = "Нажмите «%s» на панели полёта." % command
		elif destination_system != _sim.system_id:
			next = "Прыгните в систему «%s» и прибудьте в порт «%s»." % [Sector.system(destination_system).name, port]
			follow_caption = "Проложить прыжок"
		else:
			next = "Состыкуйтесь в порту «%s»." % port
			follow_caption = "Курс к порту"
	_delivery_title.text = title
	_delivery_step.text = step
	_delivery_cargo.text = cargo
	_delivery_cargo.visible = active
	_delivery_next.text = next
	var visited: Array = [origin] + stops if active else []
	for i in range(_delivery_rows.size()):
		_delivery_rows[i].visible = i < visited.size()
		if i >= visited.size():
			continue
		var current := i == leg + 1
		var port_id: int = visited[i]
		_delivery_stops[i].text = _sim.target_name(port_id)
		_delivery_stops[i].add_theme_color_override("font_color", MINT if current else INK)
		var tag := "Старт" if i == 0 else ("Финиш" if i == stops.size() else "Остановка %d" % i)
		if current:
			tag += " · Сейчас"
		elif i > 0 and i <= leg:
			tag += " · Пройдено"
		_delivery_tags[i].text = tag
	_follow("delivery", follow_caption)


func _refresh_patrol() -> void:
	var status: Dictionary = _sim.patrol_status()
	var phase: int = status.phase
	var active := phase in [Patrol.OUTBOUND, Patrol.ENGAGED, Patrol.RETURN]
	_patrol_origin.visible = active
	_patrol_reward.visible = active
	for i in range(_patrol_rows.size()):
		_patrol_rows[i].visible = active
		var step := i + Patrol.OUTBOUND
		_patrol_stops[i].add_theme_color_override("font_color", AMBER if phase == step else INK)
		_patrol_tags[i].text = "Сейчас" if phase == step else ("Пройдено" if phase > step else "")
	if not active:
		_patrol_step.text = "Завершено дозоров · %d" % _sim.patrol.completed
		_patrol_next.text = "Действующего дозора нет. Его можно принять в порту."
		_follow("patrol", "")
		return
	var system_name: String = Sector.system(Sector.system_of_site(status.origin)).name
	var port: String = _sim.target_name(status.origin)
	_patrol_origin.text = "Порт «%s» · %s" % [port, system_name]
	_patrol_reward.text = "Награда %d кр." % status.reward
	var instruction: String = status.reason
	var follow_caption := ""
	match phase:
		Patrol.OUTBOUND:
			_patrol_step.text = "Поиск сигнала"
			if status.available and not _sim.patrol_course:
				follow_caption = "К сигналу"
			elif _sim.patrol_course:
				instruction = "Курс к сигналу уже включён."
		Patrol.ENGAGED:
			_patrol_step.text = "Перехват · Корпус рейдера %.0f%%" % status.enemy_hull
			if status.available and not _sim.patrol_course:
				follow_caption = "Навести на рейдера"
			elif _sim.patrol_course:
				instruction = "Прицел включён. Следите за дальностью огня."
		Patrol.RETURN:
			_patrol_step.text = "Возвращение с докладом"
			if _sim.docked == status.origin:
				instruction = "Нажмите «Доложить» на панели полёта."
			elif status.available and _sim.docked < 0 and not _sim.landed:
				follow_caption = "Курс к порту"
	if not status.same_system:
		follow_caption = "Проложить прыжок"
	_patrol_next.text = instruction
	_follow("patrol", follow_caption)


func _refresh_passengers() -> void:
	var status: Dictionary = _sim.passenger_status()
	var active := bool(status.active)
	_passenger_record.text = "Завершено %d · Просрочено %d · Репутация %+d" % [
		int(status.completed), int(status.late), int(status.reputation),
	]
	_passenger_cabins.text = "Занято мест · %d из %d" % [int(status.seats), int(status.capacity)]
	_passenger_payment.visible = active
	_passenger_deadline.visible = active
	if not active:
		_passenger_route.text = "Пассажирских рейсов нет"
		var debt := int(status.debt)
		_passenger_status.visible = debt > 0
		_passenger_status.text = "Долг по авансу · %d кр." % debt
		_passenger_status.add_theme_color_override("font_color", AMBER)
		_passenger_next.text = "Откройте «Биржа» → «Пассажиры» в порту."
		if debt > 0:
			_passenger_next.text = "Погасите долг на бирже во вкладке «Пассажиры», чтобы брать новые рейсы."
		_follow("passenger", "")
		return

	var origin := int(status.origin)
	var destination := int(status.destination)
	var start: String = _sim.target_name(origin)
	var arrival: String = _sim.target_name(destination)
	var arrival_system := Sector.system_of_site(destination)
	_passenger_route.text = "«%s» → «%s»" % [start, arrival]
	if Sector.system_of_site(origin) != arrival_system:
		_passenger_route.text += " · %s" % Sector.system(arrival_system).name
	var overdue := bool(status.overdue)
	var remaining := ceili(maxf(0.0, float(status.remaining)))
	_passenger_status.visible = true
	_passenger_status.text = "Срок истёк" if overdue else "Осталось %d с" % remaining
	_passenger_status.add_theme_color_override("font_color", AMBER if overdue or remaining <= 60 else MINT)
	_passenger_deadline.text = "Срок прибытия · %s" % MissionCalendar.stamp(float(status.deadline))
	_passenger_payment.text = "Аванс %d кр. · К получению %d кр." % [
		int(status.advance), maxi(0, int(status.fare) - int(status.advance)),
	]
	var caption := ""
	if overdue:
		_passenger_payment.text = "Аванс к возврату · %d кр." % int(status.advance)
		if status.can_discharge:
			_passenger_next.text = "Высадите пассажиров во вкладке «Пассажиры» на бирже."
		else:
			_passenger_next.text = str(status.reason)
			var port := int(status.route_port)
			if port >= 0:
				var system := Sector.system_of_site(port)
				_passenger_next.text = "Высадите пассажиров в порту «%s»." % _sim.target_name(port)
				if system != _sim.system_id:
					_passenger_next.text = "Прыгните в систему «%s». Затем высадите пассажиров в порту «%s»." % [
						Sector.system(system).name, _sim.target_name(port),
					]
				caption = "К ближайшему порту" if system == _sim.system_id else "Проложить прыжок"
	elif status.can_discharge and not status.canceling:
		_passenger_next.text = "Порт назначения достигнут. Высадите пассажиров на бирже."
	elif arrival_system != _sim.system_id:
		_passenger_next.text = "Прыгните в систему «%s» и состыкуйтесь в порту назначения." % Sector.system(arrival_system).name
		caption = "Проложить прыжок"
	else:
		_passenger_next.text = "Состыкуйтесь в порту назначения."
		caption = "Курс к порту"
	_follow("passenger", caption if status.can_follow else "")


func _refresh_career() -> void:
	var status: Dictionary = _sim.career_status()
	var factions: Array = status.factions
	_combat_title.text = "Боевой ранг · %s" % status.combat_title
	_combat_points.text = "Боевые очки · %d" % int(status.combat_points)
	if int(status.combat_next) >= 0:
		_combat_points.text += " · следующий ранг %d" % int(status.combat_next)
	_bounty_record.text = "Премии за розыск · %d · %d кр." % [status.bounty_awards, status.bounty_credits]
	if not status.wanted.is_empty():
		_bounty_record.text += "\nВ розыске %s · %d кр." % [status.wanted.name, status.wanted.reward]
	for issuer in range(_faction_cards.size()):
		var card := _faction_cards[issuer]
		var faction: Dictionary = factions[issuer]
		card.title.text = faction.name
		card.rank.text = "%s · %d очк." % [faction.service_title, int(faction.service_points)]
		card.trust.text = "Доверие %+d" % int(faction.trust)
		card.trust.add_theme_color_override("font_color", AMBER if int(faction.trust) < 0 else MINT)
		card.access.text = "Допуск · Служебный курьер" if faction.dispatch_role else str(faction.dispatch_reason)
		card.access.add_theme_color_override("font_color", MINT if faction.dispatch_role else MUTED)

	var busy: bool = status.order.active or status.dispatch.active
	_career_action_kind = str(status.order.kind) if status.order.active else "dispatch" if status.dispatch.active else _career_choice
	for kind: String in _career_buttons:
		_career_buttons[kind].disabled = busy and kind != _career_action_kind
		_career_buttons[kind].set_pressed_no_signal(kind == _career_action_kind)
	if _career_action_kind != "dispatch":
		_refresh_military_order(status, factions)
		return
	var active: bool = status.dispatch.active
	var dispatch: Dictionary = status.dispatch if active else status.offer
	_order_title.text = "Служебная депеша"
	var origin := int(dispatch.get("origin", -1))
	var destination := int(dispatch.get("destination", -1))
	var issuer := int(dispatch.get("issuer", -1))
	var routed := Sector.is_port(origin) and Sector.is_port(destination)
	_dispatch_route.visible = routed
	_dispatch_sponsor.visible = routed and issuer >= 0 and issuer < factions.size()
	_dispatch_time.visible = routed
	if routed:
		_dispatch_route.text = "«%s» → «%s»" % [_sim.target_name(origin), _sim.target_name(destination)]
		if _dispatch_sponsor.visible:
			_dispatch_sponsor.text = "%s · %d кр." % [factions[issuer].name, int(dispatch.reward)]
		if active:
			var remaining := ceili(float(dispatch.remaining))
			_dispatch_time.text = "Срок · %s · %d с" % [MissionCalendar.stamp(float(dispatch.deadline)), remaining]
			_dispatch_time.add_theme_color_override("font_color", AMBER if remaining <= 60 else MUTED)
		else:
			_dispatch_time.text = "Срок после приёма · %d с" % int(dispatch.duration)
			_dispatch_time.add_theme_color_override("font_color", MUTED)

	var allowed: bool = dispatch.get("allowed", false)
	_career_action.text = "Сдать депешу" if active else "Принять депешу"
	_career_action.visible = bool(status.can_submit) if active else routed
	_career_action.disabled = _sim.jump_seconds_left > 0.0 or not (status.can_submit if active else allowed)
	_dispatch_hint.text = ""
	if active and not status.can_submit:
		_dispatch_hint.text = "Сдайте депешу в порту назначения."
	elif not active and not allowed:
		_dispatch_hint.text = dispatch.get("reason", "Пришвартуйтесь в порту фракции, чтобы взять депешу.")
	_dispatch_hint.visible = not _dispatch_hint.text.is_empty()
	var route_caption := "Курс к порту" if Sector.system_of_site(destination) == _sim.system_id else "Проложить прыжок"
	_follow("career", route_caption if active and status.can_follow else "")


func _refresh_military_order(status: Dictionary, factions: Array) -> void:
	var active: bool = status.order.active
	var order: Dictionary = status.order if active else status.order_offers.get(_career_action_kind, {})
	var origin := int(order.get("origin", -1))
	var issuer := int(order.get("issuer", -1))
	var reconnaissance := _career_action_kind == "recon"
	var proved: bool = order.get("proved", false)
	var allowed: bool = order.get("allowed", false)
	_order_title.text = str(order.get("name", "Разведка рубежа" if reconnaissance else "Охрана сектора"))
	_dispatch_route.visible = Sector.is_port(origin)
	_dispatch_sponsor.visible = issuer >= 0 and issuer < factions.size()
	_dispatch_time.visible = not order.is_empty()
	if _dispatch_route.visible:
		var objective: String = _sim.target_name(int(order.site)) if reconnaissance and int(order.site) >= 0 else "Рейдер местного маршрута"
		_dispatch_route.text = "Вернитесь в «%s»." % _sim.target_name(origin) if proved else objective
	if _dispatch_sponsor.visible:
		_dispatch_sponsor.text = "%s · %d кр." % [factions[issuer].name, int(order.reward)]
	if _dispatch_time.visible:
		if active:
			var left := ceili(float(order.remaining))
			_dispatch_time.text = "Срок · %s · %d с" % [MissionCalendar.stamp(float(order.deadline)), left]
			_dispatch_time.add_theme_color_override("font_color", AMBER if left <= 60 else MUTED)
		else:
			_dispatch_time.text = "Срок после приёма · %d с" % int(order.duration)
			_dispatch_time.add_theme_color_override("font_color", MUTED)
	_career_action.visible = not order.is_empty() and (not active or proved or reconnaissance)
	_career_action.text = ("Сдать доклад" if proved else "Записать разведданные") if active else "Принять приказ"
	_career_action.disabled = _sim.jump_seconds_left > 0.0 or not (status.order_can_submit or status.order_can_probe if active else allowed)
	if not active and not allowed:
		_dispatch_hint.text = str(order.get("reason", "Пришвартуйтесь в порту фракции."))
	elif proved:
		_dispatch_hint.text = "Доклад принимают в порту выдачи приказа."
	elif reconnaissance:
		_dispatch_hint.text = "Наведите нос на объект, сблизьтесь до 180 м от поверхности и снизьте относительную скорость до 45 м/с."
	else:
		_dispatch_hint.text = "Перехватите рейдера в этой системе. Его можно выбрать в списке целей."
	_dispatch_hint.visible = true
	var route := int(status.order_route)
	var caption := "Проложить прыжок" if Sector.system_of_site(route) != _sim.system_id else "Курс к цели"
	_follow("career", caption if active and status.order_can_follow else "")


func _choose_career_order(kind: String) -> void:
	if is_open() and not _career_buttons[kind].disabled:
		_career_choice = kind
		_touches.clear()
		_refresh_career()


func _request_career() -> void:
	if not is_open() or not _career_action.is_visible_in_tree() or _career_action.disabled:
		return
	_touches.clear()
	career_requested.emit(_career_action_kind)


func _refresh_story() -> void:
	var status: Dictionary = _sim.story_status()
	_story_title.text = str(status.title)
	_story_objective.text = str(status.objective)
	_story_branch.text = str(Story.BRANCHES.get(status.branch, {}).get("name", ""))
	_story_branch.visible = not _story_branch.text.is_empty()
	_story_date.text = ""
	for field: String in STORY_DATES:
		var epoch := float(status.get(field, -1.0))
		if epoch >= 0.0:
			_story_date.text = "%s · %s" % [STORY_DATES[field], MissionCalendar.stamp(epoch)]
			break
	_story_date.visible = not _story_date.text.is_empty()

	var actions: Array = status.actions
	_story_choices.visible = not actions.is_empty()
	_story_choices.columns = 1 if actions.size() < 2 else 2
	for index in range(_story_options.size()):
		var choice := _story_options[index]
		choice.row.visible = index < actions.size()
		if index >= actions.size():
			choice.button.set_meta("story_action", "")
			continue
		var action: Dictionary = actions[index]
		choice.button.text = str(action.name)
		choice.button.set_meta("story_action", str(action.id))
		choice.button.disabled = _sim.jump_seconds_left > 0.0
		choice.detail.text = str(action.detail)
		choice.detail.visible = not choice.detail.text.is_empty()

	var target := int(status.target)
	var system := Sector.system_of_site(target)
	_story_route.visible = system >= 0
	if _story_route.visible:
		_story_route.text = "«%s» · %s" % [_sim.target_name(target), Sector.system(system).name]
	var caption := ""
	if status.can_follow and system >= 0:
		if system != _sim.system_id:
			caption = "Проложить прыжок"
		elif target == _sim.landed_site:
			caption = "Открыть атлас"
		else:
			caption = "Курс к порту" if Sector.is_port(target) else "К объекту"
	_follow("story", caption)


func _request_story(button: Button) -> void:
	if not is_open() or not button.is_visible_in_tree() or button.disabled:
		return
	var id := str(button.get_meta("story_action", ""))
	var status: Dictionary = _sim.story_status()
	for option: Dictionary in status.actions:
		if option.id == id:
			_touches.clear()
			story_requested.emit(id)
			return


func _follow(kind: String, caption: String) -> void:
	var button := _follow_buttons[kind]
	button.text = caption
	button.visible = not caption.is_empty()
	button.disabled = not button.visible or _sim.jump_seconds_left > 0.0


func _add_follow_button(parent: Control, kind: String) -> void:
	var button := _button(parent, "")
	_follow_buttons[kind] = button
	button.pressed.connect(_request_follow.bind(kind))


func _request_follow(kind: String) -> void:
	var button := _follow_buttons[kind]
	if is_open() and button.is_visible_in_tree() and not button.disabled:
		_touches.clear()
		follow_requested.emit(kind)


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventScreenTouch:
		var button: Button = _touches.get(event.index)
		_touches.erase(event.index)
		if not event.canceled:
			if event.pressed:
				var hit := _button_at(event.position)
				if hit != null and hit not in _touches.values():
					_touches[event.index] = hit
			elif button != null and button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(event.position):
				button.pressed.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var held: Button = _touches.get(event.index)
		if held != null and not held.get_global_rect().has_point(event.position):
			_touches.erase(event.index)
		get_viewport().set_input_as_handled()


func _button_at(point: Vector2) -> Button:
	if _close_button.get_global_rect().has_point(point):
		return _close_button
	for tab: Button in [_work_tab, _passenger_tab, _rig_tab, _career_tab, _story_tab, _news_tab]:
		if tab.is_visible_in_tree() and tab.get_global_rect().has_point(point):
			return tab
	if _news_page.visible:
		return _news_page.button_at(point)
	for button: Button in _career_buttons.values():
		if button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(point):
			return button
	if _career_action.is_visible_in_tree() and not _career_action.disabled and _career_action.get_global_rect().has_point(point):
		return _career_action
	for option in _story_options:
		var button: Button = option.button
		if button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(point):
			return button
	for button: Button in _follow_buttons.values():
		if button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(point):
			return button
	return null


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_touches.clear()


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


static func _card(parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 400.0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(Color("101f2a"), BORDER, 14, 20))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	return column


static func _spacer(parent: Control) -> void:
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(space)


static func _step_row(parent: Control, caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size.y = 42.0
	parent.add_child(row)
	var name := _label(row, caption, 20, INK)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var tag := _label(row, "", 16, MUTED)
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return row


static func _label(parent: Control, caption: String, points: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	button.add_theme_stylebox_override("normal", _style(Color("173a41"), Color("457783"), 8, 12))
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
	box.content_margin_top = padding * 0.8
	box.content_margin_bottom = padding * 0.8
	return box
