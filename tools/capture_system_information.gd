extends SceneTree
# Actual Main pages/touches from private fresh sessions; no compositing or
# player progress. The source runtime, physics and clock stay unchanged.
const World=preload("res://scripts/planetary_system.gd")
const Settings=preload("res://scripts/device_settings.gd")
const Info=preload("res://scripts/source_system_information.gd")
const BuildInfo=preload("res://scripts/build_info.gd")
const OUTPUT:="res://validation/system-information-2026-11-07/screenshots"
const ALPHA:=0x06a49718
class MemorySettings extends Settings:
	func load_file()->bool:quality=0;return false
var game:Node3D
var checks:=0
var failures:Array=[]
var captures:Array=[]
var inputs:Dictionary={}
var frozen_payload:=PackedByteArray()
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func frame()->void:
	game._process(0.0);await process_frame;await RenderingServer.frame_post_draw
func tap(button:Button,pointer:=91)->void:
	var event:=InputEventScreenTouch.new();event.index=pointer;event.position=button.get_global_rect().get_center();event.pressed=true
	root.push_input(event,true);await frame();event.pressed=false;root.push_input(event,true);await frame()
func settle()->void:
	var started:=Time.get_ticks_msec()
	while game.information_worker!=null and Time.get_ticks_msec()-started<30000:await frame()
	check(game.information_worker==null,"Actual private information worker finishes")
	for index in range(4):await frame()
func photograph(filename:String)->void:
	for index in range(3):await frame()
	check(game.automated and not game.saving_enabled,"Capture never loads or writes player progress")
	check(var_to_bytes(game._payload())==frozen_payload,"Reading real pages preserves the complete live gameplay payload")
	var info:Control=game.active_map
	var metadata:={"file":filename,"actual_scene":"scenes/main.tscn","viewport":[root.size.x,root.size.y],"elapsed_days":game.nav.elapsed_days,"current_system_id":game.world.system_id,"active_screen":game.active_map_kind,"composited":false,"physical_phone_capture":false,"performance_benchmark":false,"player_progress_read_or_written":false}
	if game.active_map_kind=="information":
		var bounds:=info.get_viewport_rect()
		var seen:Array=[]
		for key:String in info.buttons:
			var rect:Rect2=info.buttons[key].get_global_rect()
			check(bounds.encloses(rect),"Actual information button fits its logical viewport: "+key)
			for previous:Rect2 in seen:check(not rect.intersects(previous),"Actual information action buttons do not overlap")
			seen.append(rect)
		check(info.document.visible and not info.document.text.is_empty(),"Actual source page has visible text")
		check(info.document.get_global_rect().size.x<=info.text_scroll.size.x+1,"Source text wraps within the document viewport")
		metadata.merge({"page_id":info.current_page_id,"selected_body_id":info.selected_body_id,"source_provenance":info.source_provenance,"unsupported_codes":info.unsupported_codes,"text":info.document.text,"object_rows":info.object_buttons.size()})
	check(root.get_texture().get_image().save_png(OUTPUT+"/"+filename)==OK,"Actual Main framebuffer saved as PNG")
	captures.append(metadata)
func choose_object(id:String)->void:
	var info:Control=game.active_map
	check(info.object_buttons.has(id),"Actual source object has an information action: "+id)
	if not info.object_buttons.has(id):return
	info.object_scroll.ensure_control_visible(info.object_buttons[id]);await frame();await frame()
	await tap(info.object_buttons[id],92)
	check(info.selected_body_id==id,"Actual touch selects only the information object")
func finish()->void:
	for path:String in inputs:check(FileAccess.get_sha256("res://"+path)==inputs[path],"Capture leaves source input unchanged: "+path)
	var file:=FileAccess.open(OUTPUT+"/capture-manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":BuildInfo.VERSION,"completed_utc":Time.get_datetime_string_from_system(true),"source_sha256":inputs,"checks":checks,"failures":failures,"frames":captures},"\t"));file.close()
	game.queue_free();await process_frame
	print("SYSTEM INFORMATION CAPTURE: %d frames, %d checks, %d failures"%[captures.size(),checks,failures.size()]);quit(0 if failures.is_empty() else 1)
func run()->void:
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Use a rendered display and private capture mode");quit(1);return
	for path:String in ["scripts/main.gd","scripts/system_information_view.gd","scripts/source_system_information.gd","scripts/source_information_text.gd","scripts/system_map_view.gd","scripts/galactic_map_view.gd","scripts/build_info.gd","data/ffe_system_information.json","data/system_information_ru.json"]:inputs[path]=FileAccess.get_sha256("res://"+path)
	root.size=Vector2i(1440,720);DirAccess.make_dir_recursive_absolute(OUTPUT)
	game=load("res://scenes/main.tscn").instantiate();game.settings=MemorySettings.new();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);await frame()
	game._new_models(World.FULL_LAYOUT);game._apply_system();game._safe_area();game._show_system();await frame()
	frozen_payload=var_to_bytes(game._payload())
	await tap(game.active_map.buttons.information);await settle()
	check(game.active_map_kind=="information","Actual system-map action opens the new information screen")
	if game.active_map_kind!="information":await finish();return
	await tap(game.active_map.buttons.general);await photograph("01-sol-general.png")
	await tap(game.active_map.buttons.demography);await photograph("02-sol-demography.png")
	await tap(game.active_map.buttons.trade);await photograph("03-sol-trade.png")
	await choose_object("mercury");await photograph("04-mercury-source-card.png")
	root.size=Vector2i(2316,1080);await frame();game._safe_area();await frame()
	await choose_object("earth");await photograph("05-earth-source-card-wide.png")
	game._close_map();game._close_map(false);game._show_routes();await frame()
	var galaxy:Control=game.active_map;var started:=Time.get_ticks_msec()
	while galaxy.loading() and Time.get_ticks_msec()-started<30000:await frame()
	check(not galaxy.loading() and galaxy.select_system(ALPHA),"Actual native galaxy selects Alpha Centauri")
	frozen_payload=var_to_bytes(game._payload())
	await tap(galaxy.buttons.information);await settle();await tap(game.active_map.buttons.general)
	await photograph("06-alpha-centauri-general-wide.png")
	game._close_map();game._close_map(false)
	var unknown_id:=0
	for index in range(329):
		var policy:=Info.policy_record(index)
		if int(policy.population_raw)!=0:continue
		var id:=int(str(policy.record_hex).hex_decode().decode_u32(0))
		if not game.nav.galaxy.get_system(id).is_empty():unknown_id=id;break
	check(unknown_id!=0,"Original DOS catalogue has an actual unknown system")
	root.size=Vector2i(960,540);await frame();game._safe_area();frozen_payload=var_to_bytes(game._payload())
	game._show_information(unknown_id);await settle()
	check(game.active_map.object_buttons.is_empty(),"Unknown source knowledge hides planetary information")
	await photograph("07-unknown-system-compact.png")
	game._close_information();root.size=Vector2i(1440,720);await frame();game._safe_area()
	frozen_payload=var_to_bytes(game._payload())
	await photograph("08-return-classic-flight.png")
	await finish()
