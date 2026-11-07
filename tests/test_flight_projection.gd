extends SceneTree
# Actual Main regression for the console's optical-centre correction. The
# independent Camera3D keeps Godot's original perspective semantics, including
# KEEP_WIDTH/KEEP_HEIGHT. No body, orbit, ship attitude or clock is corrected.
const World=preload("res://scripts/planetary_system.gd")
const Settings=preload("res://scripts/device_settings.gd")
const Store=preload("res://scripts/save_store.gd")
class MemorySettings extends Settings:
	func load_file()->bool:quality=0;return false
class MemoryStore extends Store:
	var writes:=0
	func write(_payload:Dictionary)->bool:writes+=1;return true
var game:Node3D
var baseline:Camera3D
var checks:=0
var failures:=0
var evidence:Array=[]

func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func copied(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func payload()->PackedByteArray:return var_to_bytes(game._payload())
func identities()->Array:return [game.ship,game.world,game.nav,game.surface,game.source_motion]
func prepare_baseline()->void:
	baseline.keep_aspect=game.camera.keep_aspect
	baseline.set_perspective(game.camera.fov,game.camera.near,game.camera.far)
	baseline.global_transform=game.camera.global_transform
func record_projection(label:String)->void:
	var centre:Vector2=game.camera.unproject_position(game.camera.global_position-game.camera.global_basis.z*1000.0)
	evidence.append({"case":label,"viewport":[get_root().get_visible_rect().size.x,get_root().get_visible_rect().size.y],"flight_rect":str(game.flight_view_rect),"optical_centre":str(centre),"reticle_centre":str(game.flight_reticle.get_global_rect().get_center()),"cross_centre":str(game.flight_cross.get_global_rect().get_center()),"fov":game.camera.fov,"near":game.camera.near,"far":game.camera.far,"keep_aspect":game.camera.keep_aspect,"godot_builtin_ray_forward_dot":game.camera.project_ray_normal(centre).dot(-game.camera.global_basis.z)})

func inspect_projection(label:String)->void:
	# Establish a quiescent payload once before comparing this presentation call.
	var before:=payload();var models:=identities();var pose:Transform3D=game.camera.global_transform
	var rate:=var_to_bytes(game.flight_time.snapshot());var raw:=var_to_bytes(game.source_motion.snapshot())
	var fov:float=game.camera.fov;var near_plane:float=game.camera.near;var far_plane:float=game.camera.far
	game._update_flight_projection();prepare_baseline()
	check(payload()==before and identities()==models,label+": projection preserves the entire source payload and every live model identity")
	check(game.camera.global_transform==pose and game.camera.fov==fov and game.camera.near==near_plane and game.camera.far==far_plane,label+": physical camera pose, FOV and clipping planes remain unchanged")
	check(var_to_bytes(game.flight_time.snapshot())==rate and var_to_bytes(game.source_motion.snapshot())==raw,label+": selected time rate and exact raw/fractional continuation remain untouched")
	var forward:Vector3=-game.camera.global_basis.z
	var forward_point:Vector3=game.camera.global_position+forward*1000.0
	var centre:Vector2=game.camera.unproject_position(forward_point)
	var old_centre:Vector2=baseline.unproject_position(forward_point)
	check(centre.distance_to(game.flight_view_rect.get_center())<0.05,label+": camera forward projects to the usable flight-window centre")
	check(centre.distance_to(game.flight_reticle.get_global_rect().get_center())<0.05 and centre.distance_to(game.flight_cross.get_global_rect().get_center())<0.05,label+": real reticle and cross share the optical centre")
	var projection:Projection=game.camera.get_camera_projection();var old_projection:Projection=baseline.get_camera_projection()
	# Godot4.6.3's project_ray_normal uses its symmetric perspective helper
	# even for FRUSTUM and omits frustum_offset. Check the ray from the ACTUAL
	# GPU projection matrix; record the built-in helper limitation separately.
	var viewport_rect:Rect2=root.get_visible_rect()
	var ndc:Vector2=(centre-viewport_rect.position)/viewport_rect.size*2.0-Vector2.ONE
	var homogeneous:Vector4=projection.inverse()*Vector4(ndc.x,-ndc.y,-1.0,1.0)
	var camera_ray:=Vector3(homogeneous.x,homogeneous.y,homogeneous.z)/homogeneous.w
	check((game.camera.global_basis*camera_ray).normalized().dot(forward)>0.999999,label+": actual frustum ray through the reticle follows the unchanged camera forward axis")
	check(absf(projection.x.x-old_projection.x.x)<0.000001 and absf(projection.y.y-old_projection.y.y)<0.000001,label+": independent Godot perspective confirms unchanged horizontal and vertical angular scale")
	var shift:Vector2=centre-old_centre
	for depth:float in [10.0,1000.0,50000.0]:
		for offset:Vector2 in [Vector2(-0.25,0),Vector2(0.25,0),Vector2(0,-0.2),Vector2(0,0.2),Vector2(0.17,-0.13)]:
			var point:Vector3=game.camera.global_position+(forward+game.camera.global_basis.x*offset.x+game.camera.global_basis.y*offset.y)*depth
			check((game.camera.unproject_position(point)-baseline.unproject_position(point)).distance_to(shift)<0.05,label+": projected source directions retain their scale at depth%.0f offset%s"%[depth,str(offset)])
	var stable:Projection=game.camera.get_camera_projection();var signature:Array=game._flight_projection_signature.duplicate(true)
	game._update_flight_projection()
	check(game.camera.get_camera_projection()==stable and game._flight_projection_signature==signature and payload()==before,label+": unchanged presentation calls are idempotent")
	record_projection(label)

func mercury_arrival()->void:
	game._new_models(World.FULL_LAYOUT);game._apply_system();game._refresh_hud();game._safe_area()
	check(game.world.layout_mode==World.FULL_LAYOUT and game.nav.is_native() and game.nav.elapsed_days==0.0,"Fixture starts an actual new source-Sol session at its original epoch")
	game._choose_body("mercury")
	check(game.world.pending_id=="mercury" and game.world.transfer_remaining>0,"Real Main body command starts the Mercury transfer")
	for step in range(31):game._tick(0.1,Vector2.ZERO,0.0)
	game._process(0.0);await process_frame
	check(game.world.focus_id=="mercury" and game.world.transfer_remaining==0 and not game.surface.active,"Actual Main finishes the Mercury transfer and configures its orbital scene")
	check(absf(game.nav.elapsed_days-0.306423533385459)<0.00001 and game.ship.hull==100 and game.ship.attitude==Quaternion.IDENTITY,"Mercury regression retains the original transfer chronology, healthy ship and unchanged arrival attitude")
	inspect_projection("Mercury arrival 1440x720")
	prepare_baseline()
	var centre:Vector3=game.to_global(game.world.local_meters("mercury",game.nav.elapsed_days))
	var old_screen:Vector2=baseline.unproject_position(centre);var fixed_screen:Vector2=game.camera.unproject_position(centre)
	var console_top:float=game.flight_console.get_global_rect().position.y
	check(absf(old_screen.y-493.766)<0.2 and old_screen.y>console_top,"Independent old perspective reproduces Mercury behind the real console at y493.8 versus y480")
	check(absf(fixed_screen.y-373.766)<0.2 and game.flight_view_rect.has_point(fixed_screen),"Actual corrected camera reveals the same Mercury centre above the console at y373.8")
	check(absf(old_screen.x-fixed_screen.x)<0.05 and absf(old_screen.y-fixed_screen.y-120.0)<0.05,"Mercury is revealed by optical-centre shift alone, with no angular rescale")
	var mercury:Vector3=game.world.local_meters("mercury",game.nav.elapsed_days)-game.ship.position
	var sun:Vector3=game.world.local_meters("star",game.nav.elapsed_days)-game.ship.position
	var separation:float=mercury.angle_to(sun)
	var mercury_radius:float=asin(float(game.world.by_id.mercury.radius_km)*1000.0/mercury.length())
	var sun_radius:float=asin(float(game.world.by_id.star.radius_km)*1000.0/sun.length())
	check(separation+sun_radius<mercury_radius and absf(rad_to_deg(separation)-11.8194)<0.01,"Actual World retains the real initial Sun/Mercury occultation; the presentation fix does not invent a visible Sun")
	check(not game._decode_state(copied(game._payload())).is_empty(),"Actual Mercury source session still round-trips through strict Main save decoding")
	evidence.append({"case":"actual_mercury_regression","old_screen":[old_screen.x,old_screen.y],"fixed_screen":[fixed_screen.x,fixed_screen.y],"console_top":console_top,"sun_mercury_separation_deg":rad_to_deg(separation),"mercury_angular_radius_deg":rad_to_deg(mercury_radius),"sun_angular_radius_deg":rad_to_deg(sun_radius),"elapsed_days":game.nav.elapsed_days})

func changes_and_views()->void:
	game._request_time_rate(100)
	check(game.flight_time.requested_rate==100,"Actual time control selection is established before presentation-only checks")
	for dimensions:Vector2i in [Vector2i(1440,720),Vector2i(2316,1080),Vector2i(960,540)]:
		root.size=dimensions;await process_frame;await process_frame;game._safe_area()
		for aspect:int in [Camera3D.KEEP_HEIGHT,Camera3D.KEEP_WIDTH]:
			game.camera.keep_aspect=aspect
			for planes:Array in [[74.0,0.5,180000.0],[52.0,2.0,6000000.0],[96.0,0.05,10000.0]]:
				game.camera.fov=planes[0];game.camera.near=planes[1];game.camera.far=planes[2]
				inspect_projection("viewport%s aspect%d FOV%.0f"%[str(dimensions),aspect,float(planes[0])])
		# Simulate unequal phone safe-area insets on the real UI container. This
		# verifies its anchor/projection contract, not an Android OS safe-area API.
		game.ui.offset_left=36;game.ui.offset_top=18;game.ui.offset_right=-12;game.ui.offset_bottom=-8
		await process_frame;await process_frame
		inspect_projection("asymmetric safe-area "+str(dimensions))
		game._safe_area();inspect_projection("actual safe-area hook "+str(dimensions))
	root.size=Vector2i(1440,720);await process_frame;await process_frame;game._safe_area()
	game.camera.keep_aspect=Camera3D.KEEP_HEIGHT;game.camera.fov=74;game.camera.near=0.5;game.camera.far=180000
	var position:Vector3=game.ship.position;var velocity:Vector3=game.ship.velocity;var attitude:Quaternion=game.ship.attitude;var days:float=game.nav.elapsed_days
	for view_key:String in ["front","rear","external"]:
		if game.instruments.view_key(game.ship.external_view)!=view_key:game.flight_console.buttons.view.pressed.emit()
		game._process(0.0)
		check(game.instruments.view_key(game.ship.external_view)==view_key,"Actual console selects the requested "+view_key+" camera")
		var expected:Dictionary=game.instruments.camera_pose(game.ship.position,game.ship.attitude,game.ship.external_view,float(game.ship.profile().visual_span_m))
		check(game.camera.position.is_equal_approx(expected.position) and absf(game.camera.quaternion.dot(expected.attitude))>0.999999,"Projection keeps the actual "+view_key+" camera pose selected by the existing camera controller")
		inspect_projection("principal view "+view_key)
		check(game.ship.position==position and game.ship.velocity==velocity and game.ship.attitude==attitude and game.nav.elapsed_days==days,"The "+view_key+" view and projection leave physical ship position, velocity, attitude and source time unchanged")
	check(game.flight_time.requested_rate==100,"Projection, resize, safe-area and all principal views preserve selected time acceleration")
	# Compatibility: loading an old save must not acquire source-motion opt-in
	# merely because its camera is now projected above the lower console.
	var legacy:Dictionary=copied(game._payload());legacy.erase("motion_session")
	var decoded:Dictionary=game._decode_state(legacy)
	check(not decoded.is_empty() and not decoded.source_motion_enabled,"Pre-opt-in source save still decodes with its original motion policy")
	if not decoded.is_empty():
		game._commit_state(decoded);game._apply_system();game._process(0.0);game.flight_time.request_rate(10)
		inspect_projection("restored legacy source save")
		check(not game.source_motion_enabled and game.flight_time.requested_rate==10,"Projection cannot enable new motion or reset the selected session rate after legacy restore")

func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires safe --rebuild-capture mode");quit(1);return
	root.size=Vector2i(1440,720)
	game=load("res://scenes/main.tscn").instantiate();game.settings=MemorySettings.new();game.saves=MemoryStore.new();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);await process_frame;await process_frame
	baseline=Camera3D.new();root.add_child(baseline)
	check(game.automated and not game.saving_enabled and game.saves.writes==0,"Private capture mode keeps actual player progress untouched")
	await mercury_arrival();await changes_and_views()
	check(game.saves.writes==0,"All actual Main transfer, camera and restoration checks write zero user-progress saves")
	print("FLIGHT PROJECTION EVIDENCE: ",JSON.stringify(evidence))
	baseline.queue_free();game.queue_free();await process_frame
	print("FLIGHT PROJECTION TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
