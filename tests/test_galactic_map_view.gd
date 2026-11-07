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
func presentation_contract()->void:
	check(view.get_meta("presentation_profile","")=="navy-star-chart-v1","Actual map publishes its display-only presentation profile")
	check(view.search_edit.is_inside_tree() and view.search_edit.is_visible_in_tree(),"Modern search field remains a live input control")
	check(view.selected_name.text=="Альфа Центавра" and view.distance_value.text=="4.35","Selected card shows the actual source Alpha Centauri and distance")
	check(view.details.text.contains("4.35") and view.selection_facts.text.contains("12 / 12"),"Public description and visible card retain the real route facts")
	for control:Control in [view.title,view.selected_name,view.distance_value,view.selection_facts,view.buttons.jump,view.search_edit]:
		check(control.get_theme_constant("outline_size")==0 and control.get_theme_color("font_shadow_color").a==0,"Modern typography clears inherited flight-console outline and shadow")
	var native_pixels:PackedByteArray=view.model.overview_pixels(52);var original:=native_pixels.duplicate()
	var display:PackedByteArray=View.display_overview_pixels(native_pixels)
	check(native_pixels==original,"Display colour transfer never edits the original FFE overview bytes")
	check(display.size()==320*158*4 and display!=native_pixels,"Display retains every original pixel on the same320x158 overview grid")
	var same_alpha:=true
	for at in range(3,native_pixels.size(),4):same_alpha=same_alpha and display[at]==native_pixels[at]
	check(same_alpha,"Overview presentation preserves original alpha and pixel ordering")
	var ramp:=PackedByteArray([0,0,0,255,64,64,64,255,128,128,128,255,192,192,192,255,255,255,255,255])
	var transferred:PackedByteArray=View.display_overview_pixels(ramp);var brightness:=-1
	for at in range(0,transferred.size(),4):
		var next:int=int(transferred[at])+int(transferred[at+1])+int(transferred[at+2])
		check(next>brightness,"Display transfer preserves the order of original density intensities");brightness=next
	check(transferred[2]>transferred[0] and int(transferred[16])+int(transferred[17])+int(transferred[18])>650,"Dark overview space blends into navy while dense source core remains bright")
	for dimensions in [Vector2(720,540),Vector2(960,540),Vector2(960,650),Vector2(960,674),Vector2(960,680),Vector2(1440,720),Vector2(2316,1080)]:
		view.size=dimensions;view._layout()
		for control:Control in [view.selected_name,view.selected_sector,view.distance_value,view.distance_unit,view.selection_facts,view.selection_state,view.buttons.jump]:
			check(view._selection_card.encloses(control.get_rect()),"Selected-system card retains real facts and CTA inside its panel across phone sizes")
		for control:Control in [view.selected_name,view.distance_value,view.selection_facts,view.selection_state]:
			check(not control.get_rect().intersects(view.buttons.jump.get_rect()),"Route facts stay clear of the actual jump touch region on short screens")
		check(view.selection_facts.text.contains("12") and view.selection_facts.text.contains("2"),"Compact route card retains fuel supply and true fuel requirement")
		var previous:Rect2=view.sector_x.get_rect()
		for control:Control in [view.sector_y,view.buttons.sector_go,view.buttons.reset,view.status]:
			check(not previous.intersects(control.get_rect()),"Actual minimum-width coordinate editors and footer actions do not overlap");previous=control.get_rect()
	view.size=Vector2(1440,720);view._layout()
func search_route_facts()->void:
	view.search_edit.text="Alpha Centauri";view._search();await settle()
	view.size=Vector2(720,540);view._layout();await frame()
	check(not view.model.search_results.is_empty() and view.result_scroll.visible,"Actual source Alpha Centauri search opens its results")
	check(view.selection_facts.visible and view.selection_state.visible and not view.buttons.jump.disabled,"Searching retains visible facts and availability for an actual reachable source destination")
	check(not view.result_scroll.get_rect().intersects(view._plot),"Search results stay outside the chart's navigation touch region")
	var first:Button=view.results.get_child(0)
	check(view.result_scroll.get_global_rect().intersection(first.get_global_rect()).size.y>=64,"First source search result retains a complete64px visible touch region")
	var count_before:=jumps.size()
	view.search_edit.text="Polaris";view._search();await settle()
	first=view.results.get_child(0);var point:=first.get_global_rect().get_center()
	input_touch(58,point,true);input_touch(58,point,false);await settle()
	check(str(view.model.selected.original_name).contains("Polaris") and jumps.size()==count_before,"Actual distant search-result touch selects without jumping")
	var state:Dictionary=view.model.jump_state()
	check(not state.reachable and view.buttons.jump.disabled,"Distant source search target remains unreachable under actual engine range")
	check(view.selection_facts.visible and view.selection_state.visible and view.selection_state.text==state.reason,"Searching retains actual fuel/cost and the full unavailable reason")
	check(view.selection_state.get_visible_line_count()>=view.selection_state.get_line_count(),"Narrow short card displays every line of the actual unavailable reason: visible=%d total=%d height=%.1f line=%d spacing=%d text=%s"%[view.selection_state.get_visible_line_count(),view.selection_state.get_line_count(),view.selection_state.size.y,view.selection_state.get_line_height(),view.selection_state.get_theme_constant("line_spacing"),view.selection_state.text])
	check(not view.selection_state.get_rect().intersects(view.buttons.jump.get_rect()),"Unavailable reason never overlaps the jump action")
	for height in [540,650,674,680,720]:
		view.size=Vector2(720,height);view._layout();await frame()
		check(view.selection_facts.get_visible_line_count()>=view.selection_facts.get_line_count(),"Actual source route fuel/cost text remains completely visible through the compact-layout breakpoint")
		check(view.selection_state.get_visible_line_count()>=view.selection_state.get_line_count(),"Actual far-source disabled reason remains completely visible through the compact-layout breakpoint")
		check(not view.selection_facts.get_rect().intersects(view.selection_state.get_rect()) and not view.selection_state.get_rect().intersects(view.buttons.jump.get_rect()),"Actual route facts, disabled reason and jump touch target remain separated at phone heights")
	view.size=Vector2(1440,720);view._layout()
func run()->void:
	root.size=Vector2i(1440,720);view=View.new();view.size=Vector2(1440,720);root.add_child(view)
	view.system_selected.connect(func(id:int):selected.append(id));view.jump_requested.connect(func(id:int):jumps.append(id));view.close_requested.connect(func():closes+=1)
	check(view.configure_state({"native":true,"current_id":SOL,"selected_id":SOL,"jump_range_ly":12.0,"fuel":12,"fuel_capacity":12,"jump_blocked_reason":""}),"Actual map configures through snapshot API")
	await settle();await real_selection();await pan_and_rotate();await named_search_and_coordinates();await overview();await latest_worker_wins();await responsive_and_focus();await crowded_source_labels();presentation_contract();await search_route_facts()
	view.queue_free();await frame()
	print("GALACTIC MAP VIEW TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
