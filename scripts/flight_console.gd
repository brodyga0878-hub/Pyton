extends Control
# Functional, touch-sized rendering of the lower FFE instrument console.
# The current scanner is explicitly a target instrument: contacts are supplied by
# the simulation. Presentation never creates objects, advances time or saves.
const TouchAction=preload("res://scripts/touch_action_button.gd")
const SourceClock=preload("res://scripts/source_clock.gd")
const HEIGHT:=240.0
const ACTIONS:=["system","routes","auto","brake","dock","view","menu"]
const EXTRA_ACTIONS:=["status","equipment","control","surface","pause"]
const LEFT_BANK:=["view","system","routes","status","equipment","menu"]
const RIGHT_BANK:=["auto","brake","dock","control","surface","pause"]
signal system_requested
signal routes_requested
signal menu_requested
signal view_requested
signal auto_requested
signal brake_requested
signal dock_requested
signal status_requested
signal equipment_requested
signal control_requested
signal surface_requested
signal pause_requested
signal gear_requested
var buttons:Dictionary={}
var scanner_buttons:Dictionary={}
var labels:Dictionary={}
var _state:Dictionary={}
var _target:=Vector3.ZERO
var _has_target:=false
var _range:=1.0
var _scanner_zoom:=1.0
var _contacts:Array[Dictionary]=[]
var _built:=false
var _bank_width:=432.0
var _scan_rect:=Rect2()
var _actions_enabled:=true
var _gear_present:=false

class ActionIcon extends Control:
	var symbol:=""
	var active:=false
	var alert:=false
	var fraction:=0.0
	func _ready()->void:mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw()->void:
		var c:=Vector2(size.x*0.5,22.0)
		var ink:=Color("d4eadc") if active else Color("3e4749")
		var green:=Color("73e58f");var red:=Color("d1554d");var gold:=Color("d1af5d")
		if alert:ink=Color("eab96a")
		match symbol:
			"system":
				draw_circle(c,12,Color("a9bccc"));draw_arc(c,12,0,TAU,36,ink,1.8,true)
				draw_arc(c,6,0,TAU,28,Color("526c87"),1.3,true);draw_line(c+Vector2(-11,0),c+Vector2(11,0),Color("526c87"),1.3,true)
			"routes":
				var points:=PackedVector2Array([c+Vector2(-13,8),c+Vector2(-5,-10),c+Vector2(4,6),c+Vector2(14,-8)])
				draw_polyline(points,Color("526c87"),2,true)
				for p in points:draw_circle(p,3,Color("d5e9e1"));draw_arc(p,3,0,TAU,16,ink,1,true)
			"auto":
				draw_arc(c,11,0,TAU,36,green if active else ink,2,true)
				draw_line(c+Vector2(-16,0),c+Vector2(16,0),green if active else ink,1.6,true);draw_line(c+Vector2(0,-15),c+Vector2(0,15),green if active else ink,1.6,true)
				draw_circle(c,3,red)
			"brake":
				for x in [-8,3]:draw_rect(Rect2(c+Vector2(x,-11),Vector2(5,22)),red)
				draw_line(c+Vector2(-13,13),c+Vector2(13,13),ink,1.5,true)
			"dock":
				draw_polyline(PackedVector2Array([c+Vector2(-14,-10),c+Vector2(-14,12),c+Vector2(14,12),c+Vector2(14,-10)]),ink,2.5,true)
				draw_line(c+Vector2(0,-15),c+Vector2(0,7),green,2.5,true);draw_polyline(PackedVector2Array([c+Vector2(-6,0),c+Vector2(0,7),c+Vector2(6,0)]),green,2.5,true)
			"view":
				draw_colored_polygon(PackedVector2Array([c+Vector2(-14,-7),c+Vector2(7,-7),c+Vector2(7,-11),c+Vector2(15,-11),c+Vector2(15,9),c+Vector2(-14,9)]),Color("9ba9ad"))
				draw_rect(Rect2(c+Vector2(-9,-3),Vector2(12,8)),Color("364d60"));draw_line(c+Vector2(-14,11),c+Vector2(15,11),ink,2,true)
			"menu":
				for y in [-9,0,9]:draw_line(c+Vector2(-12,y),c+Vector2(12,y),ink,3,true)
				for y in [-9,9]:draw_circle(c+Vector2(0,y),2,gold)
			"status":
				draw_circle(c+Vector2(0,-5),7,Color("c4d0c9"));draw_arc(c+Vector2(0,-5),7,PI,TAU,24,ink,2,true)
				draw_colored_polygon(PackedVector2Array([c+Vector2(-14,13),c+Vector2(-8,3),c+Vector2(8,3),c+Vector2(14,13)]),Color("577766"))
				draw_line(c+Vector2(-4,-4),c+Vector2(4,-4),ink,2,true)
			"equipment":
				draw_rect(Rect2(c+Vector2(-13,-10),Vector2(26,23)),Color("b6a77d"));draw_rect(Rect2(c+Vector2(-13,-10),Vector2(26,23)),ink,false,2)
				draw_line(c+Vector2(-4,-10),c+Vector2(-4,13),ink,2,true);draw_line(c+Vector2(4,-10),c+Vector2(4,13),ink,2,true)
			"control":
				draw_colored_polygon(PackedVector2Array([c+Vector2(-7,-13),c+Vector2(7,-13),c+Vector2(11,4),c+Vector2(-11,4)]),Color("93a5ac"))
				draw_line(c+Vector2(-10,5),c+Vector2(10,5),ink,2,true)
				for x in [-6,0,6]:draw_line(c+Vector2(x,8),c+Vector2(x,15 if active else 11),green if active else gold,2,true)
			"surface":
				draw_arc(c+Vector2(0,10),17,PI,TAU,36,green,2,true)
				draw_line(c+Vector2(0,-15),c+Vector2(0,3),ink,2,true);draw_polyline(PackedVector2Array([c+Vector2(-6,-3),c+Vector2(0,3),c+Vector2(6,-3)]),ink,2,true)
			"pause":
				if active:draw_colored_polygon(PackedVector2Array([c+Vector2(-8,-12),c+Vector2(12,0),c+Vector2(-8,12)]),green)
				else:
					for x in [-9,3]:draw_rect(Rect2(c+Vector2(x,-11),Vector2(6,22)),ink)
			"gear":
				c.y=13
				var down:=clampf(fraction,0,1);var gear_ink:=green if down>=1.0 else (gold if down>0 else ink)
				draw_line(c+Vector2(-13,-7),c+Vector2(13,-7),ink,2,true)
				for x in [-9.0,9.0]:
					var foot:=c+Vector2(x,lerpf(-3,8,down))
					draw_line(c+Vector2(x,-7),foot,gear_ink,2,true);draw_line(foot+Vector2(-4,0),foot+Vector2(4,0),gear_ink,2,true)

