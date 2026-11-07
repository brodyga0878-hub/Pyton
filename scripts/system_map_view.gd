extends Control
# Functional system-map UI over an isolated source-orbit model. Main owns all
# travel decisions; selecting a map symbol cannot move the gameplay ship.
const Model=preload("res://scripts/system_map_model.gd")
const Action=preload("res://scripts/touch_action_button.gd")
signal body_selected(id:String)
signal site_selected(id:String)
signal travel_requested(body_id:String,site_id:String)
signal close_requested
signal information_requested(selected_id:String)
var model:=Model.new()
var buttons:Dictionary={}
var body_buttons:Dictionary={}
var title:Label
var feedback:Label
var details:Label
var time_label:Label
var tree_list:VBoxContainer
var tree_scroll:ScrollContainer
var plot:Control
var selected_label:Label
var pixels_per_au:=20.0
var pan:=Vector2.ZERO
var yaw:=0.0
var inclination:=PI*0.36
var show_labels:=true
var show_orbits:=true
var show_ports:=true
var _built:=false
var _fit_pending:=true
var _last_size:=Vector2.ZERO
var _plot_hits:Array[Dictionary]=[]
# Actual rendered font rectangles in plot-local coordinates. Crowding only
# suppresses names; all original projected marker/hierarchy targets remain.
var last_label_rects:Array[Dictionary]=[]
var last_scale_label_rect:=Rect2()
var _pending_site_center:=""
var _feedback_text:=""
var input_allowed:=true:
	set(value):
		input_allowed=value
		if not value:release_pointers()
		for button in buttons.values():button.input_allowed=value
		for button in body_buttons.values():button.input_allowed=value

class SystemPlot extends Control:
	var owner_map:Control
	var _pointers:Dictionary={}
	var _start:=Vector2.ZERO
	var _previous:=Vector2.ZERO
	var _dragged:=false
	var _multitouch:=false
	var _mouse:=false
	var _rotating:=false
	func _ready()->void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE;clip_contents=true
	func _draw()->void:
		if is_instance_valid(owner_map):owner_map._draw_plot(self)
	func release_pointers()->void:
		_pointers.clear();_mouse=false;_rotating=false;_dragged=false;_multitouch=false
	func _notification(what:int)->void:
		if what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():release_pointers()
		elif what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_EXIT_TREE]:release_pointers()
	func _inside(point:Vector2)->bool:return Rect2(Vector2.ZERO,size).has_point(point)
	func _input(event:InputEvent)->void:
		if not is_visible_in_tree() or not is_instance_valid(owner_map) or not owner_map.input_allowed:release_pointers();return
		if event is InputEventScreenTouch:
			var local:Vector2=get_global_transform_with_canvas().affine_inverse()*event.position
			if event.canceled:
				if _pointers.has(event.index):_pointers.erase(event.index);get_viewport().set_input_as_handled()
				return
			if event.pressed:
				if not _inside(local):return
				_pointers[event.index]=local
				if _pointers.size()==1:_start=local;_previous=local;_dragged=false;_multitouch=false
				else:_multitouch=true
				get_viewport().set_input_as_handled()
			elif _pointers.has(event.index):
				get_viewport().set_input_as_handled();_pointers.erase(event.index)
				if _pointers.is_empty() and not _dragged and not _multitouch and _inside(local):owner_map.select_at(local)
		elif event is InputEventScreenDrag and _pointers.has(event.index):
			var local:Vector2=get_global_transform_with_canvas().affine_inverse()*event.position
			var old:Vector2=_pointers[event.index]
			if _pointers.size()>=2:
				var keys:Array=_pointers.keys();var other:Vector2=_pointers[keys[1] if keys[0]==event.index else keys[0]]
				var before:float=old.distance_to(other);var after:float=local.distance_to(other)
				if before>8 and after>8:owner_map.zoom_at(after/before,(local+other)*0.5)
				owner_map.pan+=(local-old)*0.5;_dragged=true
			else:
				if local.distance_to(_start)>10:_dragged=true
				if _dragged:owner_map.pan+=local-old
			_pointers[event.index]=local;owner_map._redraw();get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton:
			if event.device==-1 or not _pointers.is_empty():return
			var local:Vector2=get_global_transform_with_canvas().affine_inverse()*event.position
			if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
				if event.pressed and _inside(local):owner_map.zoom_at(1.35 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.35,local);get_viewport().set_input_as_handled()
			elif event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
				if event.pressed and _inside(local):_mouse=true;_rotating=event.button_index==MOUSE_BUTTON_RIGHT;_start=local;_previous=local;_dragged=false;get_viewport().set_input_as_handled()
				elif not event.pressed and _mouse:
					_mouse=false;get_viewport().set_input_as_handled()
					if not _dragged and not _rotating and _inside(local):owner_map.select_at(local)
		elif event is InputEventMouseMotion and _mouse:
			if event.device==-1:return
			var local:Vector2=get_global_transform_with_canvas().affine_inverse()*event.position
			if local.distance_to(_start)>10:_dragged=true
			if _dragged:
				if _rotating:owner_map.yaw+=float(local.x-_previous.x)*0.007;owner_map.inclination=clampf(owner_map.inclination+float(local.y-_previous.y)*0.007,0.15,PI*0.5)
				else:owner_map.pan+=local-_previous
			_previous=local;owner_map._redraw();get_viewport().set_input_as_handled()

