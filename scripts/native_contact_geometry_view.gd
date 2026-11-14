extends Control
# Presentation only: copied, bound native-leaf packets in an isolated world.
# The viewport, camera and gesture state never reference flight or terrain.
const Action=preload("res://scripts/touch_action_button.gd")
const CONTRACT:="source-native-leaf-isolated-inspection-view-v1"
const MAX_TRIANGLES:=3
const MINIMUM_SIZE:=Vector2(360,350)
const COLOURS:=[Color("67d9ee"),Color("edbe70"),Color("81e1b0")]
const INITIAL_YAW:=0.55
const INITIAL_PITCH:=-0.45
var input_allowed:=true:
	set(value):
		input_allowed=value
		if not value:release_pointers()
		_update_actions()
var title:Label
var status:Label
var instructions:Label
var buttons:Dictionary={}
var plot:Panel
var viewport:SubViewport
var camera:Camera3D
var triangle_count:=0
var rejected_volume_count:=0
var last_error:=""
var _snapshot:Dictionary={}
var _snapshot_sha256:=""
var _built:=false
var _scene:Node3D
var _rig:Node3D
var _geometry:Node3D
var _container:SubViewportContainer
var _pointers:Dictionary={}
var _mouse_owned:=false
var _mouse_previous:=Vector2.ZERO
var _pinch_distance:=0.0
var _yaw:=INITIAL_YAW
var _pitch:=INITIAL_PITCH
var _zoom:=1.0
var _radius:=1.0
var _fit_distance:=4.0
var _origin_f64:=PackedFloat64Array([0,0,0])
var _display_extent:=1.0
var _display_vertices:=PackedVector3Array()

func _ready()->void:
	_ensure_built();resized.connect(_layout);_layout();_update_visibility()
func _notification(what:int)->void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_PAUSED,NOTIFICATION_EXIT_TREE]:release_pointers()
	elif what==NOTIFICATION_VISIBILITY_CHANGED:
		if not is_visible_in_tree():release_pointers()
		_update_visibility()
func _ensure_built()->void:
	if _built:return
	_built=true;name="NativeContactGeometryView";mouse_filter=Control.MOUSE_FILTER_IGNORE;clip_contents=true
	custom_minimum_size=MINIMUM_SIZE;size_flags_horizontal=Control.SIZE_EXPAND_FILL
	title=_label(20,Color("e0f1f6"));title.text="Исходная геометрия контакта"
	status=_label(16,Color("9ebdcc"));status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	instructions=_label(14,Color("95aebd"));instructions.text="Потяните для поворота; два пальца — масштаб.";instructions.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	plot=Panel.new();plot.mouse_filter=Control.MOUSE_FILTER_IGNORE;plot.clip_contents=true;add_child(plot)
	var panel:=StyleBoxFlat.new();panel.bg_color=Color("07131f");panel.border_color=Color("294b5e");panel.set_border_width_all(1);panel.set_corner_radius_all(8);plot.add_theme_stylebox_override("panel",panel)
	_container=SubViewportContainer.new();_container.mouse_filter=Control.MOUSE_FILTER_IGNORE;_container.stretch=true;plot.add_child(_container)
	viewport=SubViewport.new();viewport.name="NativeContactIsolatedViewport";viewport.world_3d=World3D.new();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;viewport.handle_input_locally=false;_container.add_child(viewport)
	_scene=Node3D.new();viewport.add_child(_scene)
	var environment_node:=WorldEnvironment.new();var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("07131f");environment_node.environment=environment;_scene.add_child(environment_node)
	_geometry=Node3D.new();_geometry.name="CopiedNativeLeaves";_scene.add_child(_geometry)
	_rig=Node3D.new();_scene.add_child(_rig);camera=Camera3D.new();camera.fov=50;camera.near=0.01;camera.far=128;camera.current=true;_rig.add_child(camera)
	_button("left","←","Повернуть влево",func():_rotate(Vector2(-0.25,0)))
	_button("right","→","Повернуть вправо",func():_rotate(Vector2(0.25,0)))
	_button("zoom_out","−","Отдалить",func():_change_zoom(1.2))
	_button("zoom_in","+","Приблизить",func():_change_zoom(1.0/1.2))
	_button("reset","Сброс","Вписать исходную геометрию",reset_view)
	_publish_unavailable();_layout()
func _label(font_size:int,ink:Color)->Label:
	var label:=Label.new();label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.clip_text=true;label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",ink);add_child(label);return label
