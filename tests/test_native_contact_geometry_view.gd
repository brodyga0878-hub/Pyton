extends SceneTree
# Presentation fixtures are explicitly synthetic. Native frame/leaf validity
# is independently proved by the producer suites; no test mock is an oracle.
const View=preload("res://scripts/native_contact_geometry_view.gd")
const REPORT:="res://build/current-test-reports/native-contact-geometry-view.json"
var checks:=0
var failures:=0
var evidence:Array=[]
var view:Control
var flight_world:Node3D
var flight_camera:Camera3D
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func frame()->void:await process_frame;await process_frame;await process_frame
func encoded(values:Array,double_precision:bool)->String:
	var stride:=8 if double_precision else 4;var raw:=PackedByteArray();raw.resize(values.size()*stride)
	for index in range(values.size()):
		if double_precision:raw.encode_double(index*stride,float(values[index]))
		else:raw.encode_float(index*stride,float(values[index]))
	return raw.hex_encode()
func fixture(shift:=0.0,child:=0)->Dictionary:
	var exact:=[100000000.125+shift,20000000.125,-40000000.125,100000032.125+shift,20000008.125,-40000000.125,100000000.125+shift,20000016.125,-39999968.125]
	var packet:Dictionary=JSON.parse_string(JSON.stringify({"local_vertices_f32_hex":encoded(exact,false),"local_vertices_f64_hex":encoded(exact,true),"indices":[0,1,2],"fixture_only":"synthetic presentation leaf; not a native proof"}))
	return {"ok":true,"volumes":[{"child_index":child,"geometry_ok":true,"geometry_reason":"synthetic_ui_fixture","packet":packet,"certificate":{"ok":true,"packet_sha256":JSON.stringify(packet,"",true).sha256_text()}}]}
func touch(index:int,point:Vector2,pressed:=true,canceled:=false)->void:
	var event:=InputEventScreenTouch.new();event.index=index;event.position=point;event.pressed=pressed;event.canceled=canceled;root.push_input(event,true)
func drag(index:int,point:Vector2)->void:
	var event:=InputEventScreenDrag.new();event.index=index;event.position=point;root.push_input(event,true)
func tap(button:Button,index:int)->void:
	var point:=button.get_global_rect().get_center();touch(index,point);touch(index,point,false)
func state_without_orientation()->PackedByteArray:
	return var_to_bytes([flight_world.transform,flight_camera.transform,flight_camera.current,root.world_3d,view._snapshot,view._snapshot_sha256,view._display_vertices])
func rendering_and_copy_contract()->void:
	var snapshot:=fixture();var bytes:=var_to_bytes(snapshot)
	check(view.configure(snapshot),"A typed, bound presentation fixture configures the isolated inspector")
	await frame()
	check(var_to_bytes(snapshot)==bytes and view._snapshot==snapshot,"Configuring copies the packet and cannot edit its owner")
	check(view.viewport.world_3d!=root.world_3d and view.camera!=flight_camera and flight_camera.current,"The preview owns a distinct 3D world and camera while the flight camera remains current")
	check(view.triangle_count==1 and view._geometry.get_child_count()==2 and view._display_vertices.size()==3,"One actual supplied triangle produces its fill and matching edge mesh")
	var points:PackedFloat64Array=View._decoded_points(snapshot.volumes[0].packet.local_vertices_f32_hex,false)
	for corner in range(3):
		for axis in range(3):
			var expected:=float((points[corner*3+axis]-view._origin_f64[axis])/view._display_extent)
			var f32:=PackedByteArray();f32.resize(4);f32.encode_float(0,expected)
			check(view._display_vertices[corner][axis]==f32.decode_float(0),"Display vertices retain exact supplied F32 shape after scalar64 centring: "+str(corner)+"/"+str(axis))
	check(view._origin_f64[0]>99999999 and view._display_extent<100 and view.camera.position.is_finite(),"Planetary coordinates are centred before Vector3 conversion and camera placement stays finite")
	var before:=state_without_orientation();snapshot.volumes[0].packet.local_vertices_f32_hex="CALLER MUTATION";snapshot.volumes.clear()
	check(state_without_orientation()==before and view._snapshot.volumes.size()==1,"Later owner mutations cannot change the retained packet or rendered vertices")
	check(view.title.text=="Исходная геометрия контакта" and view.status.text.contains("треугольников: 1") and view.instructions.text.contains("два пальца"),"Only human-readable Russian inspection guidance appears in the product")
	evidence.append({"case":"isolated_world_and_copied_F32_geometry","state":view.view_state(),"synthetic_fixture_not_native_proof":true})
