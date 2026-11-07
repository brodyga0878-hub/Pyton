extends SceneTree
# External-compatible actual Main capture: run the same script against the
# immutable 0.13.1 archive and this project. Fixture camera/observer changes are
# recorded; only the first frame is the unchanged map -> Approach arrival.
const World=preload("res://scripts/planetary_system.gd")
const Settings=preload("res://scripts/device_settings.gd")
const Surface=preload("res://scripts/surface_model.gd")
const Link=preload("res://scripts/surface_orbit_link.gd")
const BuildInfo=preload("res://scripts/build_info.gd")
class MemorySettings extends Settings:
	func load_file()->bool:quality=1;return false
var game:Node3D
var output:=""
var frames:Array=[]
var failures:Array=[]
var checks:=0
var inputs:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func frame()->void:await process_frame;await RenderingServer.frame_post_draw
func array3(value:Vector3)->Array:return [value.x,value.y,value.z]
func settle()->void:
	var started:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-started<30000:
		game._process(0.0)
		if game.celestial.source_mesh_state().get("status")=="ready":break
		await frame()
	check(game.celestial.source_mesh_state().get("status")=="ready","Actual Mercury source-height globe is ready")
	for index in range(5):game._process(0.0);await frame()
func aim_at(target:Vector3)->void:
	var direction:Vector3=(target-game.ship.position).normalized()
	var up:=Vector3.RIGHT if absf(direction.dot(Vector3.UP))>0.99 else Vector3.UP
	game.ship.attitude=Basis.looking_at(direction,up).get_rotation_quaternion()
	game._apply_system()
func photograph(filename:String,fixture:String)->void:
	await settle()
	game.notice_timer=0.0;game.notice.hide();game._refresh_hud()
	await frame();await frame()
	check(game.automated and not game.saving_enabled,"No player progress is read or written")
	check(root.get_texture().get_image().save_png(output+"/"+filename)==OK,"Actual framebuffer PNG saved")
	var bodies:Dictionary={}
	for id:String in ["mercury","star"]:
		var entry:Dictionary=game.celestial.visuals[id]
		var point:Vector2=game.camera.unproject_position(entry.anchor.global_position)
		bodies[id]={"local_meters":array3(game.world.local_meters(id,game.nav.elapsed_days)),"draw_position":array3(entry.anchor.global_position),"screen_centre":[point.x,point.y],"behind_camera":game.camera.is_position_behind(entry.anchor.global_position),"coverage":entry.mesh.material_override.get_shader_parameter("view_coverage")}
	frames.append({"file":filename,"fixture":fixture,"actual_scene":"scenes/main.tscn","viewport":[root.size.x,root.size.y],"elapsed_days":game.nav.elapsed_days,"ship_position":array3(game.ship.position),"camera_forward":array3(-game.camera.global_basis.z),"console_top":game.flight_console.get_global_rect().position.y,"near_preview":game.near.active,"near_blend":game.near.space_blend,"bodies":bodies,"source_mesh":game.celestial.source_mesh_state(),"composited":false,"physical_phone_capture":false,"performance_benchmark":false,"progress_read_or_written":false})
func run()->void:
	var args:=OS.get_cmdline_user_args()
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in args:push_error("Requires rendered private capture mode");quit(1);return
	var option:=args.find("--capture-output")
	if option<0 or option+1>=args.size():push_error("--capture-output absolute directory is required");quit(1);return
	output=args[option+1];DirAccess.make_dir_recursive_absolute(output)
	for path:String in ["scripts/main.gd","scripts/celestial_renderer.gd","scripts/build_info.gd","scripts/planet.gdshader"]:
		if FileAccess.file_exists("res://"+path):inputs[path]=FileAccess.get_sha256("res://"+path)
	root.size=Vector2i(1440,720)
	game=load("res://scenes/main.tscn").instantiate();game.settings=MemorySettings.new();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);await frame()
	game._new_models(World.FULL_LAYOUT);game._apply_system();game._safe_area()
	game._choose_body("mercury")
	for tick in range(40):
		if game.world.transfer_remaining<=0.0:break
		game._tick(0.1,Vector2.ZERO,0.0)
	check(game.world.focus_id=="mercury" and game.world.transfer_remaining<=0.0,"Actual map Approach transfer reaches Mercury")
	var days:float=game.nav.elapsed_days
	await photograph("01-arrival-front.png","Unchanged actual map -> Approach arrival from fresh FULL Sol at epoch0")
	var centre:Vector3=game.world.local_meters("mercury",days)
	var sun:Vector3=game.world.local_meters("star",days)
	aim_at(centre)
	await photograph("02-arrival-target.png","Same arrival position and time; only turn the ship toward Mercury")
	var sun_direction:Vector3=(sun-centre).normalized()
	game.ship.position=centre+sun_direction*float(game.world.by_id.mercury.radius_km)*4000.0
	aim_at(centre)
	await photograph("03-dayside-orbit.png","Fixture observer at4 reference radii on the daylight side; looking at Mercury")
	aim_at(sun)
	await photograph("04-sun-orbit.png","Same daylight observer position; looking toward the unocculted Sun")
	var globe:RefCounted=Surface.make_globe(game.world,"mercury","",Surface.preferred_terrain_revision(game.world))
	var fixed:Vector3=Link.rotation_basis(game.world,"mercury",days).inverse()*sun_direction
	var latitude:float=asin(clampf(fixed.y,-1.0,1.0))
	var longitude:float=atan2(-fixed.z,fixed.x)
	var elevation:float=globe.elevation(latitude,longitude)
	game.ship.position=centre+sun_direction*(float(globe.radius)+elevation+20000.0)
	aim_at(sun)
	await photograph("05-sun-near-surface.png","Fixture observer20km above actual source-height terrain at solar zenith; looking at Sun")
	check(game.near.active and game.near.space_blend<0.001,"Actual near-surface render transition reaches zero orbital coverage")
	check(game.nav.elapsed_days==days,"Fixture views preserve the exact source epoch")
	for path:String in inputs:check(FileAccess.get_sha256("res://"+path)==inputs[path],"Capture preserves source: "+path)
	var file:=FileAccess.open(output+"/capture-manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":BuildInfo.VERSION,"completed_utc":Time.get_datetime_string_from_system(true),"source_sha256":inputs,"checks":checks,"failures":failures,"frames":frames},"\t"));file.close()
	game.queue_free();await frame()
	print("MERCURY ACTUAL MAIN CAPTURE: %d frames, %d checks, %d failures"%[frames.size(),checks,failures.size()]);quit(0 if failures.is_empty() else 1)
