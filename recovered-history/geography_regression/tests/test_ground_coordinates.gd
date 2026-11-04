extends SceneTree
const Ground=preload("res://scripts/ground_coordinates.gd")
const Sphere=preload("res://scripts/spherical_terrain.gd")
const Surface=preload("res://scripts/surface_model.gd")
const Link=preload("res://scripts/surface_orbit_link.gd")
const Near=preload("res://scripts/near_surface_view.gd")
const World=preload("res://scripts/planetary_system.gd")
const Nav=preload("res://scripts/navigation.gd")
const Ship=preload("res://scripts/flight_model.gd")
const Adapter=preload("res://scripts/procedural_worlds.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<16:push_error(message)
func _init()->void:call_deferred("run")
func json_copy(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func close_point(first:Array,second:Array,tolerance:=1e-12)->bool:
	return absf(float(first[0])-float(second[0]))<tolerance and absf(wrapf(float(first[1])-float(second[1]),-PI,PI))<tolerance
func boxes_equal(surface:RefCounted,expected:Array)->bool:
	var boxes:Array=surface.buildings()
	if boxes.size()!=expected.size():return false
	for index in range(boxes.size()):
		var row:Array=expected[index];var box:AABB=boxes[index]
		if box.position.distance_to(Vector3(row[0],row[1],row[2]))>0.02 or box.size.distance_to(Vector3(row[3],row[4],row[5]))>0.02:return false
	return true
func verify_legacy_geometry(surface:RefCounted,expected:Dictionary)->void:
	check(surface.globe.revision==Sphere.REVISION,"Previous saves remain on their original geography: "+expected.label)
	check(close_point([surface.globe.pad_latitude,surface.globe.pad_longitude],expected.pad_coordinates),"Previous landing target is not moved: "+expected.label)
	for sample in expected.height_samples:
		check(absf(surface.height_at(float(sample[0]),float(sample[1]))-float(sample[2]))<0.0001,"Previous collision terrain remains unchanged: "+expected.label)
	check(boxes_equal(surface,expected.buildings),"Previous building volumes remain unchanged: "+expected.label)
func native_controls()->Dictionary:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ground_coordinates_reference.json"))
	check(fixture.cases.size()==675 and fixture.sine_table_matches_reviewed_resource,"Independent native controls and original quarter-wave table are available")
	var origins:Dictionary={}
	for case in fixture.cases:
		origins[str(case.origin)]=true
		if case.has("arguments"):
			var packed:=Ground.constructor_angles(int(case.arguments[0]),int(case.arguments[1]))
			check(packed.x==int(case.ground_phase_u16) and packed.y==int(case.ground_inclination_u16),"F874 packing matches actual native constructor output")
		var actual:=Ground.native_radial(int(case.ground_phase_u16),int(case.ground_inclination_u16))
		check(actual==PackedInt64Array(case.radial_q31),"Port radial vector matches unmodified native F1674/F1914/F1521 output exactly")
		var site:Dictionary=Ground.from_record(int(case.ground_phase_u16),int(case.ground_inclination_u16));site.type_code=35
		var ll:Array=Ground.coordinates(site)
		var expected:=Vector3(actual[0],actual[1],actual[2]).normalized()
		check(ll.size()==2 and absf(ll[0])<=PI/2 and absf(ll[1])<=PI and Link.direction(ll[0],ll[1]).distance_to(expected)<0.000001,"Canonical body-frame coordinates preserve the source radial direction through poles and seams")
	check(origins.size()==6,"Controls cover handwritten ports, procedural tables, signed constructors, boundaries and random packed angles")
	var table_bytes:=PackedByteArray();table_bytes.resize(Ground.sine_quarter.size()*4)
	for index in range(Ground.sine_quarter.size()):table_bytes.encode_s32(index*4,int(Ground.sine_quarter[index]))
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(table_bytes)
	check(table_bytes.size()==65536 and hash.finish().hex_encode()==fixture.sine_table_sha256,"The entire runtime quarter-wave table matches the original executable bytes")
	check(Ground.coordinates({"type_code":35}).is_empty() and Ground.coordinates({"type_code":33,"ground_phase_u16":0,"ground_inclination_u16":0}).is_empty(),"Unsupported records do not invent source port coordinates")
	return fixture
func adapter_controls(fixture:Dictionary)->void:
	var nav:=Nav.new();var manual_count:=0
	for case in fixture.cases:
		if case.origin!="handcrafted":continue
		var world:=World.new();world.configure(nav.galaxy.get_system(int(case.system_id)))
		var selected:Dictionary={}
		for site in world.settlements:
			if site.name_en==case.name_en and int(site.type_code)==35:selected=site;break
		check(not selected.is_empty(),"Handwritten port remains available by original system and name")
		if selected.is_empty():continue
		manual_count+=1
		check(int(selected.ground_phase_u16)==int(case.ground_phase_u16) and int(selected.ground_inclination_u16)==int(case.ground_inclination_u16) and selected.ground_coordinate_source=="ffe_f874_arguments","Handwritten adapter normalizes constructor arguments once")
		check(int(selected.latitude_raw)==int(case.arguments[0]) and int(selected.longitude_raw)==int(case.arguments[1]),"Handwritten adapter keeps its original signed arguments for provenance")
	check(manual_count==21,"Every extracted handwritten ground port has a native positional control")
	var controls:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/inhabited_system_reference.json"))
	var adapter:=Adapter.new();var context:=World.new();var pairs:Dictionary={};var cases_used:=0
	for case in controls.cases:
		var records:Array=[]
		for encoded in case.result.records:records.append(str(encoded).hex_decode())
		check(adapter.apply_records(context,{"id":case.parameters[3]},records),"A complete native generated system can be adapted with its original port fields")
		cases_used+=1
		for site in context.settlements:
			if int(site.type_code)!=35:continue
			var record:PackedByteArray=str(site.record_hex).hex_decode()
			check(int(site.ground_phase_u16)==int(record.decode_u16(18)) and int(site.ground_inclination_u16)==int(record.decode_u16(34)) and site.ground_coordinate_source=="ffe_packed_record","Procedural adapter keeps packed source words instead of running F874 twice")
			pairs[str(site.ground_phase_u16)+":"+str(site.ground_inclination_u16)]=true
		if pairs.size()==16:break
	check(pairs.size()==16 and cases_used<100,"Actual generated records exercise all sixteen procedural ground positions")
func previous_release_controls()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/surface_geography_v0107.json"))
	check(fixture.source_zip_sha256=="2688e4b9869cddeed7fb82605aae67113469ce661db9bf21015bdac842408fad" and fixture.cases.size()==7,"Legacy controls originate from the actual packaged 0.10.7 project")
	for case in fixture.cases:
		var nav:=Nav.new();check(nav.restore(case.navigation),"Restore previous navigation: "+case.label)
		var world:=World.new();world.configure(nav.current());check(world.restore(case.world),"Restore previous world: "+case.label)
		var ship:=Ship.new();check(ship.restore(case.flight),"Restore previous flight: "+case.label)
		var loaded_flight:Dictionary=ship.snapshot()
		var surface:=Surface.new();check(surface.restore(case.surface,ship,world),"Restore actual previous surface state: "+case.label)
		check(ship.snapshot()==loaded_flight,"Legacy geography loading preserves the loaded flight and all progress: "+case.label)
		var position:Array=case.flight.position
		check(ship.position.distance_to(Vector3(position[0],position[1],position[2]))<0.000001 and ship.credits==int(case.flight.credits) and ship.hull==float(case.flight.hull) and int(ship.goods.medicines)==int(case.flight.goods.medicines),"Legacy source fixture position, money, hull and cargo are retained")
		if bool(case.surface.active):
			verify_legacy_geometry(surface,case)
			check(close_point(surface.geographic_position(ship),case.geographic),"Legacy ship remains at its saved geographic point: "+case.label)
			check(absf(surface.pad_distance(ship)-float(case.pad_distance))<0.02,"Legacy distance to landing target is preserved: "+case.label)
			var before_surface:=JSON.stringify(surface.snapshot());var before_ship:=JSON.stringify(ship.snapshot());var before_world:=JSON.stringify(world.snapshot())
			for revision in ["future-unknown",12,{},null]:
				var bad:Dictionary=case.surface.duplicate(true);bad.terrain_revision=revision
				check(not surface.restore(bad,ship,world) and JSON.stringify(surface.snapshot())==before_surface and JSON.stringify(ship.snapshot())==before_ship and JSON.stringify(world.snapshot())==before_world,"Unknown geography is rejected atomically rather than silently migrating a save")
		else:
			check(surface.globe==null and not surface.orbit_link.has("terrain_revision") and Link.terrain_revision(surface.orbit_link)==Sphere.REVISION,"Old orbital links without revision metadata retain hashed geography")
			var before_surface:=JSON.stringify(surface.snapshot());var before_ship:=JSON.stringify(ship.snapshot());var before_world:=JSON.stringify(world.snapshot())
			for revision in ["future-unknown",12,{},null]:
				var bad:Dictionary=case.surface.duplicate(true);bad.orbit_link.terrain_revision=revision
				check(not surface.restore(bad,ship,world) and JSON.stringify(surface.snapshot())==before_surface and JSON.stringify(ship.snapshot())==before_ship and JSON.stringify(world.snapshot())==before_world,"Invalid orbital geography cannot mutate live progress")
			var preview:=Near.new()
			if surface.orbit_link.revision==Link.REVISION:
				check(preview.update(surface,ship,world,nav.elapsed_days),"A previous v2 link reconstructs a preview after a fresh load")
				verify_legacy_geometry(preview.drawing,case)
				check(preview.enter_descent(surface,ship,world,nav.elapsed_days),"Previous v2 links re-enter using their saved geography")
			else:
				check(not preview.update(surface,ship,world,nav.elapsed_days),"Previous v1 embedding keeps its intentional legacy path")
				var bad:Dictionary=case.surface.duplicate(true);bad.orbit_link.terrain_revision=Sphere.SOURCE_REVISION
				check(not Link.valid(bad.orbit_link,world),"A v1 embedding cannot claim the new source geography")
				check(surface.enter_from_orbit(ship,world,nav.elapsed_days),"Previous v1 links still re-enter through their compatible fallback")
			verify_legacy_geometry(surface,case)
			check(close_point(surface.geographic_position(ship),case.geographic),"Legacy re-entry preserves the prior departure point")
func current_geography_controls()->void:
	var nav:=Nav.new();var world:=World.new();world.configure(nav.current());world.site_id="site10"
	var current:=Sphere.new();current.configure(world,"earth","site10",Sphere.SOURCE_REVISION)
	var old:=Sphere.new();old.configure(world,"earth","site10")
	var source:Array=Ground.coordinates(world.get_site("site10"))
	check(close_point([current.pad_latitude,current.pad_longitude],source),"New New Moscow landing target uses the verified source body-frame position")
	check(not close_point([old.pad_latitude,old.pad_longitude],source,0.001),"New source geography is distinct from the previous artistic port placement")
	check(old.revision==Sphere.REVISION and current.revision==Sphere.SOURCE_REVISION,"Legacy and source geography can coexist explicitly")
	for site in world.settlements:
		if site.parent!="earth" or int(site.type_code)!=35:continue
		var ll:Array=Ground.coordinates(site)
		check(close_point(current.site_coordinates(site.id),ll) and absf(current.elevation(ll[0],ll[1]))<0.000001,"Each original Earth ground port has a flattened landing district at its source position")
	var other:=Sphere.new();other.configure(world,"earth","site6",Sphere.SOURCE_REVISION)
	for ll in [[0.4,1.8],[-0.2,-0.3],source]:
		check(current.elevation(ll[0],ll[1])==other.elevation(ll[0],ll[1]),"Selecting another source port does not change planetary terrain")
	var ship:=Ship.new();ship.credits=7319;ship.goods.medicines=4
	var surface:=Surface.new();check(surface.enter(ship,world,true),"New surface entries choose source geography")
	check(surface.globe.revision==Sphere.SOURCE_REVISION and surface.snapshot().terrain_revision==Sphere.SOURCE_REVISION,"Active surface snapshots explicitly identify source geography")
	check(close_point([surface.globe.pad_latitude,surface.globe.pad_longitude],source) and surface.buildings().size()==10,"Source landing target and city geometry refer to the same port")
	check(surface.begin_landing(ship),"Source port approach can start")
	for tick in range(15000):
		surface.step(0.05,ship,Vector2.ZERO,0)
		if surface.landed:break
	check(surface.landed and ship.hull==100 and surface.pad_distance(ship)<40 and not surface.overlaps_building(ship),"Autopilot lands at the source port without terrain or building damage")
	var saved:Dictionary=json_copy(surface.snapshot());var copy:=Ship.new();copy.restore(json_copy(ship.snapshot()));var clone:=Surface.new()
	check(clone.restore(saved,copy,world) and clone.landed and close_point([clone.globe.pad_latitude,clone.globe.pad_longitude],source),"Source geography and landed progress survive JSON save/reload")
	check(clone.take_off(copy),"Source geography supports takeoff after reloading")
	copy.position.y=clone.height_at(copy.position.x,copy.position.z)+clone.clearance(copy)+700;copy.velocity=Vector3.ZERO
	var departure:Array=clone.geographic_position(copy)
	check(clone.leave(copy,world,nav.elapsed_days),"Source geography can hand off to orbit")
	world.site_id=""
	check(clone.orbit_link.terrain_revision==Sphere.SOURCE_REVISION and Link.valid(clone.orbit_link,world),"New orbital links persist the geography needed for a future fresh load")
	var orbital_flight:Dictionary=json_copy(copy.snapshot());var orbital_surface:Dictionary=json_copy(clone.snapshot())
	var fresh_ship:=Ship.new();fresh_ship.restore(orbital_flight);var fresh:=Surface.new()
	check(fresh.restore(orbital_surface,fresh_ship,world) and fresh.globe==null,"Fresh orbital loading reconstructs source geography from metadata, not a retained globe")
	var preview:=Near.new();check(preview.update(fresh,fresh_ship,world,nav.elapsed_days),"Fresh source orbital links activate a geographic preview")
	check(preview.drawing.globe.revision==Sphere.SOURCE_REVISION and close_point([preview.drawing.globe.pad_latitude,preview.drawing.globe.pad_longitude],source),"Fresh orbital preview reconstructs the same source landing target")
	var globe_id:int=preview.drawing.globe.get_instance_id()
	var old_link_state:Dictionary=orbital_surface.duplicate(true);old_link_state.orbit_link.erase("terrain_revision")
	check(fresh.restore(old_link_state,fresh_ship,world) and preview.update(fresh,fresh_ship,world,nav.elapsed_days),"Changing a restored geography invalidates a cached preview even on the same model instance")
	check(preview.drawing.globe.get_instance_id()!=globe_id and preview.drawing.globe.revision==Sphere.REVISION and close_point([preview.drawing.globe.pad_latitude,preview.drawing.globe.pad_longitude],[old.pad_latitude,old.pad_longitude]),"A cached source globe cannot leak into a legacy geography")
	check(fresh.restore(orbital_surface,fresh_ship,world) and preview.enter_descent(fresh,fresh_ship,world,nav.elapsed_days),"Source orbital saves support a controlled re-entry after fresh loading")
	check(fresh.globe.revision==Sphere.SOURCE_REVISION and close_point(fresh.geographic_position(fresh_ship),departure),"Source re-entry retains its departure point and source geography")
	var high_state:Dictionary=json_copy(fresh.snapshot());var high_ship:=Ship.new();high_ship.restore(json_copy(fresh_ship.snapshot()));var high_surface:=Surface.new()
	check(high_state.version==6 and high_surface.restore(high_state,high_ship,world) and high_surface.globe.revision==Sphere.SOURCE_REVISION and high_surface.flight_phase=="descent","Source geography also survives an active v6 descent save")
	check(high_ship.credits==7319 and int(high_ship.goods.medicines)==4 and high_ship.hull==100,"Source landing, takeoff, orbital reload and re-entry preserve progress")
func run()->void:
	var fixture:=native_controls();adapter_controls(fixture);previous_release_controls();current_geography_controls()
	print("GROUND COORDINATE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
