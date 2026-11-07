extends SceneTree
const Map=preload("res://scripts/system_map_model.gd")
const View=preload("res://scripts/system_map_view.gd")
const World=preload("res://scripts/planetary_system.gd")
const Nav=preload("res://scripts/navigation.gd")
var checks:=0
var failures:=0
var world:RefCounted
var nav:RefCounted
var state:Dictionary
var before_world:PackedByteArray
var before_nav:PackedByteArray
var events:Array=[]

func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func distance(a:Variant,b:Variant)->float:
	if a.size()!=3 or b.size()!=3:return INF
	return sqrt(pow(float(a[0])-float(b[0]),2)+pow(float(a[1])-float(b[1]),2)+pow(float(a[2])-float(b[2]),2))
func setup()->void:
	nav=Nav.new();check(nav.configure_native(),"Independent native navigation initializes for system-map consumer")
	world=World.new();world.configure(nav.current(),World.FULL_LAYOUT)
	nav.elapsed_days=3.75;world.body_rotation_state("earth",nav.elapsed_days)
	state={"star":nav.current(),"world":world.snapshot(),"elapsed_days":nav.elapsed_days,"system_name":"Солнце"}
	before_world=var_to_bytes(world.snapshot());before_nav=var_to_bytes(nav.snapshot())
