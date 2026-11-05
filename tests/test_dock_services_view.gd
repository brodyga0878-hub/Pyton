extends SceneTree
# The view renders controller quotes and routes touch commands, never commerce.
const View=preload("res://scripts/dock_services_view.gd")
var view:VBoxContainer
var scroll:ScrollContainer
var events:Array=[]
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func fixture()->Dictionary:
	var goods:Array=[];var ids:=["medicines","food","metals","machines","electronics","luxury"]
	var names:=["Медикаменты","Продовольствие","Металлы","Машины","Электроника","Предметы роскоши"]
	var buys:=[100,30,60,180,250,400];var sells:=[80,24,48,144,200,320]
	for i in range(ids.size()):goods.append({"id":ids[i],"name":names[i],"owned":2 if i==0 else 0,"buy_price":buys[i],"sell_price":sells[i],"can_buy":true,"can_sell":i==0})
	return {"original_port":false,"docked":true,"hull":64.5,"credits":12450,"cargo_used":2,"cargo_capacity":20,"fuel":3,"fuel_capacity":8,"profile_name":"Кобра", "repair":{"price":71,"can_repair":true},"refuel":{"price":100,"can_refuel":true},"delivery":{"reward":800,"can_deliver":true},"goods":goods,"ships":[{"id":"cobra","name":"Кобра","cargo_capacity":20,"trade_cost":0,"can_trade":false,"current":true},{"id":"eagle","name":"Орёл","cargo_capacity":8,"trade_cost":4000,"can_trade":true,"current":false},{"id":"shuttle","name":"Шаттл","cargo_capacity":10,"trade_cost":12000,"can_trade":false,"current":false}]}
func configure(state:Dictionary)->void:
	view.configure_state(state);scroll.scroll_vertical=0
	for frame in range(3):await process_frame
func touch(button:Button,pointer:int,pressed:bool)->void:
	var event:=InputEventScreenTouch.new();event.index=pointer;event.pressed=pressed;event.position=button.get_global_rect().get_center();button._input(event)
func reveal(button:Button)->void:
	scroll.ensure_control_visible(button)
	for frame in range(3):await process_frame
func render_actual_quotes()->void:
	var state:=fixture();var before:=JSON.stringify(state)
	await configure(state)
	check(JSON.stringify(state)==before,"View rendering leaves the complete model quote unchanged")
	check(view.labels.summary.text.contains("Кобра") and view.labels.summary.text.contains("12450") and view.labels.summary.text.contains("64.5%"),"Summary retains actual ship, balance and fractional hull damage")
	check(view.labels.capacity.text.contains("2/20") and view.labels.capacity.text.contains("3/8"),"Actual cargo capacity and fuel state are visible")
	check(view.labels.role.text.contains("УЧЕБНЫЙ"),"Training-role label does not present the market as full original FFE services")
	check(view.action_buttons.size()==18 and view.buttons.size()==18,"Six goods, three services and three ship offers render exactly once")
	for good in state.goods:
		check(view.buttons["buy:"+good.id].text.contains(str(good.buy_price)) and view.buttons["sell:"+good.id].text.contains(str(good.sell_price)),"Both quoted prices are shown without hidden recalculation for "+good.id)
		check(view.labels["good:"+good.id].text.contains(good.name),"Russian catalogue name is displayed for "+good.id)
	check(view.buttons.repair.text.contains("71") and view.buttons.refuel.text.contains("100") and view.buttons.deliver.text.contains("800"),"Repair, full-refuel and delivery use the supplied model quotations")
	check(view.buttons["trade_ship:eagle"].text.contains("4000") and view.buttons["trade_ship:cobra"].text=="Текущий корабль","Ship quote and current-ship identity are distinguishable")
	var rectangles:Array[Rect2]=[]
	for button in view.action_buttons:
		var rect:Rect2=button.get_global_rect();var contained:bool=view.get_global_rect().encloses(rect)
		check(rect.size.x>=64 and rect.size.y>=64 and contained,"Every service hit target stays large and inside the scroll content")
		var overlap:=false
		for previous in rectangles:overlap=overlap or previous.intersects(rect)
		check(not overlap,"Service actions do not overlap another hit target");rectangles.append(rect)