func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_build();resized.connect(_layout);_layout();configure_state(_state)

func _style(fill:Color,pressed:=false,top_margin:=42.0)->StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=fill
	style.border_color=Color("32373c") if pressed else Color("d6d9d3")
	style.border_width_left=2;style.border_width_top=2;style.border_width_right=1;style.border_width_bottom=1
	style.content_margin_top=top_margin;style.content_margin_bottom=2;style.content_margin_left=2;style.content_margin_right=2
	return style

func _make_button(key:String)->Button:
	var button:=TouchAction.new();button.name="ConsoleAction_"+key;button.focus_mode=Control.FOCUS_NONE
	button.input_allowed=_actions_enabled
	button.custom_minimum_size=Vector2(64,64);button.clip_text=true
	button.add_theme_stylebox_override("normal",_style(Color("a3a8a5")))
	button.add_theme_stylebox_override("hover",_style(Color("c0c5bf")))
	button.add_theme_stylebox_override("pressed",_style(Color("686f70"),true))
	button.add_theme_stylebox_override("disabled",_style(Color("666e70"),true))
	button.add_theme_color_override("font_color",Color("19282d"));button.add_theme_color_override("font_pressed_color",Color("e9e3ca"));button.add_theme_color_override("font_disabled_color",Color("b0b6b0"))
	button.add_theme_constant_override("outline_size",0)
	button.pressed.connect(_action.bind(key));add_child(button);buttons[key]=button
	var icon:=ActionIcon.new();icon.name="Icon";icon.symbol=key;icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);button.add_child(icon)
	return button

