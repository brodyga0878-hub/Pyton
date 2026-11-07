extends SceneTree
# Actual Main screenshots for the presentation-only galactic map update.
# The private capture session never loads or writes gameplay progress.
const World=preload("res://scripts/planetary_system.gd")
const Settings=preload("res://scripts/device_settings.gd")
const BuildInfo=preload("res://scripts/build_info.gd")
const OUTPUT:="res://validation/modern-map-2026-11-07/screenshots"
const ALPHA:=0x06a49718
class MemorySettings extends Settings:
	func load_file()->bool:quality=0;return false
var game:Node3D
var checks:=0
var failures:Array=[]
var frames:Array=[]
var inputs:Dictionary={}
var started_utc:=""
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->bool:
	checks+=1
	if not ok:failures.append(message);push_error(message)
	return ok
func frame()->void:await process_frame;await RenderingServer.frame_post_draw
func settle()->void:
	var started:=Time.get_ticks_msec()
	while game.active_map.loading() and Time.get_ticks_msec()-started<30000:await frame()
	check(not game.active_map.loading(),"Real source map worker completes within30s")
	for index in range(4):await frame()
func tap(button:Button,pointer:=70)->void:
	var event:=InputEventScreenTouch.new();event.index=pointer;event.position=button.get_global_rect().get_center();event.pressed=true
	# UI coordinates already include the Canvas transform. Mark them local to
	# the viewport so root-window stretching is not applied a second time.
	root.push_input(event,true);await frame();event.pressed=false;root.push_input(event,true);await frame()
func photograph(name_value:String)->void:
	for i in range(3):await frame()
	var view:Control=game.active_map
	check(game.automated and not game.saving_enabled,"Actual capture cannot load/write user progress")
	check(view.get_meta("presentation_profile","")=="navy-star-chart-v1","Actual Main uses the modern galactic map presentation")
	var rectangles:Array=[]
	var logical_bounds:Rect2=view.get_viewport_rect()
	for key:Variant in view.buttons:
		var button:Control=view.buttons[key]
		if not button.is_visible_in_tree():continue
		var rect:=button.get_global_rect()
		check(logical_bounds.encloses(rect),"Actual map button remains inside the logical viewport: "+str(key))
		for previous:Rect2 in rectangles:check(not rect.intersects(previous),"Actual map action buttons do not overlap")
		rectangles.append(rect)
	for edit:LineEdit in [view.search_edit,view.sector_x,view.sector_y]:
		var rect:=edit.get_global_rect()
		check(logical_bounds.encloses(rect),"Actual text input stays inside the logical viewport")
		for previous:Rect2 in rectangles:check(not rect.intersects(previous),"Text inputs do not overlap each other or actual map action buttons")
		rectangles.append(rect)
	for label:Dictionary in view.last_label_rects:
		check(view._plot.encloses(label.rect),"Actual star label remains inside the chart")
	for marker:Dictionary in view._markers:
		var row:Dictionary=view.model.galaxy.get_system(int(marker.id))
		check(marker.point.distance_to(view._projection(row.position_ly).point)<0.001,"Modern finish preserves the exact original-coordinate star marker")
	var picture:=root.get_texture().get_image()
	check(picture.get_size()==root.size,"Screenshot has actual viewport dimensions")
	check(picture.save_png(OUTPUT+"/"+name_value)==OK,"Actual rendered Main PNG saved")
	frames.append({"file":name_value,"viewport":[root.size.x,root.size.y],"logical_viewport":[logical_bounds.size.x,logical_bounds.size.y],"actual_scene":"scenes/main.tscn","overview":view._overview,"selected_id":view.model.selected_id,"selected_name":view.model.selected.name,"star_count":view.model.rows.size(),"elapsed_days":game.nav.elapsed_days,"composited":false,"physical_phone_capture":false,"performance_benchmark":false,"progress_read_or_written":false})
func capture_size(label:String,dimensions:Vector2i)->void:
	root.size=dimensions;await frame();game._safe_area()
	game._show_routes();await settle()
	check(game.active_map.select_system(ALPHA),"Actual source Alpha Centauri can be selected")
	var position:Vector3=game.ship.position;var days:float=game.nav.elapsed_days;var fuel:int=game.nav.fuel
	await photograph(label+"-01-sector.png")
	await tap(game.active_map.buttons.mode);await settle()
	check(game.active_map._overview and game.active_map._overview_texture!=null,"Overview displays real source-density texture")
	await photograph(label+"-02-galaxy.png")
	check(game.ship.position==position and game.nav.elapsed_days==days and game.nav.fuel==fuel and game.nav.remaining==0,"Viewing both modern maps never moves the ship, clock, fuel or starts a jump")
	game._close_map(false);await frame()
func capture_search()->void:
	root.size=Vector2i(1440,720);await frame();game._safe_area();game._show_routes();await settle()
	game.active_map.select_system(ALPHA)
	game.active_map.search_edit.text="Polaris";await tap(game.active_map.buttons.search);await settle()
	check(game.active_map.results.get_child_count()>0,"Actual distant source search results are available")
	check(game.active_map.selection_facts.is_visible_in_tree() and game.active_map.selection_state.is_visible_in_tree(),"Open search keeps fuel, range, cost and availability visible")
	await photograph("1440x720-03-search-route.png")
	if game.active_map.results.get_child_count()>0:
		var button:Button=game.active_map.results.get_child(0)
		await tap(button,74);await settle()
		check(game.active_map.buttons.jump.disabled and not game.active_map.selection_state.text.is_empty(),"Actual distant source target displays a reason for its disabled jump")
		await photograph("1440x720-04-unreachable-route.png")
	game._close_map(false);await frame()
func finish()->void:
	for path:String in inputs:check(FileAccess.get_sha256("res://"+path)==inputs[path],"Capture does not mutate frozen source: "+path)
	var out:=FileAccess.open(OUTPUT+"/capture-manifest.json",FileAccess.WRITE)
	out.store_string(JSON.stringify({"version":BuildInfo.VERSION,"started_utc":started_utc,"completed_utc":Time.get_datetime_string_from_system(true),"source_sha256":inputs,"checks":checks,"failures":failures,"frames":frames},"\t"));out.close()
	game.queue_free();await frame()
	print("MODERN GALACTIC MAP CAPTURE: %d frames, %d checks, %d failures"%[frames.size(),checks,failures.size()]);quit(0 if failures.is_empty() else 1)
func run()->void:
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires rendered display and private capture mode");quit(1);return
	started_utc=Time.get_datetime_string_from_system(true)
	for path:String in ["scripts/main.gd","scripts/galactic_map_view.gd","scripts/galactic_map_model.gd","scripts/build_info.gd","tools/capture_modern_galactic_map.gd"]:inputs[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(OUTPUT);root.size=Vector2i(1440,720)
	game=load("res://scenes/main.tscn").instantiate();game.settings=MemorySettings.new();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);await frame()
	game._new_models(World.FULL_LAYOUT);game._apply_system()
	await capture_size("1440x720",Vector2i(1440,720));await capture_size("2316x1080",Vector2i(2316,1080));await capture_size("960x540",Vector2i(960,540))
	await capture_search()
	await finish()