func commands_and_availability()->void:
	await configure(fixture())
	for key in ["buy:medicines","sell:medicines","repair","refuel","deliver","trade_ship:eagle"]:
		var button:Button=view.buttons[key];await reveal(button)
		var before:=events.size();touch(button,40,true);check(button.pointer_id==40,"An available service owns its touch: "+key);touch(button,40,false)
		var parts:PackedStringArray=str(key).split(":");var expected:=[parts[0],parts[1] if parts.size()>1 else ""]
		check(events.size()==before+1 and events[-1]==expected,"Touch release routes the exact action and catalogue identifier: "+key)
	var before:=events.size();var unavailable:Button=view.buttons["sell:food"];await reveal(unavailable);touch(unavailable,41,true);touch(unavailable,41,false)
	check(unavailable.disabled and unavailable.pointer_id==-1 and events.size()==before,"Unavailable quoted sale cannot capture or emit a transaction")
	var state:=fixture();state.repair.can_repair=false;state.repair.reason="Недостаточно средств для ремонта.";state.refuel.can_refuel=false;state.refuel.reason="Гипертопливо уже заправлено.";state.goods[0].can_buy=false
	await configure(state)
	check(view.buttons.repair.disabled and view.buttons.refuel.disabled and view.buttons["buy:medicines"].disabled,"Availability follows model quote flags rather than inferred balances")
	check(not view.buttons["buy:food"].disabled and view.buttons["trade_ship:shuttle"].disabled,"Unrelated enabled quotes remain independent from unavailable actions")
	check(view.labels.repair_status.text==state.repair.reason and view.labels.repair_status.is_visible_in_tree(),"Unavailable repair reason is visible text rather than a hover-only tooltip")
	check(view.labels.refuel_status.text==state.refuel.reason and view.labels.refuel_status.is_visible_in_tree(),"Unavailable refuel reason is visible on a touch device")
func original_port_and_state_guards()->void:
	var state:=fixture();state.original_port=true
	await configure(state)
	check(view.action_buttons.is_empty() and view.buttons.is_empty(),"Original ports expose zero training transaction controls even if quotes claim availability")
	check(view.labels.unavailable.text.contains("космопорта"),"Original-port limitation is visible rather than a blank panel")
	state=fixture();state.docked=false;await configure(state)
	check(view.buttons.is_empty() and view.labels.unavailable.text.contains("стыковку"),"Undocked callers receive no actionable market")
	state=fixture();state.hull=0;await configure(state)
	check(view.buttons.is_empty() and view.labels.unavailable.text.contains("потерян"),"Destroyed ships cannot be revived by a presentation-only repair action")
func reconfiguration_cancels_touch()->void:
	await configure(fixture());var old:Button=view.buttons.repair;await reveal(old)
	touch(old,42,true);check(old.pointer_id==42,"Service pointer is owned before a state refresh")
	var before:=events.size();var blocked:=fixture();blocked.original_port=true
	view.configure_state(blocked)
	check(old.pointer_id==-1 and events.size()==before and view.buttons.is_empty(),"Refreshing to an original port cancels held transactions without executing them")
func run()->void:
	root.size=Vector2i(1440,720);scroll=ScrollContainer.new();scroll.position=Vector2(20,20);scroll.size=Vector2(940,600);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;root.add_child(scroll)
	view=View.new();scroll.add_child(view);view.command.connect(func(action:String,id:String):events.append([action,id]))
	await process_frame
	await render_actual_quotes();await commands_and_availability();await original_port_and_state_guards();await reconfiguration_cancels_touch()
	scroll.queue_free();await process_frame
	print("DOCK SERVICES VIEW TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
