extends SceneTree
# Real Main -> DockServicesView -> transaction flow. All persistence is in memory.
const Settings=preload("res://scripts/device_settings.gd")
const Store=preload("res://scripts/save_store.gd")
class MemorySettings extends Settings:
	func load_file()->bool:return false
class MemoryStore extends Store:
	var calls:=0
	var entries:Array=[]
	func write(payload:Dictionary)->bool:
		calls+=1;sequence+=1;entries.append(payload.duplicate(true));return true
var game:Node3D
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func payload()->String:return JSON.stringify(game._payload())
func models()->Array:return [game.ship,game.nav,game.world,game.surface]
func scroll()->ScrollContainer:return game.menu_rows.get_parent() as ScrollContainer
func settle()->void:
	for frame in range(3):await process_frame
func fixture()->void:
	game.saving_enabled=false;game._release_inputs();game._new_models();game.active=true;game._close_menu();game._apply_system()
	game.ship.position=game.ship.STATION+Vector3.BACK*80;game.ship.velocity=Vector3.ZERO
	game.ship.hull=75.25;game.ship.credits=1000;game.nav.fuel=9
	check(game.ship.dock(),"A real healthy training-station docking establishes the service fixture")
	game._show_services(false);await settle()
	check(game.menu.visible and game.menu_title.text=="СЛУЖБЫ СТАНЦИИ" and game.dock_services_view!=null,"Main opens the actual dock-service view")
func action(key:String)->Button:
	return game.dock_services_view.buttons.get(key,null)
func press(key:String)->void:
	var button:=action(key)
	check(button!=null and not button.disabled,"Current model quote permits "+key)
	if button!=null:button.pressed.emit()
	await settle()
func touch(pointer:int,point:Vector2,pressed:bool)->void:
	var event:=InputEventScreenTouch.new();event.index=pointer;event.position=point;event.pressed=pressed;Input.parse_input_event(event)
func reveal(button:Button)->void:
	scroll().ensure_control_visible(button);await settle()
func docked_console_entry()->void:
	await fixture();game._close_menu();game._refresh_hud()
	check(game.auto_button.text=="Службы","The real docked flight-console action is labelled services")
	var before:=payload();var original:=models();var calls:int=game.saves.calls
	var point:Vector2=game.auto_button.get_global_rect().get_center()
	touch(0,point,true);await process_frame;touch(0,point,false);await settle()
	check(game.menu.visible and game.menu_title.text=="СЛУЖБЫ СТАНЦИИ" and action("repair")!=null,"A routed console touch opens the actual service page while docked")
	check(payload()==before and models()==original and game.saves.calls==calls,"Opening services from the docked console changes no gameplay or capture-mode persistence")
func actual_transactions()->void:
	await fixture()
	var view:Control=game.dock_services_view;var original:=models();var generation:int=game.saves.sequence;var calls:int=game.saves.calls
	check(action("buy:food").get_script().resource_path=="res://scripts/touch_action_button.gd","Actual market actions use independent touch buttons")
	var food:Button=action("buy:food");await reveal(food)
	var point:=food.get_global_rect().get_center()
	touch(0,point,true);await process_frame;touch(0,point,false);await settle()
	check(game.ship.credits==970 and int(game.ship.goods.food)==1 and game.ship.total_cargo()==3,"A real routed food-purchase touch applies the30-credit price once")
	check(game.dock_services_view==view and models()==original,"Touch purchase refreshes the same view and retains all four model objects")
	await press("sell:food")
	check(game.ship.credits==994 and int(game.ship.goods.food)==0,"Selling the purchased food returns24 credits without creating cargo")
	await press("repair")
	check(game.ship.hull==100 and game.ship.credits==944,"Repair charges the rounded50-credit quote for75.25percent hull")
	await press("refuel")
	check(game.nav.fuel==12 and game.ship.credits==914,"Refuelling applies all3 missing units at10credits each")
	await press("deliver")
	check(game.ship.delivered and int(game.ship.goods.medicines)==0 and game.ship.credits==1714,"The actual delivery consumes2 medicines and credits800 once")
	await press("trade_ship:eagle")
	check(game.ship.ship_id=="eagle" and game.ship.credits==5714,"Exchange applies the healthy Cobra trade-in and Eagle price once")
	check(game.player._id=="eagle" and is_equal_approx(game.player._span,26.0) and game.player.geometry_stats.nominal_span_m==26.0,"Accepted exchange synchronizes the existing ship renderer with the selected profile")
	check(game.dock_services_view==view and models()==original and game.ship.docked,"All service operations retain controller models, view identity and docking state")
	check(game.saves.calls==calls and game.saves.sequence==generation,"Capture-mode accepted commands perform zero save writes")
	check(view.labels.summary.text.contains("Игл") and view.labels.summary.text.contains("5714") and view.labels.capacity.text.contains("0/12"),"Refreshed service labels show the resulting profile, balance and cargo")
