extends SceneTree
# Read-only presentation contract. Native arithmetic and actual Navigation
# effects are independently covered by the actual consumer suite.
const View=preload("res://scripts/hyperdrive_services_view.gd")
var view:VBoxContainer
var scroll:ScrollContainer
var events:Array=[]
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func frame()->void:await process_frame;await process_frame;await process_frame
func fixture()->Dictionary:
	return {"source_mode":true,"docked":false,"service_available":false,"drive_name":"Стандартный гипердвигатель, класс 2","drive_class":3,"range_ly":12.0,"hydrogen":4,"military":0,"radioactives":0,"source_capacity_t":80,"occupied_t":37,"free_t":43,"drives":[],"fuels":[],"fuel_equipment":[],"fuel_system":{"source_mode":true,"jet_percent":50.0,"jet_tonnes":1.0,"jet_capacity_tonnes":2.0,"forward_propulsion_available":true,"can_manual_refuel":true,"refueller_installed":true,"refueller_enabled":true,"can_toggle_refueller":true,"scoop_installed":true,"heat_s32":987,"heat_label":"Нагрев корпуса: 987 (шкала игры).","scoop_status":"Сбор приостановлен.","cooldown_seconds":0.25,"atmospheric_shielding_installed":false,"thermal":{"initialized":true,"heat_percent":63.26,"thermal_severity":"warning","thermal_status":"Нагрев повышен.","atmospheric_status":"Корабль находится в атмосфере.","drag_status":"Действует атмосферное торможение.","damage_status":"Атмосферный урон поглощён щитом.","escape_guidance":"Уменьшите скорость и выходите из плотных слоёв атмосферы.","shielding":false,"shield_available":true,"shield_percent":57.5,"hull_percent":83.126,"upgrade_notice":"Сохранение дополнено без изменения корпуса.","host_policy":"PRIVATE_IMPLEMENTATION_POLICY","phase_f64_hex":"PRIVATE_RAW_HEX"}}}
func configure(data:Dictionary)->void:view.configure_state(data);scroll.scroll_vertical=0;await frame()
func tap(button:Button,index:int)->void:
	scroll.ensure_control_visible(button);await frame()
	var event:=InputEventScreenTouch.new();event.index=index;event.position=button.get_global_rect().get_center();event.pressed=true;root.push_input(event,true)
	event=InputEventScreenTouch.new();event.index=index;event.position=button.get_global_rect().get_center();event.pressed=false;root.push_input(event,true);await frame()
func presentation()->void:
	var data:=fixture();var before:=var_to_bytes(data);await configure(data)
	check(var_to_bytes(data)==before and events.is_empty(),"Thermal card rendering cannot mutate source state or emit runtime/service commands")
	check(view.labels.thermal_heat.text=="Нагрев корпуса: 63.3%" and view.labels.thermal_hull.text=="Корпус: 83.13%","Thermal heat and hull use model-prepared human percentages, not raw heat or source hull units")
	check(view.labels.thermal_shield.text=="Энергетический щит: 57.5%" and view.labels.thermal_shielding.text=="Атмосферная защита: не установлена","Defensive energy shield and atmospheric equipment have distinct names and independent state")
	for pair in [["thermal_status","thermal_status"],["thermal_atmosphere","atmospheric_status"],["thermal_drag","drag_status"],["thermal_damage","damage_status"],["thermal_guidance","escape_guidance"],["thermal_upgrade","upgrade_notice"]]:
		check(view.labels[pair[0]].text==data.fuel_system.thermal[pair[1]],"Source thermal presentation text is preserved verbatim: "+pair[0])
	check(view.labels.thermal_source_heat.text==data.fuel_system.heat_label and not view.labels.has("scoop_heat"),"Legacy raw heat text moves into the general thermal card rather than being duplicated under the scoop")
	check(view.labels.thermal_heat.global_position.y<view.labels.jetfuel.global_position.y,"Thermal safety information appears before the separate reactive tank and long equipment catalogue")
	check(view.buttons.size()==2 and view.buttons.has("manual_jet_refuel") and view.buttons.has("set_refueller_enabled"),"Read-only thermal card adds no control flow or action buttons")
	for label:Label in view.labels.values():check(not label.text.contains("PRIVATE_"),"Internal source policies and raw clock fields are absent from product text")
	data.fuel_system.thermal.hull_percent=1;data.fuel_system.thermal.escape_guidance="MUTATED CALLER"
	check(view.labels.thermal_hull.text=="Корпус: 83.13%" and not view.labels.thermal_guidance.text.contains("MUTATED"),"Retained thermal presentation is isolated from caller mutations")
