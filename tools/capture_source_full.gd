extends SceneTree
# Actual rendered Main frames. No player progress is read or written.
const World=preload("res://scripts/planetary_system.gd")
const Surface=preload("res://scripts/surface_model.gd")
const OUTPUT:="res://build/source-full-screenshots"
var game:Node3D
var captures:Array=[]
func _initialize()->void:call_deferred("run")
func frame()->void:await process_frame;await RenderingServer.frame_post_draw
func ready_mesh()->bool:
	for index in range(2000):
		game._sync_scene()
		if game.celestial.source_mesh_state().get("status")=="ready":return true
		await frame()
	return false
func save_frame(filename:String,eye:Vector3,target:Vector3)->bool:
	game._sync_scene();game._refresh_hud();game.camera.position=eye;game.camera.look_at(game.to_global(target),Vector3.UP);game.camera.fov=62
	game.notice_timer=0;game.notice.hide();game.player.visible=true
	for index in range(4):await frame()
	if root.get_texture().get_image().save_png(OUTPUT+"/"+filename)!=OK:return false
	captures.append({"file":filename,"actual_scene":"scenes/main.tscn","layout":game.world.layout_mode,"system_id":game.world.system_id,"site_id":game.world.site_id,"terrain_revision":game.surface.globe.revision if game.surface.globe!=null else "","station_model":int(game.world.current_site().get("model_index",-1)),"source_mesh":game.celestial.source_mesh_state(),"quality":game.settings.quality,"ship_hull":game.ship.hull,"phone_capture":false,"gameplay_progress_read":false,"gameplay_progress_written":false,"composited":false})
	return true
func finish(code:int)->void:
	game.queue_free();await frame();quit(code)
func run()->void:
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Use rendered capture mode");quit(1);return
	root.size=Vector2i(1920,1080);DirAccess.make_dir_recursive_absolute(OUTPUT)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	if not game.automated or game.saving_enabled:push_error("Unsafe capture state");await finish(1);return
	game.settings.quality=2;game._new_models(World.FULL_LAYOUT);game._apply_system();game.ship.external_view=true
	var port:Dictionary={}
	for site:Dictionary in game.world.settlements:
		if int(site.model_index)==80:port=site;break
	if port.is_empty():push_error("Source80 missing");await finish(1);return
	game.world.focus_id=str(port.parent);game.world.selected_id=str(port.parent);game.world.site_id=str(port.id);game._apply_system()
	var basis:Basis=game.world.source_station_basis(game.nav.elapsed_days)
	game.ship.position=game.ship.STATION+basis*Vector3(0,0,600);game.ship.attitude=basis.get_rotation_quaternion()
	await ready_mesh()
	var geometry:Dictionary=game.world.source_station_geometry(game.nav.elapsed_days)
	var centre:Vector3=geometry.bounds.get_center();var span:float=geometry.bounds.size.length()
	if not await save_frame("01-original-orbital-station.png",game.ship.STATION+basis*(centre+Vector3(0.8,0.35,0.9)*span),game.ship.STATION+basis*centre):await finish(1);return
	game._new_models(World.FULL_LAYOUT);game.world.site_id="site10";game.world.focus_id="earth";game.world.selected_id="earth";game._apply_system()
	await game._enter_surface()
	if not game.surface.active or not await ready_mesh():push_error("Source city capture failed");await finish(1);return
	game.ship.position=game.surface.pad_position()+Vector3(0,150,0);game.ship.external_view=true;game._apply_system()
	var target:Vector3=game.surface.pad_position()
	if not await save_frame("02-original-ground-city.png",target+Vector3(650,450,900),target):await finish(1);return
	game._new_models(World.FULL_LAYOUT);game.world.site_id="site17";game.world.focus_id="moon";game.world.selected_id="moon";game._apply_system()
	await game._enter_surface()
	if not game.surface.active or game.surface.underground==null:push_error("Original96 missing");await finish(1);return
	var controller:RefCounted=game.surface.underground;var route:Dictionary=controller.current_route(game.surface.globe,game.surface.collision_radii(game.ship))
	game.ship.position=route.interior_local_m+Vector3.UP*20;game.ship.external_view=true;game._sync_scene()
	if not await save_frame("03-original-underground-hangar.png",route.interior_local_m+Vector3(90,24,70),route.interior_local_m+Vector3(0,18,-40)):await finish(1);return
	var file:=FileAccess.open(OUTPUT+"/capture-manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(captures,"\t"));file.close()
	print("SOURCE FULL CAPTURES PASS: %d actual Main frames, no phone-performance claim"%captures.size());await finish(0)