func _build()->void:
	if _built:return
	_built=true
	for key in ["speed","set_speed","height","clock","resources","cargo","mode","view","context","target","scanner_range"]:
		var label:=Label.new();label.name="Console_"+key;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		label.clip_text=true;label.add_theme_color_override("font_color",Color("dfe1da"));label.add_theme_constant_override("outline_size",1)
		add_child(label);labels[key]=label
	for key in ACTIONS+EXTRA_ACTIONS:_make_button(key)
	for key in ["out","in"]:
		var button:=TouchAction.new();button.name="ScannerZoom_"+key;button.focus_mode=Control.FOCUS_NONE
		button.input_allowed=_actions_enabled
		button.custom_minimum_size=Vector2(64,64);button.text="−" if key=="out" else "+"
		button.tooltip_text="Увеличить дальность сканера" if key=="out" else "Уменьшить дальность сканера"
		button.add_theme_font_size_override("font_size",32)
		button.add_theme_stylebox_override("normal",_style(Color("343c3b"),false,0))
		button.add_theme_stylebox_override("hover",_style(Color("46504b"),false,0))
		button.add_theme_stylebox_override("pressed",_style(Color("1e2826"),true,0))
		button.add_theme_color_override("font_color",Color("b4d2b6"))
		button.pressed.connect(_zoom_scanner.bind(-1 if key=="out" else 1));add_child(button);scanner_buttons[key]=button

func _action(key:String)->void:
	match key:
		"system":system_requested.emit()
		"routes":routes_requested.emit()
		"menu":menu_requested.emit()
		"view":view_requested.emit()
		"auto":auto_requested.emit()
		"brake":brake_requested.emit()
		"dock":dock_requested.emit()
		"status":status_requested.emit()
		"equipment":equipment_requested.emit()
		"control":control_requested.emit()
		"surface":surface_requested.emit()
		"pause":pause_requested.emit()
		"gear":
			if _gear_present and _actions_enabled and buttons.has("gear") and not buttons.gear.disabled and buttons.gear.is_visible_in_tree():gear_requested.emit()

func _configure_gear()->void:
	var present:bool=_state.get("gear_available",false)==true
	if present and not buttons.has("gear"):
		var button:=_make_button("gear")
		for role in ["normal","hover","pressed","disabled"]:
			var style:StyleBoxFlat=button.get_theme_stylebox(role).duplicate();style.content_margin_top=26
			button.add_theme_stylebox_override(role,style)
	elif not present and buttons.has("gear"):
		var button:Button=buttons.gear;button.release_pointer();buttons.erase("gear");remove_child(button);button.queue_free()
	var changed:=_gear_present!=present;_gear_present=present
	if changed:_layout()
	if not present:return
	var caption:="Шасси";var status:=""
	if _state.get("gear_text") is String and not _state.gear_text.strip_edges().is_empty():caption=_state.gear_text.replace("\n"," ").replace("\r"," ").strip_edges()
	if _state.get("gear_status") is String:status=_state.gear_status.replace("\n"," ").replace("\r"," ").strip_edges()
	buttons.gear.text=caption+("\n"+status if not status.is_empty() else "")
	buttons.gear.tooltip_text=status if not status.is_empty() else "Выпуск или уборка шасси"
	var icon:ActionIcon=buttons.gear.get_node("Icon");icon.fraction=clampf(_number("gear_fraction"),0,1);icon.queue_redraw()

func _zoom_scanner(direction:int)->void:
	_scanner_zoom=clampf(_scanner_zoom*2.0 if direction>0 else _scanner_zoom/2.0,0.25,16.0)
	_update_scanner_labels();queue_redraw()

func _all_pointer_buttons()->Array:
	return buttons.values()+scanner_buttons.values()

func release_pointers()->void:
	for button in _all_pointer_buttons():button.release_pointer()

func set_actions_enabled(value:bool)->void:
	_actions_enabled=value
	for button in _all_pointer_buttons():button.input_allowed=value
	_update_action_availability()

