extends SceneTree
# Phone hit/layout contract for an optional source gear control. The model owns
# requested direction, mechanism movement and command availability.
const Console=preload("res://scripts/flight_console.gd")
var console:Control
var checks:=0
var failures:=0
var commands:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func frame()->void:await process_frame;await process_frame
func fixture()->Dictionary:
	return {"gear_available":true,"gear_enabled":true,"gear_text":"Убрать шасси","gear_status":"Выпуск 50%","gear_fraction":0.5,"range_m":4000.0,"target_local":Vector3(500,20,-800),"hull_percent":72.0,"fuel":5,"fuel_capacity":8,"assisted":false}
func touch(button:Button,pointer:int,pressed:bool)->void:
	var event:=InputEventScreenTouch.new();event.index=pointer;event.pressed=pressed;event.position=button.get_global_rect().get_center();root.push_input(event,true)
func optional_layout_and_contacts()->void:
	for width:int in [720,1440,1920]:
		console.configure_state({"range_m":4000.0});console.size=Vector2(width,Console.HEIGHT);console._layout();await frame()
		var legacy:Dictionary={};var legacy_scale:Rect2=console.labels.scanner_range.get_rect();var scan:Rect2=console._scan_rect
		check(console.buttons.size()==12 and console._all_pointer_buttons().size()==14,"Legacy state retains exactly12classic actions plus the existing scanner zoom controls")
		for key:String in console.buttons:legacy[key]=console.buttons[key].get_rect()
		for key:String in console.scanner_buttons:legacy["zoom:"+key]=console.scanner_buttons[key].get_rect()
		var data:=fixture();var before:=var_to_bytes(data);console.configure_state(data);await frame()
		check(var_to_bytes(data)==before and console.buttons.size()==13 and console._all_pointer_buttons().size()==15,"Optional gear rendering adds exactly one action without changing supplied source data")
		for key:String in legacy:
			var actual:Rect2=console.scanner_buttons[key.trim_prefix("zoom:")].get_rect() if key.begins_with("zoom:") else console.buttons[key].get_rect()
			check(actual==legacy[key],"Existing classic/zoom control retains its exact position and size at width"+str(width)+": "+key)
		var rect:Rect2=console.buttons.gear.get_rect();var label_rect:Rect2=console.labels.scanner_range.get_rect()
		check(rect.size.x>=132 and rect.size.y>=64 and Rect2(Vector2.ZERO,console.size).encloses(rect),"Optional gear retains a large contained touch target even at720px")
		for key:String in legacy:check(not rect.intersects(legacy[key]),"Gear cannot overlap an existing classic action or scanner zoom target: "+key)
		check(scan==console._scan_rect and label_rect.end.y<=77 and label_rect.position.y>=55 and not label_rect.intersects(rect),"Scanner width and plot are retained while its scale moves above the ellipse")
		check(console.labels.scanner_range.text=="ШКАЛА 4.0 км" and not console.labels.scanner_range.text.contains("\n"),"Gear mode keeps the actual zoom scale in a readable single line")
		check(console.buttons.gear.text=="Убрать шасси\nВыпуск 50%" and console.buttons.gear.get_node("Icon").fraction==0.5,"Ready human command/status and mechanism fraction reach the dedicated classic-style control")
		var font:Font=console.buttons.gear.get_theme_font("font");var font_size:int=console.buttons.gear.get_theme_font_size("font_size")
		for line:String in console.buttons.gear.text.split("\n"):check(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x<=rect.size.x-4,"Both gear caption lines are readable without clipping at width"+str(width))
		var center:=Vector2(console._scan_rect.get_center().x,124);var radii:=Vector2(console._scan_rect.size.x*0.43,34)
		for point:Vector3 in [Vector3(0,4000,-4000),Vector3(0,-4000,4000),Vector3(4000,4000,0)]:
			var projection:Dictionary=console._project_contact(point,center,radii)
			check(projection.top.y>=81 and projection.top.y<=164 and projection.foot.y>=90,"Real scanner contact stems and glyphs remain below the relocated scale and above gear controls")
		console.configure_state({"range_m":4000.0});await frame()
		check(console.buttons.size()==12 and not console.buttons.has("gear") and console.labels.scanner_range.get_rect()==legacy_scale and console.labels.scanner_range.text=="ШКАЛА\n4.0 км","Removing optional gear restores the exact previous scale/button layout")