func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;custom_minimum_size=Vector2(720,440)
	_build();resized.connect(_layout);_layout();_populate_hierarchy();_update_contents()

func _label(name_value:String,font_size:int)->Label:
	var label:=Label.new();label.name=name_value;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",Color("e1e3dc"));label.clip_text=true;add_child(label);return label

func _style(fill:String)->StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=Color(fill);style.border_color=Color("c2c6bd")
	style.border_width_left=2;style.border_width_top=2;style.border_width_bottom=1;style.border_width_right=1
	style.content_margin_left=5;style.content_margin_right=5;return style

func _button(key:String,text:String,callback:Callable)->Button:
	var button:=Action.new();button.name="SystemMap_"+key;button.text=text;button.tooltip_text=text;button.clip_text=true;button.focus_mode=Control.FOCUS_NONE;button.custom_minimum_size=Vector2(64,64);button.input_allowed=input_allowed
	button.add_theme_font_size_override("font_size",16);button.add_theme_stylebox_override("normal",_style("687273"));button.add_theme_stylebox_override("hover",_style("87918b"));button.add_theme_stylebox_override("pressed",_style("394c4b"));button.add_theme_stylebox_override("disabled",_style("363e40"))
	button.pressed.connect(callback);add_child(button);buttons[key]=button;return button

func _build()->void:
	_built=true
	plot=SystemPlot.new();plot.name="SystemMapPlot";plot.owner_map=self;add_child(plot)
	title=_label("SystemMapTitle",24);feedback=_label("SystemMapFeedback",13);feedback.add_theme_color_override("font_color",Color("ffbd82"))
	details=_label("SystemMapDetails",16);details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.clip_text=false
	selected_label=_label("SystemMapSelection",18);selected_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	time_label=_label("SystemMapTime",15)
	tree_scroll=ScrollContainer.new();tree_scroll.name="SystemMapHierarchy";add_child(tree_scroll)
	tree_list=VBoxContainer.new();tree_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tree_list.add_theme_constant_override("separation",3);tree_scroll.add_child(tree_list)
	_button("close","Закрыть",func():release_pointers();close_requested.emit())
	_button("information","Сведения",_request_information)
	_button("fit","Вся система",func():model.reset_focus();fit_view())
	_button("center","Центр цели",center_selection)
	_button("names","Имена",func():show_labels=not show_labels;_redraw())
	_button("orbits","Орбиты",func():show_orbits=not show_orbits;_redraw())
	_button("ports","Порты",func():show_ports=not show_ports;_redraw())
	_button("view","Ракурс",func():inclination=PI*0.5 if inclination<1.5 else PI*0.25;_redraw())
	_button("rotate_left","↶",func():yaw-=PI/12.0;_redraw())
	_button("rotate_right","↷",func():yaw+=PI/12.0;_redraw())
	_button("zoom_out","−",func():zoom_at(1.0/1.8,plot.size*0.5))
	_button("zoom_in","+",func():zoom_at(1.8,plot.size*0.5))
	_button("earlier","− день",func():set_preview_offset(model.preview_offset_days-1))
	_button("now","Сейчас",func():set_preview_offset(0))
	_button("later","+ день",func():set_preview_offset(model.preview_offset_days+1))
	_button("travel","Подойти",_request_travel)
	for key in ["names","orbits","ports"]:buttons[key].toggle_mode=true;buttons[key].set_pressed_no_signal(true)