func _update_action_availability()->void:
	if not _built:return
	var paused:=bool(_state.get("simulation_paused",false))
	buttons.control.disabled=paused or not bool(_state.get("control_enabled",true))
	buttons.surface.disabled=paused or not bool(_state.get("surface_enabled",true))
	for key in ["auto","brake","dock"]:buttons[key].disabled=paused
	if _gear_present:
		buttons.gear.disabled=paused or _state.get("gear_enabled",false)!=true
		if buttons.gear.disabled:buttons.gear.release_pointer()
	scanner_buttons["out"].disabled=_scanner_zoom<=0.25
	scanner_buttons["in"].disabled=_scanner_zoom>=16.0

func _place(key:String,at:Vector2,dimensions:Vector2,font_size:int,alignment:int=HORIZONTAL_ALIGNMENT_LEFT)->void:
	var label:Label=labels[key];label.position=at;label.size=dimensions;label.horizontal_alignment=alignment;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",font_size)

func _layout()->void:
	if not _built:return
	var width:=maxf(1,size.x);var compact:=width<1000;var font_size:=16 if compact else 20
	var third:float=(width-24.0)/3.0
	_place("speed",Vector2(8,0),Vector2(third,27),font_size)
	_place("set_speed",Vector2(8+third,0),Vector2(third,27),font_size,HORIZONTAL_ALIGNMENT_CENTER)
	_place("height",Vector2(8+third*2,0),Vector2(third,27),font_size,HORIZONTAL_ALIGNMENT_RIGHT)
	_bank_width=maxf(208.0,width*0.30)
	# 720px is the supported minimum layout. At narrow desktop windows the bank
	# still has a truthful minimum size rather than overlapping touch targets.
	var right_x:=width-_bank_width
	var small:=12 if compact else 17
	for key in ["clock","resources","cargo"]:
		_place(key,Vector2(10,30+23*["clock","resources","cargo"].find(key)),Vector2(_bank_width-20,23),small+1 if key=="clock" else small)
	for key in ["mode","view","context"]:
		_place(key,Vector2(right_x+10,30+23*["mode","view","context"].find(key)),Vector2(_bank_width-20,23),small+1 if key=="mode" else small,HORIZONTAL_ALIGNMENT_RIGHT)
	var button_width:=(_bank_width-16.0)/3.0
	for bank in [LEFT_BANK,RIGHT_BANK]:
		var start_x:=6.0 if bank==LEFT_BANK else right_x+6.0
		for index in range(bank.size()):
			var button:Button=buttons[bank[index]]
			button.position=Vector2(start_x+(index%3)*(button_width+2),104+floori(index/3.0)*68)
			button.size=Vector2(button_width,64);button.add_theme_font_size_override("font_size",11 if compact else 17)
	_scan_rect=Rect2(Vector2(_bank_width+8,30),Vector2(maxf(1,width-2*_bank_width-16),HEIGHT-34))
	_place("target",Vector2(_scan_rect.position.x+8,32),Vector2(_scan_rect.size.x-16,22),11 if compact else 15,HORIZONTAL_ALIGNMENT_CENTER)
	_place("scanner_range",Vector2(_scan_rect.get_center().x-66,182),Vector2(132,47),10 if compact else 13,HORIZONTAL_ALIGNMENT_CENTER)
	for key in ["out","in"]:
		var button:Button=scanner_buttons[key]
		button.position=Vector2(_scan_rect.position.x+3 if key=="out" else _scan_rect.end.x-67,172);button.size=Vector2(64,64)
	if _gear_present:
		var gear_width:=minf(180.0,_scan_rect.size.x-140.0)
		buttons.gear.position=Vector2(_scan_rect.get_center().x-gear_width*0.5,172);buttons.gear.size=Vector2(gear_width,64)
		buttons.gear.add_theme_font_size_override("font_size",11 if compact else 14)
		_place("scanner_range",Vector2(_scan_rect.position.x+40,55),Vector2(_scan_rect.size.x-80,22),12 if compact else 15,HORIZONTAL_ALIGNMENT_CENTER)
	queue_redraw()

func _number(key:String,fallback:=0.0)->float:
	var value:Variant=_state.get(key,fallback)
	return float(value) if (value is int or value is float) and is_finite(float(value)) else fallback

func _distance(value:float)->String:
	if not is_finite(value) or value<0:return "—"
	return "%.1f км"%(value/1000.0) if value>=1000 else "%.0f м"%value

