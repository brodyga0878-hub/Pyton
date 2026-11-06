extends SceneTree
const World=preload("res://scripts/planetary_system.gd")
const Definition=preload("res://scripts/source_system_definition.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const Flight=preload("res://scripts/flight_model.gd")
const Surface=preload("res://scripts/surface_model.gd")
const Navigation=preload("res://scripts/navigation.gd")
const Session=preload("res://scripts/source_station_session.gd")
const Profile=preload("res://scripts/source_ship_control_profile.gd")
var checks:=0
var failures:=0
var witnesses:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<20:push_error(label)
func json_copy(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func find_high_gravity_ports()->Array:
	var result:Array=[];var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_system_native.json"));var definition:=Definition.new()
	for row:Dictionary in fixture.system_cases:
		if row.group!="complete_handcrafted_dispatch":continue
		var world:=World.new();world.configure(definition.describe(int(row.system_id)),World.FULL_LAYOUT)
		if world.layout_mode!=World.FULL_LAYOUT:continue
		for site:Dictionary in world.settlements:
			if int(site.type_code)!=35 or int(site.model_index)==96:continue
			var record:=str(world.by_id[site.parent].runtime_record_hex).hex_decode()
			var placement:=Terrain.source_city_profile(site,record,Terrain.reference_radius(record))
			if placement.is_empty():continue
			var point:PackedFloat64Array=placement.source_root_body_m
			var sample:=world.source_surface_gravity(str(site.parent),Vector3(point[0],point[1],point[2]),0.0)
			if sample.is_empty():continue
			var gravity:=float(sample.gravity_mps2)
			if gravity>=20.0 and gravity<=26.0:result.append({"system_id":int(row.system_id),"site_id":str(site.id),"site_name":str(site.name),"body_id":str(site.parent),"model_index":int(world.by_id[site.parent].model_index),"body_uid_u32":int(record.decode_u32(4)),"gravity_mps2_at_native_anchor":gravity})
	return result
func restore_flight_surface(world:RefCounted,nav:RefCounted,ship:RefCounted,surface:RefCounted)->Dictionary:
	var saved_world:Dictionary=json_copy(world.snapshot());var restored_world:=World.new()
	restored_world.configure(nav.current(),World.FULL_LAYOUT)
	check(restored_world.restore(saved_world),"Actual source World snapshot restores before surface")
	var before_surface:=var_to_bytes(restored_world.snapshot())
	var restored:=Session.restore_flight(restored_world,nav,json_copy(ship.snapshot()))
	check(not restored.is_empty() and restored.ship.source_motion_profile,"Cobra source profile is re-derived from restored FULL context")
	if restored.is_empty():return {}
	var next:=Surface.new();next.set_source_time(nav.elapsed_days)
	check(next.restore(json_copy(surface.snapshot()),restored.ship,restored_world),"High-gravity landed/ascent surface state restores at actual source time")
	check(var_to_bytes(restored_world.snapshot())==before_surface,"Surface restore cannot rewind saved source spin to epoch")
	check(absf(restored.ship.acceleration()-Profile.acceleration("cobra"))<1e-10,"Restored phone controller retains the independent conservative source bound")
	return {"world":restored_world,"ship":restored.ship,"surface":next}
func test_port(witness:Dictionary)->void:
	var nav:=Navigation.new();check(nav.configure_native(int(witness.system_id)),"Actual native navigation locates high-gravity system")
	var world:=World.new();world.configure(nav.current(),World.FULL_LAYOUT)
	world.focus_id=str(witness.body_id);world.selected_id=world.focus_id;world.site_id=str(witness.site_id)
	var ship:=Flight.new();var session:=Session.configure_flight(ship,world,nav)
	check(session.ok and not session.active and ship.source_motion_profile,"FULL ground-port context derives source thrust without an invisible orbital station")
	check(ship.acceleration()>60.0 and ship.acceleration()<71.0,"Original weak-axis Cobra control replaces only the new-world18m/s2 limit")
	var old:=Flight.new();var blocked:=Surface.new().entry_error(old,world)
	check(not blocked.is_empty(),"Independent original high gravity reproduces the old insufficient-thrust entry trigger")
	var surface:=Surface.new();surface.set_source_time(nav.elapsed_days)
	check(surface.enter(ship,world,true),"Real high-gravity source port permits a safe source-Cobra entry")
	if not surface.active:return
	check(surface.gravity>=19.0 and surface.gravity<=27.0 and surface.gravity<ship.acceleration()*0.8,"Actual site gravity and source controller share a safe positive lift reserve")
	witness["live_entry_gravity_mps2"]=surface.gravity
	var safe:=false
	for offset in [Vector2(4000,4000),Vector2(-4000,0),Vector2(8000,8000),Vector2(12000,0)]:
		ship.position=Vector3(offset.x,surface.height_at(offset.x,offset.y)+surface.clearance(ship)+0.05,offset.y)
		ship.velocity=Vector3.ZERO;ship.target_speed=0;ship.attitude=Quaternion.IDENTITY
		if not surface.overlaps_building(ship) and surface._departure_column_clear(ship):safe=true;break
	check(safe,"A real collision-free off-pad landing/departure column exists")
	if not safe:return
	surface.recenter(ship);ship.position.y=surface.height_at(ship.position.x,ship.position.z)+surface.clearance(ship)+0.05
	check(surface.pad_distance(ship)>100.0 and surface.touch_down(ship) and surface.landed,"Healthy manual landing outside the actual source pad")
	var state:=restore_flight_surface(world,nav,ship,surface)
	if state.is_empty():return
	world=state.world;ship=state.ship;surface=state.surface
	check(surface.landed and surface.take_off(ship) and not surface.landed,"Restored off-pad manual take-off button works under original high gravity")
	var initial_height:=surface.altitude(ship)
	for i in range(30):
		nav.elapsed_days+=0.1/86400.0;surface.set_source_time(nav.elapsed_days);surface.step(0.1,ship,Vector2.ZERO,0.0,1.0)
	check(ship.hull==100.0 and surface.altitude(ship)>initial_height+5 and ship.velocity.y>0,"Positive phone UP lifts the restored source Cobra without hull damage")
	ship.brake()
	for i in range(15):
		nav.elapsed_days+=0.1/86400.0;surface.set_source_time(nav.elapsed_days);surface.step(0.1,ship,Vector2.ZERO,0.0)
	check(ship.velocity.length()<=20.0,"Phone brake stops manual high-gravity lift before departure")
	check(surface.begin_departure(ship) and surface.flight_phase=="ascent","Real high-gravity off-pad flight continues into automatic departure")
	var saved_height:=surface.altitude(ship);state=restore_flight_surface(world,nav,ship,surface)
	if state.is_empty():return
	world=state.world;ship=state.ship;surface=state.surface
	check(surface.flight_phase=="ascent" and not surface.landed,"Active high-gravity ascent survives save/load")
	for i in range(20):
		nav.elapsed_days+=0.1/86400.0;surface.set_source_time(nav.elapsed_days);surface.step(0.1,ship,Vector2.ZERO,0.0)
	check(surface.altitude(ship)>saved_height and ship.hull==100.0 and ship.position.is_finite(),"Saved high-gravity ascent continues with finite pose and full hull")
	witness["offpad_distance_m"]=surface.pad_distance(ship);witness["final_altitude_m"]=surface.altitude(ship);witness["source_control_profile"]=Profile.PROFILE
func run()->void:
	var candidates:=find_high_gravity_ports()
	check(candidates.size()>=1,"Actual original handcoded ports include a high-gravity witness")
	check(not candidates.is_empty() and int(candidates[0].system_id)==111466264 and int(candidates[0].model_index)==126,"Actual EtaCassiopeia LandVenice model126 is the original23m/s2 regression site")
	for i in range(mini(2,candidates.size())):
		var witness:Dictionary=candidates[i].duplicate(true);test_port(witness);witnesses.append(witness)
	print("SOURCE HIGH GRAVITY SURFACE WITNESSES: "+JSON.stringify(witnesses))
	print("SOURCE HIGH GRAVITY SURFACE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