func configure(snapshot:Dictionary)->bool:
	var ok:=model.configure(snapshot)
	_fit_pending=true;_plot_hits.clear();last_label_rects.clear();_pending_site_center="";_feedback_text=""
	if _built:_populate_hierarchy();_update_contents()
	return ok

func update_elapsed_days(days:Variant)->bool:
	if (days is float or days is int) and float(days)==model.elapsed_days:return model.configured
	var ok:=model.update_elapsed_days(days)
	if ok:_update_contents()
	return ok

func set_preview_offset(days:Variant)->bool:
	var ok:=model.set_time_offset(days)
	if ok:_update_contents()
	return ok

func set_feedback(message:String)->void:
	_feedback_text=message
	if feedback!=null:feedback.text=message

func _populate_hierarchy()->void:
	for child in tree_list.get_children():tree_list.remove_child(child);child.queue_free()
	body_buttons.clear()
	for row:Dictionary in model.hierarchy():
		var button:=Action.new();button.name="MapObject_"+str(row.id);button.custom_minimum_size=Vector2(80,64);button.focus_mode=Control.FOCUS_NONE;button.clip_text=true;button.input_allowed=input_allowed
		button.text="  ".repeat(mini(model.depth(str(row.id)),5))+("△ " if row.ground else "◇ " if row.is_site else "● ")+str(row.name)
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.add_theme_font_size_override("font_size",16);button.add_theme_stylebox_override("normal",_style("283539"));button.add_theme_stylebox_override("pressed",_style("506962"));button.add_theme_stylebox_override("hover",_style("3d5051"))
		button.pressed.connect(_select.bind(str(row.id)));tree_list.add_child(button);body_buttons[str(row.id)]=button

func _layout()->void:
	if not _built:return
	var width:=maxf(720,size.x);var height:=maxf(440,size.y);var sidebar:=250.0 if width>=1100 else 210.0
	title.position=Vector2(12,8);title.size=Vector2(width-248,32)
	feedback.position=Vector2(12,43);feedback.size=Vector2(width-260,24)
	buttons.close.position=Vector2(width-112,4);buttons.close.size=Vector2(104,64)
	buttons.information.position=Vector2(width-232,4);buttons.information.size=Vector2(112,64)
	var toolbar:=["fit","center","names","orbits","ports","view","rotate_left","rotate_right"]
	var x:=8.0;var toolbar_width:float=(width-16.0-7*3)/8.0
	buttons.fit.text="Обзор" if width<1000 else "Вся система";buttons.center.text="Центр" if width<1000 else "Центр цели"
	for key in toolbar:buttons[key].position=Vector2(x,72);buttons[key].size=Vector2(toolbar_width,64);buttons[key].add_theme_font_size_override("font_size",14 if width<1000 else 17);x+=toolbar_width+3
	plot.position=Vector2(8,144);plot.size=Vector2(width-sidebar-24,height-252)
	selected_label.position=Vector2(width-sidebar,145);selected_label.size=Vector2(sidebar-8,48)
	var short:bool=height<600
	details.position=Vector2(width-sidebar,195);details.size=Vector2(sidebar-10,60 if short else 112);details.max_lines_visible=3 if short else -1;details.add_theme_font_size_override("font_size",14 if short else 16)
	var tree_top:=260.0 if short else 312.0
	tree_scroll.position=Vector2(width-sidebar,tree_top);tree_scroll.size=Vector2(sidebar-8,maxf(0,height-108-tree_top))
	time_label.position=Vector2(12,height-102);time_label.size=Vector2(width-24,28)
	var footer:=["zoom_out","zoom_in","earlier","now","later","travel"]
	x=8
	var foot_width:float=(width-16.0-5*4)/6.0
	for key in footer:buttons[key].position=Vector2(x,height-70);buttons[key].size=Vector2(foot_width,64);x+=foot_width+4
	if _last_size!=size:_fit_pending=true;_last_size=size
	_redraw()

