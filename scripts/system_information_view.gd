extends Control
# Read-only source-information pages. Main supplies copied records and owns the
# modal/back stack; this view has no ship, navigation, clock or travel reference.
const Action=preload("res://scripts/touch_action_button.gd")
const INFORMATION_PATH:="res://scripts/source_system_information.gd"
signal close_requested
var information_provider:Script
var input_allowed:=true:
	set(value):
		input_allowed=value
		if not value:release_pointers()
		_update_actions()
var buttons:Dictionary={}
var object_buttons:Dictionary={}
var title:Label
var subtitle:Label
var page_title:Label
var status:Label
var object_count:Label
var object_scroll:ScrollContainer
var object_list:VBoxContainer
var text_scroll:ScrollContainer
var document:RichTextLabel
var pages:Array=[]
var source_provenance:Dictionary={}
var unsupported_codes:Array=[]
var current_page_id:=""
var selected_body_id:=""
var _snapshot:Dictionary={}
var _rows:Dictionary={}
var _built:=false
var _loading:=false
var _error_text:=""
var _objects_panel:Panel
var _document_panel:Panel

class TouchScroll extends ScrollContainer:
	var owner_view:Control
	var pointer_id:=-1
	var previous:=Vector2.ZERO
	func _ready()->void:
		mouse_filter=Control.MOUSE_FILTER_STOP
		vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	func release_pointer()->void:pointer_id=-1
	func _notification(what:int)->void:
		if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_EXIT_TREE]:release_pointer()
		elif what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():release_pointer()
	func _inside(point:Vector2)->bool:
		return Rect2(Vector2.ZERO,size).has_point(get_global_transform_with_canvas().affine_inverse()*point)
	func _input(event:InputEvent)->void:
		if not is_visible_in_tree() or not is_instance_valid(owner_view) or not owner_view.input_allowed:release_pointer();return
		if event is InputEventScreenTouch:
			if event.canceled:
				if event.index==pointer_id:release_pointer();get_viewport().set_input_as_handled()
			elif event.pressed and pointer_id==-1 and _inside(event.position):
				pointer_id=event.index;previous=event.position;get_viewport().set_input_as_handled()
			elif not event.pressed and event.index==pointer_id:release_pointer();get_viewport().set_input_as_handled()
		elif event is InputEventScreenDrag and event.index==pointer_id:
			var inverse:=get_global_transform_with_canvas().affine_inverse()
			scroll_vertical+=roundi((inverse*previous-inverse*event.position).y)
			previous=event.position;get_viewport().set_input_as_handled()

func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_STOP;clip_contents=true;custom_minimum_size=Vector2(720,440)
	_build();resized.connect(_layout);_layout();_publish()

func _panel()->Panel:
	var panel:=Panel.new();panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new();style.bg_color=Color("0a192b");style.border_color=Color("25475a");style.set_border_width_all(1);style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel",style);add_child(panel);return panel
func _label(font_size:int,ink:Color)->Label:
	var label:=Label.new();label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",ink)
	label.add_theme_constant_override("outline_size",0);add_child(label);return label
func _button(key:String,text:String,callback:Callable)->Button:
	var button:=Action.new();button.name="SystemInformation_"+key;button.text=text;button.clip_text=true;button.focus_mode=Control.FOCUS_NONE;button.custom_minimum_size=Vector2(64,64);button.input_allowed=input_allowed
	button.add_theme_font_size_override("font_size",18)
	for role in ["normal","hover","pressed","disabled"]:
		var style:=StyleBoxFlat.new();style.bg_color=Color("173b4b") if role=="pressed" else (Color("102b3a") if role=="hover" else Color("0d2133"));style.border_color=Color("6bc5d0") if role=="pressed" else Color("2a5365");style.set_border_width_all(1);style.set_corner_radius_all(10)
		button.add_theme_stylebox_override(role,style)
	button.add_theme_color_override("font_color",Color("dceaf3"));button.add_theme_color_override("font_disabled_color",Color("67818f"));button.pressed.connect(callback);add_child(button);buttons[key]=button;return button
