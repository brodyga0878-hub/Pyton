extends SceneTree
# Production-provider consumer tests. The source formatter has its independent
# native oracle suite; here actual World records must reach the actual phone UI
# unchanged, including F843's source counter and F842's unknown-system guard.
const View=preload("res://scripts/system_information_view.gd")
const Info=preload("res://scripts/source_system_information.gd")
const World=preload("res://scripts/planetary_system.gd")
const Definition=preload("res://scripts/source_system_definition.gd")
var view:Control
var checks:=0
var failures:=0
var evidence:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func frame()->void:await process_frame;await process_frame
func tap(button:Button,pointer:int)->void:
	var point:Vector2=button.get_global_rect().get_center()
	var event:=InputEventScreenTouch.new();event.index=pointer;event.position=point;event.pressed=true;root.push_input(event,true)
	event=InputEventScreenTouch.new();event.index=pointer;event.position=point;event.pressed=false;root.push_input(event,true)
func page(id:String)->Dictionary:
	for item:Dictionary in view.pages:
		if str(item.id)==id:return item
	return {}
func summary_calls()->Array:
	var result:Array=[]
	for call:Dictionary in page("general").get("source_calls",[]):
		if int(call.get("code",-1))==0x84a0:result.append(call)
	return result
func world_bytes(world:RefCounted)->PackedByteArray:
	return var_to_bytes([world.snapshot(),world.bodies,world.settlements,world.source_runtime_state])
