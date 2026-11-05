extends Control
# Original instrument layout inspired by the classic lower flight console.
# Displays actual model data and emits actions; never advances physics or saves.
const TouchAction=preload("res://scripts/touch_action_button.gd")
const SourceClock=preload("res://scripts/source_clock.gd")
const HEIGHT:=184.0
const ACTIONS:=["system","routes","auto","brake","dock","view","menu"]
signal system_requested
signal routes_requested
signal menu_requested
signal view_requested
signal auto_requested
signal brake_requested
signal dock_requested
var buttons:Dictionary={}
var labels:Dictionary={}
var _state:Dictionary={}
var _target:=Vector3.ZERO
var _has_target:=false
var _range:=1.0
var _built:=false

class ActionIcon extends Control:
	var symbol:=""
	func _ready()->void:mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw()->void:
		var c:=Vector2(size.x*0.5,17);var ink:=Color("e4ad48")
		match symbol:
			"system":
				draw_arc(c,10,0,TAU,28,ink,1.5,true);draw_arc(c,5,0,TAU,20,ink,1,true);draw_circle(c+Vector2(8,-6),2,Color("9ee986"))
			"routes":
				var points:=[c+Vector2(-10,8),c+Vector2(0,-8),c+Vector2(11,7)]
				draw_polyline(PackedVector2Array(points),ink,1.5,true)
				for point in points:draw_circle(point,2.5,ink)
			"auto":
				draw_arc(c,9,0,TAU,28,ink,1.5,true);draw_line(c+Vector2(-13,0),c+Vector2(13,0),ink,1.5,true);draw_line(c+Vector2(0,-13),c+Vector2(0,13),ink,1.5,true)
			"brake":
				draw_rect(Rect2(c+Vector2(-9,-9),Vector2(6,18)),Color("eaa16c"));draw_rect(Rect2(c+Vector2(3,-9),Vector2(6,18)),Color("eaa16c"))
			"dock":
				draw_polyline(PackedVector2Array([c+Vector2(-12,-10),c+Vector2(-12,10),c+Vector2(12,10),c+Vector2(12,-10)]),ink,2,true)
				draw_line(c+Vector2(0,-12),c+Vector2(0,4),Color("a8eea1"),2,true);draw_polyline(PackedVector2Array([c+Vector2(-5,-1),c+Vector2(0,4),c+Vector2(5,-1)]),Color("a8eea1"),2,true)
			"view":
				draw_polyline(PackedVector2Array([c+Vector2(-14,0),c+Vector2(-6,-8),c+Vector2(6,-8),c+Vector2(14,0),c+Vector2(6,8),c+Vector2(-6,8),c+Vector2(-14,0)]),ink,1.5,true);draw_circle(c,4,ink)
			"menu":
				for y in [-8,0,8]:draw_line(c+Vector2(-12,y),c+Vector2(12,y),ink,2,true)

func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_build();resized.connect(_layout);_layout();configure_state(_state)

func _style(fill:Color,pressed:=false)->StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=fill;style.border_color=Color("292d31") if pressed else Color("abb0b3")
	style.border_width_left=2;style.border_width_top=2;style.border_width_right=1;style.border_width_bottom=1
	style.content_margin_top=29;style.content_margin_bottom=3;style.content_margin_left=5;style.content_margin_right=5
	return style

func _build()->void:
	if _built:return
	_built=true
	for key in ["speed","set_speed","height","clock","resources","cargo","mode","view","context","target"]:
		var label:=Label.new();label.name="Console_"+key;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		label.clip_text=true;label.add_theme_color_override("font_color",Color("dfe1da"));label.add_theme_constant_override("outline_size",1)
		add_child(label);labels[key]=label
	for key in ACTIONS:
		var button:=TouchAction.new();button.name="ConsoleAction_"+key;button.focus_mode=Control.FOCUS_NONE
		button.custom_minimum_size=Vector2(64,72);button.clip_text=true
		button.add_theme_stylebox_override("normal",_style(Color("686e74")))
		button.add_theme_stylebox_override("hover",_style(Color("7d858a")))
		button.add_theme_stylebox_override("pressed",_style(Color("454d53"),true))
		button.add_theme_stylebox_override("disabled",_style(Color("41474c"),true))
		button.add_theme_color_override("font_color",Color("f0ece1"));button.add_theme_color_override("font_pressed_color",Color("ffd89a"))
		button.pressed.connect(_action.bind(key));add_child(button);buttons[key]=button
		var icon:=ActionIcon.new();icon.symbol=key;icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);button.add_child(icon)

