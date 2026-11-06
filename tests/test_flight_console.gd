extends SceneTree
# Actual lower-console controls and model-to-display conversion; no game IO.
const Console=preload("res://scripts/flight_console.gd")
var console:Control
var checks:=0
var failures:=0
var events:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func touch(button:Button,pointer:int,pressed:bool)->void:
	var event:=InputEventScreenTouch.new();event.index=pointer;event.pressed=pressed;event.position=button.get_global_rect().get_center();button._input(event)
func telemetry()->void:
	var state:={"actual_speed_mps":12.25,"target_speed_mps":-100.0,"surface_active":true,"altitude_m":321.0,"hull_percent":72.0,"fuel":5,"fuel_capacity":8,"cargo_t":2,"totalcredits":71923,"elapsed_days":1.5,"landed":true,"assisted":true,"external_view":true,"contextlabel":"Новая Москва","target_local":Vector3(500,20,-800),"range_m":2000.0}
	var before:=var_to_bytes(state)
	console.configure_state(state)
	check(var_to_bytes(state)==before,"Rendering does not mutate the provided model snapshot")
	check(console.labels.speed.text=="Факт: 12.2 м/с" and console.labels.set_speed.text=="Задано: -100.0 м/с","Actual and signed requested speed retain units and distinct values")
	check(console.labels.height.text=="Высота: 321 м","Surface altitude comes from the provided model")
	check(console.labels.clock.text=="00:00:00 3-янв-3250","Elapsed virtual days use the independently verified original FFE epoch and calendar")
	check(console.labels.resources.text.contains("72%") and console.labels.resources.text.contains("5/8"),"Actual hull and fuel values are visible")
	check(console.labels.cargo.text.contains("71923") and console.labels.context.text=="Новая Москва","Cargo/account/context belong to the supplied flight")
	check(console.buttons.dock.text=="Взлететь" and console.labels.mode.text=="НА ПОВЕРХНОСТИ","Landed console offers takeoff explicitly")
	check(console._has_target and console._target==Vector3(500,20,-800) and console._range==2000.0,"Navigation instrument receives only the actual relative target")
	console.configure_state({"docked":true,"target_distance_m":2500.0,"autopilot":false,"hull_percent":100})
	check(console.buttons.dock.text=="Вылететь" and console.labels.mode.text=="В ДОКЕ","Docked state offers departure instead of landing")
	check(console.labels.height.text=="До цели: 2.5 км" and not console._has_target,"Distance converts to kilometres while missing target creates no radar contact")
	console.configure_state({"autopilot":true,"auto_text":"Отменить авто","dock_text":"Стыковка","hull_percent":0})
	check(console.buttons.auto.text=="Отменить авто" and console.buttons.dock.text=="Стыковка","Controller may supply its authoritative action labels")
	check(console.labels.mode.text=="КОРАБЛЬ ПОТЕРЯН","Destroyed-hull status takes precedence over stale automatic-flight state")
	console.configure_state({"actual_speed_mps":NAN,"target_speed_mps":INF,"elapsed_days":NAN,"target_local":Vector3(INF,0,0),"contextlabel":null})
	check(not console.labels.speed.text.to_lower().contains("nan") and not console.labels.set_speed.text.to_lower().contains("inf"),"Invalid telemetry never formats NaN or infinity")
	check(not console._has_target and console.labels.context.text.is_empty(),"Invalid target and null context are hidden without imaginary information")
func responsive_hit_regions()->void:
	for width in [720,960,1440,2400]:
		console.size=Vector2(width,Console.HEIGHT);console._layout()
		var rectangles:Array[Rect2]=[]
		for key in Console.ACTIONS:
			var button:Button=console.buttons[key];var rectangle:Rect2=button.get_rect()
			check(rectangle.size.x>=64 and rectangle.size.y>=64,"Action target remains at least64px at%d: %s"%[width,key])
			check(Rect2(Vector2.ZERO,console.size).encloses(rectangle),"Action remains inside the lower panel at%d: %s"%[width,key])
			var intersects:=false
			for previous in rectangles:intersects=intersects or previous.intersects(rectangle)
			check(not intersects,"Action targets never overlap at%d: %s"%[width,key]);rectangles.append(rectangle)
	console.size=Vector2(1440,Console.HEIGHT);console._layout()