func _process(_delta:float)->void:
	if not is_visible_in_tree():return
	if _fit_pending and model.configured and plot.size.x>0:fit_view();_fit_pending=false
	if model.preparation_remaining()>0:
		model.prepare_geometry(2);_update_contents()
		if not _pending_site_center.is_empty() and model.selected_id==_pending_site_center and not model.position_au(_pending_site_center).is_empty():center_selection()

func fit_view()->void:
	if not model.configured or plot==null:return
	pan=Vector2.ZERO
	var center:=model.focus_position()
	if center.is_empty():return
	var extent:=0.0
	for row:Dictionary in model.rows:
		if row.is_site or (str(row.id)!=model.focus_id and str(row.parent)!=model.focus_id):continue
		var point:=model.position_au(str(row.id))
		if point.is_empty():continue
		var relative:=_relative_project(point,center)
		extent=maxf(extent,maxf(absf(relative.x),absf(relative.y)))
	var focus:Dictionary=model.by_id.get(model.focus_id,{})
	var minimum:=maxf(0.000001,float(focus.get("radius_km",1))*6000.0/Model.AU_METRES)
	extent=maxf(extent,minimum)
	pixels_per_au=clampf(minf(plot.size.x,plot.size.y)*0.40/extent,0.0000001,1.0e13);_redraw();_update_contents()

func center_selection()->void:
	if not model.set_focus(model.selected_id):return
	fit_view()
	_pending_site_center=""
	var row:=model.selected()
	if row.get("is_site",false):
		var point:=model.position_au(model.selected_id);var center:=model.focus_position()
		if point.is_empty():_pending_site_center=model.selected_id
		if not point.is_empty() and not center.is_empty():
			var body:Dictionary=model.by_id.get(str(row.parent),{})
			var distance:float=model.distance_au(str(row.parent),model.selected_id)
			var extent:=maxf(float(body.get("radius_km",1))*1400.0/Model.AU_METRES,distance*1.25)
			pixels_per_au=clampf(minf(plot.size.x,plot.size.y)*0.4/maxf(extent,1e-9),0.0000001,1.0e13)
			pan=-_relative_project(point,center)*pixels_per_au
		_redraw()

func _relative_project(point:Variant,center:Variant)->Vector2:
	var x:=float(point[0])-float(center[0]);var y:=float(point[1])-float(center[1]);var z:=float(point[2])-float(center[2])
	var rx:=x*cos(yaw)-z*sin(yaw);var rz:=x*sin(yaw)+z*cos(yaw)
	return Vector2(rx,-(y*cos(inclination)-rz*sin(inclination)))

func project(point:Variant)->Vector2:
	var center:=model.focus_position()
	if center.is_empty():return Vector2(INF,INF)
	return plot.size*0.5+pan+_relative_project(point,center)*pixels_per_au

func zoom_at(factor:float,point:Vector2)->void:
	if not is_finite(factor) or factor<=0:return
	var next:=clampf(pixels_per_au*factor,0.0000001,1.0e13)
	var ratio:=next/pixels_per_au
	pan=point-plot.size*0.5-(point-plot.size*0.5-pan)*ratio;pixels_per_au=next;_redraw()

func _select(id:String)->void:
	if not model.select(id):return
	set_feedback("")
	var row:Dictionary=model.by_id[id]
	_update_contents()
	if row.is_site:site_selected.emit(id)
	else:body_selected.emit(id)

func select_at(point:Vector2)->void:
	var closest:="";var distance:=22.0
	for item:Dictionary in _plot_hits:
		var d:=point.distance_to(item.point)
		if d<distance:closest=str(item.id);distance=d
	if not closest.is_empty():_select(closest)

func _request_travel()->void:
	if not input_allowed:return
	var target:=model.selected_travel()
	if target.is_empty():return
	release_pointers();travel_requested.emit(str(target.body_id),str(target.site_id))

func _distance(value:float)->String:
	if not is_finite(value):return "—"
	return "%.3f а.е."%value if value>=0.01 else "%.0f км"%(value*Model.AU_METRES/1000.0)

