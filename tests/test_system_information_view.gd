extends SceneTree
# UI contract uses a deliberately labelled text fixture, so scrolling/isolation
# does not pass merely because the current source happens to return short text.
const View=preload("res://scripts/system_information_view.gd")
class FixtureInformation extends RefCounted:
	static func system_pages(_id:int,name:String,bodies:Array=[],_ports:Array=[],known:bool=true,_language:String="ru")->Dictionary:
		var effective_known:=known and _id!=4242
		var long_text:=""
		for index in range(240):long_text+="ТЕСТОВАЯ СТРОКА %03d · [b]это обычный текст[/b]\n"%index
		if not bodies.is_empty():bodies[0].name="Provider copy changed"
		var pages:Array=[{"id":"general","title":name,"source_action_id":0,"text":long_text if effective_known else "ТЕСТ НЕИЗВЕСТНОЙ СИСТЕМЫ"}]
		if effective_known:pages.append_array([{"id":"demography","title":"Население","source_action_id":1,"text":"ТЕСТ НАСЕЛЕНИЯ"},{"id":"trade","title":"Торговля","source_action_id":2,"text":"ТЕСТ ТОРГОВЛИ"}])
		return {"ok":true,"pages":pages,"provenance":{"effective_known":effective_known},"unsupported_codes":[],"error":""}
	static func body_page(_id:int,body:Dictionary,_ports:Array=[],_language:String="ru")->Dictionary:
		var name:String=str(body.name);body.name="Mutated provider copy"
		return {"ok":true,"id":"body_"+str(body.id),"title":name,"source_action_id":128,"text":"ТЕСТ ОБЪЕКТА · "+name}
class FixtureCountInformation extends RefCounted:
	static var received_counts:Dictionary={}
	static func system_pages(id:int,name:String,bodies:Array=[],ports:Array=[],known:bool=true,language:String="ru",source_counts:Dictionary={})->Dictionary:
		received_counts=source_counts.duplicate(true)
		var result:Dictionary=FixtureInformation.system_pages(id,name,bodies,ports,known,language)
		result.pages[0].text="ИСХОДНЫЙ СЧЁТЧИК: "+str(source_counts.get("body_count_byte","не задан"))
		source_counts["body_count_byte"]=255
		return result
	static func body_page(id:int,body:Dictionary,ports:Array=[],language:String="ru")->Dictionary:
		return FixtureInformation.body_page(id,body,ports,language)
class FixtureTypographyInformation extends RefCounted:
	static func system_pages(id:int,name:String,bodies:Array=[],ports:Array=[],known:bool=true,language:String="ru")->Dictionary:
		var result:Dictionary=FixtureInformation.system_pages(id,name,bodies,ports,known,language)
		result.pages[0].text="Сектор: 0,0\nНаселение 1,000\nПодпись\tзначение"
		return result
	static func body_page(_id:int,body:Dictionary,_ports:Array=[],_language:String="ru")->Dictionary:
		var header:="Масса\t1,000 масс Земли\nТемпература поверхности 350^C\nКрупные космопорты"
		var ports:="Первый порт,Второй порт,Склад 1,000"
		return {"ok":true,"id":"body_"+str(body.id),"title":str(body.name),"source_action_id":128,"text":str(body.name)+"\n\n"+header+": "+ports+"\nИндекс: 0,0","source_calls":[{"code":0x84a1,"text":header,"raw_bytes":header.to_utf8_buffer()},{"code":0xffffffff,"text":ports,"raw_bytes":ports.to_utf8_buffer()}]}
var checks:=0
var failures:=0
var view:Control
var closes:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func frame()->void:await process_frame;await process_frame
func touch(id:int,point:Vector2,pressed:bool,canceled:=false)->void:
	var event:=InputEventScreenTouch.new();event.index=id;event.position=point;event.pressed=pressed;event.canceled=canceled;root.push_input(event,true)
func drag(id:int,point:Vector2)->void:
	var event:=InputEventScreenDrag.new();event.index=id;event.position=point;root.push_input(event,true)
func tap(button:Button,id:int)->void:
	var point:Vector2=button.get_global_rect().get_center();touch(id,point,true);touch(id,point,false)
func fixture()->Dictionary:
	var bodies:Array=[];var ports:Array=[]
	for index in range(18):bodies.append({"id":"body"+str(index),"name":"ТЕСТОВОЕ ТЕЛО "+str(index),"type_code":3})
	for index in range(6):ports.append({"id":"port"+str(index),"name":"ТЕСТОВЫЙ ПОРТ "+str(index),"parent":"body0","type_code":35})
	return {"system_id":70293272,"system_name":"Тест длинной страницы","bodies":bodies,"settlements":ports,"known":true,"selected_body_id":""}
