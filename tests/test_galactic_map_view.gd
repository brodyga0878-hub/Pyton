extends SceneTree
const View=preload("res://scripts/galactic_map_view.gd")
const Model=preload("res://scripts/galactic_map_model.gd")
const SOL:=0x02a49718
const ALPHA:=0x06a49718
var view:Control
var checks:=0
var failures:=0
var selected:Array=[]
var jumps:Array=[]
var closes:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func frame()->void:await process_frame
func settle()->void:
	var start:=Time.get_ticks_msec()
	while view.loading() and Time.get_ticks_msec()-start<20000:await frame()
	await frame();await frame()
	check(not view.loading(),"Latest isolated map worker completes within its bounded wait")
func input_touch(id:int,point:Vector2,pressed:bool,canceled:=false)->void:
	var e:=InputEventScreenTouch.new();e.index=id;e.position=point;e.pressed=pressed;e.canceled=canceled;root.push_input(e,true)
func input_drag(id:int,point:Vector2)->void:
	var e:=InputEventScreenDrag.new();e.index=id;e.position=point;root.push_input(e,true)
func tap_button(key:String,id:=10)->void:
	var point:Vector2=view.buttons[key].get_global_rect().get_center();input_touch(id,point,true);input_touch(id,point,false);await frame()
func point_for(id:int)->Vector2:
	for marker:Dictionary in view._markers:
		if int(marker.id)==id:return view.get_global_transform_with_canvas()*marker.point
	return Vector2(INF,INF)
func real_selection()->void:
	check(view.buttons.jump.disabled,"Current-system jump begins unavailable")
	var alpha:=point_for(ALPHA)
	check(alpha.is_finite(),"Actual AlphaCentauri source marker is plotted")
	if alpha.is_finite():input_touch(11,alpha,true);input_touch(11,alpha,false);await frame()
	check(view.model.selected_id==ALPHA and selected==[ALPHA] and jumps.is_empty(),"Actual star touch selects a system without silently jumping")
	check(not view.buttons.jump.disabled and view.details.text.contains("4.3"),"Selected native star has true distance and available separate confirmation")
	await tap_button("jump",12)
	check(jumps==[ALPHA],"Only explicit jump button emits the selected system command once")
func pan_and_rotate()->void:
	var center:Vector2=view._center;var selection:int=view.model.selected_id;var selection_count:=selected.size()
	var point:Vector2=view.get_global_transform_with_canvas()*(view._plot.position+view._plot.size*Vector2(0.35,0.35))
	input_touch(13,point,true);input_drag(13,point+Vector2(100,35));input_touch(13,point+Vector2(100,35),false)
	await settle()
	check(view._center.distance_to(center)>0.1 and view.model.selected_id==selection and selected.size()==selection_count,"Dragging really pages the sector view without selecting or jumping")
	var yaw:float=view._yaw;await tap_button("rotate_right",14)
	check(view._yaw!=yaw,"Rotation button changes actual3D map orientation")
	var zoom:float=view._pixels_per_ly;await tap_button("zoom_in",15)
	check(view._pixels_per_ly>zoom,"Zoom changes actual source-sector projection")
	var a:=point+Vector2(-40,0);var b:=point+Vector2(40,0)
	input_touch(21,a,true);input_touch(22,b,true);var before:float=view._pixels_per_ly;input_drag(22,b+Vector2(40,15));input_touch(22,b+Vector2(40,15),false);input_touch(21,a,false)
	check(view._pixels_per_ly>before and selected.size()==selection_count,"Two-finger pinch/twist adjusts the view without accidental star selection")
func named_search_and_coordinates()->void:
	view.search_edit.text="Polaris";await tap_button("search",25);await settle()
	check(not view.model.search_results.is_empty() and view.results.get_child_count()>0,"Actual name field/search button finds a distant original named system")
	var button:Button=view.results.get_child(0);var point:=button.get_global_rect().get_center()
	input_touch(26,point,true);input_touch(26,point,false);await settle()
	check(str(view.model.selected.original_name).contains("Polaris") and jumps==[ALPHA],"Result touch recentres and selects the real distant system without flying there")
	check(view.buttons.jump.disabled,"A distant selected original system cannot bypass engine range")
	view.sector_x.text="-1";view.sector_y.text="76";await tap_button("sector_go",27);await settle()
	check(floori(view._center.x)==5911 and floori(view._center.y)==5488,"Signed sector input reaches original raw coordinates, not the local nine-page limit")
	var center:Vector2=view._center;view.sector_x.text="4294967296";view.sector_y.text="0";await tap_button("sector_go",28)
	check(view._center==center and not view.loading(),"Oversized text coordinates cannot narrow/wrap into a real sector")
