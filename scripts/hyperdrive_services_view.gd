extends VBoxContainer
# Equipment/fuel quotes are copied presentation data. Main/Navigation own every
# transaction, capacity check and save; this embedded view emits requests only.
const Action=preload("res://scripts/touch_action_button.gd")
signal command(action:String,id:String,quantity:int)
signal runtime_command(action:String,enabled:bool)
var buttons:Dictionary={}
var action_buttons:Array[Button]=[]
var labels:Dictionary={}
var _state:Dictionary={}
var input_allowed:=true:
	set(value):
		input_allowed=value
		if not value:release_pointers()
		for button in action_buttons:button.input_allowed=value

func _ready()->void:
	size_flags_horizontal=Control.SIZE_EXPAND_FILL;custom_minimum_size.x=300
	add_theme_constant_override("separation",12);_render()
func configure_state(state:Dictionary)->void:
	_state=state.duplicate(true)
	if is_node_ready():_render()
func release_pointers()->void:
	for button in action_buttons:button.release_pointer()
func _notification(what:int)->void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_EXIT_TREE]:release_pointers()
	elif what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():release_pointers()
func _clear()->void:
	release_pointers()
	for child in get_children():remove_child(child);child.queue_free()
	buttons.clear();action_buttons.clear();labels.clear()
func _number(row:Dictionary,key:String)->float:
	var value:Variant=row.get(key)
	return float(value) if (value is int or value is float) and is_finite(float(value)) else NAN
func _text(row:Dictionary,key:String,fallback:="")->String:
	return row[key] if row.get(key) is String else fallback
func _amount(value:float,decimals:=2)->String:
	if not is_finite(value):return "—"
	return str(roundi(value)) if is_equal_approx(value,roundf(value)) else String.num(value,decimals)
func _quantity(row:Dictionary,key:String,fallback:=1)->int:
	var value:=_number(row,key)
	return int(value) if is_finite(value) and value>=1 and value<=1000000 and value==floorf(value) else fallback
func _label(parent:Control,key:String,text:String,font_size:=20,muted:=false)->Label:
	var label:=Label.new();label.name="HyperdriveLabel_"+key.replace(":","_");label.text=text;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("8eafbd") if muted else Color("dcebf3"));parent.add_child(label);labels[key]=label;return label
func _section(text:String)->void:
	var separator:=HSeparator.new();add_child(separator)
	var title:=_label(self,"section:"+text,text,22);title.add_theme_color_override("font_color",Color("8cdbd1"))
func _card()->VBoxContainer:
	var panel:=PanelContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var style:=StyleBoxFlat.new();style.bg_color=Color("0a1b2b");style.border_color=Color("284b5b");style.set_border_width_all(1);style.set_corner_radius_all(10)
	style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=12;style.content_margin_bottom=12;panel.add_theme_stylebox_override("panel",style);add_child(panel)
	var box:=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",9);panel.add_child(box);return box
func _editable()->bool:
	return _state.get("source_mode",false)==true and _state.get("docked",false)==true and _state.get("service_available",false)==true
func _button(parent:Control,key:String,text:String,available:bool,reason:="")->Button:
	var button:=Action.new();button.name="HyperdriveAction_"+key.replace(":","_");button.text=text;button.tooltip_text=reason;button.custom_minimum_size=Vector2(136,72)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.focus_mode=Control.FOCUS_NONE;button.clip_text=true;button.disabled=not available;button.input_allowed=input_allowed
	button.add_theme_font_size_override("font_size",18)
	for role in ["normal","hover","pressed","disabled"]:
		var style:=StyleBoxFlat.new();style.bg_color=Color("163e4b") if role=="pressed" else Color("102a3c");style.border_color=Color("78d9d6") if role in ["hover","pressed"] else Color("325767");style.set_border_width_all(1);style.set_corner_radius_all(9)
		style.content_margin_left=7;style.content_margin_right=7;button.add_theme_stylebox_override(role,style)
	button.add_theme_color_override("font_color",Color("e0f1f5"));button.add_theme_color_override("font_disabled_color",Color("78929e"))
	parent.add_child(button);buttons[key]=button;action_buttons.append(button);return button