func model_controls()->void:
	var map:=Map.new();var input:=var_to_bytes(state)
	check(map.configure(state),"Actual original Sol/world snapshot configures a private map world")
	check(var_to_bytes(state)==input,"Configuration does not edit supplied source state")
	check(map.rows.size()==world.bodies.size()+world.settlements.size() and map.rows.size()<=128,"Map retains every actual source body and port within the source record bound")
	check(map.hierarchy().size()==map.rows.size(),"Source hierarchy contains every body/port exactly once")
	var seen:Dictionary={}
	for row:Dictionary in map.hierarchy():
		check(str(row.parent).is_empty() or seen.has(str(row.parent)),"Hierarchy orders parent before child "+str(row.id));seen[str(row.id)]=true
	for id in ["earth","moon","mars","jupiter"]:
		check(distance(map.position_au(id),world.position_au(id,nav.elapsed_days))<1e-13,"Current source position matches gameplay ephemeris for "+id)
	var passes:=0
	while map.preparation_remaining()>0 and passes<128:
		check(map.prepare_geometry(3)<=3,"Geometry preparation obeys its per-call item budget");passes+=1
	check(map.preparation_remaining()==0,"Bounded preparation completes the actual source system")
	check(map.orbit_curves.has("earth") and map.orbit_curves.has("moon"),"Real parent-relative source orbital curves are available")
	for id in map.orbit_curves:
		var curve:Array=map.orbit_curves[id]
		check(curve.size()==65 and distance(curve[0],curve[-1])<1e-14,"Source phase curve closes after one complete original phase turn: "+str(id))
	var moon_before:=map.position_au("moon")
	check(map.set_time_offset(7),"Seven-day map-only forecast is accepted")
	check(distance(moon_before,map.position_au("moon"))>1e-10,"Actual Moon position changes with forecast time")
	for id in ["earth","moon","mars"]:
		check(distance(map.position_au(id),world.position_au(id,nav.elapsed_days+7))<1e-13,"Future map position remains the actual source ephemeris for "+id)
	check(map.set_time_offset(-2) and map.set_time_offset(0),"Preview can go backwards and return to current time")
	check(distance(moon_before,map.position_au("moon"))<1e-13,"Returning from forecasts exactly restores the current source position")
	var saved:=map.source_snapshot();saved.focus_id="bad"
	check(map.source_snapshot().focus_id==state.world.focus_id,"Returned source snapshot is isolated from caller edits")
	var old:=var_to_bytes(map.positions)
	check(not map.set_time_offset(NAN) and not map.set_time_offset(INF) and var_to_bytes(map.positions)==old,"Invalid map dates reject without corrupting positions")
	var invalid:=state.duplicate(true);invalid.world.source_digest="0".repeat(64)
	check(not map.configure(invalid) and map.system_name=="Солнце" and var_to_bytes(map.positions)==old,"Invalid source snapshot cannot replace the valid map")
	check(map.select("moon") and map.set_focus("moon") and map.focus_id=="moon","Map supports body selection and independent recentering")
	check(map.ancestors("moon").has("earth") and map.ancestors("moon").has("star"),"Actual Moon parent chain is preserved")
	var ground:Dictionary={};var orbital:Dictionary={}
	for row:Dictionary in map.rows:
		if row.is_site and row.ground and str(row.parent)=="earth":ground=row
		elif row.is_site and not row.ground:orbital=row
	check(not ground.is_empty() and not orbital.is_empty(),"Original Sol includes ground and orbital ports for map controls")
	if not ground.is_empty():
		check(map.select(str(ground.id)) and map.selected_travel()=={"body_id":"earth","site_id":str(ground.id)},"Ground port selection retains its actual parent and port ID")
		check(not map.position_au(str(ground.id)).is_empty(),"Source F879 prepares the actual ground-site location")
		var reference:=map.ground_target_reference(str(ground.id))
		check(reference.get("body_id")=="earth" and reference.get("system_id")==World.SOL_ID and reference.get("body_fixed_m") is Vector3,"Prepared ground target exposes a lightweight immutable body-fixed reference")
		check(str(reference.get("site_record_sha256","")).length()==64 and str(reference.get("body_record_sha256","")).length()==64 and reference.get("profile")=="system-map-source-f879-root-v1","Ground reference identifies its actual system, records and source-placement profile")
		var original_fixed:Vector3=reference.body_fixed_m;reference.body_fixed_m=Vector3.ZERO;reference.body_fixed_metres_double[0]=0.0
		check(map.ground_target_reference(str(ground.id)).body_fixed_m==original_fixed,"Returned target reference cannot edit the private source placement")
		check(map.ground_target_reference("missing").is_empty() and map.ground_target_reference("earth").is_empty(),"No fictitious ground reference is returned for unknown IDs or natural bodies")
		var separation:=map.distance_au("earth",str(ground.id))*Map.AU_METRES
		check(separation>1000 and separation<2e8,"Ground port is located at its surface displacement, not invented at the body centre")
	if not orbital.is_empty():check(distance(map.position_au(str(orbital.id)),world.site_position_au(str(orbital.id),nav.elapsed_days))<1e-13,"Orbital port position is its real source centre")
	check(map.select("star") and map.selected_travel().is_empty(),"Map cannot request an unsupported direct stellar transfer")
	check(not map.select("missing") and map.selected_id=="star","Unknown selection cannot create a fake body")
	check(var_to_bytes(world.snapshot())==before_world and var_to_bytes(nav.snapshot())==before_nav,"Map preparation/forecasts/selection do not mutate live spin, world snapshot or navigation time")
	# Actual binary and generated systems exercise hierarchy/ephemerides beyond
	# the fixed Sol layout, without constructing a second invented catalogue.
	var star_cases:Array=[nav.galaxy.get_system(111449880)]
	for star:Dictionary in nav.galaxy.sector_page(6000,5400):
		var candidate:=World.new();candidate.configure(star,World.FULL_LAYOUT)
		if candidate.layout_mode==World.FULL_LAYOUT:star_cases.append(star);break
	check(star_cases.size()==2,"A real binary and remote procedural system are available")
	for star:Dictionary in star_cases:
		var original:=World.new();original.configure(star,World.FULL_LAYOUT)
		var saved_world:Dictionary=original.snapshot();var saved_bytes:=var_to_bytes(saved_world)
		var other:=Map.new()
		check(other.configure({"star":star,"world":saved_world,"elapsed_days":21.125}),"Actual non-Sol source system configures a private map")
		check(other.hierarchy().size()==original.bodies.size()+original.settlements.size(),"Binary/procedural hierarchy retains every original record")
		check(other.set_time_offset(365.25),"Non-Sol source forecast accepts a year-scale offset")
		for body:Dictionary in original.bodies:check(distance(other.position_au(str(body.id)),original.position_au(str(body.id),386.375))<1e-12,"Non-Sol source position is exact: "+str(body.id))
		check(var_to_bytes(saved_world)==saved_bytes,"Non-Sol map preserves its supplied world snapshot")
	var old_world:=World.new();old_world.configure(nav.current(),World.SOLAR_LAYOUT)
	var old_bytes:=var_to_bytes(old_world.snapshot());var old_map:=Map.new()
	check(old_map.configure({"star":nav.current(),"world":old_world.snapshot(),"elapsed_days":2.5}),"Legacy analytic Solar save remains a supported map source")
	check(old_map.set_time_offset(4) and distance(old_map.position_au("moon"),old_world.position_au("moon",6.5))<1e-12,"Legacy preview retains its own analytic ephemeris instead of silently upgrading")
	check(var_to_bytes(old_world.snapshot())==old_bytes,"Legacy forecast preserves the original save payload")

