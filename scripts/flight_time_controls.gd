extends Control
# Original five acceleration levels, driven by the actual scheduler's options.
# This presentation never advances game time or decides what is safe.
const Action=preload("res://scripts/touch_action_button.gd")
const RATES:=[1,10,100,1000,10000]
signal rate_requested(rate:int)
var buttons:Dictionary={}
var status:Label
var _enabled:=true
var _state:Dictionary={}

func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	for rate:int in RATES:
		var button:=Action.new();button.name="TimeRate_"+str(rate);button.text="×"+str(rate);button.focus_mode=Control.FOCUS_NONE
		button.custom_minimum_size=Vector2(64,64);button.add_theme_font_size_override("font_size",16 if rate<1000 else 12)
		for key in ["normal","hover","pressed","disabled"]:
			var style:=StyleBoxFlat.new();style.bg_color=Color("535e61") if key=="pressed" else (Color("252b2d") if key=="disabled" else Color("929a99"))
			style.border_color=Color("d2d6d1") if key!="pressed" else Color("303638");style.set_border_width_all(1)
			button.add_theme_stylebox_override(key,style)
		button.add_theme_color_override("font_color",Color("14242b"));button.add_theme_color_override("font_disabled_color",Color("8b9798"))
		button.pressed.connect(_request_rate.bind(rate));add_child(button);buttons[rate]=button
	status=Label.new();status.mouse_filter=Control.MOUSE_FILTER_IGNORE;status.clip_text=true;status.add_theme_font_size_override("font_size",14)
	status.add_theme_color_override("font_color",Color("ffd17b"));add_child(status)
	resized.connect(_layout);_layout();configure_state(_state)

func _request_rate(rate:int)->void:rate_requested.emit(rate)

func _layout()->void:
	if status==null:return
	var gap:=4.0;var width:=maxf(64.0,(size.x-gap*4)/5)
	for index in range(RATES.size()):
		var button:Button=buttons[RATES[index]];button.position=Vector2(index*(width+gap),0);button.size=Vector2(width,64)
	status.position=Vector2(0,66);status.size=Vector2(size.x,24)

func configure_state(state:Dictionary)->void:
	_state=state.duplicate(true)
	if status==null:return
	var options:Variant=state.get("options",[])
	var by_rate:Dictionary={}
	if options is Array:
		for item in options:
			if item is Dictionary and item.get("rate") is int:by_rate[item.rate]=item
	for rate:int in RATES:
		var item:Dictionary=by_rate.get(rate,{})
		buttons[rate].disabled=not bool(item.get("enabled",rate==1))
		buttons[rate].tooltip_text=str(item.get("reason",""))
		buttons[rate].input_allowed=_enabled
		var chosen:bool=int(state.get("requested_rate",1))==rate
		buttons[rate].add_theme_color_override("font_color",Color("185c35") if chosen else Color("14242b"))
	var applied:int=int(state.get("applied_rate",1))
	status.text="ПАУЗА" if bool(state.get("paused",false)) else "Ход времени ×%d"%applied
	var reason:String=str(state.get("reason",""))
	if not reason.is_empty():status.text+=" · "+reason

func set_actions_enabled(value:bool)->void:
	_enabled=value
	for button in buttons.values():button.input_allowed=value

func release_pointers()->void:
	for button in buttons.values():button.release_pointer()