func _button(key:String,text:String,tooltip:String,callback:Callable)->void:
	var button:=Action.new();button.text=text;button.tooltip_text=tooltip;button.clip_text=true;button.focus_mode=Control.FOCUS_NONE;button.custom_minimum_size=Vector2(64,64)
	button.add_theme_font_size_override("font_size",16 if key=="reset" else 24);button.add_theme_color_override("font_color",Color("dceaf2"))
	for role:String in ["normal","hover","pressed","disabled"]:
		var style:=StyleBoxFlat.new();style.bg_color=Color("1b4053") if role=="pressed" else Color("102635");style.border_color=Color("64bfd0") if role=="pressed" else Color("2a5365");style.set_border_width_all(1);style.set_corner_radius_all(8);button.add_theme_stylebox_override(role,style)
	button.pressed.connect(callback);add_child(button);buttons[key]=button
func _layout()->void:
	if not _built:return
	var width:=maxf(MINIMUM_SIZE.x,size.x);var height:=maxf(MINIMUM_SIZE.y,size.y);var inset:=8.0;var gap:=6.0
	title.position=Vector2(inset,inset);title.size=Vector2(width-2*inset,32)
	status.position=Vector2(inset,46);status.size=Vector2(width-2*inset,40)
	var hint_y:=height-inset-40.0;var button_y:=hint_y-gap-64.0;var plot_y:=92.0
	plot.position=Vector2(inset,plot_y);plot.size=Vector2(width-2*inset,maxf(128,button_y-gap-plot_y))
	_container.position=Vector2.ONE;_container.size=plot.size-Vector2(2,2)
	_container.stretch_shrink=maxi(1,ceili(maxf(_container.size.x/2048.0,_container.size.y/1024.0)))
	var cell:=(width-2*inset-4*gap)/5.0;var order:=["left","right","zoom_out","zoom_in","reset"]
	for index in range(order.size()):buttons[order[index]].position=Vector2(inset+index*(cell+gap),button_y);buttons[order[index]].size=Vector2(cell,64)
	instructions.position=Vector2(inset,hint_y);instructions.size=Vector2(width-2*inset,40)
	_update_camera()
static func _hex(value:Variant,bytes:int)->bool:
	if not value is String or value.length()!=bytes*2:return false
	for character:String in value:
		if not "0123456789abcdef".contains(character):return false
	return true
static func _decoded_points(value:String,double_precision:bool)->PackedFloat64Array:
	var raw:=value.hex_decode();var result:=PackedFloat64Array();var stride:=8 if double_precision else 4
	for index in range(9):
		var scalar:=raw.decode_double(index*stride) if double_precision else raw.decode_float(index*stride)
		if not is_finite(scalar):return PackedFloat64Array()
		result.append(scalar)
	return result
static func _packet_points(row:Dictionary)->PackedFloat64Array:
	# The producer/verifier owns native geometry correctness. Presentation
	# checks its explicit success and sealed packet; it never invents a leaf.
	if row.get("geometry_ok")!=true or not row.get("packet") is Dictionary or not row.get("certificate") is Dictionary:return PackedFloat64Array()
	var packet:Dictionary=row.packet;var certificate:Dictionary=row.certificate
	if certificate.get("ok")!=true or not certificate.get("packet_sha256") is String or str(certificate.packet_sha256)!=JSON.stringify(packet,"",true).sha256_text():return PackedFloat64Array()
	var indices:Variant=packet.get("indices")
	if not indices is Array or indices.size()!=3:return PackedFloat64Array()
	for index in range(3):
		if not (indices[index] is int or indices[index] is float) or float(indices[index])!=float(index):return PackedFloat64Array()
	if not _hex(packet.get("local_vertices_f32_hex"),36) or not _hex(packet.get("local_vertices_f64_hex"),72):return PackedFloat64Array()
	if _decoded_points(packet.local_vertices_f64_hex,true).size()!=9:return PackedFloat64Array()
	return _decoded_points(packet.local_vertices_f32_hex,false)
