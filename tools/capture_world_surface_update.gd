extends SceneTree
# Actual Main scene comparison. Only camera/paused review poses and a documented
# shader-clock fixture differ from ordinary play. No saved progress is accessed.
const World=preload("res://scripts/planetary_system.gd")
var output:="res://build/world-surface-screenshots"
var label:="world-current"
var dry_run:=false
var game:Node3D
var records:Array=[]
var shader_clock:Dictionary={}

func _initialize()->void:call_deferred("capture")

func frame()->void:
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw

func dispose_game()->void:
	if is_instance_valid(game):game.queue_free();await process_frame
	game=null

func freeze_planet_shader_clock()->void:
	# RenderingServer exposes no shader-time setter in Godot4.6.3. Freeze only
	# the decorative cloud clock in a capture-local copy of the actual shader.
	# Copy every parameter explicitly when assigning the equivalent shader.
	var source:Shader=game.celestial.PlanetShader
	var expression:=RegEx.new();expression.compile("\\bTIME\\b")
	var frozen:=Shader.new();frozen.code=expression.sub(source.code,"0.0",true)
	for entry:Dictionary in game.celestial.visuals.values():
		var original:ShaderMaterial=entry.mesh.material_override
		var parameters:Dictionary={}
		for uniform:Dictionary in source.get_shader_uniform_list():
			parameters[str(uniform.name)]=original.get_shader_parameter(str(uniform.name))
		var material:ShaderMaterial=original.duplicate();material.shader=frozen
		for name:String in parameters:material.set_shader_parameter(name,parameters[name])
		entry.mesh.material_override=material
	shader_clock={"mode":"capture-only PlanetShader clone: TIME token fixed to literal0.0","source_shader_sha256":source.code.sha256_text(),"frozen_shader_sha256":frozen.code.sha256_text(),"all_existing_uniform_values_preserved":true,"physics_elapsed_days_unchanged":true}

func new_game(body_id:String,layout:String)->bool:
	await dispose_game()
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);await frame()
	game.settings.quality=2;game._apply_settings()
	game.world.configure(game.nav.current(),layout)
	if not game.world.by_id.has(body_id):push_error("Missing real body "+body_id);return false
	game.world.focus_id=body_id;game.world.selected_id=body_id;game.world.site_id=""
	game.ship.docked=false;game.ship.velocity=Vector3.ZERO;game.ship.target_speed=0
	game.ship.external_view=false
	var body:Dictionary=game.world.by_id[body_id]
	var centre:Vector3=game.world.local_meters(body_id,game.nav.elapsed_days)
	var sun:Vector3=game.world.local_meters("star",game.nav.elapsed_days)-centre
	var outward:=sun.normalized()
	if outward.length_squared()<0.5:outward=Vector3.BACK
	game.ship.position=centre+outward*float(body.radius_km)*1000.0*3.3
	game.active=true;game._apply_system();freeze_planet_shader_clock()
	return true

func photograph(name:String,eye:Vector3,target:Vector3,show_ui:bool,review:Dictionary)->bool:
	game.active=true;game._process(0.0);game._sync_scene();game._refresh_hud()
	game.camera.position=eye;game.camera.look_at(game.to_global(target),Vector3.UP)
	game.camera.fov=58;game.ui.visible=show_ui;game.notice_timer=0;game.notice.hide()
	for i in range(4):await frame()
	var body:Dictionary=game.world.by_id[game.world.focus_id]
	var filename:=name+".png"
	if not dry_run:
		var picture:=root.get_texture().get_image()
		if picture==null or picture.is_empty() or picture.get_size()!=root.size:push_error("Incomplete rendered image "+name);return false
		if picture.save_png(output+"/"+filename)!=OK:push_error("Cannot save "+name);return false
	records.append({"file":filename,"label":label,"scene":"actual scenes/main.tscn","kind":"actual Main with fixed review camera and explicit shader-clock fixture","review":review,"body_id":str(body.id),"body_name":str(body.name),"body_kind":str(body.kind),"body_source":str(body.get("source","")),"layout_mode":str(game.world.layout_mode),"source_digest":str(game.world.source_digest),"original_type":int(body.get("original_type",-1)),"system_id":game.world.system_id,"elapsed_days":game.nav.elapsed_days,"quality":game.settings.quality,"shader_clock_fixture":shader_clock.duplicate(true),"camera_position":[eye.x,eye.y,eye.z],"camera_target":[target.x,target.y,target.z],"camera_fov":58,"hud":show_ui,"surface_active":game.surface.active,"surface_kind":str(game.surface.kind) if game.surface.active else "","surface_seed":game.surface.seed_value if game.surface.active else 0,"surface_revision":str(game.surface.globe.revision) if game.surface.active and game.surface.globe!=null else "","game_payload_sha256":var_to_bytes(game._payload()).hex_encode().sha256_text(),"graphics_demo":not game.graphics_return.is_empty(),"decorative_asteroids_visible":game.space_environment.visible,"user_progress_read":false,"user_progress_written":false,"phone_capture":false,"image_composited":false,"dry_run":dry_run})
	return true

