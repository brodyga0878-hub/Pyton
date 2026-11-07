extends Control
# A real source-sector/galaxy instrument. Simulation commands are emitted only
# after a separate confirmation; the map owns no flight/navigation references.
const Model=preload("res://scripts/galactic_map_model.gd")
const TouchAction=preload("res://scripts/touch_action_button.gd")
signal system_selected(id:int)
signal jump_requested(id:int)
signal close_requested
var model:RefCounted
var buttons:Dictionary={}
var search_edit:LineEdit
var sector_x:LineEdit
var sector_y:LineEdit
var title:Label
var status:Label
var details:Label
var results:VBoxContainer
var result_scroll:ScrollContainer
var input_allowed:=true:
	set(value):
		input_allowed=value
		if not value:release_pointers()
var _state:Dictionary={}
var _pending:Dictionary={}
var _worker:Thread
var _worker_generation:=0
var _generation:=0
var _ready_ui:=false
var _plot:=Rect2()
var _overview_rect:=Rect2()
var _overview_texture:ImageTexture
var _overview:=false
var _overview_scale:=52
var _center:=Vector2.ZERO
var _pixels_per_ly:=24.0
var _yaw:=0.0
var _tilt:=0.60
var _markers:Array=[]
# Published rectangles are the actual rendered sector labels, in map-local
# coordinates. Markers remain selectable when a crowded minor label is omitted.
var last_label_rects:Array[Dictionary]=[]
var _pointers:Dictionary={}
var _press_origin:=Vector2.ZERO
var _last_pointer:=Vector2.ZERO
var _dragged:=false
var _mouse_rotating:=false
var _pinch_distance:=0.0
var _pinch_angle:=0.0
var _request_clock:=0.0
var _request_dirty:=false
var _plot_canvas:Control
var _drawing_canvas:Control

class PlotCanvas extends Control:
	var controller:Control
	func _draw()->void:
		if controller!=null:controller._paint_plot(self)

static func _prepare(state:Dictionary,request:Dictionary)->Dictionary:
	var candidate:=Model.new()
	if not candidate.configure_state(state):return {"ok":false,"error":"Не удалось открыть исходную карту."}
	var center:Variant=request.get("center",candidate.center_sector)
	if not center is Vector2 or not center.is_finite():return {"ok":false,"error":"Недопустимые координаты карты."}
	if not candidate.load_sector_window(center):return {"ok":false,"error":"Не удалось загрузить выбранный сектор."}
	var query:=str(request.get("search",""))
	if not query.is_empty():candidate.search(query)
	var pixels:=PackedByteArray()
	if bool(request.get("overview",false)):
		pixels=candidate.overview_pixels(int(request.get("overview_scale",52)))
		if pixels.is_empty():return {"ok":false,"error":"Исходные данные обзора галактики недоступны."}
	return {"ok":true,"model":candidate,"pixels":pixels,"request":request}

func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_STOP;clip_contents=true
	_build();resized.connect(_layout);_layout();_ready_ui=true
	if not _state.is_empty():_request_now()

func _exit_tree()->void:finish_preparation()
func finish_preparation()->void:
	if _worker!=null:_worker.wait_to_finish();_worker=null
func _notification(what:int)->void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_EXIT_TREE]:release_pointers()
	elif what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():release_pointers()

func configure_state(state:Dictionary)->bool:
	if not Model.prepare_shared_resources():return false
	var check:=Model.new()
	if not check.configure_state(state):return false
	_state=state.duplicate(true);_center=check.center_sector
	if _ready_ui:_request_now()
	return true

func set_feedback(message:String)->void:
	if status!=null:status.text=message

func _style()->StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=Color("9a9f9c");s.border_color=Color("d8ded7");s.border_width_left=2;s.border_width_top=2;s.border_width_right=1;s.border_width_bottom=1
	s.content_margin_left=5;s.content_margin_right=5;s.content_margin_top=4;s.content_margin_bottom=4
	return s
