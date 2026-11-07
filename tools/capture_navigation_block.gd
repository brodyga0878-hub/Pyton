extends SceneTree
# Genuine rendered Main views. Capture mode disables gameplay save/load; this
# script changes only an isolated in-memory flight and uses the real map UI.
const World=preload("res://scripts/planetary_system.gd")
const BuildInfo=preload("res://scripts/build_info.gd")
const OUTPUT:="res://validation/navigation-2026-11-07/screenshots"
const ALPHA:=0x06a49718
var game:Node3D
var records:Array=[]
var checks:=0
var failures:Array=[]
var source_sha256:Dictionary={}
var started_utc:=""

func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->bool:
	checks+=1
	if not ok:failures.append(message);push_error(message)
	return ok
func frame()->void:
	await process_frame
	await RenderingServer.frame_post_draw

func tap(button:Button,index:=80)->void:
	var event:=InputEventScreenTouch.new()
	event.index=index;event.position=button.get_global_rect().get_center();event.pressed=true
	button._input(event)
	event.pressed=false;button._input(event)
	await frame()

func wait_map()->bool:
	var start:=Time.get_ticks_msec()
	while is_instance_valid(game.active_map) and Time.get_ticks_msec()-start<30000:
		var view:Control=game.active_map
		var loading:bool=view.loading() if game.active_map_kind=="galaxy" else view.model.preparation_remaining()>0
		if not loading:
			for i in range(4):await frame()
			return check(true,"Actual map preparation completed")
		await frame()
	return check(false,"Actual map did not finish preparation within 30 seconds")

func audit_buttons(buttons:Dictionary)->void:
	var viewport:=Rect2(Vector2.ZERO,Vector2(root.size))
	var visible:Array=[]
	for key:Variant in buttons:
		var button:Control=buttons[key]
		if not button.is_visible_in_tree():continue
		var rect:=button.get_global_rect()
		check(viewport.encloses(rect),"Button stays inside capture viewport: "+str(key))
		for previous:Dictionary in visible:
			check(not rect.intersects(previous.rect),"Separate buttons do not overlap: %s / %s"%[str(key),previous.key])
		visible.append({"key":str(key),"rect":rect})

func audit_labels(labels:Array,bounds:Rect2)->void:
	var previous:Array=[]
	for label:Dictionary in labels:
		check(bounds.encloses(label.rect),"Actual rendered source label stays within plot")
		for rect:Rect2 in previous:check(not label.rect.intersects(rect),"Actual rendered source labels do not overlap")
		previous.append(label.rect)

func photograph(filename:String)->bool:
	game._process(0);game._refresh_hud();game.notice_timer=0;game.notice.hide();game.player._process(0)
	for i in range(4):await frame()
	var map:Control=game.active_map if is_instance_valid(game.active_map) else null
	if map!=null:audit_buttons(map.buttons)
	else:
		audit_buttons(game.time_controls.buttons)
		check(not game.docking_label.text.is_empty(),"Flight displays measured docking telemetry")
		check(game.ship.source_docking_telemetry().get("sample_valid",false),"Flight telemetry is a real source-time sample")
	check(game.automated and not game.saving_enabled,"Capture keeps gameplay persistence disabled")
	var image:=root.get_texture().get_image()
	if not check(image.get_width()==root.size.x and image.get_height()==root.size.y,"Image has actual viewport dimensions"):return false
	if not check(image.save_png(OUTPUT+"/"+filename)==OK,"Rendered viewport PNG saved"):return false
	var record:={"file":filename,"actual_scene":"scenes/main.tscn","viewport":[root.size.x,root.size.y],"map_kind":game.active_map_kind,"layout":game.world.layout_mode,"view":game.instruments.view_key(game.ship.external_view),"elapsed_days":game.nav.elapsed_days,"menu_visible":game.menu.visible,"gameplay_progress_read":false,"gameplay_progress_written":false,"composited":false,"physical_phone_capture":false,"performance_benchmark":false}
	if map!=null:
		record.title=map.title.text
		if game.active_map_kind=="galaxy":
			record.overview=map._overview;record.source_system_count=map.model.rows.size();record.selected_id=map.model.selected_id
			if not map._overview:
				record.rendered_sector_labels=map.last_label_rects.size()
				audit_labels(map.last_label_rects,map._plot)
		else:
			record.source_body_and_port_count=map.model.rows.size();record.selected_id=map.model.selected_id;record.preview_offset_days=map.model.preview_offset_days
			record.rendered_system_labels=map.last_label_rects.size()
			audit_labels(map.last_label_rects,Rect2(Vector2.ZERO,map.plot.size))
	else:
		record.station_model=int(game.world.current_site().get("model_index",-1));record.docking_telemetry_text=game.docking_label.text;record.time_text=game.time_controls.status.text
	records.append(record)
	return true

