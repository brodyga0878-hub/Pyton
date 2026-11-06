extends SceneTree
const Ship=preload("res://scripts/flight_model.gd")
const NavigationData=preload("res://scripts/navigation.gd")
const Services=preload("res://scripts/training_dock_services.gd")
const View=preload("res://scripts/dock_services_view.gd")
var checks:=0
var failures:=0
var events:Array=[]
var view:VBoxContainer
var scroll:ScrollContainer
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func fixture()->Dictionary:
	var ship:=Ship.new();ship.original_port=true;ship.docked=true;ship.station_available=true;ship.hull=75.5;ship.credits=1000;ship.goods.food=3;ship.mission_cargo={"native-contract":2}
	var nav:=NavigationData.new();check(nav.configure_native(),"Native source refuel fixture configures");nav.set_source_port_available(true);nav.fuel=4
	return {"ship":ship,"nav":nav}
func physical(ctx:Dictionary)->String:return JSON.stringify({"ship":ctx.ship.snapshot(),"nav":ctx.nav.snapshot(),"station":ctx.nav.has_station(),"port":ctx.ship.original_port,"available":ctx.ship.station_available})
func rejected(ctx:Dictionary,action:String,id:String="")->void:
	var before:=physical(ctx);var result:=Services.execute(ctx.ship,ctx.nav,action,id)
	check(not result.ok and physical(ctx)==before,"Rejected source service leaves ship and journey unchanged: "+action)

func backend_quotes_and_transactions()->void:
	var ctx:=fixture();var before:=physical(ctx);var state:Dictionary=Services.service_state(ctx.ship,ctx.nav)
	check(physical(ctx)==before,"Reading source refuel quote never advances or changes ship/navigation")
	check(state.source_refuel_only and state.original_port and state.docked and not state.has("native_services_unavailable"),"Native actual selected port derives one refuel-only context")
	check(state.goods.is_empty() and state.ships.is_empty() and not state.repair.can_repair and not state.delivery.can_deliver,"Native basic service publishes zero full-market or training offers")
	check(state.refuel.can_refuel and state.refuel.price==80 and state.fuel==4 and state.fuel_capacity==12,"Actual missing fuel and explicit adapted price form source quote")
	for action in ["repair","deliver","buy","sell","trade_ship","unknown"]:rejected(ctx,action,"medicines")
	var goods_before:Dictionary=ctx.ship.goods.duplicate();var missions_before:Dictionary=ctx.ship.mission_cargo.duplicate()
	var result:=Services.execute(ctx.ship,ctx.nav,"refuel")
	check(result.ok and result.status=="completed" and ctx.nav.fuel==12 and ctx.ship.credits==920,"Basic source refuel executes real Navigation refuel exactly once")
	check(ctx.ship.hull==75.5 and ctx.ship.goods==goods_before and ctx.ship.mission_cargo==missions_before and not ctx.ship.delivered,"Source fuel never repairs, trades, delivers or changes mission cargo")
	rejected(ctx,"refuel")
	state=Services.service_state(ctx.ship,ctx.nav);check(not state.refuel.can_refuel and state.refuel.price==0 and state.refuel.reason=="Баки полны.","Full tank source quote cannot charge again")
	ctx=fixture();ctx.ship.credits=79;state=Services.service_state(ctx.ship,ctx.nav)
	check(not state.refuel.can_refuel and state.refuel.price==80 and state.refuel.reason.contains("средств"),"Source insufficient funds preserves actual adapted price and visible reason")
	rejected(ctx,"refuel")
	ctx=fixture();before=physical(ctx);var repair:=Services.repair(ctx.ship)
	check(not repair.ok and physical(ctx)==before,"Direct training repair remains unavailable in an original port")
	for field in ["docked","station_available","surface_mode","combat_active"]:
		ctx=fixture();ctx.ship.set(field,field in ["surface_mode","combat_active"]);state=Services.service_state(ctx.ship,ctx.nav)
		check(not state.refuel.can_refuel,"Source refuel guard checks current mode "+field);rejected(ctx,"refuel")
	for hull in [0,-1,101]:
		ctx=fixture();ctx.ship.hull=hull;check(not Services.service_state(ctx.ship,ctx.nav).refuel.can_refuel,"Invalid/destroyed source hull rejects quote");rejected(ctx,"refuel")
	for credits in [-1,1000000001]:
		ctx=fixture();ctx.ship.credits=credits;check(not Services.service_state(ctx.ship,ctx.nav).refuel.can_refuel,"Invalid source account rejects quote");rejected(ctx,"refuel")
	for fuel in [-1,13]:
		ctx=fixture();ctx.nav.fuel=fuel;check(not Services.service_state(ctx.ship,ctx.nav).refuel.can_refuel,"Invalid source fuel rejects quote");rejected(ctx,"refuel")
	ctx=fixture();ctx.nav.remaining=1;check(not Services.service_state(ctx.ship,ctx.nav).refuel.can_refuel,"Pending native jump rejects source refuel");rejected(ctx,"refuel")
	ctx=fixture();ctx.ship.goods.food="bad";check(not Services.service_state(ctx.ship,ctx.nav).refuel.can_refuel,"Malformed source manifest rejects without invoking typed cargo sum");rejected(ctx,"refuel")
	ctx=fixture();ctx.ship.equipment=["unknown"];check(not Services.service_state(ctx.ship,ctx.nav).refuel.can_refuel,"Malformed source equipment rejects without catalog indexing");rejected(ctx,"refuel")
	ctx=fixture();ctx.nav.set_source_port_available(false);state=Services.service_state(ctx.ship,ctx.nav)
	check(not state.source_refuel_only and state.native_services_unavailable and state.goods.is_empty() and state.ships.is_empty(),"No selected real port exposes neither refuel nor training-market offers")
	rejected(ctx,"refuel");rejected(ctx,"buy","food")
	ctx=fixture();ctx.ship.original_port=false;state=Services.service_state(ctx.ship,ctx.nav)
	check(state.native_services_unavailable and not state.refuel.can_refuel,"Native false training dock cannot bypass selected original-port requirement")
	rejected(ctx,"repair");rejected(ctx,"buy","food")
	var legacy_ship:=Ship.new();legacy_ship.docked=true;legacy_ship.hull=75;var legacy_nav:=NavigationData.new();legacy_nav.fuel=4
	var legacy:Dictionary=Services.service_state(legacy_ship,legacy_nav)
	check(not legacy.has("source_refuel_only") and not legacy.has("source_port_name") and not legacy.has("native_services_unavailable") and legacy.goods.size()==6 and legacy.ships.size()==3 and legacy.repair.can_repair,"Legacy service quote keeps exact old schema and training offers")
	legacy_ship.original_port=true;var old_before:=JSON.stringify({"ship":legacy_ship.snapshot(),"nav":legacy_nav.snapshot()});result=Services.execute(legacy_ship,legacy_nav,"refuel")
	check(not result.ok and JSON.stringify({"ship":legacy_ship.snapshot(),"nav":legacy_nav.snapshot()})==old_before,"Legacy original-port rejection stays unchanged")

