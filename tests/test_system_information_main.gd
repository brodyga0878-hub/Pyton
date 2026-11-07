extends SceneTree
# Real Main integration: the information screen must not alter a live session,
# lose its parent map, start travel or publish a stale background result.
const World=preload("res://scripts/planetary_system.gd")
const Settings=preload("res://scripts/device_settings.gd")
const ALPHA:=0x06a49718
class MemorySettings extends Settings:
	func load_file()->bool:quality=0;return false
var game:Node3D
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func frame()->void:await process_frame;await process_frame
func snapshot()->PackedByteArray:return var_to_bytes(game._payload())
func identities()->Array:return [game.ship,game.nav,game.world,game.surface,game.source_motion]
func tap(button:Button,pointer:=81)->void:
	var event:=InputEventScreenTouch.new();event.index=pointer;event.position=button.get_global_rect().get_center();event.pressed=true
	root.push_input(event,true);await frame();event.pressed=false;root.push_input(event,true);await frame()
func settle_galaxy(view:Control)->void:
	var started:=Time.get_ticks_msec()
	while view.loading() and Time.get_ticks_msec()-started<30000:await frame()
	check(not view.loading(),"Actual parent galaxy worker completes")
func settle_information()->void:
	var started:=Time.get_ticks_msec()
	while game.information_worker!=null and Time.get_ticks_msec()-started<30000:
		game._pump_information();await frame()
	check(game.information_worker==null,"Isolated information worker completes")
func system_return()->void:
	game._show_system();await frame()
	var parent:Control=game.active_map
	parent.set_preview_offset(12.5);parent._select("mercury");parent.pan=Vector2(51,-32);parent.yaw=0.37
	var before:=snapshot();var old:=identities();var map_state:=var_to_bytes(parent.model.snapshot()) if parent.model.has_method("snapshot") else PackedByteArray()
	var preview:float=parent.model.preview_offset_days
	await tap(parent.buttons.information)
	var info:Control=game.active_map
	check(info!=parent and game.active_map_kind=="information" and game._blocked(),"Actual map information touch opens a modal screen")
	check(game.information_parent==parent and not parent.visible,"Parent map is retained and hidden")
	check(info.current_page_id=="object:mercury" and info.selected_body_id=="mercury","Selected Mercury opens its actual source body card")
	check(not info.document.text.is_empty(),"Real backend supplies actual object text")
	check(info.source_provenance.get("body_count_available",false),"Main forwards an actual source major-body counter")
	check(int(info.pages[0].source_calls[0].variables[0])==int(game.world.source_runtime_state.body_count_byte),"General page uses the source counter rather than displayed natural-body rows")
	for key:String in ["general","demography","trade","object"]:
		await tap(info.buttons[key],82)
		game._advance_controls(5.0);game._process(0.02)
		check(snapshot()==before and identities()==old,"Information tab preserves every live payload field and model identity: "+key)
		check(not info.document.text.is_empty(),"Actual information tab has source content: "+key)
	check(parent.model.preview_offset_days==preview and parent.pan==Vector2(51,-32) and parent.yaw==0.37,"Viewing information preserves the private forecast and chart camera")
	if not map_state.is_empty():check(var_to_bytes(parent.model.snapshot())==map_state,"Information never changes parent map snapshot")
	await tap(info.buttons.close,83)
	check(game.active_map==parent and game.active_map_kind=="system" and parent.visible,"Close returns to the same system map instance")
	check(parent.input_allowed and parent.model.selected_id=="mercury","Original map controls and target selection resume")
	check(snapshot()==before and game.nav.remaining==0 and game.world.transfer_remaining==0,"Opening/closing information never starts travel or changes the session")
	game._close_map(false);await frame()