func _button(key:String,text:String,callback:Callable)->Button:
	var b:=TouchAction.new();b.name="Galaxy_"+key;b.text=text;b.focus_mode=Control.FOCUS_NONE;b.custom_minimum_size=Vector2(64,64);b.clip_text=true
	b.add_theme_stylebox_override("normal",_style());var s:=_style();s.bg_color=Color("626d6a");b.add_theme_stylebox_override("pressed",s)
	b.add_theme_color_override("font_color",Color("17242c"));b.add_theme_font_size_override("font_size",18)
	b.pressed.connect(callback);add_child(b);buttons[key]=b;return b
func _label(text:String,font_size:int)->Label:
	var l:=Label.new();l.text=text;l.mouse_filter=Control.MOUSE_FILTER_IGNORE;l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",Color("e0e8df"));l.clip_text=true;add_child(l);return l
func _build()->void:
	_plot_canvas=PlotCanvas.new();_plot_canvas.controller=self;_plot_canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE;_plot_canvas.clip_contents=true;add_child(_plot_canvas)
	title=_label("ГАЛАКТИЧЕСКАЯ КАРТА",25);status=_label("Подготовка исходных секторов…",16)
	_button("close","Закрыть",func():release_pointers();close_requested.emit())
	_button("mode","Галактика",_toggle_mode);_button("home","К кораблю",center_current)
	_button("zoom_out","−",func():zoom(-1));_button("zoom_in","+",func():zoom(1))
	_button("rotate_left","↶",func():_yaw-=PI/12;queue_redraw())
	_button("rotate_right","↷",func():_yaw+=PI/12;queue_redraw())
	_button("tilt","Наклон",func():_tilt=0.35 if _tilt>0.7 else (_tilt+0.25);queue_redraw())
	_button("reset","Сброс",func():_yaw=0;_tilt=0.60;_pixels_per_ly=24;queue_redraw())
	_button("search","Найти",_search);_button("sector_go","Сектор",_goto_sector)
	_button("jump","Гиперпереход",_confirm_jump)
	search_edit=LineEdit.new();search_edit.placeholder_text="Название системы";search_edit.add_theme_font_size_override("font_size",20);search_edit.text_submitted.connect(func(_text:String):_search());add_child(search_edit)
	sector_x=LineEdit.new();sector_y=LineEdit.new()
	for edit in [sector_x,sector_y]:
		edit.add_theme_font_size_override("font_size",20);edit.text_submitted.connect(func(_text:String):_goto_sector());add_child(edit)
	sector_x.placeholder_text="Сектор X";sector_y.placeholder_text="Сектор Y"
	details=_label("Выберите звезду на карте.",18);details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	result_scroll=ScrollContainer.new();result_scroll.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(result_scroll)
	results=VBoxContainer.new();results.add_theme_constant_override("separation",5);results.size_flags_horizontal=Control.SIZE_EXPAND_FILL;result_scroll.add_child(results)

func _layout()->void:
	if title==null:return
	var w:=size.x;var h:=size.y;var side:=250.0 if w<1000 else 285.0;var footer:=164.0
	title.position=Vector2(14,8);title.size=Vector2(maxf(20,w-150),38)
	buttons.close.position=Vector2(w-126,8);buttons.close.size=Vector2(112,64)
	search_edit.position=Vector2(14,64);search_edit.size=Vector2(maxf(80,w-side-126),64)
	buttons.search.position=Vector2(w-side-106,64);buttons.search.size=Vector2(92,64)
	_plot=Rect2(14,142,maxf(140,w-side-40),maxf(96,h-footer-154))
	_plot_canvas.position=_plot.position;_plot_canvas.size=_plot.size
	details.position=Vector2(w-side,140);details.size=Vector2(side-14,maxf(90,_plot.size.y*0.52))
	result_scroll.position=Vector2(w-side,details.position.y+details.size.y+6);result_scroll.size=Vector2(side-14,maxf(1,_plot.end.y-70-result_scroll.position.y))
	buttons.jump.position=Vector2(w-side,_plot.end.y-64);buttons.jump.size=Vector2(side-14,64)
	var keys:=["mode","home","rotate_left","rotate_right","tilt","zoom_out","zoom_in"]
	var bw:float=(w-24-6*(keys.size()-1))/keys.size()
	for i in range(keys.size()):
		buttons[keys[i]].position=Vector2(12+i*(bw+6),h-footer+8);buttons[keys[i]].size=Vector2(bw,64)
	sector_x.position=Vector2(12,h-80);sector_x.size=Vector2(95,64)
	sector_y.position=Vector2(113,h-80);sector_y.size=Vector2(95,64)
	buttons.sector_go.position=Vector2(214,h-80);buttons.sector_go.size=Vector2(104,64)
	buttons.reset.position=Vector2(324,h-80);buttons.reset.size=Vector2(100,64)
	status.position=Vector2(438,h-80);status.size=Vector2(maxf(20,w-450),64);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	queue_redraw()

