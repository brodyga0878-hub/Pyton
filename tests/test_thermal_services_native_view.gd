extends SceneTree
# Actual Navigation/session thermal consumers. Explicit raw contexts isolate
# source arithmetic; Main's sampled-world integration is a separate report.
# Dock flags below are a service fixture, not a physical approach claim.
const View=preload("res://scripts/hyperdrive_services_view.gd")
const Nav=preload("res://scripts/navigation.gd")
const Flight=preload("res://scripts/flight_model.gd")
var nav:RefCounted
var ship:RefCounted
var view:VBoxContainer
var scroll:ScrollContainer
var events:Array=[]
var evidence:Array=[]
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func frame()->void:await process_frame;await process_frame;await process_frame
func state()->Dictionary:return nav.service_state(ship)
func thermal()->Dictionary:return nav.fuel_state(ship).thermal
func inventory()->Dictionary:return nav.snapshot().source_hyperdrive
func models()->PackedByteArray:return var_to_bytes([nav.snapshot(),ship.snapshot()])
func manifest()->PackedByteArray:return var_to_bytes([ship.goods,ship.mission_cargo,ship.story_cargo,ship.equipment])
func refresh()->void:view.configure_state(state());await frame()
func context()->Dictionary:
	return {"apply_f1014":true,"altitude_s32":100,"speed_s32":8192,"velocity_s32":[8192,0,0],"gear_down":false,"wind_enabled":false,"wind_armed":false,"parent_shield_s16":0,"wind_flags_u8":0,"step_ticks_u32":828}
func source(hull:float=37.625)->void:
	ship=Flight.new();ship.hull=hull;ship.credits=1000000;nav=Nav.new()
	check(nav.configure_source("cobra") and nav.sync_source_ship(ship),"Actual Cobra thermal consumer configures source manifest")
func bind()->void:check(nav.bind_thermal_ship(ship),"Actual explicit thermal binding preserves prior phone hull anchor")
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
	check(view.buttons.has(key),"Actual thermal consumer exposes existing action: "+key)
	if not view.buttons.has(key):return
	var button:Button=view.buttons[key];scroll.ensure_control_visible(button);await frame()
	var count:=events.size();var point:Vector2=button.get_global_rect().get_center()
	var event:=InputEventScreenTouch.new();event.index=87;event.position=point;event.pressed=true;root.push_input(event,true)
	event=InputEventScreenTouch.new();event.index=87;event.position=point;event.pressed=false;root.push_input(event,true);await frame()
	check(events.size()==count+1 and events[-1].accepted,"Real touch accepts one exact existing source command: "+key)
func old_partial_hull_and_unshielded()->void:
	source();var old:Dictionary=nav.snapshot();var before:=models();await refresh()
	check(not thermal().initialized and not view.labels.has("thermal_hull") and view.labels.has("scoop_heat") and models()==before,"Rendering an unbound source session retains the prior heat layout without inventing or initializing HP")
	check(not old.source_hyperdrive.has("thermal_system"),"Actual pre-extension source shape has no synthetic thermal sibling")
	bind();before=models();await refresh();var bound:=thermal()
	check(bound.initialized and bound.hull_percent==37.625 and absf(view.labels.thermal_hull.text.trim_prefix("Корпус: ").trim_suffix("%").to_float()-37.625)<=0.006,"Actual explicit binding preserves a fractional37.625percent old hull anchor in the readable card")
	check(inventory().thermal_system.full_hull_u16==400 and not bound.shield_available and view.labels.thermal_shield.text=="Энергетический щит: не установлен" and view.labels.thermal_shielding.text.contains("не установлена"),"Original Cobra hull400 is separate from default zero defensive shield and absent atmospheric protection")
	check(models()==before and not view.labels.has("scoop_heat") and view.labels.thermal_source_heat.text==nav.fuel_state(ship).heat_label,"Bound thermal render is read-only and moves existing heat text to the general card")
	var original_manifest:=manifest();var credits:int=ship.credits;var elapsed:float=nav.elapsed_days;var fuel:Dictionary=inventory().fuel_system.duplicate(true)
	var result:Dictionary=nav.thermal_step(context(),ship)
	check(result.ok and result.thermal.velocity_changed and inventory().fuel_system.heat_s32==512 and inventory().thermal_system.hull_u16==149 and ship.hull==37.125,"Actual source atmosphere returns drag, heat512 and two raw hull points against the retained partial-hull anchor")
	await refresh();var actual:=thermal();before=models()
	check(actual.thermal_severity=="danger" and actual.heat_percent<1 and view.labels.thermal_status.text==actual.thermal_status,"Actual hull damage promotes danger even below one percent heat; UI follows model severity")
	check(view.labels.thermal_atmosphere.text==actual.atmospheric_status and view.labels.thermal_drag.text==actual.drag_status and view.labels.thermal_damage.text==actual.damage_status,"Actual atmosphere, drag and authoritative hull damage all reach distinct Russian rows")
	check(view.labels.thermal_guidance.text==actual.escape_guidance and actual.escape_guidance.contains("атмосферы"),"Actual atmospheric danger exposes the model's practical speed/escape guidance")
	check(ship.credits==credits and nav.elapsed_days==elapsed and manifest()==original_manifest and inventory().fuel_system.jet_raw_u32==fuel.jet_raw_u32 and inventory().hydrogen==4,"Atmospheric damage display preserves credits, calendar, ordinary manifest and distinct jet/hyper fuel")
	check(models()==before and events.is_empty(),"Viewing real thermal damage does not repeat damage or emit any command")
	evidence.append({"phase":"actual_unshielded_partial_hull","initial_phone_hull_percent":37.625,"full_source_hull_u16":400,"after_source_hull_u16":inventory().thermal_system.hull_u16,"after_phone_hull_percent":ship.hull,"heat_s32":inventory().fuel_system.heat_s32,"source_drag_returned":result.thermal.velocity_changed,"severity":actual.thermal_severity})