func ground(name:String,body_id:String,expected_kind:String,layout:String,show_ui:=false)->bool:
	if not await new_game(body_id,layout):return false
	if str(game.world.by_id[body_id].kind)!=expected_kind:push_error("Actual body kind differs from requested capture "+body_id);return false
	await game._enter_surface()
	if not game.surface.active or game.surface.globe==null:push_error("Actual Main surface entry failed: "+str(game.surface.message));return false
	# The initial empty-site pad is graded within420m. Sample real relief away
	# from it; the surface model supplies the exact rendered/collision height.
	var target:=Vector3(680,0,620);target.y=game.surface.height_at(target.x,target.z)
	game.ship.position=target+Vector3(0,game.surface.clearance(game.ship)+20,0)
	game.ship.velocity=Vector3.ZERO;game.ship.target_speed=0
	var eye:=target+Vector3(0,8,16)
	eye.y=maxf(eye.y,game.surface.height_at(eye.x,eye.z)+8.0)
	# Ensure the line to the target clears every sampled intermediate hill.
	for i in range(1,20):
		var fraction:=float(i)/20.0
		var point:=target.lerp(eye,fraction)
		var needed:float=(game.surface.height_at(point.x,point.z)+0.12-target.y)/fraction
		eye.y=maxf(eye.y,target.y+needed)
	# Enter_surface rebuilds celestial materials; retain the frozen clock copy.
	freeze_planet_shader_clock()
	return await photograph(name,eye,target,show_ui,{"scope":"existing natural ground, outside initial420m pad grading","target_height_m":target.y,"camera_review_pose":true,"body_kind_is_unmodified":true,"adapter_layout":layout==World.SOLAR_LAYOUT})

func orbit(name:String,body_id:String)->bool:
	if not await new_game(body_id,World.SOURCE_LAYOUT):return false
	game._sync_scene()
	var entry:Dictionary=game.celestial.visuals[body_id]
	var target:Vector3=game.to_local(entry.mesh.global_position)
	return await photograph(name,game.ship.position,target,false,{"scope":"existing compressed orbital planet renderer","observer_relative_to_body_radii":3.3,"camera_review_pose":true,"body_kind_is_unmodified":true,"adapter_layout":false})

func capture()->void:
	var args:=OS.get_cmdline_user_args()
	if not "--rebuild-capture" in args:push_error("Needs --rebuild-capture to disable user progress");quit(1);return
	for arg in args:
		if arg.begins_with("--world-capture-output="):output=arg.trim_prefix("--world-capture-output=")
		elif arg.begins_with("--world-capture-label="):label=arg.trim_prefix("--world-capture-label=")
		elif arg=="--world-capture-check-only":dry_run=true
	if DisplayServer.get_name()=="headless" and not dry_run:push_error("Actual image capture requires a rendered viewport");quit(1);return
	if DirAccess.make_dir_recursive_absolute(output)!=OK:push_error("Cannot create capture output");quit(1);return
	root.size=Vector2i(1920,1080)
	var ok:=await ground("01-earth-ground-and-classic-console","earth","earth",World.SOURCE_LAYOUT,true)
	if ok:ok=await ground("02-moon-rock-ground","moon","rock",World.SOURCE_LAYOUT)
	if ok:ok=await ground("03-venus-desert-ground","venus","desert",World.SOURCE_LAYOUT)
	# The source world adapter currently has no ice kind. Pluto's existing
	# explicitly reconstructed Solar layout supplies this fourth material test;
	# it is never presented as an original FFE planet classification.
	if ok:ok=await ground("04-pluto-ice-ground-explicit-solar-adapter","pluto","ice",World.SOLAR_LAYOUT)
	if ok:ok=await orbit("05-earth-from-orbit","earth")
	if ok:ok=await orbit("06-moon-from-orbit","moon")
	await dispose_game()
	if ok:
		var report:={"kind":"actual Main material comparison with fixed camera/clock review fixtures","label":label,"renderer":RenderingServer.get_current_rendering_method(),"display_server":DisplayServer.get_name(),"engine":Engine.get_version_info().string,"viewport_size":[root.size.x,root.size.y],"phone_capture":false,"image_composited":false,"user_progress_read":false,"user_progress_written":false,"native_source_kinds_shown":["earth","rock","desert"],"explicit_reconstructed_solar_ice_fixture":true,"dry_run":dry_run,"captures":records}
		var file:=FileAccess.open(output+"/capture-manifest.json",FileAccess.WRITE)
		if file==null:push_error("Cannot save capture metadata");ok=false
		else:file.store_string(JSON.stringify(report,"\t"));file.close()
	if ok:print("WORLD SURFACE CAPTURES PASS: %d actual Main review frames; 3 source kinds + explicitly labelled Solar adapter ice; dry_run=%s"%[records.size(),str(dry_run)])
	quit(0 if ok else 1)