func _request_now(search:="")->void:
	_generation+=1;_request_dirty=false;_request_clock=0
	_pending={"generation":_generation,"center":_center,"overview":_overview,"overview_scale":_overview_scale,"search":search}
	if _worker==null:_start_pending()
	if status!=null:status.text="Загрузка исходной карты…"
	_update_buttons()
func _start_pending()->void:
	if _pending.is_empty():return
	var request:=_pending.duplicate(true);_pending.clear();_worker_generation=int(request.generation)
	_worker=Thread.new()
	if _worker.start(_prepare.bind(_state.duplicate(true),request))!=OK:_worker=null;status.text="Не удалось подготовить карту."
func _process(dt:float)->void:
	if _worker!=null and not _worker.is_alive():
		var result:Variant=_worker.wait_to_finish();_worker=null
		if _worker_generation==_generation:
			if result is Dictionary and bool(result.get("ok",false)):
				model=result.model
				if not result.pixels.is_empty():_overview_texture=ImageTexture.create_from_image(Image.create_from_data(320,158,false,Image.FORMAT_RGBA8,result.pixels))
				_publish_labels();_publish_search();queue_redraw()
			else:status.text=str(result.get("error","Не удалось открыть карту.")) if result is Dictionary else "Не удалось открыть карту."
		_start_pending();_update_buttons()
	if _request_dirty:
		_request_clock+=dt
		if _request_clock>=0.12:_request_now()
	for b in buttons.values():b.input_allowed=input_allowed and is_visible_in_tree()
func loading()->bool:return _worker!=null or not _pending.is_empty() or _request_dirty

func _publish_labels()->void:
	if model==null:return
	var sector:=Model.display_sector(Vector2i(floori(_center.x),floori(_center.y)))
	title.text=("ОБЗОР ГАЛАКТИКИ" if _overview else "СЕКТОРНАЯ КАРТА · (%d, %d)"%[sector.x,sector.y]) if model.native else "КАРТА СОХРАНЁННОГО ПОЛЁТА"
	sector_x.text=str(sector.x);sector_y.text=str(sector.y)
	buttons.mode.text="Сектора" if _overview else "Галактика"
	var state:Dictionary=model.jump_state();var row:Dictionary=model.selected
	var xy:=Model.display_sector(Vector2i(int(row.sector[0]),int(row.sector[1]))) if model.native else Vector2i(int(row.sector[0]),int(row.sector[1]))
	details.text="%s\nСектор (%d, %d)\nДистанция: %.2f св. лет\nДальность: %.2f св. лет\nТопливо: %d/%d\nДля прыжка: %d\n%s"%[row.name,xy.x,xy.y,float(state.distance_ly),model.jump_range_ly,model.fuel,model.fuel_capacity,int(state.fuel_required),"Переход доступен" if bool(state.reachable) else state.reason]
	status.text=("%d систем · сетка 8 св. лет"%model.rows.size() if not _overview else "Плотность по исходным данным FFE · коснитесь области для просмотра секторов") if model.native else "%d систем · сохранённая схема перелётов"%model.rows.size()
	_update_buttons()