func tap(button:Button,index:int)->void:
	var event:=InputEventScreenTouch.new();event.index=index;event.position=button.get_global_rect().get_center();event.pressed=true;button._input(event)
	event.pressed=false;button._input(event)
func touch(index:int,point:Vector2,pressed:bool)->void:
	var event:=InputEventScreenTouch.new();event.index=index;event.position=point;event.pressed=pressed;root.push_input(event,true)
func drag(index:int,point:Vector2)->void:
	var event:=InputEventScreenDrag.new();event.index=index;event.position=point;root.push_input(event,true)
func ui_controls()->void:
	root.size=Vector2i(1440,720)
	var view:=View.new();check(view.configure(state),"View can configure before entering the scene tree")
	root.add_child(view);view.size=Vector2(1440,720);view.set_process(false)
	await process_frame;view._layout()
	while view.model.preparation_remaining()>0:view.model.prepare_geometry(3)
	view.body_selected.connect(func(id:String):events.append(["body",id]))
	view.site_selected.connect(func(id:String):events.append(["site",id]))
	view.travel_requested.connect(func(body:String,site:String):events.append(["travel",body,site]))
	view.close_requested.connect(func():events.append(["close"]))
	check(view.body_buttons.size()==view.model.rows.size(),"Actual hierarchy buttons exist after pre-tree configuration")
	for width in [720,960,1440,2400]:
		view.size=Vector2(width,720);view._layout()
		var rectangles:Array[Rect2]=[]
		for id in view.buttons:
			var rect:Rect2=view.buttons[id].get_rect()
			check(rect.size.x>=64 and rect.size.y>=64 and Rect2(Vector2.ZERO,view.size).encloses(rect),"Phone action fits and retains64px target at%d: %s"%[width,id])
			var overlap:=false
			for previous in rectangles:overlap=overlap or previous.intersects(rect)
			check(not overlap,"Map command targets do not overlap at%d: %s"%[width,id]);rectangles.append(rect)
	view.size=Vector2(720,440);view._layout()
	check(view.tree_scroll.get_rect().end.y<view.time_label.position.y and view.tree_scroll.size.y>=64,"Minimum-height hierarchy stays above the calendar with a full touch row")
	check(Rect2(Vector2.ZERO,view.size).encloses(view.plot.get_rect()),"Plot remains inside the supported minimum-height window")
	view.size=Vector2(1440,720);view._layout();view._select("earth")
	check(events[-1]==["body","earth"] and not events.any(func(e):return e[0]=="travel"),"Selecting a body emits selection without starting travel")
	var before:=var_to_bytes(state)
	tap(view.buttons.travel,41)
	check(events[-1]==["travel","earth",""] and var_to_bytes(state)==before,"Only explicit travel touch emits actual body/port IDs")
	tap(view.buttons.later,42)
	check(view.model.preview_offset_days==1 and view.time_label.text.begins_with("ПРОГНОЗ"),"Actual forecast command changes only the displayed map date")
	tap(view.buttons.now,43)
	check(view.model.preview_offset_days==0 and view.buttons.now.disabled,"Actual current-time command restores the live date view")
	for row:Dictionary in view.model.rows:
		if row.is_site and row.ground and str(row.parent)=="earth":
			view._select(str(row.id));tap(view.buttons.center,44)
			check(view.project(view.model.position_au(str(row.id))).distance_to(view.plot.size*0.5)<0.25,"Centering a real ground port makes its exact surface location visible")
			break
	view.model.set_focus("earth");view.fit_view();view.show_ports=false;view._redraw();await process_frame
	var moon_screen:Vector2=view.project(view.model.position_au("moon"))
	var before_screen:=moon_screen;view.zoom_at(2,moon_screen)
	check(view.project(view.model.position_au("moon")).distance_to(before_screen)<0.2,"Zoom remains centred on the actual point beneath the cursor")
	view.fit_view();view._redraw();await process_frame
	check(not view._plot_hits.is_empty(),"The real plot builds selectable source-object hit locations")
	moon_screen=view.project(view.model.position_au("moon"))
	var moon_global:Vector2=view.plot.get_global_transform_with_canvas()*moon_screen
	touch(51,moon_global,true);touch(51,moon_global,false)
	check(view.model.selected_id=="moon" and events[-1]==["body","moon"],"Actual viewport touch selects the projected moving Moon")
	var pan_before:Vector2=view.pan;var point:Vector2=view.plot.get_global_rect().get_center()
	touch(52,point,true);drag(52,point+Vector2(70,40));touch(52,point+Vector2(70,40),false)
	check(view.pan.distance_to(pan_before)>50 and view.model.selected_id=="moon","Actual drag pans the map without selecting a new object")
	var scale_before:float=view.pixels_per_au
	touch(53,point-Vector2(50,0),true);touch(54,point+Vector2(50,0),true);drag(54,point+Vector2(100,0))
	check(view.pixels_per_au>scale_before,"Two actual independent fingers pinch-zoom the map")
	view.release_pointers()
	check(view.plot._pointers.is_empty(),"Modal/focus cleanup releases every map gesture")
	touch(53,point-Vector2(50,0),false);touch(54,point+Vector2(100,0),false)
	tap(view.buttons.close,55)
	check(events[-1]==["close"],"Actual close command emits the modal close signal")
	view.set_feedback("Сначала вылетите со станции.")
	check(view.feedback.text=="Сначала вылетите со станции." and view.model.selected_id=="moon","Authoritative Main rejection can be displayed without reconfiguring the map")
	var before_events:=events.size()
	touch(56,point,true);view.input_allowed=false;drag(56,point+Vector2(50,50));touch(56,point,false);tap(view.buttons.travel,57)
	check(view.plot._pointers.is_empty() and events.size()==before_events,"Focus/input blocking cancels map gestures and rejects new command fingers")
	view.input_allowed=true;tap(view.buttons.travel,58)
	check(events.size()==before_events+1 and events[-1]==["travel","moon",""],"Fresh command after focus restoration still reaches the real selected target")
	check(var_to_bytes(world.snapshot())==before_world and var_to_bytes(nav.snapshot())==before_nav,"All touch/forecast/travel requests leave the independent gameplay state unchanged")
	view.queue_free();await process_frame

