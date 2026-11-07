extends SceneTree
# Focused phone UI contract for copied jet/refueller/scoop state. Source control
# effects are separately exercised by the real Navigation consumer suite.
const View=preload("res://scripts/hyperdrive_services_view.gd")
var view:VBoxContainer
var scroll:ScrollContainer
var commands:Array=[]
var runtime:Array=[]
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func frame()->void:await process_frame;await process_frame;await process_frame
func fixture()->Dictionary:
	return {"source_mode":true,"docked":true,"service_available":true,"drive_name":"Стандартный гипердвигатель, класс 2","drive_class":3,"range_ly":12.0,"hydrogen":4,"military":0,"radioactives":0,"source_capacity_t":80,"occupied_t":40,"free_t":40,"can_remove":false,"drives":[],"fuels":[],"fuel_system":{"source_mode":true,"jet_raw_u32":123456789,"jet_capacity_raw_u32":987654321,"jet_tonnes":2.5,"jet_capacity_tonnes":10.0,"jet_percent":25.0,"jet_above_nominal":false,"propulsion_available":true,"forward_propulsion_available":false,"refueller_installed":true,"refueller_enabled":true,"can_toggle_refueller":true,"toggle_reason":"","can_manual_refuel":true,"manual_refuel_reason":"","scoop_installed":true,"heat_s32":12345,"heat_label":"Нагрев корпуса: 17 (шкала игры).","cooldown_u32":9999,"cooldown_seconds":0.25,"scoop_status":"Сбор приостановлен.","upgrade_notice":"Параметры бака сохранены.","atmospheric_shielding_installed":false},"fuel_equipment":[{"id":"refueller","name":"Автозаправщик","mass_t":2,"installed":true,"install_price":200,"remove_refund":75,"can_install":false,"install_reason":"Уже установлен.","can_remove":true,"remove_reason":""},{"id":"scoop","name":"Топливозаборник","mass_t":6,"installed":true,"install_price":500,"remove_refund":100,"can_install":false,"install_reason":"Уже установлен.","can_remove":false,"remove_reason":"Снятие сейчас недоступно."},{"id":"atmospheric_shielding","name":"Атмосферная защита","mass_t":1,"installed":false,"install_price":100,"remove_refund":50,"can_install":true,"install_reason":"","can_remove":false,"remove_reason":"Не установлена."}]}
func configure(data:Dictionary)->void:
	view.configure_state(data);scroll.scroll_vertical=0;await frame()
func reveal(button:Button)->void:scroll.ensure_control_visible(button);await frame()
func tap(button:Button,index:int)->void:
	var event:=InputEventScreenTouch.new();event.index=index;event.position=button.get_global_rect().get_center();event.pressed=true;root.push_input(event,true)
	event=InputEventScreenTouch.new();event.index=index;event.position=button.get_global_rect().get_center();event.pressed=false;root.push_input(event,true)
func display_contract()->void:
	var data:=fixture();var before:=var_to_bytes(data);await configure(data)
	check(var_to_bytes(data)==before,"Fuel UI cannot modify supplied source hardware, inventory or raw tank state")
	check(view.labels.jetfuel.text=="Реактивный бак: 25%" and view.labels.jetfuel_tonnes.text=="В баке: 2.5 / 10 т","Jet display uses supplied human quantities instead of inferring raw-Q units")
	check(view.labels.jet_hydrogen.text=="Водород в трюме: 4 т" and view.labels.hydrogen.text.contains("4 т"),"Cargo hydrogen is visibly separate from the reactive tank")
	check(view.labels.jet_thrust.text=="Прямая/подъёмная тяга недоступна — заправьте бак из груза." and not view.labels.jet_thrust.text.contains("вся тяга"),"Empty-fuel hint describes the original positive-axis restriction without claiming all thrust is disabled")
	check(view.labels.refueller.text=="Автозаправщик: включён" and view.buttons.set_refueller_enabled.text=="Выключить автозаправщик","Refueller state and explicit next target are readable")
	check(view.labels.scoop_heat.text==data.fuel_system.heat_label and view.labels.scoop_status.text==data.fuel_system.scoop_status and view.labels.scoop_cooldown.text.contains("0.25 с"),"Scoop heat/status/cooldown use model-prepared values, never raw counters or guessed units")
	check(view.labels.scoop_controls.text.contains("инерционный") and view.labels.scoop_controls.text.contains("875 м/с"),"Scoop instructions state the real inertial-mode and actual-speed prerequisites")
	check(view.labels.scoop_shielding.text.contains("не установлена") and view.labels.fuel_upgrade.text==data.fuel_system.upgrade_notice,"Shielding and preserved-upgrade notice remain visible source state")
	check(view.buttons["remove_fuel_equipment:refueller"].text.contains("Возврат 75 кр.") and view.buttons["install_fuel_equipment:atmospheric_shielding"].text.contains("100 кр."),"Fuel-equipment prices/refunds are the supplied adapter quotes")
	var over:=fixture();over.fuel_system.jet_percent=108.5;over.fuel_system.jet_above_nominal=true;await configure(over)
	check(view.labels.jetfuel.text.contains("108.5%") and view.labels.jet_above_nominal.text.contains("выше номинальной"),"Above-nominal original fuel values are displayed without clamping them to100percent")