func responsive_layout()->void:
	for dimensions:Vector2 in [Vector2(1440,720),Vector2(1080,720),Vector2(720,360),Vector2(360,350)]:
		view.size=dimensions;view._layout();await frame();var bounds:=Rect2(Vector2.ZERO,view.size);var controls:Array[Rect2]=[]
		for key:String in view.buttons:
			var rect:Rect2=view.buttons[key].get_rect()
			check(rect.size.x>=64 and rect.size.y>=64 and bounds.encloses(rect),"Inspector actions keep64px touch areas inside "+str(dimensions)+": "+key)
			for other:Rect2 in controls:check(not rect.intersects(other),"Inspector touch actions do not overlap: "+str(dimensions))
			controls.append(rect)
		check(bounds.encloses(view.plot.get_rect()) and bounds.encloses(view.title.get_rect()) and bounds.encloses(view.instructions.get_rect()),"Plot, title and guidance fit the current phone column: "+str(dimensions))
		check(view.plot.size.y>=128 and view.viewport.size.x<=2048 and view.viewport.size.y<=1024,"Plot remains usable and viewport allocation is bounded: "+str(dimensions))
		for point:Vector3 in view._display_vertices:
			var where:Vector2=view.camera.unproject_position(point)
			check(where.is_finite() and Rect2(Vector2.ZERO,Vector2(view.viewport.size)).has_point(where),"The fitted native triangle remains inside its own camera at "+str(dimensions))
	view.size=Vector2(720,360);view._layout();await frame()
func gesture_and_action_contract()->void:
	var before:=state_without_orientation();var original:Dictionary=view.view_state();var point:Vector2=view.plot.get_global_rect().get_center()
	touch(11,point);drag(11,point+Vector2(45,20));touch(11,point+Vector2(45,20),false)
	check(view._yaw!=original.yaw and view._pitch!=original.pitch and view._pointers.is_empty(),"A real finger drag rotates only the preview and releases its pointer")
	check(state_without_orientation()==before,"Dragging cannot mutate source snapshot, geometry, flight world or flight camera")
	var zoom:float=view._zoom;var yaw:float=view._yaw;var pitch:float=view._pitch
	touch(12,point-Vector2(30,0));touch(13,point+Vector2(30,0));drag(13,point+Vector2(65,0));touch(12,point-Vector2(30,0),false);touch(13,point+Vector2(65,0),false)
	check(view._zoom<zoom and view._yaw==yaw and view._pitch==pitch,"An actual two-finger pinch changes scale without rotating or moving flight")
	tap(view.buttons.right,14);check(view._yaw!=yaw,"An actual touch on the rotate action changes the preview orientation")
	var state:Dictionary=view.view_state();tap(view.buttons.zoom_out,15);check(view._zoom>float(state.zoom),"An actual touch on the zoom action changes only the preview scale")
	tap(view.buttons.reset,16)
	check(view._yaw==View.INITIAL_YAW and view._pitch==View.INITIAL_PITCH and view._zoom==1.0 and view._pointers.is_empty(),"Reset fits the captured geometry and clears gesture ownership")
	check(state_without_orientation()==before,"All real inspection gestures leave the caller and flight scene unchanged")
	view._change_zoom(1.0e100);check(view._zoom==4.0 and view.camera.position.is_finite(),"Extreme zoom-out remains finite and bounded")
	view._change_zoom(1.0e-100);check(view._zoom==0.5 and view.camera.position.is_finite(),"Extreme zoom-in remains finite and bounded")
	view.reset_view();evidence.append({"case":"actual_touch_orbit_pinch_and_buttons","state":view.view_state(),"flight_unchanged":state_without_orientation()==before})
