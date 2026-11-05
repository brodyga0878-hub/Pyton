extends VBoxContainer
# Read-only presentation of model quotes. Only the controller executes services.
const TouchAction=preload("res://scripts/touch_action_button.gd")
signal command(action:String,id:String)
var buttons:Dictionary={}
var action_buttons:Array[Button]=[]
var labels:Dictionary={}
var _state:Dictionary={}

func _ready()->void:
	custom_minimum_size.x=900;size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",14)
	_render()

func configure_state(state:Dictionary)->void:
	_state=state.duplicate(true)
	if is_node_ready():_render()

func release_pointers()->void:
	for button in action_buttons:button.release_pointer()

func _clear()->void:
	release_pointers()
	for child in get_children():remove_child(child);child.queue_free()
	buttons.clear();action_buttons.clear();labels.clear()

func _number(record:Dictionary,key:String,fallback:=0.0)->float:
	var value:Variant=record.get(key,fallback)
	return float(value) if (value is int or value is float) and is_finite(float(value)) else fallback

func _text(record:Dictionary,key:String,fallback:="")->String:
	return record[key] if record.get(key) is String else fallback

func _label(text:String,font_size:=21)->Label:
	var label:=Label.new();label.text=text;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",Color("e1e3dd"))
	return label

func _section(text:String)->void:
	var line:=HSeparator.new();add_child(line)
	var title:=_label(text,23);title.add_theme_color_override("font_color",Color("efb45e"));add_child(title)

func _style(fill:Color,edge:Color)->StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=fill;style.border_color=edge
	style.border_width_left=2;style.border_width_top=2;style.border_width_right=1;style.border_width_bottom=1
	style.content_margin_left=8;style.content_margin_right=8;style.content_margin_top=7;style.content_margin_bottom=7
	return style

func _action(parent:Control,key:String,text:String,action:String,id:String,available:bool,width:=220.0,hint:="")->Button:
	var button:=TouchAction.new();button.name="Service_"+key.replace(":","_");button.text=text
	button.custom_minimum_size=Vector2(width,76);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.focus_mode=Control.FOCUS_NONE;button.clip_text=true;button.disabled=not available;button.tooltip_text=hint
	button.add_theme_font_size_override("font_size",20)
	button.add_theme_stylebox_override("normal",_style(Color("59636c"),Color("a7b0b4")))
	button.add_theme_stylebox_override("hover",_style(Color("6c7881"),Color("d1c19b")))
	button.add_theme_stylebox_override("pressed",_style(Color("3a474f"),Color("dbac57")))
	button.add_theme_stylebox_override("disabled",_style(Color("293039"),Color("46515b")))
	button.add_theme_color_override("font_color",Color("f4eee1"));button.add_theme_color_override("font_disabled_color",Color("89949c"))
	button.pressed.connect(func():
		if not button.disabled:command.emit(action,id)
	)
	parent.add_child(button);buttons[key]=button;action_buttons.append(button);return button

func _service(parent:HBoxContainer,key:String,text:String,available:bool,reason:String)->void:
	var column:=VBoxContainer.new();column.custom_minimum_size.x=276;column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",6);parent.add_child(column)
	_action(column,key,text,key,"",available,276,reason)
	if not available and not reason.is_empty():
		var status:=_label(reason,18);status.add_theme_color_override("font_color",Color("c4c8c7"));column.add_child(status);labels[key+"_status"]=status