func overview()->void:
	view.search_edit.text="";await tap_button("mode",30);await settle()
	check(view._overview and view._overview_texture!=null and view._overview_texture.get_width()==320,"Galaxy mode displays a real source-density image")
	check(view.buttons.rotate_left.disabled and view.buttons.tilt.disabled,"Flat original galaxy overview does not expose fake3D controls")
	var before:int=view._overview_scale;await tap_button("zoom_in",31);await settle()
	check(view._overview_scale<before,"Overview zoom requests source density at the new original scale")
	var point:Vector2=view.get_global_transform_with_canvas()*view._overview_rect.get_center();var id:int=view.model.selected_id
	input_touch(32,point,true);input_touch(32,point,false);await settle()
	check(not view._overview and view.model.selected_id==id,"Overview point opens its source sector without changing navigation selection")
func responsive_and_focus()->void:
	for width in [720,960,1440,2400]:
		view.size=Vector2(width,720);view._layout()
		var previous:Array=[]
		for key in view.buttons:
			var rectangle:Rect2=view.buttons[key].get_rect()
			check(rectangle.size.x>=64 and rectangle.size.y>=64,"Phone map action keeps64px touch region: "+key)
			check(Rect2(Vector2.ZERO,view.size).encloses(rectangle),"Phone map action stays inside viewport: "+key)
			var overlaps:=false
			for other:Rect2 in previous:overlaps=overlaps or rectangle.intersects(other)
			check(not overlaps,"Map action hit regions do not overlap: "+key);previous.append(rectangle)
	view.size=Vector2(1440,720);view._layout()
	var point:Vector2=view.get_global_transform_with_canvas()*view._plot.get_center();input_touch(41,point,true)
	check(view._pointers.has(41),"Real plot owns a finger before lifecycle interruption")
	view._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(view._pointers.is_empty(),"Focus loss releases map pointers")
	input_touch(41,point,false)
	await tap_button("close",42)
	check(closes==1,"Actual close action works after lifecycle cancellation")
func latest_worker_wins()->void:
	view.sector_x.text="0";view.sector_y.text="0";view._goto_sector()
	var original_worker:Thread=view._worker
	for x in range(1,20):view.sector_x.text=str(x);view._goto_sector()
	check(view._worker==original_worker and not view._pending.is_empty(),"Fast map requests retain one worker and only the latest pending request")
	await settle()
	check(floori(view.model.center_sector.x)==5912+19 and floori(view._center.x)==5912+19,"Stale worker result cannot replace the user's latest sector request")
	check(view._pending.is_empty() and view._worker==null,"Completed paging leaves no orphan worker or queue")
func crowded_source_labels()->void:
	check(view.configure_state({"native":true,"current_id":SOL,"selected_id":ALPHA,"jump_range_ly":20.0,"fuel":12,"fuel_capacity":12,"jump_blocked_reason":""}),"Dense label regression configures the actual Sol source neighbourhood")
	await settle()
	for width in [720,1440,2316]:
		view.size=Vector2(width,720);view._layout()
		for projection:Array in [[24.0,0.0,0.60],[4.0,0.0,0.60],[24.0,1.2,0.85]]:
			view._pixels_per_ly=projection[0];view._yaw=projection[1];view._tilt=projection[2]
			view.queue_redraw();await frame();await frame()
			check(view._markers.size()>20,"Dense native neighbourhood retains its real source markers")
			var labelled:Dictionary={}
			for label:Dictionary in view.last_label_rects:
				check(view._plot.encloses(label.rect),"Complete real-font source label stays inside plot")
				for previous:Dictionary in labelled.values():check(not label.rect.intersects(previous.rect),"Actual source labels do not overlap in dense/rotated/phone views")
				labelled[label.id]=label
			check(labelled.has(SOL) and labelled.has(ALPHA),"Ship and selected system keep label priority in a crowded native sector")
			for marker:Dictionary in view._markers:
				var row:Dictionary=view.model.galaxy.get_system(int(marker.id))
				check(marker.point.distance_to(view._projection(row.position_ly).point)<0.001,"Label spacing preserves the exact real selectable marker position")
			if projection[0]==4.0:check(view.last_label_rects.size()<view._markers.size(),"At dense overview scale some minor names are omitted while every source marker remains")
	view._pixels_per_ly=24;view._yaw=0;view._tilt=0.60;view.size=Vector2(1440,720);view._layout()
func run()->void:
	root.size=Vector2i(1440,720);view=View.new();view.size=Vector2(1440,720);root.add_child(view)
	view.system_selected.connect(func(id:int):selected.append(id));view.jump_requested.connect(func(id:int):jumps.append(id));view.close_requested.connect(func():closes+=1)
	check(view.configure_state({"native":true,"current_id":SOL,"selected_id":SOL,"jump_range_ly":12.0,"fuel":12,"fuel_capacity":12,"jump_blocked_reason":""}),"Actual map configures through snapshot API")
	await settle();await real_selection();await pan_and_rotate();await named_search_and_coordinates();await overview();await latest_worker_wins();await responsive_and_focus();await crowded_source_labels()
	view.queue_free();await frame()
	print("GALACTIC MAP VIEW TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