func actual_system(id:int)->void:
	var star:Dictionary=Definition.new().describe(id);var world:=World.new();world.configure(star,World.FULL_LAYOUT)
	check(world.layout_mode==World.FULL_LAYOUT and not world.bodies.is_empty(),"Actual source world exists for native information UI "+str(id))
	var source_before:=world_bytes(world)
	var count:Variant=world.source_runtime_state.get("body_count_byte")
	check(count is int,"Actual source runtime exposes its original body-count byte")
	if not count is int:return
	var data:={"system_id":id,"system_name":str(star.name),"bodies":world.bodies.duplicate(true),"settlements":world.settlements.duplicate(true),"known":true,"source_counts":{"body_count_byte":int(count)},"selected_body_id":""}
	var input_before:=var_to_bytes(data)
	check(view.configure(data),"Production source provider configures actual native system pages")
	await frame()
	check(view.information_provider==Info and view.source_provenance.effective_known and view.pages.size()==3,"Actual view resolves the production provider and known DOS policy")
	var summaries:=summary_calls()
	check(view.source_provenance.get("body_count_available",false) and summaries.size()==1 and summaries[0].variables==[int(count)],"Exact source counter reaches F843 summary, including its original non-natural-body counting rules")
	if id==0x02a49718:
		check(int(count)!=world.bodies.size(),"Actual Sol counter distinguishes source F843 count from natural-body list length")
		check(view.document.text.contains("2286") and view.document.text.contains("Марс"),"Actual Russian Sol narrative reaches the rendered text control with its historical Mars date")
	else:check(view.document.text.contains("2038") and view.document.text.contains("Эдем"),"Actual Russian Alpha Centauri narrative reaches the text control with the source Eden date")
	for key in ["general","demography","trade"]:
		var source_page_before:=var_to_bytes(page(key))
		await tap(view.buttons[key],40)
		check(view.current_page_id==key and not view.document.text.is_empty() and var_to_bytes(page(key))==source_page_before,"Actual touch displays the production page without editing its provider text or provenance: "+key)
		if key=="demography":check(view.document.text.contains("0,0"),"Readable demographic layout retains the source sector coordinate without comma spacing")
	check(page("demography").source_action_id==250 and page("trade").source_action_id==249,"Information pages retain their real source-action provenance")
	var headings:={"major_imports":"Основной импорт","minor_imports":"Прочий импорт","major_exports":"Основной экспорт","minor_exports":"Прочий экспорт","illegal_goods":"Запрещённые товары"}
	for key in headings:
		if page("trade").groups[key].is_empty():check(str(page("trade").text).contains(str(headings[key])+":\nНет"),"An actual empty trade group displays the Russian no-entries label: "+str(key))
	var selected:Dictionary={}
	for body:Dictionary in world.bodies:
		if str(body.kind)!="barycenter" and int(body.get("original_index",0))>=1:selected=body;break
	check(not selected.is_empty(),"Actual native system offers a selectable body information record")
	if not selected.is_empty():
		view.object_scroll.scroll_vertical=0;await frame();view.select_object(str(selected.id));await frame()
		var body_page:=page("object:"+str(selected.id))
		var raw_body:PackedByteArray=var_to_bytes(body_page)
		check(body_page.get("ok",false) and body_page.source_action_id==0x80+int(selected.original_index)-1 and not view.document.text.is_empty(),"Actual body record opens its original F843 action in the same document view")
		check(not view.document.text.contains("\t") and not view.document.text.contains("^C") and view.document.text.contains(" °C"),"Actual native mass and temperature use readable document separators and Celsius glyph")
		view._choose_section("general");view._choose_section("object");await frame()
		check(var_to_bytes(body_page)==raw_body,"Native display typography cannot edit provider text, source calls or raw bytes")
		check(not view.document.text.contains("{FF") and not view.document.text.contains("{FD"),"Real body information expands source text controls before display")
	if id==0x02a49718:
		view.select_object("earth");await frame()
		var earth_page:=page("object:earth");var earth_before:=var_to_bytes(earth_page)
		var source_ports:String=earth_page.source_calls[1].text
		var comma:=source_ports.find(",")
		check(comma>=0,"Actual source Earth body card lists multiple original ports")
		if comma>=0:
			var first_port:=source_ports.substr(0,comma);var remaining:=source_ports.substr(comma+1)
			var next_comma:=remaining.find(",");var second_port:=remaining if next_comma<0 else remaining.substr(0,next_comma)
			check(view.document.text.contains(first_port+", "+second_port),"Actual source Earth port names have readable delimiter spacing in the document")
		check(var_to_bytes(earth_page)==earth_before and earth_page.source_calls[1].text==source_ports,"Native Earth port presentation preserves provider calls and bytes")
	var ground:Dictionary={}
	for port:Dictionary in world.settlements:
		if int(port.type_code)==35:ground=port;break
	if not ground.is_empty():
		view.select_object(str(ground.id));await frame()
		var ground_page:=page("object:"+str(ground.id))
		check(ground_page.get("ok",false) and ground_page.source_action_id==-1 and ground_page.provenance.has("adapter"),"Actual ground port uses an explicitly labelled adapter, never a fabricated source action")
		check(view.document.text.contains(str(ground.name)),"Actual ground-port name reaches its read-only card")
		check(view.document.text.contains("Наземный космопорт") and view.document.text.contains("Родитель:"),"Actual ground-port adapter expands its Russian type and parent labels")
	view.size=Vector2(720,440);view._layout();view._choose_section("general");await frame()
	check(view.text_scroll.get_v_scroll_bar().max_value>view.text_scroll.size.y,"Actual native prose, not a fixture placeholder, scrolls in the minimum phone layout")
	var point:Vector2=view.text_scroll.get_global_rect().get_center()
	var touch:=InputEventScreenTouch.new();touch.index=51;touch.position=point;touch.pressed=true;root.push_input(touch,true)
	var drag:=InputEventScreenDrag.new();drag.index=51;drag.position=point-Vector2(0,120);root.push_input(drag,true)
	touch=InputEventScreenTouch.new();touch.index=51;touch.position=drag.position;touch.pressed=false;root.push_input(touch,true);await frame()
	check(view.text_scroll.scroll_vertical>0,"An actual finger drag scrolls the production Russian source paragraph")
	check(world_bytes(world)==source_before and var_to_bytes(data)==input_before,"Actual native page navigation and provider queries preserve every World/input byte")
	evidence.append({"system_id":id,"body_count_byte":int(count),"natural_body_rows":world.bodies.size(),"port_rows":world.settlements.size(),"source_counter_forwarded":summaries.size()==1 and summaries[0].variables==[int(count)],"source_provenance":view.source_provenance.duplicate(true),"original_world_unchanged":world_bytes(world)==source_before})
	var missing:Dictionary=data.duplicate(true);missing.source_counts={}
	check(view.configure(missing) and not view.source_provenance.get("body_count_available",true) and summary_calls().is_empty(),"An unavailable real source counter omits its summary instead of counting displayed objects")
	var unknown:Dictionary=data.duplicate(true);unknown.system_id=0x0eb6973d;unknown.system_name="Неисследованная система";unknown.selected_body_id=str(selected.get("id",""))
	check(view.configure(unknown),"Actual zero-population DOS policy can configure an unknown page despite stale caller bodies")
	await frame()
	check(not view.source_provenance.effective_known and view.pages.size()==1 and view.object_buttons.is_empty() and view.selected_body_id.is_empty(),"Real F842 unknown policy suppresses stale planetary records, body cards, demographics and trade")
	check(view.document.text.contains("Неисследованная") and view.buttons.object.disabled and view.buttons.trade.disabled,"Actual original unknown warning remains readable without invented object controls")
	check(var_to_bytes(data)==input_before and world_bytes(world)==source_before,"Known-to-unknown display changes cannot mutate the actual source world")
	view.size=Vector2(1440,720);view._layout();await frame()
func run()->void:
	root.size=Vector2i(1440,720);view=View.new();root.add_child(view);view.size=Vector2(1440,720);await frame()
	await actual_system(0x02a49718);await actual_system(0x06a49718)
	print("NATIVE INFORMATION VIEW EVIDENCE: ",JSON.stringify(evidence))
	view.queue_free();await process_frame
	print("NATIVE INFORMATION VIEW TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