func configure(snapshot:Dictionary)->bool:
	_ensure_built();release_pointers();_clear_geometry();_snapshot={};_snapshot_sha256="";last_error="";triangle_count=0;rejected_volume_count=0
	var volumes:Variant=snapshot.get("volumes")
	if snapshot.get("ok")!=true or not volumes is Array or volumes.is_empty() or volumes.size()>MAX_TRIANGLES:
		last_error="invalid_or_unavailable_geometry_snapshot";_publish_unavailable();return false
	var accepted:Array=[]
	for row:Variant in volumes:
		if not row is Dictionary:last_error="invalid_geometry_volume";_publish_unavailable();return false
		var points:=_packet_points(row)
		if points.size()!=9:rejected_volume_count+=1;continue
		accepted.append({"points":points,"child_index":int(row.get("child_index",accepted.size()))})
	if accepted.is_empty():last_error="no_verified_native_leaf";_publish_unavailable();return false
	# A scalar64 centre and uniform display scale preserve the supplied F32
	# triangles even at planetary coordinates. Only final preview-relative
	# coordinates enter Vector3; the source packets stay unchanged.
	var low:=PackedFloat64Array([INF,INF,INF]);var high:=PackedFloat64Array([-INF,-INF,-INF])
	for leaf:Dictionary in accepted:
		for corner in range(3):
			for axis in range(3):var value:float=leaf.points[corner*3+axis];low[axis]=minf(low[axis],value);high[axis]=maxf(high[axis],value)
	for axis in range(3):_origin_f64[axis]=low[axis]+(high[axis]-low[axis])*0.5
	_display_extent=maxf(high[0]-low[0],maxf(high[1]-low[1],high[2]-low[2]))*0.5
	if not is_finite(_display_extent) or _display_extent<=0:last_error="degenerate_native_geometry";_publish_unavailable();return false
	var vertices:=PackedVector3Array();var face_colours:=PackedColorArray();var line_vertices:=PackedVector3Array();var line_colours:=PackedColorArray();_radius=0.0
	for leaf:Dictionary in accepted:
		var triangle:=PackedVector3Array();var colour:Color=COLOURS[posmod(int(leaf.child_index),COLOURS.size())]
		for corner in range(3):
			var point:=Vector3((float(leaf.points[corner*3])-_origin_f64[0])/_display_extent,(float(leaf.points[corner*3+1])-_origin_f64[1])/_display_extent,(float(leaf.points[corner*3+2])-_origin_f64[2])/_display_extent)
			if not point.is_finite():last_error="nonfinite_preview_projection";_publish_unavailable();return false
			triangle.append(point);_radius=maxf(_radius,point.length())
		if (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).length_squared()==0:last_error="degenerate_preview_triangle";_publish_unavailable();return false
		for point:Vector3 in triangle:vertices.append(point);face_colours.append(colour)
		for edge:Array in [[0,1],[1,2],[2,0]]:
			line_vertices.append(triangle[edge[0]]);line_vertices.append(triangle[edge[1]]);line_colours.append(colour);line_colours.append(colour)
	_display_vertices=vertices.duplicate();_mesh(vertices,face_colours,Mesh.PRIMITIVE_TRIANGLES,true);_mesh(line_vertices,line_colours,Mesh.PRIMITIVE_LINES,false)
	triangle_count=accepted.size();_snapshot=snapshot.duplicate(true);_snapshot_sha256=JSON.stringify(_snapshot,"",true).sha256_text();reset_view()
	status.text="Показано исходных треугольников: %d."%triangle_count
	if rejected_volume_count>0:status.text+=" Недоступно объёмов: %d."%rejected_volume_count
	_update_actions();_update_visibility();return true
func _mesh(vertices:PackedVector3Array,colours:PackedColorArray,primitive:int,fill:bool)->void:
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colours
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(primitive,arrays)
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.vertex_color_use_as_albedo=true;material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.no_depth_test=true
	if fill:material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.albedo_color=Color(1,1,1,0.18);material.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
	var instance:=MeshInstance3D.new();instance.mesh=mesh;instance.material_override=material;instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;_geometry.add_child(instance)
func _clear_geometry()->void:
	_display_vertices=PackedVector3Array()
	if not is_instance_valid(_geometry):return
	for child:Node in _geometry.get_children():_geometry.remove_child(child);child.queue_free()
func _publish_unavailable()->void:
	triangle_count=0;_clear_geometry();_origin_f64=PackedFloat64Array([0,0,0]);_display_extent=1.0;_radius=1.0
	if is_instance_valid(status):status.text="Исходная геометрия в этой точке недоступна."
	_update_actions();_update_visibility()
func _update_actions()->void:
	for button:Button in buttons.values():button.disabled=not input_allowed or triangle_count==0;button.input_allowed=input_allowed
func _update_visibility()->void:
	if is_instance_valid(_container):_container.visible=triangle_count>0
	if is_instance_valid(viewport):viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if triangle_count>0 and is_visible_in_tree() else SubViewport.UPDATE_DISABLED
func reset_view()->void:
	release_pointers();_yaw=INITIAL_YAW;_pitch=INITIAL_PITCH;_zoom=1.0;_update_camera()