func _action(key:String)->void:
	match key:
		"system":system_requested.emit()
		"routes":routes_requested.emit()
		"menu":menu_requested.emit()
		"view":view_requested.emit()
		"auto":auto_requested.emit()
		"brake":brake_requested.emit()
		"dock":dock_requested.emit()

func release_pointers()->void:
	for button in buttons.values():button.release_pointer()

func set_actions_enabled(value:bool)->void:
	for button in buttons.values():button.input_allowed=value

func _place(key:String,at:Vector2,dimensions:Vector2,font_size:int,alignment:int=HORIZONTAL_ALIGNMENT_LEFT)->void:
	var label:Label=labels[key];label.position=at;label.size=dimensions;label.horizontal_alignment=alignment;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",font_size)

func _layout()->void:
	if not _built:return
	var width:=maxf(1,size.x);var compact:=width<1000;var font_size:=18 if compact else 23
	var third:float=(width-24.0)/3.0
	_place("speed",Vector2(8,0),Vector2(third,31),font_size)
	_place("set_speed",Vector2(8+third,0),Vector2(third,31),font_size,HORIZONTAL_ALIGNMENT_CENTER)
	_place("height",Vector2(8+third*2,0),Vector2(third,31),font_size,HORIZONTAL_ALIGNMENT_RIGHT)
	var side:float=width*0.32;var small:=15 if compact else 19
	_place("clock",Vector2(12,33),Vector2(side,24),small+1)
	_place("resources",Vector2(12,57),Vector2(side,23),small)
	_place("cargo",Vector2(12,80),Vector2(side,23),small)
	_place("mode",Vector2(width-side-12,34),Vector2(side,23),small+1,HORIZONTAL_ALIGNMENT_RIGHT)
	_place("view",Vector2(width-side-12,57),Vector2(side,23),small,HORIZONTAL_ALIGNMENT_RIGHT)
	_place("context",Vector2(width-side-12,80),Vector2(side,23),small,HORIZONTAL_ALIGNMENT_RIGHT)
	_place("target",Vector2(width*0.35,88),Vector2(width*0.30,18),13 if compact else 15,HORIZONTAL_ALIGNMENT_CENTER)
	var row_width:=minf(width-16,1150);var gap:=6.0;var button_width:float=(row_width-gap*6)/7.0;var x:float=(width-row_width)*0.5
	for key in ACTIONS:
		var button:Button=buttons[key];button.position=Vector2(x,108);button.size=Vector2(button_width,72);button.add_theme_font_size_override("font_size",17 if compact else 22);x+=button_width+gap
	queue_redraw()

func _number(key:String,fallback:=0.0)->float:
	var value:Variant=_state.get(key,fallback)
	return float(value) if (value is int or value is float) and is_finite(float(value)) else fallback

func _distance(value:float)->String:
	if not is_finite(value) or value<0:return "—"
	return "%.1f км"%(value/1000.0) if value>=1000 else "%.0f м"%value