func _update_contents()->void:
	if not _built:return
	title.text="%s · КАРТА СИСТЕМЫ"%model.system_name
	feedback.text=_feedback_text
	buttons.information.disabled=not model.configured
	if not model.configured:selected_label.text=model.last_error;buttons.travel.disabled=true;return
	var row:=model.selected()
	selected_label.text=str(row.get("name","Объект не выбран"))
	var kind:=str(row.get("kind",""));var description:=str({"star":"Звезда","barycenter":"Барицентр","earth":"Планета","rock":"Каменное тело","desert":"Планета","ice":"Ледяное тело","gas":"Газовый гигант","ice_gas":"Газовый гигант"}.get(kind,"Небесное тело"))
	if row.get("is_site",false):description="Наземный порт" if row.ground else "Орбитальная станция"
	var parent:Dictionary=model.by_id.get(str(row.get("parent","")),{})
	details.text=description+("\nРодитель: "+str(parent.name) if not parent.is_empty() else "")
	if row.has("radius_km"):details.text+="\nРадиус: %.0f км"%float(row.radius_km)
	if model.selected_id!=model.current_focus_id:details.text+="\nДо объекта: "+_distance(model.distance_au(model.current_focus_id,model.selected_id))
	buttons.travel.disabled=model.selected_travel().is_empty();buttons.travel.text="К порту" if row.get("is_site",false) else "Подойти"
	var date:=Model.Clock.from_elapsed_days(model.preview_days())
	time_label.text=("СЕЙЧАС · " if is_zero_approx(model.preview_offset_days) else "ПРОГНОЗ %+.0f сут. · "%model.preview_offset_days)+str(date.get("label_ru","—"))
	buttons.now.disabled=is_zero_approx(model.preview_offset_days)
	buttons.earlier.disabled=model.preview_days()<=0 or model.preview_offset_days<=-Model.MAX_PREVIEW_DAYS
	buttons.later.disabled=model.preview_offset_days>=Model.MAX_PREVIEW_DAYS or model.preview_days()>=Model.Clock.MAX_ELAPSED_DAYS
	for id in body_buttons:body_buttons[id].add_theme_color_override("font_color",Color("ffce71") if id==model.selected_id else Color("d8e0d7"))
	_redraw()

func _request_information()->void:
	if not input_allowed or not model.configured:return
	release_pointers();information_requested.emit(model.selected_id)

func _redraw()->void:
	if plot!=null:plot.queue_redraw()
	queue_redraw()

func release_pointers()->void:
	if plot!=null:plot.release_pointers()
	for button in buttons.values():button.release_pointer()
	for button in body_buttons.values():button.release_pointer()

func _notification(what:int)->void:
	if what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():release_pointers()
	elif what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_EXIT_TREE]:release_pointers()

func _draw()->void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("3c4548"));draw_rect(Rect2(0,0,size.x,64),Color("767e7c"))