func prepare_flight()->bool:
	game._new_models(World.FULL_LAYOUT)
	var port:Dictionary={}
	for site:Dictionary in game.world.settlements:
		if int(site.model_index)==80 and int(site.type_code) in [32,33,34]:port=site;break
	if not check(not port.is_empty(),"Actual original orbital station80 exists in Sol"):return false
	game.world.focus_id=str(port.parent);game.world.selected_id=str(port.parent);game.world.site_id=str(port.id)
	game._apply_system()
	var basis:Basis=game.world.source_station_basis(game.nav.elapsed_days)
	game.ship.position=game.ship.STATION+basis*Vector3(0,0,800)
	game.ship.attitude=(basis*Basis(Vector3.FORWARD,deg_to_rad(12))).get_rotation_quaternion()
	game.ship.external_view=false;game.ship.velocity=Vector3.ZERO;game.ship.target_speed=0
	game._apply_system();game._tick(0.1,Vector2.ZERO,0)
	var start:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<30000:
		game._process(0)
		if game.celestial.source_mesh_state().get("status")=="ready":break
		await frame()
	return check(game.celestial.source_mesh_state().get("status")=="ready","Actual source celestial mesh prepared")

func capture_size(label:String,dimensions:Vector2i)->bool:
	root.size=dimensions;await frame();game._safe_area()
	if not await prepare_flight():return false
	if not await photograph(label+"-01-flight-time-roll.png"):return false
	game._show_routes()
	if not check(is_instance_valid(game.active_map) and game.active_map_kind=="galaxy","Main opened actual galaxy view"):return false
	if not await wait_map():return false
	if not check(game.active_map.select_system(ALPHA),"Real Alpha Centauri can be selected without jumping"):return false
	var clock:float=game.nav.elapsed_days
	var position:Vector3=game.ship.position
	if not await photograph(label+"-02-galaxy-sector.png"):return false
	await tap(game.active_map.buttons.mode)
	if not await wait_map():return false
	if not check(game.active_map._overview and game.active_map._overview_texture!=null,"Actual native galaxy density is displayed"):return false
	if not await photograph(label+"-03-galaxy-overview.png"):return false
	game._close_map(false);await frame();game._show_system()
	if not check(is_instance_valid(game.active_map) and game.active_map_kind=="system","Main opened actual system map"):return false
	if not await wait_map():return false
	await tap(game.active_map.buttons.fit)
	if not await photograph(label+"-04-system-overview.png"):return false
	game.active_map._select("earth");await tap(game.active_map.buttons.center)
	if not await wait_map():return false
	if not await photograph(label+"-05-system-earth-moon.png"):return false
	check(game.nav.elapsed_days==clock and game.ship.position==position,"Maps do not advance live clock or move the ship")
	game._close_map(false);await frame()
	return true

func finish(code:int)->void:
	var output:=FileAccess.open(OUTPUT+"/capture-manifest.json",FileAccess.WRITE)
	if output!=null:output.store_string(JSON.stringify({"version":BuildInfo.VERSION,"started_utc":started_utc,"source_sha256":source_sha256,"checks":checks,"failures":failures,"frames":records},"\t"));output.close()
	if is_instance_valid(game):game.queue_free();await frame()
	quit(code)

func run()->void:
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in OS.get_cmdline_user_args():
		push_error("Needs an actual rendered display and --rebuild-capture");quit(1);return
	started_utc=Time.get_datetime_string_from_system(true)
	for source:String in ["scripts/main.gd","scripts/build_info.gd","scripts/galactic_map_view.gd","scripts/system_map_view.gd","tools/capture_navigation_block.gd"]:source_sha256[source]=FileAccess.get_sha256("res://"+source)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size=Vector2i(1440,720)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);await frame()
	if not check(game.automated and not game.saving_enabled,"Actual Main capture mode cannot save gameplay progress"):await finish(1);return
	if not await capture_size("1440x720",Vector2i(1440,720)):await finish(1);return
	if not await capture_size("2316x1080",Vector2i(2316,1080)):await finish(1);return
	print("NAVIGATION MAIN CAPTURE: %d rendered frames, %d checks, %d failures; no physical-device performance claim"%[records.size(),checks,failures.size()])
	await finish(0 if failures.is_empty() else 1)