func actions_and_release()->void:
	for key in Console.ACTIONS:console.connect(key+"_requested",func():events.append(key))
	var index:=30
	for key in Console.ACTIONS:
		var before:=events.size();var button:Button=console.buttons[key]
		touch(button,index,true);check(button.pointer_id==index,"Actual console action independently captures its finger: "+key)
		touch(button,index,false);check(events.size()==before+1 and events[-1]==key,"Touch release emits the matching live action once: "+key);index+=1
	var before:=events.size();touch(console.buttons.auto,61,true);touch(console.buttons.dock,62,true)
	check(console.buttons.auto.pointer_id==61 and console.buttons.dock.pointer_id==62,"Two lower-console actions own different simultaneous fingers")
	console.release_pointers()
	check(console.buttons.auto.pointer_id==-1 and console.buttons.dock.pointer_id==-1 and events.size()==before,"Transition release cancels every captured action without executing it")
	console.set_actions_enabled(false);touch(console.buttons.dock,63,true)
	check(console.buttons.dock.pointer_id==-1 and events.size()==before,"Blocked console rejects fresh touch actions")
	console.set_actions_enabled(true);touch(console.buttons.auto,64,true);console.hide()
	check(console.buttons.auto.pointer_id==-1,"Hiding the console releases its owned finger")
	console.show()
func complete_console_banks()->void:
	for width in [720,960,1440,2400]:
		console.size=Vector2(width,Console.HEIGHT);console._layout()
		var rectangles:Array[Rect2]=[]
		for button in console._all_pointer_buttons():
			var rectangle:Rect2=button.get_rect()
			check(rectangle.size.x>=64 and rectangle.size.y>=64,"Every classic bank and scanner control has64px touch bounds at%d: %s"%[width,button.name])
			check(Rect2(Vector2.ZERO,console.size).encloses(rectangle),"Full console control fits at%d: %s"%[width,button.name])
			var intersects:=false
			for previous in rectangles:intersects=intersects or previous.intersects(rectangle)
			check(not intersects,"Full console controls have independent nonoverlapping touch regions at%d: %s"%[width,button.name])
			rectangles.append(rectangle)
		check(console._scan_rect.size.x>=200,"Central scanner retains useful width beside both banks at%d"%width)
	console.size=Vector2(1440,Console.HEIGHT);console._layout()
	for key in Console.EXTRA_ACTIONS:console.connect(key+"_requested",func():events.append(key))
	console.configure_state({"assisted":false,"simulation_paused":true,"view_label":"ВИД НАЗАД","control_enabled":false})
	check(console.labels.mode.text=="ПАУЗА · ИНЕРЦИОННЫЙ РЕЖИМ","Real pause and inertial control are distinguished from unavailable original engines-off")
	check(console.labels.view.text=="ВИД НАЗАД" and console.buttons.pause.text=="Продолжить","Controller camera and resume operation reach the complete console")
	var before:=events.size();touch(console.buttons.control,90,true);touch(console.buttons.control,90,false)
	check(events.size()==before and console.buttons.control.pointer_id==-1,"A controller-disabled control-mode action cannot execute through touch")
	for key in ["auto","brake","dock","surface"]:
		touch(console.buttons[key],90,true);touch(console.buttons[key],90,false)
		check(console.buttons[key].disabled and events.size()==before,"Paused simulation disables physics-changing console command: "+key)
	console.set_actions_enabled(false);console.set_actions_enabled(true)
	check(console.buttons.surface.disabled and not console.buttons.pause.disabled,"Unblocking menu input preserves simulation-specific availability while resume remains available")
	touch(console.buttons.pause,90,true);touch(console.buttons.pause,90,false)
	check(events.size()==before+1 and events[-1]=="pause","The real resume command remains touch-operable during simulation pause")
	console.configure_state({"surface_text":"Взлететь","surface_enabled":false,"cargo_t":12,"cargo_capacity_t":60})
	check(console.buttons.surface.text=="Взлететь" and console.buttons.surface.disabled,"Controller-authoritative surface label and availability reach the console")
	check(console.labels.cargo.text.contains("12/60"),"Cargo display distinguishes actual load from actual configured capacity")
	console.configure_state({"assisted":true,"simulation_paused":false,"control_enabled":true})
	for key in Console.EXTRA_ACTIONS:
		before=events.size();touch(console.buttons[key],91,true);touch(console.buttons[key],91,false)
		check(events.size()==before+1 and events[-1]==key,"New classic console command emits its real controller hook exactly once: "+key)
	check(console.buttons.pause.text=="Пауза" and console.labels.mode.text=="СТАБИЛИЗАЦИЯ","Leaving pause restores live presentation without leaving stale text")