func _draw_plot(canvas:Control)->void:
	canvas.draw_rect(Rect2(Vector2.ZERO,canvas.size),Color("020509"));_plot_hits.clear();last_label_rects.clear();last_scale_label_rect=Rect2()
	if not model.configured:return
	var font:=get_theme_default_font();var bounds:=Rect2(Vector2(2,2),canvas.size-Vector2(4,4))
	var length:=minf(150,canvas.size.x*0.3)
	var scale_text:=_distance(length/pixels_per_au)
	var scale_origin:=Vector2(12,canvas.size.y-32)
	last_scale_label_rect=Rect2(scale_origin-Vector2(0,font.get_ascent(14)),Vector2(ceilf(font.get_string_size(scale_text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x),ceilf(font.get_height(14)))).grow(2)
	var occupied_rects:Array[Rect2]=[last_scale_label_rect.merge(Rect2(Vector2(10,canvas.size.y-26),Vector2(length+4,4)))]
	var center:=canvas.size*0.5+pan
	for at in [Vector2(center.x,0),Vector2(0,center.y)]:
		if at.x==0:canvas.draw_line(at,Vector2(canvas.size.x,at.y),Color("192729"),1,true)
		else:canvas.draw_line(at,Vector2(at.x,canvas.size.y),Color("192729"),1,true)
	if show_orbits:
		for id in model.orbit_curves:
			if not model.visible_orbit(str(id)):continue
			var points:PackedVector2Array=PackedVector2Array()
			var valid:=true
			for point in model.orbit_points_au(str(id)):
				var projected:=project(point)
				if not projected.is_finite() or absf(projected.x)>1e7 or absf(projected.y)>1e7:valid=false;break
				points.append(projected)
			if valid and points.size()>1:canvas.draw_polyline(points,Color("697675") if id==model.selected_id else Color("364646"),1.2,true)
	var priority:Array[Dictionary]=[]
	var minor:Array[Dictionary]=[]
	for row:Dictionary in model.rows:
		if row.is_site and not show_ports and str(row.id)!=model.selected_id:continue
		var point:=model.position_au(str(row.id))
		if point.is_empty():continue
		var screen:=project(point)
		if not screen.is_finite() or not bounds.has_point(screen):continue
		var selected:bool=str(row.id)==model.selected_id
		var color:=Color("e8bf74") if str(row.get("kind",""))=="star" else Color("73a9cb") if str(row.get("kind","")) in ["earth","ice","ice_gas"] else Color("bbc1bc")
		if row.is_site:color=Color("8ad8bc")
		var radius:=5.0 if row.is_site else 7.0 if str(row.get("kind",""))=="star" else 4.0
		if row.is_site:
			var p:=PackedVector2Array([screen+Vector2(0,-5),screen+Vector2(5,4),screen+Vector2(-5,4),screen+Vector2(0,-5)]) if row.ground else PackedVector2Array([screen+Vector2(0,-5),screen+Vector2(5,0),screen+Vector2(0,5),screen+Vector2(-5,0),screen+Vector2(0,-5)])
			canvas.draw_polyline(p,color,1.5,true)
		else:canvas.draw_circle(screen,radius,color)
		if selected:canvas.draw_arc(screen,12,0,TAU,32,Color("ff936f"),2,true)
		if str(row.id)==model.current_focus_id:canvas.draw_arc(screen,9,0,TAU,28,Color("67d98b"),1.5,true)
		_plot_hits.append({"id":str(row.id),"point":screen})
		var current:bool=str(row.id)==model.current_focus_id
		if show_labels or selected or current:
			var label:={"id":str(row.id),"point":screen,"name":str(row.name),"color":Color("fff0b6") if selected else color}
			if selected:priority.push_front(label)
			elif current:priority.append(label)
			else:minor.append(label)
	priority.append_array(minor)
	for label:Dictionary in priority:
		var width:=ceilf(font.get_string_size(label.name,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x)
		var height:=ceilf(font.get_height(15))
		var point:Vector2=label.point
		# Each candidate bounds the complete real-font text. Selected/current
		# labels claim space first; minor names never bypass their occupied area.
		# Offsets move text only, leaving source positions and hit targets exact.
		var offsets:=[Vector2(11,-height-7),Vector2(11,7),Vector2(-width-11,-height-7),Vector2(-width-11,7),Vector2(-width*0.5,-height-15),Vector2(-width*0.5,15),Vector2(11,-height*2-9),Vector2(11,height+11),Vector2(11,-height*3-13)]
		for offset:Vector2 in offsets:
			var rect:=Rect2((point+offset).round(),Vector2(width,height)).grow(2)
			if not bounds.encloses(rect):continue
			var occupied:=false
			for previous:Rect2 in occupied_rects:
				if rect.intersects(previous):occupied=true;break
			if occupied:continue
			occupied_rects.append(rect)
			last_label_rects.append({"id":label.id,"rect":rect,"marker":point})
			canvas.draw_string(font,rect.position+Vector2(2,2+font.get_ascent(15)),label.name,HORIZONTAL_ALIGNMENT_LEFT,-1,15,label.color)
			break
	if not model.ship_position_au.is_empty() and is_zero_approx(model.preview_offset_days):
		var ship_point:=project(model.ship_position_au)
		if ship_point.is_finite() and bounds.has_point(ship_point):canvas.draw_polyline(PackedVector2Array([ship_point+Vector2(-5,5),ship_point+Vector2(0,-6),ship_point+Vector2(5,5)]),Color("f6eac2"),2,true)
	canvas.draw_line(Vector2(12,canvas.size.y-24),Vector2(12+length,canvas.size.y-24),Color("becdc3"),2,true)
	canvas.draw_string(font,scale_origin,scale_text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("becdc3"))