func _publish_search()->void:
	for child in results.get_children():results.remove_child(child);child.queue_free()
	if model==null:return
	for row:Dictionary in model.search_results:
		var b:=TouchAction.new();b.text="%s · %.1f св. лет"%[row.name,model.distance_ly(row)];b.custom_minimum_size=Vector2(100,64);b.clip_text=true;b.add_theme_font_size_override("font_size",16)
		var id:=int(row.id);b.pressed.connect(func():select_system(id,true));results.add_child(b)
	if not search_edit.text.strip_edges().is_empty():status.text="Найдено %d · именованные системы и видимая область"%model.search_results.size()
func _update_buttons()->void:
	if not _ready_ui:return
	buttons.jump.disabled=model==null or loading() or not bool(model.jump_state().get("reachable",false))
	buttons.mode.disabled=model!=null and not model.native;buttons.sector_go.disabled=model!=null and not model.native
	sector_x.editable=model==null or model.native;sector_y.editable=model==null or model.native
	for key in ["rotate_left","rotate_right","tilt"]:buttons[key].disabled=_overview

func select_system(id:int,recenter:=false)->bool:
	if model==null or loading() or not model.select(id):return false
	_state.selected_id=id;system_selected.emit(id)
	if recenter:
		_center=model.sector_position(model.selected);_overview=false;_request_now()
	else:_publish_labels();queue_redraw()
	return true
func _confirm_jump()->void:
	if model!=null and not loading() and bool(model.jump_state().get("reachable",false)):release_pointers();jump_requested.emit(int(model.selected_id))
func center_current()->void:
	if model==null:return
	_center=model.sector_position(model.current);_request_now()
func _toggle_mode()->void:
	if model!=null and not model.native:return
	_overview=not _overview;release_pointers();_request_now()
func zoom(direction:int)->void:
	if _overview:_overview_scale=clampi(roundi(float(_overview_scale)*(0.65 if direction>0 else 1.55)),1,255);_request_now()
	else:_pixels_per_ly=clampf(_pixels_per_ly*(1.3 if direction>0 else 1/1.3),4,120);queue_redraw()
func _search()->void:
	var query:=search_edit.text.strip_edges()
	if query.is_empty():status.text="Введите название системы.";return
	_request_now(query)
func _goto_sector()->void:
	if model!=null and not model.native:status.text="Исходная галактическая карта доступна в новом полёте.";return
	if not sector_x.text.is_valid_int() or not sector_y.text.is_valid_int():status.text="Координаты сектора должны быть целыми.";return
	# Validate before narrowing to Vector2i; an oversized text integer must not
	# wrap through32bits back into a valid sector.
	var x:=int(sector_x.text);var y:=int(sector_y.text)
	if x< -5912 or x>2279 or y< -5412 or y>2779:status.text="Такой сектор находится за границей галактики.";return
	var raw:=Model.raw_sector(Vector2i(x,y))
	if not Model.valid_sector(raw):status.text="Такой сектор находится за границей галактики.";return
	_center=Vector2(raw)+Vector2(0.5,0.5);_overview=false;_request_now()

func release_pointers()->void:
	_pointers.clear();_pinch_distance=0;_mouse_rotating=false
	for b in buttons.values():b.release_pointer()
	if results!=null:
		for b in results.get_children():
			if b.has_method("release_pointer"):b.release_pointer()
func _inside_plot(global:Vector2)->bool:return _plot.has_point(get_global_transform_with_canvas().affine_inverse()*global)
func _local(global:Vector2)->Vector2:return get_global_transform_with_canvas().affine_inverse()*global
func _pan(delta:Vector2)->void:
	if model==null or not delta.is_finite():return
	if _overview:
		_center=Model.clamp_center(_center+Vector2(-delta.x,delta.y)*Vector2(320,158)/_overview_rect.size*float(_overview_scale))
	else:_center=Model.clamp_center(_center-Model.pan_delta(delta,_yaw,_tilt,_pixels_per_ly))
	_request_dirty=true;_request_clock=0;queue_redraw()