func _update_scanner_labels()->void:
	if not _built:return
	labels.scanner_range.text=("ШКАЛА " if _gear_present else "ШКАЛА\n")+_distance(_range/_scanner_zoom)
	# Refit after replacing the previous two-line text; its old minimum size
	# must not leave the one-line scale extending into scanner contact glyphs.
	if _gear_present:labels.scanner_range.size.y=22
	_update_action_availability()

func configure_state(state:Dictionary)->void:
	_state=state.duplicate(true)
	if not _built:return
	_configure_gear()
	labels.speed.text="Факт: %.1f м/с"%maxf(0,_number("actual_speed_mps"))
	labels.set_speed.text="Задано: %.1f м/с"%_number("target_speed_mps")
	var surface_active:bool=bool(state.get("surface_active",false))
	labels.height.text=("Высота: "+_distance(maxf(0,_number("altitude_m")))) if surface_active else ("До цели: "+_distance(_number("target_distance_m",-1)))
	var calendar:=SourceClock.from_elapsed_days(clampf(_number("elapsed_days"),0,SourceClock.MAX_ELAPSED_DAYS))
	labels.clock.text=str(calendar.get("label_ru","—"))
	var hull:=clampf(_number("hull_percent",100),0,100)
	labels.resources.text="Корпус %.0f%% · Топливо %d/%d"%[hull,int(maxf(0,_number("fuel"))),int(maxf(0,_number("fuel_capacity")))]
	var cargo_capacity:=int(maxf(0,_number("cargo_capacity_t")))
	labels.cargo.text=("Груз %d/%d т · %d кр."%[int(maxf(0,_number("cargo_t"))),cargo_capacity,int(maxf(0,_number("totalcredits")))]) if cargo_capacity>0 else ("Груз %d т · %d кр."%[int(maxf(0,_number("cargo_t"))),int(maxf(0,_number("totalcredits")))])
	var mode:="СТАБИЛИЗАЦИЯ" if bool(state.get("assisted",true)) else "ИНЕРЦИОННЫЙ РЕЖИМ"
	if bool(state.get("autopilot",false)) or bool(state.get("landing",false)) or not str(state.get("flight_phase","")).is_empty():mode="АВТОПИЛОТ"
	if str(state.get("flight_phase",""))=="ascent":mode="ПОДЪЁМ НА ОРБИТУ"
	elif str(state.get("flight_phase",""))=="descent":mode="СПУСК К ПОВЕРХНОСТИ"
	if bool(state.get("taking_off",false)):mode="ВЗЛЁТ"
	if bool(state.get("landed",false)):mode="НА ПОВЕРХНОСТИ"
	if bool(state.get("docked",false)):mode="В ДОКЕ"
	if hull<=0:mode="КОРАБЛЬ ПОТЕРЯН"
	var paused:=bool(state.get("simulation_paused",false))
	if paused:mode="ПАУЗА · "+mode
	labels.mode.text=mode
	labels.view.text=str(state.get("view_label","ВНЕШНИЙ ВИД" if bool(state.get("external_view",false)) else "ВИД ВПЕРЁД"))
	labels.context.text=state.contextlabel if state.get("contextlabel") is String else ""
	labels.clock.add_theme_color_override("font_color",Color("f8bb56"));labels.mode.add_theme_color_override("font_color",Color("ffba5e") if hull>0 else Color("ff7863"))
	buttons.system.text="Система";buttons.routes.text="Карта";buttons.menu.text="Меню";buttons.view.text="Камера"
	buttons.auto.text="Отмена" if bool(state.get("autopilot",false)) or bool(state.get("landing",false)) or not str(state.get("flight_phase","")).is_empty() else "Авто"
	buttons.brake.text="Тормозить";buttons.dock.text="Взлететь" if bool(state.get("landed",false)) else ("Вылететь" if bool(state.get("docked",false)) else ("Посадка" if surface_active else "Стыковка"))
	buttons.status.text="Борткомп.";buttons.equipment.text="Оснащение";buttons.control.text="Стабилиз." if bool(state.get("assisted",true)) else "Инерция"
	buttons.surface.text="На орбиту" if surface_active else "Поверхн.";buttons.pause.text="Продолжить" if paused else "Пауза"
	if state.get("surface_text") is String and not state.surface_text.is_empty():buttons.surface.text=state.surface_text
	if state.get("pause_text") is String and not state.pause_text.is_empty():buttons.pause.text=state.pause_text
	if state.get("auto_text") is String and not state.auto_text.is_empty():buttons.auto.text=state.auto_text
	if state.get("dock_text") is String and not state.dock_text.is_empty():buttons.dock.text=state.dock_text
	var tips:={"view":"Сменить направление камеры","system":"Система и выбор объекта","routes":"Секторная карта и гиперпереход","menu":"Меню полёта и отчёт об ошибке","status":"Бортовой компьютер: состояние и цель","equipment":"Грузовой отсек и установленное оборудование","auto":"Автопилот к выбранной цели / отмена","brake":"Отменить автоматический полёт и остановиться","dock":"Стыковка, посадка или взлёт","control":"Переключить стабилизацию и инерционное управление","surface":"Спуск к поверхности или подъём на орбиту","pause":"Пауза симуляции / продолжение"}
	for key in tips:buttons[key].tooltip_text=tips[key]
	for key in buttons:
		var icon:ActionIcon=buttons[key].get_node("Icon")
		icon.active=(key=="auto" and bool(state.get("autopilot",false))) or (key=="control" and bool(state.get("assisted",true))) or (key=="pause" and paused)
		icon.queue_redraw()
	var candidate:Variant=state.get("target_local",null);_has_target=candidate is Vector3 and candidate.is_finite() and is_finite(candidate.length())
	_target=candidate if _has_target else Vector3.ZERO;_range=maxf(1,_number("range_m",maxf(50,_target.length()*1.25)))
	_contacts.clear()
	var supplied:Variant=state.get("scanner_contacts",[])
	if supplied is Array:
		for entry in supplied:
			if not entry is Dictionary:continue
			var point:Variant=entry.get("position")
			if not point is Vector3 or not point.is_finite() or not is_finite(point.length()):continue
			_contacts.append({"position":point,"kind":str(entry.get("kind","unknown"))})
	labels.target.text="Цель · "+_distance(_target.length()) if _has_target else "Цель не выбрана"
	_update_scanner_labels();queue_redraw()

