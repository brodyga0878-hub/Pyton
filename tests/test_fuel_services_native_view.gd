extends SceneTree
# Actual Navigation/session state drives these phone controls. Dock flags are an
# isolated service fixture; this does not certify physical docking or a device.
# Installation/refund quotes are the explicit workshop adapter, not the market.
const View=preload("res://scripts/hyperdrive_services_view.gd")
const Nav=preload("res://scripts/navigation.gd")
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
func state()->Dictionary:return nav.service_state(ship)
func models()->PackedByteArray:return var_to_bytes([nav.snapshot(),ship.snapshot()])
func manifest()->PackedByteArray:return var_to_bytes([ship.goods,ship.mission_cargo,ship.story_cargo,ship.equipment,ship.ship_id])
func equipment(actual:Dictionary,id:String)->Dictionary:
	for item:Dictionary in actual.fuel_equipment:
		if item.id==id:return item
	return {}
func dock()->void:
	ship.docked=true;ship.station_available=true;ship.original_port=true;nav.set_source_port_available(true)
func fly()->void:
	ship.docked=false;ship.station_available=false;ship.velocity=Vector3.ZERO;nav.set_source_port_available(false)
func refresh()->void:view.configure_state(state());await frame()
func route(action:String,id:String,quantity:int)->void:
	var accepted:bool=nav.service(action,id,quantity,ship)
	events.append({"route":"dock","action":action,"id":id,"quantity":quantity,"accepted":accepted})
	view.configure_state(state())
func runtime_route(action:String,enabled:bool)->void:
	var accepted:=false
	if action=="manual_jet_refuel":accepted=nav.manual_jet_refuel(ship)
	elif action=="set_refueller_enabled":accepted=nav.set_refueller_enabled(enabled,ship)
	events.append({"route":"runtime","action":action,"enabled":enabled,"accepted":accepted})
	view.configure_state(state())
func tap(key:String)->void:
	check(view.buttons.has(key),"Actual source UI has action "+key)
	if not view.buttons.has(key):return
	var button:Button=view.buttons[key];scroll.ensure_control_visible(button);await frame()
	var count:=events.size();var point:Vector2=button.get_global_rect().get_center()
	var touch:=InputEventScreenTouch.new();touch.index=91;touch.position=point;touch.pressed=true;root.push_input(touch,true)
	touch=InputEventScreenTouch.new();touch.index=91;touch.position=point;touch.pressed=false;root.push_input(touch,true);await frame()
	check(events.size()==count+1 and events[-1].accepted,"Real phone touch emits one accepted source command: "+key)
func patch_fuel(fields:Dictionary)->void:
	var saved:Dictionary=nav.snapshot();saved.source_hyperdrive.fuel_system.merge(fields,true)
	check(nav.restore(saved),"A complete source snapshot accepts the isolated fuel/thermal fixture")
	nav.apply_fuel_availability(ship)
func setup()->void:
	ship=Flight.new();ship.credits=1000000;nav=Nav.new()
	check(nav.configure_source("cobra") and nav.sync_source_ship(ship),"Actual Cobra source session configures from the real Flight manifest")
	dock();var actual:=state();var before:=models();await refresh()
	check(actual.fuel_system.jet_tonnes==2 and actual.hydrogen==4 and view.labels.jetfuel_tonnes.text=="В баке: 2 / 2 т" and view.labels.jet_hydrogen.text=="Водород в трюме: 4 т","Actual2t reactive tank and4t cargo hydrogen reach separate readable controls")
	check(view.buttons.manual_jet_refuel.disabled and not view.buttons.has("set_refueller_enabled"),"Full actual tank cannot consume cargo and absent refueller has no toggle")
	check(models()==before,"Rendering actual copied source fuel state is read-only")