func _tap(point:Vector2)->void:
	if model==null or loading():return
	if _overview:
		if _overview_rect.has_point(point):_center=model.overview_sector((point-_overview_rect.position)/_overview_rect.size*Vector2(320,158),_overview_scale);_overview=false;_request_now()
		return
	var best:=-1;var distance:=24.0
	for row:Dictionary in _markers:
		var d:float=point.distance_to(row.point)
		if d<distance:distance=d;best=int(row.id)
	if best>=0:select_system(best)
func _input(event:InputEvent)->void:
	if not input_allowed or not is_visible_in_tree():release_pointers();return
	if event is InputEventScreenTouch:
		if event.canceled:
			_pointers.erase(event.index);_pinch_distance=0;return
		if event.pressed:
			if not _inside_plot(event.position):return
			_pointers[event.index]=_local(event.position)
			if _pointers.size()==1:_press_origin=_local(event.position);_last_pointer=_press_origin;_dragged=false
			if _pointers.size()==2:
				var p:Array=_pointers.values();_pinch_distance=p[0].distance_to(p[1]);_pinch_angle=(p[1]-p[0]).angle();_dragged=true
			get_viewport().set_input_as_handled()
		elif _pointers.has(event.index):
			if _pointers.size()==1 and not _dragged:_tap(_local(event.position))
			_pointers.erase(event.index);_pinch_distance=0;get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _pointers.has(event.index):
		var local:=_local(event.position)
		if not local.is_finite():return
		var previous:Vector2=_pointers[event.index];_pointers[event.index]=local
		if _pointers.size()>=2 and not _overview:
			var p:Array=_pointers.values();var length:float=p[0].distance_to(p[1]);var angle:float=(p[1]-p[0]).angle()
			if _pinch_distance>1:_pixels_per_ly=clampf(_pixels_per_ly*length/_pinch_distance,4,120);_yaw+=wrapf(angle-_pinch_angle,-PI,PI)
			_pinch_distance=length;_pinch_angle=angle;_dragged=true;queue_redraw()
		else:
			if local.distance_to(_press_origin)>8:_dragged=true
			if _dragged:_pan(local-previous)
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		if event.device==-1:return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed and _inside_plot(event.position):zoom(1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1);get_viewport().set_input_as_handled()
		elif event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				if not _inside_plot(event.position):return
				_pointers[-2]=_local(event.position);_press_origin=_pointers[-2];_dragged=false;_mouse_rotating=event.button_index==MOUSE_BUTTON_RIGHT
			elif _pointers.has(-2):
				if not _dragged and not _mouse_rotating:_tap(_local(event.position))
				_pointers.erase(-2);_mouse_rotating=false
			else:return
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and event.device!=-1 and _pointers.has(-2):
		var local:=_local(event.position)
		if not local.is_finite():return
		var previous:Vector2=_pointers[-2];_pointers[-2]=local
		if local.distance_to(_press_origin)>8:_dragged=true
		if _dragged:
			if _mouse_rotating:_yaw+=(local.x-previous.x)*0.009;_tilt=clampf(_tilt+(local.y-previous.y)*0.006,0.20,1.4);queue_redraw()
			else:_pan(local-previous)
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event:InputEvent)->void:
	if not input_allowed or not is_visible_in_tree() or not event is InputEventKey or not event.pressed:return
	if get_viewport().gui_get_focus_owner() is LineEdit:return
	match event.physical_keycode:
		KEY_C:center_current()
		KEY_EQUAL,KEY_PLUS,KEY_KP_ADD:zoom(1)
		KEY_MINUS,KEY_KP_SUBTRACT:zoom(-1)
		KEY_LEFT:_pan(Vector2(56,0))
		KEY_RIGHT:_pan(Vector2(-56,0))
		KEY_UP:_pan(Vector2(0,56))
		KEY_DOWN:_pan(Vector2(0,-56))
		_:return
	get_viewport().set_input_as_handled()

