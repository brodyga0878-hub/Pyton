extends SceneTree
# The equipment view consumes explicit service quotes. These labelled fixture
# prices exercise display/command routing and never claim original market prices.
const View=preload("res://scripts/hyperdrive_services_view.gd")
var view:VBoxContainer
var scroll:ScrollContainer
var checks:=0
var failures:=0
var events:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func frame()->void:await process_frame;await process_frame;await process_frame
func fixture()->Dictionary:
	return {"schema":"source-hyperdrive-services-v1","source_mode":true,"ship_id":"cobra","profile_name":"Кобра Mk III","drive_class":2,"drive_index":2,"drive_name":"Стандартный гипердвигатель, класс 1","drive_class_label":"1","range_ly":3.12,"maximum_range_ly":7.5,"hydrogen":3,"military":2,"radioactives":1,"source_capacity_t":20,"occupied_t":17,"free_t":3,"flight_cargo_t":2,"credits":2500,"docked":true,"service_available":true,"reason":"","can_remove":true,"remove_price":0,"remove_reason":"","can_unload_waste":true,"unload_quantity":1,"waste_price":5,"waste_reason":"","drives":[{"class":2,"name":"Стандартный гипердвигатель, класс 1","space_t":1,"installed":true,"can_install":false,"reason":"Уже установлен","price":100},{"class":3,"name":"Стандартный гипердвигатель, класс 2","space_t":3,"installed":false,"can_install":true,"reason":"","price":200},{"class":10,"name":"Военный гипердвигатель, класс 1","space_t":6,"installed":false,"can_install":false,"reason":"Не хватает места для установки.","price":600}],"fuels":[{"id":"hydrogen","quantity":3,"can_refuel":true,"reason":"","unit_price":10,"can_unload":true,"unload_quantity":1,"unload_price":0,"unload_reason":"","fill_quantity":3,"fill_price":30,"can_fill":true,"fill_reason":""},{"id":"military","quantity":2,"can_refuel":false,"reason":"Этот запас нельзя увеличить.","unit_price":50,"can_unload":false,"unload_quantity":1,"unload_price":0,"unload_reason":"Передача недоступна.","fill_quantity":2,"fill_price":100,"can_fill":false,"fill_reason":"Нет места для полной заправки."}]}
func configure(state:Dictionary)->void:
	view.configure_state(state);scroll.scroll_vertical=0;await frame()
func reveal(button:Button)->void:
	scroll.ensure_control_visible(button);await frame()
func tap(button:Button,pointer:int)->void:
	var point:Vector2=button.get_global_rect().get_center()
	var event:=InputEventScreenTouch.new();event.index=pointer;event.position=point;event.pressed=true;root.push_input(event,true)
	event=InputEventScreenTouch.new();event.index=pointer;event.position=point;event.pressed=false;root.push_input(event,true)
func display_and_isolation()->void:
	var data:=fixture();var before:=var_to_bytes(data);await configure(data)
	check(var_to_bytes(data)==before,"Rendering does not edit supplied equipment, fuel or capacity quotes")
	check(view.labels.drive.text=="Стандартный гипердвигатель, класс 1" and view.labels["class"].text=="Класс: 1","Raw source index2 is displayed as the supplied user-facing class1 name")
	check(view.labels.range.text.contains("3.12") and view.labels.credits.text.contains("2500"),"Current fuel-limited range and balance are visible without replacement calculations")
	check(view.labels.capacity.text.contains("17 / 20") and view.labels.capacity.text.contains("3") and view.labels.flight_cargo.text.contains("2"),"Source occupancy and existing Flight cargo are shown independently, without recomputing a smaller sum")
	check(view.labels.hydrogen.text.contains("3 т") and view.labels.military.text.contains("2 т") and view.labels.radioactives.text.contains("1 т"),"Hydrogen, military fuel and radioactive waste remain distinct inventory rows")
	check(view.buttons.size()==10 and view.action_buttons.size()==10,"Exactly the quoted remove, fuel, fill, waste and compatible-drive actions appear")
	check(view.buttons["refuel:hydrogen"].text.contains("10 кр.") and view.buttons["fill:hydrogen"].text.contains("3 т") and view.buttons["fill:hydrogen"].text.contains("30 кр."),"Fuel quantity and both model-quoted prices reach the visible controls")
	check(view.buttons["install_drive:3"].text.contains("200 кр.") and view.buttons["unload_waste"].text.contains("5 кр."),"Installation and waste service display their supplied total prices")
	check(view.buttons.remove_drive.text.contains("Возврат 0 кр.") and view.buttons["unload_fuel:hydrogen"].text.contains("Без оплаты и возмещения"),"Refund and free fuel handover have explicit, different financial meanings")
	check(view.buttons["install_drive:10"].disabled and view.labels["drive_reason:10"].text==data.drives[2].reason,"Unavailable installation follows the quote despite an apparently sufficient balance")
	check(view.buttons["refuel:military"].disabled and view.labels["fuel_reason:military"].text==data.fuels[1].reason and view.labels["fill_reason:military"].text==data.fuels[1].fill_reason,"Fuel restrictions are readable on a phone instead of hover-only tooltips")
	data.drives[0].name="Mutated caller";data.fuels[0].unit_price=999
	check(view.labels.drive.text.contains("класс 1") and view.buttons["refuel:hydrogen"].text.contains("10 кр."),"Caller edits after configuration cannot silently replace retained service quotes")
