extends ColorRect
signal close_requested
signal changed
signal export_requested
signal import_requested
var settings: RefCounted
var content: VBoxContainer
var feedback: Label
func _ready() -> void:
	color=Color(0.005,0.01,0.025,0.98);mouse_filter=Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel:=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left=24;panel.offset_top=24;panel.offset_right=-24;panel.offset_bottom=-24;add_child(panel)
	var col:=VBoxContainer.new();col.add_theme_constant_override("separation",12);panel.add_child(col)
	var header:=HBoxContainer.new();col.add_child(header)
	var heading:=Label.new();heading.text="НАСТРОЙКИ ТЕЛЕФОНА";heading.add_theme_font_size_override("font_size",25);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(heading)
	header.add_child(_button("Закрыть",func():close_requested.emit()))
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;col.add_child(scroll)
	content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",12);scroll.add_child(content)
	feedback=Label.new();feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;feedback.custom_minimum_size.y=50;col.add_child(feedback)
	hide()
func _button(text: String,callback: Callable)->Button:
	var b:=Button.new();b.text=text;b.custom_minimum_size=Vector2(230,52);b.focus_mode=Control.FOCUS_NONE;b.pressed.connect(callback);return b
func _row(text: String)->HBoxContainer:
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",16);content.add_child(row)
	var label:=Label.new();label.text=text;label.custom_minimum_size=Vector2(410,52);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;row.add_child(label);return row
func configure(value: RefCounted)->void:
	settings=value
	for node in content.get_children():content.remove_child(node);node.queue_free()
	var row:=_row("Предел кадров в секунду")
	var fps:=OptionButton.new();fps.custom_minimum_size=Vector2(400,52)
	for count in [30,60,90,120]:fps.add_item(str(count))
	fps.select([30,60,90,120].find(settings.fps));fps.item_selected.connect(func(i:int):settings.fps=[30,60,90,120][i];changed.emit());row.add_child(fps)
	row=_row("Графика")
	var quality:=OptionButton.new();quality.custom_minimum_size=Vector2(400,52)
	for name in ["Экономичная · простые материалы","Сбалансированная · детали, MSAA ×2","Высокая · детали, MSAA ×4"]:quality.add_item(name)
	quality.select(settings.quality);quality.item_selected.connect(func(i:int):settings.quality=i;changed.emit());row.add_child(quality)
	_slider("Чувствительность стика",0.5,2,0.05,settings.sensitivity,func(v:float):settings.sensitivity=v;changed.emit())
	_slider("Мёртвая зона стика",0.05,0.3,0.01,settings.deadzone,func(v:float):settings.deadzone=v;changed.emit())
	_slider("Размер текста архива",16,26,1,settings.reading_size,func(v:float):settings.reading_size=int(v);changed.emit())
	for setting in [["Инвертировать вертикальный стик","invert_y"],["Гравитация у планеты на орбите","orbital_gravity"],["Показывать FPS","show_fps"]]:
		var key: String=setting[1];row=_row(str(setting[0]))
		var toggle:=CheckButton.new();toggle.custom_minimum_size=Vector2(120,52);toggle.button_pressed=bool(settings.get(key));toggle.toggled.connect(func(enabled:bool):settings.set(key,enabled);changed.emit());row.add_child(toggle)
	row=_row("Резервная копия вне приложения")
	row.add_child(_button("Экспорт сохранения",func():export_requested.emit()))
	row.add_child(_button("Импорт сохранения",func():import_requested.emit()))
	feedback.text="Профиль по умолчанию для S23 Ultra: 60 кадров/с, высокая графика. Реальные FPS и нагрев зависят от устройства. Смена настроек сохраняется отдельно от полёта."
func _slider(text: String,minimum:float,maximum:float,step:float,value:float,callback:Callable)->void:
	var row:=_row(text);var slider:=HSlider.new();slider.min_value=minimum;slider.max_value=maximum;slider.step=step;slider.value=value;slider.custom_minimum_size=Vector2(350,52);row.add_child(slider)
	var label:=Label.new();label.text="%.2f"%value;label.custom_minimum_size=Vector2(90,52);row.add_child(label)
	slider.value_changed.connect(func(v:float):label.text="%.2f"%v;callback.call(v))
