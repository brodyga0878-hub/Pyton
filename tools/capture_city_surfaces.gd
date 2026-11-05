extends SceneTree
const SourceVisual=preload("res://scripts/source_model_visual.gd")
# Actual Main scene only. Compatible with the 0.11.6 baseline: camera selection
# uses original geometry, never the new material roles or texture parameters.
# No progress reads/writes, extra geometry, lighting changes or image compositing.
var output:="res://build/city-screenshots"
var label:="city-current"
var game:Node3D
var records:Array=[]

func _initialize()->void:call_deferred("capture")

func frame()->void:
	await process_frame
	await RenderingServer.frame_post_draw

func photograph(name:String,eye:Vector3,target:Vector3,show_ui:=false,selection:Dictionary={})->bool:
	game.active=true;game._process(0.0);game._sync_scene();game._refresh_hud()
	game.camera.position=eye;game.camera.look_at(game.to_global(target),Vector3.UP)
	game.camera.fov=58;game.ui.visible=show_ui;game.notice_timer=0;game.notice.hide()
	for i in range(4):await frame()
	var path:=output+"/"+name+".png"
	if root.get_texture().get_image().save_png(path)!=OK:push_error("Cannot save "+path);return false
	records.append({"file":name+".png","label":label,"source":"actual scenes/main.tscn","renderer":"gl_compatibility","quality":game.settings.quality,"graphics_demo":not game.graphics_return.is_empty(),"decorative_asteroids_visible":game.space_environment.visible,"camera_position":[eye.x,eye.y,eye.z],"camera_target":[target.x,target.y,target.z],"camera_fov":58,"hud":show_ui,"source_model":84,"site":"Earth/site10 New Moscow","elapsed_days":game.nav.elapsed_days,"selection":selection,"phone_capture":false,"fixture":"Real source city entered and landed through existing Surface model; fixed camera only."})
	return true

func source_surfaces(pad:Vector3)->Dictionary:
	var result:Dictionary={}
	var city:Node3D=game.city_view.current_visual()
	if city==null:return result
	# Reproduce the existing renderer's stable lit/unlit batch order from the
	# original source packets. Source model312 is an actual pad marker, so a
	# nearby triangle from that model must not become the road comparison.
	var original_faces:Dictionary={"SourceLit":[],"SourceUnlit":[]}
	var pad_triangles:Array=[]
	var conversion:Basis=game.surface.city_data.conversion_basis
	for face:Dictionary in game.surface.city_data.compiled.triangles_raw:
		var appearance:=SourceVisual.face_material(face)
		original_faces["SourceUnlit" if appearance.unlit else "SourceLit"].append(face)
		if int(face.get("model_index",-1))==312:
			var triangle:=PackedVector2Array()
			for point in face.vertices:
				var local:Vector3=game.to_local(city.to_global(SourceVisual._point(point,conversion)))
				triangle.append(Vector2(local.x,local.z))
			pad_triangles.append(triangle)
	var best:Dictionary={"road":INF,"facade":INF,"roof":INF}
	for name in ["SourceLit","SourceUnlit"]:
		if not city.has_node(name):continue
		var faces:MeshInstance3D=city.get_node(name)
		var arrays:Array=faces.mesh.surface_get_arrays(0)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var palette:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		if original_faces[name].size()*3!=vertices.size():
			push_error("Source packet order does not match "+name);return {}
		for index in range(0,vertices.size(),3):
			var original:Dictionary=original_faces[name][index/3]
			var a:Vector3=game.to_local(faces.to_global(vertices[index]))
			var b:Vector3=game.to_local(faces.to_global(vertices[index+1]))
			var c:Vector3=game.to_local(faces.to_global(vertices[index+2]))
			var cross:Vector3=(b-a).cross(c-a)
			var area:float=cross.length()*0.5
			if area<100.0:continue
			var inradius:float=2.0*area/maxf(a.distance_to(b)+b.distance_to(c)+c.distance_to(a),0.0001)
			var normal:=cross.normalized();var centre:Vector3=(a+b+c)/3.0
			var distance:float=centre.distance_to(pad)
			var role:=""
			if absf(normal.y)>0.85:
				if absf(centre.y-pad.y)<0.5 and distance>100.0 and distance<1800.0 and int(original.get("model_index",-1))!=312:role="road"
				elif centre.y>pad.y+15.0 and distance<1800.0:role="roof"
			elif absf(normal.y)<0.2 and centre.y>pad.y+5.0 and centre.y<pad.y+180.0 and distance<1800.0:
				role="facade"
			if role.is_empty():continue
			if role=="road":
				# A long, thin source-road triangle can have a large area while
				# covering only a few camera pixels. Use a genuinely wide floor.
				if inradius<8.0:continue
				var overlaps_pad:=false
				for triangle:PackedVector2Array in pad_triangles:
					if Geometry2D.is_point_in_polygon(Vector2(centre.x,centre.z),triangle):overlaps_pad=true;break
				if overlaps_pad:continue
			# The pad-facing side gives an open camera direction for the facade.
			if role=="facade" and normal.dot(pad-centre)<0.0:normal=-normal
			var score:=distance
			var height:float=maxf(a.y,maxf(b.y,c.y))-minf(a.y,minf(b.y,c.y))
			if role=="road":
				var road_colour:Color=palette[index]
				var high:=maxf(road_colour.r,maxf(road_colour.g,road_colour.b))
				var low:=minf(road_colour.r,minf(road_colour.g,road_colour.b))
				score+=(high-low)/maxf(high,0.0001)*2000.0+maxf(0.0,0.06-high)*3000.0+maxf(0.0,high-0.75)*800.0
			if role=="facade":
				# Original linear source palette is also unchanged across releases.
				# Prefer neutral illuminated walls of a frameable size over the
				# nearer saturated, unlit decorative marks in this particular city.
				var colour:Color=palette[index]
				var high:=maxf(colour.r,maxf(colour.g,colour.b))
				var low:=minf(colour.r,minf(colour.g,colour.b))
				var saturation:float=(high-low)/maxf(high,0.0001)
				score+=saturation*6000.0
				if name=="SourceUnlit":score+=6000.0
				if high<0.12:score+=3000.0
				score+=maxf(0.0,height-45.0)*80.0
			if score>=float(best[role]):continue
			best[role]=score
			result[role]={"centre":centre,"normal":normal,"area_m2":area,"height_m":height,"inradius_m":inradius,"batch":name,"triangle_index":index/3,"source_model_index":int(original.get("model_index",-1)),"material_code":int(original.get("material_code",0)),"instance_path":str(original.get("instance_path","")),"offset":int(original.get("offset",-1))}
	return result