func _ellipse(center:Vector2,radii:Vector2,color:Color,line_width:float=1.0)->void:
	var points:=PackedVector2Array()
	for step in range(65):
		var angle:=TAU*step/64.0;points.append(center+Vector2(cos(angle)*radii.x,sin(angle)*radii.y))
	draw_polyline(points,color,line_width,true)

func _project_contact(point:Vector3,center:Vector2,radii:Vector2)->Dictionary:
	var range_m:=_range/_scanner_zoom
	var planar:=Vector2(point.x,point.z)/range_m
	planar=planar.limit_length(0.94)
	var foot:=center+Vector2(planar.x*radii.x,planar.y*radii.y)
	var elevation:=clampf(point.y/range_m,-1,1)*38.0
	var raw_top:=foot-Vector2(0,elevation)
	# The instrument plot ends above the scale/buttons. A capped elevation is
	# marked as such rather than drawing a contact into a different instrument.
	var top:=Vector2(raw_top.x,clampf(raw_top.y,81.0 if _gear_present else 61.0,164.0))
	return {"foot":foot,"top":top,"outside":point.length()>range_m,"clipped":not top.is_equal_approx(raw_top)}

func _draw_contact(point:Vector3,color:Color,center:Vector2,radii:Vector2,selected:=false)->void:
	var projection:=_project_contact(point,center,radii)
	if projection.outside and not selected:return
	var foot:Vector2=projection.foot;var top:Vector2=projection.top
	draw_line(foot,top,color,1.8,true);draw_circle(foot,1.7,color.darkened(0.3))
	if projection.outside or projection.clipped:
		# An open chevron indicates a bearing/elevation beyond the current plot;
		# its true distance remains in the target label above the scanner.
		var direction:=Vector2(0,1 if point.y<0 else -1) if projection.clipped else (foot-center).normalized()
		if direction.length_squared()<0.01:direction=Vector2.UP
		var lateral:=Vector2(-direction.y,direction.x)
		draw_polyline(PackedVector2Array([top-direction*3-lateral*4,top+direction*3,top-direction*3+lateral*4]),color,1.8,true)
	elif selected:
		draw_polyline(PackedVector2Array([top+Vector2(-5,0),top+Vector2(0,-4),top+Vector2(5,0),top+Vector2(0,4),top+Vector2(-5,0)]),color,1.5,true)
	else:draw_line(top-Vector2(3,0),top+Vector2(3,0),color,2.5,true)