func configure_state(state:Dictionary)->void:
	_state=state.duplicate(true)
	if not _built:return
	labels.speed.text="Факт: %.1f м/с"%maxf(0,_number("actual_speed_mps"))
	labels.set_speed.text="Задано: %.1f м/с"%_number("target_speed_mps")
	var surface_active:bool=bool(state.get("surface_active",false))
	labels.height.text=("Высота: "+_distance(maxf(0,_number("altitude_m")))) if surface_active else ("До цели: "+_distance(_number("target_distance_m",-1)))
	var calendar:=SourceClock.from_elapsed_days(clampf(_number("elapsed_days"),0,SourceClock.MAX_ELAPSED_DAYS))
	labels.clock.text=str(calendar.get("label_ru","—"))
	var hull:=clampf(_number("hull_percent",100),0,100)
	labels.resources.text="Корпус %.0f%% · Топливо %d/%d"%[hull,int(maxf(0,_number("fuel"))),int(maxf(0,_number("fuel_capacity")))]
	labels.cargo.text="Груз %d т · %d кр."%[int(maxf(0,_number("cargo_t"))),int(maxf(0,_number("totalcredits")))]
	var mode:="СТАБИЛИЗАЦИЯ" if bool(state.get("assisted",true)) else "РУЧНОЕ УПРАВЛЕНИЕ"
	if bool(state.get("autopilot",false)) or bool(state.get("landing",false)) or not str(state.get("flight_phase","")).is_empty():mode="АВТОПИЛОТ"
	if str(state.get("flight_phase",""))=="ascent":mode="ПОДЪЁМ НА ОРБИТУ"
	elif str(state.get("flight_phase",""))=="descent":mode="СПУСК К ПОВЕРХНОСТИ"
	if bool(state.get("taking_off",false)):mode="ВЗЛЁТ"
	if bool(state.get("landed",false)):mode="НА ПОВЕРХНОСТИ"
	if bool(state.get("docked",false)):mode="В ДОКЕ"
	if hull<=0:mode="КОРАБЛЬ ПОТЕРЯН"
	labels.mode.text=mode;labels.view.text="ВНЕШНИЙ ВИД" if bool(state.get("external_view",false)) else "ВИД ВПЕРЁД";labels.context.text=state.contextlabel if state.get("contextlabel") is String else ""
	labels.clock.add_theme_color_override("font_color",Color("ffb548"));labels.mode.add_theme_color_override("font_color",Color("ffb548") if hull>0 else Color("ff7863"))
	buttons.system.text="Система";buttons.routes.text="Маршруты";buttons.menu.text="Меню";buttons.view.text="Вид"
	buttons.auto.text="Отмена" if bool(state.get("autopilot",false)) or bool(state.get("landing",false)) or not str(state.get("flight_phase","")).is_empty() else "Авто"
	buttons.brake.text="Тормозить";buttons.dock.text="Взлететь" if bool(state.get("landed",false)) else ("Вылететь" if bool(state.get("docked",false)) else ("Посадка" if surface_active else "Стыковка"))
	if state.get("auto_text") is String and not state.auto_text.is_empty():buttons.auto.text=state.auto_text
	if state.get("dock_text") is String and not state.dock_text.is_empty():buttons.dock.text=state.dock_text
	var candidate:Variant=state.get("target_local",null);_has_target=candidate is Vector3 and candidate.is_finite() and is_finite(candidate.length())
	_target=candidate if _has_target else Vector3.ZERO;_range=maxf(1,_number("range_m",maxf(50,_target.length()*1.25)))
	labels.target.text="Цель · "+_distance(_target.length()) if _has_target else "Цель не выбрана"
	queue_redraw()

func _draw()->void:
	var width:=size.x
	draw_rect(Rect2(0,0,width,HEIGHT),Color("50565a"));draw_rect(Rect2(0,0,width,32),Color("14191c"))
	draw_line(Vector2(0,32),Vector2(width,32),Color("bbc0bf"),2,true);draw_line(Vector2(0,106),Vector2(width,106),Color("b6bcbd"),2,true)
	draw_colored_polygon(PackedVector2Array([Vector2(width*.31,33),Vector2(width*.69,33),Vector2(width*.74,106),Vector2(width*.26,106)]),Color("080d10"))
	for x in [width*.31,width*.69]:draw_line(Vector2(x,33),Vector2(width*.26 if x<width*.5 else width*.74,106),Color("9babab"),2,true)
	var c:=Vector2(width*.5,65);var radius:=23.0;var green:=Color("64ca83")
	draw_arc(c,radius,0,TAU,64,Color("50755e"),1,true);draw_arc(c,radius*.5,0,TAU,40,Color("314e3d"),1,true)
	draw_line(c-Vector2(radius,0),c+Vector2(radius,0),Color("345344"),1,true);draw_line(c-Vector2(0,radius),c+Vector2(0,radius),Color("345344"),1,true)
	draw_line(c,c+Vector2(0,-radius),Color("9ed3a2"),1,true)
	if _has_target:
		var planar:=Vector2(_target.x,_target.z)/_range*radius
		planar=planar.limit_length(radius-2);var elevation:=clampf(_target.y/_range,-1,1)*radius*0.45
		draw_line(c+planar,c+planar-Vector2(0,elevation),green,1.5,true);draw_circle(c+planar-Vector2(0,elevation),2.5,green)