func inspect_labels(view:Control,context:String)->Dictionary:
	var bounds:=Rect2(Vector2(2,2),view.plot.size-Vector2(4,4))
	var font:Font=view.get_theme_default_font()
	var labelled:Dictionary={}
	for label:Dictionary in view.last_label_rects:
		check(bounds.encloses(label.rect),context+": complete source label remains inside the clipped plot")
		check(not label.rect.intersects(view.last_scale_label_rect),context+": source name does not overlap the actual-font scale legend")
		var name:String=str(view.model.by_id[label.id].name)
		check(label.rect.size.x>=ceilf(font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x)+4 and label.rect.size.y>=ceilf(font.get_height(15))+4,context+": rectangle contains the actual font metrics for "+str(label.id))
		for previous:Dictionary in labelled.values():check(not label.rect.intersects(previous.rect),context+": real source label rectangles never overlap")
		check(label.marker==view.project(view.model.position_au(str(label.id))),context+": name placement leaves the exact source marker unchanged")
		labelled[label.id]=label
	for hit:Dictionary in view._plot_hits:
		check(hit.point==view.project(view.model.position_au(str(hit.id))),context+": every visible marker keeps its original selectable source coordinate")
	check(view.body_buttons.size()==view.model.rows.size(),context+": omitted plot names retain all hierarchy selection targets")
	return labelled

