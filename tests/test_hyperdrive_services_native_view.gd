extends SceneTree
# Actual v3 Navigation/session quotes consumed by the embedded equipment UI.
# Dock flags are an isolated business-service fixture, not physical docking proof;
# prices are the explicit workshop adapter, not the original economy oracle.
const View=preload("res://scripts/hyperdrive_services_view.gd")
const NavigationData=preload("res://scripts/navigation.gd")
const Flight=preload("res://scripts/flight_model.gd")
const ALPHA:=0x06a49718
var nav:RefCounted
var ship:RefCounted
var view:VBoxContainer
var scroll:ScrollContainer
var checks:=0
var failures:=0
var events:Array=[]
var evidence:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func frame()->void:await process_frame;await process_frame;await process_frame
func models()->PackedByteArray:return var_to_bytes([nav.snapshot(),ship.snapshot()])
func manifest()->PackedByteArray:return var_to_bytes([ship.goods,ship.mission_cargo,ship.story_cargo,ship.equipment,ship.ship_id])
func state()->Dictionary:return nav.service_state(ship)
func row(rows:Array,key:String,value:Variant)->Dictionary:
	for item:Dictionary in rows:
		if item.get(key)==value:return item
	return {}
func refresh()->void:view.configure_state(state());await frame()
func route(action:String,id:String,quantity:int)->void:
	var accepted:bool=nav.service(action,id,quantity,ship)
	events.append({"action":action,"id":id,"quantity":quantity,"accepted":accepted,"message":nav.message})
	view.configure_state(state())
func tap(key:String)->void:
	check(view.buttons.has(key),"Actual source quote exposes requested equipment action: "+key)
	if not view.buttons.has(key):return
	var button:Button=view.buttons[key];scroll.ensure_control_visible(button);await frame()
	var count:=events.size();var point:Vector2=button.get_global_rect().get_center()
	var touch:=InputEventScreenTouch.new();touch.index=81;touch.position=point;touch.pressed=true;root.push_input(touch,true)
	touch=InputEventScreenTouch.new();touch.index=81;touch.position=point;touch.pressed=false;root.push_input(touch,true);await frame()
	check(events.size()==count+1 and events[-1].accepted,"Actual touch routes one accepted source service command: "+key)
func setup()->void:
	ship=Flight.new();ship.goods.medicines=3;ship.mission_cargo={"fixture_delivery":2};ship.story_cargo=1;ship.equipment=["engine"];ship.credits=1000000
	nav=NavigationData.new();check(nav.configure_source("cobra"),"Actual Cobra source session initializes")
	check(nav.sync_source_ship(ship),"Actual Flight cargo/equipment bridges into the source session")
	ship.docked=true;ship.station_available=true;ship.original_port=true;nav.set_source_port_available(true)
	var before:=models();var actual:=state()
	check(models()==before and actual.source_capacity_t==80 and actual.drive_index==3,"Read-only actual service quote uses original Cobra capacity80 and default class2 raw index3")
	check(actual.flight_cargo_t==ship.total_cargo() and actual.flight_equipment_space_t==ship.equipment_space(),"Source occupancy includes every actual goods/mission/story cargo and existing equipment item")
	view.configure_state(actual);await frame()
	check(view.labels.drive.text==actual.drive_name and view.labels.ship.text.contains(ship.profile().name),"Production service state supplies the real ship name and source drive name")
	check(view.labels.capacity.text.contains(str(actual.occupied_t)+" / 80") and is_equal_approx(view.labels.range.text.trim_prefix("Дальность перехода: ").trim_suffix(" св. лет").to_float(),float(actual.range_ly)),"Actual source occupancy and fuel-limited range reach the visible controls")
	check(models()==before,"Rendering actual source quotes cannot mutate Navigation or Flight snapshots")
	evidence.append({"phase":"initial_actual_source","drive_index":actual.drive_index,"capacity_t":actual.source_capacity_t,"occupied_t":actual.occupied_t,"flight_cargo_t":actual.flight_cargo_t,"pricing_profile":actual.pricing_profile})