func touch_availability_and_lifetime()->void:
	console.size=Vector2(720,Console.HEIGHT);console.configure_state(fixture());console._layout();await frame()
	var before:=commands;touch(console.buttons.gear,151,true)
	check(console.buttons.gear.pointer_id==151,"Gear action independently owns its real finger at720px")
	touch(console.buttons.gear,151,false);await frame()
	check(commands==before+1 and console.buttons.gear.get_node("Icon").fraction==0.5,"Gear touch emits one request without optimistically changing authoritative mechanism position")
	var data:=fixture();data.gear_enabled=false;console.configure_state(data);before=commands
	touch(console.buttons.gear,152,true);touch(console.buttons.gear,152,false);console.buttons.gear.pressed.emit()
	check(console.buttons.gear.disabled and console.buttons.gear.pointer_id==-1 and commands==before,"Unavailable model command cannot capture or dispatch gear even through a forced signal")
	data=fixture();data.simulation_paused=true;console.configure_state(data);console.buttons.gear.pressed.emit()
	check(console.buttons.gear.disabled and commands==before,"Simulation pause blocks the gear physics request while retaining its status")
	console.configure_state(fixture());touch(console.buttons.gear,153,true);console.set_actions_enabled(false)
	check(console.buttons.gear.pointer_id==-1 and commands==before,"Opening a blocking menu cancels the pending gear finger without dispatch")
	console.buttons.gear.pressed.emit();check(commands==before,"Blocked console also rejects a programmatically emitted gear press")
	console.set_actions_enabled(true);touch(console.buttons.gear,154,true)
	var held:Button=console.buttons.gear;data=fixture();data.gear_enabled=false;console.configure_state(data);touch(held,154,false)
	check(held.pointer_id==-1 and commands==before,"Changing source availability cancels a held gear command before release")
	console.configure_state(fixture());touch(console.buttons.gear,155,true);held=console.buttons.gear;console.configure_state({});held.pressed.emit()
	check(held.pointer_id==-1 and not console.buttons.has("gear") and commands==before,"Source-to-legacy transition removes stale gear controls and rejects their old callback")
	await frame();console.configure_state(fixture());touch(console.buttons.gear,156,true);console.hide();console.show()
	check(console.buttons.gear.pointer_id==-1 and commands==before,"Hiding the console cancels a gear touch without causing a state change")
	touch(console.buttons.gear,157,true);console.buttons.gear._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(console.buttons.gear.pointer_id==-1 and commands==before,"Application focus loss cancels held gear input")
func finite_indicator()->void:
	for value:float in [-1,0,0.5,1,2,NAN,INF]:
		var data:=fixture();data.gear_fraction=value;var before:=var_to_bytes(data);console.configure_state(data)
		var fraction:float=console.buttons.gear.get_node("Icon").fraction
		check(is_finite(fraction) and fraction>=0 and fraction<=1 and var_to_bytes(data)==before,"Invalid/outside visual fractions are bounded locally without rewriting the source snapshot")
func run()->void:
	root.size=Vector2i(1920,720);console=Console.new();root.add_child(console);console.position=Vector2(0,480);console.size=Vector2(1440,Console.HEIGHT);console.gear_requested.connect(func():commands+=1);await frame()
	await optional_layout_and_contacts();await touch_availability_and_lifetime();finite_indicator()
	console.queue_free();await process_frame
	print("GEAR FLIGHT CONSOLE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