func selection_metadata(surface:Dictionary)->Dictionary:
	var result:Dictionary={}
	for key in ["area_m2","height_m","inradius_m","batch","triangle_index","source_model_index","material_code","instance_path","offset"]:result[key]=surface[key]
	return result

func capture()->void:
	var args:=OS.get_cmdline_user_args()
	if not "--rebuild-capture" in args or DisplayServer.get_name()=="headless":
		push_error("Needs --rebuild-capture and real rendering");quit(1);return
	for arg in args:
		if arg.begins_with("--city-capture-output="):output=arg.trim_prefix("--city-capture-output=")
		elif arg.begins_with("--city-capture-label="):label=arg.trim_prefix("--city-capture-label=")
	if DirAccess.make_dir_recursive_absolute(output)!=OK:push_error("Cannot create "+output);quit(1);return
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false)
	await frame()
	game.settings.quality=2;game._apply_settings();game.ship.external_view=true
	game.world.focus_id="earth";game.world.selected_id="earth";game.world.site_id="site10";game._apply_system()
	await game._enter_surface()
	game.surface.begin_landing(game.ship)
	for step in range(24000):
		game.surface.step(0.05,game.ship,Vector2.ZERO,0)
		if game.surface.landed:break
	if not game.surface.landed:
		push_error("Actual source city landing failed");game.queue_free();await process_frame;quit(1);return
	game.ship.external_view=true;game._sync_scene()
	var city:Node3D=game.city_view.current_visual()
	if city==null or city.source_model_index!=84:
		push_error("Expected real source city84");game.queue_free();await process_frame;quit(1);return
	var pad:Vector3=game.surface.pad_position()
	var selected:=source_surfaces(pad)
	for role in ["road","facade","roof"]:
		if not selected.has(role):
			push_error("No existing source surface for "+role);game.queue_free();await process_frame;quit(1);return
	var ok:=true
	ok=await photograph("01-city-and-classic-console",pad+Vector3(60,45,70),pad+Vector3(0,8,0),true) and ok
	ok=await photograph("02-pad-and-ship",pad+Vector3(-27,23,35),game.ship.position+Vector3(0,0,-3)) and ok
	var road:Dictionary=selected.road
	var road_target:Vector3=road.centre
	ok=await photograph("03-road",road_target+Vector3(0,9,12),road_target,false,selection_metadata(road)) and ok
	var facade:Dictionary=selected.facade
	var facade_target:Vector3=facade.centre
	var outward:Vector3=facade.normal
	var facade_distance:=clampf(maxf(sqrt(float(facade.area_m2))*0.65,float(facade.height_m)*0.95),24.0,35.0)
	var facade_metadata:=selection_metadata(facade)
	facade_metadata["selection_rule"]="Original palette: prefer neutral lit wall, moderate height, then distance."
	ok=await photograph("04-facade",facade_target+outward*facade_distance+Vector3.UP*3.0,facade_target,false,facade_metadata) and ok
	var roof:Dictionary=selected.roof
	var roof_target:Vector3=roof.centre
	ok=await photograph("05-roof",roof_target+Vector3(13,11,18),roof_target,false,selection_metadata(roof)) and ok
	var file:=FileAccess.open(output+"/capture-manifest.json",FileAccess.WRITE)
	if file==null:push_error("Cannot write capture manifest");ok=false
	else:file.store_string(JSON.stringify(records,"\t"));file.close()
	if ok:print("CITY SURFACE CAPTURES PASS: %d actual Main city84 frames; immutable geometry camera selection, label %s"%[records.size(),label])
	game.queue_free();await process_frame;quit(0 if ok else 1)