func depletion_and_manual_refuel()->void:
	fly();patch_fuel({"jet_raw_u32":100,"disabled_axes_mask_u8":0,"status_u16":0})
	var outcome:Dictionary=nav.fuel_step({"step_s32":1,"commands_s16":[512,0,0],"scoop_step_u32":0},ship)
	check(outcome.ok and outcome.consumption.amount_u32==100,"Native source consumption reaches the real equality depletion boundary")
	var actual:=state();var original_manifest:=manifest();var credits:int=ship.credits;var elapsed:float=nav.elapsed_days
	check(actual.fuel_system.jet_raw_u32==0 and actual.fuel_system.propulsion_available and not actual.fuel_system.forward_propulsion_available,"Empty source tank retains reverse thrust while disabling forward thrust")
	await refresh();var before:=models()
	check(view.labels.jetfuel.text=="Реактивный бак: 0%" and view.labels.jet_thrust.text=="Прямая/подъёмная тяга недоступна — заправьте бак из груза.","Actual empty-tank presentation warns only about the blocked positive thrust axes")
	check(view.buttons.size()==1 and view.buttons.has("manual_jet_refuel") and not view.buttons.manual_jet_refuel.disabled,"In flight, only the quoted runtime fuel action is exposed without dock commerce")
	check(models()==before,"Empty source UI render leaves all six source limits and inventory untouched")
	await tap("manual_jet_refuel");var after:=state()
	check(after.hydrogen==actual.hydrogen-1 and after.occupied_t==actual.occupied_t-1 and after.fuel_system.jet_tonnes==1 and after.fuel_system.jet_percent==50,"Actual manual refuel transfers one cargo tonne into the separate half-full tank")
	check(events[-1].route=="runtime" and events[-1].action=="manual_jet_refuel" and events[-1].enabled==false,"Touch sends the agreed manual runtime action rather than a station purchase")
	check(after.fuel_system.forward_propulsion_available and after.fuel_system.thrust_disabled_axes_mask_u8==0 and ship.forward_propulsion_available() and not view.labels.has("jet_thrust"),"Accepted manual F289 restores forward controls immediately and removes the stale warning")
	var all_limits:=true
	for limit:int in after.fuel_system.thrust_limits_u16:all_limits=all_limits and limit!=0
	check(all_limits and ship.credits==credits and nav.elapsed_days==elapsed and manifest()==original_manifest,"Manual fuel restores every cached limit without charging, advancing chronology or changing ordinary cargo")
	evidence.append({"phase":"actual_depletion_manual","any_thrust_while_empty":actual.fuel_system.propulsion_available,"forward_while_empty":actual.fuel_system.forward_propulsion_available,"hydrogen_after":after.hydrogen,"tank_tonnes_after":after.fuel_system.jet_tonnes,"all_six_limits_restored":all_limits})
func hardware_and_runtime()->void:
	dock();await refresh();var initial:=state();var original_manifest:=manifest()
	for id:String in ["refueller","scoop","atmospheric_shielding"]:
		var actual:=state();var quote:=equipment(actual,id);var credits:int=ship.credits
		check(quote.can_install and view.buttons["install_fuel_equipment:"+id].text.contains(str(quote.install_price)+" кр."),"Real fuel hardware installation uses its supplied price quote: "+id)
		await tap("install_fuel_equipment:"+id);var after:=state()
		check(equipment(after,id).installed and after.occupied_t==actual.occupied_t+int(quote.mass_t) and ship.credits==credits-int(quote.install_price),"Actual hardware fitting uses source mass and the quoted adapter debit: "+id)
		check(events[-1].route=="dock" and events[-1].action=="install_fuel_equipment" and events[-1].id==id and events[-1].quantity==1,"Real fitting touch preserves command, equipment ID and quantity: "+id)
	var fitted:=state()
	check(fitted.occupied_t==initial.occupied_t+8 and manifest()==original_manifest,"All three source hardware masses count once while ordinary Flight cargo remains intact")
	fly();await refresh();var before:=models()
	check(view.labels.refueller.text=="Автозаправщик: включён" and view.labels.scoop_controls.text.contains("875 м/с") and view.labels.scoop_shielding.text.contains("установлена"),"Installed actual hardware exposes readable runtime state and the confirmed scoop prerequisites")
	check(view.buttons.size()==2 and view.buttons.has("set_refueller_enabled") and view.buttons.has("manual_jet_refuel") and models()==before,"Flight has runtime controls only and viewing them cannot transact equipment")
	await tap("set_refueller_enabled")
	check(not state().fuel_system.refueller_enabled and events[-1].enabled==false and view.buttons.set_refueller_enabled.text=="Включить автозаправщик","Real touch turns the fitted feeder off and displays the next explicit target")
	await tap("set_refueller_enabled")
	check(state().fuel_system.refueller_enabled and events[-1].enabled==true,"A second real touch explicitly enables the feeder through Navigation")
	patch_fuel({"heat_s32":1000,"cooldown_u32":149130});await refresh();var thermal:Dictionary=state().fuel_system
	check(view.labels.scoop_heat.text==thermal.heat_label and view.labels.scoop_status.text==thermal.scoop_status and view.labels.scoop_cooldown.text=="До следующего сбора: 3 с","Actual model thermal text and converted cooldown are displayed without UI raw-unit calculations")
	before=models();check(nav.select(ALPHA) and nav.begin_jump(ship),"Actual source charge starts for runtime interlock validation")
	await refresh();var count:=events.size();before=models()
	check(view.buttons.manual_jet_refuel.disabled and view.buttons.set_refueller_enabled.disabled and not view.labels.manual_jet_reason.text.is_empty() and not view.labels.refueller_reason.text.is_empty(),"Actual pending charge quotes disable both runtime actions with readable reasons")
	view.buttons.manual_jet_refuel.pressed.emit();view.buttons.set_refueller_enabled.pressed.emit()
	check(events.size()==count and models()==before,"Disabled actual charge controls cannot mutate the pending quote, tank or feeder")
	nav.cancel_jump();await refresh()
	evidence.append({"phase":"actual_fuel_hardware","source_added_mass_t":8,"refuel_runtime_off_on":true,"cooldown_seconds_from_model":thermal.cooldown_seconds,"heat_text_from_model":thermal.heat_label,"pending_charge_actions_blocked":true})
