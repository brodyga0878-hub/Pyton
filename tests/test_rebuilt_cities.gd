extends SceneTree
# NEW reconstruction acceptance tests, adapted from preserved historical QA.
# Actual handcrafted records and native F1674/F650 controls are independent
# of the city compiler. Terrain grading and missing-root UIDs are adaptations.
const Surface=preload("res://scripts/surface_model.gd")
const Sphere=preload("res://scripts/spherical_terrain.gd")
const Profile=preload("res://scripts/source_city_profile.gd")
const Runtime=preload("res://scripts/source_city_runtime.gd")
const Units=preload("res://scripts/source_units.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
const World=preload("res://scripts/planetary_system.gd")
const Galaxy=preload("res://scripts/galaxy.gd")
const Nav=preload("res://scripts/navigation.gd")
const Ship=preload("res://scripts/flight_model.gd")
const Near=preload("res://scripts/near_surface_view.gd")
var checks:=0
var failures:=0
var native_pads:Array=[]
var pad_assets:Dictionary={}
var prepared_models:Dictionary={}
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=20:push_error(message)
func _init()->void:call_deferred("run")
func json_copy(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func equal_numbers(first:Array,second:Array)->bool:
	if first.size()!=second.size():return false
	for index in range(first.size()):
		if int(first[index])!=int(second[index]):return false
	return true
func numeric_target(matrix:Array,model:int,pad_index:int)->Array:
	# Source tables plus an independently executed original F1674 matrix.
	# No SourceGroundPads transformation helper participates in this oracle.
	var table:Dictionary=pad_assets.tables[pad_assets.models[str(model)].table]
	var vector:Array=table.vectors_i32[pad_index]
	var result:Array=[]
	for axis in range(3):
		var component:=0
		for k in range(3):component+=(int(vector[k])*int(matrix[k*3+axis]))>>31
		result.append(component*1024)
	return result
func expected_pad(root:Dictionary,target:Array,radius:float)->Array:
	var radial:Array=root.radial_q31
	var scale:=radius/sqrt(float(radial[0])*float(radial[0])+float(radial[1])*float(radial[1])+float(radial[2])*float(radial[2]))
	var x:=float(radial[0])*scale+float(target[0])*Units.METRES_PER_RAW
	var y:=float(radial[1])*scale+float(target[1])*Units.METRES_PER_RAW
	var z:=float(radial[2])*scale+float(target[2])*Units.METRES_PER_RAW
	return [atan2(y,sqrt(x*x+z*z)),atan2(-z,x)]
func native_profile(site:Dictionary,root:Dictionary,radius:float)->Dictionary:
	var profile:=Profile.describe(site,radius)
	check(not profile.is_empty(),"An eligible actual source settlement has a placement profile: "+str(site.name_en))
	if profile.is_empty():return {}
	var model:=int(site.model_index)
	var native:Dictionary={}
	for row in native_pads:
		if int(row.model_index)==model and row.origin=="all_free":native=row;break
	check(not native.is_empty(),"City model has an independently executed F650 allocation control")
	if native.is_empty():return profile
	check(int(profile.pad_count)==int(native.result.initialized_last_pad_index_i32)+1 and int(profile.pad_index)==int(native.result.selected_pad_i32),"Live city chooses the source model's actual highest free pad")
	check(equal_numbers(profile.source_matrix_q31,root.matrix_q31),"The complete original body-fixed matrix reaches city composition")
	var target:=numeric_target(root.matrix_q31,model,int(profile.pad_index))
	for axis in range(3):
		check(absf(float(profile.pad_offset_body_m[axis])-float(target[axis])*Units.METRES_PER_RAW)<0.004,"Native F650 physical target survives the profile conversion")
	for row in native_pads:
		if int(row.model_index)==model and row.origin=="all_free" and row.get("matrix_source")=="original_f1674" and int(row.ground_phase_u16)==int(root.ground_phase_u16) and int(row.ground_inclination_u16)==int(root.ground_inclination_u16):
			check(equal_numbers(target,row.result.target_vec64_raw),"Composed pad target equals an independently executed F650 at this actual port")
			break
	var expected:=expected_pad(root,target,radius)
	check(absf((float(profile.pad_latitude)-float(expected[0]))*radius)<0.01 and absf(wrapf(float(profile.pad_longitude)-float(expected[1]),-PI,PI)*radius*cos(float(expected[0])))<0.01,"Pad latitude/longitude identify the native pad rather than only the city root")
	check(absf(Profile.plane_height(profile,radius,float(profile.root_latitude),float(profile.root_longitude)))<0.000001,"Adapted city grading is rooted at its stated tangent plane")
	return profile
func verify_geometry(profile:Dictionary,label:String)->void:
	var model:=int(profile.model_index)
	if prepared_models.has(model):return
	var prepared:=Runtime.prepare(profile)
	check(prepared.get("ok",false),"Actual city composition succeeds: "+label+" "+str(prepared.get("error","")))
	if not prepared.get("ok",false):return
	prepared_models[model]=true
	check(prepared.compiled.triangle_count>1000 and prepared.triangles.size()==prepared.compiled.triangle_count,"The composed original city supplies its solid faces to collision")
	check(prepared.bounds.size.x>0 and prepared.bounds.size.z>0 and prepared.cruise_height_m>prepared.bounds.end.y,"Approach cruise clears the actual source city bounds")
	var footprint:=0.0
	for triangle in prepared.triangles:
		for point in triangle:footprint=maxf(footprint,Vector2(point.x,point.z).length())
	check(footprint<float(profile.flat_inner_m),"The terrain grading covers the complete original city footprint: %s (mesh%.2f, inner%.2f)"%[label,footprint,float(profile.flat_inner_m)])
	var too_small:=profile.duplicate(true);too_small.flat_inner_m=footprint-1.0
	var before_cache:=Runtime.cache_size()
	check(not Runtime.prepare(too_small).get("ok",false) and Runtime.cache_size()==before_cache,"A cache hit still rejects an inadequate grade region without mutating the cache")
func handcrafted_controls()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ground_coordinates_reference.json"))
	var galaxy:=Galaxy.new();var total:=0;var eligible:=0;var unsupported:=0
	for root in fixture.cases:
		if root.origin!="handcrafted":continue
		var world:=World.new();world.configure(galaxy.get_system(int(root.system_id)))
		var site:Dictionary={}
		for candidate in world.settlements:
			if int(candidate.type_code)==35 and candidate.name_en==root.name_en:site=candidate;break
		check(not site.is_empty(),"Every native handcrafted port resolves to the live world adapter")
		if site.is_empty():continue
		total+=1
		var radius:=float(world.by_id[str(site.parent)].radius_km)*1000.0
		var globe:=Sphere.new();globe.configure(world,str(site.parent),str(site.id),Sphere.CITY_REVISION)
		if int(site.model_index)==96:
			unsupported+=1
			check(Profile.describe(site,radius).is_empty() and not globe.city_profiles.has(str(site.id)),"Underground model96 has no invented open-air landing profile")
			world.site_id=str(site.id);world.focus_id=str(site.parent)
			var underground_ship:=Ship.new();var underground_surface:=Surface.new()
			var before_flight:=JSON.stringify(underground_ship.snapshot());var before_surface:=JSON.stringify(underground_surface.snapshot())
			check(not underground_surface.enter(underground_ship,world,true),"The unimplemented underground entrance rejects open-air entry: "+str(site.name_en))
			check(JSON.stringify(underground_ship.snapshot())==before_flight and JSON.stringify(underground_surface.snapshot())==before_surface and underground_surface.city_data.is_empty(),"An unsupported underground approach leaves the ship and surface unchanged")
			continue
		eligible+=1
		var profile:=native_profile(site,root,radius)
		if profile.is_empty():continue
		check(globe.city_profiles.has(str(site.id)),"Current geography retains every eligible source city on this body")
		check(absf(float(globe.pad_latitude)-float(profile.pad_latitude))<1e-12 and absf(float(globe.pad_longitude)-float(profile.pad_longitude))<1e-12,"Selecting a city uses its actual chosen landing pad")
		var root_point:Array=globe.site_coordinates(str(site.id))
		check(absf(float(root_point[0])-float(profile.root_latitude))<1e-12 and absf(float(root_point[1])-float(profile.root_longitude))<1e-12,"The original city root remains separate from its selected pad")
		verify_geometry(profile,str(site.name_en))
	check(total==21 and eligible==19 and unsupported==2,"All21 actual handcrafted ground ports are accounted for, including the two underground model96 exclusions")
func controlled_missing_root_geometry()->void:
	# These four source models do not occur in the bounded handcrafted catalogue.
	# The matrices/F650 targets are native controls; their diagnostic UID does
	# NOT stand for a recovered procedural system or native F871 generation.
	for model in [86,87,88,89]:
		var native:Dictionary={}
		for row in native_pads:
			if int(row.model_index)==model and row.origin=="all_free" and row.get("matrix_source")=="original_f1674":native=row;break
		check(not native.is_empty(),"Native F650/F1674 control exists for model%d"%model)
		if native.is_empty():continue
		var site:=Ground.from_record(int(native.ground_phase_u16),int(native.ground_inclination_u16))
		site.merge({"id":"controlled-root%d"%model,"name_en":"controlled root%d"%model,"type_code":35,"model_index":model,"source_seed":0xbdd3aa2e})
		var profile:=Profile.describe(site,6371000.0)
		check(not profile.is_empty(),"Controlled original root has a source profile")
		if profile.is_empty():continue
		var target:=numeric_target(profile.source_matrix_q31,model,int(profile.pad_index))
		check(equal_numbers(target,native.result.target_vec64_raw),"Controlled root uses independently executed native F650 target")
		verify_geometry(profile,"controlled model%d"%model)
	check(prepared_models.size()==10,"All ten original roots81–90 fit verified deterministic grade regions")

func actual_airfield_landings()->void:
	var galaxy:=Galaxy.new();var models:Dictionary={}
	for label in ["Manchester","Epping Newtown"]:
		var world:=World.new();world.configure(galaxy.get_system(111466264))
		var selected:Dictionary={}
		for site in world.settlements:
			if site.name_en==label:selected=site;break
		check(not selected.is_empty(),"Actual airfield city resolves: "+label)
		if selected.is_empty():continue
		world.site_id=str(selected.id);world.focus_id=str(selected.parent)
		var ship:=Ship.new();ship.ship_id="eagle";ship.equipment.append("engine")
		var surface:=Surface.new()
		check(surface.enter(ship,world,true),"Actual airfield approach opens: "+label)
		if not surface.active:continue
		models[int(selected.model_index)]=true
		check(surface.begin_landing(ship),"Actual airfield landing starts: "+label)
		for tick in range(12000):
			surface.step(0.05,ship,Vector2.ZERO,0)
			if surface.landed or ship.hull<=0:break
		check(surface.landed and ship.hull==100 and surface.pad_distance(ship)<40 and not surface.overlaps_building(ship),"Autopilot clears the original airfield buildings and lands at its native selected pad: "+label)
	check(models.has(81) and models.has(82),"Both actual four-pad city models81/82 have completed flight approaches")
func actual_new_moscow()->Dictionary:
	var nav:=Nav.new();var world:=World.new();world.configure(nav.current());world.site_id="site10";world.focus_id="earth";world.selected_id="earth"
	var site:Dictionary=world.current_site()
	check(site.name_en=="New Moscow" and int(site.model_index)==84 and int(site.source_seed)==0xbdd3aa2e,"The actual New Moscow is model84 with its original UID, not a substituted model89")
	var ship:=Ship.new();ship.credits=71923;ship.goods.medicines=4;ship.goods.food=2
	var surface:=Surface.new()
	check(surface.enter(ship,world,true),"Actual New Moscow opens with current source city geography")
	if not surface.active:return {}
	check(surface.globe.revision==Sphere.CITY_REVISION and int(surface.city_data.profile.model_index)==84 and surface.buildings().is_empty(),"Live entry uses original city84 and has no generic ten-box district")
	check(absf(surface.altitude(ship)-1500.0)<0.01 and not surface.overlaps_building(ship),"Initial source city entry is1500metres above terrain and clear of solid geometry")
	check(surface.begin_landing(ship),"Actual source city approach starts")
	var ticks:=0
	for tick in range(16000):
		surface.step(0.05,ship,Vector2.ZERO,0)
		ticks=tick+1
		if surface.landed or ship.hull<=0:break
	check(surface.landed and not surface.landing and ship.hull==100 and surface.pad_distance(ship)<40 and not surface.overlaps_building(ship),"Autopilot safely lands on actual New Moscow's native pad after%d ticks"%ticks)
	if not surface.landed:return {"surface":surface,"ship":ship,"world":world,"nav":nav}
	check(absf(surface.altitude(ship))<0.01 and ship.velocity.length()<0.001,"Touchdown uses the rendered terrain plane without burying the hull at the rounded native padY")
	var saved:Dictionary=json_copy(surface.snapshot());var ship_state:Dictionary=json_copy(ship.snapshot())
	var copy:=Ship.new();check(copy.restore(ship_state),"Landed flight progress decodes from JSON")
	var loaded:=Surface.new();check(loaded.restore(saved,copy,world),"Actual source city landed snapshot restores")
	check(loaded.landed and loaded.globe.revision==Sphere.CITY_REVISION and copy.credits==71923 and int(copy.goods.medicines)==4 and int(copy.goods.food)==2 and copy.hull==100,"City geometry reconstruction preserves landed progress")
	check(loaded.take_off(copy),"A restored source city pad supports takeoff")
	for tick in range(1000):
		loaded.step(0.05,copy,Vector2.ZERO,0)
		if not loaded.taking_off:break
	check(not loaded.landed and not loaded.taking_off and loaded.altitude(copy)>=34.5 and copy.hull==100 and not loaded.overlaps_building(copy),"Takeoff leaves the real source pad clear of buildings")
	copy.position.y=loaded.height_at(copy.position.x,copy.position.z)+loaded.clearance(copy)+700;copy.velocity=Vector3.ZERO
	var departure:Array=loaded.geographic_position(copy)
	check(loaded.leave(copy,world,nav.elapsed_days),"Source city flight hands off to geographic orbit")
	world.site_id=""
	var fresh_ship:=Ship.new();check(fresh_ship.restore(json_copy(copy.snapshot())),"Orbital flight snapshot restores")
	var fresh:=Surface.new();check(fresh.restore(json_copy(loaded.snapshot()),fresh_ship,world),"Source city orbital metadata restores without a retained city object")
	var preview:=Near.new();check(preview.update(fresh,fresh_ship,world,nav.elapsed_days),"A fresh source city orbital save prepares a near-surface preview")
	if preview.active:
		check(not preview.drawing.city_data.is_empty() and int(preview.drawing.city_data.profile.model_index)==84 and preview.drawing.globe.revision==Sphere.CITY_REVISION,"Orbital preview rebuilds the same actual source city")
		check(preview.enter_descent(fresh,fresh_ship,world,nav.elapsed_days),"The same source city can be re-entered after orbital JSON reload")
		check(fresh.active and fresh.globe.revision==Sphere.CITY_REVISION and int(fresh.city_data.profile.model_index)==84 and absf(fresh.geographic_position(fresh_ship)[0]-float(departure[0]))<1e-10 and absf(wrapf(fresh.geographic_position(fresh_ship)[1]-float(departure[1]),-PI,PI))<1e-10,"Re-entry preserves departure geography and source city identity")
		check(fresh_ship.credits==71923 and int(fresh_ship.goods.medicines)==4 and int(fresh_ship.goods.food)==2 and fresh_ship.hull==100,"Landing, takeoff, orbital reload and re-entry preserve money, cargo and hull")
	return {"surface":surface,"ship":ship,"world":world,"nav":nav}
func hard_source_pad_contact()->void:
	var nav:=Nav.new();var world:=World.new();world.configure(nav.current());world.site_id="site10";world.focus_id="earth"
	var ship:=Ship.new();var surface:=Surface.new()
	check(surface.enter(ship,world,true),"Hard-contact control opens the real source city")
	if not surface.active:return
	var pad:Vector3=surface.pad_position()
	ship.position=Vector3(pad.x,pad.y+surface.clearance(ship)+5,pad.z);ship.velocity=Vector3.DOWN*20
	ship.assisted=true;ship.target_speed=0;surface.landing=false
	surface.step(0.5,ship,Vector2.ZERO,0)
	check(surface.landed and ship.hull>0 and ship.hull<100 and ship.velocity==Vector3.ZERO,"A fast manual impact on the actual source pad lands with finite single-impact damage")
	var hull:float=ship.hull
	surface.step(0.5,ship,Vector2.ZERO,0)
	check(ship.hull==hull and surface.landed and absf(surface.altitude(ship))<0.01,"The same source floor contact cannot damage a stationary landed ship again")
func atomic_rejection()->void:
	var nav:=Nav.new();var world:=World.new();world.configure(nav.current());world.site_id="site10";world.focus_id="earth"
	var broken:Dictionary=world.current_site()
	var original_seed:Variant=broken.source_seed;broken.erase("source_seed")
	var ship:=Ship.new();ship.credits=7111;ship.position=Vector3(23,45,67);ship.velocity=Vector3(1,2,3)
	var surface:=Surface.new();surface.site_name="sentinel";surface.city_data={"sentinel":true};surface.seed_value=773
	var before_flight:=JSON.stringify(ship.snapshot());var before_surface:=JSON.stringify(surface.snapshot())
	check(not surface.enter(ship,world,true),"An eligible source city with missing initialized data rejects entry")
	check(JSON.stringify(ship.snapshot())==before_flight and JSON.stringify(surface.snapshot())==before_surface and surface.site_name=="sentinel" and surface.seed_value==773 and surface.city_data=={"sentinel":true},"Failed city preparation leaves the live ship and surface state unchanged")
	broken.source_seed=original_seed
	check(surface.enter(ship,world,true),"The same state can enter after its source metadata is repaired")
	var state:Dictionary=json_copy(surface.snapshot());before_flight=JSON.stringify(ship.snapshot());before_surface=JSON.stringify(surface.snapshot())
	broken.erase("source_seed")
	check(not surface.restore(state,ship,world),"A save cannot silently replace missing original city geometry with generic buildings")
	check(JSON.stringify(ship.snapshot())==before_flight and JSON.stringify(surface.snapshot())==before_surface,"Failed city restoration is atomic")
	broken.source_seed=original_seed
func legacy_and_fast_controls()->void:
	var world:=World.new();world.configure(Nav.new().current());world.site_id="site10";world.focus_id="earth"
	for revision in [Sphere.REVISION,Sphere.SOURCE_REVISION]:
		var ship:=Ship.new();var surface:=Surface.new()
		check(surface.enter(ship,world,true,revision),"Explicit legacy terrain entry still works: "+revision)
		check(surface.city_data.is_empty() and surface.buildings().size()==10,"Legacy revision keeps its own former city geography")
		var ll:Array=surface.geographic_position(ship)
		var saved:Dictionary=json_copy(surface.snapshot());var loaded:=Surface.new()
		check(loaded.restore(saved,ship,world) and loaded.globe.revision==revision,"Legacy snapshot retains its declared terrain revision")
		if loaded.globe:
			var after:Array=loaded.geographic_position(ship)
			check(absf(float(ll[0])-float(after[0]))<1e-12 and absf(float(ll[1])-float(after[1]))<1e-12,"Legacy loading never silently moves the saved geography")
	var ship:=Ship.new();var surface:=Surface.new()
	check(surface.enter(ship,world,true),"Fast native-floor CCD control opens New Moscow")
	var pad:=surface.pad_position()
	var hit:=Runtime.sweep(surface.city_data,surface.globe,pad+Vector3.UP*10000,pad-Vector3.UP*10000,surface.collision_radii(ship))
	check(not hit.is_empty() and float(hit.time)>0.45 and float(hit.time)<0.51 and hit.normal.y>0.99,"A 20-km segment cannot tunnel through the real city landing floor")
	var profile:Dictionary=surface.city_data.profile
	# prepare() may run on the one loading worker used by Main. The source
	# descriptor and sine tables have already been loaded on the main thread.
	var worker:=Thread.new()
	check(worker.start(func()->Dictionary:return Runtime.prepare(profile))==OK,"Loading worker starts using immutable source placement")
	var foreground:=Runtime.prepare(profile)
	var background:Variant=worker.wait_to_finish()
	check(foreground.get("ok",false) and background is Dictionary and background.get("ok",false) and foreground.cache_key==background.cache_key,"Main/worker requests safely share one published geometry cache entry")
func run()->void:
	var started:=Time.get_ticks_usec()
	native_pads=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ground_pads_reference.json")).cases
	pad_assets=JSON.parse_string(FileAccess.get_file_as_string("res://data/ffe_ground_pads.json"))
	handcrafted_controls();controlled_missing_root_geometry();actual_airfield_landings();actual_new_moscow();hard_source_pad_contact();atomic_rejection();legacy_and_fast_controls()
	print("Source city integration elapsed: %.2f seconds"%((Time.get_ticks_usec()-started)/1000000.0))
	print("REBUILT CITY SURFACE TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