func configure(state:Dictionary)->void:
	view.configure_state(state)
	for frame in range(3):await process_frame
func touch(button:Button,pointer:int,pressed:bool)->void:
	var event:=InputEventScreenTouch.new();event.index=pointer;event.pressed=pressed;event.position=button.get_global_rect().get_center();button._input(event)

func source_view_and_touch()->void:
	var ctx:=fixture();var state:Dictionary=Services.service_state(ctx.ship,ctx.nav);state.source_port_name="Ли Цин Дао"
	# Presentation must not reveal even supplied training offers in this mode.
	state.goods=[{"id":"food","can_buy":true}];state.ships=[{"id":"eagle","can_trade":true}];state.repair.can_repair=true;state.delivery.can_deliver=true
	var before:=JSON.stringify(state);var models:=physical(ctx)
	await configure(state)
	check(JSON.stringify(state)==before and physical(ctx)==models,"Native source panel is read-only and isolates caller quote containers")
	check(view.buttons.size()==1 and view.buttons.has("refuel") and view.action_buttons.size()==1,"Source panel shows exactly one refuel control and zero market/repair/delivery actions")
	check(view.labels.port_name.text.contains("Ли Цин Дао") and view.labels.role.text.contains("ЗАПРАВКА") and not view.labels.role.text.contains("ТРЕНИРОВОЧНЫЙ"),"Actual controller-provided port name is displayed without training role")
	var button:Button=view.buttons.refuel
	check(not button.disabled and button.text.contains("80") and button.get_global_rect().size.y>=64,"Source fuel uses actual model quote and a phone-sized touch target")
	touch(button,71,true);check(button.pointer_id==71,"Native refuel touch captures exactly one pointer");touch(button,71,false)
	check(events.size()==1 and events[-1]==["refuel",""] and physical(ctx)==models,"Source touch emits controller command and never executes commerce in view")
	state=Services.service_state(ctx.ship,ctx.nav);state.source_port_name="Ли Цин Дао";state.refuel.can_refuel=false;state.refuel.reason="Недостаточно средств на заправку."
	await configure(state);button=view.buttons.refuel;touch(button,72,true);touch(button,72,false)
	check(button.disabled and view.labels.refuel_status.text==state.refuel.reason and events.size()==1,"Disabled source fuel quote exposes a visible reason and cannot emit")
	state=Services.service_state(ctx.ship,ctx.nav);state.source_port_name="Ли Цин Дао";await configure(state);button=view.buttons.refuel;touch(button,73,true)
	ctx.nav.set_source_port_available(false);state=Services.service_state(ctx.ship,ctx.nav);view.configure_state(state)
	check(button.pointer_id==-1 and view.buttons.is_empty() and events.size()==1,"Losing source port during held touch cancels pointer without stale refuel")
	check(view.labels.unavailable.text.contains("космопорт"),"Unselected native port displays actionable availability information")
	ctx=fixture();ctx.ship.docked=false;state=Services.service_state(ctx.ship,ctx.nav);state.source_port_name="Ли Цин Дао";await configure(state)
	check(view.buttons.is_empty() and view.labels.port_name.text.contains("Ли Цин Дао") and view.labels.unavailable.text.contains("стыковку"),"Actual undocked source port keeps its name without exposing transactions")
	ctx.ship.docked=true;ctx.ship.hull=0;await configure(Services.service_state(ctx.ship,ctx.nav))
	check(view.buttons.is_empty() and view.labels.unavailable.text.contains("потерян"),"Destroyed source ship exposes no refuel action")

func run()->void:
	backend_quotes_and_transactions()
	root.size=Vector2i(1440,720);scroll=ScrollContainer.new();scroll.position=Vector2(20,20);scroll.size=Vector2(940,600);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;root.add_child(scroll)
	view=View.new();scroll.add_child(view);view.command.connect(func(action:String,id:String):events.append([action,id]))
	await process_frame;await source_view_and_touch()
	scroll.queue_free();await process_frame
	print("SOURCE PORT REFUEL TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
