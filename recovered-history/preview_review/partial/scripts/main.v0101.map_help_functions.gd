func _build_map() -> void:
	map_overlay = ColorRect.new()
	map_overlay.color = Color(0.005,0.01,0.025,0.92)
	map_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(map_overlay)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 26
	panel.offset_top = 26
	panel.offset_right = -26
	panel.offset_bottom = -26
	map_overlay.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation",12)
	panel.add_child(col)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",12)
	col.add_child(header)
	var title := label("ГАЛАКТИЧЕСКАЯ КАРТА",25,Color("6ce2df"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(button("Поиск",_search_system,100))
	header.add_child(button("К кораблю",func(): map_canvas.recenter(),135))
	header.add_child(button("Вся галактика",func(): map_canvas.overview = true; map_canvas.queue_redraw(),165))
	header.add_child(button("−",func(): map_canvas.change_zoom(1/1.35),54))
	header.add_child(button("+",func(): map_canvas.change_zoom(1.35),54))
	header.add_child(button("Закрыть",_close_map,125))
	map_readout = label("",17,Color("a9c3d1"))
	col.add_child(map_readout)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation",18)
	col.add_child(row)
	map_canvas = Control.new()
	map_canvas.set_script(GalaxyMap)
	map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_canvas.system_selected.connect(func(code: int):
		if nav.select(code): _refresh_map())
	row.add_child(map_canvas)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 340
	sidebar.add_theme_constant_override("separation",14)
	row.add_child(sidebar)
	map_info = label("",19)
	map_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_info.custom_minimum_size = Vector2(340,235)
	sidebar.add_child(map_info)
	map_jump = button("Перейти к цели",_jump_action,340)
	sidebar.add_child(map_jump)
	col.add_child(label("Зелёный круг — проекция дальности. Для поддержанных систем доступны миры FFE; полёт и поверхности адаптированы.",14,Color("8aa5b5")))
	map_overlay.hide()

func _refresh_map() -> void:
	map_canvas.jump_range=model.jump_range()
	map_canvas.configure(nav)
	var target: Dictionary = nav.selected()
	var dist := nav.distance()
	map_readout.text = "Вы: %s · Цель: %s · Топливо %d/12 т · Посещено систем: %d" % [nav.current().name,target.name,nav.fuel,nav.visited.size()]
	map_info.text = "%s\n%s\nСектор: (%d, %d)\n\nРасстояние: %.2f св. лет\nГипертопливо: %d т\nПредел: %.0f св. лет\n\n%s" % [target.name,target.type,int(target.sector[0]),int(target.sector[1]),dist,nav.fuel_required(),model.jump_range(),"Есть станция прототипа" if nav.has_station(int(target.id)) else "Нет станции: заправка недоступна"]
	var reason := nav.jump_error(model)
	map_jump.text = "Отменить заряд" if nav.remaining>0 else "Начать переход"
	map_jump.disabled = false
	if reason!="" and nav.remaining<=0:
		map_info.text += "\n\n"+reason

func _show_map() -> void:
	_release_inputs()
	if is_instance_valid(settings_panel) and settings_panel.visible:_close_settings()
	if is_instance_valid(story_panel) and story_panel.visible:_close_story()
	if is_instance_valid(services_panel) and services_panel.visible:_close_services()
	fire_held=false
	if is_instance_valid(hangar_panel) and hangar_panel.visible: _close_hangar()
	if is_instance_valid(system_panel): _close_system()
	if not is_instance_valid(map_overlay): return
	help_panel.hide()
	stick.release()
	roll_left = false
	roll_right = false
	map_overlay.show()
	map_canvas.jump_range=model.jump_range()
	map_canvas.configure(nav)
	map_canvas.recenter()
	_refresh_map()

func _close_map() -> void:
	map_canvas.clear_input()
	map_overlay.hide()

func _show_help() -> void:
	_release_inputs()
	if is_instance_valid(settings_panel) and settings_panel.visible:_close_settings()
	if is_instance_valid(story_panel) and story_panel.visible:_close_story()
	if is_instance_valid(services_panel) and services_panel.visible:_close_services()
	fire_held=false
	if is_instance_valid(hangar_panel) and hangar_panel.visible: _close_hangar()
	if is_instance_valid(system_panel): _close_system()
	stick.release()
	roll_left = false
	roll_right = false
	if is_instance_valid(map_overlay): _close_map()
	help_panel.show()