func _render()->void:
	_clear()
	var hull:=_number(_state,"hull");var hull_text:="%.0f%%"%hull if is_equal_approx(hull,roundf(hull)) else "%.1f%%"%hull
	var summary:=_label("Корабль: %s · Баланс: %d кр. · Корпус: %s"%[_text(_state,"profile_name","—"),int(_number(_state,"credits")),hull_text],23)
	add_child(summary);labels["summary"]=summary
	var capacity:=_label("Груз: %d/%d т · Гипертопливо: %d/%d"%[int(_number(_state,"cargo_used")),int(_number(_state,"cargo_capacity")),int(_number(_state,"fuel")),int(_number(_state,"fuel_capacity"))])
	add_child(capacity);labels["capacity"]=capacity
	if _state.get("original_port",false)==true:
		var unavailable:=_label("Службы этого космопорта пока недоступны. Учебный рынок находится у тренировочного орбитального узла.")
		add_child(unavailable);labels["unavailable"]=unavailable;return
	if _state.get("docked",false)!=true:
		var unavailable:=_label("Для доступа к службам сначала выполните стыковку.")
		add_child(unavailable);labels["unavailable"]=unavailable;return
	if _number(_state,"hull")<=0:
		var unavailable:=_label("Корабль потерян: обслуживание недоступно.")
		add_child(unavailable);labels["unavailable"]=unavailable;return
	var role:=_label("ТРЕНИРОВОЧНЫЙ УЗЕЛ · УЧЕБНЫЙ РЫНОК И ОБСЛУЖИВАНИЕ",20)
	role.add_theme_color_override("font_color",Color("efb45e"));add_child(role);labels["role"]=role
	_section("ОБСЛУЖИВАНИЕ И ДОСТАВКА")
	var service_row:=HBoxContainer.new();service_row.add_theme_constant_override("separation",12);add_child(service_row)
	var repair:Dictionary=_state.get("repair",{}) if _state.get("repair") is Dictionary else {}
	var refuel:Dictionary=_state.get("refuel",{}) if _state.get("refuel") is Dictionary else {}
	var delivery:Dictionary=_state.get("delivery",{}) if _state.get("delivery") is Dictionary else {}
	_service(service_row,"repair","Ремонт корпуса\n%d кр."%int(_number(repair,"price")),repair.get("can_repair",false)==true,_text(repair,"reason"))
	_service(service_row,"refuel","Заправить гипердвигатель\n%d кр."%int(_number(refuel,"price")),refuel.get("can_refuel",false)==true,_text(refuel,"reason"))
	_service(service_row,"deliver","Сдать учебные лекарства\nНаграда %d кр."%int(_number(delivery,"reward")),delivery.get("can_deliver",false)==true,_text(delivery,"reason"))
	_section("ГРУЗОВОЙ РЫНОК · ЦЕНЫ ЗА 1 Т")
	var goods:Variant=_state.get("goods",[])
	if goods is Array:
		for raw in goods:
			if not raw is Dictionary:continue
			var good:Dictionary=raw;var id:=_text(good,"id")
			if id.is_empty():continue
			var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);row.custom_minimum_size.y=76;add_child(row)
			var label:=_label("%s\nВ трюме: %d т"%[_text(good,"name",id),int(_number(good,"owned"))],22)
			label.custom_minimum_size.x=360;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label);labels["good:"+id]=label
			_action(row,"buy:"+id,"Купить 1 т\n%d кр."%int(_number(good,"buy_price")),"buy",id,good.get("can_buy",false)==true,220,_text(good,"buy_reason"))
			_action(row,"sell:"+id,"Продать 1 т\n%d кр."%int(_number(good,"sell_price")),"sell",id,good.get("can_sell",false)==true,220,_text(good,"sell_reason"))
	_section("ОБМЕН КОРАБЛЯ")
	var ships:Variant=_state.get("ships",[])
	if ships is Array:
		for raw in ships:
			if not raw is Dictionary:continue
			var ship:Dictionary=raw;var id:=_text(ship,"id")
			if id.is_empty():continue
			var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);row.custom_minimum_size.y=76;add_child(row)
			var current:bool=ship.get("current",false)==true
			var label:=_label("%s · трюм %d т%s"%[_text(ship,"name",id),int(_number(ship,"cargo_capacity"))," · текущий" if current else ""],22)
			label.custom_minimum_size.x=500;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label);labels["ship:"+id]=label
			var price:=int(_number(ship,"trade_cost"));var offer:="Доплата: %d кр."%price if price>=0 else "К получению: %d кр."%(-price)
			_action(row,"trade_ship:"+id,"Текущий корабль" if current else "Обменять\n"+offer,"trade_ship",id,not current and ship.get("can_trade",false)==true,320,_text(ship,"reason"))