func responsive_layout()->void:
	for width in [320,440,720,960,1440]:
		scroll.size=Vector2(width,540);scroll.scroll_vertical=0;await frame()
		var previous:Array[Rect2]=[]
		for button:Button in view.action_buttons:
			var rect:=button.get_global_rect()
			check(rect.size.x>=64 and rect.size.y>=64,"Equipment service action retains a phone-sized touch target at width "+str(width))
			check(view.get_global_rect().encloses(rect) and rect.end.x<=scroll.global_position.x+width+1,"Equipment action fits embedded menu width without horizontal overflow")
			for other in previous:check(not rect.intersects(other),"Equipment transaction targets never overlap")
			previous.append(rect)
		for label:Label in view.labels.values():check(label.get_global_rect().end.x<=scroll.global_position.x+width+1,"Equipment text wraps inside the embedded menu column: "+label.name+" at "+str(width))
	check(scroll.get_v_scroll_bar().max_value>scroll.size.y,"Actual long drive catalogue is reachable by the enclosing menu scroll")
	scroll.size=Vector2(440,540);await frame()
func commands_and_lifecycle()->void:
	await configure(fixture())
	for test in [["install_drive:3","install_drive","3",1],["unload_fuel:hydrogen","unload_fuel","hydrogen",1],["remove_drive","remove_drive","",1],["refuel:hydrogen","refuel","hydrogen",1],["fill:hydrogen","refuel","hydrogen",3],["unload_waste","unload_waste","",1]]:
		var button:Button=view.buttons[test[0]];await reveal(button);var count:=events.size();tap(button,31);await frame()
		check(events.size()==count+1 and events[-1]==[test[1],test[2],test[3]],"Actual touch emits the exact action/ID/quantity quote: "+str(test[0]))
	var disabled:Button=view.buttons["refuel:military"];await reveal(disabled);var count:=events.size();tap(disabled,32);disabled.pressed.emit();await frame()
	check(events.size()==count and disabled.pointer_id==-1,"Unavailable quotes cannot capture a finger or dispatch a transaction")
	var held:Button=view.buttons["refuel:hydrogen"];await reveal(held)
	var event:=InputEventScreenTouch.new();event.index=33;event.position=held.get_global_rect().get_center();event.pressed=true;root.push_input(event,true)
	check(held.pointer_id==33,"An enabled fuel quote owns its current finger")
	view.input_allowed=false;event.pressed=false;root.push_input(event,true);held.pressed.emit()
	check(held.pointer_id==-1 and events.size()==count,"Input blocking releases pending fuel commands without activation")
	view.input_allowed=true
	event=InputEventScreenTouch.new();event.index=34;event.position=held.get_global_rect().get_center();event.pressed=true;root.push_input(event,true)
	view._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);event.pressed=false;root.push_input(event,true)
	check(held.pointer_id==-1 and events.size()==count,"Application focus loss cancels the owned service touch")
	event=InputEventScreenTouch.new();event.index=35;event.position=held.get_global_rect().get_center();event.pressed=true;root.push_input(event,true)
	var flight:=fixture();flight.docked=false;flight.reason="Обслуживание доступно после стыковки.";view.configure_state(flight);held.pressed.emit()
	check(held.pointer_id==-1 and events.size()==count and view.buttons.is_empty(),"A refreshed flight state removes held/stale actions without executing them")
	await frame()
func readonly_and_missing_quotes()->void:
	for field in ["docked","source_mode","service_available"]:
		var state:=fixture();state[field]=false;state.reason="В этом состоянии доступен только просмотр.";await configure(state)
		check(view.buttons.is_empty() and view.labels.readonly.text==state.reason and not view.labels.hydrogen.text.is_empty(),"Read-only context retains equipment/fuel readings but offers zero transaction controls: "+field)
	var invalid:=fixture();invalid.drives=7;invalid.range_ly=NAN;invalid.free_t=INF;invalid.fuels=[];invalid.erase("can_unload_waste")
	await configure(invalid)
	check(view.labels.range.text.contains("—") and view.labels.capacity.text.contains("—"),"Unavailable numeric readings render as unknown instead of fabricated zeros")
	var empty:=fixture();empty.fuels[0].fill_quantity=0;empty.fuels[0].can_fill=true;empty.unload_quantity=0
	await configure(empty)
	check(view.buttons["fill:hydrogen"].disabled and not view.buttons["fill:hydrogen"].text.contains("0 т") and view.buttons.unload_waste.disabled,"Zero or missing batch quantities cannot be sent as service commands")
func run()->void:
	root.size=Vector2i(1440,720)
	scroll=ScrollContainer.new();scroll.position=Vector2(12,12);scroll.size=Vector2(440,540);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;root.add_child(scroll)
	view=View.new();view.command.connect(func(action:String,id:String,quantity:int):events.append([action,id,quantity]));scroll.add_child(view);await frame()
	await display_and_isolation();await responsive_layout();await commands_and_lifecycle();await readonly_and_missing_quotes()
	scroll.queue_free();await process_frame
	print("HYPERDRIVE SERVICES VIEW TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