func military_manual_refuel()->void:
	dock();await refresh();await tap("install_drive:11");await tap("refuel:military")
	fly();patch_fuel({"jet_raw_u32":0,"disabled_axes_mask_u8":0x15,"status_u16":1});await refresh()
	var actual:=state();var original_manifest:=manifest();var credits:int=ship.credits;var elapsed:float=nav.elapsed_days
	check(actual.fuel_kind=="military" and actual.military==1 and actual.fuel_system.can_manual_refuel,"Actual military drive quotes manual jet refuel from its matching cargo fuel")
	await tap("manual_jet_refuel");var after:=state()
	check(after.military==actual.military-1 and after.radioactives==actual.radioactives+1 and after.hydrogen==actual.hydrogen,"Military manual refuel produces one waste tonne and preserves cargo hydrogen")
	check(after.occupied_t==actual.occupied_t and after.fuel_system.jet_tonnes==1 and after.fuel_system.forward_propulsion_available,"Military-to-waste conversion keeps capacity and restores forward thrust with a separate filled jet tank")
	check(view.labels.jet_hydrogen.text.contains(str(after.hydrogen)+" т") and view.labels.radioactives.text.contains(str(after.radioactives)+" т") and view.buttons.manual_jet_refuel.disabled,"After the last military tonne, UI retains distinct hydrogen/waste rows and follows the unavailable manual quote")
	check(ship.credits==credits and nav.elapsed_days==elapsed and manifest()==original_manifest,"Military manual runtime touch preserves credits, chronology and ordinary cargo")
	evidence.append({"phase":"actual_military_manual","military_consumed":1,"radioactives_added":1,"hydrogen_unchanged":true,"occupied_t_unchanged":after.occupied_t==actual.occupied_t})
func eagle_and_narrow_phone()->void:
	ship=Flight.new();ship.ship_id="eagle";ship.credits=1000000;nav=Nav.new()
	check(nav.configure_source("eagle") and nav.sync_source_ship(ship),"Actual Eagle source session configures")
	dock();await refresh();var actual:=state();var scoop:=equipment(actual,"scoop")
	check(actual.occupied_t==19 and actual.fuel_system.atmospheric_shielding_installed and view.labels.scoop_shielding.text.contains("установлена"),"Eagle displays baseline atmospheric shielding without counting its tonne twice")
	check(not scoop.can_install and view.buttons["install_fuel_equipment:scoop"].disabled and view.labels["fuel_equipment_reason:scoop"].text==scoop.install_reason,"A ship without source scoop mounting shows the actual disabled reason")
	var count:=events.size();var before:=models();view.buttons["install_fuel_equipment:scoop"].pressed.emit()
	check(events.size()==count and models()==before,"A blocked source scoop fitting cannot dispatch even through a forced signal")
	for width:int in [320,440,720]:
		scroll.size=Vector2(width,540);await frame()
		for key:String in ["manual_jet_refuel","remove_fuel_equipment:atmospheric_shielding","install_fuel_equipment:scoop"]:
			var rect:Rect2=view.buttons[key].get_global_rect()
			check(rect.size.y>=64 and rect.position.x>=scroll.position.x and rect.end.x<=scroll.position.x+width+1,"Actual source fuel touch area fits width"+str(width)+": "+key)
		for key:String in ["jetfuel","jetfuel_tonnes","jet_hydrogen","scoop_heat","fuel_equipment_reason:scoop"]:
			check(view.labels[key].get_global_rect().end.x<=scroll.position.x+width+1,"Actual source fuel text wraps within width"+str(width)+": "+key)
	scroll.size=Vector2(320,540);await frame();var quote:=equipment(state(),"atmospheric_shielding");var credits:int=ship.credits
	await tap("remove_fuel_equipment:atmospheric_shielding")
	check(state().occupied_t==18 and not state().fuel_system.atmospheric_shielding_installed and ship.credits==credits+int(quote.remove_refund),"Actual narrow phone touch removes Eagle shielding once and credits the quoted refund")
	await tap("install_fuel_equipment:atmospheric_shielding")
	check(state().occupied_t==19 and state().fuel_system.atmospheric_shielding_installed,"Actual narrow phone reinstall preserves the source starter-mass credit")
	evidence.append({"phase":"actual_eagle_phone","widths":[320,440,720],"scoop_mounting_rejected":not scoop.can_install,"occupied_t_with_default_shield":actual.occupied_t,"occupied_after_reinstall":state().occupied_t})
func run()->void:
	root.size=Vector2i(1440,720);scroll=ScrollContainer.new();scroll.position=Vector2(12,12);scroll.size=Vector2(440,540);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;root.add_child(scroll)
	view=View.new();view.command.connect(route);view.runtime_command.connect(runtime_route);scroll.add_child(view);await frame()
	await setup();await depletion_and_manual_refuel();await hardware_and_runtime();await military_manual_refuel();await eagle_and_narrow_phone()
	print("FUEL SERVICES NATIVE VIEW EVIDENCE: ",JSON.stringify(evidence))
	scroll.queue_free();await process_frame
	print("FUEL SERVICES NATIVE VIEW TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