func label_layout()->void:
	var view:=View.new();check(view.configure(state),"Label regression uses the actual original Sol source world")
	root.add_child(view);view.set_process(false);await process_frame
	while view.model.preparation_remaining()>0:view.model.prepare_geometry(3)
	view._select("moon")
	var source_positions:=var_to_bytes(view.model.positions)
	var evidence:Array=[]
	for viewport:Vector2 in [Vector2(720,440),Vector2(1440,720),Vector2(2316,1080)]:
		root.size=Vector2i(viewport);view.size=viewport;view._layout()
		view.model.reset_focus();view.fit_view();view._redraw();await process_frame;await process_frame
		var context:="Sol overview %dx%d"%[viewport.x,viewport.y]
		var labelled:=inspect_labels(view,context)
		check(labelled.has("moon") and labelled.has("earth") and labelled.has("star"),context+": selected Moon, current Earth and source Sun keep distinct readable names in the dense inner-system cluster")
		check(view.last_label_rects.size()>=2 and view.last_label_rects[0].id=="moon" and view.last_label_rects[1].id=="earth",context+": selected body and current focus allocate labels before all minor names")
		check(view.last_label_rects.size()<view._plot_hits.size(),context+": crowded minor names are omitted while their source markers remain selectable")
		evidence.append({"viewport":[int(viewport.x),int(viewport.y)],"scale":"whole_sol","label_count":view.last_label_rects.size(),"marker_count":view._plot_hits.size(),"labels":view.last_label_rects.duplicate(true)})
		# The clip corners and scale-legend area require another bounded offset,
		# rather than overpainting the scale or moving the real source marker.
		for corner:Vector2 in [Vector2(5,5),Vector2(view.plot.size.x-5,5),view.plot.size-Vector2(5,5),Vector2(5,view.plot.size.y-5),Vector2(20,view.plot.size.y-30)]:
			view.pan+=corner-view.project(view.model.position_au("moon"));view._redraw();await process_frame;await process_frame
			var edge_labels:=inspect_labels(view,context+" edge "+str(corner))
			check(edge_labels.has("moon"),context+": selected name remains readable at every plot corner")
			check(view.project(view.model.position_au("moon")).distance_to(corner)<0.01,context+": label fitting does not nudge the selected source marker away from the requested map position")
		view.model.set_focus("earth");view.fit_view();view._redraw();await process_frame;await process_frame
		labelled=inspect_labels(view,"Earth/Moon %dx%d"%[viewport.x,viewport.y])
		check(labelled.has("moon") and labelled.has("earth"),context+": Earth/Moon focus retains selected and current body labels")
		evidence.append({"viewport":[int(viewport.x),int(viewport.y)],"scale":"earth_moon","label_count":view.last_label_rects.size(),"marker_count":view._plot_hits.size(),"labels":view.last_label_rects.duplicate(true)})
	check(var_to_bytes(view.model.positions)==source_positions,"All label priorities, zoom scales and edge fitting leave every actual source position unchanged")
	check(var_to_bytes(world.snapshot())==before_world and var_to_bytes(nav.snapshot())==before_nav,"Label allocation never mutates live world records, spin or source clock")
	print("SYSTEM MAP LABEL EVIDENCE: ",JSON.stringify(evidence))
	view.queue_free();await process_frame

func run()->void:
	var model_script:Script=Map;var view_script:Script=View
	if not model_script.can_instantiate() or not view_script.can_instantiate():
		check(false,"System map scripts compile before test execution");quit(1);return
	setup();model_controls();await ui_controls();await label_layout()
	print("SYSTEM MAP TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