func persistence_and_scroll()->void:
	await fixture()
	var view:Control=game.dock_services_view
	scroll().scroll_vertical=120;await settle()
	var offset:=scroll().scroll_vertical
	check(offset>0,"Real service page has a nonzero scroll position for the refresh regression")
	game.saving_enabled=true
	var calls:int=game.saves.calls;var generation:int=game.saves.sequence
	await press("buy:food")
	check(game.saves.calls==calls+1 and game.saves.sequence==generation+1,"One accepted command with saving enabled writes exactly one generation")
	check(game.saves.entries[-1]==game._payload(),"Accepted-command persistence records the complete resulting active game")
	check(game.dock_services_view==view and scroll().scroll_vertical==offset,"In-place quote refresh preserves service view and scroll offset after layout")
	game.ship.credits=0
	var before:=payload();calls=game.saves.calls;generation=game.saves.sequence
	game._service_command("buy","food");await settle()
	check(payload()==before and game.saves.calls==calls and game.saves.sequence==generation,"A stale quote rejected for insufficient funds writes no generation and leaves gameplay unchanged")
	check(action("buy:food").disabled,"Rejected command refreshes the visible affordability state")
	game.saving_enabled=false
func guarded_contexts()->void:
	for context in ["undocked","destroyed","insufficient"]:
		await fixture()
		if context=="undocked":game.ship.launch()
		elif context=="destroyed":game.ship.hull=0
		else:game.ship.credits=0
		var before:=payload();var original:=models();var calls:int=game.saves.calls;var generation:int=game.saves.sequence
		game.saving_enabled=true;game._service_command("buy","food");await settle();game.saving_enabled=false
		check(payload()==before and models()==original,"Blocked "+context+" service command preserves complete active gameplay and model identities")
		check(game.saves.calls==calls and game.saves.sequence==generation,"Blocked "+context+" command performs zero persistence writes")
		if context=="destroyed":check(game.dock_services_view.buttons.is_empty(),"Destroyed hull exposes no commerce or repair actions")
	await fixture()
	var site:Dictionary={}
	for candidate in game.world.settlements:
		if int(candidate.type_code)<35 and game.world.by_id.has(str(candidate.parent)):site=candidate;break
	check(not site.is_empty(),"Original source orbital-port context exists independently of the training dock")
	if site.is_empty():return
	game.world.focus_id=str(site.parent);game.world.selected_id=str(site.parent);game.world.site_id=str(site.id);game._apply_system()
	check(game.ship.original_port and game._station_here() and game.ship.docked,"Original-port rejection fixture uses a real source orbital site")
	game._show_services(false);await settle()
	check(game.dock_services_view.buttons.is_empty() and game.dock_services_view.labels.unavailable.text.contains("космопорта"),"Source ports show their limitation and expose zero training transactions")
	var before:=payload();var calls:int=game.saves.calls;var generation:int=game.saves.sequence
	game.saving_enabled=true;game._service_command("repair");game._service_command("refuel");game._service_command("buy","food");game.saving_enabled=false
	check(payload()==before and game.saves.calls==calls and game.saves.sequence==generation,"Original-port service rejections preserve data and write no generations")
	check(not game.nav.refuel(game.ship) and payload()==before,"Direct navigation refuel also rejects source ports without charging or filling")
func lifecycle_and_gating()->void:
	await fixture()
	var button:Button=action("repair");await reveal(button)
	var point:=button.get_global_rect().get_center();var before:=payload()
	var event:=InputEventScreenTouch.new();event.index=31;event.pressed=true;event.position=point;button._input(event)
	check(button.pointer_id==31,"A real service action owns its pointer before focus loss")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);game._process(0.0)
	check(button.pointer_id==-1 and not button.input_allowed,"Focus loss releases and gates dock-service actions")
	event.pressed=false;button._input(event)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);game._process(0.0)
	check(button.input_allowed and payload()==before,"Focus return restores current service input without executing the old release")
	event.index=32;event.pressed=true;button._input(event)
	game._close_menu()
	check(button.pointer_id==-1 and not button.is_visible_in_tree() and not game._blocked(),"Closing services releases held transactions and restores flight controls immediately")
	event.pressed=false;button._input(event)
	check(payload()==before,"A released hidden service pointer cannot perform a transaction")
	game._show_services(false);await settle();button=action("repair");await reveal(button)
	event.index=33;event.pressed=true;event.position=button.get_global_rect().get_center();button._input(event)
	game._show_routes()
	check(game.dock_services_view==null and button.pointer_id==-1 and not button.is_inside_tree(),"Switching menu pages detaches the previous services view and cancels its action ownership")
	event.pressed=false;button._input(event)
	check(payload()==before,"A detached service action cannot execute when its old finger is released")
	game._close_menu()
func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires --rebuild-capture");quit(1);return
	root.size=Vector2i(1440,720)
	game=load("res://scenes/main.tscn").instantiate();game.settings=MemorySettings.new();game.saves=MemoryStore.new();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	await settle()
	check(game.automated and not game.saving_enabled,"Actual Main starts this test with user progress persistence disabled")
	await docked_console_entry();await actual_transactions();await persistence_and_scroll();await guarded_contexts();await lifecycle_and_gating()
	game.saving_enabled=false;game.queue_free();await process_frame
	print("DOCK SERVICE ACTIONS TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