func _rotate(delta:Vector2)->void:
	if not input_allowed or triangle_count==0 or not delta.is_finite():return
	_yaw=wrapf(_yaw+delta.x,-PI,PI);_pitch=clampf(_pitch+delta.y,-1.35,1.35);_update_camera()
func _change_zoom(factor:float)->void:
	if not input_allowed or triangle_count==0 or not is_finite(factor) or factor<=0:return
	_zoom=clampf(_zoom*factor,0.5,4.0);_update_camera()
func _update_camera()->void:
	if not is_instance_valid(camera) or not is_instance_valid(plot):return
	var aspect:=maxf(0.01,plot.size.x/maxf(1,plot.size.y));var vertical_half:=deg_to_rad(camera.fov)*0.5;var half_angle:=minf(vertical_half,atan(tan(vertical_half)*aspect))
	_fit_distance=maxf(_radius,1.0)*1.12/sin(half_angle);camera.position=Vector3(0,0,_fit_distance*_zoom);camera.rotation=Vector3.ZERO;camera.far=maxf(128,_fit_distance*8);_rig.rotation=Vector3(_pitch,_yaw,0)
func release_pointers()->void:
	_pointers.clear();_mouse_owned=false;_pinch_distance=0.0
	for button:Button in buttons.values():button.release_pointer()
func _inside_plot(point:Vector2)->bool:
	if not is_instance_valid(plot) or not plot.is_visible_in_tree() or not Rect2(Vector2.ZERO,plot.size).has_point(plot.get_global_transform_with_canvas().affine_inverse()*point):return false
	var ancestor:Node=self
	while ancestor!=null:
		if ancestor is Control and ancestor.clip_contents and not Rect2(Vector2.ZERO,ancestor.size).has_point(ancestor.get_global_transform_with_canvas().affine_inverse()*point):return false
		ancestor=ancestor.get_parent()
	return true
func _local_plot(point:Vector2)->Vector2:return plot.get_global_transform_with_canvas().affine_inverse()*point
func _current_pinch_distance()->float:
	if _pointers.size()!=2:return 0.0
	var points:=_pointers.values();return _local_plot(points[0]).distance_to(_local_plot(points[1]))
func _input(event:InputEvent)->void:
	if not input_allowed or triangle_count==0 or not is_visible_in_tree():release_pointers();return
	if event is InputEventScreenTouch:
		if event.canceled or not event.pressed:
			if _pointers.has(event.index):_pointers.erase(event.index);_pinch_distance=_current_pinch_distance();get_viewport().set_input_as_handled()
		elif not _mouse_owned and _pointers.size()<2 and _inside_plot(event.position):
			_pointers[event.index]=event.position;_pinch_distance=_current_pinch_distance();get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _pointers.has(event.index):
		var previous:Vector2=_pointers[event.index];_pointers[event.index]=event.position
		if _pointers.size()==2:
			var distance:=_current_pinch_distance()
			if distance>0 and _pinch_distance>0:_change_zoom(_pinch_distance/distance)
			_pinch_distance=distance
		else:_rotate((_local_plot(event.position)-_local_plot(previous))*Vector2(0.01,0.01))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.device==-1 or not _pointers.is_empty():return
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed and _inside_plot(event.position):_mouse_owned=true;_mouse_previous=event.position;get_viewport().set_input_as_handled()
			elif not event.pressed and _mouse_owned:_mouse_owned=false;get_viewport().set_input_as_handled()
		elif event.pressed and _inside_plot(event.position) and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:_change_zoom(1.0/1.15 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.15);get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _mouse_owned:
		if event.device==-1:return
		if not event.button_mask&MOUSE_BUTTON_MASK_LEFT:_mouse_owned=false;return
		_rotate((_local_plot(event.position)-_local_plot(_mouse_previous))*Vector2(0.01,0.01));_mouse_previous=event.position;get_viewport().set_input_as_handled()
func view_state()->Dictionary:
	return {"source_contract":CONTRACT,"readonly_preview":true,"flight_camera_or_geometry_changed":false,"triangle_count":triangle_count,"rejected_volume_count":rejected_volume_count,"snapshot_sha256":_snapshot_sha256,"yaw":_yaw,"pitch":_pitch,"zoom":_zoom,"pointer_count":_pointers.size(),"mouse_owned":_mouse_owned,"display_origin_f64":Array(_origin_f64),"display_extent":_display_extent,"camera_distance":camera.position.length() if is_instance_valid(camera) else 0.0,"last_error":last_error}