func atmospheric_fitting_and_comparison()->void:
	source();bind();ship.docked=true;ship.station_available=true;ship.original_port=true;nav.set_source_port_available(true);await refresh()
	var actual:=state();var quote:Dictionary={}
	for item:Dictionary in actual.fuel_equipment:
		if item.id=="atmospheric_shielding":quote=item
	var credits:int=ship.credits;scroll.size=Vector2(320,540);await frame()
	await tap("install_fuel_equipment:atmospheric_shielding");var protected:=thermal()
	check(protected.shielding and not protected.shield_available and view.labels.thermal_shielding.text=="Атмосферная защита: установлена" and view.labels.thermal_shield.text=="Энергетический щит: не установлен","Actual narrow-phone atmospheric fitting changes its own equipment state without inventing defensive shields")
	check(state().occupied_t==actual.occupied_t+int(quote.mass_t) and ship.credits==credits-int(quote.install_price) and ship.hull==37.625,"Existing fitting touch uses model mass/price while retaining authoritative thermal HP")
	check(events[-1].action=="install_fuel_equipment" and events[-1].id=="atmospheric_shielding" and events[-1].quantity==1,"Thermal presentation preserves the existing dock equipment command contract")
	ship.docked=false;ship.station_available=false;nav.set_source_port_available(false)
	var result:Dictionary=nav.thermal_step(context(),ship);await refresh();protected=thermal()
	check(result.ok and result.thermal.velocity_changed and inventory().fuel_system.heat_s32==8 and ship.hull==37.625,"Actual fitted atmospheric protection reduces this source heat to8 and avoids the unshielded hull loss while retaining drag")
	check(view.labels.thermal_drag.text==protected.drag_status and view.labels.thermal_damage.text==protected.damage_status and protected.thermal_severity=="normal","Protected atmosphere displays returned drag and undamaged hull without a false danger warning")
	for width:int in [320,440,720]:
		scroll.size=Vector2(width,540);await frame()
		for key:String in ["thermal_heat","thermal_status","thermal_hull","thermal_shield","thermal_shielding","thermal_atmosphere","thermal_drag","thermal_damage"]:
			var rect:Rect2=view.labels[key].get_global_rect()
			check(rect.end.x<=scroll.global_position.x+width+1,"Actual thermal text fits phone width"+str(width)+": "+key)
		check(view.buttons.manual_jet_refuel.size.y>=64 and view.buttons.manual_jet_refuel.get_global_rect().end.x<=scroll.global_position.x+width+1,"Actual existing runtime fuel target remains reachable at phone width"+str(width))
	evidence.append({"phase":"actual_atmospheric_protection","source_heat_s32":inventory().fuel_system.heat_s32,"phone_hull_percent":ship.hull,"atmospheric_shielding":protected.shielding,"energy_shield_available":protected.shield_available,"drag_returned":result.thermal.velocity_changed,"actual_UI_widths":[320,440,720],"fitting_touch_width":320})
func external_heat_and_critical()->void:
	# Complete valid snapshots seed explicit boundary states, not sampled-world
	# claims. They verify model status/guidance consumers and critical read-only UI.
	var saved:Dictionary=nav.snapshot();saved.source_hyperdrive.fuel_system.heat_s32=0x8000
	saved.source_hyperdrive.thermal_system.last_atmosphere_active=false;saved.source_hyperdrive.thermal_system.last_drag_active=false
	check(nav.restore(saved),"Actual source snapshot accepts an explicit external-heat warning boundary")
	await refresh();var actual:=thermal();var before:=models()
	check(actual.thermal_severity=="warning" and absf(view.labels.thermal_heat.text.trim_prefix("Нагрев корпуса: ").trim_suffix("%").to_float()-50.0)<0.01 and view.labels.thermal_guidance.text==actual.escape_guidance and not actual.escape_guidance.contains("атмосферы"),"Heat outside an atmosphere shows the model's source-escape guidance instead of a false atmospheric instruction")
	check(models()==before,"External warning render cannot advance thermal cadence or alter damage state")
	saved=nav.snapshot();saved.source_hyperdrive.thermal_system.destroyed=true;saved.source_hyperdrive.thermal_system.hull_u16=0
	check(nav.restore(saved),"Actual complete source snapshot accepts the explicit destroyed boundary")
	await refresh();actual=thermal();before=models()
	check(actual.thermal_severity=="critical" and view.labels.thermal_hull.text=="Корпус: 0%" and view.labels.thermal_damage.text==actual.damage_status and view.labels.thermal_status.text==actual.thermal_status,"Critical source state displays authoritative zero HP/destruction without inventing new actions")
	check(models()==before,"Critical thermal UI is read-only")
	evidence.append({"phase":"explicit_warning_and_critical_boundaries","outside_atmosphere_guidance":true,"destroyed_hull_percent":actual.hull_percent,"critical_source_status":actual.thermal_status,"sampled_world_claim":false})
func run()->void:
	root.size=Vector2i(1440,720);scroll=ScrollContainer.new();scroll.position=Vector2(12,12);scroll.size=Vector2(440,540);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;root.add_child(scroll)
	view=View.new();view.command.connect(route);view.runtime_command.connect(runtime_route);scroll.add_child(view);await frame()
	await old_partial_hull_and_unshielded();await atmospheric_fitting_and_comparison();await external_heat_and_critical()
	print("THERMAL SERVICES NATIVE VIEW EVIDENCE: ",JSON.stringify(evidence))
	scroll.queue_free();await process_frame
	print("THERMAL SERVICES NATIVE VIEW TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