func _build()->void:
	_built=true
	_objects_panel=_panel();_document_panel=_panel()
	title=_label(27,Color("e7f3f8"));title.clip_text=true
	subtitle=_label(14,Color("81acbd"));subtitle.text="СВЕДЕНИЯ О СИСТЕМЕ";subtitle.clip_text=true
	_button("close","Закрыть",func():release_pointers();close_requested.emit())
	for item in [["general","Общие"],["demography","Население"],["trade","Торговля"],["object","Объекты"]]:
		var key:String=item[0];var button:=_button(key,str(item[1]),_choose_section.bind(key));button.toggle_mode=true
	object_count=_label(14,Color("83afbe"));object_count.clip_text=true
	page_title=_label(24,Color("dff4f5"));page_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;page_title.max_lines_visible=2
	status=_label(19,Color("b5c9d6"));status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	object_scroll=TouchScroll.new();object_scroll.name="InformationObjectScroll";object_scroll.owner_view=self;add_child(object_scroll)
	object_list=VBoxContainer.new();object_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;object_list.add_theme_constant_override("separation",6);object_scroll.add_child(object_list)
	text_scroll=TouchScroll.new();text_scroll.name="InformationTextScroll";text_scroll.owner_view=self;add_child(text_scroll)
	document=RichTextLabel.new();document.name="SourceInformationText";document.bbcode_enabled=false;document.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;document.fit_content=true;document.scroll_active=false;document.selection_enabled=true
	document.mouse_filter=Control.MOUSE_FILTER_PASS;document.size_flags_horizontal=Control.SIZE_EXPAND_FILL;document.add_theme_font_size_override("normal_font_size",20);document.add_theme_color_override("default_color",Color("d2e3ee"));document.add_theme_constant_override("line_separation",5)
	text_scroll.add_child(document)

func _layout()->void:
	if not _built:return
	var width:=maxf(720,size.x);var height:=maxf(440,size.y);var side:=250.0 if width>=1100 else 210.0
	title.position=Vector2(24,14);title.size=Vector2(width-178,34);title.add_theme_font_size_override("font_size",24 if width<1000 else 27)
	subtitle.position=Vector2(24,51);subtitle.size=Vector2(width-178,22)
	buttons.close.position=Vector2(width-136,12);buttons.close.size=Vector2(112,64)
	var tab_width:float=(width-48-3*8)/4
	for index in range(4):
		var key:String=["general","demography","trade","object"][index];buttons[key].position=Vector2(24+index*(tab_width+8),88);buttons[key].size=Vector2(tab_width,64)
	_objects_panel.position=Vector2(24,168);_objects_panel.size=Vector2(side,height-192)
	object_count.position=Vector2(38,182);object_count.size=Vector2(side-28,24)
	object_scroll.position=Vector2(32,214);object_scroll.size=Vector2(side-16,maxf(1,height-246))
	var page_x:=24+side+16;var page_width:=width-page_x-24
	_document_panel.position=Vector2(page_x,168);_document_panel.size=Vector2(page_width,height-192)
	page_title.position=Vector2(page_x+20,184);page_title.size=Vector2(page_width-40,60)
	text_scroll.position=Vector2(page_x+20,252);text_scroll.size=Vector2(page_width-40,maxf(1,height-284))
	status.position=Vector2(page_x+20,252);status.size=Vector2(page_width-40,maxf(1,height-284))
	queue_redraw()

func configure_loading(system_id:int,system_name:String)->void:
	release_pointers();_snapshot={"system_id":system_id,"system_name":system_name};_rows.clear();pages.clear();current_page_id="";selected_body_id="";_loading=true;_error_text="";source_provenance.clear();unsupported_codes.clear()
	if _built:_publish()