func responsive()->void:
	await configure(fixture())
	for width in [320,440,720,1440]:
		scroll.size=Vector2(width,540);await frame()
		var previous:Array[Rect2]=[]
		for button:Button in view.action_buttons:
			var rect:=button.get_global_rect()
			check(rect.size.x>=64 and rect.size.y>=64 and rect.end.x<=scroll.global_position.x+width+1,"Jet/fuel equipment action fits a real narrow menu touch region")
			for other in previous:check(not rect.intersects(other),"Runtime and dock service actions never overlap")
			previous.append(rect)
		for label:Label in view.labels.values():check(label.get_global_rect().end.x<=scroll.global_position.x+width+1,"Fuel text wraps inside the phone column")
	scroll.size=Vector2(440,540);await frame()
func separate_routes()->void:
	var data:=fixture();data.docked=false;data.service_available=false;data.reason="Замена оборудования доступна после стыковки.";await configure(data)
	check(view.buttons.has("manual_jet_refuel") and view.buttons.has("set_refueller_enabled") and not view.buttons.has("remove_drive") and not view.buttons.has("remove_fuel_equipment:refueller"),"In-flight runtime controls remain distinct from dock-only commerce")
	data.erase("reason");await configure(data)
	check(view.labels.readonly.text=="Замена двигателя и покупка топлива доступны после стыковки." and not view.buttons.manual_jet_refuel.disabled,"Default flight hint scopes the docking requirement to purchases while manual tank refuel remains available")
	await reveal(view.buttons.manual_jet_refuel);tap(view.buttons.manual_jet_refuel,51);await frame()
	await reveal(view.buttons.set_refueller_enabled);tap(view.buttons.set_refueller_enabled,52);await frame()
	check(runtime==[["manual_jet_refuel",false],["set_refueller_enabled",false]] and commands.is_empty(),"Actual flight touches emit only runtime actions with explicit target booleans")
	data.fuel_system.refueller_enabled=false;await configure(data);await reveal(view.buttons.set_refueller_enabled);tap(view.buttons.set_refueller_enabled,53);await frame()
	check(runtime[-1]==["set_refueller_enabled",true],"A disabled refueller touch requests enable rather than toggling model state locally")
	data=fixture();await configure(data)
	await reveal(view.buttons["remove_fuel_equipment:refueller"]);tap(view.buttons["remove_fuel_equipment:refueller"],54);await frame()
	await reveal(view.buttons["install_fuel_equipment:atmospheric_shielding"]);tap(view.buttons["install_fuel_equipment:atmospheric_shielding"],55);await frame()
	check(commands==[["remove_fuel_equipment","refueller",1],["install_fuel_equipment","atmospheric_shielding",1]],"Dock fuel hardware uses exact service IDs and quantities")
func blocked_and_lifecycle()->void:
	var data:=fixture();data.fuel_system.can_manual_refuel=false;data.fuel_system.manual_refuel_reason="В трюме нет водорода.";data.fuel_system.can_toggle_refueller=false;data.fuel_system.toggle_reason="Сначала отмените переход."
	await configure(data);var old_count:=runtime.size()
	check(view.buttons.manual_jet_refuel.disabled and view.labels.manual_jet_reason.text==data.fuel_system.manual_refuel_reason,"A rejected manual-refuel quote has a visible phone reason")
	check(view.buttons.set_refueller_enabled.disabled and view.labels.refueller_reason.text==data.fuel_system.toggle_reason,"Runtime interlocks follow the controller quote")
	view.buttons.manual_jet_refuel.pressed.emit();view.buttons.set_refueller_enabled.pressed.emit();check(runtime.size()==old_count,"Disabled runtime quotes cannot dispatch through emitted button signals")
	await configure(fixture());var held:Button=view.buttons.manual_jet_refuel;await reveal(held)
	var touch:=InputEventScreenTouch.new();touch.index=61;touch.position=held.get_global_rect().get_center();touch.pressed=true;root.push_input(touch,true)
	check(held.pointer_id==61,"Manual fuel action owns its real finger")
	view.input_allowed=false;touch.pressed=false;root.push_input(touch,true);check(held.pointer_id==-1 and runtime.size()==old_count,"Background input blocking cancels held runtime commands")
	view.input_allowed=true
	touch=InputEventScreenTouch.new();touch.index=62;touch.position=held.get_global_rect().get_center();touch.pressed=true;root.push_input(touch,true)
	data=fixture();data.fuel_system.refueller_installed=false;data.fuel_system.refueller_enabled=false;data.fuel_system.can_toggle_refueller=false;view.configure_state(data);held.pressed.emit()
	check(held.pointer_id==-1 and runtime.size()==old_count and not view.buttons.has("set_refueller_enabled"),"Reconfiguration cancels stale held runtime controls and removes absent hardware toggle")
func run()->void:
	root.size=Vector2i(1440,720);scroll=ScrollContainer.new();scroll.position=Vector2(12,12);scroll.size=Vector2(440,540);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;root.add_child(scroll)
	view=View.new();view.command.connect(func(action:String,id:String,quantity:int):commands.append([action,id,quantity]));view.runtime_command.connect(func(action:String,enabled:bool):runtime.append([action,enabled]));scroll.add_child(view);await frame()
	await display_contract();await responsive();await separate_routes();await blocked_and_lifecycle()
	scroll.queue_free();await process_frame
	print("FUEL SERVICES VIEW TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