func _projection(position:Array)->Dictionary:
	var center:Array
	if model.native:center=[(float(_center.x)-float(model.galaxy._sol_q16[0])/65536.0)*8.0,(float(_center.y)-float(model.galaxy._sol_q16[1])/65536.0)*8.0,0.0]
	else:center=[(float(_center.x)-Model.DISPLAY_ORIGIN.x)*8.0,(float(_center.y)-Model.DISPLAY_ORIGIN.y)*8.0,0.0]
	return Model.map_point(position,center,_yaw,_tilt,_pixels_per_ly,_plot.get_center())
func _line(a:Dictionary,b:Dictionary,color:Color,width:=1.0)->void:
	if not a.is_empty() and not b.is_empty():_drawing_canvas.draw_line(a.point,b.point,color,width,true)
func _draw_grid()->void:
	var start_x:=floori(_center.x)-1;var start_y:=floori(_center.y)-1
	var offset_x:=float(model.galaxy._sol_q16[0])/65536.0 if model.native else float(Model.DISPLAY_ORIGIN.x)
	var offset_y:=float(model.galaxy._sol_q16[1])/65536.0 if model.native else float(Model.DISPLAY_ORIGIN.y)
	for i in range(4):
		var x:=float(start_x+i-offset_x)*8.0;var y:=float(start_y+i-offset_y)*8.0
		_line(_projection([x,(start_y-offset_y)*8.0,0.0]),_projection([x,(start_y+3-offset_y)*8.0,0.0]),Color("263e4b"))
		_line(_projection([(start_x-offset_x)*8.0,y,0.0]),_projection([(start_x+3-offset_x)*8.0,y,0.0]),Color("263e4b"))
func _draw_range()->void:
	var c:Array=model.current.position_ly;var radius:float=model.jump_range_ly
	if radius<=0:return
	for plane in range(3):
		var previous:Dictionary={}
		for i in range(65):
			var angle:=TAU*float(i)/64;var p:=c.duplicate();p[plane]=float(c[plane])+cos(angle)*radius;p[(plane+1)%3]=float(c[(plane+1)%3])+sin(angle)*radius
			var point:=_projection(p)
			if not previous.is_empty():_line(previous,point,Color(0.2,0.5,0.25,0.36))
			previous=point