func _draw_gauge(at:Vector2,height:float,ratio:float,color:Color)->void:
	draw_rect(Rect2(at-Vector2(2,2),Vector2(10,height+4)),Color("111a1c"))
	draw_rect(Rect2(at+Vector2(0,height*(1-ratio)),Vector2(6,height*ratio)),color)
	for tick in range(5):draw_line(at+Vector2(-2,height*tick/4.0),at+Vector2(8,height*tick/4.0),Color("737c75"),1,true)

func _draw()->void:
	var width:=size.x
	draw_rect(Rect2(0,0,width,HEIGHT),Color("7c8585"));draw_rect(Rect2(0,0,width,28),Color("151d20"))
	draw_line(Vector2(0,28),Vector2(width,28),Color("d8ded7"),2,true)
	# The angular side plates form the distinctive continuous lower cockpit.
	var left:=PackedVector2Array([Vector2(0,29),Vector2(_bank_width-14,29),Vector2(_bank_width+5,98),Vector2(_bank_width,HEIGHT),Vector2(0,HEIGHT)])
	var right:=PackedVector2Array([Vector2(width-_bank_width+14,29),Vector2(width,29),Vector2(width,HEIGHT),Vector2(width-_bank_width,HEIGHT),Vector2(width-_bank_width-5,98)])
	draw_colored_polygon(left,Color("727c7f"));draw_colored_polygon(right,Color("727c7f"))
	draw_polyline(left,Color("c4ccca"),2,true);draw_polyline(right,Color("c4ccca"),2,true)
	draw_colored_polygon(PackedVector2Array([Vector2(_scan_rect.position.x,29),Vector2(_scan_rect.end.x,29),Vector2(_scan_rect.end.x-8,HEIGHT),Vector2(_scan_rect.position.x+8,HEIGHT)]),Color("0b1115"))
	for x in [6.0,width-8]:
		for y in [34.0,97.0,HEIGHT-5]:draw_circle(Vector2(x,y),2.2,Color("303b3e"));draw_circle(Vector2(x-0.6,y-0.6),0.9,Color("d4dad2"))
	var center:=Vector2(_scan_rect.get_center().x,124)
	var radii:=Vector2(maxf(24,_scan_rect.size.x*0.43),34)
	for band in range(3):_ellipse(center,radii+Vector2(band*2.0,band*0.75),Color(0.42,0.07,0.07,0.28),2.0)
	for ratio in [1.0,0.66,0.33]:_ellipse(center,radii*ratio,Color("9b3935") if ratio==1.0 else Color("572e2c"),1.5 if ratio==1.0 else 1.0)
	draw_line(center-Vector2(radii.x,0),center+Vector2(radii.x,0),Color("623a37"),1,true)
	draw_line(center-Vector2(0,radii.y),center+Vector2(0,radii.y),Color("623a37"),1,true)
	draw_line(center+Vector2(-radii.x*.7,radii.y*.7),center+Vector2(radii.x*.7,-radii.y*.7),Color("462c2b"),1,true)
	draw_polyline(PackedVector2Array([center+Vector2(-4,3),center+Vector2(0,-5),center+Vector2(4,3)]),Color("c9dfcc"),1.5,true)
	for contact in _contacts:
		var ink:=Color("75ce94") if contact.kind=="friendly" else (Color("e66c61") if contact.kind=="hostile" else Color("c0c8c1"))
		_draw_contact(contact.position,ink,center,radii)
	if _has_target:_draw_contact(_target,Color("7ce4ab"),center,radii,true)
	_draw_gauge(Vector2(_scan_rect.position.x+3,61),99,clampf(_number("hull_percent",100)/100.0,0,1),Color("69c78a"))
	var capacity:=_number("fuel_capacity",0)
	_draw_gauge(Vector2(_scan_rect.end.x-9,61),99,clampf(_number("fuel")/capacity,0,1) if capacity>0 else 0,Color("c4b15e"))
