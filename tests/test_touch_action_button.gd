extends SceneTree
# Routes real viewport input, including Godot's primary-touch mouse emulation.
const Action=preload("res://scripts/touch_action_button.gd")
var checks:=0
var failures:=0
var layer:CanvasLayer
var a:Button
var b:Button
var counts:={"a":0,"b":0,"scroll":0}
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func at(control:Control,local:Vector2)->Vector2:return control.get_global_transform_with_canvas()*local
func touch(index:int,point:Vector2,pressed:=true,canceled:=false)->void:
	var event:=InputEventScreenTouch.new();event.index=index;event.position=point;event.pressed=pressed;event.canceled=canceled;root.push_input(event,true)
func drag(index:int,point:Vector2)->void:
	var event:=InputEventScreenDrag.new();event.index=index;event.position=point;root.push_input(event,true)
func mouse(point:Vector2,pressed:=true,device:=0)->void:
	var event:=InputEventMouseButton.new();event.device=device;event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.pressed=pressed;root.push_input(event,true)
func parse_touch(index:int,point:Vector2,pressed:bool)->void:
	var event:=InputEventScreenTouch.new();event.index=index;event.position=point;event.pressed=pressed;Input.parse_input_event(event)
func button(parent:Node,position_value:Vector2)->Button:
	var result:=Action.new();result.position=position_value;result.size=Vector2(160,80);result.text="Действие";parent.add_child(result);return result
func basic_ownership()->void:
	var pa:=at(a,a.size*0.5);var pb:=at(b,b.size*0.5)
	touch(4,pa);touch(5,pb)
	check(a.pointer_id==4 and b.pointer_id==5,"Two action buttons retain independent real touch owners through transformed canvas coordinates")
	touch(6,pa);touch(6,pa,false)
	check(a.pointer_id==4 and counts.a==0,"Unrelated finger cannot steal or release an occupied action")
	touch(5,pb,false);check(counts.b==1 and b.pointer_id==-1 and a.pointer_id==4,"Second action fires exactly once while the first finger remains down")
	touch(4,pa,false);check(counts.a==1 and a.pointer_id==-1,"First action fires on its own inside release")
	touch(7,pa);drag(7,Vector2(-100,-100));touch(7,Vector2(-100,-100),false)
	check(counts.a==1 and a.pointer_id==-1,"Outside release cancels the action")
	touch(8,pa);touch(8,pa,true,true)
	check(counts.a==1 and a.pointer_id==-1,"Android canceled event never fires even if pressed remains true")
	mouse(pa,true,-1);mouse(pa,false,-1)
	check(counts.a==1 and a.pointer_id==-1,"Emulated mouse events cannot duplicate a touch action")
	mouse(pa);check(a.pointer_id==-2,"Real desktop mouse can capture the action")
	touch(9,pa);touch(9,pa,false)
	check(a.pointer_id==-2 and counts.a==1,"Touch cannot steal a real mouse capture")
	mouse(pa,false);check(counts.a==2 and a.pointer_id==-1,"Real mouse activates on inside release exactly once")
func lifecycle()->void:
	var pa:=at(a,a.size*0.5)
	touch(10,pa);a.input_allowed=false
	check(a.pointer_id==-1,"Disabling action input immediately releases capture")
	touch(10,pa,false);check(counts.a==2,"A release after disable cannot replay an action")
	a.input_allowed=true;touch(11,pa);a.hide()
	check(a.pointer_id==-1,"Visibility loss immediately releases capture")
	a.show();touch(11,pa,false);check(counts.a==2,"Showing again needs a fresh press")
	touch(12,pa);a.disabled=true;await process_frame
	check(a.pointer_id==-1,"Native disabled state releases active capture")
	a.disabled=false;touch(12,pa,false);check(counts.a==2,"Re-enabling does not replay the old finger release")
	for notification in [Node.NOTIFICATION_APPLICATION_FOCUS_OUT,Node.NOTIFICATION_APPLICATION_PAUSED,Node.NOTIFICATION_PAUSED]:
		touch(13,pa);a.notification(notification)
		check(a.pointer_id==-1 and counts.a==2,"Application/focus/tree pause releases capture without activation")
		touch(13,pa,false)
func real_emulation_route()->void:
	var before_a:int=counts.a;var before_b:int=counts.b
	var pa:=at(a,a.size*0.5);var pb:=at(b,b.size*0.5)
	parse_touch(0,pa,true);await process_frame
	check(a.pointer_id==0,"Primary touch is owned as touch, not emulated mouse")
	parse_touch(1,pb,true);await process_frame;parse_touch(1,pb,false);await process_frame
	check(counts.b==before_b+1 and a.pointer_id==0,"Secondary real touch still activates while primary finger holds another action")
	parse_touch(0,pa,false);await process_frame
	check(counts.a==before_a+1,"Primary real touch plus its emulated mouse produces only one action")
func scrolling_and_clipping()->void:
	var scroll:=ScrollContainer.new();scroll.position=Vector2(650,35);scroll.size=Vector2(280,150);root.add_child(scroll)
	var rows:=VBoxContainer.new();rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(rows)
	var buttons:Array=[]
	for i in range(4):
		var action:=Action.new();action.text="Пункт%d"%i;action.custom_minimum_size=Vector2(250,85);rows.add_child(action);buttons.append(action)
	buttons[3].pressed.connect(func():counts.scroll+=1)
	await process_frame;await process_frame
	var hidden:Control=buttons[3]
	touch(20,at(hidden,hidden.size*0.5));touch(20,at(hidden,hidden.size*0.5),false)
	check(hidden.pointer_id==-1 and counts.scroll==0,"A menu item outside its ancestor clip cannot steal a touch")
	scroll.scroll_vertical=10000;await process_frame
	var visible_point:Vector2=at(hidden,hidden.size*0.5)
	touch(21,visible_point);touch(21,visible_point,false)
	check(counts.scroll==1,"Scrolled visible menu action remains clickable")
	scroll.scroll_vertical=0;await process_frame
	var start:Vector2=at(buttons[0],buttons[0].size*0.5)
	touch(22,start);drag(22,start-Vector2(0,55));touch(22,start-Vector2(0,55),false)
	check(scroll.scroll_vertical>0 and counts.scroll==1,"Dragging on a menu button scrolls rather than activating a clipped action")
	scroll.queue_free();await process_frame
func toggles()->void:
	b.toggle_mode=true;var states:Array=[];b.toggled.connect(func(value:bool):states.append(value))
	var pb:=at(b,b.size*0.5)
	touch(30,pb);touch(30,pb,false)
	check(b.button_pressed and states==[true],"Toggle mode preserves the standard toggled signal and checked state")
	touch(31,pb);touch(31,pb,true,true)
	check(b.button_pressed and states==[true],"Cancel preserves prior toggle state")
	touch(32,pb);touch(32,pb,false)
	check(not b.button_pressed and states==[true,false],"Second completed toggle clears its state once")
func run()->void:
	root.size=Vector2i(1440,720);layer=CanvasLayer.new();layer.transform=Transform2D(0.03,Vector2(20,25));root.add_child(layer)
	var parent:=Control.new();parent.position=Vector2(35,20);parent.scale=Vector2(1.2,0.9);parent.rotation=-0.06;parent.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(parent)
	a=button(parent,Vector2(0,0));b=button(parent,Vector2(220,0))
	a.pressed.connect(func():counts.a+=1);b.pressed.connect(func():counts.b+=1)
	await process_frame
	basic_ownership();await lifecycle();await real_emulation_route();await scrolling_and_clipping();toggles()
	layer.queue_free();await process_frame
	print("TOUCH ACTION BUTTON TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