func _draw_sector()->void:
	_markers.clear();last_label_rects.clear();_draw_grid();_draw_range()
	var font:=ThemeDB.fallback_font
	var priority:Array[Dictionary]=[]
	var minor:Array[Dictionary]=[]
	for row:Dictionary in model.rows:
		var top:=_projection(row.position_ly)
		if top.is_empty() or not _plot.has_point(top.point):continue
		var ground:Array=row.position_ly.duplicate();ground[2]=0.0;var base:=_projection(ground)
		_line(base,top,Color("36556a"))
		var id:=int(row.id);var color:=Color("d5dbcf")
		if id==model.current_id:color=Color("63e796")
		elif id==model.selected_id:color=Color("ffe18b")
		_drawing_canvas.draw_circle(top.point,4 if id in [model.current_id,model.selected_id] else 2.2,color,true,-1,true)
		if id==model.selected_id:_drawing_canvas.draw_arc(top.point,10,0,TAU,28,color,1.5,true)
		_markers.append({"id":id,"point":top.point})
		var label:={"id":id,"point":top.point,"name":str(row.name),"color":color}
		if id==model.current_id:priority.push_front(label)
		elif id==model.selected_id:priority.append(label)
		elif model.rows.size()<90:minor.append(label)
	_line(_projection(model.current.position_ly),_projection(model.selected.position_ly),Color("c3aa65"),1.5)
	priority.append_array(minor)
	for label:Dictionary in priority:
		var width:=ceilf(font.get_string_size(label.name,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x)
		var height:=ceilf(font.get_height(14))
		var point:Vector2=label.point
		# Bounded placement around each real marker; source positions, marker hit
		# regions and font size stay unchanged. Clip the complete text rectangle.
		var offsets:=[Vector2(7,-height-4),Vector2(7,5),Vector2(-width-7,-height-4),Vector2(-width-7,5),Vector2(-width*0.5,-height-12),Vector2(-width*0.5,12),Vector2(7,-height*2-6),Vector2(7,height+8)]
		for offset:Vector2 in offsets:
			var rect:=Rect2((point+offset).round(),Vector2(width,height)).grow(2)
			if not _plot.encloses(rect):continue
			var occupied:=false
			for previous:Dictionary in last_label_rects:
				if rect.intersects(previous.rect):occupied=true;break
			if occupied:continue
			last_label_rects.append({"id":label.id,"rect":rect,"marker":point})
			_drawing_canvas.draw_string(font,rect.position+Vector2(2,2+font.get_ascent(14)),label.name,HORIZONTAL_ALIGNMENT_LEFT,-1,14,label.color)
			break
func _draw_overview()->void:
	last_label_rects.clear()
	var fit:=minf(_plot.size.x/320.0,_plot.size.y/158.0)
	_overview_rect=Rect2(_plot.get_center()-Vector2(320,158)*fit*0.5,Vector2(320,158)*fit)
	if _overview_texture!=null:_drawing_canvas.draw_texture_rect(_overview_texture,_overview_rect,false)
	_drawing_canvas.draw_line(_overview_rect.get_center()-Vector2(10,0),_overview_rect.get_center()+Vector2(10,0),Color("8198a0"),1,true)
	_drawing_canvas.draw_line(_overview_rect.get_center()-Vector2(0,10),_overview_rect.get_center()+Vector2(0,10),Color("8198a0"),1,true)
	var current:Vector2=model.sector_position(model.current)
	var sx:=floori(_center.x)-(_overview_scale>>1)+160*_overview_scale;var sy:=floori(_center.y)+(_overview_scale>>1)-79*_overview_scale
	var p:=Vector2(319-(float(sx)-current.x)/_overview_scale,157-(current.y-float(sy))/_overview_scale)
	var marker:=_overview_rect.position+p/Vector2(320,158)*_overview_rect.size
	if _overview_rect.has_point(marker):
		_drawing_canvas.draw_arc(marker,6,0,TAU,24,Color("66ee94"),2,true)
		_drawing_canvas.draw_string(ThemeDB.fallback_font,marker+Vector2(8,-5),str(model.current.name),HORIZONTAL_ALIGNMENT_LEFT,170,15,Color("66ee94"))
	for landmark:Dictionary in model._map_data.get("landmarks",[]):
		# F846 stops once its descending maximum-scale threshold is below the
		# current scale. Unknown text codes are not replaced with invented names.
		if int(landmark.get("visible_above_scale",0))<_overview_scale:continue
		if not landmark.get("name_ru") is String:continue
		var raw:Array=landmark.get("sector_raw",[])
		if raw.size()!=2:continue
		var pixel:=Vector2(319-(float(sx)-float(raw[0]))/_overview_scale,157-(float(raw[1])-float(sy))/_overview_scale)
		var where:=_overview_rect.position+pixel/Vector2(320,158)*_overview_rect.size
		if _overview_rect.has_point(where):_drawing_canvas.draw_string(ThemeDB.fallback_font,where,str(landmark.name_ru),HORIZONTAL_ALIGNMENT_LEFT,210,14,Color("b9b9b9"))
func _paint_plot(canvas:Control)->void:
	if model==null:return
	_drawing_canvas=canvas;canvas.draw_set_transform(-_plot.position)
	if _overview:_draw_overview()
	else:_draw_sector()
func _draw()->void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("020408"));draw_rect(Rect2(0,size.y-164,size.x,164),Color("727b7b"));draw_line(Vector2(0,size.y-164),Vector2(size.x,size.y-164),Color("c4cdc9"),2,true)
	draw_rect(_plot,Color("050910"));draw_rect(_plot,Color("3e5965"),false,1)
	if _plot_canvas!=null:_plot_canvas.queue_redraw()