func actual_scanner_and_scale()->void:
	var snapshot:={"target_local":Vector3(80,20,-120),"range_m":400.0,"elapsed_days":4.0,"scanner_contacts":[{"position":Vector3(10,-1,-20),"kind":"friendly"},{"position":Vector3(-8,3,40),"kind":"hostile"},{"position":Vector3(INF,0,0)},null,{"position":"invented"}]}
	var original:=var_to_bytes(snapshot)
	console.configure_state(snapshot)
	check(console._contacts.size()==2,"Scanner accepts only supplied finite physical contacts and rejects invalid entries")
	check(console._contacts[0].position==Vector3(10,-1,-20) and console._target==snapshot.target_local,"Scanner retains actual contact and target coordinates")
	var before:=events.size();var clock:String=console.labels.clock.text
	for step in range(4):touch(console.scanner_buttons["in"],100,true);touch(console.scanner_buttons["in"],100,false)
	check(console._scanner_zoom==16.0 and console.scanner_buttons["in"].disabled,"Real scale buttons reach the bounded nearest scanner scale")
	touch(console.scanner_buttons["in"],101,true)
	check(console.scanner_buttons["in"].pointer_id==-1,"At the scale bound a disabled plus button cannot capture a finger")
	check(console.labels.scanner_range.text=="ШКАЛА\n25 м","Scanner scale labels use the real physical input range divided by presentation zoom")
	for step in range(6):touch(console.scanner_buttons["out"],102,true);touch(console.scanner_buttons["out"],102,false)
	check(console._scanner_zoom==0.25 and console.scanner_buttons["out"].disabled,"Real scale buttons reach the bounded farthest scanner scale")
	check(var_to_bytes(snapshot)==original and events.size()==before and console.labels.clock.text==clock,"Local scanner scaling neither modifies model telemetry nor emits a physics or time command")
	console.configure_state({})
	check(console._contacts.is_empty() and not console._has_target,"An empty physical snapshot leaves the scanner empty")
	var center:=Vector2(720,124);var radii:=Vector2(220,34)
	console.configure_state({"range_m":400.0})
	console._scanner_zoom=1.0
	var below:Dictionary=console._project_contact(Vector3(0,-400,400),center,radii)
	check(below.top.y<=164 and below.clipped,"A real lower-hemisphere contact is bounded above the scale and64px zoom controls")
	check(below.outside,"A contact farther than the physical scanner range is marked as beyond-scale instead of an ordinary nearby contact")
	var ahead:Dictionary=console._project_contact(Vector3(0,0,-200),center,radii)
	check(ahead.foot.is_equal_approx(Vector2(720,107)) and ahead.top==ahead.foot and not ahead.outside and not ahead.clipped,"An in-range forward contact retains its real bearing with no invented elevation or boundary mark")
	console._zoom_scanner(1)
	touch(console.scanner_buttons["in"],103,true);touch(console.buttons.pause,104,true)
	check(console.scanner_buttons["in"].pointer_id==103 and console.buttons.pause.pointer_id==104,"Range and pause buttons can own simultaneous independent fingers")
	before=events.size();console.set_actions_enabled(false)
	check(console.scanner_buttons["in"].pointer_id==-1 and console.buttons.pause.pointer_id==-1 and events.size()==before,"Controller blocking cancels scanner and console touches without executing commands")
	console.set_actions_enabled(true)
func run()->void:
	root.size=Vector2i(1440,720);console=Console.new();root.add_child(console);console.size=Vector2(1440,Console.HEIGHT)
	await process_frame
	telemetry();responsive_hit_regions();actions_and_release();complete_console_banks();actual_scanner_and_scale()
	console.queue_free();await process_frame
	print("FLIGHT CONSOLE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