func status_return()->void:
	game._show_status();await frame()
	var rows:Array=game.menu_rows.get_children();var before:=snapshot()
	var action:Button
	for row:Node in rows:
		if row is Button and row.text=="Сведения о системе":action=row;break
	check(action!=null,"Actual onboard computer offers system information")
	if action==null:return
	var scroll:ScrollContainer=game.menu_rows.get_parent()
	scroll.ensure_control_visible(action);await frame()
	await tap(action,84)
	check(game.active_map_kind=="information" and not game.menu.visible,"Onboard computer opens real information")
	if game.active_map_kind!="information":game._close_menu();return
	await tap(game.active_map.buttons.close,85)
	check(game.active_map==null and game.menu.visible and game.menu_rows.get_children()==rows,"Close restores existing onboard rows without rebuilding or saving")
	check(snapshot()==before,"Onboard information preserves raw motion, time and gameplay payload")
	game._close_menu();await frame()
func galaxy_return()->void:
	game._show_routes();await frame()
	var parent:Control=game.active_map;await settle_galaxy(parent)
	check(parent.select_system(ALPHA),"Actual source Alpha Centauri is available")
	parent._pan(Vector2(13,-7))
	await frame();await settle_galaxy(parent)
	var before:=snapshot();var old:=identities();var centre:Vector2=parent._center
	await tap(parent.buttons.information,86);await settle_information()
	check(game.active_map_kind=="information" and game.active_map!=parent,"Galaxy opens independent distant-system information")
	if game.active_map_kind!="information":game._close_map(false);return
	check(game.active_map.title.text.contains("Центавр"),"Distant page keeps the selected source system")
	check(game.active_map.pages.size()>=3 and not game.active_map.document.text.is_empty(),"Actual distant private world supplies information pages")
	check(snapshot()==before and identities()==old,"Distant source generation does not replace or edit the live world")
	game._close_map()
	check(game.active_map==parent and parent.model.selected_id==ALPHA and parent._center==centre,"Back restores exact galaxy selection and pan")
	check(game.nav.remaining==0 and game.world.transfer_remaining==0,"Reading a distant star never starts a jump or transfer")
	game._show_information(ALPHA)
	game._close_map(false);await frame();game._pump_information()
	check(game.active_map==null and game.information_parent==null and game.information_worker==null,"Replacement/close joins the bounded worker and discards the hidden map")
	check(snapshot()==before and identities()==old,"Cancelled information cannot later publish a different world/session")
func focus_and_exit()->void:
	game.flight_time.request_rate(100);game.flight_time.pending_real_seconds=0.025
	var before:=snapshot();game._show_information();await frame()
	var info:Control=game.active_map
	check(game.flight_time.requested_rate==1 and game.flight_time.pending_real_seconds==0.0,"Information applies the existing modal policy: interrupt time acceleration without advancing the source clock")
	check(snapshot()==before,"Interrupting UI time acceleration preserves physical source clock and fractional motion")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);game._process(1.0)
	check(not info.input_allowed,"Background app disables information actions")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);game._process(0.0)
	check(info.input_allowed and snapshot()==before,"Resume restores screen input with no catch-up simulation")
	game._close_information();await frame()
	check(game.active_map==null and not game._blocked(),"Information opened from flight returns to flight")
func run()->void:
	root.size=Vector2i(1440,720)
	game=load("res://scenes/main.tscn").instantiate();game.settings=MemorySettings.new();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);await frame()
	check(game.automated and not game.saving_enabled,"Integration uses private capture mode without player saves")
	game._new_models(World.FULL_LAYOUT);game._apply_system();game._safe_area()
	game.ship.velocity=Vector3(0.00123,-0.00234,0.00345);game.ship.assisted=false;game._tick(0.0073,Vector2.ZERO,0)
	check(game.source_motion.is_active(),"Read-only controls begin with a genuine fractional native motion session")
	await system_return();await status_return();await galaxy_return();await focus_and_exit()
	var live_world:RefCounted=game.world;var world_state:=var_to_bytes(live_world.snapshot())
	game._show_information(ALPHA)
	var exit_job:Thread=game.information_worker
	check(exit_job!=null and exit_job.is_started(),"Exit control starts a real independent information job")
	game.queue_free();await frame()
	check(not is_instance_valid(game) and not exit_job.is_started(),"Actual scene exit joins its information worker")
	check(var_to_bytes(live_world.snapshot())==world_state,"Scene exit while reading a distant system preserves the live source world")
	print("SYSTEM INFORMATION MAIN TESTS: %d checks, %d failures"%[checks,failures]);quit(0 if failures==0 else 1)
