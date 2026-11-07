extends SceneTree
const Contact=preload("res://scripts/source_atmosphere_contact.gd")
const Natural=preload("res://scripts/source_ground_surface.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const Query=preload("res://scripts/source_terrain_query.gd")
const World=preload("res://scripts/planetary_system.gd")
const Flight=preload("res://scripts/flight_model.gd")
const Surface=preload("res://scripts/surface_model.gd")
const Galaxy=preload("res://scripts/galaxy.gd")
var checks:=0
var failures:=0
var evidence:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=25:push_error(message)
func raw_point(values:Variant)->PackedInt64Array:
	var result:=PackedInt64Array()
	for value:Variant in values:result.append(int(value))
	return result
func native_natural_references()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_ground_surface_native.json"));var kernel:=Contact.new();var models:Dictionary={}
	check(fixture.source_sha256==Contact.SOURCE_SHA and fixture.source_assembly_sha256=="d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a","Reused original native solid geometry reference provenance")
	for i in range(fixture.query_cases.size()):
		var row:Dictionary=fixture.query_cases[i];var expected:Dictionary=row.expected.passes[0];var parent:=str(row.expected.initialized_parent_hex).hex_decode();var point:=raw_point(row.point_input_raw);var before:=point.duplicate()
		var result:=kernel.query_raw(int(row.parent_model),int(parent.decode_u32(0xa0)),point,int(row.graphics_level));var label:="solid native%d model%d"%[i,int(row.parent_model)]
		check(result.ok,label+" exact original natural caller accepted")
		if not result.ok:continue
		models[int(row.parent_model)]=true
		check(result.contact.altitude_raw_s32==int(expected.height_s32),label+" F574 returned altitude")
		check(result.contact.flags_u8==int(expected.collision_flags_u8),label+" F575 actual atmosphere flags")
		check(result.terrain_query_calls==int(row.expected.terrain_query_calls),label+" native field call count")
		check(point==before,label+" source point remains immutable")
		check(result.body_flags_u8==int(parent[0x14c]),label+" actual descriptor-derived object flags")
	check(models.size()==17,"Every supported solid model consumes independent original reference rows")
	evidence.append({"reused_reference_fixture":"tests/fixtures/source_ground_surface_native.json","reused_reference_cases":fixture.query_cases.size(),"models":models.keys(),"new_original_machine_execution_by_this_test":false,"scope":"New context wrapper checked against already independently generated native fixture, not newly executing the original code."})
func native_gas_references()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_fuel_contact_native.json"));var kernel:=Contact.new();var count:=0
	for row:Dictionary in fixture.cases:
		var point:=raw_point(row.point_input_raw);var result:=kernel.query_raw(int(row.parent_model),int(row.parent_uid_u32),point,int(row.graphics_level));var expected:Dictionary=row.expected.passes[0]
		check(result.ok,"Frozen gas/star natural module remains callable")
		if not result.ok:continue
		check(result.contact.altitude_raw_s32==int(expected.height_s32) and result.contact.flags_u8==int(expected.collision_flags_u8),"Gas/star contact forwards exact original reference height and flags")
		count+=1
	evidence.append({"reused_reference_fixture":"tests/fixtures/source_fuel_contact_native.json","reused_reference_cases":count,"new_original_machine_execution_by_this_test":false})
func native_speed_references()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_atmosphere_speed_native.json"))
	check(fixture.source_variant=="pinned_JJFFE_original_source_instructions_host_ABI" and not fixture.whole_DOS_binary_equivalence,"New native speed reference does not claim whole DOS instruction equivalence")
	check(fixture.fresh_process_runs==3 and fixture.reverse_repeat_count==fixture.case_count,"Fresh/reverse native speed controls agree")
	for i in range(fixture.cases.size()):
		var row:Dictionary=fixture.cases[i];var before:Array=row.velocity_s32.duplicate();var result:=Contact.speed_from_raw_velocity(row.velocity_s32)
		check(result.ok,"Raw velocity accepted for speed reference"+str(i))
		check(result.speed_s32==int(row.speed_s32),"Actual F1099/F1475/F1466 speed reference"+str(i))
		check(result.source_shift==int(row.source_shift),"Actual F1475 scaling reference"+str(i))
		check(row.velocity_s32==before,"Speed resampling preserves source input vector"+str(i))
	for value:Variant in [[],[0,0],[0,0,NAN],[0,0,1.5],[0,0,0x80000000]]:check(not Contact.speed_from_raw_velocity(value).ok,"Malformed raw speed resampling rejects")
	evidence.append({"new_native_speed_cases":fixture.case_count,"native_speed_variant":fixture.source_variant,"native_speed_output_sha256":fixture.native_output_sha256})
func live_contexts()->void:
	var galaxy:=Galaxy.new();galaxy.configure_native();var world:=World.new();world.configure(galaxy.get_system(World.SOL_ID),World.FULL_LAYOUT);var ship:=Flight.new();var surface:=Surface.new();var kernel:=Contact.new()
	check(world.layout_mode==World.FULL_LAYOUT,"Actual complete source Sol context")
	var before:=var_to_bytes([world.snapshot(),ship.snapshot(),surface.snapshot()]);var initial:=kernel.sample(world,ship,surface,0)
	check(initial.ok and var_to_bytes([world.snapshot(),ship.snapshot(),surface.snapshot()])==before,"Free-flight context is read-only")
	var spin_before:=var_to_bytes(world.snapshot().body_spin_by_id);check(kernel.sample(world,ship,surface,1).ok and var_to_bytes(world.snapshot().body_spin_by_id)==spin_before,"Future sampling preserves actual source spin state")
	check(not kernel.sample(world,ship,surface,-1).ok,"Invalid source time rejects before deriving geometry")
	world.focus_id="earth";world.selected_id="earth";world.site_id="";ship.station_available=false;ship.docked=false;ship.hull=100;ship.source_motion_profile=false
	var terrain:=Terrain.new();terrain.configure(world,"earth","")
	check(terrain.configured_ok,"Actual source Earth field configured without a city selection")
	var lat:=terrain.latitude;var lon:=terrain.longitude;var elevation:=terrain.elevation(lat,lon);var ll_basis:Basis=terrain.basis_at(lat,lon);var position_body:Vector3=ll_basis*Vector3(0,float(terrain.radius)+elevation+1500,0)
	var orientation:=Contact.Gas._basis_readonly(world,world.by_id.earth,0);ship.position=world.local_meters("earth",0)+Basis(orientation.basis)*position_body;ship.velocity=Vector3(500,200,-100)
	var orbital:=kernel.sample(world,ship,surface,0,true)
	check(orbital.ok and orbital.body_id=="earth" and orbital.apply_f1014 and orbital.within_altitude_gate,"Actual atmospheric Earth point activates F1014 natural branch")
	check(orbital.gear_down and orbital.velocity_s32.size()==3 and orbital.velocity_basis==Basis.IDENTITY,"Caller gear and native velocity frame are explicit")
	# Use the same source surface object and local tangent coordinates as the
	# production Surface model; no fake contact flags or height are supplied.
	surface.active=true;surface.body_id="earth";surface.globe=terrain;surface._source_system=world;surface._source_days=0;ship.surface_mode=true;ship.position=Vector3(0,elevation+1500,0);ship.velocity=Vector3(500,200,-100)
	before=var_to_bytes([world.snapshot(),ship.snapshot(),surface.snapshot()]);var shared_before:=var_to_bytes(Query.resources);var active:=kernel.sample(world,ship,surface,0)
	check(active.ok and active.apply_f1014 and active.within_altitude_gate and active.body_id=="earth","Actual source surface tangent position uses the same native atmosphere field")
	check(active.velocity_frame=="bodyfixed_from_current_source_surface_tangent" and not active.gear_down,"Surface mode does not invent a native undercarriage state")
	check((active.velocity_to_phone_basis*active.bodyfixed_basis).is_equal_approx(Basis.IDENTITY),"Bodyfixed drag delta maps back to the exact current phone tangent basis")
	check(var_to_bytes([world.snapshot(),ship.snapshot(),surface.snapshot()])==before and var_to_bytes(Query.resources)==shared_before,"Surface context preserves source terrain, saved frame, ship and shared field tables")
	check(absf(float(active.altitude_s32)-float(orbital.altitude_s32))<100000,"Orbital and tangent contexts agree on source field altitude within explicit float32 position adapter precision")
	ship.position.y=elevation+25000;var high:=kernel.sample(world,ship,surface,0)
	check(high.ok and not high.within_altitude_gate,"Above source20M-raw altitude skips the thermal core gate")
	ship.docked=true;check(not kernel.sample(world,ship,surface,0).apply_f1014,"Docked ships never receive airborne phone heating")
	ship.docked=false;surface.active=false;ship.surface_mode=false;world.focus_id="mercury";world.selected_id="mercury";world.site_id=""
	var mercury:=Terrain.new();mercury.configure(world,"mercury","");var mercury_height:=mercury.elevation(mercury.latitude,mercury.longitude);var mercury_point:Vector3=mercury.basis_at(mercury.latitude,mercury.longitude)*Vector3(0,mercury.radius+mercury_height+1000,0);var mercury_rotation:=Contact.Gas._basis_readonly(world,world.by_id.mercury,0);ship.position=world.local_meters("mercury",0)+Basis(mercury_rotation.basis)*mercury_point
	var airless:=kernel.sample(world,ship,surface,0);check(airless.ok and airless.body_id=="mercury" and not airless.apply_f1014 and (int(airless.contact.flags_u8)&1)==0,"Original airless Mercury prefix82 never gains a fictional atmosphere")
	world.focus_id="earth";world.selected_id="earth";var star:Dictionary=world.by_id.star;var meta:=Contact.metadata(int(star.model_index));ship.position=world.local_meters("star",0)+Vector3(float(meta.outer_bound_m)*0.95,0,0)
	var stellar:=kernel.sample(world,ship,surface,0)
	check(stellar.ok and stellar.apply_f1014 and stellar.contact.altitude_raw_s32==-1 and stellar.altitude_s32==0x7fffffff and not stellar.within_altitude_gate,"Unknown source stellar height is HUD INTMAX before F1014; negative raw sentinel cannot falsely heat or drag")
	world.layout_mode=World.PORT_LAYOUT;check(not kernel.sample(world,ship,surface,0).apply_f1014,"Legacy world does not opt in implicitly")
	evidence.append({"live_earth_orbit_contact":orbital.contact,"live_earth_surface_contact":active.contact,"airless_mercury_contact":airless.contact,"star_unknown_altitude_normalized":stellar.altitude_s32,"reference_frame":"Orbit: current phone world-local words; surface: bodyfixed words with an inverse tangent basis for applying only the drag delta. Automatic original rotating-frame selection remains outside this wrapper.","gear_policy":"Explicit raw E9 bit2, default clear; SET requests retraction. No implicit surface-mode physical gear assertion."})
func run()->void:
	native_natural_references();native_gas_references();native_speed_references();live_contexts()
	var report:={"schema":1,"checks":checks,"failures":failures,"evidence":evidence,"scope":"New read-only natural atmosphere context wrapper, actual World/Surface frame projection, original raw-speed extraction and F1033 HUD-altitude sentinel. Solid/gas native field fixtures are reused reference records; only239 raw-speed controls are newly independently executed. Pinned JJFFE/source-data provenance is mixed and does not establish whole-DOS equivalence or full F569/caller dispatch.","physical_device_tested":false,"sources":{"core_sha256":FileAccess.get_sha256("res://scripts/source_atmosphere_contact.gd"),"test_sha256":FileAccess.get_sha256("res://tests/test_source_atmosphere_contact.gd"),"speed_fixture_sha256":FileAccess.get_sha256("res://tests/fixtures/source_atmosphere_speed_native.json"),"solid_reference_sha256":FileAccess.get_sha256("res://tests/fixtures/source_ground_surface_native.json"),"gas_reference_sha256":FileAccess.get_sha256("res://tests/fixtures/source_fuel_contact_native.json"),"ground_resource_sha256":FileAccess.get_sha256("res://data/ffe_ground_collision.json"),"fuel_resource_sha256":FileAccess.get_sha256("res://data/ffe_fuel.json")}}
	var path:="res://validation/contact-2026-11-08/atmosphere-contact-regression.json";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()));var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));print("Source atmosphere contact: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