func severity_and_equipment()->void:
	var colors:Dictionary={}
	for severity:String in ["normal","warning","danger","critical","unknown"]:
		var data:=fixture();data.fuel_system.thermal.thermal_severity=severity;data.fuel_system.thermal.heat_percent=125.5
		await configure(data);colors[severity]=view.labels.thermal_heat.get_theme_color("font_color")
		check(view.labels.thermal_heat.text.contains("125.5%") and view.labels.thermal_status.text==data.fuel_system.thermal.thermal_status,"UI neither clamps original heat nor computes status thresholds: "+severity)
	check(colors.normal!=colors.warning and colors.warning!=colors.danger and colors.danger!=colors.critical and colors.critical!=colors.unknown,"Supplied severity produces readable distinct normal, warning, dangerous, critical and unknown color cues")
	var data:=fixture();data.fuel_system.thermal.shielding=true;data.fuel_system.thermal.shield_available=false;data.fuel_system.thermal.shield_percent=0;data.fuel_system.thermal.escape_guidance="";data.fuel_system.thermal.upgrade_notice=""
	await configure(data)
	check(view.labels.thermal_shielding.text=="Атмосферная защита: установлена" and view.labels.thermal_shield.text=="Энергетический щит: не установлен","Fitted atmospheric shielding never invents an energy-shield generator")
	check(not view.labels.has("thermal_guidance") and not view.labels.has("thermal_upgrade"),"Absent model guidance/upgrade messages do not create invented instructions or empty rows")
func responsive_and_runtime()->void:
	await configure(fixture())
	for width:int in [320,440,720,1440]:
		scroll.size=Vector2(width,540);await frame()
		for key:String in ["thermal_heat","thermal_status","thermal_hull","thermal_shield","thermal_shielding","thermal_atmosphere","thermal_drag","thermal_damage","thermal_guidance","thermal_upgrade","thermal_source_heat"]:
			var rect:Rect2=view.labels[key].get_global_rect()
			check(rect.position.x>=scroll.global_position.x and rect.end.x<=scroll.global_position.x+width+1,"Thermal safety text fits the phone column at width"+str(width)+": "+key)
		for button:Button in view.action_buttons:
			check(button.size.y>=64 and button.get_global_rect().end.x<=scroll.global_position.x+width+1,"Existing runtime touch actions retain their target size beside thermal content")
	scroll.size=Vector2(320,540);await frame()
	await tap(view.buttons.manual_jet_refuel,71);await tap(view.buttons.set_refueller_enabled,72)
	check(events==[["manual_jet_refuel",false],["set_refueller_enabled",false]],"Actual narrow-phone touches keep the established fuel runtime signal unchanged")
func legacy_and_uninitialized()->void:
	for mode:String in ["missing","uninitialized","invalid"]:
		var data:=fixture()
		if mode=="missing":data.fuel_system.erase("thermal")
		elif mode=="uninitialized":data.fuel_system.thermal.initialized=false
		else:data.fuel_system.thermal="invalid"
		var before:=var_to_bytes(data);await configure(data)
		check(not view.labels.has("thermal_heat") and not view.labels.has("thermal_hull") and view.labels.scoop_heat.text==data.fuel_system.heat_label,"Previous/no-bound-hull contexts retain their earlier layout and never display invented zero HP: "+mode)
		check(var_to_bytes(data)==before,"Viewing an uninitialized/legacy state cannot bind or upgrade the model: "+mode)
func run()->void:
	root.size=Vector2i(1440,720);scroll=ScrollContainer.new();scroll.position=Vector2(12,12);scroll.size=Vector2(440,540);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;root.add_child(scroll)
	view=View.new();view.runtime_command.connect(func(action:String,enabled:bool):events.append([action,enabled]));view.command.connect(func(action:String,id:String,quantity:int):events.append([action,id,quantity]));scroll.add_child(view);await frame()
	await presentation();await severity_and_equipment();await responsive_and_runtime();await legacy_and_uninitialized()
	scroll.queue_free();await process_frame
	print("THERMAL SERVICES VIEW TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
