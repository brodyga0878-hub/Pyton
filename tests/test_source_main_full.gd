extends SceneTree
# Actual Main orchestration, with persistence redirected to memory. Source-unit
# control suites remain independent; this exercises the player-facing glue.
const World=preload("res://scripts/planetary_system.gd")
const Settings=preload("res://scripts/device_settings.gd")
const Store=preload("res://scripts/save_store.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const BuildInfo=preload("res://scripts/build_info.gd")
class MemorySettings extends Settings:
	func load_file()->bool:quality=0;return false
class MemoryStore extends Store:
	var writes:=0
	func write(_payload:Dictionary)->bool:writes+=1;return true
var game:Node3D
var checks:=0
var failures:=0
var started:=0
var report_directory:=""
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<30:push_error(message)
func copy(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func settle(count:=2)->void:
	for frame in range(count):await process_frame
func touch_button(button:Button,pointer:=71)->void:
	var event:=InputEventScreenTouch.new();event.index=pointer;event.position=button.get_global_rect().get_center();event.pressed=true
	Input.parse_input_event(event);await process_frame
	event.pressed=false;Input.parse_input_event(event);await process_frame
func reset_full()->void:
	game.saving_enabled=false;game._release_inputs();game._new_models(World.FULL_LAYOUT);game._close_menu();game._apply_system()
	check(game.nav.is_native() and game.world.layout_mode==World.FULL_LAYOUT,"Actual Main explicitly activates native navigation and complete source world")
func site(model:int,orbital:=false)->Dictionary:
	for candidate:Dictionary in game.world.settlements:
		if int(candidate.model_index)==model and ((int(candidate.type_code) in [32,33,34]) if orbital else int(candidate.type_code)==35):return candidate
	return {}
func reload_payload(label:String)->bool:
	var payload:Dictionary=copy(game._payload());var old_ship:RefCounted=game.ship
	var decoded:Dictionary=game._decode_state(payload)
	check(not decoded.is_empty(),"Actual Main decodes "+label)
	if decoded.is_empty():return false
	if payload.surface.get("active",false) and payload.surface.get("terrain_revision")==Terrain.REVISION_NAME:
		check(float(decoded.surface._source_days)==float(decoded.nav.elapsed_days) and float(decoded.nav.elapsed_days)>0,"Surface restore uses saved nonzero native time before gravity/rotation queries: "+label)
		check(copy(decoded.world.snapshot().body_spin_by_id)==payload.planetary.body_spin_by_id,"Surface decode preserves every saved source Q31 body frame without epoch rewind: "+label)
	game._commit_state(decoded);game._apply_system();game._refresh_hud()
	check(game.ship!=old_ship and game.nav.snapshot().version==2 and game.world.snapshot().version==4,"Actual Main commits isolated source models for "+label)
	return true
func reject_payload(payload:Dictionary,label:String)->void:
	var before:=JSON.stringify(game._payload());var identity:Array=[game.ship,game.nav,game.world,game.surface]
	check(game._decode_state(payload).is_empty(),"Main rejects "+label)
	check(JSON.stringify(game._payload())==before and [game.ship,game.nav,game.world,game.surface]==identity,"Rejected "+label+" leaves all live models unchanged")
func pump_hatch()->void:
	game._pump_underground_geometry()
	if game.hatch_worker==null:return
	var frames:=0
	while game.hatch_worker!=null and frames<10000:
		await process_frame;game._pump_underground_geometry();frames+=1
	check(game.hatch_worker==null,"Actual Main worker completes bounded source hatch preparation")
func transfer_to(target:Dictionary)->bool:
	if target.is_empty():check(false,"Requested original site exists");return false
	game._choose_site(str(target.id))
	check(game.world.transfer_remaining>0,"Main begins transfer to actual source site "+str(target.name))
	if game.world.transfer_remaining<=0:return false
	for frame in range(7):game._tick(0.5,Vector2.ZERO,0.0)
	var frames:=0
	while game.busy and frames<10000:await process_frame;frames+=1
	await settle()
	check(game.world.site_id==str(target.id) and game.world.transfer_remaining==0,"Main commits original site and completes transfer")
	return game.world.site_id==str(target.id)

func jump_controls()->void:
	print("Main FULL: native jump and pending save/cancel")
	reset_full()
	var destination:=-1
	for star:Dictionary in game.nav.galaxy.all():
		var id:=int(star.id);var distance:float=game.nav.galaxy.distance(game.nav.current_id,id)
		if id!=game.nav.current_id and distance>0 and distance<=game.ship.jump_range():destination=id;break
	check(destination>=0,"Native source catalogue supplies an in-range distinct jump target")
	if destination<0:return
	var fuel:int=game.nav.fuel;var origin:int=game.nav.current_id
	game._start_jump(destination)
	check(game.nav.remaining>0 and game.nav.pending_id==destination,"Main starts native-catalogue jump")
	if not reload_payload("pending native jump"):return
	game._brake()
	check(game.nav.remaining==0 and game.nav.pending_id==-1 and game.nav.fuel==fuel and game.nav.current_id==origin,"Main brake cancels restored jump without fuel loss")
	game._start_jump(destination)
	for frame in range(7):game._tick(0.5,Vector2.ZERO,0.0)
	check(game.nav.current_id==destination and game.nav.remaining==0 and game.nav.fuel<fuel and game.world.system_id==destination and game.world.layout_mode==World.FULL_LAYOUT,"Completed Main jump constructs actual destination source system")
	check(reload_payload("completed native jump"),"Completed native world survives Main roundtrip")

func orbital_controls()->void:
	print("Main FULL: orbital transfer, physical autopilot, services and launch")
	reset_full()
	var target:=site(72,true)
	check(not target.is_empty(),"Sol exposes an original model72 orbital port")
	if target.is_empty():return
	game._choose_site(str(target.id))
	check(game.world.transfer_remaining>0,"Main queues original orbital transfer")
	if not reload_payload("pending orbital transfer"):return
	game._brake()
	check(game.world.transfer_remaining==0 and game.world.pending_site_id.is_empty(),"Main brake cancels restored intra-system transfer")
	if not await transfer_to(target):return
	check(not game.surface.active and game.ship.has_source_station() and game.nav.has_station() and game.ship.snapshot().version==5,"Selected original orbital port binds source Flightv5 and derived refuel context")
	# A bounded initial approach fixture starts outside the real source opening;
	# the complete staging, alignment, bay entry and exit are physical tick loops.
	var basis:Basis=game.world.source_station_basis(game.nav.elapsed_days)
	var geometry:Dictionary=game.world.source_station_geometry(game.nav.elapsed_days)
	game.ship.position=game.ship.STATION+basis*(geometry.approach_waypoint+Vector3(80,20,100))
	game.ship.velocity=Vector3.ZERO;game.ship.attitude=Quaternion(Vector3.RIGHT,0.3)
	game._toggle_auto()
	var entered:=false;var aligned:=false;var frames:=0
	while not game.ship.docked and game.ship.hull>0 and frames<3200:
		game._tick(0.25,Vector2.ZERO,0.0);frames+=1
		if game.ship._source_pilot_phase=="align":aligned=true
		if game.ship._source_pilot_phase=="enter":entered=true
	check(game.ship.docked and entered and aligned,"Actual Main ticks stage, align and enter original bay without capture teleport")
	check(game.ship.hull==100 and game.ship.position==game.ship.STATION and game.ship.velocity==Vector3.ZERO,"Physical orbital approach reaches actual source dock centre without hull damage")
	if not game.ship.docked:return
	check(reload_payload("physically docked source Flightv5"),"Actual docked source frame survives Main decode/commit")
	var forged:Dictionary=copy(game._payload());forged.flight.velocity=[0,0,1]
	reject_payload(forged,"moving docked source save")
	forged=copy(game._payload());forged.flight.target_speed=1.0
	reject_payload(forged,"nonzero docked source target speed")
	game.nav.fuel=10;game.ship.credits=1000
	game._show_services(false);await settle()
	check(game.menu.visible and game.dock_services_view!=null and game._dock_services_state().source_refuel_only,"Actual Main opens selected-source-port services")
	var refuel:Button=game.dock_services_view.buttons.get("refuel")
	check(refuel!=null and not refuel.disabled,"Actual source service view enables valid refuel quote")
	if refuel!=null:refuel.pressed.emit()
	check(game.nav.fuel==12 and game.ship.credits==980,"Actual service signal charges exactly20 credits for two fuel units")
	game._close_menu()
	# A legitimate docked save may have a sealed source gate. Only the station
	# door word/status are changed to create that initial saved fixture; all
	# opening, waiting, cancellation and physical departure use real Main APIs.
	var sealed:Dictionary=copy(game._payload());var station_id:String=game.world.site_id
	sealed.planetary.station_state_by_site[station_id].door_u16=65535
	sealed.planetary.station_state_by_site[station_id].status_u8=0
	sealed.planetary.station_state_by_site[station_id].pending_launch=false
	var decoded:Dictionary=game._decode_state(sealed)
	check(not decoded.is_empty(),"Main accepts legitimate closed-gate docked Flightv5 save")
	if decoded.is_empty():return
	game._commit_state(decoded);game._apply_system();game._refresh_hud();game._update_flight_controls();await settle()
	check(game.ship.docked and game.world.source_station_state(game.nav.elapsed_days).door_u16==65535,"Closed original gate restores paired with docked source ship")
	await touch_button(game.flight_console.buttons.dock,73)
	check(game.ship.docked and game.world.station_launch_pending() and game.world.source_station_state(game.nav.elapsed_days).status_u8==254 and game.ship.position==game.ship.STATION,"Routed dock-console touch requests real gate opening and waits in bay")
	game._tick(0.1,Vector2.ZERO,0.0)
	var waiting_door:int=game.world.source_station_state(game.nav.elapsed_days).door_u16
	check(waiting_door>0 and waiting_door<65535 and game.ship.docked,"Actual Main F865 ticks open closed orbital gate without early teleport")
	if not reload_payload("waiting closed-gate orbital launch"):return
	check(game.ship.docked and game.world.station_launch_pending() and int(game.world.source_station_state(game.nav.elapsed_days).door_u16)==waiting_door,"Pending launch and intermediate source door word survive Main save/reload")
	game._brake();game._tick(0.1,Vector2.ZERO,0.0)
	check(game.ship.docked and not game.world.station_launch_pending(),"Main brake cancels restored launch request without forcing departure")
	game._refresh_hud();game._update_flight_controls();await settle()
	await touch_button(game.flight_console.buttons.dock,74)
	check(game.ship.docked and game.world.station_launch_pending(),"Phone dock action can retry cancelled launch while real gate is still opening")
	var launch_frames:=0
	while game.ship.docked and launch_frames<60:game._tick(0.1,Vector2.ZERO,0.0);launch_frames+=1
	check(not game.ship.docked and not game.world.station_launch_pending() and int(game.world.source_station_state(game.nav.elapsed_days).door_u16)==0,"Source F865 opening completes waiting Main launch and clears persisted request")
	check(game.ship.position.distance_to(game.ship.STATION)<2.0,"Automatic resumed launch begins at source interior with only one physical tick of movement")
	for frame in range(160):game._tick(0.25,Vector2.ZERO,0.0)
	basis=game.world.source_station_basis(game.nav.elapsed_days)
	check(game.ship.hull==100 and (basis.transposed()*(game.ship.position-game.ship.STATION)).z>400,"Physical launch clears real source gate and station transfer guard")
	var before:int=game.ship.credits;game._service_command("refuel")
	check(game.ship.credits==before,"Main rejects service transaction after launch")

func offpad_controls()->void:
	print("Main FULL: New Moscow original terrain, offpad landing and phone lift")
	reset_full()
	game.nav.elapsed_days=3.75
	var target:=site(84)
	if not await transfer_to(target):return
	check(game.surface.active and game.surface.source_surface() and game.surface.globe.revision==Terrain.REVISION_NAME,"Main ground transfer activates actual v4 source field")
	if not game.surface.active:return
	var found:=false
	for point:Vector2 in [Vector2(650,-600),Vector2(1500,-1500),Vector2(-1600,1300),Vector2(2200,1800)]:
		game.ship.position=Vector3(point.x,game.surface.height_at(point.x,point.y)+game.surface.clearance(game.ship)+0.7,point.y)
		game.ship.velocity=Vector3.ZERO;game.ship.attitude=Quaternion.IDENTITY
		if not game.surface.overlaps_building(game.ship) and game.surface._departure_column_clear(game.ship):found=true;break
	check(found,"Offpad landing fixture has a verified open source-triangle ascent column")
	if not found:return
	game.ship.assisted=false;game.ship.target_speed=0
	for frame in range(80):
		game._tick(0.05,Vector2.ZERO,0.0)
		if game.surface.landed:break
	check(game.surface.landed and game.ship.hull==100 and game.surface.pad_distance(game.ship)>80,"Actual Main gravity and source floor perform healthy landing outside designated pad")
	if not game.surface.landed:return
	check(reload_payload("healthy offpad source landing"),"Offpad landing saves and reloads through actual Main")
	game._tick(0.1,Vector2.ZERO,0.0,1.0)
	check(not game.surface.landed and game.ship.hull==100 and game.ship.velocity.y>0,"Phone positive lift leaves restored healthy offpad landing")
	for frame in range(40):game._tick(0.1,Vector2.ZERO,0.0,1.0)
	check(game.surface.altitude(game.ship)>2 and game.ship.hull==100,"Held phone lift physically rises above actual source terrain")
	check(reload_payload("offpad ascent"),"Healthy offpad airborne state survives Main reload")

func underground_controls()->void:
	print("Main FULL: Moon model96 physical hatch approach, save and launch")
	reset_full()
	game.nav.elapsed_days=7.125
	var target:=site(96)
	if not await transfer_to(target):return
	check(game.surface.active and game.surface.underground!=null and game.surface.city_data.door_u16==65535,"Main enters original lunar hangar with actual closed roof")
	if game.surface.underground==null:return
	var initial_visual:Node3D=game.city_view.current_visual()
	check(initial_visual!=null and initial_visual.get_script().resource_path=="res://scripts/source_enclosed_city_visual.gd" and initial_visual.door_u16==65535,"Actual Main scene uses source enclosed-city visual with matching closed collider")
	var static_visual:Node3D=initial_visual.static_visual if initial_visual!=null else null
	game._toggle_auto()
	check(game.surface.landing and game.surface.underground.state.phase=="opening","Main autopilot requests original ground hatch opening")
	var frames:=0;var opened:=false;var inside:=false
	while not game.surface.landed and game.ship.hull>0 and frames<1800:
		game._tick(0.25,Vector2.ZERO,0.0);await pump_hatch();frames+=1
		if game.surface.city_data.door_u16==0 and not opened:
			opened=true;game._sync_scene()
			var visual:Node3D=game.city_view.current_visual()
			check(visual!=null and visual.door_u16==0 and visual.static_visual==static_visual and visual.static_build_count==1,"Actual Main publishes open roof visually while preserving static city mesh")
		if game.surface.underground.state.phase=="inside":inside=true
		if frames%300==0:print("Main96 frame=",frames," phase=",game.surface.underground.state.phase," alt=",game.surface.altitude(game.ship)," hull=",game.ship.hull)
	check(game.surface.landed and opened and inside,"Actual Main autoland physically passes original open roof and reaches hangar floor")
	check(game.ship.hull==100,"Actual source96 descent preserves healthy hull")
	if not game.surface.landed:return
	for frame in range(24):game._tick(0.25,Vector2.ZERO,0.0);await pump_hatch()
	check(game.surface.underground.state.phase=="docked" and game.surface.city_data.door_u16==65535,"Actual floor contact enables enclosed dock and closes source hatch")
	game._sync_scene()
	check(game.city_view.current_visual().door_u16==game.surface.city_data.door_u16,"Actual Main rendered sealed hatch and physical source pose remain paired")
	check(reload_payload("closed original lunar hangar"),"Closed original hangar geometry/phase reload through actual Main")
	var bad:Dictionary=copy(game._payload());bad.surface.underground.state.door_u16=70000
	reject_payload(bad,"corrupt lunar hatch state")
	game._refresh_hud();game._update_flight_controls();await settle()
	var launch_button:Button=game.flight_console.buttons.dock
	check(game.dock_button.text=="Взлететь" and launch_button.input_allowed and not launch_button.disabled,"Restored closed hangar exposes enabled takeoff action in preferred lower console")
	await touch_button(launch_button)
	check(not game.surface.landed and game.surface.underground.state.intent=="launch","Routed phone-console touch reaches actual Main takeoff action in restored closed hangar")
	frames=0
	while game.ship.hull>0 and frames<240 and game.surface.underground.state.phase!="closed":
		game._tick(0.25,Vector2.ZERO,0.0);await pump_hatch();frames+=1
	check(not game.surface.landed and game.ship.hull==100 and game.surface.underground.state.phase=="closed","Main launch opens roof, physically exits, then safely reseals source hangar")
	var where:Dictionary=game.surface.underground.current_route(game.surface.globe,game.surface.collision_radii(game.ship))
	check(game.ship.position.y>where.hatch_center_local_m.y+game.surface.clearance(game.ship),"Launch leaves entire ship above real source roof")
	check(reload_payload("exited lunar hangar"),"Post-launch source surface state survives Main decode/commit")

func cleanup_private(path:String)->void:
	for name in DirAccess.get_files_at(path):DirAccess.remove_absolute(path.path_join(name))
	for name in DirAccess.get_directories_at(path):cleanup_private(path.path_join(name))
	DirAccess.remove_absolute(path)
func diagnostic_report_controls()->void:
	print("Main FULL: actual diagnostic ZIP with complete saved source world")
	if not game.surface.active or game.world.layout_mode!=World.FULL_LAYOUT:check(false,"FULL source surface remains available for diagnostic save fixture");return
	report_directory="user://source-main-full-report-%d"%Time.get_ticks_usec()
	game.diagnostics.directory=report_directory+"/diagnostics";game.diagnostics.reports_directory=report_directory+"/reports";game.diagnostics.engine_logs_directory=report_directory+"/isolated-engine-logs"
	check(game.diagnostics.initialize(BuildInfo.VERSION),"Actual Main collector initializes only under unique private test directory")
	var named_fields:Dictionary={}
	named_fields[&"authorization"]="MUST_BE_FILTERED";named_fields[&"refresh_token"]="MUST_BE_FILTERED";named_fields[&"source_contract"]=&"original-world-v4"
	var sanitized:Dictionary=game.diagnostics._safe_value(named_fields,0)
	check(game.diagnostics._json_safe(named_fields),"Diagnostics accepts legitimate GDScript StringName keys and values used by FULL saves")
	check(not sanitized.has("authorization") and not sanitized.has("refresh_token") and sanitized.get("source_contract")=="original-world-v4" and sanitized.source_contract is String,"StringName normalization preserves source metadata and filters sensitive names before export")
	var before:String=JSON.stringify(game._payload());var identity:Array=[game.ship,game.nav,game.world,game.surface]
	check(game.diagnostics._json_safe(game._payload()),"Complete Navigationv2/Worldv4/Flight/surface payload contains only JSON-safe saved values")
	game._show_bug_report()
	for child in game.menu_rows.get_children():
		if child is CheckBox:child.button_pressed=true
	game.report_description.text="Проверка исходного мира: лунный ангар, сохранение и вылет."
	game.report_description.text_changed.emit()
	check(game.report_include_save,"Actual Main report checkbox includes complete current source save")
	await game._create_bug_report(false)
	check(not game.busy and game.current_report.get("ok",false),"Actual Main builds FULL bug-report ZIP with save: "+str(game.current_report.get("error",game.diagnostics.last_error)))
	if not game.current_report.get("ok",false):game.diagnostics.shutdown();return
	var zip:=ZIPReader.new();var opened:=zip.open(str(game.current_report.path))==OK
	check(opened,"FULL diagnostic artifact is an actual readable ZIP")
	if opened:
		var names:=zip.get_files()
		check("game-save.json" in names and "report.json" in names and "manifest.json" in names and "events/current-events.jsonl" in names,"FULL diagnostic ZIP includes canonical save, source metadata, manifest and game logs")
		var saved_text:=zip.read_file("game-save.json").get_string_from_utf8()
		check(saved_text==before,"Diagnostic ZIP preserves complete canonical source-world payload without truncation")
		var included:Variant=JSON.parse_string(saved_text)
		check(included is Dictionary and not game._decode_state(included).is_empty(),"Complete FULL save recovered from ZIP restores through real Main decoder")
		var metadata:Dictionary=JSON.parse_string(zip.read_file("report.json").get_string_from_utf8())
		check(metadata.included_save and metadata.version==BuildInfo.VERSION and metadata.context.session.world_layout==World.FULL_LAYOUT and float(metadata.context.session.elapsed_days)>0,"FULL report keeps actual build, world contract and nonzero native session time")
		var manifest:Dictionary=JSON.parse_string(zip.read_file("manifest.json").get_string_from_utf8())
		for entry in manifest.files:
			var bytes:=zip.read_file(str(entry.name))
			check(bytes.size()==int(entry.bytes) and game.diagnostics._hash(bytes)==str(entry.sha256),"FULL report ZIP size/SHA verifies "+str(entry.name))
		zip.close()
	check(JSON.stringify(game._payload())==before and [game.ship,game.nav,game.world,game.surface]==identity,"Creating FULL diagnostic archive changes no live gameplay models or saved state")
	check(not game.report_export.is_busy(),"Diagnostic test does not open native SAF/export picker")
	game.diagnostics.shutdown();game._close_menu()

func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires --rebuild-capture to protect user progress");quit(1);return
	started=Time.get_ticks_msec();root.size=Vector2i(1440,720)
	game=load("res://scenes/main.tscn").instantiate();game.settings=MemorySettings.new();game.saves=MemoryStore.new();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);await settle()
	check(game.automated and not game.saving_enabled and game.saves.writes==0,"Actual Main capture mode performs no user-progress writes")
	await jump_controls();await orbital_controls();await offpad_controls();await underground_controls();await diagnostic_report_controls()
	check(game.saves.writes==0,"All FULL gameplay tests leave user progress untouched")
	game.saving_enabled=false;game.queue_free();await process_frame
	if not report_directory.is_empty():cleanup_private(report_directory)
	print("SOURCE MAIN FULL TESTS: ",checks," checks, ",failures," failures; ",(Time.get_ticks_msec()-started)/1000.0,"s")
	quit(1 if failures else 0)