func configure_error(message:String)->void:
	release_pointers();_loading=false;pages.clear();current_page_id="";_rows.clear();_error_text=message;source_provenance.clear();unsupported_codes.clear()
	if _built:_publish();status.text=message

func configure(snapshot:Dictionary)->bool:
	release_pointers()
	if not snapshot.get("system_id") is int or not snapshot.get("system_name") is String or not snapshot.get("bodies",[]) is Array or not snapshot.get("settlements",[]) is Array or (snapshot.has("source_counts") and not snapshot.source_counts is Dictionary):
		configure_error("Не удалось открыть сведения о системе.");return false
	_snapshot=snapshot.duplicate(true);_loading=false;_error_text="";_rows.clear();pages.clear();source_provenance.clear();unsupported_codes.clear();current_page_id="";selected_body_id=str(snapshot.get("selected_body_id",""))
	var known:bool=bool(_snapshot.get("known",true))
	if known:
		for row in _snapshot.get("bodies",[])+_snapshot.get("settlements",[]):
			if row is Dictionary and row.get("id") is String and not row.id.is_empty():_rows[str(row.id)]=row.duplicate(true)
	if information_provider==null and ResourceLoader.exists(INFORMATION_PATH):information_provider=load(INFORMATION_PATH)
	if information_provider==null:
		configure_error("Сведения о системе недоступны.");return false
	var arguments:Array=[int(_snapshot.system_id),str(_snapshot.system_name),_snapshot.get("bodies",[]).duplicate(true),_snapshot.get("settlements",[]).duplicate(true),known,"ru"]
	# The original header count is not the number of natural-body rows. Preserve
	# a supplied counter verbatim; an absent counter keeps old provider APIs.
	if _snapshot.has("source_counts"):arguments.append(_snapshot.source_counts.duplicate(true))
	var response:Dictionary=information_provider.callv("system_pages",arguments)
	if not response.get("ok",false):configure_error(str(response.get("error","Не удалось открыть сведения о системе.")));return false
	if response.get("provenance") is Dictionary:source_provenance=response.provenance.duplicate(true)
	if response.get("unsupported_codes") is Array:unsupported_codes=response.unsupported_codes.duplicate(true)
	if source_provenance.get("effective_known",known)==false:_rows.clear();selected_body_id=""
	for page in response.get("pages",[]):
		if page is Dictionary and page.get("id") is String and page.get("text") is String:pages.append(page.duplicate(true))
	current_page_id=str(pages[0].id) if not pages.is_empty() else ""
	if _built:_publish()
	if _rows.has(selected_body_id):_set_object_page(selected_body_id)
	return not pages.is_empty()

func _publish()->void:
	if not _built:return
	title.text=str(_snapshot.get("system_name","Сведения о системе"));object_count.text=("ОБЪЕКТЫ · %d"%_rows.size()) if not _rows.is_empty() else "ОБЪЕКТЫ"
	for child in object_list.get_children():object_list.remove_child(child);child.queue_free()
	object_buttons.clear()
	for id in _rows:
		var row:Dictionary=_rows[id];var button:=Action.new();button.name="InformationObject_"+str(id);button.text=str(row.get("name",id));button.clip_text=true;button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.focus_mode=Control.FOCUS_NONE;button.custom_minimum_size=Vector2(80,64);button.add_theme_font_size_override("font_size",17);button.input_allowed=input_allowed
		button.pressed.connect(select_object.bind(str(id)));object_list.add_child(button);object_buttons[str(id)]=button
	if _loading:
		page_title.text="Сведения о системе";status.text="Загрузка сведений…";status.show();text_scroll.hide()
	elif pages.is_empty():page_title.text="Сведения о системе";status.text=_error_text if not _error_text.is_empty() else "Сведения недоступны.";status.show();text_scroll.hide()
	else:_show_page(current_page_id)
	_update_actions()

