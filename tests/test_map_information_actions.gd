extends SceneTree
# Real map buttons must open reading without selecting, travelling, changing a
# forecast or replacing the private map model/pan/search state.
const SystemView=preload("res://scripts/system_map_view.gd")
const GalaxyView=preload("res://scripts/galactic_map_view.gd")
const World=preload("res://scripts/planetary_system.gd")
const Navigation=preload("res://scripts/navigation.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func frame()->void:await process_frame;await process_frame
func tap(button:Button,id:int)->void:
	var point:Vector2=button.get_global_rect().get_center()
	var touch:=InputEventScreenTouch.new();touch.index=id;touch.position=point;touch.pressed=true;root.push_input(touch,true)
	touch=InputEventScreenTouch.new();touch.index=id;touch.position=point;touch.pressed=false;root.push_input(touch,true)
func controls(view:Control)->void:
	for width in [720,960,1440,2316]:
		view.size=Vector2(width,720);view._layout();await frame()
		var info:Rect2=view.buttons.information.get_rect()
		check(info.size.x>=64 and info.size.y>=64 and Rect2(Vector2.ZERO,view.size).encloses(info),"Dedicated information action is a visible phone target at width "+str(width))
		for key in view.buttons:
			if key!="information":check(not info.intersects(view.buttons[key].get_rect()),"Information never covers existing "+str(key)+" action")
	view.size=Vector2(1440,720);view._layout();await frame()
func system_action()->void:
	var nav:=Navigation.new();check(nav.configure_native(),"System information fixture uses actual native galaxy")
	var world:=World.new();world.configure(nav.current(),World.FULL_LAYOUT)
	var source:=var_to_bytes([world.snapshot(),nav.snapshot()])
	var view:=SystemView.new();check(view.configure({"star":nav.current(),"world":world.snapshot(),"elapsed_days":23.125}),"Actual private system map accepts its source world")
	root.add_child(view);view.size=Vector2(1440,720);view.set_process(false);await frame();view._layout()
	var requests:Array=[];var navigation:Array=[]
	view.information_requested.connect(func(id:String):requests.append(id))
	view.body_selected.connect(func(id:String):navigation.append(["body",id]))
	view.site_selected.connect(func(id:String):navigation.append(["site",id]))
	view.travel_requested.connect(func(body:String,site:String):navigation.append(["travel",body,site]))
	view.model.select("moon");view.model.set_time_offset(7);view.pan=Vector2(40,-20);view.yaw=0.77;view._update_contents()
	var before:=var_to_bytes([view.model.source_snapshot(),view.model.selected_id,view.model.preview_offset_days,view.pan,view.yaw,view.pixels_per_au])
	tap(view.buttons.information,31);await frame()
	check(requests==["moon"] and navigation.is_empty(),"Only the explicit system information button emits the selected body, without selection or travel")
	check(var_to_bytes([view.model.source_snapshot(),view.model.selected_id,view.model.preview_offset_days,view.pan,view.yaw,view.pixels_per_au])==before,"Reading request preserves map selection, forecast, projection and source snapshot")
	view.input_allowed=false;view._request_information();check(requests.size()==1,"Blocked system map cannot dispatch a stale reading command")
	view.input_allowed=true
	await controls(view)
	check(var_to_bytes([world.snapshot(),nav.snapshot()])==source,"System information actions do not mutate gameplay world or chronology")
	view.queue_free();await frame()
func galaxy_action()->void:
	var view:=GalaxyView.new();check(view.configure_state({"native":true,"current_id":0x02a49718,"selected_id":0x06a49718,"jump_range_ly":20.0,"fuel":12,"fuel_capacity":12,"jump_blocked_reason":""}),"Galaxy information fixture uses native selected Alpha Centauri")
	root.add_child(view);view.size=Vector2(1440,720);await frame()
	var deadline:=Time.get_ticks_msec()+20000
	while view.loading() and Time.get_ticks_msec()<deadline:await frame()
	check(not view.loading() and view.model!=null,"Independent source galaxy worker completes")
	if view.loading() or view.model==null:view.queue_free();await frame();return
	var requests:Array=[];var navigation:Array=[]
	view.information_requested.connect(func(id:int):requests.append(id))
	view.system_selected.connect(func(id:int):navigation.append(["select",id]))
	view.jump_requested.connect(func(id:int):navigation.append(["jump",id]))
	view._yaw=0.41;view._center+=Vector2(0.1,0.2);view.search_edit.text="Неизменяемая строка поиска"
	var model:RefCounted=view.model
	var before:=var_to_bytes([view._state,view.model.selected_id,view._center,view._yaw,view._pixels_per_ly,view.search_edit.text])
	tap(view.buttons.information,41);await frame()
	check(requests==[0x06a49718] and navigation.is_empty(),"Explicit galaxy information emits only selected system ID without a jump or re-selection")
	check(view.model==model and var_to_bytes([view._state,view.model.selected_id,view._center,view._yaw,view._pixels_per_ly,view.search_edit.text])==before,"Reading request retains the exact map model, sector, zoom, orientation and search")
	view.input_allowed=false;view._request_information();check(requests.size()==1,"Blocked galaxy map cannot dispatch a stale reading command")
	view.input_allowed=true
	await controls(view)
	view.queue_free();await frame()
func run()->void:
	root.size=Vector2i(1440,720)
	await system_action();await galaxy_action()
	print("MAP INFORMATION ACTION TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