func _action(parent:Control,key:String,text:String,action:String,id:String,quantity:int,available:bool,reason:="")->Button:
	var button:=_button(parent,key,text,available and _editable() and quantity>0,reason)
	button.pressed.connect(func():
		if input_allowed and _editable() and is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled and quantity>0:command.emit(action,id,quantity)
	)
	return button
func _fuel_runtime_context()->bool:
	var fuel:Variant=_state.get("fuel_system")
	return _state.get("source_mode",false)==true and fuel is Dictionary and fuel.get("source_mode",false)==true
func _runtime_action(parent:Control,key:String,text:String,action:String,enabled:bool,available:bool,reason:="")->Button:
	var button:=_button(parent,key,text,available and _fuel_runtime_context(),reason)
	button.pressed.connect(func():
		if input_allowed and _fuel_runtime_context() and is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled:runtime_command.emit(action,enabled)
	)
	return button

func _price(row:Dictionary,key:String,caption:="")->String:
	var value:=_number(row,key)
	return "\n"+caption+_amount(value)+" кр." if is_finite(value) and value>=0 else ""
func _reason(parent:Control,key:String,text:String)->void:
	if not text.is_empty():_label(parent,key,text,17,true)


func _render_fuel_system()->void:
	var value:Variant=_state.get("fuel_system")
	if not value is Dictionary:return
	var fuel:Dictionary=value
	if fuel.get("source_mode",false)!=true:return
	_section("РЕАКТИВНОЕ ТОПЛИВО")
	var tank:=_card()
	var percent:=_number(fuel,"jet_percent")
	_label(tank,"jetfuel","Реактивный бак: "+(_amount(percent,1)+"%" if is_finite(percent) else "—"),23)
	if is_finite(_number(fuel,"jet_tonnes")) and is_finite(_number(fuel,"jet_capacity_tonnes")):
		_label(tank,"jetfuel_tonnes","В баке: %s / %s т"%[_amount(_number(fuel,"jet_tonnes")),_amount(_number(fuel,"jet_capacity_tonnes"))],18,true)
	if fuel.get("jet_above_nominal",false)==true:_reason(tank,"jet_above_nominal","Уровень выше номинальной ёмкости бака.")
	_label(tank,"jet_hydrogen","Водород в трюме: "+_amount(_number(_state,"hydrogen"))+" т",19)
	var forward:Variant=fuel.get("forward_propulsion_available",fuel.get("propulsion_available"))
	if forward is bool and not forward:
		_reason(tank,"jet_thrust","Прямая/подъёмная тяга недоступна — заправьте бак из груза.")
	_runtime_action(tank,"manual_jet_refuel","Заправить бак из трюма","manual_jet_refuel",false,fuel.get("can_manual_refuel",false)==true,_text(fuel,"manual_refuel_reason"))
	if fuel.get("can_manual_refuel",false)!=true:_reason(tank,"manual_jet_reason",_text(fuel,"manual_refuel_reason"))
	_reason(tank,"fuel_state_reason",_text(fuel,"reason"));_reason(tank,"fuel_upgrade",_text(fuel,"upgrade_notice"))
	var refueller:=_card();var installed:Variant=fuel.get("refueller_installed");var enabled:Variant=fuel.get("refueller_enabled")
	var mode:="—"
	if installed is bool:
		if not installed:mode="не установлен"
		elif enabled is bool:mode="включён" if enabled else "выключен"
	_label(refueller,"refueller","Автозаправщик: "+mode,21)
	if installed==true and enabled is bool:
		_runtime_action(refueller,"set_refueller_enabled","Выключить автозаправщик" if enabled else "Включить автозаправщик","set_refueller_enabled",not enabled,fuel.get("can_toggle_refueller",false)==true,_text(fuel,"toggle_reason"))
		if fuel.get("can_toggle_refueller",false)!=true:_reason(refueller,"refueller_reason",_text(fuel,"toggle_reason"))
	var scoop:=_card();var fitted:Variant=fuel.get("scoop_installed")
	_label(scoop,"scoop","Топливозаборник: "+("установлен" if fitted else "не установлен") if fitted is bool else "Топливозаборник: —",21)
	_reason(scoop,"scoop_status",_text(fuel,"scoop_status"));_reason(scoop,"scoop_heat",_text(fuel,"heat_label"))
	var seconds:=_number(fuel,"cooldown_seconds")
	if is_finite(seconds):_label(scoop,"scoop_cooldown","До следующего сбора: "+_amount(seconds,2)+" с",18,true)
	if fuel.get("atmospheric_shielding_installed") is bool:_label(scoop,"scoop_shielding","Атмосферная защита: "+("установлена" if fuel.atmospheric_shielding_installed else "не установлена"),18,true)
	if fitted==true:_reason(scoop,"scoop_controls","Для сбора нужен инерционный режим и фактическая скорость не ниже 875 м/с.")

