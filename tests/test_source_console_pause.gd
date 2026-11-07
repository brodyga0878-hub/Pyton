extends SceneTree
# Real Main/Worldv4/source Earth terrain, not a synthetic geometry callback.
# A completed, unconsumed CPU core job must stay pending throughout pause and
# every modal screen, then preserve the real parked contact when published.
const World=preload("res://scripts/planetary_system.gd")
const Settings=preload("res://scripts/device_settings.gd")
const Store=preload("res://scripts/save_store.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
class MemorySettings extends Settings:
	func load_file()->bool:quality=0;return false
class MemoryStore extends Store:
	var writes:=0
	func write(_payload:Dictionary)->bool:writes+=1;return true
var game:Node3D
var checks:=0
var failures:=0
var started:=0

func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func snapshot()->PackedByteArray:return var_to_bytes(game._payload())
func touch(key:String,pointer:int)->void:
	var event:=InputEventScreenTouch.new()
	event.index=pointer;event.position=game.flight_console.buttons[key].get_global_rect().get_center();event.pressed=true
	Input.parse_input_event(event);await process_frame
	event.pressed=false;Input.parse_input_event(event);await process_frame
func bounded_wait_until_idle(timeout_msec:=20000)->bool:
	var deadline:=Time.get_ticks_msec()+timeout_msec
	while game.busy and Time.get_ticks_msec()<deadline:await process_frame
	return not game.busy

func prepare_earth()->bool:
	game._new_models(World.FULL_LAYOUT);game.nav.elapsed_days=3.75;game._apply_system();game._refresh_hud()
	check(game.world.layout_mode==World.FULL_LAYOUT and game.nav.is_native(),"Real Main activates source Worldv4 and native navigation")
	var target:Dictionary={}
	for row:Dictionary in game.world.settlements:
		if int(row.model_index)==84 and int(row.type_code)==35:target=row;break
	check(not target.is_empty(),"Actual source Earth has original New Moscow city84")
	if target.is_empty():return false
	game._choose_site(str(target.id))
	check(game.world.transfer_remaining>0,"Main starts the actual source-ground transfer")
	for frame in range(7):game._tick(0.5,Vector2.ZERO,0.0)
	check(await bounded_wait_until_idle(),"Source entry worker finishes inside a bounded deadline")
	game._process(0.0)
	check(game.surface.active and game.surface.source_surface() and game.surface.globe.revision==Terrain.REVISION_NAME,"Main enters actual Earth source terrain through its own orchestration")
	if not game.surface.active:return false
	var deadline:=Time.get_ticks_msec()+20000
	while int(game.ground_view.source_stream_stats().pending_jobs)>0 and Time.get_ticks_msec()<deadline:
		await process_frame;game._process(0.0)
	check(int(game.ground_view.source_stream_stats().pending_jobs)==0 and game.surface.source_render_state!=null,"Initial genuine rendered/collision packet settles before the regression fixture")
	return game.surface.source_render_state!=null

func prepare_pending_core()->Dictionary:
	if not await prepare_earth():return {}
	# Put the real ship at a clear nonvertex point inside the published Earth
	# core but beyond the 512m streaming threshold. The fixture changes only
	# test state; source heights, CPU preparation and publishing are untouched.
	var found:=false
	for point:Vector2 in [Vector2(650.25,-600.5),Vector2(1500.25,-1500.5),Vector2(-1600.25,1300.5)]:
		game.ship.position=Vector3(point.x,game.surface.height_at(point.x,point.y)+game.surface.clearance(game.ship)+0.5,point.y)
		game.ship.velocity=Vector3.ZERO;game.ship.attitude=Quaternion.IDENTITY
		if not game.surface.overlaps_building(game.ship) and game.surface._departure_column_clear(game.ship):found=true;break
	check(found,"Actual source-triangle fixture has an open offpad ascent column")
	if not found:return {}
	game.ship.assisted=false;game.ship.target_speed=0.0
	# This fixture studies paused terrain publication after a normal landing.
	# The actual source gear mechanism must now be requested before touchdown.
	game._request_landing_gear(true)
	for frame in range(80):
		game._tick(0.05,Vector2.ZERO,0.0)
		if game.surface.landed:break
	check(Vector2(game.ship.position.x,game.ship.position.z).length()<=game.surface.REBASE_DISTANCE+20.0,"Physical landing uses the real surface rebase required by valid saves")
	check(game.surface.landed and game.ship.hull==100,"Real Main performs healthy offpad contact before the pending LOD handoff")
	if not game.surface.landed:return {}
	game.surface.render_position=game.ship.position;game.surface.render_velocity=game.ship.velocity
	var old_state:RefCounted=game.surface.source_render_state
	var old_core:Vector2=game.ground_view.source_stream_stats().core_offset
	game._process(0.0)
	var job:Thread=game.ground_view._source_worker
	check(job!=null and int(game.ground_view.source_stream_stats().pending_core_jobs)==1,"Actual Main scene queues one real Earth CPU core job")
	check(game.surface.source_render_state==old_state,"Starting background work does not prematurely replace collision geometry")
	if job==null:return {}
	return {"state":old_state,"core":old_core,"job":job}

func pending_core_pause()->void:
	var prepared:=await prepare_pending_core()
	if prepared.is_empty():return
	var old_state:RefCounted=prepared.state
	var old_core:Vector2=prepared.core
	var job:Thread=prepared.job
	game._refresh_hud();game._update_flight_controls();await touch("pause",101)
	check(game.instruments.paused and not game.flight_console.buttons.pause.disabled,"Real console touch pauses with an enabled resume command")
	var before:=snapshot();var position:Vector3=game.ship.position;var velocity:Vector3=game.ship.velocity
	var clock:float=game.nav.elapsed_days;var altitude:float=game.surface.altitude(game.ship)
	var done_before:int=game.ground_view.source_stream_stats().jobs_finished
	var deadline:=Time.get_ticks_msec()+20000
	while job.is_alive() and Time.get_ticks_msec()<deadline:
		game._process(0.05);game._tick(0.05,Vector2.ONE,1.0,1.0);await process_frame
	check(not job.is_alive(),"Real native-height core worker finishes while simulation remains paused")
	# Exercise display frames after the worker is ready, which used to consume
	# the job and alter the physical contact despite the guarded physics tick.
	for frame in range(12):game._process(0.05);game._tick(0.05,Vector2.ONE,1.0,1.0);await process_frame
	check(game.ground_view._source_worker==job and job.is_started(),"Completed source job remains joined-to-nobody and unconsumed during pause")
	check(game.surface.source_render_state==old_state and int(game.ground_view.source_stream_stats().jobs_finished)==done_before,"Pause display frames cannot publish the finished source LOD")
	check(game.ground_view.source_stream_stats().core_offset==old_core,"Paused rendering retains its exact old published core")
	check(game.ship.position==position and game.ship.velocity==velocity and game.nav.elapsed_days==clock,"Paused physical ship and nonzero source clock stay unchanged")
	check(snapshot()==before,"Completed real worker plus paused Main display/physics frames preserve the entire source save payload")
	game._brake();game._takeoff_action();game._begin_departure_action();await game._enter_surface()
	check(snapshot()==before and game.surface.landed,"Direct physical command paths cannot bypass pause on actual source ground")
	check(not game._decode_state(JSON.parse_string(JSON.stringify(game._payload()))).is_empty(),"Paused source contact still decodes through actual Main save validation")
	await touch("pause",102)
	check(not game.instruments.paused,"Actual console resume touch unpauses the source session")
	game._process(0.0)
	check(game.ground_view._source_worker==null and int(game.ground_view.source_stream_stats().jobs_finished)==done_before+1,"Resume consumes the already completed real CPU job exactly once")
	check(game.surface.source_render_state!=old_state and game.ground_view.source_stream_stats().core_offset!=old_core,"Resume publishes a genuine different source collision/render packet")
	check(absf(game.surface.altitude(game.ship)-altitude)<0.02 and game.surface.landed and game.ship.hull==100,"Actual parked clearance, healthy hull and landing survive resumed source LOD publication")
	check(game.nav.elapsed_days==clock and game.ship.velocity==velocity,"Geometry acceptance itself does not advance source time or inject velocity")
	check(not game._decode_state(JSON.parse_string(JSON.stringify(game._payload()))).is_empty(),"New published contact still saves and restores through real Main decoding")
	check(game._takeoff_action(),"Real Main takeoff is usable after the deferred source job is accepted")
	game._tick(0.05,Vector2.ZERO,0.0,1.0)
	check(not game.surface.landed and game.ship.velocity.y>0 and game.ship.hull==100,"Actual phone lift physically leaves the healthy source floor after resume")
	print("SOURCE CONSOLE PAUSE EVIDENCE: ",JSON.stringify({"source_model":game.surface.globe.source_model_index,"jobs_finished_before":done_before,"jobs_finished_after":game.ground_view.source_stream_stats().jobs_finished,"core_before":str(old_core),"core_after":str(game.ground_view.source_stream_stats().core_offset),"source_days":clock,"worker_real":true,"mock_geometry":false}))

func open_modal(kind:String)->void:
	match kind:
		"system":game._show_system()
		"galaxy":game._show_routes()
		"menu":game._show_menu()
		"settings":
			# Follow the actual menu's connected settings action rather than
			# constructing a replacement overlay in this regression fixture.
			game._show_menu()
			for child in game.menu_rows.get_children():
				if child is Button and child.text=="Настройки телефона":
					child.pressed.emit();break
	game._update_flight_controls()

func close_modal(kind:String)->void:
	match kind:
		"system","galaxy":game._close_map(false)
		"menu":game._close_menu()
		"settings":game._close_settings()

func pending_core_modal(kind:String)->void:
	var prepared:=await prepare_pending_core()
	if prepared.is_empty():return
	var old_state:RefCounted=prepared.state
	var old_core:Vector2=prepared.core
	var job:Thread=prepared.job
	var before:=snapshot();var bodies:=var_to_bytes(game.world.bodies)
	var contact:=var_to_bytes(game.surface.snapshot().get("terrain_contact",{}))
	var position:Vector3=game.ship.position;var velocity:Vector3=game.ship.velocity
	var attitude:Quaternion=game.ship.attitude;var clock:float=game.nav.elapsed_days
	var altitude:float=game.surface.altitude(game.ship)
	open_modal(kind)
	var expected_modal:bool=(is_instance_valid(game.active_map) and game.active_map_kind==kind) if kind in ["system","galaxy"] else (game.menu.visible if kind=="menu" else game.settings_panel.visible)
	check(expected_modal and game._blocked() and not game.instruments.paused,kind+": the actual modal screen freezes flight without using the explicit pause flag")
	if not expected_modal:return
	check(snapshot()==before and game.surface.source_render_state==old_state,kind+": opening the actual modal itself leaves live gameplay and contact untouched")
	if kind=="system":check(game.active_map.set_preview_offset(2.5),"system: a real independent forecast is usable while the pending physical core remains blocked")
	var done_before:int=game.ground_view.source_stream_stats().jobs_finished
	var deadline:=Time.get_ticks_msec()+20000
	while job.is_alive() and Time.get_ticks_msec()<deadline:
		game._process(0.05);game._advance_controls(0.05);await process_frame
	check(not job.is_alive(),kind+": the actual native-height core worker finishes while the modal is open")
	# The CPU job must remain available after it finishes. Render frames used
	# to publish it here even though the normal physics path was blocked.
	for frame in range(12):game._process(0.05);game._advance_controls(0.05);await process_frame
	check(game.ground_view._source_worker==job and job.is_started() and int(game.ground_view.source_stream_stats().pending_core_jobs)==1,kind+": display frames keep the completed real worker unconsumed")
	check(game.surface.source_render_state==old_state and int(game.ground_view.source_stream_stats().jobs_finished)==done_before and game.ground_view.source_stream_stats().core_offset==old_core,kind+": the modal cannot publish or replace the source collision/render core")
	check(game.ship.position==position and game.ship.velocity==velocity and game.ship.attitude==attitude and game.nav.elapsed_days==clock,kind+": parked ship pose, velocity and source clock stay exactly unchanged")
	check(var_to_bytes(game.world.bodies)==bodies and var_to_bytes(game.surface.snapshot().get("terrain_contact",{}))==contact,kind+": original body records and saved physical contact stay exactly unchanged")
	check(snapshot()==before,kind+": a completed real worker plus modal display and control frames preserve the entire actual save payload")
	close_modal(kind)
	check(not game._blocked() and not game.instruments.paused,kind+": closing the actual modal resumes publication without a pause toggle")
	game._process(0.0)
	check(game.ground_view._source_worker==null and int(game.ground_view.source_stream_stats().jobs_finished)==done_before+1,kind+": the first unblocked display frame consumes the completed core exactly once")
	check(game.surface.source_render_state!=old_state and game.ground_view.source_stream_stats().core_offset!=old_core,kind+": closing publishes a genuinely different source collision/render packet")
	check(absf(game.surface.altitude(game.ship)-altitude)<0.02 and game.surface.landed and game.ship.hull==100,kind+": deferred LOD publication preserves healthy parked clearance and contact")
	check(game.nav.elapsed_days==clock and game.ship.velocity==velocity and var_to_bytes(game.world.bodies)==bodies,kind+": publication injects neither time nor velocity and does not mutate source body records")
	check(not game._decode_state(JSON.parse_string(JSON.stringify(game._payload()))).is_empty(),kind+": the accepted actual source contact still saves and restores through Main validation")
	print("SOURCE CONSOLE MODAL EVIDENCE: ",JSON.stringify({"modal":kind,"source_model":game.surface.globe.source_model_index,"jobs_finished_before":done_before,"jobs_finished_after":game.ground_view.source_stream_stats().jobs_finished,"core_before":str(old_core),"core_after":str(game.ground_view.source_stream_stats().core_offset),"source_days":clock,"parked_altitude_before":altitude,"parked_altitude_after":game.surface.altitude(game.ship),"worker_real":true,"mock_geometry":false}))

func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires safe --rebuild-capture mode");quit(1);return
	started=Time.get_ticks_msec();root.size=Vector2i(1440,720)
	game=load("res://scenes/main.tscn").instantiate();game.settings=MemorySettings.new();game.saves=MemoryStore.new();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);await process_frame
	check(game.automated and not game.saving_enabled and game.saves.writes==0,"Capture mode leaves actual player saves untouched")
	await pending_core_pause()
	for kind:String in ["system","galaxy","menu","settings"]:await pending_core_modal(kind)
	check(game.saves.writes==0,"Source pause, modal maps/menus/settings, restoration probes and takeoff make zero user-progress writes")
	game.queue_free();await process_frame
	print("SOURCE CONSOLE PAUSE TESTS: %d checks, %d failures; %.3fs"%[checks,failures,(Time.get_ticks_msec()-started)/1000.0])
	quit(1 if failures else 0)
