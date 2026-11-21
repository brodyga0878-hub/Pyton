extends "res://scripts/recon_panel.gd"

signal operation_requested(id: String, action: String)

const Catalog := preload("res://scripts/sector_catalog.gd")
const TITLES := {"signal": "Подлёдный сигнал", "courier": "Перехват РК-408", "relay": "Тихая решётка"}
const COMMANDS := ["accept", "buy", "survey", "research", "safety", "disable", "report", "renew", "follow"]

var _selected := "signal"


func build() -> void:
	layer = 9
	var backdrop := ColorRect.new()
	backdrop.color = Color("09141d")
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout = MarginContainer.new()
	add_child(_layout)
	_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rows := VBoxContainer.new()
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override("separation", 14)
	_layout.add_child(rows)
	var header := HBoxContainer.new()
	rows.add_child(header)
	_label(header, "Особые операции", 31, TEXT).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "close", "Закрыть")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	rows.add_child(tabs)
	for id: String in TITLES:
		_button(tabs, "tab_" + id, TITLES[id])
		_buttons["tab_" + id].toggle_mode = true
	_title = _label(rows, "", 25, MINT)
	_detail = _label(rows, "", 20, TEXT)
	_hint = _label(rows, "", 18, MUTED)
	_result = _label(rows, "", 19, MINT)
	var commands := HBoxContainer.new()
	commands.add_theme_constant_override("separation", 8)
	rows.add_child(commands)
	for action: String in COMMANDS:
		_button(commands, action, "")
	get_viewport().size_changed.connect(_update_insets)
	_update_insets()
	hide()


func refresh(message := "") -> void:
	if not is_open():
		return
	var status: Dictionary = _sim.operation_status(_selected)
	_title.text = str(status.title)
	_detail.text = str(status.text)
	var site := int(status.site)
	var destination := Catalog.system_of_site(site)
	var place := "" if destination < 0 else "%s · %s" % [_sim.target_name(site), Catalog.system(destination).name]
	var remaining := ceili(float(status.time))
	var terms := "%d кр. при выполнении" % int(status.reward)
	if remaining > 0:
		terms += " · осталось %d мин %02d с" % [floori(remaining / 60.0), remaining % 60]
	elif str(status.stage).begins_with("done"):
		terms = "Завершено"
	var details := [place, terms, str(status.hint)]
	_hint.text = "\n".join(details.filter(func(text: String) -> bool: return not text.is_empty()))
	for id: String in TITLES:
		var tab: Button = _buttons["tab_" + id]
		tab.set_pressed_no_signal(id == _selected)
		tab.disabled = id == _selected
	for action: String in COMMANDS:
		_buttons[action].hide()
	for option: Dictionary in status.actions:
		var button: Button = _buttons[option.id]
		button.text = option.name
		button.disabled = not option.enabled
		button.show()
	var follow: Button = _buttons.follow
	follow.text = "Проложить курс"
	follow.disabled = _sim.jump_seconds_left > 0.0
	follow.visible = site >= 0 and site != _sim.docked and site != _sim.landed_site
	if not message.is_empty():
		_result.text = message


func _request(action: String) -> void:
	if action == "close":
		dismissed.emit()
	elif action.begins_with("tab_"):
		_selected = action.trim_prefix("tab_")
		_result.text = ""
		refresh()
	else:
		operation_requested.emit(_selected, action)