func _render_fuel_equipment()->void:
	var items:Variant=_state.get("fuel_equipment",[])
	if not items is Array or items.is_empty():return
	_section("ЗАПРАВОЧНОЕ ОБОРУДОВАНИЕ")
	for item:Variant in items:
		if not item is Dictionary:continue
		var equipment:Dictionary=item;var id:=_text(equipment,"id")
		if id not in ["refueller","scoop","atmospheric_shielding"]:continue
		var card:=_card();_label(card,"fuel_equipment:"+id,_text(equipment,"name","Заправочное оборудование"),21)
		_label(card,"fuel_equipment_mass:"+id,"Занимает: "+_amount(_number(equipment,"mass_t"))+" т",18,true)
		var fitted:bool=equipment.get("installed",false)==true
		if fitted:_label(card,"fuel_equipment_installed:"+id,"Установлено",18,true)
		if not _editable():continue
		if fitted:
			_action(card,"remove_fuel_equipment:"+id,"Снять"+_price(equipment,"remove_refund","Возврат "),"remove_fuel_equipment",id,1,equipment.get("can_remove",false)==true,_text(equipment,"remove_reason"))
			if equipment.get("can_remove",false)!=true:_reason(card,"fuel_equipment_reason:"+id,_text(equipment,"remove_reason"))
		else:
			_action(card,"install_fuel_equipment:"+id,"Установить"+_price(equipment,"install_price"),"install_fuel_equipment",id,1,equipment.get("can_install",false)==true,_text(equipment,"install_reason"))
			if equipment.get("can_install",false)!=true:_reason(card,"fuel_equipment_reason:"+id,_text(equipment,"install_reason"))

func _current_drive_name()->String:
	var name:=_text(_state,"drive_name")
	if not name.is_empty():return name
	var drives:Variant=_state.get("drives",[])
	if drives is Array:
		for row:Variant in drives:
			if row is Dictionary and row.get("installed",false)==true:return _text(row,"name","Гипердвигатель")
	return "Не установлен" if _state.get("source_mode",false)==true and _number(_state,"drive_class")==0 else "Гипердвигатель"