func layout_contract()->void:
	for dimensions in [Vector2(720,440),Vector2(960,540),Vector2(1440,720),Vector2(2316,1080)]:
		view.size=dimensions;view._layout();await frame()
		var previous:Array[Rect2]=[]
		for key in view.buttons:
			var rect:Rect2=view.buttons[key].get_rect()
			check(rect.size.x>=64 and rect.size.y>=64,"Every information action retains a 64px touch area: "+key)
			check(Rect2(Vector2.ZERO,dimensions).encloses(rect),"Every information action stays on screen: "+key)
			for other in previous:check(not rect.intersects(other),"Information action hit areas do not overlap at "+str(dimensions))
			previous.append(rect)
		check(not view.object_scroll.get_rect().intersects(view.text_scroll.get_rect()),"Object selection and document keep separate scroll regions")
		check(Rect2(Vector2.ZERO,dimensions).encloses(view.text_scroll.get_rect()),"Source document scroll area remains entirely visible")
		check(view.text_scroll.size.x>=400 and view.text_scroll.size.y>=150,"Source text retains a readable phone column and scroll height")
	view.size=Vector2(1440,720);view._layout();await frame()
func pages_and_scroll()->void:
	check(view.current_page_id=="general" and not view.document.bbcode_enabled,"Source text opens without interpreting FF/markup-looking text as formatting")
	check(view.document.text.contains("[b]это обычный текст[/b]") and view.document.text.contains("239"),"The complete long text reaches the actual document control")
	check(view.text_scroll.get_v_scroll_bar().max_value>view.text_scroll.size.y*4,"Real long text creates a scrollable page, not clipped labels")
	var point:Vector2=view.text_scroll.get_global_rect().get_center();touch(10,point,true);drag(10,point-Vector2(0,180));touch(10,point-Vector2(0,180),false);await frame()
	check(view.text_scroll.scroll_vertical>=150 and closes==0,"A real finger drag scrolls source prose without closing or triggering actions")
	view.text_scroll.scroll_vertical=int(view.text_scroll.get_v_scroll_bar().max_value);await frame()
	check(view.text_scroll.scroll_vertical>1000,"The last source paragraphs can be reached through the actual scroll container")
	tap(view.buttons.demography,11);await frame();check(view.current_page_id=="demography" and view.document.text=="ТЕСТ НАСЕЛЕНИЯ" and view.text_scroll.scroll_vertical==0,"Section touch replaces the visible source page and resets scroll")
	tap(view.buttons.trade,12);await frame();check(view.current_page_id=="trade" and view.document.text=="ТЕСТ ТОРГОВЛИ","Trade section displays its supplied source page")
	tap(view.object_buttons.body0,13);await frame();check(view.current_page_id=="object:body0" and view.document.text=="ТЕСТ ОБЪЕКТА · ТЕСТОВОЕ ТЕЛО 0","Actual object touch opens its source information without a travel action")
	view.object_scroll.scroll_vertical=int(view.object_scroll.get_v_scroll_bar().max_value);await frame()
	tap(view.object_buttons.port5,14);await frame();check(view.current_page_id=="object:port5" and view.document.text.contains("ТЕСТОВЫЙ ПОРТ 5"),"A port at the end of the scroll list remains selectable")
	check(view._rows.body0.name=="ТЕСТОВОЕ ТЕЛО 0","Body-page provider receives an isolated row copy")
func lifecycle_and_states()->void:
	var point:Vector2=view.buttons.close.get_global_rect().get_center();touch(20,point,true)
	check(view.buttons.close.pointer_id==20,"Close action owns its current finger")
	view.input_allowed=false;touch(20,point,false);await frame();check(closes==0 and view.buttons.close.pointer_id==-1,"Blocking the modal releases pending actions without activation")
	view.input_allowed=true;tap(view.buttons.close,21);await frame();check(closes==1,"Only a completed explicit close touch emits close_requested")
	point=view.text_scroll.get_global_rect().get_center();touch(22,point,true);view._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(view.text_scroll.pointer_id==-1,"Focus loss releases document scroll ownership")
	touch(22,point,false)
	view.configure_loading(123,"Следующая система");await frame()
	check(view.title.text=="Следующая система" and view.status.visible and not view.text_scroll.visible and view.object_buttons.is_empty(),"Async loading removes stale pages and objects while retaining close")
	check(view.buttons.general.disabled and view.buttons.object.disabled and not view.buttons.close.disabled,"Loading offers only an explicit close action")
	view.configure_error("Система недоступна");await frame();check(view.status.text=="Система недоступна","An async failure is visible without stale source text")
	var unknown:=fixture();unknown.known=false
	check(view.configure(unknown),"Unknown-system source response can configure the modal")
	await frame();check(view.object_buttons.is_empty() and view.pages.size()==1 and view.buttons.object.disabled and view.buttons.trade.disabled and view.document.text=="ТЕСТ НЕИЗВЕСТНОЙ СИСТЕМЫ","Unknown system exposes only supplied unknown-page text and never fabricated bodies")
	var source_unknown:=fixture();source_unknown.system_id=4242;source_unknown.selected_body_id="body0"
	check(view.configure(source_unknown),"Original source unknown-policy can override a caller known hint")
	await frame();check(view.object_buttons.is_empty() and view.selected_body_id.is_empty() and view.current_page_id=="general" and view.pages.size()==1,"Native unknown provenance suppresses generated bodies and selected-body details")
	var selected:=fixture();selected.selected_body_id="port0";view.input_allowed=false
	check(view.configure(selected),"Programmatic selection can configure while input is blocked")
	await frame();check(view.current_page_id=="object:port0","Selected map port remains the initial detail page independent of touch focus")
	view.input_allowed=true