func _choose_section(id:String)->void:
	if not input_allowed:return
	if id=="object":
		if _rows.has(selected_body_id):_set_object_page(selected_body_id)
		elif not _rows.is_empty():select_object(str(_rows.keys()[0]))
	else:_show_page(id)

func _show_page(id:String)->bool:
	for page:Dictionary in pages:
		if str(page.id)!=id:continue
		current_page_id=id
		if _built:
			page_title.text=str(page.get("title","Сведения"));document.text=_display_text(page);text_scroll.scroll_vertical=0;status.hide();text_scroll.show();_update_actions()
		return true
	return false


func _display_text(page:Dictionary)->String:
	# Source text/calls/raw bytes remain the audit record. Only the readable
	# document adapts the original tab stops and font-specific Celsius glyph.
	var text:=str(page.get("text",""))
	var calls:Variant=page.get("source_calls",[])
	if str(page.get("id","")).begins_with("object:") and calls is Array and calls.size()>=2 and calls[0] is Dictionary and calls[1] is Dictionary:
		# F843's mass/temperature header is followed by its synthesized port
		# list. Other commas (sector coordinates, numbers, prose) are untouched.
		if int(calls[0].get("code",-1))==0x84a1 and int(calls[1].get("code",-1))==0xffffffff:
			var ports:=str(calls[1].get("text",""));var spaced:="";var at:=0
			while at<ports.length():
				var character:=ports.substr(at,1);spaced+=character
				if character=="," and at+1<ports.length():
					var before:=ports.substr(at-1,1) if at>0 else ""
					var after:=ports.substr(at+1,1)
					var numeric:bool=before>="0" and before<="9" and after>="0" and after<="9"
					if not numeric:
						while at+1<ports.length() and ports.substr(at+1,1) in [" ","\t"]:at+=1
						spaced+=" "
				at+=1
			var header:=str(calls[0].get("text",""))+": "
			if not ports.is_empty():text=text.replace(header+ports,header+spaced)
	return text.replace("\t","  ").replace("^C"," °C")

func select_object(id:String)->void:
	if not input_allowed or not _rows.has(id) or information_provider==null:return
	release_pointers();_set_object_page(id)

func _set_object_page(id:String)->void:
	selected_body_id=id
	var page:Dictionary=information_provider.body_page(int(_snapshot.system_id),_rows[id].duplicate(true),_snapshot.get("settlements",[]).duplicate(true),"ru")
	var page_id:="object:"+id
	for index in range(pages.size()-1,-1,-1):
		if str(pages[index].id).begins_with("object:"):pages.remove_at(index)
	page.id=page_id
	if not page.get("ok",true):page.text=str(page.get("text","Сведения об этом объекте недоступны."))
	if not page.get("title") is String:page.title=str(_rows[id].get("name",id))
	if not page.get("text") is String:page.text="Сведения об этом объекте недоступны."
	pages.append(page.duplicate(true));_show_page(page_id)

func _update_actions()->void:
	if not _built:return
	for key in buttons:
		buttons[key].input_allowed=input_allowed
		if key=="close":continue
		var available:bool=not _rows.is_empty() if key=="object" else pages.any(func(page):return str(page.id)==key)
		buttons[key].disabled=_loading or not available
		buttons[key].set_pressed_no_signal((current_page_id.begins_with("object:") if key=="object" else current_page_id==key))
	for id in object_buttons:
		object_buttons[id].input_allowed=input_allowed;object_buttons[id].add_theme_color_override("font_color",Color("8aead3") if id==selected_body_id else Color("cfdee7"))

func release_pointers()->void:
	for button in buttons.values():button.release_pointer()
	for button in object_buttons.values():button.release_pointer()
	if text_scroll!=null:text_scroll.release_pointer()
	if object_scroll!=null:object_scroll.release_pointer()

func _notification(what:int)->void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_EXIT_TREE]:release_pointers()
	elif what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():release_pointers()

func _draw()->void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("050d19"));draw_line(Vector2(24,78),Vector2(size.x-24,78),Color("24475b"),1,true)