func _render()->void:
	_clear()
	_section("ГИПЕРДВИГАТЕЛЬ")
	var current:=_card();_label(current,"drive",_current_drive_name(),24)
	var class_label:=_text(_state,"drive_class_label",_text(_state,"class_label"))
	if not class_label.is_empty():_label(current,"class","Класс: "+class_label,18,true)
	_label(current,"range","Дальность перехода: "+_amount(_number(_state,"range_ly"))+" св. лет",21)
	var profile:=_text(_state,"profile_name")
	if not profile.is_empty():_label(current,"ship","Корабль: "+profile,18,true)
	if is_finite(_number(_state,"credits")):_label(current,"credits","Баланс: "+_amount(_number(_state,"credits"))+" кр.",18)
	_label(current,"capacity","Занято: %s / %s т · Свободно: %s т"%[_amount(_number(_state,"occupied_t")),_amount(_number(_state,"source_capacity_t")),_amount(_number(_state,"free_t"))],19)
	if is_finite(_number(_state,"flight_cargo_t")):_label(current,"flight_cargo","Текущий груз: "+_amount(_number(_state,"flight_cargo_t"))+" т",18,true)
	if not _editable():_reason(current,"readonly",_text(_state,"reason","Замена двигателя и покупка топлива доступны после стыковки."))
	else:
		_action(current,"remove_drive","Снять гипердвигатель"+_price(_state,"remove_price","Возврат "),"remove_drive","",1,_state.get("can_remove",false)==true,_text(_state,"remove_reason"))
		if _state.get("can_remove",false)!=true:_reason(current,"remove_reason",_text(_state,"remove_reason"))
	_render_fuel_system()
	_render_fuel_equipment()
	_section("ТОПЛИВО И ОТХОДЫ")
	var inventory:=_card()
	_label(inventory,"hydrogen","Водородное топливо: "+_amount(_number(_state,"hydrogen"))+" т")
	_label(inventory,"military","Военное топливо: "+_amount(_number(_state,"military"))+" т")
	_label(inventory,"radioactives","Радиоактивные отходы: "+_amount(_number(_state,"radioactives"))+" т")
	if _editable():
		var fuels:Variant=_state.get("fuels",[])
		if fuels is Array:
			for item:Variant in fuels:
				if not item is Dictionary:continue
				var fuel:Dictionary=item;var id:=_text(fuel,"id")
				if id not in ["hydrogen","military"]:continue
				var fuel_box:=_card();_label(fuel_box,"fuel:"+id,"Водородное топливо" if id=="hydrogen" else "Военное топливо",21)
				var row:=HBoxContainer.new();row.add_theme_constant_override("separation",10);fuel_box.add_child(row)
				_action(row,"refuel:"+id,"Купить 1 т"+_price(fuel,"unit_price"),"refuel",id,1,fuel.get("can_refuel",false)==true,_text(fuel,"reason"))
				if fuel.has("fill_quantity"):
					var quantity:=_quantity(fuel,"fill_quantity",0)
					_action(row,"fill:"+id,("Заправить %d т"%quantity if quantity>0 else "Заполнить")+_price(fuel,"fill_price"),"refuel",id,quantity,quantity>0 and fuel.get("can_fill",false)==true,_text(fuel,"fill_reason"))
				if fuel.has("can_unload"):
					var amount:=_quantity(fuel,"unload_quantity",0)
					var text:="Передать %d т космопорту"%amount if amount>0 else "Передать топливо космопорту"
					text+=("\nБез оплаты и возмещения" if _number(fuel,"unload_price")==0 else _price(fuel,"unload_price"))
					_action(fuel_box,"unload_fuel:"+id,text,"unload_fuel",id,amount,amount>0 and fuel.get("can_unload",false)==true,_text(fuel,"unload_reason"))
					if fuel.get("can_unload",false)!=true:_reason(fuel_box,"unload_reason:"+id,_text(fuel,"unload_reason"))
				if fuel.get("can_refuel",false)!=true:_reason(fuel_box,"fuel_reason:"+id,_text(fuel,"reason"))
				if fuel.has("fill_quantity") and fuel.get("can_fill",false)!=true:_reason(fuel_box,"fill_reason:"+id,_text(fuel,"fill_reason"))
		if _state.has("can_unload_waste"):
			var waste:=_card();var quantity:=_quantity(_state,"unload_quantity",0)
			_action(waste,"unload_waste",("Сдать отходы: %d т"%quantity if quantity>0 else "Сдать отходы")+_price(_state,"waste_price"),"unload_waste","",quantity,_state.get("can_unload_waste",false)==true,_text(_state,"waste_reason"))
			if _state.get("can_unload_waste",false)!=true:_reason(waste,"waste_reason",_text(_state,"waste_reason"))
	var drives:Variant=_state.get("drives",[])
	if drives is Array and not drives.is_empty():
		_section("ДОСТУПНЫЕ ГИПЕРДВИГАТЕЛИ")
		for item:Variant in drives:
			if not item is Dictionary:continue
			var drive:Dictionary=item;var id:=str(drive.get("id",drive.get("class","")))
			if id.is_empty():continue
			var card:=_card();_label(card,"drive:"+id,_text(drive,"name","Гипердвигатель"),21)
			_label(card,"drive_space:"+id,"Занимает: "+_amount(_number(drive,"space_t"))+" т",18,true)
			if drive.get("installed",false)==true:_label(card,"installed:"+id,"Установлен",18,true)
			elif _editable():
				_action(card,"install_drive:"+id,"Установить"+_price(drive,"price"),"install_drive",id,1,drive.get("can_install",false)==true,_text(drive,"reason"))
				if drive.get("can_install",false)!=true:_reason(card,"drive_reason:"+id,_text(drive,"reason"))