func blocked_and_lifecycle()->void:
	var point:Vector2=view.plot.get_global_rect().get_center();touch(21,point);view.input_allowed=false
	check(view._pointers.is_empty() and view.buttons.reset.disabled,"Blocking input releases current gestures and disables actions")
	var angle:float=view._yaw;drag(21,point+Vector2(40,0));touch(21,point,false);check(view._yaw==angle,"Blocked and later released input cannot replay a held gesture")
	view.input_allowed=true;touch(22,point);view.hide();check(view._pointers.is_empty() and view.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Hiding releases gestures and stops the isolated render target")
	view.show();touch(22,point,false)
	for notification:int in [Node.NOTIFICATION_APPLICATION_FOCUS_OUT,Node.NOTIFICATION_APPLICATION_PAUSED,Node.NOTIFICATION_PAUSED]:
		touch(23,point);view.notification(notification);check(view._pointers.is_empty(),"Focus/application pause releases preview pointer ownership")
		touch(23,point,false)
	var variations:Array=[];var data:=fixture();data.volumes[0].geometry_ok=false;data.volumes[0].geometry_reason="antiparallel_axis_frame";variations.append(data)
	data=fixture();data.volumes[0].certificate.ok=false;variations.append(data)
	data=fixture();data.volumes[0].packet.indices=[2,1,0];variations.append(data)
	data=fixture();data.volumes[0].packet.local_vertices_f32_hex="a";variations.append(data)
	data=fixture();data.volumes[0].packet.local_vertices_f32_hex="z".repeat(72);variations.append(data)
	data=fixture();data.volumes[0].packet.local_vertices_f32_hex=encoded([NAN,0,0,1,0,0,0,1,0],false);data.volumes[0].certificate.packet_sha256=JSON.stringify(data.volumes[0].packet,"",true).sha256_text();variations.append(data)
	data=fixture();data.volumes[0].packet.local_vertices_f32_hex=encoded([1,1,1,1,1,1,1,1,1],false);data.volumes[0].certificate.packet_sha256=JSON.stringify(data.volumes[0].packet,"",true).sha256_text();variations.append(data)
	data=fixture();data.volumes[0].packet.local_vertices_f64_hex=encoded([INF,0,0,1,0,0,0,1,0],true);data.volumes[0].certificate.packet_sha256=JSON.stringify(data.volumes[0].packet,"",true).sha256_text();variations.append(data)
	data=fixture();data.volumes.append_array(data.volumes.duplicate(true));data.volumes.append_array(data.volumes.duplicate(true));variations.append(data)
	variations.append({"ok":false,"volumes":[]});variations.append({"ok":true,"volumes":[12]})
	for index in range(variations.size()):
		var source:=var_to_bytes(variations[index]);check(not view.configure(variations[index]),"Unavailable, malformed, stale or unbound packets are rejected: "+str(index))
		check(view.triangle_count==0 and view._display_vertices.is_empty() and not view._container.visible and view.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"A blocked packet never displays stale or fabricated geometry: "+str(index))
		check(var_to_bytes(variations[index])==source and view.status.text.contains("недоступна"),"Failure preserves its caller and displays a Russian unavailable state: "+str(index))
	data=fixture();data.volumes.append({"child_index":1,"geometry_ok":false,"geometry_reason":"outside_query_scope"})
	check(view.configure(data) and view.triangle_count==1 and view.rejected_volume_count==1 and view.status.text.contains("Недоступно объёмов: 1"),"A mixed snapshot displays only proved supplied geometry and labels its unavailable volume")
	data=fixture();data.volumes.append(fixture(64,1).volumes[0]);data.volumes.append(fixture(-64,2).volumes[0])
	check(view.configure(data) and view.triangle_count==3 and view._display_vertices.size()==9,"All three bounded original volume packets can be inspected together")
	await frame();check(flight_camera.current and view.viewport.world_3d!=root.world_3d,"Reconfiguration and blocked states never take flight camera or world ownership")
	evidence.append({"case":"blocked_pole_and_packet_lifecycle","rejected_fixtures":variations.size(),"state":view.view_state()})
func run()->void:
	root.size=Vector2i(1440,720);flight_world=Node3D.new();root.add_child(flight_world);flight_camera=Camera3D.new();flight_world.add_child(flight_camera);flight_camera.position=Vector3(10,20,30);flight_camera.current=true
	view=View.new();view.position=Vector2(0,0);view.size=Vector2(1440,720);root.add_child(view);await frame()
	await rendering_and_copy_contract();await responsive_layout();gesture_and_action_contract();await blocked_and_lifecycle()
	var sources:Dictionary={}
	for path:String in ["scripts/native_contact_geometry_view.gd","scripts/touch_action_button.gd","tests/test_native_contact_geometry_view.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE);file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"source_contract":View.CONTRACT,"sources":sources,"evidence":evidence,"scope":"Isolated read-only SubViewport presentation with synthetic explicitly labelled bound packet fixtures. Actual pointer/pinch/action input, responsive layout, scalar64 centring of supplied F32 geometry, camera fitting, source/flight ownership, rejected stale/nonfinite/blocked packets and lifecycle cleanup. This UI suite does not prove native geometry correctness, source/render mesh parity, physical Android, FPS or changed flight physics."},"\t"));file.close()
	view.queue_free();flight_world.queue_free();await frame();print("NATIVE CONTACT GEOMETRY VIEW TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