func fuel_and_fitting()->void:
	var before_manifest:=manifest();var actual:=state();var credits:int=ship.credits;var quote:=row(actual.fuels,"id","hydrogen")
	await tap("refuel:hydrogen")
	var after:=state()
	check(after.hydrogen==actual.hydrogen+1 and ship.credits==credits-int(quote.unit_price),"Actual hydrogen purchase debits the quoted adapter price for exactly one tonne")
	check(after.occupied_t==actual.occupied_t+1 and after.free_t==actual.free_t-1 and manifest()==before_manifest,"Fuel shares source capacity without replacing existing Flight cargo")
	actual=after;credits=ship.credits
	check(view.buttons.remove_drive.text.contains("Возврат "+str(actual.remove_price)),"The real removal quote is clearly labelled as a refund")
	await tap("remove_drive")
	after=state()
	check(after.drive_index==0 and ship.credits==credits+int(actual.remove_price) and after.range_ly==0.0,"Removing the actual source drive credits its quoted refund and removes jump range")
	var military_drive:=row(after.drives,"class",11);check(military_drive.get("can_install",false),"Actual source military class2 fits the isolated Cobra manifest")
	credits=ship.credits;await tap("install_drive:11")
	after=state()
	check(after.drive_index==11 and ship.credits==credits-int(military_drive.price) and after.fuel_kind=="military","Actual source fitting uses raw ID11 while consuming the quoted installation cost")
	check(view.labels.drive.text==military_drive.name and after.hydrogen==actual.hydrogen,"Drive replacement preserves stored hydrogen and displays the correct military class name")
	quote=row(after.fuels,"id","military");var quantity:int=quote.fill_quantity;credits=ship.credits;actual=after
	check(quantity>0 and quote.can_fill,"Actual military-fuel fill quote is available")
	await tap("fill:military")
	after=state()
	check(after.military==actual.military+quantity and ship.credits==credits-int(quote.fill_price) and after.free_t==0,"Batch refuel uses the exact quote and fills only the available source capacity")
	check(events[-1].action=="refuel" and events[-1].id=="military" and events[-1].quantity==quantity,"The real fill control preserves action, fuel kind and model-quoted batch quantity")
	var oversized:=row(after.drives,"class",9);check(not oversized.can_install and view.buttons["install_drive:9"].disabled,"A source class8 drive that cannot fit never becomes an active touch command")
	actual=after;credits=ship.credits
	await tap("unload_fuel:hydrogen")
	after=state()
	check(after.hydrogen==actual.hydrogen-1 and after.free_t==actual.free_t+1 and ship.credits==credits,"Fuel handover frees exactly one tonne without a charge or refund")
	check(events[-1].action=="unload_fuel" and events[-1].id=="hydrogen" and events[-1].quantity==1,"Fuel handover sends the exact controller command")
	check(manifest()==before_manifest,"Source drive/fuel service leaves all ordinary Flight inventory unchanged")
	evidence.append({"phase":"fitted_and_fuelled","drive_index":after.drive_index,"hydrogen":after.hydrogen,"military":after.military,"occupied_t":after.occupied_t,"free_t":after.free_t,"fuel_handover_credit_change":0})