func original_counter_forwarding()->void:
	view.information_provider=FixtureCountInformation
	var data:=fixture();data.source_counts={"body_count_byte":53};var before:=var_to_bytes(data)
	check(view.configure(data),"Source counter configures a provider with the optional count argument")
	await frame()
	check(FixtureCountInformation.received_counts=={"body_count_byte":53} and view.document.text=="ИСХОДНЫЙ СЧЁТЧИК: 53","Actual source header counter is forwarded, never replaced by the 24 displayed object rows")
	check(var_to_bytes(data)==before and view._snapshot.source_counts=={"body_count_byte":53},"Provider changes to its counter copy cannot mutate caller or retained source metadata")
	data=fixture();data.source_counts={}
	check(view.configure(data) and FixtureCountInformation.received_counts.is_empty(),"An unavailable source counter stays empty rather than being invented from list size")
	view.information_provider=FixtureInformation
	check(view.configure(fixture()),"Older explicit fixture provider remains compatible without a source_counts field")
	var bad:=fixture();bad.source_counts=53
	check(not view.configure(bad),"Malformed source-counter metadata is rejected before invoking a typed provider")

func readable_source_presentation()->void:
	view.information_provider=FixtureTypographyInformation
	check(view.configure(fixture()),"Typography fixture opens through the real information view")
	await frame()
	check(view.document.text=="Сектор: 0,0\nНаселение 1,000\nПодпись  значение","Document tab stops are readable without changing sector coordinates or thousands grouping")
	view.select_object("body0");await frame()
	var raw_page:Dictionary=view.pages[-1];var before:=var_to_bytes(raw_page)
	check(view.document.text.contains("Масса  1,000 масс Земли") and not view.document.text.contains("Масса1,000"),"Original body tab cannot concatenate the mass label and value")
	check(view.document.text.contains("350 °C") and not view.document.text.contains("^C"),"Original font Celsius marker becomes a readable modern degree symbol")
	check(view.document.text.contains("Крупные космопорты: Первый порт, Второй порт, Склад 1,000"),"Only actual source port-list delimiters receive readable spaces; numeric grouping inside names is retained")
	check(view.document.text.contains("Индекс: 0,0"),"Other body-card commas are untouched")
	check(raw_page.text.contains("\t") and raw_page.text.contains("350^C") and raw_page.source_calls[1].text=="Первый порт,Второй порт,Склад 1,000","Provider text and port-list records retain the original presentation bytes")
	view._choose_section("general");view._choose_section("object");await frame()
	check(var_to_bytes(raw_page)==before and raw_page.source_calls[0].raw_bytes.get_string_from_utf8().contains("\t") and raw_page.source_calls[0].raw_bytes.get_string_from_utf8().contains("^C"),"Repeated presentation never rewrites source page, call metadata or raw_bytes")

func run()->void:
	root.size=Vector2i(1440,720)
	view=View.new();view.information_provider=FixtureInformation;view.configure_loading(1,"Начало");root.add_child(view);view.size=Vector2(1440,720);view.close_requested.connect(func():closes+=1)
	await frame();check(view.status.text=="Загрузка сведений…","Loading configured before ready survives construction")
	var data:=fixture();var before:=var_to_bytes(data)
	check(view.configure(data),"Supplied source-page provider configures known system")
	await frame();check(var_to_bytes(data)==before and view.object_buttons.size()==24 and view._rows.body0.name=="ТЕСТОВОЕ ТЕЛО 0","Configuration/provider mutation cannot edit caller records or retained object rows")
	await layout_contract();await pages_and_scroll();await lifecycle_and_states();await original_counter_forwarding();await readable_source_presentation()
	view.queue_free();await process_frame
	print("SYSTEM INFORMATION VIEW TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