func military_jump_and_waste()->void:
	ship.docked=false;ship.velocity=Vector3.ZERO;ship.station_available=false;nav.set_source_port_available(false)
	await refresh();var before:=models();var before_manifest:=manifest()
	check(not view.buttons.has("refuel:military") and not view.buttons.has("remove_drive") and not view.labels.readonly.text.is_empty(),"Actual in-flight source inventory is readable without exposing dock service actions")
	check(not nav.service("refuel","military",1,ship) and models()==before,"Controller also rejects in-flight service atomically")
	check(nav.select(ALPHA),"Actual source Alpha Centauri can be selected")
	var quote:Dictionary=nav.quote_for(ALPHA,ship)
	check(quote.get("ok",false) and quote.get("can_jump",false),"Actual fitted military drive has a source quote for the native destination")
	var inventory:=state();var days:float=nav.elapsed_days
	check(nav.begin_jump(ship),"Actual source military jump starts through Navigation")
	check(nav.step(nav.CHARGE_SECONDS,ship),"Actual Navigation commits the charged source military jump")
	var after:=state();var consumed:int=inventory.military-after.military
	check(consumed>0 and consumed==int(quote.required_fuel) and after.radioactives==inventory.radioactives+consumed,"Real military consumption produces exactly its source radioactive waste")
	check(after.hydrogen==inventory.hydrogen and after.occupied_t==inventory.occupied_t and manifest()==before_manifest,"Military fuel-to-waste conversion preserves total occupancy and ordinary Flight cargo")
	check(nav.current_id==ALPHA and absf(nav.elapsed_days-days-float(quote.duration_days))<1e-10,"Source destination and duration follow the actual quote")
	await refresh()
	check(view.labels.radioactives.text.contains(str(after.radioactives)+" т") and not view.buttons.has("unload_waste"),"Post-jump source waste is visible without exposing the dock-only handover action")
	ship.docked=true;ship.station_available=true;nav.set_source_port_available(true);await refresh()
	inventory=state();var credits:int=ship.credits;var quantity:int=inventory.unload_quantity
	check(quantity==inventory.radioactives and inventory.can_unload_waste,"Actual port offers a waste handover quote for the source inventory")
	await tap("unload_waste")
	after=state()
	check(after.radioactives==0 and after.free_t==inventory.free_t+quantity and ship.credits==credits-int(inventory.waste_price),"Actual waste disposal applies its quoted price and releases only the handed-over mass")
	check(events[-1].action=="unload_waste" and events[-1].quantity==quantity,"Waste handover keeps the exact quoted quantity")
	var source_before:=models();view.configure_state(state());await frame()
	check(models()==source_before,"Final real equipment render remains read-only after the transactions")
	evidence.append({"phase":"military_jump_and_waste","required_fuel":quote.required_fuel,"military_consumed":consumed,"waste_handed_over":quantity,"duration_raw_u32":quote.duration_raw_u32,"duration_days":quote.duration_days,"ordinary_inventory_unchanged":manifest()==before_manifest,"final_free_t":after.free_t})
func immediate_migration_services()->void:
	var retained_nav:=nav;var retained_ship:=ship
	nav=NavigationData.new();ship=Flight.new()
	check(nav.configure_native(),"Actual previous v2 native session initializes for migration consumer")
	ship.docked=true;ship.station_available=true;ship.original_port=true;nav.set_source_port_available(true)
	nav.elapsed_days=17.25;nav.select(ALPHA)
	var fuel:int=nav.fuel;var credits:int=ship.credits;var before_manifest:=manifest()
	var result:Dictionary=nav.migrate_source(ship)
	check(result.get("ok",false) and nav.is_source_hyperdrive(),"Actual v2 session can explicitly migrate to source v3")
	# Deliberately no StationSession/Main derive call here: the accepted model
	# conversion must retain the already validated live port context immediately.
	var actual:=state();view.configure_state(actual);await frame()
	check(actual.service_available and actual.docked and view.buttons.has("refuel:hydrogen") and not view.buttons["refuel:hydrogen"].disabled,"Already-docked migration immediately offers fuel service without another simulation/context refresh")
	check(actual.hydrogen==fuel and ship.credits==credits and nav.elapsed_days==17.25 and nav.selected_id==ALPHA and manifest()==before_manifest,"Migration preserves prior fuel units, balance, chronology, target and ordinary manifest")
	await tap("refuel:hydrogen")
	check(state().hydrogen==fuel+1 and ship.credits==credits-10,"Immediate post-migration UI dispatches the real accepted service command")
	evidence.append({"phase":"immediate_post_migration","service_available_without_extra_refresh":actual.service_available,"old_fuel_units":fuel,"hydrogen_after_service":state().hydrogen,"elapsed_days":nav.elapsed_days,"ordinary_inventory_unchanged":manifest()==before_manifest})
	nav=retained_nav;ship=retained_ship;await refresh()

func run()->void:
	root.size=Vector2i(1440,720);scroll=ScrollContainer.new();scroll.position=Vector2(12,12);scroll.size=Vector2(440,540);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;root.add_child(scroll)
	view=View.new();view.command.connect(route);scroll.add_child(view);await frame()
	await setup();await fuel_and_fitting();await military_jump_and_waste();await immediate_migration_services()
	print("HYPERDRIVE NATIVE VIEW EVIDENCE: ",JSON.stringify(evidence))
	scroll.queue_free();await process_frame
	print("HYPERDRIVE NATIVE VIEW TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
